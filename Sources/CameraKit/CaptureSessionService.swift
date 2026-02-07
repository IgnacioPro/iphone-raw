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

public struct RawCaptureCapability: Equatable, Sendable {
    public let isSupported: Bool
    public let availableRawPhotoPixelFormatTypes: [UInt32]
    public let reason: String?

    public init(
        isSupported: Bool,
        availableRawPhotoPixelFormatTypes: [UInt32],
        reason: String? = nil
    ) {
        self.isSupported = isSupported
        self.availableRawPhotoPixelFormatTypes = availableRawPhotoPixelFormatTypes
        self.reason = reason
    }
}

public enum CapturePhotoFormat: String, Equatable, Sendable {
    case processed
    case raw
}

public struct CapturedPhotoPayload: Equatable, Sendable {
    public let processedData: Data?
    public let rawData: Data?

    public init(processedData: Data? = nil, rawData: Data? = nil) {
        self.processedData = processedData
        self.rawData = rawData
    }

    public var totalByteCount: Int {
        (processedData?.count ?? 0) + (rawData?.count ?? 0)
    }

    public func primaryData(for format: CapturePhotoFormat) throws -> Data {
        switch format {
        case .processed:
            if let processedData { return processedData }
            if let rawData { return rawData }
        case .raw:
            if let rawData { return rawData }
            if let processedData { return processedData }
        }
        throw CaptureSessionError.backendFailure(message: "Photo capture finished without image data.")
    }

    public func secondaryData(for format: CapturePhotoFormat) -> Data? {
        switch format {
        case .processed:
            return rawData
        case .raw:
            return processedData
        }
    }
}

public enum CaptureSessionError: Error, Equatable, LocalizedError {
    case cameraSwitchNotSupported
    case backendFailure(message: String)
    case captureTimedOut
    case rawCaptureNotSupported

    public var errorDescription: String? {
        switch self {
        case .cameraSwitchNotSupported:
            return "Camera switch is not supported on this device."
        case let .backendFailure(message):
            return message
        case .captureTimedOut:
            return "Camera capture timed out."
        case .rawCaptureNotSupported:
            return "RAW capture is not supported for the current camera configuration."
        }
    }
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
    func capturePhoto() async throws -> Data
    func capturePhoto(format: CapturePhotoFormat) async throws -> Data
    func capturePhotoPayload(format: CapturePhotoFormat) async throws -> CapturedPhotoPayload
    func rawCaptureCapability() -> RawCaptureCapability
}

public protocol CaptureSessionServing {
    var state: CaptureSessionState { get }
    #if canImport(AVFoundation)
    var previewSession: AVCaptureSession? { get }
    #endif
    func start() throws
    func stop()
    func switchCamera() throws
    func capturePhoto() async throws -> Data
    func capturePhoto(format: CapturePhotoFormat) async throws -> Data
    func capturePhotoPayload(format: CapturePhotoFormat) async throws -> CapturedPhotoPayload
    func rawCaptureCapability() -> RawCaptureCapability
    func markInterrupted(reason: String)
}

public extension CaptureSessionBackend {
    func capturePhoto(format: CapturePhotoFormat) async throws -> Data {
        switch format {
        case .processed:
            return try await capturePhoto()
        case .raw:
            throw CaptureSessionError.rawCaptureNotSupported
        }
    }

    func capturePhotoPayload(format: CapturePhotoFormat) async throws -> CapturedPhotoPayload {
        let data = try await capturePhoto(format: format)
        switch format {
        case .processed:
            return CapturedPhotoPayload(processedData: data)
        case .raw:
            return CapturedPhotoPayload(rawData: data)
        }
    }
}

public extension CaptureSessionServing {
    func capturePhoto() async throws -> Data {
        try await capturePhoto(format: .processed)
    }

    func capturePhotoPayload(format: CapturePhotoFormat) async throws -> CapturedPhotoPayload {
        let data = try await capturePhoto(format: format)
        switch format {
        case .processed:
            return CapturedPhotoPayload(processedData: data)
        case .raw:
            return CapturedPhotoPayload(rawData: data)
        }
    }
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

    public func capturePhoto() async throws -> Data {
        try await capturePhoto(format: .processed)
    }

