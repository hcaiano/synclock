import Foundation

/// Sink the engine schedules ticks into. Phase 3 implements this over direct
/// CoreMIDI (timestamped `MIDIEventList`); tests implement a recording sink.
/// `hostTimeNanos` is an absolute future host time — the output converts it to
/// the CoreMIDI timestamp domain and lets the OS deliver it precisely.
public protocol ClockOutput: AnyObject {
    func scheduleTick(index: Int, hostTimeNanos: UInt64)
}

/// The hand-owned clock scheduler. A high-priority worker wakes on a timer,
/// computes which ticks fall in the lookahead window, and schedules them
/// *ahead* of due time. The timer is only the wake/refill mechanism — the tick
/// timestamps (not the timer firings) are the source of musical truth.
///
/// State is confined to `queue`; `pump(now:)` is exposed for deterministic
/// tests and must otherwise only run on `queue`.
public final class ClockEngine {
    public struct Config {
        /// How far ahead to schedule ticks. Bigger = more jitter-immune but
        /// less responsive to tempo changes.
        public var lookaheadNanos: UInt64
        /// Worker wake interval. Should be well under `lookaheadNanos`.
        public var tickIntervalNanos: UInt64
        public init(lookaheadNanos: UInt64 = 20_000_000,   // 20 ms
                    tickIntervalNanos: UInt64 = 4_000_000) { // 4 ms
            self.lookaheadNanos = lookaheadNanos
            self.tickIntervalNanos = tickIntervalNanos
        }
    }

    private let config: Config
    private unowned let output: ClockOutput
    private let queue = DispatchQueue(label: "com.caiano.synclock.clock", qos: .userInteractive)
    private var timer: DispatchSourceTimer?

    // State — only touched on `queue` (or single-threaded in tests).
    private var grid: TickGrid
    private var lastScheduledIndex = -1
    private(set) public var isRunning = false
    /// Ticks that came due before the engine could schedule them (diagnostics).
    private(set) public var underrunCount = 0

    public init(tempo: Tempo, output: ClockOutput, config: Config = Config()) {
        self.grid = FreeRunningGrid(tempo: tempo)
        self.output = output
        self.config = config
    }

    // MARK: - Control (thread-safe entry points)

    public func start(at now: UInt64 = HostTime.nowNanos()) {
        queue.async { [self] in
            resetState(at: now)
            startTimer()
        }
    }

    public func stop() {
        queue.async { [self] in
            isRunning = false
            timer?.cancel()
            timer = nil
        }
    }

    /// Change tempo while keeping the beat grid phase-continuous: the next tick
    /// follows the last scheduled tick by exactly one new-tempo interval. Only
    /// affects free-running grids; Link grids treat Link as the tempo authority.
    public func setTempo(_ newTempo: Tempo, at now: UInt64 = HostTime.nowNanos()) {
        queue.async { [self] in applyTempo(newTempo, at: now) }
    }

    /// Swap the tick-time source (Phase 5: Free <-> Link grids). Scheduling
    /// resumes from the next future tick so no past ticks are replayed.
    public func setGrid(_ newGrid: TickGrid, at now: UInt64 = HostTime.nowNanos()) {
        queue.async { [self] in
            grid = newGrid
            lastScheduledIndex = anchorIndex(for: newGrid, at: now)
        }
    }

    /// First-schedulable anchor: the tick due *at* `now` becomes the next one
    /// scheduled (so the next pump fills the lookahead without replaying past
    /// history). For a freshly-reset FreeRunningGrid this is -1 (tick 0 fires);
    /// for a Link grid it's the current beat index, not 0.
    private func anchorIndex(for grid: TickGrid, at now: UInt64) -> Int {
        grid.lastDueIndex(byHostNanos: now) - 1
    }

    // MARK: - Synchronous state core (queue-confined; shared with test seams)

    private func resetState(at now: UInt64) {
        grid.reset(at: now)
        lastScheduledIndex = anchorIndex(for: grid, at: now)
        underrunCount = 0
        isRunning = true
    }

    private func applyTempo(_ newTempo: Tempo, at now: UInt64) {
        let index = (isRunning && lastScheduledIndex >= 0) ? lastScheduledIndex : -1
        grid.setTempo(newTempo, at: now, lastScheduledIndex: index)
        if index < 0 { lastScheduledIndex = -1 }
    }

    // MARK: - Test seams (drive pump() yourself; no background timer)

    /// Reset and arm the engine WITHOUT starting the worker thread, so tests can
    /// call `pump(now:)` deterministically. Production code uses `start`.
    public func startForTesting(at now: UInt64) { resetState(at: now) }
    public func setTempoForTesting(_ t: Tempo, at now: UInt64) { applyTempo(t, at: now) }
    public func setGridForTesting(_ g: TickGrid, at now: UInt64) {
        grid = g; lastScheduledIndex = anchorIndex(for: g, at: now)
    }

    // MARK: - Worker

    private func startTimer() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(),
                   repeating: .nanoseconds(Int(config.tickIntervalNanos)),
                   leeway: .nanoseconds(500_000)) // 0.5 ms
        t.setEventHandler { [weak self] in
            guard let self else { return }
            self.pump(now: HostTime.nowNanos())
        }
        timer = t
        t.resume()
    }

    /// Schedule all ticks now due within the lookahead window. Pure-ish: depends
    /// only on `now` and engine state. Safe to call directly from tests.
    public func pump(now: UInt64) {
        guard isRunning else { return }
        let horizon = now &+ config.lookaheadNanos
        let lastDue = grid.lastDueIndex(byHostNanos: horizon)
        guard lastDue > lastScheduledIndex else { return }
        let first = lastScheduledIndex + 1
        let last = min(lastDue, first + ClockScheduler.maxBatch - 1)

        for index in first...last {
            let due = grid.hostTimeNanos(forTick: index)
            if due < now { underrunCount += 1 } // came due before we could schedule
            output.scheduleTick(index: index, hostTimeNanos: due)
        }
        lastScheduledIndex = last
    }
}
