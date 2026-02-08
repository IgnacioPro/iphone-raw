# M5 RAW Rendering — Implementation Plan

Last updated: 2026-02-07

## Decisions

| Decision | Choice |
|---|---|
| Architecture | New `RenderKit` SPM module |
| Review UX | Tap thumbnail → in-app review screen |
| Compare interaction | Slider divider (Lightroom-style before/after) |
| Rendering profiles | Neutral only (Classic/Punch deferred to follow-up) |
| Export formats | JPEG + TIFF |
| Performance target | <700ms for preview-sized render |

## New SPM Module: `RenderKit`

New module at `Sources/RenderKit/` with dependency on `CameraKit` (for `CapturedPhotoPayload` and `CaptureTechnicalMetadata`). Pure Core Image — no UIKit dependency.

### Package.swift changes

- New `.library(name: "RenderKit", targets: ["RenderKit"])`
- New `.target(name: "RenderKit", dependencies: ["CameraKit"])`
- New `.testTarget(name: "RenderKitTests", dependencies: ["RenderKit"])`
- `App` gains dependency on `RenderKit`

### Key types

| File | Type | Role |
|---|---|---|
| `RawRenderer.swift` | `RawRenderer` actor | Core engine — wraps `CIRAWFilter`, accepts DNG `Data`, returns `CIImage` |
| `RenderingProfile.swift` | `RenderingProfile` enum | `.neutral` for now (extensible for `.classic`, `.punch`) |
| `RenderResult.swift` | `RenderResult` struct | Rendered `CIImage`, render duration, applied profile, source metadata |
| `RenderExporter.swift` | `RenderExporter` | Converts `CIImage` → JPEG/TIFF `Data` with color space tags and metadata |

## Phase 1: `CIRAWFilter` Neutral Renderer (RND-001) — 2 days

**Goal:** Take DNG data from `CapturedPhotoPayload.rawData` and produce a neutral, flat render with minimal processing.

### `RawRenderer` implementation

1. Initialize `CIRAWFilter` from DNG `Data` via `CIRAWFilter(imageData:identifierHint:)` (iOS 15+)
2. Apply neutral profile settings:
   - `boostAmount = 0` — no boost
   - `boostShadowAmount = 0` — no shadow lift
   - `noiseReductionAmount = 0` — disable NR
   - `luminanceNoiseReductionAmount = 0` — disable luminance NR
   - `colorNoiseReductionAmount = 0` — disable chroma NR
   - `noiseReductionSharpnessAmount = 0` — disable NR sharpening
   - `noiseReductionContrastAmount = 0` — disable NR contrast
   - `noiseReductionDetailAmount = 0` — disable NR detail
   - `sharpnessAmount = 0` — disable sharpening
   - `localToneMapAmount = 0` — disable local tone mapping (iOS 17+)
   - `extendedDynamicRangeAmount = 0` — no HDR headroom
   - Let `neutralChromaticity`, `neutralTemperature`, `neutralTint` default to DNG-embedded values (as-shot WB)
   - `exposure = 0` — no EV offset
   - `baselineExposure` — read from DNG metadata, don't override
3. Render via `CIContext.createCGImage(_:from:)` using a `CIContext` with `.workingColorSpace = CGColorSpace(name: CGColorSpace.linearSRGB)!`
4. Measure and return render duration alongside the `CIImage`

### Protocol for testability

```swift
public protocol RawRendering: Sendable {
    func render(dngData: Data, profile: RenderingProfile) async throws -> RenderResult
}
```

Actor-based implementation for thread safety (`CIContext` is thread-safe but `CIRAWFilter` is not).

### Tests

- Verify neutral settings are applied (mock or inspect filter parameters)
- Verify render produces non-nil output with expected dimensions
- Verify render duration is captured
- Verify error handling for invalid/corrupt DNG data

## Phase 2: Export Pipeline (RND-004) — 1 day

### `RenderExporter` implementation

| Export Format | Approach | Color Space |
|---|---|---|
| JPEG | `CIContext.jpegRepresentation(of:colorSpace:options:)` | Display P3 |
| TIFF | `CIContext.tiffRepresentation(of:format:colorSpace:options:)` | Display P3, 16-bit |

Both include:
- EXIF metadata from the original `CaptureTechnicalMetadata` (ISO, shutter, WB, lens)
- `kCGImagePropertyProfileName` set to the rendering profile name
- Correct ICC profile embedding

### Protocol

```swift
public protocol RenderExporting: Sendable {
    func exportJPEG(from result: RenderResult, quality: Float) async throws -> Data
    func exportTIFF(from result: RenderResult) async throws -> Data
}
```

### Tests

- Verify JPEG output is valid (parseable by `CGImageSource`)
- Verify TIFF output is valid
- Verify embedded color space is Display P3
- Verify metadata is preserved in exported files

## Phase 3: In-App Review Screen (RND-003) — 2 days

### Navigation change

- Tapping `LastPhotoThumbnailButton` opens a `.fullScreenCover` instead of `UIApplication.shared.open(photos-redirect://)`
- Long-press on thumbnail still opens system Photos (preserves escape hatch)
- For processed (JPG) captures: show processed image full-screen without compare slider
- For RAW/ProRAW captures: show compare slider with rendered RAW vs processed JPEG

### New file: `ios/PhotodewApp/PhotoReviewView.swift`

#### Full-screen zoomable image view

- `MagnifyGesture` + `DragGesture` for pinch-to-zoom and pan
- Minimum zoom 1x, maximum 5x
- Double-tap to toggle between fit and 1:1 pixel zoom

