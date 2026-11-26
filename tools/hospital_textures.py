"""0.68: the hospital's own surfaces (work/Reference/Davao Central Laboratory): the lobby's white terrazzo with grey
and blue chips, the laboratory's large white floor tiles with dark grout, and the hazard band round the big door.

    python -I tools/hospital_textures.py   -> game/assets/hospital/{terrazzo,lab_tile,hazard}.png (512 px, tiling)
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "game", "assets", "hospital")
N = 512
rng = np.random.default_rng(6802)


def blur_wrap(a, r):
    out = a.copy()
    for _ in range(r):
        out = (out + np.roll(out, 1, 0) + np.roll(out, -1, 0) + np.roll(out, 1, 1) + np.roll(out, -1, 1)) / 5.0
    return out


def terrazzo():
    base = np.ones((N, N, 3), np.float32) * np.array((0.86, 0.86, 0.84), np.float32)
    cloud = blur_wrap(rng.random((N, N)).astype(np.float32), 18)
    cloud = (cloud - cloud.min()) / (cloud.max() - cloud.min() + 1e-6)
    base *= (0.94 + 0.08 * cloud)[..., None]
    yy, xx = np.mgrid[0:N, 0:N]
    palette = [((0.48, 0.48, 0.47), 900, 2.6), ((0.30, 0.31, 0.32), 500, 2.0), ((0.20, 0.32, 0.58), 420, 2.2),
               ((0.62, 0.60, 0.55), 700, 3.0), ((0.12, 0.13, 0.15), 260, 1.6), ((0.95, 0.95, 0.93), 500, 2.4)]
    for col, count, size in palette:
        cx = rng.integers(0, N, count)
        cy = rng.integers(0, N, count)
        rad = rng.uniform(0.6, size, count)
        for x, y, r in zip(cx, cy, rad):
            x0, x1 = int(x - r - 1), int(x + r + 2)
            y0, y1 = int(y - r - 1), int(y + r + 2)
            for py in range(y0, y1):
                for px in range(x0, x1):
                    ang = np.arctan2(py - y, px - x)
                    rr = r * (0.75 + 0.35 * np.sin(ang * 3 + x))
                    if (px - x) ** 2 + (py - y) ** 2 <= rr * rr:
                        base[py % N, px % N] = col
    return base


def lab_tile():
    base = np.ones((N, N, 3), np.float32) * np.array((0.88, 0.9, 0.92), np.float32)
    cloud = blur_wrap(rng.random((N, N)).astype(np.float32), 10)
    cloud = (cloud - cloud.min()) / (cloud.max() - cloud.min() + 1e-6)
    base *= (0.96 + 0.05 * cloud)[..., None]
    for k in range(2):
        q = k * (N // 2)
        base[q:q + 3, :] = (0.34, 0.36, 0.38)
        base[:, q:q + 3] = (0.34, 0.36, 0.38)
    return base


def hazard():
    yy, xx = np.mgrid[0:N, 0:N]
    stripe = ((xx + yy) // 64) % 2 == 0
    base = np.where(stripe[..., None], np.array((0.86, 0.66, 0.06), np.float32), np.array((0.06, 0.06, 0.06), np.float32))
    grime = blur_wrap(rng.random((N, N)).astype(np.float32), 6)
    base = base * (0.82 + 0.25 * grime[..., None])
    return base


def save(name, a):
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, name))
    print("wrote", name)


save("terrazzo.png", terrazzo())
save("lab_tile.png", lab_tile())
save("hazard.png", hazard())
