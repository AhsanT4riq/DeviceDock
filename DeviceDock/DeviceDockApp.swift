//
//  DeviceDockApp.swift
//  DeviceDock
//
//  Created by Ahsan Tariq on 30/10/2026.
//

import SwiftUI

@main
struct DeviceDockApp: App {
    @State private var store = DeviceStore()
    var body: some Scene {
        MenuBarExtra("DeviceDock", systemImage: "iphone") {
            ForEach(store.devicesByRuntime, id: \.runtime) { group in
                Section(group.runtime) {
                    ForEach(group.devices) { device in
                        Button(device.name){
                            print("Open \(device.name)")
                        }
                    }
                }
            }
            Divider()
            Button("Refresh") {
                Task { await store.refresh() }
            }
            .keyboardShortcut("r")
            Button("Quit DeviceDock") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
