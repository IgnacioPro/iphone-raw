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

    public private(set) var bootState: AppBootState = .idle

    public init(
        permissionGate: CameraPermissionGate,
        sessionService: CaptureSessionServing,
        metadataStore: CaptureMetadataStoring,
        logger: CaptureEventLogging? = nil
    ) {
        self.permissionGate = permissionGate
        self.sessionService = sessionService
        self.metadataStore = metadataStore
        self.logger = logger
    }

    public func bootstrap() async {
        bootState = .requestingPermission

        let access = await permissionGate.ensureAccess()
        switch access {
        case .granted:
            do {
                try sessionService.start()
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

    public func stopSession() {
        sessionService.stop()
    }

    public func resumeSessionIfNeeded() {
        guard case .ready = bootState else { return }

        do {
            try sessionService.start()
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

    public func switchCamera() throws {
        try sessionService.switchCamera()
    }

    public func capturePhotoData() async throws -> Data {
        try await sessionService.capturePhoto()
    }

    #if canImport(AVFoundation)
    public var previewSession: AVCaptureSession? {
        sessionService.previewSession
    }
    #endif

    public func saveArtifact(_ artifact: CaptureArtifact) async {
        await metadataStore.save(artifact)
    }
}

extension CaptureAppModel: @unchecked Sendable {}
