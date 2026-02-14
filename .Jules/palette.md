## 2026-01-24 - Enhancing Empty States with Context-Aware Icons and Accessibility
**Learning:** Generic empty states (e.g., using "sparkles" for everything) can feel disconnected from the user's current context. Providing context-appropriate SF Symbols (like "clock" for history or "icloud" for cloud storage) makes the interface feel more intuitive and polished. Additionally, grouping the title and message into a single accessibility element improves the experience for VoiceOver users by providing a cohesive description of the state.

**Action:** When creating empty states or informational views, always consider if there's a more specific icon that represents the missing data, and ensure typography scales with `DesignTokens.Typography.scaled` while grouping related text for accessibility.
