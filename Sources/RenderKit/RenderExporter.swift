import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import os

// MARK: - Protocol

/// Abstraction for exporting rendered RAW images to standard formats.
public protocol RenderExporting: Sendable {
    /// Export a rendered image as JPEG data.
    ///
    /// - Parameters:
    ///   - result: The render result containing the `CIImage` to export.
    ///   - quality: JPEG quality from 0.0 (maximum compression) to 1.0 (maximum quality).
    /// - Returns: JPEG file data with embedded ICC profile and metadata.
    func exportJPEG(from result: RenderResult, quality: Float) async throws -> Data

    /// Export a rendered image as 16-bit TIFF data.
    ///
    /// - Parameters:
    ///   - result: The render result containing the `CIImage` to export.
    /// - Returns: TIFF file data with embedded ICC profile and metadata.
    func exportTIFF(from result: RenderResult) async throws -> Data
}

// MARK: - Errors

public enum RenderExportError: Error, Equatable, LocalizedError {
    case jpegExportFailed
    case tiffExportFailed

    public var errorDescription: String? {
        switch self {
        case .jpegExportFailed:
            return "Failed to export rendered image as JPEG."
        case .tiffExportFailed:
            return "Failed to export rendered image as TIFF."
        }
    }
}

// MARK: - Implementation

/// Exports rendered `CIImage` results to JPEG and TIFF formats
/// with Display P3 color space and embedded metadata.
public actor RenderExporter: RenderExporting {
    private let context: CIContext
    private let signposter: OSSignposter
    private let logger: Logger

    /// The color space used for exported files.
    /// Display P3 provides the wide gamut that iPhone cameras capture.
    private let exportColorSpace: CGColorSpace

    public init() {
        self.context = CIContext(options: [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.linearSRGB)!,
            .highQualityDownsample: true,
        ])
        self.exportColorSpace = CGColorSpace(name: CGColorSpace.displayP3)!
        self.signposter = OSSignposter(subsystem: "com.photodew.renderkit", category: "RenderExporter")
        self.logger = Logger(subsystem: "com.photodew.renderkit", category: "RenderExporter")
    }

    public func exportJPEG(from result: RenderResult, quality: Float) async throws -> Data {
        let state = signposter.beginInterval("exportJPEG", id: signposter.makeSignpostID())
        defer { signposter.endInterval("exportJPEG", state) }
        let start = ContinuousClock.now

        let clampedQuality = max(0, min(1, quality))
        logger.info(
            "raw_export_started format=jpeg profile=\(result.profile.rawValue, privacy: .public) width=\(result.width) height=\(result.height)"
        )

        let exportProperties = exportMetadata(for: result, fileType: "jpeg")

        guard let data = context.jpegRepresentation(
            of: result.image,
            colorSpace: exportColorSpace,
            options: [
                kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: clampedQuality,
            ]
        ) else {
            logger.error("raw_export_failed format=jpeg profile=\(result.profile.rawValue, privacy: .public)")
            throw RenderExportError.jpegExportFailed
        }

        guard let taggedData = injectingMetadata(into: data, properties: exportProperties) else {
            logger.error("raw_export_failed format=jpeg reason=metadata_injection profile=\(result.profile.rawValue, privacy: .public)")
            throw RenderExportError.jpegExportFailed
        }

        let durationMs = Int(start.duration(to: ContinuousClock.now).timeInterval * 1000)
        logger.info(
            "raw_export_completed format=jpeg profile=\(result.profile.rawValue, privacy: .public) bytes=\(taggedData.count) duration_ms=\(durationMs)"
        )

        return taggedData
    }

    public func exportTIFF(from result: RenderResult) async throws -> Data {
        let state = signposter.beginInterval("exportTIFF", id: signposter.makeSignpostID())
        defer { signposter.endInterval("exportTIFF", state) }
        let start = ContinuousClock.now
        logger.info(
            "raw_export_started format=tiff profile=\(result.profile.rawValue, privacy: .public) width=\(result.width) height=\(result.height)"
        )

        let exportProperties = exportMetadata(for: result, fileType: "tiff")

        guard let data = context.tiffRepresentation(
            of: result.image,
            format: .RGBA16,
            colorSpace: exportColorSpace,
            options: [:]
        ) else {
            logger.error("raw_export_failed format=tiff profile=\(result.profile.rawValue, privacy: .public)")
            throw RenderExportError.tiffExportFailed
        }

        guard let taggedData = injectingMetadata(into: data, properties: exportProperties) else {
            logger.error("raw_export_failed format=tiff reason=metadata_injection profile=\(result.profile.rawValue, privacy: .public)")
            throw RenderExportError.tiffExportFailed
        }

        let durationMs = Int(start.duration(to: ContinuousClock.now).timeInterval * 1000)
        logger.info(
            "raw_export_completed format=tiff profile=\(result.profile.rawValue, privacy: .public) bytes=\(taggedData.count) duration_ms=\(durationMs)"
        )

        return taggedData
    }

    private func exportMetadata(for result: RenderResult, fileType: String) -> [CFString: Any] {
        let tiff: [CFString: Any] = [
            kCGImagePropertyTIFFSoftware: "Photodew",
            kCGImagePropertyTIFFArtist: "Photodew RenderKit",
        ]
        let exif: [CFString: Any] = [
            kCGImagePropertyExifUserComment: "Photodew RAW render profile=\(result.profile.rawValue) format=\(fileType)",
        ]

        return [
            kCGImagePropertyProfileName: result.profile.displayName,
            kCGImagePropertyTIFFDictionary: tiff,
            kCGImagePropertyExifDictionary: exif,
        ]
    }

    private func injectingMetadata(into data: Data, properties: [CFString: Any]) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let sourceType = CGImageSourceGetType(source) else {
            return nil
        }

        let destinationData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(destinationData, sourceType, 1, nil) else {
            return nil
        }

        CGImageDestinationAddImageFromSource(destination, source, 0, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return destinationData as Data
    }
}
