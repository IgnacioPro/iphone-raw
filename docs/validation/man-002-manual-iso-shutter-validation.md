# MAN-002 Manual ISO and Shutter Validation

Last updated: 2026-02-07
Status: Accepted (user-validated on device on 2026-02-07)

## Goal

Validate that manual ISO and shutter selections are applied to capture and reflected in persisted capture metadata.

## Implemented Behavior

- In-app manual exposure controls:
  - `Auto` action
  - ISO picker
  - Shutter picker
  - `Apply ISO/Shutter` action
- Service-level exposure transitions are now applied through camera backend configuration.
- Exposure state is reapplied after session start/camera switch to keep behavior deterministic.
- Unit tests assert manual exposure values appear in capture metadata payload.

## Validation Steps

1. Launch Photodew on a physical iPhone and enter camera preview.
2. Set a distinct manual exposure:
   - choose an ISO from the picker,
   - choose a shutter speed from the picker,
   - tap `Apply ISO/Shutter`.
3. Capture a photo in processed mode.
4. Confirm the exposure mode summary in-app shows the selected ISO/shutter pair.
5. Repeat with another noticeably different ISO/shutter pair.
6. Tap `Auto` and capture again; confirm mode returns to `Auto`.

## Completion Criteria

- Manual ISO/shutter values can be changed from the UI without session restart.
- Captures succeed after applying manual exposure and after returning to auto.
- The app remains stable during camera switching and manual exposure changes.

## Validation Notes

- User confirmed manual ISO/shutter flows worked on device and asked to mark the ticket done on 2026-02-07.
