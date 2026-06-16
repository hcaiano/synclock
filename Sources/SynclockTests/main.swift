import Foundation
import SynclockCore
import SynclockMIDI

// Dependency-free test runner (Lineup pattern): `swift run synclock-tests`.
// Exits non-zero on any failure so it can gate CI without XCTest.

var failures = 0
var checks = 0

func check(_ condition: Bool, _ message: String) {
    checks += 1
    if !condition {
        failures += 1
        FileHandle.standardError.write(Data("  ✗ \(message)\n".utf8))
    }
}

func approx(_ a: Double, _ b: Double, _ eps: Double = 1e-6) -> Bool { abs(a - b) <= eps }

func group(_ name: String, _ body: () -> Void) {
    print("• \(name)")
    body()
}

group("Tempo clamps to 30...300") {
    check(Tempo(10).bpm == 30, "below range clamps to 30")
    check(Tempo(999).bpm == 300, "above range clamps to 300")
    check(Tempo(122.5).bpm == 122.5, "in-range preserved")
    check(Tempo(.nan).bpm == 30, "NaN clamps to lower bound")
}

group("Tempo nudge stays in range") {
    check(Tempo(300).nudged(by: 1).bpm == 300, "nudge past max clamps")
    check(Tempo(30).nudged(by: -1).bpm == 30, "nudge past min clamps")
    check(approx(Tempo(120).nudged(by: 0.1).bpm, 120.1), "fine nudge applies")
}

group("Tempo display trims trailing .0") {
    check(Tempo(120).description == "120", "whole number has no decimal")
    check(Tempo(122.5).description == "122.5", "decimal preserved")
}

group("ClockMath tick interval") {
    // At 120 BPM: 120*24 = 2880 ticks/min -> 60e9/2880 ns ≈ 20833333.33 ns.
    check(approx(ClockMath.nanosecondsPerTick(Tempo(120)), 60e9 / 2880, 1e-3),
          "120 BPM tick interval")
    // A beat = 24 ticks; at 120 BPM that is 0.5 s = 5e8 ns.
    check(approx(ClockMath.nanosecondsPerBeat(Tempo(120)), 5e8, 1e-3),
          "120 BPM beat = 500ms")
    // Faster tempo -> shorter ticks.
    check(ClockMath.nanosecondsPerTick(Tempo(240)) < ClockMath.nanosecondsPerTick(Tempo(120)),
          "higher BPM -> shorter tick")
}

group("ClockMath tick timestamps are monotonic") {
    let t = Tempo(174)
    let origin: UInt64 = 1_000_000
    let t0 = ClockMath.tickTime(index: 0, tempo: t, originNanos: origin)
    let t1 = ClockMath.tickTime(index: 1, tempo: t, originNanos: origin)
    let t100 = ClockMath.tickTime(index: 100, tempo: t, originNanos: origin)
    check(t0 == origin, "tick 0 at origin")
    check(t1 > t0, "tick 1 after tick 0")
    check(t100 > t1, "tick 100 after tick 1")
}

group("LinkMode semantics") {
    check(LinkMode.free.joinsSession == false, "Free does not join")
    check(LinkMode.followLink.joinsSession, "Follow joins")
    check(LinkMode.leadLink.joinsSession, "Lead joins")
    check(LinkMode.followLink.allowsLocalTempoEdit == false, "Follow is tempo read-only")
    check(LinkMode.free.allowsLocalTempoEdit, "Free allows tempo edit")
    check(LinkMode.allCases.count == 3, "three modes")
}

group("OutputSettings defaults to OFF (live safety)") {
    let d = OutputSettings(uniqueID: 42, systemName: "IAC Bus 1")
    check(d.enabled == false, "new device defaults disabled")
    check(d.sendTransport, "transport on by default")
    check(d.displayName == "IAC Bus 1", "display falls back to system name")
    var named = d
    named.nickname = "TR-8S"
    check(named.displayName == "TR-8S", "nickname overrides display")
}

