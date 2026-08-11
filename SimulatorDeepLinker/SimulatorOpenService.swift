//
//  SimulatorOpenService.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 22.05.2026.
//

import Foundation

struct SimulatorOpenResult {
    let stdout: String
    let stderr: String
}

enum SimulatorOpenError: LocalizedError {
    case invalidURL
    case emptyCustomUDID
    case commandFailed(statusCode: Int32, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "Invalid URL. Check the scheme, for example https://, myapp://, or magnit://.")
        case .emptyCustomUDID:
            return String(localized: "Enter a simulator UDID or choose Booted simulator.")
        case let .commandFailed(statusCode, message):
            return String(
                format: String(localized: "xcrun exited with code %d. %@"),
                statusCode,
                message
            )
        }
    }
}

enum SimulatorOpenService {
    static func open(
        urlString: String,
        target: SimulatorTarget,
        customUDID: String
    ) async throws -> SimulatorOpenResult {
        let normalizedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: normalizedURL), url.scheme?.isEmpty == false else {
            throw SimulatorOpenError.invalidURL
        }

        let deviceArgument: String
        switch target {
        case .booted:
            deviceArgument = "booted"
        case .custom:
            let normalizedUDID = customUDID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard normalizedUDID.isEmpty == false else {
                throw SimulatorOpenError.emptyCustomUDID
            }
            deviceArgument = normalizedUDID
        }

        let result = try await CommandRunner.run(
            executablePath: "/usr/bin/xcrun",
            arguments: ["simctl", "openurl", deviceArgument, url.absoluteString]
        )

        return SimulatorOpenResult(
            stdout: result.stdout,
            stderr: result.stderr
        )
    }
}
