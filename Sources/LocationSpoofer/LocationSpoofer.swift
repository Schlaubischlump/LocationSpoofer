//
//  LocationSpoofer.swift
//  LocationSimulator
//
//  Created by David Klopp on 18.08.19.
//  Copyright © 2019 David Klopp. All rights reserved.
//

import Foundation
import CoreLocation

// MARK: - Constants

public typealias SucessHandler = (_ sucessfull: Bool) -> Void

// MARK: - Spoofer

public class LocationSpoofer {

    // MARK: - Properties

    /// Current simulated location.
    public private(set) var currentLocation: CLLocationCoordinate2D?

    /// The last current location without the GPS uncertainty drift.
    public private(set) var realCurrentLocation: CLLocationCoordinate2D?

    /// Change the direction in which to move (you can change this while auto updating is active).
    public var heading: CLLocationDegrees = 0.0

    /// The movement speed variance in percentage of current speed. Set this value to vary the current movement speed.
    /// Set this value to nil to disable the movement speed variance. E.g a range of 0.8..1.2 would mean, the movement
    /// speed will be at least 0.8 of the current speed and at most 1.2 of the current speed value.
    public var movementSpeedVariance: Range<Double>?

    /// Delegate which is informed about location changes.
    public weak var delegate: LocationSpooferDelegate?

