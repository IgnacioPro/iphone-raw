# Changelog

All notable changes to Photodew are documented in this file.

## [1.1.0] - 2026-02-07

### M8 UI Focus -- Complete Camera UI Overhaul

#### Added
- **CaptureDesignTokens** -- Centralized enum for all spacing, radii, sizing, and color values. All new UI work references these tokens.
- **Haptic feedback** -- Three levels: `hapticLight()` for toggles/navigation, `hapticMedium()` for shutter, `hapticRigid()` for focus lock/unlock. Applied to shutter, mode toggle, preset apply, focus lock, pro panel toggle, and all utility bar buttons.
- **Camera utility bar** (UX-005) -- Compact icon-only row with 44pt touch targets for camera switch, exposure lock, focus peaking, zebra, white balance lock, and pro controls toggle.
- **Swipe gesture for pro panel** (UX-005) -- Swipe up on camera surface to show pro controls, swipe down to dismiss.
- **Pro controls panel close button** -- X button in panel header for direct dismissal.
- **Preset quick switcher** (UX-006) -- Horizontal capsule pill row in primary control deck. Tap to select slot, tap saved slot to apply immediately. Spring animation on selection change.
- **Camera status footer** -- Storage pressure warnings and capture error messages now visible in bottom chrome.
- **VoiceOver accessibility** -- Labels, hints, and `accessibilityElement` grouping added throughout all interactive controls.
- **Spring animations** -- Pro panel slide (response: 0.35, damping: 0.82), preset switcher (response: 0.25, damping: 0.8), utility toggle active state (easeInOut: 0.15).

#### Fixed
- **5 orphaned view components wired into view hierarchy** (UI-001) -- `previewQuickStrip`, `cameraUtilityBar`, `primaryControlDeck`, `cameraStatusFooter`, and `proControlsPanel` were fully built but never rendered. All are now part of the active layout.
- **ZStack ordering** (UI-001) -- `previewScrimOverlay` now renders BEHIND zebra and focus peaking overlays instead of on top, which was occluding them.
- **Bottom chrome layout** (UI-001) -- Replaced fragile `offset(y: -43)` hack and hardcoded 126pt black bar with proper `bottomChromeStack` using `safeAreaInset`.
- **Duplicate shutter button removed** -- Old `bottomCameraChrome` deleted; shutter now lives only in `primaryControlDeck`.
- **Horizon level re-enabled** -- Changed `isHorizonLevelEnabled` from `false` to `true` in `BootstrapViewModel`. Core Motion updates will now start when camera is ready.
- **Pro controls panel state** -- `isProControlsPresented` now correctly gates panel visibility with animated transitions.

#### Changed
- **Scrim opacity reduced** -- Top scrim 0.42 (was higher), bottom scrim 0.52 (was higher) to avoid overpowering the preview when rendered behind overlays.
- **Touch targets hardened to 44pt minimum** (UI-004) -- All utility toggles, icon circle buttons, exposure HUD chip, focus button, and preset buttons now meet iOS minimum touch target guidelines. `contentShape` modifiers added for accurate hit testing.
- **Top chrome restructured** -- Now contains both the top HUD (histogram, horizon, EV chip) and the camera utility bar.
- **Bottom chrome restructured** -- Now composed of preview quick strip, camera status footer, and primary control deck.

## [1.0.0] - 2026-02-07

### Initial Implementation (M0-M4)

- M0 Foundation: Swift package modules, camera permission gate, capture session abstraction, structured logging, CI pipeline.
- M1 Camera MVP: Live preview, shutter capture, camera switching, save to Photos, EXIF orientation, capture latency instrumentation, error recovery and retry UX.
- M2 Manual Controls: Exposure state machine (auto/locked/custom), manual ISO/shutter, manual focus lock, white balance temperature/tint, EV compensation, preset persistence.
- M3 True RAW: Capability detection, Bayer DNG capture, RAW+processed pair save, RAW-safe settings policy, metadata pack, storage cleanup, Apple ProRAW mode, in-app mode education.
- M4 Pro Capture UX: Real-time luminance histogram, zebra clipping overlay, focus peaking overlay, horizon level indicator.
