import Foundation

public struct CaptureArtifact: Equatable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let primaryURL: URL
    public let companionURL: URL?
    public let photoLibraryLocalIdentifier: String?
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        primaryURL: URL,
        companionURL: URL? = nil,
        photoLibraryLocalIdentifier: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.primaryURL = primaryURL
        self.companionURL = companionURL
        self.photoLibraryLocalIdentifier = photoLibraryLocalIdentifier
        self.metadata = metadata
    }
}
