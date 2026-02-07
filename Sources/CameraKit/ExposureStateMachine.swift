import Foundation

public struct ExposureValues: Equatable, Sendable {
    public let iso: Double
    public let shutterSeconds: Double

    public init(
        iso: Double,
        shutterSeconds: Double
    ) {
        self.iso = iso
        self.shutterSeconds = shutterSeconds
    }
}

public enum ExposureControlMode: String, Equatable, Sendable {
    case auto
    case locked
    case custom
}

public enum ExposureControlState: Equatable, Sendable {
    case auto
    case locked(ExposureValues)
    case custom(ExposureValues)

    public var mode: ExposureControlMode {
        switch self {
        case .auto:
            return .auto
        case .locked:
            return .locked
        case .custom:
            return .custom
        }
    }

    public var values: ExposureValues? {
        switch self {
        case .auto:
            return nil
        case let .locked(values):
            return values
        case let .custom(values):
            return values
        }
    }
}

public enum ExposureStateTransition: Equatable, Sendable {
    case setAuto
    case lock(ExposureValues)
    case setCustom(ExposureValues)
}

public enum ExposureStateMachineError: Error, Equatable, LocalizedError {
    case invalidISO(Double)
    case invalidShutterSeconds(Double)

    public var errorDescription: String? {
        switch self {
        case let .invalidISO(iso):
            return "ISO must be a finite positive value. Received \(iso)."
        case let .invalidShutterSeconds(shutterSeconds):
            return "Shutter seconds must be a finite positive value. Received \(shutterSeconds)."
        }
    }
}

public struct ExposureStateMachine: Equatable, Sendable {
    public private(set) var state: ExposureControlState

    public init(initialState: ExposureControlState = .auto) {
        self.state = initialState
    }

    @discardableResult
    public mutating func apply(_ transition: ExposureStateTransition) throws -> ExposureControlState {
        switch transition {
        case .setAuto:
            state = .auto
        case let .lock(values):
            state = .locked(try Self.validated(values: values))
        case let .setCustom(values):
            state = .custom(try Self.validated(values: values))
        }
        return state
    }

    private static func validated(values: ExposureValues) throws -> ExposureValues {
        guard values.iso.isFinite, values.iso > 0 else {
            throw ExposureStateMachineError.invalidISO(values.iso)
        }
        guard values.shutterSeconds.isFinite, values.shutterSeconds > 0 else {
            throw ExposureStateMachineError.invalidShutterSeconds(values.shutterSeconds)
        }
        return values
    }
}
