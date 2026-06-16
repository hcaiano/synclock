#!/usr/bin/env python3
from __future__ import annotations

import math
import textwrap
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parent

BLUE = (47, 107, 255, 255)
OFF_WHITE = (242, 244, 240, 255)
GRAPHITE_TOP = (36, 39, 44, 255)
GRAPHITE_BOTTOM = (17, 19, 22, 255)
INK_MUTED = (185, 188, 184, 255)
BLACK = (0, 0, 0, 255)


DIRECTIONS = {
    "a-precision-ring": {
        "title": "A. Precision Ring",
        "rationale": "Closest to the current candidate: a studio-clock mark with 24 PPQN ticks, calm graphite, and one Lineup-blue beat marker.",
    },
    "b-pulse-path": {
        "title": "B. Pulse Path",
        "rationale": "A restrained heartbeat/transport pulse that makes Synclock feel alive without turning into an audio waveform brand.",
    },
    "c-phase-grid": {
        "title": "C. Phase Grid",
        "rationale": "A beat-phase grid: precise, technical, and directly tied to Link phase plus 24 PPQN scheduling.",
    },
    "d-link-nodes": {
        "title": "D. Link Nodes",
        "rationale": "Three synced nodes around a clock ring, emphasizing Ableton Link peers and gear routing without network-logo noise.",
    },
    "e-metronome-abstract": {
        "title": "E. Metronome Abstract",
        "rationale": "A native, reduced metronome silhouette for users who think of Synclock as the master pulse of the rig.",
    },
}


def font(size: int, weight: str = "regular") -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/SFNSDisplay.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
    ]
    for candidate in candidates:
        try:
            return ImageFont.truetype(candidate, size=size)
        except OSError:
            pass
    return ImageFont.load_default()


def lerp(a: int, b: int, t: float) -> int:
    return round(a + (b - a) * t)


def point(cx: float, cy: float, radius: float, degrees: float) -> tuple[float, float]:
    radians = math.radians(degrees - 90)
    return cx + math.cos(radians) * radius, cy + math.sin(radians) * radius


def base_icon(size: int = 1024, scale: int = 3) -> tuple[Image.Image, ImageDraw.ImageDraw, float, float, int]:
    canvas = size * scale
    img = Image.new("RGBA", (canvas, canvas))
    px = img.load()
    for y in range(canvas):
        t = y / max(1, canvas - 1)
        row = tuple(lerp(GRAPHITE_TOP[i], GRAPHITE_BOTTOM[i], t) for i in range(4))
        for x in range(canvas):
            px[x, y] = row

    mask = Image.new("L", (canvas, canvas), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, canvas - 1, canvas - 1), radius=225 * scale, fill=255)
    img.putalpha(mask)

    vignette = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    vdraw = ImageDraw.Draw(vignette)
    for i in range(70 * scale):
        alpha = int(36 * (i / (70 * scale)) ** 1.9)
        vdraw.rounded_rectangle(
            (i, i, canvas - 1 - i, canvas - 1 - i),
            radius=max(1, 225 * scale - i),
            outline=(0, 0, 0, alpha),
            width=2 * scale,
        )
    img = Image.alpha_composite(img, vignette)
    return img, ImageDraw.Draw(img), canvas / 2, canvas / 2, scale


def downsample(img: Image.Image) -> Image.Image:
    return img.resize((1024, 1024), Image.Resampling.LANCZOS)


def draw_ring(draw: ImageDraw.ImageDraw, cx: float, cy: float, r: float, width: int, color=OFF_WHITE) -> None:
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=color, width=width)


