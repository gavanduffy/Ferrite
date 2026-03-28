//
//  ListRowViews.swift
//  Ferrite
//
//  Created by Brian Dashore on 7/26/22.
//
//  List row button, text, and link boilerplate
//

import SwiftUI

struct ListRowLinkView: View {
    let text: String
    let link: String

    var body: some View {
        Group {
            if let url = URL(string: link) {
                Link(destination: url) {
                    HStack {
                        Text(text)
                            .foregroundColor(.primary)

                        Spacer()

                        Image(systemName: "arrow.up.forward.app.fill")
                            .foregroundColor(.gray)
                            .accessibilityHidden(true)
                    }
                    .contentShape(Rectangle())
                }
                .accessibilityLabel(text)
                .accessibilityHint("Opens link in browser")
            } else {
                HStack {
                    Text(text)
                        .foregroundColor(.secondary)

                    Spacer()

                    Image(systemName: "link.badge.plus")
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                }
                .accessibilityLabel("\(text), link unavailable")
            }
        }
        .padding(.trailing, -DesignTokens.Spacing.tiny - 1)
    }
}

struct ListRowButtonView: View {
    let text: String
    let systemImage: String?
    let action: () -> Void

    init(_ text: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.text = text
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button {
            action()
        } label: {
            HStack {
                Text(text)
                    .foregroundColor(.primary)

                Spacer()

                if let imageName = systemImage {
                    Image(systemName: imageName)
                        .foregroundColor(.gray)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, -DesignTokens.Spacing.tiny - 1)
        .accessibilityLabel(text)
    }
}

struct ListRowTextView: View {
    let leftText: String
    var rightText: String?
    var rightSymbol: String?

    var body: some View {
        HStack {
            Text(leftText)

            Spacer()

            if let rightText {
                Text(rightText)
            } else if let rightSymbol {
                Image(systemName: rightSymbol)
            }
        }
        .padding(.trailing, -5)
    }
}
