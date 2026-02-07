import Foundation

public struct LuminanceHistogram: Equatable, Sendable {
    public static let defaultBinCount = 64

    public let bins: [UInt32]
    public let sampleCount: UInt32
    public let generatedAt: Date

    public init(
        bins: [UInt32],
        sampleCount: UInt32,
        generatedAt: Date = Date()
    ) {
        self.bins = bins
        self.sampleCount = sampleCount
        self.generatedAt = generatedAt
    }

    public static func empty(binCount: Int = defaultBinCount) -> LuminanceHistogram {
        let resolvedBinCount = max(1, binCount)
        return LuminanceHistogram(
            bins: Array(repeating: 0, count: resolvedBinCount),
            sampleCount: 0
        )
    }

    public var normalizedBins: [Double] {
        let maxCount = bins.max() ?? 0
        guard maxCount > 0 else {
            return bins.map { _ in 0 }
        }

        let denominator = Double(maxCount)
        return bins.map { Double($0) / denominator }
    }
}
