//
//  CommandRunner.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 22.05.2026.
//

import Foundation

struct CommandResult {
    let statusCode: Int32
    let stdout: String
    let stderr: String
}

enum CommandRunner {
    static func run(executablePath: String, arguments: [String]) async throws -> CommandResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let outputPipe = Pipe()
                let errorPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: executablePath)
                process.arguments = arguments
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                process.terminationHandler = { process in
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                    let stdout = String(data: outputData, encoding: .utf8) ?? ""
                    let stderr = String(data: errorData, encoding: .utf8) ?? ""
                    let statusCode = process.terminationStatus

                    if statusCode == 0 {
                        continuation.resume(returning: CommandResult(
                            statusCode: statusCode,
                            stdout: stdout,
                            stderr: stderr
                        ))
                    } else {
                        let message = [stderr, stdout]
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { $0.isEmpty == false }
                            .joined(separator: "\n")

                        continuation.resume(throwing: SimulatorOpenError.commandFailed(
                            statusCode: statusCode,
                            message: message.isEmpty ? "Проверь, что Xcode установлен и симулятор запущен." : message
                        ))
                    }
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


