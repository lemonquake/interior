"""Interior 0.31: what the menus are stained with.

    python tools/ui_assets.py [preview]

Writes game/assets/ui/:
  menu_blood.png   1600 x 900, the whole screen: two spatters (upper right, lower right), a long drag along the
                   bottom and a short one down the right, a few runs from the top edge. Dark and thin: it is drawn
                   at about half strength over the menu's street. The left third, where the title and the menu are,
                   is left clean.
  panel_drip.png   768 x 128, tiles sideways: a wet line with runs hanging from it, for the top edge of a window.
  smear.png        384 x 64: one wipe of a thumb, for the menu entry under the pointer.
All of it is drawn here (noise and strokes), nothing photographed. `preview` also writes work/v31/ui/*.png on grey.
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "game", "assets", "ui")
SS = 2


def blur(a, r):
    im = Image.fromarray(np.clip(a * 255.0, 0, 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(r))
    return np.asarray(im, np.float32) / 255.0


def fbm(h, w, rng, scales=(64, 32, 16, 8, 4), weights=(1.0, 0.6, 0.4, 0.25, 0.15)):
    out = np.zeros((h, w), np.float32)
    for s, wt in zip(scales, weights):
        small = rng.random((h // s + 3, w // s + 3)).astype(np.float32)
        im = Image.fromarray((small * 255).astype(np.uint8), "L").resize((w + 2 * s, h + 2 * s), Image.BICUBIC)
        out += np.asarray(im, np.float32)[s:s + h, s:s + w] / 255.0 * wt
    out -= out.min()
    return out / (out.max() + 1e-6)


class Canvas:
    def __init__(self, w, h, wrap=False):
        self.w, self.h, self.wrap = w * SS, h * SS, wrap
        self.im = Image.new("L", (self.w, self.h), 0)
        self.d = ImageDraw.Draw(self.im)

    def dot(self, x, y, r, v):
        for ox in ((0, -self.w, self.w) if self.wrap else (0,)):
            self.d.ellipse((x + ox - r, y - r, x + ox + r, y + r), fill=int(max(0, min(255, v * 255))))

    def stroke(self, x0, y0, x1, y1, width, v):
        for ox in ((0, -self.w, self.w) if self.wrap else (0,)):
            self.d.line((x0 + ox, y0, x1 + ox, y1), fill=int(max(0, min(255, v * 255))), width=max(1, int(round(width))))
        self.dot(x0, y0, width * 0.5, v)
        self.dot(x1, y1, width * 0.5, v)

    def array(self):
        return np.asarray(self.im, np.float32) / 255.0


def spatter(c, rng, cx, cy, radius, toward=None, drops=220):
    """A burst from (cx, cy): a broken core, and drops thrown out of it, longer and thinner the further they went."""
    cx, cy, radius = cx * SS, cy * SS, radius * SS
    for _ in range(26):
        a = rng.uniform(0, math.tau)
        r = radius * 0.3 * rng.random() ** 0.7
        c.dot(cx + math.cos(a) * r, cy + math.sin(a) * r, radius * rng.uniform(0.05, 0.16), rng.uniform(0.55, 1.0))
    for _ in range(drops):
        a = rng.uniform(0, math.tau) if toward is None else rng.normal(toward, 0.75)
        far = radius * (0.35 + rng.lognormal(-0.5, 0.75))
        size = radius * rng.uniform(0.006, 0.04) / (0.6 + far / radius)
        x, y = cx + math.cos(a) * far, cy + math.sin(a) * far
        tail = size * rng.uniform(1.0, 2.0 + 5.0 * far / radius)
        c.stroke(x, y, x + math.cos(a) * tail, y + math.sin(a) * tail, size * 2.0, rng.uniform(0.45, 1.0))
    for _ in range(drops * 3):
        a = rng.uniform(0, math.tau) if toward is None else rng.normal(toward, 1.0)
        far = radius * (0.2 + rng.lognormal(0.0, 0.7))
        c.dot(cx + math.cos(a) * far, cy + math.sin(a) * far, rng.uniform(0.5, 1.6) * SS * 0.6, rng.uniform(0.25, 0.8))


def drag(c, rng, points, width, bristles=18, heavy=0.95):
    """Something wet pulled along a line: many thin parallel tracks that each break up and give out in their own time."""
    pts = [(x * SS, y * SS) for x, y in points]
    width *= SS
    steps = 260
    path = []
    for i in range(steps + 1):
        t = i / steps
        k = t * (len(pts) - 1)
        j = min(int(k), len(pts) - 2)
        f = k - j
        f = f * f * (3 - 2 * f)
        path.append((pts[j][0] + (pts[j + 1][0] - pts[j][0]) * f, pts[j][1] + (pts[j + 1][1] - pts[j][1]) * f))
    for b in range(bristles):
        off = (b / (bristles - 1) - 0.5) * width + rng.normal(0, width * 0.02)
        gate = np.convolve(rng.random(steps + 40), np.ones(18) / 18.0, "same")[20:20 + steps + 1]
        gate = (gate - gate.min()) / (gate.max() - gate.min() + 1e-6)
        ends = rng.uniform(0.45, 1.0)
        thick = rng.uniform(1.2, 4.2) * SS * (1.6 if abs(off) < width * 0.2 else 1.0)
        for i in range(steps):
            t = i / steps
            if t > ends:
                break
            (x0, y0), (x1, y1) = path[i], path[i + 1]
            dx, dy = x1 - x0, y1 - y0
            n = math.hypot(dx, dy) + 1e-6
            nx, ny = -dy / n, dx / n
            v = heavy * (1.0 - t / ends) ** 0.8 * (0.25 + 0.75 * gate[i]) * (1.0 if gate[i] > 0.32 else 0.0)
            if v <= 0.02:
                continue
            c.stroke(x0 + nx * off, y0 + ny * off, x1 + nx * off, y1 + ny * off, thick * (0.6 + 0.4 * gate[i]), v)
    # Where it began: it lay there a moment first.
    for _ in range(14):
        c.dot(path[0][0] + rng.normal(0, width * 0.3), path[0][1] + rng.normal(0, width * 0.3), width * rng.uniform(0.08, 0.26), rng.uniform(0.6, 1.0))


def run(c, rng, x, y, length, width):
    """One run downward from (x, y): it wanders a hair, thins, and ends in a bead."""
    x, y, length, width = x * SS, y * SS, length * SS, width * SS
    steps = max(8, int(length / (2 * SS)))
    px = x
    for i in range(steps):
        t = i / steps
        nx = px + rng.normal(0, 0.18 * SS)
        w = width * (1.0 - 0.55 * t)
        c.stroke(px, y + length * t, nx, y + length * (t + 1.0 / steps), w, 0.95 - 0.25 * t)
        px = nx
    c.dot(px, y + length, width * 0.72, 1.0)


def colour(density, rng, strength=1.0):
    """Density -> RGBA: thin is red, thick is nearly black, the rim of a dried patch darker than its middle."""
    h, w = density.shape
    d = np.clip(density, 0, 1)
    grain = fbm(h, w, rng, scales=(48, 12, 4), weights=(1.0, 0.5, 0.3))
    d = np.clip(d * (0.72 + 0.5 * grain), 0, 1)
    rim = np.clip(d - blur(d, 3.0 * SS), 0, 1) * 2.2
    thin = np.array([0.40, 0.020, 0.022], np.float32)
    thick = np.array([0.105, 0.004, 0.008], np.float32)
    k = np.clip(d * 1.25 + rim * 0.6, 0, 1)[..., None]
    rgb = thin * (1.0 - k) + thick * k
    alpha = np.clip(d * 1.35, 0, 1) ** 0.85 * strength
    out = np.concatenate([np.broadcast_to(rgb, (h, w, 3)), alpha[..., None]], axis=2)
    im = Image.fromarray(np.clip(out * 255.0, 0, 255).astype(np.uint8), "RGBA")
    return im.resize((w // SS, h // SS), Image.LANCZOS)


def menu_blood(rng):
    W, H = 1600, 900
    c = Canvas(W, H)
    spatter(c, rng, 1430, 120, 210, toward=2.5, drops=260)
    spatter(c, rng, 1290, 705, 120, toward=-0.5, drops=150)
    spatter(c, rng, 930, 60, 70, toward=1.4, drops=70)
    drag(c, rng, [(520, 842), (760, 858), (1040, 832), (1330, 846), (1575, 790)], 74, bristles=22)
    drag(c, rng, [(1486, 250), (1462, 380), (1478, 520), (1440, 640)], 46, bristles=14, heavy=0.8)
    for x, length, width in ((905, 150, 5.0), (938, 70, 3.5), (1210, 210, 5.5), (1236, 95, 3.5), (1392, 300, 6.0), (1418, 130, 4.0), (1530, 180, 4.5)):
        run(c, rng, x, -4, length * rng.uniform(0.8, 1.15), width)
    a = c.array()
    a = np.maximum(a, blur(a, 1.2 * SS) * 0.9)
    # The left of the screen stays clean: the title and the menu are there.
    xs = np.linspace(0, 1, a.shape[1])[None, :]
    a *= np.clip((xs - 0.30) / 0.12, 0, 1)
    return colour(a, rng, 0.92)


def panel_drip(rng):
    W, H = 768, 128
    c = Canvas(W, H, wrap=True)
    x = 0.0
    while x < W:
        c.stroke(x * SS, 2 * SS, (x + 14) * SS, 2 * SS, rng.uniform(3.0, 7.5) * SS, rng.uniform(0.7, 1.0))
        x += 9
    x = rng.uniform(8, 30)
    while x < W - 6:
        long = rng.random() < 0.3
        run(c, rng, x, 2, rng.uniform(46, 112) if long else rng.uniform(8, 34), rng.uniform(3.0, 5.0) if long else rng.uniform(2.0, 3.4))
        x += rng.uniform(16, 70)
    a = c.array()
    a = np.maximum(a, blur(a, 0.8 * SS) * 0.85)
    return colour(a, rng, 0.95)


def smear(rng):
    W, H = 384, 64
    c = Canvas(W, H)
    drag(c, rng, [(10, 34), (130, 30), (260, 34), (376, 31)], 44, bristles=20, heavy=0.9)
    a = c.array()
    a = np.maximum(a, blur(a, 1.5 * SS))
    ys = np.linspace(-1, 1, a.shape[0])[:, None]
    a *= np.clip(1.15 - ys * ys * 1.1, 0, 1)
    return colour(a, rng, 0.9)


def main():
    os.makedirs(OUT, exist_ok=True)
    rng = np.random.default_rng(31)
    made = {"menu_blood": menu_blood(rng), "panel_drip": panel_drip(rng), "smear": smear(rng)}
    for name, im in made.items():
        im.save(os.path.join(OUT, name + ".png"))
        print("ui", name, im.size)
    if "preview" in sys.argv:
        work = os.path.join(ROOT, "work", "v31", "ui")
        os.makedirs(work, exist_ok=True)
        for name, im in made.items():
            back = Image.new("RGBA", im.size, (38, 44, 54, 255))
            back.alpha_composite(im)
            back.convert("RGB").save(os.path.join(work, name + ".jpg"), quality=88)


if __name__ == "__main__":
    main()
