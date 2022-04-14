//
//  File.swift
//  
//
//  Created by David Klopp on 06.04.22.
//
#if canImport(MapKit)
import MapKit

public extension MoveType {
    var transportType: MKDirectionsTransportType {
        return (self == .drive) ? .automobile : .walking
    }
}

#endif
