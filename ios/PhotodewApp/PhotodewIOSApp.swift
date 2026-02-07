import App
import CameraKit
import Foundation
import SwiftUI
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(CoreMotion)
import CoreMotion
#endif
#if canImport(Photos)
import Photos
#endif
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
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

enum SaveToastState: Equatable {
    case saving
    case saved
    case cleaned

    var message: String {
        switch self {
        case .saving:
            return "Saving to Photos..."
        case .saved:
            return "Saved to Photos."
        case .cleaned:
            return "Deleted last capture from Photos."
        }
    }
}

/// A `Sendable` weak-reference box that avoids capturing `@MainActor`-isolated
/// objects directly in `@Sendable` closures, which would trigger Swift 6.1
/// runtime isolation assertions even when the closure only forwards to a
/// `Task { @MainActor in }` block.
private final class WeakRef<T: AnyObject>: @unchecked Sendable {
    weak var value: T?
    init(_ value: T) { self.value = value }
}

// MARK: - Non-isolated callback factories
//
// Closures defined inside a @MainActor method inherit MainActor isolation,
// causing Swift 6.1 to insert runtime dispatch-queue assertions even when the
// closure never accesses actor-isolated state directly.  These free functions
// live outside any actor context so the closures they return are genuinely
// nonisolated.

#if canImport(CoreMotion)
import CoreMotion

/// Returns a Core Motion handler that forwards device-motion updates to the
/// MainActor via the provided `WeakRef`.
private func makeMotionHandler(
    weakSelf: WeakRef<BootstrapViewModel>
) -> (CMDeviceMotion?, (any Error)?) -> Void {
    return { motion, error in
        if let error {
            let message = error.localizedDescription
            Task { @MainActor in
                weakSelf.value?.horizonStatusMessage = "Horizon updates failed: \(message)"
            }
            return
        }
        guard let rollRadians = motion?.attitude.roll else { return }
        Task { @MainActor in
            weakSelf.value?.applyHorizonRoll(radians: rollRadians)
        }
    }
}
#endif

/// Returns a luminance-histogram handler that hops to MainActor.
private func makeHistogramHandler(
    weakSelf: WeakRef<BootstrapViewModel>
) -> @Sendable (LuminanceHistogram) -> Void {
    return { histogram in
        Task { @MainActor in
            weakSelf.value?.applyLuminanceHistogram(histogram)
        }
    }
}

/// Returns a zebra-clipping overlay handler that hops to MainActor.
private func makeZebraHandler(
    weakSelf: WeakRef<BootstrapViewModel>
) -> @Sendable (ZebraClippingOverlay) -> Void {
    return { overlay in
        Task { @MainActor in
            weakSelf.value?.applyZebraClippingOverlay(overlay)
        }
    }
}

/// Returns a focus-peaking overlay handler that hops to MainActor.
private func makeFocusPeakingHandler(
    weakSelf: WeakRef<BootstrapViewModel>
) -> @Sendable (FocusPeakingOverlay) -> Void {
    return { overlay in
        Task { @MainActor in
            weakSelf.value?.applyFocusPeakingOverlay(overlay)
        }
    }
}

@MainActor
final class BootstrapViewModel: ObservableObject {
    @Published private(set) var state: AppBootState = .idle
    @Published private(set) var isCapturingPhoto = false
    @Published private(set) var isRecoveringSession = false
    @Published private(set) var lastCaptureByteCount: Int?
    @Published private(set) var lastCaptureAt: Date?
    @Published private(set) var lastCaptureError: String?
    #if canImport(UIKit)
    @Published private(set) var lastCapturedThumbnail: UIImage?
    #endif
    @Published private(set) var saveToast: SaveToastState?
    @Published private(set) var selectedCaptureFormat: CapturePhotoFormat = .processed
    @Published private(set) var storagePressureWarning: String?
    @Published private(set) var isCleaningRecentCapture = false
    @Published private(set) var exposureState: ExposureControlState = .auto
    @Published private(set) var exposureCompensation: Double = 0
    @Published private(set) var exposureCompensationRange: ClosedRange<Double> = -2...2
    @Published private(set) var focusState: FocusControlState = .auto
    @Published private(set) var whiteBalanceState: WhiteBalanceControlState = .auto
    @Published private(set) var luminanceHistogram: LuminanceHistogram?
    @Published private(set) var zebraClippingOverlay: ZebraClippingOverlay?
    @Published private(set) var focusPeakingOverlay: FocusPeakingOverlay?
    @Published private(set) var horizonRollDegrees: Double?
    @Published fileprivate(set) var horizonStatusMessage: String?
    @Published private(set) var isZebraOverlayEnabled = false
    @Published private(set) var isFocusPeakingEnabled = false
    @Published var selectedExposureISO: Double = 100
    @Published var selectedExposureShutterSeconds: Double = 1.0 / 125.0
    @Published var selectedExposureCompensation: Double = 0
    @Published var selectedZebraThreshold: Double = 0.95
    @Published var selectedFocusPeakingThreshold: Double = 0.24
    @Published var selectedFocusLensPosition: Double = 0.5
    @Published var selectedWhiteBalanceTemperatureKelvin: Double = 5_000
    @Published var selectedWhiteBalanceTint: Double = 0
    @Published var selectedPresetSlot: CapturePresetSlot = .preset1
    @Published private(set) var savedPresetSlots: Set<CapturePresetSlot> = []
    @Published private(set) var selectedPresetSavedAt: Date?
    @Published private(set) var rawCaptureCapability = RawCaptureCapability(
        isSupported: false,
        availableRawPhotoPixelFormatTypes: [],
        reason: "RAW capability is unavailable until the camera session is running."
    )

