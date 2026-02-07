import App
import CameraKit
import Foundation
import Storage
import Testing
#if canImport(AVFoundation)
import AVFoundation
#endif

@Suite("CaptureAppModel")
struct CaptureAppModelTests {
    @Test("bootstrap moves app to ready when access granted and session starts")
    func bootstrapReady() async {
        let permissionClient = StubPermissionClient(status: .authorized, requestAccessResult: true)
        let sessionBackend = StubCaptureBackend()
        let sessionService = CaptureSessionService(backend: sessionBackend)
        let gate = CameraPermissionGate(client: permissionClient)
        let model = CaptureAppModel(
            permissionGate: gate,
            sessionService: sessionService,
            metadataStore: InMemoryCaptureMetadataStore()
        )

        await model.bootstrap()

        #expect(model.bootState == .ready)
    }

    @Test("bootstrap blocks app when access denied")
    func bootstrapDenied() async {
        let permissionClient = StubPermissionClient(status: .denied, requestAccessResult: false)
        let sessionBackend = StubCaptureBackend()
        let sessionService = CaptureSessionService(backend: sessionBackend)
        let gate = CameraPermissionGate(client: permissionClient)
        let model = CaptureAppModel(
            permissionGate: gate,
            sessionService: sessionService,
            metadataStore: InMemoryCaptureMetadataStore()
        )

        await model.bootstrap()

        guard case let .blocked(reason) = model.bootState else {
            Issue.record("Expected blocked state.")
            return
        }
        #expect(reason.contains("denied"))
    }

    @Test("capturePhotoData returns bytes from session service")
    func capturePhotoData() async throws {
        let permissionClient = StubPermissionClient(status: .authorized, requestAccessResult: true)
        let sessionBackend = StubCaptureBackend(captureData: Data([0xAA, 0xBB]))
        let sessionService = CaptureSessionService(backend: sessionBackend)
        let gate = CameraPermissionGate(client: permissionClient)
        let model = CaptureAppModel(
            permissionGate: gate,
            sessionService: sessionService,
            metadataStore: InMemoryCaptureMetadataStore()
        )

        await model.bootstrap()
        let data = try await model.capturePhotoData()

        #expect(data == Data([0xAA, 0xBB]))
    }

    @Test("resumeSessionIfNeeded restarts a stopped ready session")
    func resumeSessionIfNeeded() async {
        let permissionClient = StubPermissionClient(status: .authorized, requestAccessResult: true)
        let sessionBackend = StubCaptureBackend()
        let sessionService = CaptureSessionService(backend: sessionBackend)
        let gate = CameraPermissionGate(client: permissionClient)
        let model = CaptureAppModel(
            permissionGate: gate,
            sessionService: sessionService,
            metadataStore: InMemoryCaptureMetadataStore()
        )

        await model.bootstrap()
        model.stopSession()
        model.resumeSessionIfNeeded()

        #expect(model.bootState == .ready)
        #expect(sessionBackend.isRunning)
    }

    @Test("persistPhotoLibraryCapture stores local identifier timestamp and lens metadata")
    func persistPhotoLibraryCaptureMetadata() async {
        let permissionClient = StubPermissionClient(status: .authorized, requestAccessResult: true)
        let sessionBackend = StubCaptureBackend()
        let sessionService = CaptureSessionService(backend: sessionBackend)
        let gate = CameraPermissionGate(client: permissionClient)
        let metadataStore = InMemoryCaptureMetadataStore()
        let model = CaptureAppModel(
            permissionGate: gate,
            sessionService: sessionService,
            metadataStore: metadataStore
        )

        await model.bootstrap()
        let capturedAt = Date(timeIntervalSince1970: 1_234_567_890)
        await model.persistPhotoLibraryCapture(
            localIdentifier: "A1B2-C3D4",
            capturedAt: capturedAt,
            lensPosition: .front,
            byteCount: 4_200,
            captureFormat: .raw,
            pairedLocalIdentifier: "E5F6-G7H8",
            pairedByteCount: 2_100
        )

        let artifacts = await metadataStore.fetchAll()
        #expect(artifacts.count == 1)
        guard let artifact = artifacts.first else {
            Issue.record("Expected one persisted capture artifact.")
            return
        }

        #expect(artifact.photoLibraryLocalIdentifier == "A1B2-C3D4")
        #expect(artifact.primaryURL.absoluteString == "photos://asset")
        #expect(artifact.createdAt == capturedAt)
        #expect(artifact.metadata["photo_library_local_identifier"] == "A1B2-C3D4")
        #expect(artifact.metadata["captured_at"] == capturedAt.ISO8601Format())
        #expect(artifact.metadata["lens_position"] == "front")
        #expect(artifact.metadata["byte_count"] == "4200")
        #expect(artifact.metadata["capture_format"] == "raw")
        #expect(artifact.metadata["paired_photo_library_local_identifier"] == "E5F6-G7H8")
        #expect(artifact.metadata["paired_byte_count"] == "2100")
    }

