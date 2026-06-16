# Product

## Register

product

## Users
Music producers, live performers, and hardware/synth hobbyists on macOS who run a setup of MIDI gear (grooveboxes, drum machines, synths, sequencers) and/or software (Ableton, Logic) and need everything locked to one tempo. Their context: they're at a desk or on stage, often mid-session, and they do NOT want to boot a heavy DAW just to get a clock running. They reach for Synclock from the menu bar, set a tempo, pick which gear syncs, hit play, and get back to making music. The job: "make all my gear share one tight clock, instantly, and stay out of my way."

## Product Purpose
Synclock is a native macOS menubar app that acts as the master MIDI clock + Ableton Link hub for a music setup. It sends a rock-solid, low-jitter MIDI clock + transport (Start/Stop/Continue) to any connected gear and a virtual port, and participates in Ableton Link sessions (Free / Follow / Lead). Success = a producer trusts it as the heartbeat of their rig: the clock feels tight (measurably low jitter), every device is controllable (per-device enable, nickname, sync delay, transport), nothing surprises them live, and the app is invisible until needed. It replaces a janky Electron predecessor whose JS-timer clock jittered.

## Brand Personality
Native, precise, calm. Voice is quiet and exact — it states facts (BPM, mode, peer count, device status), never markets at you. Three words: **trustworthy, exact, invisible.** Emotional goal: the confidence of a piece of studio hardware — you set it and forget it because it just holds. It should feel like Apple shipped it, and sit naturally next to its sibling app Lineup.

## Anti-references
- **Electron density / web-app feel** (the old midiclock). No cramped custom chrome, no web widgets pretending to be native.
- **Mini-DAW clutter** — no transport bars bristling with knobs, no faux-rack skeuomorphism, no MIDI-DIN nostalgia or waveform decoration.
- **"AI-made" tells** — gradient text, glassmorphism-for-decoration, identical card grids, tiny tracked uppercase eyebrows, rainbow accents.
- **Configuration as punishment** — no dumping a raw list of cryptic CoreMIDI endpoint names with no nicknames, no status, no safe defaults.
- **Loud confirmation theater** — no celebratory modals for setting a tempo.

## Design Principles
1. **The tool disappears into the task.** First click exposes exactly what a producer needs mid-session (tempo, transport, mode, output health) and nothing else. Depth lives in Preferences.
2. **State you can trust at a glance.** The active Link mode, which devices are live, and whether the clock is running must be unmistakable without reading — the app never leaves you guessing what it's doing to your rig.
3. **Safe by default, powerful on demand.** New gear never receives clock until you opt it in; destructive/live-affecting actions (Panic, start blasting clock) are deliberate, not accidental.
4. **Speak the user's language, not CoreMIDI's.** Nicknames, plain labels ("Sync delay", "Send transport"), human device status — never raw endpoint UIDs.
5. **Earned familiarity over novelty.** Standard macOS idioms (popover, vibrancy, system controls, NSStatusItem) so a Mac user is instantly fluent. Delight is reserved for one moment: the pulse.

## Accessibility & Inclusion
- Full keyboard operability in the popover and Preferences; visible focus rings; logical tab order.
- VoiceOver labels on every control, especially device rows and transport state (announce "Playing, 122.5 BPM, Following Link" not just icon state).
- Do not encode device/sync status by color alone — pair the status dot with shape/label (active/connected/missing).
- Respect Reduce Motion: the pulse and any transitions degrade to a non-animated state indicator.
- Contrast ≥4.5:1 for all text including secondary labels; the #2F6BFF accent only on active/selected/primary, never as low-contrast body text.
