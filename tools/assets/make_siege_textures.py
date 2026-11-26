"""Decal textures for the walled town (0.23).

    python tools/assets/make_siege_textures.py

Writes game/assets/siege/<name>_albedo.png (RGBA), <name>_normal.png and <name>_orm.png, the same layout as the Nichols
trail (tools/assets/make_blood_decals.py, whose noise and save helpers are reused):
- splat_a, splat_b, splat_c   impact spatter on a wall: a dense core, radial streaks, satellite drops and runs that
                              dripped down before they dried (v = down the wall);
- smear_wall                  something heavy slid down a wall: a vertical smear widening to a pool at the foot;
- drag_body_a, drag_body_b    a person dragged over asphalt: a broad smear, heel and clothing streaks, gaps where the
                              body was lifted, drops either side (u along the drag);
- pool_big                    a large dried pool with a congealed centre;
- spatter_floor               cast-off drops across the ground;
- shoe_mud                    one muddy sneaker print (toe at +v);
- spray_arrow, spray_arrow_l  an orange spray-painted arrow with overspray (points +u / -u);
- spray_x                     a spray-painted X (a searched house);
- scorch                      soot and ash where tyres were burnt.
Gore stays to trails, pools and splatter (no lettering, no hand prints: the owner's rule).
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_blood_decals as blood  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, 'game', 'assets', 'siege')
blood.OUT = OUT
RNG = np.random.default_rng(2310)
noise, noise2, smoothstep = blood.noise, blood.noise2, blood.smoothstep


def disc(h, w, cy, cx, r, sy=1.0):
    yy, xx = np.ogrid[:h, :w]
    return np.clip(1 - np.hypot((yy - cy) / sy, xx - cx) / r, 0, 1)


def runs(thick, count, seed, max_len=.45):
    """Drips running down (+y) from the thicker parts of a wall stain."""
    rng = np.random.default_rng(seed)
    h, w = thick.shape
    out = thick.copy()
    ys, xs = np.nonzero(thick > .55)
    if len(ys) == 0:
        return out
    yy = np.arange(h)[:, None]
    for _ in range(count):
        k = rng.integers(len(ys))
        y0, x0 = ys[k], xs[k]
        length = rng.uniform(.08, max_len) * h
        width = rng.uniform(1.4, 4.0)
        xw = x0 + np.cumsum(rng.normal(0, .25, h))  # a slightly wandering run
        cols = np.arange(w)[None, :]
        along = np.clip((yy - y0) / length, 0, 1)
        body = (yy >= y0) & (yy <= y0 + length)
        prof = np.exp(-((cols - xw[:, None]) / (width * (1 - .5 * along))) ** 2)
        run = prof * body * (1 - .55 * along)
        # A bead where the drip stopped.
        run = np.maximum(run, disc(h, w, min(h - 2, y0 + length), x0 + (xw[min(h - 1, int(y0 + length))] - x0), width * 1.6) * .95)
        out = np.maximum(out, run * .9)
    return np.clip(out, 0, 1)


def splat(name, seed, size=512, spines=9, drops=170, run_count=14):
    """Impact spatter: a lobed core, drops thrown mostly one way (a cone around `aim`) as teardrops whose tails point
    away from the core, a few short thick spines from the core's edge, and runs that dripped down."""
    rng = np.random.default_rng(seed)
    h = w = size
    yy, xx = np.mgrid[0:h, 0:w]
    cy, cx = h * rng.uniform(.36, .44), w * rng.uniform(.4, .5)
    dy, dx = yy - cy, xx - cx
    r = np.hypot(dx, dy)
    ang = np.arctan2(dy, dx)
    aim = rng.uniform(-.6, .6)  # most of the spray goes this way (radians, 0 = +u)
    core_r = size * rng.uniform(.07, .1)
    lobes = noise(1, 720, 50, 3, seed)[0][((ang + np.pi) / (2 * np.pi) * 719).astype(int)]
    reach = core_r * (1 + .9 * (lobes - .5) + .55 * np.clip(np.cos(ang - aim), 0, 1))
    thick = 1 - smoothstep(reach * .75, reach, r + (noise(h, w, 14, 3, seed + 1) - .5) * 16)
    def teardrop(px, py, a, rad, stretch):
        u = (xx - px) * np.cos(a) + (yy - py) * np.sin(a)
        v = -(xx - px) * np.sin(a) + (yy - py) * np.cos(a)
        head = np.clip(1 - np.hypot(u / stretch, v) / rad, 0, 1)
        tail = np.clip(1 - np.abs(v) / (rad * .35), 0, 1) * (u > 0) * np.clip(1 - u / (rad * stretch * 3.5), 0, 1)
        return np.maximum(head, tail * .8)
    for _ in range(spines):
        a = aim + rng.normal(0, .7)
        length = core_r * rng.uniform(1.4, 3.2)
        base = core_r * .8
        u = dx * np.cos(a) + dy * np.sin(a)
        v = -dx * np.sin(a) + dy * np.cos(a)
        t = np.clip((u - base) / length, 0, 1)
        width = rng.uniform(3, 7) * (1 - t) + .8
        seg = (u > base * .6) & (u < base + length)
        thick = np.maximum(thick, np.exp(-(v / width) ** 2) * seg * (1 - .4 * t))
        thick = np.maximum(thick, teardrop(cx + np.cos(a) * (base + length * 1.08), cy + np.sin(a) * (base + length * 1.08), a, rng.uniform(3, 6), 1.6))
    for _ in range(drops):
        a = aim + rng.normal(0, .65) if rng.random() < .75 else rng.uniform(-np.pi, np.pi)
        d = core_r * (1.1 + rng.exponential(1.6))
        if d > size * .47:
            continue
        rad = max(1.1, rng.uniform(2.0, 7.5) * (core_r * 1.2 / d) ** .6)
        thick = np.maximum(thick, teardrop(cx + np.cos(a) * d, cy + np.sin(a) * d, a, rad, 1.0 + d / size * 4) * rng.uniform(.7, 1))
    thick *= .6 + .4 * noise(h, w, 22, 3, seed + 2)
    thick = runs(thick, run_count, seed + 3)
    yy1 = np.linspace(0, 1, h)[:, None]
    thick *= smoothstep(0, .03, yy1) * smoothstep(0, .03, 1 - yy1)
    blood.save(name, thick, rough_dry=.8, rough_wet=.4)