group("HostTime is monotonic") {
    let a = HostTime.nowNanos()
    let b = HostTime.nowNanos()
    check(b >= a, "host time does not go backwards")
    check(a > 0, "host time is positive")
}

group("ClockScheduler.lastDueIndex") {
    let t = Tempo(120) // ~20.833 ms/tick
    check(ClockScheduler.lastDueIndex(by: 0, origin: 0, tempo: t) == 0, "tick 0 due at origin")
    check(ClockScheduler.lastDueIndex(by: 100, origin: 1000, tempo: t) == -1, "nothing due before origin")
    // horizon 50ms -> floor(50/20.833) = 2
    check(ClockScheduler.lastDueIndex(by: 50_000_000, origin: 0, tempo: t) == 2, "two ticks by 50ms")
}

group("ClockScheduler.ticksToSchedule windows correctly") {
    let t = Tempo(120)
    // now=0, lookahead 20ms: only tick 0 (tick 1 at ~20.83ms > 20ms horizon).
    let r0 = ClockScheduler.ticksToSchedule(now: 0, lookaheadNanos: 20_000_000,
                                            lastScheduledIndex: -1, origin: 0, tempo: t)
    check(r0 == 0...0, "first window schedules only tick 0")
    // nothing new at the same now.
    let r0b = ClockScheduler.ticksToSchedule(now: 0, lookaheadNanos: 20_000_000,
                                             lastScheduledIndex: 0, origin: 0, tempo: t)
    check(r0b == nil, "no duplicate scheduling")
    // advance to 25ms: horizon 45ms -> lastDue 2 -> schedule 1...2.
    let r1 = ClockScheduler.ticksToSchedule(now: 25_000_000, lookaheadNanos: 20_000_000,
                                            lastScheduledIndex: 0, origin: 0, tempo: t)
    check(r1 == 1...2, "advancing schedules the next ticks")
}

final class RecordingOutput: ClockOutput {
    var ticks: [(index: Int, time: UInt64)] = []
    func scheduleTick(index: Int, hostTimeNanos: UInt64) {
        ticks.append((index, hostTimeNanos))
    }
}

group("ClockEngine schedules monotonic ticks via pump") {
    let out = RecordingOutput()
    let engine = ClockEngine(tempo: Tempo(120), output: out)
    engine.startForTesting(at: 0)
    engine.pump(now: 0)
    engine.pump(now: 25_000_000)
    engine.pump(now: 60_000_000)
    let indices = out.ticks.map(\.index)
    check(indices == Array(0...indices.count - 1), "tick indices are contiguous from 0")
    check(indices.count >= 3, "several ticks scheduled across pumps")
    let times = out.ticks.map(\.time)
    check(zip(times, times.dropFirst()).allSatisfy { $0 < $1 }, "timestamps strictly increasing")
    // tick 0 lands at origin (0); spacing ≈ 20.833 ms.
    check(times.first == 0, "tick 0 at origin")
    if times.count >= 2 {
        let dt = Double(times[1] - times[0])
        check(approx(dt, 60e9 / 2880, 1.0), "tick spacing ≈ 20.833 ms at 120 BPM")
    }
}

group("ClockEngine pump does nothing when stopped") {
    let out = RecordingOutput()
    let engine = ClockEngine(tempo: Tempo(120), output: out)
    engine.pump(now: 0) // never started
    check(out.ticks.isEmpty, "no ticks while stopped")
}

group("ClockEngine tempo change stays phase-continuous") {
    let out = RecordingOutput()
    let engine = ClockEngine(tempo: Tempo(120), output: out)
    engine.startForTesting(at: 0)
    engine.pump(now: 25_000_000)        // schedule a few ticks at 120
    let lastBefore = out.ticks.last!
    engine.setTempoForTesting(Tempo(240), at: 25_000_000)
    engine.pump(now: 60_000_000)        // continue at 240
    let firstAfter = out.ticks[out.ticks.firstIndex(where: { $0.index == lastBefore.index + 1 })!]
    let gap = Double(firstAfter.time - lastBefore.time)
    // After doubling tempo, the very next tick is one 240-BPM interval later.
    check(approx(gap, 60e9 / (240 * 24), 2.0), "next tick honors new tempo interval")
    check(firstAfter.time > lastBefore.time, "grid stays monotonic across tempo change")
}

