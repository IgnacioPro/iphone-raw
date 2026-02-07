import CameraKit
import Foundation

public enum CapturePresetSlot: String, CaseIterable, Codable, Hashable, Sendable {
    case preset1
    case preset2
    case preset3

    public var displayName: String {
        switch self {
        case .preset1:
            return "C1"
        case .preset2:
            return "C2"
        case .preset3:
            return "C3"
        }
    }
}

public enum CapturePresetExposureMode: String, Codable, Equatable, Sendable {
    case auto
    case locked
    case custom
}

public struct CapturePresetExposureState: Codable, Equatable, Sendable {
    public let mode: CapturePresetExposureMode
    public let iso: Double?
    public let shutterSeconds: Double?

    public init(mode: CapturePresetExposureMode, iso: Double?, shutterSeconds: Double?) {
        self.mode = mode
        self.iso = iso
        self.shutterSeconds = shutterSeconds
    }

    public init(_ state: ExposureControlState) {
        switch state {
        case .auto:
            self.init(mode: .auto, iso: nil, shutterSeconds: nil)
        case let .locked(values):
            self.init(mode: .locked, iso: values.iso, shutterSeconds: values.shutterSeconds)
        case let .custom(values):
            self.init(mode: .custom, iso: values.iso, shutterSeconds: values.shutterSeconds)
        }
    }

    public func resolvedCameraState() -> ExposureControlState {
        switch mode {
        case .auto:
            return .auto
        case .locked:
            guard let iso, let shutterSeconds else { return .auto }
            return .locked(ExposureValues(iso: iso, shutterSeconds: shutterSeconds))
        case .custom:
            guard let iso, let shutterSeconds else { return .auto }
            return .custom(ExposureValues(iso: iso, shutterSeconds: shutterSeconds))
        }
    }
}

public enum CapturePresetFocusMode: String, Codable, Equatable, Sendable {
    case auto
    case locked
}

public struct CapturePresetFocusState: Codable, Equatable, Sendable {
    public let mode: CapturePresetFocusMode
    public let lensPosition: Double?

    public init(mode: CapturePresetFocusMode, lensPosition: Double?) {
        self.mode = mode
        self.lensPosition = lensPosition
    }

    public init(_ state: FocusControlState) {
        switch state {
        case .auto:
            self.init(mode: .auto, lensPosition: nil)
        case let .locked(lensPosition):
            self.init(mode: .locked, lensPosition: lensPosition)
        }
    }

    public func resolvedCameraState() -> FocusControlState {
        switch mode {
        case .auto:
            return .auto
        case .locked:
            guard let lensPosition else { return .auto }
            return .locked(lensPosition: lensPosition)
        }
    }
}

public enum CapturePresetWhiteBalanceMode: String, Codable, Equatable, Sendable {
    case auto
    case locked
}

public struct CapturePresetWhiteBalanceState: Codable, Equatable, Sendable {
    public let mode: CapturePresetWhiteBalanceMode
    public let temperatureKelvin: Double?
    public let tint: Double?

    public init(
        mode: CapturePresetWhiteBalanceMode,
        temperatureKelvin: Double?,
        tint: Double?
    ) {
        self.mode = mode
        self.temperatureKelvin = temperatureKelvin
        self.tint = tint
    }

    public init(_ state: WhiteBalanceControlState) {
        switch state {
        case .auto:
            self.init(
                mode: .auto,
                temperatureKelvin: nil,
                tint: nil
            )
        case let .locked(values):
            self.init(
                mode: .locked,
                temperatureKelvin: values.temperatureKelvin,
                tint: values.tint
            )
        }
    }

    public func resolvedCameraState() -> WhiteBalanceControlState {
        switch mode {
        case .auto:
            return .auto
        case .locked:
            guard let temperatureKelvin, let tint else { return .auto }
            return .locked(
                WhiteBalanceValues(
                    temperatureKelvin: temperatureKelvin,
                    tint: tint
                )
            )
        }
    }
}

public struct CaptureControlPreset: Codable, Equatable, Sendable {
    public let exposureState: CapturePresetExposureState
    public let focusState: CapturePresetFocusState
    public let whiteBalanceState: CapturePresetWhiteBalanceState
    public let exposureCompensation: Double
    public let savedAt: Date

    public init(
        exposureState: CapturePresetExposureState,
        focusState: CapturePresetFocusState,
        whiteBalanceState: CapturePresetWhiteBalanceState,
        exposureCompensation: Double,
        savedAt: Date
    ) {
        self.exposureState = exposureState
        self.focusState = focusState
        self.whiteBalanceState = whiteBalanceState
        self.exposureCompensation = exposureCompensation
        self.savedAt = savedAt
    }
}

public protocol CapturePresetStoring {
    func save(_ preset: CaptureControlPreset, for slot: CapturePresetSlot) throws
    func load(for slot: CapturePresetSlot) throws -> CaptureControlPreset?
    func availableSlots() throws -> Set<CapturePresetSlot>
}

public final class InMemoryCapturePresetStore: CapturePresetStoring {
    private var storage: [CapturePresetSlot: CaptureControlPreset]

    public init(
        initialStorage: [CapturePresetSlot: CaptureControlPreset] = [:]
    ) {
        storage = initialStorage
    }

    public func save(_ preset: CaptureControlPreset, for slot: CapturePresetSlot) throws {
        storage[slot] = preset
    }

    public func load(for slot: CapturePresetSlot) throws -> CaptureControlPreset? {
        storage[slot]
    }

    public func availableSlots() throws -> Set<CapturePresetSlot> {
        Set(storage.keys)
    }
}

public final class UserDefaultsCapturePresetStore: CapturePresetStoring {
    private static let storageKey = "capture_control_presets_v1"

    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    public func save(_ preset: CaptureControlPreset, for slot: CapturePresetSlot) throws {
        var storedPresets = try decodeStorage()
        storedPresets[slot.rawValue] = preset
        try persistStorage(storedPresets)
    }

    public func load(for slot: CapturePresetSlot) throws -> CaptureControlPreset? {
        try decodeStorage()[slot.rawValue]
    }

    public func availableSlots() throws -> Set<CapturePresetSlot> {
        let keys = try decodeStorage().keys
        return Set(keys.compactMap(CapturePresetSlot.init(rawValue:)))
    }

    private func decodeStorage() throws -> [String: CaptureControlPreset] {
        guard let data = userDefaults.data(forKey: Self.storageKey) else {
            return [:]
        }
        return try decoder.decode([String: CaptureControlPreset].self, from: data)
    }

    private func persistStorage(_ storage: [String: CaptureControlPreset]) throws {
        let data = try encoder.encode(storage)
        userDefaults.set(data, forKey: Self.storageKey)
    }
}
