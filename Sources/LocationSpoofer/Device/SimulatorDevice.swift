//
//  SimulatorDevice.swift
//  LocationSimulator
//
//  Created by David Klopp on 13.03.21.
//  Copyright © 2021 David Klopp. All rights reserved.
//

#if SWIFT_PACKAGE
//import CLogger
import SimulatorDevice
#endif

import Foundation
import CoreLocation

public struct SimulatorDevice: Device {

    // MARK: - Static attributes

    public static var availableDevices: [Device] {
        let devices = SimDeviceWrapper.availableDevices()?.allObjects as? [SimDeviceWrapper] ?? []
        return (devices.map { SimulatorDevice(wrapper: $0) } as? [Device]) ?? []
    }

    public static var isGeneratingDeviceNotifications: Bool {
        return SimulatorDevice.subscriberID != nil
    }

    /// The internal handler id for simulator device notifications
    static private var subscriberID: UInt?

    // MARK: - Instance attributes

    public var udid: String {
        return self.wrapper.udid()
    }
    public var name: String {
        return self.wrapper.name()
    }
    public var productName: String? {
        return self.wrapper.productName()
    }
    public var version: String? {
        return self.wrapper.productVersion()
    }
    public private(set) var connectionType: ConnectionType = .unknown

    /// Internal wrapper around the simulator device
    private var wrapper: SimDeviceWrapper

    // MARK: - Static functions

    @discardableResult
    public static func startGeneratingDeviceNotifications() -> Bool {
        guard !SimulatorDevice.isGeneratingDeviceNotifications else { return false }

        // Listen for new simulator devices.
        SimulatorDevice.subscriberID = SimDeviceWrapper.subscribe { simDeviceWrapper in
            let device = SimulatorDevice(wrapper: simDeviceWrapper)
            let connected = simDeviceWrapper.isConnected()
            let notification: Notification.Name = connected ? .DeviceConnected : .DeviceDisconnected
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: notification, object: nil, userInfo: ["device": device])
            }
        }

        return true
    }

    @discardableResult
    public static func stopGeneratingDeviceNotifications() -> Bool {
        guard SimulatorDevice.isGeneratingDeviceNotifications else { return false }
        return SimDeviceWrapper.unsubscribe(SimulatorDevice.subscriberID!)
    }

    // MARK: - Manage location

    public func simulateLocation(_ location: CLLocationCoordinate2D) -> Bool {
        return self.wrapper.setLocationWithLatitude(location.latitude, andLongitude: location.longitude)
    }

    public func disableSimulation() -> Bool {
        return self.wrapper.resetLocation()
    }
}

extension SimulatorDevice: Equatable {
    /// We consider a device to be equal if the udid is the same.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.udid == rhs.udid
    }
}
