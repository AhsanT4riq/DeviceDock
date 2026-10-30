//
//  Android.swift
//  DeviceDock
//
//  Created by Ahsan Tariq on 30/10/2026.
//

import Foundation

nonisolated enum Android {
    static func sdkPath() -> String? {
        let env = ProcessInfo.processInfo.environment
        let candidates = [
            env["ANDROID_HOME"],
            env["ANDROID_SDK_ROOT"],
            NSHomeDirectory() + "/Library/Android/sdk",
        ]
        return candidates
            .compactMap { $0 }
            .first { FileManager.default.fileExists(atPath: $0 + "/emulator/emulator") }
    }
    
    @concurrent
    static func avdNames(sdk: String) async throws -> [String] {
        let result = try await Shell.run(sdk + "/emulator/emulator", ["-list-avds"])
        return result.output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
    
    // AVD name -> adb serial (e.g. "Bunnings_Pixel_8_API_35" -> "emulator-5554")
    @concurrent
    static func runningEmulators(sdk: String) async throws -> [String: String] {
        let adb = sdk + "/platform-tools/adb"
        let list = try await Shell.run(adb, ["devices"])

        var running: [String: String] = [:]
        for line in list.output.split(whereSeparator: \.isNewline) where line.hasPrefix("emulator-") {
            guard let serial = line.split(whereSeparator: \.isWhitespace).first else { continue }
            let reply = try await Shell.run(adb, ["-s", String(serial), "emu", "avd", "name"])
            if let name = reply.output.split(whereSeparator: \.isNewline).first {
                running[name.trimmingCharacters(in: .whitespacesAndNewlines)] = String(serial)
            }
        }
        return running
    }
    
    @concurrent
    static func listDevices() async throws -> [Device] {
        guard let sdk = sdkPath() else { return [] }
        let names = try await avdNames(sdk: sdk)
        let running = try await runningEmulators(sdk: sdk)

        return names.map { name in
            Device(
                id: name,
                name: name.replacingOccurrences(of: "_", with: " "),
                platform: .android,
                osVersion: "Android",
                state: running[name] != nil ? .booted : .shutdown
            )
        }
    }
    
    static func start(avd: String) throws {
        guard let sdk = sdkPath() else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: sdk + "/emulator/emulator")
        process.arguments = ["-avd", avd]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }
    
    @concurrent
    static func stop(avd: String) async throws {
        guard let sdk = sdkPath() else { return }
        let running = try await runningEmulators(sdk: sdk)
        guard let serial = running[avd] else {return}
        _ = try await Shell.run(sdk + "/platform-tools/adb", ["-s", serial, "emu", "kill"])
    }
}
