import Foundation

public enum FocusControlMode: String, Equatable, Sendable {
    case auto
    case locked
}

public enum FocusControlState: Equatable, Sendable {
    case auto
    case locked(lensPosition: Double)

    public var mode: FocusControlMode {
        switch self {
        case .auto:
            return .auto
        case .locked:
            return .locked
        }
    }

    public var lensPosition: Double? {
        switch self {
        case .auto:
            return nil
        case let .locked(lensPosition):
            return lensPosition
        }
    }
}

public enum FocusStateTransition: Equatable, Sendable {
    case setAuto
    case lock(lensPosition: Double)
}

public enum FocusStateMachineError: Error, Equatable, LocalizedError {
    case invalidLensPosition(Double)

    public var errorDescription: String? {
        switch self {
        case let .invalidLensPosition(position):
            return "Focus lens position must be between 0 and 1. Received \(position)."
        }
    }
}

public struct FocusStateMachine: Equatable, Sendable {
    public private(set) var state: FocusControlState

    public init(initialState: FocusControlState = .auto) {
        self.state = initialState
    }

    @discardableResult
    public mutating func apply(_ transition: FocusStateTransition) throws -> FocusControlState {
        switch transition {
        case .setAuto:
            state = .auto
        case let .lock(lensPosition):
            state = .locked(lensPosition: try Self.validated(lensPosition: lensPosition))
        }
        return state
    }

    private static func validated(lensPosition: Double) throws -> Double {
        guard lensPosition.isFinite, lensPosition >= 0, lensPosition <= 1 else {
            throw FocusStateMachineError.invalidLensPosition(lensPosition)
        }
        return lensPosition
    }
}
