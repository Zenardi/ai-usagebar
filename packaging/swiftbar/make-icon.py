#!/usr/bin/env python3
"""Generate the ai-usagebar app icon (macOS .iconset PNGs).

Motif: a "usage gauge" — a 270° severity ring (green -> amber -> red) on a dark
graphite squircle, echoing the live menu-bar gauge. Drawn at 4x supersample and
downscaled with LANCZOS for crisp edges at every size.
"""
import math
import os
import sys
from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "ai-usagebar.iconset"
BASE = 1024
S = 4                      # supersample factor
N = BASE * S               # working canvas

# ---- brand palette ---------------------------------------------------------
BG_TOP = (42, 53, 71)      # #2A3547 slate
BG_BOT = (18, 22, 30)      # #12161E graphite
TRACK = (51, 63, 82)       # #333F52 muted gauge track
RAMP = [                   # severity ramp across full 0..100% of the gauge
    (0.00, (63, 185, 80)),   # #3FB950 green
    (0.55, (227, 179, 65)),  # #E3B341 amber
    (1.00, (248, 81, 73)),   # #F85149 red
]
FILL = 0.70                # gauge fill fraction (ends in warm amber)

# ---- geometry (base units, scaled by S) ------------------------------------
CX, CY = 512, 548          # gauge center (nudged down to balance bottom gap)
R = 300                    # centerline radius
STROKE = 108               # ring thickness
SQ = (86, 86, 938, 938)    # squircle bbox (~8% margin, macOS grid-ish)
RAD = 190                  # squircle corner radius
START = 135                # gauge start angle (lower-left); gap centered at 6 o'clock
SWEEP = 270


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def ramp(f):
    f = max(0.0, min(1.0, f))
    for i in range(len(RAMP) - 1):
        f0, c0 = RAMP[i]
        f1, c1 = RAMP[i + 1]
        if f <= f1:
            return lerp(c0, c1, (f - f0) / (f1 - f0))
    return RAMP[-1][1]


def sc(v):
    return v * S


def vgradient(size, top, bot):
    g = Image.new("RGB", (1, size), top)
    px = g.load()
    for y in range(size):
        px[0, y] = lerp(top, bot, y / (size - 1))
    return g.resize((size, size))


def dot(draw, cx, cy, r, color):
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=color)


def arc_dots(draw, a0, a1, radius, half, color_fn, step=0.5):
    a = a0
    while a <= a1 + 1e-6:
        rad = math.radians(a)
        x = sc(CX) + sc(radius) * math.cos(rad)
        y = sc(CY) + sc(radius) * math.sin(rad)
        dot(draw, x, y, sc(half), color_fn(a))
        a += step


def main():
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))

    # soft drop shadow (reads well on light Spotlight/Finder backgrounds)
    shadow = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    off = sc(14)
    sd.rounded_rectangle(
        (sc(SQ[0]), sc(SQ[1]) + off, sc(SQ[2]), sc(SQ[3]) + off),
        radius=sc(RAD), fill=(0, 0, 0, 150),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(sc(16)))
    img = Image.alpha_composite(img, shadow)

    # squircle background with vertical gradient (masked)
    grad = vgradient(N, BG_TOP, BG_BOT).convert("RGBA")
    mask = Image.new("L", (N, N), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (sc(SQ[0]), sc(SQ[1]), sc(SQ[2]), sc(SQ[3])), radius=sc(RAD), fill=255)
    img.paste(grad, (0, 0), mask)

    # subtle top inner sheen for depth (capped low so it never blows out)
    white = Image.new("RGBA", (N, N), (255, 255, 255, 255))
    hmask = Image.new("L", (N, N), 0)
    ImageDraw.Draw(hmask).rectangle((0, 0, N, sc(SQ[1]) + sc(210)), fill=255)
    hmask = hmask.filter(ImageFilter.GaussianBlur(sc(70)))
    hmask = hmask.point(lambda v: v * 30 // 255)          # peak ~12% opacity
    hmask = Image.composite(hmask, Image.new("L", (N, N), 0), mask)
    img.paste(white, (0, 0), hmask)

    d = ImageDraw.Draw(img)
    half = STROKE / 2

    # track (full gauge)
    arc_dots(d, START, START + SWEEP, R, half, lambda a: TRACK, step=0.6)

    # value arc — color = severity at that absolute gauge position
    end = START + SWEEP * FILL
    arc_dots(d, START, end, R, half,
             lambda a: ramp((a - START) / SWEEP), step=0.4)

    # leading tip marker (the "live" value indicator)
    trad = math.radians(end)
    tx = sc(CX) + sc(R) * math.cos(trad)
    ty = sc(CY) + sc(R) * math.sin(trad)
    dot(d, tx, ty, sc(half * 0.92), (255, 255, 255, 255))
    dot(d, tx, ty, sc(half * 0.50), ramp(FILL))

    # downscale + write iconset
    os.makedirs(OUT, exist_ok=True)
    pairs = [
        ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
    ]
    cache = {}
    for name, px in pairs:
        if px not in cache:
            cache[px] = img.resize((px, px), Image.LANCZOS)
        cache[px].save(os.path.join(OUT, name))
    # a standalone preview
    img.resize((512, 512), Image.LANCZOS).save("preview.png")
    print("wrote", OUT, "and preview.png")


if __name__ == "__main__":
    main()