    private let model: CaptureAppModel
    private let cameraRollSaver: CameraRollSaving
    private let storageMonitor: StorageMonitoring
    private var activeCaptureID: UUID?
    private var lastSavedLocalIdentifiers: [String] = []
    private var dismissSaveToastTask: Task<Void, Never>?
    private var lastHistogramPublishedAt: Date?
    private var lastZebraOverlayPublishedAt: Date?
    private var lastFocusPeakingOverlayPublishedAt: Date?
    private var lastHorizonLevelPublishedAt: Date?
    #if canImport(CoreMotion)
    private let motionManager = CMMotionManager()
    private let motionUpdatesQueue = OperationQueue()
    #endif
    #if canImport(AVFoundation)
    private var sessionNotificationObservers: [NSObjectProtocol] = []
    private weak var observedCaptureSession: AVCaptureSession?
    #endif
    private static let lowStorageThresholdBytes: Int64 = 5_000_000_000
    private static let minimumHistogramUpdateIntervalSeconds: TimeInterval = 1.0 / 12.0
    private static let minimumZebraOverlayUpdateIntervalSeconds: TimeInterval = 1.0 / 12.0
    private static let minimumFocusPeakingOverlayUpdateIntervalSeconds: TimeInterval = 1.0 / 12.0
    private static let minimumHorizonLevelUpdateIntervalSeconds: TimeInterval = 1.0 / 30.0
    private static let horizonLevelSmoothingFactor: Double = 0.35
    private static let isHorizonLevelEnabled = true
    static let horizonLevelToleranceDegrees: Double = 1.4
    static let zebraThresholdRange: ClosedRange<Double> = 0.85...0.99
    static let focusPeakingThresholdRange: ClosedRange<Double> = 0.12...0.4
    static let manualISOOptions: [Double] = [25, 50, 64, 80, 100, 125, 160, 200, 320, 400, 640, 800, 1_250]
    static let manualShutterOptions: [Double] = [
        1.0 / 1_000.0,
        1.0 / 500.0,
        1.0 / 250.0,
        1.0 / 120.0,
        1.0 / 125.0,
        1.0 / 60.0,
        1.0 / 30.0,
        1.0 / 15.0,
        1.0 / 8.0,
    ]
    static let manualWhiteBalanceTemperatureRange: ClosedRange<Double> = 2_000...10_000
    static let manualWhiteBalanceTintRange: ClosedRange<Double> = -150...150
    static let presetSlots: [CapturePresetSlot] = CapturePresetSlot.allCases

    init(
        model: CaptureAppModel = AppCompositionRoot().makeAppModel(),
        cameraRollSaver: CameraRollSaving = SystemCameraRollSaver(),
        storageMonitor: StorageMonitoring = DeviceStorageMonitor()
    ) {
        self.model = model
        self.cameraRollSaver = cameraRollSaver
        self.storageMonitor = storageMonitor
        #if canImport(CoreMotion)
        motionUpdatesQueue.name = "Photodew.HorizonLevelMotionUpdates"
        motionUpdatesQueue.maxConcurrentOperationCount = 1
        motionUpdatesQueue.qualityOfService = .userInteractive
        #endif
    }

    func start() async {
        #if targetEnvironment(simulator)
        state = .blocked(reason: "Simulator has no real camera input. Use a physical iPhone for camera testing.")
        rawCaptureCapability = RawCaptureCapability(
            isSupported: false,
            availableRawPhotoPixelFormatTypes: [],
            reason: "RAW capability checks require a physical iPhone camera.",
            isAppleProRAWSupported: false,
            availableAppleProRAWPhotoPixelFormatTypes: [],
            appleProRAWReason: "Apple ProRAW capability checks require a physical iPhone camera."
        )
        selectedCaptureFormat = .processed
        resetLuminanceHistogramUpdates()
        resetZebraOverlayUpdates()
        resetFocusPeakingOverlayUpdates()
        resetHorizonLevelUpdates()
        return
        #else
        await model.bootstrap()
        state = model.bootState
        refreshRawCaptureCapability()
        refreshExposureState()
        refreshExposureCompensation()
        refreshFocusState()
        refreshWhiteBalanceState()
        refreshStoragePressureWarning()
        refreshPresetState()
        configureSessionObserversIfNeeded()
        configureLuminanceHistogramUpdatesIfNeeded()
        configureZebraOverlayUpdatesIfNeeded()
        configureFocusPeakingOverlayUpdatesIfNeeded()
        configureHorizonLevelUpdatesIfNeeded()
        await fetchLastPhotoThumbnail()
        #endif
    }

    func stop() async {
        await model.stopSession()
        rawCaptureCapability = RawCaptureCapability(
            isSupported: false,
            availableRawPhotoPixelFormatTypes: [],
            reason: "RAW capability is unavailable until the camera session is running.",
            isAppleProRAWSupported: false,
            availableAppleProRAWPhotoPixelFormatTypes: [],
            appleProRAWReason: "Apple ProRAW capability is unavailable until the camera session is running."
        )
        selectedCaptureFormat = .processed
        exposureState = .auto
        exposureCompensation = 0
        exposureCompensationRange = -2...2
        selectedExposureCompensation = 0
        focusState = .auto
        whiteBalanceState = .auto
        selectedWhiteBalanceTemperatureKelvin = 5_000
        selectedWhiteBalanceTint = 0
        savedPresetSlots = []
        selectedPresetSavedAt = nil
        storagePressureWarning = nil
        resetLuminanceHistogramUpdates()
        resetZebraOverlayUpdates()
        resetFocusPeakingOverlayUpdates()
        resetHorizonLevelUpdates()
        removeSessionObservers()
    }

    func resumeSessionIfNeeded() async {
        await model.resumeSessionIfNeeded()
        state = model.bootState
        refreshRawCaptureCapability()
        refreshExposureState()
        refreshExposureCompensation()
        refreshFocusState()
        refreshWhiteBalanceState()
        refreshStoragePressureWarning()
        refreshPresetState()
        configureSessionObserversIfNeeded()
        configureLuminanceHistogramUpdatesIfNeeded()
        configureZebraOverlayUpdatesIfNeeded()
        configureFocusPeakingOverlayUpdatesIfNeeded()
        configureHorizonLevelUpdatesIfNeeded()
    }

