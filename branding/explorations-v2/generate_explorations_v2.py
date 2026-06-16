#!/usr/bin/env python3
from __future__ import annotations

import math
import textwrap
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parent

CORAL = (255, 92, 87, 255)
CORAL_DARK = (228, 68, 65, 255)
CORAL_LIGHT = (255, 153, 143, 255)
CREAM = (255, 249, 244, 255)
WARM_WHITE = (255, 253, 250, 255)
PEACH = (255, 225, 216, 255)
INK = (37, 39, 44, 255)
INK_SOFT = (93, 87, 86, 255)
WHITE = (255, 255, 255, 255)
BLACK = (0, 0, 0, 255)


DIRECTIONS = {
    "a-tempo-dot": {
        "title": "A. Tempo Dot",
        "rationale": "A single friendly downbeat dot with a tiny pulse notch: immediate at 32px and far less technical than the old waveform.",
        "tagline": "the friendly master pulse",
    },
    "b-soft-sync-rings": {
        "title": "B. Soft Sync Rings",
        "rationale": "Two warm sync rings and one centered beat make the Link/session idea readable without feeling like a radar diagram.",
        "tagline": "tight tempo, soft landing",
    },
    "c-coral-beat": {
        "title": "C. Coral Beat",
        "rationale": "A coral-forward app tile with one white beat stroke, bold enough for the Dock and simple enough for the menu bar.",
        "tagline": "one beat for the whole rig",
    },
    "d-rounded-metronome": {
        "title": "D. Rounded Metronome",
        "rationale": "A softened metronome mark keeps the musician signal while avoiding the generic alarm-clock read.",
        "tagline": "steady tempo, no DAW",
    },
    "e-phase-pebble": {
        "title": "E. Phase Pebble",
        "rationale": "A small coral phase pebble orbiting a calm center suggests follow/lead sync in the most minimal way.",
        "tagline": "follow or lead the pulse",
    },
}


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for candidate in (
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/SFNSDisplay.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
    ):
        try:
            return ImageFont.truetype(candidate, size=size)
        except OSError:
            pass
    return ImageFont.load_default()


def lerp(a: int, b: int, t: float) -> int:
    return round(a + (b - a) * t)


def mix(a: tuple[int, int, int, int], b: tuple[int, int, int, int], t: float) -> tuple[int, int, int, int]:
    return tuple(lerp(a[i], b[i], t) for i in range(4))


def point(cx: float, cy: float, radius: float, degrees: float) -> tuple[float, float]:
    radians = math.radians(degrees - 90)
    return cx + math.cos(radians) * radius, cy + math.sin(radians) * radius


def rounded_icon_background(
    top: tuple[int, int, int, int],
    bottom: tuple[int, int, int, int],
    size: int = 1024,
    scale: int = 3,
) -> tuple[Image.Image, ImageDraw.ImageDraw, int]:
    canvas = size * scale
    img = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    px = img.load()
    for y in range(canvas):
        t = y / max(1, canvas - 1)
        row = mix(top, bottom, t)
        for x in range(canvas):
            px[x, y] = row

    mask = Image.new("L", (canvas, canvas), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, canvas - 1, canvas - 1), radius=220 * scale, fill=255)
    img.putalpha(mask)

    shade = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shade)
    for i in range(70 * scale):
        alpha = int(26 * (i / (70 * scale)) ** 1.8)
        sdraw.rounded_rectangle(
            (i, i, canvas - 1 - i, canvas - 1 - i),
            radius=max(1, 220 * scale - i),
            outline=(122, 60, 46, alpha),
            width=2 * scale,
        )
    img = Image.alpha_composite(img, shade)
    return img, ImageDraw.Draw(img), scale


def soft_shadow(size: tuple[int, int], shape: str, box: tuple[int, int, int, int], radius: int = 0) -> Image.Image:
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    if shape == "ellipse":
        draw.ellipse(box, fill=(112, 44, 34, 80))
    else:
        draw.rounded_rectangle(box, radius=radius, fill=(112, 44, 34, 72))
    return layer.filter(ImageFilter.GaussianBlur(24))


