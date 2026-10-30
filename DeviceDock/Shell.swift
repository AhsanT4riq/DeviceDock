//
//  Shell.swift
//  DeviceDock
//
//  Created by Ahsan Tariq on 30/10/2026.
//

import Foundation

nonisolated struct ShellResult: Sendable {
    let output: String
    let exitCode: Int32
}

nonisolated enum Shell {
    @concurrent
    static func run(_ executable: String, _ arguments: [String] = []) async throws -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        try process.run()
        let data = try pipe.fileHandleForReading.readToEnd() ?? Data()
        process.waitUntilExit()
        
        return ShellResult(output: String(decoding: data, as: UTF8.self), exitCode: process.terminationStatus)
    }
}
