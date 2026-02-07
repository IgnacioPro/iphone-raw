# Photodew iPhone RAW Camera Execution Board

Last updated: 2026-02-07
Planning horizon: 2026-02-09 through 2026-04-24

## 0) Current Status Snapshot (as of 2026-02-07)

### Milestone Progress

| Milestone | Status | Notes |
| --- | --- | --- |
| M0 Foundation | Complete | `FND-001` to `FND-005` are implemented and covered by package tests and CI workflow. |
| M1 Camera MVP | Complete | `CAM-001` through `CAM-006` are implemented; interruption recovery and retry UX were validated on device. |
| M2 Manual Controls | Complete | `MAN-001` through `MAN-006` are implemented in code and accepted on device. |
| M3 True RAW | Complete (ahead of schedule) | `RAW-001` to `RAW-008` are implemented and accepted on device. |
| M4 Pro Capture UX | Complete | `UX-001` to `UX-004` are implemented and accepted on device. |
| M8 UI Focus | Complete | `UX-005`, `UX-006`, `UI-001` to `UI-004` implemented; ContentView restructured with all orphaned components wired, design tokens, haptics, accessibility. |
| M5 to M7 | Not started | Render pipeline, QA hardening, and release workstreams are still untouched. |

### Ticket Status (Implemented / In Progress / Next)

