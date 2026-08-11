//
//  RaycastIntegrationViewModel.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 11.08.2026.
//

import AppKit
import Combine
import Foundation

@MainActor
final class RaycastIntegrationViewModel: ObservableObject {
    @Published private(set) var isRaycastInstalled = false

    private let workspace: NSWorkspace
    private let storeURL = URL(
        string: "https://www.raycast.com/shtefan_boblik/simulator-deep-linker"
    )!
    private let commandURL = URL(
        string: "raycast://extensions/shtefan_boblik/simulator-deep-linker/search-deep-links"
    )!

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
        refresh()
    }

    func refresh() {
        isRaycastInstalled = workspace.urlForApplication(toOpen: commandURL) != nil
    }

    func installExtension() {
        workspace.open(storeURL)
    }

    func openExtension() {
        if isRaycastInstalled {
            workspace.open(commandURL)
        } else {
            installExtension()
        }
    }
}
