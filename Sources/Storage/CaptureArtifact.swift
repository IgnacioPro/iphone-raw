import Foundation

public struct CaptureArtifact: Equatable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let primaryURL: URL
    public let companionURL: URL?
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        primaryURL: URL,
        companionURL: URL? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.primaryURL = primaryURL
        self.companionURL = companionURL
        self.metadata = metadata
    }
}
