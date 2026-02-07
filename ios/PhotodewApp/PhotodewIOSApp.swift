import App
import CameraKit
import Foundation
import SwiftUI
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(Photos)
import Photos
#endif
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

@main
struct PhotodewIOSApp: SwiftUI.App {
    @StateObject private var bootstrap = BootstrapViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(bootstrap: bootstrap)
        }
    }
}

enum SaveToastState: Equatable {
    case saving
    case saved

    var message: String {
        switch self {
        case .saving:
            return "Saving to Photos..."
        case .saved:
            return "Saved to Photos."
        }
    }
}

@MainActor
final class BootstrapViewModel: ObservableObject {
    @Published private(set) var state: AppBootState = .idle
    @Published private(set) var isCapturingPhoto = false
    @Published private(set) var lastCaptureByteCount: Int?
    @Published private(set) var lastCaptureAt: Date?
    @Published private(set) var lastCaptureError: String?
    @Published private(set) var saveToast: SaveToastState?
    @Published private(set) var isRawCaptureEnabled = false
    @Published private(set) var rawCaptureCapability = RawCaptureCapability(
        isSupported: false,
        availableRawPhotoPixelFormatTypes: [],
        reason: "RAW capability is unavailable until the camera session is running."
    )

    private let model: CaptureAppModel
    private let cameraRollSaver: CameraRollSaving
    private var activeCaptureID: UUID?
    private var dismissSaveToastTask: Task<Void, Never>?

    init(
        model: CaptureAppModel = AppCompositionRoot().makeAppModel(),
        cameraRollSaver: CameraRollSaving = SystemCameraRollSaver()
    ) {
        self.model = model
        self.cameraRollSaver = cameraRollSaver
    }

    func start() async {
        #if targetEnvironment(simulator)
        state = .blocked(reason: "Simulator has no real camera input. Use a physical iPhone for camera testing.")
        rawCaptureCapability = RawCaptureCapability(
            isSupported: false,
            availableRawPhotoPixelFormatTypes: [],
            reason: "RAW capability checks require a physical iPhone camera."
        )
        return
        #else
        await model.bootstrap()
        state = model.bootState
        refreshRawCaptureCapability()
        #endif
    }

    func stop() {
        model.stopSession()
        rawCaptureCapability = RawCaptureCapability(
            isSupported: false,
            availableRawPhotoPixelFormatTypes: [],
            reason: "RAW capability is unavailable until the camera session is running."
        )
    }

    func resumeSessionIfNeeded() {
        model.resumeSessionIfNeeded()
        state = model.bootState
        refreshRawCaptureCapability()
    }

    func capturePhoto() async {
        guard case .ready = state else { return }
        guard !isCapturingPhoto else { return }

        let captureID = UUID()
        activeCaptureID = captureID
        isCapturingPhoto = true
        lastCaptureError = nil
        setSaveToast(nil)

        startCaptureWatchdog(for: captureID)

        do {
            let lensPosition = model.currentLensPosition()
            let captureFormat: CapturePhotoFormat = isRawCaptureEnabled ? .raw : .processed
            let capturePayload = try await model.capturePhotoPayload(format: captureFormat)
            setSaveToast(.saving)
            let saveResult = try await cameraRollSaver.saveCapturePayload(
                capturePayload,
                requestedFormat: captureFormat
            )
            guard activeCaptureID == captureID else { return }
            let capturedAt = Date()
            let primaryByteCount = try capturePayload.primaryData(for: captureFormat).count
            let pairedByteCount = capturePayload.secondaryData(for: captureFormat)?.count
            lastCaptureByteCount = capturePayload.totalByteCount
            lastCaptureAt = capturedAt
            lastCaptureError = nil
            await model.persistPhotoLibraryCapture(
                localIdentifier: saveResult.primaryLocalIdentifier,
                capturedAt: capturedAt,
                lensPosition: lensPosition,
                byteCount: primaryByteCount,
                captureFormat: captureFormat,
                pairedLocalIdentifier: saveResult.pairedLocalIdentifier,
                pairedByteCount: pairedByteCount
            )
            setSaveToast(.saved)
            scheduleSaveToastDismiss()
            activeCaptureID = nil
            isCapturingPhoto = false
        } catch {
            guard activeCaptureID == captureID else { return }
            activeCaptureID = nil
            isCapturingPhoto = false
            lastCaptureError = captureErrorMessage(from: error)
            setSaveToast(nil)
            if error is CaptureSessionError {
                Task { [weak self] in
                    await self?.recoverSessionAfterCaptureFailure()
                }
            }
        }
    }

