# Photodew -- Project Context

## What is Photodew?

A native iOS RAW camera app (Swift 6.1, SwiftUI, AVFoundation) targeting iPhone photographers who want a true low-processing capture path similar to Halide's Process Zero philosophy. Supports True RAW (Bayer DNG), Apple ProRAW, and full manual controls.

## Architecture

- **SPM modules**: `CameraKit` (camera infrastructure), `Storage` (persistence), `App` (orchestration/model), `CaptureUI` (shared SwiftUI views), `RenderKit` (RAW rendering and export)
- **iOS app target**: `ios/PhotodewApp/` (Xcode project at `ios/PhotodewApp.xcodeproj`)
- **No third-party dependencies**. iOS 17+, Swift 6.1.
- `ContentView.swift` is the main camera UI. `PhotodewIOSApp.swift` contains `BootstrapViewModel` (~1500 lines, `@MainActor ObservableObject`) which is the bridge between SPM modules and the SwiftUI view layer. `PhotoReviewView.swift` is the post-capture review screen with RAW rendering and export.

## Build

```bash
# SPM package (CameraKit, Storage, App, CaptureUI)
swift build

# Full iOS app (requires Xcode)
xcodebuild -project ios/PhotodewApp.xcodeproj -scheme PhotodewApp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build

# Tests
swift test
```

## Key Files

| File | Role |
|---|---|
| `ios/PhotodewApp/ContentView.swift` | Main camera UI -- all chrome, overlays, pro controls |
| `ios/PhotodewApp/PhotoReviewView.swift` | Post-capture review screen with RAW rendering and export |
| `ios/PhotodewApp/PhotodewIOSApp.swift` | App entry point + BootstrapViewModel |
| `Sources/CameraKit/CaptureSessionService.swift` | Core camera session abstraction |
| `Sources/CameraKit/ExposureStateMachine.swift` | Exposure auto/locked/custom state machine |
| `Sources/CameraKit/FocusStateMachine.swift` | Focus auto/locked state machine |
| `Sources/CameraKit/WhiteBalanceStateMachine.swift` | WB auto/locked state machine |
| `Sources/App/CaptureAppModel.swift` | App-level orchestration model |
| `Sources/App/CaptureControlPreset.swift` | Preset slot persistence |
| `Sources/RenderKit/RawRenderer.swift` | CIRAWFilter neutral RAW renderer |
| `Sources/RenderKit/RenderExporter.swift` | JPEG/TIFF export pipeline |
| `Sources/RenderKit/RenderingProfile.swift` | Rendering profile enum (neutral) |
| `Sources/RenderKit/RenderResult.swift` | Render result model with timing |
| `Sources/Storage/CaptureMetadataStore.swift` | Photo library capture metadata |
| `docs/planning/iphone-raw-camera-execution-board.md` | Full execution board with tickets and sprints |

## Milestone Status (as of 2026-02-08)

| Milestone | Status |
|---|---|
| M0 Foundation | Complete |
| M1 Camera MVP | Complete |
| M2 Manual Controls | Complete |
| M3 True RAW | Complete |
| M4 Pro Capture UX | Complete |
| M8 UI Focus | Complete |
| M5 RAW Rendering | In Progress (RND-001, RND-004 done and validated on device; RND-003 revised -- compare slider removed; RND-002, RND-005 not started) |
| M6-M7 | Not started |

## Conventions

- **Versioning**: Minor bump for major phase changes, patch for minor changes
- **Releases**: `CHANGELOG.md` + `gh release create`
- **Commit style**: Descriptive messages preferred; terse messages used during rapid iteration
- **SwiftLint**: Configured via `.swiftlint.yml`
- **CI**: `.github/workflows/ci.yml` runs lint + build + test

## Design Tokens

`CaptureDesignTokens` enum in `ContentView.swift` centralizes all spacing, radii, sizing, and color values for the camera UI. All new UI work should reference these tokens rather than hardcoding values.

## Haptics

Three haptic levels are used: `hapticLight()` for toggles/navigation, `hapticMedium()` for shutter, `hapticRigid()` for focus lock/unlock.

## Next Steps

1. On-device validation of M5 photo review screen (neutral render, export)
2. On-device validation of M8 UI changes (mini + Pro Max)
3. M5 RAW Rendering: `RND-002` (additional rendering profiles), `RND-005` (performance benchmarks)
