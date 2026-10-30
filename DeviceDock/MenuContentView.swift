import SwiftUI

struct MenuContentView: View {
    let store: DeviceStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("DeviceDock").font(.headline)
                Spacer()
                Button {
                    Task { await store.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .keyboardShortcut("r")
                .disabled(store.isRefreshing)
                .help("Refresh")
                .accessibilityLabel("Refresh")
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                } label: {
                    Image(systemName: "gear")
                }
                .help("Settings")
                .accessibilityLabel("Settings")
            }
            .buttonStyle(.borderless)
            .padding(12)

            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !store.hasLoaded {
                        ProgressView("Loading devices…").controlSize(.small)
                    } else {
                        if store.devicesByRuntime.isEmpty {
                            deviceSection("iOS", devices: [], emptyMessage: store.iosError == nil ? "No iOS simulators found" : "Unable to load iOS simulators")
                        }
                        ForEach(store.devicesByRuntime, id: \.runtime) { group in
                            deviceSection(group.runtime, devices: group.devices)
                        }
                        deviceSection("Android", devices: store.androidDevices, emptyMessage: androidMessage)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            }
            .frame(maxHeight: 480)
            .fixedSize(horizontal: false, vertical: true)

            Divider()
            VStack(alignment: .leading, spacing: 8) {
                if let error = store.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
                HStack {
                    Spacer()
                    Button("Quit DeviceDock") { NSApp.terminate(nil) }
                        .keyboardShortcut("q")
                        .buttonStyle(.borderless)
                }
            }
            .padding(12)
        }
        .frame(width: 320)
        .task { await store.refresh() }
    }

    private var androidMessage: String {
        if store.androidError != nil { return "Unable to load Android emulators" }
        return store.androidSDKAvailable ? "No Android emulators (AVDs) found" : "Android SDK not found"
    }

    private func deviceSection(_ title: String, devices: [Device], emptyMessage: String = "") -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if devices.isEmpty {
                Text(emptyMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(devices) { device in
                DeviceRow(device: device, store: store)
            }
        }
    }
}
