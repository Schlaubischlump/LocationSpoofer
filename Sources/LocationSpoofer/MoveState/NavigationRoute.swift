//
//  File.swift
//  
//
//  Created by David Klopp on 06.04.22.
//

import Foundation
import CoreLocation

public struct NavigationRoute {
    /// All the waypoints already traveled to
    public var traveledCoordinates: ArraySlice<CLLocationCoordinate2D> {
        return self.coordinates[..<self.currentRouteIndex]
    }

    /// All the upcoming waypoints
    public var upcomingCoordinates: ArraySlice<CLLocationCoordinate2D> {
        return self.coordinates[self.currentRouteIndex...]
    }

    public private(set) var coordinates: [CLLocationCoordinate2D]

    fileprivate var currentRouteIndex: Int = -1

    /// True if the start of the route is reached.
    public var isAtStart: Bool {
        return self.currentRouteIndex <= 0
    }

    /// True if the end of the route is reached, False otherwise.
    public var isFinished: Bool {
        return self.currentRouteIndex >= self.coordinates.count
    }

    public init(_ route: [CLLocationCoordinate2D]) {
        self.coordinates = route
        self.currentRouteIndex = self.coordinates.isEmpty ? -1 : 0
    }

    internal func get() -> CLLocationCoordinate2D? {
        if self.currentRouteIndex >= 0 && self.currentRouteIndex < self.coordinates.count {
            return self.coordinates[self.currentRouteIndex]
        }
        return nil
    }

    @discardableResult
    internal mutating func next() -> Bool {
        if self.isFinished {
            return false
        }
        self.currentRouteIndex += 1
        return true
    }

    @discardableResult
    internal mutating func previous() -> Bool {
        if self.currentRouteIndex - 1 < 0 {
            return false
        }
        self.currentRouteIndex -= 1
        return true
    }
}

extension NavigationRoute: Equatable {
    public static func ==(lhs: NavigationRoute, rhs: NavigationRoute) -> Bool {
        // Two routes are equal if they share the same coordinates. It does not matter if we start from the beginning
        // or the end.
        return lhs.coordinates.count == rhs.coordinates.count
            && (lhs.coordinates == rhs.coordinates || lhs.coordinates == rhs.coordinates.reversed())
    }
}