    func switchCamera() {
        guard case .ready = state else { return }
        do {
            try model.switchCamera()
            lastCaptureError = nil
            refreshRawCaptureCapability()
        } catch {
            lastCaptureError = String(describing: error)
        }
    }

    func toggleRawCaptureMode() {
        guard rawCaptureCapability.isSupported else {
            isRawCaptureEnabled = false
            if let reason = rawCaptureCapability.reason {
                lastCaptureError = reason
            }
            return
        }
        isRawCaptureEnabled.toggle()
        lastCaptureError = nil
    }

    #if canImport(AVFoundation)
    var previewSession: AVCaptureSession? {
        model.previewSession
    }
    #endif

    private func recoverSessionAfterCaptureFailure() async {
        model.stopSession()
        await model.bootstrap()
        state = model.bootState
        refreshRawCaptureCapability()
    }

    private func startCaptureWatchdog(for captureID: UUID) {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard let self else { return }
            guard self.activeCaptureID == captureID else { return }

            self.activeCaptureID = nil
            self.isCapturingPhoto = false
            self.lastCaptureError = "Capture timed out. Restarting camera session."
            self.setSaveToast(nil)
            await self.recoverSessionAfterCaptureFailure()
        }
    }

    private func captureErrorMessage(from error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }

        return error.localizedDescription
    }

    private func setSaveToast(_ toast: SaveToastState?) {
        dismissSaveToastTask?.cancel()
        dismissSaveToastTask = nil
        saveToast = toast
    }

    private func scheduleSaveToastDismiss() {
        dismissSaveToastTask?.cancel()
        dismissSaveToastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.saveToast = nil
                self?.dismissSaveToastTask = nil
            }
        }
    }

    private func refreshRawCaptureCapability() {
        guard case .ready = state else {
            rawCaptureCapability = RawCaptureCapability(
                isSupported: false,
                availableRawPhotoPixelFormatTypes: [],
                reason: "RAW capability is unavailable until the camera session is running."
            )
            isRawCaptureEnabled = false
            return
        }
        rawCaptureCapability = model.rawCaptureCapability()
        if !rawCaptureCapability.isSupported {
            isRawCaptureEnabled = false
        }
    }
}

protocol CameraRollSaving: Sendable {
    func saveCapturePayload(
        _ payload: CapturedPhotoPayload,
        requestedFormat: CapturePhotoFormat
    ) async throws -> CameraRollSaveResult
}

struct CameraRollSaveResult: Sendable, Equatable {
    let primaryLocalIdentifier: String
    let pairedLocalIdentifier: String?
}

