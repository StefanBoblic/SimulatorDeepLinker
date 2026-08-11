//
//  EnvironmentStore.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 11.08.2026.
//

import Combine
import Foundation

@MainActor
final class EnvironmentStore: ObservableObject {
    @Published var environments: [LinkEnvironment] {
        didSet { save() }
    }

    private let userDefaults: UserDefaults
    private let storageKey = "linkEnvironments"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let data = userDefaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([LinkEnvironment].self, from: data) {
            environments = decoded
        } else {
            environments = []
        }
    }

    func add() -> LinkEnvironment {
        let environment = LinkEnvironment(name: String(localized: "New Environment"))
        environments.append(environment)
        return environment
    }

    func delete(at offsets: IndexSet) {
        offsets.sorted(by: >).forEach { environments.remove(at: $0) }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(environments) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}
