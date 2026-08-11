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
    @ObservedObject var viewModel: StorageSettingsViewModel
    @ObservedObject var environmentStore: EnvironmentStore

    var body: some View {
        TabView {
            storageSettings
                .tabItem { Label("Storage", systemImage: "externaldrive") }

            EnvironmentSettingsView(store: environmentStore)
                .tabItem { Label("Environments", systemImage: "slider.horizontal.3") }
        }
        .padding(8)
        .frame(width: 680, height: 440)
    }

    private var storageSettings: some View {
        Form {
            Section("Shared Storage") {
                LabeledContent("Location") {
                    Text(viewModel.usesCustomStorageFile ? "Custom file" : "Default file")
                        .foregroundStyle(.secondary)
                }

                Text(viewModel.storagePath)
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

                Button("Use Default File", action: viewModel.useDefaultStorageFile)
                    .disabled(viewModel.usesCustomStorageFile == false)
            }

            Section("External Apps") {
                Text("External tools can read and write this JSON file. Changes are reloaded automatically while SimulatorDeepLinker is running.")
                    .foregroundStyle(.secondary)

                if let error = viewModel.storageError {
                    feedback(error, isError: true)
                } else if let text = viewModel.feedbackText {
                    feedback(text, isError: viewModel.feedbackIsError)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func feedback(_ text: String, isError: Bool) -> some View {
        Label(text, systemImage: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            .foregroundStyle(isError ? .red : .green)
            .textSelection(.enabled)
    }

    private func chooseExistingFile() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Choose Deep Link Storage")
        panel.prompt = String(localized: "Use File")
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = currentDirectoryURL
        guard panel.runModal() == .OK, let fileURL = panel.url else { return }
        viewModel.useExistingStorageFile(at: fileURL)
    }

    private func createSharedCopy() {
        let panel = NSSavePanel()
        panel.title = String(localized: "Create Shared Storage")
        panel.prompt = String(localized: "Create")
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "deeplinks.json"
        panel.directoryURL = currentDirectoryURL
        guard panel.runModal() == .OK, let fileURL = panel.url else { return }
        viewModel.createSharedStorageFile(at: fileURL)
    }

    private func copyPath() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(viewModel.storagePath, forType: .string)
        viewModel.setFeedback(String(localized: "Storage path copied."))
    }

    private func revealStorageFile() {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: viewModel.storagePath)])
    }

    private var currentDirectoryURL: URL? {
        guard viewModel.storagePath.isEmpty == false else { return nil }
        return URL(fileURLWithPath: viewModel.storagePath).deletingLastPathComponent()
    }
}

private struct EnvironmentSettingsView: View {
    @ObservedObject var store: EnvironmentStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Environments").font(.title2.weight(.semibold))
            Text("Use {{KEY}} or ${KEY} in a deep link, then define values for development, staging, or production.")
                .foregroundStyle(.secondary)

            List {
                ForEach($store.environments) { $environment in
                    EnvironmentEditorRow(environment: $environment)
                        .deleteDisabled(environment.isBuiltIn)
                }
                .onDelete(perform: store.delete)
            }

            HStack {
                Button("Add Environment", systemImage: "plus") { _ = store.add() }
                Spacer()
            }

            LabeledContent("Shared File") {
                Text(store.storagePath)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }

            if let storageError = store.storageError {
                Label(storageError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
        .padding(18)
    }
}

private struct EnvironmentEditorRow: View {
    @Binding var environment: LinkEnvironment
    @State private var variablesText: String

    init(environment: Binding<LinkEnvironment>) {
        _environment = environment
        _variablesText = State(initialValue: environment.wrappedValue.variables
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "\n"))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if environment.isBuiltIn {
                    Text(environment.displayName)
                        .font(.headline)
                    Label("Built In", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    TextField("Environment name", text: $environment.name)
                        .font(.headline)
                }
            }
            TextEditor(text: $variablesText)
                .font(.system(.callout, design: .monospaced))
                .frame(minHeight: 52)
                .onChange(of: variablesText) { _, value in
                    environment.variables = parse(value)
                }
        }
        .padding(.vertical, 6)
    }

    private func parse(_ source: String) -> [String: String] {
        let pairs: [(String, String)] = source.split(whereSeparator: { $0.isNewline }).compactMap { line in
            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            guard key.isEmpty == false else { return nil }
            return (key, parts[1].trimmingCharacters(in: .whitespaces))
        }
        return pairs.reduce(into: [:]) { result, pair in result[pair.0] = pair.1 }
    }
}