def downsample(img: Image.Image) -> Image.Image:
    return img.resize((1024, 1024), Image.Resampling.LANCZOS)


def icon_tempo_dot() -> Image.Image:
    img, draw, s = rounded_icon_background(WARM_WHITE, PEACH)
    size = img.size
    cx = cy = size[0] // 2
    img = Image.alpha_composite(img, soft_shadow(size, "ellipse", (272 * s, 262 * s, 752 * s, 742 * s)))
    draw = ImageDraw.Draw(img)
    draw.ellipse((282 * s, 272 * s, 742 * s, 732 * s), fill=CORAL)
    draw.ellipse((342 * s, 332 * s, 682 * s, 672 * s), fill=(255, 116, 111, 255))
    draw.ellipse((430 * s, 420 * s, 594 * s, 584 * s), fill=WHITE)
    draw.ellipse((478 * s, 468 * s, 546 * s, 536 * s), fill=CORAL_DARK)
    draw.line((cx, 320 * s, cx, 244 * s), fill=CORAL_DARK, width=42 * s)
    draw.ellipse((cx - 33 * s, 226 * s, cx + 33 * s, 292 * s), fill=CORAL_DARK)
    return downsample(img)


def icon_soft_sync_rings() -> Image.Image:
    img, draw, s = rounded_icon_background(CREAM, (255, 235, 229, 255))
    cx = cy = img.size[0] // 2
    for radius, width, color in (
        (342 * s, 34 * s, (255, 92, 87, 92)),
        (254 * s, 42 * s, (255, 92, 87, 142)),
    ):
        draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), outline=color, width=width)
    arc_box = (cx - 254 * s, cy - 254 * s, cx + 254 * s, cy + 254 * s)
    draw.arc(arc_box, start=-88, end=18, fill=CORAL, width=46 * s)
    draw.ellipse((cx - 118 * s, cy - 118 * s, cx + 118 * s, cy + 118 * s), fill=CORAL)
    draw.ellipse((cx - 46 * s, cy - 46 * s, cx + 46 * s, cy + 46 * s), fill=WHITE)
    x, y = point(cx, cy, 254 * s, 0)
    draw.ellipse((x - 38 * s, y - 38 * s, x + 38 * s, y + 38 * s), fill=CORAL)
    return downsample(img)


def icon_coral_beat() -> Image.Image:
    img, draw, s = rounded_icon_background(CORAL_LIGHT, CORAL_DARK)
    size = img.size
    img = Image.alpha_composite(img, soft_shadow(size, "ellipse", (252 * s, 290 * s, 772 * s, 810 * s)))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle((178 * s, 236 * s, 846 * s, 788 * s), radius=180 * s, fill=(255, 255, 255, 58))
    pts = [
        (214 * s, 526 * s),
        (352 * s, 526 * s),
        (414 * s, 422 * s),
        (504 * s, 642 * s),
        (588 * s, 384 * s),
        (672 * s, 526 * s),
        (810 * s, 526 * s),
    ]
    draw.line(pts, fill=WHITE, width=54 * s, joint="curve")
    draw.ellipse((466 * s, 472 * s, 558 * s, 564 * s), fill=CORAL_DARK)
    return downsample(img)


def icon_rounded_metronome() -> Image.Image:
    img, draw, s = rounded_icon_background((255, 253, 250, 255), (255, 230, 224, 255))
    img = Image.alpha_composite(img, soft_shadow(img.size, "round", (298 * s, 204 * s, 726 * s, 834 * s), 112 * s))
    draw = ImageDraw.Draw(img)
    body = [(348 * s, 792 * s), (512 * s, 218 * s), (676 * s, 792 * s)]
    draw.line((*body[0], *body[1]), fill=CORAL, width=74 * s)
    draw.line((*body[1], *body[2]), fill=CORAL, width=74 * s)
    draw.line((378 * s, 792 * s, 646 * s, 792 * s), fill=CORAL, width=82 * s)
    draw.line((512 * s, 634 * s, 628 * s, 342 * s), fill=WHITE, width=46 * s)
    draw.ellipse((590 * s, 398 * s, 682 * s, 490 * s), fill=WHITE)
    draw.ellipse((468 * s, 666 * s, 556 * s, 754 * s), fill=WHITE)
    return downsample(img)


