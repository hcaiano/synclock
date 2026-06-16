import Foundation

/// Pure tick-window math for the clock scheduler. Given the current time and
/// what's already been scheduled, decide which future ticks fall inside the
/// lookahead window. No threads, no state — trivially testable.
///
/// Tick `i` is due at `origin + round(nsPerTick * i)`. The engine schedules
/// every tick whose due time is at or before `now + lookahead`, timestamped
/// ahead of time so CoreMIDI delivers it precisely.
public enum ClockScheduler {
    /// Hard cap on ticks returned from a single call, so a far-past origin can't
    /// produce a giant batch. The engine catches up across successive pumps.
    public static let maxBatch = 1024

    /// Highest tick index whose due time is at or before `horizonNanos`.
    /// Returns -1 when not even tick 0 is due yet.
    public static func lastDueIndex(by horizonNanos: UInt64, origin: UInt64, tempo: Tempo) -> Int {
        guard horizonNanos >= origin else { return -1 }
        let delta = Double(horizonNanos - origin)
        let index = (delta / ClockMath.nanosecondsPerTick(tempo)).rounded(.down)
        return Int(index)
    }

    /// The contiguous range of tick indices to schedule now: those after
    /// `lastScheduledIndex` and due within `[*, now + lookahead]`, capped at
    /// `maxBatch`. Returns nil when there's nothing to schedule.
    public static func ticksToSchedule(now: UInt64,
                                       lookaheadNanos: UInt64,
                                       lastScheduledIndex: Int,
                                       origin: UInt64,
                                       tempo: Tempo) -> ClosedRange<Int>? {
        let horizon = now &+ lookaheadNanos
        let lastDue = lastDueIndex(by: horizon, origin: origin, tempo: tempo)
        guard lastDue > lastScheduledIndex else { return nil }
        let first = lastScheduledIndex + 1
        let last = min(lastDue, first + maxBatch - 1)
        return first...last
    }
}
