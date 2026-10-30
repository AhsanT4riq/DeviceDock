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

extension Device {
    static let samples: [Device] = [
        Device(id: "fake-ios-1", name: "iPhone 18 Pro", platform: .iOS, osVersion: "iOS 27.0", state: .booted),
        Device(id: "fake-ios-2", name: "iPhone 18 Pro Max", platform: .iOS, osVersion: "iOS 27.0", state: .shutdown),
        Device(id: "fake-android-1", name: "Bunnings_Pixel_8_API_35", platform: .android, osVersion: "API 35", state: .shutdown),
    ]
}
