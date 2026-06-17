import Foundation
import AbletonLinkBridge
import SynclockCore
import SynclockMIDI

private struct Failure: Error, CustomStringConvertible {
    let description: String
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw Failure(description: message) }
}

private func wait(timeout: TimeInterval, until predicate: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if predicate() { return true }
        RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))
    }
    return predicate()
}

private func makeTempStore() -> (SettingsStore, URL) {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("synclock-follow-check-\(UUID().uuidString)")
    return (SettingsStore(directory: dir), dir)
}

let (store, storeDirectory) = makeTempStore()
defer { try? FileManager.default.removeItem(at: storeDirectory) }

do {
    try require(MCLinkIsRealImplementation(), "AbletonLinkBridge is still the stub")
    let engine = try SyncEngine(store: store)
    guard let peer = MCLinkCreate(126) else {
        throw Failure(description: "MCLinkCreate returned nil")
    }
    defer { MCLinkDestroy(peer) }

    MCLinkSetEnabled(peer, true)
    MCLinkSetStartStopSyncEnabled(peer, true)

    engine.setLinkEnabled(true)
    try require(wait(timeout: 6) { engine.snapshot().peerCount >= 1 },
                "SyncEngine did not discover the Link peer")

    MCLinkSetTempo(peer, 137, MCLinkClockMicros(peer))
    try require(wait(timeout: 3) { abs(engine.snapshot().tempo.bpm - 137) < 0.5 },
                "Link ON did not adopt peer tempo")

    MCLinkSetIsPlayingAndRequestBeatAtTime(peer, true, MCLinkClockMicros(peer),
                                           0, LinkFollowGrid.defaultQuantum)
    try require(wait(timeout: 3) { engine.snapshot().transport == .playing },
                "Link ON did not adopt Link play state")

    MCLinkSetIsPlaying(peer, false, MCLinkClockMicros(peer))
    try require(wait(timeout: 3) { engine.snapshot().transport == .stopped },
                "Link ON did not adopt Link stop state")

    engine.setTempo(Tempo(111))
    try require(wait(timeout: 3) { abs(MCLinkTempo(peer) - 111) < 0.5 },
                "Link ON did not publish local tempo")

    engine.play()
    try require(wait(timeout: 3) { MCLinkIsPlaying(peer) },
                "Link ON did not publish play state")

    engine.stop()
    try require(wait(timeout: 3) { !MCLinkIsPlaying(peer) },
                "Link ON did not publish stop state")

    let phase = engine.currentBarPhase()
    let beat = engine.currentBeatInBar()
    try require(phase >= 0 && phase < 1, "currentBarPhase out of range")
    try require((0...3).contains(beat), "currentBeatInBar out of range")

    print("SynclockFollowCheck OK")
    print("peerCount=\(engine.snapshot().peerCount)")
    print("adoptedTempo=137")
    print("publishedTempo=111")
    print("barPhase=\(phase)")
    print("beatInBar=\(beat)")
} catch {
    fputs("SynclockFollowCheck FAILED: \(error)\n", stderr)
    exit(1)
}
