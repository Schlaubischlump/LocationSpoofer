//
//  File.swift
//  
//
//  Created by David Klopp on 05.04.22.
//

import Foundation

typealias TimeStamp = UInt64

extension TimeStamp {
    static func now() -> UInt64 {
        return DispatchTime.now().uptimeNanoseconds
    }

    static func seconds(since: UInt64) -> TimeInterval {
        return TimeInterval(DispatchTime.now().uptimeNanoseconds - since) / 1000000000
    }
}