def draw_ticks(
    draw: ImageDraw.ImageDraw,
    cx: float,
    cy: float,
    outer: float,
    count: int,
    minor: float,
    major: float,
    scale: int,
    accent_index: int = 0,
) -> None:
    for i in range(count):
        deg = i * 360 / count
        is_major = i % 6 == 0 if count == 24 else i % max(1, count // 4) == 0
        length = (major if is_major else minor) * scale
        width = (15 if is_major else 9) * scale
        color = BLUE if i == accent_index else (242, 244, 240, 150 if is_major else 92)
        x1, y1 = point(cx, cy, outer - length, deg)
        x2, y2 = point(cx, cy, outer, deg)
        draw.line((x1, y1, x2, y2), fill=color, width=width)


def icon_precision_ring() -> Image.Image:
    img, draw, cx, cy, s = base_icon()
    draw_ring(draw, cx, cy, 345 * s, 42 * s)
    draw_ticks(draw, cx, cy, 435 * s, 24, 34, 58, s)
    nx, ny = point(cx, cy, 288 * s, 10)
    tx, ty = point(cx, cy, 82 * s, 190)
    draw.line((tx, ty, nx, ny), fill=OFF_WHITE, width=34 * s)
    draw.ellipse((cx - 59 * s, cy - 59 * s, cx + 59 * s, cy + 59 * s), fill=OFF_WHITE)
    draw.ellipse((cx - 21 * s, cy - 21 * s, cx + 21 * s, cy + 21 * s), fill=BLUE)
    return downsample(img)


def icon_pulse_path() -> Image.Image:
    img, draw, cx, cy, s = base_icon()
    draw_ring(draw, cx, cy, 330 * s, 30 * s, (242, 244, 240, 210))
    path = [
        (210, 525), (302, 525), (340, 470), (388, 610), (460, 368),
        (526, 657), (586, 525), (816, 525),
    ]
    pts = [(x * s, y * s) for x, y in path]
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    gdraw.line(pts, fill=(47, 107, 255, 135), width=34 * s, joint="curve")
    glow = glow.filter(ImageFilter.GaussianBlur(10 * s))
    img = Image.alpha_composite(img, glow)
    draw = ImageDraw.Draw(img)
    draw.line(pts, fill=OFF_WHITE, width=28 * s, joint="curve")
    draw.line(pts, fill=BLUE, width=14 * s, joint="curve")
    draw.ellipse((cx - 50 * s, cy - 50 * s, cx + 50 * s, cy + 50 * s), fill=OFF_WHITE)
    draw.ellipse((cx - 18 * s, cy - 18 * s, cx + 18 * s, cy + 18 * s), fill=BLUE)
    return downsample(img)


def icon_phase_grid() -> Image.Image:
    img, draw, cx, cy, s = base_icon()
    for r, alpha, width in ((350, 210, 24), (250, 130, 14), (150, 84, 10)):
        draw_ring(draw, cx, cy, r * s, width * s, (242, 244, 240, alpha))
    for i in range(24):
        deg = i * 15
        rr = 350 * s
        x, y = point(cx, cy, rr, deg)
        dot = (10 if i % 6 else 15) * s
        color = BLUE if i == 0 else (242, 244, 240, 160 if i % 6 == 0 else 95)
        draw.ellipse((x - dot, y - dot, x + dot, y + dot), fill=color)
    draw.arc((cx - 250 * s, cy - 250 * s, cx + 250 * s, cy + 250 * s), start=-88, end=38, fill=BLUE, width=38 * s)
    draw.line((cx, cy, *point(cx, cy, 306 * s, 42)), fill=OFF_WHITE, width=25 * s)
    draw.ellipse((cx - 42 * s, cy - 42 * s, cx + 42 * s, cy + 42 * s), fill=OFF_WHITE)
    return downsample(img)


def icon_link_nodes() -> Image.Image:
    img, draw, cx, cy, s = base_icon()
    node_angles = [0, 125, 235]
    node_points = [point(cx, cy, 285 * s, a) for a in node_angles]
    for p1, p2 in zip(node_points, node_points[1:] + node_points[:1]):
        draw.line((*p1, *p2), fill=(242, 244, 240, 70), width=18 * s)
    draw_ring(draw, cx, cy, 340 * s, 25 * s, (242, 244, 240, 180))
    for i, (x, y) in enumerate(node_points):
        r = (66 if i == 0 else 54) * s
        draw.ellipse((x - r, y - r, x + r, y + r), fill=BLUE if i == 0 else OFF_WHITE)
        inner = 22 * s
        draw.ellipse((x - inner, y - inner, x + inner, y + inner), fill=GRAPHITE_BOTTOM if i == 0 else BLUE)
    draw.ellipse((cx - 40 * s, cy - 40 * s, cx + 40 * s, cy + 40 * s), fill=OFF_WHITE)
    draw.ellipse((cx - 14 * s, cy - 14 * s, cx + 14 * s, cy + 14 * s), fill=BLUE)
    return downsample(img)


def icon_metronome() -> Image.Image:
    img, draw, cx, cy, s = base_icon()
    draw_ring(draw, cx, cy, 352 * s, 20 * s, (242, 244, 240, 130))
    body = [(348 * s, 782 * s), (512 * s, 220 * s), (676 * s, 782 * s)]
    draw.line((*body[0], *body[1]), fill=OFF_WHITE, width=30 * s)
    draw.line((*body[1], *body[2]), fill=OFF_WHITE, width=30 * s)
    draw.line((420 * s, 782 * s, 604 * s, 782 * s), fill=OFF_WHITE, width=34 * s)
    draw.line((512 * s, 620 * s, 604 * s, 330 * s), fill=BLUE, width=24 * s)
    draw.ellipse((572 * s, 402 * s, 636 * s, 466 * s), fill=BLUE)
    draw.ellipse((cx - 38 * s, cy - 38 * s, cx + 38 * s, cy + 38 * s), fill=OFF_WHITE)
    return downsample(img)


def menu_glyph(kind: str, playing: bool, size: int = 36) -> Image.Image:
    scale = 8
    canvas = size * scale
    img = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    s = canvas / 18
    cx = cy = 9 * s
    stroke = max(1, round(1.5 * s))

    if kind == "a-precision-ring":
        draw.ellipse((3.1 * s, 3.1 * s, 14.9 * s, 14.9 * s), outline=BLACK, width=stroke)
        draw.line((cx, cy, cx, 4.1 * s), fill=BLACK, width=stroke)
        draw.line((14.1 * s, cy, 16 * s, cy), fill=BLACK, width=stroke)
        draw.line((1.9 * s, cy, 3.7 * s, cy), fill=BLACK, width=stroke)
    elif kind == "b-pulse-path":
        pts = [(2.2, 9.2), (5.2, 9.2), (6.4, 6.5), (8.3, 12.2), (10.1, 5.1), (12.1, 9.2), (15.8, 9.2)]
        draw.line([(x * s, y * s) for x, y in pts], fill=BLACK, width=stroke, joint="curve")
    elif kind == "c-phase-grid":
        draw.ellipse((3.2 * s, 3.2 * s, 14.8 * s, 14.8 * s), outline=BLACK, width=stroke)
        draw.arc((5.3 * s, 5.3 * s, 12.7 * s, 12.7 * s), start=-90, end=35, fill=BLACK, width=stroke)
        draw.line((cx, cy, 12.8 * s, 5.2 * s), fill=BLACK, width=stroke)
    elif kind == "d-link-nodes":
        points = [(9, 3.2), (14.2, 12.1), (3.8, 12.1)]
        for a, b in zip(points, points[1:] + points[:1]):
            draw.line((a[0] * s, a[1] * s, b[0] * s, b[1] * s), fill=BLACK, width=max(1, round(1.1 * s)))
        for x, y in points:
            draw.ellipse(((x - 1.35) * s, (y - 1.35) * s, (x + 1.35) * s, (y + 1.35) * s), fill=BLACK)
    elif kind == "e-metronome-abstract":
        draw.line((5.3 * s, 15 * s, 9 * s, 3 * s, 12.7 * s, 15 * s), fill=BLACK, width=stroke)
        draw.line((7 * s, 15 * s, 11 * s, 15 * s), fill=BLACK, width=stroke)
        draw.line((9 * s, 11 * s, 12 * s, 5.2 * s), fill=BLACK, width=stroke)
    if playing:
        dot = 1.25 * s
        draw.ellipse((cx - dot, cy - dot, cx + dot, cy + dot), fill=BLACK)
    return img.resize((size, size), Image.Resampling.LANCZOS)


def write_glyph_svg(path: Path, kind: str, playing: bool) -> None:
    # Inline simple black-only SVG source. AppKit should load as a template image.
    dot = '<circle cx="9" cy="9" r="1.25" fill="#000"/>' if playing else ""
    if kind == "a-precision-ring":
        body = '<circle cx="9" cy="9" r="5.9" fill="none" stroke="#000" stroke-width="1.5"/><path d="M9 9V4.1M14.1 9H16M1.9 9H3.7" fill="none" stroke="#000" stroke-width="1.5" stroke-linecap="round"/>'
    elif kind == "b-pulse-path":
        body = '<path d="M2.2 9.2H5.2L6.4 6.5L8.3 12.2L10.1 5.1L12.1 9.2H15.8" fill="none" stroke="#000" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>'
    elif kind == "c-phase-grid":
        body = '<circle cx="9" cy="9" r="5.8" fill="none" stroke="#000" stroke-width="1.5"/><path d="M9 9L12.8 5.2" fill="none" stroke="#000" stroke-width="1.5" stroke-linecap="round"/><path d="M9 5.3A3.7 3.7 0 0 1 12.1 11" fill="none" stroke="#000" stroke-width="1.5" stroke-linecap="round"/>'
    elif kind == "d-link-nodes":
        body = '<path d="M9 3.2L14.2 12.1H3.8Z" fill="none" stroke="#000" stroke-width="1.2" stroke-linejoin="round"/><circle cx="9" cy="3.2" r="1.35" fill="#000"/><circle cx="14.2" cy="12.1" r="1.35" fill="#000"/><circle cx="3.8" cy="12.1" r="1.35" fill="#000"/>'
    else:
        body = '<path d="M5.3 15L9 3L12.7 15M7 15H11M9 11L12 5.2" fill="none" stroke="#000" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>'
    path.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 18 18">{body}{dot}</svg>\n', encoding="utf-8")


def wordmark(slug: str, title: str) -> Image.Image:
    img = Image.new("RGBA", (1200, 320), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    icon = GENERATORS[slug]().resize((184, 184), Image.Resampling.LANCZOS)
    img.alpha_composite(icon, (40, 68))
    draw.text((258, 87), "Synclock", font=font(94), fill=OFF_WHITE)
    descriptor = {
        "a-precision-ring": "MIDI Clock & Link",
        "b-pulse-path": "the master pulse",
        "c-phase-grid": "phase-tight MIDI clock",
        "d-link-nodes": "sync every output",
        "e-metronome-abstract": "steady tempo, no DAW",
    }[slug]
    draw.text((264, 192), descriptor, font=font(29), fill=INK_MUTED)
    return img


GENERATORS = {
    "a-precision-ring": icon_precision_ring,
    "b-pulse-path": icon_pulse_path,
    "c-phase-grid": icon_phase_grid,
    "d-link-nodes": icon_link_nodes,
    "e-metronome-abstract": icon_metronome,
}


def save_direction(slug: str, meta: dict[str, str]) -> tuple[Image.Image, Image.Image]:
    out = ROOT / slug
    out.mkdir(parents=True, exist_ok=True)
    icon = GENERATORS[slug]()
    icon.save(out / "app-icon-1024.png")
    icon.resize((256, 256), Image.Resampling.LANCZOS).save(out / "app-icon-256.png")
    icon.resize((64, 64), Image.Resampling.LANCZOS).save(out / "app-icon-64.png")
    icon.resize((32, 32), Image.Resampling.LANCZOS).save(out / "app-icon-32.png")

    lockup = wordmark(slug, meta["title"])
    lockup.save(out / "wordmark-lockup.png")

    for variant, playing in (("idle", False), ("playing", True)):
        for size in (18, 36):
            menu_glyph(slug, playing, size).save(out / f"menubar-{variant}-{size}.png")
        write_glyph_svg(out / f"menubar-{variant}.svg", slug, playing)

    (out / "README.md").write_text(
        f"# {meta['title']}\n\n{meta['rationale']}\n\nAccent: #2F6BFF. App icon: graphite macOS rounded square. Menubar glyphs are black template assets.\n",
        encoding="utf-8",
    )
    return icon, lockup


def make_contact_sheet(items: list[tuple[str, dict[str, str], Image.Image, Image.Image]]) -> None:
    width = 1480
    row_h = 260
    sheet = Image.new("RGBA", (width, 42 + row_h * len(items)), (18, 19, 22, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((36, 18), "Synclock logo/app-icon explorations", font=font(28), fill=OFF_WHITE)
    for i, (slug, meta, icon, lockup) in enumerate(items):
        y = 56 + i * row_h
        draw.rounded_rectangle((24, y, width - 24, y + row_h - 18), radius=24, fill=(32, 34, 38, 255))
        sheet.alpha_composite(icon.resize((164, 164), Image.Resampling.LANCZOS), (52, y + 35))
        glyph_idle = menu_glyph(slug, False, 36)
        glyph_play = menu_glyph(slug, True, 36)
        white_idle = Image.new("RGBA", glyph_idle.size, (255, 255, 255, 0)); white_idle.putalpha(glyph_idle.getchannel("A"))
        white_play = Image.new("RGBA", glyph_play.size, (255, 255, 255, 0)); white_play.putalpha(glyph_play.getchannel("A"))
        sheet.alpha_composite(white_idle, (246, y + 50))
        sheet.alpha_composite(white_play, (296, y + 50))
        sheet.alpha_composite(lockup.resize((420, 112), Image.Resampling.LANCZOS), (246, y + 100))
        draw.text((710, y + 46), meta["title"], font=font(34), fill=OFF_WHITE)
        for line_index, line in enumerate(textwrap.wrap(meta["rationale"], width=82)):
            draw.text((710, y + 96 + line_index * 31), line, font=font(22), fill=INK_MUTED)
        draw.text((710, y + 170), f"Path: branding/explorations/{slug}/", font=font(18), fill=(140, 144, 148, 255))
    sheet.save(ROOT / "contact-sheet.png")


def main() -> None:
    items = []
    for slug, meta in DIRECTIONS.items():
        icon, lockup = save_direction(slug, meta)
        items.append((slug, meta, icon, lockup))
    make_contact_sheet(items)
    print(f"Wrote {ROOT / 'contact-sheet.png'}")
    for slug in DIRECTIONS:
        print(f"Wrote {ROOT / slug}")


if __name__ == "__main__":
    main()
