# Synclock — Build Plan

> Native macOS menubar **master MIDI clock + Ableton Link** app. The free, findable Mac one that syncs your gear without a DAW.
> Stack: Swift 5.9+ / SPM · AppKit (no SwiftUI) · LSUIElement menubar · GPLv2+. Sibling to Lineup.

## Goal
Ship a tiny, rock-solid menubar app that is the master clock for a hardware/software setup: tight MIDI clock out + transport, plus first-class Ableton Link (Free / Follow / Lead). Quality wedge = measurable low jitter, native feel ("Apple shipped it"), zero-DAW.

## Owners
- **Claude** — core timing/transport/MIDI, persistence, AppKit UI, packaging, planning, goal prompt.
- **Codex** — Ableton Link C-ABI bridge recipe (done, see findings.md), icon/branding, name vetting (done), adversarial review of timing code.
- **Henrique** — founder; design decisions (locked), test hardware, release.

## Quality bar (the product promise)
Timestamped CoreMIDI clock. Measure p95/p99 **inter-tick jitter** under CPU/UI load. Starting target: **p95 ≤ ~0.3 ms, p99 ≤ ~1 ms** at 120 & 300 BPM — validate empirically, adjust honestly. NOT "sample accurate" (no audio engine).

## Phases

| # | Phase | Status | Gate / Exit criteria |
|---|-------|--------|----------------------|
| 0 | **Link bridge build-proof spike** | ✅ complete | Codex vendored `Ableton/link` Link-4.0 submodule, wired Package.swift cxxSettings (header paths + LINK_PLATFORM_MACOSX=1), replaced stub with real `ableton::Link` behind the unchanged C ABI, `MCLinkIsRealImplementation()`==true. Verified: `swift build`, `swift run SynclockTests`, `swift run SynclockLinkCheck --self-peer`, and external-process peer proof with Ableton `LinkHutSilent` + `swift run SynclockLinkCheck --require-peer` (peer count + tempo/start-stop callbacks fired). |
| 1 | **Repo + skeleton + CI** | ✅ complete | SPM layout (AbletonLinkBridge C++ + SynclockCore + SynclockApp + SynclockTests) builds; GPLv2 LICENSE + README + notices; LSUIElement app launches as accessory with NSStatusItem; dependency-free runner `swift run SynclockTests` green. CI is present at `.github/workflows/ci.yml` and builds/tests/bundles the app on macOS. |
| 2 | **Core timing scheduler (hand-owned)** | ✅ complete | `HostTime` (CLOCK_UPTIME_RAW ns), `ClockScheduler` (pure lookahead-window math), `ClockEngine` (userInteractive `DispatchSourceTimer` wake/refill + deterministic `pump()` + phase-continuous tempo change) driving an injectable `ClockOutput`. Unit-tested and wired to real CoreMIDI via Phase 3; jitter validated in Phase 8. |
| 3 | **MIDI output + gear management** | ✅ complete | MIDIDiscovery + CoreMIDIOutput (virtual source, timestamped sends, per-route delay+global offset, Panic=Stop+AllNotesOff, underruns) + `GearModel` (reconcile, new-OFF, 4-state status, routes, panic targets) wired in `SyncEngine`. LIVE: app discovered real AF16Rig gear, all new-default-OFF, persisted. CoreMIDI setup notifications now debounce into automatic device refresh/reconcile; manual Refresh remains as an explicit fallback. |
| 4 | **Transport + tempo + modes** | ✅ complete | `TransportLogic` + `TapTempo` (unit-tested), wired through `SyncEngine.play/stop/toggle/setTempo` + popover/menu UI. Clock-while-stopped honored on launch. |
| 5 | **Ableton Link integration** | ✅ complete | `LinkFollowGrid` derives the MIDI tick grid from Link tempo+phase via a sampled `LinkClockMapper`; Free disables Link; Follow joins read-only + adopts peer tempo/start-stop; Lead keeps FreeRunningGrid + commits tempo/start-stop to Link. Verified: SynclockFollowCheck (peerCount=1, follow=137, lead=111), SynclockLinkCheck --self-peer, 83 unit checks, AND follow-mode jitter pass (`SynclockJitter --follow`: 120 BPM follow p95=0.055ms/p99=0.064ms — as tight as free-run). Callbacks→main verified safe (timing path queue-confined). Remaining (Codex, optional): external Ableton Live smoke test. |
| 6 | **Menubar UI (AppKit)** | ✅ complete | NSPopover (PopoverViewController) per mockup: tabular BPM, nudge, Play/Tap transport, Link segmented mode + peers, output-health + signature PulseView (Reduce-Motion aware), Theme from DESIGN.md. Left-click=popover, right-click=fallback menu. Tempo Dot menubar template glyph bundled. Offscreen-rendered + visually verified (`design/synclock-popover-coral.png`). Remaining polish only: deeper VoiceOver pass. |
| 7 | **Preferences + persistence** | ✅ complete | Persistence (SynclockSettings + SettingsStore) tested + live. UI: PreferencesWindowController with General · Devices · Link · About tabs; **Devices tab = the gear table** (NSTableView: status, editable nickname, enable, sync-delay stepper, transport) + no-devices empty state + Panic + Refresh. Launch-at-login uses `SMAppService`. Builds + launches. |
| 8 | **Timing test harness** | ✅ complete | `SynclockJitter` target: monitors the virtual source, reports p50/p95/p99 inter-tick deviation at 120 & 300 BPM, `--load` for CPU stress. MEASURED (idle, release): 120 BPM p95=0.045ms/p99=0.062ms; 300 BPM p95=0.028ms/p99=0.054ms. MEASURED under CPU load: 120 BPM p95=0.019ms/p99=0.028ms; 300 BPM p95=0.017ms/p99=0.024ms (one 16.633ms max outlier at 300 BPM, p95/p99 unaffected). All p95/p99 results are well inside the ≤0.3/≤1ms target. Remaining external acceptance: Henrique's AF16Rig + real synth list. |
| 9 | **Packaging + distribution** | build+DMG+Sparkle wiring ✅ / sign+notarize BLOCKED | `Scripts/build-app.sh` → launchable `Synclock.app` (Info.plist LSUIElement, Tempo Dot `Synclock.icns`, Sparkle.framework bundled, hardened runtime). `Scripts/make-dmg.sh` → drag-to-install `Synclock-<v>.dmg` and signs the DMG when a Developer ID identity is present. `Scripts/notarize.sh` notarizes/staples `.app` or `.dmg` and fails fast unless the artifact is Developer-ID signed. Sparkle is linked in `SynclockApp`; release builds inject `SUFeedURL` + `SUPublicEDKey` via `SPARKLE_PUBLIC_ED_KEY`. BLOCKED only on Henrique's Apple Developer ID and on an EdDSA key + first signed appcast item. Full runbook in RELEASING.md. |
| 10 | **Brand + marketing site** | ✅ complete | `site/index.html` static landing page (register=brand) reusing the real popover render + Tempo Dot icon: hero, the-problem (with the old-jitter code story), 3-step how-it-works, features (incl. live jitter stat + Link modes), download, free+BMC, GPLv2 footer. Passed impeccable design hook. Lineup-style Cloudflare Workers static-assets config (`site/wrangler.toml`, `_headers`, robots, sitemap, README). **DEPLOYED LIVE: `synclock` Worker on the Caiano account, custom domain `synclock.caiano.com` attached (DNS auto-created, HTTP 200, cert provisioned), with Pulse Coral + Tempo Dot site assets and OG card.** Remaining: optional pulse demo. |

