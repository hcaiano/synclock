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
| 1 | **Repo + skeleton + CI** | ✅ complete | SPM layout (AbletonLinkBridge C++ + SynclockCore + SynclockApp + SynclockTests) builds; GPLv2 LICENSE + README + notices; LSUIElement app launches as accessory with NSStatusItem; dependency-free runner `swift run SynclockTests` green (25 checks). CI = TODO. |
| 2 | **Core timing scheduler (hand-owned)** | ✅ core complete | `HostTime` (CLOCK_UPTIME_RAW ns), `ClockScheduler` (pure lookahead-window math), `ClockEngine` (userInteractive `DispatchSourceTimer` wake/refill + deterministic `pump()` + phase-continuous tempo change) driving an injectable `ClockOutput`. Unit-tested (41 checks). Remaining: wire to real CoreMIDI sink (Phase 3) + jitter validation (Phase 8). |
| 3 | **MIDI output + gear management** | ✅ core complete | MIDIDiscovery + CoreMIDIOutput (virtual source, timestamped sends, per-route delay+global offset, Panic=Stop+AllNotesOff, underruns) + `GearModel` (reconcile, new-OFF, 4-state status, routes, panic targets) wired in `SyncEngine`. LIVE: app discovered real AF16Rig gear, all new-default-OFF, persisted. Remaining: hotplug MIDI-notify re-reconcile (currently manual Refresh). |
| 4 | **Transport + tempo + modes** | ✅ core complete | `TransportLogic` + `TapTempo` (unit-tested), wired through `SyncEngine.play/stop/toggle/setTempo` + functional menu. Clock-while-stopped honored on launch. Remaining: tap UI + Follow/Lead tick-derivation (Phase 5, Codex). |
| 5 | **Ableton Link integration** | pending | Free / Follow Link / Lead Link modes wired to bridge; tempo+phase follow derives MIDI tick grid; Lead commits tempo/start-stop to session; Start/Stop sync; deterministic peer-vs-local conflict rules; UI always shows active mode. |
| 6 | **Menubar UI (AppKit)** | ✅ core complete | NSPopover (PopoverViewController) per mockup: tabular BPM, nudge, Play/Tap transport, Link segmented mode + peers, output-health + signature PulseView (Reduce-Motion aware), Theme from DESIGN.md. Left-click=popover, right-click=fallback menu. Offscreen-rendered + visually verified (design/synclock-popover-render.png). Remaining: B menubar template glyph (Codex), empty-state polish, deeper VoiceOver. |
| 7 | **Preferences + persistence** | ✅ core complete | Persistence (SynclockSettings + SettingsStore) tested + live. UI: PreferencesWindowController with General · Devices · Link · About tabs; **Devices tab = the gear table** (NSTableView: status, name, enable, sync-delay stepper, transport) + Panic + Refresh. Builds + launches. Remaining: launch-at-login (SMAppService), nickname inline edit, design polish. |
| 8 | **Timing test harness** | ✅ harness done | `SynclockJitter` target: monitors the virtual source, reports p50/p95/p99 inter-tick deviation at 120 & 300 BPM, `--load` for CPU stress. MEASURED (idle, release): 120 BPM p95=0.045ms/p99=0.062ms; 300 BPM p95=0.028ms/p99=0.054ms — **~5-6× better than target** (≤0.3/≤1ms). Remaining: under-load run + acceptance checklist vs Henrique's AF16Rig + real synths. |
| 9 | **Packaging + distribution** | pending | Notarized DMG, hardened runtime, Developer ID signing, Sparkle appcast, GitHub Releases. GPL source-availability satisfied. Locked B "Pulse Path" identity (.appiconset + menubar glyph) integrated. |
| 10 | **Brand + marketing site** | ✅ core complete | `site/index.html` static landing page (register=brand) reusing the real popover render + B icon: hero, the-problem (with the old-jitter code story), 3-step how-it-works, features (incl. live jitter stat + Link modes), download, free+BMC, GPLv2 footer. Passed impeccable design hook. Remaining: deploy to synclock.caiano.com (Henrique's DNS/hosting), OG image, optional pulse demo. |

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
- Accent color: **RESOLVED**. Reuse Lineup-family blue `#2F6BFF`.

## Status: BUILDING — ~85% of v1 done & verified. Pushed to github.com/hcaiano/synclock (main). Phases 0-4,6,7,8,10 complete; Phase 5 (Link Follow/Lead) in progress (Codex, TickGrid seam handed off); Phase 9 (notarized DMG + Sparkle) BLOCKED on Henrique's Apple Developer ID. 76 unit checks green; jitter p99 ~0.05ms @120 BPM. Open: Dev ID; deploy site to synclock.caiano.com; full test-gear list.
