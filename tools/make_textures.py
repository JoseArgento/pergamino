#!/usr/bin/env python3
"""Draws Pergamino's textures into Libs/Pergamino/Media/*.tga.

Everything comes from noise and shapes (no game art). Sizes are powers of 2, files are 32-bit TGA, which the
WoW client loads from an addon folder. Deterministic: the same seed gives the same files. Needs Pillow.

  page.tga          512x512  parchment page (the book shows the left page as-is and mirrors it for the right one)
  leather.tga       512x512  dark leather: the cover around the pages, the fill of buttons
  spine.tga         128x512  the shadow of the spine, alpha only (stretched over the middle of the book)
  ribbon.tga        256x128  two cloth bookmarks, 256x64 each: crimson (top) and gold (bottom) (kept for old copies)
  bookmark.tga      256x32   a light cloth bookmark, tinted in-game (one colour per bookmark): tucked-in shadow on the
                             left, stitches along both edges, swallowtail on the right
  title.tga         512x64   the banner that holds the title
  seal.tga          64x64    a wax seal (the close button)
  check.tga         64x32    an ink box (left half) and its tick (right half)
  pill.tga          64x32    a white rounded pill, tinted in-game for tags and chips
  ring.tga          64x64    the leather ring with a gold fillet around the minimap button (transparent middle)
  mask.tga          64x64    a white disc: the mask that rounds the icon inside the minimap button
"""

import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Libs" / "Pergamino" / "Media"

PARCHMENT_DARK, PARCHMENT_LIGHT = (214, 190, 142), (247, 234, 204)
LEATHER_DARK, LEATHER_LIGHT = (34, 18, 10), (84, 44, 26)
CRIMSON, CRIMSON_DARK = (143, 42, 29), (84, 22, 14)
GOLD, GOLD_DARK, GOLD_LIGHT = (216, 168, 69), (148, 112, 31), (240, 206, 120)
INK = (58, 35, 19)


