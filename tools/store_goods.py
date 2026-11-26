"""0.42: the stock of Olivar Family Mart, as one texture atlas.

Real brands a Davao convenience store carries (Coca-Cola and Pepsi lines, Red Bull, Pringles, Lay's, Century Tuna,
555, Argentina, Nissin, Oreo, Tide...), each drawn as its label at the shape's true proportions, then squeezed into
a 512 px cell of a 4096 px atlas (8 x 8). The goods are script-built meshes (scripts/coop/store_goods.gd) whose UVs
point into these cells, so every product in the store is one draw call per material.

Writes game/assets/coop/goods/atlas.png, goods.json (name -> cell, shape, size, swatches), hole.png and crack.png.
Run: python -I tools/store_goods.py
"""
import json
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game" / "assets" / "coop" / "goods"
CELL = 512
GRID = 8
FONTS = Path("C:/Windows/Fonts")
rng = random.Random(42)


def font(name, size):
    return ImageFont.truetype(str(FONTS / name), int(size))


def text_fit(d, xy, text, face, max_w, max_h, fill, stroke=0, stroke_fill=None, anchor="mm", spacing=0):
    size = max_h
    while size > 6:
        f = font(face, size)
        box = d.textbbox((0, 0), text, font=f, stroke_width=int(stroke * size / 100), anchor="lt")
        if box[2] - box[0] <= max_w and box[3] - box[1] <= max_h:
            break
        size -= 2
    f = font(face, size)
    d.text(xy, text, font=f, fill=fill, anchor=anchor, stroke_width=int(stroke * size / 100), stroke_fill=stroke_fill)
    return size


def vgrad(img, box, top, bottom):
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        t = (y - y0) / max(1, y1 - y0 - 1)
        d.line([(x0, y), (x1, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)))


def hgrad(img, box, left, right):
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = box
    for x in range(x0, x1):
        t = (x - x0) / max(1, x1 - x0 - 1)
        d.line([(x, y0), (x, y1)], fill=tuple(int(a + (b - a) * t) for a, b in zip(left, right)))


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def barcode(d, x, y, w, h):
    d.rectangle([x - 4, y - 4, x + w + 4, y + h + 14], fill=(250, 250, 248))
    cx = x
    while cx < x + w:
        bw = rng.choice([1, 1, 2, 3])
        d.rectangle([cx, y, cx + bw - 1, y + h], fill=(15, 15, 15))
        cx += bw + rng.choice([1, 2, 2, 3])
    d.text((x + w / 2, y + h + 7), "4 800888 %06d" % rng.randint(0, 999999), font=font("arial.ttf", 9), fill=(15, 15, 15), anchor="mm")


def fine_print(d, x, y, w, lines, color, size=10):
    f = font("arial.ttf", size)
    for i in range(lines):
        lw = w * rng.uniform(.55, 1.0)
        d.rectangle([x, y + i * (size + 3), x + lw, y + i * (size + 3) + size * .45], fill=color)


def wave(d, w, y, amp, thick, color, phase=0.0, periods=1.0):
    pts = []
    for i in range(0, w + 8, 8):
        pts.append((i, y + amp * math.sin(phase + i / w * math.tau * periods)))
    for i in range(w + 8, -8, -8):
        pts.append((i, y + thick + amp * .7 * math.sin(phase + .6 + i / w * math.tau * periods)))
    d.polygon(pts, fill=color)


def bubbles(d, w, h, color, n=40, rmax=9):
    for _ in range(n):
        x, y, r = rng.uniform(0, w), rng.uniform(0, h), rng.uniform(2, rmax)
        d.ellipse([x - r, y - r, x + r, y + r], outline=color, width=2)


# ------------------------------------------------------------------ label designs
# Each takes (img, d, w, h, x0) where x0..x0+w is one face/repeat panel.


def coke(img, d, w, h, x0, zero=False):
    bg = (18, 18, 18) if zero else (226, 22, 30)
    d.rectangle([x0, 0, x0 + w, h], fill=bg)
    wave_d = ImageDraw.Draw(img)
    for k, (c, t) in enumerate([((255, 255, 255), 16), ((226, 22, 30) if zero else (255, 255, 255), 0)]):
        pass
    pts = [(x0 + i, h * .74 + 30 * math.sin(i / w * math.tau + 1.2)) for i in range(0, w + 1, 6)]
    pts += [(x0 + i, h * .80 + 18 * math.sin(i / w * math.tau + 1.9)) for i in range(w, -1, -6)]
    wave_d.polygon(pts, fill=(255, 255, 255) if not zero else (226, 22, 30))
    text_fit(d, (x0 + w / 2, h * .42), "Coca-Cola", "BRUSHSCI.TTF", w * .9, h * .38, (226, 22, 30) if zero else (255, 255, 255))
    if zero:
        text_fit(d, (x0 + w / 2, h * .63), "ZERO SUGAR", "ariblk.ttf", w * .62, h * .09, (255, 255, 255))
    else:
        text_fit(d, (x0 + w / 2, h * .63), "ORIGINAL TASTE", "arialbd.ttf", w * .5, h * .06, (255, 255, 255))
    d.text((x0 + w * .5, h * .92), "330 mL", font=font("arialbd.ttf", h * .045), fill=(255, 255, 255), anchor="mm")


def pepsi(img, d, w, h, x0):
    vgrad(img, (x0, 0, x0 + w, h), (10, 40, 140), (0, 20, 80))
    cx, cy, r = x0 + w / 2, h * .38, min(w, h) * .2
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 255))
    d.pieslice([cx - r, cy - r, cx + r, cy + r], 180, 360, fill=(228, 30, 40))
    d.pieslice([cx - r * .98, cy - r * .98, cx + r * .98, cy + r * .98], 15, 165, fill=(20, 60, 170))
    pts = [(cx - r + i, cy - 4 + 12 * math.sin(i / (2 * r) * math.pi * 1.6)) for i in range(0, int(2 * r) + 1, 4)]
    d.line(pts, fill=(255, 255, 255), width=int(r * .2))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(255, 255, 255), width=4)
    text_fit(d, (x0 + w / 2, h * .74), "pepsi", "ariblk.ttf", w * .8, h * .2, (255, 255, 255))
    d.text((x0 + w * .5, h * .92), "330 mL", font=font("arialbd.ttf", h * .045), fill=(200, 210, 255), anchor="mm")


