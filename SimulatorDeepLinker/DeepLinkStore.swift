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

    private let fileStorage: DeepLinkFileStorage

    init(fileStorage: DeepLinkFileStorage = JSONDeepLinkFileStorage()) {
        self.fileStorage = fileStorage
        load()
    }

    func add(title: String, urlString: String) {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedURLString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedURLString.isEmpty == false else {
            return
        }

        let deepLinkItem = DeepLinkItem(
            title: normalizedTitle.isEmpty ? normalizedURLString : normalizedTitle,
            urlString: normalizedURLString
        )

        items.insert(deepLinkItem, at: 0)
        save()
    }

    func update(item: DeepLinkItem, title: String, urlString: String) {
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
        items[itemIndex].updatedAt = Date()

        save()
    }

    func delete(_ item: DeepLinkItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func reload() {
        load()
    }

    private func load() {
        do {
            items = try fileStorage.loadDeepLinks()
            storagePath = try fileStorage.storageFileURL().path
            print("Deep links loaded from:", storagePath)
        } catch {
            items = []
            print("Deep links load error:", error.localizedDescription)
        }
    }

    private func save() {
        do {
            try fileStorage.saveDeepLinks(items)
            storagePath = try fileStorage.storageFileURL().path
            print("Deep links saved to:", storagePath)
        } catch {
            print("Deep links save error:", error.localizedDescription)
        }
    }
}
