import CameraKit
import Testing

@Suite("ExposureStateMachine")
struct ExposureStateMachineTests {
    @Test("defaults to auto mode")
    func defaultsToAutoMode() {
        let machine = ExposureStateMachine()
        #expect(machine.state == .auto)
        #expect(machine.state.mode == .auto)
        #expect(machine.state.values == nil)
    }

    @Test("auto locked custom auto transitions are deterministic")
    func deterministicTransitions() throws {
        let lockedValues = ExposureValues(iso: 125.0, shutterSeconds: 1.0 / 120.0)
        let customValues = ExposureValues(iso: 80.0, shutterSeconds: 1.0 / 60.0)

        var first = ExposureStateMachine()
        var second = ExposureStateMachine()

        let transitions: [ExposureStateTransition] = [
            .lock(lockedValues),
            .setCustom(customValues),
            .setAuto,
            .setCustom(customValues),
        ]

        for transition in transitions {
            try first.apply(transition)
            try second.apply(transition)
        }

        #expect(first.state == second.state)
        #expect(first.state == .custom(customValues))
        #expect(first.state.mode == .custom)
    }

    @Test("invalid values throw and do not change state")
    func invalidValuesDoNotMutateState() throws {
        var machine = ExposureStateMachine()
        let validValues = ExposureValues(iso: 200.0, shutterSeconds: 1.0 / 100.0)
        try machine.apply(.setCustom(validValues))
        let previousState = machine.state

        #expect(throws: ExposureStateMachineError.self) {
            try machine.apply(.setCustom(ExposureValues(iso: -1, shutterSeconds: 0.01)))
        }
        #expect(machine.state == previousState)

        #expect(throws: ExposureStateMachineError.self) {
            try machine.apply(.lock(ExposureValues(iso: 100, shutterSeconds: 0)))
        }
        #expect(machine.state == previousState)
    }
}
