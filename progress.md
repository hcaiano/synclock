# Synclock — Progress Log

## Session 1 — 2026-06-16 — Cofounder grill + plan (Claude + Codex + Henrique)
- Studied Lineup (~/code/window-manager) for house style; extracted old midiclock features + its jitter flaw.
- Ran cofounder grill via herdr-pair (sid 1781612223-b980). Codex delivered 16→18 engineering-grade grill questions + Link spike + name vetting + icon spec.
- Henrique override: dependencies ARE allowed (not zero-dep) — choose per subsystem by quality.
- Locked full v1 design (see findings.md). Name = **Synclock**. License = **GPLv2+**.
- Codex verified Ableton/link source path (not LinkKit) + C-ABI bridge recipe → de-risks Link.
- Codex generating icon assets bound to Synclock (in flight).
- Created task_plan.md (10 phases, 0–9), findings.md, progress.md.

### Done
- Drafted GOAL_PROMPT.md; Codex reviewed + sent `accepted` (confirmed Phase 0 gate, Free/Follow/Lead semantics, canonical-time rule). Claude `accepted` → planning pair complete.
- Folded Codex note: MIDIEventList primary + MIDIPacketList fallback for legacy endpoints.
- Icon delivered under branding/ (verified: 1024 master, full .appiconset 1x/2x, menubar idle/play template glyphs, 32px reads as clock). Accent = Lineup blue #2F6BFF.

## Session 2 — 2026-06-16 — Gear model + UI/UX design
- Henrique: app must work with ANY gear + per-device settings (which gear syncs, sync delay, etc.) → make it fully production-ready. Domain = caiano.com, never gam3s.gg (saved to memory). Bundle id → com.caiano.synclock.
- Pulled per-device **sync delay** from v2 into v1; gear management is now a core surface (Phase 3 + Devices prefs tab). Added new-device-defaults-OFF safety, per-device transport-vs-clock-only, live status, nicknames.
- Ran impeccable (product register): wrote PRODUCT.md + DESIGN.md; built design/synclock-mockup.html, screenshot verified (design/synclock-mockup.png), passed design hook.
- Updated task_plan.md (Phases 3/6/7 + production-readiness section + deferred list), GOAL_PROMPT.md, findings.md.

### Next (implementation, on Henrique's go)
- Henrique pastes GOAL_PROMPT.md to both agents → start Phase 0 (Link bridge build-proof spike).

### Open
- Henrique's specific test hardware list (he has a lot of gear). Codex accent proposal (default Lineup blue). Impeccable v3.7.0 update available (offered, non-blocking).

## Session 3 — 2026-06-16 — Marketing scope + finalization pair (sid 1781617867-af36)
- Added marketing/brand scope: site at synclock.caiano.com (register=brand) reusing real widgets for "How it works"; Phase 10 added; brand-asset licensing clarified (reserved, non-GPL).
- Upgraded impeccable 3.6.0 → 3.7.0 (global install).
- Reopened Codex pair to finalize. Codex returned 5 surgical plan edits (offset stacking rule for Free/Follow/Lead, 4-state gear model, hotplug confident-ID-only, Panic safety scope, brand-asset licensing) — ALL applied to GOAL_PROMPT.md + DESIGN.md. Plan locked.
- Codex generated 5 divergent icon/logo directions (branding/explorations/A–E + contact sheet). Cofounders converged: **B "Pulse Path" PRIMARY, C "Phase Grid" ALTERNATE** with locked refinements. Both accepted; pair closed.

### Awaiting Henrique
- Founder sign-off on icon B (or pick C). Real test-gear list. Then GOAL_PROMPT.md is final to paste to both agents → Phase 0.

