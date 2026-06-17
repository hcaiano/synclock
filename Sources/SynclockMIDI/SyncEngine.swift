import Foundation
import CoreMIDI
import SynclockCore
import AbletonLinkBridge

private final class LinkCallbackBox {
    weak var engine: SyncEngine?
    init(engine: SyncEngine) { self.engine = engine }
}

private let syncEngineTempoCallback: MCLinkTempoCallback = { context, bpm in
    guard let context else { return }
    let box = Unmanaged<LinkCallbackBox>.fromOpaque(context).takeUnretainedValue()
    box.engine?.linkTempoChanged(bpm)
}

private let syncEngineStartStopCallback: MCLinkStartStopCallback = { context, isPlaying in
    guard let context else { return }
    let box = Unmanaged<LinkCallbackBox>.fromOpaque(context).takeUnretainedValue()
    box.engine?.linkStartStopChanged(isPlaying)
}

/// The runtime that composes the whole app: settings + gear model + clock
/// scheduler + CoreMIDI output + the Link bridge. The UI (Phase 6) drives this
/// and reads `Snapshot` for display. Link off runs the local grid; Link on
/// derives MIDI tick timestamps from the active Ableton Link beat grid while
/// also publishing local tempo/transport changes into the session.
///
/// Call from the main thread. The clock runs on its own high-priority queue.
public final class SyncEngine {
    /// Immutable view for the UI.
    public struct Snapshot: Equatable {
        public var tempo: Tempo
        public var linkEnabled: Bool
        public var transport: TransportState
        public var peerCount: Int
        public var linkIsReal: Bool
        public var activeOutputs: Int
        public var missingOutputs: Int
    }

    private let store: SettingsStore
    private var settings: SynclockSettings
    private let output: CoreMIDIOutput
    private let clock: ClockEngine
    private var gear: GearModel
    private let link: OpaquePointer?
    private var linkCallbackContext: UnsafeMutableRawPointer?
    private var hotplugMonitor: MIDIHotplugMonitor?
    private var pendingHotplugRefresh: DispatchWorkItem?

    private var discovered: [DiscoveredOutput] = []
    private(set) public var transport: TransportState = .stopped
    private var clockRunning = false
    private let phaseLock = NSLock()
    private var phaseTempo: Tempo
    private var phaseAnchorHostNanos: UInt64
    private var phaseAnchorBeat: Double = 0
    private var phaseClockRunning = false
    private var phaseLinkEnabled: Bool

    public init(store: SettingsStore = SettingsStore()) throws {
        self.store = store
        let loaded = store.load()
        self.settings = loaded
        self.gear = loaded.gearModel
        self.output = try CoreMIDIOutput(virtualSourceName: loaded.virtualPortName)
        self.clock = ClockEngine(tempo: loaded.tempo, output: output)
        self.link = MCLinkCreate(loaded.bpm)
        self.phaseTempo = loaded.tempo
        self.phaseAnchorHostNanos = HostTime.nowNanos()
        self.phaseLinkEnabled = loaded.linkEnabled
        output.globalOffsetNanos = Int64((loaded.globalOffsetMs * 1_000_000).rounded())
        if let link {
            installLinkCallbacks(link)
            MCLinkSetStartStopSyncEnabled(link, true)
        }
        applyLinkEnabled(loaded.linkEnabled, at: HostTime.nowNanos(), persistSettings: false)
        refreshDevices()
        hotplugMonitor = try? MIDIHotplugMonitor { [weak self] in self?.scheduleHotplugRefresh() }
        // Honour clock-while-stopped on launch (continuous F8 even when stopped).
        updateClockRunning(at: HostTime.nowNanos())
    }

    deinit {
        if let link { MCLinkDestroy(link) }
        if let linkCallbackContext {
            Unmanaged<LinkCallbackBox>.fromOpaque(linkCallbackContext).release()
        }
    }

    // MARK: - Devices