def icon_phase_pebble() -> Image.Image:
    img, draw, s = rounded_icon_background(WARM_WHITE, (255, 228, 222, 255))
    cx = cy = img.size[0] // 2
    draw.ellipse((cx - 286 * s, cy - 286 * s, cx + 286 * s, cy + 286 * s), outline=(255, 92, 87, 80), width=36 * s)
    draw.ellipse((cx - 172 * s, cy - 172 * s, cx + 172 * s, cy + 172 * s), fill=(255, 255, 255, 210))
    draw.ellipse((cx - 98 * s, cy - 98 * s, cx + 98 * s, cy + 98 * s), fill=CORAL)
    x, y = point(cx, cy, 286 * s, 42)
    img = Image.alpha_composite(img, soft_shadow(img.size, "ellipse", (int(x - 70 * s), int(y - 70 * s), int(x + 70 * s), int(y + 70 * s))))
    draw = ImageDraw.Draw(img)
    draw.ellipse((x - 66 * s, y - 66 * s, x + 66 * s, y + 66 * s), fill=CORAL)
    draw.ellipse((x - 24 * s, y - 24 * s, x + 24 * s, y + 24 * s), fill=WHITE)
    return downsample(img)


GENERATORS = {
    "a-tempo-dot": icon_tempo_dot,
    "b-soft-sync-rings": icon_soft_sync_rings,
    "c-coral-beat": icon_coral_beat,
    "d-rounded-metronome": icon_rounded_metronome,
    "e-phase-pebble": icon_phase_pebble,
}


def menu_glyph(slug: str, playing: bool, size: int = 36) -> Image.Image:
    scale = 8
    canvas = size * scale
    img = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    s = canvas / 18
    stroke = max(1, round(1.7 * s))
    cx = cy = 9 * s

    if slug == "a-tempo-dot":
        draw.ellipse((4.5 * s, 4.5 * s, 13.5 * s, 13.5 * s), outline=BLACK, width=stroke)
        draw.ellipse((7.1 * s, 7.1 * s, 10.9 * s, 10.9 * s), fill=BLACK)
        draw.line((cx, 4.4 * s, cx, 2.4 * s), fill=BLACK, width=stroke)
    elif slug == "b-soft-sync-rings":
        draw.ellipse((3.0 * s, 3.0 * s, 15.0 * s, 15.0 * s), outline=BLACK, width=stroke)
        draw.arc((5.3 * s, 5.3 * s, 12.7 * s, 12.7 * s), start=-90, end=22, fill=BLACK, width=stroke)
        draw.ellipse((7.4 * s, 7.4 * s, 10.6 * s, 10.6 * s), fill=BLACK)
    elif slug == "c-coral-beat":
        pts = [(2.5, 9.4), (5.6, 9.4), (6.9, 7.0), (9.0, 12.0), (10.8, 6.1), (12.5, 9.4), (15.5, 9.4)]
        draw.line([(x * s, y * s) for x, y in pts], fill=BLACK, width=stroke, joint="curve")
    elif slug == "d-rounded-metronome":
        draw.line((5.6 * s, 15 * s, 9 * s, 3.2 * s, 12.4 * s, 15 * s), fill=BLACK, width=stroke)
        draw.line((7.0 * s, 15 * s, 11.0 * s, 15 * s), fill=BLACK, width=stroke)
        draw.line((9 * s, 11.8 * s, 12.0 * s, 5.4 * s), fill=BLACK, width=stroke)
    else:
        draw.ellipse((3.0 * s, 3.0 * s, 15.0 * s, 15.0 * s), outline=BLACK, width=stroke)
        draw.ellipse((7.1 * s, 7.1 * s, 10.9 * s, 10.9 * s), fill=BLACK)
        draw.ellipse((12.0 * s, 4.8 * s, 15.2 * s, 8.0 * s), fill=BLACK)

    if playing:
        dot = 1.2 * s
        draw.ellipse((cx - dot, cy - dot, cx + dot, cy + dot), fill=BLACK)
    return img.resize((size, size), Image.Resampling.LANCZOS)


