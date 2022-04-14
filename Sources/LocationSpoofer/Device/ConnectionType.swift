//
//  ConnectionType.swift
//  LocationSimulator2
//
//  Created by David Klopp on 24.09.20.
//
#if SWIFT_PACKAGE
import CMobileDevice
#endif


import Foundation

/// The current connection type for a specific device.
public struct ConnectionType: OptionSet, Hashable, CustomStringConvertible, Codable {
    public let rawValue: Int
   
    public static let unknown = ConnectionType(rawValue: 1 << 0)
    public static let usb     = ConnectionType(rawValue: 1 << 1)
    public static let network = ConnectionType(rawValue: 1 << 2)

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// A human readable string for this connection type.
    public var description: String {
        let options: [ConnectionType: String] = [.usb: "usb", .network: "network", .unknown: "unknown"]
        let optionArr: [String] = options.keys.compactMap { self.contains($0) ? options[$0] : nil }
        return optionArr.joined(separator: ", ")
    }

    /// The  lookup operations to use for this connection type.
    public var lookupOps: idevice_options {
        // If the device is only connected via USB, use only the USB connection.
        // If the device is only connected via network, use only the network connection.
        // In all other cases use both.
        switch self {
        case .network: return IDEVICE_LOOKUP_NETWORK
        case .usb:     return IDEVICE_LOOKUP_USBMUX
        default:       return idevice_options(IDEVICE_LOOKUP_NETWORK.rawValue | IDEVICE_LOOKUP_USBMUX.rawValue)
        }
    }
}
