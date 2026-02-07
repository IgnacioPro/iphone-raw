# UX-003 Focus Peaking Overlay Validation

Last updated: 2026-02-07
Status: Completed (accepted via on-device validation on 2026-02-07)

## Goal

Validate that focus peaking overlay highlights high-detail edges reliably while manual focus changes, and that threshold controls behave predictably without destabilizing capture.

## Validation Summary

- User validated on-device focus peaking behavior and accepted ticket completion on 2026-02-07.

## Implemented Behavior

- Added real-time focus peaking analysis from preview frames in `CaptureSessionService`.
- Added `Focus Peaking` overlay model and handler/threshold API surface.
- Added UI controls to enable/disable peaking and adjust threshold.
- Added green peaking overlay rendering on preview.
- Added service-level tests for threshold forwarding and overlay ratio behavior.

## Validation Steps

1. Launch Photodew on a physical iPhone and ensure camera permission is granted.
2. Open controls and expand the `Focus Peaking` section.
3. Enable peaking and verify a green overlay appears only on detail/edge regions.
4. Set focus to `Auto Focus`, point at a scene with near and far detail, and confirm overlay updates smoothly with scene changes.
5. Switch to manual focus lock and move the focus slider from low to high values:
   - confirm highlighted regions shift between near and far subjects,
   - confirm no UI freezes or session interruption occurs.
6. Test threshold behavior:
   - lower threshold near 12% and confirm more peaking coverage,
   - raise threshold near 40% and confirm less peaking coverage,
   - tap `Apply Threshold` after each change and verify immediate effect.
7. Toggle peaking off and on repeatedly:
   - overlay should disappear immediately when disabled,
   - overlay should resume quickly when enabled,
   - no capture controls should become blocked.
8. Capture photos in `Processed`, `True RAW`, and `Apple ProRAW` modes while peaking is enabled to confirm capture/save behavior remains unchanged.

## Completion Criteria

- Focus peaking tracks focus plane changes in typical near/far scenes.
- Threshold control produces clear, proportional changes in highlighted regions.
- No crashes, severe lag, or capture regressions while peaking is enabled.
