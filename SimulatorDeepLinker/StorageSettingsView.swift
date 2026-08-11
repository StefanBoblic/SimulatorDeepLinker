//
//  StorageSettingsView.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 11.08.2026.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct StorageSettingsView: View {
    @EnvironmentObject private var store: DeepLinkStore

    @State private var feedbackText: String?
    @State private var feedbackIsError = false

    var body: some View {
        Form {
            Section("Shared Storage") {
                LabeledContent("Location") {
                    Text(
                        store.usesCustomStorageFile
                            ? String(localized: "Custom file")
                            : String(localized: "Default file")
                    )
                        .foregroundStyle(.secondary)
                }

                Text(store.storagePath)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Button("Choose Existing File…", action: chooseExistingFile)
                    Button("Create Shared Copy…", action: createSharedCopy)

                    Spacer()

                    Button("Copy Path", action: copyPath)
                    Button("Show in Finder", action: revealStorageFile)
                }

                Button("Use Default File", action: useDefaultFile)
                    .disabled(store.usesCustomStorageFile == false)
            }

            Section("External Apps") {
                Text("External tools can read and write this JSON file. Changes are reloaded automatically while SimulatorDeepLinker is running.")
                    .foregroundStyle(.secondary)

                if let error = store.storageError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                } else if let feedbackText {
                    Label(
                        feedbackText,
                        systemImage: feedbackIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
                    )
                    .foregroundStyle(feedbackIsError ? .red : .green)
                    .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .frame(width: 660, height: 390)
    }

    private func chooseExistingFile() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Choose Deep Link Storage")
        panel.message = String(localized: "Choose an existing SimulatorDeepLinker JSON file. Its links will replace the current list without changing the previous file.")
        panel.prompt = String(localized: "Use File")
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = currentDirectoryURL

        guard panel.runModal() == .OK, let fileURL = panel.url else { return }

        performStorageChange {
            try store.useExistingStorageFile(at: fileURL)
            return String(localized: "Existing storage file selected.")
        }
    }

    private func createSharedCopy() {
        let panel = NSSavePanel()
        panel.title = String(localized: "Create Shared Storage")
        panel.message = String(localized: "Create a copy of the current links and use it as the new storage file. The previous file remains unchanged.")
        panel.prompt = String(localized: "Create")
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "deeplinks.json"
        panel.directoryURL = currentDirectoryURL

        guard panel.runModal() == .OK, let fileURL = panel.url else { return }

        performStorageChange {
            try store.createSharedStorageFile(at: fileURL)
            return String(localized: "Shared storage file created.")
        }
    }

    private func useDefaultFile() {
        performStorageChange {
            try store.useDefaultStorageFile()
            return String(localized: "Default storage file selected. The custom file remains unchanged.")
        }
    }

    private func performStorageChange(_ operation: () throws -> String) {
        do {
            feedbackText = try operation()
            feedbackIsError = false
        } catch {
            feedbackText = String(
                format: String(localized: "Could not change the storage file: %@"),
                error.localizedDescription
            )
            feedbackIsError = true
        }
    }

    private func copyPath() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(store.storagePath, forType: .string)
        feedbackText = String(localized: "Storage path copied.")
        feedbackIsError = false
    }

    private func revealStorageFile() {
        NSWorkspace.shared.activateFileViewerSelecting([
            URL(fileURLWithPath: store.storagePath)
        ])
    }

    private var currentDirectoryURL: URL? {
        guard store.storagePath.isEmpty == false else { return nil }
        return URL(fileURLWithPath: store.storagePath).deletingLastPathComponent()
    }
}
