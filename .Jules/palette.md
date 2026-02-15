## 2024-05-23 - Accessible Empty States
**Learning:** Grouping title and message in an empty state view using `.accessibilityElement(children: .combine)` provides a much better VoiceOver experience than reading them as separate elements. Additionally, hiding decorative icons from accessibility prevents unnecessary clutter.
**Action:** Always use `.accessibilityElement(children: .combine)` on containers that present a unified message (like empty states or alerts) and hide decorative SF Symbols.
