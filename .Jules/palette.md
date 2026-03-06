## 2025-05-15 - Context-Aware Empty States and Grouped Accessibility

**Learning:** Generic empty states (e.g., a single "sparkles" icon for everything) fail to provide clear visual cues for different application contexts. Grouping title and message for VoiceOver while hiding decorative icons significantly improves screen-reader navigation efficiency by reducing "swipe fatigue".

**Action:** Always use context-specific SF Symbols for empty states and implement `.accessibilityElement(children: .combine)` on text clusters in standardized UI components.
