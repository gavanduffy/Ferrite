//
//  HistoryButtonView.swift
//  Ferrite
//
//  Created by Brian Dashore on 9/9/22.
//

import SwiftUI
import UIKit

struct HistoryButtonView: View {
    @EnvironmentObject var logManager: LoggingManager
    @EnvironmentObject var navModel: NavigationViewModel
    @EnvironmentObject var debridManager: DebridManager

    let entry: HistoryEntry

    var body: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()

            navModel.selectedTitle = entry.name ?? ""
            navModel.selectedBatchTitle = entry.subName ?? ""

            if let url = entry.url {
                if url.starts(with: "magnet:") {
                    navModel.selectedMagnet = Magnet(hash: nil, link: url)
                    navModel.resultFromCloud = false
                } else {
                    navModel.selectedMagnet = nil
                    debridManager.downloadUrl = url
                    navModel.resultFromCloud = true
                }

                navModel.currentChoiceSheet = .action
            } else {
                logManager.error(
                    "History: URL for name \(String(describing: entry.name)) is invalid",
                    description: "URL invalid. Cannot load this history entry. Please delete it."
                )
            }
        } label: {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                VStack(alignment: .leading) {
                    Text(entry.name ?? "Unknown title")
                        .font(entry.subName == nil ? .body : .subheadline)
                        .lineLimit(entry.subName == nil ? 2 : 1)

                    if let subName = entry.subName {
                        Text(subName)
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                            .lineLimit(2)
                    }
                }

                HStack {
                    Text(entry.source ?? "Unknown source")

                    Spacer()

                    Text("DEBRID")
                        .fontWeight(.bold)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .liquidGlassPill(
                            tint: getTagColor().opacity(0.2),
                            shadow: false
                        )
                }
                .font(.caption)
            }
            .disabledAppearance(navModel.currentChoiceSheet != nil, dimmedOpacity: 0.7, animation: .easeOut(duration: 0.2))
        }
        .buttonStyle(PressableButtonStyle())
        .tint(.primary)
        .disableInteraction(navModel.currentChoiceSheet != nil)
        .accessibilityLabel("\(entry.name ?? "Unknown title")\(entry.subName != nil ? ", \(entry.subName!)" : "")")
        .accessibilityHint("Tap to open link actions for this history item")
    }

    func getTagColor() -> Color {
        if let url = entry.url, url.starts(with: "https://") {
            return Color.green
        } else {
            return Color.red
        }
    }
}
