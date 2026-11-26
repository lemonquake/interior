"""0.64: the blood pictures in one sheet for phones (scripts/blood_marks.gd).

    python -I tools/blood_atlas.py

The phone renderer (Compatibility) cannot draw Decal nodes, so on a phone the blood lies on surfaces as flat
quads, many to a draw call. That needs every picture in one texture: a 4 x 4 sheet of 256 px cells, albedo and
normal map. Cell order (blood_marks.gd CELLS): splat_a..e, drops_a, drops_b, pool_a, pool_b, then four blots (the
round stains a drop leaves, drawn here the way blood.gd `_blot` draws them). Each picture keeps a 4 px clear border
so the mip levels do not bleed into the next cell.
"""
import math
import os
import random

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLOOD = os.path.join(ROOT, 'game', 'assets', 'zombies', 'blood')
CELL = 256
PAD = 4
GRID = 4
KITS = ['splat_a', 'splat_b', 'splat_c', 'splat_d', 'splat_e', 'drops_a', 'drops_b', 'pool_a', 'pool_b']


def blot(seed):
    """blood.gd `_blot`, at the cell's size."""
    rng = random.Random(40 + seed)
    lobes = [(rng.uniform(2.0, 9.0), rng.uniform(0.0, math.tau), rng.uniform(.02, .09)) for _ in range(5)]
    satellites = []
    for _ in range(2 + seed):
        angle = rng.uniform(0.0, math.tau)
        far = rng.uniform(.72, .92)
        satellites.append((math.cos(angle) * far, math.sin(angle) * far, rng.uniform(.04, .09)))
    size = CELL - 2 * PAD
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float64)
    dx = (xs - size * .5 + .5) / (size * .5)
    dy = (ys - size * .5 + .5) / (size * .5)
    r = np.hypot(dx, dy)
    a = np.arctan2(dy, dx)
    edge = np.full_like(r, .58)
    for n, phase, depth in lobes:
        edge += np.sin(a * round(n) + phase) * depth

    def smooth(e0, e1, x):
        t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
        return t * t * (3.0 - 2.0 * t)

    alpha = 1.0 - smooth(edge - .025, edge, r)
    for sx, sy, sr in satellites:
        alpha = np.maximum(alpha, 1.0 - smooth(sr - .012, sr, np.hypot(dx - sx, dy - sy)))
    body = 1.0 + (.75 - 1.0) * smooth(edge * .4, edge, r)
    rgba = np.zeros((size, size, 4), np.float64)
    rgba[..., 0] = .3 * body
    rgba[..., 1] = .012
    rgba[..., 2] = .014
    rgba[..., 3] = alpha * .96
    return Image.fromarray((np.clip(rgba, 0, 1) * 255 + .5).astype(np.uint8), 'RGBA')


def main():
    albedo = Image.new('RGBA', (CELL * GRID, CELL * GRID), (77, 3, 4, 0))
    normal = Image.new('RGB', (CELL * GRID, CELL * GRID), (128, 128, 255))
    inner = CELL - 2 * PAD
    cells = []
    for key in KITS:
        a = Image.open(os.path.join(BLOOD, key + '_albedo.png')).convert('RGBA').resize((inner, inner), Image.LANCZOS)
        n = Image.open(os.path.join(BLOOD, key + '_normal.png')).convert('RGB').resize((inner, inner), Image.LANCZOS)
        cells.append((a, n))
    for seed in range(4):
        cells.append((blot(seed), None))
    for i, (a, n) in enumerate(cells):
        x, y = (i % GRID) * CELL + PAD, (i // GRID) * CELL + PAD
        albedo.paste(a, (x, y))
        if n is not None:
            normal.paste(n, (x, y))
    albedo.save(os.path.join(BLOOD, 'mobile_atlas_albedo.png'), optimize=True)
    normal.save(os.path.join(BLOOD, 'mobile_atlas_normal.png'), optimize=True)
    print('blood atlas: %d cells, %d px' % (len(cells), CELL * GRID))


if __name__ == '__main__':
    main()