#if canImport(Photos)
private struct SystemCameraRollSaver: CameraRollSaving {
    func saveCapturePayload(
        _ payload: CapturedPhotoPayload,
        requestedFormat: CapturePhotoFormat
    ) async throws -> CameraRollSaveResult {
        let status = await authorizationStatus()
        switch status {
        case .authorized, .limited:
            break
        case .restricted:
            throw CameraRollSaveError.accessRestricted
        case .denied, .notDetermined:
            throw CameraRollSaveError.accessDenied
        @unknown default:
            throw CameraRollSaveError.accessDenied
        }

        switch requestedFormat {
        case .processed:
            guard let data = payload.processedData ?? payload.rawData else {
                throw CameraRollSaveError.missingCaptureData
            }
            let localIdentifier = try await saveSingleAsset(data: data, format: .processed)
            return CameraRollSaveResult(
                primaryLocalIdentifier: localIdentifier,
                pairedLocalIdentifier: nil
            )

        case .raw:
            guard let rawData = payload.rawData else {
                throw CameraRollSaveError.missingCaptureData
            }
            guard let processedData = payload.processedData else {
                throw CameraRollSaveError.missingCaptureData
            }

            var rawLocalIdentifier: String?
            var processedLocalIdentifier: String?

            do {
                try await PHPhotoLibrary.shared().performChanges { [rawData, processedData] in
                    let rawRequest = PHAssetCreationRequest.forAsset()
                    rawRequest.addResource(
                        with: .photo,
                        data: rawData,
                        options: makeCreationOptions(format: .raw)
                    )
                    rawLocalIdentifier = rawRequest.placeholderForCreatedAsset?.localIdentifier

                    let processedRequest = PHAssetCreationRequest.forAsset()
                    processedRequest.addResource(
                        with: .photo,
                        data: processedData,
                        options: makeCreationOptions(format: .processed)
                    )
                    processedLocalIdentifier = processedRequest.placeholderForCreatedAsset?.localIdentifier
                }
            } catch {
                throw CameraRollSaveError.saveFailed
            }

            guard let rawLocalIdentifier, let processedLocalIdentifier else {
                throw CameraRollSaveError.saveFailed
            }

            return CameraRollSaveResult(
                primaryLocalIdentifier: rawLocalIdentifier,
                pairedLocalIdentifier: processedLocalIdentifier
            )
        }
    }

    private func saveSingleAsset(data: Data, format: CapturePhotoFormat) async throws -> String {
        var localIdentifier: String?
        do {
            try await PHPhotoLibrary.shared().performChanges { [data] in
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: makeCreationOptions(format: format))
                localIdentifier = request.placeholderForCreatedAsset?.localIdentifier
            }
        } catch {
            throw CameraRollSaveError.saveFailed
        }

        guard let localIdentifier else {
            throw CameraRollSaveError.saveFailed
        }

        return localIdentifier
    }

    private func makeCreationOptions(format: CapturePhotoFormat) -> PHAssetResourceCreationOptions {
        let options = PHAssetResourceCreationOptions()
        let timestamp = Self.filenameTimestampFormatter.string(from: Date())

        switch format {
        case .processed:
            options.originalFilename = "Photodew-\(timestamp).jpg"
            #if canImport(UniformTypeIdentifiers)
            if #available(iOS 26, *) {
                options.contentType = .jpeg
            } else {
                options.uniformTypeIdentifier = "public.jpeg"
            }
            #endif
        case .raw:
            options.originalFilename = "Photodew-\(timestamp).dng"
            #if canImport(UniformTypeIdentifiers)
            if #available(iOS 26, *) {
                options.contentType = .dng
            } else {
                options.uniformTypeIdentifier = "com.adobe.raw-image"
            }
            #endif
        }

        return options
    }

    private func authorizationStatus() async -> PHAuthorizationStatus {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard currentStatus == .notDetermined else { return currentStatus }
        return await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    }

    private static let filenameTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
#else
private struct SystemCameraRollSaver: CameraRollSaving {
    func saveCapturePayload(
        _ payload: CapturedPhotoPayload,
        requestedFormat: CapturePhotoFormat
    ) async throws -> CameraRollSaveResult {
        throw CameraRollSaveError.unavailable
    }
}
#endif

private enum CameraRollSaveError: LocalizedError {
    case accessDenied
    case accessRestricted
    case saveFailed
    case missingCaptureData
    case unavailable

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            "Photos access denied. Enable Photos access in Settings to save captures."
        case .accessRestricted:
            "Photos access is restricted by system policy."
        case .saveFailed:
            "Could not save the photo to Photos."
        case .missingCaptureData:
            "Capture data was incomplete. Try capturing again."
        case .unavailable:
            "Saving to Photos is unavailable on this device."
        }
    }
}
