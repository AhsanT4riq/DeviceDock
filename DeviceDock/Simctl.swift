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
    
    // Brings the simulator window forward. Xcode 27+ shows simulators in DeviceHub, where a
    // devices:// link selects the device; earlier Xcode versions use Simulator.app.
    @concurrent
    static func show(_ udid: String) async throws {
        if (try? await Shell.checked("/usr/bin/open", ["devices://device/open?id=\(udid)"])) != nil { return }
        if (try? await Shell.checked("/usr/bin/open", ["-b", "com.apple.dt.Devices"])) != nil { return }
        _ = try await Shell.checked("/usr/bin/open", ["-a", "Simulator"])
    }

    @concurrent
    static func boot(_ udid: String) async throws {
        _ = try await Shell.checked("/usr/bin/xcrun", ["simctl", "boot", udid])
        // simctl reports "Booted" as soon as the kernel is up; bootstatus waits until iOS has
        // finished starting (first boots can take 20s+). It never returns if the device is
        // stopped meanwhile, hence the timeout.
        _ = try? await Shell.run("/usr/bin/xcrun", ["simctl", "bootstatus", udid], timeoutSeconds: 180)
        // The device is booting even if no window can be shown, so that doesn't fail the boot.
        try? await show(udid)
    }
    
    @concurrent
    static func shutdown(_ udid: String) async throws {
        _ = try await Shell.checked("/usr/bin/xcrun", ["simctl", "shutdown", udid])
    }
}
