import Foundation

/// A clamped decimal tempo in beats per minute.
///
/// Synclock v1 accepts decimal BPM in `Tempo.range` (30–300). Construction and
/// every mutation clamp into range, so an out-of-range tempo is unrepresentable.
public struct Tempo: Equatable, Comparable, CustomStringConvertible {
    /// Inclusive valid BPM range for v1.
    public static let range: ClosedRange<Double> = 30.0...300.0

    public private(set) var bpm: Double

    public init(_ bpm: Double) {
        self.bpm = Tempo.clamp(bpm)
    }

    private static func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return range.lowerBound }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    /// Returns a new tempo nudged by `delta` BPM (clamped). Use small deltas
    /// (e.g. 0.1) for fine nudge, 1.0 for coarse.
    public func nudged(by delta: Double) -> Tempo {
        Tempo(bpm + delta)
    }

    /// Display rounded to one decimal, trimming a trailing ".0" (122.0 -> "122").
    public var description: String {
        let rounded = (bpm * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return String(Int(rounded))
        }
        return String(format: "%.1f", rounded)
    }

    public static func < (lhs: Tempo, rhs: Tempo) -> Bool { lhs.bpm < rhs.bpm }
}
