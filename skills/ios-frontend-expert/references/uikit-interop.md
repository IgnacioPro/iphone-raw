# UIKit Interop and Migration

## Use Cases

- Embed UIKit controls in SwiftUI when API parity is missing.
- Embed SwiftUI views in UIKit during incremental migration.
- Keep boundaries thin and isolate interop logic in dedicated wrappers.

## Wrap UIKit in SwiftUI

- Use `UIViewRepresentable` for views.
- Use `UIViewControllerRepresentable` for controllers.
- Implement `makeUIView` for creation and `updateUIView` for state sync.
- Use `Coordinator` for delegates, targets, and callbacks.

```swift
struct LegacyTextView: UIViewRepresentable {
    @Binding var text: String

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text { uiView.text = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        private let parent: LegacyTextView
        init(_ parent: LegacyTextView) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) { parent.text = textView.text }
    }
}
```

## Embed SwiftUI in UIKit

- Use `UIHostingController(rootView:)` for screen-level embedding.
- Pin hosted view with explicit constraints.
- Pass dependencies from UIKit coordinator/router into SwiftUI root.
- Treat hosting boundary as a module seam for migration.

## Collection and Table Strategies

- Prefer `UICollectionViewDiffableDataSource` for complex UIKit lists.
- Keep cell configuration deterministic and idempotent.
- For SwiftUI list cells in UIKit, measure performance before full migration.

## Migration Rules

- Migrate per feature boundary, not per control.
- Keep navigation and analytics stable during migration.
- Avoid rewriting business logic during UI migration unless required.
- Add regression tests before replacing legacy screens.

## Accessibility Across Boundaries

- Verify accessibility labels on wrapped UIKit controls.
- Preserve focus order when mixing SwiftUI and UIKit content.
- Ensure custom wrappers expose accessibility traits correctly.
