import Foundation

public protocol CaptureEventLogging {
    func log(_ event: CaptureEvent)
}

public final class StructuredCaptureLogger: CaptureEventLogging {
    private let encoder: JSONEncoder
    private let sink: (String) -> Void

    public init(sink: @escaping (String) -> Void = { print($0) }) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        self.sink = sink
    }

    public func log(_ event: CaptureEvent) {
        guard let data = try? encoder.encode(event),
              let line = String(data: data, encoding: .utf8) else {
            return
        }
        sink(line)
    }
}

public final class InMemoryCaptureEventLogger: CaptureEventLogging {
    public private(set) var events: [CaptureEvent] = []

    public init() {}

    public func log(_ event: CaptureEvent) {
        events.append(event)
    }
}
