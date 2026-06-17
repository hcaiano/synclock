import Foundation

/// Persisted application settings. Schema-versioned for forward migration
/// (Lineup pattern). Single global profile in v1; the shape is ready to nest
/// under a profiles map later without breaking older files.
public struct SynclockSettings: Codable, Equatable {
    public static let currentSchema = 2

    public var schema: Int
    public var bpm: Double
    public var linkEnabled: Bool
    public var clockWhileStopped: Bool
    public var globalOffsetMs: Double
    public var virtualPortName: String
    public var devices: [OutputSettings]

    public init(schema: Int = SynclockSettings.currentSchema,
                bpm: Double = 120,
                linkEnabled: Bool = false,
                clockWhileStopped: Bool = true,
                globalOffsetMs: Double = 0,
                virtualPortName: String = "Synclock",
                devices: [OutputSettings] = []) {
        self.schema = schema
        self.bpm = bpm
        self.linkEnabled = linkEnabled
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

    private enum CodingKeys: String, CodingKey {
        case schema
        case bpm
        case linkEnabled
        case linkMode
        case clockWhileStopped
        case globalOffsetMs
        case virtualPortName
        case devices
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schema = (try? container.decode(Int.self, forKey: .schema)) ?? 1
        bpm = (try? container.decode(Double.self, forKey: .bpm)) ?? 120
        if let decoded = try? container.decode(Bool.self, forKey: .linkEnabled) {
            linkEnabled = decoded
        } else {
            let legacy = (try? container.decode(String.self, forKey: .linkMode)) ?? "free"
            linkEnabled = legacy == "followLink" || legacy == "leadLink"
        }
        clockWhileStopped = (try? container.decode(Bool.self, forKey: .clockWhileStopped)) ?? true
        globalOffsetMs = (try? container.decode(Double.self, forKey: .globalOffsetMs)) ?? 0
        virtualPortName = (try? container.decode(String.self, forKey: .virtualPortName)) ?? "Synclock"
        devices = (try? container.decode([OutputSettings].self, forKey: .devices)) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schema, forKey: .schema)
        try container.encode(bpm, forKey: .bpm)
        try container.encode(linkEnabled, forKey: .linkEnabled)
        try container.encode(clockWhileStopped, forKey: .clockWhileStopped)
        try container.encode(globalOffsetMs, forKey: .globalOffsetMs)
        try container.encode(virtualPortName, forKey: .virtualPortName)
        try container.encode(devices, forKey: .devices)
    }
}