def simple_can(img, d, w, h, x0, bg, bg2, title, face, color, sub="", subcolor=None, stroke=0, sfill=None, deco=None):
    vgrad(img, (x0, 0, x0 + w, h), rgb(bg), rgb(bg2))
    if deco:
        deco(img, d, w, h, x0)
    text_fit(d, (x0 + w / 2, h * .45), title, face, w * .86, h * .3, color, stroke, sfill)
    if sub:
        text_fit(d, (x0 + w / 2, h * .7), sub, "arialbd.ttf", w * .7, h * .075, subcolor or color)


def sprite_deco(img, d, w, h, x0):
    for k in range(5):
        y = h * (.15 + k * .19)
        d.line([(x0, y), (x0 + w, y - h * .2)], fill=(80, 190, 90), width=10)
    d.ellipse([x0 + w * .1, h * .62, x0 + w * .9, h * .8], fill=(250, 220, 30))
    bubbles(d, w, h, (190, 240, 200), 15, 7)


def dew_deco(img, d, w, h, x0):
    d.polygon([(x0, h * .2), (x0 + w, h * .05), (x0 + w, h * .22), (x0, h * .36)], fill=(190, 25, 30))
    d.polygon([(x0, h * .74), (x0 + w, h * .6), (x0 + w, h * .66), (x0, h * .8)], fill=(150, 220, 40))


def seven_up(img, d, w, h, x0):
    vgrad(img, (x0, 0, x0 + w, h), (20, 150, 70), (5, 90, 40))
    bubbles(d, w, h, (120, 220, 150), 20, 8)
    r = min(w, h) * .2
    cx, cy = x0 + w / 2, h * .45
    d.rounded_rectangle([cx - r * 1.3, cy - r, cx + r * 1.3, cy + r], radius=r * .4, fill=(255, 255, 255))
    text_fit(d, (cx, cy), "7UP", "ariblk.ttf", r * 2.2, r * 1.4, (20, 140, 60))
    d.ellipse([cx + r * .1, cy - r * .2, cx + r * .5, cy + r * .2], fill=(230, 30, 35))
    text_fit(d, (cx, h * .75), "LEMON LIME", "arialbd.ttf", w * .6, h * .07, (255, 255, 255))


def royal_deco(img, d, w, h, x0):
    for k in range(6):
        d.ellipse([x0 + w * (.1 + k * .15), h * .75, x0 + w * (.2 + k * .15), h * .85], fill=(255, 150, 20))


