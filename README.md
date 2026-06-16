# Synclock

**A native macOS menubar master MIDI clock + Ableton Link.** Sync your hardware
and software to one tight clock without opening a DAW. Free, native, open source.

> Status: in active development. See [`task_plan.md`](task_plan.md) for the phased
> build and [`GOAL_PROMPT.md`](GOAL_PROMPT.md) for the full spec.

## What it does (v1)
- Master **MIDI clock** (`0xF8` @ 24 PPQN) + transport (Start / Stop / Continue) to
  any connected gear and a named **virtual port**.
- **Ableton Link** — Free / Follow / Lead, peer count, the active mode always visible.
- **Works with any gear**: per-device enable, nickname, sync delay (ms),
  clock-vs-transport, live status. New devices default **off** for live safety.
- Decimal BPM (30–300) + fine nudge + tap tempo.
- A hand-owned, timestamped CoreMIDI scheduler — the clock is meant to feel *tight*.

## Build
Requires Swift 5.9+ (macOS 13+).

```sh
swift build            # builds the app + C-ABI Link bridge
swift run SynclockApp  # launch the menubar agent
swift run SynclockTests # dependency-free test runner
```

The `AbletonLinkBridge` target currently ships a self-contained **stub** so the
app builds offline; the real Ableton Link source is vendored in Phase 0 (see
[`ThirdParty/README.md`](ThirdParty/README.md)) behind the same C ABI.

## License
**GPLv2-or-later** (see [`LICENSE`](LICENSE)) — required because Synclock links the
Ableton Link C++ source. The **Synclock name, logo, and brand assets are reserved
Caiano brand assets**, not covered by the GPL.

Free, with an optional [Buy Me a Coffee](https://buymeacoffee.com/caiano).

Copyright © 2026 Henrique Caiano.
