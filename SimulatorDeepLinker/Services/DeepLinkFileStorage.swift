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
    private static let recoveryClaimFileName = ".recovery-claim"
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
        let candidateURL = URL(fileURLWithPath: lockURL.path + ".candidate." + owner.token)
        let candidateOwnerURL = candidateURL.appendingPathComponent(Self.lockOwnerFileName, isDirectory: false)
        let deadline = Date().addingTimeInterval(Self.lockTimeout)

        while true {
            try fileManager.createDirectory(at: candidateURL, withIntermediateDirectories: false)
            do {
                try writeStorageLockOwner(owner, to: candidateOwnerURL)
            } catch {
                try? fileManager.removeItem(at: candidateOwnerURL)
                try? removeEmptyDirectory(at: candidateURL)
                throw error
            }

            do {
                // A symlink publishes the initialized candidate with create-if-absent semantics. Unlike rename, it
                // cannot replace an existing empty lock while another writer is releasing or recovering it.
                try fileManager.createSymbolicLink(at: lockURL, withDestinationURL: candidateURL)
                break
            } catch {
                try? fileManager.removeItem(at: candidateOwnerURL)
                try? removeEmptyDirectory(at: candidateURL)
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
        guard (try? readStorageLockOwner(from: ownerURL)) == owner else {
            throw StorageLockError.ownershipChanged
        }

        let releaseURL = URL(fileURLWithPath: lockURL.path + ".release." + owner.token)
        do {
            try fileManager.moveItem(at: lockURL, to: releaseURL)
        } catch {
            throw StorageLockError.couldNotVerifyOwnership(error)
        }

        let claimedOwnerURL = releaseURL.appendingPathComponent(Self.lockOwnerFileName, isDirectory: false)
        let currentOwner = try? readStorageLockOwner(from: claimedOwnerURL)
        guard currentOwner == owner else {
            throw StorageLockError.ownershipChanged
        }

        try removeClaimedStorageLock(at: releaseURL, ownerURL: claimedOwnerURL)
    }

    private func recoverAbandonedStorageLock(at lockURL: URL, ownerURL: URL) throws {
        guard let observedOwner = try? readStorageLockOwner(from: ownerURL) else {
            try recoverLegacyTransitionLock(at: lockURL)
            return
        }
        guard isProcessAlive(observedOwner.pid) == false else { return }

        // This generation-local claim serializes recovery and prevents a stale observer from moving a replacement lock.
        guard let recoveryLease = try acquireStorageRecoveryClaim(at: lockURL, owner: observedOwner) else { return }
        guard (try? readStorageLockOwner(from: ownerURL)) == observedOwner,
              (try? readStorageRecoveryClaim(from: recoveryLease.url)) == recoveryLease.claim else {
            releaseStorageRecoveryClaim(recoveryLease)
            return
        }

        let recoveryURL = URL(fileURLWithPath: lockURL.path + ".recovery." + UUID().uuidString)
        do {
            try fileManager.moveItem(at: lockURL, to: recoveryURL)
        } catch {
            releaseStorageRecoveryClaim(recoveryLease)
            guard fileManager.fileExists(atPath: lockURL.path) else { return }
            throw error
        }

        let claimedOwnerURL = recoveryURL.appendingPathComponent(Self.lockOwnerFileName, isDirectory: false)
        guard (try? readStorageLockOwner(from: claimedOwnerURL)) == observedOwner else { return }

        try removeClaimedStorageLock(at: recoveryURL, ownerURL: claimedOwnerURL)
    }

    private func recoverLegacyTransitionLock(at lockURL: URL) throws {
        let entries: [URL]
        do {
            entries = try fileManager.contentsOfDirectory(at: lockURL, includingPropertiesForKeys: nil)
        } catch {
            guard fileManager.fileExists(atPath: lockURL.path) else { return }
            throw error
        }

        guard entries.isEmpty == false else {
            throw StorageLockError.ownerlessLegacyLock
        }

        let transitions = entries.filter {
            $0.lastPathComponent.hasPrefix(".recovery.") || $0.lastPathComponent.hasPrefix(".release.")
        }
        guard transitions.count == 1,
              let transitionOwner = try? readStorageLockOwner(from: transitions[0]),
              isProcessAlive(transitionOwner.pid) == false else { return }

        guard let recoveryLease = try acquireStorageRecoveryClaim(at: lockURL, owner: transitionOwner) else { return }
        guard (try? readStorageLockOwner(from: transitions[0])) == transitionOwner,
              (try? readStorageRecoveryClaim(from: recoveryLease.url)) == recoveryLease.claim else {
            releaseStorageRecoveryClaim(recoveryLease)
            return
        }

        let recoveryURL = URL(fileURLWithPath: lockURL.path + ".recovery." + UUID().uuidString)
        do {
            try fileManager.moveItem(at: lockURL, to: recoveryURL)
        } catch {
            releaseStorageRecoveryClaim(recoveryLease)
            guard fileManager.fileExists(atPath: lockURL.path) else { return }
            throw error
        }

        let claimedTransitionURL = recoveryURL.appendingPathComponent(transitions[0].lastPathComponent)
        guard (try? readStorageLockOwner(from: claimedTransitionURL)) == transitionOwner else { return }
        try removeClaimedStorageLock(at: recoveryURL, ownerURL: claimedTransitionURL)
    }

    private func acquireStorageRecoveryClaim(
        at lockURL: URL,
        owner: StorageLockOwner
    ) throws -> (claim: StorageRecoveryClaim, url: URL, canReleaseSafely: Bool)? {
        let resourceValues = try? lockURL.resourceValues(forKeys: [.isSymbolicLinkKey])
        let canReleaseSafely = resourceValues?.isSymbolicLink == true
        let lockTargetURL = lockURL.resolvingSymlinksInPath()
        let claimURL = lockTargetURL.appendingPathComponent(Self.recoveryClaimFileName, isDirectory: false)
        let claim = StorageRecoveryClaim(
            ownerToken: owner.token,
            ownerPid: owner.pid,
            claimantToken: UUID().uuidString,
            claimantPid: getpid()
        )

        do {
            try writeStorageRecoveryClaim(claim, to: claimURL)
            return (claim, claimURL, canReleaseSafely)
        } catch CocoaError.fileNoSuchFile {
            return nil
        } catch CocoaError.fileWriteFileExists {
            // The existing claimant is inspected below.
        }

        guard let abandonedClaim = try? readStorageRecoveryClaim(from: claimURL),
              abandonedClaim.ownerToken == owner.token,
              abandonedClaim.ownerPid == owner.pid,
              isProcessAlive(abandonedClaim.claimantPid) == false else { return nil }

        let takeoverURL = lockTargetURL.appendingPathComponent(
            "\(Self.recoveryClaimFileName).takeover.\(claim.claimantToken)",
            isDirectory: false
        )
        do {
            try fileManager.moveItem(at: claimURL, to: takeoverURL)
        } catch CocoaError.fileNoSuchFile {
            return nil
        }

        guard (try? readStorageRecoveryClaim(from: takeoverURL)) == abandonedClaim else { return nil }

        do {
            try writeStorageRecoveryClaim(claim, to: claimURL)
        } catch CocoaError.fileNoSuchFile {
            try? fileManager.removeItem(at: takeoverURL)
            return nil
        } catch CocoaError.fileWriteFileExists {
            try? fileManager.removeItem(at: takeoverURL)
            return nil
        } catch {
            try? fileManager.removeItem(at: takeoverURL)
            throw error
        }
        try? fileManager.removeItem(at: takeoverURL)
        return (claim, claimURL, canReleaseSafely)
    }

    private func releaseStorageRecoveryClaim(
        _ lease: (claim: StorageRecoveryClaim, url: URL, canReleaseSafely: Bool)
    ) {
        guard lease.canReleaseSafely,
              (try? readStorageRecoveryClaim(from: lease.url)) == lease.claim else { return }
        try? fileManager.removeItem(at: lease.url)
    }

    private func removeClaimedStorageLock(at lockURL: URL, ownerURL: URL) throws {
        let resourceValues = try lockURL.resourceValues(forKeys: [.isSymbolicLinkKey])
        let symbolicLinkDestination = resourceValues.isSymbolicLink == true
            ? try fileManager.destinationOfSymbolicLink(atPath: lockURL.path)
            : nil
        try fileManager.removeItem(at: ownerURL)
        let recoveryClaimURL = lockURL.appendingPathComponent(Self.recoveryClaimFileName, isDirectory: false)
        if fileManager.fileExists(atPath: recoveryClaimURL.path) {
            try fileManager.removeItem(at: recoveryClaimURL)
        }
        for entry in try fileManager.contentsOfDirectory(at: lockURL, includingPropertiesForKeys: nil)
        where entry.lastPathComponent.hasPrefix("\(Self.recoveryClaimFileName).takeover.") {
            try fileManager.removeItem(at: entry)
        }
        if let symbolicLinkDestination {
            let destinationURL = URL(fileURLWithPath: symbolicLinkDestination, relativeTo: lockURL.deletingLastPathComponent())
                .standardizedFileURL
            try removeEmptyDirectory(at: destinationURL)
            try fileManager.removeItem(at: lockURL)
        } else {
            try removeEmptyDirectory(at: lockURL)
        }
    }

    private func writeStorageLockOwner(_ owner: StorageLockOwner, to ownerURL: URL) throws {
        try JSONEncoder().encode(owner).write(to: ownerURL, options: .withoutOverwriting)
    }

    private func readStorageLockOwner(from ownerURL: URL) throws -> StorageLockOwner {
        try JSONDecoder().decode(StorageLockOwner.self, from: Data(contentsOf: ownerURL))
    }

    private func writeStorageRecoveryClaim(_ claim: StorageRecoveryClaim, to claimURL: URL) throws {
        try JSONEncoder().encode(claim).write(to: claimURL, options: .withoutOverwriting)
    }

    private func readStorageRecoveryClaim(from claimURL: URL) throws -> StorageRecoveryClaim {
        try JSONDecoder().decode(StorageRecoveryClaim.self, from: Data(contentsOf: claimURL))
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

private struct StorageRecoveryClaim: Codable, Equatable {
    let schemaVersion: Int
    let ownerToken: String
    let ownerPid: Int32
    let claimantToken: String
    let claimantPid: Int32

    init(ownerToken: String, ownerPid: Int32, claimantToken: String, claimantPid: Int32) {
        schemaVersion = 1
        self.ownerToken = ownerToken
        self.ownerPid = ownerPid
        self.claimantToken = claimantToken
        self.claimantPid = claimantPid
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        ownerToken = try container.decode(String.self, forKey: .ownerToken)
        ownerPid = try container.decode(Int32.self, forKey: .ownerPid)
        claimantToken = try container.decode(String.self, forKey: .claimantToken)
        claimantPid = try container.decode(Int32.self, forKey: .claimantPid)
        guard schemaVersion == 1,
              ownerToken.isEmpty == false,
              ownerPid > 0,
              claimantToken.isEmpty == false,
              claimantPid > 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported storage recovery claim metadata."
            )
        }
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case ownerToken
        case ownerPid
        case claimantToken
        case claimantPid
    }
}

private enum StorageLockError: LocalizedError {
    case timedOut
    case ownershipChanged
    case couldNotVerifyOwnership(Error)
    case ownerlessLegacyLock

    var errorDescription: String? {
        switch self {
        case .timedOut:
            "Timed out waiting for another Simulator Deep Linker writer to finish. If no writer is running, remove the abandoned storage lock manually."
        case .ownershipChanged:
            "Storage lock ownership changed while updating deep links; the replacement lock was left intact."
        case let .couldNotVerifyOwnership(error):
            "Could not verify storage lock ownership: \(error.localizedDescription)"
        case .ownerlessLegacyLock:
            "Simulator Deep Linker found an unfinished storage update from an older version. Quit Simulator Deep Linker and Raycast, remove the .simulator-deep-linker.lock folder next to your storage file, then try again."
        }
    }
}
