//
//  ContentView.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 22.05.2026.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: DeepLinkStore

    @State private var selectedItemID: DeepLinkItem.ID?
    @State private var titleText = ""
    @State private var urlText = ""
    @State private var searchText = ""
    @State private var simulatorTarget: SimulatorTarget = .booted
    @State private var customUDID = ""
    @State private var isOpening = false
    @State private var status: StatusMessage?

    private var selectedItem: DeepLinkItem? {
        store.items.first { $0.id == selectedItemID }
    }

    private var filteredItems: [DeepLinkItem] {
        let normalizedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedSearchText.isEmpty == false else {
            return store.items
        }

        return store.items.filter { item in
            item.title.localizedCaseInsensitiveContains(normalizedSearchText)
                || item.urlString.localizedCaseInsensitiveContains(normalizedSearchText)
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 300, ideal: 340)
        } detail: {
            detail
        }
    }

    private var sidebar: some View {
        VStack(spacing: 12) {
            TextField("Search", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .padding(.top, 12)

            List(selection: $selectedItemID) {
                ForEach(filteredItems) { item in
                    DeepLinkRow(item: item)
                        .tag(item.id)
                        .contextMenu {
                            Button("Open in Simulator") {
                                Task { await open(item: item) }
                            }

                            Divider()

                            Button("Delete", role: .destructive) {
                                delete(item)
                            }
                        }
                }
                .onMove(perform: store.move)
                .onDelete { indexSet in
                    deleteItems(at: indexSet)
                }
            }
            .listStyle(.sidebar)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    clearEditor()
                } label: {
                    Label("New", systemImage: "plus")
                }
            }
        }
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            editor

            Divider()

            simulatorSettings

            Spacer()

            statusView
        }
        .padding(24)
        .onChange(of: selectedItemID) { _, _ in
            fillEditorFromSelection()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(selectedItem == nil ? String(localized: "New Deep Link") : String(localized: "Edit Deep Link"))
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Save frequently used links and open them in the active iOS Simulator with xcrun simctl openurl.")
                .foregroundStyle(.secondary)
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Name")
                .font(.headline)

            TextField("For example: Product details", text: $titleText)
                .textFieldStyle(.roundedBorder)

            Text("URL")
                .font(.headline)

            TextField("For example: https://example.com/product/123 or myapp://product/123", text: $urlText)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

            HStack(spacing: 12) {
                Button(selectedItem == nil ? String(localized: "Save") : String(localized: "Save Changes")) {
                    saveEditor()
                }
                .buttonStyle(.borderedProminent)
                .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Open") {
                    Task { await openCurrentEditorURL() }
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(isOpening || urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if selectedItem != nil {
                    Button("Delete", role: .destructive) {
                        if let selectedItem {
                            delete(selectedItem)
                        }
                    }
                }
            }
        }
    }

    private var simulatorSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Simulator")
                .font(.headline)

            Picker("Target", selection: $simulatorTarget) {
                ForEach(SimulatorTarget.allCases) { target in
                    Text(target.title).tag(target)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)

            if simulatorTarget == .custom {
                TextField("Simulator UDID", text: $customUDID)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }

            Text("Booted simulator is enough for the usual workflow: start the iPhone Simulator you need, then click Open.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var statusView: some View {
        if let status {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: status.kind.systemImageName)
                    .foregroundStyle(status.kind == .success ? .green : .red)

                Text(status.text)
                    .font(.callout)
                    .textSelection(.enabled)
            }
            .padding(12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func saveEditor() {
        if let selectedItem {
            store.update(item: selectedItem, title: titleText, urlString: urlText)
            status = StatusMessage(kind: .success, text: String(localized: "Changes saved"))
        } else {
            store.add(title: titleText, urlString: urlText)
            selectedItemID = store.items.first?.id
            status = StatusMessage(kind: .success, text: String(localized: "Deep link saved"))
        }
    }

    private func clearEditor() {
        selectedItemID = nil
        titleText = ""
        urlText = ""
        status = nil
    }

    private func fillEditorFromSelection() {
        guard let selectedItem else {
            return
        }

        titleText = selectedItem.title
        urlText = selectedItem.urlString
    }

    private func openCurrentEditorURL() async {
        let temporaryItem = DeepLinkItem(
            title: titleText.isEmpty ? urlText : titleText,
            urlString: urlText
        )
        await open(item: temporaryItem)
    }

    private func open(item: DeepLinkItem) async {
        isOpening = true
        status = StatusMessage(kind: .success, text: String(localized: "Opening…"))

        do {
            let result = try await SimulatorOpenService.open(
                urlString: item.urlString,
                target: simulatorTarget,
                customUDID: customUDID
            )

            let commandOutput = [result.stderr, result.stdout]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.isEmpty == false }
                .joined(separator: "\n")

            status = StatusMessage(
                kind: .success,
                text: commandOutput.isEmpty
                    ? String(format: String(localized: "Opened: %@"), item.urlString)
                    : commandOutput
            )
        } catch {
            status = StatusMessage(kind: .error, text: error.localizedDescription)
        }

        isOpening = false
    }

    private func delete(_ item: DeepLinkItem) {
        store.delete(item)

        if selectedItemID == item.id {
            clearEditor()
        }

        status = StatusMessage(kind: .success, text: String(localized: "Deep link deleted"))
    }

    private func deleteItems(at indexSet: IndexSet) {
        let itemsToDelete = indexSet.compactMap { index in
            filteredItems.indices.contains(index) ? filteredItems[index] : nil
        }

        itemsToDelete.forEach(delete)
    }
}
