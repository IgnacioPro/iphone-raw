import Foundation

public struct FocusPeakingOverlay: Equatable, Sendable {
    public static let defaultColumnCount = 48
    public static let defaultRowCount = 27

    public let columnCount: Int
    public let rowCount: Int
    public let peakCells: [UInt8]
    public let threshold: Double
    public let generatedAt: Date

    public init(
        columnCount: Int,
        rowCount: Int,
        peakCells: [UInt8],
        threshold: Double,
        generatedAt: Date = Date()
    ) {
        self.columnCount = max(columnCount, 1)
        self.rowCount = max(rowCount, 1)
        let expectedCellCount = self.columnCount * self.rowCount
        if peakCells.count == expectedCellCount {
            self.peakCells = peakCells.map { $0 > 0 ? 1 : 0 }
        } else {
            self.peakCells = Array(repeating: 0, count: expectedCellCount)
        }
        self.threshold = min(max(threshold, 0), 1)
        self.generatedAt = generatedAt
    }

    public var peakedCellCount: Int {
        peakCells.reduce(0) { partialResult, value in
            partialResult + (value > 0 ? 1 : 0)
        }
    }

    public var peakedRatio: Double {
        guard !peakCells.isEmpty else { return 0 }
        return Double(peakedCellCount) / Double(peakCells.count)
    }

    public func isCellPeaked(column: Int, row: Int) -> Bool {
        guard column >= 0,
              column < columnCount,
              row >= 0,
              row < rowCount else {
            return false
        }
        let index = row * columnCount + column
        return peakCells[index] > 0
    }
}

public typealias FocusPeakingOverlayHandler = @Sendable (FocusPeakingOverlay) -> Void
