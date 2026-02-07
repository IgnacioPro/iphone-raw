import CameraKit
import Testing

@Suite("FocusStateMachine")
struct FocusStateMachineTests {
    @Test("defaults to auto mode")
    func defaultsToAutoMode() {
        let machine = FocusStateMachine()
        #expect(machine.state == .auto)
        #expect(machine.state.mode == .auto)
        #expect(machine.state.lensPosition == nil)
    }

    @Test("lock auto lock transitions are deterministic")
    func deterministicTransitions() throws {
        var first = FocusStateMachine()
        var second = FocusStateMachine()

        let transitions: [FocusStateTransition] = [
            .lock(lensPosition: 0.2),
            .setAuto,
            .lock(lensPosition: 0.8),
        ]

        for transition in transitions {
            try first.apply(transition)
            try second.apply(transition)
        }

        #expect(first.state == second.state)
        #expect(first.state == .locked(lensPosition: 0.8))
    }

    @Test("invalid lens position throws and does not mutate state")
    func invalidLensPosition() throws {
        var machine = FocusStateMachine()
        try machine.apply(.lock(lensPosition: 0.4))
        let previousState = machine.state

        #expect(throws: FocusStateMachineError.self) {
            try machine.apply(.lock(lensPosition: -0.1))
        }
        #expect(machine.state == previousState)
    }
}