    /// Re-enumerate outputs, reconcile against persisted settings, rebuild routes.
    public func refreshDevices() {
        discovered = MIDIDiscovery.destinations()
        gear.reconcile(present: discovered.map { DiscoveredEndpoint(uniqueID: $0.uniqueID, name: $0.name) })
        rebuildRoutes()
        persist()
    }

    private func scheduleHotplugRefresh() {
        pendingHotplugRefresh?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refreshDevices() }
        pendingHotplugRefresh = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func rebuildRoutes() {
        let byID = Dictionary(discovered.map { ($0.uniqueID, $0.endpoint) },
                              uniquingKeysWith: { a, _ in a })
        output.routes = gear.activeRoutes().compactMap { r in
            guard let endpoint = byID[r.uniqueID] else { return nil }
            return CoreMIDIOutput.Route(endpoint: endpoint,
                                        delayNanos: r.delayNanos,
                                        sendsTransport: r.sendsTransport)
        }
        output.globalOffsetNanos = Int64((settings.globalOffsetMs * 1_000_000).rounded())
    }

    // MARK: - Transport

    public func play() { applyTransport(.play) }
    public func stop() { applyTransport(.stop) }
    public func toggle() { applyTransport(transport == .playing ? .stop : .play) }

    private func applyTransport(_ action: TransportAction, mirrorToLink: Bool = true) {
        let decision = TransportLogic.resolve(state: transport, action: action,
                                              clockWhileStopped: settings.clockWhileStopped)
        transport = decision.state
        let now = HostTime.nowNanos() &+ 1_000_000 // 1 ms ahead
        for byte in decision.emit { output.sendTransport(byte, atHostNanos: now) }
        if mirrorToLink, settings.linkEnabled, let link {
            let linkNow = MCLinkClockMicros(link)
            if transport == .playing {
                MCLinkSetIsPlayingAndRequestBeatAtTime(link, true, linkNow, 0, LinkFollowGrid.defaultQuantum)
            } else {
                MCLinkSetIsPlaying(link, false, linkNow)
            }
        }
        updateClockRunning(at: now)
    }

    private func updateClockRunning(at now: UInt64) {
        let shouldRun = TransportLogic.clockRunning(state: transport,
                                                    clockWhileStopped: settings.clockWhileStopped)
        if shouldRun && !clockRunning {
            clock.start(at: now); clockRunning = true
            setPhaseClockRunning(true, resetLocalPhaseAt: now)
        } else if !shouldRun && clockRunning {
            clock.stop(); clockRunning = false
            setPhaseClockRunning(false, resetLocalPhaseAt: nil)
        }
    }

    /// Panic: stop transport, All-Notes-Off, halt the clock.
    public func panic() {
        output.panic()
        clock.stop(); clockRunning = false
        setPhaseClockRunning(false, resetLocalPhaseAt: nil)
        transport = .stopped
    }

    // MARK: - Settings mutations

    public func setTempo(_ tempo: Tempo) {
        let now = HostTime.nowNanos()
        reanchorLocalPhaseForTempoChange(at: now)
        settings.bpm = tempo.bpm
        setPhaseTempo(tempo)
        clock.setTempo(tempo, at: now)
        if let link, settings.linkEnabled {
            MCLinkSetTempo(link, tempo.bpm, Int64(MCLinkClockMicros(link)))
        }
        persist()
    }

    public func setLinkEnabled(_ on: Bool) {
        applyLinkEnabled(on, at: HostTime.nowNanos(), persistSettings: true)
    }

    public func setClockWhileStopped(_ on: Bool) {
        settings.clockWhileStopped = on
        updateClockRunning(at: HostTime.nowNanos())
        persist()
    }

    public func setGlobalOffset(ms: Double) {
        settings.globalOffsetMs = ms
        output.globalOffsetNanos = Int64((ms * 1_000_000).rounded())
        persist()
    }

