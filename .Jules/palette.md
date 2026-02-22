## 2026-01-24 - Contextual Empty States & a11y Grouping
**Learning:** Generic empty states can be confusing and provide a poor VoiceOver experience. By adding context-specific icons (SF Symbols) and grouping the title and message into a single accessibility element, we reduce cognitive load and navigation friction.
**Action:** Always use `EmptyInstructionView` with a relevant `systemName` and ensure accessibility grouping is applied to paired text elements.

## 2026-01-24 - Build Health vs. UX Scope
**Learning:** Build-breaking issues like dangling project references (exit code 65) and invalid APIs (e.g., `glassEffect`) take precedence over pure UX scope, as they prevent verification and deployment. However, when fixing these, maintain the intended visual richness of the design system by using stable SwiftUI equivalents like `.thinMaterial` with overlays.
**Action:** Always scan for and resolve dangling file references and invalid API usage (e.g., `iOS 26.0` guards) to ensure build stability before finalizing UX changes.