final class FakeOffsetGrid: TickGrid {
    let interval: UInt64
    init(interval: UInt64) { self.interval = interval }
    func reset(at now: UInt64) {}                                   // Link-like: ignores reset
    func setTempo(_ t: Tempo, at now: UInt64, lastScheduledIndex: Int) {}
    func hostTimeNanos(forTick index: Int) -> UInt64 { UInt64(index) * interval }
    func lastDueIndex(byHostNanos horizon: UInt64) -> Int { Int(horizon / interval) }
}

group("ClockEngine grid swap anchors to current position (no replay)") {
    let out = RecordingOutput()
    let engine = ClockEngine(tempo: Tempo(120), output: out)
    let now: UInt64 = 1_000_000_000            // 1 s
    engine.startForTesting(at: now)
    engine.setGridForTesting(FakeOffsetGrid(interval: 20_000_000), at: now) // tick i at i*20ms
    engine.pump(now: now)
    let indices = out.ticks.map(\.index)
    check(!indices.isEmpty, "scheduled at least one tick")
    check(indices.allSatisfy { $0 >= 49 }, "no replay of beat-0 history; starts near current index (~50)")
    check(zip(indices, indices.dropFirst()).allSatisfy { $0 < $1 }, "indices monotonic after swap")
}

group("TransportLogic emits Start/Stop and gates clock") {
    let playFromStop = TransportLogic.resolve(state: .stopped, action: .play, clockWhileStopped: true)
    check(playFromStop.state == .playing, "play -> playing")
    check(playFromStop.emit == [MIDIByte.start], "play emits Start (0xFA)")
    check(playFromStop.clockRunning, "clock runs while playing")

    let stopCWSon = TransportLogic.resolve(state: .playing, action: .stop, clockWhileStopped: true)
    check(stopCWSon.emit == [MIDIByte.stop], "stop emits Stop (0xFC)")
    check(stopCWSon.clockRunning, "clock keeps running when clock-while-stopped ON")

    let stopCWSoff = TransportLogic.resolve(state: .playing, action: .stop, clockWhileStopped: false)
    check(stopCWSoff.clockRunning == false, "clock stops when clock-while-stopped OFF")

    let redundantPlay = TransportLogic.resolve(state: .playing, action: .play, clockWhileStopped: false)
    check(redundantPlay.emit.isEmpty, "play while playing emits nothing")
}

group("TapTempo estimates BPM from taps") {
    var tap = TapTempo()
    let halfSecond: UInt64 = 500_000_000 // 120 BPM
    check(tap.tap(at: 0) == nil, "first tap has no estimate")
    let t1 = tap.tap(at: halfSecond)
    check(t1 != nil && approx(t1!.bpm, 120, 0.5), "two taps at 0.5s -> ~120 BPM")
    let t2 = tap.tap(at: 2 * halfSecond)
    check(t2 != nil && approx(t2!.bpm, 120, 0.5), "third tap holds ~120 BPM")
    // A long gap resets the run.
    var tap2 = TapTempo()
    _ = tap2.tap(at: 0)
    _ = tap2.tap(at: halfSecond)
    check(tap2.tap(at: halfSecond + 5_000_000_000) == nil, "tap after long gap restarts")
}

group("GearModel reconcile adds new devices OFF") {
    var model = GearModel()
    model.reconcile(present: [DiscoveredEndpoint(uniqueID: 1, name: "TR-8S"),
                              DiscoveredEndpoint(uniqueID: 2, name: "Digitakt")])
    check(model.devices.count == 2, "two devices tracked")
    check(model.devices[1]?.enabled == false, "new device 1 defaults OFF")
    check(model.devices[2]?.enabled == false, "new device 2 defaults OFF")
    check(model.isPresent(1), "device 1 present")
}

