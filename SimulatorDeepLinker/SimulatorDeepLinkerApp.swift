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
    @StateObject private var deepLinkStore = DeepLinkStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(deepLinkStore)
                .frame(minWidth: 860, minHeight: 560)
        }
    }
}
