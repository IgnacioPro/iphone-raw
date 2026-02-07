# MAN-005 EV Compensation Validation

Last updated: 2026-02-07
Status: Pending on-device validation

## Goal

Validate that exposure compensation (EV) can be adjusted and reset from the app UI with visible preview impact while the session remains stable.

## Implemented Behavior

- Capture service exposes EV compensation state and applies it through backend configuration.
- EV value is reapplied after session start and camera switch.
- iOS UI includes:
  - EV slider,
  - `Apply EV` action,
  - `Reset EV` action.
- Manual controls panel can be collapsed (`Show Controls` / `Hide Controls`) so shutter testing remains accessible.
- Tests cover EV apply/reset, failure rollback, and persistence across camera switch.

## Validation Steps

1. Launch Photodew on a physical iPhone and enter camera preview.
2. Tap `Show Controls` if controls are collapsed.
3. Move EV slider to a positive value (for example `+1.0`) and tap `Apply EV`.
4. Confirm preview appears brighter and EV readout updates.
5. Capture a photo and verify no capture/recovery errors occur.
6. Set a negative EV value (for example `-1.0`), apply, and confirm preview darkens.
7. Tap `Reset EV` and confirm EV returns to `0.0 EV`.
8. Switch cameras and verify EV controls still apply without session failure.

## Completion Criteria

- EV adjustments apply from the UI and visibly affect preview exposure.
- `Reset EV` restores neutral compensation (`0.0 EV`).
- Capture remains stable before and after EV changes and camera switching.
