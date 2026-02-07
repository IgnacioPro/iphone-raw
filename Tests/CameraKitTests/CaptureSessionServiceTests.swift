import CameraKit
import Foundation
import Testing
#if canImport(AVFoundation)
import AVFoundation
#endif

@Suite("CaptureSessionService")
struct CaptureSessionServiceTests {
    @Test("start updates state to running")
    func startTransitionsToRunning() throws {
        let backend = StubCaptureBackend()
        let logger = InMemoryCaptureEventLogger()
        let service = CaptureSessionService(backend: backend, logger: logger)

        try service.start()

        #expect(service.state == .running(position: .back))
        #expect(logger.events.contains(where: { $0.action == "session_started" }))
    }

    @Test("switchCamera changes active position and emits log")
    func switchCamera() throws {
        let backend = StubCaptureBackend()
        let logger = InMemoryCaptureEventLogger()
        let service = CaptureSessionService(backend: backend, logger: logger)
        try service.start()

        try service.switchCamera()

        #expect(service.state == .running(position: .front))
        #expect(logger.events.contains(where: { $0.action == "camera_switched" }))
    }

    @Test("backend start failure becomes failed state")
    func startFailure() {
        let backend = StubCaptureBackend(shouldFailStart: true)
        let logger = InMemoryCaptureEventLogger()
        let service = CaptureSessionService(backend: backend, logger: logger)

        #expect(throws: CaptureSessionError.self) {
            try service.start()
        }

        guard case let .failed(message) = service.state else {
            Issue.record("Service did not enter failed state.")
            return
        }

