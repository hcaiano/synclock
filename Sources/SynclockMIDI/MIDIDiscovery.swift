import Foundation
import CoreMIDI

/// A CoreMIDI destination found on the system. Works with ANY gear — we never
/// hardcode endpoints; we enumerate whatever is connected.
public struct DiscoveredOutput: Equatable {
    public let uniqueID: Int32
    public let name: String
    public let endpoint: MIDIEndpointRef
}

public enum MIDIDiscovery {
    /// All current MIDI destinations (physical + other apps' virtual ports).
    public static func destinations() -> [DiscoveredOutput] {
        let count = MIDIGetNumberOfDestinations()
        var result: [DiscoveredOutput] = []
        result.reserveCapacity(count)
        for i in 0..<count {
            let ep = MIDIGetDestination(i)
            guard ep != 0 else { continue }
            let uid = intProperty(ep, kMIDIPropertyUniqueID) ?? 0
            let name = stringProperty(ep, kMIDIPropertyDisplayName)
                ?? stringProperty(ep, kMIDIPropertyName)
                ?? "Unknown"
            result.append(DiscoveredOutput(uniqueID: uid, name: name, endpoint: ep))
        }
        return result
    }

    static func intProperty(_ obj: MIDIObjectRef, _ key: CFString) -> Int32? {
        var value: Int32 = 0
        return MIDIObjectGetIntegerProperty(obj, key, &value) == noErr ? value : nil
    }

    static func stringProperty(_ obj: MIDIObjectRef, _ key: CFString) -> String? {
        var value: Unmanaged<CFString>?
        guard MIDIObjectGetStringProperty(obj, key, &value) == noErr,
              let cf = value?.takeRetainedValue() else { return nil }
        return cf as String
    }
}

/// Watches CoreMIDI setup changes so plugged/unplugged devices are reconciled
/// without requiring the user to press Refresh.
public final class MIDIHotplugMonitor {
    public enum SetupError: Error { case clientCreate(OSStatus) }

    private var client = MIDIClientRef()

    public init(onChange: @escaping () -> Void) throws {
        let status = MIDIClientCreateWithBlock("SynclockHotplug" as CFString, &client) { _ in
            DispatchQueue.main.async(execute: onChange)
        }
        guard status == noErr else { throw SetupError.clientCreate(status) }
    }

    deinit {
        if client != 0 { MIDIClientDispose(client) }
    }
}
