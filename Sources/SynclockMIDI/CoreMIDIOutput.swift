import Foundation
import CoreMIDI
import SynclockCore

/// Direct-CoreMIDI implementation of `ClockOutput`. Owns a MIDI client, an
/// output port, and a named virtual source ("Synclock") that DAWs can subscribe
/// to. Sends are timestamped in the CoreMIDI host-time domain so the OS delivers
/// them precisely — no library hides the timestamps.
///
/// Per the canonical offset rule, the per-output send time is
/// `tick time + global offset + that route's sync delay`. A route whose adjusted
/// time would land in the past is clamped to "now" and counted as an underrun.
public final class CoreMIDIOutput: ClockOutput {
    /// One enabled physical destination plus its compensation.
    public struct Route {
        public let endpoint: MIDIEndpointRef
        public let delayNanos: Int64
        public let sendsTransport: Bool
        public init(endpoint: MIDIEndpointRef, delayNanos: Int64, sendsTransport: Bool) {
            self.endpoint = endpoint
            self.delayNanos = delayNanos
            self.sendsTransport = sendsTransport
        }
    }

    public enum SetupError: Error { case clientCreate(OSStatus), portCreate(OSStatus), virtualSource(OSStatus) }

    private var client = MIDIClientRef()
    private var outputPort = MIDIPortRef()
    private var virtualSource = MIDIEndpointRef()

    /// Global offset applied to every output (ns). Stacks with per-route delay.
    public var globalOffsetNanos: Int64 = 0
    /// Whether the virtual source emits (it's always enabled by default).
    public var virtualSourceEnabled = true
    /// Active physical destinations.
    public var routes: [Route] = []

    public private(set) var underrunCount = 0

    /// The virtual source endpoint, exposed so monitors/tests can subscribe.
    public var virtualSourceEndpoint: MIDIEndpointRef { virtualSource }

    public init(clientName: String = "Synclock",
                virtualSourceName: String = "Synclock") throws {
        var status = MIDIClientCreateWithBlock(clientName as CFString, &client) { _ in }
        guard status == noErr else { throw SetupError.clientCreate(status) }

        status = MIDIOutputPortCreate(client, "out" as CFString, &outputPort)
        guard status == noErr else { throw SetupError.portCreate(status) }

        status = MIDISourceCreate(client, virtualSourceName as CFString, &virtualSource)
        guard status == noErr else { throw SetupError.virtualSource(status) }
    }

    deinit {
        if virtualSource != 0 { MIDIEndpointDispose(virtualSource) }
        if client != 0 { MIDIClientDispose(client) }
    }

    // MARK: - ClockOutput

    public func scheduleTick(index: Int, hostTimeNanos: UInt64) {
        send([MIDIByte.clock], atHostNanos: hostTimeNanos)
    }

    /// Transport events (Start/Stop/Continue). Only reaches routes that opted
    /// into transport (clock-only routes are skipped).
    public func sendTransport(_ byte: UInt8, atHostNanos hostTimeNanos: UInt64) {
        send([byte], atHostNanos: hostTimeNanos, transportOnly: true)
    }

    /// Panic: Stop, then All-Notes-Off (CC 123) on all 16 channels, to the
    /// virtual source and every active route. Sent immediately.
    public func panic() {
        let now = HostTime.nowNanos()
        send([MIDIByte.stop], atHostNanos: now)
        for channel in 0..<16 {
            send([0xB0 | UInt8(channel), 123, 0], atHostNanos: now)
        }
    }

    // MARK: - Sending

    private func send(_ bytes: [UInt8], atHostNanos base: UInt64, transportOnly: Bool = false) {
        if virtualSourceEnabled {
            let ts = timestamp(forNanos: base, plus: globalOffsetNanos)
            var list = packetList(bytes: bytes, timestamp: ts)
            MIDIReceived(virtualSource, &list)
        }
        for route in routes where !transportOnly || route.sendsTransport {
            let ts = timestamp(forNanos: base, plus: globalOffsetNanos &+ route.delayNanos)
            var list = packetList(bytes: bytes, timestamp: ts)
            MIDISend(outputPort, route.endpoint, &list)
        }
    }

    private func timestamp(forNanos base: UInt64, plus offset: Int64) -> MIDITimeStamp {
        let adjusted = Int64(bitPattern: base) &+ offset
        let nowTicks = MIDIHostTime.now()
        guard adjusted > 0 else { underrunCount += 1; return nowTicks }
        let ticks = MIDIHostTime.machTicks(fromNanos: UInt64(adjusted))
        if ticks < nowTicks { underrunCount += 1; return nowTicks }
        return ticks
    }

    private func packetList(bytes: [UInt8], timestamp: MIDITimeStamp) -> MIDIPacketList {
        var list = MIDIPacketList()
        let packet = MIDIPacketListInit(&list)
        var data = bytes
        _ = MIDIPacketListAdd(&list, MemoryLayout<MIDIPacketList>.size, packet,
                              timestamp, data.count, &data)
        return list
    }
}