        #expect(message.contains("startup failed"))
        #expect(logger.events.contains(where: { $0.action == "session_start_failed" }))
    }

    @Test("capturePhoto returns bytes and logs success")
    func capturePhotoSuccess() async throws {
        let backend = StubCaptureBackend(captureData: Data([0x01, 0x02, 0x03]))
        let logger = InMemoryCaptureEventLogger()
        let service = CaptureSessionService(backend: backend, logger: logger)
        try service.start()

        let data = try await service.capturePhoto()

        #expect(data == Data([0x01, 0x02, 0x03]))
        #expect(logger.events.contains(where: { $0.action == "photo_capture_started" }))
        #expect(logger.events.contains(where: { $0.action == "photo_capture_succeeded" }))
        guard let startedEvent = logger.events.first(where: { $0.action == "photo_capture_started" }),
              let successEvent = logger.events.first(where: { $0.action == "photo_capture_succeeded" }) else {
            Issue.record("Expected start and success capture telemetry events.")
            return
        }

        #expect(startedEvent.payload["format"] == "processed")
        #expect(successEvent.payload["format"] == "processed")
        #expect(successEvent.payload["capture_id"] == startedEvent.payload["capture_id"])
        #expect(successEvent.payload["bytes"] == "3")
        #expect(successEvent.payload["total_bytes"] == "3")
        guard let latencyValue = successEvent.payload["capture_latency_ms"],
              let latencyMilliseconds = Int(latencyValue) else {
            Issue.record("Expected capture_latency_ms in success telemetry payload.")
            return
        }
        #expect(latencyMilliseconds >= 0)
    }

    @Test("raw capture exposes RAW and processed pair payload")
    func rawCapturePayload() async throws {
        let processedMetadata = CaptureTechnicalMetadata(
            lensModel: "Back Wide Camera",
            iso: 80,
            shutterSeconds: 0.02,
            whiteBalanceMode: "auto",
            whiteBalanceTemperatureKelvin: 4_800,
            whiteBalanceTint: 1
        )
        let rawMetadata = CaptureTechnicalMetadata(
            lensModel: "Back Wide Camera",
            iso: 64,
            shutterSeconds: 0.016_666,
            whiteBalanceMode: "manual",
            whiteBalanceTemperatureKelvin: 5_000,
            whiteBalanceTint: -4
        )
        let backend = StubCaptureBackend(
            capturePayload: CapturedPhotoPayload(
                processedData: Data([0x10, 0x20]),
                rawData: Data([0xAA, 0xBB, 0xCC]),
                processedMetadata: processedMetadata,
                rawMetadata: rawMetadata
            )
        )
        let logger = InMemoryCaptureEventLogger()
        let service = CaptureSessionService(backend: backend, logger: logger)
        try service.start()

        let payload = try await service.capturePhotoPayload(format: .raw)
        let primaryData = try await service.capturePhoto(format: .raw)

        #expect(payload.rawData == Data([0xAA, 0xBB, 0xCC]))
        #expect(payload.processedData == Data([0x10, 0x20]))
        #expect(primaryData == Data([0xAA, 0xBB, 0xCC]))
        #expect(payload.primaryMetadata(for: .raw) == rawMetadata)
        #expect(payload.secondaryMetadata(for: .raw) == processedMetadata)
        #expect(payload.primaryMetadata(for: .processed) == processedMetadata)
        #expect(payload.secondaryMetadata(for: .processed) == rawMetadata)
        guard let successEvent = logger.events.last(where: { $0.action == "photo_capture_succeeded" }) else {
            Issue.record("Expected raw capture success telemetry event.")
            return
        }
        #expect(successEvent.payload["format"] == "raw")
        #expect(successEvent.payload["bytes"] == "3")
        #expect(successEvent.payload["paired_bytes"] == "2")
        #expect(successEvent.payload["total_bytes"] == "5")
    }

    @Test("apple pro raw capture exposes RAW primary payload")
    func appleProRAWCapturePayload() async throws {
        let processedMetadata = CaptureTechnicalMetadata(
            lensModel: "Back Wide Camera",
            iso: 200,
            shutterSeconds: 0.01,
            whiteBalanceMode: "auto",
            whiteBalanceTemperatureKelvin: 5_200,
            whiteBalanceTint: 0
        )
        let rawMetadata = CaptureTechnicalMetadata(
            lensModel: "Back Wide Camera",
            iso: 125,
            shutterSeconds: 0.016,
            whiteBalanceMode: "locked",
            whiteBalanceTemperatureKelvin: 5_000,
            whiteBalanceTint: -2
        )
        let backend = StubCaptureBackend(
            capturePayload: CapturedPhotoPayload(
                processedData: Data([0x01, 0x02]),
                rawData: Data([0xA1, 0xB2, 0xC3]),
                processedMetadata: processedMetadata,
                rawMetadata: rawMetadata
            )
        )
        let logger = InMemoryCaptureEventLogger()
        let service = CaptureSessionService(backend: backend, logger: logger)
        try service.start()

        let payload = try await service.capturePhotoPayload(format: .appleProRAW)
        let primaryData = try await service.capturePhoto(format: .appleProRAW)

        #expect(payload.rawData == Data([0xA1, 0xB2, 0xC3]))
        #expect(payload.processedData == Data([0x01, 0x02]))
        #expect(primaryData == Data([0xA1, 0xB2, 0xC3]))
        #expect(payload.primaryMetadata(for: .appleProRAW) == rawMetadata)
        #expect(payload.secondaryMetadata(for: .appleProRAW) == processedMetadata)
        guard let successEvent = logger.events.last(where: { $0.action == "photo_capture_succeeded" }) else {
            Issue.record("Expected Apple ProRAW capture success telemetry event.")
            return
        }
        #expect(successEvent.payload["format"] == "appleProRAW")
        #expect(successEvent.payload["bytes"] == "3")
        #expect(successEvent.payload["paired_bytes"] == "2")
        #expect(successEvent.payload["total_bytes"] == "5")
    }

    @Test("capturePhoto logs failure when backend throws")
    func capturePhotoFailure() async {
        let backend = StubCaptureBackend(shouldFailCapture: true)
        let logger = InMemoryCaptureEventLogger()
        let service = CaptureSessionService(backend: backend, logger: logger)
        try? service.start()

        await #expect(throws: CaptureSessionError.self) {
            _ = try await service.capturePhoto()
        }

        #expect(logger.events.contains(where: { $0.action == "photo_capture_started" }))
        #expect(logger.events.contains(where: { $0.action == "photo_capture_failed" }))
        guard let startedEvent = logger.events.first(where: { $0.action == "photo_capture_started" }),
              let failedEvent = logger.events.first(where: { $0.action == "photo_capture_failed" }) else {
            Issue.record("Expected start and failure capture telemetry events.")
            return
        }

        #expect(failedEvent.payload["format"] == "processed")
        #expect(failedEvent.payload["capture_id"] == startedEvent.payload["capture_id"])
        #expect(failedEvent.payload["error"]?.contains("capture failed") == true)
        guard let latencyValue = failedEvent.payload["capture_latency_ms"],
              let latencyMilliseconds = Int(latencyValue) else {
            Issue.record("Expected capture_latency_ms in failure telemetry payload.")
            return
        }
        #expect(latencyMilliseconds >= 0)
    }

    @Test("rawCaptureCapability returns backend reported capability")
    func rawCaptureCapability() {
        let expected = RawCaptureCapability(
            isSupported: true,
            availableRawPhotoPixelFormatTypes: [875_704_422],
            isAppleProRAWSupported: true,
            availableAppleProRAWPhotoPixelFormatTypes: [875_704_430]
        )
        let backend = StubCaptureBackend(rawCapability: expected)
        let service = CaptureSessionService(backend: backend)

        #expect(service.rawCaptureCapability() == expected)
    }

    @Test("luminance histogram handler receives backend updates")
    func luminanceHistogramHandlerReceivesBackendUpdates() {
        let backend = StubCaptureBackend()
        let service = CaptureSessionService(backend: backend)
        let collector = HistogramCollector()
        service.setLuminanceHistogramHandler { histogram in
            collector.append(histogram)
        }

        let histogram = LuminanceHistogram(
            bins: [0, 3, 6, 9],
            sampleCount: 18
        )
        backend.emitLuminanceHistogram(histogram)

        #expect(collector.snapshot() == [histogram])
    }

    @Test("luminance histogram normalized bins scale to unit range")
    func luminanceHistogramNormalizedBins() {
        let histogram = LuminanceHistogram(
            bins: [0, 2, 4, 8],
            sampleCount: 14
        )

        #expect(histogram.normalizedBins == [0.0, 0.25, 0.5, 1.0])
    }

    @Test("zebra clipping threshold and handler forward to backend")
    func zebraClippingConfigurationForwardsToBackend() {
        let backend = StubCaptureBackend()
        let service = CaptureSessionService(backend: backend)
        let collector = ZebraOverlayCollector()
        service.setZebraClippingOverlayHandler { overlay in
            collector.append(overlay)
        }
        service.setZebraClippingThreshold(0.96)

        let overlay = ZebraClippingOverlay(
            columnCount: 2,
            rowCount: 2,
            clippedCells: [0, 1, 0, 1],
            threshold: 0.96
        )
        backend.emitZebraClippingOverlay(overlay)

        #expect(backend.latestZebraClippingThreshold == 0.96)
        #expect(collector.snapshot() == [overlay])
    }

    @Test("zebra clipping overlay reports clipped ratio")
    func zebraClippingOverlayReportsClippedRatio() {
        let overlay = ZebraClippingOverlay(
            columnCount: 2,
            rowCount: 2,
            clippedCells: [0, 1, 1, 0],
            threshold: 0.95
        )

        #expect(overlay.clippedCellCount == 2)
        #expect(overlay.clippedRatio == 0.5)
        #expect(overlay.isCellClipped(column: 1, row: 0))
        #expect(!overlay.isCellClipped(column: 0, row: 0))
    }

    @Test("focus peaking threshold and handler forward to backend")
    func focusPeakingConfigurationForwardsToBackend() {
        let backend = StubCaptureBackend()
        let service = CaptureSessionService(backend: backend)
        let collector = FocusPeakingOverlayCollector()
        service.setFocusPeakingOverlayHandler { overlay in
            collector.append(overlay)
        }
        service.setFocusPeakingThreshold(0.24)

        let overlay = FocusPeakingOverlay(
            columnCount: 2,
            rowCount: 2,
            peakCells: [1, 0, 1, 1],
            threshold: 0.24
        )
        backend.emitFocusPeakingOverlay(overlay)

        #expect(backend.latestFocusPeakingThreshold == 0.24)
        #expect(collector.snapshot() == [overlay])
    }

    @Test("focus peaking overlay reports peaked ratio")
    func focusPeakingOverlayReportsPeakedRatio() {
        let overlay = FocusPeakingOverlay(
            columnCount: 2,
            rowCount: 2,
            peakCells: [1, 0, 0, 1],
            threshold: 0.25
        )

        #expect(overlay.peakedCellCount == 2)
        #expect(overlay.peakedRatio == 0.5)
        #expect(overlay.isCellPeaked(column: 0, row: 0))
        #expect(!overlay.isCellPeaked(column: 1, row: 0))
    }

    @Test("markInterrupted updates state and emits interruption event")
    func markInterrupted() throws {
        let backend = StubCaptureBackend()
        let logger = InMemoryCaptureEventLogger()
        let service = CaptureSessionService(backend: backend, logger: logger)
        try service.start()

        service.markInterrupted(reason: "videoDeviceNotAvailableInBackground")

        #expect(service.state == .interrupted(reason: "videoDeviceNotAvailableInBackground"))
        guard let interruptionEvent = logger.events.last(where: { $0.action == "session_interrupted" }) else {
            Issue.record("Expected session_interrupted event.")
            return
        }
        #expect(interruptionEvent.payload["reason"] == "videoDeviceNotAvailableInBackground")
    }

    @Test("exposure state transitions auto locked custom")
    func exposureStateTransitions() throws {
        let backend = StubCaptureBackend()
        let logger = InMemoryCaptureEventLogger()
        let service = CaptureSessionService(backend: backend, logger: logger)

        #expect(service.exposureState == .auto)

        try service.lockExposure(iso: 64, shutterSeconds: 1.0 / 120.0)
        #expect(
            service.exposureState ==
            .locked(
                ExposureValues(
                    iso: 64,
                    shutterSeconds: 1.0 / 120.0
                )
            )
        )

        try service.setCustomExposure(iso: 200, shutterSeconds: 1.0 / 50.0)
        #expect(
            service.exposureState ==
            .custom(
                ExposureValues(
                    iso: 200,
                    shutterSeconds: 1.0 / 50.0
                )
            )
        )

        try service.setExposureAuto()
        #expect(service.exposureState == .auto)

        let exposureEvents = logger.events.filter { $0.action == "exposure_mode_changed" }
        #expect(exposureEvents.count == 3)
        #expect(exposureEvents[0].payload["mode"] == "locked")
        #expect(exposureEvents[1].payload["mode"] == "custom")
        #expect(exposureEvents[2].payload["mode"] == "auto")
    }

    @Test("invalid exposure values throw and preserve prior state")
    func invalidExposureValues() throws {
        let backend = StubCaptureBackend()
        let service = CaptureSessionService(backend: backend)

        try service.setCustomExposure(iso: 100, shutterSeconds: 1.0 / 100.0)
        let previousState = service.exposureState

        #expect(throws: ExposureStateMachineError.self) {
            try service.lockExposure(iso: 0, shutterSeconds: 0.01)
        }

        #expect(service.exposureState == previousState)
    }

    @Test("backend exposure apply failure preserves previous state")
    func backendExposureApplyFailure() throws {
        let backend = StubCaptureBackend(shouldFailExposureApply: true)
        let service = CaptureSessionService(backend: backend)

        #expect(service.exposureState == .auto)
        #expect(throws: CaptureSessionError.self) {
            try service.setCustomExposure(iso: 200, shutterSeconds: 1.0 / 100.0)
        }
        #expect(service.exposureState == .auto)
    }

    @Test("capture metadata reflects selected ISO and shutter values")
    func captureMetadataReflectsManualExposureValues() async throws {
        let backend = StubCaptureBackend()
        let service = CaptureSessionService(backend: backend)
        try service.start()

        try service.setCustomExposure(iso: 320, shutterSeconds: 1.0 / 30.0)
        let payload = try await service.capturePhotoPayload(format: .processed)
        guard let metadata = payload.primaryMetadata(for: .processed) else {
            Issue.record("Expected capture metadata for processed payload.")
            return
        }

        #expect(metadata.iso == 320)
        #expect(metadata.shutterSeconds == 1.0 / 30.0)
    }

    @Test("exposure compensation apply and reset")
    func exposureCompensationApplyAndReset() throws {
        let backend = StubCaptureBackend()
        let logger = InMemoryCaptureEventLogger()
        let service = CaptureSessionService(backend: backend, logger: logger)

        #expect(service.exposureCompensation == 0)

        try service.setExposureCompensation(1.2)
        #expect(service.exposureCompensation == 1.2)

        try service.resetExposureCompensation()
        #expect(service.exposureCompensation == 0)

        let events = logger.events.filter { $0.action == "exposure_compensation_changed" }
        #expect(events.count == 2)
        #expect(events[0].payload["ev"] == "1.2")
        #expect(events[1].payload["ev"] == "0.0")
    }

    @Test("exposure compensation apply failure preserves previous value")
    func exposureCompensationApplyFailurePreservesValue() throws {
        let backend = StubCaptureBackend(shouldFailExposureCompensationApply: true)
        let service = CaptureSessionService(backend: backend)

        #expect(service.exposureCompensation == 0)
        #expect(throws: CaptureSessionError.self) {
            try service.setExposureCompensation(0.8)
        }
        #expect(service.exposureCompensation == 0)
    }

    @Test("exposure compensation persists across camera switch")
    func exposureCompensationPersistsAcrossCameraSwitch() throws {
        let backend = StubCaptureBackend()
        let service = CaptureSessionService(backend: backend)
        try service.start()

        try service.setExposureCompensation(-0.7)
        try service.switchCamera()

        #expect(service.exposureCompensation == -0.7)
    }

    @Test("focus state transitions lock auto")
    func focusStateTransitions() throws {
        let backend = StubCaptureBackend()
        let logger = InMemoryCaptureEventLogger()
        let service = CaptureSessionService(backend: backend, logger: logger)

        #expect(service.focusState == .auto)

        try service.lockFocus(lensPosition: 0.72)
        #expect(service.focusState == .locked(lensPosition: 0.72))

        try service.setFocusAuto()
        #expect(service.focusState == .auto)

        let focusEvents = logger.events.filter { $0.action == "focus_mode_changed" }
        #expect(focusEvents.count == 2)
        #expect(focusEvents[0].payload["mode"] == "locked")
        #expect(focusEvents[0].payload["lens_position"] == "0.72")
        #expect(focusEvents[1].payload["mode"] == "auto")
    }

    @Test("invalid focus values throw and preserve prior state")
    func invalidFocusValues() throws {
        let backend = StubCaptureBackend()
        let service = CaptureSessionService(backend: backend)

        try service.lockFocus(lensPosition: 0.3)
        let previousState = service.focusState

        #expect(throws: FocusStateMachineError.self) {
            try service.lockFocus(lensPosition: 1.2)
        }
        #expect(service.focusState == previousState)
    }

    @Test("backend focus apply failure preserves previous state")
    func backendFocusApplyFailure() throws {
        let backend = StubCaptureBackend(shouldFailFocusApply: true)
        let service = CaptureSessionService(backend: backend)

        #expect(service.focusState == .auto)
        #expect(throws: CaptureSessionError.self) {
            try service.lockFocus(lensPosition: 0.25)
        }
        #expect(service.focusState == .auto)
    }

    @Test("focus state persists across camera switch")
    func focusStatePersistsAcrossCameraSwitch() throws {
        let backend = StubCaptureBackend()
        let service = CaptureSessionService(backend: backend)
        try service.start()

        try service.lockFocus(lensPosition: 0.64)
        try service.switchCamera()

        #expect(service.focusState == .locked(lensPosition: 0.64))
    }

    @Test("white balance state transitions lock auto")
    func whiteBalanceStateTransitions() throws {
        let backend = StubCaptureBackend()
        let logger = InMemoryCaptureEventLogger()
        let service = CaptureSessionService(backend: backend, logger: logger)

        #expect(service.whiteBalanceState == .auto)

        try service.lockWhiteBalance(temperatureKelvin: 5_600, tint: -12)
        #expect(
            service.whiteBalanceState ==
            .locked(
                WhiteBalanceValues(
                    temperatureKelvin: 5_600,
                    tint: -12
                )
            )
        )

        try service.setWhiteBalanceAuto()
        #expect(service.whiteBalanceState == .auto)

        let whiteBalanceEvents = logger.events.filter { $0.action == "white_balance_mode_changed" }
        #expect(whiteBalanceEvents.count == 2)
        #expect(whiteBalanceEvents[0].payload["mode"] == "locked")
        #expect(whiteBalanceEvents[0].payload["temperature_kelvin"] == "5600.0")
        #expect(whiteBalanceEvents[0].payload["tint"] == "-12.0")
        #expect(whiteBalanceEvents[1].payload["mode"] == "auto")
    }

    @Test("invalid white balance values throw and preserve prior state")
    func invalidWhiteBalanceValues() throws {
        let backend = StubCaptureBackend()
        let service = CaptureSessionService(backend: backend)

        try service.lockWhiteBalance(temperatureKelvin: 5_200, tint: 4)
        let previousState = service.whiteBalanceState

        #expect(throws: WhiteBalanceStateMachineError.self) {
            try service.lockWhiteBalance(temperatureKelvin: 0, tint: 2)
        }
        #expect(service.whiteBalanceState == previousState)
    }

    @Test("backend white balance apply failure preserves previous state")
    func backendWhiteBalanceApplyFailure() throws {
        let backend = StubCaptureBackend(shouldFailWhiteBalanceApply: true)
        let service = CaptureSessionService(backend: backend)

        #expect(service.whiteBalanceState == .auto)
        #expect(throws: CaptureSessionError.self) {
            try service.lockWhiteBalance(temperatureKelvin: 5_000, tint: -8)
        }
        #expect(service.whiteBalanceState == .auto)
    }

    @Test("white balance state persists across camera switch")
    func whiteBalanceStatePersistsAcrossCameraSwitch() throws {
        let backend = StubCaptureBackend()
        let service = CaptureSessionService(backend: backend)
        try service.start()

        try service.lockWhiteBalance(temperatureKelvin: 5_400, tint: -6)
        try service.switchCamera()

        #expect(
            service.whiteBalanceState ==
            .locked(
                WhiteBalanceValues(
                    temperatureKelvin: 5_400,
                    tint: -6
                )
            )
        )
    }

    @Test("capture metadata reflects selected white balance values")
    func captureMetadataReflectsManualWhiteBalanceValues() async throws {
        let backend = StubCaptureBackend()
        let service = CaptureSessionService(backend: backend)
        try service.start()

        try service.lockWhiteBalance(temperatureKelvin: 5_800, tint: -10)
        let payload = try await service.capturePhotoPayload(format: .processed)
        guard let metadata = payload.primaryMetadata(for: .processed) else {
            Issue.record("Expected capture metadata for processed payload.")
            return
        }

        #expect(metadata.whiteBalanceMode == "locked")
        #expect(metadata.whiteBalanceTemperatureKelvin == 5_800)
        #expect(metadata.whiteBalanceTint == -10)
    }
}