    public func capturePhoto(format: CapturePhotoFormat) async throws -> Data {
        do {
            let payload = try await capturePhotoPayload(format: format)
            let data = try payload.primaryData(for: format)
            logger?.log(
                CaptureEvent(
                    category: .capture,
                    action: "photo_capture_succeeded",
                    payload: [
                        "bytes": "\(data.count)",
                        "format": format.rawValue,
                    ]
                )
            )
            return data
        } catch {
            let message = String(describing: error)
            logger?.log(
                CaptureEvent(
                    category: .capture,
                    action: "photo_capture_failed",
                    payload: [
                        "error": message,
                        "format": format.rawValue,
                    ]
                )
            )
            throw error
        }
    }

    public func capturePhotoPayload(format: CapturePhotoFormat) async throws -> CapturedPhotoPayload {
        try await backend.capturePhotoPayload(format: format)
    }

    public func rawCaptureCapability() -> RawCaptureCapability {
        backend.rawCaptureCapability()
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

    public func capturePhoto() async throws -> Data {
        // Small synthetic JPEG marker payload to keep simulator/test flows deterministic.
        Data([0xFF, 0xD8, 0xFF, 0xD9])
    }

    public func rawCaptureCapability() -> RawCaptureCapability {
        RawCaptureCapability(
            isSupported: false,
            availableRawPhotoPixelFormatTypes: [],
            reason: "RAW photo capture is unavailable in the simulated backend."
        )
    }
}

public final class AVCaptureSessionBackend: CaptureSessionBackend {
    #if canImport(AVFoundation)
    private let session: AVCaptureSession
    private let photoOutput: AVCapturePhotoOutput
    private var isConfigured = false
    private let inFlightCaptureLock = NSLock()
    private var inFlightCaptures: [UUID: PhotoCaptureProcessor] = [:]
    #endif

    public private(set) var isRunning = false
    public private(set) var activeLensPosition: CaptureLensPosition

    public init(initialPosition: CaptureLensPosition = .back) {
        self.activeLensPosition = initialPosition
        #if canImport(AVFoundation)
        self.session = AVCaptureSession()
        self.photoOutput = AVCapturePhotoOutput()
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

    public func capturePhoto() async throws -> Data {
        try await capturePhoto(format: .processed)
    }

    public func capturePhoto(format: CapturePhotoFormat) async throws -> Data {
        let payload = try await capturePhotoPayload(format: format)
        return try payload.primaryData(for: format)
    }

    public func capturePhotoPayload(format: CapturePhotoFormat) async throws -> CapturedPhotoPayload {
        #if canImport(AVFoundation)
        guard isRunning, session.isRunning else {
            throw CaptureSessionError.backendFailure(message: "Capture session is not running.")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let completionBox = CaptureCompletionBox(continuation: continuation)
            let captureID = UUID()
            let processor = PhotoCaptureProcessor(requestedFormat: format) { [weak self] result in
                self?.removeInFlightCapture(captureID)
                completionBox.resume(with: result)
            }
            addInFlightCapture(processor, id: captureID)
            do {
                photoOutput.capturePhoto(with: try makePhotoSettings(for: format), delegate: processor)
            } catch {
                removeInFlightCapture(captureID)
                completionBox.resume(with: .failure(error))
                return
            }

            Task {
                try? await Task.sleep(for: .seconds(12))
                completionBox.resume(with: .failure(CaptureSessionError.captureTimedOut))
            }
        }
        #else
        throw CaptureSessionError.backendFailure(message: "Photo capture is unavailable on this platform.")
        #endif
    }

    public func rawCaptureCapability() -> RawCaptureCapability {
        #if canImport(AVFoundation)
        do {
            try configureSessionIfNeeded(for: activeLensPosition)
        } catch {
            return RawCaptureCapability(
                isSupported: false,
                availableRawPhotoPixelFormatTypes: [],
                reason: "RAW capability check failed: \(String(describing: error))"
            )
        }

        let formatTypes: [UInt32] = photoOutput.availableRawPhotoPixelFormatTypes.map { UInt32($0) }
        return RawCaptureCapability(
            isSupported: !formatTypes.isEmpty,
            availableRawPhotoPixelFormatTypes: formatTypes,
            reason: formatTypes.isEmpty ? "No RAW pixel formats are available for the active camera configuration." : nil
        )
        #else
        return RawCaptureCapability(
            isSupported: false,
            availableRawPhotoPixelFormatTypes: [],
            reason: "RAW photo capture is unavailable on this platform."
        )
        #endif
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
        if !session.outputs.contains(where: { $0 === photoOutput }) {
            guard session.canAddOutput(photoOutput) else {
                throw CaptureSessionError.backendFailure(message: "Cannot add photo output to capture session.")
            }
            session.addOutput(photoOutput)
        }
        isConfigured = true
    }

    private func cameraDevice(for position: CaptureLensPosition) -> AVCaptureDevice? {
        let avPosition: AVCaptureDevice.Position = position == .back ? .back : .front
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: avPosition)
    }

