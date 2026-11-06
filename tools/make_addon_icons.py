#!/usr/bin/env python3
"""Draws the minimap/compartment icons of the family's addons: cream symbols with a gold rim shadow on a
transparent background, made for the dark leather disc of Pergamino's minimap button (Pergamino 7).

Same shapes as tools/logos.html: open book (Bitácora), bell (Recordame), 3x3 card (Bingo de la Guild),
hammer (Taller), banner (Listos para la raid), eye (Centinela), crossed arrows (Trueque). Drawn at 4x and
reduced to 64x64, 32-bit TGA, written straight into each addon's Media folder (paths below; --out DIR writes
them all into one folder instead). No game art.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

CREAM = (242, 227, 192, 255)
GOLD = (216, 168, 69, 255)
SIZE = 64
SCALE = 4
S = SIZE * SCALE  # 256 drawing canvas
W = 7 * SCALE  # stroke width at 4x

HOME = Path(__file__).resolve().parents[2]
TARGETS = {
    "book": [HOME / "bitacora/Bitacora_Datos/Media/icon.tga", HOME / "bitacora/Recordame/Media/icon.tga"],
    "bell": [HOME / "bitacora/Bitacora_Datos/Media/icon_bell.tga", HOME / "bitacora/Recordame/Media/icon_bell.tga"],
    "grid": [HOME / "bingo-guild/BingoDeLaGuild/Media/icon.tga"],
    "hammer": [HOME / "taller/Taller/Media/icon.tga"],
    "flag": [HOME / "listos-raid/ListosParaLaRaid/Media/icon.tga"],
    "eye": [HOME / "centinela/Centinela/Media/icon.tga"],
    "swap": [HOME / "trueque/Trueque/Media/icon.tga"],
}


def p(x: float, y: float) -> tuple[float, float]:
    """A point in the 200x200 space of logos.html, mapped onto the canvas with a margin."""
    m = 0.14
    return (m * S + x / 200 * (1 - 2 * m) * S, m * S + y / 200 * (1 - 2 * m) * S)


def stroke(d: ImageDraw.ImageDraw, pts, color, width=W, closed=False) -> None:
    pts = [p(*q) for q in pts]
    if closed:
        pts.append(pts[0])
    d.line(pts, fill=color, width=width, joint="curve")
    r = width / 2
    for x, y in pts:  # round caps
        d.ellipse([x - r, y - r, x + r, y + r], fill=color)


def book(d, c):
    stroke(d, [(100, 60), (82, 44), (56, 40), (28, 46), (28, 156), (56, 150), (82, 154), (100, 170)], c)
    stroke(d, [(100, 60), (118, 44), (144, 40), (172, 46), (172, 156), (144, 150), (118, 154), (100, 170)], c)
    stroke(d, [(100, 60), (100, 170)], c)
    for y in (80, 110):
        stroke(d, [(52, y), (88, y + 2)], c, width=W * 2 // 3)
        stroke(d, [(148, y), (112, y + 2)], c, width=W * 2 // 3)


def bell(d, c):
    stroke(d, [(100, 32), (100, 44)], c)
    stroke(d, [(58, 142), (58, 98), (66, 72), (84, 54), (100, 52), (116, 54), (134, 72), (142, 98), (142, 142), (158, 160), (42, 160), (58, 142)], c)
    stroke(d, [(84, 172), (92, 184), (108, 184), (116, 172)], c)


def grid(d, c):
    stroke(d, [(34, 34), (166, 34), (166, 166), (34, 166)], c, closed=True)
    stroke(d, [(78, 34), (78, 166)], c)
    stroke(d, [(122, 34), (122, 166)], c)
    stroke(d, [(34, 78), (166, 78)], c)
    stroke(d, [(34, 122), (166, 122)], c)
    for (x, y) in ((56, 56), (144, 100), (100, 144)):
        stroke(d, [(x - 8, y - 8), (x + 8, y + 8)], c, width=W * 2 // 3)
        stroke(d, [(x + 8, y - 8), (x - 8, y + 8)], c, width=W * 2 // 3)


def hammer(d, c):
    stroke(d, [(30, 170), (104, 96)], c)
    stroke(d, [(92, 46), (154, 108), (174, 88), (182, 70), (174, 52), (154, 32), (136, 26), (116, 32), (92, 46)], c, closed=True)
    stroke(d, [(118, 20), (180, 82)], c)


def flag(d, c):
    stroke(d, [(52, 176), (52, 28)], c)
    stroke(d, [(52, 36), (150, 36), (128, 68), (150, 100), (52, 100)], c)
    stroke(d, [(78, 56), (118, 56)], c, width=W * 2 // 3)
    stroke(d, [(78, 76), (118, 76)], c, width=W * 2 // 3)


def eye(d, c):
    pts = []
    import math

    for i in range(41):
        t = i / 40
        x = 22 + 156 * t
        y = 100 - 52 * math.sin(math.pi * t)
        pts.append((x, y))
    stroke(d, pts, c)
    pts = [(22 + 156 * (i / 40), 100 + 52 * math.sin(math.pi * (i / 40))) for i in range(41)]
    stroke(d, pts, c)
    cx, cy = p(100, 100)
    r = 26 / 200 * (1 - 0.28) * S
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=c, width=W)
    r2 = 9 / 200 * (1 - 0.28) * S
    d.ellipse([cx - r2, cy - r2, cx + r2, cy + r2], fill=c)


def swap(d, c):
    stroke(d, [(34, 72), (154, 72), (124, 42)], c)
    stroke(d, [(166, 128), (46, 128), (76, 158)], c)


SHAPES = {"book": book, "bell": bell, "grid": grid, "hammer": hammer, "flag": flag, "eye": eye, "swap": swap}


def render(name: str) -> Image.Image:
    # gold rim: the shape drawn a little thicker, blurred, under the cream shape
    rim = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    SHAPES[name](ImageDraw.Draw(rim), GOLD)
    rim = rim.filter(ImageFilter.MaxFilter(SCALE * 2 + 1)).filter(ImageFilter.GaussianBlur(SCALE * 1.2))
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    SHAPES[name](ImageDraw.Draw(shadow), (30, 18, 8, 200))
    shadow = shadow.filter(ImageFilter.GaussianBlur(SCALE * 1.5))
    face = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    SHAPES[name](ImageDraw.Draw(face), CREAM)
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.alpha_composite(shadow, (SCALE, SCALE * 2))
    out.alpha_composite(rim)
    out.alpha_composite(face)
    return out.resize((SIZE, SIZE), Image.LANCZOS)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", help="write every icon into this folder (as <name>.tga) instead of the addons")
    args = ap.parse_args()
    for name in SHAPES:
        img = render(name)
        paths = [Path(args.out) / f"{name}.tga"] if args.out else TARGETS[name]
        for path in paths:
            path.parent.mkdir(parents=True, exist_ok=True)
            img.save(path, compression=None)
            print(f"{name:7s} -> {path}")


if __name__ == "__main__":
    main()