def noise(w: int, h: int, scale: int, seed: int) -> Image.Image:
    rnd = random.Random(seed)
    small = Image.new("L", (max(2, w // scale), max(2, h // scale)))
    small.putdata([rnd.randint(0, 255) for _ in range(small.width * small.height)])
    return small.resize((w, h), Image.BICUBIC)


def fractal(w: int, h: int, seed: int) -> Image.Image:
    out = Image.new("L", (w, h), 0)
    for i, (s, weight) in enumerate([(64, 0.45), (16, 0.3), (4, 0.18), (1, 0.07)]):
        out = ImageChops.add(
            out, noise(w, h, s, seed + i).point(lambda v, k=weight: int(v * k))
        )
    return out


def tint(gray: Image.Image, dark: tuple, light: tuple) -> Image.Image:
    bands = [
        gray.point(lambda v, i=i: int(dark[i] + (light[i] - dark[i]) * v / 255))
        for i in range(3)
    ]
    return Image.merge("RGB", bands)


def vignette(w: int, h: int, start: float, strength: float) -> Image.Image:
    v = Image.new("L", (w, h))
    px = v.load()
    cx, cy = (w - 1) / 2, (h - 1) / 2
    for y in range(h):
        for x in range(w):
            d = math.hypot((x - cx) / cx, (y - cy) / cy) / math.sqrt(2)
            px[x, y] = int(
                255 * min(1.0, max(0.0, (d - start) / (1 - start))) ** 1.5 * strength
            )
    return v


def page() -> Image.Image:
    size = 512
    paper = tint(fractal(size, size, 7), PARCHMENT_DARK, PARCHMENT_LIGHT)
    # a few fibres
    d = ImageDraw.Draw(paper)
    rnd = random.Random(11)
    for _ in range(70):
        x, y = rnd.randint(0, size), rnd.randint(0, size)
        length, angle = rnd.randint(6, 26), rnd.uniform(0, math.pi)
        d.line(
            (x, y, x + length * math.cos(angle), y + length * math.sin(angle)),
            fill=(204, 182, 138),
            width=1,
        )
    paper = paper.filter(ImageFilter.GaussianBlur(0.4))
    # darker, slightly burnt edges; the inner (spine) edge is the left one and stays lighter
    edge = Image.new("L", (size, size), 0)
    px = edge.load()
    for y in range(size):
        for x in range(size):
            dx_right = (size - 1 - x) / size
            dy = min(y, size - 1 - y) / size
            e = min(dx_right * 3.2, dy * 3.2, 1.0)
            px[x, y] = int(255 * (1 - e) ** 2.2 * 0.55)
    paper = Image.composite(Image.new("RGB", (size, size), (150, 112, 66)), paper, edge)
    return paper.convert("RGBA")


def leather() -> Image.Image:
    size = 512
    skin = tint(fractal(size, size, 41), LEATHER_DARK, LEATHER_LIGHT)
    grain = noise(size, size, 2, 99).point(lambda v: int(v * 0.12))
    skin = ImageChops.subtract(skin, Image.merge("RGB", (grain, grain, grain)))
    skin = Image.composite(
        Image.new("RGB", (size, size), (18, 8, 4)), skin, vignette(size, size, 0.5, 0.7)
    )
    return skin.filter(ImageFilter.SMOOTH).convert("RGBA")


def spine() -> Image.Image:
    w, h = 128, 512
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for x in range(w):
        t = abs((x - (w - 1) / 2) / ((w - 1) / 2))  # 0 at the centre, 1 at the edges
        a = int(230 * (1 - t) ** 2.0)
        for y in range(h):
            px[x, y] = (24, 12, 6, a)
    return img


def cloth(w: int, h: int, base: tuple, dark: tuple, seed: int) -> Image.Image:
    weave = noise(w, h, 1, seed).point(lambda v: 150 + v * 105 // 255)
    img = tint(weave, dark, base)
    # soft fold shading along the length
    shade = Image.new("L", (w, h))
    px = shade.load()
    for y in range(h):
        s = 1 - abs((y - (h - 1) / 2) / ((h - 1) / 2))
        v = int(255 * (0.55 + 0.45 * s))
        for x in range(w):
            px[x, y] = v
    return Image.composite(img, tint(weave, dark, dark), shade)


def ribbon() -> Image.Image:
    """Two bookmarks, one per row: crimson, then gold. Straight left end (under the cover), swallowtail right end."""
    w, h = 256, 64
    out = Image.new("RGBA", (w, h * 2), (0, 0, 0, 0))
    for row, (base, dark, edge) in enumerate(
        [(CRIMSON, CRIMSON_DARK, GOLD_DARK), (GOLD, GOLD_DARK, CRIMSON_DARK)]
    ):
        body = cloth(w, h, base, dark, 5 + row).convert("RGBA")
        mask = Image.new("L", (w, h), 0)
        d = ImageDraw.Draw(mask)
        notch = 14
        d.polygon(
            [(0, 6), (w - 1, 6), (w - 1 - notch, h // 2), (w - 1, h - 7), (0, h - 7)],
            fill=255,
        )
        body.putalpha(mask)
        d2 = ImageDraw.Draw(body)
        d2.line([(0, 6), (w - 1, 6)], fill=edge + (255,), width=2)
        d2.line([(0, h - 7), (w - 1, h - 7)], fill=edge + (255,), width=2)
        out.paste(body, (0, row * h), body)
    return out


def bookmark() -> Image.Image:
    """A near-white cloth ribbon, tinted in-game with SetVertexColor. 256x32.

    Left: a dark gradient where it goes under the cover. Top and bottom: a light dashed stitch. Right: a
    swallowtail cut. A thin dark edge all around so two ribbons never melt into each other."""
    w, h = 256, 32
    weave = noise(w, h, 1, 41).point(lambda v: 205 + v * 50 // 255)
    stripes = Image.new("L", (w, h))
    sp = stripes.load()
    for y in range(h):
        for x in range(w):
            sp[x, y] = 255 if (y % 3) else 232  # fine woven lines along the length
    body = ImageChops.multiply(weave, stripes)
    px = body.load()
    for y in range(h):  # fold: a little darker towards both edges
        s = 1 - abs((y - (h - 1) / 2) / ((h - 1) / 2))
        for x in range(w):
            tuck = min(1.0, x / 34)  # the part under the cover goes dark
            px[x, y] = int(px[x, y] * (0.78 + 0.22 * s) * (0.35 + 0.65 * tuck))
    img = Image.merge("RGBA", (body, body, body, Image.new("L", (w, h), 255)))
    d = ImageDraw.Draw(img)
    for yy in (4, h - 5):  # stitches
        for x in range(30, w - 22, 7):
            d.line([(x, yy), (x + 3, yy)], fill=(255, 250, 235, 255), width=1)
    mask = Image.new("L", (w, h), 0)
    notch = 12
    ImageDraw.Draw(mask).polygon([(0, 1), (w - 1, 1), (w - 1 - notch, h // 2), (w - 1, h - 2), (0, h - 2)], fill=255)
    edge = mask.filter(ImageFilter.MinFilter(3))
    outline = ImageChops.subtract(mask, edge)
    dark = Image.new("RGBA", (w, h), (70, 60, 50, 255))
    img = Image.composite(dark, img, outline)
    img.putalpha(mask)
    return img


def title() -> Image.Image:
    w, h = 512, 64
    body = cloth(w, h, CRIMSON, CRIMSON_DARK, 23).convert("RGBA")
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    notch, pad = 18, 8
    d.polygon(
        [
            (0, pad),
            (w - 1, pad),
            (w - 1 - notch, h // 2),
            (w - 1, h - 1 - pad),
            (0, h - 1 - pad),
            (notch, h // 2),
        ],
        fill=255,
    )
    body.putalpha(mask)
    d2 = ImageDraw.Draw(body)
    for yy in (pad + 2, h - 3 - pad):
        d2.line([(notch + 4, yy), (w - 5 - notch, yy)], fill=GOLD + (255,), width=2)
    return body


def seal() -> Image.Image:
    size = 64
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c, r = size / 2, 27
    d.ellipse((c - r, c - r, c + r, c + r), fill=(120, 30, 22, 255))
    d.ellipse((c - r + 3, c - r + 3, c + r - 3, c + r - 3), fill=(150, 42, 30, 255))
    d.ellipse(
        (c - r + 8, c - r + 8, c + r - 8, c + r - 8),
        outline=(100, 24, 18, 255),
        width=2,
    )
    # an eight-point star pressed into the wax
    pts = []
    for k in range(16):
        a = k * math.pi / 8
        rr = 13 if k % 2 == 0 else 6
        pts.append((c + rr * math.sin(a), c - rr * math.cos(a)))
    d.polygon(pts, fill=(104, 26, 20, 255), outline=(176, 70, 50, 255))
    # a highlight
    d.arc(
        (c - r + 4, c - r + 4, c + r - 4, c + r - 4),
        200,
        260,
        fill=(200, 100, 80, 200),
        width=2,
    )
    return img.filter(ImageFilter.GaussianBlur(0.3))


def check() -> Image.Image:
    w, h = 64, 32
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((3, 3, 28, 28), radius=3, outline=INK + (255,), width=2)
    d.line([(38, 16), (45, 24), (59, 8)], fill=INK + (255,), width=4, joint="curve")
    return img


def pill() -> Image.Image:
    w, h = 64, 32
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle(
        (1, 1, w - 2, h - 2), radius=14, fill=(255, 255, 255, 255)
    )
    return img


def _radial(size: int, inner: float, outer: float) -> Image.Image:
    """An 'L' band mask: 255 between the two radii (in px from the centre), soft edges."""
    big = size * 4
    m = Image.new("L", (big, big), 0)
    d = ImageDraw.Draw(m)
    c = big / 2
    d.ellipse((c - outer * 4, c - outer * 4, c + outer * 4, c + outer * 4), fill=255)
    d.ellipse((c - inner * 4, c - inner * 4, c + inner * 4, c + inner * 4), fill=0)
    return m.resize((size, size), Image.LANCZOS)


def _bevel(size: int, light_angle: float = 135.0) -> Image.Image:
    """A diagonal light: bright towards the upper left, dark towards the lower right ('L')."""
    img = Image.new("L", (size, size))
    px = img.load()
    ax, ay = math.cos(math.radians(light_angle)), -math.sin(math.radians(light_angle))
    for y in range(size):
        for x in range(size):
            nx, ny = (x - size / 2) / (size / 2), (y - size / 2) / (size / 2)
            v = 0.5 + 0.5 * (nx * ax + ny * ay)  # 1 on the lit side, 0 on the shaded side
            px[x, y] = int(max(0, min(1, v)) * 255)
    return img


def _ring(light: bool) -> Image.Image:
    """The gold ring of the minimap button: a bevelled band (lit upper left, shaded lower right), a dark
    fillet inside, a thin dark edge outside. Drawn at 4x and downsampled so the edges are smooth.
    'light' is the hover version."""
    size, k = 64, 4
    big = size * k
    c = big / 2
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    bev = _bevel(big)
    lo, hi = (112, 78, 18), (250, 226, 140)
    if light:
        lo, hi = (170, 128, 40), (255, 244, 196)
    band = tint(bev, lo, hi).convert("RGBA")
    grain = noise(big, big, 3, 91).point(lambda v: 235 + v * 20 // 255)
    band = ImageChops.multiply(band, Image.merge("RGBA", (grain, grain, grain, Image.new("L", (big, big), 255))))
    hole = Image.new("L", (big, big), 0)
    hd = ImageDraw.Draw(hole)
    hd.ellipse((c - 30.5 * k, c - 30.5 * k, c + 30.5 * k, c + 30.5 * k), fill=255)
    hd.ellipse((c - 22.5 * k, c - 22.5 * k, c + 22.5 * k, c + 22.5 * k), fill=0)
    band.putalpha(hole)
    img.alpha_composite(band)
    d = ImageDraw.Draw(img)
    # the crest of the band: a bright line on the lit side, a dark one on the shaded side
    d.arc((c - 26.5 * k, c - 26.5 * k, c + 26.5 * k, c + 26.5 * k), 190, 280, fill=hi + (200,), width=k)
    d.arc((c - 26.5 * k, c - 26.5 * k, c + 26.5 * k, c + 26.5 * k), 10, 100, fill=lo + (160,), width=k)
    # the inner lip: a dark fillet, then a thin lit line (the disc sits below it)
    d.ellipse((c - 22.5 * k, c - 22.5 * k, c + 22.5 * k, c + 22.5 * k), outline=(40, 22, 10, 255), width=k + 2)
    d.ellipse((c - 24 * k, c - 24 * k, c + 24 * k, c + 24 * k), outline=hi + (110,), width=k // 2)
    # the outer edge: dark, with a faint lit rim on top
    d.ellipse((c - 30.5 * k, c - 30.5 * k, c + 30.5 * k, c + 30.5 * k), outline=(36, 20, 8, 255), width=k + 2)
    d.arc((c - 29.5 * k, c - 29.5 * k, c + 29.5 * k, c + 29.5 * k), 200, 260, fill=hi + (120,), width=k // 2)
    return img.resize((size, size), Image.LANCZOS)


def ring() -> Image.Image:
    return _ring(False)


def ring_hl() -> Image.Image:
    return _ring(True)


def disc() -> Image.Image:
    """The dark leather inside the ring, with a vignette, for the icon to sit on."""
    size = 64
    base = tint(fractal(size, size, 123), LEATHER_DARK, LEATHER_LIGHT).convert("RGBA")
    # vignette: darker towards the edge
    vig = Image.new("L", (size, size), 0)
    px = vig.load()
    for y in range(size):
        for x in range(size):
            r = math.hypot(x - size / 2 + 0.5, y - size / 2 + 0.5) / (size / 2)
            px[x, y] = int(255 * max(0.18, 1 - r * r * r * 1.1))
    base = ImageChops.multiply(base, Image.merge("RGBA", (vig, vig, vig, Image.new("L", (size, size), 255))))
    base.putalpha(_radial(size, 0, 23.5))
    return base


def shadow() -> Image.Image:
    """A soft round shadow to lay under the button."""
    size = 64
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).ellipse((8, 10, size - 8, size - 4), fill=170)
    m = m.filter(ImageFilter.GaussianBlur(4))
    return Image.merge("RGBA", (Image.new("L", (size, size), 0),) * 3 + (m,))


def mask() -> Image.Image:
    size = 64
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(img).ellipse((9, 9, size - 10, size - 10), fill=(255, 255, 255, 255))
    return img


def icon_hub() -> Image.Image:
    """The one button for the whole family: a closed cream book on leather (64x64, square: it gets the
    round mask in-game)."""
    size, k = 64, 4
    big = size * k
    img = tint(fractal(big, big, 55), LEATHER_DARK, LEATHER_LIGHT).convert("RGBA")
    d = ImageDraw.Draw(img)
    cream, edge, pages = (242, 227, 192, 255), (58, 35, 19, 255), (214, 190, 142, 255)
    # page block (slightly offset: the pages peek out on the right), the cover on top
    d.rounded_rectangle((15 * k, 13 * k, 50 * k, 50 * k), radius=2 * k, fill=pages, outline=edge, width=k)
    d.rounded_rectangle((13 * k, 11 * k, 47 * k, 48 * k), radius=2 * k, fill=cream, outline=edge, width=k)
    d.rectangle((13 * k, 11 * k, 20 * k, 48 * k), fill=(84, 44, 26, 255), outline=edge, width=k)
    d.rectangle((24 * k, 19 * k, 43 * k, 25 * k), fill=CRIMSON + (255,))
    for y in (31, 36, 41):
        d.line((24 * k, y * k, 42 * k, y * k), fill=(120, 95, 60, 255), width=k)
    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, make in [
        ("page", page),
        ("leather", leather),
        ("spine", spine),
        ("ribbon", ribbon),
        ("bookmark", bookmark),
        ("title", title),
        ("seal", seal),
        ("check", check),
        ("pill", pill),
        ("ring", ring),
        ("ring_hl", ring_hl),
        ("disc", disc),
        ("shadow", shadow),
        ("mask", mask),
        ("icon_hub", icon_hub),
    ]:
        img = make().convert("RGBA")
        assert (
            img.width & (img.width - 1) == 0 and img.height & (img.height - 1) == 0
        ), name
        path = OUT / f"{name}.tga"
        img.save(path, compression=None)
        print(f"wrote {path.relative_to(ROOT)} ({img.width}x{img.height})")


if __name__ == "__main__":
    main()