    /// The current automove state. Use `manual` to navigate by calling the move function. Use `auto` to automatically
    /// move depeding on the speed and heading value. Use `navigate` to follow a specific route with the specified
    /// speed.
    public var moveState: MoveState = .manual {
        willSet {
            guard self.moveState != newValue else { return }
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.delegate?.willChangeMoveState(spoofer: strongSelf, toMoveState: newValue)
            }
        }
        didSet {
            guard self.moveState != oldValue else { return }
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.delegate?.didChangeMoveState(spoofer: strongSelf, fromMoveState: oldValue)
            }
        }
    }

    /// The current move type which defines the speed. The available types are: walk, cycle and drive.
    public var moveType: MoveType = .walk {
        willSet {
            guard self.moveType != newValue else { return }
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.delegate?.willChangeMoveType(spoofer: strongSelf, toMoveType: newValue)
            }
        }
        didSet {
            guard self.moveType != oldValue else { return }
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.delegate?.didChangeMoveType(spoofer: strongSelf, fromMoveType: oldValue)
            }
        }
    }

    /// The connected device.
    public let device: Device

    /// Total distance moved in meter.
    public private(set) var totalDistance: CLLocationDistance = 0.0

    /// True if auto update is active, false otherwise.
    public private(set) var isAutoUpdating: Bool = false {
        willSet {
            guard self.isAutoUpdating != newValue else { return }
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.delegate?.willChangeAutoUpdate(spoofer: strongSelf, toValue: newValue)
            }
        }
        didSet {
            guard self.isAutoUpdating != oldValue else { return }
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.delegate?.didChangeAutoUpdate(spoofer: strongSelf, fromValue: oldValue)
            }
        }
    }

    /// The current speed. Can be changed will auto updating.
    public var speed: CLLocationSpeed = 0

    /// Internal: Background queue which performs the location update operations.
    private let dispatchQueue: DispatchQueue

    /// Internal: The current work item used to dispatch the location update.
    private var updateWorkItem: DispatchWorkItem?

    /// Internal: True if a location update operation is ongoing. False otherwise.
    private var hasPendingTask: Bool = false

    // MARK: - Constructor

    public init(_ device: Device) {
        self.device = device
        self.currentLocation = nil
        self.realCurrentLocation = nil
        self.dispatchQueue = DispatchQueue(label: "locationUpdates", qos: .userInteractive)
    }

    // MARK: - Public

    /// Async call to change the device location. Use the delegate method to get informed when the location did change.
    /// - Parameter coordinate: new location
    public func setLocation(_ coordinate: CLLocationCoordinate2D) {
        // Only allow setting the location in manual state
        guard self.moveState == .manual else { return }
        self.setLocation(coordinate) { _ in }
    }

    /// Disable location spoofing for the connected device. This will reset the location to the real device location.
    public func resetLocation() {
        // Inform delegate that the location will be reset
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.delegate?.willChangeLocation(spoofer: strongSelf, toCoordinate: nil)
        }

        // Disable auto update and revert back to manual movement
        self.stopAutoUpdate()

        self.dispatchQueue.async { [weak self] in
            // Try to reset the location
            let success: Bool = self?.device.disableSimulation() ?? false
            if success {
                self?.totalDistance = 0.0
                self?.currentLocation = nil
                self?.realCurrentLocation = nil
            }

            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }

                if success {
                    strongSelf.delegate?.didChangeLocation(spoofer: strongSelf, toCoordinate: nil)
                } else {
                    strongSelf.delegate?.errorChangingLocation(spoofer: strongSelf, toCoordinate: nil)
                }
            }
        }
    }

    /// Update the current location by moving to the next location depending on the move state, the speed and heading.
    public func move() throws {
        // TODO: Move this out of the spoofer class. This should be handled inside key down (or the function that is called in mapViewController on key down) and didChangeLocation ?
        // We only allow a new manual move, if the previous move is finished.
        guard !self.hasPendingTask else {
            throw LocationSpooferError.queueIsBusy("Operation queue is busy. Wait till the task is finished.")
        }

        if !self.isAutoUpdating {
            // Auto move is deactivated. We can manually move indepentently of the move state.
            guard let nextLocation = self.moveState.getNextLocation(distance: self.moveType.speed,
                                                                    heading: self.heading,
                                                                    previousLocation: self.currentLocation,
                                                                    isAutoUpdate: false) else {
                return
            }
            self.setLocation(nextLocation)
        } else if case .manual = self.moveState {
            // Make sure no update operation gets in the way
            self.cancelNextUpdate()
            // We always assume a time difference of 1 second to calculate the distance
            guard let nextLocation = self.moveState.getNextLocation(distance: self.moveType.speed,
                                                                    heading: self.heading,
                                                                    previousLocation: self.currentLocation,
                                                                    isAutoUpdate: false) else {
                return
            }
            let interval = self.moveState.getNextAutoUpdateInterval()
            self.setLocation(nextLocation) { [weak self] successful in
                // Reschedule ourself to add a gps uncertainty effect.
                guard successful else { return }
                self?.scheduleNextUpdate(after: interval)
            }
        } else {
            throw LocationSpooferError.interactionNotPossible(
                "Interaction while auto updating is only possible in 'manual' mode."
            )
        }
    }

    /// Automatically update the current location based on the move type, heading and speed after.
    /// You might need a current location to activate auto update depending on the move state.
    /// - Return: True if the auto update can be started, False otherwise.
    @discardableResult
    public func startAutoUpdate() -> Bool {
        guard !self.isAutoUpdating else {
            return true
        }

        // We need a current location to auto update.
        if self.moveState.requiresInitialLocationForAutoUpdate && self.currentLocation == nil {
            return false
        }

        self.isAutoUpdating = true

        let interval = self.moveState.getNextAutoUpdateInterval()
        self.scheduleNextUpdate(after: interval)
        // self.update(interval: interval)

        return true
    }

    /// Stop the automatic update operation.
    public func stopAutoUpdate() {
        guard self.isAutoUpdating else { return }
        self.cancelNextUpdate()
        self.isAutoUpdating = false
    }

    /// Toggle the auto update state. 
    public func toggleAutoUpdate() {
        if self.isAutoUpdating {
            self.stopAutoUpdate()
        } else {
            self.startAutoUpdate()
        }
    }

    // MARK: - Private

    /// Change the location on the connected device to the new coordinates.
    /// - Parameter coordinate: new location
    /// - Parameter isGpsUncertaintyUpdate: True if the operation simulates a GPS uncertainty effect
    /// - Parameter completion: completion block after the update oparation was performed
    private func setLocation(_ coordinate: CLLocationCoordinate2D, isGpsUncertaintyUpdate: Bool = false,
                             completion:@escaping SucessHandler) {
        self.hasPendingTask = true

        // inform delegate that the location will change
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.delegate?.willChangeLocation(spoofer: strongSelf, toCoordinate: coordinate)
        }

        self.dispatchQueue.async { [weak self] in
            // try to simulate the location on the device
            let success: Bool = self?.device.simulateLocation(coordinate) ?? false
            if success {
                self?.totalDistance += self?.currentLocation?.distanceTo(coordinate: coordinate) ?? 0
                self?.currentLocation = coordinate
                if !isGpsUncertaintyUpdate {
                    self?.realCurrentLocation = coordinate
                }
            }

            // call the completion block and inform the delegate about the change
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }
                completion(success)
                if success {
                    strongSelf.delegate?.didChangeLocation(spoofer: strongSelf, toCoordinate: coordinate)
                } else {
                    strongSelf.delegate?.errorChangingLocation(spoofer: strongSelf, toCoordinate: coordinate)
                }
                strongSelf.hasPendingTask = false
            }
        }
    }

    /// Cancel the next scheduled update operation.
    private func cancelNextUpdate() {
        // Cancel any ongoing operation
        self.updateWorkItem?.cancel()
        self.updateWorkItem = nil
    }

    /// Schedule a new update operation after a specific time.
    /// - Parameter after: The time after which the update should be scheduled
    /// - Parameter lastTime: The last update time
    @discardableResult
    private func scheduleNextUpdate(after: TimeInterval, lastTime: TimeStamp? = nil) -> Bool {
        guard self.isAutoUpdating else {
            return false
        }

        self.cancelNextUpdate()

        // Schedule the new update operation
        let work = DispatchWorkItem() { [weak self] in
            self?.update(interval: after, lastTime: lastTime)
        }
        self.updateWorkItem = work
        self.dispatchQueue.asyncAfter(deadline: .now() + after, execute: work)

        return true
    }

    /// Move `moveType.distance` meters per second into the direction defined by `heading` or by the current route.
    /// This function will reschedule itself.
    /// - Parameter interval: The interval used to schedule the next update operation
    /// - Parameter lastTime: The time stamp of the last update operation.
    private func update(interval: TimeInterval, lastTime: TimeStamp? = nil) {
        // Apply the variance to the speed if required
        var distance = 0.0
        var speed = self.speed
        if let variance = self.movementSpeedVariance {
            speed = max(0.0, speed * Double.random(in: variance))
        }

        // If the `setLocation` takes to long we might need to move a little bit more to keep the speed.
        if let lastTime = lastTime {
            distance = speed * TimeStamp.seconds(since: lastTime)
        } else {
            distance = speed * interval
        }

        // We simulate a gps uncertainty effect from the last manually set location.
        // Not from the already modified location.
        let isInManualState = self.moveState == .manual
        let previousLocation = isInManualState ? self.realCurrentLocation : self.currentLocation

        // As long as we have a next location we can update the location.
        guard let nextLocation = self.moveState.getNextLocation(distance: distance, heading: self.heading,
                                                                previousLocation: previousLocation,
                                                                isAutoUpdate: true) else {
            self.stopAutoUpdate()
            return
        }

        // Save the time when we start sending the location information
        let time = TimeStamp.now()
        let nextInterval = self.moveState.getNextAutoUpdateInterval(previousInterval: interval)

        // Send the new location information
        self.setLocation(nextLocation, isGpsUncertaintyUpdate: isInManualState) { [weak self] successful in
            // Cancel the update if the location could no be changed
            guard successful else {
                self?.stopAutoUpdate()
                return
            }

            // Reschedule ourself after setting the new location!
            self?.scheduleNextUpdate(after: nextInterval, lastTime: time)
        }
    }
}
