# MAN-006 Preset Persistence Validation

Last updated: 2026-02-07
Status: Accepted (user-validated on device on 2026-02-07)

## Goal

Validate that manual control presets can be saved into slots, persisted across app relaunch, and reapplied to restore exposure/focus/white-balance/EV settings.

## Implemented Behavior

- App model can snapshot current control state into preset slots (`Preset 1` to `Preset 3`).
- Presets persist via UserDefaults store and survive app relaunch.
- Preset apply path restores:
  - exposure state (`auto`, `locked`, or `custom` values),
  - focus state (`auto` or locked lens position),
  - white balance state (`auto` or locked temperature/tint),
  - exposure compensation (EV).
- iOS UI includes:
  - preset slot segmented selector,
  - `Save Preset` action,
  - `Apply Preset` action (disabled when selected slot is empty),
  - status line showing saved timestamp or empty state.
- Unit tests cover:
  - UserDefaults preset round-trip and slot enumeration,
  - save/load/apply behavior through `CaptureAppModel`.

## Validation Steps

1. Launch Photodew on a physical iPhone and enter camera preview.
2. Set a distinct manual configuration:
   - set custom ISO/shutter and apply,
   - lock focus to a clear non-default value,
   - lock white balance temperature/tint,
   - apply non-zero EV compensation.
3. Select `Preset 1` and tap `Save Preset`.
4. Change controls back toward defaults (`Auto`, `Auto Focus`, `Auto WB`, `Reset EV`) and confirm mode summaries reflect the defaults.
5. Tap `Apply Preset` for `Preset 1` and confirm all four control groups restore to the saved values.
6. Save a different configuration to `Preset 2` and verify slot switching shows `Preset 1` and `Preset 2` as populated while `Preset 3` remains empty.
7. Background/terminate and relaunch the app, then open controls and re-apply `Preset 1`; confirm values still restore.
8. Capture a photo after preset apply and verify no capture/recovery error is shown.

## Completion Criteria

- Saved presets restore full control state without app restart.
- Preset slot contents persist across app relaunch.
- Empty slot cannot be applied from UI.
- Capture remains stable after applying a preset.

## Validation Notes

- User confirmed preset persistence worked on device and asked to continue on 2026-02-07.
