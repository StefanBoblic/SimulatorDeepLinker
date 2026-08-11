//
//  IntegrationManifestWriter.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 11.08.2026.
//

import Foundation

struct IntegrationManifest: Codable, Sendable {
    let schemaVersion: Int
    let storagePath: String
    let environmentsPath: String
    let updatedAt: Date
}

protocol IntegrationManifestWriting: Sendable {
    func write(storageFileURL: URL) throws
}

struct IntegrationManifestWriter: IntegrationManifestWriting {
    static let fileName = "integration.json"

    private let fileManager: FileManager
    private let encoder: JSONEncoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func write(storageFileURL: URL) throws {
        let storageFileURL = storageFileURL.standardizedFileURL
        let manifest = IntegrationManifest(
            schemaVersion: 1,
            storagePath: storageFileURL.path,
            environmentsPath: storageFileURL
                .deletingLastPathComponent()
                .appendingPathComponent("environments.json")
                .path,
            updatedAt: Date()
        )
        let manifestURL = try manifestFileURL()

        try fileManager.createDirectory(
            at: manifestURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(manifest).write(to: manifestURL, options: .atomic)
    }

    private func manifestFileURL() throws -> URL {
        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let appFolderName = Bundle.main.bundleIdentifier ?? "com.stefan.SimulatorDeepLinker"
        return applicationSupportURL
            .appendingPathComponent(appFolderName, isDirectory: true)
            .appendingPathComponent(Self.fileName, isDirectory: false)
    }
}
