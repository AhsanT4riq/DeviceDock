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
                        if device.state == .booted {
                            Menu("● \(device.name)"){
                                Button("Show") {Task {await store.open(device)}}
                                Button("Stop") {Task {await store.stop(device)}}
                            }
                        } else {
                            Button(device.name){
                                Task {await store.open(device)}
                            }
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
