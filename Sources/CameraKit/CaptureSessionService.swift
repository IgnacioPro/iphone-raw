import Foundation

#if canImport(AVFoundation)
import AVFoundation
#endif

public enum CaptureLensPosition: String, Equatable, Sendable {
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

public typealias LuminanceHistogramHandler = @Sendable (LuminanceHistogram) -> Void

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
    func startRunning() async throws
    func stopRunning() async
    func switchCamera() async throws -> CaptureLensPosition
    func capturePhoto() async throws -> Data
    func capturePhoto(format: CapturePhotoFormat) async throws -> Data
    func capturePhotoPayload(format: CapturePhotoFormat) async throws -> CapturedPhotoPayload
    func rawCaptureCapability() -> RawCaptureCapability
    func applyExposureState(_ state: ExposureControlState) throws -> ExposureControlState
    func applyFocusState(_ state: FocusControlState) throws -> FocusControlState
    func applyWhiteBalanceState(_ state: WhiteBalanceControlState) throws -> WhiteBalanceControlState
    func applyExposureCompensation(_ value: Double) throws -> Double
    func exposureCompensationRange() -> ClosedRange<Double>?
    func setLuminanceHistogramHandler(_ handler: LuminanceHistogramHandler?)
    func setZebraClippingThreshold(_ threshold: Double?)
    func setZebraClippingOverlayHandler(_ handler: ZebraClippingOverlayHandler?)
    func setFocusPeakingThreshold(_ threshold: Double?)
    func setFocusPeakingOverlayHandler(_ handler: FocusPeakingOverlayHandler?)
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
    func start() async throws
    func stop() async
    func switchCamera() async throws
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
    func setLuminanceHistogramHandler(_ handler: LuminanceHistogramHandler?)
    func setZebraClippingThreshold(_ threshold: Double?)
    func setZebraClippingOverlayHandler(_ handler: ZebraClippingOverlayHandler?)
    func setFocusPeakingThreshold(_ threshold: Double?)
    func setFocusPeakingOverlayHandler(_ handler: FocusPeakingOverlayHandler?)
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

    func setLuminanceHistogramHandler(_ handler: LuminanceHistogramHandler?) {}

    func setZebraClippingThreshold(_ threshold: Double?) {}

    func setZebraClippingOverlayHandler(_ handler: ZebraClippingOverlayHandler?) {}

    func setFocusPeakingThreshold(_ threshold: Double?) {}

    func setFocusPeakingOverlayHandler(_ handler: FocusPeakingOverlayHandler?) {}
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

