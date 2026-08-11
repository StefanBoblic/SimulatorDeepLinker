//
//  LaunchHistoryStore.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 11.08.2026.
//

import Combine
import Foundation

@MainActor
final class LaunchHistoryStore: ObservableObject {
    @Published private(set) var entries: [LaunchHistoryEntry] = []

    private let userDefaults: UserDefaults
    private let storageKey = "launchHistory"
    private let maximumEntryCount = 200

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }

    func record(_ entry: LaunchHistoryEntry) {
        entries.insert(entry, at: 0)
        entries = Array(entries.prefix(maximumEntryCount))
        save()
    }

    func clear() {
        entries = []
        userDefaults.removeObject(forKey: storageKey)
    }

    private func load() {
        guard let data = userDefaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([LaunchHistoryEntry].self, from: data) else {
            return
        }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}
