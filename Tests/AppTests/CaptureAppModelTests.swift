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
            captureFormat: .raw
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
}
