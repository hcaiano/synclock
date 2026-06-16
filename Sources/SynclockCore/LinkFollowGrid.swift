import Foundation
import AbletonLinkBridge

/// Converts between Synclock's host-time nanoseconds and Ableton Link's clock
/// microseconds. Link and CoreMIDI advance at the same monotonic rate, but the
/// epoch is treated as an implementation detail, so we map by sampled deltas.
public struct LinkClockMapper: Equatable {
    public var hostNanosAtSample: UInt64
    public var linkMicrosAtSample: Int64

    public init(hostNanosAtSample: UInt64, linkMicrosAtSample: Int64) {
        self.hostNanosAtSample = hostNanosAtSample
        self.linkMicrosAtSample = linkMicrosAtSample
    }

    public func linkMicros(forHostNanos host: UInt64) -> Int64 {
        if host >= hostNanosAtSample {
            return linkMicrosAtSample &+ Int64((host - hostNanosAtSample) / 1_000)
        }
        return linkMicrosAtSample &- Int64((hostNanosAtSample - host) / 1_000)
    }

    public func hostNanos(forLinkMicros micros: Int64) -> UInt64 {
        let deltaMicros = micros &- linkMicrosAtSample
        if deltaMicros >= 0 {
            return hostNanosAtSample &+ UInt64(deltaMicros) &* 1_000
        }
        return hostNanosAtSample &- UInt64(-deltaMicros) &* 1_000
    }
}

/// Tick grid whose musical truth is the active Ableton Link session.
///
/// Tick index `i` maps to Link beat `i / 24`, matching MIDI clock's 24 PPQN.
/// Local tempo edits and resets are ignored; Follow mode treats Link as the
/// authority for tempo and phase.
public final class LinkFollowGrid: TickGrid {
    public static let defaultQuantum: Double = 4

    private let link: OpaquePointer
    private let quantum: Double
    private let mapper: LinkClockMapper

    public init(link: OpaquePointer,
                quantum: Double = LinkFollowGrid.defaultQuantum,
                hostNanosAtSample: UInt64 = HostTime.nowNanos()) {
        self.link = link
        self.quantum = quantum
        self.mapper = LinkClockMapper(hostNanosAtSample: hostNanosAtSample,
                                      linkMicrosAtSample: MCLinkClockMicros(link))
    }

    public func reset(at now: UInt64) {
        // Link owns phase; mode switches re-anchor ClockEngine's scheduled index.
    }

    public func setTempo(_ tempo: Tempo, at now: UInt64, lastScheduledIndex: Int) {
        // Link owns tempo in Follow mode.
    }

    public func hostTimeNanos(forTick index: Int) -> UInt64 {
        let beat = Double(index) / Double(MIDIClock.pulsesPerQuarterNote)
        let linkMicros = MCLinkTimeAtBeat(link, beat, quantum)
        return mapper.hostNanos(forLinkMicros: linkMicros)
    }

    public func lastDueIndex(byHostNanos horizon: UInt64) -> Int {
        let linkMicros = mapper.linkMicros(forHostNanos: horizon)
        let beat = MCLinkBeatAtTime(link, linkMicros, quantum)
        guard beat.isFinite else { return -1 }
        return Int((beat * Double(MIDIClock.pulsesPerQuarterNote)).rounded(.down))
    }
}