private final class StubCaptureBackend: CaptureSessionBackend {
    private(set) var isRunning: Bool = false
    private(set) var activeLensPosition: CaptureLensPosition = .back

    private let shouldFailStart: Bool
    private let shouldFailSwitch: Bool
    private let shouldFailCapture: Bool
    private let shouldFailExposureApply: Bool
    private let shouldFailExposureCompensationApply: Bool
    private let shouldFailFocusApply: Bool
    private let shouldFailWhiteBalanceApply: Bool
    private let captureData: Data
    private let capturePayload: CapturedPhotoPayload?
    private let rawCapability: RawCaptureCapability
    private var exposureState: ExposureControlState = .auto
    private var exposureCompensation: Double = 0
    private var focusState: FocusControlState = .auto
    private var whiteBalanceState: WhiteBalanceControlState = .auto
    private var luminanceHistogramHandler: LuminanceHistogramHandler?
    private var zebraClippingOverlayHandler: ZebraClippingOverlayHandler?
    private var focusPeakingOverlayHandler: FocusPeakingOverlayHandler?
    private(set) var latestZebraClippingThreshold: Double?
    private(set) var latestFocusPeakingThreshold: Double?

    init(
        shouldFailStart: Bool = false,
        shouldFailSwitch: Bool = false,
        shouldFailCapture: Bool = false,
        shouldFailExposureApply: Bool = false,
        shouldFailExposureCompensationApply: Bool = false,
        shouldFailFocusApply: Bool = false,
        shouldFailWhiteBalanceApply: Bool = false,
        captureData: Data = Data([0xFF, 0xD8, 0xFF, 0xD9]),
        capturePayload: CapturedPhotoPayload? = nil,
        rawCapability: RawCaptureCapability = RawCaptureCapability(
            isSupported: false,
            availableRawPhotoPixelFormatTypes: []
        )
    ) {
        self.shouldFailStart = shouldFailStart
        self.shouldFailSwitch = shouldFailSwitch
        self.shouldFailCapture = shouldFailCapture
        self.shouldFailExposureApply = shouldFailExposureApply
        self.shouldFailExposureCompensationApply = shouldFailExposureCompensationApply
        self.shouldFailFocusApply = shouldFailFocusApply
        self.shouldFailWhiteBalanceApply = shouldFailWhiteBalanceApply
        self.captureData = captureData
        self.capturePayload = capturePayload
        self.rawCapability = rawCapability
    }

