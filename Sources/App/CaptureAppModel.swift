import CameraKit
import Foundation
import Storage
#if canImport(AVFoundation)
import AVFoundation
#endif

public enum AppBootState: Equatable, Sendable {
    case idle
    case requestingPermission
    case ready
    case blocked(reason: String)
    case failed(reason: String)
}

public final class CaptureAppModel {
    private let permissionGate: CameraPermissionGate
    private let sessionService: CaptureSessionServing
    private let logger: CaptureEventLogging?
    private let metadataStore: CaptureMetadataStoring
    private let presetStore: CapturePresetStoring

    public private(set) var bootState: AppBootState = .idle

    public init(
        permissionGate: CameraPermissionGate,
        sessionService: CaptureSessionServing,
        metadataStore: CaptureMetadataStoring,
        presetStore: CapturePresetStoring = InMemoryCapturePresetStore(),
        logger: CaptureEventLogging? = nil
    ) {
        self.permissionGate = permissionGate
        self.sessionService = sessionService
        self.metadataStore = metadataStore
        self.presetStore = presetStore
        self.logger = logger
    }

    public func bootstrap() async {
        bootState = .requestingPermission

        let access = await permissionGate.ensureAccess()
        switch access {
        case .granted:
            do {
                try await sessionService.start()
                bootState = .ready
                logger?.log(
                    CaptureEvent(
                        category: .system,
                        action: "app_boot_ready"
                    )
                )
            } catch {
                let message = String(describing: error)
                bootState = .failed(reason: message)
                logger?.log(
                    CaptureEvent(
                        category: .system,
                        action: "app_boot_failed",
                        payload: ["error": message]
                    )
                )
            }
        case .denied:
            bootState = .blocked(reason: "Camera access denied. Enable it in Settings.")
            logger?.log(
                CaptureEvent(
                    category: .system,
                    action: "app_boot_blocked_denied"
                )
            )
        case .restricted:
            bootState = .blocked(reason: "Camera access restricted by system policy.")
            logger?.log(
                CaptureEvent(
                    category: .system,
                    action: "app_boot_blocked_restricted"
                )
            )
        }
    }

    public func stopSession() async {
        await sessionService.stop()
    }

    public func resumeSessionIfNeeded() async {
        guard case .ready = bootState else { return }

        do {
            try await sessionService.start()
            bootState = .ready
        } catch {
            let message = String(describing: error)
            bootState = .failed(reason: message)
            logger?.log(
                CaptureEvent(
                    category: .system,
                    action: "app_session_resume_failed",
                    payload: ["error": message]
                )
            )
        }
    }

    public func switchCamera() async throws {
        try await sessionService.switchCamera()
    }

    public func capturePhotoData() async throws -> Data {
        try await sessionService.capturePhoto()
    }

    public func capturePhotoData(format: CapturePhotoFormat) async throws -> Data {
        try await sessionService.capturePhoto(format: format)
    }

    public func capturePhotoPayload(format: CapturePhotoFormat) async throws -> CapturedPhotoPayload {
        try await sessionService.capturePhotoPayload(format: format)
    }

    public func currentLensPosition() -> CaptureLensPosition? {
        guard case let .running(position) = sessionService.state else {
            return nil
        }
        return position
    }

    public func rawCaptureCapability() -> RawCaptureCapability {
        sessionService.rawCaptureCapability()
    }

    public func setLuminanceHistogramHandler(_ handler: LuminanceHistogramHandler?) {
        sessionService.setLuminanceHistogramHandler(handler)
    }

    public func setZebraClippingThreshold(_ threshold: Double?) {
        sessionService.setZebraClippingThreshold(threshold)
    }

    public func setZebraClippingOverlayHandler(_ handler: ZebraClippingOverlayHandler?) {
        sessionService.setZebraClippingOverlayHandler(handler)
    }

    public func setFocusPeakingThreshold(_ threshold: Double?) {
        sessionService.setFocusPeakingThreshold(threshold)
    }