def glyph_svg(slug: str, playing: bool) -> str:
    dot = '<circle cx="9" cy="9" r="1.2" fill="#000"/>' if playing else ""
    if slug == "a-tempo-dot":
        body = '<circle cx="9" cy="9" r="4.5" fill="none" stroke="#000" stroke-width="1.7"/><circle cx="9" cy="9" r="1.9" fill="#000"/><path d="M9 4.4V2.4" fill="none" stroke="#000" stroke-width="1.7" stroke-linecap="round"/>'
    elif slug == "b-soft-sync-rings":
        body = '<circle cx="9" cy="9" r="6" fill="none" stroke="#000" stroke-width="1.7"/><path d="M9 5.3A3.7 3.7 0 0 1 12.5 10.2" fill="none" stroke="#000" stroke-width="1.7" stroke-linecap="round"/><circle cx="9" cy="9" r="1.6" fill="#000"/>'
    elif slug == "c-coral-beat":
        body = '<path d="M2.5 9.4H5.6L6.9 7L9 12L10.8 6.1L12.5 9.4H15.5" fill="none" stroke="#000" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>'
    elif slug == "d-rounded-metronome":
        body = '<path d="M5.6 15L9 3.2L12.4 15M7 15H11M9 11.8L12 5.4" fill="none" stroke="#000" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>'
    else:
        body = '<circle cx="9" cy="9" r="6" fill="none" stroke="#000" stroke-width="1.7"/><circle cx="9" cy="9" r="1.9" fill="#000"/><circle cx="13.6" cy="6.4" r="1.6" fill="#000"/>'
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 18 18">{body}{dot}</svg>\n'


