# CAM-004 Orientation and EXIF Validation Matrix

Last updated: 2026-02-07
Status: Completed (accepted via manual on-device validation on 2026-02-07)

## Scope

Validate orientation and EXIF correctness for processed and RAW capture outputs across front and back cameras in portrait and landscape capture positions.

## Test Environment

| Field | Value |
| --- | --- |
| Device model | `<user device>` |
| iOS version | `<user device>` |
| Build | `<current local build>` |
| App commit | `<workspace HEAD>` |
| Tester | User |
| Date | 2026-02-07 |

## Validation Summary

- Manual on-device smoke validation completed by user.
- User confirmed captures succeed in both RAW and processed/JPEG modes.
- Ticket accepted as done by user decision.

## Validation Matrix

| Case ID | Lens | Capture mode | Device orientation at shutter | Expected Photos orientation | Expected metadata checks | Result | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| ORI-001 | Back | Processed | Portrait (upright) | Upright portrait display | EXIF orientation exists and resolves to upright portrait | Pending | `<screenshot / notes>` |
| ORI-002 | Back | Processed | Landscape left | Correct landscape display | EXIF orientation exists and resolves to landscape-left capture | Pending | `<screenshot / notes>` |
| ORI-003 | Back | Processed | Landscape right | Correct landscape display | EXIF orientation exists and resolves to landscape-right capture | Pending | `<screenshot / notes>` |
| ORI-004 | Front | Processed | Portrait (upright) | Upright portrait display without unintended rotation | EXIF orientation exists and is valid for front camera output | Pending | `<screenshot / notes>` |
| ORI-005 | Front | Processed | Landscape left | Correct landscape display | EXIF orientation exists and resolves correctly | Pending | `<screenshot / notes>` |
| ORI-006 | Back | RAW | Portrait (upright) | RAW and processed pair both display correctly | DNG + processed pair include orientation metadata and values are coherent | Pending | `<screenshot / notes>` |
| ORI-007 | Back | RAW | Landscape left | RAW and processed pair both display correctly | DNG + processed pair include orientation metadata and values are coherent | Pending | `<screenshot / notes>` |
| ORI-008 | Front | RAW | Portrait (upright) | RAW and processed pair both display correctly | DNG + processed pair include orientation metadata and values are coherent | Pending | `<screenshot / notes>` |

## Execution Steps

1. Launch Photodew on a physical iPhone and grant Camera + Photos permissions.
2. For each case above, frame a scene with obvious orientation cues, capture, and save.
3. Verify visual orientation in Photos first.
4. Export files from Photos to Files/Mac for metadata inspection.
5. Record pass/fail and attach screenshots or metadata snippets in the matrix.

## Metadata Inspection Notes

Use one of these commands after exporting a file to local disk:

```bash
mdls -name kMDItemOrientation -name kMDItemPixelWidth -name kMDItemPixelHeight <file>
```

If `exiftool` is installed:

```bash
exiftool -Orientation -ImageWidth -ImageHeight -Make -Model <file>
```

For RAW captures, inspect both DNG and processed pair files.

## Completion Criteria

- All matrix cases are marked `Pass`.
- Each case has attached evidence (UI screenshot, metadata output, or both).
- Any failure has a linked bug and repro notes.
