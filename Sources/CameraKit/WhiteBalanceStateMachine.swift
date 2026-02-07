import Foundation

public struct WhiteBalanceValues: Equatable, Sendable {
    public let temperatureKelvin: Double
    public let tint: Double

    public init(
        temperatureKelvin: Double,
        tint: Double
    ) {
        self.temperatureKelvin = temperatureKelvin
        self.tint = tint
    }
}

public enum WhiteBalanceControlMode: String, Equatable, Sendable {
    case auto
    case locked
}

public enum WhiteBalanceControlState: Equatable, Sendable {
    case auto
    case locked(WhiteBalanceValues)

    public var mode: WhiteBalanceControlMode {
        switch self {
        case .auto:
            return .auto
        case .locked:
            return .locked
        }
    }

    public var values: WhiteBalanceValues? {
        switch self {
        case .auto:
            return nil
        case let .locked(values):
            return values
        }
    }
}

public enum WhiteBalanceStateTransition: Equatable, Sendable {
    case setAuto
    case lock(WhiteBalanceValues)
}

public enum WhiteBalanceStateMachineError: Error, Equatable, LocalizedError {
    case invalidTemperatureKelvin(Double)
    case invalidTint(Double)

    public var errorDescription: String? {
        switch self {
        case let .invalidTemperatureKelvin(temperatureKelvin):
            return "White balance temperature must be a finite positive value. Received \(temperatureKelvin)."
        case let .invalidTint(tint):
            return "White balance tint must be finite. Received \(tint)."
        }
    }
}

public struct WhiteBalanceStateMachine: Equatable, Sendable {
    public private(set) var state: WhiteBalanceControlState

    public init(initialState: WhiteBalanceControlState = .auto) {
        self.state = initialState
    }

    @discardableResult
    public mutating func apply(_ transition: WhiteBalanceStateTransition) throws -> WhiteBalanceControlState {
        switch transition {
        case .setAuto:
            state = .auto
        case let .lock(values):
            state = .locked(try Self.validated(values: values))
        }
        return state
    }

    private static func validated(values: WhiteBalanceValues) throws -> WhiteBalanceValues {
        guard values.temperatureKelvin.isFinite, values.temperatureKelvin > 0 else {
            throw WhiteBalanceStateMachineError.invalidTemperatureKelvin(values.temperatureKelvin)
        }
        guard values.tint.isFinite else {
            throw WhiteBalanceStateMachineError.invalidTint(values.tint)
        }
        return values
    }
}
