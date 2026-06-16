#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent
DEFAULT_SOURCE = ROOT / "explorations-v3" / "a-mint-pulse-tile"
APP_DIR = ROOT / "app-icon"
EXPORTS_DIR = APP_DIR / "exports"
APPICONSET_DIR = ROOT / "Synclock.appiconset"
MENUBAR_DIR = ROOT / "menubar"
WORDMARK_DIR = ROOT / "wordmark"
VERIFY_DIR = ROOT / "verification"


def resolve_source() -> Path:
    if len(sys.argv) > 2:
        raise SystemExit("Usage: generate_synclock_icons.py [source-exploration-dir]")
    source_arg = sys.argv[1] if len(sys.argv) == 2 else os.environ.get("SYNCLOCK_ICON_SOURCE")
    if source_arg:
        return Path(source_arg).expanduser().resolve()
    return DEFAULT_SOURCE


def ensure_sources(source: Path) -> None:
    required = [
        source / "app-icon-1024.png",
        source / "menubar-idle.svg",
        source / "menubar-playing.svg",
        source / "menubar-idle-36.png",
        source / "menubar-playing-36.png",
        source / "wordmark-lockup.png",
    ]
    missing = [str(path) for path in required if not path.exists()]
    if missing:
        raise SystemExit(f"Missing Synclock icon source assets: {missing}")


def save_appiconset(master: Image.Image) -> None:
    entries = [
        ("16x16", "1x", 16, "synclock-icon-16.png"),
        ("16x16", "2x", 32, "synclock-icon-16@2x.png"),
        ("32x32", "1x", 32, "synclock-icon-32.png"),
        ("32x32", "2x", 64, "synclock-icon-32@2x.png"),
        ("128x128", "1x", 128, "synclock-icon-128.png"),
        ("128x128", "2x", 256, "synclock-icon-128@2x.png"),
        ("256x256", "1x", 256, "synclock-icon-256.png"),
        ("256x256", "2x", 512, "synclock-icon-256@2x.png"),
        ("512x512", "1x", 512, "synclock-icon-512.png"),
        ("512x512", "2x", 1024, "synclock-icon-512@2x.png"),
    ]
    images = []
    for logical, scale, pixels, filename in entries:
        master.resize((pixels, pixels), Image.Resampling.LANCZOS).save(APPICONSET_DIR / filename)
        images.append(
            {
                "filename": filename,
                "idiom": "mac",
                "scale": scale,
                "size": logical,
            }
        )
    (APPICONSET_DIR / "Contents.json").write_text(
        json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n",
        encoding="utf-8",
    )


def save_menubar_assets(source: Path) -> None:
    for variant in ("idle", "playing"):
        shutil.copyfile(source / f"menubar-{variant}.svg", MENUBAR_DIR / f"synclock-menubar-{variant}.svg")
        source_image = Image.open(source / f"menubar-{variant}-36.png").convert("RGBA")
        for size in (16, 18, 32, 36):
            source_image.resize((size, size), Image.Resampling.LANCZOS).save(
                MENUBAR_DIR / f"synclock-menubar-{variant}-{size}.png"
            )


def make_verification(master: Image.Image) -> None:
    thirty_two = master.resize((32, 32), Image.Resampling.LANCZOS)
    thirty_two.save(VERIFY_DIR / "synclock-icon-32px-readability.png")

    previews = [(140, "1024px"), (128, "128px"), (64, "64px"), (32, "32px"), (16, "16px")]
    sheet = Image.new("RGBA", (560, 190), (248, 248, 248, 255))
    draw = ImageDraw.Draw(sheet)
    x = 20
    for preview_size, label in previews:
        icon = master.resize((preview_size, preview_size), Image.Resampling.LANCZOS)
        y = 20 + (140 - preview_size) // 2
        sheet.alpha_composite(icon, (x, y))
        draw.text((x, 164), label, fill=(25, 25, 25, 255))
        x += preview_size + 34
    sheet.save(VERIFY_DIR / "synclock-icon-readability-sheet.png")

    glyph_sheet = Image.new("RGBA", (230, 90), (248, 248, 248, 255))
    gdraw = ImageDraw.Draw(glyph_sheet)
    gdraw.rounded_rectangle((118, 12, 218, 78), radius=12, fill=(30, 32, 36, 255))
    for i, variant in enumerate(("idle", "playing")):
        black = Image.open(MENUBAR_DIR / f"synclock-menubar-{variant}-36.png").convert("RGBA")
        white = Image.new("RGBA", black.size, (255, 255, 255, 0))
        white.putalpha(black.getchannel("A"))
        glyph_sheet.alpha_composite(black, (22 + i * 46, 20))
        glyph_sheet.alpha_composite(white, (134 + i * 46, 20))
    gdraw.text((20, 62), "idle", fill=(25, 25, 25, 255))
    gdraw.text((62, 62), "play", fill=(25, 25, 25, 255))
    gdraw.text((132, 62), "idle", fill=(235, 235, 235, 255))
    gdraw.text((174, 62), "play", fill=(235, 235, 235, 255))
    glyph_sheet.save(VERIFY_DIR / "synclock-menubar-glyph-sheet.png")


def main() -> None:
    source = resolve_source()
    ensure_sources(source)
    for directory in (APP_DIR, EXPORTS_DIR, APPICONSET_DIR, MENUBAR_DIR, WORDMARK_DIR, VERIFY_DIR):
        directory.mkdir(parents=True, exist_ok=True)

    master = Image.open(source / "app-icon-1024.png").convert("RGBA")
    master.save(APP_DIR / "synclock-icon-1024.png")
    for size in (16, 32, 64, 128, 256, 512, 1024):
        master.resize((size, size), Image.Resampling.LANCZOS).save(
            EXPORTS_DIR / f"synclock-icon-{size}.png"
        )
    save_appiconset(master)

    save_menubar_assets(source)
    shutil.copyfile(source / "wordmark-lockup.png", WORDMARK_DIR / "synclock-wordmark-lockup.png")

    make_verification(master)

    print(f"Source {source}")
    print(f"Wrote {APP_DIR / 'synclock-icon-1024.png'}")
    print(f"Wrote {APPICONSET_DIR}")
    print(f"Wrote {MENUBAR_DIR}")
    print(f"Wrote {WORDMARK_DIR / 'synclock-wordmark-lockup.png'}")
    print(f"Wrote {VERIFY_DIR / 'synclock-icon-readability-sheet.png'}")


if __name__ == "__main__":
    main()
