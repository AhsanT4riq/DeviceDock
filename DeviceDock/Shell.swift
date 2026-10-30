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
    static func run(_ executable: String, _ arguments: [String] = [], timeoutSeconds: Double? = nil) async throws -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        try process.run()
        if let timeoutSeconds {
            // For commands that can wait indefinitely; terminating them ends the read below.
            DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSeconds) {
                if process.isRunning { process.terminate() }
            }
        }
        let data = try pipe.fileHandleForReading.readToEnd() ?? Data()
        process.waitUntilExit()
        
        return ShellResult(output: String(decoding: data, as: UTF8.self), exitCode: process.terminationStatus)
    }
}

nonisolated struct CommandError: LocalizedError {
    let command: String
    let exitCode: Int32

    var errorDescription: String? {
        "\(command) failed (exit \(exitCode))."
    }
}

extension Shell {
    @concurrent
    static func checked(_ executable: String, _ arguments: [String] = []) async throws -> ShellResult {
        let result = try await run(executable, arguments)
        guard result.exitCode == 0 else {
            throw CommandError(command: URL(fileURLWithPath: executable).lastPathComponent, exitCode: result.exitCode)
        }
        return result
    }
}
