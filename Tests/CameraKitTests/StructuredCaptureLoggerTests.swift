import CameraKit
import Foundation
import Testing

@Suite("StructuredCaptureLogger")
struct StructuredCaptureLoggerTests {
    @Test("emits JSON payload line")
    func emitsJSON() {
        var lines: [String] = []
        let logger = StructuredCaptureLogger { lines.append($0) }

        logger.log(
            CaptureEvent(
                category: .capture,
                action: "photo_taken",
                payload: ["format": "dng"]
            )
        )

        #expect(lines.count == 1)
        #expect(lines[0].contains("\"action\":\"photo_taken\""))
        #expect(lines[0].contains("\"category\":\"capture\""))
    }
}
