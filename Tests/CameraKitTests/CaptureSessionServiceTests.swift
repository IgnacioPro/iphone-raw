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
        #expect(logger.events.contains(where: { $0.action == "photo_capture_succeeded" }))
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

        #expect(logger.events.contains(where: { $0.action == "photo_capture_failed" }))
    }
}

private final class StubCaptureBackend: CaptureSessionBackend {
    private(set) var isRunning: Bool = false
    private(set) var activeLensPosition: CaptureLensPosition = .back

    private let shouldFailStart: Bool
    private let shouldFailSwitch: Bool
    private let shouldFailCapture: Bool
    private let captureData: Data

    init(
        shouldFailStart: Bool = false,
        shouldFailSwitch: Bool = false,
        shouldFailCapture: Bool = false,
        captureData: Data = Data([0xFF, 0xD8, 0xFF, 0xD9])
    ) {
        self.shouldFailStart = shouldFailStart
        self.shouldFailSwitch = shouldFailSwitch
        self.shouldFailCapture = shouldFailCapture
        self.captureData = captureData
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
}
