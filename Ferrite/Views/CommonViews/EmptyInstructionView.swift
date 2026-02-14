//
//  EmptyInstructionView.swift
//  Ferrite
//
//  Created by Brian Dashore on 9/5/22.
//

import SwiftUI

struct EmptyInstructionView: View {
    let title: String
    let message: String
    let systemImage: String

    init(title: String, message: String, systemImage: String = "sparkles") {
        self.title = title
        self.message = message
        self.systemImage = systemImage
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .accessibilityHidden(true)

            VStack(spacing: DesignTokens.Spacing.tiny) {
                Text(title)
                    .font(DesignTokens.Typography.scaled(.title2, weight: .semibold))

                Text(message)
                    .font(DesignTokens.Typography.scaled(.caption))
                    .padding(.horizontal, DesignTokens.Spacing.xlarge * 2)
            }
        }
        .multilineTextAlignment(.center)
        .foregroundColor(.secondary)
        .padding(DesignTokens.Spacing.xlarge)
        .liquidGlass(cornerRadius: DesignTokens.CornerRadius.large, shadow: false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}
