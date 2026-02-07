import CameraKit
import Testing

@Suite("WhiteBalanceStateMachine")
struct WhiteBalanceStateMachineTests {
    @Test("defaults to auto mode")
    func defaultsToAutoMode() {
        let machine = WhiteBalanceStateMachine()
        #expect(machine.state == .auto)
        #expect(machine.state.mode == .auto)
        #expect(machine.state.values == nil)
    }

    @Test("lock auto lock transitions are deterministic")
    func deterministicTransitions() throws {
        let firstLockedValues = WhiteBalanceValues(temperatureKelvin: 4_500, tint: -8)
        let secondLockedValues = WhiteBalanceValues(temperatureKelvin: 6_200, tint: 14)

        var first = WhiteBalanceStateMachine()
        var second = WhiteBalanceStateMachine()

        let transitions: [WhiteBalanceStateTransition] = [
            .lock(firstLockedValues),
            .setAuto,
            .lock(secondLockedValues),
        ]

        for transition in transitions {
            try first.apply(transition)
            try second.apply(transition)
        }

        #expect(first.state == second.state)
        #expect(first.state == .locked(secondLockedValues))
    }

    @Test("invalid values throw and do not mutate state")
    func invalidValuesDoNotMutateState() throws {
        var machine = WhiteBalanceStateMachine()
        let validValues = WhiteBalanceValues(temperatureKelvin: 5_200, tint: 3)
        try machine.apply(.lock(validValues))
        let previousState = machine.state

        #expect(throws: WhiteBalanceStateMachineError.self) {
            try machine.apply(.lock(WhiteBalanceValues(temperatureKelvin: 0, tint: 0)))
        }
        #expect(machine.state == previousState)

        #expect(throws: WhiteBalanceStateMachineError.self) {
            try machine.apply(.lock(WhiteBalanceValues(temperatureKelvin: 5_500, tint: .infinity)))
        }
        #expect(machine.state == previousState)
    }
}