    @Test("persistPhotoLibraryCapture stores RAW metadata pack fields")
    func persistPhotoLibraryCaptureTechnicalMetadata() async {
        let permissionClient = StubPermissionClient(status: .authorized, requestAccessResult: true)
        let sessionBackend = StubCaptureBackend()
        let sessionService = CaptureSessionService(backend: sessionBackend)
        let gate = CameraPermissionGate(client: permissionClient)
        let metadataStore = InMemoryCaptureMetadataStore()
        let model = CaptureAppModel(
            permissionGate: gate,
            sessionService: sessionService,
            metadataStore: metadataStore
        )

        await model.bootstrap()
        let capturedAt = Date(timeIntervalSince1970: 1_234_567_891)
        let primaryMetadata = CaptureTechnicalMetadata(
            lensModel: "Back Wide Camera",
            iso: 160.0,
            shutterSeconds: 0.01,
            whiteBalanceMode: "locked",
            whiteBalanceTemperatureKelvin: 5_200.0,
            whiteBalanceTint: -8.0
        )
        let pairedMetadata = CaptureTechnicalMetadata(
            lensModel: "Back Wide Camera",
            iso: 320.0,
            shutterSeconds: 0.02,
            whiteBalanceMode: "auto",
            whiteBalanceTemperatureKelvin: 5_100.0,
            whiteBalanceTint: -3.0
        )

        await model.persistPhotoLibraryCapture(
            localIdentifier: "RAW-PRIMARY",
            capturedAt: capturedAt,
            lensPosition: .back,
            byteCount: 8_192,
            captureFormat: .raw,
            pairedLocalIdentifier: "RAW-PAIRED",
            pairedByteCount: 4_096,
            captureMetadata: primaryMetadata,
            pairedCaptureMetadata: pairedMetadata
        )

        let artifacts = await metadataStore.fetchAll()
        #expect(artifacts.count == 1)
        guard let artifact = artifacts.first else {
            Issue.record("Expected one persisted capture artifact.")
            return
        }

        #expect(artifact.metadata["capture_lens_model"] == "Back Wide Camera")
        #expect(artifact.metadata["capture_iso"] == "160.0")
        #expect(artifact.metadata["capture_shutter_seconds"] == "0.01")
        #expect(artifact.metadata["capture_white_balance_mode"] == "locked")
        #expect(artifact.metadata["capture_white_balance_temperature_kelvin"] == "5200.0")
        #expect(artifact.metadata["capture_white_balance_tint"] == "-8.0")
        #expect(artifact.metadata["paired_capture_lens_model"] == "Back Wide Camera")
        #expect(artifact.metadata["paired_capture_iso"] == "320.0")
        #expect(artifact.metadata["paired_capture_shutter_seconds"] == "0.02")
        #expect(artifact.metadata["paired_capture_white_balance_mode"] == "auto")
        #expect(artifact.metadata["paired_capture_white_balance_temperature_kelvin"] == "5100.0")
        #expect(artifact.metadata["paired_capture_white_balance_tint"] == "-3.0")
    }

    @Test("rawCaptureCapability exposes service capability state")
    func rawCaptureCapability() async {
        let permissionClient = StubPermissionClient(status: .authorized, requestAccessResult: true)
        let sessionBackend = StubCaptureBackend(
            rawCapability: RawCaptureCapability(
                isSupported: true,
                availableRawPhotoPixelFormatTypes: [875_704_422]
            )
        )
        let sessionService = CaptureSessionService(backend: sessionBackend)
        let gate = CameraPermissionGate(client: permissionClient)
        let model = CaptureAppModel(
            permissionGate: gate,
            sessionService: sessionService,
            metadataStore: InMemoryCaptureMetadataStore()
        )

        await model.bootstrap()
        let capability = model.rawCaptureCapability()

        #expect(capability.isSupported)
        #expect(capability.availableRawPhotoPixelFormatTypes == [875_704_422])
    }

    @Test("exposure controls forward to session service state machine")
    func exposureControls() async throws {
        let permissionClient = StubPermissionClient(status: .authorized, requestAccessResult: true)
        let sessionBackend = StubCaptureBackend()
        let sessionService = CaptureSessionService(backend: sessionBackend)
        let gate = CameraPermissionGate(client: permissionClient)
        let model = CaptureAppModel(
            permissionGate: gate,
            sessionService: sessionService,
            metadataStore: InMemoryCaptureMetadataStore()
        )

        await model.bootstrap()
        #expect(model.exposureState() == .auto)

        try model.lockExposure(iso: 64, shutterSeconds: 1.0 / 120.0)
        #expect(
            model.exposureState() ==
            .locked(
                ExposureValues(
                    iso: 64,
                    shutterSeconds: 1.0 / 120.0
                )
            )
        )

