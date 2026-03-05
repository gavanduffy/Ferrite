## 2024-05-24 - Standardizing Empty States for Accessibility and Context

**Learning:** Empty states in SwiftUI should provide both visual feedback (SF Symbols) and actionable guidance. For accessibility, combining title and message into a single element while hiding decorative icons creates a cleaner VoiceOver experience. Using design tokens for typography ensures consistent scaling with Dynamic Type.

**Action:** When implementing empty states, always use `EmptyInstructionView`, hide the decorative icon from VoiceOver with `.accessibilityHidden(true)`, and group text elements using `.accessibilityElement(children: .combine)`.