def smear_wall():
    h, w = 1024, 384
    rng = np.random.default_rng(77)
    y = np.linspace(0, 1, h)[:, None]
    x = np.linspace(-1, 1, w)[None, :]
    centre = (noise(h, 1, 200, 2, 78)[:, 0][:, None] - .5) * .25
    width = .35 + .45 * y ** 1.6
    d = np.abs(x - centre) / width
    body = 1 - smoothstep(.45, 1.0, d + (noise2(h, w, 30, 18, 4, 79) - .5) * .6)
    streaks = smoothstep(.3, .75, noise2(h, w, 160, 3.5, 3, 80))
    thick = body * (.35 + .65 * streaks)
    thick *= smoothstep(.0, .12, y)  # starts at shoulder height, thin
    # The pool at the foot, where it came to rest.
    thick = np.maximum(thick, (1 - smoothstep(.15, .5, np.hypot(x * .7, (y - 1.0) * 3.2))) * (.7 + .3 * noise(h, w, 30, 3, 81)))
    thick = runs(thick, 10, 82, .25)
    thick *= smoothstep(0, .05, np.abs(1 - np.abs(x))) * smoothstep(0, .01, 1 - y)
    blood.save('smear_wall', np.clip(thick, 0, 1), rough_dry=.78, rough_wet=.35)


def drag_body(name, seed):
    """Wider than the Nichols animal drag: two blurred bands (the torso and the legs) and heel scuffs either side."""
    rng = np.random.default_rng(seed)
    w, h = 1024, 384
    y = np.linspace(-1, 1, h)[:, None]
    x = np.linspace(0, 1, w)[None, :]
    centre = (noise(1, w, 300, 2, seed)[0] - .5)[None, :] * .25
    profile = .72 * (.7 + .3 * noise(1, w, 140, 3, seed + 1)[0])[None, :]
    d = np.abs(y - centre) / profile
    body = 1 - smoothstep(.45, 1.0, d + (noise2(h, w, 18, 50, 4, seed + 2) - .5) * .6)
    cloth = smoothstep(.28, .8, noise2(h, w, 6, 220, 3, seed + 3))
    lift = smoothstep(.2, .6, noise2(h, w, 80, 160, 3, seed + 4))
    thick = body * (.35 + .65 * cloth) * (.2 + .8 * lift)
    # Heels: two narrow scuff lines either side, broken.
    for side in (-1, 1):
        lane = np.exp(-((y - centre - side * profile * .9) / .035) ** 2)
        thick = np.maximum(thick, lane * smoothstep(.45, .7, noise2(h, w, 4, 60, 2, seed + 5 + side)) * .75)
    pause = smoothstep(.68, .92, noise2(h, w, 90, 80, 2, seed + 7))
    thick = np.clip(thick + body * pause * .5, 0, 1)
    thick *= smoothstep(0, .08, x) * smoothstep(0, .08, 1 - x)
    yy, xx = np.ogrid[:h, :w]
    for _ in range(50):
        cy, cx = rng.integers(0, h), rng.integers(20, w - 20)
        thick = np.maximum(thick, np.clip(1 - np.hypot(yy - cy, (xx - cx) * .7) / rng.uniform(1.5, 5.5), 0, 1) * (np.abs(y) > .55))
    blood.save(name, np.clip(thick, 0, 1), rough_dry=.85, rough_wet=.4, darken=.1)


