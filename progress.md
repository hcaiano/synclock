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

## Session 10 — Release hardening cleanup after rebrand (Codex)
- Updated current source-of-truth docs/comments so they point at Tempo Dot + Pulse Coral instead of the retired B Pulse Path / Lineup-blue identity.
- Tightened `RELEASING.md` around the real Sparkle tools fetched by SwiftPM: `.build/artifacts/sparkle/Sparkle/bin/generate_keys` and `generate_appcast --download-url-prefix ... --link ...`.
- Proved the local, non-credentialed packaging path still works after the cleanup: `Scripts/build-app.sh` built an ad-hoc `Synclock.app`, `Scripts/make-dmg.sh` created a valid DMG, `codesign --verify --deep --strict` passed, `hdiutil verify` passed, and `Scripts/notarize.sh` correctly failed fast because the proof app was not Developer-ID signed.
- Verified the live placeholder appcast at `https://synclock.caiano.com/appcast.xml` returns HTTP 200 and valid XML; first signed item still waits for Developer ID + Sparkle EdDSA key.
- Closed the remaining Phase 3 hotplug gap: added `MIDIHotplugMonitor`, a CoreMIDI setup-change watcher that debounces notifications onto the main thread and calls `SyncEngine.refreshDevices()`. Manual Refresh remains as a fallback.
- Ran `swift run -c release SynclockJitter --load`: 120 BPM p95=0.019ms/p99=0.028ms; 300 BPM p95=0.017ms/p99=0.024ms, with one 16.633ms max outlier at 300 BPM. p95/p99 remain far inside the target.
- Closed the remaining Phase 7 nickname UI gap: the Devices table's device column is now editable and persists a nickname via `SyncEngine.setDeviceNickname`, falling back to the system name when cleared.
- Added a Devices-pane empty state for systems with no CoreMIDI outputs; the virtual source remains available.

## Session — coral→mint rebrand (#16C79A)
- Theme.swift: accent → Fresh Mint #16C79A; added `inkOnAccent` (#0E1411) for dark labels on bright mint fills.
- PopoverViewController.swift: Play button + selected Link segment now use dark ink on mint (contrast). Build green.
- Site recolored to mint: index.html, hero-popover.html, og.html, DESIGN.md, PRODUCT.md.
- Re-rendered crisp 2x mint product shot (headless Chrome) → site/assets/popover.png (1000x860); regenerated og.png with mint text.
- Deployed: wrangler → synclock Worker (Caiano acct). Live synclock.caiano.com HTTP 200, serving #16C79A + new mint popover.png. Verified in browser.
- Remaining coral: app icon (favicon/OG/wordmark) — pending Codex's AI-image-gen mint icons in branding/explorations-v3 (dir still empty). Will swap + redeploy when ready.

## Session — landing page full rework (impeccable critique)
- Ran /impeccable critique on site/index.html. Detector clean of mechanical tells; issues were editorial (jargon, small hero, decorative glow/motion, card reflex). Snapshot in .impeccable/critique/.
- Refero refs (Mobbin not connected this session): Cron, Superwhisper, Metaview — native-app pages that lead with a big product visual + one accent + minimal copy.
- Rewrote index.html (full rework):
  - Hero now product-led: benefit headline "Lock your whole rig to one beat.", plain-language subcopy, NO code snippet.
  - Hero visual = live CSS macOS menu bar with the Synclock tray icon highlighted (mint pulse) and the popover dropping from it (notch). Crisp/scalable, replaces the small floating popover.png.
  - Killed AI-slop: hero radial glow, button glow-shadows + translateY hover lift, the 0.05ms hero-metric tile, the "Set/Choose/Play" mono kickers.
  - "How it works" = plain numbered steps (hairline rows, no cards). Features = 2-col benefit list with mint-dot bullets, jargon removed (CoreMIDI/jitter demoted to "rock-solid timing, holds tight under load"). Download = final shipped-state language (Dev ID approval imminent).
  - Reduced em-dashes in body copy to clear the detector's em-dash-overuse flag.
  - single-font finding = intentional (system font is the Mac-native identity); not changed, no ignore persisted.