    public func start() async throws {
        do {
            try await backend.startRunning()
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

    public func stop() async {
        await backend.stopRunning()
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

    public func switchCamera() async throws {
        do {
            let newPosition = try await backend.switchCamera()
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

    public func setLuminanceHistogramHandler(_ handler: LuminanceHistogramHandler?) {
        backend.setLuminanceHistogramHandler(handler)
    }

    public func setZebraClippingThreshold(_ threshold: Double?) {
        backend.setZebraClippingThreshold(threshold)
    }

    public func setZebraClippingOverlayHandler(_ handler: ZebraClippingOverlayHandler?) {
        backend.setZebraClippingOverlayHandler(handler)
    }

    public func setFocusPeakingThreshold(_ threshold: Double?) {
        backend.setFocusPeakingThreshold(threshold)
    }

    public func setFocusPeakingOverlayHandler(_ handler: FocusPeakingOverlayHandler?) {
        backend.setFocusPeakingOverlayHandler(handler)
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

    public func startRunning() async throws {
        isRunning = true
    }

    public func stopRunning() async {
        isRunning = false
    }

    public func switchCamera() async throws -> CaptureLensPosition {
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

public final class AVCaptureSessionBackend: NSObject, CaptureSessionBackend, @unchecked Sendable {
    #if canImport(AVFoundation)
    private let session: AVCaptureSession
    private let photoOutput: AVCapturePhotoOutput
    private let videoDataOutput: AVCaptureVideoDataOutput
    private let sessionQueue: DispatchQueue
    private let sessionQueueKey = DispatchSpecificKey<UInt8>()
    private let sessionQueueValue: UInt8 = 1
    private let videoDataOutputQueue: DispatchQueue
    private var isConfigured = false
    private let inFlightCaptureLock = NSLock()
    private var inFlightCaptures: [UUID: PhotoCaptureProcessor] = [:]
    private let histogramHandlerLock = NSLock()
    private var histogramHandler: LuminanceHistogramHandler?
    private let zebraOverlayLock = NSLock()
    private var zebraThresholdLuma: UInt8?
    private var zebraThresholdNormalized: Double = 0.95
    private var zebraOverlayHandler: ZebraClippingOverlayHandler?
    private let focusPeakingOverlayLock = NSLock()
    private var focusPeakingThresholdMagnitude: UInt16?
    private var focusPeakingThresholdNormalized: Double = 0.24
    private var focusPeakingOverlayHandler: FocusPeakingOverlayHandler?
    #endif

    public private(set) var isRunning = false
    public private(set) var activeLensPosition: CaptureLensPosition

    public override init() {
        self.activeLensPosition = .back
        #if canImport(AVFoundation)
        self.session = AVCaptureSession()
        self.photoOutput = AVCapturePhotoOutput()
        self.videoDataOutput = AVCaptureVideoDataOutput()
        self.sessionQueue = DispatchQueue(label: "CameraKit.CaptureSessionBackend.SessionQueue")
        self.videoDataOutputQueue = DispatchQueue(label: "CameraKit.PreviewAnalysisVideoDataOutput")
        #endif
        super.init()
        #if canImport(AVFoundation)
        sessionQueue.setSpecific(key: sessionQueueKey, value: sessionQueueValue)
        onSessionQueueSync {
            configureVideoDataOutput()
        }
        #endif
    }

    public init(initialPosition: CaptureLensPosition = .back) {
        self.activeLensPosition = initialPosition
        #if canImport(AVFoundation)
        self.session = AVCaptureSession()
        self.photoOutput = AVCapturePhotoOutput()
        self.videoDataOutput = AVCaptureVideoDataOutput()
        self.sessionQueue = DispatchQueue(label: "CameraKit.CaptureSessionBackend.SessionQueue")
        self.videoDataOutputQueue = DispatchQueue(label: "CameraKit.PreviewAnalysisVideoDataOutput")
        #endif
        super.init()
        #if canImport(AVFoundation)
        sessionQueue.setSpecific(key: sessionQueueKey, value: sessionQueueValue)
        onSessionQueueSync {
            configureVideoDataOutput()
        }
        #endif
    }

    deinit {
        #if canImport(AVFoundation)
        onSessionQueueSync {
            videoDataOutput.setSampleBufferDelegate(nil, queue: nil)
        }
        #endif
    }

    #if canImport(AVFoundation)
    public var previewSession: AVCaptureSession? {
        session
    }
    #endif

    public func startRunning() async throws {
        #if canImport(AVFoundation)
        try await onSessionQueueAsync { [self] in
            try configureSessionIfNeeded(for: activeLensPosition)
            if !session.isRunning {
                session.startRunning()
            }
            isRunning = true
        }
        #endif
        #if !canImport(AVFoundation)
        isRunning = true
        #endif
    }

    public func stopRunning() async {
        #if canImport(AVFoundation)
        await onSessionQueueAsync { [self] in
            if session.isRunning {
                session.stopRunning()
            }
            isRunning = false
        }
        #endif
        #if !canImport(AVFoundation)
        isRunning = false
        #endif
    }

    public func switchCamera() async throws -> CaptureLensPosition {
        let targetPosition: CaptureLensPosition = activeLensPosition == .back ? .front : .back
        #if canImport(AVFoundation)
        try await onSessionQueueAsync { [self] in
            guard cameraDevice(for: targetPosition) != nil else {
                throw CaptureSessionError.cameraSwitchNotSupported
            }

            try configureSession(for: targetPosition)
            if isRunning, !session.isRunning {
                session.startRunning()
            }
            activeLensPosition = targetPosition
        }
        #endif
        #if !canImport(AVFoundation)
        activeLensPosition = targetPosition
        #endif
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
        return try await withCheckedThrowingContinuation { continuation in
            let completionBox = CaptureCompletionBox(continuation: continuation)
            let captureID = UUID()

            do {
                try onSessionQueueSync {
                    guard isRunning, session.isRunning else {
                        throw CaptureSessionError.backendFailure(message: "Capture session is not running.")
                    }

                    let metadataSnapshot = captureMetadataSnapshot()
                    let processor = PhotoCaptureProcessor(
                        requestedFormat: format,
                        metadataSnapshot: metadataSnapshot
                    ) { [weak self] result in
                        self?.removeInFlightCapture(captureID)
                        completionBox.resume(with: result)
                    }
                    addInFlightCapture(processor, id: captureID)
                    photoOutput.capturePhoto(with: try makePhotoSettings(for: format), delegate: processor)
                }
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
        onSessionQueueSync {
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
        }
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
        try onSessionQueueSync {
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
        }
        #else
        return state
        #endif
    }

    public func applyWhiteBalanceState(_ state: WhiteBalanceControlState) throws -> WhiteBalanceControlState {
        #if canImport(AVFoundation)
        try onSessionQueueSync {
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
        }
        #else
        return state
        #endif
    }

    public func applyExposureCompensation(_ value: Double) throws -> Double {
        #if canImport(AVFoundation)
        try onSessionQueueSync {
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
        }
        #else
        return value
        #endif
    }

    public func exposureCompensationRange() -> ClosedRange<Double>? {
        #if canImport(AVFoundation)
        onSessionQueueSync {
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
        }
        #else
        return nil
        #endif
    }

    public func setLuminanceHistogramHandler(_ handler: LuminanceHistogramHandler?) {
        #if canImport(AVFoundation)
        histogramHandlerLock.withLock {
            histogramHandler = handler
        }
        #endif
    }

    public func setZebraClippingThreshold(_ threshold: Double?) {
        #if canImport(AVFoundation)
        zebraOverlayLock.withLock {
            guard let threshold else {
                zebraThresholdLuma = nil
                return
            }
            let clampedThreshold = min(max(threshold, 0), 1)
            zebraThresholdNormalized = clampedThreshold
            zebraThresholdLuma = UInt8((clampedThreshold * 255.0).rounded())
        }
        #endif
    }

    public func setZebraClippingOverlayHandler(_ handler: ZebraClippingOverlayHandler?) {
        #if canImport(AVFoundation)
        zebraOverlayLock.withLock {
            zebraOverlayHandler = handler
        }
        #endif
    }

    public func setFocusPeakingThreshold(_ threshold: Double?) {
        #if canImport(AVFoundation)
        focusPeakingOverlayLock.withLock {
            guard let threshold else {
                focusPeakingThresholdMagnitude = nil
                return
            }
            let clampedThreshold = min(max(threshold, 0), 1)
            focusPeakingThresholdNormalized = clampedThreshold
            let maxMagnitude = Double(FocusPeakingOverlayAnalyzer.maxGradientMagnitude)
            focusPeakingThresholdMagnitude = UInt16((clampedThreshold * maxMagnitude).rounded())
        }
        #endif
    }

    public func setFocusPeakingOverlayHandler(_ handler: FocusPeakingOverlayHandler?) {
        #if canImport(AVFoundation)
        focusPeakingOverlayLock.withLock {
            focusPeakingOverlayHandler = handler
        }
        #endif
    }

    public func applyFocusState(_ state: FocusControlState) throws -> FocusControlState {
        #if canImport(AVFoundation)
        try onSessionQueueSync {
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
        }
        #else
        return state
        #endif
    }

    #if canImport(AVFoundation)
    private func onSessionQueueSync<T>(_ body: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: sessionQueueKey) == sessionQueueValue {
            return try body()
        }
        return try sessionQueue.sync {
            try body()
        }
    }

    private func onSessionQueueAsync<T: Sendable>(_ body: @Sendable @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                do {
                    let result = try body()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func onSessionQueueAsync(_ body: @Sendable @escaping () -> Void) async {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                body()
                continuation.resume()
            }
        }
    }

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
        if !session.outputs.contains(where: { $0 === videoDataOutput }) {
            guard session.canAddOutput(videoDataOutput) else {
                throw CaptureSessionError.backendFailure(message: "Cannot add video data output to capture session.")
            }
            session.addOutput(videoDataOutput)
        }
        #if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
        if photoOutput.isAppleProRAWSupported, !photoOutput.isAppleProRAWEnabled {
            photoOutput.isAppleProRAWEnabled = true
        }
        #endif
        isConfigured = true
    }

    private func configureVideoDataOutput() {
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        let pixelFormatType = preferredHistogramPixelFormatType()
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: pixelFormatType)
        ]
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
    }

    private func preferredHistogramPixelFormatType() -> OSType {
        let preferredPixelFormatTypes: [OSType] = [
            kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            kCVPixelFormatType_32BGRA,
        ]
        let supportedPixelFormatTypes = Set(videoDataOutput.availableVideoPixelFormatTypes)
        return preferredPixelFormatTypes.first(where: { supportedPixelFormatTypes.contains($0) })
            ?? kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
    }

    private func dispatchHistogramIfNeeded(from sampleBuffer: CMSampleBuffer) {
        guard let histogramHandler = histogramHandlerLock.withLock({ histogramHandler }) else {
            return
        }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let histogram = LuminanceHistogramAnalyzer.histogram(from: pixelBuffer) else {
            return
        }
        histogramHandler(histogram)
    }

    private func dispatchZebraOverlayIfNeeded(from sampleBuffer: CMSampleBuffer) {
        let zebraConfiguration = zebraOverlayLock.withLock {
            (
                handler: zebraOverlayHandler,
                thresholdLuma: zebraThresholdLuma,
                threshold: zebraThresholdNormalized
            )
        }
        guard let zebraHandler = zebraConfiguration.handler,
              let thresholdLuma = zebraConfiguration.thresholdLuma else {
            return
        }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let overlay = ZebraClippingOverlayAnalyzer.overlay(
                  from: pixelBuffer,
                  thresholdLuma: thresholdLuma,
                  threshold: zebraConfiguration.threshold
              ) else {
            return
        }
        zebraHandler(overlay)
    }

    private func dispatchFocusPeakingOverlayIfNeeded(from sampleBuffer: CMSampleBuffer) {
        let peakingConfiguration = focusPeakingOverlayLock.withLock {
            (
                handler: focusPeakingOverlayHandler,
                thresholdMagnitude: focusPeakingThresholdMagnitude,
                threshold: focusPeakingThresholdNormalized
            )
        }
        guard let peakingHandler = peakingConfiguration.handler,
              let thresholdMagnitude = peakingConfiguration.thresholdMagnitude else {
            return
        }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let overlay = FocusPeakingOverlayAnalyzer.overlay(
                  from: pixelBuffer,
                  thresholdMagnitude: thresholdMagnitude,
                  threshold: peakingConfiguration.threshold
              ) else {
            return
        }
        peakingHandler(overlay)
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
extension AVCaptureSessionBackend: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard output === videoDataOutput else { return }
        dispatchHistogramIfNeeded(from: sampleBuffer)
        dispatchZebraOverlayIfNeeded(from: sampleBuffer)
        dispatchFocusPeakingOverlayIfNeeded(from: sampleBuffer)
    }
}

private enum LuminanceHistogramAnalyzer {
    static let binCount = LuminanceHistogram.defaultBinCount
    static let sampleStride = 4

    static func histogram(from pixelBuffer: CVPixelBuffer) -> LuminanceHistogram? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        var bins = Array(repeating: UInt32(0), count: binCount)
        var sampleCount: UInt32 = 0

        let planeCount = CVPixelBufferGetPlaneCount(pixelBuffer)
        if planeCount > 0 {
            guard let baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else {
                return nil
            }
            let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
            let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
            let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
            accumulateLuminanceBins(
                fromPlanarLumaBaseAddress: baseAddress,
                width: width,
                height: height,
                bytesPerRow: bytesPerRow,
                into: &bins,
                sampleCount: &sampleCount
            )
        } else {
            guard CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_32BGRA,
                  let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
                return nil
            }
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
            accumulateLuminanceBins(
                fromBGRABaseAddress: baseAddress,
                width: width,
                height: height,
                bytesPerRow: bytesPerRow,
                into: &bins,
                sampleCount: &sampleCount
            )
        }

        guard sampleCount > 0 else { return nil }
        return LuminanceHistogram(
            bins: bins,
            sampleCount: sampleCount,
            generatedAt: Date()
        )
    }

    private static func accumulateLuminanceBins(
        fromPlanarLumaBaseAddress baseAddress: UnsafeMutableRawPointer,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        into bins: inout [UInt32],
        sampleCount: inout UInt32
    ) {
        let lumaBuffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        for y in stride(from: 0, to: height, by: sampleStride) {
            let rowPointer = lumaBuffer.advanced(by: y * bytesPerRow)
            for x in stride(from: 0, to: width, by: sampleStride) {
                let luminance = rowPointer[x]
                let binIndex = min((Int(luminance) * binCount) >> 8, binCount - 1)
                bins[binIndex] += 1
                sampleCount += 1
            }
        }
    }

    private static func accumulateLuminanceBins(
        fromBGRABaseAddress baseAddress: UnsafeMutableRawPointer,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        into bins: inout [UInt32],
        sampleCount: inout UInt32
    ) {
        let bgraBuffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        for y in stride(from: 0, to: height, by: sampleStride) {
            let rowPointer = bgraBuffer.advanced(by: y * bytesPerRow)
            for x in stride(from: 0, to: width, by: sampleStride) {
                let pixelOffset = x * 4
                let blue = Int(rowPointer[pixelOffset])
                let green = Int(rowPointer[pixelOffset + 1])
                let red = Int(rowPointer[pixelOffset + 2])
                // Integer BT.709 approximation.
                let luminance = (54 * red + 183 * green + 19 * blue) >> 8
                let binIndex = min((luminance * binCount) >> 8, binCount - 1)
                bins[binIndex] += 1
                sampleCount += 1
            }
        }
    }
}

private enum ZebraClippingOverlayAnalyzer {
    static let sampleStride = 4
    static let minimumClippedSampleRatio = 0.08
    static let columnCount = ZebraClippingOverlay.defaultColumnCount
    static let rowCount = ZebraClippingOverlay.defaultRowCount

    static func overlay(
        from pixelBuffer: CVPixelBuffer,
        thresholdLuma: UInt8,
        threshold: Double
    ) -> ZebraClippingOverlay? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let cellCount = columnCount * rowCount
        var clippedSampleCounts = Array(repeating: UInt32(0), count: cellCount)
        var totalSampleCounts = Array(repeating: UInt32(0), count: cellCount)

        let planeCount = CVPixelBufferGetPlaneCount(pixelBuffer)
        if planeCount > 0 {
            guard let baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else {
                return nil
            }
            let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
            let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
            let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
            accumulateClippingSamples(
                fromPlanarLumaBaseAddress: baseAddress,
                width: width,
                height: height,
                bytesPerRow: bytesPerRow,
                thresholdLuma: thresholdLuma,
                clippedSampleCounts: &clippedSampleCounts,
                totalSampleCounts: &totalSampleCounts
            )
        } else {
            guard CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_32BGRA,
                  let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
                return nil
            }
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
            accumulateClippingSamples(
                fromBGRABaseAddress: baseAddress,
                width: width,
                height: height,
                bytesPerRow: bytesPerRow,
                thresholdLuma: thresholdLuma,
                clippedSampleCounts: &clippedSampleCounts,
                totalSampleCounts: &totalSampleCounts
            )
        }

        var clippedCells = Array(repeating: UInt8(0), count: cellCount)
        for index in 0..<cellCount {
            let totalSamples = totalSampleCounts[index]
            guard totalSamples > 0 else { continue }
            let clippedSamples = clippedSampleCounts[index]
            if Double(clippedSamples) / Double(totalSamples) >= minimumClippedSampleRatio {
                clippedCells[index] = 1
            }
        }

        return ZebraClippingOverlay(
            columnCount: columnCount,
            rowCount: rowCount,
            clippedCells: clippedCells,
            threshold: threshold,
            generatedAt: Date()
        )
    }

    private static func accumulateClippingSamples(
        fromPlanarLumaBaseAddress baseAddress: UnsafeMutableRawPointer,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        thresholdLuma: UInt8,
        clippedSampleCounts: inout [UInt32],
        totalSampleCounts: inout [UInt32]
    ) {
        let lumaBuffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        for y in stride(from: 0, to: height, by: sampleStride) {
            let rowPointer = lumaBuffer.advanced(by: y * bytesPerRow)
            for x in stride(from: 0, to: width, by: sampleStride) {
                let cellIndex = gridCellIndex(x: x, y: y, width: width, height: height)
                totalSampleCounts[cellIndex] += 1
                if rowPointer[x] >= thresholdLuma {
                    clippedSampleCounts[cellIndex] += 1
                }
            }
        }
    }

    private static func accumulateClippingSamples(
        fromBGRABaseAddress baseAddress: UnsafeMutableRawPointer,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        thresholdLuma: UInt8,
        clippedSampleCounts: inout [UInt32],
        totalSampleCounts: inout [UInt32]
    ) {
        let bgraBuffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        for y in stride(from: 0, to: height, by: sampleStride) {
            let rowPointer = bgraBuffer.advanced(by: y * bytesPerRow)
            for x in stride(from: 0, to: width, by: sampleStride) {
                let pixelOffset = x * 4
                let blue = Int(rowPointer[pixelOffset])
                let green = Int(rowPointer[pixelOffset + 1])
                let red = Int(rowPointer[pixelOffset + 2])
                let luminance = UInt8((54 * red + 183 * green + 19 * blue) >> 8)
                let cellIndex = gridCellIndex(x: x, y: y, width: width, height: height)
                totalSampleCounts[cellIndex] += 1
                if luminance >= thresholdLuma {
                    clippedSampleCounts[cellIndex] += 1
                }
            }
        }
    }

    private static func gridCellIndex(x: Int, y: Int, width: Int, height: Int) -> Int {
        guard width > 0, height > 0 else { return 0 }
        let column = min((x * columnCount) / width, columnCount - 1)
        let row = min((y * rowCount) / height, rowCount - 1)
        return row * columnCount + column
    }
}

private enum FocusPeakingOverlayAnalyzer {
    static let sampleStride = 4
    static let minimumPeakedSampleRatio = 0.18
    static let maxGradientMagnitude: UInt16 = 510
    static let columnCount = FocusPeakingOverlay.defaultColumnCount
    static let rowCount = FocusPeakingOverlay.defaultRowCount

    static func overlay(
        from pixelBuffer: CVPixelBuffer,
        thresholdMagnitude: UInt16,
        threshold: Double
    ) -> FocusPeakingOverlay? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let cellCount = columnCount * rowCount
        var peakedSampleCounts = Array(repeating: UInt32(0), count: cellCount)
        var totalSampleCounts = Array(repeating: UInt32(0), count: cellCount)

        let planeCount = CVPixelBufferGetPlaneCount(pixelBuffer)
        if planeCount > 0 {
            guard let baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else {
                return nil
            }
            let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
            let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
            let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
            accumulatePeakingSamples(
                fromPlanarLumaBaseAddress: baseAddress,
                width: width,
                height: height,
                bytesPerRow: bytesPerRow,
                thresholdMagnitude: thresholdMagnitude,
                peakedSampleCounts: &peakedSampleCounts,
                totalSampleCounts: &totalSampleCounts
            )
        } else {
            guard CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_32BGRA,
                  let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
                return nil
            }
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
            accumulatePeakingSamples(
                fromBGRABaseAddress: baseAddress,
                width: width,
                height: height,
                bytesPerRow: bytesPerRow,
                thresholdMagnitude: thresholdMagnitude,
                peakedSampleCounts: &peakedSampleCounts,
                totalSampleCounts: &totalSampleCounts
            )
        }

        var peakCells = Array(repeating: UInt8(0), count: cellCount)
        for index in 0..<cellCount {
            let totalSamples = totalSampleCounts[index]
            guard totalSamples > 0 else { continue }
            let peakedSamples = peakedSampleCounts[index]
            if Double(peakedSamples) / Double(totalSamples) >= minimumPeakedSampleRatio {
                peakCells[index] = 1
            }
        }

        return FocusPeakingOverlay(
            columnCount: columnCount,
            rowCount: rowCount,
            peakCells: peakCells,
            threshold: threshold,
            generatedAt: Date()
        )
    }