## Session 4 — 2026-06-16 — Build start (goal set to @GOAL_PROMPT.md)
- Icon B signed off. Began implementation. Swift 6.3 toolchain (CLT, no full Xcode → swift build only; .app bundle is Phase 9).
- **Phase 1 COMPLETE**: git init (main), SPM package (AbletonLinkBridge C++ / SynclockCore / SynclockApp / SynclockTests), GPLv2 LICENSE + README + ThirdParty note, .gitignore. App launches as LSUIElement accessory with NSStatusItem (metronome SF Symbol placeholder), quits clean. `swift run SynclockTests` green.
- **Phase 0 (Codex lane)**: AbletonLinkBridge C ABI header (MCLink* contract) + self-contained STUB cpp (local beat grid, peerCount 0, MCLinkIsRealImplementation()==false). Compiles + links into Swift. Codex still to vendor Ableton/link submodule + swap stub for real Link.
- **Phase 2 COMPLETE (core)**: SynclockCore = Tempo (clamped 30–300), MIDIClock (bytes + PPQN + ClockMath), LinkMode, OutputDevice (4-state + per-device settings, new=OFF), HostTime, ClockScheduler (pure window math), ClockEngine (high-QoS timer + deterministic pump + phase-continuous tempo). 41 checks pass.
- NOT committed (awaiting Henrique's go to commit/push). Fresh repo on `main`, no remote yet.

### Build progress (this session, continued)
- **Phase 3 (Claude)**: SynclockMIDI built — MIDIDiscovery + CoreMIDIOutput (virtual source, timestamped MIDIPacketList, per-route delay + global offset, underrun tracking). LIVE end-to-end clock check (SynclockClockCheck target): real engine→output→virtual source = ~49-50 pulses/s @120 BPM (expected 48). Remaining: OutputSettings→routes reconciliation, hotplug, Panic, virtual-source-failure.
- **Phase 4 (Claude, core)**: TransportLogic (Start/Stop + clock-while-stopped gating) + TapTempo, unit-tested. 55 checks total.
- **Phase 0 (Codex) — REAL bridge landed**: Codex reopened-pair-accepted the work split (after mistakenly thinking goal done), vendored Ableton Link 4.0 submodule, wired cxxSettings, replaced stub with real `ableton::Link`, MCLinkIsRealImplementation()==true. Integrates green on Claude side. Codex still owes real-peer verification.
- Coordination: fresh herdr-pair (sid 1781620955-15d2). Lanes — Claude: SynclockCore/MIDI/App (gear/transport/UI/prefs/harness). Codex: AbletonLinkBridge + ThirdParty + branding (B icon) + Phase 5 Link + timing review. Meet at SynclockApp controller for Phase 5 (flag before editing).

### Continued build (Claude)
- Phase 3 gear model COMPLETE (core): GearModel reconcile/status/routes/panic + SyncEngine wiring. Phase 4 COMPLETE (core): transport+tap wired through SyncEngine + functional menu. Phase 7 persistence COMPLETE: SynclockSettings + SettingsStore. 73 unit checks.
- `SyncEngine` (SynclockMIDI) composes settings+gear+clock+output+Link bridge; play/stop/toggle/tempo/mode/panic/per-device edits; snapshot for UI.
- AppDelegate now drives SyncEngine via a functional dynamic menu (transport, nudge, mode submenu, panic, refresh).
- **LIVE: app launched, auto-discovered Henrique's real gear "AF16Rig" (DIN 1/2 Out, USB Host Out, Clock Out, Mixer Control), all new-default-OFF, persisted ~/.config/synclock/settings.json.** ← partial answer to the test-gear question: AF16Rig is on his system.

### Remaining
- Claude: Phase 6 designed popover + Devices table UI (currently a menu); Phase 8 jitter harness; hotplug MIDI-notify; help Phase 9/10.
- Codex: Phase 5 Follow/Lead tick-derivation (meet at SyncEngine); B-icon production assets; adversarial timing review.

### Continued build (Codex)
- **Phase 0 COMPLETE**: vendored `Ableton/link` as a pinned `Link-4.0` submodule with `asio-standalone`; wired `Package.swift` C++17 header paths + `LINK_PLATFORM_MACOSX=1`; replaced the local-clock stub with real `std::unique_ptr<ableton::Link>` behind the unchanged C ABI; `MCLinkIsRealImplementation()` returns true.
- Added `SynclockLinkCheck` CLI proof target. Verified `swift build`, `swift run SynclockTests`, `swift run SynclockLinkCheck --self-peer` (two real Link instances discover each other; peer-count/tempo/start-stop callbacks fire), and external-process proof with Ableton `LinkHutSilent` + `swift run SynclockLinkCheck --require-peer`.
- **B Pulse Path production identity generated**: replaced the previous direction-A production assets with B-derived `branding/app-icon/synclock-icon-1024.png`, full `branding/Synclock.appiconset`, `branding/menubar/` idle/playing template glyphs, `branding/wordmark/synclock-wordmark-lockup.png`, and updated verification sheets. `branding/generate_synclock_icons.py` now regenerates production assets from `branding/explorations/b-pulse-path/`.

## Session 5 — UI, harness, Phase 5 seam, marketing, first push (Claude)
- Phase 6 COMPLETE (core): NSPopover (Theme/PopoverViewController/PulseView) per mockup, offscreen-rendered + verified (design/synclock-popover-render.png). Status item left-click=popover/right-click=menu.
- Phase 7 UI COMPLETE (core): PreferencesWindowController (General · Devices · Link · About); Devices = NSTableView gear table + Panic/Refresh.
- Phase 8 COMPLETE (harness): SynclockJitter. Measured idle/release 120 BPM p95=0.045/p99=0.062ms; 300 BPM p95=0.028/p99=0.054ms (~5-6x better than target).
- Phase 5 SEAM: TickGrid protocol + FreeRunningGrid; ClockEngine refactored to drive ticks via `grid`+`setGrid()`; anchorIndex fix (no beat-0 replay on grid swap) per Codex review. 76 checks. Handed to Codex for LinkFollowGrid + setMode.
- Phase 10 COMPLETE (core): site/index.html landing page reusing real popover + B icon; passed impeccable hook.
- **FIRST COMMIT + PUSH**: github.com/hcaiano/synclock (main). 29 Swift files, 96 branding assets, docs, site, Link submodule gitlink; tool/agent dirs gitignored.
- Discovered Henrique's real gear on launch: AF16Rig (DIN1/2, USB Host, Clock Out, Mixer Control).

### Blocked / open
- Phase 9 packaging (notarized DMG + Sparkle) BLOCKED on Henrique's Apple Developer ID.
- Deploy site to synclock.caiano.com (Henrique DNS/hosting). Full test-gear list.
- Codex: Phase 5 Follow/Lead in progress.
