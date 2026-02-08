import CoreImage
import Foundation
import os

#if canImport(CoreImage.CIRAWFilter)
import CoreImage.CIRAWFilter
#endif

// MARK: - Protocol

/// Abstraction for RAW DNG rendering, enabling test doubles.
public protocol RawRendering: Sendable {
    /// Render DNG data with the specified profile.
    ///
    /// - Parameters:
    ///   - dngData: Raw DNG file data (True RAW Bayer or Apple ProRAW).
    ///   - profile: The rendering profile to apply.
    ///   - targetSize: Optional maximum dimension for the rendered output.
    ///                 If `nil`, renders at full sensor resolution.
    /// - Returns: A `RenderResult` containing the rendered `CIImage` and timing.
    func render(dngData: Data, profile: RenderingProfile, targetSize: CGSize?) async throws -> RenderResult
}

extension RawRendering {
    /// Convenience overload that renders at full resolution.
    public func render(dngData: Data, profile: RenderingProfile) async throws -> RenderResult {
        try await render(dngData: dngData, profile: profile, targetSize: nil)
    }
}

// MARK: - Errors

public enum RawRenderError: Error, Equatable, LocalizedError {
    case filterInitializationFailed
    case renderFailed
    case emptyDNGData

    public var errorDescription: String? {
        switch self {
        case .filterInitializationFailed:
            return "Failed to initialize RAW filter from DNG data."
        case .renderFailed:
            return "Failed to render RAW image."
        case .emptyDNGData:
            return "DNG data is empty."
        }
    }
}

// MARK: - Implementation

/// Core RAW rendering engine backed by `CIRAWFilter`.
///
/// Processes DNG data captured by `CaptureSessionService` and produces
/// a `CIImage` with the specified rendering profile applied.
///
/// Thread safety is provided by the actor model — `CIRAWFilter` is not
/// thread-safe, but `CIContext` is reused across renders for efficiency.
public actor RawRenderer: RawRendering {
    private let context: CIContext
    private let signposter: OSSignposter
    private let logger: Logger

    public init() {
        // Use a GPU-backed context with linear sRGB working color space
        // for predictable, consistent output across devices.
        self.context = CIContext(options: [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.linearSRGB)!,
            .highQualityDownsample: true,
        ])
        self.signposter = OSSignposter(subsystem: "com.photodew.renderkit", category: "RawRenderer")
        self.logger = Logger(subsystem: "com.photodew.renderkit", category: "RawRenderer")
    }

    public func render(dngData: Data, profile: RenderingProfile, targetSize: CGSize?) async throws -> RenderResult {
        guard !dngData.isEmpty else {
            throw RawRenderError.emptyDNGData
        }

        let state = signposter.beginInterval("render", id: signposter.makeSignpostID())
        defer { signposter.endInterval("render", state) }

        let targetWidth = targetSize.map { Int($0.width) } ?? -1
        let targetHeight = targetSize.map { Int($0.height) } ?? -1
        logger.info(
            "raw_render_started profile=\(profile.rawValue, privacy: .public) dng_bytes=\(dngData.count) target_width=\(targetWidth) target_height=\(targetHeight)"
        )

        // Phase 1: Initialize CIRAWFilter from DNG data
        let initStart = ContinuousClock.now

        guard let filter = createRAWFilter(from: dngData) else {
            logger.error("raw_render_failed reason=filter_init profile=\(profile.rawValue, privacy: .public)")
            throw RawRenderError.filterInitializationFailed
        }

        applyProfile(profile, to: filter)

        let initEnd = ContinuousClock.now
        let initDuration = initStart.duration(to: initEnd)

        // Phase 2: Produce rendered CIImage
        let renderStart = ContinuousClock.now

        guard var outputImage = filter.outputImage else {
            logger.error("raw_render_failed reason=missing_output_image profile=\(profile.rawValue, privacy: .public)")
            throw RawRenderError.renderFailed
        }

        let extent = outputImage.extent
        // CIRAWFilter may produce a degenerate image (0x0 or infinite extent)
        // for invalid/corrupt DNG data. Treat this as a render failure.
        guard extent.width > 0, extent.height > 0,
              extent.width.isFinite, extent.height.isFinite else {
            logger.error(
                "raw_render_failed reason=invalid_extent profile=\(profile.rawValue, privacy: .public) extent_width=\(extent.width) extent_height=\(extent.height)"
            )
            throw RawRenderError.renderFailed
        }

        // Scale down if a target size is specified
        if let targetSize {
            outputImage = scaleToFit(outputImage, within: targetSize)
        }

        let width = Int(outputImage.extent.width)
        let height = Int(outputImage.extent.height)

        let renderEnd = ContinuousClock.now
        let renderDuration = renderStart.duration(to: renderEnd)
        let initDurationMs = Int(initDuration.timeInterval * 1000)
        let renderDurationMs = Int(renderDuration.timeInterval * 1000)
        let totalDurationMs = initDurationMs + renderDurationMs
        logger.info(
            "raw_render_completed profile=\(profile.rawValue, privacy: .public) render_width=\(width) render_height=\(height) init_duration_ms=\(initDurationMs) render_duration_ms=\(renderDurationMs) total_duration_ms=\(totalDurationMs)"
        )

        return RenderResult(
            image: outputImage,
            width: width,
            height: height,
            profile: profile,
            renderDuration: renderDuration.timeInterval,
            initializationDuration: initDuration.timeInterval
        )
    }

    // MARK: - Private

    private func createRAWFilter(from dngData: Data) -> CIRAWFilter? {
        CIRAWFilter(imageData: dngData, identifierHint: "com.adobe.raw-image")
    }

    /// Apply the rendering profile settings to the CIRAWFilter.
    private func applyProfile(_ profile: RenderingProfile, to filter: CIRAWFilter) {
        switch profile {
        case .neutral:
            applyNeutralProfile(to: filter)
        }
    }

    /// Neutral profile: disable all processing to approximate the raw sensor output.
    /// White balance and baseline exposure use the DNG-embedded (as-shot) values.
    private func applyNeutralProfile(to filter: CIRAWFilter) {
        // Disable boost (shadow lift and general boost)
        filter.boostAmount = 0
        filter.boostShadowAmount = 0

        // Disable all noise reduction
        filter.luminanceNoiseReductionAmount = 0
        filter.colorNoiseReductionAmount = 0

        // Disable sharpening
        filter.sharpnessAmount = 0

        // Disable local tone mapping (iOS 17+)
        filter.localToneMapAmount = 0

        // No HDR headroom
        filter.extendedDynamicRangeAmount = 0

        // No exposure compensation — use the DNG baseline exposure as-is
        filter.exposure = 0

        // White balance: leave neutralChromaticity/neutralTemperature/neutralTint
        // at their defaults, which reads from the DNG's as-shot WB tags.
        // This gives us the scene-accurate white balance the sensor recorded.
    }

    /// Scale an image to fit within the target size while maintaining aspect ratio.
    private func scaleToFit(_ image: CIImage, within targetSize: CGSize) -> CIImage {
        let extent = image.extent
        guard extent.width > 0, extent.height > 0 else { return image }

        let scaleX = targetSize.width / extent.width
        let scaleY = targetSize.height / extent.height
        let scale = min(scaleX, scaleY)

        // Only downscale, never upscale
        guard scale < 1.0 else { return image }

        return image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }
}

// MARK: - Duration Extension

extension Duration {
    /// Convert `Duration` to `TimeInterval` (seconds as Double).
    var timeInterval: TimeInterval {
        let (seconds, attoseconds) = self.components
        return Double(seconds) + Double(attoseconds) * 1e-18
    }
}