def redbull(img, d, w, h, x0):
    hw = w // 2
    for y in range(0, h, 20):
        for x in range(0, hw, 20):
            col = (210, 214, 222) if (x // 20 + y // 20) % 2 else (180, 186, 196)
            d.rectangle([x0 + x, y, x0 + x + 19, y + 19], fill=col)
            col = (20, 40, 110) if (x // 20 + y // 20) % 2 else (35, 60, 140)
            d.rectangle([x0 + hw + x, y, x0 + hw + x + 19, y + 19], fill=col)
    cx, cy, r = x0 + w / 2, h * .38, min(w, h) * .17
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(250, 200, 10))
    for s in (-1, 1):
        d.polygon([(cx + s * r * .3, cy + r * .1), (cx + s * r * 1.6, cy - r * .2), (cx + s * r * 1.7, cy + r * .5), (cx + s * r * .4, cy + r * .6)], fill=(200, 20, 40))
    text_fit(d, (cx, h * .66), "Red Bull", "ariblk.ttf", w * .8, h * .14, (200, 20, 40), 6, (250, 250, 250))
    text_fit(d, (cx, h * .8), "ENERGY DRINK", "arialbd.ttf", w * .6, h * .06, (20, 30, 80), 4, (230, 230, 230))


def monster(img, d, w, h, x0):
    d.rectangle([x0, 0, x0 + w, h], fill=(14, 14, 14))
    for k in range(3):
        x = x0 + w * (.32 + k * .14)
        pts = [(x, h * .08)]
        for j in range(1, 9):
            pts.append((x + (12 if j % 2 else -10), h * .08 + j * h * .065))
        pts += [(p[0] + 26, p[1] + 6) for p in reversed(pts)]
        d.polygon(pts, fill=(120, 230, 30))
    text_fit(d, (x0 + w / 2, h * .76), "MONSTER", "impact.ttf", w * .8, h * .12, (240, 240, 240))
    text_fit(d, (x0 + w / 2, h * .88), "ENERGY", "arialbd.ttf", w * .4, h * .05, (120, 230, 30))


def sanmig(img, d, w, h, x0):
    vgrad(img, (x0, 0, x0 + w, h), (245, 228, 170), (215, 180, 100))
    d.rectangle([x0, h * .1, x0 + w, h * .14], fill=(120, 70, 30))
    d.rectangle([x0, h * .86, x0 + w, h * .9], fill=(120, 70, 30))
    cx = x0 + w / 2
    d.ellipse([cx - 40, h * .18, cx + 40, h * .3], outline=(170, 30, 30), width=5)
    text_fit(d, (cx, h * .45), "San Miguel", "BRUSHSCI.TTF", w * .85, h * .2, (90, 45, 20))
    text_fit(d, (cx, h * .64), "PALE PILSEN", "timesbd.ttf", w * .7, h * .1, (170, 30, 30))
    text_fit(d, (cx, h * .77), "BEER  •  5% ALC/VOL", "arialbd.ttf", w * .5, h * .045, (90, 45, 20))


def redhorse(img, d, w, h, x0):
    vgrad(img, (x0, 0, x0 + w, h), (200, 25, 30), (130, 10, 15))
    cx = x0 + w / 2
    d.ellipse([cx - 55, h * .12, cx + 55, h * .34], fill=(250, 245, 230))
    d.polygon([(cx - 30, h * .3), (cx - 10, h * .15), (cx + 25, h * .17), (cx + 35, h * .25), (cx + 10, h * .24), (cx + 5, h * .32)], fill=(170, 20, 25))
    text_fit(d, (cx, h * .5), "RED HORSE", "impact.ttf", w * .85, h * .17, (250, 245, 230))
    text_fit(d, (cx, h * .67), "EXTRA STRONG BEER", "arialbd.ttf", w * .7, h * .06, (250, 220, 120))


def heineken(img, d, w, h, x0):
    vgrad(img, (x0, 0, x0 + w, h), (20, 120, 50), (5, 70, 25))
    cx = x0 + w / 2
    d.ellipse([cx - w * .4, h * .36, cx + w * .4, h * .62], fill=(250, 250, 245), outline=(200, 30, 40), width=6)
    text_fit(d, (cx, h * .49), "Heineken", "arialbd.ttf", w * .66, h * .12, (20, 100, 45))
    r = 26
    star = [(cx + r * math.cos(math.pi / 2 + k * math.pi * .8) * 1, h * .24 - r * math.sin(math.pi / 2 + k * math.pi * .8)) for k in range(5)]
    d.polygon(star, fill=(220, 30, 40))
    text_fit(d, (cx, h * .75), "LAGER BEER", "arialbd.ttf", w * .5, h * .05, (250, 250, 245))


def bottle_label(fn, liquid, band=(.3, .78)):
    """A PET bottle body: liquid above and below, the label band between."""
    def draw(img, d, w, h, x0):
        d.rectangle([x0, 0, x0 + w, h], fill=liquid)
        for k in range(4):
            d.rectangle([x0, h * (.04 + k * .06), x0 + w, h * (.04 + k * .06) + 4], fill=tuple(min(255, c + 30) for c in liquid))
        y0, y1 = int(h * band[0]), int(h * band[1])
        band_img = Image.new("RGB", (w, y1 - y0))
        bd = ImageDraw.Draw(band_img)
        fn(band_img, bd, w, y1 - y0, 0)
        img.paste(band_img, (x0, y0))
    return draw


def gatorade(img, d, w, h, x0):
    d.rectangle([x0, 0, x0 + w, h], fill=(15, 15, 15))
    cx = x0 + w / 2
    d.polygon([(cx - 30, h * .1), (cx + 22, h * .1), (cx + 2, h * .4), (cx + 30, h * .4), (cx - 26, h * .9), (cx - 8, h * .5), (cx - 34, h * .5)], fill=(250, 120, 20))
    text_fit(d, (cx, h * .5), "GATORADE", "impact.ttf", w * .8, h * .26, (255, 255, 255))
    text_fit(d, (cx, h * .8), "BLUE BOLT", "arialbd.ttf", w * .5, h * .12, (60, 140, 255))


def pocari(img, d, w, h, x0):
    d.rectangle([x0, 0, x0 + w, h], fill=(250, 250, 252))
    d.polygon([(x0, h * .55), (x0 + w, h * .3), (x0 + w, h), (x0, h)], fill=(20, 90, 200))
    text_fit(d, (x0 + w / 2, h * .32), "POCARI SWEAT", "ariblk.ttf", w * .8, h * .2, (20, 90, 200))
    text_fit(d, (x0 + w / 2, h * .78), "ION SUPPLY DRINK", "arialbd.ttf", w * .5, h * .1, (255, 255, 255))


def c2(img, d, w, h, x0):
    hgrad(img, (x0, 0, x0 + w, h), (150, 200, 40), (60, 140, 30))
    text_fit(d, (x0 + w * .5, h * .42), "C2", "ariblk.ttf", w * .5, h * .55, (255, 255, 255), 6, (30, 90, 20))
    text_fit(d, (x0 + w * .5, h * .82), "GREEN TEA  •  APPLE", "arialbd.ttf", w * .7, h * .12, (255, 255, 255))


def wilkins(img, d, w, h, x0):
    vgrad(img, (x0, 0, x0 + w, h), (30, 110, 210), (15, 60, 150))
    wave(d, w, h * .7, 10, 18, (140, 200, 255))
    text_fit(d, (x0 + w / 2, h * .38), "Wilkins", "georgiaz.ttf", w * .7, h * .38, (255, 255, 255))
    text_fit(d, (x0 + w / 2, h * .9), "DISTILLED DRINKING WATER", "arialbd.ttf", w * .7, h * .09, (255, 255, 255))


def minute_maid(img, d, w, h, x0):
    vgrad(img, (x0, 0, x0 + w, h), (250, 150, 20), (230, 100, 10))
    for k in range(3):
        cx = x0 + w * (.2 + k * .3)
        d.ellipse([cx - 30, h * .62, cx + 30, h * .95], fill=(255, 190, 40), outline=(220, 110, 10), width=3)
    text_fit(d, (x0 + w / 2, h * .25), "Minute Maid", "georgiaz.ttf", w * .8, h * .26, (20, 110, 40), 4, (255, 255, 255))
    text_fit(d, (x0 + w / 2, h * .5), "PULPY ORANGE", "ariblk.ttf", w * .6, h * .14, (255, 255, 255))


def cobra(img, d, w, h, x0):
    d.rectangle([x0, 0, x0 + w, h], fill=(20, 20, 20))
    d.polygon([(x0, h * .2), (x0 + w, h * .05), (x0 + w, h * .15), (x0, h * .3)], fill=(250, 210, 20))
    text_fit(d, (x0 + w / 2, h * .55), "COBRA", "impact.ttf", w * .8, h * .4, (250, 210, 20))
    text_fit(d, (x0 + w / 2, h * .85), "ENERGY DRINK", "arialbd.ttf", w * .5, h * .1, (255, 255, 255))


def pringles(color, dark, flavour):
    def draw(img, d, w, h, x0):
        vgrad(img, (x0, 0, x0 + w, h), rgb(color), rgb(dark))
        cx, cy = x0 + w / 2, h * .32
        d.ellipse([cx - 70, cy - 85, cx + 70, cy + 85], fill=(250, 245, 235), outline=(30, 30, 30), width=4)
        d.ellipse([cx - 42, cy - 60, cx - 12, cy - 30], fill=(30, 30, 30))
        d.ellipse([cx + 12, cy - 60, cx + 42, cy - 30], fill=(30, 30, 30))
        d.chord([cx - 70, cy - 105, cx + 70, cy - 45], 180, 360, fill=(110, 60, 20))
        d.chord([cx - 50, cy - 5, cx + 50, cy + 40], 180, 360, fill=(90, 50, 20))
        d.line([(cx - 20, cy + 50), (cx + 20, cy + 50)], fill=(30, 30, 30), width=6)
        d.ellipse([cx - 16, cy - 25, cx + 16, cy - 2], fill=(30, 30, 30))
        text_fit(d, (cx, h * .64), "Pringles", "ariblk.ttf", w * .86, h * .13, (255, 255, 255), 5, (30, 30, 30))
        d.rectangle([x0, h * .74, x0 + w, h * .85], fill=(250, 245, 235))
        text_fit(d, (cx, h * .795), flavour, "arialbd.ttf", w * .8, h * .07, rgb(dark))
        d.text((cx, h * .93), "107 g", font=font("arialbd.ttf", 22), fill=(255, 255, 255), anchor="mm")
    return draw


def bag(bg, bg2, title, face, color, sub, subcolor, stroke=6, sfill=(30, 30, 30), deco=None, chips=None):
    def draw(img, d, w, h, x0):
        vgrad(img, (x0, 0, x0 + w, h), rgb(bg), rgb(bg2))
        # crimped ends
        for y0 in (0, h - 26):
            for x in range(0, w, 10):
                d.line([(x0 + x, y0), (x0 + x, y0 + 26)], fill=tuple(int(c * .75) for c in rgb(bg)), width=3)
        if deco:
            deco(img, d, w, h, x0)
        if chips:
            for k in range(7):
                cx, cy = x0 + w * rng.uniform(.15, .85), h * rng.uniform(.66, .86)
                r = rng.uniform(30, 50)
                if chips == "tri":
                    d.polygon([(cx, cy - r), (cx + r, cy + r * .7), (cx - r, cy + r * .7)], fill=(240, 150, 30), outline=(190, 90, 20))
                elif chips == "hex":
                    d.regular_polygon((cx, cy, r), 6, rotation=rng.uniform(0, 60), fill=(245, 205, 90), outline=(200, 150, 40))
                elif chips == "curl":
                    d.ellipse([cx - r, cy - r * .5, cx + r, cy + r * .5], fill=(250, 140, 30), outline=(200, 90, 20), width=3)
                else:
                    d.ellipse([cx - r, cy - r * .7, cx + r, cy + r * .7], fill=(250, 215, 110), outline=(215, 170, 60), width=3)
        text_fit(d, (x0 + w / 2, h * .32), title, face, w * .82, h * .17, color, stroke, sfill)
        text_fit(d, (x0 + w / 2, h * .52), sub, "ariblk.ttf", w * .7, h * .065, subcolor)
        d.text((x0 + w * .82, h * .92), "NET WT 60g", font=font("arialbd.ttf", 16), fill=(255, 255, 255), anchor="mm")
    return draw


def lays_deco(img, d, w, h, x0):
    cx, cy = x0 + w / 2, h * .32
    d.ellipse([cx - 120, cy - 120, cx + 120, cy + 120], fill=(250, 200, 20))
    d.rounded_rectangle([cx - w * .44, cy - 52, cx + w * .44, cy + 52], radius=50, fill=(220, 20, 30))


def doritos_deco(img, d, w, h, x0):
    d.polygon([(x0, h * .2), (x0 + w, h * .12), (x0 + w, h * .42), (x0, h * .46)], fill=(15, 15, 15))
    d.polygon([(x0 + w * .1, h * .44), (x0 + w * .9, h * .4), (x0 + w * .9, h * .43), (x0 + w * .1, h * .47)], fill=(250, 140, 20))


def piattos_deco(img, d, w, h, x0):
    d.ellipse([x0 + w * .08, h * .2, x0 + w * .92, h * .44], fill=(220, 30, 30), outline=(255, 230, 100), width=6)


def oishi_deco(img, d, w, h, x0):
    d.ellipse([x0 + w * .3, h * .1, x0 + w * .7, h * .24], fill=(220, 30, 30), outline=(255, 255, 255), width=5)
    d.text((x0 + w / 2, h * .17), "Oishi", font=font("arialbd.ttf", 38), fill=(255, 255, 255), anchor="mm")
    for k in range(4):
        cx, cy = x0 + w * (.2 + k * .2), h * .78
        d.arc([cx - 40, cy - 30, cx + 40, cy + 40], 200, 520, fill=(250, 120, 90), width=16)


def ruffles_deco(img, d, w, h, x0):
    d.polygon([(x0 + w * .05, h * .24), (x0 + w * .95, h * .2), (x0 + w * .92, h * .42), (x0 + w * .08, h * .44)], fill=(220, 30, 40))


def mms_deco(img, d, w, h, x0):
    for k in range(9):
        cx, cy = x0 + w * rng.uniform(.12, .88), h * rng.uniform(.62, .88)
        col = rng.choice([(220, 30, 30), (30, 90, 220), (40, 170, 60), (250, 200, 20), (240, 120, 20), (120, 70, 30)])
        d.ellipse([cx - 30, cy - 24, cx + 30, cy + 24], fill=col)
        d.text((cx, cy), "m", font=font("arialbd.ttf", 24), fill=(255, 255, 255), anchor="mm")


def lucky_deco(img, d, w, h, x0):
    d.rectangle([x0, h * .58, x0 + w, h * .9], fill=(120, 60, 20))
    for k in range(14):
        y = h * (.6 + k * .02)
        d.arc([x0 + 20, y - 20, x0 + w - 20, y + 30], 0, 180, fill=(240, 180, 80), width=5)


def short_can(bg, title, face, color, sub, subcolor, band=None, top=None, stroke=0, sfill=None):
    def draw(img, d, w, h, x0):
        d.rectangle([x0, 0, x0 + w, h], fill=rgb(bg))
        if top:
            d.rectangle([x0, 0, x0 + w, h * .45], fill=rgb(top))
        if band:
            d.rectangle([x0, h * .7, x0 + w, h * .88], fill=rgb(band))
        text_fit(d, (x0 + w / 2, h * .32), title, face, w * .85, h * .36, color, stroke, sfill)
        text_fit(d, (x0 + w / 2, h * .79), sub, "arialbd.ttf", w * .85, h * .12, subcolor)
        d.rectangle([x0, 0, x0 + w, 6], fill=(170, 170, 170))
        d.rectangle([x0, h - 6, x0 + w, h], fill=(170, 170, 170))
    return draw


def spam(img, d, w, h, x0):
    d.rectangle([x0, 0, x0 + w, h], fill=(20, 50, 130))
    d.rectangle([x0, h * .62, x0 + w, h], fill=(250, 200, 20))
    for k in range(3):
        d.rounded_rectangle([x0 + w * (.18 + k * .22), h * .66, x0 + w * (.36 + k * .22), h * .92], radius=10, fill=(230, 140, 130), outline=(190, 90, 80), width=3)
    text_fit(d, (x0 + w / 2, h * .3), "SPAM", "ariblk.ttf", w * .8, h * .34, (250, 200, 20), 5, (200, 30, 30))
    text_fit(d, (x0 + w / 2, h * .54), "CLASSIC", "arialbd.ttf", w * .4, h * .07, (255, 255, 255))


def box_front(bg, bg2, title, face, color, sub, subcolor, stroke=0, sfill=None, deco=None, title_y=.32):
    def draw(img, d, w, h, x0):
        vgrad(img, (x0, 0, x0 + w, h), rgb(bg), rgb(bg2))
        if deco:
            deco(img, d, w, h, x0)
        text_fit(d, (x0 + w / 2, h * title_y), title, face, w * .84, h * .22, color, stroke, sfill)
        if sub:
            text_fit(d, (x0 + w / 2, h * (title_y + .2)), sub, "ariblk.ttf", w * .76, h * .08, subcolor)
        fine_print(d, x0 + w * .06, h * .86, w * .4, 3, tuple(int(c * .7) for c in rgb(bg2)), 9)
    return draw


def oreo_deco(img, d, w, h, x0):
    for k in range(3):
        cx, cy = x0 + w * (.25 + k * .25), h * .72
        d.ellipse([cx - 55, cy - 55, cx + 55, cy + 55], fill=(35, 25, 25))
        d.ellipse([cx - 45, cy - 45, cx + 45, cy + 45], outline=(60, 45, 45), width=4)
    d.rectangle([x0 + w * .19, h * .7, x0 + w * .81, h * .74], fill=(245, 245, 240))


def flakes_deco(img, d, w, h, x0):
    d.chord([x0 + w * .15, h * .5, x0 + w * .85, h * .95], 0, 180, fill=(250, 250, 250))
    for k in range(18):
        cx, cy = x0 + w * rng.uniform(.25, .75), h * rng.uniform(.6, .72)
        d.ellipse([cx - 22, cy - 12, cx + 22, cy + 12], fill=(235, 170, 60), outline=(190, 120, 40))


def tide_deco(img, d, w, h, x0):
    cx, cy = x0 + w / 2, h * .42
    for k, col in enumerate([(250, 120, 20), (250, 200, 20), (250, 120, 20), (250, 200, 20)]):
        r = 190 - k * 42
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col)


