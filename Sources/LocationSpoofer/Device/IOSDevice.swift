//
//  Device.swift
//  LocationSimulator
//
//  Created by David Klopp on 18.08.19.
//  Copyright © 2019 David Klopp. All rights reserved.
//

import Foundation
import CoreLocation

#if SWIFT_PACKAGE
//import CLogger
import CMobileDevice
#endif


/// An internal map with all currently detected devices.
private var deviceList: [String: IOSDevice] = [:]

public struct IOSDevice: Device {

    // MARK: - Static attributes

    public static var availableDevices: [Device] {
        return Array(deviceList.values)
    }

    public private(set) static var isGeneratingDeviceNotifications: Bool = false

    /// The default `preferNetworkConnection` value.
    /// Change this value to change the `preferNetworkConnection` on initialisation for all devices.
    public static var preferNetworkConnectionDefault: Bool = false

    /// Set this value to true to find network & USB devices or to false to only find USB devices.
    public static var detectNetworkDevices: Bool = true

    // MARK: - Instance attributes

    public private(set) var udid: String
    public private(set) var name: String
    public private(set) var productName: String?
    public private(set) var version: String?
    public private(set) var connectionType: ConnectionType = .unknown

    /// Prefer the network connection even if the device is paired via USB.
    public var preferNetworkConnection: Bool = false

    /// Readonly: Get the current lookup flags to perform the request. This allows changing from USB to network.
    private var lookupOps: idevice_options {
        // Get the current lookup operations for this connection type. This might be USB, network or both.
        var ops = self.connectionType.lookupOps
        // If the device is connected via the network and we prefer this connection, then pass in the flag.
        if self.preferNetworkConnection && self.connectionType.contains(.network) {
            ops.rawValue |= IDEVICE_LOOKUP_PREFER_NETWORK.rawValue
        }
        return ops
    }

    /// Readonly: True when the devices uses the network connection, otherwise false.
    public var usesNetwork: Bool {
        return (self.connectionType == .network) ||
               (self.connectionType.contains(.network) && self.preferNetworkConnection)
    }

    /// Readonly: True if the DeveloperDiskImage is already mounted
    public var developerDiskImageIsMounted: Bool {
        var allConnections = ConnectionType.usb
        allConnections.insert(ConnectionType.network)
        return developerImageIsMountedForDevice(udid, allConnections.lookupOps)
    }

    // MARK: - Static functions

    // swiftlint:disable cyclomatic_complexity
    /// Start an observer for newly added, paired or removed iOS devices.
    /// - Return: True if the observer could be started, false otherwise.
    @discardableResult
    public static func startGeneratingDeviceNotifications() -> Bool {
        guard !IOSDevice.isGeneratingDeviceNotifications else { return false }

        let callback: idevice_event_cb_t = { (event, _: UnsafeMutableRawPointer?) in
            guard let eventT = event?.pointee, let udidT = eventT.udid else { return }

            let udid = String(cString: udidT)
            var notificationName: Notification.Name?

            // Replace the idevice_connection_type with a swift enum
            var conType: ConnectionType = .unknown
            switch eventT.conn_type {
            case CONNECTION_USBMUXD: conType = .usb
            case CONNECTION_NETWORK:
                // Make sure to skip this network device if we only allow USB connections.
                guard IOSDevice.detectNetworkDevices else { return }
                conType = .network
            default: conType = .unknown
            }

            // The existing device isntance or nil if the device does not exist yet.
            var device = deviceList[udid]

            // Determine the correct event to send
            switch eventT.event {
            case IDEVICE_DEVICE_ADD, IDEVICE_DEVICE_PAIRED:
                // Check if the devive is already connected via a different connection type.
                if (device != nil) && !(device!.connectionType.contains(conType)) {
                    // Add the missing connection type to the device.
                    device?.connectionType.insert(conType)
                    notificationName = .DeviceChanged
                    break
                } else if let res = deviceName(udid, conType.lookupOps) {
                    // Create and add the device to the internal device list before sending the notification.
                    device = IOSDevice(UDID: udid, name: String(cString: res), connectionType: conType)
                    notificationName = (eventT.event == IDEVICE_DEVICE_ADD) ? .DeviceConnected : .DevicePaired

                    // Load the product details
                    let productVersion: UnsafePointer<Int8> = deviceProductVersion(udid, conType.lookupOps)
                    device?.version = String(cString: productVersion)

                    let productName: UnsafePointer<Int8> = deviceProductName(udid, conType.lookupOps)
                    device?.productName = String(cString: productName)

                    break
                }

                // Something went wrong. Most likely we can not read the device. Abort.
                return

            case IDEVICE_DEVICE_REMOVE:
                // Remove an existing connectionType from the list.
                if  device?.connectionType.contains(conType) ?? false {
                    device?.connectionType.remove(conType)

                    // If there is no connection type left, we need to disconnect the device.
                    notificationName = (device?.connectionType.isEmpty ?? true) ? .DeviceDisconnected : .DeviceChanged
                    break
                }

                // Something went wrong. Maybe some error in the connection.
                notificationName = .DeviceDisconnected
            default:
                return
            }

            // The deviceList does not store references, therefore write the modified device to the list to update
            // the cached device.
            deviceList[udid] = (notificationName == .DeviceDisconnected) ? nil : device

            DispatchQueue.main.async {
                // Fix a rare crash where device is somehow nil.
                if let device = device {
                    NotificationCenter.default.post(name: notificationName!, object: nil, userInfo: ["device": device])
                }
            }
        }

        // Subscribe for new devices events.
        if idevice_event_subscribe(callback, nil) == IDEVICE_E_SUCCESS {
            IOSDevice.isGeneratingDeviceNotifications = true
            return true
        }

        return false
    }
    // swiftlint:enable cyclomatic_complexity

