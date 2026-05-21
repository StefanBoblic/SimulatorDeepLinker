//
//  DeepLinkFileStorage.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 22.05.2026.
//

import Foundation

protocol DeepLinkFileStorage {
    func loadDeepLinks() throws -> [DeepLinkItem]
    func saveDeepLinks(_ deepLinks: [DeepLinkItem]) throws
    func storageFileURL() throws -> URL
}

final class JSONDeepLinkFileStorage: DeepLinkFileStorage {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = FileManager.default) {
        self.fileManager = fileManager

        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        jsonEncoder.dateEncodingStrategy = .iso8601
        self.encoder = jsonEncoder

        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601
        self.decoder = jsonDecoder
    }

    func loadDeepLinks() throws -> [DeepLinkItem] {
        let fileURL = try storageFileURL()

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        let fileData = try Data(contentsOf: fileURL)
        return try decoder.decode([DeepLinkItem].self, from: fileData)
    }

    func saveDeepLinks(_ deepLinks: [DeepLinkItem]) throws {
        let fileURL = try storageFileURL()
        let directoryURL = fileURL.deletingLastPathComponent()

        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let fileData = try encoder.encode(deepLinks)
        try fileData.write(to: fileURL, options: [.atomic])
    }

    func storageFileURL() throws -> URL {
        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let appFolderName = Bundle.main.bundleIdentifier ?? "SimulatorDeepLinker"

        return applicationSupportURL
            .appendingPathComponent(appFolderName, isDirectory: true)
            .appendingPathComponent("deeplinks.json", isDirectory: false)
    }
}