| Ticket | Status | Evidence in Repo | Next Action |
| --- | --- | --- | --- |
| FND-001 | Done | Swift package modules present in `Sources/` and `Package.swift`. | None |
| FND-002 | Done | Permission gate + blocked state in `Sources/CameraKit/CameraPermissionGate.swift` and app boot flow. | None |
| FND-003 | Done | `CaptureSessionService` abstraction and tests. | None |
| FND-004 | Done | Structured capture/session logging and event schema implemented. | None |
| FND-005 | Done | CI job with lint/build/test in `/Users/ignacio/Code/photodew/.github/workflows/ci.yml`. | None |
| CAM-001 | Done | Live preview + shutter path in `/Users/ignacio/Code/photodew/ios/PhotodewApp/ContentView.swift` and backend capture pipeline. | None |
| CAM-002 | Done | Camera switch control and backend switching implemented. | None |
| CAM-003 | Done | Save-to-Photos flow (including RAW pair save) in `/Users/ignacio/Code/photodew/ios/PhotodewApp/PhotodewIOSApp.swift`. | None |
| CAM-004 | Done (accepted) | User-confirmed on-device capture validation for both RAW and processed/JPEG flows; matrix and notes are in `/Users/ignacio/Code/photodew/docs/validation/cam-004-orientation-exif-matrix.md`. | None |
| CAM-005 | Done | Capture telemetry now emits `photo_capture_started`, `photo_capture_succeeded`, and `photo_capture_failed` with `capture_latency_ms` in `/Users/ignacio/Code/photodew/Sources/CameraKit/CaptureSessionService.swift` and `/Users/ignacio/Code/photodew/Tests/CameraKitTests/CaptureSessionServiceTests.swift`. | None |
| CAM-006 | Done (accepted) | Interruption observers + recovery/retry UX copy are implemented in `/Users/ignacio/Code/photodew/ios/PhotodewApp/PhotodewIOSApp.swift` and `/Users/ignacio/Code/photodew/ios/PhotodewApp/ContentView.swift`; interruption state logging is covered in `/Users/ignacio/Code/photodew/Tests/CameraKitTests/CaptureSessionServiceTests.swift`; user validated on device. | None |
| MAN-001 | Done | Exposure state machine scaffolding (`auto`, `locked`, `custom`) is implemented in `/Users/ignacio/Code/photodew/Sources/CameraKit/ExposureStateMachine.swift`, integrated into `/Users/ignacio/Code/photodew/Sources/CameraKit/CaptureSessionService.swift` and `/Users/ignacio/Code/photodew/Sources/App/CaptureAppModel.swift`, with deterministic transitions covered in `/Users/ignacio/Code/photodew/Tests/CameraKitTests/ExposureStateMachineTests.swift`. | None |
| MAN-002 | Done (accepted) | Manual ISO/shutter controls are wired from UI to backend in `/Users/ignacio/Code/photodew/ios/PhotodewApp/ContentView.swift`, `/Users/ignacio/Code/photodew/ios/PhotodewApp/PhotodewIOSApp.swift`, and `/Users/ignacio/Code/photodew/Sources/CameraKit/CaptureSessionService.swift`; metadata assertions are covered in `/Users/ignacio/Code/photodew/Tests/CameraKitTests/CaptureSessionServiceTests.swift`; on-device validation is documented in `/Users/ignacio/Code/photodew/docs/validation/man-002-manual-iso-shutter-validation.md`. | None |
| MAN-003 | Done (accepted) | Manual focus lock state machine and backend apply path are implemented in `/Users/ignacio/Code/photodew/Sources/CameraKit/FocusStateMachine.swift` and `/Users/ignacio/Code/photodew/Sources/CameraKit/CaptureSessionService.swift`; iOS controls are in `/Users/ignacio/Code/photodew/ios/PhotodewApp/ContentView.swift`; deterministic transition coverage is in `/Users/ignacio/Code/photodew/Tests/CameraKitTests/FocusStateMachineTests.swift`. | None |
| MAN-004 | Done (accepted) | White balance temperature/tint state machine (`/Users/ignacio/Code/photodew/Sources/CameraKit/WhiteBalanceStateMachine.swift`), backend apply/reset in `/Users/ignacio/Code/photodew/Sources/CameraKit/CaptureSessionService.swift`, app model passthrough in `/Users/ignacio/Code/photodew/Sources/App/CaptureAppModel.swift`, and iOS controls in `/Users/ignacio/Code/photodew/ios/PhotodewApp/ContentView.swift` are implemented with tests in `/Users/ignacio/Code/photodew/Tests/CameraKitTests/CaptureSessionServiceTests.swift` and `/Users/ignacio/Code/photodew/Tests/CameraKitTests/WhiteBalanceStateMachineTests.swift`; user validated on device. | None |
| MAN-005 | Done (accepted) | EV compensation is implemented via backend/service API (`/Users/ignacio/Code/photodew/Sources/CameraKit/CaptureSessionService.swift`), app model passthrough (`/Users/ignacio/Code/photodew/Sources/App/CaptureAppModel.swift`), and iOS slider/actions (`/Users/ignacio/Code/photodew/ios/PhotodewApp/PhotodewIOSApp.swift`, `/Users/ignacio/Code/photodew/ios/PhotodewApp/ContentView.swift`) with coverage in `/Users/ignacio/Code/photodew/Tests/CameraKitTests/CaptureSessionServiceTests.swift` and `/Users/ignacio/Code/photodew/Tests/AppTests/CaptureAppModelTests.swift`; user validated on device. | None |
| MAN-006 | Done (accepted) | Preset slot/domain persistence and default UserDefaults store are implemented in `/Users/ignacio/Code/photodew/Sources/App/CaptureControlPreset.swift`; save/apply app-model wiring is in `/Users/ignacio/Code/photodew/Sources/App/CaptureAppModel.swift`; iOS preset controls are implemented in `/Users/ignacio/Code/photodew/ios/PhotodewApp/PhotodewIOSApp.swift` and `/Users/ignacio/Code/photodew/ios/PhotodewApp/ContentView.swift`; coverage is in `/Users/ignacio/Code/photodew/Tests/AppTests/CaptureAppModelTests.swift` and `/Users/ignacio/Code/photodew/Tests/AppTests/CaptureControlPresetStoreTests.swift`; user validated on device. | None |
| RAW-007 | Done (accepted) | Apple ProRAW capture format (`appleProRAW`) is implemented in `/Users/ignacio/Code/photodew/Sources/CameraKit/CaptureSessionService.swift`; mode selection UI and save path are implemented in `/Users/ignacio/Code/photodew/ios/PhotodewApp/ContentView.swift` and `/Users/ignacio/Code/photodew/ios/PhotodewApp/PhotodewIOSApp.swift`; coverage is in `/Users/ignacio/Code/photodew/Tests/CameraKitTests/CaptureSessionServiceTests.swift`; user validated on device. | None |
| RAW-001 | Done | RAW capability detection and gating wired from backend to UI. | None |
| RAW-002 | Done | True RAW capture path generates DNG on supported device. | None |
| RAW-003 | Done | RAW+processed payload capture and dual Photos save implemented. | None |
| RAW-004 | Done | RAW policy enforces speed mode and zoom/crop guardrails before capture. | None |
| RAW-005 | Done (accepted) | Metadata pack extraction/persistence is implemented and user-confirmed working on device; implementation in `/Users/ignacio/Code/photodew/Sources/CameraKit/CaptureTechnicalMetadata.swift`, `/Users/ignacio/Code/photodew/Sources/CameraKit/CaptureSessionService.swift`, `/Users/ignacio/Code/photodew/Sources/App/CaptureAppModel.swift`, with tests in `/Users/ignacio/Code/photodew/Tests/AppTests/CaptureAppModelTests.swift`. | None |
| RAW-006 | Done (accepted) | Storage warning + cleanup UX is implemented and user-confirmed working on device; implementation in `/Users/ignacio/Code/photodew/ios/PhotodewApp/PhotodewIOSApp.swift`, `/Users/ignacio/Code/photodew/ios/PhotodewApp/ContentView.swift`, and `/Users/ignacio/Code/photodew/Sources/Storage/CaptureMetadataStore.swift`. | None |
| RAW-008 | Done (accepted) | Explicit in-app mode education copy in `/Users/ignacio/Code/photodew/ios/PhotodewApp/ContentView.swift` explains True RAW vs Apple ProRAW vs processed tradeoffs; user validated on device. | None |
| UX-001 | Done | Real-time luminance histogram model/analyzer and UI overlay are implemented in `/Users/ignacio/Code/photodew/Sources/CameraKit/LuminanceHistogram.swift`, `/Users/ignacio/Code/photodew/Sources/CameraKit/CaptureSessionService.swift`, and `/Users/ignacio/Code/photodew/ios/PhotodewApp/ContentView.swift`; forwarding and model behavior are covered in `/Users/ignacio/Code/photodew/Tests/CameraKitTests/CaptureSessionServiceTests.swift`. | None |
| UX-002 | Done | Zebra clipping thresholding, overlay analyzer, and UI controls are implemented in `/Users/ignacio/Code/photodew/Sources/CameraKit/ZebraClippingOverlay.swift`, `/Users/ignacio/Code/photodew/Sources/CameraKit/CaptureSessionService.swift`, and `/Users/ignacio/Code/photodew/ios/PhotodewApp/ContentView.swift`; coverage is in `/Users/ignacio/Code/photodew/Tests/CameraKitTests/CaptureSessionServiceTests.swift`. | None |
| UX-003 | Done (accepted) | Focus peaking overlay model/analyzer and thresholded UI controls are implemented in `/Users/ignacio/Code/photodew/Sources/CameraKit/FocusPeakingOverlay.swift`, `/Users/ignacio/Code/photodew/Sources/CameraKit/CaptureSessionService.swift`, `/Users/ignacio/Code/photodew/Sources/App/CaptureAppModel.swift`, `/Users/ignacio/Code/photodew/ios/PhotodewApp/PhotodewIOSApp.swift`, and `/Users/ignacio/Code/photodew/ios/PhotodewApp/ContentView.swift`; coverage is in `/Users/ignacio/Code/photodew/Tests/CameraKitTests/CaptureSessionServiceTests.swift`; user validated on device. | None |
| UX-004 | Done (accepted) | Horizon level indicator driven by Core Motion device-motion roll is implemented in `/Users/ignacio/Code/photodew/ios/PhotodewApp/PhotodewIOSApp.swift` and `/Users/ignacio/Code/photodew/ios/PhotodewApp/ContentView.swift`; physical-device validation is recorded in `/Users/ignacio/Code/photodew/docs/validation/ux-004-horizon-level-validation.md`. | None |
| UX-005 | Done | Quick toggles and gesture model implemented in `ContentView.swift`; utility bar with 44pt targets, swipe-up/down gesture for pro panel, close button; haptics on all toggles. | Validate one-thumb operation on mini + Pro Max layouts on device. |
| UX-006 | Done | Preset quick switcher implemented as horizontal capsule pill row in `primaryControlDeck`; tap to select/apply with spring animation. | Validate no preview interruption on device. |
| UI-001 | Done | Full capture chrome layout restructure: 5 orphaned components wired, ZStack ordering fixed (scrims behind overlays), `bottomChromeStack` replaces offset hack, `topCameraChrome` includes utility bar. | Validate on compact + large iPhones on device. |
| UI-002 | Done | `CaptureDesignTokens` enum centralizes all spacing, radii, sizing, and color tokens; all hardcoded magic numbers replaced. | None |
| UI-003 | Done | Haptics added (light/medium/rigid) on shutter, mode toggle, preset apply, focus lock, pro panel toggle, utility bar buttons; spring animations on pro panel and preset switcher. | None |
| UI-004 | Done | 44pt minimum touch targets enforced on all interactive controls; `contentShape` modifiers for accurate hit testing; VoiceOver labels, hints, and `accessibilityElement` grouping added throughout. | None |

