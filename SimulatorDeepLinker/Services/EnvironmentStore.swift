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
    @Published var environments: [LinkEnvironment] = [] {
        didSet {
            guard isLoading == false else { return }
            save()
        }
    }
    @Published private(set) var storagePath = ""
    @Published private(set) var storageError: String?

    private let deepLinkStore: DeepLinkStore
    private let fileManager: FileManager
    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()
    private let fileMonitor = StorageFileMonitor()
    private var cancellables: Set<AnyCancellable> = []
    private var externalReloadTask: Task<Void, Never>?
    private var isLoading = false

    init(
        deepLinkStore: DeepLinkStore,
        fileManager: FileManager = .default,
        userDefaults: UserDefaults = .standard
    ) {
        self.deepLinkStore = deepLinkStore
        self.fileManager = fileManager
        self.userDefaults = userDefaults

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        deepLinkStore.$storagePath
            .removeDuplicates()
            .sink { [weak self] _ in self?.loadForCurrentStorage() }
            .store(in: &cancellables)
    }

    func add() -> LinkEnvironment {
        let environment = LinkEnvironment(name: String(localized: "New Environment"))
        environments.append(environment)
        return environment
    }

    func delete(at offsets: IndexSet) {
        let removableOffsets = offsets.filter { environments[$0].isBuiltIn == false }
        removableOffsets.sorted(by: >).forEach { environments.remove(at: $0) }
    }

    private func loadForCurrentStorage() {
        guard deepLinkStore.storagePath.isEmpty == false else { return }
        let fileURL = environmentFileURL
        storagePath = fileURL.path

        do {
            let loaded: [LinkEnvironment]
            let fileExists = fileManager.fileExists(atPath: fileURL.path)
            if fileExists {
                loaded = try decoder.decode([LinkEnvironment].self, from: Data(contentsOf: fileURL))
            } else {
                let legacyEnvironments = migratedLegacyEnvironments()
                loaded = legacyEnvironments.isEmpty ? environments : legacyEnvironments
            }
            let needsDefaults = loaded.contains { $0.id == LinkEnvironment.development.id } == false
                || loaded.contains { $0.id == LinkEnvironment.production.id } == false

            isLoading = true
            environments = withBuiltInDefaults(loaded)
            isLoading = false
            storageError = nil
            if fileExists == false || needsDefaults {
                save()
            }
            monitor(fileURL)
        } catch {
            isLoading = false
            storageError = error.localizedDescription
        }
    }

    private func save() {
        guard storagePath.isEmpty == false else { return }
        do {
            let fileURL = URL(fileURLWithPath: storagePath)
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try encoder.encode(environments).write(to: fileURL, options: .atomic)
            storageError = nil
        } catch {
            storageError = error.localizedDescription
        }
    }

    private func migratedLegacyEnvironments() -> [LinkEnvironment] {
        let key = "linkEnvironments"
        guard let data = userDefaults.data(forKey: key),
              let decoded = try? decoder.decode([LinkEnvironment].self, from: data) else {
            return []
        }
        userDefaults.removeObject(forKey: key)
        return decoded
    }

    private func withBuiltInDefaults(_ source: [LinkEnvironment]) -> [LinkEnvironment] {
        let development = source.first {
            $0.id == LinkEnvironment.development.id
                || $0.name.caseInsensitiveCompare("Development") == .orderedSame
        } ?? LinkEnvironment.development
        let production = source.first {
            $0.id == LinkEnvironment.production.id
                || $0.name.caseInsensitiveCompare("Production") == .orderedSame
        } ?? LinkEnvironment.production
        var result = source.filter {
            $0.id != development.id && $0.id != production.id
        }
        developmentAndProduction(&result, development: development, production: production)
        return result
    }

    private func developmentAndProduction(
        _ environments: inout [LinkEnvironment],
        development: LinkEnvironment,
        production: LinkEnvironment
    ) {
        let normalizedDevelopment = LinkEnvironment(
            id: LinkEnvironment.development.id,
            name: "Development",
            variables: development.variables,
            isBuiltIn: true
        )
        let normalizedProduction = LinkEnvironment(
            id: LinkEnvironment.production.id,
            name: "Production",
            variables: production.variables,
            isBuiltIn: true
        )
        environments.insert(normalizedProduction, at: 0)
        environments.insert(normalizedDevelopment, at: 0)
    }

    private var environmentFileURL: URL {
        URL(fileURLWithPath: deepLinkStore.storagePath)
            .deletingLastPathComponent()
            .appendingPathComponent("environments.json")
    }

    private func monitor(_ fileURL: URL) {
        fileMonitor.start(fileURL: fileURL) { [weak self] in
            Task { @MainActor [weak self] in self?.scheduleExternalReload() }
        }
    }

    private func scheduleExternalReload() {
        externalReloadTask?.cancel()
        externalReloadTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard Task.isCancelled == false else { return }
            self?.loadForCurrentStorage()
        }
    }
}
