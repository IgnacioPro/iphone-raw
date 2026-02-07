#if canImport(SwiftUI)
import App
import SwiftUI

public struct CaptureStatusView: View {
    private let state: AppBootState

    public init(state: AppBootState) {
        self.state = state
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Photodew")
                .font(.headline)
            Text(statusTitle)
                .font(.subheadline)
                .foregroundStyle(statusColor)
        }
        .padding(12)
    }

    private var statusTitle: String {
        switch state {
        case .idle:
            return "Idle"
        case .requestingPermission:
            return "Requesting camera access"
        case .ready:
            return "Ready to capture"
        case let .blocked(reason):
            return "Blocked: \(reason)"
        case let .failed(reason):
            return "Failed: \(reason)"
        }
    }

    private var statusColor: Color {
        switch state {
        case .ready:
            return .green
        case .requestingPermission, .idle:
            return .yellow
        case .blocked, .failed:
            return .red
        }
    }
}
#endif
