import App
import Foundation
import Testing

@Suite("CaptureControlPresetStore")
struct CaptureControlPresetStoreTests {
    @Test("UserDefaults store round-trips presets by slot")
    func userDefaultsRoundTrip() throws {
        let suiteName = "CaptureControlPresetStoreTests-\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create isolated UserDefaults suite.")
            return
        }
        userDefaults.removePersistentDomain(forName: suiteName)

        let store = UserDefaultsCapturePresetStore(userDefaults: userDefaults)
        let preset1 = CaptureControlPreset(
            exposureState: CapturePresetExposureState(
                mode: .locked,
                iso: 160,
                shutterSeconds: 1.0 / 120.0
            ),
            focusState: CapturePresetFocusState(mode: .locked, lensPosition: 0.5),
            whiteBalanceState: CapturePresetWhiteBalanceState(
                mode: .locked,
                temperatureKelvin: 5_200,
                tint: -8
            ),
            exposureCompensation: 0.4,
            savedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let preset2 = CaptureControlPreset(
            exposureState: CapturePresetExposureState(mode: .auto, iso: nil, shutterSeconds: nil),
            focusState: CapturePresetFocusState(mode: .auto, lensPosition: nil),
            whiteBalanceState: CapturePresetWhiteBalanceState(
                mode: .auto,
                temperatureKelvin: nil,
                tint: nil
            ),
            exposureCompensation: 0,
            savedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )

        try store.save(preset1, for: .preset1)
        try store.save(preset2, for: .preset3)

        #expect(try store.load(for: .preset1) == preset1)
        #expect(try store.load(for: .preset2) == nil)
        #expect(try store.load(for: .preset3) == preset2)
        #expect(try store.availableSlots() == Set([.preset1, .preset3]))

        userDefaults.removePersistentDomain(forName: suiteName)
    }
}
