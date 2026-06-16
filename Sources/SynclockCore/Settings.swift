import Foundation

/// Persisted application settings. Schema-versioned for forward migration
/// (Lineup pattern). Single global profile in v1; the shape is ready to nest
/// under a profiles map later without breaking older files.
public struct SynclockSettings: Codable, Equatable {
    public static let currentSchema = 1

    public var schema: Int
    public var bpm: Double
    public var linkMode: LinkMode
    public var clockWhileStopped: Bool
    public var globalOffsetMs: Double
    public var virtualPortName: String
    public var devices: [OutputSettings]

    public init(schema: Int = SynclockSettings.currentSchema,
                bpm: Double = 120,
                linkMode: LinkMode = .free,
                clockWhileStopped: Bool = true,
                globalOffsetMs: Double = 0,
                virtualPortName: String = "Synclock",
                devices: [OutputSettings] = []) {
        self.schema = schema
        self.bpm = bpm
        self.linkMode = linkMode
        self.clockWhileStopped = clockWhileStopped
        self.globalOffsetMs = globalOffsetMs
        self.virtualPortName = virtualPortName
        self.devices = devices
    }

    /// Default settings for a fresh install.
    public static var defaults: SynclockSettings { SynclockSettings() }

    /// A `Tempo` clamped from the stored bpm.
    public var tempo: Tempo { Tempo(bpm) }

    /// A reconcilable gear model seeded from persisted device settings.
    public var gearModel: GearModel { GearModel(devices: devices) }
}