## Production-readiness (woven across phases — for "fully production ready")
- **Gear model is core, not an afterthought** (Phase 3/7): works with ANY gear via live CoreMIDI discovery; per-device enable/nickname/delay/transport/status; new-device-OFF default.
- **States:** empty (no gear found, teaches the virtual port), device missing/reconnecting, virtual-port-creation failure, Link unavailable. No dead ends.
- **Accessibility:** full keyboard nav, visible focus, VoiceOver labels (announce transport+mode+BPM), status never color-only, Reduce Motion fallback for the pulse.
- **Safety:** new gear never auto-receives clock; Panic always reachable; confirm/hold on live-affecting actions.
- **Design source of truth:** PRODUCT.md (strategy), DESIGN.md (visual system), design/synclock-mockup.html (.png reference render).

## Deferred to v2 (explicitly out of scope for v1)
SPP, MTC, follow external MIDI clock-in, multiple rig profiles, per-device clock-while-stopped override, half/double tempo (nice-to-have). NOTE: per-device **sync delay** was pulled INTO v1 (Henrique, production-ready gear control).

## Open items
- Bundle id: **`com.caiano.synclock`** — RESOLVED. Personal projects use caiano.com; never gam3s.gg (company brand).
- Henrique's specific test hardware list (he has a lot of gear) — defines Phase 8 acceptance rig.
- Accent color: **RESOLVED**. Use Synclock's distinct Fresh Mint `#16C79A` (was Pulse Coral `#FF5C57`, then blue — Henrique: red/coral "doesn't look good", and blue is Lineup's; mint gives a fresh distinct feel).

## Status: BUILDING — ~97% of v1 done & verified. Pushed to github.com/hcaiano/synclock (main). Phases 0-8 and 10 complete; Synclock is live at synclock.caiano.com with Fresh Mint (#16C79A) branding (app + site recolored from coral; mint popover product shot redeployed). App icon redesign in progress (Codex, AI image-gen, branding/explorations-v3). Phase 9 scaffolding includes Sparkle app wiring, release appcast placeholder, build/notarize/DMG scripts, and runbook, but the final notarized DMG/appcast remains BLOCKED on Henrique's Apple Developer ID + Sparkle EdDSA key. 83 unit checks green; Phase 5 Follow/Lead proof green; free/follow/load jitter p95/p99 all beat the target. Open: Dev ID; full test-gear list; optional external Ableton Live smoke test.
