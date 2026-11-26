"""0.50: textures for the Prof. Ivan Lawrence College of Science and Technology (scripts/coop/school.gd).

  python -I tools/school_textures.py

Writes game/assets/school/*.png (albedo only; the materials are triplanar in world space, so each image covers
the metres given in SIZES and tiles seamlessly). Painted by numpy noise, nothing downloaded:
  checker    the lobby's black-and-cream vinyl checker, 0.3 m tiles, grout, scuffs
  corridor   the corridors' pale green-grey vinyl squares, worn paths, grime in the joints
  classroom  cream cement tiles 0.4 m, the floors of the rooms
  ceiling    acoustic tiles on a T-bar grid, 0.6 m, water stains and a few missing corners
  board      the chalkboards: green slate, chalk dust smeared by the eraser
  cream      the upper walls: cream paint, damp stains, peeling
  green      the wainscot: gloss institutional green, chips to the grey plaster under it
  paper      a sheet of ruled notebook paper (the scattered papers)
"""
import os

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "game", "assets", "school")
N = 1024
rng = np.random.default_rng(5050)


def noise(cells, seed):
    """Tileable value noise: a cells x cells random grid, wrapped, smoothly upsampled to N."""
    r = np.random.default_rng(seed).random((cells, cells)).astype(np.float32)
    big = np.tile(r, (3, 3))
    img = Image.fromarray((big * 255).astype(np.uint8)).resize((N * 3, N * 3), Image.BICUBIC)
    a = np.asarray(img, np.float32)[N:2 * N, N:2 * N] / 255.0
    return a


def fbm(base, seed, octaves=5):
    out = np.zeros((N, N), np.float32)
    amp = 1.0
    total = 0.0
    for o in range(octaves):
        out += noise(base * 2 ** o, seed + o * 17) * amp
        total += amp
        amp *= .5
    return out / total


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def save(name, rgb):
    os.makedirs(OUT, exist_ok=True)
    img = Image.fromarray(np.clip(rgb * 255, 0, 255).astype(np.uint8), "RGB")
    img.save(os.path.join(OUT, name + ".png"))
    print("wrote", name)


def grid(tiles):
    y, x = np.mgrid[0:N, 0:N].astype(np.float32)
    s = N / tiles
    return x, y, np.floor(x / s), np.floor(y / s), (x % s) / s, (y % s) / s


def checker():
    x, y, i, j, u, v = grid(4)
    dark = ((i + j) % 2 == 0)
    c = np.where(dark[..., None], np.array([.055, .058, .06]), np.array([.80, .76, .66]))
    c = c * (0.9 + 0.2 * fbm(3, 1))[..., None]
    grime = fbm(4, 2)
    c = c * (1 - .45 * smooth(.45, .8, grime))[..., None] + np.array([.16, .13, .09]) * (.35 * smooth(.45, .8, grime))[..., None]
    joint = (np.minimum(np.minimum(u, 1 - u), np.minimum(v, 1 - v)) < .012)
    c[joint] = c[joint] * .35 + np.array([.09, .08, .06]) * .65
    scuff = smooth(.62, .78, fbm(16, 3)) * smooth(.4, .7, fbm(2, 4))
    c = c * (1 - .35 * scuff)[..., None] + .35 * scuff[..., None] * np.array([.3, .3, .3])
    save("checker", c)


def corridor():
    x, y, i, j, u, v = grid(4)
    shade = ((i * 7 + j * 3) % 3)
    base = np.stack([np.choose(shade.astype(int), [.62, .66, .58]), np.choose(shade.astype(int), [.68, .70, .63]),
                     np.choose(shade.astype(int), [.62, .62, .57])], -1)
    c = base * (0.88 + 0.24 * fbm(3, 11))[..., None]
    worn = smooth(.4, .75, fbm(2, 12))
    c = c * (1 - .3 * worn)[..., None] + .3 * worn[..., None] * np.array([.32, .3, .25])
    joint = (np.minimum(np.minimum(u, 1 - u), np.minimum(v, 1 - v)) < .014)
    c[joint] = c[joint] * .3 + np.array([.12, .11, .08]) * .7
    speck = np.random.default_rng(13).random((N, N)) > .985
    c[speck] = c[speck] * .55
    dirt = smooth(.55, .85, fbm(5, 14))
    c = c * (1 - .5 * dirt)[..., None] + .5 * dirt[..., None] * np.array([.18, .15, .1])
    save("corridor", c)


