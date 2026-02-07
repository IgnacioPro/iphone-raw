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
            let data = try await model.capturePhotoData()
            setSaveToast(.saving)
            let saveResult = try await cameraRollSaver.savePhotoData(data)
            guard activeCaptureID == captureID else { return }
            let capturedAt = Date()
            lastCaptureByteCount = data.count
            lastCaptureAt = capturedAt
            lastCaptureError = nil
            await model.persistPhotoLibraryCapture(
                localIdentifier: saveResult.localIdentifier,
                capturedAt: capturedAt,
                lensPosition: lensPosition,
                byteCount: data.count
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
            return
        }
        rawCaptureCapability = model.rawCaptureCapability()
    }
}

protocol CameraRollSaving: Sendable {
    func savePhotoData(_ data: Data) async throws -> CameraRollSaveResult
}

struct CameraRollSaveResult: Sendable, Equatable {
    let localIdentifier: String
}

#if canImport(Photos)
private struct SystemCameraRollSaver: CameraRollSaving {
    func savePhotoData(_ data: Data) async throws -> CameraRollSaveResult {
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

        var localIdentifier: String?
        do {
            try await PHPhotoLibrary.shared().performChanges { [data] in
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
                localIdentifier = request.placeholderForCreatedAsset?.localIdentifier
            }
        } catch {
            throw CameraRollSaveError.saveFailed
        }

        guard let localIdentifier else {
            throw CameraRollSaveError.saveFailed
        }

        return CameraRollSaveResult(localIdentifier: localIdentifier)
    }

    private func authorizationStatus() async -> PHAuthorizationStatus {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard currentStatus == .notDetermined else { return currentStatus }
        return await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    }
}
#else
private struct SystemCameraRollSaver: CameraRollSaving {
    func savePhotoData(_ data: Data) async throws -> CameraRollSaveResult {
        throw CameraRollSaveError.unavailable
    }
}
#endif

private enum CameraRollSaveError: LocalizedError {
    case accessDenied
    case accessRestricted
    case saveFailed
    case unavailable

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            "Photos access denied. Enable Photos access in Settings to save captures."
        case .accessRestricted:
            "Photos access is restricted by system policy."
        case .saveFailed:
            "Could not save the photo to Photos."
        case .unavailable:
            "Saving to Photos is unavailable on this device."
        }
    }
}