    func capturePhoto() async {
        guard case .ready = state else { return }
        guard !isCapturingPhoto else { return }

        let captureID = UUID()
        activeCaptureID = captureID
        isCapturingPhoto = true
        lastCaptureError = nil
        setSaveToast(nil)

        startCaptureWatchdog(for: captureID)

        do {
            let lensPosition = model.currentLensPosition()
            let captureFormat = selectedCaptureFormat
            let capturePayload = try await model.capturePhotoPayload(format: captureFormat)
            setSaveToast(.saving)
            let saveResult = try await cameraRollSaver.saveCapturePayload(
                capturePayload,
                requestedFormat: captureFormat
            )
            guard activeCaptureID == captureID else { return }
            let capturedAt = Date()
            let primaryByteCount = try capturePayload.primaryData(for: captureFormat).count
            let pairedLocalIdentifier = saveResult.pairedLocalIdentifier
            let pairedByteCount = pairedLocalIdentifier == nil ? nil : capturePayload.secondaryData(for: captureFormat)?.count
            let primaryCaptureMetadata = capturePayload.primaryMetadata(for: captureFormat)
            let pairedCaptureMetadata = pairedLocalIdentifier == nil ? nil : capturePayload.secondaryMetadata(for: captureFormat)
            lastSavedLocalIdentifiers = saveResult.localIdentifiers
            lastCaptureByteCount = capturePayload.totalByteCount
            lastCaptureAt = capturedAt
            lastCaptureError = nil
            await model.persistPhotoLibraryCapture(
                localIdentifier: saveResult.primaryLocalIdentifier,
                capturedAt: capturedAt,
                lensPosition: lensPosition,
                byteCount: primaryByteCount,
                captureFormat: captureFormat,
                pairedLocalIdentifier: pairedLocalIdentifier,
                pairedByteCount: pairedByteCount,
                captureMetadata: primaryCaptureMetadata,
                pairedCaptureMetadata: pairedCaptureMetadata
            )
            refreshStoragePressureWarning()
            #if canImport(UIKit)
            updateLastCapturedThumbnail(from: capturePayload)
            #endif
            setSaveToast(.saved)
            scheduleSaveToastDismiss()
            activeCaptureID = nil
            isCapturingPhoto = false
        } catch {
            guard activeCaptureID == captureID else { return }
            activeCaptureID = nil
            isCapturingPhoto = false
            lastCaptureError = captureErrorMessage(from: error)
            setSaveToast(nil)
            if error is CaptureSessionError {
                lastCaptureError = "\(captureErrorMessage(from: error)) Recovering camera session."
                Task { [weak self] in
                    await self?.recoverSession(trigger: "capture_error")
                }
            }
        }
    }

    var canCleanupRecentCapture: Bool {
        !lastSavedLocalIdentifiers.isEmpty
    }

    func cleanupRecentCapture() async {
        guard case .ready = state else { return }
        guard !isCleaningRecentCapture else { return }
        let localIdentifiers = lastSavedLocalIdentifiers
        guard !localIdentifiers.isEmpty else { return }

        isCleaningRecentCapture = true
        defer { isCleaningRecentCapture = false }

        do {
            let deletedCount = try await cameraRollSaver.deleteAssets(localIdentifiers: localIdentifiers)
            guard deletedCount > 0 else { return }
            await model.removePhotoLibraryCaptures(localIdentifiers: localIdentifiers)
            lastSavedLocalIdentifiers = []
            lastCaptureError = nil
            refreshStoragePressureWarning()
            setSaveToast(.cleaned)
            scheduleSaveToastDismiss()
        } catch {
            lastCaptureError = captureErrorMessage(from: error)
        }
    }

