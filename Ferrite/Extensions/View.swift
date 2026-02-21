//
//  View.swift
//  Ferrite
//
//  Created by Brian Dashore on 8/15/22.
//

import SwiftUI

extension View {
    // Modifies properties of a view. Works the same way as a ViewModifier
    // From: https://github.com/SwiftUIX/SwiftUIX/blob/master/Sources/Intermodular/Extensions/SwiftUI/View%2B%2B.swift#L10
    func modifyViewProp(_ body: (inout Self) -> Void) -> Self {
        var result = self
        body(&result)

        return result
    }

    // MARK: Modifiers

    func disabledAppearance(_ disabled: Bool, dimmedOpacity: Double? = nil, animation: Animation? = nil) -> some View {
        modifier(DisabledAppearanceModifier(disabled: disabled, dimmedOpacity: dimmedOpacity, animation: animation))
    }

    func disableInteraction(_ disabled: Bool) -> some View {
        modifier(DisableInteractionModifier(disabled: disabled))
    }

    func inlinedList(inset: CGFloat) -> some View {
        modifier(InlinedListModifier(inset: inset))
    }

    @ViewBuilder
    func liquidGlass(
        cornerRadius: CGFloat = 16,
        tint: Color? = nil,
        interactive: Bool = false,
        shadow: Bool = true,
        stroke: Bool = true
    ) -> some View {
        ZStack {
            if let tint = tint {
                tint.opacity(0.05)
            }
            Color.clear
        }
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.primary.opacity(0.06), lineWidth: stroke ? 0.5 : 0)
                .blendMode(.overlay)
        )
        .overlay(
            // subtle top-left highlight to imply depth
            LinearGradient(
                gradient: Gradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.01)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .allowsHitTesting(false)
        )
        .shadow(color: shadow ? Color.black.opacity(0.03) : .clear, radius: shadow ? 6 : 0, x: 0, y: shadow ? 2 : 0)
    }

    // MARK: - Semantic Style Wrappers for liquidGlass

    /// Card-style liquid glass with medium corner radius
    func liquidGlassCard(
        tint: Color? = nil,
        interactive: Bool = false,
        shadow: Bool = true,
        stroke: Bool = true
    ) -> some View {
        liquidGlass(cornerRadius: 12, tint: tint, interactive: interactive, shadow: shadow, stroke: stroke)
    }

    /// Pill-style liquid glass with fully rounded corners
    func liquidGlassPill(
        tint: Color? = nil,
        interactive: Bool = false,
        shadow: Bool = true,
        stroke: Bool = true
    ) -> some View {
        liquidGlass(cornerRadius: 999, tint: tint, interactive: interactive, shadow: shadow, stroke: stroke)
    }

    /// Toast-style liquid glass with small corner radius
    /// Uses cornerRadius 10 for a slightly rounded but not pill-shaped appearance,
    /// suitable for temporary notification overlays
    func liquidGlassToast(
        tint: Color? = nil,
        interactive: Bool = false,
        shadow: Bool = true,
        stroke: Bool = true
    ) -> some View {
        liquidGlass(cornerRadius: 10, tint: tint, interactive: interactive, shadow: shadow, stroke: stroke)
    }
}

// MARK: - PressableButtonStyle (top-level)
// Moved out of the liquidGlass implementation so it can be applied app-wide.
struct PressableButtonStyle: ButtonStyle {
    /// Scale applied while pressed (defaults to a gentle 0.98)
    var scaleAmount: CGFloat = 0.98
    /// Opacity applied while pressed (defaults to a slight dim)
    var opacityAmount: Double = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .opacity(configuration.isPressed ? opacityAmount : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

// MARK: - Cardify extension
// A reusable card modifier for consistent container styling across the app.
extension View {
    func cardify(
        cornerRadius: CGFloat = 12,
        padding: CGFloat = 12,
        shadow: Bool = true,
        strokeOpacity: Double = 0.04
    ) -> some View {
        self
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.primary.opacity(strokeOpacity), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: shadow ? Color.black.opacity(0.04) : .clear, radius: shadow ? 8 : 0, x: 0, y: shadow ? 4 : 0)
    }

    /// Convenience: apply the pressable button style via a view modifier chain.
    func applyPressableButtonStyle(scaleAmount: CGFloat = 0.98, opacityAmount: Double = 0.96) -> some View {
        self.buttonStyle(PressableButtonStyle(scaleAmount: scaleAmount, opacityAmount: opacityAmount))
    }
}
