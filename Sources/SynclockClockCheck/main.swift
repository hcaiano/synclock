import Foundation
import CoreMIDI
import SynclockCore
import SynclockMIDI

// Live end-to-end proof: run the real ClockEngine -> CoreMIDIOutput, monitor the
// virtual source from a second client, and count 0xF8 pulses over ~1 second.
// At 120 BPM expect 120 * 24 / 60 = 48 clocks/sec.

final class Counter {
    private let lock = NSLock()
    private var n = 0
    func bump() { lock.lock(); n += 1; lock.unlock() }
    var value: Int { lock.lock(); defer { lock.unlock() }; return n }
}

guard let output = try? CoreMIDIOutput() else {
    print("CoreMIDI unavailable; cannot run clock check"); exit(2)
}

let counter = Counter()
var monitorClient = MIDIClientRef()
MIDIClientCreateWithBlock("SynclockClockCheckMonitor" as CFString, &monitorClient) { _ in }
var inPort = MIDIPortRef()
MIDIInputPortCreateWithBlock(monitorClient, "in" as CFString, &inPort) { listPtr, _ in
    for packet in listPtr.unsafeSequence() {
        let len = Int(packet.pointee.length)
        withUnsafeBytes(of: packet.pointee.data) { raw in
            for i in 0..<len where raw[i] == MIDIByte.clock { counter.bump() }
        }
    }
}
MIDIPortConnectSource(inPort, output.virtualSourceEndpoint, nil)

let bpm = 120.0
let engine = ClockEngine(tempo: Tempo(bpm), output: output)
engine.start()
Thread.sleep(forTimeInterval: 1.0)
engine.stop()
Thread.sleep(forTimeInterval: 0.05) // let in-flight scheduled packets arrive

let count = counter.value
let expected = Int((bpm * Double(midiClockPPQN) / 60).rounded())
print("clock pulses in ~1s at \(Int(bpm)) BPM: \(count) (expected ~\(expected)), underruns: \(output.underrunCount)")
let ok = abs(count - expected) <= 2
print(ok ? "✓ clock rate within tolerance" : "✗ clock rate off")
exit(ok ? 0 : 1)
