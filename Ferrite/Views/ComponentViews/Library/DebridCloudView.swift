//
//  DebridCloudView.swift
//  Ferrite
//
//  Created by Brian Dashore on 12/31/22.
//

import SwiftUI

struct DebridCloudView: View {
    @EnvironmentObject var debridManager: DebridManager
    @EnvironmentObject var navModel: NavigationViewModel
    @EnvironmentObject var logManager: LoggingManager

    @Store var debridSource: DebridSource

    @Binding var searchText: String
    @State private var selectedDownloads: Set<DebridCloudDownload> = []
    @State private var selectedMagnets: Set<DebridCloudMagnet> = []
    @State private var showBulkAlert = false
    @State private var bulkAlertMessage = ""
    @State private var skippedMagnets: [DebridCloudMagnet] = []
    @State private var showSkippedMagnetsSheet = false
    @State private var selectedSkippedMagnet: DebridCloudMagnet?
    
    // Segmented control state
    @State private var selectedSegment: CloudSegment = .current
    
    // Cached filtered history for performance
    @State private var cachedFilteredHistory: [DebridCloudHistoryItem] = []
    
    enum CloudSegment: String, CaseIterable {
        case current = "Current"
        case past = "Past"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Segmented control
            Picker("View", selection: $selectedSegment) {
                ForEach(CloudSegment.allCases, id: \.self) { segment in
                    Text(segment.rawValue).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DesignTokens.Spacing.medium)
            .padding(.vertical, DesignTokens.Spacing.small)
            
            // Content based on selection
            if selectedSegment == .current {
                currentCloudView
            } else {
                pastCloudView
            }
        }
        .overlay {
            if !searchText.isEmpty && isCloudEmpty {
                EmptyInstructionView(
                    systemName: "magnifyingglass",
                    title: "No items found",
                    message: "Try a different search term"
                )
            }
        }
        .task {
            await debridManager.fetchDebridCloud()
        }
        .refreshable {
            await debridManager.fetchDebridCloud(bypassTTL: true)
        }
        .onChange(of: debridManager.selectedDebridSource?.id) { newType in
            if newType != nil {
                selectedDownloads.removeAll()
                selectedMagnets.removeAll()
                updateFilteredHistory()
                Task {
                    await debridManager.fetchDebridCloud()
                }
            }
        }
        .onChange(of: debridSource.cloudDownloads) { _ in
            updateFilteredHistory()
        }
        .onChange(of: debridSource.cloudMagnets) { _ in
            updateFilteredHistory()
        }
        .onChange(of: searchText) { _ in
            updateFilteredHistory()
        }
        .onChange(of: debridManager.cloudHistory) { _ in
            updateFilteredHistory()
        }
        .onAppear {
            updateFilteredHistory()
        }
        .toolbar {
            if selectedSegment == .current {
                currentToolbar
            }
        }
        .alert("Bulk unrestrict", isPresented: $showBulkAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(bulkAlertMessage)
        }
        .sheet(isPresented: $showSkippedMagnetsSheet) {
            BulkMagnetPickerView(
                debridSource: debridSource,
                magnets: skippedMagnets,
                selectedMagnet: $selectedSkippedMagnet
            )
        }
        .sheet(item: $selectedSkippedMagnet) { magnet in
            DebridTransferBrowserView(
                debridSource: debridSource,
                handle: DebridTransferHandle(id: magnet.id, kind: .torrent),
                title: magnet.fileName,
                resultFromCloud: true
            )
        }
    }
    
    // MARK: - Current Cloud View
    
    private var currentCloudView: some View {
        List(selection: listSelection) {
            CloudDownloadView(debridSource: debridSource, searchText: $searchText)
            CloudMagnetView(debridSource: debridSource, searchText: $searchText)
        }
        .listStyle(.plain)
    }
    
    // MARK: - Past Cloud View
    
