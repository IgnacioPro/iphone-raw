import CaptureUI
import SwiftUI
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @ObservedObject var bootstrap: BootstrapViewModel

    var body: some View {
        VStack(spacing: 16) {
            CaptureStatusView(state: bootstrap.state)

            if case .ready = bootstrap.state,
               let previewSession = bootstrap.previewSession {
                CameraPreviewView(session: previewSession)
                    .frame(maxWidth: .infinity)
                    .frame(height: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Button(buttonTitle) {
                Task {
                    await bootstrap.start()
                }
            }
            .buttonStyle(.borderedProminent)

            #if targetEnvironment(simulator)
                Text("The iOS simulator has no real camera input. Run Photodew on a physical iPhone to test capture.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            #endif

            Text("This wrapper app boots the package camera stack.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .padding(24)
        .onDisappear {
            bootstrap.stop()
        }
    }

    private var buttonTitle: String {
        switch bootstrap.state {
        case .requestingPermission:
            return "Launching..."
        default:
            return "Launch Camera"
        }
    }
}

#if canImport(UIKit) && canImport(AVFoundation)
private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: PreviewContainerView, context: Context) {
        uiView.previewLayer.session = session
    }
}

private final class PreviewContainerView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("PreviewContainerView must use AVCaptureVideoPreviewLayer.")
        }
        return layer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        previewLayer.videoGravity = .resizeAspectFill
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
#endif