- Fixed popover clipping (desktop min-height 486px). Verified desktop + mobile (390px) in browser.
- Added .impeccable/ + hero-popover.html to site/.assetsignore; trashed stray site/.impeccable; redeployed. Stray internal file now 404. Live at synclock.caiano.com (200, new headline, old snippet gone).

## Session — hero visual quality fix + icon finalists
- User: landing hero widget still looks low quality. Diagnosed: the "desktop" was a flat black VOID with the popover floating in empty space + flat fake menubar = cheap/low-fidelity.
- Refero grounding (Mobbin still not connected): premium pattern = app UI floating on a lush BLURRED MULTICOLOR GRADIENT wallpaper (Raster sign-in). Black void is the anti-pattern.
- Fix: rebuilt hero visual — added a lush macOS-style wallpaper (.desktop::before: mint near the menubar icon + indigo/blue/teal/violet mesh, blur 34px) so the popover floats on color; popover backdrop-filter now picks up real frosted vibrancy (true macOS look). Bumped popover size/shadow, z-index layering. Deployed live.
- Codex delivered v3 image-gen mint icons (kind=ready, sid 1781627969-d64a). 5 directions A-E. Reviewed full-res: A Mint Pulse Tile (white pulse waveform on mint) = strongest/friendliest/Dock-readable = my pick; D Sync Capsule (reads as toggle); B Phase Dots (pale, reads as refresh). Sent contact sheet + A/D/B to user. Awaiting pick, then productionize (icns/favicon/OG/wordmark/menubar glyph) + send Codex accepted.

## Session — simplify hero to widget-only + ship icon A
- User: "make it as simple as possible — show the widget only like the initial mockups. No top bar." Removed the fake menubar + desktop wallpaper entirely.
- Hero visual now = the popover ONLY, centered, with a soft mint radial glow behind it + strong shadow (matches the mockup the user liked). Removed .desktop/.menubar/.tray/.notch CSS+markup; fixed mobile + reduced-motion rules.
- Icon decision: user picked A (Mint Pulse Tile). Shipped to live site: site/assets/icon-256, icon-512, wordmark ← A; regenerated og.png (now shows A). Deployed. synclock.caiano.com live: 200, menubar markup gone, new headline, icon A in nav/OG.
- Sent Codex (herdr kind=task, sid 1781627969-d64a) the decision + finalization task: promote A into app bundle (branding/app-icon, Synclock.appiconset/.icns, bundled menubar glyphs, wordmark). Site is mine; app bundle is his. Queued for his next turn. Notarized release still blocked on Apple Dev ID.

