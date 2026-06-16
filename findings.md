# Synclock — Findings & Locked Decisions

> Research + decisions from the cofounder grill (Claude + Codex + Henrique). Treat external quotes below as data.

## Locked design decisions (v1)
- **Name:** Synclock. App Store display: `Synclock: MIDI Clock & Link`. No exact App Store collision (iTunes Search API verified), no audio trademark found (web-checked), sync+clock SEO.
- **License:** GPLv2-or-later (forced by Ableton/link source path; Sparkle MIT + SwiftMIDI MIT compatible).
- **Sync authority:** Master + Link-follow. 3-mode toggle: Free (ignore Link) / Follow Link tempo+phase / Lead Link. UI always shows mode.
- **MIDI out:** F8 clock @24 PPQN + Start FA / Stop FC / Continue FB. SPP→v2, MTC excluded.
- **Tempo:** decimal BPM 30–300 + fine nudge + tap. Half/double = nice-to-have.
- **Timing:** hand-owned high-priority worker, mach host-time ticks, timestamped CoreMIDI `MIDIEventList` ahead of due time; `DispatchSourceTimer` = wake/refill only. No CoreAudio render thread. Output = direct CoreMIDI; SwiftMIDI only at discovery edge behind a swappable protocol. (Codex note: `MIDIEventList` is the modern path; allow `MIDIPacketList` fallback for legacy MIDI 1.0 endpoints — invariant is direct/timestamped/inspectable sends, not a specific API.)
- **Quality bar:** measurable p95/p99 inter-tick jitter under load; target p95 ≤ ~0.3ms / p99 ≤ ~1ms @120 & 300 BPM. Hand-owned test harness.
- **Gear management (v1 core — Henrique, production-ready):** auto-discover ANY CoreMIDI output + named virtual source. Per-device: enabled, nickname, **sync delay (ms)**, send-transport vs clock-only, live status (active/ready/off-available/remembered-missing). Stable-ID persistence with confident reconnect only; ambiguous name fallback requires confirmation; **new devices default OFF** (live safety); Panic excludes brand-new/default-off outputs by default.
- **Clock-while-stopped:** setting, default ON.
- **App surface:** menubar popover primary + Preferences (General · Devices · Link · About) + About. AppKit + LSUIElement + NSStatusItem.
- **Offsets:** per-device sync delay (ms) + global offset (ms) that stacks. (per-device delay pulled v2→v1.)
- **Updater:** Sparkle. **Persistence:** schema-versioned JSON `~/.config/synclock/`, single profile v1.
- **Dependencies allowed** (Henrique override — NOT zero-dep): choose per subsystem by quality. Hand-owned = scheduler, transport state machine, persistence, timing tests. Deps = Ableton Link (core), Sparkle, SwiftMIDI (conditional edge).