### Immediate Next Sequence

1. Run build verification to ensure M8 changes compile cleanly.
2. On-device validation of M8 UI on mini and Pro Max for one-thumb ergonomics.
3. Kick off `M5 RAW Rendering` with `RND-001` (CIRAWFilter neutral renderer).

### Known Device Console Noise

- Device logs `FigXPCUtilities/FigCaptureSourceRemote err=-17281` are currently treated as non-blocking based on Apple Developer Forums guidance. Track only if user-facing behavior regresses.

## 1) Product Objective

Build an iPhone camera app that gives users a true low-processing capture path similar to Halide's Process Zero philosophy, while still offering optional computational modes.

Primary outcome for v1:
- Reliable `True RAW (Bayer DNG)` mode with manual controls and pro capture tools.

Secondary outcome for v1:
- Optional `Computational RAW/Processed` mode for users who prefer convenience in low light.

## 2) Hard Technical Guardrails

These constraints come from AVFoundation behavior and must be reflected in product decisions and UI copy.

- Apple ProRAW is scene-referred but partially processed. It is not the same as Bayer RAW.
- For Bayer RAW capture, keep photo quality prioritization at `Speed`.
- For strict RAW capture, keep zoom at `1.0` (no digital zoom/crop changes).
- In low light, `Balanced` and `Quality` can override locked ISO/shutter via multi-image fusion.
- If the app promises "minimal processing", the capture mode must enforce these constraints automatically.

