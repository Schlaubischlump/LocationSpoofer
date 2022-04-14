//
//  File.swift
//  
//
//  Created by David Klopp on 04.04.22.
//

import Foundation
import CoreLocation

// Configuration for automatic moving when standing still in manual mode
fileprivate let kGpsUncertaintyTimeInterval: Range<TimeInterval> = 5.0..<15.0
fileprivate let kGpsUncertaintyHeadingInterval: Range<CLLocationDegrees>  = 0.0..<360.0
fileprivate let kGpsUncertaintyDistanceInterval: Range<CLLocationDistance> = 5.0..<10.0

// The default lower bound update interval
fileprivate let kAutoUpdateInterval: Double = 0.25


public enum MoveState {
    case manual
    case auto
    case navigation(route: NavigationRoute)

    /// The name of the move state without the associated values.
    public var caseName: String {
        return Mirror(reflecting: self).children.first?.label ?? String(describing: self)
    }

    /// True if an initial location is required to start the auto update. False otherwise.
    internal var requiresInitialLocationForAutoUpdate: Bool {
        if case .navigation = self {
            return false
        }
        return true
    }

    /// Calculate the next update interval used to perform the auto update operation. This is a mimimum value. If the
    /// devices responds slower a longer time will be used.
    /// - Parameter previousInterval: The previous update interval
    /// - Return: The next update interval
    internal func getNextAutoUpdateInterval(previousInterval: TimeInterval? = nil) -> TimeInterval {
        switch self {
        case .manual:
            return TimeInterval.random(in: kGpsUncertaintyTimeInterval)
        default:
            return previousInterval ?? kAutoUpdateInterval
        }
    }

    /// Calculate the next location to go to.
    /// - Parameter distance: The distance to move
    /// - Parameter heading: The current heading
    /// - Parameter previousLocation: The previous location from which we move away
    /// - Parameter isAutoUpdate: True if the next location is request via an autoUpdate, False otherwise
    /// - Return: The new coordinates to move to
    internal mutating func getNextLocation(distance: CLLocationDistance,
                                           heading: CLLocationDegrees?,
                                           previousLocation: CLLocationCoordinate2D?,
                                           isAutoUpdate: Bool) -> CLLocationCoordinate2D? {
        switch self {
        case .navigation(var route):
            // We assume that we always start at the first route coordinate
            if route.isAtStart {
                let startCoord = route.get()

                // We need to navigate to startCoord before we can start the actual navigation.
                if (previousLocation == nil || previousLocation != startCoord) {
                    return startCoord
                }

                // We are already at the start position. Move on to the next waypoint.
                route.next()
                self = .navigation(route: route)
            }
            
            // We got an empty route
            guard let coord = route.get() else {
                return nil
            }

            // We have no previous location... This should never be the case if we got an active navigation.
            guard let previousLocation = previousLocation else {
                fatalError("Unexpect error! No previous location found for navigation.")
            }

            // If we want to move to the location we are already at => Skip to the next waypoint
            guard previousLocation != coord else {
                route.next()
                self = .navigation(route: route)
                return coord
            }

            // Calculate the next location we move to
            let heading = previousLocation.heading(toLocation: coord)
            let nextLocation = previousLocation.location(inDistance: distance, heading: heading)

            // Snap into place if we are close enough to a waypoint
            if nextLocation.distanceTo(coordinate: coord) <= distance {
                route.next()
                // Update the associated value
                self = .navigation(route: route)
                return coord
            }

            return nextLocation
        case .manual:
            if isAutoUpdate {
                // Interactive state has a special role. We want to simulate GPS uncertainty if we do not move.
                let distance = CLLocationDistance.random(in: kGpsUncertaintyDistanceInterval)
                let heading = CLLocationDegrees.random(in: kGpsUncertaintyHeadingInterval)
                return previousLocation?.location(inDistance: distance, heading: heading)
            }
            fallthrough
        default:
            return previousLocation?.location(inDistance: distance, heading: heading ?? 0)
        }
    }
}

extension MoveState: Equatable {
    public static func == (lhs: MoveState, rhs: MoveState) -> Bool {
        switch (lhs, rhs) {
        case (.manual, .manual):
            return true
        case (.auto, .auto):
            return true
        case (.navigation(let lhsRoute), .navigation(let rhsRoute)):
            return lhsRoute == rhsRoute
        default:
            return false
        }
    }
}
