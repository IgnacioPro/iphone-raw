import CameraKit
import Foundation
import Testing

@Suite("CameraPermissionGate")
struct CameraPermissionGateTests {
    @Test("returns granted immediately when already authorized")
    func authorizedWithoutPrompt() async {
        let permissionClient = StubPermissionClient(
            status: .authorized,
            requestAccessResult: false
        )
        let gate = CameraPermissionGate(client: permissionClient)

        let result = await gate.ensureAccess()

        #expect(result == .granted)
        #expect(permissionClient.requestCallCount == 0)
    }

    @Test("requests access if status is not determined")
    func requestsWhenNotDetermined() async {
        let permissionClient = StubPermissionClient(
            status: .notDetermined,
            requestAccessResult: true
        )
        let gate = CameraPermissionGate(client: permissionClient)

        let result = await gate.ensureAccess()

        #expect(result == .granted)
        #expect(permissionClient.requestCallCount == 1)
    }

    @Test("returns denied when prompt response is denied")
    func deniedAfterPrompt() async {
        let permissionClient = StubPermissionClient(
            status: .notDetermined,
            requestAccessResult: false
        )
        let gate = CameraPermissionGate(client: permissionClient)

        let result = await gate.ensureAccess()

        #expect(result == .denied)
        #expect(permissionClient.requestCallCount == 1)
    }

    @Test("returns restricted status")
    func restricted() async {
        let permissionClient = StubPermissionClient(
            status: .restricted,
            requestAccessResult: true
        )
        let gate = CameraPermissionGate(client: permissionClient)

        let result = await gate.ensureAccess()

        #expect(result == .restricted)
        #expect(permissionClient.requestCallCount == 0)
    }
}

private final class StubPermissionClient: CameraPermissionClient {
    private let status: CameraAuthorizationStatus
    private let requestAccessResult: Bool

    private(set) var requestCallCount: Int = 0

    init(status: CameraAuthorizationStatus, requestAccessResult: Bool) {
        self.status = status
        self.requestAccessResult = requestAccessResult
    }

    func authorizationStatus() -> CameraAuthorizationStatus {
        status
    }

    func requestAccess() async -> Bool {
        requestCallCount += 1
        return requestAccessResult
    }
}