def nescafe_deco(img, d, w, h, x0):
    cx, cy = x0 + w / 2, h * .72
    d.rounded_rectangle([cx - 70, cy - 40, cx + 60, cy + 70], radius=20, fill=(250, 250, 250))
    d.ellipse([cx - 66, cy - 52, cx + 56, cy - 22], fill=(110, 60, 30))
    d.arc([cx + 40, cy - 20, cx + 100, cy + 40], 270, 90, fill=(250, 250, 250), width=12)


def safeguard_deco(img, d, w, h, x0):
    d.rectangle([x0, h * .6, x0 + w, h], fill=(20, 80, 170))
    d.ellipse([x0 + w * .3, h * .66, x0 + w * .7, h * .9], fill=(250, 250, 250))


def marlboro(img, d, w, h, x0):
    d.rectangle([x0, 0, x0 + w, h], fill=(250, 250, 248))
    d.polygon([(x0, 0), (x0 + w, 0), (x0 + w, h * .3), (x0 + w / 2, h * .16), (x0, h * .3)], fill=(205, 25, 35))
    text_fit(d, (x0 + w / 2, h * .45), "Marlboro", "timesbd.ttf", w * .8, h * .1, (20, 20, 20))
    d.rectangle([x0 + w * .06, h * .62, x0 + w * .94, h * .94], fill=(20, 20, 20))
    text_fit(d, (x0 + w / 2, h * .78), "SMOKING KILLS", "ariblk.ttf", w * .8, h * .1, (255, 255, 255))


