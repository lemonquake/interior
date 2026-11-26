"""Original spray-paint vandalism decals for the abandoned canal settlement (CC0, made here).

    python tools/assets/make_canal_graffiti.py

Writes RGBA PNGs to game/assets/outdoor/canal/tags/: random symbols, scribbled tags, bubble letters,
relocation-census house numbers and hand-brushed warning signs. Everything is procedural: strokes are
splatted as soft spray with overspray speckle and gravity drips, then eroded by noise so the paint
looks old and flaking. Deterministic (fixed seeds).
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "game", "assets", "outdoor", "canal", "tags")
FONTS = "C:/Windows/Fonts/"
SIZE = 512

PAINTS = [(150, 22, 18), (20, 20, 22), (225, 222, 210), (28, 70, 150), (35, 120, 60), (215, 110, 20), (170, 40, 120),
          (200, 180, 40)]


def noise(shape, scale, rng):
    small = rng.random((max(2, shape[0] // scale), max(2, shape[1] // scale)))
    img = Image.fromarray((small * 255).astype(np.uint8)).resize((shape[1], shape[0]), Image.BICUBIC)
    return np.asarray(img, dtype=np.float32) / 255.0


class Canvas:
    def __init__(self, w, h, seed):
        self.w, self.h = w, h
        self.rng = np.random.default_rng(seed)
        self.r = random.Random(seed)
        self.layers = []  # (alpha float array, colour)

    def new_layer(self, colour):
        a = np.zeros((self.h, self.w), np.float32)
        self.layers.append([a, colour])
        return a

    def spray(self, a, pts, width, drips=0.25):
        """Soft spray stroke along a polyline (pixel coords)."""
        img = Image.new("L", (self.w, self.h), 0)
        d = ImageDraw.Draw(img)
        d.line([tuple(p) for p in pts], fill=255, width=max(1, int(width)), joint="curve")
        for p in (pts[0], pts[-1]):
            d.ellipse([p[0] - width / 2, p[1] - width / 2, p[0] + width / 2, p[1] + width / 2], fill=255)
        core = np.asarray(img.filter(ImageFilter.GaussianBlur(width * .18)), np.float32) / 255.0
        halo = np.asarray(img.filter(ImageFilter.GaussianBlur(width * .9)), np.float32) / 255.0
        speck = (self.rng.random(core.shape) < halo * .35).astype(np.float32) * .55
        np.maximum(a, np.maximum(core, speck), out=a)
        # Gravity drips from paint-heavy points.
        for p in pts:
            if self.r.random() < drips:
                length = self.r.uniform(8, 70) * (width / 10)
                x, y = p[0] + self.r.uniform(-width * .3, width * .3), p[1] + width * .3
                dimg = Image.new("L", (self.w, self.h), 0)
                dd = ImageDraw.Draw(dimg)
                dw = max(1, width * self.r.uniform(.12, .25))
                dd.line([(x, y), (x + self.r.uniform(-1, 1), y + length)], fill=230, width=int(dw))
                dd.ellipse([x - dw * .8, y + length - dw * .6, x + dw * .8, y + length + dw], fill=230)
                np.maximum(a, np.asarray(dimg.filter(ImageFilter.GaussianBlur(.8)), np.float32) / 255.0, out=a)

    def fill_poly(self, a, pts, soft=2.0):
        img = Image.new("L", (self.w, self.h), 0)
        ImageDraw.Draw(img).polygon([tuple(p) for p in pts], fill=255)
        np.maximum(a, np.asarray(img.filter(ImageFilter.GaussianBlur(soft)), np.float32) / 255.0, out=a)

    def text(self, a, txt, font, size, xy, stroke=0, anchor="mm"):
        img = Image.new("L", (self.w, self.h), 0)
        f = ImageFont.truetype(FONTS + font, size)
        ImageDraw.Draw(img).text(xy, txt, font=f, fill=255, anchor=anchor, stroke_width=stroke, stroke_fill=255)
        np.maximum(a, np.asarray(img.filter(ImageFilter.GaussianBlur(1.2)), np.float32) / 255.0, out=a)

    def save(self, name, fade=(.55, .9)):
        rgb = np.zeros((self.h, self.w, 3), np.float32)
        alpha = np.zeros((self.h, self.w), np.float32)
        for a, colour in self.layers:
            c = np.array(colour, np.float32) / 255.0
            rgb = rgb * (1 - a[..., None]) + c * a[..., None]
            alpha = alpha + a * (1 - alpha)
        # Weathering: blotchy fade, fine flaking and a few scraped streaks.
        erosion = noise((self.h, self.w), 24, self.rng) * .6 + noise((self.h, self.w), 4, self.rng) * .4
        flakes = (self.rng.random((self.h, self.w)) > .08).astype(np.float32)
        strength = self.r.uniform(*fade)
        alpha *= np.clip((erosion - .18) * 2.2, 0, 1) * flakes * strength
        grime = .75 + .25 * noise((self.h, self.w), 16, self.rng)
        rgb *= grime[..., None]
        out = np.dstack([np.clip(rgb, 0, 1) * 255, np.clip(alpha, 0, 1) * 255]).astype(np.uint8)
        Image.fromarray(out, "RGBA").save(os.path.join(OUT, name + ".png"))


def jitter(pts, r, amount):
    return [(x + r.uniform(-amount, amount), y + r.uniform(-amount, amount)) for x, y in pts]


def circle(cx, cy, rad, n=40, start=0.0, sweep=math.tau):
    return [(cx + math.cos(start + sweep * i / n) * rad, cy + math.sin(start + sweep * i / n) * rad) for i in range(n + 1)]


def symbol(c, kind, cx, cy, s, colour, width):
    r = c.r
    a = c.new_layer(colour)
    if kind == "crossed_circle":
        c.spray(a, jitter(circle(cx, cy, s), r, s * .03), width)
        c.spray(a, [(cx - s * .8, cy - s * .8), (cx + s * .8, cy + s * .8)], width)
        c.spray(a, [(cx + s * .8, cy - s * .8), (cx - s * .8, cy + s * .8)], width)
    elif kind == "eye_triangle":
        tri = [(cx, cy - s), (cx + s * .95, cy + s * .7), (cx - s * .95, cy + s * .7), (cx, cy - s)]
        c.spray(a, jitter(tri, r, s * .04), width)
        eye = [(cx - s * .45, cy + s * .2), (cx, cy - s * .05), (cx + s * .45, cy + s * .2), (cx, cy + s * .42),
               (cx - s * .45, cy + s * .2)]
        c.spray(a, jitter(eye, r, s * .03), width * .7)
        c.spray(a, circle(cx, cy + s * .19, s * .08, 12), width * .9)
    elif kind == "arrow":
        ang = r.uniform(-.6, .6) + (math.pi if r.random() < .3 else 0)
        dx, dy = math.cos(ang) * s, math.sin(ang) * s
        tip = (cx + dx, cy + dy)
        c.spray(a, [(cx - dx, cy - dy), tip], width)
        for side in (-1, 1):
            back = (tip[0] - dx * .4 - dy * .3 * side, tip[1] - dy * .4 + dx * .3 * side)
            c.spray(a, [tip, back], width)
    elif kind == "crown":
        pts = [(cx - s, cy + s * .5), (cx - s, cy - s * .3), (cx - s * .5, cy + s * .1), (cx, cy - s * .6),
               (cx + s * .5, cy + s * .1), (cx + s, cy - s * .3), (cx + s, cy + s * .5), (cx - s, cy + s * .5)]
        c.spray(a, jitter(pts, r, s * .05), width)
    elif kind == "spiral":
        pts = [(cx + math.cos(t * .35) * t * s / 36, cy + math.sin(t * .35) * t * s / 36) for t in range(0, 38)]
        c.spray(a, pts, width)
    elif kind == "tally":
        for i in range(r.randint(3, 4)):
            for j in range(4):
                x = cx - s + i * s * .6 + j * s * .1
                c.spray(a, [(x, cy - s * .4), (x + r.uniform(-3, 3), cy + s * .4)], width * .6, .4)
            c.spray(a, [(cx - s * 1.05 + i * s * .6, cy + s * .3), (cx - s * .6 + i * s * .6, cy - s * .3)], width * .6)
    elif kind == "star":
        pts = []
        for i in range(11):
            rad = s if i % 2 == 0 else s * .42
            ang = -math.pi / 2 + i * math.pi / 5
            pts.append((cx + math.cos(ang) * rad, cy + math.sin(ang) * rad))
        c.spray(a, jitter(pts, r, s * .04), width)
    elif kind == "big_x":
        c.spray(a, [(cx - s, cy - s), (cx + s * .9, cy + s)], width * 1.4, .5)
        c.spray(a, [(cx + s, cy - s * .9), (cx - s * .9, cy + s)], width * 1.4, .5)
    elif kind == "scribble":
        x, y = cx - s * 1.3, cy
        pts = []
        for i in range(r.randint(28, 46)):
            x += r.uniform(2, s * .12)
            y = cy + math.sin(i * r.uniform(.6, 1.4)) * s * r.uniform(.2, .6)
            pts.append((x, y))
            if r.random() < .15:
                pts += circle(x, y - s * .15, s * .15, 8)
        c.spray(a, pts, width * .55, .15)
        c.spray(a, [(cx - s * 1.3, cy + s * .55), (cx + s * 1.2, cy + s * .45)], width * .45, .2)
    elif kind == "smiley":
        c.spray(a, jitter(circle(cx, cy, s), r, s * .03), width)
        for side in (-1, 1):
            c.spray(a, [(cx + side * s * .35, cy - s * .35), (cx + side * s * .3, cy - s * .05)], width)
        c.spray(a, [(cx - s * .5, cy + s * .45), (cx, cy + s * .3), (cx + s * .5, cy + s * .45)], width)
    elif kind == "hand":
        # Paint-dipped hand print: palm and four fingers.
        c.fill_poly(a, jitter(circle(cx, cy + s * .25, s * .45, 18), r, s * .04))
        for i in range(4):
            fx = cx - s * .36 + i * s * .24
            c.spray(a, [(fx, cy), (fx + r.uniform(-4, 4), cy - s * r.uniform(.6, .85))], s * .17, .6)
        c.spray(a, [(cx + s * .4, cy + s * .25), (cx + s * .8, cy - s * .05)], s * .17, .6)


def bubble(c, txt, cx, cy, size, fill, outline):
    a = c.new_layer(outline)
    c.text(a, txt, "seguibl.ttf", size, (cx, cy), stroke=int(size * .09))
    b = c.new_layer(fill)
    c.text(b, txt, "seguibl.ttf", size, (cx, cy))
    for x in range(0, c.w, 3):
        if c.r.random() < .08:
            c.spray(b, [(x, cy + size * .2), (x, cy + size * .2 + c.r.uniform(10, 40))], 3, 0)


def letters(r, n):
    return "".join(r.choice("ABDEGJKMNORSTVYZ") for _ in range(n))


def main():
    os.makedirs(OUT, exist_ok=True)
    kinds = ["crossed_circle", "eye_triangle", "arrow", "crown", "spiral", "tally", "star", "big_x", "scribble",
             "smiley", "hand"]
    # 16 random symbol clusters: 1-4 overlapping symbols in different paints, some over older buffed paint.
    for i in range(16):
        c = Canvas(SIZE, SIZE, 900 + i)
        r = c.r
        if r.random() < .4:  # an older layer painted over with grey "buff" rectangles
            old = c.new_layer(r.choice(PAINTS))
            symbol(c, r.choice(kinds), 256, 256, 150, r.choice(PAINTS), 22)
            buff = c.new_layer((r.randint(70, 110),) * 3)
            c.fill_poly(buff, jitter([(60, 120), (450, 100), (470, 380), (80, 400)], r, 30), 5)
        for k in range(r.randint(1, 4)):
            s = r.uniform(55, 150)
            symbol(c, r.choice(kinds), r.uniform(s, SIZE - s), r.uniform(s, SIZE - s), s, r.choice(PAINTS),
                   r.uniform(9, 22))
        c.save("tag_%02d" % i)
    # Bubble-letter throw-ups and plain scribbled names (random letters, no real crews).
    for i in range(6):
        c = Canvas(SIZE * 2, SIZE, 1300 + i)
        r = c.r
        fill, outline = r.sample(PAINTS, 2)
        bubble(c, letters(r, r.randint(3, 5)), SIZE, SIZE // 2, r.randint(170, 230), fill, outline)
        if r.random() < .6:
            symbol(c, "scribble", r.uniform(250, 770), r.uniform(330, 440), 120, r.choice(PAINTS), 14)
        c.save("throw_%02d" % i)
    # Relocation census numbers sprayed on houses before the settlement was cleared.
    for i in range(8):
        c = Canvas(SIZE, SIZE // 2, 1500 + i)
        r = c.r
        a = c.new_layer((165, 25, 20) if r.random() < .7 else (25, 25, 25))
        code = r.choice(["SP", "BLK", "D", "LOT", "R"]) + "-" + str(r.randint(4, 260))
        c.text(a, code, "impact.ttf", r.randint(110, 150), (SIZE // 2, SIZE // 4), stroke=1)
        if r.random() < .6:
            c.spray(a, jitter([(SIZE // 2 + x * 1.9, SIZE // 4 + y) for x, y in circle(0, 0, 112, 30)], r, 6), 12)
        if r.random() < .5:
            c.spray(a, [(70, 40), (440, 220)], 16, .5)
        c.save("census_%02d" % i)
    # Hand-brushed warning signs (Filipino and English as they really appear on walls).
    signs = ["BAWAL UMIHI DITO", "BAWAL MAGTAPON\nNG BASURA DITO", "BAWAL PUMASOK", "BAWAL TUMAMBAY",
             "KEEP OUT", "PRIVATE PROPERTY\nBAWAL PUMASOK", "DELIKADO", "WALANG\nTAPUNAN DITO"]
    for i, sign in enumerate(signs):
        c = Canvas(SIZE * 2, SIZE, 1700 + i)
        r = c.r
        a = c.new_layer(r.choice([(20, 20, 20), (150, 25, 20), (230, 228, 215)]))
        img = Image.new("L", (c.w, c.h), 0)
        f = ImageFont.truetype(FONTS + r.choice(["Inkfree.ttf", "segoeprb.ttf", "comicbd.ttf"]), 84)
        ImageDraw.Draw(img).multiline_text((c.w // 2, c.h // 2), sign, font=f, fill=255, anchor="mm", align="center",
                                           spacing=14, stroke_width=3, stroke_fill=255)
        img = img.rotate(r.uniform(-4, 4), resample=Image.BICUBIC)
        np.maximum(a, np.asarray(img.filter(ImageFilter.GaussianBlur(1.0)), np.float32) / 255.0, out=a)
        for x in range(60, c.w - 60, 7):  # brush drips
            if r.random() < .06:
                c.spray(a, [(x, c.h * .5 + r.uniform(-60, 60)), (x, c.h * .5 + r.uniform(80, 200))], 4, 0)
        c.save("sign_%02d" % i, (.7, .95))
    print("wrote", len(os.listdir(OUT)), "decals to", OUT)


if __name__ == "__main__":
    main()
