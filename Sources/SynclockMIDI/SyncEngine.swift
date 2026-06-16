import Foundation
import CoreMIDI
import SynclockCore
import AbletonLinkBridge

/// The runtime that composes the whole app: settings + gear model + clock
/// scheduler + CoreMIDI output + the Link bridge. The UI (Phase 6) drives this
/// and reads `Snapshot` for display. Free mode is fully functional here; Follow/
/// Lead tick-derivation is wired in Phase 5 (the bridge is already created).
///
/// Call from the main thread. The clock runs on its own high-priority queue.
public final class SyncEngine {
    /// Immutable view for the UI.
    public struct Snapshot: Equatable {
        public var tempo: Tempo
        public var mode: LinkMode
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

    private var discovered: [DiscoveredOutput] = []
    private(set) public var transport: TransportState = .stopped
    private var clockRunning = false

    public init(store: SettingsStore = SettingsStore()) throws {
        self.store = store
        let loaded = store.load()
        self.settings = loaded
        self.gear = loaded.gearModel
        self.output = try CoreMIDIOutput(virtualSourceName: loaded.virtualPortName)
        self.clock = ClockEngine(tempo: loaded.tempo, output: output)
        self.link = MCLinkCreate(loaded.bpm)
        output.globalOffsetNanos = Int64((loaded.globalOffsetMs * 1_000_000).rounded())
        refreshDevices()
        // Honour clock-while-stopped on launch (continuous F8 even when stopped).
        updateClockRunning(at: HostTime.nowNanos())
    }

    deinit { if let link { MCLinkDestroy(link) } }

    // MARK: - Devices

    /// Re-enumerate outputs, reconcile against persisted settings, rebuild routes.
    public func refreshDevices() {
        discovered = MIDIDiscovery.destinations()
        gear.reconcile(present: discovered.map { DiscoveredEndpoint(uniqueID: $0.uniqueID, name: $0.name) })
        rebuildRoutes()
        persist()
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

    private func applyTransport(_ action: TransportAction) {
        let decision = TransportLogic.resolve(state: transport, action: action,
                                              clockWhileStopped: settings.clockWhileStopped)
        transport = decision.state
        let now = HostTime.nowNanos() &+ 1_000_000 // 1 ms ahead
        for byte in decision.emit { output.sendTransport(byte, atHostNanos: now) }
        // Mirror transport into Link (Lead) — harmless in Free; Phase 5 refines.
        if settings.linkMode == .leadLink, let link {
            MCLinkSetIsPlaying(link, transport == .playing, Int64(MCLinkClockMicros(link)))
        }
        updateClockRunning(at: now)
    }

    private func updateClockRunning(at now: UInt64) {
        let shouldRun = TransportLogic.clockRunning(state: transport,
                                                    clockWhileStopped: settings.clockWhileStopped)
        if shouldRun && !clockRunning {
            clock.start(at: now); clockRunning = true
        } else if !shouldRun && clockRunning {
            clock.stop(); clockRunning = false
        }
    }

    /// Panic: stop transport, All-Notes-Off, halt the clock.
    public func panic() {
        output.panic()
        clock.stop(); clockRunning = false
        transport = .stopped
    }

    // MARK: - Settings mutations

    public func setTempo(_ tempo: Tempo) {
        guard settings.linkMode.allowsLocalTempoEdit else { return }
        settings.bpm = tempo.bpm
        clock.setTempo(tempo)
        if let link, settings.linkMode == .leadLink {
            MCLinkSetTempo(link, tempo.bpm, Int64(MCLinkClockMicros(link)))
        }
        persist()
    }

    public func setMode(_ mode: LinkMode) {
        settings.linkMode = mode
        if let link { MCLinkSetEnabled(link, mode.joinsSession) }
        persist()
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

    public var sortedDevices: [OutputSettings] { gear.sortedDevices }

    public func status(for id: Int32) -> OutputStatus {
        gear.status(for: id, transport: transport, clockWhileStopped: settings.clockWhileStopped)
    }

    public func snapshot() -> Snapshot {
        let peers = link.map { Int(MCLinkPeerCount($0)) } ?? 0
        let statuses = gear.sortedDevices.map { status(for: $0.uniqueID) }
        return Snapshot(
            tempo: settings.tempo,
            mode: settings.linkMode,
            transport: transport,
            peerCount: peers,
            linkIsReal: MCLinkIsRealImplementation(),
            activeOutputs: statuses.filter { $0 == .active }.count,
            missingOutputs: statuses.filter { $0 == .missing }.count)
    }

    // MARK: -

    private func persist() {
        settings.devices = Array(gear.devices.values)
        try? store.save(settings)
    }
}
