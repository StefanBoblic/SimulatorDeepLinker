//
//  ContentView.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 22.05.2026.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum AppPage: String, CaseIterable, Identifiable {
    case links
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .links: String(localized: "Deep Links")
        case .history: String(localized: "Launch History")
        }
    }

    var systemImage: String {
        switch self {
        case .links: "link"
        case .history: "clock.arrow.circlepath"
        }
    }
}

struct ContentView: View {
    @ObservedObject var viewModel: DeepLinksViewModel
    @ObservedObject var historyViewModel: LaunchHistoryViewModel

    @State private var page: AppPage = .links
    @State private var isShowingQRCode = false

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 300, ideal: 340)
        } detail: {
            switch page {
            case .links:
                linkDetail
            case .history:
                LaunchHistoryView(viewModel: historyViewModel)
            }
        }
        .task { await viewModel.discoverTargets() }
        .sheet(isPresented: $isShowingQRCode) {
            QRCodeView(image: viewModel.qrImage, value: viewModel.resolvedURL)
        }
    }

    private var sidebar: some View {
        VStack(spacing: 10) {
            Picker("Section", selection: $page) {
                ForEach(AppPage.allCases) { page in
                    Label(page.title, systemImage: page.systemImage).tag(page)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.top, 12)

            if page == .links {
                filters

                List(selection: $viewModel.selectedIDs) {
                    ForEach(viewModel.filteredItems) { item in
                        DeepLinkRow(item: item)
                            .tag(item.id)
                            .contextMenu {
                                Button("Open") { Task { await open(item) } }
                                Button(item.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                                    viewModel.toggleFavorite(item)
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    viewModel.selectedIDs = [item.id]
                                    viewModel.deleteSelected()
                                }
                            }
                    }
                    .onMove(perform: viewModel.move)
                }
                .listStyle(.sidebar)
            } else {
                Spacer()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: viewModel.addFromClipboard) {
                    Label("Add from Clipboard", systemImage: "doc.on.clipboard")
                }

                Button(action: viewModel.createNew) {
                    Label("New", systemImage: "plus")
                }
            }
        }
    }

    private var filters: some View {
        VStack(spacing: 8) {
            TextField("Search", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)

            Picker("Group", selection: $viewModel.selectedGroup) {
                Text("All Groups").tag("")
                ForEach(viewModel.groups, id: \.self) { Text($0).tag($0) }
            }
        }
        .padding(.horizontal, 12)
    }

    private var linkDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                editor
                Divider()
                targetSettings
                Divider()
                utilityActions
                statusView
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.selectedItem == nil ? "New Deep Link" : "Edit Deep Link")
                .font(.largeTitle.weight(.semibold))
            Text("Save, organize, and open deep links on iOS and Android targets.")
                .foregroundStyle(.secondary)
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Name", text: $viewModel.titleText)
                .textFieldStyle(.roundedBorder)
            TextField("URL, for example {{BASE_URL}}/product/123", text: $viewModel.urlText)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

            HStack {
                TextField("Group", text: $viewModel.groupText)
                TextField("Tags, comma separated", text: $viewModel.tagsText)
                Toggle("Favorite", isOn: $viewModel.isFavorite)
                    .toggleStyle(.checkbox)
            }

            HStack {
                Button(viewModel.selectedItem == nil ? "Save" : "Save Changes", action: viewModel.save)
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Open") { Task { await viewModel.openCurrent() } }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(viewModel.isOpening || viewModel.urlText.isEmpty)

                if viewModel.selectedIDs.count > 1 {
                    Button("Open Selected (\(viewModel.selectedIDs.count))") {
                        Task { await viewModel.openSelected() }
                    }
                    Button("Delete Selected", role: .destructive, action: viewModel.deleteSelected)
                } else if viewModel.selectedItem != nil {
                    Button("Delete", role: .destructive, action: viewModel.deleteSelected)
                }
            }
        }
    }

    private var targetSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Target").font(.headline)
                Spacer()
                if viewModel.isDiscovering {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        Task { await viewModel.discoverTargets() }
                    }
                    .labelStyle(.iconOnly)
                }
            }

            Picker("Device", selection: $viewModel.selectedTargetID) {
                ForEach(viewModel.targets) { target in
                    Label {
                        Text(target.detail.isEmpty ? target.name : "\(target.name) — \(target.detail)")
                    } icon: {
                        Image(systemName: target.platform.systemImage)
                    }
                    .tag(target.id)
                }
            }

            if viewModel.selectedTarget.platform == .iOSDevice {
                TextField("Installed app bundle identifier", text: $viewModel.bundleIdentifier)
                    .textFieldStyle(.roundedBorder)
            }

            if viewModel.selectedTarget.platform == .android {
                TextField("Android package (optional)", text: $viewModel.androidPackage)
                    .textFieldStyle(.roundedBorder)
            }

            Picker("Environment", selection: $viewModel.selectedEnvironmentID) {
                ForEach(viewModel.environments) { Text($0.displayName).tag($0.id) }
            }

            if viewModel.resolvedURL != viewModel.urlText {
                LabeledContent("Resolved URL") {
                    Text(viewModel.resolvedURL)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                }
            }

            DisclosureGroup("Connect Android over Wi-Fi") {
                HStack {
                    TextField("IP address and port", text: $viewModel.adbAddress)
                    TextField("Pairing code", text: $viewModel.adbPairingCode)
                        .frame(width: 130)
                    Button("Pair") { Task { await viewModel.pairAndroidDevice() } }
                    Button("Connect") { Task { await viewModel.connectAndroidDevice() } }
                }
                .padding(.top, 8)
            }
        }
    }

    private var utilityActions: some View {
        HStack {
            Button("Show QR Code", systemImage: "qrcode") {
                viewModel.showQRCode()
                isShowingQRCode = viewModel.qrImage != nil
            }
            .disabled(viewModel.resolvedURL.isEmpty)

            Button("Import…", action: importLinks)
            Button("Export…", action: exportLinks)
            Spacer()
        }
    }

    @ViewBuilder
    private var statusView: some View {
        if let status = viewModel.status {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: status.kind.systemImageName)
                    .foregroundStyle(status.kind == .success ? .green : .red)
                Text(status.text)
                    .font(.callout)
                    .textSelection(.enabled)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func open(_ item: DeepLinkItem) async {
        viewModel.selectedIDs = [item.id]
        await viewModel.openSelected()
    }

    private func importLinks() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        viewModel.importLinks(from: url)
    }

    private func exportLinks() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "deeplinks.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        viewModel.exportLinks(to: url)
    }
}