def classroom():
    x, y, i, j, u, v = grid(3)
    c = np.ones((N, N, 3), np.float32) * np.array([.72, .68, .6])
    c = c * (0.85 + 0.3 * fbm(4, 21))[..., None]
    joint = (np.minimum(np.minimum(u, 1 - u), np.minimum(v, 1 - v)) < .01)
    c[joint] = c[joint] * .45
    dirt = smooth(.5, .82, fbm(3, 22))
    c = c * (1 - .55 * dirt)[..., None] + .55 * dirt[..., None] * np.array([.2, .17, .12])
    save("classroom", c)


def ceiling():
    x, y, i, j, u, v = grid(2)
    c = np.ones((N, N, 3), np.float32) * np.array([.78, .76, .7])
    pits = np.random.default_rng(31).random((N, N))
    c[pits > .93] *= .82
    c = c * (0.92 + 0.12 * fbm(8, 32))[..., None]
    stain = fbm(2, 33)
    ring = smooth(.58, .64, stain) - smooth(.7, .74, stain)
    c = c * (1 - .22 * smooth(.62, .82, stain))[..., None] + np.array([.5, .4, .26]) * (.22 * smooth(.62, .82, stain))[..., None]
    c = c * (1 - .18 * np.clip(ring, 0, 1))[..., None]
    bar = (np.minimum(np.minimum(u, 1 - u), np.minimum(v, 1 - v)) < .018)
    c[bar] = np.array([.62, .6, .55])
    save("ceiling", c)


def board():
    c = np.ones((N, N, 3), np.float32) * np.array([.11, .2, .15])
    c = c * (0.85 + 0.3 * fbm(5, 41))[..., None]
    y, x = np.mgrid[0:N, 0:N].astype(np.float32)
    sweep = (np.sin(x * .02 + np.sin(y * .011) * 2.0) * .5 + .5) * smooth(.45, .75, fbm(2, 42))
    c = c + sweep[..., None] * np.array([.12, .13, .12])
    dust = smooth(.7, .9, fbm(12, 43))
    c = c + dust[..., None] * .05
    save("board", c)


def cream():
    c = np.ones((N, N, 3), np.float32) * np.array([.86, .8, .66])
    c = c * (0.9 + 0.16 * fbm(4, 51))[..., None]
    damp = smooth(.55, .82, fbm(2, 52))
    c = c * (1 - .38 * damp)[..., None] + .38 * damp[..., None] * np.array([.48, .42, .3])
    peel = smooth(.7, .72, fbm(6, 53)) * smooth(.55, .7, fbm(2, 54)) * .75
    c = c * (1 - peel)[..., None] + peel[..., None] * np.array([.66, .62, .55])
    edge = smooth(.66, .68, fbm(6, 53)) - smooth(.7, .72, fbm(6, 53))
    c = c * (1 - .4 * np.clip(edge, 0, 1) * smooth(.45, .6, fbm(2, 54)))[..., None]
    save("cream", c)


def green():
    c = np.ones((N, N, 3), np.float32) * np.array([.24, .48, .38])
    c = c * (0.9 + 0.14 * fbm(4, 61))[..., None]
    chip = smooth(.72, .74, fbm(10, 62)) * smooth(.4, .55, fbm(2, 63))
    c = c * (1 - chip)[..., None] + chip[..., None] * np.array([.6, .6, .56])
    grime = smooth(.5, .85, fbm(3, 64))
    c = c * (1 - .45 * grime)[..., None] + .45 * grime[..., None] * np.array([.1, .12, .08])
    save("green", c)


def paper():
    n2 = 256
    c = np.ones((n2, n2, 3), np.float32) * np.array([.9, .89, .84])
    for k in range(18, n2, 12):
        c[k:k + 1, :, :] = np.array([.55, .65, .82])
    c[:, 30:31, :] = np.array([.85, .45, .45])
    words = np.random.default_rng(71).random((n2, n2))
    for k in range(18, n2 - 12, 12):
        length = int(np.random.default_rng(k).integers(80, 220))
        row = slice(k - 7, k - 2)
        mask = words[row, 36:36 + length] > .55
        c[row, 36:36 + length][mask] = np.array([.16, .18, .32])
    img = Image.fromarray(np.clip(c * 255, 0, 255).astype(np.uint8), "RGB").filter(ImageFilter.GaussianBlur(.6))
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, "paper.png"))
    print("wrote paper")


if __name__ == "__main__":
    checker()
    corridor()
    classroom()
    ceiling()
    board()
    cream()
    green()
    paper()