#### Slider divider (compare mode — RAW formats only)

- Vertical divider line with a drag handle
- Left side: rendered RAW (neutral profile)
- Right side: processed JPEG (from `CapturedPhotoPayload.processedData`)
- Divider starts at center (50%)
- Drag left/right to reveal more of either side
- Label overlay: "RAW" on left, "Processed" on right (small, fades after 2s)
- Works with zoom — both sides zoom together
- Slider disabled while zoomed in (to avoid UX complexity)

#### Top bar

- Close button (left) — dismisses the review
- Format badge ("RAW" / "PRO" / "JPG") — informational

#### Bottom bar

- Export button → action sheet with "JPEG" and "TIFF" options
- Share button → system share sheet with the exported file
- Open in Photos button → opens the specific asset via `PHAsset` local identifier

### State management

`PhotoReviewViewModel` holds:
- The `CapturedPhotoPayload` from the last capture
- The `RenderResult` (loaded async on presentation)
- Loading/error state for the render
- Export progress state

### Data flow

1. After capture, `BootstrapViewModel` stores the full `CapturedPhotoPayload` (not just thumbnail)
2. When review screen appears, processed JPEG is shown immediately (fast path)
3. RAW rendering starts async — loading indicator on the RAW side of the slider
4. Once render completes, the slider becomes interactive

## Phase 4: Performance Benchmarks (RND-005) — 0.5 day

### Measurements

- `CIRAWFilter` initialization time (DNG parsing)
- Render time (filter → `CGImage`)
- Export time (JPEG and TIFF separately)
- Memory high-water mark during render

### Target

<700ms total for preview-sized output (screen resolution, ~2500px long edge)

### Implementation

- `os_signpost` intervals around each phase
- Structured log events: `raw_render_started`, `raw_render_completed` with `render_duration_ms`, `render_width`, `render_height`
- If render exceeds 700ms, investigate:
  - Render at half resolution first, then full resolution in background
  - Use `CIRAWFilter.previewImage` for instant preview, then full render

## Phase 5: Integration and Wiring — 1 day

### `BootstrapViewModel` changes (PhotodewIOSApp.swift)

- Store `lastCapturedPayload: CapturedPhotoPayload?` after successful capture
- Store `lastCaptureFormat: CapturePhotoFormat?` to control compare mode availability
- Add `isPhotoReviewPresented: Bool` — drives `.fullScreenCover`
- Instantiate `RawRenderer` (via protocol) during `start()`

### `ContentView.swift` changes

- `LastPhotoThumbnailButton` tap → sets `isPhotoReviewPresented = true`
- Long-press → opens Photos app (existing behavior)
- `.fullScreenCover(isPresented:)` presents `PhotoReviewView`

## Ticket Mapping

| Ticket | Phase | Status |
|---|---|---|
| RND-001 | Phase 1: `RenderKit` module, `RawRenderer`, neutral `CIRAWFilter` settings | Not started |
| RND-002 | Deferred: Classic and Punch profiles — add as parameterized `RenderingProfile` cases | Deferred |
| RND-003 | Phase 3: `PhotoReviewView` with slider divider, zoom, compare mode | Not started |
| RND-004 | Phase 2: `RenderExporter` for JPEG and TIFF with color space tags | Not started |
| RND-005 | Phase 4: `os_signpost` benchmarks, structured logging, <700ms target | Not started |

## Execution Order

```
Phase 1 (RND-001)  →  Phase 2 (RND-004)  →  Phase 3 (RND-003)  →  Phase 4 (RND-005)  →  Phase 5 (wiring)
     2d                    1d                    2d                    0.5d                   1d
```

**Total estimate: ~6.5 days**

## Files to Create

| File | Contents |
|---|---|
| `Sources/RenderKit/RawRenderer.swift` | `RawRendering` protocol + `RawRenderer` actor |
| `Sources/RenderKit/RenderingProfile.swift` | `RenderingProfile` enum (`.neutral`) |
| `Sources/RenderKit/RenderResult.swift` | `RenderResult` value type |
| `Sources/RenderKit/RenderExporter.swift` | `RenderExporting` protocol + `RenderExporter` |
| `Tests/RenderKitTests/RawRendererTests.swift` | Renderer unit tests |
| `Tests/RenderKitTests/RenderExporterTests.swift` | Export format tests |
| `ios/PhotodewApp/PhotoReviewView.swift` | Full review screen with compare slider |

## Files to Modify

| File | Changes |
|---|---|
| `Package.swift` | Add `RenderKit` library, target, test target; add `RenderKit` dep to `App` |
| `ios/PhotodewApp.xcodeproj/project.pbxproj` | Add `RenderKit` dependency to app target |
| `ios/PhotodewApp/PhotodewIOSApp.swift` | Store payload, review state, wire renderer |
| `ios/PhotodewApp/ContentView.swift` | Thumbnail tap → review, long-press → Photos, `.fullScreenCover` |

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| `CIRAWFilter` may not accept all DNG variants from our capture pipeline | Test with actual captured DNGs early in Phase 1 |
| Render >700ms on older devices | Preview-resolution first, full-res background render |
| Memory spike during render (DNG + CIImage + CGImage in memory) | Render at screen resolution, not full sensor resolution for preview |
| Slider divider + zoom interaction complexity | Keep zoom shared between both sides, disable slider while zoomed in |
| ProRAW DNGs may behave differently than True RAW in CIRAWFilter | Test both formats explicitly, may need different neutral settings |
