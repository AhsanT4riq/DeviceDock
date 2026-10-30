//
//  DeviceStore.swift
//  DeviceDock
//
//  Created by Ahsan Tariq on 30/10/2026.
//

import Foundation
import Observation

@Observable
final class DeviceStore {
    var devices: [Device] = []
    var errorMessage: String?
    var devicesByRuntime: [(runtime: String, devices: [Device])] {
        Dictionary(grouping: devices, by: \.osVersion)
            .map { (runtime: $0.key, devices: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.runtime.localizedStandardCompare($1.runtime) == .orderedDescending }
    }
    
    func refresh() async {
        do {
            async let ios = Simctl.listDevices()
            async let android = Android.listDevices()
            devices = try await ios + android
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func open(_ device: Device) async {
        do {
            if device.platform == .iOS {
                try await Simctl.boot(device.id)
            } else {
                try Android.start(avd: device.id)
            }
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func stop(_ device: Device) async {
        do {
            if device.platform == .iOS {
                try await Simctl.shutdown(device.id)
            } else {
                try await Android.stop(avd: device.id)
            }
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
