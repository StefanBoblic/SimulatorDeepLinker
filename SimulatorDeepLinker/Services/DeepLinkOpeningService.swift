//
//  DeepLinkOpeningService.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 11.08.2026.
//

import Foundation

protocol DeepLinkOpening: Sendable {
    func open(
        urlString: String,
        on target: DeviceTarget,
        bundleIdentifier: String,
        androidPackage: String
    ) async throws -> String
}

enum DeepLinkOpeningError: LocalizedError {
    case invalidURL
    case executableNotFound(String)
    case bundleIdentifierRequired
    case commandFailed(tool: String, statusCode: Int32, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            String(localized: "Invalid URL. Add a scheme such as https:// or myapp://.")
        case let .executableNotFound(executable):
            String(
                format: String(localized: "%@ was not found. Check the developer tools installation."),
                executable
            )
        case .bundleIdentifierRequired:
            String(localized: "Enter the installed app's bundle identifier to open a link on a physical Apple device.")
        case let .commandFailed(tool, statusCode, message):
            String(
                format: String(localized: "%@ exited with code %d. %@"),
                tool,
                statusCode,
                message
            )
        }
    }
}

struct DeepLinkOpeningService: DeepLinkOpening {
    private let runner: any CommandRunning
    private let executables: any ExecutableLocating

    init(
        runner: any CommandRunning = ProcessCommandRunner(),
        executables: any ExecutableLocating = ExecutableLocator()
    ) {
        self.runner = runner
        self.executables = executables
    }

    func open(
        urlString: String,
        on target: DeviceTarget,
        bundleIdentifier: String,
        androidPackage: String
    ) async throws -> String {
        let normalizedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: normalizedURL), url.scheme?.isEmpty == false else {
            throw DeepLinkOpeningError.invalidURL
        }

        let tool: String
        let arguments: [String]

        switch target.platform {
        case .iOSSimulator:
            tool = "xcrun"
            arguments = ["simctl", "openurl", target.identifier, url.absoluteString]

        case .iOSDevice:
            let bundleIdentifier = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard bundleIdentifier.isEmpty == false else {
                throw DeepLinkOpeningError.bundleIdentifierRequired
            }
            tool = "xcrun"
            arguments = [
                "devicectl", "device", "process", "launch",
                "--device", target.identifier,
                bundleIdentifier,
                "--payload-url", url.absoluteString
            ]

        case .android:
            tool = "adb"
            var adbArguments = [
                "-s", target.identifier,
                "shell", "am", "start", "-W",
                "-a", "android.intent.action.VIEW",
                "-d", url.absoluteString
            ]
            let androidPackage = androidPackage.trimmingCharacters(in: .whitespacesAndNewlines)
            if androidPackage.isEmpty == false {
                adbArguments.append(androidPackage)
            }
            arguments = adbArguments
        }

        guard let executableURL = executables.locate(tool) else {
            throw DeepLinkOpeningError.executableNotFound(tool)
        }

        let result = try await runner.run(executableURL: executableURL, arguments: arguments)
        let output = [result.stderr, result.stdout]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: "\n")

        guard result.statusCode == 0 else {
            throw DeepLinkOpeningError.commandFailed(
                tool: tool,
                statusCode: result.statusCode,
                message: output.isEmpty ? String(localized: "No command output was returned.") : output
            )
        }

        return output
    }
}

protocol AndroidDeviceConnecting: Sendable {
    func pair(address: String, code: String) async throws -> String
    func connect(address: String) async throws -> String
}

struct AndroidDeviceConnectionService: AndroidDeviceConnecting {
    private let runner: any CommandRunning
    private let executables: any ExecutableLocating

    init(
        runner: any CommandRunning = ProcessCommandRunner(),
        executables: any ExecutableLocating = ExecutableLocator()
    ) {
        self.runner = runner
        self.executables = executables
    }

    func pair(address: String, code: String) async throws -> String {
        try await run(arguments: ["pair", normalized(address), code])
    }

    func connect(address: String) async throws -> String {
        try await run(arguments: ["connect", normalized(address)])
    }

    private func run(arguments: [String]) async throws -> String {
        guard let adb = executables.locate("adb") else {
            throw DeepLinkOpeningError.executableNotFound("adb")
        }

        let result = try await runner.run(executableURL: adb, arguments: arguments)
        let output = [result.stderr, result.stdout]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: "\n")

        guard result.statusCode == 0 else {
            throw DeepLinkOpeningError.commandFailed(
                tool: "adb",
                statusCode: result.statusCode,
                message: output
            )
        }
        return output
    }

    private func normalized(_ address: String) -> String {
        address.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
