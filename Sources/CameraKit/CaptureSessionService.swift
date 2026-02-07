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
    public let isAppleProRAWSupported: Bool
    public let availableAppleProRAWPhotoPixelFormatTypes: [UInt32]
    public let appleProRAWReason: String?

    public init(
        isSupported: Bool,
        availableRawPhotoPixelFormatTypes: [UInt32],
        reason: String? = nil,
        isAppleProRAWSupported: Bool = false,
        availableAppleProRAWPhotoPixelFormatTypes: [UInt32] = [],
        appleProRAWReason: String? = nil
    ) {
        self.isSupported = isSupported
        self.availableRawPhotoPixelFormatTypes = availableRawPhotoPixelFormatTypes
        self.reason = reason
        self.isAppleProRAWSupported = isAppleProRAWSupported
        self.availableAppleProRAWPhotoPixelFormatTypes = availableAppleProRAWPhotoPixelFormatTypes
        self.appleProRAWReason = appleProRAWReason
    }
}

public enum CapturePhotoFormat: String, Equatable, Sendable {
    case processed
    case raw
    case appleProRAW
}

public struct CapturedPhotoPayload: Equatable, Sendable {
    public let processedData: Data?
    public let rawData: Data?
    public let processedMetadata: CaptureTechnicalMetadata?
    public let rawMetadata: CaptureTechnicalMetadata?

    public init(
        processedData: Data? = nil,
        rawData: Data? = nil,
        processedMetadata: CaptureTechnicalMetadata? = nil,
        rawMetadata: CaptureTechnicalMetadata? = nil
    ) {
        self.processedData = processedData
        self.rawData = rawData
        self.processedMetadata = processedMetadata
        self.rawMetadata = rawMetadata
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
        case .appleProRAW:
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
        case .appleProRAW:
            return processedData
        }
    }

    public func primaryMetadata(for format: CapturePhotoFormat) -> CaptureTechnicalMetadata? {
        switch format {
        case .processed:
            return processedMetadata ?? rawMetadata
        case .raw:
            return rawMetadata ?? processedMetadata
        case .appleProRAW:
            return rawMetadata ?? processedMetadata
        }
    }

    public func secondaryMetadata(for format: CapturePhotoFormat) -> CaptureTechnicalMetadata? {
        switch format {
        case .processed:
            return rawMetadata
        case .raw:
            return processedMetadata
        case .appleProRAW:
            return processedMetadata
        }
    }
}

public enum CaptureSessionError: Error, Equatable, LocalizedError {
    case cameraSwitchNotSupported
    case backendFailure(message: String)
    case captureTimedOut
    case rawCaptureNotSupported
    case appleProRAWCaptureNotSupported

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
        case .appleProRAWCaptureNotSupported:
            return "Apple ProRAW capture is not supported for the current camera configuration."
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
    func applyExposureState(_ state: ExposureControlState) throws -> ExposureControlState
    func applyFocusState(_ state: FocusControlState) throws -> FocusControlState
    func applyWhiteBalanceState(_ state: WhiteBalanceControlState) throws -> WhiteBalanceControlState
    func applyExposureCompensation(_ value: Double) throws -> Double
    func exposureCompensationRange() -> ClosedRange<Double>?
}

public protocol CaptureSessionServing {
    var state: CaptureSessionState { get }
    var exposureState: ExposureControlState { get }
    var focusState: FocusControlState { get }
    var whiteBalanceState: WhiteBalanceControlState { get }
    var exposureCompensation: Double { get }
    var exposureCompensationRange: ClosedRange<Double> { get }
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
    func setExposureAuto() throws
    func lockExposure(iso: Double, shutterSeconds: Double) throws
    func setCustomExposure(iso: Double, shutterSeconds: Double) throws
    func setFocusAuto() throws
    func lockFocus(lensPosition: Double) throws
    func setWhiteBalanceAuto() throws
    func lockWhiteBalance(temperatureKelvin: Double, tint: Double) throws
    func setExposureCompensation(_ value: Double) throws
    func resetExposureCompensation() throws
}

public extension CaptureSessionBackend {
    func capturePhoto(format: CapturePhotoFormat) async throws -> Data {
        switch format {
        case .processed:
            return try await capturePhoto()
        case .raw:
            throw CaptureSessionError.rawCaptureNotSupported
        case .appleProRAW:
            throw CaptureSessionError.appleProRAWCaptureNotSupported
        }
    }

