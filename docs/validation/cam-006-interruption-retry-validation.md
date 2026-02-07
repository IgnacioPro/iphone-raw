# CAM-006 Interruption and Retry UX Validation

Last updated: 2026-02-07
Status: Accepted (user-validated on device on 2026-02-07)

## Goal

Validate that camera interruptions and runtime failures recover without app restart and provide clear retry copy.

## Implemented Behavior

- Session interruption observers now handle interrupted, ended, and runtime-error notifications.
- App shows interruption/runtime recovery copy in the capture panel.
- App auto-recovers session after interruption end/runtime error/timeout.
- Manual `Retry Camera Session` action is available when capture errors are shown.

## Validation Steps

1. Launch Photodew on a physical iPhone and enter camera preview.
2. Trigger interruption scenarios:
   - background the app and return,
   - start another camera-using app briefly, then return.
3. Confirm app shows recovery copy and returns to ready capture state without force quit.
4. Trigger capture timeout/failure path (if reproducible) and confirm:
   - retry copy appears,
   - `Retry Camera Session` works,
   - shutter recovers.

## Completion Criteria

- Session recovers from interruption scenarios without app restart.
- Retry copy/action are visible and actionable.
- No persistent broken camera state remains after recovery.

## Validation Notes

- User confirmed CAM-006 behavior looked correct on a physical device and accepted the ticket as done on 2026-02-07.
