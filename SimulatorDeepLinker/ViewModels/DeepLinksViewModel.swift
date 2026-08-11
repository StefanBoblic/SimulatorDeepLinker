//
//  DeepLinksViewModel.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 11.08.2026.
//

import AppKit
import Combine
import Foundation

@MainActor
final class DeepLinksViewModel: ObservableObject {
    @Published private(set) var items: [DeepLinkItem] = []
    @Published var selectedIDs: Set<DeepLinkItem.ID> = [] {
        didSet { loadSelectionIntoEditor() }
    }
    @Published var titleText = ""
    @Published var urlText = ""
    @Published var groupText = ""
    @Published var tagsText = ""
    @Published var isFavorite = false
    @Published var searchText = ""
    @Published var selectedGroup = ""
    @Published private(set) var targets: [DeviceTarget] = [.bootedSimulator]
    @Published var selectedTargetID = DeviceTarget.bootedSimulator.id
    @Published var bundleIdentifier = ""
    @Published var androidPackage = ""
    @Published var adbAddress = ""
    @Published var adbPairingCode = ""
    @Published var selectedEnvironmentID = LinkEnvironment.none.id
    @Published private(set) var isDiscovering = false
    @Published private(set) var isOpening = false
    @Published var status: StatusMessage?
    @Published var qrImage: NSImage?

    private let store: DeepLinkStore
    private let historyStore: LaunchHistoryStore
    private let environmentStore: EnvironmentStore
    private let discoveryService: any DeviceDiscovering
    private let openingService: any DeepLinkOpening
    private let clipboardService: any ClipboardReading
    private let qrCodeGenerator: any QRCodeGenerating
    private let androidConnectionService: any AndroidDeviceConnecting
    private var cancellables: Set<AnyCancellable> = []

