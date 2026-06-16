import Foundation

/// MIDI System Real-Time and transport byte constants used by the clock.
/// v1 scope: clock + Start/Stop/Continue. (SPP/MTC are v2.)
public enum MIDIByte {
    /// Timing Clock — sent 24 times per quarter note.
    public static let clock: UInt8 = 0xF8
    /// Start — begin playback from the top.
    public static let start: UInt8 = 0xFA
    /// Continue — resume playback from current position.
    public static let `continue`: UInt8 = 0xFB
    /// Stop.
    public static let stop: UInt8 = 0xFC
}

/// Pulses Per Quarter Note for MIDI clock. Fixed by the MIDI spec.
public let midiClockPPQN: Int = 24

/// Pure timing math for the MIDI clock. No threads, no I/O — just the numbers
/// the hand-owned scheduler schedules against. All durations in nanoseconds.
public enum ClockMath {
    /// Nanoseconds between two consecutive `0xF8` ticks at `tempo`.
    /// 60s / (bpm * 24) per tick.
    public static func nanosecondsPerTick(_ tempo: Tempo) -> Double {
        let ticksPerMinute = tempo.bpm * Double(midiClockPPQN)
        return 60.0 * 1_000_000_000.0 / ticksPerMinute
    }

    /// Nanoseconds per quarter note (a "beat") at `tempo`.
    public static func nanosecondsPerBeat(_ tempo: Tempo) -> Double {
        nanosecondsPerTick(tempo) * Double(midiClockPPQN)
    }

    /// Absolute host-time (ns) of tick `index` measured from `originNanos`.
    /// The scheduler emits packets with these timestamps, slightly ahead of due.
    public static func tickTime(index: Int, tempo: Tempo, originNanos: UInt64) -> UInt64 {
        let offset = nanosecondsPerTick(tempo) * Double(index)
        return originNanos &+ UInt64(offset.rounded())
    }
}
