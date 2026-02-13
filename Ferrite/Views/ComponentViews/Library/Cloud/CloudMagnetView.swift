//
//  CloudMagnetView.swift
//  Ferrite
//
//  Created by Brian Dashore on 6/6/24.
//

import SwiftUI

struct CloudMagnetView: View {
    @EnvironmentObject var navModel: NavigationViewModel
    @EnvironmentObject var debridManager: DebridManager

    @Store var debridSource: DebridSource

    @Binding var searchText: String
    @State private var showTransferBrowser = false
    @State private var transferHandle: DebridTransferHandle?
    @State private var transferTitle: String = ""
    // Confirmation state for destructive actions
    @State private var showDeleteConfirm: Bool = false
    @State private var pendingDeleteMagnet: DebridCloudMagnet?

    var body: some View {
        DisclosureGroup("Magnets") {
            ForEach(debridSource.cloudMagnets.filter {
                searchText.isEmpty ? true : $0.fileName.lowercased().contains(searchText.lowercased())
            }, id: \.self) { cloudMagnet in
                Button {
                    if debridSource.cachedStatus.contains(cloudMagnet.status), !cloudMagnet.links.isEmpty {
                        navModel.resultFromCloud = true
                        navModel.selectedTitle = cloudMagnet.fileName
                        navModel.selectedMagnet = nil
                        transferHandle = DebridTransferHandle(id: cloudMagnet.id, kind: .torrent)
                        transferTitle = cloudMagnet.fileName
                        showTransferBrowser = true
                    }
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(statusColor(cloudMagnet.status))
                            .frame(width: 10, height: 10)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(cloudMagnet.fileName)
                                .font(.callout)
                                .lineLimit(2)

                            HStack(spacing: 8) {
                                Text(cloudMagnet.status.capitalizingFirstLetter())
                                Text("\(cloudMagnet.links.count) files")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)

                            // Placeholder progress indicator:
                            // If `DebridManager` later exposes a `@Published var transferProgress: [String: Double]`,
                            // this will surface a per-magnet progress bar. If no entry exists, the row shows no progress.
                            if let progress = debridManager.transferProgress?[cloudMagnet.id] {
                                ProgressView(value: progress)
                                    .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                                    .frame(height: DesignTokens.Sizes.progressHeight)
                                    .clipShape(Capsule())
                                    .padding(.top, DesignTokens.Spacing.small)
                            }
                        }

                        Spacer()

                        DebridLabelView(debridSource: debridSource, cloudLinks: cloudMagnet.links)
                    }
                    .padding(DesignTokens.Spacing.small)
                    .liquidGlass(cornerRadius: DesignTokens.CornerRadius.medium)
                }
                .disabledAppearance(navModel.currentChoiceSheet != nil, dimmedOpacity: 0.7, animation: .easeOut(duration: 0.2))
                .tint(.primary)
                .tag(cloudMagnet)
                .listRowBackground(Color.clear)
                .contextMenu {
                                    Button {
                                        UIPasteboard.general.string = cloudMagnet.hash
                                    } label: {
                                        Text("Copy hash")
                                        Image(systemName: "doc.on.doc.fill")
                                    }

                                    Button {
                                        // Get a streamable/transcoded link from provider and present playback/share options.
                                        // Use the first available web link; fall back to copying the magnet hash if none exists.
                                        if let firstLink = cloudMagnet.links.first, !firstLink.isEmpty {
                                            Task {
                                                await debridManager.fetchStreamableLink(from: firstLink, providerId: debridSource.id)
                                                if !debridManager.downloadUrl.isEmpty {
                                                    navModel.currentChoiceSheet = .action
                                                }
                                            }
                                        } else {
                                            UIPasteboard.general.string = cloudMagnet.hash
                                        }
                                    } label: {
                                        Text("Get streamable link")
                                        Image(systemName: "link.circle")
                                    }

                                    Button {
                                        // show confirmation dialog before deleting
                                        pendingDeleteMagnet = cloudMagnet
                                        showDeleteConfirm = true
                                    } label: {
                                        Text("Delete magnet")
                                        Image(systemName: "trash.fill")
                                    }
                                }
                // Add swipe actions for quick access on rows
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        UIPasteboard.general.string = cloudMagnet.hash
                    } label: {
                        Label("Copy hash", systemImage: "doc.on.doc.fill")
                    }
                    .tint(.blue)

