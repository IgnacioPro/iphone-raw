import App
import CameraKit
import Foundation
import SwiftUI
#if canImport(AVFoundation)
import AVFoundation
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

    private let model: CaptureAppModel
    private var activeCaptureID: UUID?

    init(model: CaptureAppModel = AppCompositionRoot().makeAppModel()) {
        self.model = model
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

        startCaptureWatchdog(for: captureID)

        do {
            let data = try await model.capturePhotoData()
            guard activeCaptureID == captureID else { return }
            lastCaptureByteCount = data.count
            lastCaptureAt = Date()
            lastCaptureError = nil
            activeCaptureID = nil
            isCapturingPhoto = false
        } catch {
            guard activeCaptureID == captureID else { return }
            activeCaptureID = nil
            isCapturingPhoto = false
            lastCaptureError = error.localizedDescription
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
}
