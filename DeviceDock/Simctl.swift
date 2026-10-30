//
//  Simctl.swift
//  DeviceDock
//
//  Created by Ahsan Tariq on 30/10/2026.
//

import Foundation

nonisolated struct SimctlList: Decodable {
    let devices: [String: [SimctlDevice]]
}

nonisolated struct SimctlDevice: Decodable {
    let udid: String
    let name: String
    let state: String
}

nonisolated enum Simctl {
    // com.apple.CoreSimulator.SimRuntime.iOS-27-0 -> iOS 27.0
    static func osVersion(from runtime: String) -> String {
        let last = runtime.split(separator: ".").last ?? ""
        let parts = last.split(separator: "-")
        guard let name = parts.first else {return runtime}
        return "\(name) \(parts.dropFirst().joined(separator:"."))"
    }
    
    @concurrent
    static func listDevices() async throws -> [Device] {
        let result = try await Shell.run("/usr/bin/xcrun", ["simctl", "list", "devices", "available", "-j"])
        let list = try JSONDecoder().decode(SimctlList.self, from: Data(result.output.utf8))
        
        var devices: [Device] = []
        for (runtime, simDevices) in list.devices where runtime.contains(".iOS-") {
            for sim in simDevices {
                devices.append(Device(id: sim.udid, name: sim.name, platform: .iOS, osVersion: osVersion(from: runtime), state: sim.state == "Booted" ? .booted : .shutdown))
            }
        }
        return devices
    }
}
