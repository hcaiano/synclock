# Synclock — Shared Goal Prompt

> Paste this to **both Claude and Codex** at the start of an implementation session. It is the single source of truth. Claude and Codex are cofounders building this with Henrique; collaborate as peers via herdr-pair, review each other's work, and converge.

---

## Mission
Build **Synclock**: a native macOS menubar app that is the **master MIDI clock + Ableton Link** hub for a music setup — sync hardware and software to a tight clock without opening a DAW. Free, native, findable. It replaces Henrique's old Electron `midiclock` and is a sibling to his window manager **Lineup** ("feels like Apple shipped it").

**Why it's better than the old one:** the old app fired clock pulses from JS `setInterval` in Electron's GC'd main process → audible jitter. Synclock uses a hand-owned high-priority scheduler emitting **timestamped CoreMIDI** packets, so the clock actually feels tight. Tightness is the product.

## Non-negotiable quality bar
Measurable **inter-tick jitter** (timestamped CoreMIDI). Target **p95 ≤ ~0.3 ms, p99 ≤ ~1 ms at 120 & 300 BPM under CPU/UI load**, validated by a hand-owned test harness against real rigs. Do NOT claim "sample accurate" (no audio engine). Report honest measured numbers.

## Stack & constraints
- **Swift 5.9+ / Swift Package Manager**, **AppKit (NOT SwiftUI)**, **LSUIElement** menubar agent via `NSStatusItem`. Target **macOS 13+**.
- **License: GPLv2-or-later** (forced by the Ableton Link C++ source). Include GPL text + Ableton notices; publish corresponding source.
- **Dependencies are allowed**, chosen per subsystem by quality (this is an explicit founder decision — do NOT pursue zero-dep purity):
  - **Hand-owned** (define the feel, must be inspectable/testable): clock tick scheduler, transport state machine, persistence/migration, timing test harness.
  - **Use deps:** Ableton **Link** (C++ source, core), **Sparkle** (updater, MIT), **SwiftMIDI** (orchetect/swift-midi, ex-MIDIKit, MIT) — only at the discovery/routing edge, behind a swappable protocol, and only if it never hides send timestamps.
  - **Output send path = direct CoreMIDI**, never a library, so timestamps stay inspectable. Use `MIDIEventList` as the modern timestamped path; fall back to `MIDIPacketList` where legacy MIDI 1.0 endpoints require it. The invariant is *direct, timestamped, inspectable host-time sends* — not a specific API.

