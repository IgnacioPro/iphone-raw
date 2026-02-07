# RAW-007 Apple ProRAW Mode Validation

Last updated: 2026-02-07
Status: Completed (accepted via on-device validation on 2026-02-07)

## Goal

Validate that Apple ProRAW mode is available only when supported, clearly labeled, and captures/saves correctly without breaking existing True RAW or processed flows.

## Validation Summary

- User confirmed on-device Apple ProRAW capture worked as expected.
- Ticket accepted as done by user decision on 2026-02-07.

## Implemented Behavior

- Capture format now includes `Processed`, `True RAW`, and `Apple ProRAW`.
- Capability checks distinguish Bayer RAW support from Apple ProRAW support.
- Apple ProRAW captures use the Apple ProRAW pixel format when available and save a single DNG asset.
- True RAW capture behavior remains unchanged (RAW + processed pair).
- Mode guide copy explains Apple ProRAW is partially processed scene-referred RAW, not Bayer RAW.

## Validation Steps

1. Launch Photodew on a physical iPhone with Apple ProRAW support and camera permission granted.
2. Open controls and verify all three mode buttons are present:
   - `Processed`
   - `True RAW`
   - `Apple ProRAW`
3. Confirm capability lines show:
   - `True RAW: Supported` (or clear unavailable reason on devices without Bayer RAW),
   - `Apple ProRAW: Supported` (or clear unavailable reason where unsupported).
4. Select `Apple ProRAW` and capture a photo.
5. Verify:
   - capture succeeds with no recovery error,
   - the photo is saved to Photos as DNG,
   - app metadata records `capture_format = appleProRAW`.
6. Switch to `True RAW` and capture once; confirm RAW + processed paired save still works.
7. Switch to `Processed` and capture once; confirm normal JPEG save still works.
8. Repeat steps 4-7 after switching front/back camera to ensure unsupported mode fallback is clear and safe.

## Completion Criteria

- Apple ProRAW mode is selectable only when supported and displays truthful capability status.
- Apple ProRAW captures save successfully without regressions in True RAW or processed modes.
- Unsupported devices/camera configurations show clear non-crashing guidance.
