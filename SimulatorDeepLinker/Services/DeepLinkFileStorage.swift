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
    func updateDeepLinks(_ update: (inout [DeepLinkItem]) throws -> Void) throws -> [DeepLinkItem]
    func saveDeepLinks(_ deepLinks: [DeepLinkItem]) throws
    func saveDeepLinks(_ deepLinks: [DeepLinkItem], to fileURL: URL) throws
    func ensureStorageExists() throws
    func storageFileURL() throws -> URL
    func defaultStorageFileURL() throws -> URL
    func setCustomStorageFileURL(_ fileURL: URL?)
    var usesCustomStorageFile: Bool { get }
}

final class JSONDeepLinkFileStorage: DeepLinkFileStorage {
    private static let customStoragePathKey = "customDeepLinkStoragePath"
    private static let lockSuffix = ".simulator-deep-linker.lock"
    private static let lockRetryInterval: TimeInterval = 0.025
    private static let lockTimeout: TimeInterval = 10
    private static let staleLockAge: TimeInterval = 120

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
        try loadDeepLinksWithoutLock(from: canonicalFileURL(fileURL))
    }

    func updateDeepLinks(_ update: (inout [DeepLinkItem]) throws -> Void) throws -> [DeepLinkItem] {
        try withStorageLock(for: storageFileURL()) { fileURL in
            var deepLinks = try loadDeepLinksWithoutLock(from: fileURL)
            try update(&deepLinks)
            try saveDeepLinksWithoutLock(deepLinks, to: fileURL)
            return deepLinks
        }
    }

    func ensureStorageExists() throws {
        try withStorageLock(for: storageFileURL()) { fileURL in
            guard fileManager.fileExists(atPath: fileURL.path) == false else { return }
            try saveDeepLinksWithoutLock([], to: fileURL)
        }
    }

    private func loadDeepLinksWithoutLock(from fileURL: URL) throws -> [DeepLinkItem] {
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
        try withStorageLock(for: fileURL) { lockedFileURL in
            try saveDeepLinksWithoutLock(deepLinks, to: lockedFileURL)
        }
    }

    private func saveDeepLinksWithoutLock(_ deepLinks: [DeepLinkItem], to fileURL: URL) throws {
        let directoryURL = fileURL.deletingLastPathComponent()

        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let fileData = try encoder.encode(deepLinks)
        try fileData.write(to: fileURL, options: [.atomic])
    }

    private func withStorageLock<T>(for fileURL: URL, operation: (URL) throws -> T) throws -> T {
        let canonicalURL = canonicalFileURL(fileURL)
        let directoryURL = canonicalURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let lockURL = URL(fileURLWithPath: canonicalURL.path + Self.lockSuffix)
        let deadline = Date().addingTimeInterval(Self.lockTimeout)

        while true {
            do {
                try fileManager.createDirectory(at: lockURL, withIntermediateDirectories: false)
                break
            } catch {
                guard fileManager.fileExists(atPath: lockURL.path) else { throw error }
                try removeStaleLockIfNeeded(at: lockURL)
                guard Date() < deadline else {
                    throw StorageLockError.timedOut
                }
                Thread.sleep(forTimeInterval: Self.lockRetryInterval)
            }
        }

        defer { try? fileManager.removeItem(at: lockURL) }
        return try operation(canonicalURL)
    }

    private func removeStaleLockIfNeeded(at lockURL: URL) throws {
        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try fileManager.attributesOfItem(atPath: lockURL.path)
        } catch {
            guard fileManager.fileExists(atPath: lockURL.path) else { return }
            throw error
        }
        guard let modifiedAt = attributes[.modificationDate] as? Date,
              Date().timeIntervalSince(modifiedAt) > Self.staleLockAge else {
            return
        }

        let staleURL = URL(fileURLWithPath: lockURL.path + ".stale." + UUID().uuidString)
        do {
            try fileManager.moveItem(at: lockURL, to: staleURL)
            try? fileManager.removeItem(at: staleURL)
        } catch {
            guard fileManager.fileExists(atPath: lockURL.path) else { return }
            throw error
        }
    }

    private func canonicalFileURL(_ fileURL: URL) -> URL {
        let standardizedURL = fileURL.standardizedFileURL
        return fileManager.fileExists(atPath: standardizedURL.path)
            ? standardizedURL.resolvingSymlinksInPath()
            : standardizedURL
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

private enum StorageLockError: LocalizedError {
    case timedOut

    var errorDescription: String? {
        "Timed out waiting for another Simulator Deep Linker writer to finish."
    }
}
