//
//  LaunchHistoryViewModel.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 11.08.2026.
//

import Combine
import Foundation

@MainActor
final class LaunchHistoryViewModel: ObservableObject {
    @Published private(set) var entries: [LaunchHistoryEntry] = []

    private let store: LaunchHistoryStore
    private var cancellables: Set<AnyCancellable> = []

    init(store: LaunchHistoryStore) {
        self.store = store
        entries = store.entries
        store.$entries
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entries in self?.entries = entries }
            .store(in: &cancellables)
    }

    func clear() {
        store.clear()
    }
}