    public func setFocusPeakingOverlayHandler(_ handler: FocusPeakingOverlayHandler?) {
        sessionService.setFocusPeakingOverlayHandler(handler)
    }

    public func exposureState() -> ExposureControlState {
        sessionService.exposureState
    }

    public func setExposureAuto() throws {
        try sessionService.setExposureAuto()
    }

    public func lockExposure(iso: Double, shutterSeconds: Double) throws {
        try sessionService.lockExposure(iso: iso, shutterSeconds: shutterSeconds)
    }

    public func setCustomExposure(iso: Double, shutterSeconds: Double) throws {
        try sessionService.setCustomExposure(iso: iso, shutterSeconds: shutterSeconds)
    }

    public func exposureCompensation() -> Double {
        sessionService.exposureCompensation
    }

    public func exposureCompensationRange() -> ClosedRange<Double> {
        sessionService.exposureCompensationRange
    }

    public func setExposureCompensation(_ value: Double) throws {
        try sessionService.setExposureCompensation(value)
    }

    public func resetExposureCompensation() throws {
        try sessionService.resetExposureCompensation()
    }

    @discardableResult
    public func saveCurrentControlPreset(
        for slot: CapturePresetSlot,
        savedAt: Date = Date()
    ) throws -> CaptureControlPreset {
        let preset = CaptureControlPreset(
            exposureState: CapturePresetExposureState(sessionService.exposureState),
            focusState: CapturePresetFocusState(sessionService.focusState),
            whiteBalanceState: CapturePresetWhiteBalanceState(sessionService.whiteBalanceState),
            exposureCompensation: sessionService.exposureCompensation,
            savedAt: savedAt
        )
        try presetStore.save(preset, for: slot)
        logger?.log(
            CaptureEvent(
                category: .capture,
                action: "control_preset_saved",
                payload: [
                    "slot": slot.rawValue,
                    "saved_at": savedAt.ISO8601Format(),
                ]
            )
        )
        return preset
    }

    public func loadControlPreset(for slot: CapturePresetSlot) throws -> CaptureControlPreset? {
        try presetStore.load(for: slot)
    }

    public func availableControlPresetSlots() throws -> Set<CapturePresetSlot> {
        try presetStore.availableSlots()
    }

    @discardableResult
    public func applyControlPreset(for slot: CapturePresetSlot) throws -> CaptureControlPreset? {
        guard let preset = try presetStore.load(for: slot) else {
            return nil
        }
        try applyControlPreset(preset, slot: slot)
        return preset
    }

    public func focusState() -> FocusControlState {
        sessionService.focusState
    }

    public func setFocusAuto() throws {
        try sessionService.setFocusAuto()
    }

    public func lockFocus(lensPosition: Double) throws {
        try sessionService.lockFocus(lensPosition: lensPosition)
    }

    public func whiteBalanceState() -> WhiteBalanceControlState {
        sessionService.whiteBalanceState
    }

    public func setWhiteBalanceAuto() throws {
        try sessionService.setWhiteBalanceAuto()
    }

    public func lockWhiteBalance(temperatureKelvin: Double, tint: Double) throws {
        try sessionService.lockWhiteBalance(temperatureKelvin: temperatureKelvin, tint: tint)
    }

    public func markSessionInterrupted(reason: String) {
        sessionService.markInterrupted(reason: reason)
    }

    #if canImport(AVFoundation)
    public var previewSession: AVCaptureSession? {
        sessionService.previewSession
    }
    #endif

    public func saveArtifact(_ artifact: CaptureArtifact) async {
        await metadataStore.save(artifact)
    }

    public func removePhotoLibraryCaptures(localIdentifiers: [String]) async {
        let normalizedIdentifiers = Set(localIdentifiers)
        guard !normalizedIdentifiers.isEmpty else { return }
        await metadataStore.delete(photoLibraryLocalIdentifiers: normalizedIdentifiers)
        logger?.log(
            CaptureEvent(
                category: .storage,
                action: "capture_metadata_deleted",
                payload: ["count": "\(normalizedIdentifiers.count)"]
            )
        )
    }

