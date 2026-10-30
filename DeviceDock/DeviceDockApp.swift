import SwiftUI

@main
struct DeviceDockApp: App {
    @State private var store = DeviceStore()

    var body: some Scene {
        MenuBarExtra("DeviceDock", systemImage: "iphone") {
            MenuContentView(store: store)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(store: store)
        }
    }
}
