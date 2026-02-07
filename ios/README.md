# iOS Wrapper App

This folder contains a lightweight Xcode app wrapper (`PhotodewApp`) that links against the local Swift package products in the repo root.

## Generate Project

Run from repo root:

```bash
./scripts/generate_xcodeproj.sh
```

This generates:

- `ios/PhotodewApp.xcodeproj`

## Open in Xcode

```bash
open ios/PhotodewApp.xcodeproj
```

Then:

1. Select the `PhotodewApp` scheme.
2. Pick an iOS Simulator or a connected iPhone.
3. Build and run.

## Notes

- The wrapper target depends on local package products: `App` and `CaptureUI`.
- Camera permission copy is injected via generated Info.plist settings.
- If signing is required on device, set your team and bundle identifier in Xcode target settings.
- The iOS Simulator does not provide real camera input for this app flow; run on a physical iPhone for camera capture testing.