    /// Stop observing device changes.
    /// - Return: True if the observer could be closed, False otherwise.
    @discardableResult
    public static func stopGeneratingDeviceNotifications() -> Bool {
        guard IOSDevice.isGeneratingDeviceNotifications else { return false }

        // Remove all currently connected devices.
        deviceList.forEach({
            NotificationCenter.default.post(name: .DeviceDisconnected, object: nil, userInfo: ["device": $1])
        })
        deviceList.removeAll()

        // Cancel device event subscription.
        if idevice_event_unsubscribe() == IDEVICE_E_SUCCESS {
            IOSDevice.isGeneratingDeviceNotifications = false
            return true
        }

        return false
    }

    // MARK: - Initializing Device
    private init(UDID: String, name: String, connectionType: ConnectionType) {
        self.udid = UDID
        self.name = name
        self.connectionType = connectionType
        // Assign the default value
        self.preferNetworkConnection = IOSDevice.preferNetworkConnectionDefault
    }

    // MARK: - Upload Developer Disk Image

    /// Pair the specific iOS Device with this computer and try to upload the DeveloperDiskImage.
    /// - Parameter devImage: URL to the DeveloperDiskImage.dmg
    /// - Parameter devImageSig: URL to the DeveloperDiskImage.dmg.signature
    /// - Throws:
    ///    * `DeviceError.pair`: The pairing process failed
    ///    * `DeviceError.devDiskImageMount`: DeveloperDiskImage mounting failed
    /// - Return: Device instance
    public func pair(devImage: URL, devImageSig: URL) throws {
        // Check if the device is connected
        guard pairDevice(self.udid, self.lookupOps) else {
            throw DeviceError.pair("Could not pair device!")
        }

        // Try to mount the DeveloperDiskImage.dmg
        if !self.mountDeveloperDiskImage(devImage: devImage, devImageSig: devImageSig) {
            throw DeviceError.devDiskImageMount("Mount error!")
        }
    }

    /// Try to upload and mount the DeveloperDiskImage.dmg on this device.
    /// - Parameter devImage: URL to the DeveloperDiskImage.dmg
    /// - Parameter devImageSig: URL to the DeveloperDiskImage.dmg.signature
    private func mountDeveloperDiskImage(devImage: URL, devImageSig: URL) -> Bool {
        return mountImageForDevice(udid, devImage.path, devImageSig.path, self.lookupOps)
    }

    // MARK: - Managing locations

    /// Set the device location to the new coordinates.
    /// - Parameter location: new coordinates
    /// - Return: True on success, false otherwise.
    @discardableResult
    public func simulateLocation(_ location: CLLocationCoordinate2D) -> Bool {
        return sendLocation("\(location.latitude)", "\(location.longitude)", "\(self.udid)", self.lookupOps)
    }

    /// Stop spoofing the iOS device location and reset the coordinates to the real device coordinates.
    /// - Return: True on success, False otherwise.
    @discardableResult
    public func disableSimulation() -> Bool {
        return resetLocation("\(self.udid)", self.lookupOps)
    }
}

extension IOSDevice: Equatable {
    /// We consider a device to be equal if the udid is the same.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.udid == rhs.udid
    }
}
