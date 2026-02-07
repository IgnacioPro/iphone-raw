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

@MainActor
final class BootstrapViewModel: ObservableObject {
    @Published private(set) var state: AppBootState = .idle
    @Published private(set) var isCapturingPhoto = false
    @Published private(set) var lastCaptureByteCount: Int?
    @Published private(set) var lastCaptureAt: Date?
    @Published private(set) var lastCaptureError: String?
    @Published private(set) var lastSaveStatusMessage: String?

    private let model: CaptureAppModel
    private let cameraRollSaver: CameraRollSaving
    private var activeCaptureID: UUID?

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
        return
        #else
        await model.bootstrap()
        state = model.bootState
        #endif
    }

    func stop() {
        model.stopSession()
    }

    func resumeSessionIfNeeded() {
        model.resumeSessionIfNeeded()
        state = model.bootState
    }

    func capturePhoto() async {
        guard case .ready = state else { return }
        guard !isCapturingPhoto else { return }

        let captureID = UUID()
        activeCaptureID = captureID
        isCapturingPhoto = true
        lastCaptureError = nil
        lastSaveStatusMessage = nil

        startCaptureWatchdog(for: captureID)

        do {
            let data = try await model.capturePhotoData()
            try await cameraRollSaver.savePhotoData(data)
            guard activeCaptureID == captureID else { return }
            lastCaptureByteCount = data.count
            lastCaptureAt = Date()
            lastCaptureError = nil
            lastSaveStatusMessage = "Saved to Photos."
            activeCaptureID = nil
            isCapturingPhoto = false
        } catch {
            guard activeCaptureID == captureID else { return }
            activeCaptureID = nil
            isCapturingPhoto = false
            lastCaptureError = captureErrorMessage(from: error)
            lastSaveStatusMessage = nil
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
    }

    private func startCaptureWatchdog(for captureID: UUID) {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard let self else { return }
            guard self.activeCaptureID == captureID else { return }

            self.activeCaptureID = nil
            self.isCapturingPhoto = false
            self.lastCaptureError = "Capture timed out. Restarting camera session."
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
}

protocol CameraRollSaving: Sendable {
    func savePhotoData(_ data: Data) async throws
}

#if canImport(Photos)
private struct SystemCameraRollSaver: CameraRollSaving {
    func savePhotoData(_ data: Data) async throws {
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

        do {
            try await PHPhotoLibrary.shared().performChanges { [data] in
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
            }
        } catch {
            throw CameraRollSaveError.saveFailed
        }
    }

    private func authorizationStatus() async -> PHAuthorizationStatus {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard currentStatus == .notDetermined else { return currentStatus }
        return await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    }
}
#else
private struct SystemCameraRollSaver: CameraRollSaving {
    func savePhotoData(_ data: Data) async throws {
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
