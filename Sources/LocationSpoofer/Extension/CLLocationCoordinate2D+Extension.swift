//
//  CLLocationCoordinate2D+Extension.swift
//  LocationSimulator
//
//  Created by David Klopp on 18.08.19.
//  Copyright © 2019 David Klopp. All rights reserved.
//

import Foundation
import CoreLocation
import MapKit

fileprivate extension FloatingPoint {
    /// Convert degrees to radians
    var degreesToRadians: Self { return self * .pi / 180 }
    /// Convert radians to degrees
    var radiansToDegrees: Self { return self * 180 / .pi }
}

extension CLLocationCoordinate2D {
    /// Calculate the new location based on the current heading and distance.
    /// - Parameter distance: distance to move in meters
    /// - Parameter heading: direction to move in
    /// - Return: new location
    internal func location(inDistance distance: CLLocationDistance,
                           heading: CLLocationDegrees) -> CLLocationCoordinate2D {
        // move into the direction of heading
        let latitude = self.latitude
        let longitude = self.longitude

        let earthCircle = 2 * .pi * 6371000.0

        let latDistance = distance * cos(heading * .pi / 180)
        let latPerMeter = 360 / earthCircle
        let latDelta = latDistance * latPerMeter
        let newLat = latitude + latDelta

        let lngDistance = distance * sin(heading * .pi / 180)
        let earthRadiusAtLng = 6371000.0 * cos(newLat * .pi / 180)
        let earthCircleAtLng = 2 * .pi * earthRadiusAtLng
        let lngPerMeter = 360 / earthCircleAtLng
        let lngDelta = lngDistance * lngPerMeter
        let newLng = longitude + lngDelta

        return CLLocationCoordinate2D(latitude: newLat, longitude: newLng)
    }

    /// Calculate the distance from this location to the given one.
    /// - Parameter coordinate: coordinate to which the distance should be calculated to
    /// - Return: distance between the two locations
    internal func distanceTo(coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        let thisLocation = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let otherLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return thisLocation.distance(from: otherLocation)
    }

    /// Calculate the heading from this location to the target location in degrees
    /// See: https://stackoverflow.com/questions/6924742/valid-way-to-calculate-angle-between-2-cllocations
    /// - Parameter to: target location
    /// - Return: heading in degrees
    internal func heading(toLocation: CLLocationCoordinate2D) -> CLLocationDegrees {
        let lat1 = self.latitude.degreesToRadians
        let lon1 = self.longitude.degreesToRadians

        let lat2 = toLocation.latitude.degreesToRadians
        let lon2 = toLocation.longitude.degreesToRadians

        let dLon = lon2 - lon1
        let yVal = sin(dLon) * cos(lat2)
        let xVal = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        let headingDegrees = atan2(yVal, xVal).radiansToDegrees
        return headingDegrees >= 0 ? headingDegrees : headingDegrees + 360
    }
}

extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.distanceTo(coordinate: rhs) <= 0.0005
        //return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
