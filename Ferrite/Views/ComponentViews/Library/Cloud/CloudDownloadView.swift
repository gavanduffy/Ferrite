//
//  CloudDownloadView.swift
//  Ferrite
//
//  Created by Brian Dashore on 6/6/24.
//

import SwiftUI

struct CloudDownloadView: View {
    @EnvironmentObject var navModel: NavigationViewModel
    @EnvironmentObject var debridManager: DebridManager

    @Store var debridSource: DebridSource

    @Binding var searchText: String
    @State private var showTransferBrowser = false
    @State private var transferHandle: DebridTransferHandle?
    @State private var transferFiles: [DebridTransferFile] = []
    @State private var transferTitle: String = ""
    // Confirmation state for destructive actions
    @State private var showDeleteConfirm = false
    @State private var pendingDeleteDownload: DebridCloudDownload?

    var body: some View {
        DisclosureGroup("Downloads") {
            ForEach(filteredDownloads, id: \.self) { cloudDownload in
                CloudDownloadRow(
                    cloudDownload: cloudDownload,
                    onSelect: { handleDownloadSelection(cloudDownload) },
                    onCopy: { UIPasteboard.general.string = cloudDownload.link },
                    onOpen: { if let url = URL(string: cloudDownload.link) { UIApplication.shared.open(url) } },
                    onDelete: { pendingDeleteDownload = cloudDownload; showDeleteConfirm = true }
                )
                .disabledAppearance(navModel.currentChoiceSheet != nil,
                                    dimmedOpacity: 0.7,
                                    animation: .easeOut(duration: 0.2))
                .tag(cloudDownload)
                .listRowBackground(Color.clear)
                .contextMenu {
                    contextMenuContent(for: cloudDownload)
                }
            }

            .onDelete(perform: deleteDownloads)

        }
        .sheet(isPresented: $showTransferBrowser) {
            transferBrowserView
        }
        // Deletion now uses a scheduled-delete + undo workflow.
        // Individual deletes are scheduled via `debridManager.scheduleRemoteDelete(...)`
        // and callers should present an undo toast. The old confirmation dialog is removed
        // in favor of the non-blocking undo flow.
    }

    private var filteredDownloads: [DebridCloudDownload] {
        debridSource.cloudDownloads.filter {
            searchText.isEmpty ? true : $0.fileName.lowercased().contains(searchText.lowercased())
        }
    }

    @ViewBuilder
    private var transferBrowserView: some View {
        if let transferHandle {
            DebridTransferBrowserView(
                debridSource: debridSource,
                handle: transferHandle,
                initialFiles: transferFiles,
                title: transferTitle,
                resultFromCloud: true
            )
        }
    }

    private func handleDownloadSelection(_ cloudDownload: DebridCloudDownload) {
        navModel.resultFromCloud = true
        navModel.selectedTitle = cloudDownload.fileName
        navModel.selectedMagnet = nil

        let fileLink = cloudDownload.link.isEmpty ? nil : cloudDownload.link
        transferFiles = [
            DebridTransferFile(
                id: cloudDownload.id,
                name: cloudDownload.fileName,
                link: fileLink
            )
        ]
        transferHandle = DebridTransferHandle(id: cloudDownload.id, kind: .webDownload)
        transferTitle = cloudDownload.fileName
        showTransferBrowser = true
    }

