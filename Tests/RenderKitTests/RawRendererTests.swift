import Foundation
import RenderKit
import Testing
import CoreImage

@Suite("RawRenderer")
struct RawRendererTests {

    // MARK: - RenderingProfile

    @Test("RenderingProfile has expected display names")
    func profileDisplayNames() {
        #expect(RenderingProfile.neutral.displayName == "Neutral")
    }

    @Test("RenderingProfile raw value round-trips")
    func profileRawValue() {
        #expect(RenderingProfile(rawValue: "neutral") == .neutral)
        #expect(RenderingProfile(rawValue: "invalid") == nil)
    }

    @Test("RenderingProfile allCases contains only neutral")
    func profileAllCases() {
        #expect(RenderingProfile.allCases == [.neutral])
    }

    // MARK: - RenderResult

    @Test("RenderResult totalDuration combines init and render durations")
    func resultTotalDuration() {
        let image = CIImage.empty()
        let result = RenderResult(
            image: image,
            width: 4032,
            height: 3024,
            profile: .neutral,
            renderDuration: 0.35,
            initializationDuration: 0.15
        )

        #expect(result.totalDuration == 0.5)
        #expect(result.totalDurationMilliseconds == 500)
        #expect(result.width == 4032)
        #expect(result.height == 3024)
        #expect(result.profile == .neutral)
    }

    @Test("RenderResult totalDurationMilliseconds rounds correctly")
    func resultMillisecondRounding() {
        let result = RenderResult(
            image: CIImage.empty(),
            width: 100,
            height: 100,
            profile: .neutral,
            renderDuration: 0.4567,
            initializationDuration: 0.1234
        )

        #expect(result.totalDurationMilliseconds == 580)
    }

    // MARK: - RawRenderError

    @Test("RawRenderError has human-readable descriptions")
    func errorDescriptions() {
        #expect(RawRenderError.emptyDNGData.errorDescription != nil)
        #expect(RawRenderError.filterInitializationFailed.errorDescription != nil)
        #expect(RawRenderError.renderFailed.errorDescription != nil)
    }

    @Test("RawRenderError is Equatable")
    func errorEquatable() {
        #expect(RawRenderError.emptyDNGData == RawRenderError.emptyDNGData)
        #expect(RawRenderError.emptyDNGData != RawRenderError.renderFailed)
    }

    // MARK: - RawRenderer (error paths)

    @Test("RawRenderer rejects empty DNG data")
    func rendererRejectsEmptyData() async {
        let renderer = RawRenderer()

        await #expect(throws: RawRenderError.emptyDNGData) {
            try await renderer.render(dngData: Data(), profile: .neutral)
        }
    }

    @Test("RawRenderer rejects invalid DNG data")
    func rendererRejectsInvalidData() async {
        let renderer = RawRenderer()
        let garbage = Data([0xDE, 0xAD, 0xBE, 0xEF])

        // CIRAWFilter accepts arbitrary data but produces a degenerate (0x0) image.
        // The renderer detects this and throws renderFailed.
        await #expect(throws: RawRenderError.renderFailed) {
            try await renderer.render(dngData: garbage, profile: .neutral)
        }
    }

    // MARK: - RawRendering protocol conformance

    @Test("RawRenderer conforms to RawRendering protocol")
    func protocolConformance() {
        let renderer = RawRenderer()
        let _: any RawRendering = renderer
    }

    @Test("RawRendering default targetSize parameter is nil")
    func defaultTargetSizeIsNil() async {
        let stub = StubRawRenderer()
        _ = try? await stub.render(dngData: Data([0x01]), profile: .neutral)
        #expect(stub.lastTargetSize == nil)
    }
}

// MARK: - Test Doubles

/// Stub renderer for testing protocol conformance and default parameter behavior.
final class StubRawRenderer: RawRendering, @unchecked Sendable {
    var lastTargetSize: CGSize?
    var shouldThrow = false

    func render(dngData: Data, profile: RenderingProfile, targetSize: CGSize?) async throws -> RenderResult {
        lastTargetSize = targetSize
        if shouldThrow {
            throw RawRenderError.renderFailed
        }
        return RenderResult(
            image: CIImage.empty(),
            width: 100,
            height: 100,
            profile: profile,
            renderDuration: 0.1,
            initializationDuration: 0.05
        )
    }
}
