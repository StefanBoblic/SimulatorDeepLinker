//
//  DeepLinkFileStorage.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 22.05.2026.
//

import Foundation

protocol DeepLinkFileStorage {
    func loadDeepLinks() throws -> [DeepLinkItem]
    func loadDeepLinks(from fileURL: URL) throws -> [DeepLinkItem]
    func saveDeepLinks(_ deepLinks: [DeepLinkItem]) throws
    func saveDeepLinks(_ deepLinks: [DeepLinkItem], to fileURL: URL) throws
    func storageFileURL() throws -> URL
    func defaultStorageFileURL() throws -> URL
    func setCustomStorageFileURL(_ fileURL: URL?)
    var usesCustomStorageFile: Bool { get }
}

final class JSONDeepLinkFileStorage: DeepLinkFileStorage {
    private static let customStoragePathKey = "customDeepLinkStoragePath"

    private let fileManager: FileManager
    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        fileManager: FileManager = FileManager.default,
        userDefaults: UserDefaults = .standard
    ) {
        self.fileManager = fileManager
        self.userDefaults = userDefaults

        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        jsonEncoder.dateEncodingStrategy = .iso8601
        self.encoder = jsonEncoder

        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601
        self.decoder = jsonDecoder
    }

    func loadDeepLinks() throws -> [DeepLinkItem] {
        try loadDeepLinks(from: storageFileURL())
    }

    func loadDeepLinks(from fileURL: URL) throws -> [DeepLinkItem] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        let fileData = try Data(contentsOf: fileURL)
        return try decoder.decode([DeepLinkItem].self, from: fileData)
    }

    func saveDeepLinks(_ deepLinks: [DeepLinkItem]) throws {
        try saveDeepLinks(deepLinks, to: storageFileURL())
    }

    func saveDeepLinks(_ deepLinks: [DeepLinkItem], to fileURL: URL) throws {
        let directoryURL = fileURL.deletingLastPathComponent()

        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let fileData = try encoder.encode(deepLinks)
        try fileData.write(to: fileURL, options: [.atomic])
    }

    func storageFileURL() throws -> URL {
        if let customStoragePath = userDefaults.string(forKey: Self.customStoragePathKey),
           customStoragePath.isEmpty == false {
            return URL(fileURLWithPath: customStoragePath).standardizedFileURL
        }

        return try defaultStorageFileURL()
    }

    func defaultStorageFileURL() throws -> URL {
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

    func setCustomStorageFileURL(_ fileURL: URL?) {
        if let fileURL {
            userDefaults.set(fileURL.standardizedFileURL.path, forKey: Self.customStoragePathKey)
        } else {
            userDefaults.removeObject(forKey: Self.customStoragePathKey)
        }
    }

    var usesCustomStorageFile: Bool {
        userDefaults.string(forKey: Self.customStoragePathKey)?.isEmpty == false
    }
}
