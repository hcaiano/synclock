import AbletonLinkBridge
import Foundation

private final class CallbackState {
    private let lock = NSLock()
    private(set) var peerEvents = 0
    private(set) var tempoEvents = 0
    private(set) var startStopEvents = 0
    private(set) var lastPeers: UInt32 = 0
    private(set) var lastTempo: Double = 0
    private(set) var lastPlaying = false

    func recordPeers(_ peers: UInt32) {
        lock.lock()
        peerEvents += 1
        lastPeers = peers
        lock.unlock()
    }

    func recordTempo(_ bpm: Double) {
        lock.lock()
        tempoEvents += 1
        lastTempo = bpm
        lock.unlock()
    }

    func recordStartStop(_ playing: Bool) {
        lock.lock()
        startStopEvents += 1
        lastPlaying = playing
        lock.unlock()
    }
}

private struct Failure: Error, CustomStringConvertible {
    let description: String
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw Failure(description: message) }
}

private func waitForPeers(_ links: [OpaquePointer], timeout: TimeInterval) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if links.allSatisfy({ MCLinkPeerCount($0) >= 1 }) {
            return true
        }
        Thread.sleep(forTimeInterval: 0.1)
    }
    return links.allSatisfy({ MCLinkPeerCount($0) >= 1 })
}

private func wait(timeout: TimeInterval, until predicate: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if predicate() { return true }
        Thread.sleep(forTimeInterval: 0.05)
    }
    return predicate()
}

private let peerCallback: MCLinkPeerCountCallback = { context, peers in
    guard let context else { return }
    Unmanaged<CallbackState>.fromOpaque(context).takeUnretainedValue().recordPeers(peers)
}

private let tempoCallback: MCLinkTempoCallback = { context, bpm in
    guard let context else { return }
    Unmanaged<CallbackState>.fromOpaque(context).takeUnretainedValue().recordTempo(bpm)
}

private let startStopCallback: MCLinkStartStopCallback = { context, isPlaying in
    guard let context else { return }
    Unmanaged<CallbackState>.fromOpaque(context).takeUnretainedValue().recordStartStop(isPlaying)
}

let args = Set(CommandLine.arguments.dropFirst())
let requirePeer = args.contains("--require-peer")
let selfPeer = args.contains("--self-peer")
let timeout: TimeInterval = 6

do {
    try require(MCLinkIsRealImplementation(), "AbletonLinkBridge is still the stub")
    guard let primary = MCLinkCreate(120) else {
        throw Failure(description: "MCLinkCreate returned nil")
    }
    defer { MCLinkDestroy(primary) }

    let callbacks = CallbackState()
    let callbacksContext = Unmanaged.passUnretained(callbacks).toOpaque()
    MCLinkSetPeerCountCallback(primary, callbacksContext, peerCallback)
    MCLinkSetTempoCallback(primary, callbacksContext, tempoCallback)
    MCLinkSetStartStopCallback(primary, callbacksContext, startStopCallback)

    let t0 = MCLinkClockMicros(primary)
    Thread.sleep(forTimeInterval: 0.01)
    let t1 = MCLinkClockMicros(primary)
    try require(t1 > t0, "Link clock is not monotonic")

    try require(!MCLinkIsEnabled(primary), "Link should start disabled")
    MCLinkSetEnabled(primary, true)
    try require(MCLinkIsEnabled(primary), "Link did not enable")

    MCLinkSetStartStopSyncEnabled(primary, true)
    try require(MCLinkIsStartStopSyncEnabled(primary), "Start/stop sync did not enable")

    let now = MCLinkClockMicros(primary)
    MCLinkSetTempo(primary, 128, now)
    try require(abs(MCLinkTempo(primary) - 128) < 0.001, "Tempo set/read mismatch")
    try require(wait(timeout: 2) { callbacks.tempoEvents >= 1 }, "Tempo callback did not fire")

    let beat = MCLinkBeatAtTime(primary, now, 4)
    let phase = MCLinkPhaseAtTime(primary, now, 4)
    try require(phase >= 0 && phase < 4, "Phase out of quantum range")
    let beatTime = MCLinkTimeAtBeat(primary, beat, 4)
    try require(abs(Double(beatTime - now)) < 2_000, "timeAtBeat did not invert beatAtTime closely")

    MCLinkSetIsPlayingAndRequestBeatAtTime(primary, true, now, 0, 4)
    try require(MCLinkIsPlaying(primary), "Transport did not enter playing state")
    try require(wait(timeout: 2) { callbacks.startStopEvents >= 1 && callbacks.lastPlaying },
                "Start/stop callback did not fire")

    var peerLinks = [primary]
    var secondary: OpaquePointer?
    if selfPeer {
        secondary = MCLinkCreate(128)
        if let secondary {
            MCLinkSetEnabled(secondary, true)
            MCLinkSetStartStopSyncEnabled(secondary, true)
            peerLinks.append(secondary)
        }
    }
    defer {
        if let secondary { MCLinkDestroy(secondary) }
    }

    let peersOK = waitForPeers(peerLinks, timeout: timeout)
    if requirePeer || selfPeer {
        try require(peersOK, "No Link peer discovered within \(timeout)s")
        try require(wait(timeout: 2) { callbacks.peerEvents >= 1 && callbacks.lastPeers >= 1 },
                    "Peer-count callback did not fire")
    }

    print("SynclockLinkCheck OK")
    print("realImplementation=true")
    print("primaryPeerCount=\(MCLinkPeerCount(primary))")
    if let secondary {
        print("secondaryPeerCount=\(MCLinkPeerCount(secondary))")
    }
    print("tempo=\(MCLinkTempo(primary))")
    print("tempoCallbacks=\(callbacks.tempoEvents)")
    print("startStopCallbacks=\(callbacks.startStopEvents)")
    print("peerCallbacks=\(callbacks.peerEvents)")
    print("beat=\(beat)")
    print("phase=\(phase)")
} catch {
    fputs("SynclockLinkCheck FAILED: \(error)\n", stderr)
    exit(1)
}
