//
//  SearchResultButtonView.swift
//  Ferrite
//
//  Created by Brian Dashore on 9/2/22.
//

import SwiftUI
import UIKit

struct SearchResultButtonView: View {
    let backgroundContext = PersistenceController.shared.backgroundContext

    @EnvironmentObject var navModel: NavigationViewModel
    @EnvironmentObject var debridManager: DebridManager

    var result: SearchResult
    var debridIAStatus: IAStatus?

    @State private var runOnce = false
    @State var existingBookmark: Bookmark? = nil
    @State private var showConfirmation = false

    var body: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()

            if debridManager.currentDebridTask == nil {
                navModel.selectedMagnet = result.magnet
                navModel.selectedTitle = result.title ?? ""
                navModel.resultFromCloud = false

                var historyEntry = HistoryEntryJson(
                    name: result.title,
                    source: result.source
                )

                switch debridIAStatus ?? debridManager.matchMagnetHash(result.magnet) {
                case .full:
                    if debridManager.selectDebridResult(magnet: result.magnet) {
                        debridManager.currentDebridTask = Task {
                            await downloadToDebrid()
                        }
                    }
                case .partial:
                    if debridManager.selectDebridResult(magnet: result.magnet) {
                        navModel.selectedHistoryInfo = historyEntry
                        navModel.currentChoiceSheet = .batch
                    }
                case .none:
                    historyEntry.url = result.magnet.link
                    PersistenceController.shared.createHistory(historyEntry, performSave: true)

                    navModel.currentChoiceSheet = .action
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(result.title ?? "No title")
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(4)

                    Spacer(minLength: 0)

                    if let badge = cacheBadgeText() {
                        Text(badge)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .liquidGlassPill(
                                tint: badgeColor(for: badge).opacity(0.15),
                                shadow: false
                            )
                    }
                }

                SearchResultInfoView(result: result)
            }
            .padding(DesignTokens.Spacing.medium)
            .liquidGlassCard(shadow: false)
            .listRowBackground(Color.clear)
            .disabledAppearance(navModel.currentChoiceSheet != nil, dimmedOpacity: 0.7, animation: .easeOut(duration: 0.2))
        }
        .disableInteraction(navModel.currentChoiceSheet != nil)
        .tint(.primary)
        .contextMenu {
            ZStack {
                if let bookmark = existingBookmark {
                    Button {
                        PersistenceController.shared.delete(bookmark, context: backgroundContext)

                        // When the entity is deleted, let other instances know to remove that reference
                        NotificationCenter.default.post(name: .didDeleteBookmark, object: existingBookmark)
                    } label: {
                        Text("Remove bookmark")
                        Image(systemName: "bookmark.slash.fill")
                    }
                } else {
                    Button {
                        let newBookmark = Bookmark(context: backgroundContext)
                        newBookmark.title = result.title
                        newBookmark.source = result.source
                        newBookmark.magnetHash = result.magnet.hash
                        newBookmark.magnetLink = result.magnet.link
                        newBookmark.seeders = result.seeders
                        newBookmark.leechers = result.leechers

                        existingBookmark = newBookmark

                        PersistenceController.shared.save(backgroundContext)
                    } label: {
                        Text("Bookmark")
                        Image(systemName: "bookmark")
                    }
                }
            }

            Button {
                if debridManager.currentDebridTask == nil {
                    let foundIAResult = debridManager.selectDebridResult(magnet: result.magnet)

                    // Add a fake IA because we don't know if the magnet is cached at this point
                    if !foundIAResult {
                        debridManager.selectedDebridItem = DebridIA(
                            magnet: result.magnet,
                            expiryTimeStamp: Date().timeIntervalSince1970,
                            files: []
                        )
                    }

                    debridManager.currentDebridTask = Task {
                        await downloadToDebrid()

                        // Re-populate the IA cache if a result wasn't initially found
                        if !foundIAResult {
                            await debridManager.populateDebridIA([result.magnet])
                        }
                    }
                }
            } label: {
                Text("Download to Debrid")
                Image(systemName: "arrow.down.circle")
            }
        }
        .alert("Caching file", isPresented: $debridManager.showDeleteAlert) {
            Button("Yes", role: .destructive) {
                Task {
                    try? await debridManager.selectedDebridSource?.deleteUserMagnet(cloudMagnetId: nil)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "\(debridManager.selectedDebridSource?.id ?? "Unknown Debrid") is currently caching this file. " +
                    "Would you like to delete it? \n\n" +
                    "Progress can be checked on the \(debridManager.selectedDebridSource?.id ?? "Unknown Debrid") website."
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .didDeleteBookmark)) { notification in
            // If the instance contains the deleted bookmark, remove it.
            if let deletedBookmark = notification.object as? Bookmark,
               let bookmark = existingBookmark,
               deletedBookmark.objectID == bookmark.objectID
            {
                existingBookmark = nil
            }
        }
        .onAppear {
            // Only run a exists request if a bookmark isn't passed to the view
            if existingBookmark == nil, !runOnce {
                let bookmarkRequest = Bookmark.fetchRequest()
                bookmarkRequest.predicate = NSPredicate(
                    format: "title == %@ AND source == %@ AND magnetLink == %@ AND magnetHash = %@",
                    result.title ?? "",
                    result.source,
                    result.magnet.link ?? "",
                    result.magnet.hash ?? ""
                )
                bookmarkRequest.fetchLimit = 1

                if let fetchedBookmark = try? backgroundContext.fetch(bookmarkRequest).first {
                    existingBookmark = fetchedBookmark
                }

                runOnce = true
            }
        }
    }

    // Common function to download
    func downloadToDebrid() async {
        var historyEntry = HistoryEntryJson(
            name: result.title,
            source: result.source
        )

        await debridManager.fetchDebridDownload(magnet: result.magnet)
        navModel.selectedTitle = result.title ?? ""

        if debridManager.requiresUnrestrict {
            navModel.currentChoiceSheet = .batch

            return
        }

        if !debridManager.downloadUrl.isEmpty {
            historyEntry.url = debridManager.downloadUrl
            PersistenceController.shared.createHistory(historyEntry, performSave: true)

            navModel.currentChoiceSheet = .action
        }
    }

    private func cacheBadgeText() -> String? {
        let status = debridIAStatus ?? debridManager.matchMagnetHash(result.magnet)
        switch status {
        case .full:
            return "Cached"
        case .partial:
            return "Batch"
        case .none:
            return nil
        }
    }

    private func badgeColor(for badgeText: String) -> Color {
        switch badgeText {
        case "Cached":
            return .green
        case "Batch":
            return .accentColor
        default:
            return .secondary
        }
    }
}