    #if canImport(AVFoundation)
    var previewSession: AVCaptureSession? {
        nil
    }
    #endif

    func startRunning() throws {
        if shouldFailStart {
            throw CaptureSessionError.backendFailure(message: "startup failed")
        }
        isRunning = true
    }

    func stopRunning() {
        isRunning = false
    }

    func switchCamera() throws -> CaptureLensPosition {
        if shouldFailSwitch {
            throw CaptureSessionError.cameraSwitchNotSupported
        }
        activeLensPosition = activeLensPosition == .back ? .front : .back
        return activeLensPosition
    }

    func capturePhoto() async throws -> Data {
        if shouldFailCapture {
            throw CaptureSessionError.backendFailure(message: "capture failed")
        }
        return captureData
    }

    func capturePhotoPayload(format: CapturePhotoFormat) async throws -> CapturedPhotoPayload {
        if shouldFailCapture {
            throw CaptureSessionError.backendFailure(message: "capture failed")
        }
        if let capturePayload {
            return capturePayload
        }

        let exposureValues: ExposureValues?
        switch exposureState {
        case .auto:
            exposureValues = nil
        case let .locked(values), let .custom(values):
            exposureValues = values
        }

        let whiteBalanceMetadata: (mode: String?, temperatureKelvin: Double?, tint: Double?)
        switch whiteBalanceState {
        case .auto:
            whiteBalanceMetadata = (
                mode: exposureValues == nil ? nil : "auto",
                temperatureKelvin: nil,
                tint: nil
            )
        case let .locked(values):
            whiteBalanceMetadata = (
                mode: "locked",
                temperatureKelvin: values.temperatureKelvin,
                tint: values.tint
            )
        }

        let metadata = CaptureTechnicalMetadata(
            lensModel: "Stub Camera",
            iso: exposureValues?.iso,
            shutterSeconds: exposureValues?.shutterSeconds,
            whiteBalanceMode: whiteBalanceMetadata.mode,
            whiteBalanceTemperatureKelvin: whiteBalanceMetadata.temperatureKelvin,
            whiteBalanceTint: whiteBalanceMetadata.tint
        )
        let resolvedMetadata = metadata.isEmpty ? nil : metadata

        switch format {
        case .processed:
            return CapturedPhotoPayload(
                processedData: captureData,
                processedMetadata: resolvedMetadata
            )
        case .raw:
            return CapturedPhotoPayload(
                rawData: captureData,
                rawMetadata: resolvedMetadata
            )
        case .appleProRAW:
            return CapturedPhotoPayload(
                rawData: captureData,
                rawMetadata: resolvedMetadata
            )
        }
    }

