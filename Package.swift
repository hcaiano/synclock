// swift-tools-version:5.9
import PackageDescription

// Synclock — native macOS menubar master MIDI clock + Ableton Link.
// GPLv2-or-later. See LICENSE. Sibling to Lineup.
//
// Build risk lives in the C++ AbletonLinkBridge target. It vendors
// github.com/Ableton/link under ThirdParty/ableton-link and exposes a small C
// ABI for Swift (Sources/AbletonLinkBridge/include).
//
// Sparkle is wired for Phase 9 packaging; release builds enable it when the
// app bundle contains SUFeedURL + SUPublicEDKey.

let package = Package(
    name: "Synclock",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "synclock", targets: ["SynclockApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.3"),
    ],
    targets: [
        // C ABI bridge to Ableton Link's C++ source.
        .target(
            name: "AbletonLinkBridge",
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("../../ThirdParty/ableton-link/include"),
                .headerSearchPath("../../ThirdParty/ableton-link/modules/asio-standalone/asio/include"),
                .define("LINK_PLATFORM_MACOSX", to: "1"),
            ]
        ),
        // Pure, testable domain logic. No AppKit, no CoreMIDI I/O here.
        .target(
            name: "SynclockCore",
            dependencies: ["AbletonLinkBridge"]
        ),
        // Direct CoreMIDI I/O: virtual source, timestamped sends, discovery.
        // Implements SynclockCore's ClockOutput; the only target that touches
        // CoreMIDI, so the rest stays pure and testable.
        .target(
            name: "SynclockMIDI",
            dependencies: ["SynclockCore"],
            linkerSettings: [.linkedFramework("CoreMIDI")]
        ),
        // AppKit LSUIElement menubar agent.
        .executableTarget(
            name: "SynclockApp",
            dependencies: [
                "SynclockCore",
                "SynclockMIDI",
                "AbletonLinkBridge",
                .product(name: "Sparkle", package: "Sparkle"),
            ]
        ),
        // Dependency-free test runner (Lineup pattern): `swift run SynclockTests`.
        .executableTarget(
            name: "SynclockTests",
            dependencies: ["SynclockCore", "SynclockMIDI"]
        ),
        // Live end-to-end clock-rate check (timing-dependent, kept out of the
        // unit runner): emits real CoreMIDI clock for ~1s and counts pulses.
        .executableTarget(
            name: "SynclockClockCheck",
            dependencies: ["SynclockCore", "SynclockMIDI"],
            linkerSettings: [.linkedFramework("CoreMIDI")]
        ),
        // Phase 0 proof: exercises the real AbletonLinkBridge C ABI from Swift.
        .executableTarget(
            name: "SynclockLinkCheck",
            dependencies: ["AbletonLinkBridge"]
        ),
        // Phase 5 proof: exercises SyncEngine Follow/Lead against a real
        // Ableton Link peer in-process.
        .executableTarget(
            name: "SynclockFollowCheck",
            dependencies: ["SynclockCore", "SynclockMIDI", "AbletonLinkBridge"]
        ),
        // Phase 8 jitter harness: measures inter-tick delivery deviation
        // (p50/p95/p99) at 120 & 300 BPM, optionally under CPU load, and
        // (--follow) while chasing a real Ableton Link peer.
        .executableTarget(
            name: "SynclockJitter",
            dependencies: ["SynclockCore", "SynclockMIDI", "AbletonLinkBridge"],
            linkerSettings: [.linkedFramework("CoreMIDI")]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
