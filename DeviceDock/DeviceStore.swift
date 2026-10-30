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
            devices = try await Simctl.listDevices()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func open(_ device: Device) async {
        do {
            try await Simctl.boot(device.id)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func stop(_ device: Device) async {
        do {
            try await Simctl.shutdown(device.id)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