def bar(bg, title, face, color, stroke=0, sfill=None, oval=None):
    def draw(img, d, w, h, x0):
        vgrad(img, (x0, 0, x0 + w, h), rgb(bg), tuple(int(c * .75) for c in rgb(bg)))
        if oval:
            d.ellipse([x0 + w * .12, h * .2, x0 + w * .88, h * .8], fill=rgb(oval))
        text_fit(d, (x0 + w / 2, h * .5), title, face, w * .74, h * .5, color, stroke, sfill)
    return draw


def cup(band, title, sub):
    def draw(img, d, w, h, x0):
        d.rectangle([x0, 0, x0 + w, h], fill=(250, 250, 246))
        d.rectangle([x0, h * .3, x0 + w, h * .62], fill=rgb(band))
        text_fit(d, (x0 + w / 2, h * .46), title, "ariblk.ttf", w * .84, h * .2, (255, 255, 255))
        text_fit(d, (x0 + w / 2, h * .14), "NISSIN", "arialbd.ttf", w * .3, h * .1, rgb(band))
        text_fit(d, (x0 + w / 2, h * .78), sub, "arialbd.ttf", w * .6, h * .1, rgb(band))
    return draw


def milo(img, d, w, h, x0):
    vgrad(img, (x0, 0, x0 + w, h), (30, 140, 60), (10, 90, 40))
    text_fit(d, (x0 + w / 2, h * .38), "MILO", "ariblk.ttf", w * .7, h * .36, (255, 255, 255), 6, (10, 70, 30))
    text_fit(d, (x0 + w / 2, h * .66), "ACTIGEN-E", "arialbd.ttf", w * .5, h * .09, (250, 210, 30))
    d.ellipse([x0 + w * .7, h * .7, x0 + w * .9, h * .95], fill=(110, 60, 30))


def coke_case(img, d, w, h, x0):
    d.rectangle([x0, 0, x0 + w, h], fill=(226, 22, 30))
    pts = [(x0 + i, h * .68 + 24 * math.sin(i / w * math.tau)) for i in range(0, w + 1, 6)]
    pts += [(x0 + i, h * .76 + 14 * math.sin(i / w * math.tau + .7)) for i in range(w, -1, -6)]
    d.polygon(pts, fill=(255, 255, 255))
    text_fit(d, (x0 + w / 2, h * .38), "Coca-Cola", "BRUSHSCI.TTF", w * .8, h * .42, (255, 255, 255))
    text_fit(d, (x0 + w / 2, h * .88), "24 x 330 mL CANS", "arialbd.ttf", w * .5, h * .09, (255, 255, 255))


