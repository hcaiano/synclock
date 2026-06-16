import Foundation

/// Playback state of the master transport.
public enum TransportState: String, Codable, Equatable {
    case stopped
    case playing
}

/// User transport intents.
public enum TransportAction: Equatable {
    case play
    case stop
}

/// Outcome of a transport action: the new state, which MIDI transport bytes to
/// emit, and whether the clock (F8 stream) should be running afterwards.
public struct TransportDecision: Equatable {
    public var state: TransportState
    public var emit: [UInt8]
    public var clockRunning: Bool
}

/// Pure transport state machine. Keeps the F8 clock and Start/Stop/Continue
/// transport messages coherent with the clock-while-stopped setting.
///
/// v1 has no Song Position Pointer, so Play always emits Start (from the top)
/// and Stop emits Stop. `clockWhileStopped` decides whether F8 keeps streaming
/// while stopped (many rigs expect continuous clock; others prefer silence).
public enum TransportLogic {
    public static func resolve(state: TransportState,
                               action: TransportAction,
                               clockWhileStopped: Bool) -> TransportDecision {
        switch (state, action) {
        case (.stopped, .play):
            return TransportDecision(state: .playing, emit: [MIDIByte.start], clockRunning: true)
        case (.playing, .play):
            return TransportDecision(state: .playing, emit: [], clockRunning: true)
        case (.playing, .stop):
            return TransportDecision(state: .stopped, emit: [MIDIByte.stop], clockRunning: clockWhileStopped)
        case (.stopped, .stop):
            return TransportDecision(state: .stopped, emit: [], clockRunning: clockWhileStopped)
        }
    }

    /// Whether the clock should run for a given resting state + setting (used
    /// when the clock-while-stopped setting is toggled, not via an action).
    public static func clockRunning(state: TransportState, clockWhileStopped: Bool) -> Bool {
        state == .playing || clockWhileStopped
    }
}