    private var pastCloudView: some View {
        List {
            ForEach(cachedFilteredHistory, id: \.historyKey) { item in
                CloudHistoryRow(historyItem: item)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
    }
    
    private var isCloudEmpty: Bool {
        if selectedSegment == .current {
            return debridSource.cloudDownloads.filter {
                searchText.isEmpty ? true : $0.fileName.lowercased().contains(searchText.lowercased())
            }.isEmpty && debridSource.cloudMagnets.filter {
                searchText.isEmpty ? true : $0.fileName.lowercased().contains(searchText.lowercased())
            }.isEmpty
        } else {
            return cachedFilteredHistory.isEmpty
        }
    }

    private func updateFilteredHistory() {
        let currentKeys = debridManager.getCurrentCloudHistoryKeys(for: debridSource.id)
        
        cachedFilteredHistory = debridManager.cloudHistory
            .filter { item in
                // Filter by provider
                item.providerId == debridSource.id &&
                // Exclude items still in current cloud
                !currentKeys.contains(item.historyKey) &&
                // Filter by search text
                (searchText.isEmpty || item.name.lowercased().contains(searchText.lowercased()))
            }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var currentToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Menu("Bulk Actions") {
                Button("Select all downloads") {
                    selectedDownloads = Set(debridSource.cloudDownloads)
                }

                Button("Select all magnets") {
                    selectedMagnets = Set(debridSource.cloudMagnets)
                }

                if !selectedDownloads.isEmpty || !selectedMagnets.isEmpty {
                    Button("Bulk unrestrict") {
                        Task {
                            await bulkUnrestrict()
                        }
                    }
                }

                if !selectedDownloads.isEmpty {
                    Button("Share downloads") {
                        let urls = selectedDownloads.compactMap { URL(string: $0.link) }
                        if !urls.isEmpty {
                            navModel.activityItems = urls
                            navModel.currentChoiceSheet = .activity
                        }
                    }

                    Button("Copy download URLs") {
                        let urls = selectedDownloads.map { $0.link }.filter { !$0.isEmpty }
                        UIPasteboard.general.string = urls.joined(separator: "\n")
                    }

                    Button("Delete downloads", role: .destructive) {
                        Task {
                            for download in selectedDownloads {
                                await debridManager.deleteCloudDownload(download)
                            }
                            selectedDownloads.removeAll()
                        }
                    }
                }

                if !selectedMagnets.isEmpty {
                    Button("Copy magnet hashes") {
                        let hashes = selectedMagnets.map { $0.hash }
                        UIPasteboard.general.string = hashes.joined(separator: "\n")
                    }

                    Button("Delete magnets", role: .destructive) {
                        Task {
                            for magnet in selectedMagnets {
                                await debridManager.deleteUserMagnet(magnet)
                            }
                            selectedMagnets.removeAll()
                        }
                    }
                }
            }
        }
    }

    private var listSelection: Binding<Set<AnyHashable>> {
        Binding(
            get: {
                var combined = Set<AnyHashable>()
                combined.formUnion(selectedDownloads.map { AnyHashable($0) })
                combined.formUnion(selectedMagnets.map { AnyHashable($0) })
                return combined
            },
            set: { newValue in
                selectedDownloads = Set(newValue.compactMap { $0.base as? DebridCloudDownload })
                selectedMagnets = Set(newValue.compactMap { $0.base as? DebridCloudMagnet })
            }
        )
    }

    private func bulkUnrestrict() async {
        logManager.updateIndeterminateToast("Resolving links", cancelAction: nil)

        var resolvedUrls: [URL] = []
        var skippedNeedsSelection = 0
        var skippedErrors = 0
        var skippedMagnetsList: [DebridCloudMagnet] = []

        for download in selectedDownloads {
            do {
                let resolved = try await debridSource.checkUserDownloads(link: download.link) ?? download.link
                if let url = URL(string: resolved) {
                    resolvedUrls.append(url)
                } else {
                    skippedErrors += 1
                }
            } catch {
                skippedErrors += 1
            }
        }

        for magnet in selectedMagnets {
            let handle = DebridTransferHandle(id: magnet.id, kind: .torrent)
            do {
                let files = try await debridSource.fetchTransferFiles(handle)
                if files.count == 1, let file = files.first {
                    let result = try await debridSource.unrestrictTransferFile(handle, file: file)
                    if let url = URL(string: result.urlString) {
                        resolvedUrls.append(url)
                    } else {
                        skippedErrors += 1
                    }
                } else {
                    skippedNeedsSelection += 1
                    skippedMagnetsList.append(magnet)
                }
            } catch {
                skippedErrors += 1
            }
        }

        logManager.hideIndeterminateToast()

        if !resolvedUrls.isEmpty {
            navModel.activityItems = resolvedUrls
            navModel.currentChoiceSheet = .activity
        }

        if skippedNeedsSelection > 0 || skippedErrors > 0 {
            var messageParts: [String] = []
            if skippedNeedsSelection > 0 {
                messageParts.append("\(skippedNeedsSelection) item(s) need file selection.")
            }
            if skippedErrors > 0 {
                messageParts.append("\(skippedErrors) item(s) failed to resolve.")
            }
            bulkAlertMessage = messageParts.joined(separator: " ")
            showBulkAlert = true
        }

        if !skippedMagnetsList.isEmpty {
            skippedMagnets = skippedMagnetsList
            showSkippedMagnetsSheet = true
        }
    }
}

// MARK: - Cloud History Row

private struct CloudHistoryRow: View {
    let historyItem: DebridCloudHistoryItem
    
    private var iconName: String {
        historyItem.kind == .webDownload ? "arrow.down.circle" : "link.circle"
    }
    
    private var iconColor: Color {
        historyItem.kind == .webDownload ? .blue : .purple
    }
    
    private var kindLabel: String {
        historyItem.kind == .webDownload ? "Download" : "Magnet"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(historyItem.name)
                    .font(.callout)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Text(kindLabel)
                    Text("•")
                    Text(historyItem.dateAdded, style: .date)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                if !historyItem.linkOrHash.isEmpty {
                    Text(historyItem.linkOrHash)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            
            Spacer()
        }
        .padding(DesignTokens.Spacing.small)
        .liquidGlass(cornerRadius: DesignTokens.CornerRadius.medium)
        .contextMenu {
            Button {
                UIPasteboard.general.string = historyItem.linkOrHash
            } label: {
                Text("Copy \(historyItem.kind == .webDownload ? "link" : "hash")")
                Image(systemName: "doc.on.doc.fill")
            }
        }
    }
}

private struct BulkMagnetPickerView: View {
    @Environment(\.dismiss) var dismiss

    let debridSource: DebridSource
    let magnets: [DebridCloudMagnet]
    @Binding var selectedMagnet: DebridCloudMagnet?

    var body: some View {
        NavigationStack {
            List(magnets, id: \.self) { magnet in
                Button {
                    selectedMagnet = magnet
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(magnet.fileName)
                            .font(.callout)
                            .lineLimit(2)
                        Text(magnet.status.capitalizingFirstLetter())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.primary)
            }
            .navigationTitle("Pick Files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
