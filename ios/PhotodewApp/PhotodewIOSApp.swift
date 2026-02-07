import App
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

    private let model: CaptureAppModel

    init(model: CaptureAppModel = AppCompositionRoot().makeAppModel()) {
        self.model = model
    }

    func start() async {
        #if targetEnvironment(simulator)
        state = .blocked(reason: "Simulator has no real camera input. Use a physical iPhone for camera testing.")
        return
        #endif

        await model.bootstrap()
        state = model.bootState
    }

    func stop() {
        model.stopSession()
    }

    #if canImport(AVFoundation)
    var previewSession: AVCaptureSession? {
        model.previewSession
    }
    #endif
}
