import Foundation
import Observation

nonisolated struct DeviceLoadResult: Sendable {
    var devices: [Device]?
    var error: String?

    @concurrent
    static func load(_ platform: Platform) async -> DeviceLoadResult {
        do {
            let devices: [Device]
            if platform == .iOS {
                devices = try await Simctl.listDevices()
            } else {
                devices = try await Android.listDevices()
            }
            return DeviceLoadResult(devices: devices)
        } catch {
            return DeviceLoadResult(error: error.localizedDescription)
        }
    }
}

@Observable
final class DeviceStore {
    private(set) var devices: [Device] = []
    private(set) var isRefreshing = false
    private(set) var hasLoaded = false
    private(set) var androidSDKAvailable = false
    private(set) var iosError: String?
    private(set) var androidError: String?
    private var actionError: String?
    private var pendingBoots: Set<String> = []
    private var bootCommands: Set<String> = []
    @ObservationIgnored private var refreshTask: Task<Void, Never>?

    var errorMessage: String? {
        let messages = [iosError.map { "iOS: \($0)" }, androidError.map { "Android: \($0)" }, actionError].compactMap { $0 }
        return messages.isEmpty ? nil : messages.joined(separator: "\n")
    }

    var devicesByRuntime: [(runtime: String, devices: [Device])] {
        Dictionary(grouping: devices.filter { $0.platform == .iOS }, by: \.osVersion)
            .map { (runtime: $0.key, devices: $0.value.sorted { (Self.rank($0.state), $0.name) < (Self.rank($1.state), $1.name) }) }
            .sorted { $0.runtime.localizedStandardCompare($1.runtime) == .orderedDescending }
    }

    var androidDevices: [Device] {
        devices.filter { $0.platform == .android }.sorted { (Self.rank($0.state), $0.name) < (Self.rank($1.state), $1.name) }
    }
    
    // Running first, then booting, then stopped.
    private static func rank(_ state: Device.State) -> Int {
        switch state {
        case .booted: 0
        case .booting: 1
        case .shutdown: 2
        }
    }

    init() {
        // Refresh for the app's lifetime, including before the panel is first opened.
        Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                do { try await Task.sleep(for: .seconds(8)) } catch { return }
                guard self != nil else { return }
            }
        }
    }

    func refresh() async {
        if let refreshTask {
            await refreshTask.value
            return
        }
        isRefreshing = true
        let task = Task {
            async let ios = DeviceLoadResult.load(.iOS)
            async let android = DeviceLoadResult.load(.android)
            let (iosResult, androidResult) = await (ios, android)
            apply(iosResult, platform: .iOS)
            apply(androidResult, platform: .android)
            iosError = iosResult.error
            androidError = androidResult.error
            androidSDKAvailable = Android.sdkPath() != nil
            hasLoaded = true
        }
        refreshTask = task
        await task.value
        refreshTask = nil
        isRefreshing = false
    }

    private func apply(_ result: DeviceLoadResult, platform: Platform) {
        guard let loaded = result.devices else { return }
        let merged = loaded.map { device in
            var device = device
            if pendingBoots.contains(device.id) {
                if device.state == .booted && !bootCommands.contains(device.id) {
                    pendingBoots.remove(device.id)
                } else {
                    // A refresh can observe shutdown before the boot command takes effect.
                    device.state = .booting
                }
            }
            return device
        }
        devices = devices.filter { $0.platform != platform } + merged
    }

    func open(_ device: Device) async {
        guard let current = devices.first(where: { $0.id == device.id }), current.state == .shutdown else { return }
        pendingBoots.insert(device.id)
        bootCommands.insert(device.id)
        setState(.booting, for: device.id)
        actionError = nil
        do {
            if device.platform == .iOS {
                try await Simctl.boot(device.id)
            } else {
                try await Android.start(avd: device.id)
            }
            bootCommands.remove(device.id)
            for _ in 0..<30 {
                await refresh()
                if !pendingBoots.contains(device.id) { return }
                try await Task.sleep(for: .seconds(2))
            }
            actionError = "\(device.name) is taking longer than expected to boot. Refresh to check its status."
        } catch {
            actionError = "\(device.name): \(error.localizedDescription)"
        }
        bootCommands.remove(device.id)
        pendingBoots.remove(device.id)
        setState(.shutdown, for: device.id)
        await refresh()
    }

    func show(_ device: Device) async {
        do {
            try await Simctl.show(device.id)
        } catch {
            actionError = "\(device.name): \(error.localizedDescription)"
        }
    }

    func stop(_ device: Device) async {
        actionError = nil
        do {
            if device.platform == .iOS {
                try await Simctl.shutdown(device.id)
            } else {
                try await Android.stop(avd: device.id)
            }
            await refresh()
        } catch {
            actionError = "\(device.name): \(error.localizedDescription)"
        }
    }

    private func setState(_ state: Device.State, for id: String) {
        guard let index = devices.firstIndex(where: { $0.id == id }) else { return }
        devices[index].state = state
    }
}
