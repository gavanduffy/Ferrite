//
//  EmptyInstructionView.swift
//  Ferrite
//
//  Created by Brian Dashore on 9/5/22.
//

import SwiftUI

struct EmptyInstructionView: View {
    var systemName: String = "sparkles"
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            Image(systemName: systemName)
                .font(DesignTokens.Typography.scaled(.title, weight: .semibold))
                .accessibilityHidden(true)

            VStack(spacing: DesignTokens.Spacing.small) {
                Text(title)
                    .font(DesignTokens.Typography.scaled(.title2, weight: .semibold))

                Text(message)
                    .font(DesignTokens.Typography.scaled(.footnote))
                    .padding(.horizontal, DesignTokens.Spacing.xlarge * 2)
            }
            .accessibilityElement(children: .combine)
        }
        .multilineTextAlignment(.center)
        .foregroundColor(.init(uiColor: .secondaryLabel))
        .padding(DesignTokens.Spacing.xlarge)
        .liquidGlass(cornerRadius: DesignTokens.CornerRadius.large, shadow: false)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}
