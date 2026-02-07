# RAW-006 Storage Pressure and Cleanup Validation

Last updated: 2026-02-07
Status: Completed (accepted via on-device validation on 2026-02-07)

## Goal

Validate low-storage warning behavior and cleanup action for recent captures.

## Validation Summary

- User executed on-device validation and confirmed storage warning/cleanup behavior works.
- Ticket accepted as done by user decision on 2026-02-07.

## Implemented Behavior

- App computes available storage and shows a warning when available capacity is at or below `5 GB`.
- Warning copy is shown in capture UI.
- `Clean Last Capture` deletes the most recent saved capture assets from Photos.
- Metadata entries for deleted local identifiers are removed from the app metadata store.

## Validation Steps

1. Run Photodew on a physical iPhone with low available storage (or temporarily lower the warning threshold for a debug build).
2. Capture a RAW photo pair.
3. Confirm low-storage warning is visible in the bottom panel.
4. Tap `Clean Last Capture`.
5. Confirm:
   - cleanup toast appears,
   - capture is removed from Photos,
   - no cleanup error is shown.

## Completion Criteria

- Warning appears under low-storage conditions.
- Cleanup action successfully deletes last saved assets and does not crash.
- Failure paths show clear user-facing error copy when Photos read-write permission is unavailable.
