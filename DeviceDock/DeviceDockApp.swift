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
            Button("Quit DeviceDock") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