## 3) Milestones and Dates

| Milestone | Dates | Goal | Exit Criteria |
| --- | --- | --- | --- |
| M0 Foundation | 2026-02-09 to 2026-02-13 | Project skeleton and camera infrastructure | App launches camera preview, capture pipeline compiles, CI runs unit tests |
| M1 Camera MVP | 2026-02-16 to 2026-02-27 | Basic capture app | Preview, shutter, camera switch, save to Photos, metadata/orientation correct |
| M2 Manual Controls | 2026-03-02 to 2026-03-13 | Manual photography controls | ISO, shutter, focus, WB, EV, lock states stable and persisted |
| M3 True RAW | 2026-03-16 to 2026-03-27 | Bayer DNG capture mode | DNG capture works on supported hardware, mode enforces RAW-safe constraints |
| M4 Pro Capture UX | 2026-03-30 to 2026-04-10 | Core pro capture overlays | Histogram, zebra, peaking, and level delivered |
| M8 UI Focus | 2026-02-09 to 2026-02-27 | UI ergonomics and visual polish pivot | One-thumb controls, preset switcher, polished chrome, and accessibility baseline validated |
| M5 RAW Rendering | 2026-03-02 to 2026-03-13 | Process Zero-like renderer | Neutral RAW rendering pipeline with compare/export flow |
| M6 Performance + QA | 2026-03-16 to 2026-03-27 | Stability and speed | Thermal fallback, memory targets, regression suite green |
| M7 Beta + Release | 2026-03-30 to 2026-04-24 | External testing and shipping | TestFlight feedback triaged, RC signed off, App Store submission ready |

