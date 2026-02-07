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

// MARK: - Design Tokens

private enum CaptureDesignTokens {
    static let chromeInset: CGFloat = 12
    static let controlGap: CGFloat = 10
    static let sectionGap: CGFloat = 12
    static let controlRadius: CGFloat = 12
    static let panelRadius: CGFloat = 16
    static let minimumTouchTarget: CGFloat = 44
    static let shutterButtonOuterSize: CGFloat = 72
    static let shutterButtonInnerSize: CGFloat = 58
    static let histogramWidth: CGFloat = 80
    static let histogramHeight: CGFloat = 32
    static let proControlsPanelMaxHeight: CGFloat = 340
    static let accentColor = Color(red: 0.93, green: 0.88, blue: 0.24)
}

// MARK: - Haptics

#if canImport(UIKit)
@MainActor
private func hapticLight() {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
}

@MainActor
private func hapticMedium() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
}

@MainActor
private func hapticRigid() {
    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
}
#endif

// MARK: - ContentView

@MainActor
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var bootstrap: BootstrapViewModel

    @State private var isProControlsPresented = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            #if canImport(AVFoundation)
            if case .ready = bootstrap.state,
               let previewSession = bootstrap.previewSession {
                readyCameraSurface(session: previewSession)
            } else {
                launchSurface
            }
            #else
            launchSurface
            #endif
        }
        .overlay(alignment: .top) {
            if let saveToast = bootstrap.saveToast {
                Text(saveToast.message)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, CaptureDesignTokens.chromeInset)
                    .padding(.vertical, 9)
                    .background(.black.opacity(0.78), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.15), lineWidth: 1)
                    )
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: bootstrap.saveToast)
        .statusBarHidden(true)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                Task { await bootstrap.resumeSessionIfNeeded() }
            case .background:
                Task { await bootstrap.stop() }
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

    // MARK: - Launch Surface

    private var launchSurface: some View {
        VStack(spacing: 16) {
            CaptureStatusView(state: bootstrap.state)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(buttonTitle) {
                Task { @MainActor in
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

    // MARK: - Ready Camera Surface

    #if canImport(AVFoundation)
    private func readyCameraSurface(session: AVCaptureSession) -> some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let viewfinderHeight = screenWidth * 4.0 / 3.0  // 4:3 aspect ratio

            VStack(spacing: 0) {
                // Top bar — HUD + utility toggles on solid black
                topCameraChrome

                // 4:3 viewfinder — fixed aspect ratio, full width
                ZStack {
                    CameraPreviewView(session: session)

                    // Assist overlays
                    if bootstrap.isZebraOverlayEnabled,
                       let zebraClippingOverlay = bootstrap.zebraClippingOverlay {
                        ZebraClippingOverlayView(overlay: zebraClippingOverlay)
                            .allowsHitTesting(false)
                    }

                    if bootstrap.isFocusPeakingEnabled,
                       let focusPeakingOverlay = bootstrap.focusPeakingOverlay {
                        FocusPeakingOverlayView(overlay: focusPeakingOverlay)
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: screenWidth, height: viewfinderHeight)
                .clipped()
                .overlay(alignment: .bottom) {
                    if isProControlsPresented {
                        proControlsPanel
                            .padding(.horizontal, CaptureDesignTokens.chromeInset)
                            .padding(.bottom, CaptureDesignTokens.chromeInset)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

                // Bottom bar — shutter centered in remaining space
                bottomChromeStack
                    .frame(maxHeight: .infinity)
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isProControlsPresented)
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    if value.translation.height < -40, !isProControlsPresented {
                        hapticLight()
                        withAnimation { isProControlsPresented = true }
                    } else if value.translation.height > 40, isProControlsPresented {
                        hapticLight()
                        withAnimation { isProControlsPresented = false }
                    }
                }
        )
    }

    // MARK: - Top Chrome

    private var topCameraChrome: some View {
        VStack(spacing: 4) {
            topHUD
            cameraUtilityBar
        }
        .padding(.horizontal, CaptureDesignTokens.chromeInset)
        .padding(.top, 4)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    // MARK: - Bottom Chrome Stack

    private var bottomChromeStack: some View {
        VStack(spacing: CaptureDesignTokens.controlGap) {
            cameraStatusFooter

            Spacer(minLength: 0)

            ShutterControlButton(
                isBusy: bootstrap.isCapturingPhoto || bootstrap.isRecoveringSession,
                action: {
                    hapticMedium()
                    Task { @MainActor in
                        await bootstrap.capturePhoto()
                    }
                }
            )
            .disabled(isInteractionDisabled)
            .accessibilityLabel("Shutter")
            .accessibilityValue(shutterButtonTitle)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Top HUD

    private var topHUD: some View {
        HStack(alignment: .center, spacing: 8) {
            Group {
                if let luminanceHistogram = bootstrap.luminanceHistogram {
                    LuminanceHistogramOverlayView(histogram: luminanceHistogram)
                        .frame(
                            width: CaptureDesignTokens.histogramWidth,
                            height: CaptureDesignTokens.histogramHeight
                        )
                } else {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 32, height: 28)
                        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            if let horizonRollDegrees = bootstrap.horizonRollDegrees {
                HorizonLevelIndicatorView(
                    rollDegrees: horizonRollDegrees,
                    levelToleranceDegrees: BootstrapViewModel.horizonLevelToleranceDegrees
                )
                .frame(width: 56, height: 28)
            }

            Spacer(minLength: 0)

            exposureHUDChip
        }
    }

    // MARK: - Exposure HUD Chip

    private var exposureHUDChip: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(.green)
                .frame(width: 6, height: 6)

            Text(formattedExposureCompensation(bootstrap.exposureCompensation))
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .foregroundStyle(CaptureDesignTokens.accentColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.black.opacity(0.35), in: Capsule())
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.1), lineWidth: 0.5)
        )
        .contentShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Exposure compensation")
        .accessibilityValue(formattedExposureCompensation(bootstrap.exposureCompensation))
    }

    // MARK: - Camera Utility Bar (Quick Toggles)

    private var cameraUtilityBar: some View {
        HStack(spacing: 2) {
            utilityToggle(
                symbol: "arrow.triangle.2.circlepath.camera",
                isActive: false,
                label: "Switch Camera"
            ) {
                hapticLight()
                Task { await bootstrap.switchCamera() }
            }

            utilityToggle(
                symbol: "timer",
                isActive: !isExposureAuto,
                label: isExposureAuto ? "Lock Exposure" : "Unlock Exposure"
            ) {
                hapticLight()
                toggleExposureMode()
            }

            utilityToggle(
                symbol: "viewfinder",
                isActive: bootstrap.isFocusPeakingEnabled,
                label: bootstrap.isFocusPeakingEnabled ? "Disable Focus Peaking" : "Enable Focus Peaking"
            ) {
                hapticLight()
                bootstrap.toggleFocusPeakingOverlay()
            }

            utilityToggle(
                symbol: "lines.measurement.horizontal",
                isActive: bootstrap.isZebraOverlayEnabled,
                label: bootstrap.isZebraOverlayEnabled ? "Disable Zebra" : "Enable Zebra"
            ) {
                hapticLight()
                bootstrap.toggleZebraOverlay()
            }

            utilityToggle(
                symbol: "drop.halffull",
                isActive: !isWhiteBalanceAuto,
                label: isWhiteBalanceAuto ? "Lock White Balance" : "Unlock White Balance"
            ) {
                hapticLight()
                toggleWhiteBalanceMode()
            }

            utilityToggle(
                symbol: "slider.horizontal.3",
                isActive: isProControlsPresented,
                label: isProControlsPresented ? "Hide Pro Controls" : "Show Pro Controls"
            ) {
                hapticLight()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    isProControlsPresented.toggle()
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }

    // MARK: - Camera Status Footer

    private var cameraStatusFooter: some View {
        VStack(spacing: 6) {
            if let storagePressureWarning = bootstrap.storagePressureWarning {
                statusNotice(
                    text: storagePressureWarning,
                    color: .yellow,
                    showCleanup: bootstrap.canCleanupRecentCapture || bootstrap.isCleaningRecentCapture
                )
            }

            if let lastCaptureError = bootstrap.lastCaptureError {
                VStack(spacing: 6) {
                    statusNotice(text: lastCaptureError, color: .red, showCleanup: false)

                    Button(bootstrap.isRecoveringSession ? "Recovering..." : "Retry Camera Session") {
                        Task { @MainActor in
                            await bootstrap.retrySessionRecovery()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(bootstrap.isRecoveringSession || bootstrap.isCapturingPhoto)
                }
            }
        }
    }

    @ViewBuilder
    private func statusNotice(text: String, color: Color, showCleanup: Bool) -> some View {
        VStack(spacing: 6) {
            Text(text)
                .font(.caption)
                .foregroundStyle(color)
                .multilineTextAlignment(.center)

            if showCleanup {
                Button(bootstrap.isCleaningRecentCapture ? "Cleaning..." : "Clean Last Capture") {
                    Task { @MainActor in
                        await bootstrap.cleanupRecentCapture()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(bootstrap.isCleaningRecentCapture || bootstrap.isCapturingPhoto)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Pro Controls Panel

    private var proControlsPanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: CaptureDesignTokens.sectionGap) {
                HStack {
                    panelTitle("Pro Controls")
                    Spacer()
                    Button {
                        hapticLight()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            isProControlsPresented = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(
                                width: CaptureDesignTokens.minimumTouchTarget,
                                height: CaptureDesignTokens.minimumTouchTarget
                            )
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close pro controls")
                }

                exposureSection
                focusSection
                whiteBalanceSection
                assistSection
                presetSection
                captureModeSection
                capabilitySection
            }
            .padding(CaptureDesignTokens.chromeInset)
        }
        .frame(maxHeight: CaptureDesignTokens.proControlsPanelMaxHeight)
        .background(
            .black.opacity(0.88),
            in: RoundedRectangle(cornerRadius: CaptureDesignTokens.panelRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CaptureDesignTokens.panelRadius, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pro controls panel")
    }

    // MARK: - Pro Panel Sections

    private var exposureSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            panelTitle("Exposure")

            Text(exposureModeLine)
                .font(.caption)
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
                compactPanelButton("Auto") {
                    hapticLight()
                    bootstrap.applyExposureAuto()
                }

                compactPanelButton("Apply ISO/Shutter") {
                    hapticLight()
                    bootstrap.applyCustomExposureSelection()
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Slider(
                    value: $bootstrap.selectedExposureCompensation,
                    in: bootstrap.exposureCompensationRange,
                    step: 0.1
                )
                Text("EV: \(formattedExposureCompensation(bootstrap.selectedExposureCompensation))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                compactPanelButton("Reset EV") {
                    hapticLight()
                    bootstrap.resetExposureCompensation()
                }

                compactPanelButton("Apply EV") {
                    hapticLight()
                    bootstrap.applyExposureCompensationSelection()
                }
            }
        }
        .disabled(isInteractionDisabled)
    }

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            panelTitle("Focus")

            Text(focusModeLine)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Slider(
                    value: $bootstrap.selectedFocusLensPosition,
                    in: 0...1,
                    step: 0.02
                )
                Text("Manual focus: \(formattedFocusPosition(bootstrap.selectedFocusLensPosition))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                compactPanelButton("Auto Focus") {
                    hapticRigid()
                    bootstrap.applyFocusAuto()
                }

                compactPanelButton("Lock Focus") {
                    hapticRigid()
                    bootstrap.applyFocusLockSelection()
                }
            }
        }
        .disabled(isInteractionDisabled)
    }

    private var whiteBalanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            panelTitle("White Balance")

            Text(whiteBalanceModeLine)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Slider(
                    value: $bootstrap.selectedWhiteBalanceTemperatureKelvin,
                    in: BootstrapViewModel.manualWhiteBalanceTemperatureRange,
                    step: 50
                )
                Text("Temperature: \(formattedWhiteBalanceTemperature(bootstrap.selectedWhiteBalanceTemperatureKelvin))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Slider(
                    value: $bootstrap.selectedWhiteBalanceTint,
                    in: BootstrapViewModel.manualWhiteBalanceTintRange,
                    step: 1
                )
                Text("Tint: \(formattedWhiteBalanceTint(bootstrap.selectedWhiteBalanceTint))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                compactPanelButton("Auto WB") {
                    hapticLight()
                    bootstrap.applyWhiteBalanceAuto()
                }

                compactPanelButton("Lock WB") {
                    hapticLight()
                    bootstrap.applyWhiteBalanceLockSelection()
                }
            }
        }
        .disabled(isInteractionDisabled)
    }

    private var assistSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            panelTitle("Assist Tools")

            VStack(alignment: .leading, spacing: 4) {
                Text(zebraStatusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Slider(
                    value: $bootstrap.selectedZebraThreshold,
                    in: BootstrapViewModel.zebraThresholdRange,
                    step: 0.01
                )

                HStack(spacing: 10) {
                    compactPanelButton(bootstrap.isZebraOverlayEnabled ? "Disable Zebra" : "Enable Zebra") {
                        hapticLight()
                        bootstrap.toggleZebraOverlay()
                    }

                    compactPanelButton("Apply Zebra") {
                        hapticLight()
                        bootstrap.applyZebraThresholdSelection()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(focusPeakingStatusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Slider(
                    value: $bootstrap.selectedFocusPeakingThreshold,
                    in: BootstrapViewModel.focusPeakingThresholdRange,
                    step: 0.01
                )

                HStack(spacing: 10) {
                    compactPanelButton(bootstrap.isFocusPeakingEnabled ? "Disable Peaking" : "Enable Peaking") {
                        hapticLight()
                        bootstrap.toggleFocusPeakingOverlay()
                    }

                    compactPanelButton("Apply Peaking") {
                        hapticLight()
                        bootstrap.applyFocusPeakingThresholdSelection()
                    }
                }
            }

            Text(horizonStatusLine)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .disabled(isInteractionDisabled)
    }

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            panelTitle("Presets")

            Picker("Preset Slot", selection: $bootstrap.selectedPresetSlot) {
                ForEach(BootstrapViewModel.presetSlots, id: \.self) { slot in
                    Text(slot.displayName).tag(slot)
                }
            }
            .pickerStyle(.segmented)

            Text(presetStatusLine)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                compactPanelButton("Save") {
                    hapticLight()
                    bootstrap.savePresetSelection()
                }

                compactPanelButton("Apply") {
                    hapticLight()
                    bootstrap.applyPresetSelection()
                }
                .disabled(!bootstrap.savedPresetSlots.contains(bootstrap.selectedPresetSlot))
            }
        }
        .disabled(isInteractionDisabled)
    }

    private var captureModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            panelTitle("Capture Mode")

            HStack(spacing: 8) {
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

            Text(modeGuidePrimaryLine)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .disabled(isInteractionDisabled)
    }

    private var capabilitySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            panelTitle("Device Capability")

            Text(rawCapabilityHeadline)
                .font(.caption.weight(.semibold))
                .foregroundStyle(bootstrap.rawCaptureCapability.isSupported ? .green : .yellow)

            if let rawCapabilityReason {
                Text(rawCapabilityReason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(appleProRAWCapabilityHeadline)
                .font(.caption.weight(.semibold))
                .foregroundStyle(bootstrap.rawCaptureCapability.isAppleProRAWSupported ? .green : .yellow)

            if let appleProRAWCapabilityReason {
                Text(appleProRAWCapabilityReason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    #endif

    // MARK: - Shared View Builders

    @ViewBuilder
    private func panelTitle(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
    }

    @ViewBuilder
    private func compactPanelButton(_ title: String, action: @MainActor @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func utilityToggle(
        symbol: String,
        isActive: Bool,
        label: String,
        action: @MainActor @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 36, height: 36)
                .foregroundStyle(isActive ? CaptureDesignTokens.accentColor : .white.opacity(0.85))
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isActive ? .white.opacity(0.12) : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isInteractionDisabled)
        .accessibilityLabel(label)
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }

    // MARK: - Computed Properties

    private var isInteractionDisabled: Bool {
        bootstrap.isCapturingPhoto || bootstrap.isRecoveringSession
    }

    private var buttonTitle: String {
        switch bootstrap.state {
        case .requestingPermission:
            return "Launching..."
        default:
            return "Launch Camera"
        }
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

    private var isExposureAuto: Bool {
        if case .auto = bootstrap.exposureState {
            return true
        }
        return false
    }

    private var isWhiteBalanceAuto: Bool {
        if case .auto = bootstrap.whiteBalanceState {
            return true
        }
        return false
    }

    // MARK: - Actions

    private func toggleExposureMode() {
        if isExposureAuto {
            bootstrap.applyCustomExposureSelection()
        } else {
            bootstrap.applyExposureAuto()
        }
    }

    private func toggleWhiteBalanceMode() {
        if isWhiteBalanceAuto {
            bootstrap.applyWhiteBalanceLockSelection()
        } else {
            bootstrap.applyWhiteBalanceAuto()
        }
    }

    // MARK: - Derived State

    private func formattedByteCount(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
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
            hapticLight()
            bootstrap.selectCaptureFormat(format)
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? tint : nil)
        .opacity(isSupported || format == .processed ? 1.0 : 0.7)
        .disabled(isInteractionDisabled)
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
            return "0.0"
        }
        return String(format: "%+.1f", value)
    }

    private func formattedZebraThreshold(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func formattedFocusPeakingThreshold(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private var zebraStatusLine: String {
        let stateDescription = bootstrap.isZebraOverlayEnabled ? "Zebra enabled" : "Zebra disabled"
        if let zebraClippingOverlay = bootstrap.zebraClippingOverlay {
            let clippedPercent = Int((zebraClippingOverlay.clippedRatio * 100).rounded())
            return "\(stateDescription) · clipped area \(clippedPercent)%"
        }
        return "\(stateDescription) · threshold \(formattedZebraThreshold(bootstrap.selectedZebraThreshold))"
    }

    private var focusPeakingStatusLine: String {
        let stateDescription = bootstrap.isFocusPeakingEnabled ? "Peaking enabled" : "Peaking disabled"
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

// MARK: - Shutter Control Button

private struct ShutterControlButton: View {
    let isBusy: Bool
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.24))
                    .frame(
                        width: CaptureDesignTokens.shutterButtonOuterSize,
                        height: CaptureDesignTokens.shutterButtonOuterSize
                    )

                Circle()
                    .stroke(.white.opacity(0.75), lineWidth: 2)
                    .frame(
                        width: CaptureDesignTokens.shutterButtonOuterSize,
                        height: CaptureDesignTokens.shutterButtonOuterSize
                    )

                Circle()
                    .fill(isBusy ? .white.opacity(0.72) : .white.opacity(0.92))
                    .frame(
                        width: CaptureDesignTokens.shutterButtonInnerSize,
                        height: CaptureDesignTokens.shutterButtonInnerSize
                    )
            }
            .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Horizon Level Indicator

private struct HorizonLevelIndicatorView: View {
    let rollDegrees: Double
    let levelToleranceDegrees: Double

    var body: some View {
        let clampedRollDegrees = min(max(rollDegrees, -45), 45)
        let isLevel = abs(rollDegrees) <= levelToleranceDegrees
        let indicatorColor: Color = isLevel ? .green : .yellow

        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(.black.opacity(0.35))

            Capsule()
                .fill(.white.opacity(0.15))
                .frame(width: 40, height: 1.5)

            Capsule()
                .fill(indicatorColor.opacity(0.9))
                .frame(width: 40, height: 2)
                .rotationEffect(.degrees(-clampedRollDegrees))
        }
        .overlay(alignment: .trailing) {
            Text(String(format: "%.0f°", abs(rollDegrees)))
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(indicatorColor.opacity(0.9))
                .padding(.trailing, 3)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Horizon level indicator")
        .accessibilityValue("\(Int(rollDegrees.rounded())) degrees")
    }
}

// MARK: - Luminance Histogram Overlay

private struct LuminanceHistogramOverlayView: View {
    let histogram: LuminanceHistogram

    var body: some View {
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
                        width: max(barWidth - 1, 0.4),
                        height: barHeight
                    )
                    context.fill(Path(barRect), with: .color(.white.opacity(0.85)))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Luminance histogram")
    }
}

// MARK: - Zebra Clipping Overlay

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

// MARK: - Focus Peaking Overlay

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

// MARK: - Camera Preview

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