def pool_big():
    n = 768
    yy, xx = np.mgrid[-1:1:n * 1j, -1:1:n * 1j]
    ang = np.arctan2(yy, xx)
    r = np.hypot(xx * 1.05, yy * 1.3)
    lobes = noise(1, 720, 70, 3, 91)[0][((ang + np.pi) / (2 * np.pi) * 719).astype(int)]
    edge = .55 + .3 * lobes
    blob = 1 - smoothstep(edge - .1, edge, r + (noise(n, n, 50, 4, 92) - .5) * .2)
    thick = blob * (.6 + .4 * noise(n, n, 60, 3, 93))
    core = 1 - smoothstep(.0, .35, np.hypot(xx * 1.1 - .05, yy * 1.4 + .04))
    thick = np.clip(thick + core * .5, 0, 1)
    cracks = smoothstep(.48, .5, noise(n, n, 22, 2, 94)) * smoothstep(.52, .5, noise(n, n, 22, 2, 94))
    thick = np.clip(thick - cracks * .3 * blob * (1 - core), 0, 1)
    blood.save('pool_big', thick, rough_dry=.7, rough_wet=.22, darken=.08)


def spatter_floor():
    n = 512
    rng = np.random.default_rng(101)
    thick = np.zeros((n, n))
    yy, xx = np.mgrid[0:n, 0:n]
    a0 = rng.uniform(0, np.pi)
    for k in range(70):
        t = rng.uniform(-.45, .45)
        cx = n / 2 + np.cos(a0) * t * n + rng.normal(0, 22)
        cy = n / 2 + np.sin(a0) * t * n + rng.normal(0, 22)
        r = rng.uniform(2, 9) * (1 - abs(t))
        u = (xx - cx) * np.cos(a0) + (yy - cy) * np.sin(a0)
        v = -(xx - cx) * np.sin(a0) + (yy - cy) * np.cos(a0)
        blob = np.clip(1 - np.hypot(u / 1.8, v) / max(r, 1), 0, 1)
        tail = np.clip(1 - np.abs(v) / (r * .3 + .5), 0, 1) * (u > 0) * np.clip(1 - u / (r * 5 + 1), 0, 1)
        thick = np.maximum(thick, np.maximum(blob, tail * .7))
    thick *= .65 + .35 * noise(n, n, 30, 3, 102)
    blood.save('spatter_floor', thick)


def shoe_mud():
    """A sneaker print in wet mud: a rounded sole (toe at the top of the image, +v), chevron tread, the heel pressed
    deepest, the edges broken where the mud was thin."""
    h, w = 512, 224
    yy, xx = np.mgrid[0:h, 0:w]
    v = 1 - yy / h
    x = (xx - w / 2) / (w / 2)
    half = np.interp(v, [0, .04, .14, .3, .4, .52, .7, .84, .93, 1.0], [.0, .5, .64, .6, .5, .6, .78, .74, .52, .0])
    ox = np.interp(v, [0, .5, 1], [0, .05, .14])  # a slight inward curve to the toe
    d = np.abs(x - ox) / np.maximum(half, 1e-3)
    sole = 1 - smoothstep(.82, 1.0, d + (noise(h, w, 10, 3, 110) - .5) * .25)
    sole *= smoothstep(.01, .05, v) * smoothstep(.0, .04, 1 - v)
    chevron = np.sin((v * 2 - np.abs(x - ox) * .35) * 60)
    tread = smoothstep(-.2, .5, chevron)
    heel_lug = (v < .3) * smoothstep(-.4, .4, np.sin(x * 14) * np.sin(v * 50))
    press = np.interp(v, [0, .3, .45, .7, 1.0], [1.0, .9, .45, .8, .7])
    thick = sole * press * (.35 + .5 * np.maximum(tread, heel_lug) + .15)
    thick *= smoothstep(.2, .55, noise(h, w, 26, 3, 111) + .25)
    thick = ndimage.gaussian_filter(thick, 1.0)
    blood.save('shoe_mud', np.clip(thick, 0, 1), rough_dry=.9, rough_wet=.5, tint=(.15, .115, .08))


