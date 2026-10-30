//
//  DeviceDockApp.swift
//  DeviceDock
//
//  Created by Ahsan Tariq on 30/10/2026.
//

import SwiftUI

@main
struct DeviceDockApp: App {
    var body: some Scene {
        MenuBarExtra("DeviceDock", systemImage: "iphone") {
            ForEach(Device.samples) {
                device in Button("\(device.name) - \(device.osVersion)") {
                    print("Open \(device.name)")
                }
            }
            Divider()
            Button("Test Shell") {
                Task {
                    do {
                        let result = try await Shell.run("/usr/bin/xcrun", ["simctl", "list", "devices", "available", "-j"])
                        print("exit:", result.exitCode)
                        print(result.output.prefix(300))
                    } catch {
                        print("Shell failed:", error)
                    }
                }
            }
            Button("Quit DeviceDock") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
