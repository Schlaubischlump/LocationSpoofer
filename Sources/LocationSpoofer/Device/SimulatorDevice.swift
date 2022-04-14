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
        let devices = SimDeviceWrapper.availableDevices()
        return (devices?.allObjects as? [Device]) ?? []
    }

    public static var isGeneratingDeviceNotifications: Bool {
        return SimulatorDevice.subscriberID != nil
    }

    /// The internal handler id for simulator device notifications
    static private var subscriberID: UInt?

    // MARK: - Instance attributes

    public private(set) var udid: String
    public private(set) var name: String
    public private(set) var productName: String?
    public private(set) var version: String?
    public private(set) var connectionType: ConnectionType = .unknown

    /// Internal wrapper around the simulator device
    private var wrapper: SimDeviceWrapper?

    // MARK: - Static functions

    @discardableResult
    public static func startGeneratingDeviceNotifications() -> Bool {
        guard !SimulatorDevice.isGeneratingDeviceNotifications else { return false }

        // Listen for new simulator devices.
        SimulatorDevice.subscriberID = SimDeviceWrapper.subscribe { simDeviceWrapper in
            let udid = simDeviceWrapper.udid()
            let name = simDeviceWrapper.name()
            var device = SimulatorDevice(udid: udid, name: name, connectionType: .unknown, wrapper: simDeviceWrapper)
            device.productName = simDeviceWrapper.productName()
            device.version = simDeviceWrapper.productVersion();

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
        return self.wrapper?.setLocationWithLatitude(location.latitude, andLongitude: location.longitude) ?? false
    }

    public func disableSimulation() -> Bool {
        if self.wrapper?.resetLocation() ?? false {
            return true
        }
        return false
    }
}

extension SimulatorDevice: Equatable {
    /// We consider a device to be equal if the udid is the same.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.udid == rhs.udid
    }
}
