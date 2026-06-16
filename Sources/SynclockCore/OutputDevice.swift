import Foundation

/// Live status of a MIDI output (GOAL_PROMPT.md state model). Status is never
/// color-only in the UI — paired with a label/shape (DESIGN.md).
public enum OutputStatus: String, Codable, Equatable {
    /// Present, enabled, currently emitting clock/transport (incl. continuous
    /// F8 while stopped if clock-while-stopped is ON).
    case active
    /// Present, enabled, but not emitting right now per transport state.
    case ready
    /// Present but disabled-for-sync (includes new devices, which default OFF).
    case off
    /// Persisted but absent; settings preserved, awaiting confident reconnect.
    case missing

    public var label: String {
        switch self {
        case .active: return "Active"
        case .ready: return "Ready"
        case .off: return "Off"
        case .missing: return "Missing"
        }
    }
}

/// Per-output persisted settings, keyed by a stable CoreMIDI unique id with a
/// name fallback. Auto-discovery finds the endpoint; this carries the user's
/// choices for it. New devices are created with `enabled == false` (live safety).
public struct OutputSettings: Codable, Equatable {
    /// Stable identity. `uniqueID` is the CoreMIDI kMIDIPropertyUniqueID.
    public var uniqueID: Int32
    /// System endpoint name, used for display fallback and ambiguous matching.
    public var systemName: String
    /// User nickname; falls back to `systemName` when empty.
    public var nickname: String
    /// Receives clock/transport when true. New devices default to false.
    public var enabled: Bool
    /// Per-device send-time compensation in milliseconds (can be negative).
    public var syncDelayMs: Double
    /// When false, this output gets clock only (no Start/Stop/Continue).
    public var sendTransport: Bool

    public init(uniqueID: Int32,
                systemName: String,
                nickname: String = "",
                enabled: Bool = false,
                syncDelayMs: Double = 0,
                sendTransport: Bool = true) {
        self.uniqueID = uniqueID
        self.systemName = systemName
        self.nickname = nickname
        self.enabled = enabled
        self.syncDelayMs = syncDelayMs
        self.sendTransport = sendTransport
    }

    /// Name shown in the UI: nickname if set, else the system endpoint name.
    public var displayName: String {
        let trimmed = nickname.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? systemName : trimmed
    }
}
