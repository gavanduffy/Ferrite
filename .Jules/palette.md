## 2025-01-28 - Enhancing Interactive List Rows

**Learning:** Making the entire row a `Button` label and using `.contentShape(Rectangle())` is crucial in SwiftUI Lists to ensure the entire area is tappable, especially when adding `PressableButtonStyle` for visual feedback. Simply using `onTapGesture` or having a small `Button` inside an `HStack` leads to a poor user experience where only the text is interactive.

**Action:** Always wrap the contents of a custom list row in a `Button` label if the entire row should be interactive, and apply `.contentShape(Rectangle())` to the container inside the label.

## 2025-01-28 - Accessibility and Haptics for Common Components

**Learning:** When refactoring common components like `ListRowLinkView`, adding `@Environment(\.openURL)` provides a cleaner and more testable way to handle external links than using the `Link` view directly, especially when combined with haptic feedback and custom analytics or logging in the future.

**Action:** Prefer `openURL` environment action for link navigation in interactive rows to allow for the injection of haptics and other side effects before the navigation occurs.
