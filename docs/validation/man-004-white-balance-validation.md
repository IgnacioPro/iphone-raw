# MAN-004 White Balance Temperature and Tint Validation

Last updated: 2026-02-07
Status: Accepted (user-validated on device on 2026-02-07)

## Goal

Validate that white balance temperature/tint can be locked from UI controls and reset back to auto mode without restarting the camera session.

## Implemented Behavior

- White balance state machine supports deterministic `auto` and `locked` transitions.
- Service applies white balance state to backend configuration and rolls back on apply failure.
- White balance state is reapplied after session start and camera switch.
- iOS UI includes:
  - temperature slider,
  - tint slider,
  - `Auto WB` action,
  - `Lock WB` action.
- Unit tests cover white balance transitions, failure rollback, state persistence across camera switch, and metadata propagation in simulated captures.

## Validation Steps

1. Launch Photodew on a physical iPhone and enter camera preview.
2. Move temperature and tint sliders to distinct values, then tap `Lock WB`.
3. Confirm the mode summary updates to `White balance mode: Locked (...)`.
4. Capture a photo and verify no capture/recovery errors occur.
5. Tap `Auto WB` and confirm the mode summary returns to `White balance mode: Auto`.
6. Switch cameras and repeat step 2 and step 5.

## Completion Criteria

- WB lock applies from UI controls and shows locked state.
- `Auto WB` reliably resets mode to auto.
- Camera capture remains stable after WB changes and camera switching.

## Validation Notes

- User confirmed the app behavior worked on device and asked to continue on 2026-02-07.
