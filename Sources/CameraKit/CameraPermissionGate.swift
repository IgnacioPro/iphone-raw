import Foundation

#if canImport(AVFoundation)
import AVFoundation
#endif

public enum CameraAuthorizationStatus: Equatable {
    case notDetermined
    case restricted
    case denied
    case authorized
}

public enum CameraPermissionGateResult: Equatable {
    case granted
    case denied
    case restricted
}

public protocol CameraPermissionClient {
    func authorizationStatus() -> CameraAuthorizationStatus
    func requestAccess() async -> Bool
}

public struct CameraPermissionGate {
    private let client: CameraPermissionClient
    private let logger: CaptureEventLogging?

    public init(
        client: CameraPermissionClient = AVCameraPermissionClient(),
        logger: CaptureEventLogging? = nil
    ) {
        self.client = client
        self.logger = logger
    }

    public func ensureAccess() async -> CameraPermissionGateResult {
        switch client.authorizationStatus() {
        case .authorized:
            logger?.log(
                CaptureEvent(
                    category: .permission,
                    action: "camera_access_granted_existing"
                )
            )
            return .granted
        case .restricted:
            logger?.log(
                CaptureEvent(
                    category: .permission,
                    action: "camera_access_restricted"
                )
            )
            return .restricted
        case .denied:
            logger?.log(
                CaptureEvent(
                    category: .permission,
                    action: "camera_access_denied_existing"
                )
            )
            return .denied
        case .notDetermined:
            let granted = await client.requestAccess()
            logger?.log(
                CaptureEvent(
                    category: .permission,
                    action: granted ? "camera_access_granted_requested" : "camera_access_denied_requested"
                )
            )
            return granted ? .granted : .denied
        }
    }
}

public struct AVCameraPermissionClient: CameraPermissionClient {
    public init() {}

    public func authorizationStatus() -> CameraAuthorizationStatus {
        #if canImport(AVFoundation)
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .authorized
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        @unknown default:
            return .restricted
        }
        #else
        return .restricted
        #endif
    }

    public func requestAccess() async -> Bool {
        #if canImport(AVFoundation)
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
        #else
        return false
        #endif
    }
}
