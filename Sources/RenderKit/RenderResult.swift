import CoreImage
import Foundation

/// The output of a RAW rendering pass.
///
/// Contains the rendered image, timing information, and metadata about
/// what profile was applied and the source DNG's technical metadata.
public struct RenderResult: Sendable {
    /// The rendered image. Use `CIContext` to convert to `CGImage` or export data.
    public let image: CIImage

    /// The pixel dimensions of the rendered output.
    public let width: Int
    public let height: Int

    /// The rendering profile that was applied.
    public let profile: RenderingProfile

    /// Wall-clock time for the render pass, in seconds.
    public let renderDuration: TimeInterval

    /// Wall-clock time to initialize the CIRAWFilter (DNG parsing), in seconds.
    public let initializationDuration: TimeInterval

    public init(
        image: CIImage,
        width: Int,
        height: Int,
        profile: RenderingProfile,
        renderDuration: TimeInterval,
        initializationDuration: TimeInterval
    ) {
        self.image = image
        self.width = width
        self.height = height
        self.profile = profile
        self.renderDuration = renderDuration
        self.initializationDuration = initializationDuration
    }

    /// Total time from DNG load to rendered CIImage, in seconds.
    public var totalDuration: TimeInterval {
        initializationDuration + renderDuration
    }

    /// Total duration in milliseconds, for logging convenience.
    public var totalDurationMilliseconds: Int {
        Int(totalDuration * 1000)
    }
}