def hershey(img, d, w, h, x0):
    d.rectangle([x0, 0, x0 + w, h], fill=(75, 40, 25))
    text_fit(d, (x0 + w / 2, h * .48), "HERSHEY'S", "arialbd.ttf", w * .8, h * .42, (205, 205, 210))
    d.text((x0 + w / 2, h * .85), "MILK CHOCOLATE", font=font("arialbd.ttf", 18), fill=(205, 205, 210), anchor="mm")


def century(img, d, w, h, x0):
    d.rectangle([x0, 0, x0 + w, h], fill=(250, 250, 250))
    d.rectangle([x0, 0, x0 + w, h * .48], fill=(20, 60, 150))
    text_fit(d, (x0 + w / 2, h * .25), "CENTURY", "ariblk.ttf", w * .8, h * .3, (255, 255, 255), 5, (200, 30, 30))
    text_fit(d, (x0 + w / 2, h * .62), "TUNA FLAKES IN OIL", "arialbd.ttf", w * .85, h * .14, (200, 30, 30))
    d.ellipse([x0 + w * .4, h * .76, x0 + w * .6, h * .95], fill=(110, 140, 190))


# name, shape, design, size (m: radius/height or w/h/d), swatches, material, design aspect (w:h of one repeat), repeats
CATALOGUE = [
    ("coke_can", "can", lambda *a: coke(*a), [.033, .122], ["silver"], "metal", .85, 2),
    ("coke_zero_can", "can", lambda *a: coke(*a, zero=True), [.033, .122], ["silver"], "metal", .85, 2),
    ("pepsi_can", "can", pepsi, [.033, .122], ["silver"], "metal", .85, 2),
    ("sprite_can", "can", lambda img, d, w, h, x0: simple_can(img, d, w, h, x0, "#1f9a45", "#0c5f2a", "Sprite", "ariblk.ttf", (255, 255, 255), "LEMON-LIME", (250, 220, 30), 5, (20, 60, 140), sprite_deco), [.033, .122], ["silver"], "metal", .85, 2),
    ("mtn_dew_can", "can", lambda img, d, w, h, x0: simple_can(img, d, w, h, x0, "#1d5e22", "#0b2f10", "MTN DEW", "impact.ttf", (255, 255, 255), "DO THE DEW", (150, 220, 40), 0, None, dew_deco), [.033, .122], ["silver"], "metal", .85, 2),
    ("sevenup_can", "can", seven_up, [.033, .122], ["silver"], "metal", .85, 2),
    ("royal_can", "can", lambda img, d, w, h, x0: simple_can(img, d, w, h, x0, "#f7941d", "#e05a10", "Royal", "georgiaz.ttf", (255, 255, 255), "TRU-ORANGE", (255, 240, 200), 6, (180, 60, 10), royal_deco), [.033, .122], ["silver"], "metal", .85, 2),
    ("redbull_can", "can", redbull, [.027, .135], ["silver"], "metal", .63, 2),
    ("monster_can", "can", monster, [.033, .168], ["black"], "metal", .62, 2),
    ("sanmig_can", "can", sanmig, [.033, .122], ["gold"], "metal", .85, 2),
    ("redhorse_can", "can", redhorse, [.033, .122], ["silver"], "metal", .85, 2),
    ("heineken_can", "can", heineken, [.033, .122], ["silver"], "metal", .85, 2),
    ("coke_bottle", "bottle", bottle_label(lambda *a: coke(*a), (45, 20, 12)), [.046, .33], ["red", "cola"], "plastic", .9, 1),
    ("sprite_bottle", "bottle", bottle_label(lambda img, d, w, h, x0: simple_can(img, d, w, h, x0, "#1f9a45", "#0c5f2a", "Sprite", "ariblk.ttf", (255, 255, 255), "LEMON-LIME", (250, 220, 30), 5, (20, 60, 140), sprite_deco), (150, 205, 160)), [.046, .33], ["green", "lime"], "plastic", .9, 1),
    ("pepsi_bottle", "bottle", bottle_label(pepsi, (45, 20, 12)), [.046, .33], ["blue", "cola"], "plastic", .9, 1),
    ("gatorade_bottle", "bottle", bottle_label(gatorade, (40, 110, 230), (.25, .72)), [.036, .21], ["orange", "bluedrink"], "plastic", .9, 1),
    ("pocari_bottle", "bottle", bottle_label(pocari, (220, 230, 240), (.25, .8)), [.033, .2], ["blue", "water"], "plastic", .9, 1),
    ("c2_bottle", "bottle", bottle_label(c2, (190, 170, 60), (.25, .78)), [.033, .2], ["green", "tea"], "plastic", .9, 1),
    ("wilkins_bottle", "bottle", bottle_label(wilkins, (205, 225, 240), (.3, .72)), [.033, .22], ["blue", "water"], "plastic", .9, 1),
    ("minute_maid_bottle", "bottle", bottle_label(minute_maid, (250, 160, 30), (.25, .8)), [.034, .21], ["orange", "juice"], "plastic", .9, 1),
    ("cobra_bottle", "bottle", bottle_label(cobra, (240, 200, 30), (.28, .76)), [.03, .18], ["black", "juice"], "plastic", .9, 1),
    ("pringles_original", "tube", pringles("#d71f26", "#8d0f14", "ORIGINAL"), [.038, .23], ["silver", "red"], "paper", 1.0, 1),
    ("pringles_sour_cream", "tube", pringles("#2f9a45", "#14602a", "SOUR CREAM & ONION"), [.038, .23], ["silver", "green"], "paper", 1.0, 1),
    ("pringles_cheese", "tube", pringles("#f2a31c", "#b5650c", "CHEDDAR CHEESE"), [.038, .23], ["silver", "orange"], "paper", 1.0, 1),
    ("lays_classic", "bag", bag("#f7c51c", "#e8a20c", "Lay's", "ariblk.ttf", (255, 255, 255), "CLASSIC", (210, 20, 30), 0, None, lays_deco, "round"), [.2, .28, .07], [], "plastic", .72, 1),
    ("doritos_nacho", "bag", bag("#d3202a", "#8f0f14", "DORITOS", "impact.ttf", (255, 255, 255), "NACHO CHEESE", (250, 200, 30), 6, (15, 15, 15), doritos_deco, "tri"), [.2, .28, .07], [], "plastic", .72, 1),
    ("cheetos", "bag", bag("#f47b20", "#d95b0c", "Cheetos", "comicbd.ttf", (255, 255, 255), "CRUNCHY", (20, 90, 30), 8, (180, 40, 10), None, "curl"), [.2, .28, .07], [], "plastic", .72, 1),
    ("piattos", "bag", bag("#3e9a3a", "#1f6a20", "Piattos", "ariblk.ttf", (255, 255, 255), "CHEESE", (255, 230, 90), 0, None, piattos_deco, "hex"), [.18, .25, .06], [], "plastic", .72, 1),
    ("nova", "bag", bag("#5b2d8e", "#33175a", "Nova", "ariblk.ttf", (250, 210, 40), "COUNTRY CHEDDAR", (255, 255, 255), 6, (90, 20, 20), None, "round"), [.18, .25, .06], [], "plastic", .72, 1),
    ("oishi_prawn", "bag", bag("#f05a28", "#c43414", "PRAWN", "ariblk.ttf", (255, 255, 255), "CRACKERS", (255, 230, 120), 6, (150, 20, 10), oishi_deco), [.18, .26, .06], [], "plastic", .72, 1),
    ("ruffles", "bag", bag("#1c4fa0", "#0f2f6a", "Ruffles", "ariblk.ttf", (255, 255, 255), "ORIGINAL", (255, 255, 255), 0, None, ruffles_deco, "round"), [.2, .28, .07], [], "plastic", .72, 1),
    ("lucky_me_canton", "bag", bag("#e8381e", "#a51e0e", "Lucky Me!", "ariblk.ttf", (250, 220, 30), "PANCIT CANTON", (255, 255, 255), 6, (120, 10, 10), lucky_deco), [.13, .16, .025], [], "plastic", .82, 1),
    ("mms_peanut", "bag", bag("#f6c21a", "#e0a10c", "m&m's", "arialbd.ttf", (255, 255, 255), "PEANUT", (120, 70, 30), 8, (120, 70, 30), mms_deco), [.11, .15, .03], [], "plastic", .74, 1),
    ("spam", "box", spam, [.098, .058, .052], [], "metal", 1.7, 1),
    ("century_tuna", "can", century, [.042, .06], ["silver"], "metal", 2.2, 2),
    ("argentina_corned_beef", "can", short_can("#f4f1ea", "Argentina", "georgiaz.ttf", (200, 25, 30), "CORNED BEEF", (255, 255, 255), "#c8191e"), [.04, .085], ["silver"], "metal", 1.5, 2),
    ("555_sardines", "can", short_can("#f6c418", "555", "ariblk.ttf", (210, 25, 30), "SARDINES in Tomato Sauce", (255, 255, 255), "#d2191e", None, 6, (255, 255, 255)), [.037, .1], ["silver"], "metal", 1.15, 2),
    ("ligo_sardines", "can", short_can("#d2191e", "LIGO", "ariblk.ttf", (250, 210, 30), "SARDINES  •  RED", (210, 25, 30), "#f6d418", None, 6, (90, 10, 10)), [.037, .1], ["silver"], "metal", 1.15, 2),
    ("libbys_vienna", "can", short_can("#f8f8f5", "Libby's", "georgiaz.ttf", (200, 25, 30), "VIENNA SAUSAGE", (255, 255, 255), "#1d3f8f"), [.033, .06], ["silver"], "metal", 1.7, 2),
    ("del_monte_fruit", "can", short_can("#f8f8f2", "DEL MONTE", "ariblk.ttf", (20, 110, 50), "FRUIT COCKTAIL", (255, 255, 255), "#1e7a3a", None, 4, (250, 210, 40)), [.042, .115], ["silver"], "metal", 1.15, 2),
    ("campbells_tomato", "can", short_can("#f8f8f5", "Campbell's", "BRUSHSCI.TTF", (255, 255, 255), "TOMATO SOUP", (200, 25, 30), None, "#c8191e"), [.034, .1], ["silver"], "metal", 1.05, 2),
    ("cup_noodles", "cup", cup("#d3202a", "CUP NOODLES", "ORIGINAL"), [.047, .036, .105], ["white"], "paper", 2.5, 2),
    ("cup_noodles_seafood", "cup", cup("#1f5fb5", "CUP NOODLES", "SEAFOOD"), [.047, .036, .105], ["white"], "paper", 2.5, 2),
    ("oreo", "box", box_front("#1f4ea8", "#0f2f72", "OREO", "ariblk.ttf", (255, 255, 255), "CHOCOLATE SANDWICH COOKIE", (255, 255, 255), 5, (10, 20, 60), oreo_deco), [.2, .065, .05], [], "paper", 3.0, 1),
    ("corn_flakes", "box", box_front("#f6f6f0", "#e7e4d8", "Kellogg's", "BRUSHSCI.TTF", (200, 20, 30), "CORN FLAKES", (30, 130, 50), 0, None, flakes_deco, .2), [.19, .28, .07], [], "paper", .68, 1),
    ("milo_tin", "can", milo, [.062, .15], ["green"], "metal", 2.6, 1),
    ("nescafe_3in1", "box", box_front("#c8191e", "#8c0f12", "NESCAFÉ", "ariblk.ttf", (255, 255, 255), "3in1 ORIGINAL", (255, 230, 180), 0, None, nescafe_deco), [.15, .19, .08], [], "paper", .8, 1),
    ("tide_powder", "box", box_front("#f6f6f0", "#e6e4dc", "Tide", "ariblk.ttf", (20, 60, 160), "", (0, 0, 0), 6, (255, 255, 255), tide_deco, .42), [.18, .24, .07], [], "paper", .75, 1),
    ("colgate", "box", box_front("#d81f26", "#a1141a", "Colgate", "ariblk.ttf", (255, 255, 255), "MAXIMUM CAVITY PROTECTION", (255, 255, 255), 0, None, None, .42), [.2, .045, .045], [], "paper", 4.4, 1),
    ("safeguard", "box", box_front("#f8f8f8", "#e8e8ea", "Safeguard", "ariblk.ttf", (20, 80, 170), "PURE WHITE", (20, 80, 170), 0, None, safeguard_deco), [.1, .065, .04], [], "paper", 1.5, 1),
    ("kitkat", "box", bar("#d3202a", "KitKat", "ariblk.ttf", (210, 30, 40), 0, None, "#ffffff"), [.15, .045, .015], [], "paper", 3.3, 1),
    ("snickers", "box", bar("#5a3420", "SNICKERS", "ariblk.ttf", (30, 80, 170), 7, (255, 255, 255)), [.15, .04, .02], [], "paper", 3.7, 1),
    ("hersheys", "box", hershey, [.15, .06, .01], [], "paper", 2.5, 1),
    ("marlboro", "box", marlboro, [.056, .088, .022], [], "paper", .64, 1),
    ("coke_case", "box", coke_case, [.4, .25, .27], [], "paper", 1.6, 1),
    ("skyflakes", "box", box_front("#f6f6f8", "#d8e3f3", "SkyFlakes", "ariblk.ttf", (20, 70, 170), "CRACKERS", (200, 25, 30), 0, None, None), [.22, .07, .055], [], "paper", 3.1, 1),
]