    #if canImport(UIKit)
    private func updateLastCapturedThumbnail(from payload: CapturedPhotoPayload) {
        let imageData = payload.processedData ?? payload.rawData
        guard let imageData, let fullImage = UIImage(data: imageData) else { return }
        let thumbnailSize: CGFloat = 96 // 48pt × 2x retina
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: thumbnailSize, height: thumbnailSize))
        lastCapturedThumbnail = renderer.image { _ in
            let aspectRatio = fullImage.size.width / fullImage.size.height
            let drawWidth: CGFloat
            let drawHeight: CGFloat
            if aspectRatio > 1 {
                drawHeight = thumbnailSize
                drawWidth = thumbnailSize * aspectRatio
            } else {
                drawWidth = thumbnailSize
                drawHeight = thumbnailSize / aspectRatio
            }
            let drawX = (thumbnailSize - drawWidth) / 2
            let drawY = (thumbnailSize - drawHeight) / 2
            fullImage.draw(in: CGRect(x: drawX, y: drawY, width: drawWidth, height: drawHeight))
        }
    }
    #endif

    #if canImport(Photos) && canImport(UIKit)
    private func fetchLastPhotoThumbnail() async {
        var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        guard status == .authorized || status == .limited else { return }

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1
        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        guard let asset = result.firstObject else { return }

        let thumbnailPixelSize = CGSize(width: 96, height: 96) // 48pt × 2x retina
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false
        options.isSynchronous = false

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: thumbnailPixelSize,
            contentMode: .aspectFill,
            options: options
        ) { [weak self] image, _ in
            Task { @MainActor [weak self] in
                guard let self, let image else { return }
                if self.lastCapturedThumbnail == nil {
                    self.lastCapturedThumbnail = image
                }
            }
        }
    }
    #endif

    func retrySessionRecovery() async {
        lastCaptureError = "Retrying camera session..."
        await recoverSession(trigger: "manual_retry")
    }

    func switchCamera() async {
        guard case .ready = state else { return }
        do {
            try await model.switchCamera()
            lastCaptureError = nil
            refreshRawCaptureCapability()
            refreshExposureState()
            refreshExposureCompensation()
            refreshFocusState()
            refreshWhiteBalanceState()
        } catch {
            lastCaptureError = String(describing: error)
        }
    }

    func selectCaptureFormat(_ format: CapturePhotoFormat) {
        guard case .ready = state else { return }
        guard isCaptureFormatSupported(format) else {
            selectedCaptureFormat = .processed
            if let reason = captureFormatUnavailableReason(for: format) {
                lastCaptureError = reason
            }
            return
        }
        selectedCaptureFormat = format
        lastCaptureError = nil
    }

    func cycleCaptureFormat() {
        guard case .ready = state else { return }
        let allFormats: [CapturePhotoFormat] = [.processed, .raw, .appleProRAW]
        let supported = allFormats.filter { isCaptureFormatSupported($0) }
        guard let currentIndex = supported.firstIndex(of: selectedCaptureFormat) else {
            selectCaptureFormat(.processed)
            return
        }
        let nextIndex = (currentIndex + 1) % supported.count
        selectCaptureFormat(supported[nextIndex])
    }

    func applyExposureAuto() {
        guard case .ready = state else { return }
        do {
            try model.setExposureAuto()
            refreshExposureState()
            lastCaptureError = nil
        } catch {
            lastCaptureError = captureErrorMessage(from: error)
        }
    }

    func applyCustomExposureSelection() {
        guard case .ready = state else { return }
        do {
            try model.setCustomExposure(
                iso: selectedExposureISO,
                shutterSeconds: selectedExposureShutterSeconds
            )
            refreshExposureState()
            lastCaptureError = nil
        } catch {
            lastCaptureError = captureErrorMessage(from: error)
        }
    }

    func applyExposureCompensationSelection() {
        guard case .ready = state else { return }
        do {
            try model.setExposureCompensation(selectedExposureCompensation)
            refreshExposureCompensation()
            lastCaptureError = nil
        } catch {
            lastCaptureError = captureErrorMessage(from: error)
        }
    }

    func resetExposureCompensation() {
        guard case .ready = state else { return }
        do {
            try model.resetExposureCompensation()
            refreshExposureCompensation()
            lastCaptureError = nil
        } catch {
            lastCaptureError = captureErrorMessage(from: error)
        }
    }

    func toggleZebraOverlay() {
        guard case .ready = state else { return }
        isZebraOverlayEnabled.toggle()
        if isZebraOverlayEnabled {
            model.setZebraClippingThreshold(clampedZebraThreshold(selectedZebraThreshold))
        } else {
            model.setZebraClippingThreshold(nil)
            zebraClippingOverlay = nil
            lastZebraOverlayPublishedAt = nil
        }
    }

    func applyZebraThresholdSelection() {
        guard case .ready = state else { return }
        selectedZebraThreshold = clampedZebraThreshold(selectedZebraThreshold)
        if isZebraOverlayEnabled {
            model.setZebraClippingThreshold(selectedZebraThreshold)
        }
    }

    func toggleFocusPeakingOverlay() {
        guard case .ready = state else { return }
        isFocusPeakingEnabled.toggle()
        if isFocusPeakingEnabled {
            model.setFocusPeakingThreshold(clampedFocusPeakingThreshold(selectedFocusPeakingThreshold))
        } else {
            model.setFocusPeakingThreshold(nil)
            focusPeakingOverlay = nil
            lastFocusPeakingOverlayPublishedAt = nil
        }
    }

    func applyFocusPeakingThresholdSelection() {
        guard case .ready = state else { return }
        selectedFocusPeakingThreshold = clampedFocusPeakingThreshold(selectedFocusPeakingThreshold)
        if isFocusPeakingEnabled {
            model.setFocusPeakingThreshold(selectedFocusPeakingThreshold)
        }
    }

    func applyFocusAuto() {
        guard case .ready = state else { return }
        do {
            try model.setFocusAuto()
            refreshFocusState()
            lastCaptureError = nil
        } catch {
            lastCaptureError = captureErrorMessage(from: error)
        }
    }

    func applyFocusLockSelection() {
        guard case .ready = state else { return }
        do {
            try model.lockFocus(lensPosition: selectedFocusLensPosition)
            refreshFocusState()
            lastCaptureError = nil
        } catch {
            lastCaptureError = captureErrorMessage(from: error)
        }
    }

    func applyWhiteBalanceAuto() {
        guard case .ready = state else { return }
        do {
            try model.setWhiteBalanceAuto()
            refreshWhiteBalanceState()
            lastCaptureError = nil
        } catch {
            lastCaptureError = captureErrorMessage(from: error)
        }
    }

    func applyWhiteBalanceLockSelection() {
        guard case .ready = state else { return }
        do {
            try model.lockWhiteBalance(
                temperatureKelvin: selectedWhiteBalanceTemperatureKelvin,
                tint: selectedWhiteBalanceTint
            )
            refreshWhiteBalanceState()
            lastCaptureError = nil
        } catch {
            lastCaptureError = captureErrorMessage(from: error)
        }
    }

    func savePresetSelection() {
        guard case .ready = state else { return }
        do {
            let preset = try model.saveCurrentControlPreset(for: selectedPresetSlot)
            savedPresetSlots.insert(selectedPresetSlot)
            selectedPresetSavedAt = preset.savedAt
            lastCaptureError = nil
        } catch {
            lastCaptureError = captureErrorMessage(from: error)
        }
    }

    func applyPresetSelection() {
        guard case .ready = state else { return }
        do {
            guard let preset = try model.applyControlPreset(for: selectedPresetSlot) else {
                selectedPresetSavedAt = nil
                lastCaptureError = "\(selectedPresetSlot.displayName) has no saved controls yet."
                return
            }
            refreshExposureState()
            refreshExposureCompensation()
            refreshFocusState()
            refreshWhiteBalanceState()
            savedPresetSlots.insert(selectedPresetSlot)
            selectedPresetSavedAt = preset.savedAt
            lastCaptureError = nil
        } catch {
            lastCaptureError = captureErrorMessage(from: error)
        }
    }

    func refreshSelectedPresetSlot() {
        do {
            selectedPresetSavedAt = try model.loadControlPreset(for: selectedPresetSlot)?.savedAt
        } catch {
            selectedPresetSavedAt = nil
            if case .ready = state {
                lastCaptureError = captureErrorMessage(from: error)
            }
        }
    }

    #if canImport(AVFoundation)
    var previewSession: AVCaptureSession? {
        model.previewSession
    }
    #endif

    private func recoverSession(trigger: String) async {
        guard !isRecoveringSession else { return }
        isRecoveringSession = true
        defer { isRecoveringSession = false }

        await model.stopSession()
        await model.bootstrap()
        state = model.bootState
        refreshRawCaptureCapability()
        refreshExposureState()
        refreshExposureCompensation()
        refreshFocusState()
        refreshWhiteBalanceState()
        refreshStoragePressureWarning()
        refreshPresetState()
        configureSessionObserversIfNeeded()
        configureLuminanceHistogramUpdatesIfNeeded()
        configureZebraOverlayUpdatesIfNeeded()
        configureFocusPeakingOverlayUpdatesIfNeeded()
        configureHorizonLevelUpdatesIfNeeded()

        if case .ready = state {
            if trigger == "manual_retry" || trigger == "session_runtime_error" || trigger == "session_interruption_ended" {
                lastCaptureError = nil
            }
            return
        }

        if trigger == "manual_retry" {
            lastCaptureError = "Camera recovery failed. Close and relaunch if the issue persists."
        }
    }

    private func startCaptureWatchdog(for captureID: UUID) {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard let self else { return }
            guard self.activeCaptureID == captureID else { return }

            self.activeCaptureID = nil
            self.isCapturingPhoto = false
            self.lastCaptureError = "Capture timed out. Recovering camera session."
            self.setSaveToast(nil)
            await self.recoverSession(trigger: "capture_watchdog_timeout")
        }
    }

    private func captureErrorMessage(from error: Error) -> String {
        if let captureError = error as? CaptureSessionError {
            switch captureError {
            case .captureTimedOut:
                return "Camera capture timed out."
            case .backendFailure:
                break
            case .cameraSwitchNotSupported:
                return "Camera switch is not available on this device."
            case .rawCaptureNotSupported:
                return "RAW capture is not available for the current camera configuration."
            case .appleProRAWCaptureNotSupported:
                return "Apple ProRAW capture is not available for the current camera configuration."
            }
        }

        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }

        return error.localizedDescription
    }

    private func setSaveToast(_ toast: SaveToastState?) {
        dismissSaveToastTask?.cancel()
        dismissSaveToastTask = nil
        saveToast = toast
    }

    private func scheduleSaveToastDismiss() {
        dismissSaveToastTask?.cancel()
        dismissSaveToastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.saveToast = nil
                self?.dismissSaveToastTask = nil
            }
        }
    }

    private func refreshRawCaptureCapability() {
        guard case .ready = state else {
            rawCaptureCapability = RawCaptureCapability(
                isSupported: false,
                availableRawPhotoPixelFormatTypes: [],
                reason: "RAW capability is unavailable until the camera session is running.",
                isAppleProRAWSupported: false,
                availableAppleProRAWPhotoPixelFormatTypes: [],
                appleProRAWReason: "Apple ProRAW capability is unavailable until the camera session is running."
            )
            selectedCaptureFormat = .processed
            return
        }
        rawCaptureCapability = model.rawCaptureCapability()
        sanitizeSelectedCaptureFormat()
    }

    private func isCaptureFormatSupported(_ format: CapturePhotoFormat) -> Bool {
        switch format {
        case .processed:
            return true
        case .raw:
            return rawCaptureCapability.isSupported
        case .appleProRAW:
            return rawCaptureCapability.isAppleProRAWSupported
        }
    }

    private func captureFormatUnavailableReason(for format: CapturePhotoFormat) -> String? {
        switch format {
        case .processed:
            return nil
        case .raw:
            return rawCaptureCapability.reason
        case .appleProRAW:
            return rawCaptureCapability.appleProRAWReason
        }
    }

    private func sanitizeSelectedCaptureFormat() {
        guard !isCaptureFormatSupported(selectedCaptureFormat) else { return }
        selectedCaptureFormat = .processed
    }

    private func refreshExposureState() {
        guard case .ready = state else {
            exposureState = .auto
            selectedExposureISO = Self.nearestOption(to: 100, in: Self.manualISOOptions) ?? selectedExposureISO
            selectedExposureShutterSeconds = Self.nearestOption(
                to: 1.0 / 125.0,
                in: Self.manualShutterOptions
            ) ?? selectedExposureShutterSeconds
            return
        }

        let currentExposureState = model.exposureState()
        exposureState = currentExposureState
        if let values = currentExposureState.values {
            selectedExposureISO = Self.nearestOption(to: values.iso, in: Self.manualISOOptions) ?? values.iso
            selectedExposureShutterSeconds = Self.nearestOption(
                to: values.shutterSeconds,
                in: Self.manualShutterOptions
            ) ?? values.shutterSeconds
        }
    }

    private func refreshExposureCompensation() {
        guard case .ready = state else {
            exposureCompensation = 0
            exposureCompensationRange = -2...2
            selectedExposureCompensation = 0
            return
        }

        exposureCompensationRange = model.exposureCompensationRange()
        let currentValue = model.exposureCompensation()
        exposureCompensation = currentValue
        selectedExposureCompensation = min(
            max(currentValue, exposureCompensationRange.lowerBound),
            exposureCompensationRange.upperBound
        )
    }

    private static func nearestOption(to value: Double, in options: [Double]) -> Double? {
        guard !options.isEmpty else { return nil }
        return options.min { lhs, rhs in
            abs(lhs - value) < abs(rhs - value)
        }
    }

    private func refreshFocusState() {
        guard case .ready = state else {
            focusState = .auto
            selectedFocusLensPosition = 0.5
            return
        }
        let currentFocusState = model.focusState()
        focusState = currentFocusState
        if let lensPosition = currentFocusState.lensPosition {
            selectedFocusLensPosition = min(max(lensPosition, 0), 1)
        }
    }

    private func refreshWhiteBalanceState() {
        guard case .ready = state else {
            whiteBalanceState = .auto
            selectedWhiteBalanceTemperatureKelvin = 5_000
            selectedWhiteBalanceTint = 0
            return
        }

        let currentWhiteBalanceState = model.whiteBalanceState()
        whiteBalanceState = currentWhiteBalanceState
        if let values = currentWhiteBalanceState.values {
            selectedWhiteBalanceTemperatureKelvin = min(
                max(values.temperatureKelvin, Self.manualWhiteBalanceTemperatureRange.lowerBound),
                Self.manualWhiteBalanceTemperatureRange.upperBound
            )
            selectedWhiteBalanceTint = min(
                max(values.tint, Self.manualWhiteBalanceTintRange.lowerBound),
                Self.manualWhiteBalanceTintRange.upperBound
            )
        }
    }

    private func refreshStoragePressureWarning() {
        guard case .ready = state else {
            storagePressureWarning = nil
            return
        }

        guard let availableBytes = storageMonitor.currentAvailableCapacityForImportantUsage() else {
            storagePressureWarning = nil
            return
        }

        if availableBytes <= Self.lowStorageThresholdBytes {
            let availableText = ByteCountFormatter.string(fromByteCount: availableBytes, countStyle: .file)
            storagePressureWarning = "Low storage: \(availableText) available. RAW and Apple ProRAW captures may fail. Clean recent captures if needed."
            return
        }

        storagePressureWarning = nil
    }

    private func refreshPresetState() {
        do {
            savedPresetSlots = try model.availableControlPresetSlots()
            selectedPresetSavedAt = try model.loadControlPreset(for: selectedPresetSlot)?.savedAt
        } catch {
            savedPresetSlots = []
            selectedPresetSavedAt = nil
            if case .ready = state {
                lastCaptureError = captureErrorMessage(from: error)
            }
        }
    }

    private func configureLuminanceHistogramUpdatesIfNeeded() {
        guard case .ready = state else {
            resetLuminanceHistogramUpdates()
            return
        }
        let weakSelf = WeakRef(self)
        model.setLuminanceHistogramHandler(makeHistogramHandler(weakSelf: weakSelf))
    }

    private func resetLuminanceHistogramUpdates() {
        model.setLuminanceHistogramHandler(nil)
        lastHistogramPublishedAt = nil
        luminanceHistogram = nil
    }

    fileprivate func applyLuminanceHistogram(_ histogram: LuminanceHistogram) {
        let now = Date()
        if let lastHistogramPublishedAt,
           now.timeIntervalSince(lastHistogramPublishedAt) < Self.minimumHistogramUpdateIntervalSeconds {
            return
        }
        self.lastHistogramPublishedAt = now
        luminanceHistogram = histogram
    }

    private func configureZebraOverlayUpdatesIfNeeded() {
        guard case .ready = state else {
            resetZebraOverlayUpdates()
            return
        }
        let weakSelf = WeakRef(self)
        model.setZebraClippingOverlayHandler(makeZebraHandler(weakSelf: weakSelf))
        if isZebraOverlayEnabled {
            model.setZebraClippingThreshold(clampedZebraThreshold(selectedZebraThreshold))
        } else {
            model.setZebraClippingThreshold(nil)
        }
    }

    private func resetZebraOverlayUpdates() {
        model.setZebraClippingThreshold(nil)
        model.setZebraClippingOverlayHandler(nil)
        zebraClippingOverlay = nil
        lastZebraOverlayPublishedAt = nil
    }

    fileprivate func applyZebraClippingOverlay(_ overlay: ZebraClippingOverlay) {
        guard isZebraOverlayEnabled else { return }
        let now = Date()
        if let lastZebraOverlayPublishedAt,
           now.timeIntervalSince(lastZebraOverlayPublishedAt) < Self.minimumZebraOverlayUpdateIntervalSeconds {
            return
        }
        lastZebraOverlayPublishedAt = now
        zebraClippingOverlay = overlay
    }

    private func clampedZebraThreshold(_ value: Double) -> Double {
        min(max(value, Self.zebraThresholdRange.lowerBound), Self.zebraThresholdRange.upperBound)
    }

    private func configureFocusPeakingOverlayUpdatesIfNeeded() {
        guard case .ready = state else {
            resetFocusPeakingOverlayUpdates()
            return
        }
        let weakSelf = WeakRef(self)
        model.setFocusPeakingOverlayHandler(makeFocusPeakingHandler(weakSelf: weakSelf))
        if isFocusPeakingEnabled {
            model.setFocusPeakingThreshold(clampedFocusPeakingThreshold(selectedFocusPeakingThreshold))
        } else {
            model.setFocusPeakingThreshold(nil)
        }
    }

    private func resetFocusPeakingOverlayUpdates() {
        model.setFocusPeakingThreshold(nil)
        model.setFocusPeakingOverlayHandler(nil)
        focusPeakingOverlay = nil
        lastFocusPeakingOverlayPublishedAt = nil
    }

    fileprivate func applyFocusPeakingOverlay(_ overlay: FocusPeakingOverlay) {
        guard isFocusPeakingEnabled else { return }
        let now = Date()
        if let lastFocusPeakingOverlayPublishedAt,
           now.timeIntervalSince(lastFocusPeakingOverlayPublishedAt) < Self.minimumFocusPeakingOverlayUpdateIntervalSeconds {
            return
        }
        lastFocusPeakingOverlayPublishedAt = now
        focusPeakingOverlay = overlay
    }

    private func clampedFocusPeakingThreshold(_ value: Double) -> Double {
        min(max(value, Self.focusPeakingThresholdRange.lowerBound), Self.focusPeakingThresholdRange.upperBound)
    }

    private func configureHorizonLevelUpdatesIfNeeded() {
        guard case .ready = state else {
            resetHorizonLevelUpdates()
            return
        }
        guard Self.isHorizonLevelEnabled else {
            resetHorizonLevelUpdates()
            return
        }
        #if canImport(CoreMotion)
        guard motionManager.isDeviceMotionAvailable else {
            horizonStatusMessage = "Horizon level unavailable on this device."
            horizonRollDegrees = nil
            return
        }
        if motionManager.isDeviceMotionActive {
            return
        }
        horizonStatusMessage = nil
        motionManager.deviceMotionUpdateInterval = Self.minimumHorizonLevelUpdateIntervalSeconds
        let referenceFrame = preferredAttitudeReferenceFrame()
        let weakSelf = WeakRef(self)
        motionManager.startDeviceMotionUpdates(
            using: referenceFrame,
            to: motionUpdatesQueue,
            withHandler: makeMotionHandler(weakSelf: weakSelf)
        )
        #else
        horizonStatusMessage = "Horizon level requires Core Motion support."
        horizonRollDegrees = nil
        #endif
    }

    private func resetHorizonLevelUpdates() {
        #if canImport(CoreMotion)
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
        #endif
        horizonStatusMessage = nil
        horizonRollDegrees = nil
        lastHorizonLevelPublishedAt = nil
    }

    fileprivate func applyHorizonRoll(radians: Double) {
        let now = Date()
        if let lastHorizonLevelPublishedAt,
           now.timeIntervalSince(lastHorizonLevelPublishedAt) < Self.minimumHorizonLevelUpdateIntervalSeconds {
            return
        }
        let normalizedRollDegrees = normalizedHorizonRollDegrees(from: radians)
        if let existingRollDegrees = horizonRollDegrees {
            horizonRollDegrees = existingRollDegrees + ((normalizedRollDegrees - existingRollDegrees) * Self.horizonLevelSmoothingFactor)
        } else {
            horizonRollDegrees = normalizedRollDegrees
        }
        horizonStatusMessage = nil
        lastHorizonLevelPublishedAt = now
    }

    private func normalizedHorizonRollDegrees(from radians: Double) -> Double {
        var degrees = radians * 180.0 / .pi
        while degrees > 180 {
            degrees -= 360
        }
        while degrees < -180 {
            degrees += 360
        }
        if degrees > 90 {
            degrees -= 180
        } else if degrees < -90 {
            degrees += 180
        }
        return degrees
    }

    #if canImport(CoreMotion)
    private func preferredAttitudeReferenceFrame() -> CMAttitudeReferenceFrame {
        let availableFrames = CMMotionManager.availableAttitudeReferenceFrames()
        if availableFrames.contains(.xArbitraryCorrectedZVertical) {
            return .xArbitraryCorrectedZVertical
        }
        if availableFrames.contains(.xArbitraryZVertical) {
            return .xArbitraryZVertical
        }
        if availableFrames.contains(.xMagneticNorthZVertical) {
            return .xMagneticNorthZVertical
        }
        return .xTrueNorthZVertical
    }
    #endif

    #if canImport(AVFoundation)
    private func configureSessionObserversIfNeeded() {
        guard case .ready = state else {
            removeSessionObservers()
            return
        }
        guard let captureSession = model.previewSession else {
            removeSessionObservers()
            return
        }
        if observedCaptureSession === captureSession, !sessionNotificationObservers.isEmpty {
            return
        }

        removeSessionObservers()
        observedCaptureSession = captureSession

        let notificationCenter = NotificationCenter.default
        let interruptedObserver = notificationCenter.addObserver(
            forName: AVCaptureSession.wasInterruptedNotification,
            object: captureSession,
            queue: .main
        ) { [weak self] notification in
            let reasonDescription = sessionInterruptionReasonDescription(from: notification.userInfo)
            Task { @MainActor [weak self] in
                self?.handleSessionInterrupted(reasonDescription: reasonDescription)
            }
        }
        let interruptionEndedObserver = notificationCenter.addObserver(
            forName: AVCaptureSession.interruptionEndedNotification,
            object: captureSession,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleSessionInterruptionEnded()
            }
        }
        let runtimeErrorObserver = notificationCenter.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification,
            object: captureSession,
            queue: .main
        ) { [weak self] notification in
            let reasonDescription = sessionRuntimeErrorDescription(from: notification.userInfo)
            Task { @MainActor [weak self] in
                self?.handleSessionRuntimeError(reasonDescription: reasonDescription)
            }
        }

        sessionNotificationObservers = [
            interruptedObserver,
            interruptionEndedObserver,
            runtimeErrorObserver,
        ]
    }

    private func removeSessionObservers() {
        let notificationCenter = NotificationCenter.default
        for observer in sessionNotificationObservers {
            notificationCenter.removeObserver(observer)
        }
        sessionNotificationObservers = []
        observedCaptureSession = nil
    }

    private func handleSessionInterrupted(reasonDescription: String) {
        model.markSessionInterrupted(reason: reasonDescription)
        lastCaptureError = "Camera interrupted (\(reasonDescription)). Waiting for recovery..."
    }

    private func handleSessionInterruptionEnded() {
        Task { [weak self] in
            await self?.recoverSession(trigger: "session_interruption_ended")
        }
    }

    private func handleSessionRuntimeError(reasonDescription: String) {
        lastCaptureError = "Camera session error (\(reasonDescription)). Recovering..."
        Task { [weak self] in
            await self?.recoverSession(trigger: "session_runtime_error")
        }
    }

    #endif
}