    @ViewBuilder
    private func contextMenuContent(for cloudDownload: DebridCloudDownload) -> some View {
        Button {
            UIPasteboard.general.string = cloudDownload.link
        } label: {
            Text("Copy download URL")
            Image(systemName: "doc.on.doc.fill")
        }

        Button {
            if let url = URL(string: cloudDownload.link) {
                navModel.activityItems = [url]
                navModel.currentChoiceSheet = .activity
            }
        } label: {
            Text("Share download URL")
            Image(systemName: "square.and.arrow.up.fill")
        }

        Button {
            if let url = URL(string: cloudDownload.link) {
                UIApplication.shared.open(url)
            }
        } label: {
            Text("Open in Safari")
            Image(systemName: "safari.fill")
        }

        // Get a streamable/transcoded link (provider-dependent). This uses DebridManager's helper
        // and then opens the action sheet so the user can Play/Copy/Share the resulting link.
        Button {
            Task {
                if !cloudDownload.link.isEmpty {
                    await debridManager.fetchStreamableLink(from: cloudDownload.link)
                    // Trigger the standard action sheet that reads debridManager.downloadUrl
                    navModel.currentChoiceSheet = .action
                }
            }
        } label: {
            Text("Get streamable link")
            Image(systemName: "play.rectangle.fill")
        }

        Button(role: .destructive) {
            // Schedule a remote delete with an undo window instead of immediate deletion.
            debridManager.scheduleRemoteDelete(cloudDownload)
            debridManager.logManager?.info("Scheduled delete for \(cloudDownload.fileName). Undo available.", description: "You can undo the delete from the toast.")
        } label: {
            Text("Delete download")
            Image(systemName: "trash.fill")
        }
    }

    private func deleteDownloads(at offsets: IndexSet) {
        // When user deletes from a list (bulk delete), schedule remote deletes so the action
        // can be undone. This avoids immediate destructive behavior.
        for index in offsets {
            if let cloudDownload = debridSource.cloudDownloads[safe: index] {
                debridManager.scheduleRemoteDelete(cloudDownload)
                debridManager.logManager?.info("Scheduled deletion for \(cloudDownload.fileName). Undo available.", description: "Use Undo to cancel deletion.")
            }
        }
    }
}

private struct CloudDownloadRow: View {
    @EnvironmentObject private var debridManager: DebridManager

    let cloudDownload: DebridCloudDownload
    let onSelect: () -> Void
    let onCopy: (DebridCloudDownload) -> Void
    let onOpen: (DebridCloudDownload) -> Void
    let onDelete: (DebridCloudDownload) -> Void

    // Placeholder: return an optional progress value (0.0 - 1.0) for the given download.
    // This is intentionally a local shim — real progress values can be wired up in DebridManager
    // and this function updated to read the real published progress dictionary.
    private func progressForDownload(_ download: DebridCloudDownload) -> Double? {
        // Read per-transfer progress published by DebridManager (if available).
        // This returns a normalized value 0.0...1.0 or nil if no entry exists.
        return debridManager.transferProgress?[download.id]
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 6) {
                    Text(cloudDownload.fileName)
                        .font(.callout)
                        .lineLimit(2)

                    // Secondary line with optional progress
                    if let progress = progressForDownload(cloudDownload) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Web download")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            // Progress bar for the download (linear)
                            ProgressView(value: progress) {
                                EmptyView()
                            }
                            .progressViewStyle(.linear)
                            .tint(Color.accentColor)
                            .frame(height: 6)
                        }
                    } else {
                        Text("Web download")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding(DesignTokens.Spacing.small)
            .liquidGlass(cornerRadius: DesignTokens.CornerRadius.medium)
        }
        .tint(.primary)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                onCopy(cloudDownload)
            } label: {
                Label("Copy URL", systemImage: "doc.on.doc.fill")
            }
            .tint(.blue)

            Button {
                onOpen(cloudDownload)
            } label: {
                Label("Open", systemImage: "safari.fill")
            }
            .tint(.green)

            Button(role: .destructive) {
                // Schedule remote delete with undo window instead of immediate delete.
                debridManager.scheduleRemoteDelete(cloudDownload)
                debridManager.logManager?.info("Scheduled delete for \(cloudDownload.fileName). Undo available.", description: "Tap Undo in the toast to cancel.")
            } label: {
                Label("Delete", systemImage: "trash.fill")
            }
        }
    }
}

 // MARK: - Previews (file scope)
 @MainActor struct CloudDownloadView_Previews: PreviewProvider {
     static var previews: some View {
         let debridManager = DebridManager()
         let navModel = NavigationViewModel()
         let logManager = LoggingManager()

         return CloudDownloadView(debridSource: RealDebrid() as DebridSource, searchText: .constant(""))
             .environmentObject(debridManager)
             .environmentObject(navModel)
             .environmentObject(logManager)
             .padding()
             .previewLayout(.sizeThatFits)
     }
 }