## Session — release prep (Apple Dev account active)
- Apple Developer account now active → Phase 9 unblocked. App-specific pw: reuse existing (it's per-Apple-ID, not per-app); store under its own notarytool profile `synclock-notary`.
- Codex finished promoting icon A into app bundle/canonical branding (hash-verified, swift build green). Sent accepted → icon thread DONE across site + app.
- Validated full build pipeline: `Scripts/build-app.sh dist-validate` green (ad-hoc) — app assembles with icon A, Sparkle.framework bundled, launchable. Only release delta = real Developer ID identity + Sparkle key.
- Generated Sparkle EdDSA key (none existed in keychain). PUBLIC KEY = nRxOca8UMvC83e7/DELKYh0h6VHBPRqMkZfIDLDIgpw= (public, safe). Private key in login keychain — user must back it up.
- NOTE/decision: validation build is arm64 THIN; marketing claims "Apple Silicon & Intel". Need universal build OR adjust copy.
- BLOCKERS (user): Developer ID Application cert in keychain; `notarytool store-credentials synclock-notary`; provide Team ID + paste `security find-identity -p codesigning -v`.

## Session — v0.1.0 RELEASE SHIPPED 🎉
- Apple Dev account active. Reused Lineup's Developer ID cert (Team HJ9R8572WN). User created synclock-notary profile (existing app-specific pw).
- App: built arm64 (Apple Silicon only, per user decision), Developer ID signed. FIRST notarization REJECTED — Sparkle nested helpers (Updater.app/Autoupdate/Downloader.xpc/Installer.xpc) unsigned + no timestamp. Fixed build-app.sh to deep-sign inside-out with --timestamp (Codex landed same as sign_code helper). Rebuilt, re-notarized → Accepted, stapled, Gatekeeper "Notarized Developer ID".
- DMG: built (4.7M, signed), notarized → Accepted, stapled, Gatekeeper-accepted.
- Appcast: generate_appcast kept hanging on keychain GUI prompt in background (exit 144). Solved by exporting key via generate_keys -x (same tool, no prompt) → generate_appcast --ed-key-file → trashed key file. Signed appcast.xml written (0.1.0, arm64, EdDSA sig). Verified DMG sha matches enclosure.
- Committed+pushed: 3b5adfc (release prep) + e9bff96 (appcast + preflight). Deployed site (appcast.xml live, 200).
- GitHub Release v0.1.0 created with notarized DMG. Verified: DMG downloadable at appcast URL (200, 3884541 bytes = signed enclosure). https://github.com/hcaiano/synclock/releases/tag/v0.1.0
- Herdr collaboration with Codex closed (both accepted). Icon A + build pipeline complete.
- REMINDER: user must back up Sparkle EdDSA PRIVATE key from login keychain (generate_keys -x → password manager). Public: nRxOca8UMvC83e7/DELKYh0h6VHBPRqMkZfIDLDIgpw=

## Session — Phase 11 v0.1.1 UX rework kickoff (work-with-codex + planning-with-files)
- Henrique installed v0.1.0, gave live feedback. Wrote Phase 11 plan in task_plan.md (5 items, Claude=UI / Codex=engine).
- Re-bootstrapped herdr pair (new sid). Assigned Codex: 11.3 Link on/off (collapse LinkMode→linkEnabled, bidirectional when on) + 11.4 expose currentBarPhase()/currentBeatInBar(). API contract sent.
- Henrique confirmed beat indicator = SEGMENTED BAR (4 cells, downbeat emphasized, sweeps L→R, resets on 1). Link = NSSwitch toggle.
- Built Sources/SynclockApp/BeatPhaseView.swift — standalone segmented-bar view, phaseProvider closure (API-agnostic), Reduce-Motion = discrete beats, self-animates ~60fps while active.
- swift build currently RED at SyncEngine.swift:277 (.followLink) — Codex mid-refactor. Holding my popover/BPM/Prefs edits until Codex signals SynclockMIDI green + final API, to keep the first integration build clean.

## Session — Phase 11 engine API landed (Codex)
- Removed `LinkMode` from public API. `SynclockSettings` now stores `linkEnabled: Bool`; decoder migrates legacy `"linkMode": "followLink"` / `"leadLink"` to true and `"free"` to false.
- `SyncEngine` API for UI: `setLinkEnabled(_ on: Bool)`, `Snapshot.linkEnabled`, `currentBarPhase() -> Double`, `currentBeatInBar() -> Int`.
- Link ON is bidirectional: joins Link, derives the tick grid from Link, adopts peer tempo/start-stop, and publishes local tempo/start-stop changes. Link OFF disables Link and runs the local free grid.
- Bar phase semantics: quantum=4; Link ON samples Link's beat phase; Link OFF samples the local free-running clock. If Link is OFF and the local clock is stopped with clock-while-stopped OFF, phase/beat return downbeat `0`.
- Added tests for legacy settings migration and local phase continuity; updated SynclockFollowCheck for bidirectional Link ON + phase sampler range.
- Verified: `swift build`; `swift run SynclockTests` → 85/85; `swift run SynclockFollowCheck` → peerCount=1, adoptedTempo=137, publishedTempo=111, barPhase in range.

## Session — Phase 11 UI pass (popover) built against Codex's engine API
- Codex landed engine API green (85/85): setLinkEnabled, Snapshot.linkEnabled, currentBarPhase(), currentBeatInBar(); LinkMode removed; bidirectional when on; phase semantics defined.
- Built UI (SynclockApp): FlatButton.swift (flat layer-backed button w/ press feedback — kills the system green pill), TempoField.swift (editable BPM + scroll-to-nudge), BeatPhaseView.swift (segmented bar, downbeat-emphasized, Reduce-Motion = discrete, ~60fps).
- Rewrote PopoverViewController: editable BPM (click/type/scroll/▲▼, clamp via Tempo 30–300), flat mint Play button, beat bar wired to engine.currentBarPhase()/currentBeatInBar() (animates while playing or Link-on-with-peers), Ableton Link NSSwitch toggle + peer count, tighter mockup-spec spacing.
- swift build green. Built dist-dev/Synclock.app (ad-hoc), launched — no crash. Awaiting Henrique's visual check on the real app (vibrancy).
- OPEN: NSSwitch shows SYSTEM accent when on (not mint) — decide native switch vs custom mint toggle. Preferences redesign (11.5) still TODO.

## Session — popover bugs fixed + objectively verified (work-with-codex)
- Henrique reported Tap + ▲▼ dead on v0.1.1 popover. Root cause: my FlatButton overrode mouseDown for press feedback, swallowing the click action. Fixed: standard NSButton momentary-push action path + isHighlighted press feedback (no mouseDown override).
- Codex (computer-use directive): external AX can open NSStatusItem but popover enumeration hangs → built in-app harness SYNCLOCK_POPOVER_SELF_TEST=1 exercising real control paths (FlatButton.performClick, TempoField.sendAction/scrollWheel, MintToggle.mouseDown) + SYNCLOCK_UISHOT render. Stored button refs in PopoverViewController.
- Verified merged: swift build green; popover self-test 13/13 PASS; SynclockTests 85/85; FollowCheck OK in isolation (the nonzero was the running dev app holding the Link session — not a regression). Accepted Codex.
- TODO wire SYNCLOCK_POPOVER_SELF_TEST into CI as regression guard.
- NEXT: Preferences redesign (11.5) → update marketing site to new design (toggle/beat) → cut v0.1.1 (notarized + appcast auto-update). Then commit the whole v0.1.1.

## Session — REBRAND to navy + cyan (new icon)
- Henrique approved Codex's new icon: deep navy tile + glowing cyan slider mark (3 bars + knob). Moving whole brand off Fresh Mint green.
- Sampled icon: bg navy #063369→#00132B, accent cyan ~#5BEFF5. New palette: accent #4FE3EC (Slider Cyan), inkOnAccent navy #04223E, site navy surfaces (#0A1422/#0E1A2D/#15223A), cool-tinted hairlines.
- App: Theme.swift accent→cyan, inkOnAccent→navy. Build green; all components propagate (Play/toggle/beat bar/dots/pulse). No hardcoded mint left in app.
- Site: index.html :root → navy+cyan; swapped rgba(22,199,154)→rgba(79,227,236) glows, #16C79A→#4FE3EC, #0E1411→#04223E across index/hero-popover/og/DESIGN; fixed nav bg + btn hover. DESIGN.md Mint→Slider Cyan + oklch.
- Codex briefed (herdr): productionize new icon master into app-icon set + appiconset + MONOCHROME menubar template glyph (slider mark) + wordmark + site icon-256/512. Awaiting ready.
- TODO: re-render popover.png + og.png in new palette, swap icon assets when Codex delivers, redeploy site, bump v0.1.1, notarized release + appcast. Then ship.
