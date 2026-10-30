import SwiftUI

struct SettingsView: View {
    let store: DeviceStore
    @AppStorage(Android.sdkPathKey) private var sdkPath = ""

    var body: some View {
        Form {
            TextField("Android SDK path", text: $sdkPath, prompt: Text("/path/to/Android/sdk"))
            Text("Leave empty to use ANDROID_HOME, ANDROID_SDK_ROOT, or ~/Library/Android/sdk. The folder must contain emulator/emulator.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Use default") { sdkPath = "" }
                .disabled(sdkPath.isEmpty)
        }
        .padding(20)
        .frame(width: 440)
        .onDisappear { Task { await store.refresh() } }
    }
}
