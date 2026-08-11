//
//  StorageSettingsViewModel.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 11.08.2026.
//

import Combine
import Foundation

@MainActor
final class StorageSettingsViewModel: ObservableObject {
    @Published private(set) var storagePath = ""
    @Published private(set) var usesCustomStorageFile = false
    @Published private(set) var storageError: String?
    @Published var feedbackText: String?
    @Published var feedbackIsError = false

    private let store: DeepLinkStore
    private var cancellables: Set<AnyCancellable> = []

    init(store: DeepLinkStore) {
        self.store = store
        storagePath = store.storagePath
        usesCustomStorageFile = store.usesCustomStorageFile
        storageError = store.storageError

        store.$storagePath.assign(to: &$storagePath)
        store.$usesCustomStorageFile.assign(to: &$usesCustomStorageFile)
        store.$storageError.assign(to: &$storageError)
    }

    func useExistingStorageFile(at fileURL: URL) {
        perform {
            try store.useExistingStorageFile(at: fileURL)
            return String(localized: "Existing storage file selected.")
        }
    }

    func createSharedStorageFile(at fileURL: URL) {
        perform {
            try store.createSharedStorageFile(at: fileURL)
            return String(localized: "Shared storage file created.")
        }
    }

    func useDefaultStorageFile() {
        perform {
            try store.useDefaultStorageFile()
            return String(localized: "Default storage file selected. The custom file remains unchanged.")
        }
    }

    func setFeedback(_ text: String, isError: Bool = false) {
        feedbackText = text
        feedbackIsError = isError
    }

    private func perform(_ operation: () throws -> String) {
        do {
            setFeedback(try operation())
        } catch {
            setFeedback(
                String(
                    format: String(localized: "Could not change the storage file: %@"),
                    error.localizedDescription
                ),
                isError: true
            )
        }
    }
}