    private func makePhotoSettings(for format: CapturePhotoFormat) throws -> AVCapturePhotoSettings {
        switch format {
        case .processed:
            return makeProcessedPhotoSettings()
        case .raw:
            return try makeRawPhotoSettings()
        }
    }

    private func makeProcessedPhotoSettings() -> AVCapturePhotoSettings {
        let settings: AVCapturePhotoSettings
        if photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        } else {
            settings = AVCapturePhotoSettings()
        }
        settings.photoQualityPrioritization = .balanced
        return settings
    }

    private func makeRawPhotoSettings() throws -> AVCapturePhotoSettings {
        #if os(macOS)
        throw CaptureSessionError.rawCaptureNotSupported
        #else
        guard let rawPixelFormatType = photoOutput.availableRawPhotoPixelFormatTypes.first else {
            throw CaptureSessionError.rawCaptureNotSupported
        }

        let processedCodec = preferredProcessedCodec()
        guard let processedCodec else {
            throw CaptureSessionError.backendFailure(
                message: "RAW capture requires a processed codec for RAW+processed pair output."
            )
        }

        try enforceRawSafetyPolicy()

        let rawFileType = preferredRawFileType()
        let processedFileType = preferredProcessedFileType()
        let settings: AVCapturePhotoSettings
        if let rawFileType {
            settings = AVCapturePhotoSettings(
                rawPixelFormatType: rawPixelFormatType,
                rawFileType: rawFileType,
                processedFormat: [AVVideoCodecKey: processedCodec],
                processedFileType: processedFileType
            )
        } else {
            settings = AVCapturePhotoSettings(
                rawPixelFormatType: rawPixelFormatType,
                processedFormat: [AVVideoCodecKey: processedCodec]
            )
        }
        settings.photoQualityPrioritization = .speed
        settings.flashMode = .off
        settings.isHighResolutionPhotoEnabled = false
        return settings
        #endif
    }

