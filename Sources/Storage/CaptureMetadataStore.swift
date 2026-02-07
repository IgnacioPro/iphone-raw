import Foundation

public protocol CaptureMetadataStoring {
    func save(_ artifact: CaptureArtifact) async
    func fetchAll() async -> [CaptureArtifact]
    func find(id: UUID) async -> CaptureArtifact?
    func delete(photoLibraryLocalIdentifiers: Set<String>) async
}

public actor InMemoryCaptureMetadataStore: CaptureMetadataStoring {
    private var artifacts: [CaptureArtifact] = []

    public init() {}

    public func save(_ artifact: CaptureArtifact) async {
        if let index = artifacts.firstIndex(where: { $0.id == artifact.id }) {
            artifacts[index] = artifact
            return
        }
        artifacts.append(artifact)
    }

    public func fetchAll() async -> [CaptureArtifact] {
        artifacts.sorted { $0.createdAt > $1.createdAt }
    }

    public func find(id: UUID) async -> CaptureArtifact? {
        artifacts.first(where: { $0.id == id })
    }

    public func delete(photoLibraryLocalIdentifiers: Set<String>) async {
        guard !photoLibraryLocalIdentifiers.isEmpty else { return }
        artifacts.removeAll { artifact in
            if let primaryIdentifier = artifact.photoLibraryLocalIdentifier,
               photoLibraryLocalIdentifiers.contains(primaryIdentifier) {
                return true
            }
            if let pairedIdentifier = artifact.metadata["paired_photo_library_local_identifier"],
               photoLibraryLocalIdentifiers.contains(pairedIdentifier) {
                return true
            }
            return false
        }
    }
}
