#!/usr/bin/env python3
"""Generate Synclock's menu-bar template glyph: the logo's three fader bars
(short outer pair, tall center) with a round knob on the center fader.

Template images are pure black + alpha; macOS recolors them for light/dark
menu bars. Rendered at 8x and downsampled for crisp edges at 16-18px.
"""
from PIL import Image, ImageDraw

SS = 8                      # supersample factor
BLACK = (0, 0, 0, 255)


def capsule(draw, cx, cy, w, h, fill):
    r = w / 2
    draw.rounded_rectangle([cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2],
                           radius=r, fill=fill)


def glyph(size):
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    bar_w = 0.118 * S
    gap = 0.270 * S          # spacing between fader centers
    cx = S / 2
    cy = S / 2
    left_x, right_x = cx - gap, cx + gap

    center_h = 0.76 * S      # tall center fader
    outer_h = 0.46 * S       # shorter symmetric outer faders
    knob_d = 0.30 * S        # round knob bulge on the center fader

    capsule(d, left_x, cy, bar_w, outer_h, BLACK)
    capsule(d, right_x, cy, bar_w, outer_h, BLACK)
    capsule(d, cx, cy, bar_w, center_h, BLACK)
    d.ellipse([cx - knob_d / 2, cy - knob_d / 2, cx + knob_d / 2, cy + knob_d / 2],
              fill=BLACK)

    return img.resize((size, size), Image.LANCZOS)


def main():
    here = __file__.rsplit("/", 1)[0]
    for state in ("idle", "playing"):   # same mark for both states
        for px in (16, 18, 32, 36):
            glyph(px).save(f"{here}/synclock-menubar-{state}-{px}.png")
    print("wrote menu-bar template glyphs (idle + playing, 16/18/32/36)")


if __name__ == "__main__":
    main()
