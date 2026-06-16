import Foundation
import CoreMIDI
import SynclockCore
import SynclockMIDI

// Phase 8 jitter harness. Runs the real ClockEngine -> CoreMIDIOutput -> virtual
// source, captures the host-time arrival of each 0xF8 at a monitoring client,
// and reports inter-tick deviation percentiles versus the ideal interval.
//
// This measures END-TO-END delivery jitter (scheduler + CoreMIDI + monitor
// callback), so it is a conservative upper bound on the clock's own jitter.
//
// Usage: SynclockJitter [seconds] [--load]
//   --load spins background CPU to test jitter under stress.

let args = CommandLine.arguments
let seconds = Double(args.dropFirst().first { Double($0) != nil } ?? "6") ?? 6
let underLoad = args.contains("--load")

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

func startLoad() -> DispatchSourceTimer? {
    guard underLoad else { return nil }
    // A few busy queues to contend for CPU while the clock runs.
    for _ in 0..<3 {
        DispatchQueue.global(qos: .userInitiated).async {
            var x = 0.0
            while true { x += Foundation.sqrt(Double.random(in: 1...2)); if x > 1e12 { x = 0 } }
        }
    }
    return nil
}

func measure(bpm: Double) {
    guard let output = try? CoreMIDIOutput(virtualSourceName: "SynclockJitter") else {
        print("CoreMIDI unavailable"); exit(2)
    }
    let arrivals = Arrivals()
    var monitorClient = MIDIClientRef()
    MIDIClientCreateWithBlock("SynclockJitterMon" as CFString, &monitorClient) { _ in }
    var inPort = MIDIPortRef()
    MIDIInputPortCreateWithBlock(monitorClient, "in" as CFString, &inPort) { listPtr, _ in
        let now = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        for packet in listPtr.unsafeSequence() {
            let len = Int(packet.pointee.length)
            withUnsafeBytes(of: packet.pointee.data) { raw in
                for i in 0..<len where raw[i] == MIDIByte.clock { arrivals.record(now) }
            }
        }
    }
    MIDIPortConnectSource(inPort, output.virtualSourceEndpoint, nil)

    let engine = ClockEngine(tempo: Tempo(bpm), output: output)
    engine.start()
    Thread.sleep(forTimeInterval: seconds)
    engine.stop()
    Thread.sleep(forTimeInterval: 0.1)

    let times = arrivals.snapshot
    guard times.count > 4 else { print("  too few ticks captured (\(times.count))"); return }
    let idealNs = 60.0 * 1e9 / (bpm * Double(midiClockPPQN))
    // Deviation of each inter-arrival interval from the ideal, in milliseconds.
    var deviations: [Double] = []
    deviations.reserveCapacity(times.count - 1)
    for (a, b) in zip(times, times.dropFirst()) {
        deviations.append(abs(Double(b - a) - idealNs) / 1e6)
    }
    let sorted = deviations.sorted()
    let mean = deviations.reduce(0, +) / Double(deviations.count)
    print(String(format: "  %.0f BPM  ticks=%d  ideal=%.3fms  mean=%.3fms  p50=%.3f  p95=%.3f  p99=%.3f  max=%.3f",
                 bpm, times.count, idealNs / 1e6, mean,
                 percentile(sorted, 50), percentile(sorted, 95),
                 percentile(sorted, 99), sorted.last ?? 0))
}

print("Synclock jitter harness — \(Int(seconds))s per tempo\(underLoad ? ", UNDER CPU LOAD" : "")")
print("Target: p95 ≤ ~0.3 ms, p99 ≤ ~1 ms (inter-tick deviation)")
_ = startLoad()
measure(bpm: 120)
measure(bpm: 300)
