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
        HStack {
            if let url = URL(string: link) {
                Link(text, destination: url)
                    .foregroundColor(.primary)
            } else {
                Text(text)
                    .foregroundColor(.primary)
            }

            Spacer()

            Image(systemName: "arrow.up.forward.app.fill")
                .foregroundColor(.gray)
                .accessibilityHidden(true)
        }
        .padding(.trailing, -5)
        .contentShape(Rectangle())
        .accessibilityLabel(text)
        .accessibilityHint("Opens in external browser")
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
        Button(action: action) {
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
            .padding(.trailing, -5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                    .foregroundColor(.secondary)
            } else if let rightSymbol {
                Image(systemName: rightSymbol)
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.trailing, -5)
        .contentShape(Rectangle())
    }
}