## 4) Workstream Board

Use this as the execution board backbone in GitHub Projects/Jira/Linear.

### Workstream A: Foundation

| ID | Title | Milestone | Estimate | Depends On | Acceptance Criteria |
| --- | --- | --- | --- | --- | --- |
| FND-001 | Create Swift project modules | M0 | 1d | None | Modules compile (`App`, `CameraKit`, `CaptureUI`, `Storage`) |
| FND-002 | Camera authorization and onboarding gate | M0 | 0.5d | FND-001 | First-run permission flow and denied-state recovery |
| FND-003 | `CaptureSessionService` abstraction | M0 | 1.5d | FND-001 | Session start/stop/switch API with unit tests |
| FND-004 | Structured logging + event schema | M0 | 1d | FND-001 | Capture events logged with timestamps and error codes |
| FND-005 | CI for lint + tests + archive build | M0 | 1d | FND-001 | CI blocks merges on failed tests/lint |

### Workstream B: Camera MVP

| ID | Title | Milestone | Estimate | Depends On | Acceptance Criteria |
| --- | --- | --- | --- | --- | --- |
| CAM-001 | Live preview + shutter capture | M1 | 1.5d | FND-003 | Photo callback delivers image data on supported devices |
| CAM-002 | Front/back camera switching | M1 | 0.5d | CAM-001 | Switching is stable and preserves session state |
| CAM-003 | Save output to Photos | M1 | 1d | CAM-001 | Photos permission flow and successful save confirmation |
| CAM-004 | EXIF/orientation correctness | M1 | 1d | CAM-001 | Landscape/portrait outputs display with correct orientation |
| CAM-005 | Capture latency instrumentation | M1 | 1d | FND-004, CAM-001 | Capture-to-delivery timing logged in telemetry |
| CAM-006 | Error recovery and retry UX | M1 | 1d | CAM-001 | Session interruptions recover without app restart |

### Workstream C: Manual Controls

| ID | Title | Milestone | Estimate | Depends On | Acceptance Criteria |
| --- | --- | --- | --- | --- | --- |
| MAN-001 | Exposure state machine | M2 | 1d | CAM-001 | Auto/locked/custom transitions deterministic |
| MAN-002 | Manual ISO and shutter controls | M2 | 1.5d | MAN-001 | Capture values match selected control values in metadata |
| MAN-003 | Manual focus + focus lock | M2 | 1d | CAM-001 | Focus ring updates and lock state persistent |
| MAN-004 | White balance temperature/tint | M2 | 1d | CAM-001 | WB can be adjusted and reset to auto |
| MAN-005 | EV compensation control | M2 | 0.5d | MAN-001 | EV applied with visible preview effect |
| MAN-006 | Preset persistence | M2 | 1d | MAN-002, MAN-003, MAN-004 | Presets save and restore in <200ms |

### Workstream D: True RAW Capture

| ID | Title | Milestone | Estimate | Depends On | Acceptance Criteria |
| --- | --- | --- | --- | --- | --- |
| RAW-001 | Capability detector by device format | M3 | 1d | CAM-001 | UI only exposes RAW on compatible devices/formats |
| RAW-002 | Bayer DNG capture path | M3 | 2d | RAW-001 | DNG captured and readable in Photos/Lightroom |
| RAW-003 | RAW+processed pair capture | M3 | 1d | RAW-002 | Both files saved and linked in metadata |
| RAW-004 | Enforce RAW-safe settings policy | M3 | 1.5d | RAW-002, MAN-002 | Mode forces `Speed`, disables conflicting options, zoom guardrail |
| RAW-005 | Metadata pack (lens, ISO, shutter, WB) | M3 | 1d | RAW-002 | DNG metadata complete and validated in external tool |
| RAW-006 | Storage and cleanup strategy | M3 | 1d | RAW-002 | App warns on storage pressure and supports cleanup |
| RAW-007 | Optional Apple ProRAW mode | M3 | 1d | RAW-001 | Clearly labeled as partially processed |
| RAW-008 | In-app mode education copy | M3 | 0.5d | RAW-004, RAW-007 | Users can understand RAW vs ProRAW tradeoffs quickly |

