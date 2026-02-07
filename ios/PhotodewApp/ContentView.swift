import CaptureUI
import CameraKit
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
                if bootstrap.isZebraOverlayEnabled,
                   let zebraClippingOverlay = bootstrap.zebraClippingOverlay {
                    ZebraClippingOverlayView(overlay: zebraClippingOverlay)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
                if bootstrap.isFocusPeakingEnabled,
                   let focusPeakingOverlay = bootstrap.focusPeakingOverlay {
                    FocusPeakingOverlayView(overlay: focusPeakingOverlay)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
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
                    if let horizonRollDegrees = bootstrap.horizonRollDegrees {
                        HorizonLevelIndicatorView(
                            rollDegrees: horizonRollDegrees,
                            levelToleranceDegrees: BootstrapViewModel.horizonLevelToleranceDegrees
                        )
                        .frame(width: 96, height: 48)
                    }
                    if let luminanceHistogram = bootstrap.luminanceHistogram {
                        LuminanceHistogramOverlayView(histogram: luminanceHistogram)
                            .frame(width: 156, height: 62)
                    }
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
                        modeSelectionButton(
                            title: "Processed",
                            format: .processed,
                            tint: .blue
                        )
                        modeSelectionButton(
                            title: "True RAW",
                            format: .raw,
                            tint: .green
                        )
                        modeSelectionButton(
                            title: "Apple ProRAW",
                            format: .appleProRAW,
                            tint: .orange
                        )
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
                            Text("Zebra Clipping")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white)

                            Text(zebraStatusLine)
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Slider(
                                    value: $bootstrap.selectedZebraThreshold,
                                    in: BootstrapViewModel.zebraThresholdRange,
                                    step: 0.01
                                )
                                Text("Threshold: \(formattedZebraThreshold(bootstrap.selectedZebraThreshold))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 10) {
                                Button(bootstrap.isZebraOverlayEnabled ? "Disable Zebra" : "Enable Zebra") {
                                    bootstrap.toggleZebraOverlay()
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)

                                Button("Apply Threshold") {
                                    bootstrap.applyZebraThresholdSelection()
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .disabled(bootstrap.isCapturingPhoto || bootstrap.isRecoveringSession)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Focus Peaking")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white)

                            Text(focusPeakingStatusLine)
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Slider(
                                    value: $bootstrap.selectedFocusPeakingThreshold,
                                    in: BootstrapViewModel.focusPeakingThresholdRange,
                                    step: 0.01
                                )
                                Text("Threshold: \(formattedFocusPeakingThreshold(bootstrap.selectedFocusPeakingThreshold))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 10) {
                                Button(bootstrap.isFocusPeakingEnabled ? "Disable Peaking" : "Enable Peaking") {
                                    bootstrap.toggleFocusPeakingOverlay()
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)

                                Button("Apply Threshold") {
                                    bootstrap.applyFocusPeakingThresholdSelection()
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .disabled(bootstrap.isCapturingPhoto || bootstrap.isRecoveringSession)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Horizon Level")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white)

                            Text(horizonStatusLine)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
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

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Control Presets")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white)

                            Picker("Preset Slot", selection: $bootstrap.selectedPresetSlot) {
                                ForEach(BootstrapViewModel.presetSlots, id: \.self) { slot in
                                    Text(slot.displayName).tag(slot)
                                }
                            }
                            .pickerStyle(.segmented)

                            Text(presetStatusLine)
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 10) {
                                Button("Save Preset") {
                                    bootstrap.savePresetSelection()
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)

                                Button("Apply Preset") {
                                    bootstrap.applyPresetSelection()
                                }
                                .buttonStyle(.bordered)
                                .disabled(!bootstrap.savedPresetSlots.contains(bootstrap.selectedPresetSlot))
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .disabled(bootstrap.isCapturingPhoto || bootstrap.isRecoveringSession)

                        Text("Mode: \(captureFormatTitle(bootstrap.selectedCaptureFormat))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Mode Guide")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white)

                            Text(modeGuidePrimaryLine)
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Text("Apple ProRAW is partially processed computational RAW and remains scene-referred, but it is not sensor Bayer RAW.")
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

                    Text(appleProRAWCapabilityHeadline)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(bootstrap.rawCaptureCapability.isAppleProRAWSupported ? .green : .yellow)

                    if let appleProRAWCapabilityReason = appleProRAWCapabilityReason {
                        Text(appleProRAWCapabilityReason)
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
        .onChange(of: bootstrap.selectedPresetSlot) { _, _ in
            bootstrap.refreshSelectedPresetSlot()
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

    @ViewBuilder
    private func modeSelectionButton(
        title: String,
        format: CapturePhotoFormat,
        tint: Color
    ) -> some View {
        let isSelected = bootstrap.selectedCaptureFormat == format
        let isSupported = isCaptureFormatSupported(format)
        Button(title) {
            bootstrap.selectCaptureFormat(format)
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? tint : nil)
        .opacity(isSupported || format == .processed ? 1.0 : 0.7)
        .disabled(bootstrap.isCapturingPhoto || bootstrap.isRecoveringSession)
        .frame(maxWidth: .infinity)
    }

    private func captureFormatTitle(_ format: CapturePhotoFormat) -> String {
        switch format {
        case .processed:
            return "Processed"
        case .raw:
            return "True RAW (DNG)"
        case .appleProRAW:
            return "Apple ProRAW (DNG)"
        }
    }

    private func isCaptureFormatSupported(_ format: CapturePhotoFormat) -> Bool {
        switch format {
        case .processed:
            return true
        case .raw:
            return bootstrap.rawCaptureCapability.isSupported
        case .appleProRAW:
            return bootstrap.rawCaptureCapability.isAppleProRAWSupported
        }
    }

    private var rawCapabilityHeadline: String {
        let formatCount = bootstrap.rawCaptureCapability.availableRawPhotoPixelFormatTypes.count
        if bootstrap.rawCaptureCapability.isSupported {
            return "True RAW: Supported (\(formatCount) format\(formatCount == 1 ? "" : "s"))"
        }

        return "True RAW: Unavailable"
    }

    private var rawCapabilityReason: String? {
        guard !bootstrap.rawCaptureCapability.isSupported else { return nil }
        return bootstrap.rawCaptureCapability.reason
    }

    private var appleProRAWCapabilityHeadline: String {
        let formatCount = bootstrap.rawCaptureCapability.availableAppleProRAWPhotoPixelFormatTypes.count
        if bootstrap.rawCaptureCapability.isAppleProRAWSupported {
            return "Apple ProRAW: Supported (\(formatCount) format\(formatCount == 1 ? "" : "s"))"
        }

        return "Apple ProRAW: Unavailable"
    }

    private var appleProRAWCapabilityReason: String? {
        guard !bootstrap.rawCaptureCapability.isAppleProRAWSupported else { return nil }
        return bootstrap.rawCaptureCapability.appleProRAWReason
    }

    private var modeGuidePrimaryLine: String {
        switch bootstrap.selectedCaptureFormat {
        case .processed:
            return "Current mode: Processed capture for convenience and speed."
        case .raw:
            return "True RAW (DNG): minimal processing capture path for maximum edit latitude."
        case .appleProRAW:
            return "Apple ProRAW (DNG): partially processed computational RAW for higher convenience."
        }
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

    private func formattedZebraThreshold(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func formattedFocusPeakingThreshold(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private var zebraStatusLine: String {
        let stateDescription = bootstrap.isZebraOverlayEnabled ? "Enabled" : "Disabled"
        if let zebraClippingOverlay = bootstrap.zebraClippingOverlay {
            let clippedPercent = Int((zebraClippingOverlay.clippedRatio * 100).rounded())
            return "\(stateDescription) · clipped area \(clippedPercent)%"
        }
        return "\(stateDescription) · threshold \(formattedZebraThreshold(bootstrap.selectedZebraThreshold))"
    }

    private var focusPeakingStatusLine: String {
        let stateDescription = bootstrap.isFocusPeakingEnabled ? "Enabled" : "Disabled"
        if let focusPeakingOverlay = bootstrap.focusPeakingOverlay {
            let peakedPercent = Int((focusPeakingOverlay.peakedRatio * 100).rounded())
            return "\(stateDescription) · peaked area \(peakedPercent)%"
        }
        return "\(stateDescription) · threshold \(formattedFocusPeakingThreshold(bootstrap.selectedFocusPeakingThreshold))"
    }

    private var horizonStatusLine: String {
        if let horizonStatusMessage = bootstrap.horizonStatusMessage {
            return horizonStatusMessage
        }
        guard let horizonRollDegrees = bootstrap.horizonRollDegrees else {
            return "Waiting for device motion..."
        }
        let isLevel = abs(horizonRollDegrees) <= BootstrapViewModel.horizonLevelToleranceDegrees
        let stateDescription = isLevel ? "Level" : "Tilted"
        return "\(stateDescription) · roll \(formattedHorizonDegrees(horizonRollDegrees))"
    }

    private func formattedHorizonDegrees(_ degrees: Double) -> String {
        String(format: "%+.1f°", degrees)
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

    private var presetStatusLine: String {
        if let savedAt = bootstrap.selectedPresetSavedAt {
            return "\(bootstrap.selectedPresetSlot.displayName) saved \(savedAt.formatted(date: .abbreviated, time: .shortened))."
        }
        return "\(bootstrap.selectedPresetSlot.displayName) is empty."
    }
}

private struct HorizonLevelIndicatorView: View {
    let rollDegrees: Double
    let levelToleranceDegrees: Double

    var body: some View {
        let clampedRollDegrees = min(max(rollDegrees, -45), 45)
        let isLevel = abs(rollDegrees) <= levelToleranceDegrees
        let indicatorColor: Color = isLevel ? .green : .yellow

        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.black.opacity(0.58))
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)

            Capsule()
                .fill(.white.opacity(0.2))
                .frame(width: 66, height: 2)

            Capsule()
                .fill(indicatorColor.opacity(0.92))
                .frame(width: 66, height: 3)
                .rotationEffect(.degrees(-clampedRollDegrees))

            Circle()
                .fill(.white.opacity(0.85))
                .frame(width: 6, height: 6)
        }
        .overlay(alignment: .bottom) {
            Text(String(format: "%+.1f°", rollDegrees))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(indicatorColor.opacity(0.95))
                .padding(.bottom, 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Horizon level indicator")
        .accessibilityValue("\(Int(rollDegrees.rounded())) degrees")
    }
}

private struct LuminanceHistogramOverlayView: View {
    let histogram: LuminanceHistogram

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Histogram")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))

            GeometryReader { geometry in
                let normalizedBins = histogram.normalizedBins
                Canvas { context, size in
                    guard !normalizedBins.isEmpty else { return }
                    let barWidth = size.width / CGFloat(normalizedBins.count)
                    for (index, normalizedValue) in normalizedBins.enumerated() {
                        let clampedValue = min(max(normalizedValue, 0), 1)
                        let barHeight = max(size.height * clampedValue, 1)
                        let x = CGFloat(index) * barWidth
                        let barRect = CGRect(
                            x: x,
                            y: size.height - barHeight,
                            width: max(barWidth - 1, 0.5),
                            height: barHeight
                        )
                        context.fill(Path(barRect), with: .color(.white.opacity(0.9)))
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Luminance histogram")
    }
}

private struct ZebraClippingOverlayView: View {
    let overlay: ZebraClippingOverlay
    private let stripeSpacing: CGFloat = 14
    private let stripeLineWidth: CGFloat = 1.4

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                guard overlay.columnCount > 0, overlay.rowCount > 0 else { return }
                let cellWidth = size.width / CGFloat(overlay.columnCount)
                let cellHeight = size.height / CGFloat(overlay.rowCount)
                var clippedArea = Path()
                for row in 0..<overlay.rowCount {
                    for column in 0..<overlay.columnCount {
                        guard overlay.isCellClipped(column: column, row: row) else { continue }
                        let rect = CGRect(
                            x: CGFloat(column) * cellWidth,
                            y: CGFloat(row) * cellHeight,
                            width: cellWidth,
                            height: cellHeight
                        )
                        clippedArea.addRect(rect)
                    }
                }
                guard !clippedArea.isEmpty else { return }
                context.fill(clippedArea, with: .color(.black.opacity(0.15)))
                context.clip(to: clippedArea)

                var stripePath = Path()
                for startX in stride(from: -size.height, through: size.width + size.height, by: stripeSpacing) {
                    stripePath.move(to: CGPoint(x: startX, y: 0))
                    stripePath.addLine(to: CGPoint(x: startX + size.height, y: size.height))
                }
                context.stroke(stripePath, with: .color(.white.opacity(0.7)), lineWidth: stripeLineWidth)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Zebra clipping overlay")
    }
}

private struct FocusPeakingOverlayView: View {
    let overlay: FocusPeakingOverlay

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                guard overlay.columnCount > 0, overlay.rowCount > 0 else { return }
                let cellWidth = size.width / CGFloat(overlay.columnCount)
                let cellHeight = size.height / CGFloat(overlay.rowCount)

                var peakedArea = Path()
                for row in 0..<overlay.rowCount {
                    for column in 0..<overlay.columnCount {
                        guard overlay.isCellPeaked(column: column, row: row) else { continue }
                        let rect = CGRect(
                            x: CGFloat(column) * cellWidth,
                            y: CGFloat(row) * cellHeight,
                            width: cellWidth,
                            height: cellHeight
                        )
                        peakedArea.addRect(rect)
                    }
                }
                guard !peakedArea.isEmpty else { return }
                context.fill(peakedArea, with: .color(.green.opacity(0.2)))

                var highlightPath = Path()
                for row in 0..<overlay.rowCount {
                    for column in 0..<overlay.columnCount {
                        guard overlay.isCellPeaked(column: column, row: row) else { continue }
                        let insetRect = CGRect(
                            x: CGFloat(column) * cellWidth + 0.5,
                            y: CGFloat(row) * cellHeight + 0.5,
                            width: max(cellWidth - 1, 0.5),
                            height: max(cellHeight - 1, 0.5)
                        )
                        highlightPath.addRect(insetRect)
                    }
                }
                context.stroke(highlightPath, with: .color(.green.opacity(0.75)), lineWidth: 1)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Focus peaking overlay")
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
