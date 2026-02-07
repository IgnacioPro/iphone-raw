# MAN-003 Manual Focus and Focus Lock Validation

Last updated: 2026-02-07
Status: Accepted (user-validated on device on 2026-02-07)

## Goal

Validate that manual focus lock can be adjusted from the app UI, reset to auto focus, and remain stable through normal capture flow.

## Implemented Behavior

- Focus state machine supports deterministic `auto` and `locked` transitions.
- Service applies focus state to camera backend and rolls back state on apply failure.
- Focus state is reapplied after session start and camera switch.
- iOS UI exposes focus lens-position slider with `Auto Focus` and `Lock Focus` actions.

## Validation Steps

1. Launch Photodew on a physical iPhone and enter camera preview.
2. Move the focus slider to a distinct value and tap `Lock Focus`.
3. Confirm the focus mode summary updates to `Locked`.
4. Capture a photo and confirm the app stays responsive.
5. Tap `Auto Focus` and confirm summary returns to `Auto`.
6. Switch cameras and verify focus controls still function.

## Completion Criteria

- Focus can be locked and returned to auto from the UI.
- Capture remains stable after focus changes.
- Camera switching does not break focus controls.

## Validation Notes

- User confirmed the behavior looked correct on a physical device and accepted MAN-003 as done on 2026-02-07.