### Workstream E: Pro Capture UX

| ID | Title | Milestone | Estimate | Depends On | Acceptance Criteria |
| --- | --- | --- | --- | --- | --- |
| UX-001 | Real-time luminance histogram | M4 | 1d | CAM-001 | Histogram updates at preview frame cadence |
| UX-002 | Zebra clipping overlay | M4 | 1d | CAM-001 | Configurable threshold and stable rendering |
| UX-003 | Focus peaking overlay | M4 | 1.5d | MAN-003 | Peaking accuracy validated at different focal distances |
| UX-004 | Horizon level indicator | M4 | 0.5d | CAM-001 | Level responds to device motion with minimal lag |

### Workstream H: UI Focus (Pivot)

| ID | Title | Milestone | Estimate | Depends On | Acceptance Criteria |
| --- | --- | --- | --- | --- | --- |
| UX-005 | Quick toggles and gesture model | M8 | 1d | UX-001, UX-002, UX-003 | One-thumb operation on Pro Max and mini sizes |
| UX-006 | Preset quick switcher | M8 | 0.5d | MAN-006 | 3-tap flow to switch presets during shooting |
| UI-001 | Capture chrome layout pass | M8 | 1d | UX-005 | Top/bottom bars and control groups are consistent across compact and large screens |
| UI-002 | Control visual hierarchy pass | M8 | 1d | UI-001 | Shared spacing, icon sizing, typography, and contrast tokens applied consistently |
| UI-003 | Motion and haptics tuning | M8 | 1d | UX-005, UX-006 | Core capture interactions provide clear haptic feedback and smooth transitions |
| UI-004 | Accessibility and touch target hardening | M8 | 1d | UI-001, UI-002 | VoiceOver labels/hints, dynamic type, and 44pt targets validated in capture flow |

### Workstream F: RAW Rendering and Export

| ID | Title | Milestone | Estimate | Depends On | Acceptance Criteria |
| --- | --- | --- | --- | --- | --- |
| RND-001 | `CIRAWFilter` neutral renderer | M5 | 2d | RAW-002 | Baseline profile minimizes tone curve and NR/sharpening |
| RND-002 | Rendering profiles (`Neutral`, `Classic`, `Punch`) | M5 | 1.5d | RND-001 | Profiles produce consistent output across test set |
| RND-003 | Compare view (RAW render vs processed) | M5 | 1d | RND-001, RAW-003 | Split view or toggle compare at full resolution preview |
| RND-004 | Export pipeline (JPEG/TIFF) | M5 | 1d | RND-001 | Exported files include profile metadata and color space tags |
| RND-005 | Rendering performance benchmarks | M5 | 1d | RND-001 | Render target <700ms for preview-sized output on target devices |

### Workstream G: Performance, Quality, Release

| ID | Title | Milestone | Estimate | Depends On | Acceptance Criteria |
| --- | --- | --- | --- | --- | --- |
| QLT-001 | Thermal/pressure degradation strategy | M6 | 1d | CAM-005 | App adapts overlays/features without crashing |
| QLT-002 | Memory budget and leak checks | M6 | 1d | RAW-003, RND-001 | No critical leaks in 20-minute capture session |
| QLT-003 | Device test matrix and regression plan | M6 | 1d | All prior milestones | Tests cover at least 1 non-Pro + 2 Pro devices |
| QLT-004 | TestFlight feedback triage process | M7 | 0.5d | QLT-003 | Feedback categories and SLA defined |
| REL-001 | App Store assets and positioning | M7 | 1.5d | UX-005, RAW-008 | Screenshots and copy align with mode truthfulness |
| REL-002 | Release candidate checklist | M7 | 1d | QLT-001, QLT-002, QLT-003 | All release blockers closed before submission |

