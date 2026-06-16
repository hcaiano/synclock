import Foundation

/// A MIDI output as currently discovered on the system (identity only). The
/// CoreMIDI layer supplies these; the model never sees endpoint handles.
public struct DiscoveredEndpoint: Equatable {
    public let uniqueID: Int32
    public let name: String
    public init(uniqueID: Int32, name: String) {
        self.uniqueID = uniqueID
        self.name = name
    }
}

/// The gear model: reconciles live-discovered outputs against persisted
/// per-device settings, keyed by stable unique id. Pure and testable — no
/// CoreMIDI. Encodes the live-safety rules: new devices arrive disabled, and
/// Panic never reaches brand-new/default-off outputs.
public struct GearModel: Codable, Equatable {
    /// Persisted settings by unique id (present and remembered-absent alike).
    public private(set) var devices: [Int32: OutputSettings] = [:]
    /// Unique ids currently present on the system.
    public private(set) var presentIDs: Set<Int32> = []

    public init() {}

    /// Decode persisted settings (presence is runtime-only, starts empty).
    public init(devices: [OutputSettings]) {
        for d in devices { self.devices[d.uniqueID] = d }
    }

    /// Reconcile against the current discovery snapshot. Known devices update
    /// their system name and become present; unknown devices are added DISABLED
    /// (new-device-OFF live safety); absent-but-remembered devices are retained.
    public mutating func reconcile(present endpoints: [DiscoveredEndpoint]) {
        presentIDs = Set(endpoints.map(\.uniqueID))
        for ep in endpoints {
            if var existing = devices[ep.uniqueID] {
                existing.systemName = ep.name
                devices[ep.uniqueID] = existing
            } else {
                devices[ep.uniqueID] = OutputSettings(uniqueID: ep.uniqueID,
                                                      systemName: ep.name,
                                                      enabled: false)
            }
        }
    }

    public func isPresent(_ id: Int32) -> Bool { presentIDs.contains(id) }

    /// Live status for an output given the current transport + setting.
    public func status(for id: Int32,
                       transport: TransportState,
                       clockWhileStopped: Bool) -> OutputStatus {
        guard let s = devices[id] else { return .missing }
        guard presentIDs.contains(id) else { return .missing }
        guard s.enabled else { return .off }
        let emitting = transport == .playing || clockWhileStopped
        return emitting ? .active : .ready
    }

    /// Present + enabled outputs that should receive clock/transport, as
    /// (uniqueID, delay-ns, sendsTransport) — the CoreMIDI layer binds these to
    /// endpoints and builds routes.
    public func activeRoutes() -> [(uniqueID: Int32, delayNanos: Int64, sendsTransport: Bool)] {
        devices.values
            .filter { presentIDs.contains($0.uniqueID) && $0.enabled }
            .map { ($0.uniqueID, Int64(($0.syncDelayMs * 1_000_000).rounded()), $0.sendTransport) }
    }

    /// Panic targets: present + enabled outputs only (never brand-new/off ones).
    /// The virtual source is panicked separately and always.
    public func panicTargetIDs() -> [Int32] {
        devices.values
            .filter { presentIDs.contains($0.uniqueID) && $0.enabled }
            .map(\.uniqueID)
    }

    // MARK: - Mutations (UI edits)

    public mutating func setEnabled(_ enabled: Bool, for id: Int32) {
        devices[id]?.enabled = enabled
    }
    public mutating func setNickname(_ name: String, for id: Int32) {
        devices[id]?.nickname = name
    }
    public mutating func setSyncDelay(ms: Double, for id: Int32) {
        devices[id]?.syncDelayMs = ms
    }
    public mutating func setSendTransport(_ on: Bool, for id: Int32) {
        devices[id]?.sendTransport = on
    }

    /// Stable, display-sorted settings for the Devices table.
    public var sortedDevices: [OutputSettings] {
        devices.values.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}