def wordmark(slug: str, meta: dict[str, str]) -> Image.Image:
    img = Image.new("RGBA", (1200, 320), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    icon = GENERATORS[slug]().resize((166, 166), Image.Resampling.LANCZOS)
    img.alpha_composite(icon, (48, 72))
    draw.text((252, 82), "Synclock", font=font(90), fill=INK)
    draw.text((258, 188), meta["tagline"], font=font(30), fill=INK_SOFT)
    return img


def save_direction(slug: str, meta: dict[str, str]) -> tuple[Image.Image, Image.Image]:
    out = ROOT / slug
    out.mkdir(parents=True, exist_ok=True)
    icon = GENERATORS[slug]()
    icon.save(out / "app-icon-1024.png")
    for size in (512, 256, 128, 64, 32, 16):
        icon.resize((size, size), Image.Resampling.LANCZOS).save(out / f"app-icon-{size}.png")

    lockup = wordmark(slug, meta)
    lockup.save(out / "wordmark-lockup.png")

    for variant, playing in (("idle", False), ("playing", True)):
        for size in (18, 36):
            menu_glyph(slug, playing, size).save(out / f"menubar-{variant}-{size}.png")
        (out / f"menubar-{variant}.svg").write_text(glyph_svg(slug, playing), encoding="utf-8")

    (out / "README.md").write_text(
        f"# {meta['title']}\n\n{meta['rationale']}\n\nAccent: #FF5C57 Pulse Coral. App icon: light/friendly macOS rounded square. Menubar glyphs are black template assets.\n",
        encoding="utf-8",
    )
    return icon, lockup


def make_contact_sheet(items: list[tuple[str, dict[str, str], Image.Image, Image.Image]]) -> None:
    width = 1500
    row_h = 258
    sheet = Image.new("RGBA", (width, 58 + row_h * len(items)), (255, 250, 246, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((36, 22), "Synclock icon explorations v2 — Pulse Coral #FF5C57", font=font(30), fill=INK)
    for i, (slug, meta, icon, lockup) in enumerate(items):
        y = 64 + i * row_h
        draw.rounded_rectangle((24, y, width - 24, y + row_h - 20), radius=28, fill=WHITE, outline=(255, 214, 205, 255), width=2)
        sheet.alpha_composite(icon.resize((164, 164), Image.Resampling.LANCZOS), (54, y + 34))

        glyph_idle = menu_glyph(slug, False, 36)
        glyph_play = menu_glyph(slug, True, 36)
        sheet.alpha_composite(glyph_idle, (252, y + 50))
        sheet.alpha_composite(glyph_play, (302, y + 50))
        sheet.alpha_composite(lockup.resize((410, 110), Image.Resampling.LANCZOS), (246, y + 104))

        draw.text((710, y + 44), meta["title"], font=font(34), fill=INK)
        for line_index, line in enumerate(textwrap.wrap(meta["rationale"], width=78)):
            draw.text((710, y + 94 + line_index * 30), line, font=font(22), fill=INK_SOFT)
        draw.text((710, y + 172), f"Path: branding/explorations-v2/{slug}/", font=font(18), fill=(132, 100, 94, 255))
    sheet.save(ROOT / "contact-sheet.png")


def make_finalists_sheet(items: list[tuple[str, dict[str, str], Image.Image, Image.Image]]) -> None:
    finalists = [item for item in items if item[0] in ("a-tempo-dot", "c-coral-beat")]
    sheet = Image.new("RGBA", (1500, 820), (255, 250, 246, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((44, 30), "Synclock icon finalists — A vs C", font=font(38), fill=INK)
    draw.text(
        (48, 82),
        "Same Pulse Coral system; compare friendly tempo read vs bold modern Dock presence.",
        font=font(22),
        fill=INK_SOFT,
    )

    for column, (slug, meta, icon, lockup) in enumerate(finalists):
        x = 42 + column * 730
        draw.rounded_rectangle((x, 132, x + 688, 764), radius=34, fill=WHITE, outline=(255, 214, 205, 255), width=2)
        draw.text((x + 36, 168), meta["title"], font=font(34), fill=INK)
        for line_index, line in enumerate(textwrap.wrap(meta["rationale"], width=46)):
            draw.text((x + 36, 218 + line_index * 28), line, font=font(21), fill=INK_SOFT)

        sheet.alpha_composite(icon.resize((260, 260), Image.Resampling.LANCZOS), (x + 36, 330))
        sheet.alpha_composite(icon.resize((128, 128), Image.Resampling.LANCZOS), (x + 348, 360))
        sheet.alpha_composite(icon.resize((64, 64), Image.Resampling.LANCZOS), (x + 508, 390))
        sheet.alpha_composite(icon.resize((32, 32), Image.Resampling.LANCZOS), (x + 602, 406))

        glyph_idle = menu_glyph(slug, False, 36)
        glyph_play = menu_glyph(slug, True, 36)
        sheet.alpha_composite(glyph_idle, (x + 350, 536))
        sheet.alpha_composite(glyph_play, (x + 404, 536))
        draw.text((x + 348, 584), "idle", font=font(16), fill=INK_SOFT)
        draw.text((x + 398, 584), "play", font=font(16), fill=INK_SOFT)

        sheet.alpha_composite(lockup.resize((340, 91), Image.Resampling.LANCZOS), (x + 314, 612))
        draw.text((x + 36, 724), f"Source: branding/explorations-v2/{slug}/", font=font(16), fill=(132, 100, 94, 255))
    sheet.save(ROOT / "finalists-a-c.png")


def main() -> None:
    items = []
    for slug, meta in DIRECTIONS.items():
        icon, lockup = save_direction(slug, meta)
        items.append((slug, meta, icon, lockup))
    make_contact_sheet(items)
    make_finalists_sheet(items)
    print(f"Wrote {ROOT / 'contact-sheet.png'}")
    print(f"Wrote {ROOT / 'finalists-a-c.png'}")
    for slug in DIRECTIONS:
        print(f"Wrote {ROOT / slug}")


if __name__ == "__main__":
    main()