def spray(name, mask_fn, colour, seed):
    """Spray paint: a soft core line, overspray haze and a few runs. mask_fn(u, v) -> distance-ish (0 on the stroke)."""
    n = 512
    rng = np.random.default_rng(seed)
    vv, uu = np.mgrid[0:n, 0:n] / (n - 1)
    d = mask_fn(uu, vv)
    core = np.exp(-(d / .028) ** 2)
    haze = np.exp(-(d / .08) ** 2) * .35
    speckle = (rng.random((n, n)) < .04) * np.exp(-(d / .14) ** 2)
    paint = np.clip(core + haze + speckle * .8, 0, 1)
    paint *= .75 + .25 * noise(n, n, 20, 3, seed + 1)
    paint = runs(paint, 7, seed + 2, .22)
    alpha = np.clip(paint, 0, 1) * .92
    col = np.array(colour) * (.85 + .2 * noise(n, n, 40, 2, seed + 3)[..., None])
    rgba = np.dstack([np.clip(col, 0, 1), alpha])
    Image.fromarray((rgba * 255).astype(np.uint8), 'RGBA').save(os.path.join(OUT, name + '_albedo.png'))
    flat = np.dstack([np.full((n, n), .5), np.full((n, n), .5), np.ones((n, n))])
    Image.fromarray((flat * 255).astype(np.uint8), 'RGB').save(os.path.join(OUT, name + '_normal.png'))
    orm = np.dstack([np.ones((n, n)), np.full((n, n), .55), np.zeros((n, n))])
    Image.fromarray((orm * 255).astype(np.uint8), 'RGB').save(os.path.join(OUT, name + '_orm.png'))
    print('wrote', name)


def seg(uu, vv, a, b):
    ax, ay = a
    bx, by = b
    px, py = uu - ax, vv - ay
    dx, dy = bx - ax, by - ay
    t = np.clip((px * dx + py * dy) / (dx * dx + dy * dy), 0, 1)
    return np.hypot(px - t * dx, py - t * dy)


def arrow(uu, vv):
    # A hand-sprayed arrow pointing +u, slightly wobbly.
    wob = .012 * np.sin(uu * 17)
    shaft = seg(uu, vv + wob, (.1, .52), (.82, .5))
    head1 = seg(uu, vv, (.86, .5), (.62, .3))
    head2 = seg(uu, vv, (.86, .5), (.64, .7))
    return np.minimum(shaft, np.minimum(head1, head2))


def cross(uu, vv):
    return np.minimum(seg(uu, vv, (.18, .2), (.82, .84)), seg(uu, vv, (.8, .16), (.2, .82)))


def scorch():
    n = 768
    yy, xx = np.mgrid[-1:1:n * 1j, -1:1:n * 1j]
    r = np.hypot(xx, yy * 1.2) + (noise(n, n, 60, 4, 121) - .5) * .5
    soot = 1 - smoothstep(.25, .95, r)
    ash = smoothstep(.55, .8, noise(n, n, 12, 3, 122)) * (1 - smoothstep(.1, .5, r))
    alpha = np.clip(soot * (.75 + .25 * noise(n, n, 30, 3, 123)), 0, 1)
    col = np.zeros((n, n, 3)) + np.array([.025, .022, .02])
    col = col * (1 - ash[..., None]) + np.array([.32, .3, .28]) * ash[..., None]
    rgba = np.dstack([col, alpha])
    Image.fromarray((rgba * 255).astype(np.uint8), 'RGBA').save(os.path.join(OUT, 'scorch_albedo.png'))
    flat = np.dstack([np.full((n, n), .5), np.full((n, n), .5), np.ones((n, n))])
    Image.fromarray((flat * 255).astype(np.uint8), 'RGB').save(os.path.join(OUT, 'scorch_normal.png'))
    orm = np.dstack([np.ones((n, n)), np.full((n, n), .97), np.zeros((n, n))])
    Image.fromarray((orm * 255).astype(np.uint8), 'RGB').save(os.path.join(OUT, 'scorch_orm.png'))
    print('wrote scorch')


def main():
    os.makedirs(OUT, exist_ok=True)
    splat('splat_a', 11)
    splat('splat_b', 23, spines=5, drops=230, run_count=20)
    splat('splat_c', 37, spines=13, drops=110, run_count=8)
    smear_wall()
    drag_body('drag_body_a', 51)
    drag_body('drag_body_b', 63)
    pool_big()
    spatter_floor()
    shoe_mud()
    spray('spray_arrow', arrow, (.95, .38, .06), 131)
    # The same arrow pointing the other way (its runs still drip down): decals cannot be mirrored.
    for part in ('albedo', 'normal', 'orm'):
        Image.open(os.path.join(OUT, 'spray_arrow_%s.png' % part)).transpose(Image.FLIP_LEFT_RIGHT).save(os.path.join(OUT, 'spray_arrow_l_%s.png' % part))
    spray('spray_x', cross, (.82, .1, .06), 141)
    scorch()


if __name__ == '__main__':
    main()
