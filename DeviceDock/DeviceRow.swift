import SwiftUI

struct DeviceRow: View {
    let device: Device
    let store: DeviceStore

    private var statusColor: Color {
        switch device.state {
        case .shutdown: .gray
        case .booting: .orange
        case .booted: .green
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
                .accessibilityLabel(device.state == .booted ? "Running" : device.state == .booting ? "Booting" : "Stopped")
            Text(device.name)
                .lineLimit(2)
                .help(device.name)
            Spacer(minLength: 4)
            switch device.state {
            case .shutdown:
                Button("Open") { Task { await store.open(device) } }
            case .booting:
                ProgressView().controlSize(.mini)
                Text("Booting…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .booted:
                if device.platform == .iOS {
                    Button("Show") { Task { await store.show(device) } }
                        .help("Show this simulator")
                }
                Button("Stop") { Task { await store.stop(device) } }
            }
        }
        .buttonStyle(.borderless)
        .padding(.vertical, 5)
    }
}