#if canImport(AVFoundation)
private func sessionInterruptionReasonDescription(from userInfo: [AnyHashable: Any]?) -> String {
    guard let userInfo,
          let reasonValue = userInfo[AVCaptureSessionInterruptionReasonKey] as? NSNumber,
          let reason = AVCaptureSession.InterruptionReason(rawValue: reasonValue.intValue) else {
        return "unknown interruption"
    }

    switch reason {
    case .audioDeviceInUseByAnotherClient:
        return "audio in use by another app"
    case .videoDeviceInUseByAnotherClient:
        return "camera in use by another app"
    case .videoDeviceNotAvailableInBackground:
        return "camera unavailable in background"
    case .videoDeviceNotAvailableWithMultipleForegroundApps:
        return "camera unavailable with multiple foreground apps"
    case .videoDeviceNotAvailableDueToSystemPressure:
        return "camera unavailable due to system pressure"
    case .sensitiveContentMitigationActivated:
        return "camera unavailable due to sensitive content mitigation"
    @unknown default:
        return "unrecognized interruption"
    }
}

private func sessionRuntimeErrorDescription(from userInfo: [AnyHashable: Any]?) -> String {
    if let userInfo,
       let error = userInfo[AVCaptureSessionErrorKey] as? NSError {
        return error.localizedDescription
    }
    return "unknown runtime error"
}
#endif

