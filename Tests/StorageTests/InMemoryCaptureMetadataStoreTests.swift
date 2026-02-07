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
}