    func capturePhotoPayload(format: CapturePhotoFormat) async throws -> CapturedPhotoPayload {
        let data = try await capturePhoto(format: format)
        switch format {
        case .processed:
            return CapturedPhotoPayload(processedData: data)
        case .raw:
            return CapturedPhotoPayload(rawData: data)
        case .appleProRAW:
            return CapturedPhotoPayload(rawData: data)
        }
    }

    func applyExposureState(_ state: ExposureControlState) throws -> ExposureControlState {
        state
    }

    func applyFocusState(_ state: FocusControlState) throws -> FocusControlState {
        state
    }

    func applyWhiteBalanceState(_ state: WhiteBalanceControlState) throws -> WhiteBalanceControlState {
        state
    }

    func applyExposureCompensation(_ value: Double) throws -> Double {
        value
    }

    func exposureCompensationRange() -> ClosedRange<Double>? {
        nil
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
        case .appleProRAW:
            return CapturedPhotoPayload(rawData: data)
        }
    }
}

public final class CaptureSessionService: CaptureSessionServing {
    private let backend: CaptureSessionBackend
    private let logger: CaptureEventLogging?
    private let lock = NSLock()
    private var mutableState: CaptureSessionState = .idle
    private var exposureStateMachine = ExposureStateMachine()
    private var focusStateMachine = FocusStateMachine()
    private var whiteBalanceStateMachine = WhiteBalanceStateMachine()
    private var mutableExposureCompensation: Double = 0

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

    public var exposureState: ExposureControlState {
        lock.withLock { exposureStateMachine.state }
    }

    public var focusState: FocusControlState {
        lock.withLock { focusStateMachine.state }
    }

    public var whiteBalanceState: WhiteBalanceControlState {
        lock.withLock { whiteBalanceStateMachine.state }
    }

    public var exposureCompensation: Double {
        lock.withLock { mutableExposureCompensation }
    }

    public var exposureCompensationRange: ClosedRange<Double> {
        backend.exposureCompensationRange() ?? (-2.0...2.0)
    }

    #if canImport(AVFoundation)
    public var previewSession: AVCaptureSession? {
        backend.previewSession
    }
    #endif

