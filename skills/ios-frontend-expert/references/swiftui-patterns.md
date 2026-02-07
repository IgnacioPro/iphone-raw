# SwiftUI Patterns

## View Structure

- Compose screens from small subviews with explicit inputs.
- Keep side effects out of `body`.
- Extract repeated view fragments into reusable components.
- Keep modifier chains readable; move custom styling into modifiers.

## State Ownership

- Use `@State` for view-local transient state.
- Use `@Binding` for parent-owned mutable state.
- Use `@StateObject` for view-owned observable lifecycle.
- Use `@ObservedObject` for externally-owned observable lifecycle.
- Use `@EnvironmentObject` only for truly shared app-level state.

## Common State Model

```swift
enum ScreenState<T> {
    case idle
    case loading
    case loaded(T)
    case empty
    case error(message: String)
}
```

- Model empty and error explicitly instead of ad-hoc flags.
- Keep rendering logic exhaustive with `switch` over state.

## Concurrency

- Run asynchronous loading with structured concurrency.
- Mark UI-facing types with `@MainActor`.
- Cancel stale tasks on parameter changes.

```swift
.task(id: viewModel.reloadToken) {
    await viewModel.load()
}
```

## Navigation

- Prefer value-driven navigation with `NavigationStack`.
- Keep route enums codable/hashable when state restoration matters.
- Avoid hidden navigation side effects in deeply nested views.

## Lists and Scrolling

- Use stable ids in `ForEach`.
- Use `LazyVStack` and `LazyHStack` for long lists.
- Avoid heavy synchronous work during scrolling.

## Animations

- Use animation to explain state transitions, not decorate every update.
- Keep durations short and intentional.
- Avoid stacking multiple implicit animations on same state change.

## Theming and Design System

- Centralize spacing, radius, typography, and color tokens.
- Provide semantic tokens rather than hard-coded values.
- Keep component APIs style-agnostic where possible.

## Preview Strategy

- Create previews for loading, content, empty, and error.
- Preview minimum and extra-large dynamic type.
- Preview light and dark appearances only if product supports both.
