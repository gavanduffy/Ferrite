## 2026-01-24 - Contextual Accessibility Hints for Disabled States

**Learning:** In complex forms like `AddView`, buttons are often disabled based on multiple state variables (e.g., `isProcessing`, empty input, or provider support). Simply disabling the button leaves VoiceOver users without an explanation of why the action is unavailable. Using `.accessibilityHint()` with conditional logic provides immediate, clear feedback on what the user needs to do to enable the action.

**Action:** Always apply `.accessibilityHint()` to buttons that can be disabled, explaining the specific condition (e.g., "Wait for current processing to finish" vs "Enter web links or magnets first").

## 2026-01-24 - Tactile Confirmation for Destructive & Primary Actions

**Learning:** Adding `UIImpactFeedbackGenerator(style: .light)` to small/destructive actions (like removing an item from a list) and `.medium` to primary submit actions significantly enhances the "premium" feel of the native iOS experience. It provides a non-visual confirmation that the tap was registered, which is especially helpful when the UI might have a slight delay due to async processing.

**Action:** Implement `UIImpactFeedbackGenerator` within the action closure of all interactive buttons in Ferrite, matching the intensity to the importance of the action.

## 2026-01-24 - Clean Accessibility Logic with Computed Properties

**Learning:** Complex conditional accessibility hints (using nested ternaries) can quickly become unreadable and hard to maintain in the SwiftUI view body. Moving this logic to a private computed property within the View struct improves code clarity and allows for more readable `if-else` or `switch` statements.

**Action:** Use private computed properties (e.g., `private var submitButtonHint: String`) to manage complex accessibility hint logic.
## 2024-05-24 - Contextual Empty States and Accessibility Grouping

**Learning:** When implementing "empty states" in SwiftUI, using a single reusable component like `EmptyInstructionView` is efficient, but it must be flexible enough to provide context-specific icons (SF Symbols) to remain intuitive. Additionally, for better VoiceOver support, grouping the title and message into a single accessibility element using `.accessibilityElement(children: .combine)` provides a much smoother experience than navigating through separate labels. Marking decorative icons as `.accessibilityHidden(true)` is also crucial for reducing noise.

**Action:** Always provide an icon property in reusable state views and ensure accessibility grouping is applied to related text elements to improve VoiceOver flow in Ferrite.

## 2026-05-30 - Full-Row Tap Targets in Lists
**Learning:** Standard SwiftUI `Link` and `Button` in a `List` row only register taps on their text/label, leaving the rest of the row (like spacers or trailing icons) dead zones. Wrapping the entire `HStack` in a `Button` label and applying `.contentShape(Rectangle())` ensures the whole row is tappable, significantly improving ergonomics.
**Action:** Replace direct `Link` and icon-only buttons in list rows with a full-row `Button` wrapper and `.contentShape(Rectangle())` for better hit testing.
