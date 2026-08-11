//
//  CommandRunner.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 22.05.2026.
//

import Foundation

struct CommandResult: Sendable {
    let statusCode: Int32
    let stdout: String
    let stderr: String
}

protocol CommandRunning: Sendable {
    func run(executableURL: URL, arguments: [String]) async throws -> CommandResult
}

struct ProcessCommandRunner: CommandRunning {
    func run(executableURL: URL, arguments: [String]) async throws -> CommandResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let outputPipe = Pipe()
                let errorPipe = Pipe()

                process.executableURL = executableURL
                process.arguments = arguments
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                process.terminationHandler = { process in
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                    let stdout = String(data: outputData, encoding: .utf8) ?? ""
                    let stderr = String(data: errorData, encoding: .utf8) ?? ""
                    let statusCode = process.terminationStatus

                    continuation.resume(returning: CommandResult(
                        statusCode: statusCode,
                        stdout: stdout,
                        stderr: stderr
                    ))
                }

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
