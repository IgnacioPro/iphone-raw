# RAW-005 Metadata Pack Validation

Last updated: 2026-02-07
Status: Completed (accepted via on-device validation on 2026-02-07)

## Goal

Validate that capture metadata persisted by Photodew includes lens, ISO, shutter, and white balance values for RAW captures.

## Validation Summary

- User executed on-device validation and confirmed the RAW metadata flow works.
- Ticket accepted as done by user decision on 2026-02-07.

## Implemented Fields

- `capture_lens_model`
- `capture_iso`
- `capture_shutter_seconds`
- `capture_white_balance_mode`
- `capture_white_balance_temperature_kelvin`
- `capture_white_balance_tint`
- `paired_capture_lens_model`
- `paired_capture_iso`
- `paired_capture_shutter_seconds`
- `paired_capture_white_balance_mode`
- `paired_capture_white_balance_temperature_kelvin`
- `paired_capture_white_balance_tint`

## Validation Steps

1. Capture at least one RAW photo (DNG + processed pair) on a physical iPhone.
2. Export both files to local disk.
3. Inspect metadata in exported files with:

```bash
exiftool -LensModel -ISO -ExposureTime -WhiteBalance -AsShotNeutral <file>
```

4. Compare exported values with Photodew capture metadata saved in app logs (`capture_metadata_saved` payload) and verify lens/ISO/shutter/WB consistency.
5. Mark pass/fail and note any drift outside expected tolerance.

## Completion Criteria

- At least one RAW pair capture passes lens/ISO/shutter/WB comparison.
- Any mismatch has a linked bug with repro and affected device/OS.
