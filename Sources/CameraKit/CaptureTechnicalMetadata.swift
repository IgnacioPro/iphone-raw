import Foundation
#if canImport(ImageIO)
import ImageIO
#endif

public struct CaptureTechnicalMetadata: Equatable, Sendable {
    public let lensModel: String?
    public let iso: Double?
    public let shutterSeconds: Double?
    public let whiteBalanceMode: String?
    public let whiteBalanceTemperatureKelvin: Double?
    public let whiteBalanceTint: Double?

    public init(
        lensModel: String? = nil,
        iso: Double? = nil,
        shutterSeconds: Double? = nil,
        whiteBalanceMode: String? = nil,
        whiteBalanceTemperatureKelvin: Double? = nil,
        whiteBalanceTint: Double? = nil
    ) {
        self.lensModel = lensModel
        self.iso = iso
        self.shutterSeconds = shutterSeconds
        self.whiteBalanceMode = whiteBalanceMode
        self.whiteBalanceTemperatureKelvin = whiteBalanceTemperatureKelvin
        self.whiteBalanceTint = whiteBalanceTint
    }

    public var isEmpty: Bool {
        lensModel == nil &&
        iso == nil &&
        shutterSeconds == nil &&
        whiteBalanceMode == nil &&
        whiteBalanceTemperatureKelvin == nil &&
        whiteBalanceTint == nil
    }
}

extension CaptureTechnicalMetadata {
    static func resolving(photoMetadata: [String: Any], fallback: CaptureTechnicalMetadata?) -> CaptureTechnicalMetadata? {
        var lensModel = fallback?.lensModel
        var iso = fallback?.iso
        var shutterSeconds = fallback?.shutterSeconds
        var whiteBalanceMode = fallback?.whiteBalanceMode
        var whiteBalanceTemperatureKelvin = fallback?.whiteBalanceTemperatureKelvin
        var whiteBalanceTint = fallback?.whiteBalanceTint

        #if canImport(ImageIO)
        let exifDictionary = photoMetadata[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let tiffDictionary = photoMetadata[kCGImagePropertyTIFFDictionary as String] as? [String: Any]

        if let tiffDictionary {
            lensModel = stringValue(tiffDictionary["LensModel"])
                ?? stringValue(tiffDictionary["Model"])
                ?? lensModel
        }

        if let exifDictionary {
            iso = exifISOValue(from: exifDictionary) ?? iso
            shutterSeconds = numericValue(exifDictionary["ExposureTime"]) ?? shutterSeconds
            if let whiteBalanceCode = integerValue(exifDictionary["WhiteBalance"]) {
                whiteBalanceMode = whiteBalanceCode == 0 ? "auto" : "manual"
            }
            whiteBalanceTemperatureKelvin = numericValue(exifDictionary["Temperature"]) ?? whiteBalanceTemperatureKelvin
            whiteBalanceTint = numericValue(exifDictionary["Tint"]) ?? whiteBalanceTint
        }
        #endif

        let resolved = CaptureTechnicalMetadata(
            lensModel: lensModel,
            iso: iso,
            shutterSeconds: shutterSeconds,
            whiteBalanceMode: whiteBalanceMode,
            whiteBalanceTemperatureKelvin: whiteBalanceTemperatureKelvin,
            whiteBalanceTint: whiteBalanceTint
        )
        return resolved.isEmpty ? nil : resolved
    }

    #if canImport(ImageIO)
    private static func exifISOValue(from exifDictionary: [String: Any]) -> Double? {
        if let sensitivity = numericValue(exifDictionary["PhotographicSensitivity"]) {
            return sensitivity
        }
        if let values = exifDictionary["ISOSpeedRatings"] as? [Any] {
            return values.compactMap(numericValue).first
        }
        return nil
    }
    #endif

    private static func numericValue(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let value = value as? Double {
            return value
        }
        if let value = value as? Float {
            return Double(value)
        }
        if let value = value as? Int {
            return Double(value)
        }
        if let value = value as? String {
            return Double(value)
        }
        return nil
    }

    private static func integerValue(_ value: Any?) -> Int? {
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let value = value as? Int {
            return value
        }
        if let value = value as? String {
            return Int(value)
        }
        return nil
    }

    private static func stringValue(_ value: Any?) -> String? {
        if let value = value as? String {
            return value
        }
        if let value = value as? NSString {
            return value as String
        }
        return nil
    }
}
