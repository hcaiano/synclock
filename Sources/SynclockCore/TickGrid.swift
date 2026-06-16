import Foundation

/// Maps clock tick indices to host-time timestamps. This is the seam between
/// the engine's scheduling loop and the *source of musical truth*: free-running
/// local tempo (Free/Lead) or an Ableton Link beat grid (Follow). The engine
/// never knows which; it just asks the grid when each tick fires.
///
/// All times are CLOCK_UPTIME_RAW nanoseconds (HostTime domain).
public protocol TickGrid: AnyObject {
    /// Re-anchor the grid to start at `now` (Free/Lead). Link grids ignore this.
    func reset(at now: UInt64)
    /// Local tempo change (Free/Lead), kept phase-continuous from the last
    /// scheduled tick. Link grids ignore this — Link is the tempo authority.
    func setTempo(_ tempo: Tempo, at now: UInt64, lastScheduledIndex: Int)
    /// Host time at which tick `index` should fire.
    func hostTimeNanos(forTick index: Int) -> UInt64
    /// Highest tick index whose fire time is at or before `horizon`.
    func lastDueIndex(byHostNanos horizon: UInt64) -> Int
}

/// The default grid: a free-running local clock at a fixed tempo. Tempo changes
/// re-anchor the origin so the beat grid stays phase-continuous (no jump at the
/// next tick). Used in Free and Lead modes.
public final class FreeRunningGrid: TickGrid {
    private var tempo: Tempo
    private var origin: UInt64

    public init(tempo: Tempo, origin: UInt64 = 0) {
        self.tempo = tempo
        self.origin = origin
    }

    public func reset(at now: UInt64) { origin = now }

    public func setTempo(_ newTempo: Tempo, at now: UInt64, lastScheduledIndex: Int) {
        guard lastScheduledIndex >= 0 else {
            tempo = newTempo
            origin = now
            return
        }
        let lastTickTime = ClockMath.tickTime(index: lastScheduledIndex, tempo: tempo, originNanos: origin)
        let newPerTick = ClockMath.nanosecondsPerTick(newTempo)
        // origin' so tickTime(lastIndex, newTempo, origin') == lastTickTime.
        origin = lastTickTime &- UInt64((newPerTick * Double(lastScheduledIndex)).rounded())
        tempo = newTempo
    }

    public func hostTimeNanos(forTick index: Int) -> UInt64 {
        ClockMath.tickTime(index: index, tempo: tempo, originNanos: origin)
    }

    public func lastDueIndex(byHostNanos horizon: UInt64) -> Int {
        ClockScheduler.lastDueIndex(by: horizon, origin: origin, tempo: tempo)
    }
}
