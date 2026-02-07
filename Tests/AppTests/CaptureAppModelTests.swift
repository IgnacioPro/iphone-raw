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

    init(captureData: Data = Data([0xFF, 0xD8, 0xFF, 0xD9])) {
        self.captureData = captureData
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
}
