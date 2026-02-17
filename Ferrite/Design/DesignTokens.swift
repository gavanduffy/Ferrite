//
//  DesignTokens.swift
//  Ferrite
//
//  Centralized design tokens for consistent spacing, sizing, and styling across the app.
//
//  Created by AI assistant on behalf of the user.
//

import SwiftUI

/// Centralized design tokens for the Ferrite app.
///
/// Use these tokens to keep spacing, corner radii, shadows, and sizes consistent
/// across the codebase. Avoid hard-coded numbers in views; reference these tokens instead.
enum DesignTokens {
    enum Spacing {
        static let tiny: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xlarge: CGFloat = 24
    }

    enum CornerRadius {
        static let micro: CGFloat = 6
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let pill: CGFloat = 999 // use for capsule-like shapes
    }

    enum Stroke {
        /// Very thin subtle stroke useful for glass outlines.
        static let ultraThin: CGFloat = 0.5
        /// Standard outline width.
        static let thin: CGFloat = 1.0
    }

    enum Shadow {
        static let subtle = ShadowSpec(radius: 2, y: 1, color: Color.black.opacity(0.02))
        static let medium = ShadowSpec(radius: 4, y: 2, color: Color.black.opacity(0.04))
        static let prominent = ShadowSpec(radius: 8, y: 4, color: Color.black.opacity(0.06))

        struct ShadowSpec {
            let radius: CGFloat
            let y: CGFloat
            let color: Color
        }
    }

    enum TabBar {
        /// Smaller height for the tab bar (reduced from 56)
        static let height: CGFloat = 44
        /// Even more compact height when keyboard visible
        static let compactHeight: CGFloat = 40
        /// Tighter horizontal padding to keep bar closer to edges
        static let horizontalPadding: CGFloat = 8
        /// Minimal bottom padding to keep bar closer to screen edge
        static let bottomPadding: CGFloat = 4
        static let cornerRadius: CGFloat = CornerRadius.medium
    }

    enum Sizes {
        static let iconSmall: CGFloat = 14
        static let iconMedium: CGFloat = 20
        static let iconLarge: CGFloat = 28

        static let progressHeight: CGFloat = 6
        static let rowVerticalPadding: CGFloat = 10
    }

    enum Typography {
        // Use the system text styles which automatically scale with Dynamic Type.
        static var largeTitle: Font { .largeTitle }
        static var title: Font { .title }
        static var title2: Font { .title2 }
        static var headline: Font { .headline }
        static var body: Font { .body }
        static var callout: Font { .callout }
        static var caption: Font { .caption }

        // Convenience helper to return a scaled SwiftUI Font with weight
        static func scaled(_ textStyle: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
            // Prefer the built-in text style so SwiftUI dynamic type scaling is preserved.
            switch textStyle {
            case .largeTitle: return .system(.largeTitle, design: .default).weight(weight)
            case .title: return .system(.title, design: .default).weight(weight)
            case .title2: return .system(.title2, design: .default).weight(weight)
            case .title3: return .system(.title3, design: .default).weight(weight)
            case .headline: return .system(.headline, design: .default).weight(weight)
            case .body: return .system(.body, design: .default).weight(weight)
            case .callout: return .system(.callout, design: .default).weight(weight)
            case .subheadline: return .system(.subheadline, design: .default).weight(weight)
            case .footnote: return .system(.footnote, design: .default).weight(weight)
            case .caption: return .system(.caption, design: .default).weight(weight)
            case .caption2: return .system(.caption2, design: .default).weight(weight)
            default: return .system(.body, design: .default).weight(weight)
            }
        }
    }

    // MARK: - Helpful view modifiers and helpers

    /// Apply a subtle card background style with material, stroke and shadow.
    static func cardBackground<R: Shape>(cornerRadius: CGFloat = CornerRadius.medium) -> some ViewModifier {
        CardBackgroundModifier(cornerRadius: cornerRadius)
    }

    private struct CardBackgroundModifier: ViewModifier {
        var cornerRadius: CGFloat

        func body(content: Content) -> some View {
            content
                .padding(Spacing.small)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.primary.opacity(0.04), lineWidth: Stroke.ultraThin))
                .shadow(color: Shadow.subtle.color, radius: Shadow.subtle.radius, x: 0, y: Shadow.subtle.y)
        }
    }
}
