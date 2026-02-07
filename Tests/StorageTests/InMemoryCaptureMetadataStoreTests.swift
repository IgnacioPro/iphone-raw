import Foundation
import Storage
import Testing

@Suite("InMemoryCaptureMetadataStore")
struct InMemoryCaptureMetadataStoreTests {
    @Test("save and fetch round-trips artifacts")
    func saveAndFetch() async {
        let store = InMemoryCaptureMetadataStore()
        let artifact = CaptureArtifact(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            createdAt: Date(timeIntervalSince1970: 1_000),
            primaryURL: URL(fileURLWithPath: "/tmp/a.dng"),
            companionURL: URL(fileURLWithPath: "/tmp/a.heic"),
            metadata: ["iso": "100"]
        )

        await store.save(artifact)

        let loaded = await store.find(id: artifact.id)
        #expect(loaded == artifact)
    }

    @Test("fetchAll returns newest artifacts first")
    func sortedFetch() async {
        let store = InMemoryCaptureMetadataStore()
        let older = CaptureArtifact(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            createdAt: Date(timeIntervalSince1970: 10),
            primaryURL: URL(fileURLWithPath: "/tmp/old.dng")
        )
        let newer = CaptureArtifact(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            createdAt: Date(timeIntervalSince1970: 20),
            primaryURL: URL(fileURLWithPath: "/tmp/new.dng")
        )

        await store.save(older)
        await store.save(newer)

        let all = await store.fetchAll()
        #expect(all.map(\.id) == [newer.id, older.id])
    }

    @Test("delete removes artifacts by primary or paired local identifier")
    func deleteByLocalIdentifier() async {
        let store = InMemoryCaptureMetadataStore()
        let keepArtifact = CaptureArtifact(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            createdAt: Date(timeIntervalSince1970: 30),
            primaryURL: URL(fileURLWithPath: "/tmp/keep.dng"),
            photoLibraryLocalIdentifier: "KEEP-1"
        )
        let deleteByPrimaryArtifact = CaptureArtifact(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            createdAt: Date(timeIntervalSince1970: 40),
            primaryURL: URL(fileURLWithPath: "/tmp/delete-primary.dng"),
            photoLibraryLocalIdentifier: "DEL-PRIMARY"
        )
        let deleteByPairArtifact = CaptureArtifact(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            createdAt: Date(timeIntervalSince1970: 50),
            primaryURL: URL(fileURLWithPath: "/tmp/delete-pair.dng"),
            photoLibraryLocalIdentifier: "DEL-OWNER",
            metadata: ["paired_photo_library_local_identifier": "DEL-PAIRED"]
        )

        await store.save(keepArtifact)
        await store.save(deleteByPrimaryArtifact)
        await store.save(deleteByPairArtifact)

        await store.delete(photoLibraryLocalIdentifiers: Set(["DEL-PRIMARY", "DEL-PAIRED"]))

        let remaining = await store.fetchAll()
        #expect(remaining.map(\.id) == [keepArtifact.id])
    }
}
