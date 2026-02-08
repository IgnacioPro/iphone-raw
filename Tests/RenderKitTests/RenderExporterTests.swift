import Foundation
import CoreImage
import ImageIO
import RenderKit
import Testing

@Suite("RenderExporter")
struct RenderExporterTests {

    // MARK: - RenderExportError

    @Test("RenderExportError has human-readable descriptions")
    func errorDescriptions() {
        #expect(RenderExportError.jpegExportFailed.errorDescription != nil)
        #expect(RenderExportError.tiffExportFailed.errorDescription != nil)
    }

    @Test("RenderExportError is Equatable")
    func errorEquatable() {
        #expect(RenderExportError.jpegExportFailed == RenderExportError.jpegExportFailed)
        #expect(RenderExportError.jpegExportFailed != RenderExportError.tiffExportFailed)
    }

    // MARK: - RenderExporting protocol conformance

    @Test("RenderExporter conforms to RenderExporting protocol")
    func protocolConformance() {
        let exporter = RenderExporter()
        let _: any RenderExporting = exporter
    }

    // MARK: - JPEG export from synthetic CIImage

    @Test("JPEG export produces valid data from a solid-color CIImage")
    func jpegExportFromSyntheticImage() async throws {
        let exporter = RenderExporter()
        let image = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5))
            .cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))
        let result = RenderResult(
            image: image,
            width: 100,
            height: 100,
            profile: .neutral,
            renderDuration: 0.1,
            initializationDuration: 0.05
        )

        let jpegData = try await exporter.exportJPEG(from: result, quality: 0.9)

        #expect(!jpegData.isEmpty)
        // JPEG files start with 0xFF 0xD8 (SOI marker)
        #expect(jpegData[0] == 0xFF)
        #expect(jpegData[1] == 0xD8)
    }

    @Test("JPEG export clamps quality to valid range")
    func jpegQualityClamping() async throws {
        let exporter = RenderExporter()
        let image = CIImage(color: CIColor(red: 1, green: 0, blue: 0))
            .cropped(to: CGRect(x: 0, y: 0, width: 50, height: 50))
        let result = RenderResult(
            image: image,
            width: 50,
            height: 50,
            profile: .neutral,
            renderDuration: 0.1,
            initializationDuration: 0.05
        )

        // Quality below 0 and above 1 should not crash
        let lowQuality = try await exporter.exportJPEG(from: result, quality: -0.5)
        let highQuality = try await exporter.exportJPEG(from: result, quality: 2.0)

        #expect(!lowQuality.isEmpty)
        #expect(!highQuality.isEmpty)
    }

    // MARK: - TIFF export from synthetic CIImage

    @Test("TIFF export produces valid data from a solid-color CIImage")
    func tiffExportFromSyntheticImage() async throws {
        let exporter = RenderExporter()
        let image = CIImage(color: CIColor(red: 0.2, green: 0.6, blue: 0.8))
            .cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))
        let result = RenderResult(
            image: image,
            width: 100,
            height: 100,
            profile: .neutral,
            renderDuration: 0.1,
            initializationDuration: 0.05
        )

        let tiffData = try await exporter.exportTIFF(from: result)

        #expect(!tiffData.isEmpty)
        // TIFF files start with either "II" (little-endian) or "MM" (big-endian)
        let firstTwo = [tiffData[0], tiffData[1]]
        let isLittleEndian = firstTwo == [0x49, 0x49] // "II"
        let isBigEndian = firstTwo == [0x4D, 0x4D]    // "MM"
        #expect(isLittleEndian || isBigEndian)
    }

    @Test("Exported JPEG and TIFF include profile metadata markers")
    func exportMetadataMarkers() async throws {
        let exporter = RenderExporter()
        let image = CIImage(color: CIColor(red: 0.1, green: 0.2, blue: 0.3))
            .cropped(to: CGRect(x: 0, y: 0, width: 120, height: 120))
        let result = RenderResult(
            image: image,
            width: 120,
            height: 120,
            profile: .neutral,
            renderDuration: 0.1,
            initializationDuration: 0.05
        )

        let jpegData = try await exporter.exportJPEG(from: result, quality: 0.9)
        let tiffData = try await exporter.exportTIFF(from: result)

        let jpegProperties = try imageProperties(from: jpegData)
        let tiffProperties = try imageProperties(from: tiffData)

        let jpegExif = jpegProperties[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let jpegComment = jpegExif?[kCGImagePropertyExifUserComment as String] as? String
        #expect(jpegComment?.contains("profile=neutral") == true)

        let tiffDictionary = tiffProperties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        let software = tiffDictionary?[kCGImagePropertyTIFFSoftware as String] as? String
        #expect(software == "Photodew")
    }

    private func imageProperties(from data: Data) throws -> [String: Any] {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            throw NSError(domain: "RenderExporterTests", code: 1, userInfo: nil)
        }
        return properties
    }
}