    public func start() throws {
        do {
            try backend.startRunning()
            let configuredExposureState = lock.withLock { exposureStateMachine.state }
            let appliedExposureState = try backend.applyExposureState(configuredExposureState)
            let configuredFocusState = lock.withLock { focusStateMachine.state }
            let appliedFocusState = try backend.applyFocusState(configuredFocusState)
            let configuredWhiteBalanceState = lock.withLock { whiteBalanceStateMachine.state }
            let appliedWhiteBalanceState = try backend.applyWhiteBalanceState(configuredWhiteBalanceState)
            let configuredExposureCompensation = lock.withLock { mutableExposureCompensation }
            let appliedExposureCompensation = try backend.applyExposureCompensation(configuredExposureCompensation)
            lock.withLock {
                exposureStateMachine = ExposureStateMachine(initialState: appliedExposureState)
                focusStateMachine = FocusStateMachine(initialState: appliedFocusState)
                whiteBalanceStateMachine = WhiteBalanceStateMachine(initialState: appliedWhiteBalanceState)
                mutableExposureCompensation = appliedExposureCompensation
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
            let configuredExposureState = lock.withLock { exposureStateMachine.state }
            let appliedExposureState = try backend.applyExposureState(configuredExposureState)
            let configuredFocusState = lock.withLock { focusStateMachine.state }
            let appliedFocusState = try backend.applyFocusState(configuredFocusState)
            let configuredWhiteBalanceState = lock.withLock { whiteBalanceStateMachine.state }
            let appliedWhiteBalanceState = try backend.applyWhiteBalanceState(configuredWhiteBalanceState)
            let configuredExposureCompensation = lock.withLock { mutableExposureCompensation }
            let appliedExposureCompensation = try backend.applyExposureCompensation(configuredExposureCompensation)
            lock.withLock {
                exposureStateMachine = ExposureStateMachine(initialState: appliedExposureState)
                focusStateMachine = FocusStateMachine(initialState: appliedFocusState)
                whiteBalanceStateMachine = WhiteBalanceStateMachine(initialState: appliedWhiteBalanceState)
                mutableExposureCompensation = appliedExposureCompensation
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

    public func setExposureAuto() throws {
        _ = try applyExposureTransition(.setAuto)
    }

    public func lockExposure(iso: Double, shutterSeconds: Double) throws {
        _ = try applyExposureTransition(
            .lock(
                ExposureValues(
                    iso: iso,
                    shutterSeconds: shutterSeconds
                )
            )
        )
    }

    public func setCustomExposure(iso: Double, shutterSeconds: Double) throws {
        _ = try applyExposureTransition(
            .setCustom(
                ExposureValues(
                    iso: iso,
                    shutterSeconds: shutterSeconds
                )
            )
        )
    }

    public func setFocusAuto() throws {
        _ = try applyFocusTransition(.setAuto)
    }

    public func lockFocus(lensPosition: Double) throws {
        _ = try applyFocusTransition(.lock(lensPosition: lensPosition))
    }

    public func setWhiteBalanceAuto() throws {
        _ = try applyWhiteBalanceTransition(.setAuto)
    }

    public func lockWhiteBalance(temperatureKelvin: Double, tint: Double) throws {
        _ = try applyWhiteBalanceTransition(
            .lock(
                WhiteBalanceValues(
                    temperatureKelvin: temperatureKelvin,
                    tint: tint
                )
            )
        )
    }

    public func setExposureCompensation(_ value: Double) throws {
        _ = try applyExposureCompensation(value)
    }

    public func resetExposureCompensation() throws {
        _ = try applyExposureCompensation(0)
    }

    public func capturePhoto() async throws -> Data {
        try await capturePhoto(format: .processed)
    }

    public func capturePhoto(format: CapturePhotoFormat) async throws -> Data {
        let payload = try await capturePhotoPayload(format: format)
        return try payload.primaryData(for: format)
    }

    public func capturePhotoPayload(format: CapturePhotoFormat) async throws -> CapturedPhotoPayload {
        let captureID = UUID()
        let startedAt = Date()
        logger?.log(
            CaptureEvent(
                category: .capture,
                action: "photo_capture_started",
                payload: [
                    "capture_id": captureID.uuidString,
                    "format": format.rawValue,
                    "capture_started_at": startedAt.ISO8601Format(),
                ]
            )
        )

        do {
            let payload = try await backend.capturePhotoPayload(format: format)
            let endedAt = Date()
            let primaryData = try payload.primaryData(for: format)
            let secondaryByteCount = payload.secondaryData(for: format)?.count
            var eventPayload: [String: String] = [
                "capture_id": captureID.uuidString,
                "format": format.rawValue,
                "capture_started_at": startedAt.ISO8601Format(),
                "capture_ended_at": endedAt.ISO8601Format(),
                "capture_latency_ms": "\(Self.captureLatencyMilliseconds(from: startedAt, to: endedAt))",
                "bytes": "\(primaryData.count)",
                "total_bytes": "\(payload.totalByteCount)",
            ]
            if let secondaryByteCount {
                eventPayload["paired_bytes"] = "\(secondaryByteCount)"
            }
            logger?.log(
                CaptureEvent(
                    category: .capture,
                    action: "photo_capture_succeeded",
                    payload: eventPayload
                )
            )
            return payload
        } catch {
            let endedAt = Date()
            let message = String(describing: error)
            logger?.log(
                CaptureEvent(
                    category: .capture,
                    action: "photo_capture_failed",
                    payload: [
                        "capture_id": captureID.uuidString,
                        "format": format.rawValue,
                        "capture_started_at": startedAt.ISO8601Format(),
                        "capture_ended_at": endedAt.ISO8601Format(),
                        "capture_latency_ms": "\(Self.captureLatencyMilliseconds(from: startedAt, to: endedAt))",
                        "error": message,
                    ]
                )
            )
            throw error
        }
    }

    public func rawCaptureCapability() -> RawCaptureCapability {
        backend.rawCaptureCapability()
    }

    private static func captureLatencyMilliseconds(from start: Date, to end: Date) -> Int {
        max(Int((end.timeIntervalSince(start) * 1_000).rounded()), 0)
    }

    @discardableResult
    private func applyExposureTransition(_ transition: ExposureStateTransition) throws -> ExposureControlState {
        let previousState = lock.withLock { exposureStateMachine.state }
        let requestedState = try lock.withLock {
            try exposureStateMachine.apply(transition)
        }

        do {
            let appliedState = try backend.applyExposureState(requestedState)
            lock.withLock {
                exposureStateMachine = ExposureStateMachine(initialState: appliedState)
            }
            logExposureModeChange(state: appliedState)
            return appliedState
        } catch {
            lock.withLock {
                exposureStateMachine = ExposureStateMachine(initialState: previousState)
            }
            logger?.log(
                CaptureEvent(
                    category: .capture,
                    action: "exposure_mode_change_failed",
                    payload: [
                        "mode": requestedState.mode.rawValue,
                        "error": String(describing: error),
                    ]
                )
            )
            throw error
        }
    }

    @discardableResult
    private func applyFocusTransition(_ transition: FocusStateTransition) throws -> FocusControlState {
        let previousState = lock.withLock { focusStateMachine.state }
        let requestedState = try lock.withLock {
            try focusStateMachine.apply(transition)
        }

        do {
            let appliedState = try backend.applyFocusState(requestedState)
            lock.withLock {
                focusStateMachine = FocusStateMachine(initialState: appliedState)
            }
            logFocusModeChange(state: appliedState)
            return appliedState
        } catch {
            lock.withLock {
                focusStateMachine = FocusStateMachine(initialState: previousState)
            }
            logger?.log(
                CaptureEvent(
                    category: .capture,
                    action: "focus_mode_change_failed",
                    payload: [
                        "mode": requestedState.mode.rawValue,
                        "error": String(describing: error),
                    ]
                )
            )
            throw error
        }
    }

    @discardableResult
    private func applyWhiteBalanceTransition(_ transition: WhiteBalanceStateTransition) throws -> WhiteBalanceControlState {
        let previousState = lock.withLock { whiteBalanceStateMachine.state }
        let requestedState = try lock.withLock {
            try whiteBalanceStateMachine.apply(transition)
        }

        do {
            let appliedState = try backend.applyWhiteBalanceState(requestedState)
            lock.withLock {
                whiteBalanceStateMachine = WhiteBalanceStateMachine(initialState: appliedState)
            }
            logWhiteBalanceModeChange(state: appliedState)
            return appliedState
        } catch {
            lock.withLock {
                whiteBalanceStateMachine = WhiteBalanceStateMachine(initialState: previousState)
            }
            logger?.log(
                CaptureEvent(
                    category: .capture,
                    action: "white_balance_mode_change_failed",
                    payload: [
                        "mode": requestedState.mode.rawValue,
                        "error": String(describing: error),
                    ]
                )
            )
            throw error
        }
    }

    private func logExposureModeChange(state: ExposureControlState) {
        var payload: [String: String] = [
            "mode": state.mode.rawValue,
        ]
        if let values = state.values {
            payload["iso"] = String(values.iso)
            payload["shutter_seconds"] = String(values.shutterSeconds)
        }
        logger?.log(
            CaptureEvent(
                category: .capture,
                action: "exposure_mode_changed",
                payload: payload
            )
        )
    }

    private func logFocusModeChange(state: FocusControlState) {
        var payload: [String: String] = [
            "mode": state.mode.rawValue,
        ]
        if let lensPosition = state.lensPosition {
            payload["lens_position"] = String(lensPosition)
        }
        logger?.log(
            CaptureEvent(
                category: .capture,
                action: "focus_mode_changed",
                payload: payload
            )
        )
    }

    private func logWhiteBalanceModeChange(state: WhiteBalanceControlState) {
        var payload: [String: String] = [
            "mode": state.mode.rawValue,
        ]
        if let values = state.values {
            payload["temperature_kelvin"] = String(values.temperatureKelvin)
            payload["tint"] = String(values.tint)
        }
        logger?.log(
            CaptureEvent(
                category: .capture,
                action: "white_balance_mode_changed",
                payload: payload
            )
        )
    }

    @discardableResult
    private func applyExposureCompensation(_ value: Double) throws -> Double {
        guard value.isFinite else {
            throw CaptureSessionError.backendFailure(message: "Exposure compensation value must be finite.")
        }

        let previousValue = lock.withLock { mutableExposureCompensation }
        do {
            let appliedValue = try backend.applyExposureCompensation(value)
            lock.withLock {
                mutableExposureCompensation = appliedValue
            }
            logger?.log(
                CaptureEvent(
                    category: .capture,
                    action: "exposure_compensation_changed",
                    payload: [
                        "ev": String(appliedValue),
                    ]
                )
            )
            return appliedValue
        } catch {
            lock.withLock {
                mutableExposureCompensation = previousValue
            }
            logger?.log(
                CaptureEvent(
                    category: .capture,
                    action: "exposure_compensation_change_failed",
                    payload: [
                        "ev": String(value),
                        "error": String(describing: error),
                    ]
                )
            )
            throw error
        }
    }
}

public final class SimulatedCaptureSessionBackend: CaptureSessionBackend {
    public private(set) var isRunning = false
    public private(set) var activeLensPosition: CaptureLensPosition
    private var exposureState: ExposureControlState = .auto
    private var focusState: FocusControlState = .auto
    private var whiteBalanceState: WhiteBalanceControlState = .auto
    private var exposureCompensation: Double = 0

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

    public func applyExposureState(_ state: ExposureControlState) throws -> ExposureControlState {
        exposureState = state
        return exposureState
    }

    public func applyFocusState(_ state: FocusControlState) throws -> FocusControlState {
        focusState = state
        return focusState
    }

    public func applyWhiteBalanceState(_ state: WhiteBalanceControlState) throws -> WhiteBalanceControlState {
        whiteBalanceState = state
        return whiteBalanceState
    }

    public func applyExposureCompensation(_ value: Double) throws -> Double {
        exposureCompensation = value
        return exposureCompensation
    }

    public func exposureCompensationRange() -> ClosedRange<Double>? {
        -3...3
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
            let metadataSnapshot = captureMetadataSnapshot()
            let processor = PhotoCaptureProcessor(
                requestedFormat: format,
                metadataSnapshot: metadataSnapshot
            ) { [weak self] result in
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

        #if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
        let bayerFormatTypes: [UInt32] = photoOutput.availableRawPhotoPixelFormatTypes
            .filter { AVCapturePhotoOutput.isBayerRAWPixelFormat($0) }
            .map { UInt32($0) }
        let appleProRAWFormatTypes: [UInt32] = photoOutput.availableRawPhotoPixelFormatTypes
            .filter { AVCapturePhotoOutput.isAppleProRAWPixelFormat($0) }
            .map { UInt32($0) }
        #else
        let bayerFormatTypes: [UInt32] = photoOutput.availableRawPhotoPixelFormatTypes.map { UInt32($0) }
        let appleProRAWFormatTypes: [UInt32] = []
        #endif

        return RawCaptureCapability(
            isSupported: !bayerFormatTypes.isEmpty,
            availableRawPhotoPixelFormatTypes: bayerFormatTypes,
            reason: bayerFormatTypes.isEmpty ? "No Bayer RAW pixel formats are available for the active camera configuration." : nil,
            isAppleProRAWSupported: !appleProRAWFormatTypes.isEmpty,
            availableAppleProRAWPhotoPixelFormatTypes: appleProRAWFormatTypes,
            appleProRAWReason: appleProRAWFormatTypes.isEmpty ? "No Apple ProRAW pixel formats are available for the active camera configuration." : nil
        )
        #else
        return RawCaptureCapability(
            isSupported: false,
            availableRawPhotoPixelFormatTypes: [],
            reason: "RAW photo capture is unavailable on this platform."
        )
        #endif
    }

    public func applyExposureState(_ state: ExposureControlState) throws -> ExposureControlState {
        #if canImport(AVFoundation)
        try configureSessionIfNeeded(for: activeLensPosition)
        guard let activeDevice = session.inputs.compactMap({ $0 as? AVCaptureDeviceInput }).first?.device else {
            throw CaptureSessionError.backendFailure(message: "No active camera device is configured.")
        }

        do {
            try activeDevice.lockForConfiguration()
        } catch {
            throw CaptureSessionError.backendFailure(
                message: "Could not lock active camera device for exposure configuration."
            )
        }
        defer { activeDevice.unlockForConfiguration() }

        switch state {
        case .auto:
            if activeDevice.isExposureModeSupported(.continuousAutoExposure) {
                activeDevice.exposureMode = .continuousAutoExposure
                return .auto
            }
            if activeDevice.isExposureModeSupported(.autoExpose) {
                activeDevice.exposureMode = .autoExpose
                return .auto
            }
            throw CaptureSessionError.backendFailure(
                message: "Auto exposure is not supported by the active camera."
            )
        case let .locked(values):
            return .locked(try applyManualExposure(values, to: activeDevice))
        case let .custom(values):
            return .custom(try applyManualExposure(values, to: activeDevice))
        }
        #else
        return state
        #endif
    }

    public func applyWhiteBalanceState(_ state: WhiteBalanceControlState) throws -> WhiteBalanceControlState {
        #if canImport(AVFoundation)
        try configureSessionIfNeeded(for: activeLensPosition)
        guard let activeDevice = session.inputs.compactMap({ $0 as? AVCaptureDeviceInput }).first?.device else {
            throw CaptureSessionError.backendFailure(message: "No active camera device is configured.")
        }

        do {
            try activeDevice.lockForConfiguration()
        } catch {
            throw CaptureSessionError.backendFailure(
                message: "Could not lock active camera device for white balance configuration."
            )
        }
        defer { activeDevice.unlockForConfiguration() }

        switch state {
        case .auto:
            if activeDevice.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                activeDevice.whiteBalanceMode = .continuousAutoWhiteBalance
                return .auto
            }
            if activeDevice.isWhiteBalanceModeSupported(.autoWhiteBalance) {
                activeDevice.whiteBalanceMode = .autoWhiteBalance
                return .auto
            }
            throw CaptureSessionError.backendFailure(
                message: "Auto white balance is not supported by the active camera."
            )
        case let .locked(values):
            return .locked(try applyLockedWhiteBalance(values, to: activeDevice))
        }
        #else
        return state
        #endif
    }

    public func applyExposureCompensation(_ value: Double) throws -> Double {
        #if canImport(AVFoundation)
        try configureSessionIfNeeded(for: activeLensPosition)
        guard let activeDevice = session.inputs.compactMap({ $0 as? AVCaptureDeviceInput }).first?.device else {
            throw CaptureSessionError.backendFailure(message: "No active camera device is configured.")
        }

        #if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
        let range = Double(activeDevice.minExposureTargetBias)...Double(activeDevice.maxExposureTargetBias)
        let clampedValue = min(max(value, range.lowerBound), range.upperBound)
        do {
            try activeDevice.lockForConfiguration()
        } catch {
            throw CaptureSessionError.backendFailure(
                message: "Could not lock active camera device for EV compensation."
            )
        }
        defer { activeDevice.unlockForConfiguration() }
        activeDevice.setExposureTargetBias(Float(clampedValue), completionHandler: nil)
        return clampedValue
        #else
        throw CaptureSessionError.backendFailure(
            message: "Exposure compensation controls are unavailable on this platform."
        )
        #endif
        #else
        return value
        #endif
    }

    public func exposureCompensationRange() -> ClosedRange<Double>? {
        #if canImport(AVFoundation)
        do {
            try configureSessionIfNeeded(for: activeLensPosition)
        } catch {
            return nil
        }
        guard let activeDevice = session.inputs.compactMap({ $0 as? AVCaptureDeviceInput }).first?.device else {
            return nil
        }
        #if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
        return Double(activeDevice.minExposureTargetBias)...Double(activeDevice.maxExposureTargetBias)
        #else
        return nil
        #endif
        #else
        return nil
        #endif
    }

    public func applyFocusState(_ state: FocusControlState) throws -> FocusControlState {
        #if canImport(AVFoundation)
        try configureSessionIfNeeded(for: activeLensPosition)
        guard let activeDevice = session.inputs.compactMap({ $0 as? AVCaptureDeviceInput }).first?.device else {
            throw CaptureSessionError.backendFailure(message: "No active camera device is configured.")
        }

        do {
            try activeDevice.lockForConfiguration()
        } catch {
            throw CaptureSessionError.backendFailure(
                message: "Could not lock active camera device for focus configuration."
            )
        }
        defer { activeDevice.unlockForConfiguration() }

        switch state {
        case .auto:
            if activeDevice.isFocusModeSupported(.continuousAutoFocus) {
                activeDevice.focusMode = .continuousAutoFocus
                return .auto
            }
            if activeDevice.isFocusModeSupported(.autoFocus) {
                activeDevice.focusMode = .autoFocus
                return .auto
            }
            throw CaptureSessionError.backendFailure(
                message: "Auto focus is not supported by the active camera."
            )
        case let .locked(lensPosition):
            return .locked(lensPosition: try applyLockedFocus(lensPosition, to: activeDevice))
        }
        #else
        return state
        #endif
    }

    #if canImport(AVFoundation)
    private func applyLockedFocus(_ lensPosition: Double, to device: AVCaptureDevice) throws -> Double {
        #if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
        guard device.isFocusModeSupported(.locked) else {
            throw CaptureSessionError.backendFailure(
                message: "Manual focus lock is not supported by the active camera."
            )
        }
        let clampedPosition = min(max(lensPosition, 0), 1)
        device.setFocusModeLocked(lensPosition: Float(clampedPosition), completionHandler: nil)
        return clampedPosition
        #else
        throw CaptureSessionError.backendFailure(
            message: "Manual focus controls are unavailable on this platform."
        )
        #endif
    }

    private func applyLockedWhiteBalance(
        _ values: WhiteBalanceValues,
        to device: AVCaptureDevice
    ) throws -> WhiteBalanceValues {
        #if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
        guard device.isWhiteBalanceModeSupported(.locked) else {
            throw CaptureSessionError.backendFailure(
                message: "Manual white balance lock is not supported by the active camera."
            )
        }

        let temperatureAndTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
            temperature: Float(values.temperatureKelvin),
            tint: Float(values.tint)
        )
        let convertedGains = device.deviceWhiteBalanceGains(for: temperatureAndTint)
        let clampedGains = clampedWhiteBalanceGains(convertedGains, for: device)
        device.setWhiteBalanceModeLocked(with: clampedGains, completionHandler: nil)
        let appliedTemperatureAndTint = device.temperatureAndTintValues(for: clampedGains)

        return WhiteBalanceValues(
            temperatureKelvin: Double(appliedTemperatureAndTint.temperature),
            tint: Double(appliedTemperatureAndTint.tint)
        )
        #else
        throw CaptureSessionError.backendFailure(
            message: "Manual white balance controls are unavailable on this platform."
        )
        #endif
    }

    #if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
    private func clampedWhiteBalanceGains(
        _ gains: AVCaptureDevice.WhiteBalanceGains,
        for device: AVCaptureDevice
    ) -> AVCaptureDevice.WhiteBalanceGains {
        let minimumGain: Float = 1.0
        let maximumGain = max(device.maxWhiteBalanceGain, minimumGain)
        var clamped = gains
        clamped.redGain = min(max(clamped.redGain, minimumGain), maximumGain)
        clamped.greenGain = min(max(clamped.greenGain, minimumGain), maximumGain)
        clamped.blueGain = min(max(clamped.blueGain, minimumGain), maximumGain)
        return clamped
    }
    #endif

    private func applyManualExposure(_ values: ExposureValues, to device: AVCaptureDevice) throws -> ExposureValues {
        #if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
        guard device.isExposureModeSupported(.custom) else {
            throw CaptureSessionError.backendFailure(
                message: "Manual exposure controls are not supported by the active camera."
            )
        }

        let clampedISO = min(
            max(values.iso, Double(device.activeFormat.minISO)),
            Double(device.activeFormat.maxISO)
        )
        let minimumDuration = max(device.activeFormat.minExposureDuration.seconds, 1.0 / 12_000.0)
        let maximumDuration = max(device.activeFormat.maxExposureDuration.seconds, minimumDuration)
        let clampedShutterSeconds = min(
            max(values.shutterSeconds, minimumDuration),
            maximumDuration
        )

        let exposureDuration = CMTime(
            seconds: clampedShutterSeconds,
            preferredTimescale: 1_000_000_000
        )

        device.setExposureModeCustom(
            duration: exposureDuration,
            iso: Float(clampedISO),
            completionHandler: nil
        )

        return ExposureValues(
            iso: clampedISO,
            shutterSeconds: clampedShutterSeconds
        )
        #else
        throw CaptureSessionError.backendFailure(
            message: "Manual exposure controls are unavailable on this platform."
        )
        #endif
    }

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
        #if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
        if photoOutput.isAppleProRAWSupported, !photoOutput.isAppleProRAWEnabled {
            photoOutput.isAppleProRAWEnabled = true
        }
        #endif
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
        case .appleProRAW:
            return try makeAppleProRAWPhotoSettings()
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
        guard let rawPixelFormatType = preferredBayerRawPixelFormatType() else {
            throw CaptureSessionError.rawCaptureNotSupported
        }

        let processedCodec = preferredProcessedCodec()
        guard let processedCodec else {
            throw CaptureSessionError.backendFailure(
                message: "RAW capture requires a processed codec for RAW+processed pair output."
            )
        }

        try enforceRawSafetyPolicy()

        let rawFileType = preferredRawFileType(for: rawPixelFormatType)
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

    private func makeAppleProRAWPhotoSettings() throws -> AVCapturePhotoSettings {
        #if os(macOS)
        throw CaptureSessionError.appleProRAWCaptureNotSupported
        #else
        guard let rawPixelFormatType = preferredAppleProRAWPixelFormatType() else {
            throw CaptureSessionError.appleProRAWCaptureNotSupported
        }

        let processedCodec = preferredProcessedCodec()
        guard let processedCodec else {
            throw CaptureSessionError.backendFailure(
                message: "Apple ProRAW capture requires a processed codec for paired output."
            )
        }

        let rawFileType = preferredRawFileType(for: rawPixelFormatType)
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
        settings.photoQualityPrioritization = .balanced
        settings.flashMode = .off
        settings.isHighResolutionPhotoEnabled = false
        return settings
        #endif
    }

    private func preferredBayerRawPixelFormatType() -> OSType? {
        #if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
        return photoOutput.availableRawPhotoPixelFormatTypes.first {
            AVCapturePhotoOutput.isBayerRAWPixelFormat($0)
        }
        #else
        return photoOutput.availableRawPhotoPixelFormatTypes.first
        #endif
    }

    private func preferredAppleProRAWPixelFormatType() -> OSType? {
        #if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
        return photoOutput.availableRawPhotoPixelFormatTypes.first {
            AVCapturePhotoOutput.isAppleProRAWPixelFormat($0)
        }
        #else
        return nil
        #endif
    }

    private func preferredProcessedCodec() -> AVVideoCodecType? {
        if photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
            return .jpeg
        }
        return photoOutput.availablePhotoCodecTypes.first
    }

    private func preferredRawFileType(for rawPixelFormatType: OSType) -> AVFileType? {
        #if os(macOS)
        return nil
        #else
        let dngType = AVFileType(rawValue: "com.adobe.raw-image")
        if photoOutput.availableRawPhotoFileTypes.contains(dngType),
           photoOutput.supportedRawPhotoPixelFormatTypes(for: dngType).contains(rawPixelFormatType) {
            return dngType
        }
        for fileType in photoOutput.availableRawPhotoFileTypes {
            let supportedFormats = photoOutput.supportedRawPhotoPixelFormatTypes(for: fileType)
            if supportedFormats.contains(rawPixelFormatType) {
                return fileType
            }
        }
        return nil
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

    private func captureMetadataSnapshot() -> CaptureTechnicalMetadata? {
        guard let activeDevice = session.inputs.compactMap({ $0 as? AVCaptureDeviceInput }).first?.device else {
            return nil
        }

        var iso: Double?
        var shutterSeconds: Double?
        var whiteBalanceMode: String?
        var whiteBalanceTemperatureKelvin: Double?
        var whiteBalanceTint: Double?

        #if os(iOS) || targetEnvironment(macCatalyst)
        iso = Double(activeDevice.iso)
        shutterSeconds = activeDevice.exposureDuration.seconds
        switch activeDevice.whiteBalanceMode {
        case .autoWhiteBalance:
            whiteBalanceMode = "auto"
        case .continuousAutoWhiteBalance:
            whiteBalanceMode = "continuous_auto"
        case .locked:
            whiteBalanceMode = "locked"
        @unknown default:
            whiteBalanceMode = "unknown"
        }
        let temperatureAndTint = activeDevice.temperatureAndTintValues(for: activeDevice.deviceWhiteBalanceGains)
        whiteBalanceTemperatureKelvin = Double(temperatureAndTint.temperature)
        whiteBalanceTint = Double(temperatureAndTint.tint)
        #endif

        let metadata = CaptureTechnicalMetadata(
            lensModel: activeDevice.localizedName,
            iso: iso,
            shutterSeconds: shutterSeconds,
            whiteBalanceMode: whiteBalanceMode,
            whiteBalanceTemperatureKelvin: whiteBalanceTemperatureKelvin,
            whiteBalanceTint: whiteBalanceTint
        )
        return metadata.isEmpty ? nil : metadata
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
    private let metadataSnapshot: CaptureTechnicalMetadata?
    private let onComplete: (Result<CapturedPhotoPayload, Error>) -> Void
    private let lock = NSLock()
    private var hasCompleted = false
    private var processedData: Data?
    private var rawData: Data?
    private var processedMetadata: CaptureTechnicalMetadata?
    private var rawMetadata: CaptureTechnicalMetadata?
    private var processingError: Error?

    init(
        requestedFormat: CapturePhotoFormat,
        metadataSnapshot: CaptureTechnicalMetadata?,
        onComplete: @escaping (Result<CapturedPhotoPayload, Error>) -> Void
    ) {
        self.requestedFormat = requestedFormat
        self.metadataSnapshot = metadataSnapshot
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
        let metadata: CaptureTechnicalMetadata?
        #if os(macOS)
        metadata = metadataSnapshot
        #else
        metadata = CaptureTechnicalMetadata.resolving(
            photoMetadata: photo.metadata,
            fallback: metadataSnapshot
        )
        #endif
        lock.withLock {
            #if os(macOS)
            processedData = data
            processedMetadata = metadata
            #else
            if photo.isRawPhoto {
                rawData = data
                rawMetadata = metadata
            } else {
                processedData = data
                processedMetadata = metadata
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
                rawData: rawData,
                processedMetadata: processedMetadata,
                rawMetadata: rawMetadata
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
            case .appleProRAW:
                guard payload.rawData != nil else {
                    return .failure(
                        CaptureSessionError.backendFailure(
                            message: "Apple ProRAW capture finished without RAW image data."
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
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
