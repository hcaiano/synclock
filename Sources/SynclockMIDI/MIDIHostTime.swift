import Foundation
import CoreMIDI

/// Converts between the scheduler's nanosecond host time (`HostTime.nowNanos`,
/// CLOCK_UPTIME_RAW) and CoreMIDI's `MIDITimeStamp`, which is in
/// `mach_absolute_time` units. Both share the mach uptime epoch, so this is a
/// pure timebase ratio — no clock skew between them.
enum MIDIHostTime {
    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    /// nanoseconds -> mach ticks (CoreMIDI timestamp). Overflow-safe split so a
    /// large uptime value times `denom` can't wrap UInt64.
    static func machTicks(fromNanos ns: UInt64) -> MIDITimeStamp {
        let numer = UInt64(timebase.numer)
        let denom = UInt64(timebase.denom)
        if numer == denom { return ns } // common on Apple Silicon
        // ticks = ns * denom / numer, computed without overflowing.
        let whole = ns / numer
        let rem = ns % numer
        return whole &* denom &+ (rem &* denom) / numer
    }

    /// Current time as a CoreMIDI timestamp.
    static func now() -> MIDITimeStamp { mach_absolute_time() }
}