    init(
        store: DeepLinkStore,
        historyStore: LaunchHistoryStore,
        environmentStore: EnvironmentStore,
        discoveryService: (any DeviceDiscovering)? = nil,
        openingService: (any DeepLinkOpening)? = nil,
        clipboardService: (any ClipboardReading)? = nil,
        qrCodeGenerator: (any QRCodeGenerating)? = nil,
        androidConnectionService: (any AndroidDeviceConnecting)? = nil
    ) {
        self.store = store
        self.historyStore = historyStore
        self.environmentStore = environmentStore
        self.discoveryService = discoveryService ?? DeviceDiscoveryService()
        self.openingService = openingService ?? DeepLinkOpeningService()
        self.clipboardService = clipboardService ?? SystemClipboardService()
        self.qrCodeGenerator = qrCodeGenerator ?? QRCodeGenerator()
        self.androidConnectionService = androidConnectionService ?? AndroidDeviceConnectionService()
        items = store.items

        store.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in self?.items = items }
            .store(in: &cancellables)
    }

    var filteredItems: [DeepLinkItem] {
        items.filter { item in
            let matchesGroup = selectedGroup.isEmpty || item.group == selectedGroup
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = query.isEmpty
                || item.title.localizedCaseInsensitiveContains(query)
                || item.urlString.localizedCaseInsensitiveContains(query)
                || item.tags.contains { $0.localizedCaseInsensitiveContains(query) }
            return matchesGroup && matchesSearch
        }
    }

    var groups: [String] {
        Array(Set(items.map(\.group).filter { $0.isEmpty == false })).sorted()
    }

    var selectedItem: DeepLinkItem? {
        guard selectedIDs.count == 1, let id = selectedIDs.first else { return nil }
        return items.first { $0.id == id }
    }

    var selectedTarget: DeviceTarget {
        targets.first { $0.id == selectedTargetID } ?? .bootedSimulator
    }

    var environments: [LinkEnvironment] {
        [.none] + environmentStore.environments
    }

    var resolvedURL: String {
        let variables = environments.first { $0.id == selectedEnvironmentID }?.variables ?? [:]
        return EnvironmentResolver.resolve(urlText, variables: variables)
    }

    func createNew() {
        selectedIDs = []
        titleText = ""
        urlText = ""
        groupText = ""
        tagsText = ""
        isFavorite = false
        status = nil
    }

    func save() {
        let tags = parsedTags
        if let selectedItem {
            store.update(
                item: selectedItem,
                title: titleText,
                urlString: urlText,
                group: groupText,
                tags: tags,
                isFavorite: isFavorite
            )
            status = .init(kind: .success, text: String(localized: "Changes saved"))
        } else if let newItem = store.add(
            title: titleText,
            urlString: urlText,
            group: groupText,
            tags: tags,
            isFavorite: isFavorite
        ) {
            selectedIDs = [newItem.id]
            status = .init(kind: .success, text: String(localized: "Deep link saved"))
        }
    }

    func deleteSelected() {
        guard selectedIDs.isEmpty == false else { return }
        store.delete(ids: selectedIDs)
        createNew()
        status = .init(kind: .success, text: String(localized: "Deep link deleted"))
    }

    func toggleFavorite(_ item: DeepLinkItem) {
        store.toggleFavorite(item)
    }

    func move(from source: IndexSet, to destination: Int) {
        guard searchText.isEmpty, selectedGroup.isEmpty else { return }
        store.move(from: source, to: destination)
    }

    func discoverTargets() async {
        isDiscovering = true
        let discoveredTargets = await discoveryService.discover()
        targets = discoveredTargets
        if discoveredTargets.contains(where: { $0.id == selectedTargetID }) == false {
            selectedTargetID = DeviceTarget.bootedSimulator.id
        }
        isDiscovering = false
    }

    func pairAndroidDevice() async {
        await runAndroidConnection {
            try await androidConnectionService.pair(address: adbAddress, code: adbPairingCode)
        }
    }

    func connectAndroidDevice() async {
        await runAndroidConnection {
            try await androidConnectionService.connect(address: adbAddress)
        }
    }

    func openCurrent() async {
        let item = DeepLinkItem(
            title: titleText.isEmpty ? resolvedURL : titleText,
            urlString: resolvedURL,
            group: groupText,
            tags: parsedTags,
            isFavorite: isFavorite
        )
        await open(item)
    }

    func openSelected() async {
        let selectedItems = items.filter { selectedIDs.contains($0.id) }
        guard selectedItems.isEmpty == false else {
            await openCurrent()
            return
        }
        for item in selectedItems {
            await open(item)
        }
    }

    func showQRCode() {
        qrImage = qrCodeGenerator.image(for: resolvedURL)
    }

    func addFromClipboard() {
        guard let clipboardValue = clipboardService.string()?.trimmingCharacters(in: .whitespacesAndNewlines),
              clipboardValue.isEmpty == false else {
            status = .init(kind: .error, text: String(localized: "The clipboard does not contain a URL."))
            return
        }
        createNew()
        urlText = clipboardValue
        titleText = URL(string: clipboardValue)?.host ?? clipboardValue
    }

    func importLinks(from fileURL: URL) {
        do {
            let count = try store.importDeepLinks(from: fileURL)
            status = .init(
                kind: .success,
                text: String(format: String(localized: "Imported %d links."), count)
            )
        } catch {
            status = .init(kind: .error, text: error.localizedDescription)
        }
    }

    func exportLinks(to fileURL: URL) {
        do {
            try store.exportDeepLinks(to: fileURL)
            status = .init(kind: .success, text: String(localized: "Links exported."))
        } catch {
            status = .init(kind: .error, text: error.localizedDescription)
        }
    }

    private func open(_ item: DeepLinkItem) async {
        isOpening = true
        let environment = environments.first { $0.id == selectedEnvironmentID }
        let url = EnvironmentResolver.resolve(item.urlString, variables: environment?.variables ?? [:])

        do {
            let output = try await openingService.open(
                urlString: url,
                on: selectedTarget,
                bundleIdentifier: bundleIdentifier,
                androidPackage: androidPackage
            )
            let message = output.isEmpty
                ? String(format: String(localized: "Opened: %@"), url)
                : output
            status = .init(kind: .success, text: message)
            historyStore.record(historyEntry(for: item, url: url, succeeded: true, message: message))
        } catch {
            status = .init(kind: .error, text: error.localizedDescription)
            historyStore.record(historyEntry(for: item, url: url, succeeded: false, message: error.localizedDescription))
        }
        isOpening = false
    }

    private func runAndroidConnection(_ operation: () async throws -> String) async {
        isDiscovering = true
        do {
            let output = try await operation()
            status = .init(kind: .success, text: output)
            targets = await discoveryService.discover()
        } catch {
            status = .init(kind: .error, text: error.localizedDescription)
        }
        isDiscovering = false
    }

    private func historyEntry(
        for item: DeepLinkItem,
        url: String,
        succeeded: Bool,
        message: String
    ) -> LaunchHistoryEntry {
        LaunchHistoryEntry(
            linkTitle: item.title,
            urlString: url,
            targetName: selectedTarget.name,
            platform: selectedTarget.platform,
            succeeded: succeeded,
            message: message
        )
    }

    private func loadSelectionIntoEditor() {
        guard let item = selectedItem else { return }
        titleText = item.title
        urlText = item.urlString
        groupText = item.group
        tagsText = item.tags.joined(separator: ", ")
        isFavorite = item.isFavorite
    }

    private var parsedTags: [String] {
        tagsText.split(separator: ",").map(String.init)
    }
}
