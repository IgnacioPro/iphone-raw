# M8 UI Focus -- Full Layout Pass Implementation Plan

## Problem Statement

The camera UI in ContentView.swift has **5 fully-built view components that are never rendered** in the view hierarchy:
- `previewQuickStrip` (line 283) -- zebra toggle, pro controls toggle, format badge
- `cameraUtilityBar` (line 338) -- camera switch, exposure, peaking, AWB, pro controls
- `primaryControlDeck` (line 371) -- focus mode, preset, thumbnail, shutter, lens switcher
- `cameraStatusFooter` (line 513) -- storage warnings, capture errors, retry button
- `proControlsPanel` (line 560) -- scrollable panel with all pro control sections

Additional issues:
- Horizon level is permanently disabled (`isHorizonLevelEnabled = false` in PhotodewIOSApp.swift:111)
- `previewScrimOverlay` renders ON TOP of zebra/peaking overlays, occluding them
- Bottom chrome uses fragile `offset(y: -43)` hack
- `isProControlsPresented` toggles have no effect (nothing reads the state)
- Duplicate shutter button in `bottomCameraChrome` and `primaryControlDeck`

## Files to Modify

1. `ios/PhotodewApp/ContentView.swift` -- Major restructure
2. `ios/PhotodewApp/PhotodewIOSApp.swift` -- Re-enable horizon level
3. `docs/planning/iphone-raw-camera-execution-board.md` -- Update ticket statuses
4. `CLAUDE.md` -- Create with project context

## Phase 1: UI-001 -- Capture Chrome Layout Pass

### 1.1 Fix ZStack ordering in `readyCameraSurface`

Move `previewScrimOverlay` BEFORE zebra/peaking overlays so scrims don't occlude pro assists:

```swift
private func readyCameraSurface(session: AVCaptureSession) -> some View {
    ZStack {
        CameraPreviewView(session: session)
        previewScrimOverlay          // scrims FIRST (behind overlays)
        // zebra overlay
        // focus peaking overlay
    }
    .safeAreaInset(edge: .top) { topCameraChrome }
    .safeAreaInset(edge: .bottom) { bottomChromeStack }  // NEW
    .overlay(alignment: .bottom) { proControlsPanel if isProControlsPresented }
}
```

### 1.2 Add `CaptureDesignTokens` enum

Extract all hardcoded magic numbers into a centralized token system at the top of the file:

```swift
private enum CaptureDesignTokens {
    static let chromeInset: CGFloat = 14
    static let controlGap: CGFloat = 12
    static let sectionGap: CGFloat = 14
    static let controlRadius: CGFloat = 14
    static let panelRadius: CGFloat = 18
    static let chipRadius: CGFloat = 100 // Capsule
    static let minimumTouchTarget: CGFloat = 44
    static let scrimTopHeight: CGFloat = 160
    static let scrimBottomHeight: CGFloat = 260
    static let shutterButtonOuterSize: CGFloat = 86
    static let shutterButtonInnerSize: CGFloat = 70
    static let histogramWidth: CGFloat = 102
    static let histogramHeight: CGFloat = 42
    static let proControlsPanelMaxHeight: CGFloat = 340
    static let proControlsPanelBottomPadding: CGFloat = 180
    static let accentColor = Color(red: 0.93, green: 0.88, blue: 0.24)
}
```

### 1.3 Restructure topCameraChrome

Wire `cameraUtilityBar` below the existing `topHUD`:

```swift
private var topCameraChrome: some View {
    VStack(spacing: 8) {
        topHUD
        cameraUtilityBar
    }
    .padding(.horizontal, CaptureDesignTokens.chromeInset)
    .padding(.top, 8)
    .padding(.bottom, 10)
    .background(gradient)
}
```

### 1.4 Replace bottomCameraChromeInset with bottomChromeStack

Remove the `offset(y: -43)` hack. Replace `bottomCameraChromeInset` + `bottomCameraChrome` with a new `bottomChromeStack` that composes:
- `previewQuickStrip` (top)
- `cameraStatusFooter` (middle, if errors/warnings)
- `primaryControlDeck` (bottom -- replaces old `bottomCameraChrome`)

```swift
private var bottomChromeStack: some View {
    VStack(spacing: CaptureDesignTokens.controlGap) {
        previewQuickStrip
        cameraStatusFooter
        primaryControlDeck
    }
    .padding(.horizontal, CaptureDesignTokens.chromeInset)
    .padding(.bottom, 8)
    .background(bottomChromeGradient)
}
```