# 16 flat swatches in the last cell, for lids, caps, shoulders.
SWATCHES = ["silver", "gold", "white", "red", "green", "blue", "black", "orange", "cola", "lime", "water", "tea",
            "juice", "bluedrink", "cardboard", "grey"]
SWATCH_COLOURS = {"silver": (196, 198, 202), "gold": (205, 170, 90), "white": (240, 240, 236), "red": (205, 25, 35),
                  "green": (40, 140, 60), "blue": (25, 75, 170), "black": (25, 25, 25), "orange": (240, 120, 20),
                  "cola": (40, 18, 10), "lime": (170, 215, 175), "water": (200, 222, 236), "tea": (185, 165, 60),
                  "juice": (245, 160, 30), "bluedrink": (40, 110, 230), "cardboard": (160, 125, 80), "grey": (120, 120, 120)}


def grime(cell):
    """A little wear: the store has been shut, dusty and fought in."""
    over = Image.new("L", cell.size, 0)
    od = ImageDraw.Draw(over)
    for _ in range(26):
        x, y, r = rng.uniform(0, CELL), rng.uniform(0, CELL), rng.uniform(4, 40)
        od.ellipse([x - r, y - r, x + r, y + r], fill=rng.randint(10, 40))
    for _ in range(6):
        x, y = rng.uniform(0, CELL), rng.uniform(0, CELL)
        od.line([(x, y), (x + rng.uniform(-90, 90), y + rng.uniform(-90, 90))], fill=rng.randint(30, 70), width=rng.randint(1, 3))
    over = over.filter(ImageFilter.GaussianBlur(3))
    dark = Image.new("RGB", cell.size, (40, 32, 24))
    return Image.composite(dark, cell, over)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    atlas = Image.new("RGB", (CELL * GRID, CELL * GRID), (128, 128, 128))
    manifest = {"grid": GRID, "goods": {}, "swatches": {}}
    for i, (name, shape, draw, size, swatches, mat, aspect, repeats) in enumerate(CATALOGUE):
        h = 512
        w = int(round(h * aspect))
        canvas = Image.new("RGB", (w * repeats, h), (255, 255, 255))
        d = ImageDraw.Draw(canvas)
        for k in range(repeats):
            draw(canvas, d, w, h, k * w)
        if shape in ("box", "bag", "tube", "cup", "can"):
            barcode(d, int(w * .07), int(h * .8), 70, 30)
        cell = grime(canvas.resize((CELL, CELL), Image.LANCZOS))
        col, row = i % GRID, i // GRID
        atlas.paste(cell, (col * CELL, row * CELL))
        manifest["goods"][name] = {"cell": i, "shape": shape, "size": size, "swatches": swatches, "material": mat, "repeats": repeats}
    sw = len(CATALOGUE)
    assert sw < GRID * GRID
    sw_img = Image.new("RGB", (CELL, CELL))
    sd = ImageDraw.Draw(sw_img)
    for k, key in enumerate(SWATCHES):
        x, y = (k % 4) * 128, (k // 4) * 128
        sd.rectangle([x, y, x + 127, y + 127], fill=SWATCH_COLOURS[key])
        manifest["swatches"][key] = k
    atlas.paste(sw_img, ((sw % GRID) * CELL, (sw // GRID) * CELL))
    manifest["swatch_cell"] = sw
    atlas.save(OUT / "atlas.png", optimize=True)
    (OUT / "goods.json").write_text(json.dumps(manifest, indent=1))
    # A bullet hole and a cracked-glass star, for walls, fridges and the glass front.
    hole = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hole)
    for r, a in [(30, 60), (20, 120), (12, 210), (7, 255)]:
        hd.ellipse([64 - r, 64 - r, 64 + r, 64 + r], fill=(30, 26, 22, a))
    for _ in range(9):
        ang = rng.uniform(0, math.tau)
        hd.line([(64, 64), (64 + math.cos(ang) * rng.uniform(22, 40), 64 + math.sin(ang) * rng.uniform(22, 40))], fill=(60, 55, 50, 150), width=2)
    hole.filter(ImageFilter.GaussianBlur(.6)).save(OUT / "hole.png")
    crack = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    cd = ImageDraw.Draw(crack)
    for _ in range(16):
        ang = rng.uniform(0, math.tau)
        x, y = 256, 256
        for step in range(8):
            ang += rng.uniform(-.35, .35)
            nx, ny = x + math.cos(ang) * rng.uniform(16, 34), y + math.sin(ang) * rng.uniform(16, 34)
            cd.line([(x, y), (nx, ny)], fill=(235, 245, 245, 200), width=2)
            x, y = nx, ny
    for r in (40, 80, 130):
        pts = []
        for k in range(24):
            ang = k / 24 * math.tau
            rr = r * rng.uniform(.8, 1.15)
            pts.append((256 + math.cos(ang) * rr, 256 + math.sin(ang) * rr))
        for k in range(24):
            if rng.random() < .55:
                cd.line([pts[k], pts[(k + 1) % 24]], fill=(235, 245, 245, 150), width=1)
    cd.ellipse([242, 242, 270, 270], fill=(20, 20, 20, 230))
    crack.save(OUT / "crack.png")
    print(f"{len(CATALOGUE)} goods, atlas {atlas.size}, swatch cell {sw}")


if __name__ == "__main__":
    main()
