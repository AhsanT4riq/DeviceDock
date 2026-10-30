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
        let result = try await Shell.checked("/usr/bin/xcrun", ["simctl", "list", "devices", "available", "-j"])
        let list = try JSONDecoder().decode(SimctlList.self, from: Data(result.output.utf8))
        
        var devices: [Device] = []
        for (runtime, simDevices) in list.devices where runtime.contains(".iOS-") {
            for sim in simDevices {
                let state: Device.State
                switch sim.state {
                case "Booted": state = .booted
                case "Booting": state = .booting
                default: state = .shutdown
                }
                devices.append(Device(id: sim.udid, name: sim.name, platform: .iOS, osVersion: osVersion(from: runtime), state: state))
            }
        }
        return devices
    }
    
    @concurrent
    static func boot(_ udid: String) async throws {
        _ = try await Shell.checked("/usr/bin/xcrun", ["simctl", "boot", udid])
        _ = try await Shell.checked("/usr/bin/open", ["-b", "com.apple.dt.Devices"])
    }
    
    @concurrent
    static func shutdown(_ udid: String) async throws {
        _ = try await Shell.checked("/usr/bin/xcrun", ["simctl", "shutdown", udid])
    }
}
