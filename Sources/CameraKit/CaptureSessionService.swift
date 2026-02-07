import Foundation

#if canImport(AVFoundation)
import AVFoundation
#endif

public enum CaptureLensPosition: String, Equatable {
    case back
    case front
}

public enum CaptureSessionState: Equatable {
    case idle
    case running(position: CaptureLensPosition)
    case interrupted(reason: String)
    case failed(message: String)
}

public enum CaptureSessionError: Error, Equatable {
    case cameraSwitchNotSupported
    case backendFailure(message: String)
}

public protocol CaptureSessionBackend {
    var isRunning: Bool { get }
    var activeLensPosition: CaptureLensPosition { get }
    #if canImport(AVFoundation)
    var previewSession: AVCaptureSession? { get }
    #endif
    func startRunning() throws
    func stopRunning()
    func switchCamera() throws -> CaptureLensPosition
}

public protocol CaptureSessionServing {
    var state: CaptureSessionState { get }
    #if canImport(AVFoundation)
    var previewSession: AVCaptureSession? { get }
    #endif
    func start() throws
    func stop()
    func switchCamera() throws
    func markInterrupted(reason: String)
}

public final class CaptureSessionService: CaptureSessionServing {
    private let backend: CaptureSessionBackend
    private let logger: CaptureEventLogging?
    private let lock = NSLock()
    private var mutableState: CaptureSessionState = .idle

    public init(
        backend: CaptureSessionBackend = AVCaptureSessionBackend(),
        logger: CaptureEventLogging? = nil
    ) {
        self.backend = backend
        self.logger = logger
    }

    public var state: CaptureSessionState {
        lock.withLock { mutableState }
    }

    #if canImport(AVFoundation)
    public var previewSession: AVCaptureSession? {
        backend.previewSession
    }
    #endif

    public func start() throws {
        do {
            try backend.startRunning()
            lock.withLock {
                mutableState = .running(position: backend.activeLensPosition)
            }
            logger?.log(
                CaptureEvent(
                    category: .session,
                    action: "session_started",
                    payload: ["position": backend.activeLensPosition.rawValue]
                )
            )
        } catch {
            let message = String(describing: error)
            lock.withLock {
                mutableState = .failed(message: message)
            }
            logger?.log(
                CaptureEvent(
                    category: .session,
                    action: "session_start_failed",
                    payload: ["error": message]
                )
            )
            throw error
        }
    }

    public func stop() {
        backend.stopRunning()
        lock.withLock {
            mutableState = .idle
        }
        logger?.log(
            CaptureEvent(
                category: .session,
                action: "session_stopped"
            )
        )
    }

    public func switchCamera() throws {
        do {
            let newPosition = try backend.switchCamera()
            lock.withLock {
                mutableState = .running(position: newPosition)
            }
            logger?.log(
                CaptureEvent(
                    category: .session,
                    action: "camera_switched",
                    payload: ["position": newPosition.rawValue]
                )
            )
        } catch {
            let message = String(describing: error)
            lock.withLock {
                mutableState = .failed(message: message)
            }
            logger?.log(
                CaptureEvent(
                    category: .session,
                    action: "camera_switch_failed",
                    payload: ["error": message]
                )
            )
            throw error
        }
    }

    public func markInterrupted(reason: String) {
        lock.withLock {
            mutableState = .interrupted(reason: reason)
        }
        logger?.log(
            CaptureEvent(
                category: .session,
                action: "session_interrupted",
                payload: ["reason": reason]
            )
        )
    }
}

public final class SimulatedCaptureSessionBackend: CaptureSessionBackend {
    public private(set) var isRunning = false
    public private(set) var activeLensPosition: CaptureLensPosition

    public init(initialPosition: CaptureLensPosition = .back) {
        self.activeLensPosition = initialPosition
    }

    #if canImport(AVFoundation)
    public var previewSession: AVCaptureSession? {
        nil
    }
    #endif

    public func startRunning() throws {
        isRunning = true
    }

    public func stopRunning() {
        isRunning = false
    }

    public func switchCamera() throws -> CaptureLensPosition {
        activeLensPosition = activeLensPosition == .back ? .front : .back
        return activeLensPosition
    }
}

public final class AVCaptureSessionBackend: CaptureSessionBackend {
    #if canImport(AVFoundation)
    private let session: AVCaptureSession
    private var isConfigured = false
    #endif

    public private(set) var isRunning = false
    public private(set) var activeLensPosition: CaptureLensPosition

    public init(initialPosition: CaptureLensPosition = .back) {
        self.activeLensPosition = initialPosition
        #if canImport(AVFoundation)
        self.session = AVCaptureSession()
        #endif
    }

    #if canImport(AVFoundation)
    public var previewSession: AVCaptureSession? {
        session
    }
    #endif

    public func startRunning() throws {
        #if canImport(AVFoundation)
        try configureSessionIfNeeded(for: activeLensPosition)
        if !session.isRunning {
            session.startRunning()
        }
        #endif
        isRunning = true
    }

    public func stopRunning() {
        #if canImport(AVFoundation)
        if session.isRunning {
            session.stopRunning()
        }
        #endif
        isRunning = false
    }

    public func switchCamera() throws -> CaptureLensPosition {
        let targetPosition: CaptureLensPosition = activeLensPosition == .back ? .front : .back
        #if canImport(AVFoundation)
        guard cameraDevice(for: targetPosition) != nil else {
            throw CaptureSessionError.cameraSwitchNotSupported
        }

        try configureSession(for: targetPosition)
        if isRunning, !session.isRunning {
            session.startRunning()
        }
        #endif
        activeLensPosition = targetPosition
        return activeLensPosition
    }

    #if canImport(AVFoundation)
    private func configureSessionIfNeeded(for position: CaptureLensPosition) throws {
        guard !isConfigured else { return }
        try configureSession(for: position)
    }

    private func configureSession(for position: CaptureLensPosition) throws {
        guard let device = cameraDevice(for: position) else {
            throw CaptureSessionError.backendFailure(message: "No \(position.rawValue) camera is available.")
        }

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            throw CaptureSessionError.backendFailure(message: "Failed to initialize camera input: \(error.localizedDescription)")
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo
        for existingInput in session.inputs {
            session.removeInput(existingInput)
        }

        guard session.canAddInput(input) else {
            throw CaptureSessionError.backendFailure(message: "Cannot add \(position.rawValue) camera input to capture session.")
        }

        session.addInput(input)
        isConfigured = true
    }

    private func cameraDevice(for position: CaptureLensPosition) -> AVCaptureDevice? {
        let avPosition: AVCaptureDevice.Position = position == .back ? .back : .front
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: avPosition)
    }
    #endif
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
