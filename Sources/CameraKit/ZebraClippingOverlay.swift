import Foundation

public struct ZebraClippingOverlay: Equatable, Sendable {
    public static let defaultColumnCount = 48
    public static let defaultRowCount = 27

    public let columnCount: Int
    public let rowCount: Int
    public let clippedCells: [UInt8]
    public let threshold: Double
    public let generatedAt: Date

    public init(
        columnCount: Int,
        rowCount: Int,
        clippedCells: [UInt8],
        threshold: Double,
        generatedAt: Date = Date()
    ) {
        self.columnCount = max(columnCount, 1)
        self.rowCount = max(rowCount, 1)
        let expectedCellCount = self.columnCount * self.rowCount
        if clippedCells.count == expectedCellCount {
            self.clippedCells = clippedCells.map { $0 > 0 ? 1 : 0 }
        } else {
            self.clippedCells = Array(repeating: 0, count: expectedCellCount)
        }
        self.threshold = min(max(threshold, 0), 1)
        self.generatedAt = generatedAt
    }

    public var clippedCellCount: Int {
        clippedCells.reduce(0) { partialResult, value in
            partialResult + (value > 0 ? 1 : 0)
        }
    }

    public var clippedRatio: Double {
        guard !clippedCells.isEmpty else { return 0 }
        return Double(clippedCellCount) / Double(clippedCells.count)
    }

    public func isCellClipped(column: Int, row: Int) -> Bool {
        guard column >= 0,
              column < columnCount,
              row >= 0,
              row < rowCount else {
            return false
        }
        let index = row * columnCount + column
        return clippedCells[index] > 0
    }
}

public typealias ZebraClippingOverlayHandler = @Sendable (ZebraClippingOverlay) -> Void