## Locked v1 feature spec
- **Sync authority — Master + Link-follow**, 3-mode toggle the UI always displays:
  - **Free** — ignore Link (don't join the network).
  - **Follow Link** — read Link tempo+phase, derive the MIDI tick grid from it; don't push tempo.
  - **Lead Link** — commit local tempo + start/stop into the Link session (`setTempo`, `setIsPlayingAndRequestBeatAtTime`; avoid `forceBeatAtTime`).
- **MIDI out:** Timing Clock `0xF8` @ 24 PPQN + Start `0xFA` / Stop `0xFC` / Continue `0xFB`. (SPP, MTC, external-clock-in = v2.)
- **Tempo:** decimal BPM 30–300 + fine ± nudge + tap tempo.
- **Gear management (works with ANY gear):** auto-discover every CoreMIDI output live (no hardcoding) + one named **virtual source**. Each output has per-device settings: **enabled-for-sync**, **nickname** (speak the user's language, not raw endpoint UIDs), **sync delay (ms, per-device)**, **send-transport vs clock-only**, and **live status** (see state model). Persist by stable unique ID; on hotplug keep valid outputs running, mark missing, auto-reconnect. **New devices default to OFF** so plugging in gear never blasts clock into a live set.
  - **Status state model:** `active` (present, enabled, currently emitting clock/transport — incl. continuous F8 while stopped if clock-while-stopped is ON) · `ready` (present, enabled, but not emitting right now per transport/clock-while-stopped state) · `off`/`available` (present but disabled-for-sync, incl. new-default-OFF devices) · `remembered-missing` (persisted but absent; settings preserved).
  - **Hotplug identity safety:** reconnect only restores settings when identity is confident (stable unique ID). If only an ambiguous name-fallback match exists, do NOT auto-enable — surface as available/new and require user confirmation. Preserves the live-safety promise.
  - **Panic scope:** sends Stop to currently active/enabled outputs and All-Notes-Off to all present devices that are enabled-for-sync (or remembered as previously enabled); the virtual source always receives Panic. It does NOT send to brand-new/default-off outputs. A "panic everything present" variant, if wanted, is an explicit hold-to-confirm action, never the default.
- **Clock-while-stopped:** setting, default **ON** (continuous `F8`, transport via Start/Stop) for device compatibility.
- **Offsets (canonical rule):** the scheduler first computes a canonical tick grid in the active time domain — Free/Lead from the local mach-host timeline, **Follow** from Link `clock().micros()` tempo/phase mapped into host-time send timestamps. Then **per-output send timestamp = canonical tick timestamp + global offset + that device's sync delay**. Offsets affect ONLY outbound MIDI scheduling — never Link session tempo/phase/transport. Negative offsets are honored only within the scheduler lookahead window; a would-be-past timestamp sends on the next safe tick and records an underrun in diagnostics. Invariant: Link gives the beat grid; delays are per-output delivery compensation layered after the grid is known.
- **Menubar surface:** `NSStatusItem` + popover — BPM (tabular numerals), nudge, tap, transport, Link segmented mode + peer count, output-health chip, live pulse. Separate **Preferences** window with tabs **General · Devices · Link · About** (Devices = the per-device gear table; virtual port pinned at top; NEW badges; Panic). Build to match `design/synclock-mockup.html`, `DESIGN.md`, and `PRODUCT.md`.
- **Persistence:** schema-versioned JSON in `~/.config/synclock/` with migration (Lineup pattern). Single global profile v1; schema designed to add profiles later.
- **Production-ready states & a11y:** empty state (no gear → teach the virtual port), missing/reconnecting devices, virtual-port-creation failure, Link unavailable; full keyboard nav + VoiceOver (announce transport+mode+BPM); status never color-only; Reduce Motion fallback for the pulse.
- **Distribution:** notarized DMG, hardened runtime, Developer ID signing, **Sparkle** appcast, GitHub Releases. App icon/menubar glyph/wordmark use the locked B "Pulse Path" identity from Codex.

## Marketing site & brand assets (`synclock.caiano.com`)
A separate static marketing site (NOT GPL-bound; the app is GPLv2, the site is just a landing page) hosted at **synclock.caiano.com** (personal domain caiano.com — never gam3s.gg). It must **reuse the real app UI** we designed (the popover + Devices mockups in `design/`) as the product visuals, so the site shows the actual thing, not faux screenshots.
- **Register = brand** (design IS the product here) — distinct from the app's product register; sibling-consistent with Lineup's site.
- **Sections:** hero (one-line pitch + the live menubar widget), the problem (sync your gear without a heavy DAW; the old jitter story), **"How it works"** (3 steps using the actual widgets: set tempo → choose which gear syncs → hit play / join Link), feature highlights (tight measurable clock, works with any gear + per-device control, Ableton Link Free/Follow/Lead, free & open-source), a quiet timing-quality proof (the jitter numbers), download (notarized DMG + GitHub Releases), free + Buy-Me-a-Coffee, GPLv2/source link.
- **Assets to produce:** final app icon + logo/wordmark, favicon, OG/social share images, App-Store-style screenshots of both surfaces, and an optional short looping demo of the pulse + transport.
- **Asset licensing (explicit):** marketing site source/assets may live separately from the GPL app source. App code is GPLv2-or-later; the **Synclock name/logo/brand assets are Henrique/Caiano brand assets** (reserved, not GPL) unless explicitly dual-licensed. Screenshots of the GPL app do not impose GPL on the static site. If brand assets also ship inside the app repo, license/reserve them separately in that repo so GPL doesn't sweep them in.
- **Brand/logo direction (LOCKED — founder signed off):** explored 5 directions under `branding/explorations/`. **PRIMARY = B "Pulse Path"** — a clock/phase ring with a rhythmic pulse spike and centered downbeat dot, making the app's signature pulse the brand mark (one coherent system across icon → menubar glyph → in-app pulse → marketing hero). **ALTERNATE = C "Phase Grid"** (more technical/Link-forward). Locked refinements for B: centered blue dot = the downbeat (meaningful, not decoration); pulse spike = the beat event (not a generic waveform); ring stays quiet so the pulse owns the mark; reserve C's blue phase-arc for MOTION (in-app Link-phase sweep/fill, hover/active, marketing demo); keep graphite + off-white + `#2F6BFF` for Lineup-family consistency. Production `.appiconset`, menubar template glyph, favicon, wordmark, and site assets derive from B.

## Architecture (Ableton Link bridge — already spiked, verified current)
- Vendor **`github.com/Ableton/link`** C++ source as a pinned git submodule under `ThirdParty/ableton-link/` (NOT LinkKit — LinkKit's license covers iOS apps only). Header-only; add `include` + `modules/asio-standalone/asio/include`, define `LINK_PLATFORM_MACOSX=1`, C++17, Xcode 16.2+.
- Expose it through a thin **C-ABI bridge** (`extern "C"`, opaque `MCLinkRef` owning `std::unique_ptr<ableton::Link>`), Swift-imported — NOT Swift/C++ interop for v1. API surface: create/destroy, setEnabled, setStartStopSyncEnabled, peerCount, tempo get/set(bpm, hostMicros), beat/phase/timeAtBeat, requestBeatAtTime, isPlaying/setIsPlaying(+AndRequestBeat), clockMicros, and peerCount/tempo/startStop callbacks.
- Canonical time domain = Link `clock().micros()`. **Never** let `Date`/`DispatchTime` into timing code. Link callbacks → core state queue → main-thread snapshot to AppKit.

### Repo layout
```
Package.swift                  # platforms macOS .v13, cxxLanguageStandard .cxx17
ThirdParty/ableton-link/       # submodule (Link.hpp + asio-standalone)
Sources/AbletonLinkBridge/     # include/AbletonLinkBridge.h (C ABI) + AbletonLinkBridge.cpp
Sources/SynclockCore/          # transport, scheduler, modes, settings, persistence (pure, tested)
Sources/SynclockApp/           # AppKit LSUIElement: status item, popover, prefs, about
branding/                      # icon assets (.appiconset, menubar template glyph)
```
SPM + a C++17 target is the real build risk → **Phase 0 proves the build before anything else**; fallback is a generated `.xcodeproj` with a static `AbletonLinkBridge` target.

## Build phases (gate-driven — see task_plan.md for full table)
0. **Link bridge build-proof spike** (the gate): SPM C++17 bridge compiles; Swift CLI calls create/enable/peerCount/tempo; verified against a real Link peer.
1. Repo + GPLv2 + SPM skeleton + LSUIElement launch + dependency-free test runner.
2. Core timing scheduler (hand-owned, mach host-time, timestamped `MIDIEventList`, unit-tested).
3. MIDI output + gear management (virtual source + destinations, per-device enable/nickname/delay/transport/status, hotplug, Panic).
4. Transport + tempo + modes (F8 + Start/Stop/Continue, decimal BPM + nudge + tap, clock-while-stopped).
5. Ableton Link integration (Free/Follow/Lead, conflict rules, Start/Stop sync).
6. Menubar UI (popover, template glyph idle/playing).
7. Preferences + persistence (JSON + migration, Devices gear table, global offset, per-device settings, launch-at-login).
8. Timing test harness (p50/p95/p99 vs real rigs; acceptance checklist).
9. Packaging (notarized DMG + Sparkle + GitHub Releases + locked B identity integration).
10. **Brand + marketing site** (`synclock.caiano.com`): build the static landing page reusing the real widget UI for "How it works," plus favicon, logo/wordmark, social/OG assets, screenshots, and optional pulse demo from the locked B identity.

## Division of labor
- **Claude:** core timing/transport/MIDI/persistence, AppKit UI, packaging, plan upkeep.
- **Codex:** Link C-ABI bridge implementation, icon/branding, adversarial review of timing/concurrency code, build-system wrangling (SPM↔C++).
- **Henrique:** decisions, test hardware, release. Founder word overrides both agents.

## Working agreement (cofounders)
- Collaborate via **herdr-pair** (message header protocol). Review each other's diffs before merge; verify with measurements, not vibes.
- Re-read `task_plan.md` before phase decisions; log discoveries to `findings.md`, session notes to `progress.md`. Update phase status as you go.
- Smallest change that solves the task; match Lineup's style; no speculative abstractions.
- Each phase is **done** when its gate passes AND there's a test or a measured number proving it. Don't mark a phase complete on hope.

## Definition of done (v1)
A notarized, signed, GPLv2 DMG of Synclock that: lives in the menubar, sends a measurably tight MIDI clock + transport to a virtual port and selected hardware, supports per-device gear control (enable, nickname, sync delay, transport, status), joins an Ableton Link session in Free/Follow/Lead with the mode always visible, survives device hotplug safely, persists setup across launches, auto-updates via Sparkle, and ships the locked B "Pulse Path" Synclock identity — with a timing harness report showing p95/p99 jitter meeting (or honestly reporting against) the target.

## Open items to confirm at kickoff
- Henrique's exact test hardware (he has a lot of gear — get the specific list to define the Phase 8 acceptance rig).
