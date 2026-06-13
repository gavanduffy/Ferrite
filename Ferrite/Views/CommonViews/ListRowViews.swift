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
    @Environment(\.openURL) var openURL

    let text: String
    let link: String

    var body: some View {
        Button {
            if let url = URL(string: link) {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                openURL(url)
            }
        } label: {
            HStack {
                Text(text)
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "arrow.up.forward.app.fill")
                    .foregroundColor(.gray)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.trailing, -5)
        .accessibilityLabel(text)
        .accessibilityHint("Opens in browser")
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
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        } label: {
            HStack {
                Text(text)
                    .foregroundColor(.primary)

                Spacer()

                if let imageName = systemImage {
                    Image(systemName: imageName)
                        .foregroundColor(.gray)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.trailing, -5)
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