    func rawCaptureCapability() -> RawCaptureCapability {
        rawCapability
    }

    func applyExposureState(_ state: ExposureControlState) throws -> ExposureControlState {
        if shouldFailExposureApply {
            throw CaptureSessionError.backendFailure(message: "manual exposure apply failed")
        }
        exposureState = state
        return exposureState
    }

    func applyExposureCompensation(_ value: Double) throws -> Double {
        if shouldFailExposureCompensationApply {
            throw CaptureSessionError.backendFailure(message: "exposure compensation apply failed")
        }
        exposureCompensation = value
        return exposureCompensation
    }

    func exposureCompensationRange() -> ClosedRange<Double>? {
        -3...3
    }

    func applyFocusState(_ state: FocusControlState) throws -> FocusControlState {
        if shouldFailFocusApply {
            throw CaptureSessionError.backendFailure(message: "manual focus apply failed")
        }
        focusState = state
        return focusState
    }

    func applyWhiteBalanceState(_ state: WhiteBalanceControlState) throws -> WhiteBalanceControlState {
        if shouldFailWhiteBalanceApply {
            throw CaptureSessionError.backendFailure(message: "manual white balance apply failed")
        }
        whiteBalanceState = state
        return whiteBalanceState
    }

    func setLuminanceHistogramHandler(_ handler: LuminanceHistogramHandler?) {
        luminanceHistogramHandler = handler
    }