group("GearModel status reflects presence/enabled/transport") {
    var model = GearModel()
    model.reconcile(present: [DiscoveredEndpoint(uniqueID: 1, name: "TR-8S")])
    check(model.status(for: 1, transport: .stopped, clockWhileStopped: false) == .off,
          "present but disabled -> off")
    model.setEnabled(true, for: 1)
    check(model.status(for: 1, transport: .stopped, clockWhileStopped: false) == .ready,
          "enabled, stopped, no clock-while-stopped -> ready")
    check(model.status(for: 1, transport: .stopped, clockWhileStopped: true) == .active,
          "enabled, stopped, clock-while-stopped -> active")
    check(model.status(for: 1, transport: .playing, clockWhileStopped: false) == .active,
          "enabled, playing -> active")
    // Unplug it.
    model.reconcile(present: [])
    check(model.status(for: 1, transport: .playing, clockWhileStopped: false) == .missing,
          "absent -> missing, settings retained")
    check(model.devices[1]?.enabled == true, "settings preserved across disconnect")
}

group("GearModel Panic + routes exclude new/off devices") {
    var model = GearModel()
    model.reconcile(present: [DiscoveredEndpoint(uniqueID: 1, name: "On"),
                              DiscoveredEndpoint(uniqueID: 2, name: "OffNew")])
    model.setEnabled(true, for: 1)
    model.setSyncDelay(ms: 12, for: 1)
    let panic = model.panicTargetIDs()
    check(panic == [1], "panic targets only present+enabled (not new/off)")
    let routes = model.activeRoutes()
    check(routes.count == 1, "one active route")
    check(routes.first?.delayNanos == 12_000_000, "12ms -> 12,000,000 ns")
}

group("SettingsStore round-trips and survives corruption") {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent("synclock-test-\(UUID().uuidString)")
    let store = SettingsStore(directory: tmp)

    check(store.load() == .defaults, "missing file -> defaults")

    var s = SynclockSettings.defaults
    s.bpm = 137.5
    s.linkMode = .followLink
    s.clockWhileStopped = false
    s.globalOffsetMs = -3
    s.devices = [OutputSettings(uniqueID: 7, systemName: "TR-8S", nickname: "Drums",
                                enabled: true, syncDelayMs: 12, sendTransport: false)]
    try? store.save(s)
    let loaded = store.load()
    check(loaded == s, "settings round-trip through JSON")
    check(loaded.gearModel.devices[7]?.nickname == "Drums", "gear model seeds from persisted devices")

    // Corrupt the file -> defaults + backup, no crash.
    try? Data("{ not json".utf8).write(to: store.fileURL)
    check(store.load() == .defaults, "corrupt file -> defaults")
    let backups = (try? FileManager.default.contentsOfDirectory(atPath: tmp.path)) ?? []
    check(backups.contains { $0.hasPrefix("settings.corrupt-") }, "corrupt file backed up")

    try? FileManager.default.removeItem(at: tmp)
}

group("MIDIDiscovery does not crash") {
    let dests = MIDIDiscovery.destinations()
    check(dests.count >= 0, "destinations enumerated (\(dests.count) found)")
}

group("CoreMIDIOutput sends + tracks underruns") {
    if let output = try? CoreMIDIOutput() {
        // Future tick: fine.
        output.scheduleTick(index: 0, hostTimeNanos: HostTime.nowNanos() + 10_000_000)
        check(output.underrunCount == 0, "future tick is not an underrun")
        // Past tick: clamped to now and counted as underrun.
        output.scheduleTick(index: 1, hostTimeNanos: 1)
        check(output.underrunCount >= 1, "past tick counted as underrun")
    } else {
        print("  (skipped: CoreMIDI client unavailable in this environment)")
    }
}

print("")
if failures == 0 {
    print("✓ all \(checks) checks passed")
    exit(0)
} else {
    print("✗ \(failures)/\(checks) checks failed")
    exit(1)
}
