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

    engine.setMode(.followLink)
    try require(wait(timeout: 6) { engine.snapshot().peerCount >= 1 },
                "SyncEngine did not discover the Link peer")

    MCLinkSetTempo(peer, 137, MCLinkClockMicros(peer))
    try require(wait(timeout: 3) { abs(engine.snapshot().tempo.bpm - 137) < 0.5 },
                "Follow mode did not adopt peer tempo")

    MCLinkSetIsPlayingAndRequestBeatAtTime(peer, true, MCLinkClockMicros(peer),
                                           0, LinkFollowGrid.defaultQuantum)
    try require(wait(timeout: 3) { engine.snapshot().transport == .playing },
                "Follow mode did not adopt Link play state")

    MCLinkSetIsPlaying(peer, false, MCLinkClockMicros(peer))
    try require(wait(timeout: 3) { engine.snapshot().transport == .stopped },
                "Follow mode did not adopt Link stop state")

    engine.setMode(.leadLink)
    engine.setTempo(Tempo(111))
    try require(wait(timeout: 3) { abs(MCLinkTempo(peer) - 111) < 0.5 },
                "Lead mode did not publish local tempo")

    engine.play()
    try require(wait(timeout: 3) { MCLinkIsPlaying(peer) },
                "Lead mode did not publish play state")

    engine.stop()
    try require(wait(timeout: 3) { !MCLinkIsPlaying(peer) },
                "Lead mode did not publish stop state")

    print("SynclockFollowCheck OK")
    print("peerCount=\(engine.snapshot().peerCount)")
    print("followTempo=137")
    print("leadTempo=111")
} catch {
    fputs("SynclockFollowCheck FAILED: \(error)\n", stderr)
    exit(1)
}
