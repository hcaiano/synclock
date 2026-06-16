import Foundation

/// Tap-tempo estimator. Feed it tap timestamps (host nanoseconds); it averages
/// the recent intervals into a BPM. Taps spaced further apart than `resetGap
/// Nanos` start a fresh measurement (you walked away and came back).
public struct TapTempo {
    private var taps: [UInt64] = []
    private let maxTaps: Int
    private let resetGapNanos: UInt64

    public init(maxTaps: Int = 4, resetGapNanos: UInt64 = 2_000_000_000) {
        self.maxTaps = max(2, maxTaps)
        self.resetGapNanos = resetGapNanos
    }

    /// Number of taps currently contributing to the estimate.
    public var count: Int { taps.count }

    /// Register a tap. Returns the estimated tempo once there are ≥2 taps in the
    /// current run, else nil (need more taps).
    public mutating func tap(at hostNanos: UInt64) -> Tempo? {
        if let last = taps.last, hostNanos &- last > resetGapNanos {
            taps.removeAll(keepingCapacity: true)
        }
        taps.append(hostNanos)
        if taps.count > maxTaps { taps.removeFirst(taps.count - maxTaps) }
        guard taps.count >= 2 else { return nil }

        var total: Double = 0
        for (a, b) in zip(taps, taps.dropFirst()) { total += Double(b - a) }
        let avgInterval = total / Double(taps.count - 1)
        guard avgInterval > 0 else { return nil }
        let bpm = 60.0 * 1_000_000_000.0 / avgInterval
        return Tempo(bpm)
    }

    public mutating func reset() { taps.removeAll(keepingCapacity: true) }
}
