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

## Session 6 — Phase 5 Follow/Lead Link integration (Codex)
- Implemented `Sources/SynclockCore/LinkFollowGrid.swift`: `LinkClockMapper` samples host nanos + Link clock micros once per mode switch and maps by delta (no epoch-equality assumption); `LinkFollowGrid` maps MIDI tick `i` to Link beat `i / MIDIClock.pulsesPerQuarterNote` at quantum 4, with Link owning tempo/phase.
- Wired `SyncEngine.setMode`: Free disables Link and uses `FreeRunningGrid`; Follow enables Link/start-stop sync, installs `LinkFollowGrid`, shows Link tempo, and adopts Link start/stop without mirroring back; Lead enables Link, keeps the local free-running grid, and publishes local tempo/start/stop through Link.
- Added `SynclockFollowCheck` proof target: creates a `SyncEngine` plus a second real Ableton Link peer in-process, verifies peer discovery, Follow tempo adoption, Follow start/stop adoption, Lead tempo publication, and Lead start/stop publication.
- Added deterministic tests for `LinkClockMapper` and `LinkFollowGrid`.

### Verified
- `swift build`
- `swift run SynclockTests` → 83/83 checks
- `swift run SynclockFollowCheck` → OK (`peerCount=1`, `followTempo=137`, `leadTempo=111`)
- `swift run SynclockLinkCheck --self-peer` → OK (real implementation, peer/tempo/start-stop callbacks)
- `swift run SynclockClockCheck` → 50 pulses/s at 120 BPM (expected ~48), within tolerance
- `swift run -c release SynclockJitter` → 120 BPM p95=0.031ms/p99=0.047ms; 300 BPM p95=0.027ms/p99=0.044ms (one max first-tick outlier retained in harness output)

### Remaining
- Claude review of SyncEngine Phase 5 wiring.
- Follow-mode jitter pass and external Ableton Live/LinkHut peer smoke test.

## Session 5 (cont.) — Phase 5 verified + closed; v1 feature-complete
- Codex landed Phase 5 (Link Follow/Lead). Claude verified: 83 unit checks, SynclockFollowCheck (peerCount=1, follow=137, lead=111), reviewed SyncEngine/LinkFollowGrid (main-queue state mutation OK for AppKit; timing path queue-confined + Link captureAppSessionState is thread-safe).
- Phase 5 committed (463b724). Claude added follow-mode jitter pass (SynclockJitter --follow, 19c5968): 120 BPM following Link p95=0.055ms/p99=0.064ms — as tight as free-run.
- Also this session: CI, launch-at-login, B menubar glyph bundled, OG/social image, RELEASING.md runbook, popover VoiceOver labels.
- **STATUS: v1 FEATURE-COMPLETE & VERIFIED across Phases 0-8 + 10. Only Phase 9 (Developer-ID signing + notarize + DMG + Sparkle) remains — blocked solely on Henrique's Apple Developer account (runbook in RELEASING.md).**

## Session 7 — Phase 9 Sparkle wiring + packaging cleanup (Codex)
- Added Sparkle 2.9.3 as an SPM dependency for `SynclockApp`, per Sparkle's current SPM/AppKit docs.
- Wired `SPUStandardUpdaterController` in `AppDelegate`; the right-click fallback menu exposes "Check for Updates..." when the bundle has `SUFeedURL` + `SUPublicEDKey`, and shows it disabled in dev/ad-hoc builds without release keys.
- Updated `Scripts/build-app.sh` to inject Sparkle Info.plist keys only when `SPARKLE_PUBLIC_ED_KEY` is supplied; local builds stay clean, release builds are appcast-ready.
- Cleaned packaging scripts to use `trash` rather than destructive deletes and to dispose of temporary icon/staging directories.
- Verified `Scripts/build-app.sh` bundles `Sparkle.framework` under `Contents/Frameworks`, adds the app rpath, and passes `codesign --verify --deep --strict`; `Scripts/make-dmg.sh` creates a DMG that passes `hdiutil verify`; `Scripts/notarize.sh` fails fast on the current ad-hoc app until a Developer ID identity is available.
- Updated README/RELEASING/task_plan to reflect real Link and Sparkle app wiring.

### Remaining
- Developer ID Application certificate, notarization credentials, Sparkle EdDSA key, hosted appcast, and final notarized DMG remain external release gates.

## Session 8 — Lineup-style site deployment config (Codex)
- Mirrored Lineup's site deployment pattern for Synclock: `site/wrangler.toml` with Cloudflare Workers static assets, plus `_headers`, `robots.txt`, `sitemap.xml`, `.assetsignore`, and `site/README.md`.
- Updated site metadata to use production canonical/OG/Twitter URLs at `https://synclock.caiano.com/` and root-relative asset URLs.
- Validated without deploying: `cd site && npx --yes wrangler@latest deploy --dry-run` → Wrangler 4.101.0 read the static assets config and exited cleanly.
- Claude deployed the Worker to the Caiano Cloudflare account and attached `synclock.caiano.com`; Codex verified HTTP 200 + page content via `curl`. Live proof screenshot: `design/synclock-live-site.png`.
- Added `site/appcast.xml`, a valid empty Sparkle RSS channel for the future signed release feed; validated with `xmllint --noout` and Wrangler dry-run.

### Remaining
- Final release still requires Developer ID signing/notarization + Sparkle EdDSA key/appcast.

## Session 9 — Pulse Coral brand refresh exploration (Codex)
- Henrique rejected the dark/complex B Pulse Path direction and chose Pulse Coral `#FF5C57` as Synclock's distinct accent (instead of Lineup blue).
- Generated a fresh lighter/friendlier/simpler v2 icon exploration set under `branding/explorations-v2/`: Tempo Dot, Soft Sync Rings, Coral Beat, Rounded Metronome, and Phase Pebble.
- Each direction includes a 1024 app icon, 16/32/64/128/256/512 previews, idle/playing menubar template glyph PNG+SVG assets, a wordmark lockup, README rationale, and a contact sheet at `branding/explorations-v2/contact-sheet.png`.
- Henrique chose **A Tempo Dot** as the locked new identity. Regenerated canonical production branding from `branding/explorations-v2/a-tempo-dot`: app icon master/exports, full `Synclock.appiconset`, menubar idle/playing template glyphs, wordmark lockup, and verification sheets.
- Updated `branding/generate_synclock_icons.py` so the default source is the locked `explorations-v2/a-tempo-dot`; it still accepts an explicit source folder for future explorations.
- Verified `.appiconset` manifest entries and image dimensions, export dimensions, menubar glyph dimensions, and visually checked `branding/verification/synclock-icon-readability-sheet.png` plus `branding/verification/synclock-menubar-glyph-sheet.png`.