### 1.5 Remove old bottomCameraChromeInset and bottomCameraChrome

Delete `bottomCameraChromeInset` (lines 136-145) and `bottomCameraChrome` (lines 228-253) entirely. The `primaryControlDeck` already contains a shutter button, so the duplicate is removed.

### 1.6 Wire proControlsPanel with animation

Gate `proControlsPanel` display on `isProControlsPresented` with a slide-up transition:

```swift
.overlay(alignment: .bottom) {
    if isProControlsPresented {
        proControlsPanel
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
.animation(.spring(response: 0.35, dampingFraction: 0.82), value: isProControlsPresented)
```

### 1.7 Re-enable horizon level

In `PhotodewIOSApp.swift` line 111, change:
```swift
private static let isHorizonLevelEnabled = false
```
to:
```swift
private static let isHorizonLevelEnabled = true
```

## Phase 2: UX-005 -- Quick Toggles and Gesture Model

### 2.1 Redesign cameraUtilityBar

Make it a compact icon-only row with 44pt minimum touch targets:

```swift
private var cameraUtilityBar: some View {
    HStack(spacing: CaptureDesignTokens.controlGap) {
        utilityToggle(symbol: "arrow.triangle.2.circlepath.camera", isActive: false, label: "Switch Camera") {
            bootstrap.switchCamera()
        }
        utilityToggle(symbol: "timer", isActive: !isExposureAuto, label: "Exposure") {
            toggleExposureMode()
        }
        utilityToggle(symbol: "viewfinder", isActive: bootstrap.isFocusPeakingEnabled, label: "Focus Peaking") {
            bootstrap.toggleFocusPeakingOverlay()
        }
        utilityToggle(symbol: "lines.measurement.horizontal", isActive: bootstrap.isZebraOverlayEnabled, label: "Zebra") {
            bootstrap.toggleZebraOverlay()
        }
        utilityToggle(symbol: "drop.halffull", isActive: !isWhiteBalanceAuto, label: "White Balance") {
            toggleWhiteBalanceMode()
        }
        utilityToggle(symbol: "slider.horizontal.3", isActive: isProControlsPresented, label: "Pro Controls") {
            withAnimation { isProControlsPresented.toggle() }
        }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(.black.opacity(0.64), in: RoundedRectangle(cornerRadius: CaptureDesignTokens.controlRadius, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: CaptureDesignTokens.controlRadius, style: .continuous)
        .stroke(.white.opacity(0.12), lineWidth: 1))
}
```

### 2.2 Add swipe gesture for proControlsPanel

On `readyCameraSurface`, add a `DragGesture` that:
- Swipe up (translation.height < -40): show pro panel if hidden
- Swipe down (translation.height > 40): hide pro panel if shown

### 2.3 One-thumb sizing

Use the existing `primaryControlDeck` layout which centers the shutter button. Ensure all controls in the bottom chrome are within thumb reach on Pro Max. The `previewQuickStrip` and `cameraUtilityBar` are secondary controls that require deliberate reach to the top -- this is correct camera UX.

## Phase 3: UX-006 -- Preset Quick Switcher

### 3.1 Add preset pill row

Add a horizontal row of 3 preset capsule buttons above the shutter in `primaryControlDeck`:

```swift
private var presetQuickSwitcher: some View {
    HStack(spacing: 8) {
        ForEach(BootstrapViewModel.presetSlots, id: \.self) { slot in
            Button {
                hapticLight()
                if bootstrap.savedPresetSlots.contains(slot) {
                    bootstrap.selectedPresetSlot = slot
                    bootstrap.applyPresetSelection()
                } else {
                    bootstrap.selectedPresetSlot = slot
                }
            } label: {
                Text(slot.displayName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(slot == bootstrap.selectedPresetSlot ? CaptureDesignTokens.accentColor : .white.opacity(0.7))
                    .frame(minWidth: 44, minHeight: 30)
                    .background(slot == bootstrap.selectedPresetSlot ? .white.opacity(0.12) : .clear, in: Capsule())
                    .overlay(Capsule().stroke(
                        bootstrap.savedPresetSlots.contains(slot) ? .white.opacity(0.35) : .white.opacity(0.12),
                        lineWidth: 1
                    ))
            }
            .buttonStyle(.plain)
        }
    }
}
```

Wire this into `primaryControlDeck` between the focus row and the shutter row.

