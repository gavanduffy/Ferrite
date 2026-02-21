## 2024-05-24 - Context-Aware Empty States and Accessibility Grouping

**Learning:** Empty states are more effective when they provide visual context through relevant iconography. Additionally, grouping title and message in a single accessibility element improves the experience for VoiceOver users by providing a coherent announcement of the state.

**Action:** When implementing empty states in Ferrite, use `EmptyInstructionView` with a context-specific SF Symbol and ensure accessibility grouping is maintained.
