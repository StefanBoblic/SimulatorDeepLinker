//
//  DeepLinkStore.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 22.05.2026.
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class DeepLinkStore: ObservableObject {
    @Published private(set) var items: [DeepLinkItem] = []
    @Published private(set) var storagePath: String = ""
    @Published private(set) var usesCustomStorageFile = false
    @Published private(set) var storageError: String?

    private let fileStorage: DeepLinkFileStorage
    private let fileMonitor = StorageFileMonitor()
    private var externalReloadTask: Task<Void, Never>?

    init(fileStorage: DeepLinkFileStorage? = nil) {
        self.fileStorage = fileStorage ?? JSONDeepLinkFileStorage()
        load(clearItemsOnFailure: true)
    }

    @discardableResult
    func add(
        title: String,
        urlString: String,
        group: String = "",
        tags: [String] = [],
        isFavorite: Bool = false
    ) -> DeepLinkItem? {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedURLString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedURLString.isEmpty == false else {
            return nil
        }

        let deepLinkItem = DeepLinkItem(
            title: normalizedTitle.isEmpty ? normalizedURLString : normalizedTitle,
            urlString: normalizedURLString,
            group: group.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: normalized(tags),
            isFavorite: isFavorite
        )

        items.insert(deepLinkItem, at: 0)
        save()
        return deepLinkItem
    }

    func update(
        item: DeepLinkItem,
        title: String,
        urlString: String,
        group: String = "",
        tags: [String] = [],
        isFavorite: Bool = false
    ) {
        guard let itemIndex = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedURLString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedURLString.isEmpty == false else {
            return
        }

        items[itemIndex].title = normalizedTitle.isEmpty ? normalizedURLString : normalizedTitle
        items[itemIndex].urlString = normalizedURLString
        items[itemIndex].group = group.trimmingCharacters(in: .whitespacesAndNewlines)
        items[itemIndex].tags = normalized(tags)
        items[itemIndex].isFavorite = isFavorite
        items[itemIndex].updatedAt = Date()

        save()
    }

    func delete(_ item: DeepLinkItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func toggleFavorite(_ item: DeepLinkItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isFavorite.toggle()
        items[index].updatedAt = Date()
        save()
    }

    func delete(ids: Set<DeepLinkItem.ID>) {
        items.removeAll { ids.contains($0.id) }
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func reload() {
        load()
    }

    func importDeepLinks(from fileURL: URL) throws -> Int {
        let importedItems = try fileStorage.loadDeepLinks(from: fileURL)
        var itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        importedItems.forEach { itemsByID[$0.id] = $0 }
        items = itemsByID.values.sorted { $0.updatedAt > $1.updatedAt }
        save()
        return importedItems.count
    }

    func exportDeepLinks(to fileURL: URL) throws {
        try fileStorage.saveDeepLinks(items, to: fileURL.standardizedFileURL)
    }

    func useExistingStorageFile(at fileURL: URL) throws {
        let standardizedURL = fileURL.standardizedFileURL
        let loadedItems = try fileStorage.loadDeepLinks(from: standardizedURL)

        fileStorage.setCustomStorageFileURL(standardizedURL)
        items = loadedItems
        try updateStorageState()
    }

    func createSharedStorageFile(at fileURL: URL) throws {
        let standardizedURL = fileURL.standardizedFileURL

        try fileStorage.saveDeepLinks(items, to: standardizedURL)
        fileStorage.setCustomStorageFileURL(standardizedURL)
        try updateStorageState()
    }

    func useDefaultStorageFile() throws {
        let defaultURL = try fileStorage.defaultStorageFileURL()
        let loadedItems = try fileStorage.loadDeepLinks(from: defaultURL)

        fileStorage.setCustomStorageFileURL(nil)
        items = loadedItems
        try updateStorageState()
    }

    private func load(clearItemsOnFailure: Bool = false) {
        do {
            items = try fileStorage.loadDeepLinks()
            try updateStorageState()
            print("Deep links loaded from:", storagePath)
        } catch {
            if clearItemsOnFailure {
                items = []
            }
            storageError = error.localizedDescription
            print("Deep links load error:", error.localizedDescription)
        }
    }

    private func save() {
        do {
            try fileStorage.saveDeepLinks(items)
            try updateStorageState()
            print("Deep links saved to:", storagePath)
        } catch {
            storageError = error.localizedDescription
            print("Deep links save error:", error.localizedDescription)
        }
    }

    private func updateStorageState() throws {
        let fileURL = try fileStorage.storageFileURL()
        storagePath = fileURL.path
        usesCustomStorageFile = fileStorage.usesCustomStorageFile
        storageError = nil
        monitorStorageFile(at: fileURL)
    }

    private func monitorStorageFile(at fileURL: URL) {
        fileMonitor.start(fileURL: fileURL) { [weak self] in
            Task { @MainActor [weak self] in
                self?.scheduleExternalReload()
            }
        }
    }

    private func scheduleExternalReload() {
        externalReloadTask?.cancel()
        externalReloadTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard Task.isCancelled == false else { return }
            self?.load()
        }
    }

    private func normalized(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        return tags.compactMap { tag in
            let value = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard value.isEmpty == false else { return nil }
            let key = value.lowercased()
            guard seen.insert(key).inserted else { return nil }
            return value
        }
    }
}