## Phase 4: UI-002, UI-003, UI-004 -- Visual Polish, Motion, Accessibility

### 4.1 UI-002: Extract reusable CaptureChip

Multiple views share the capsule-with-border pattern. Extract:

```swift
private struct CaptureChip<Content: View>: View {
    let isActive: Bool
    @ViewBuilder let content: Content
    
    var body: some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.black.opacity(0.58), in: Capsule())
            .overlay(Capsule().stroke(
                isActive ? CaptureDesignTokens.accentColor.opacity(0.56) : .white.opacity(0.14),
                lineWidth: 1
            ))
    }
}
```

Apply to: `exposureHUDChip`, `captureModeToggleButton`, badge text in `thumbnailButton`, `previewQuickStrip` format badge.

### 4.2 UI-002: Replace all magic numbers

Replace every hardcoded CGFloat dimension with `CaptureDesignTokens.*` reference. Key replacements:
- `126` -> removed (no longer needed)
- `-43` -> removed (no longer needed)
- `160`, `260` -> `CaptureDesignTokens.scrimTopHeight`, `.scrimBottomHeight`
- `14` padding -> `CaptureDesignTokens.chromeInset`
- `102, 42` -> `CaptureDesignTokens.histogramWidth/Height`
- `86, 70` -> `CaptureDesignTokens.shutterButtonOuterSize/InnerSize`

### 4.3 UI-003: Add haptic feedback

Import UIKit for haptics. Add helper functions:

```swift
#if canImport(UIKit)
private func hapticLight() {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
}
private func hapticMedium() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
}
private func hapticRigid() {
    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
}
#endif
```

Add haptics to:
- Shutter press -> `hapticMedium()`
- Mode toggle -> `hapticLight()`
- Preset apply -> `hapticLight()`
- Focus lock/unlock -> `hapticRigid()`
- Pro panel toggle -> `hapticLight()`
- Utility bar toggles -> `hapticLight()`

### 4.4 UI-003: Animation polish

- Pro controls panel: `.spring(response: 0.35, dampingFraction: 0.82)`
- Mode toggle: `.spring(response: 0.3, dampingFraction: 0.75)`
- Preset quick switcher: `.spring(response: 0.25, dampingFraction: 0.8)`
- Utility bar active state: `.easeInOut(duration: 0.15)`

### 4.5 UI-004: Touch target hardening

Ensure minimum 44pt targets:
- `utilityButton` / `utilityToggle`: increase frame from 38x30 to 44x44
- `exposureHUDChip`: add `.contentShape(Capsule())` and ensure min height 44
- `iconCircleButton`: increase frame from 36x36 to 44x44
- All buttons in `primaryControlDeck`: already 44+ (shutter 86, focus 44, preset 42->44)
- `presetQuickSwitcher` pills: `minWidth: 44, minHeight: 44`

### 4.6 UI-004: VoiceOver labels/hints

Verify and add where missing:
- `cameraUtilityBar` buttons: already have `accessibilityLabel` via `utilityButton` helper
- `presetQuickSwitcher`: add `.accessibilityLabel()` and `.accessibilityHint()`
- `proControlsPanel`: add `.accessibilityElement(children: .contain)` with group label
- `cameraStatusFooter`: storage warning and error text are already `Text` (auto-labeled)

## Execution Order

1. Add `CaptureDesignTokens` enum
2. Restructure `readyCameraSurface` (ZStack fix + new composition)
3. Create `bottomChromeStack` wiring all bottom components
4. Restructure `topCameraChrome` to include utility bar
5. Remove old `bottomCameraChromeInset` and `bottomCameraChrome`
6. Add swipe gesture and panel animation
7. Add `presetQuickSwitcher` to `primaryControlDeck`
8. Extract `CaptureChip` component
9. Add haptic helpers and wire them
10. Fix touch targets (44pt minimum)
11. VoiceOver audit pass
12. Re-enable horizon level in PhotodewIOSApp.swift
13. Replace remaining magic numbers with tokens
14. Build and verify compilation
15. Update execution board and CLAUDE.md

## Risk Assessment

- **Compile risk**: Medium -- large structural changes to view hierarchy. Mitigated by building after each major edit.
- **Layout risk**: Low-medium -- new layout should be tested on device. Hardcoded values are replaced with tokens that can be tuned.
- **Regression risk**: Low -- no backend/model changes. All changes are in the view layer.
