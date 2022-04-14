//
//  File.swift
//  
//
//  Created by David Klopp on 05.04.22.
//

import Foundation

public enum LocationSpooferError: Error {
    case queueIsBusy(_ message: String)
    case interactionNotPossible(_ message: String)
}

