//
//  Android.swift
//  DeviceDock
//
//  Created by Ahsan Tariq on 30/10/2026.
//

import Foundation

nonisolated enum Android {
    static let sdkPathKey = "androidSDKPath"

    static func sdkPath() -> String? {
        let env = ProcessInfo.processInfo.environment
        let candidates = [
            UserDefaults.standard.string(forKey: sdkPathKey),
            env["ANDROID_HOME"],
            env["ANDROID_SDK_ROOT"],
            NSHomeDirectory() + "/Library/Android/sdk",
        ]
        return candidates
            .compactMap { $0 }
            .map { ($0.trimmingCharacters(in: .whitespacesAndNewlines) as NSString).expandingTildeInPath }
            .filter { !$0.isEmpty }
            .first { FileManager.default.fileExists(atPath: $0 + "/emulator/emulator") }
    }
    
    @concurrent
    static func avdNames(sdk: String) async throws -> [String] {
        let result = try await Shell.checked(sdk + "/emulator/emulator", ["-list-avds"])
        return result.output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
    
    // AVD name -> adb serial (e.g. "Bunnings_Pixel_8_API_35" -> "emulator-5554")
    @concurrent
    static func runningEmulators(sdk: String) async throws -> [String: String] {
        let adb = sdk + "/platform-tools/adb"
        let list = try await Shell.checked(adb, ["devices"])

        var running: [String: String] = [:]
        for line in list.output.split(whereSeparator: \.isNewline) where line.hasPrefix("emulator-") {
            guard let serial = line.split(whereSeparator: \.isWhitespace).first else { continue }
            let reply = try await Shell.checked(adb, ["-s", String(serial), "emu", "avd", "name"])
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
        guard !names.isEmpty else { return [] }
        let running = try await runningEmulators(sdk: sdk)

        var devices: [Device] = []
        for name in names {
            var state: Device.State = .shutdown
            if let serial = running[name] {
                let result = try? await Shell.checked(sdk + "/platform-tools/adb", ["-s", serial, "shell", "getprop", "sys.boot_completed"])
                let bootCompleted = result?.output.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
                state = bootCompleted ? .booted : .booting
            }
            devices.append(Device(
                id: name,
                name: name.replacingOccurrences(of: "_", with: " "),
                platform: .android,
                osVersion: "Android",
                state: state
            ))
        }
        return devices
    }
    
    @concurrent
    static func start(avd: String) async throws {
        guard let sdk = sdkPath() else { throw SDKNotFound() }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: sdk + "/emulator/emulator")
        process.arguments = ["-avd", avd]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }
    
    @concurrent
    static func stop(avd: String) async throws {
        guard let sdk = sdkPath() else { throw SDKNotFound() }
        let running = try await runningEmulators(sdk: sdk)
        guard let serial = running[avd] else {return}
        _ = try await Shell.checked(sdk + "/platform-tools/adb", ["-s", serial, "emu", "kill"])
    }
}

nonisolated struct SDKNotFound: LocalizedError {
    var errorDescription: String? { "Android SDK not found" }
}
