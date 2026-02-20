## 2026-02-20 - Enhancing Empty States with Semantic Tokens and Accessibility
**Learning:** Empty states are crucial for user guidance. Using `DesignTokens.Typography.scaled` ensures they respect Dynamic Type, and `accessibilityElement(children: .combine)` prevents VoiceOver from fragmentation between title and message. Context-specific SF Symbols significantly improve visual at-a-glance understanding.
**Action:** Always use `EmptyInstructionView` for empty states and ensure it has a context-appropriate icon and combined accessibility traits.
