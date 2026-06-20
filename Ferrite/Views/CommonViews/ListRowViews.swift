//
//  ListRowViews.swift
//  Ferrite
//
//  Created by Brian Dashore on 7/26/22.
//
//  List row button, text, and link boilerplate
//

import SwiftUI
import UIKit

struct ListRowLinkView: View {
    let text: String
    let link: String

    var body: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()

            if let url = URL(string: link) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack {
                Text(text)
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "arrow.up.forward.app.fill")
                    .foregroundColor(.secondary)
            }
            .padding(.trailing, -5)
            .contentShape(Rectangle())
        }
        .applyPressableButtonStyle()
        .accessibilityLabel(text)
        .accessibilityHint("Opens the website")
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
                        .foregroundColor(.secondary)
                }
            }
            .padding(.trailing, -5)
            .contentShape(Rectangle())
        }
        .applyPressableButtonStyle()
        .accessibilityHint("Performs an action")
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
