import Foundation

public enum CaptureEventCategory: String, Codable, Equatable {
    case permission
    case session
    case capture
    case storage
    case system
}

public struct CaptureEvent: Codable, Equatable {
    public let id: UUID
    public let category: CaptureEventCategory
    public let action: String
    public let timestamp: Date
    public let payload: [String: String]

    public init(
        id: UUID = UUID(),
        category: CaptureEventCategory,
        action: String,
        timestamp: Date = Date(),
        payload: [String: String] = [:]
    ) {
        self.id = id
        self.category = category
        self.action = action
        self.timestamp = timestamp
        self.payload = payload
    }
}