    public func persistPhotoLibraryCapture(
        localIdentifier: String,
        capturedAt: Date,
        lensPosition: CaptureLensPosition?,
        byteCount: Int,
        captureFormat: CapturePhotoFormat,
        pairedLocalIdentifier: String? = nil,
        pairedByteCount: Int? = nil,
        captureMetadata: CaptureTechnicalMetadata? = nil,
        pairedCaptureMetadata: CaptureTechnicalMetadata? = nil
    ) async {
        var metadata: [String: String] = [
            "photo_library_local_identifier": localIdentifier,
            "captured_at": capturedAt.ISO8601Format(),
            "lens_position": lensPosition?.rawValue ?? "unknown",
            "byte_count": String(byteCount),
            "capture_format": captureFormat.rawValue,
        ]
        if let pairedLocalIdentifier {
            metadata["paired_photo_library_local_identifier"] = pairedLocalIdentifier
        }
        if let pairedByteCount {
            metadata["paired_byte_count"] = String(pairedByteCount)
        }
        appendCaptureMetadata(captureMetadata, prefix: "capture_", to: &metadata)
        appendCaptureMetadata(pairedCaptureMetadata, prefix: "paired_capture_", to: &metadata)

        let artifact = CaptureArtifact(
            createdAt: capturedAt,
            primaryURL: URL(string: "photos://asset")!,
            photoLibraryLocalIdentifier: localIdentifier,
            metadata: metadata
        )
        await metadataStore.save(artifact)

        logger?.log(
            CaptureEvent(
                category: .storage,
                action: "capture_metadata_saved",
                payload: metadata
            )
        )
    }

    private func appendCaptureMetadata(
        _ captureMetadata: CaptureTechnicalMetadata?,
        prefix: String,
        to metadata: inout [String: String]
    ) {
        guard let captureMetadata else { return }
        if let lensModel = captureMetadata.lensModel {
            metadata["\(prefix)lens_model"] = lensModel
        }
        if let iso = captureMetadata.iso {
            metadata["\(prefix)iso"] = String(iso)
        }
        if let shutterSeconds = captureMetadata.shutterSeconds {
            metadata["\(prefix)shutter_seconds"] = String(shutterSeconds)
        }
        if let whiteBalanceMode = captureMetadata.whiteBalanceMode {
            metadata["\(prefix)white_balance_mode"] = whiteBalanceMode
        }
        if let whiteBalanceTemperatureKelvin = captureMetadata.whiteBalanceTemperatureKelvin {
            metadata["\(prefix)white_balance_temperature_kelvin"] = String(whiteBalanceTemperatureKelvin)
        }
        if let whiteBalanceTint = captureMetadata.whiteBalanceTint {
            metadata["\(prefix)white_balance_tint"] = String(whiteBalanceTint)
        }
    }

    private func applyControlPreset(
        _ preset: CaptureControlPreset,
        slot: CapturePresetSlot
    ) throws {
        switch preset.exposureState.resolvedCameraState() {
        case .auto:
            try setExposureAuto()
        case let .locked(values):
            try lockExposure(iso: values.iso, shutterSeconds: values.shutterSeconds)
        case let .custom(values):
            try setCustomExposure(iso: values.iso, shutterSeconds: values.shutterSeconds)
        }

        switch preset.focusState.resolvedCameraState() {
        case .auto:
            try setFocusAuto()
        case let .locked(lensPosition):
            try lockFocus(lensPosition: lensPosition)
        }

        switch preset.whiteBalanceState.resolvedCameraState() {
        case .auto:
            try setWhiteBalanceAuto()
        case let .locked(values):
            try lockWhiteBalance(
                temperatureKelvin: values.temperatureKelvin,
                tint: values.tint
            )
        }

        try setExposureCompensation(preset.exposureCompensation)

        logger?.log(
            CaptureEvent(
                category: .capture,
                action: "control_preset_applied",
                payload: [
                    "slot": slot.rawValue,
                    "saved_at": preset.savedAt.ISO8601Format(),
                ]
            )
        )
    }
}

extension CaptureAppModel: @unchecked Sendable {}
