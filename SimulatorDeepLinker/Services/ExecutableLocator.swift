//
//  ExecutableLocator.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 11.08.2026.
//

import Foundation

protocol ExecutableLocating: Sendable {
    func locate(_ executable: String) -> URL?
}

struct ExecutableLocator: ExecutableLocating {
    private let environment: [String: String]
    private let homeDirectory: URL

    init(
        fileManager: FileManager? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        homeDirectory = (fileManager ?? .default).homeDirectoryForCurrentUser
        self.environment = environment
    }

    func locate(_ executable: String) -> URL? {
        for candidate in candidates(for: executable)
        where FileManager.default.isExecutableFile(atPath: candidate.path) {
            return candidate
        }
        return nil
    }

    private func candidates(for executable: String) -> [URL] {
        var paths = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map { URL(fileURLWithPath: String($0)).appendingPathComponent(executable) }

        if executable == "xcrun" {
            paths.insert(URL(fileURLWithPath: "/usr/bin/xcrun"), at: 0)
        }

        if executable == "adb" {
            if let androidHome = environment["ANDROID_HOME"] ?? environment["ANDROID_SDK_ROOT"] {
                paths.insert(
                    URL(fileURLWithPath: androidHome)
                        .appendingPathComponent("platform-tools/adb"),
                    at: 0
                )
            }

            paths.append(
                homeDirectory
                    .appendingPathComponent("Library/Android/sdk/platform-tools/adb")
            )
        }

        return paths
    }
}