protocol CameraRollSaving: Sendable {
    func saveCapturePayload(
        _ payload: CapturedPhotoPayload,
        requestedFormat: CapturePhotoFormat
    ) async throws -> CameraRollSaveResult
    func deleteAssets(localIdentifiers: [String]) async throws -> Int
}

struct CameraRollSaveResult: Sendable, Equatable {
    let primaryLocalIdentifier: String
    let pairedLocalIdentifier: String?

    var localIdentifiers: [String] {
        var identifiers = [primaryLocalIdentifier]
        if let pairedLocalIdentifier {
            identifiers.append(pairedLocalIdentifier)
        }
        return identifiers
    }
}

protocol StorageMonitoring: Sendable {
    func currentAvailableCapacityForImportantUsage() -> Int64?
}

struct DeviceStorageMonitor: StorageMonitoring {
    func currentAvailableCapacityForImportantUsage() -> Int64? {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey]
        guard let values = try? homeURL.resourceValues(forKeys: keys) else {
            return nil
        }
        return values.volumeAvailableCapacityForImportantUsage
    }
}

#if canImport(Photos)
private struct SystemCameraRollSaver: CameraRollSaving {
    func saveCapturePayload(
        _ payload: CapturedPhotoPayload,
        requestedFormat: CapturePhotoFormat
    ) async throws -> CameraRollSaveResult {
        let status = await authorizationStatus()
        switch status {
        case .authorized, .limited:
            break
        case .restricted:
            throw CameraRollSaveError.accessRestricted
        case .denied, .notDetermined:
            throw CameraRollSaveError.accessDenied
        @unknown default:
            throw CameraRollSaveError.accessDenied
        }

        switch requestedFormat {
        case .processed:
            guard let data = payload.processedData ?? payload.rawData else {
                throw CameraRollSaveError.missingCaptureData
            }
            let localIdentifier = try await saveSingleAsset(data: data, format: .processed)
            return CameraRollSaveResult(
                primaryLocalIdentifier: localIdentifier,
                pairedLocalIdentifier: nil
            )

        case .raw:
            guard let rawData = payload.rawData else {
                throw CameraRollSaveError.missingCaptureData
            }
            guard let processedData = payload.processedData else {
                throw CameraRollSaveError.missingCaptureData
            }

            var rawLocalIdentifier: String?
            var processedLocalIdentifier: String?

            do {
                try await PHPhotoLibrary.shared().performChanges { [rawData, processedData] in
                    let rawRequest = PHAssetCreationRequest.forAsset()
                    rawRequest.addResource(
                        with: .photo,
                        data: rawData,
                        options: makeCreationOptions(format: .raw)
                    )
                    rawLocalIdentifier = rawRequest.placeholderForCreatedAsset?.localIdentifier

                    let processedRequest = PHAssetCreationRequest.forAsset()
                    processedRequest.addResource(
                        with: .photo,
                        data: processedData,
                        options: makeCreationOptions(format: .processed)
                    )
                    processedLocalIdentifier = processedRequest.placeholderForCreatedAsset?.localIdentifier
                }
            } catch {
                throw CameraRollSaveError.saveFailed
            }

            guard let rawLocalIdentifier, let processedLocalIdentifier else {
                throw CameraRollSaveError.saveFailed
            }

            return CameraRollSaveResult(
                primaryLocalIdentifier: rawLocalIdentifier,
                pairedLocalIdentifier: processedLocalIdentifier
            )
        case .appleProRAW:
            guard let rawData = payload.rawData else {
                throw CameraRollSaveError.missingCaptureData
            }
            let localIdentifier = try await saveSingleAsset(data: rawData, format: .appleProRAW)
            return CameraRollSaveResult(
                primaryLocalIdentifier: localIdentifier,
                pairedLocalIdentifier: nil
            )
        }
    }

