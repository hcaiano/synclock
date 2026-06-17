# Design

> Visual system for Synclock. Native macOS idiom — this maps to AppKit, the HTML mockup only exists to iterate the look. SF Pro, vibrancy, standard controls.

## Theme
Primary context is a **dark vibrancy popover** (producers work in dim studios / on stage). A light-appearance variant follows the same tokens via macOS semantic colors. Color strategy: **Restrained** — neutral surfaces + a single `#4FE3EC` Slider Cyan accent reserved for active/selected/primary and the live pulse. Nothing decorative.

## Color (dark popover; OKLCH values, rendered over NSVisualEffectView vibrancy)
| Role | Value | Use |
|------|-------|-----|
| `--bg` | translucent graphite `oklch(0.22 0.005 270 / 0.72)` over vibrancy | popover material |
| `--surface` | `oklch(0.27 0.006 270)` | raised rows, fields |
| `--surface-hover` | `oklch(0.31 0.006 270)` | row hover |
| `--ink` | `oklch(0.96 0.004 110)` (#F2F4F0) | primary text, BPM |
| `--ink-secondary` | `oklch(0.78 0.004 110)` | labels (≥4.5:1) |
| `--ink-muted` | `oklch(0.62 0.004 110)` | tertiary, units |
| `--accent` | `oklch(0.86 0.10 199)` (#4FE3EC, Slider Cyan) | active sync, selected mode, primary, pulse |
| `--hairline` | `oklch(1 0 0 / 0.08)` | separators |
| status: active | accent filled dot + "Active" | present, enabled, emitting clock/transport now |
| status: ready | `--ink-secondary` ring dot + "Ready" | present, enabled, not emitting right now |
| status: off/available | dim hollow dot + "Off" (or "New" badge) | present but disabled-for-sync (incl. new-default-OFF) |
| status: missing | amber `oklch(0.78 0.13 75)` hollow dot + "Missing" | remembered but absent; settings preserved |
Status is never color-only: dot fill/shape + text label always paired.

## Typography
`-apple-system, "SF Pro Text"/"SF Pro Display"`. Fixed rem scale, ratio ~1.2. **Tabular/monospaced numerals for BPM, ms, peer count** (no width jitter as digits change).
- BPM hero: 40px SF Pro Display, weight 500, `font-variant-numeric: tabular-nums`.
- Section labels: 11px, weight 600, `--ink-muted` (used sparingly — NOT an eyebrow on every block).
- Body/controls: 13px (macOS control size). Row title 13px ink, subtitle 11px secondary.

## Components (each needs default/hover/focus/active/disabled)
- **Segmented control** (Free · Follow · Lead) — selected segment fills accent, white text; macOS `NSSegmentedControl`.
- **BPM stepper** — large editable number, ▲▼ fine nudge (±0.1 hold-to-repeat), tap-tempo button. Tap shows last 4 taps subtly.
- **Transport** — single primary Play↔Stop button, accent when playing; Panic as a quiet secondary (not red-loud; confirm-on-hold or small).
- **Device row** — status dot + label, nickname (inline-editable), enable switch (`NSSwitch`), sync-delay stepper (ms, ±), transport toggle (compact). Hover raises surface; disabled rows dim to muted.
- **Output health chip** (popover) — "3 active · 1 missing" linking to Devices prefs.
- Empty state: "No MIDI gear found. Connect a device or enable the Synclock virtual port." — teaches, not "nothing here."

## Motion
150–250ms ease-out on state transitions (mode switch, switch toggle, row hover). The **pulse** is the one signature: a 1-beat accent flash synced to the clock (the visible heartbeat). All motion has a `prefers-reduced-motion` fallback — pulse becomes a static lit dot; transitions become instant.

## Layout
- **Popover**: ~300pt wide, content-height. Vertical stack: tempo+transport block → Link mode block → output health → footer (gear → Preferences, power). Generous but not airy; producer scans top-to-bottom.
- **Preferences window**: standard macOS toolbar tabs — General · Devices · Link · About. Devices = a clean table (not cards), one row per output, virtual port pinned at top.
- Responsive = structural only (window resize reflows the device table); no fluid type.
