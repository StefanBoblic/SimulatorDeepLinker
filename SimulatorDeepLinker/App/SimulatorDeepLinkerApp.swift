//
//  SimulatorDeepLinkerApp.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 22.05.2026.
//

import SwiftUI

// MARK: - App

@main
struct SimulatorDeepLinkerApp: App {
    @StateObject private var deepLinksViewModel: DeepLinksViewModel
    @StateObject private var historyViewModel: LaunchHistoryViewModel
    @StateObject private var storageSettingsViewModel: StorageSettingsViewModel
    @StateObject private var raycastIntegrationViewModel: RaycastIntegrationViewModel
    @StateObject private var environmentStore: EnvironmentStore

    init() {
        let deepLinkStore = DeepLinkStore()
        let launchHistoryStore = LaunchHistoryStore()
        let environmentStore = EnvironmentStore(deepLinkStore: deepLinkStore)

        _deepLinksViewModel = StateObject(
            wrappedValue: DeepLinksViewModel(
                store: deepLinkStore,
                historyStore: launchHistoryStore,
                environmentStore: environmentStore
            )
        )
        _historyViewModel = StateObject(
            wrappedValue: LaunchHistoryViewModel(store: launchHistoryStore)
        )
        _storageSettingsViewModel = StateObject(
            wrappedValue: StorageSettingsViewModel(store: deepLinkStore)
        )
        _raycastIntegrationViewModel = StateObject(wrappedValue: RaycastIntegrationViewModel())
        _environmentStore = StateObject(wrappedValue: environmentStore)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: deepLinksViewModel,
                historyViewModel: historyViewModel
            )
                .frame(minWidth: 860, minHeight: 560)
        }

        Settings {
            StorageSettingsView(
                viewModel: storageSettingsViewModel,
                environmentStore: environmentStore,
                raycastViewModel: raycastIntegrationViewModel
            )
        }
    }
}
