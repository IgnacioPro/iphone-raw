import CaptureUI
import Foundation
import SwiftUI
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var bootstrap: BootstrapViewModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if case .ready = bootstrap.state,
               let previewSession = bootstrap.previewSession {
                CameraPreviewView(session: previewSession)
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 14) {
                    CaptureStatusView(state: bootstrap.state)
                        .frame(maxWidth: .infinity, alignment: .leading)

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
                }
                .padding(.horizontal, 20)
            }
        }
        .overlay(alignment: .top) {
            if let saveToast = bootstrap.saveToast {
                Text(saveToast.message)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.black.opacity(0.75), in: Capsule())
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: bootstrap.saveToast)
        .safeAreaInset(edge: .top) {
            if case .ready = bootstrap.state {
                HStack {
                    CaptureStatusView(state: bootstrap.state)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .background(.ultraThinMaterial.opacity(0.8))
            }
        }
        .safeAreaInset(edge: .bottom) {
            if case .ready = bootstrap.state {
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        Button("Switch Camera") {
                            bootstrap.switchCamera()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)

                        Button(bootstrap.isCapturingPhoto ? "Capturing..." : "Shutter") {
                            Task {
                                await bootstrap.capturePhoto()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(bootstrap.isCapturingPhoto)
                        .frame(maxWidth: .infinity)
                    }

                    if let lastCaptureByteCount = bootstrap.lastCaptureByteCount {
                        Text("Last capture: \(formattedByteCount(lastCaptureByteCount))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let lastCaptureAt = bootstrap.lastCaptureAt {
                        Text("Captured at \(lastCaptureAt.formatted(date: .omitted, time: .shortened))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Text(rawCapabilityHeadline)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(bootstrap.rawCaptureCapability.isSupported ? .green : .yellow)

                    if let rawCapabilityReason = rawCapabilityReason {
                        Text(rawCapabilityReason)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if let lastCaptureError = bootstrap.lastCaptureError {
                        Text("Capture error: \(lastCaptureError)")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial.opacity(0.85))
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                bootstrap.resumeSessionIfNeeded()
            case .background:
                bootstrap.stop()
            case .inactive:
                break
            @unknown default:
                break
            }
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

    private func formattedByteCount(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private var rawCapabilityHeadline: String {
        let formatCount = bootstrap.rawCaptureCapability.availableRawPhotoPixelFormatTypes.count
        if bootstrap.rawCaptureCapability.isSupported {
            return "RAW: Supported (\(formatCount) format\(formatCount == 1 ? "" : "s"))"
        }

        return "RAW: Unavailable"
    }

    private var rawCapabilityReason: String? {
        guard !bootstrap.rawCaptureCapability.isSupported else { return nil }
        return bootstrap.rawCaptureCapability.reason
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
