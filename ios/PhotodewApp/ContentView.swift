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
    @State private var areAdvancedControlsExpanded = false

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
                        .disabled(bootstrap.isRecoveringSession || bootstrap.isCapturingPhoto)
                        .frame(maxWidth: .infinity)

                        Button(shutterButtonTitle) {
                            Task {
                                await bootstrap.capturePhoto()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(bootstrap.isCapturingPhoto || bootstrap.isRecoveringSession)
                        .frame(maxWidth: .infinity)
                    }

                    HStack(spacing: 12) {
                        Button(bootstrap.isRawCaptureEnabled ? "RAW Capture: On" : "RAW Capture: Off") {
                            bootstrap.toggleRawCaptureMode()
                        }
                        .buttonStyle(.bordered)
                        .tint(bootstrap.isRawCaptureEnabled ? .green : nil)
                        .disabled(!bootstrap.rawCaptureCapability.isSupported || bootstrap.isCapturingPhoto || bootstrap.isRecoveringSession)
                        .frame(maxWidth: .infinity)
                    }

                    Button(areAdvancedControlsExpanded ? "Hide Controls" : "Show Controls") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            areAdvancedControlsExpanded.toggle()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(bootstrap.isCapturingPhoto || bootstrap.isRecoveringSession)
                    .frame(maxWidth: .infinity)

                    if areAdvancedControlsExpanded {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Exposure Controls")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white)

                            Text(exposureModeLine)
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Text("EV compensation: \(formattedExposureCompensation(bootstrap.exposureCompensation))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 10) {
                                Picker("ISO", selection: $bootstrap.selectedExposureISO) {
                                    ForEach(BootstrapViewModel.manualISOOptions, id: \.self) { iso in
                                        Text("ISO \(Int(iso))").tag(iso)
                                    }
                                }
                                .pickerStyle(.menu)

                                Picker("Shutter", selection: $bootstrap.selectedExposureShutterSeconds) {
                                    ForEach(BootstrapViewModel.manualShutterOptions, id: \.self) { shutterSeconds in
                                        Text(formattedShutter(shutterSeconds)).tag(shutterSeconds)
                                    }
                                }
                                .pickerStyle(.menu)
                            }

                            HStack(spacing: 10) {
                                Button("Auto") {
                                    bootstrap.applyExposureAuto()
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)

                                Button("Apply ISO/Shutter") {
                                    bootstrap.applyCustomExposureSelection()
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Slider(
                                    value: $bootstrap.selectedExposureCompensation,
                                    in: bootstrap.exposureCompensationRange,
                                    step: 0.1
                                )
                                Text("Selected EV: \(formattedExposureCompensation(bootstrap.selectedExposureCompensation))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 10) {
                                Button("Reset EV") {
                                    bootstrap.resetExposureCompensation()
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)

                                Button("Apply EV") {
                                    bootstrap.applyExposureCompensationSelection()
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .disabled(bootstrap.isCapturingPhoto || bootstrap.isRecoveringSession)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Focus Controls")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white)

                            Text(focusModeLine)
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Slider(
                                    value: $bootstrap.selectedFocusLensPosition,
                                    in: 0...1,
                                    step: 0.02
                                )
                                Text("Selected: \(formattedFocusPosition(bootstrap.selectedFocusLensPosition))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 10) {
                                Button("Auto Focus") {
                                    bootstrap.applyFocusAuto()
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)

                                Button("Lock Focus") {
                                    bootstrap.applyFocusLockSelection()
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .disabled(bootstrap.isCapturingPhoto || bootstrap.isRecoveringSession)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("White Balance Controls")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white)

                            Text(whiteBalanceModeLine)
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Slider(
                                    value: $bootstrap.selectedWhiteBalanceTemperatureKelvin,
                                    in: BootstrapViewModel.manualWhiteBalanceTemperatureRange,
                                    step: 50
                                )
                                Text("Temperature: \(formattedWhiteBalanceTemperature(bootstrap.selectedWhiteBalanceTemperatureKelvin))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Slider(
                                    value: $bootstrap.selectedWhiteBalanceTint,
                                    in: BootstrapViewModel.manualWhiteBalanceTintRange,
                                    step: 1
                                )
                                Text("Tint: \(formattedWhiteBalanceTint(bootstrap.selectedWhiteBalanceTint))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 10) {
                                Button("Auto WB") {
                                    bootstrap.applyWhiteBalanceAuto()
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)

                                Button("Lock WB") {
                                    bootstrap.applyWhiteBalanceLockSelection()
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .disabled(bootstrap.isCapturingPhoto || bootstrap.isRecoveringSession)

                        Text("Mode: \(bootstrap.isRawCaptureEnabled ? "RAW (DNG)" : "Processed")")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Mode Guide")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white)

                            Text(modeGuidePrimaryLine)
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Text("Apple ProRAW is partially processed computational RAW and is not yet available in Photodew.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Text("Processed mode is faster and smaller for sharing. True RAW (DNG) is larger and best for heavy edits.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
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

                    if let storagePressureWarning = bootstrap.storagePressureWarning {
                        Text(storagePressureWarning)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.yellow)
                            .multilineTextAlignment(.center)
                    }

                    if bootstrap.storagePressureWarning != nil,
                       (bootstrap.canCleanupRecentCapture || bootstrap.isCleaningRecentCapture) {
                        Button(bootstrap.isCleaningRecentCapture ? "Cleaning..." : "Clean Last Capture") {
                            Task {
                                await bootstrap.cleanupRecentCapture()
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(bootstrap.isCleaningRecentCapture || bootstrap.isCapturingPhoto)
                        .frame(maxWidth: .infinity)
                    }

                    if let lastCaptureError = bootstrap.lastCaptureError {
                        Text("Capture error: \(lastCaptureError)")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)

                        Button(bootstrap.isRecoveringSession ? "Recovering..." : "Retry Camera Session") {
                            Task {
                                await bootstrap.retrySessionRecovery()
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(bootstrap.isRecoveringSession || bootstrap.isCapturingPhoto)
                        .frame(maxWidth: .infinity)
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

    private var shutterButtonTitle: String {
        if bootstrap.isCapturingPhoto {
            return "Capturing..."
        }
        if bootstrap.isRecoveringSession {
            return "Recovering..."
        }
        return "Shutter"
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

    private var modeGuidePrimaryLine: String {
        if bootstrap.isRawCaptureEnabled {
            return "True RAW (DNG): minimal processing capture path for maximum edit latitude."
        }

        return "Current mode: Processed capture for convenience and speed."
    }

    private var exposureModeLine: String {
        switch bootstrap.exposureState {
        case .auto:
            return "Exposure mode: Auto"
        case let .locked(values):
            return "Exposure mode: Locked (ISO \(Int(values.iso)), \(formattedShutter(values.shutterSeconds)))"
        case let .custom(values):
            return "Exposure mode: Custom (ISO \(Int(values.iso)), \(formattedShutter(values.shutterSeconds)))"
        }
    }

    private func formattedShutter(_ shutterSeconds: Double) -> String {
        guard shutterSeconds > 0 else { return "0s" }
        if shutterSeconds >= 1 {
            return String(format: "%.1fs", shutterSeconds)
        }
        let denominator = Int((1.0 / shutterSeconds).rounded())
        return "1/\(max(1, denominator))s"
    }

    private func formattedExposureCompensation(_ value: Double) -> String {
        if abs(value) < 0.000_1 {
            return "0.0 EV"
        }
        return String(format: "%+.1f EV", value)
    }

    private var focusModeLine: String {
        switch bootstrap.focusState {
        case .auto:
            return "Focus mode: Auto"
        case let .locked(lensPosition):
            return "Focus mode: Locked (\(formattedFocusPosition(lensPosition)))"
        }
    }

    private func formattedFocusPosition(_ lensPosition: Double) -> String {
        let percentage = Int((min(max(lensPosition, 0), 1) * 100).rounded())
        return "\(percentage)%"
    }

    private var whiteBalanceModeLine: String {
        switch bootstrap.whiteBalanceState {
        case .auto:
            return "White balance mode: Auto"
        case let .locked(values):
            return "White balance mode: Locked (\(formattedWhiteBalanceTemperature(values.temperatureKelvin)), \(formattedWhiteBalanceTint(values.tint)))"
        }
    }

    private func formattedWhiteBalanceTemperature(_ temperatureKelvin: Double) -> String {
        let rounded = Int(temperatureKelvin.rounded())
        return "\(rounded)K"
    }

    private func formattedWhiteBalanceTint(_ tint: Double) -> String {
        let rounded = Int(tint.rounded())
        if rounded > 0 {
            return "+\(rounded)"
        }
        return "\(rounded)"
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
