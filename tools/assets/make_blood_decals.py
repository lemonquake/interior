"""Decal textures for the Nichols basement trail (0.22): blood a few days old, dragged from the front door to the cellar.

    python tools/assets/make_blood_decals.py

Writes game/assets/nichols/blood/<name>_albedo.png (RGBA), <name>_normal.png and <name>_orm.png (occlusion, roughness,
metal) for Godot Decals (u along the decal's X, v along its Z):
- drag_a, drag_b, drag_c   a carcass dragged along the floor: a smear with fur streaks, ragged edges, gaps;
- pool                     where something lay and bled: a dark clot with a dried, cracked rim;
- drops                    drips and spatter;
- scrape                   pale scuffs where a heavy shelf was dragged through the dust;
The owner asked for trails and splatter only (no lettering, no hand prints).
Dried blood is maroon to brown and matt; where it lay thick it is still almost black and tacky (lower roughness).
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, 'game', 'assets', 'nichols', 'blood')
RNG = np.random.default_rng(1906)


def noise(h, w, scale, octaves=4, seed=None):
    """Fractal value noise in [0, 1]."""
    rng = np.random.default_rng(seed) if seed is not None else RNG
    out = np.zeros((h, w))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        gh, gw = max(2, int(h / scale * 2 ** o) + 2), max(2, int(w / scale * 2 ** o) + 2)
        grid = rng.random((gh, gw))
        layer = ndimage.zoom(grid, (h / (gh - 1), w / (gw - 1)), order=3)[:h, :w]
        out += layer * amp
        total += amp
        amp *= .5
    out /= total
    return np.clip((out - out.min()) / (np.ptp(out) + 1e-9), 0, 1)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def save(name, thick, rough_dry=.78, rough_wet=.32, tint=None, darken=0.0):
    """thick: 0..1 thickness of blood. Writes albedo (RGBA), normal and ORM."""
    h, w = thick.shape
    alpha = smoothstep(.04, .3, thick)
    # Coffee-ring rim: blood dries darker at the edge of a stain.
    edge = np.clip(np.abs(ndimage.gaussian_filter(thick, 2.0) - ndimage.gaussian_filter(thick, 7.0)) * 5, 0, 1)
    mottling = noise(h, w, 24, 4)
    dried = np.array([.24, .075, .05])      # thin, dried: brown
    deep = np.array([.15, .018, .014])      # thick, a few days old: near-black maroon
    fresh = np.array([.3, .025, .02])       # where it stayed wet longest
    t = smoothstep(.15, .85, thick)[..., None]
    col = dried * (1 - t) + deep * t
    col = col * (1 - .35 * edge[..., None]) + (fresh - col) * (.25 * (mottling[..., None] > .7) * t)
    col *= (.82 + .3 * mottling[..., None])
    if tint is not None:
        col = col * 0 + np.array(tint) * (.8 + .3 * mottling[..., None])
    col *= (1 - darken)
    rgba = np.dstack([np.clip(col, 0, 1), alpha])
    Image.fromarray((rgba * 255).astype(np.uint8), 'RGBA').save(os.path.join(OUT, name + '_albedo.png'))
    # Normal from a height of the thickness (crusted, a little raised).
    height = ndimage.gaussian_filter(thick, 1.2) * 3.0
    gy, gx = np.gradient(height)
    n = np.dstack([-gx, gy, np.ones_like(gx) * .35])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    Image.fromarray(((n * .5 + .5) * 255).astype(np.uint8), 'RGB').save(os.path.join(OUT, name + '_normal.png'))
    rough = rough_dry * (1 - t[..., 0]) + rough_wet * t[..., 0]
    rough = np.clip(rough + (mottling - .5) * .12, 0, 1)
    orm = np.dstack([np.ones_like(rough), rough, np.zeros_like(rough)])
    Image.fromarray((orm * 255).astype(np.uint8), 'RGB').save(os.path.join(OUT, name + '_orm.png'))
    print('wrote', name, thick.shape)


def noise2(h, w, sy, sx, octaves=3, seed=0):
    """Value noise stretched differently along y and x (sy, sx: feature size in pixels)."""
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        gh, gw = max(2, int(h / sy * 2 ** o) + 2), max(2, int(w / sx * 2 ** o) + 2)
        layer = ndimage.zoom(rng.random((gh, gw)), (h / (gh - 1), w / (gw - 1)), order=3)[:h, :w]
        out += layer * amp
        total += amp
        amp *= .5
    out /= total
    return np.clip((out - out.min()) / (np.ptp(out) + 1e-9), 0, 1)


def drag(name, seed, w=1024, h=384, gap=.25, width=.62):
    rng = np.random.default_rng(seed)
    y = np.linspace(-1, 1, h)[:, None]
    x = np.linspace(0, 1, w)[None, :]
    # Width of the smear along its length, its centre line wandering.
    profile = width * (.6 + .4 * noise(1, w, 160, 3, seed)[0])[None, :]
    centre = (noise(1, w, 320, 2, seed + 1)[0] - .5)[None, :] * .3
    d = np.abs(y - centre) / profile
    body = 1 - smoothstep(.4, 1.0, d + (noise2(h, w, 20, 40, 4, seed + 2) - .5) * .7)
    # Fur and hair: fine streaks along the drag that come and go.
    streaks = smoothstep(.32, .78, noise2(h, w, 3.5, 160, 3, seed + 3))
    streaks = streaks * (.5 + .5 * smoothstep(.3, .7, noise2(h, w, 40, 90, 2, seed + 4)))
    # Where the body lifted off the floor: patchy gaps, longer than they are wide.
    lift = smoothstep(gap, gap + .4, noise2(h, w, 70, 130, 3, seed + 5))
    thick = body * (.3 + .7 * streaks) * (.12 + .88 * lift)
    # A thick core and clotted spots where it stopped for a while.
    stops = smoothstep(.62, .9, noise2(h, w, 60, 70, 2, seed + 6))
    thick = np.clip(thick + body * stops * .55 * np.clip(1 - d, 0, 1), 0, 1)
    # Feather the two ends so decals overlap without seams.
    thick *= smoothstep(0, .1, x) * smoothstep(0, .1, 1 - x)
    # Drops either side.
    yy, xx = np.ogrid[:h, :w]
    drops = np.zeros((h, w))
    for _ in range(36):
        cy, cx = rng.integers(0, h), rng.integers(20, w - 20)
        r = rng.uniform(1.5, 5)
        drops = np.maximum(drops, np.clip(1 - np.hypot(yy - cy, (xx - cx) * .8) / r, 0, 1))
    thick = np.clip(np.maximum(thick, drops * (np.abs(y) > .5)), 0, 1)
    save(name, thick)


def pool():
    n = 512
    yy, xx = np.mgrid[-1:1:n * 1j, -1:1:n * 1j]
    ang = np.arctan2(yy, xx)
    r = np.hypot(xx * 1.15, yy)
    edge = .62 + .14 * noise(1, 360, 40, 3, 7)[0][((ang + np.pi) / (2 * np.pi) * 359).astype(int)]
    blob = 1 - smoothstep(edge - .12, edge, r + (noise(n, n, 40, 4, 8) - .5) * .18)
    thick = blob * (.55 + .45 * noise(n, n, 50, 3, 9))
    # Cracks in the dried crust.
    cracks = smoothstep(.47, .5, noise(n, n, 18, 2, 10)) * smoothstep(.53, .5, noise(n, n, 18, 2, 10))
    thick = np.clip(thick - cracks * .35 * blob, 0, 1)
    # Satellite drops.
    for _ in range(30):
        a = RNG.uniform(0, 2 * np.pi)
        rr = RNG.uniform(.6, .95)
        cx, cy = np.cos(a) * rr, np.sin(a) * rr
        s = RNG.uniform(.01, .04)
        thick = np.maximum(thick, np.clip(1 - np.hypot(xx - cx, yy - cy) / s, 0, 1) * .8)
    save('pool', thick)


def drops():
    n = 512
    thick = np.zeros((n, n))
    yy, xx = np.mgrid[0:n, 0:n]
    for _ in range(26):
        cx, cy = RNG.uniform(40, n - 40), RNG.uniform(40, n - 40)
        r = RNG.uniform(4, 13)
        # Elongated with a tail (drops that fell while moving).
        a = RNG.uniform(0, np.pi)
        dx, dy = xx - cx, yy - cy
        u = dx * np.cos(a) + dy * np.sin(a)
        v = -dx * np.sin(a) + dy * np.cos(a)
        blob = np.clip(1 - np.hypot(u / 1.3, v) / r, 0, 1)
        tail = np.clip(1 - np.abs(v) / (r * .25), 0, 1) * (u < 0) * np.clip(1 + u / (r * 4), 0, 1)
        thick = np.maximum(thick, np.maximum(blob, tail * .7))
    thick *= .6 + .4 * noise(n, n, 30, 3, 11)
    save('drops', thick)


def scrape():
    w, h = 1024, 256
    y = np.linspace(0, 1, h)[:, None]
    lines = np.zeros((h, w))
    for _ in range(14):
        cy = RNG.uniform(.15, .85)
        width = RNG.uniform(.004, .02)
        lines = np.maximum(lines, np.exp(-((y - cy) / width) ** 2) * RNG.uniform(.4, 1))
    lines *= smoothstep(0, .1, np.linspace(0, 1, w))[None, :] * smoothstep(0, .1, 1 - np.linspace(0, 1, w))[None, :]
    lines *= .6 + .4 * noise(h, w, 40, 3, 14)
    save('scrape', lines, rough_dry=.95, rough_wet=.95, tint=(.62, .6, .55))


def main():
    os.makedirs(OUT, exist_ok=True)
    drag('drag_a', 21)
    drag('drag_b', 33, gap=.35, width=.5)
    drag('drag_c', 47, gap=.15, width=.75)
    pool()
    drops()
    scrape()


if __name__ == '__main__':
    main()