    func emitLuminanceHistogram(_ histogram: LuminanceHistogram) {
        luminanceHistogramHandler?(histogram)
    }

    func setZebraClippingThreshold(_ threshold: Double?) {
        latestZebraClippingThreshold = threshold
    }

    func setZebraClippingOverlayHandler(_ handler: ZebraClippingOverlayHandler?) {
        zebraClippingOverlayHandler = handler
    }

    func emitZebraClippingOverlay(_ overlay: ZebraClippingOverlay) {
        zebraClippingOverlayHandler?(overlay)
    }

    func setFocusPeakingThreshold(_ threshold: Double?) {
        latestFocusPeakingThreshold = threshold
    }

    func setFocusPeakingOverlayHandler(_ handler: FocusPeakingOverlayHandler?) {
        focusPeakingOverlayHandler = handler
    }

    func emitFocusPeakingOverlay(_ overlay: FocusPeakingOverlay) {
        focusPeakingOverlayHandler?(overlay)
    }
}

private final class HistogramCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var histograms: [LuminanceHistogram] = []

    func append(_ histogram: LuminanceHistogram) {
        lock.lock()
        histograms.append(histogram)
        lock.unlock()
    }

    func snapshot() -> [LuminanceHistogram] {
        lock.lock()
        let values = histograms
        lock.unlock()
        return values
    }
}

private final class ZebraOverlayCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var overlays: [ZebraClippingOverlay] = []

    func append(_ overlay: ZebraClippingOverlay) {
        lock.lock()
        overlays.append(overlay)
        lock.unlock()
    }

    func snapshot() -> [ZebraClippingOverlay] {
        lock.lock()
        let values = overlays
        lock.unlock()
        return values
    }
}

private final class FocusPeakingOverlayCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var overlays: [FocusPeakingOverlay] = []

    func append(_ overlay: FocusPeakingOverlay) {
        lock.lock()
        overlays.append(overlay)
        lock.unlock()
    }

    func snapshot() -> [FocusPeakingOverlay] {
        lock.lock()
        let values = overlays
        lock.unlock()
        return values
    }
}
