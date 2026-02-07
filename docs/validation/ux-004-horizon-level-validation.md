# UX-004 Horizon Level Indicator Validation

Last updated: 2026-02-07
Status: Completed (accepted via manual on-device validation on 2026-02-07)

## Goal

Validate that the horizon level indicator tracks roll/tilt with low lag and gives clear near-level feedback while composing shots.

## Validation Summary

- Code implementation and build/test checks are complete.
- Manual physical-device validation completed by user.
- Ticket accepted as done by user decision.

## Implemented Behavior

- Added Core Motion device-motion updates (`CMMotionManager`) in the iOS bootstrap view model.
- Selected a vertical-axis attitude reference frame with preference for corrected arbitrary frame.
- Converted `attitude.roll` radians to normalized degrees and applied lightweight smoothing.
- Added a top-bar horizon indicator that rotates opposite device roll and shows degree readout.
- Added controls-panel status text showing current roll and level state.

## Validation Steps

1. Launch Photodew on a physical iPhone and grant camera access.
2. Keep the phone upright and stable:
   - verify the horizon indicator appears in the top bar,
   - verify status reports near 0° and `Level` when device is flat/upright.
3. Slowly roll the phone left/right:
   - indicator line should rotate smoothly with minimal lag,
   - degree readout should change direction and magnitude correctly.
4. Return device to level:
   - indicator color should return to `Level` state near 0°.
5. Capture photos in `Processed`, `True RAW`, and `Apple ProRAW` while moving roll:
   - capture should remain stable with no added interruptions.
6. Leave app to background and return:
   - motion tracking should resume,
   - indicator should continue updating without stale values.

## Completion Criteria

- Horizon indicator tracks device roll smoothly enough for framing guidance.
- Near-level feedback is visually clear and repeatable.
- No regressions in capture reliability while indicator is active.