    public func setDeviceEnabled(_ enabled: Bool, id: Int32) {
        gear.setEnabled(enabled, for: id); rebuildRoutes(); persist()
    }
    public func setDeviceNickname(_ name: String, id: Int32) {
        gear.setNickname(name, for: id); persist()
    }
    public func setDeviceSyncDelay(ms: Double, id: Int32) {
        gear.setSyncDelay(ms: ms, for: id); rebuildRoutes(); persist()
    }
    public func setDeviceSendTransport(_ on: Bool, id: Int32) {
        gear.setSendTransport(on, for: id); rebuildRoutes(); persist()
    }

    // MARK: - UI read model

    public var clockWhileStopped: Bool { settings.clockWhileStopped }
    public var virtualPortName: String { settings.virtualPortName }
    public var sortedDevices: [OutputSettings] { gear.sortedDevices }

    public func status(for id: Int32) -> OutputStatus {
        gear.status(for: id, transport: transport, clockWhileStopped: settings.clockWhileStopped)
    }

    public func snapshot() -> Snapshot {
        let peers = link.map { Int(MCLinkPeerCount($0)) } ?? 0
        let statuses = gear.sortedDevices.map { status(for: $0.uniqueID) }
        let displayedTempo: Tempo
        if settings.linkEnabled, let link {
            displayedTempo = Tempo(MCLinkTempo(link))
        } else {
            displayedTempo = settings.tempo
        }
        return Snapshot(
            tempo: displayedTempo,
            linkEnabled: settings.linkEnabled,
            transport: transport,
            peerCount: peers,
            linkIsReal: MCLinkIsRealImplementation(),
            activeOutputs: statuses.filter { $0 == .active }.count,
            missingOutputs: statuses.filter { $0 == .missing }.count)
    }

    /// Current phase in a four-beat bar, normalized to `[0, 1)`.
    ///
    /// Link ON samples Ableton Link's beat phase. Link OFF samples the local
    /// free-running clock when it is running (playing, or clock-while-stopped
    /// is ON). If Link is OFF and the local clock is not running, phase is the
    /// stopped downbeat: `0`.
    public func currentBarPhase() -> Double {
        let beat = currentBeatPhase()
        return beat / LinkFollowGrid.defaultQuantum
    }

    /// Current beat number in the four-beat bar (`0...3`). Returns `0` when
    /// stopped with Link OFF and clock-while-stopped OFF.
    public func currentBeatInBar() -> Int {
        min(3, max(0, Int((currentBarPhase() * LinkFollowGrid.defaultQuantum).rounded(.down))))
    }

    // MARK: -

    private func installLinkCallbacks(_ link: OpaquePointer) {
        let box = LinkCallbackBox(engine: self)
        let context = Unmanaged.passRetained(box).toOpaque()
        linkCallbackContext = context
        MCLinkSetTempoCallback(link, context, syncEngineTempoCallback)
        MCLinkSetStartStopCallback(link, context, syncEngineStartStopCallback)
    }

    private func applyLinkEnabled(_ on: Bool, at now: UInt64, persistSettings: Bool) {
        settings.linkEnabled = on
        setPhaseLinkEnabled(on)

        guard let link else {
            clock.setGrid(FreeRunningGrid(tempo: settings.tempo, origin: now), at: now)
            if persistSettings { persist() }
            return
        }

        MCLinkSetEnabled(link, on)
        MCLinkSetStartStopSyncEnabled(link, on)

        if on {
            settings.bpm = Tempo(MCLinkTempo(link)).bpm
            setPhaseTempo(settings.tempo)
            clock.setGrid(LinkFollowGrid(link: link,
                                         quantum: LinkFollowGrid.defaultQuantum,
                                         hostNanosAtSample: now),
                          at: now)
            applyLinkTransportIfNeeded(MCLinkIsPlaying(link))
        } else {
            seedLocalPhaseFromLinkIfPossible(link, at: now)
            clock.setGrid(FreeRunningGrid(tempo: settings.tempo, origin: now), at: now)
        }

        if persistSettings { persist() }
    }

