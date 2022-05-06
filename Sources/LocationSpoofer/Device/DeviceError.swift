//
//  DeviceError.swift
//  LocationSimulator2
//
//  Created by David Klopp on 24.09.20.
//

import Foundation

/// Error messages while connecting to a device.
public enum DeviceError: Error, LocalizedError {
    case pair(_ message: String)
    case permisson(_ message: String)
    case devDiskImageNotFound(_ message: String)
    case devDiskImageMount(_ message: String)
    case productInfo(_ message: String)

    public var errorDescription: String? {
        switch self {
            case .pair(let message):                    return message
            case .permisson(let message):               return message
            case .devDiskImageNotFound(let message):    return message
            case .devDiskImageMount(let message):       return message
            case .productInfo(let message):             return message
        }
    }
}
