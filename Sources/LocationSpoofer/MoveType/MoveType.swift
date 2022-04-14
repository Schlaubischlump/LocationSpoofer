//
//  File.swift
//  
//
//  Created by David Klopp on 04.04.22.
//

import Foundation
import CoreLocation

public enum MoveType: Int, CaseIterable {
    case walk = 0
    case cycle
    case drive

    /// Speed in meters per second
    public var speed: CLLocationSpeed {
        switch self {
        case .walk:
            return 1.39 // 5km/h
        case .cycle:
            return 4.167  // 15km/h
        case .drive:
            return 11.112 // 40km/h
        }
    }
}
