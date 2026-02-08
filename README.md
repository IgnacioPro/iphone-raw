# Photodew

Photodew is a native iOS RAW camera app built with Swift, SwiftUI, and AVFoundation.
It targets photographers who want low-processing capture workflows with manual control.

## Highlights

- True RAW (Bayer DNG) capture on supported devices
- Apple ProRAW capture mode
- RAW + processed pair save to Photos
- Manual exposure, ISO/shutter, focus, white balance, and EV compensation
- Pro capture overlays: histogram, zebra clipping, focus peaking, horizon level
- In-app photo review with neutral RAW rendering and JPEG/TIFF export
- Preset slots for quick manual-control recall

## Tech Stack

- Swift 6.1
- Swift Package Manager modules
- SwiftUI + AVFoundation
- iOS 17+ target
- No third-party runtime dependencies

## Project Structure

- `Sources/CameraKit` - camera session, capture pipeline, overlays, state machines
- `Sources/App` - app orchestration and domain model
- `Sources/CaptureUI` - shared UI components
- `Sources/RenderKit` - RAW rendering and export pipeline
- `Sources/Storage` - capture metadata persistence
- `ios/PhotodewApp` - iOS wrapper app and app-level SwiftUI entry
- `Tests/*` - unit tests by module

## Prerequisites

- Xcode 16+ (recommended for iOS 17 SDK / Swift 6 toolchain)
- Ruby (only needed if regenerating the `.xcodeproj`)
- `xcodeproj` gem (for `scripts/generate_xcodeproj.sh`)
- SwiftLint (for linting)

Install optional tooling:

```bash
gem install xcodeproj
brew install swiftlint
```

## Quick Start

### 1. Build and test package targets

```bash
swift build --build-tests
swift test
```

### 2. Lint

```bash
swiftlint
```

### 3. Run the iOS app

The repository already includes `ios/PhotodewApp.xcodeproj`.
If you need to regenerate it:

```bash
./scripts/generate_xcodeproj.sh
```

Open in Xcode:

```bash
open ios/PhotodewApp.xcodeproj
```

Then select the `PhotodewApp` scheme and run on an iPhone.
The simulator is useful for UI iteration, but real camera capture validation requires a physical device.

## CI

GitHub Actions workflow:

- `.github/workflows/ci.yml`
- Runs lint, Swift package build, and tests on pushes and pull requests

## Docs

- Planning board: `docs/planning/iphone-raw-camera-execution-board.md`
- Rendering plan: `docs/planning/m5-raw-rendering-plan.md`
- Validation notes: `docs/validation/`
- Changes: `CHANGELOG.md`

