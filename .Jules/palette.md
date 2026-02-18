## 2026-01-24 - Context-Aware Empty States
**Learning:** Empty states in SwiftUI are more engaging and accessible when they use context-specific SF Symbols and combine text elements for VoiceOver. Using a centralized `EmptyInstructionView` with a customizable icon parameter ensures consistency while providing relevant visual cues.
**Action:** Always use `EmptyInstructionView` for empty lists or overlays, providing a `systemName` that matches the content (e.g., 'magnifyingglass' for search, 'archivebox' for backups). Ensure the icon is hidden from accessibility and text is combined.
