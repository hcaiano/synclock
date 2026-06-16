import Foundation

/// Synclock's sync authority relative to an Ableton Link session. The UI must
/// always display the active mode (DESIGN.md: state you can trust at a glance).
public enum LinkMode: String, CaseIterable, Codable, Equatable {
    /// Ignore Link entirely — do not join the network. Local clock is master.
    case free
    /// Read Link tempo + phase and derive the MIDI tick grid from it. Local
    /// BPM is read-only; do not push tempo into the session.
    case followLink
    /// Commit local tempo + transport into the Link session.
    case leadLink

    /// Short label for the segmented control.
    public var label: String {
        switch self {
        case .free: return "Free"
        case .followLink: return "Follow"
        case .leadLink: return "Lead"
        }
    }

    /// Whether this mode joins the Link network (Free does not).
    public var joinsSession: Bool { self != .free }

    /// Whether local BPM edits are allowed (false while following).
    public var allowsLocalTempoEdit: Bool { self != .followLink }
}
