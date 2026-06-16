import Foundation
import CoreMIDI
import SynclockCore
import SynclockMIDI
import AbletonLinkBridge

// Phase 8 jitter harness. Runs the real ClockEngine -> CoreMIDIOutput -> virtual
// source, captures the host-time arrival of each 0xF8 at a monitoring client,
// and reports inter-tick deviation percentiles versus the ideal interval.
//
// This measures END-TO-END delivery jitter (scheduler + CoreMIDI + monitor
// callback), so it is a conservative upper bound on the clock's own jitter.
//
// Usage: SynclockJitter [seconds] [--load] [--follow]
//   --load    spins background CPU to test jitter under stress.
//   --follow  also measures jitter while FOLLOWING a real Link peer (the grid
//             is driven by Link's beat clock, not the local timeline).

let args = CommandLine.arguments
let seconds = Double(args.dropFirst().first { Double($0) != nil } ?? "6") ?? 6
let underLoad = args.contains("--load")
let doFollow = args.contains("--follow")

final class Arrivals {
    private let lock = NSLock()
    private var times: [UInt64] = []
    func record(_ t: UInt64) { lock.lock(); times.append(t); lock.unlock() }
    var snapshot: [UInt64] { lock.lock(); defer { lock.unlock() }; return times }
}

func percentile(_ sorted: [Double], _ p: Double) -> Double {
    guard !sorted.isEmpty else { return 0 }
    let idx = Int((p / 100.0) * Double(sorted.count - 1).rounded())
    return sorted[min(max(idx, 0), sorted.count - 1)]
}

func startLoad() {
    guard underLoad else { return }
    for _ in 0..<3 {
        DispatchQueue.global(qos: .userInitiated).async {
            var x = 0.0
            while true { x += Foundation.sqrt(Double.random(in: 1...2)); if x > 1e12 { x = 0 } }
        }
    }
}

/// Attach a monitoring input client to `output`'s virtual source, recording the
/// host-time arrival of every 0xF8.
func monitor(_ output: CoreMIDIOutput) -> Arrivals {
    let arrivals = Arrivals()
    var client = MIDIClientRef()
    MIDIClientCreateWithBlock("SynclockJitterMon" as CFString, &client) { _ in }
    var inPort = MIDIPortRef()
    MIDIInputPortCreateWithBlock(client, "in" as CFString, &inPort) { listPtr, _ in
        let now = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        for packet in listPtr.unsafeSequence() {
            let len = Int(packet.pointee.length)
            withUnsafeBytes(of: packet.pointee.data) { raw in
                for i in 0..<len where raw[i] == MIDIByte.clock { arrivals.record(now) }
            }
        }
    }
    MIDIPortConnectSource(inPort, output.virtualSourceEndpoint, nil)
    return arrivals
}

func report(label: String, times: [UInt64], idealNs: Double) {
    guard times.count > 4 else { print("  \(label): too few ticks (\(times.count))"); return }
    var deviations: [Double] = []
    deviations.reserveCapacity(times.count - 1)
    for (a, b) in zip(times, times.dropFirst()) {
        deviations.append(abs(Double(b - a) - idealNs) / 1e6)
    }
    let sorted = deviations.sorted()
    let mean = deviations.reduce(0, +) / Double(deviations.count)
    print(String(format: "  %-14s ticks=%d  ideal=%.3fms  mean=%.3f  p50=%.3f  p95=%.3f  p99=%.3f  max=%.3f",
                 (label as NSString).utf8String!, times.count, idealNs / 1e6, mean,
                 percentile(sorted, 50), percentile(sorted, 95),
                 percentile(sorted, 99), sorted.last ?? 0))
}

func idealNs(forBPM bpm: Double) -> Double { 60.0 * 1e9 / (bpm * Double(midiClockPPQN)) }

/// Local free-running clock at `bpm`.
func measure(bpm: Double) {
    guard let output = try? CoreMIDIOutput(virtualSourceName: "SynclockJitter") else {
        print("CoreMIDI unavailable"); exit(2)
    }
    let arrivals = monitor(output)
    let engine = ClockEngine(tempo: Tempo(bpm), output: output)
    engine.start()
    Thread.sleep(forTimeInterval: seconds)
    engine.stop()
    Thread.sleep(forTimeInterval: 0.1)
    report(label: "\(Int(bpm)) BPM free", times: arrivals.snapshot, idealNs: idealNs(forBPM: bpm))
}

/// Clock FOLLOWING a real in-process Link peer: the tick grid is derived from
/// Link's beat clock via LinkFollowGrid. Verifies we stay tight while chasing Link.
func measureFollow(bpm: Double) {
    guard let peer = MCLinkCreate(bpm), let clock = MCLinkCreate(bpm) else {
        print("  follow: Link create failed"); return
    }
    defer { MCLinkDestroy(peer); MCLinkDestroy(clock) }
    MCLinkSetEnabled(peer, true)
    MCLinkSetEnabled(clock, true)
    MCLinkSetTempo(peer, bpm, MCLinkClockMicros(peer))

    var waited = 0.0
    while MCLinkPeerCount(clock) == 0 && waited < 5 { Thread.sleep(forTimeInterval: 0.1); waited += 0.1 }
    guard MCLinkPeerCount(clock) > 0 else { print("  follow: no Link peer discovered; skipping"); return }

    guard let output = try? CoreMIDIOutput(virtualSourceName: "SynclockJitterFollow") else {
        print("  follow: CoreMIDI unavailable"); return
    }
    let arrivals = monitor(output)
    let engine = ClockEngine(tempo: Tempo(bpm), output: output)
    engine.setGrid(LinkFollowGrid(link: clock))
    engine.start()
    Thread.sleep(forTimeInterval: seconds)
    engine.stop()
    Thread.sleep(forTimeInterval: 0.1)
    // Ideal interval comes from the live session tempo (what we're chasing).
    report(label: "\(Int(bpm)) BPM follow", times: arrivals.snapshot,
           idealNs: idealNs(forBPM: MCLinkTempo(clock)))
}

print("Synclock jitter harness — \(Int(seconds))s per tempo\(underLoad ? ", UNDER CPU LOAD" : "")")
print("Target: p95 ≤ ~0.3 ms, p99 ≤ ~1 ms (inter-tick deviation)")
startLoad()
measure(bpm: 120)
measure(bpm: 300)
if doFollow { measureFollow(bpm: 120) }
