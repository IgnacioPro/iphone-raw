# MAN-001 Exposure State Machine Validation

Last updated: 2026-02-07
Status: Complete (unit-test validated)

## Goal

Ensure exposure mode transitions are deterministic across `auto`, `locked`, and `custom` states.

## Implemented Behavior

- Added `ExposureStateMachine` with explicit transitions:
  - `.setAuto`
  - `.lock(ExposureValues)`
  - `.setCustom(ExposureValues)`
- Added value validation for exposure parameters:
  - ISO must be finite and positive.
  - Shutter seconds must be finite and positive.
- Integrated state machine into capture service and app model surfaces.

## Validation Evidence

- `swift test` passes with deterministic transition coverage:
  - `ExposureStateMachineTests`
  - `CaptureSessionServiceTests` exposure transition coverage
  - `CaptureAppModelTests` exposure passthrough coverage

## Completion Criteria

- Transition sequences produce deterministic final states.
- Invalid exposure values throw without mutating prior state.
- Service and app model expose the state machine for upcoming manual controls work.
