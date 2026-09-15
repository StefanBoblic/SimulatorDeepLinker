//
//  DeepLinkFileStorage.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 22.05.2026.
//

import Darwin
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
    private static let lockOwnerFileName = "owner"
    private static let lockRetryInterval: TimeInterval = 0.025
    private static let lockTimeout: TimeInterval = 10

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
        let ownerURL = lockURL.appendingPathComponent(Self.lockOwnerFileName, isDirectory: false)
        let owner = StorageLockOwner(token: UUID().uuidString, pid: getpid())
        let deadline = Date().addingTimeInterval(Self.lockTimeout)

        while true {
            do {
                try fileManager.createDirectory(at: lockURL, withIntermediateDirectories: false)
                do {
                    try writeStorageLockOwner(owner, to: ownerURL)
                } catch {
                    try? fileManager.removeItem(at: ownerURL)
                    try? removeEmptyDirectory(at: lockURL)
                    throw error
                }
                break
            } catch {
                guard fileManager.fileExists(atPath: lockURL.path) else { throw error }
                try recoverAbandonedStorageLock(at: lockURL, ownerURL: ownerURL)
                guard Date() < deadline else {
                    throw StorageLockError.timedOut
                }
                Thread.sleep(forTimeInterval: Self.lockRetryInterval)
            }
        }

        do {
            let result = try operation(canonicalURL)
            try releaseStorageLock(at: lockURL, ownerURL: ownerURL, owner: owner)
            return result
        } catch {
            let operationError = error
            try? releaseStorageLock(at: lockURL, ownerURL: ownerURL, owner: owner)
            throw operationError
        }
    }

    private func releaseStorageLock(at lockURL: URL, ownerURL: URL, owner: StorageLockOwner) throws {
        let releaseURL = lockURL.appendingPathComponent(".release.\(owner.token)")
        do {
            try fileManager.moveItem(at: ownerURL, to: releaseURL)
        } catch {
            throw StorageLockError.couldNotVerifyOwnership(error)
        }

        let currentOwner = try? readStorageLockOwner(from: releaseURL)
        guard currentOwner == owner else {
            try? restoreStorageLockOwner(from: releaseURL, to: ownerURL)
            throw StorageLockError.ownershipChanged
        }

        try removeClaimedStorageLock(at: lockURL, ownerURL: ownerURL, claimURL: releaseURL, owner: owner)
    }

    private func recoverAbandonedStorageLock(at lockURL: URL, ownerURL: URL) throws {
        guard let observedOwner = try? readStorageLockOwner(from: ownerURL) else {
            try recoverOwnerlessStorageLock(at: lockURL, ownerURL: ownerURL)
            return
        }
        guard isProcessAlive(observedOwner.pid) == false else { return }

        let recoveryURL = lockURL.appendingPathComponent(".recovery.\(UUID().uuidString)")
        do {
            try fileManager.moveItem(at: ownerURL, to: recoveryURL)
        } catch {
            guard fileManager.fileExists(atPath: ownerURL.path) else { return }
            throw error
        }

        guard let claimedOwner = try? readStorageLockOwner(from: recoveryURL),
              claimedOwner == observedOwner,
              isProcessAlive(claimedOwner.pid) == false else {
            try? restoreStorageLockOwner(from: recoveryURL, to: ownerURL)
            return
        }

        try removeClaimedStorageLock(at: lockURL, ownerURL: ownerURL, claimURL: recoveryURL, owner: claimedOwner)
    }

    private func recoverOwnerlessStorageLock(at lockURL: URL, ownerURL: URL) throws {
        let entries: [URL]
        do {
            entries = try fileManager.contentsOfDirectory(at: lockURL, includingPropertiesForKeys: nil)
        } catch {
            guard fileManager.fileExists(atPath: lockURL.path) else { return }
            throw error
        }

        if entries.isEmpty {
            try? removeEmptyDirectory(at: lockURL)
            return
        }

        let transitions = entries.filter {
            $0.lastPathComponent.hasPrefix(".recovery.") || $0.lastPathComponent.hasPrefix(".release.")
        }
        guard transitions.count == 1,
              let transitionOwner = try? readStorageLockOwner(from: transitions[0]),
              isProcessAlive(transitionOwner.pid) == false else { return }
        try? restoreStorageLockOwner(from: transitions[0], to: ownerURL)
    }

    private func removeClaimedStorageLock(
        at lockURL: URL,
        ownerURL: URL,
        claimURL: URL,
        owner: StorageLockOwner
    ) throws {
        try fileManager.removeItem(at: claimURL)
        do {
            try removeEmptyDirectory(at: lockURL)
        } catch {
            try? writeStorageLockOwner(owner, to: ownerURL)
            throw error
        }
    }

    private func restoreStorageLockOwner(from claimURL: URL, to ownerURL: URL) throws {
        guard fileManager.fileExists(atPath: claimURL.path) else { return }
        try fileManager.moveItem(at: claimURL, to: ownerURL)
    }

    private func writeStorageLockOwner(_ owner: StorageLockOwner, to ownerURL: URL) throws {
        try JSONEncoder().encode(owner).write(to: ownerURL)
    }

    private func readStorageLockOwner(from ownerURL: URL) throws -> StorageLockOwner {
        try JSONDecoder().decode(StorageLockOwner.self, from: Data(contentsOf: ownerURL))
    }

    private func isProcessAlive(_ pid: Int32) -> Bool {
        if Darwin.kill(pid, 0) == 0 { return true }
        return errno != ESRCH
    }

    private func removeEmptyDirectory(at directoryURL: URL) throws {
        let result: Int32 = directoryURL.withUnsafeFileSystemRepresentation { fileSystemPath in
            guard let fileSystemPath else { return -1 }
            return Darwin.rmdir(fileSystemPath)
        }
        guard result == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
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

private struct StorageLockOwner: Codable, Equatable {
    let schemaVersion: Int
    let token: String
    let pid: Int32

    init(token: String, pid: Int32) {
        schemaVersion = 1
        self.token = token
        self.pid = pid
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        token = try container.decode(String.self, forKey: .token)
        pid = try container.decode(Int32.self, forKey: .pid)
        guard schemaVersion == 1, token.isEmpty == false, pid > 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported storage lock owner metadata."
            )
        }
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case token
        case pid
    }
}

private enum StorageLockError: LocalizedError {
    case timedOut
    case ownershipChanged
    case couldNotVerifyOwnership(Error)

    var errorDescription: String? {
        switch self {
        case .timedOut:
            "Timed out waiting for another Simulator Deep Linker writer to finish. If no writer is running, remove the abandoned storage lock manually."
        case .ownershipChanged:
            "Storage lock ownership changed while updating deep links; the replacement lock was left intact."
        case let .couldNotVerifyOwnership(error):
            "Could not verify storage lock ownership: \(error.localizedDescription)"
        }
    }
}
