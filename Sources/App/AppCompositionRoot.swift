import CameraKit
import Foundation
import Storage

public struct AppCompositionRoot {
    public let logger: CaptureEventLogging
    public let metadataStore: CaptureMetadataStoring
    public let sessionService: CaptureSessionServing
    public let permissionGate: CameraPermissionGate

    public init() {
        let logger = StructuredCaptureLogger()
        self.logger = logger
        self.metadataStore = InMemoryCaptureMetadataStore()
        self.sessionService = CaptureSessionService(
            backend: AVCaptureSessionBackend(),
            logger: logger
        )
        self.permissionGate = CameraPermissionGate(
            client: AVCameraPermissionClient(),
            logger: logger
        )
    }

    public func makeAppModel() -> CaptureAppModel {
        CaptureAppModel(
            permissionGate: permissionGate,
            sessionService: sessionService,
            metadataStore: metadataStore,
            logger: logger
        )
    }
}
