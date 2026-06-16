import Foundation

/// Loads and saves `SynclockSettings` as JSON at `~/.config/synclock/settings.json`
/// (Lineup pattern). Corrupt files are backed up and replaced with defaults
/// rather than crashing. Writes are atomic.
public struct SettingsStore {
    public let directory: URL
    public var fileURL: URL { directory.appendingPathComponent("settings.json") }

    public init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.directory = home.appendingPathComponent(".config/synclock", isDirectory: true)
        }
    }

    /// Load settings, or defaults when missing. A corrupt file is moved aside to
    /// `settings.corrupt-<time>.json` and defaults are returned, so a bad file
    /// never bricks the app.
    public func load() -> SynclockSettings {
        guard let data = try? Data(contentsOf: fileURL) else { return .defaults }
        do {
            let decoded = try JSONDecoder().decode(SynclockSettings.self, from: data)
            return migrate(decoded)
        } catch {
            backupCorruptFile()
            return .defaults
        }
    }

    /// Atomically persist settings (creating the directory if needed).
    public func save(_ settings: SynclockSettings) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Forward-migrate older schemas. v1 is the first schema; this is the seam
    /// where future versions fill defaults for new fields.
    private func migrate(_ settings: SynclockSettings) -> SynclockSettings {
        guard settings.schema < SynclockSettings.currentSchema else { return settings }
        var migrated = settings
        // (No older schema yet; bump and fall through as versions are added.)
        migrated.schema = SynclockSettings.currentSchema
        return migrated
    }

    private func backupCorruptFile() {
        let stamp = Int(Date().timeIntervalSince1970)
        let backup = directory.appendingPathComponent("settings.corrupt-\(stamp).json")
        try? FileManager.default.moveItem(at: fileURL, to: backup)
    }
}