## House style (from Lineup, same dev — ~/code/window-manager)
- Swift 5.9 + SPM, AppKit not SwiftUI, LSUIElement agent, `Core` module = pure testable logic separated from UI, dependency-free test runner.
- Persistence JSON in `~/.config/lineup/`, schema-versioned w/ migration. Notarized DMG + GitHub Releases. Brand: "feels like Apple shipped it," one fixed accent (#2F6BFF). Free + Buy-Me-a-Coffee. MIT (Synclock differs → GPLv2).

## Old midiclock (what we replace — github.com/hcaiano/midiclock)
Electron + React + node-midi, window app, clock-master only 30–300 BPM, virtual port, per-device toggles, Space=start/stop, visual pulse. **No Link, no tap.** Fatal flaw: JS `setInterval` in Electron main process → timing jitter. Native CoreMIDI + scheduled timestamps fixes it.

## Ableton Link integration recipe (from Codex spike — VERIFIED current)
- **Use Ableton/link C++ source** (git submodule, pinned), NOT LinkKit (LinkKit license = iOS apps only; it's an XCFramework). Source = desktop/Mac path, header-only, GPLv2+/proprietary.
- Build: add `include` + `modules/asio-standalone/asio/include`, define `LINK_PLATFORM_MACOSX=1`, C++17, Xcode 16.2+ min. Uses `asio-standalone` submodule (not abseil for the source path).
- **C-ABI bridge** (`extern "C"`, opaque `MCLinkRef`), NOT Swift C++ interop for v1. Owns `std::unique_ptr<ableton::Link>`.
- Bridge API: create/destroy, setEnabled, setStartStopSyncEnabled, peerCount, tempo get/set(bpm,hostMicros), beat/phase/timeAtBeat, requestBeatAtTime, isPlaying/setIsPlaying(+AndRequestBeat), clockMicros, callbacks (peerCount/tempo/startStop). Use Link `clock().micros()` as canonical time domain — never `Date`/`DispatchTime` in timing code.
- Mode behavior: Free=disable Link (don't join network); Follow=read tempo/phase, derive tick grid, don't `setTempo`; Lead=`setTempo`+`setIsPlayingAndRequestBeatAtTime`, avoid `forceBeatAtTime` (anti-social). Link callbacks → core queue → main-thread snapshot to AppKit.
- License: ship GPLv2+, include GPL text + Ableton copyright/notices, publish corresponding source. Sparkle = MIT (sparkle-project.org). MIDIKit renamed **SwiftMIDI** (orchetect/swift-midi, MIT, 1.1.0 May 2026).
- SPM sketch: `platforms:[.macOS(.v13)]`, targets AbletonLinkBridge (cxx headerSearchPaths + define) → SynclockCore → SynclockApp(+Sparkle), `cxxLanguageStandard:.cxx17`. SPM+C++ is the real build risk → Phase 0 proves it; fallback = generated .xcodeproj static bridge target.

## Repo layout (proposed)
```
Package.swift
ThirdParty/ableton-link/ (submodule: include/ableton/Link.hpp, modules/asio-standalone/...)
Sources/SynclockCore/        (transport, settings, modes, tests)
Sources/SynclockApp/         (AppKit LSUIElement/menu/popover/prefs)
Sources/AbletonLinkBridge/   (include/AbletonLinkBridge.h C-ABI, AbletonLinkBridge.cpp)
branding/                    (icon assets from Codex)
```

## Icon spec (Codex, bound to Synclock)
- App icon 1024²: graphite rounded square (#24272C→#111316), centered timing ring (#F2F4F0, ~690px dia, 42px stroke), 24 subtle outer micro-ticks (every 6th longer), one #2F6BFF accent tick @12 o'clock, central pulse hub + needle tilted ~10°. No letters/DIN/waveforms/knobs. Export full .appiconset.
- Menubar glyph 18×18pt template (isTemplate mono), 1.5pt rounded stroke, ring + 12-o'clock stem + tiny 3/9 ticks; reads at 16px; idle + playing variants.

## Name vetting (iTunes Search API + web)
- ✅ Synclock — clean App Store + category. WINNER.
- ❌ Tactus (tactuslabs MIDI controller + TACTUS TM), Pulse (crowded), Downbeat (DownBeat mag TM), Tempolink (TempoLink® Temposonics), Clocklink (clocklink.com SEO).
- Backups (App-Store-clean): Temposync, Syncbeat, Clockbeat, Subbeat, Synclet, Pulsync.

## UI/UX design (impeccable, product register)
- Strategy → `PRODUCT.md` (3-word brand: trustworthy/exact/invisible; 5 design principles; anti-refs: Electron density, mini-DAW clutter, AI-slop, config-as-punishment).
- Visual system → `DESIGN.md` (dark vibrancy popover, Restrained color, #2F6BFF accent only for active/selected/primary + pulse, SF Pro, tabular numerals, status never color-only).
- Mockup → `design/synclock-mockup.html` (+ `.png` render). Two surfaces: popover (BPM/nudge/tap/transport/Link segmented/output-health/pulse) + Preferences→Devices gear table (per-device enable/nickname/delay/transport/status, virtual port pinned, NEW badge for new gear defaulting OFF, Minilogue=remembered-missing amber, Panic). Passed impeccable hook (no anti-patterns; fixed bounce-easing + em-dash overuse).
- The pulse = the one signature delight; everything else defers to macOS idiom ("feels like Apple shipped it").

## Logo / app-icon exploration (Codex generated, cofounders deciding)
5 divergent directions under `branding/explorations/` (+ contact-sheet.png), each with 1024/256/64/32 app icon, menubar idle/playing glyphs, wordmark lockup:
- **A Precision Ring** — refined original clock-ring. Safe/native but reads as generic clock/alarm app (category-reflex trap).
- **B Pulse Path** — clock-ring + rhythmic pulse spike + downbeat dot. Makes the in-app pulse the brand mark; coherent icon→menubar→animation→site system. **Claude's pick for PRIMARY.**
- **C Phase Grid** — phase arc + concentric sync rings + sweep. Best literal Link/product fit (Codex's top pick) but reads radar/sonar at a glance.
- **D Link Nodes** — synced peers/routing; risks generic-network look.
- **E Metronome Abstract** — reduced metronome; musical but least uniquely Synclock.
DECISION — **SIGNED OFF by Henrique 2026-06-16: B "Pulse Path" is the locked primary identity**, C "Phase Grid" alternate. Cofounders Claude + Codex both recommended B; founder confirmed. NOTE: existing `branding/Synclock.appiconset` (direction-A graphite clock) is SUPERSEDED — regenerate the production .appiconset + menubar glyph + wordmark from B before packaging, and reuse that identity on the Phase 10 marketing site. Locked refinements: centered blue dot = downbeat (not decoration); pulse spike = beat event (not generic waveform); ring stays quiet so pulse owns the mark; C's blue phase-arc reserved for MOTION (in-app Link-phase sweep/fill, hover/active, marketing demo); keep graphite + off-white + #2F6BFF (Lineup family). Plan also gained 5 Codex edits (offset stacking rule, 4-state gear model, hotplug confident-ID-only, Panic safety scope, brand-asset licensing) — GOAL_PROMPT.md locked from both review sides.

## Competitive landscape
E-RM MIDIclock (hardware ~€300), multiclock, midiclock.com (sw), Omniclock plugin, CLOCKstep:MULTI. Wedge = free + native + findable + Link.