    private static func accumulatePeakingSamples(
        fromPlanarLumaBaseAddress baseAddress: UnsafeMutableRawPointer,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        thresholdMagnitude: UInt16,
        peakedSampleCounts: inout [UInt32],
        totalSampleCounts: inout [UInt32]
    ) {
        guard width > 1, height > 1 else { return }
        let lumaBuffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        for y in stride(from: 0, to: height - 1, by: sampleStride) {
            let rowPointer = lumaBuffer.advanced(by: y * bytesPerRow)
            let nextRowPointer = lumaBuffer.advanced(by: (y + 1) * bytesPerRow)
            for x in stride(from: 0, to: width - 1, by: sampleStride) {
                let centerLuma = Int(rowPointer[x])
                let rightLuma = Int(rowPointer[x + 1])
                let downLuma = Int(nextRowPointer[x])
                let gradientMagnitude = UInt16(abs(rightLuma - centerLuma) + abs(downLuma - centerLuma))
                let cellIndex = gridCellIndex(x: x, y: y, width: width, height: height)
                totalSampleCounts[cellIndex] += 1
                if gradientMagnitude >= thresholdMagnitude {
                    peakedSampleCounts[cellIndex] += 1
                }
            }
        }
    }

    private static func accumulatePeakingSamples(
        fromBGRABaseAddress baseAddress: UnsafeMutableRawPointer,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        thresholdMagnitude: UInt16,
        peakedSampleCounts: inout [UInt32],
        totalSampleCounts: inout [UInt32]
    ) {
        guard width > 1, height > 1 else { return }
        let bgraBuffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        for y in stride(from: 0, to: height - 1, by: sampleStride) {
            let rowPointer = bgraBuffer.advanced(by: y * bytesPerRow)
            let nextRowPointer = bgraBuffer.advanced(by: (y + 1) * bytesPerRow)
            for x in stride(from: 0, to: width - 1, by: sampleStride) {
                let pixelOffset = x * 4
                let centerLuma = luminance(
                    red: Int(rowPointer[pixelOffset + 2]),
                    green: Int(rowPointer[pixelOffset + 1]),
                    blue: Int(rowPointer[pixelOffset])
                )
                let rightLuma = luminance(
                    red: Int(rowPointer[pixelOffset + 6]),
                    green: Int(rowPointer[pixelOffset + 5]),
                    blue: Int(rowPointer[pixelOffset + 4])
                )
                let downLuma = luminance(
                    red: Int(nextRowPointer[pixelOffset + 2]),
                    green: Int(nextRowPointer[pixelOffset + 1]),
                    blue: Int(nextRowPointer[pixelOffset])
                )
                let gradientMagnitude = UInt16(abs(rightLuma - centerLuma) + abs(downLuma - centerLuma))
                let cellIndex = gridCellIndex(x: x, y: y, width: width, height: height)
                totalSampleCounts[cellIndex] += 1
                if gradientMagnitude >= thresholdMagnitude {
                    peakedSampleCounts[cellIndex] += 1
                }
            }
        }
    }

    private static func luminance(red: Int, green: Int, blue: Int) -> Int {
        (54 * red + 183 * green + 19 * blue) >> 8
    }

    private static func gridCellIndex(x: Int, y: Int, width: Int, height: Int) -> Int {
        guard width > 0, height > 0 else { return 0 }
        let column = min((x * columnCount) / width, columnCount - 1)
        let row = min((y * rowCount) / height, rowCount - 1)
        return row * columnCount + column
    }
}

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