                    Button {
                        // Quick access to provider-transcoded/streamable link for the magnet (if a web link exists).
                        if let firstLink = cloudMagnet.links.first, !firstLink.isEmpty {
                            Task {
                                await debridManager.fetchStreamableLink(from: firstLink, providerId: debridSource.id)
                                if !debridManager.downloadUrl.isEmpty {
                                    navModel.currentChoiceSheet = .action
                                }
                            }
                        } else {
                            UIPasteboard.general.string = cloudMagnet.hash
                        }
                    } label: {
                        Label("Get streamable", systemImage: "link")
                    }
                    .tint(.purple)

                    Button(role: .destructive) {
                        pendingDeleteMagnet = cloudMagnet
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash.fill")
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\\(cloudMagnet.fileName), \\(cloudMagnet.links.count) files, status \\(cloudMagnet.status)")
                .accessibilityHint("Double tap to open the magnet details")
            }
            .onDelete { offsets in
                for index in offsets {
                    if let cloudMagnet = debridSource.cloudMagnets[safe: index] {
                        Task {
                            await debridManager.deleteUserMagnet(cloudMagnet)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showTransferBrowser) {
            if let transferHandle {
                DebridTransferBrowserView(
                    debridSource: debridSource,
                    handle: transferHandle,
                    title: transferTitle,
                    resultFromCloud: true
                )
            }
        }
        // Confirmation dialog for destructive magnet deletion
        .confirmationDialog("Delete magnet?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let magnet = pendingDeleteMagnet {
                    Task {
                        await debridManager.deleteUserMagnet(magnet)
                        pendingDeleteMagnet = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteMagnet = nil
            }
        } message: {
            if let m = pendingDeleteMagnet {
                Text("Are you sure you want to delete \"\\(m.fileName)\"?")
            } else {
                Text("Are you sure you want to delete this magnet?")
            }
        }
    }

    private func statusColor(_ status: String) -> Color {
        if debridSource.cachedStatus.contains(status) {
            return .green
        }

        if status.lowercased().contains("error") {
            return .red
        }

        return .orange
    }

    private func fetchStreamable(_ cloudMagnet: DebridCloudMagnet) {
        // Use the first link (if available) as the web-hosted resource to ask the provider to transcode/unrestrict.
        guard let firstLink = cloudMagnet.links.first, !firstLink.isEmpty else {
            // No web-hosted link available; copy magnet hash as a fallback.
            UIPasteboard.general.string = cloudMagnet.hash
            return
        }

        Task {
            await debridManager.fetchStreamableLink(from: firstLink, providerId: debridSource.id)
            if !debridManager.downloadUrl.isEmpty {
                // Present the standard action sheet so user can Play/Copy/Share the returned link.
                navModel.currentChoiceSheet = .action
            }
        }
    }
}

//
// Previews: Dynamic Type variants for CloudMagnetView
//
@MainActor struct CloudMagnetView_Previews: PreviewProvider {
    static var sampleMagnet = DebridCloudMagnet(
        id: "m1",
        fileName: "Sample Series - Episode 1 — A very long title intended to exercise wrapping and accessibility dynamic type scaling",
        status: "downloaded",
        hash: "abc123",
        links: ["https://example.com/video.m3u8"]
    )

    static var previews: some View {
        let debridManager = DebridManager()
        let navModel = NavigationViewModel()
        let logManager = LoggingManager()

        return Group {
            // Default size
            CloudMagnetView(debridSource: RealDebrid() as DebridSource, searchText: .constant(""))
                .environmentObject(navModel)
                .environmentObject(debridManager)
                .environmentObject(logManager)
                .previewDisplayName("Magnets — Default")

            // Accessibility large
            CloudMagnetView(debridSource: RealDebrid() as DebridSource, searchText: .constant(""))
                .environmentObject(navModel)
                .environmentObject(debridManager)
                .environmentObject(logManager)
                .environment(\.sizeCategory, .accessibilityExtraLarge)
                .previewDisplayName("Magnets — Large Dynamic Type")

            // Accessibility XXL
            CloudMagnetView(debridSource: RealDebrid() as DebridSource, searchText: .constant(""))
                .environmentObject(navModel)
                .environmentObject(debridManager)
                .environmentObject(logManager)
                .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
                .previewDisplayName("Magnets — Accessibility XXL")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