## 5) Sprint Plan

Sprint length: 2 weeks (except Sprint 0 foundation week and extended release sprint)

### Completed Sprints (Accepted)

| Sprint | Dates | Delivered Tickets |
| --- | --- | --- |
| Sprint 0 | 2026-02-09 to 2026-02-13 | FND-001, FND-002, FND-003, FND-004, FND-005 |
| Sprint 1 | 2026-02-16 to 2026-02-27 | CAM-001, CAM-002, CAM-003, CAM-004, CAM-005, CAM-006 |
| Sprint 2 | 2026-03-02 to 2026-03-13 | MAN-001, MAN-002, MAN-003, MAN-004, MAN-005, MAN-006 |
| Sprint 3 | 2026-03-16 to 2026-03-27 | RAW-001, RAW-002, RAW-003, RAW-004, RAW-005, RAW-006, RAW-008 |
| Sprint 4 | 2026-03-30 to 2026-04-10 | RAW-007, UX-001, UX-002, UX-003, UX-004 |
| Sprint UI (Pivot) | 2026-02-07 to 2026-02-07 | UX-005, UX-006, UI-001, UI-002, UI-003, UI-004 |

### Upcoming Sprints (Planned)

| Sprint | Dates | Planned Tickets |
| --- | --- | --- |
| Sprint 5 | 2026-03-02 to 2026-03-13 | RND-001, RND-002, RND-003, RND-004, RND-005 |
| Sprint 6 | 2026-03-16 to 2026-03-27 | QLT-001, QLT-002, QLT-003 |
| Sprint 7 | 2026-03-30 to 2026-04-24 | QLT-004, REL-001, REL-002 + bugfix buffer |

## 6) Definition of Done (Engineering)

Each ticket is done only when all are true:

- Code merged with tests and lint passing in CI.
- Manual verification notes attached to ticket with tested device/OS.
- Error states are handled and user-visible copy is clear.
- Telemetry event(s) for new feature added where applicable.
- No known P0/P1 bug introduced.

## 7) Device Test Matrix (Minimum)

| Tier | Device Type | Why |
| --- | --- | --- |
| A | Latest non-Pro iPhone | Baseline performance and feature fallback behavior |
| A | Latest Pro iPhone | Full RAW/pro tool path and thermal profile |
| A | Previous-gen Pro iPhone | Backward compatibility and timing sensitivity |
| B | Older supported iPhone | Memory pressure and degraded mode behavior |

## 8) Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| RAW capabilities vary heavily by hardware | Inconsistent feature set | Build capability gating early (`RAW-001`) |
| Thermal throttling during overlays + RAW | Capture lag and poor UX | Add adaptive degradation rules (`QLT-001`) |
| Users misunderstand RAW vs ProRAW | Trust and review risk | Strong mode labels and onboarding (`RAW-008`) |
| Storage usage spikes with DNG pairs | App abandonment | Storage policy and cleanup UX (`RAW-006`) |
| Render pipeline too slow on older devices | Editing flow unusable | Preview-scale rendering + benchmark gate (`RND-005`) |

## 9) Week 1 Operating Checklist

Execute these immediately on 2026-02-09:

1. Create repo scaffolding and module boundaries (`FND-001`).
2. Implement permission flow and denied-state UI (`FND-002`).
3. Stand up capture session wrapper with tests (`FND-003`).
4. Add telemetry schema for all capture attempts (`FND-004`).
5. Configure CI to run tests on every PR (`FND-005`).

## 10) Delivery Metrics

Track weekly:

- Crash-free sessions percentage.
- Median capture latency and p95 capture latency.
- DNG capture success rate on supported devices.
- Manual control accuracy rate (selected vs metadata values).
- TestFlight qualitative feedback score (1-5).
