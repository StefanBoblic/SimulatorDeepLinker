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
            TextField("Поиск", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .padding(.top, 12)

            List(selection: $selectedItemID) {
                ForEach(filteredItems) { item in
                    DeepLinkRow(item: item)
                        .tag(item.id)
                        .contextMenu {
                            Button("Открыть в симуляторе") {
                                Task { await open(item: item) }
                            }

                            Divider()

                            Button("Удалить", role: .destructive) {
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
                    Label("Новый", systemImage: "plus")
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
            Text(selectedItem == nil ? "Новый диплинк" : "Редактирование диплинка")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Сохраняй частые ссылки и открывай их в активном iOS Simulator через xcrun simctl openurl.")
                .foregroundStyle(.secondary)
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Название")
                .font(.headline)

            TextField("Например: Карточка товара", text: $titleText)
                .textFieldStyle(.roundedBorder)

            Text("URL")
                .font(.headline)

            TextField("Например: https://example.com/product/123 или myapp://product/123", text: $urlText)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

            HStack(spacing: 12) {
                Button(selectedItem == nil ? "Сохранить" : "Сохранить изменения") {
                    saveEditor()
                }
                .buttonStyle(.borderedProminent)
                .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Открыть") {
                    Task { await openCurrentEditorURL() }
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(isOpening || urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if selectedItem != nil {
                    Button("Удалить", role: .destructive) {
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
            Text("Симулятор")
                .font(.headline)

            Picker("Target", selection: $simulatorTarget) {
                ForEach(SimulatorTarget.allCases) { target in
                    Text(target.title).tag(target)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)

            if simulatorTarget == .custom {
                TextField("UDID симулятора", text: $customUDID)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }

            Text("Для обычного сценария достаточно Booted simulator: сначала запусти нужный iPhone Simulator, потом нажми Открыть.")
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
            status = StatusMessage(kind: .success, text: "Изменения сохранены")
        } else {
            store.add(title: titleText, urlString: urlText)
            selectedItemID = store.items.first?.id
            status = StatusMessage(kind: .success, text: "Диплинк сохранён")
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
        status = StatusMessage(kind: .success, text: "Открываю…")

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
                text: commandOutput.isEmpty ? "Открыл: \(item.urlString)" : commandOutput
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

        status = StatusMessage(kind: .success, text: "Диплинк удалён")
    }

    private func deleteItems(at indexSet: IndexSet) {
        let itemsToDelete = indexSet.compactMap { index in
            filteredItems.indices.contains(index) ? filteredItems[index] : nil
        }

        itemsToDelete.forEach(delete)
    }
}
