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
    let systemImageName: String

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            Image(systemName: systemImageName)
                .font(DesignTokens.Typography.scaled(.title, weight: .semibold))
                .accessibilityHidden(true)

            Text(title)
                .font(DesignTokens.Typography.scaled(.title2, weight: .semibold))

            Text(message)
                .padding(.horizontal, DesignTokens.Spacing.xlarge * 2)
                .font(DesignTokens.Typography.scaled(.footnote))
        }
        .multilineTextAlignment(.center)
        .foregroundColor(.secondary)
        .padding(DesignTokens.Spacing.xlarge)
        .liquidGlass(cornerRadius: DesignTokens.CornerRadius.large, shadow: false)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .accessibilityElement(children: .combine)
    }
}