        try model.setCustomExposure(iso: 160, shutterSeconds: 1.0 / 80.0)
        #expect(
            model.exposureState() ==
            .custom(
                ExposureValues(
                    iso: 160,
                    shutterSeconds: 1.0 / 80.0
                )
            )
        )

        try model.setExposureAuto()
        #expect(model.exposureState() == .auto)
    }

    @Test("focus controls forward to session service state machine")
    func focusControls() async throws {
        let permissionClient = StubPermissionClient(status: .authorized, requestAccessResult: true)
        let sessionBackend = StubCaptureBackend()
        let sessionService = CaptureSessionService(backend: sessionBackend)
        let gate = CameraPermissionGate(client: permissionClient)
        let model = CaptureAppModel(
            permissionGate: gate,
            sessionService: sessionService,
            metadataStore: InMemoryCaptureMetadataStore()
        )

        await model.bootstrap()
        #expect(model.focusState() == .auto)

        try model.lockFocus(lensPosition: 0.62)
        #expect(model.focusState() == .locked(lensPosition: 0.62))

        try model.setFocusAuto()
        #expect(model.focusState() == .auto)
    }

    @Test("white balance controls forward to session service state machine")
    func whiteBalanceControls() async throws {
        let permissionClient = StubPermissionClient(status: .authorized, requestAccessResult: true)
        let sessionBackend = StubCaptureBackend()
        let sessionService = CaptureSessionService(backend: sessionBackend)
        let gate = CameraPermissionGate(client: permissionClient)
        let model = CaptureAppModel(
            permissionGate: gate,
            sessionService: sessionService,
            metadataStore: InMemoryCaptureMetadataStore()
        )

        await model.bootstrap()
        #expect(model.whiteBalanceState() == .auto)

        try model.lockWhiteBalance(temperatureKelvin: 5_600, tint: -10)
        #expect(
            model.whiteBalanceState() ==
            .locked(
                WhiteBalanceValues(
                    temperatureKelvin: 5_600,
                    tint: -10
                )
            )
        )

        try model.setWhiteBalanceAuto()
        #expect(model.whiteBalanceState() == .auto)
    }

    @Test("exposure compensation controls forward to session service")
    func exposureCompensationControls() async throws {
        let permissionClient = StubPermissionClient(status: .authorized, requestAccessResult: true)
        let sessionBackend = StubCaptureBackend()
        let sessionService = CaptureSessionService(backend: sessionBackend)
        let gate = CameraPermissionGate(client: permissionClient)
        let model = CaptureAppModel(
            permissionGate: gate,
            sessionService: sessionService,
            metadataStore: InMemoryCaptureMetadataStore()
        )

        await model.bootstrap()
        #expect(model.exposureCompensation() == 0)

        try model.setExposureCompensation(0.9)
        #expect(model.exposureCompensation() == 0.9)

        try model.resetExposureCompensation()
        #expect(model.exposureCompensation() == 0)
    }
}

private final class StubPermissionClient: CameraPermissionClient {
    private let status: CameraAuthorizationStatus
    private let requestAccessResult: Bool

    init(status: CameraAuthorizationStatus, requestAccessResult: Bool) {
        self.status = status
        self.requestAccessResult = requestAccessResult
    }

    func authorizationStatus() -> CameraAuthorizationStatus {
        status
    }

    func requestAccess() async -> Bool {
        requestAccessResult
    }
}

private final class StubCaptureBackend: CaptureSessionBackend {
    private(set) var isRunning: Bool = false
    private(set) var activeLensPosition: CaptureLensPosition = .back
    private let captureData: Data
    private let rawCapability: RawCaptureCapability
    private var exposureState: ExposureControlState = .auto
    private var exposureCompensation: Double = 0
    private var focusState: FocusControlState = .auto
    private var whiteBalanceState: WhiteBalanceControlState = .auto

    init(
        captureData: Data = Data([0xFF, 0xD8, 0xFF, 0xD9]),
        rawCapability: RawCaptureCapability = RawCaptureCapability(
            isSupported: false,
            availableRawPhotoPixelFormatTypes: []
        )
    ) {
        self.captureData = captureData
        self.rawCapability = rawCapability
    }

    #if canImport(AVFoundation)
    var previewSession: AVCaptureSession? {
        nil
    }
    #endif

    func startRunning() throws {
        isRunning = true
    }

    func stopRunning() {
        isRunning = false
    }

    func switchCamera() throws -> CaptureLensPosition {
        activeLensPosition = activeLensPosition == .back ? .front : .back
        return activeLensPosition
    }

    func capturePhoto() async throws -> Data {
        captureData
    }

    func rawCaptureCapability() -> RawCaptureCapability {
        rawCapability
    }

    func applyExposureState(_ state: ExposureControlState) throws -> ExposureControlState {
        exposureState = state
        return exposureState
    }

    func applyExposureCompensation(_ value: Double) throws -> Double {
        exposureCompensation = value
        return exposureCompensation
    }

    func exposureCompensationRange() -> ClosedRange<Double>? {
        -3...3
    }

    func applyFocusState(_ state: FocusControlState) throws -> FocusControlState {
        focusState = state
        return focusState
    }

    func applyWhiteBalanceState(_ state: WhiteBalanceControlState) throws -> WhiteBalanceControlState {
        whiteBalanceState = state
        return whiteBalanceState
    }
}