    private func preferredProcessedCodec() -> AVVideoCodecType? {
        if photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
            return .jpeg
        }
        return photoOutput.availablePhotoCodecTypes.first
    }

    private func preferredRawFileType() -> AVFileType? {
        #if os(macOS)
        return nil
        #else
        let dngType = AVFileType(rawValue: "com.adobe.raw-image")
        if photoOutput.availableRawPhotoFileTypes.contains(dngType) {
            return dngType
        }
        return photoOutput.availableRawPhotoFileTypes.first
        #endif
    }

    private func preferredProcessedFileType() -> AVFileType? {
        let jpegType = AVFileType(rawValue: "public.jpeg")
        if photoOutput.availablePhotoFileTypes.contains(jpegType) {
            return jpegType
        }
        return photoOutput.availablePhotoFileTypes.first
    }

    private func enforceRawSafetyPolicy() throws {
        #if os(macOS)
        throw CaptureSessionError.rawCaptureNotSupported
        #else
        if let connection = photoOutput.connection(with: .video),
           connection.videoScaleAndCropFactor != 1.0 {
            connection.videoScaleAndCropFactor = 1.0
        }

        if let activeDeviceInput = session.inputs.compactMap({ $0 as? AVCaptureDeviceInput }).first {
            let device = activeDeviceInput.device
            if device.videoZoomFactor != 1.0 {
                do {
                    try device.lockForConfiguration()
                    defer { device.unlockForConfiguration() }
                    let clampedZoom = min(max(1.0, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
                    device.videoZoomFactor = clampedZoom
                } catch {
                    throw CaptureSessionError.backendFailure(
                        message: "RAW capture requires zoom factor 1.0, and the camera could not reset zoom automatically."
                    )
                }
            }
        }

        if let connection = photoOutput.connection(with: .video),
           connection.videoScaleAndCropFactor != 1.0 {
            throw CaptureSessionError.backendFailure(
                message: "RAW capture requires zoom factor 1.0."
            )
        }

        if let activeDeviceInput = session.inputs.compactMap({ $0 as? AVCaptureDeviceInput }).first,
           activeDeviceInput.device.videoZoomFactor != 1.0 {
            throw CaptureSessionError.backendFailure(
                message: "RAW capture requires camera zoom factor 1.0."
            )
        }
        #endif
    }

    private func addInFlightCapture(_ processor: PhotoCaptureProcessor, id: UUID) {
        inFlightCaptureLock.withLock {
            inFlightCaptures[id] = processor
        }
    }

    private func removeInFlightCapture(_ id: UUID) {
        inFlightCaptureLock.withLock {
            inFlightCaptures[id] = nil
        }
    }
    #endif
}

#if canImport(AVFoundation)
private final class CaptureCompletionBox: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<CapturedPhotoPayload, Error>?

    init(continuation: CheckedContinuation<CapturedPhotoPayload, Error>) {
        self.continuation = continuation
    }

    func resume(with result: Result<CapturedPhotoPayload, Error>) {
        let capturedContinuation = lock.withLock {
            let continuation = continuation
            self.continuation = nil
            return continuation
        }
        capturedContinuation?.resume(with: result)
    }
}
#endif

#if canImport(AVFoundation)
private final class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    private let requestedFormat: CapturePhotoFormat
    private let onComplete: (Result<CapturedPhotoPayload, Error>) -> Void
    private let lock = NSLock()
    private var hasCompleted = false
    private var processedData: Data?
    private var rawData: Data?
    private var processingError: Error?

    init(
        requestedFormat: CapturePhotoFormat,
        onComplete: @escaping (Result<CapturedPhotoPayload, Error>) -> Void
    ) {
        self.requestedFormat = requestedFormat
        self.onComplete = onComplete
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            lock.withLock {
                processingError = error
            }
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            lock.withLock {
                processingError = CaptureSessionError.backendFailure(message: "Failed to produce photo data.")
            }
            return
        }
        lock.withLock {
            #if os(macOS)
            processedData = data
            #else
            if photo.isRawPhoto {
                rawData = data
            } else {
                processedData = data
            }
            #endif
        }
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        if let error {
            completeOnce(.failure(CaptureSessionError.backendFailure(message: error.localizedDescription)))
            return
        }
        let result = lock.withLock { () -> Result<CapturedPhotoPayload, Error> in
            if let processingError {
                return .failure(
                    CaptureSessionError.backendFailure(message: processingError.localizedDescription)
                )
            }

            let payload = CapturedPhotoPayload(
                processedData: processedData,
                rawData: rawData
            )

            switch requestedFormat {
            case .processed:
                guard payload.processedData != nil else {
                    return .failure(
                        CaptureSessionError.backendFailure(
                            message: "Photo capture finished without processed image data."
                        )
                    )
                }
            case .raw:
                guard payload.rawData != nil else {
                    return .failure(
                        CaptureSessionError.backendFailure(
                            message: "Photo capture finished without RAW image data."
                        )
                    )
                }
                guard payload.processedData != nil else {
                    return .failure(
                        CaptureSessionError.backendFailure(
                            message: "RAW capture finished without processed pair image data."
                        )
                    )
                }
            }

            return .success(payload)
        }

        completeOnce(result)
    }

    private func completeOnce(_ result: Result<CapturedPhotoPayload, Error>) {
        let shouldComplete = lock.withLock {
            if hasCompleted {
                return false
            }
            hasCompleted = true
            return true
        }
        guard shouldComplete else { return }
        onComplete(result)
    }
}
#endif

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