    fileprivate func linkTempoChanged(_ bpm: Double) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.settings.linkEnabled else { return }
            let tempo = Tempo(bpm)
            self.settings.bpm = tempo.bpm
            self.setPhaseTempo(tempo)
            self.persist()
        }
    }

    fileprivate func linkStartStopChanged(_ isPlaying: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.settings.linkEnabled else { return }
            self.applyLinkTransportIfNeeded(isPlaying)
        }
    }

    private func applyLinkTransportIfNeeded(_ isPlaying: Bool) {
        let target: TransportState = isPlaying ? .playing : .stopped
        guard transport != target else { return }
        applyTransport(isPlaying ? .play : .stop, mirrorToLink: false)
    }

    private func persist() {
        settings.devices = Array(gear.devices.values)
        try? store.save(settings)
    }

    // MARK: - Bar phase sampler

    private func currentBeatPhase() -> Double {
        phaseLock.lock()
        let linkEnabled = phaseLinkEnabled
        let clockRunning = phaseClockRunning
        let tempo = phaseTempo
        let anchorHost = phaseAnchorHostNanos
        let anchorBeat = phaseAnchorBeat
        phaseLock.unlock()

        if linkEnabled, let link {
            let phase = MCLinkPhaseAtTime(link, MCLinkClockMicros(link), LinkFollowGrid.defaultQuantum)
            return normalizedBeatPhase(phase)
        }

        guard clockRunning else { return 0 }
        let now = HostTime.nowNanos()
        let elapsed = now >= anchorHost ? now - anchorHost : 0
        let beat = anchorBeat + Double(elapsed) / ClockMath.nanosecondsPerBeat(tempo)
        return normalizedBeatPhase(beat)
    }

    private func normalizedBeatPhase(_ beat: Double) -> Double {
        guard beat.isFinite else { return 0 }
        let quantum = LinkFollowGrid.defaultQuantum
        let phase = beat.truncatingRemainder(dividingBy: quantum)
        return phase >= 0 ? phase : phase + quantum
    }

    private func localBeatLocked(at now: UInt64) -> Double {
        let elapsed = now >= phaseAnchorHostNanos ? now - phaseAnchorHostNanos : 0
        return phaseAnchorBeat + Double(elapsed) / ClockMath.nanosecondsPerBeat(phaseTempo)
    }

    private func reanchorLocalPhaseForTempoChange(at now: UInt64) {
        phaseLock.lock()
        phaseAnchorBeat = localBeatLocked(at: now)
        phaseAnchorHostNanos = now
        phaseLock.unlock()
    }

    private func setPhaseTempo(_ tempo: Tempo) {
        phaseLock.lock()
        phaseTempo = tempo
        phaseLock.unlock()
    }

    private func setPhaseClockRunning(_ running: Bool, resetLocalPhaseAt now: UInt64?) {
        phaseLock.lock()
        if let now {
            phaseAnchorBeat = 0
            phaseAnchorHostNanos = now
        }
        phaseClockRunning = running
        phaseLock.unlock()
    }

    private func setPhaseLinkEnabled(_ enabled: Bool) {
        phaseLock.lock()
        phaseLinkEnabled = enabled
        phaseLock.unlock()
    }

    private func seedLocalPhaseFromLinkIfPossible(_ link: OpaquePointer, at now: UInt64) {
        let linkBeat = MCLinkBeatAtTime(link, MCLinkClockMicros(link), LinkFollowGrid.defaultQuantum)
        phaseLock.lock()
        phaseAnchorBeat = linkBeat.isFinite ? linkBeat : 0
        phaseAnchorHostNanos = now
        phaseTempo = settings.tempo
        phaseLock.unlock()
    }
}
