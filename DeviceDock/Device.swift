//
//  Device.swift
//  DeviceDock
//
//  Created by Ahsan Tariq on 30/10/2026.
//

import Foundation

nonisolated enum Platform: String, Hashable {
    case iOS
    case android
}

nonisolated struct Device: Identifiable, Hashable {
    enum State: Hashable {
        case shutdown
        case booting
        case booted
    }
    
    let id: String
    let name: String
    let platform: Platform
    let osVersion: String
    var state: State
}