    private func saveSingleAsset(data: Data, format: CapturePhotoFormat) async throws -> String {
        var localIdentifier: String?
        do {
            try await PHPhotoLibrary.shared().performChanges { [data] in
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: makeCreationOptions(format: format))
                localIdentifier = request.placeholderForCreatedAsset?.localIdentifier
            }
        } catch {
            throw CameraRollSaveError.saveFailed
        }

        guard let localIdentifier else {
            throw CameraRollSaveError.saveFailed
        }

        return localIdentifier
    }

    private func makeCreationOptions(format: CapturePhotoFormat) -> PHAssetResourceCreationOptions {
        let options = PHAssetResourceCreationOptions()
        let timestamp = Self.filenameTimestampFormatter.string(from: Date())

        switch format {
        case .processed:
            options.originalFilename = "Photodew-\(timestamp).jpg"
            #if canImport(UniformTypeIdentifiers)
            if #available(iOS 26, *) {
                options.contentType = .jpeg
            } else {
                options.uniformTypeIdentifier = "public.jpeg"
            }
            #endif
        case .raw:
            options.originalFilename = "Photodew-\(timestamp).dng"
            #if canImport(UniformTypeIdentifiers)
            if #available(iOS 26, *) {
                options.contentType = .dng
            } else {
                options.uniformTypeIdentifier = "com.adobe.raw-image"
            }
            #endif
        case .appleProRAW:
            options.originalFilename = "Photodew-\(timestamp)-pro.dng"
            #if canImport(UniformTypeIdentifiers)
            if #available(iOS 26, *) {
                options.contentType = .dng
            } else {
                options.uniformTypeIdentifier = "com.adobe.raw-image"
            }
            #endif
        }

        return options
    }

    private func authorizationStatus() async -> PHAuthorizationStatus {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard currentStatus == .notDetermined else { return currentStatus }
        return await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    }

    func deleteAssets(localIdentifiers: [String]) async throws -> Int {
        let uniqueIdentifiers = Array(Set(localIdentifiers))
        guard !uniqueIdentifiers.isEmpty else { return 0 }

        let status = await cleanupAuthorizationStatus()
        switch status {
        case .authorized, .limited:
            break
        case .restricted:
            throw CameraRollSaveError.cleanupAccessRestricted
        case .denied, .notDetermined:
            throw CameraRollSaveError.cleanupAccessDenied
        @unknown default:
            throw CameraRollSaveError.cleanupAccessDenied
        }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: uniqueIdentifiers, options: nil)
        guard fetchResult.count > 0 else {
            return 0
        }

        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets as NSArray)
            }
        } catch {
            throw CameraRollSaveError.cleanupFailed
        }

        return assets.count
    }

    private func cleanupAuthorizationStatus() async -> PHAuthorizationStatus {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard currentStatus == .notDetermined else { return currentStatus }
        return await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    private static let filenameTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
#else
private struct SystemCameraRollSaver: CameraRollSaving {
    func saveCapturePayload(
        _ payload: CapturedPhotoPayload,
        requestedFormat: CapturePhotoFormat
    ) async throws -> CameraRollSaveResult {
        throw CameraRollSaveError.unavailable
    }

    func deleteAssets(localIdentifiers: [String]) async throws -> Int {
        throw CameraRollSaveError.unavailable
    }
}
#endif

private enum CameraRollSaveError: LocalizedError {
    case accessDenied
    case accessRestricted
    case saveFailed
    case missingCaptureData
    case cleanupAccessDenied
    case cleanupAccessRestricted
    case cleanupFailed
    case unavailable

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            "Photos access denied. Enable Photos access in Settings to save captures."
        case .accessRestricted:
            "Photos access is restricted by system policy."
        case .saveFailed:
            "Could not save the photo to Photos."
        case .missingCaptureData:
            "Capture data was incomplete. Try capturing again."
        case .cleanupAccessDenied:
            "Photos cleanup requires read-write Photos permission. Enable it in Settings."
        case .cleanupAccessRestricted:
            "Photos cleanup is restricted by system policy."
        case .cleanupFailed:
            "Could not delete saved photos during cleanup."
        case .unavailable:
            "Saving to Photos is unavailable on this device."
        }
    }
}
