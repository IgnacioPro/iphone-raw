import Foundation

/// Defines how a RAW DNG file should be rendered.
///
/// Currently only `.neutral` is supported, which applies minimal processing
/// to approximate the sensor's unprocessed output (Process Zero philosophy).
/// Future profiles (`.classic`, `.punch`) can be added as additional cases.
public enum RenderingProfile: String, Equatable, Sendable, CaseIterable {
    /// Flat, neutral render: all noise reduction, sharpening, tone mapping,
    /// and boost disabled. As-shot white balance from DNG metadata.
    case neutral
}

extension RenderingProfile {
    /// Human-readable display name for UI labels.
    public var displayName: String {
        switch self {
        case .neutral:
            return "Neutral"
        }
    }
}
