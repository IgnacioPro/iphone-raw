---
name: ios-frontend-expert
description: Expert iOS frontend development for SwiftUI and UIKit, including feature implementation, refactoring, component design, interaction polish, accessibility, localization, and performance tuning. Use when Codex must build or review iOS UI code, screen flows, design-system components, view models, animation behavior, or SwiftUI/UIKit interoperability.
---

# iOS Frontend Expert

## Overview

Build production-grade iOS UI with pragmatic engineering rigor.
Ship features that are visually polished, accessible, testable, and maintainable.

## Workflow

1. Clarify the feature contract.
2. Choose SwiftUI, UIKit, or hybrid based on constraints.
3. Define a thin view layer and explicit state ownership.
4. Implement the minimum vertical slice first.
5. Add accessibility, localization, and dynamic type support before polish.
6. Add interaction polish, loading/error states, and performance fixes.
7. Add or update tests.
8. Summarize tradeoffs and follow-up risks.

## Stack Selection

- Prefer SwiftUI for new screens, rapid iteration, and composable design-system views.
- Prefer UIKit for advanced collection layout control, mature legacy modules, or API gaps.
- Use hybrid composition when migration risk is high or feature velocity requires incremental adoption.
- Keep interop boundaries explicit and small.
- Load `references/swiftui-patterns.md` for SwiftUI-specific implementation details.
- Load `references/uikit-interop.md` for wrappers, hosting, and migration patterns.

## Implementation Rules

### Architecture
- Keep views dumb and deterministic.
- Move business decisions into view models or domain services.
- Expose UI state as explicit enums or structs.
- Model loading, content, empty, and error as first-class states.

### State and Data Flow
- Keep one source of truth per feature boundary.
- Minimize derived state duplication.
- Isolate side effects behind injected protocols.
- Cancel stale async tasks when view lifecycle changes.

### UI Composition
- Build small reusable components with clear inputs.
- Keep custom modifiers and style tokens centralized.
- Support dynamic type and content-size changes by default.
- Avoid hard-coded spacing and colors when tokens exist.

### Interaction Quality
- Animate meaningful transitions only.
- Preserve interaction continuity across loading and pagination.
- Handle skeleton, retry, and offline states intentionally.
- Keep hit targets and gesture conflicts ergonomic.

### Accessibility and Localization
- Add accessibility labels, hints, and traits for custom controls.
- Validate VoiceOver order and discoverability.
- Validate color contrast and non-color affordances.
- Externalize all user-facing strings.
- Anticipate longer localized strings and right-to-left layouts.

### Performance
- Keep expensive computation out of `body` and layout passes.
- Avoid unnecessary view invalidations and identity churn.
- Use lazy containers for large scrolling datasets.
- Measure before optimizing and document bottlenecks.

## Testing Expectations

- Add unit tests for view model state transitions.
- Add snapshot or visual regression checks for core states when available.
- Add UI tests for primary flow and critical error paths.
- Keep test fixtures stable and representative.
- Verify dark mode only if the product supports it.

## Output Contract

When executing this skill:

- State assumptions and unresolved product constraints.
- Present a concrete implementation plan before large refactors.
- Deliver shippable code, not pseudo-implementations.
- Report validation status for build/tests and any gaps.
- List follow-up hardening tasks if scope was constrained.

## Reference Files

- Load `references/swiftui-patterns.md` when implementing SwiftUI layouts, state handling, animation, and preview strategy.
- Load `references/uikit-interop.md` when embedding UIKit in SwiftUI, embedding SwiftUI in UIKit, or migrating legacy screens.
- Load `references/qa-checklist.md` when preparing a feature for merge, release, or code review.
