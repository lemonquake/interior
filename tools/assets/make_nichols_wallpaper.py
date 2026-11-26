"""Seamless Victorian wallpaper masks for the Nichols house (0.21), generated (no downloads).

    python tools/assets/make_nichols_wallpaper.py

Writes game/assets/nichols/wallpaper_masks.png (1024x1024, tiles seamlessly):
  R  damask: ogee lattice with a mirrored fleur medallion in every cell, half-drop repeat
  G  small floral sprigs on a half-drop grid (bedrooms)
  B  narrow regency stripes with a hairline (dining room)
nichols_wallpaper.gdshader colours, fades, stains and peels them.
"""
import os

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "game", "assets", "nichols", "wallpaper_masks.png")
N = 1024


def cell_coords(cells_x, cells_y, half_drop=True):
    """Local coords (u, v) in [-1, 1] within each repeat cell (half-drop rows)."""
    y, x = np.mgrid[0:N, 0:N].astype(np.float64) / N
    cx = x * cells_x
    col = np.floor(cx)
    cy = y * cells_y + (0.5 * (col % 2) if half_drop else 0)
    u = (cx - col) * 2 - 1
    v = (cy - np.floor(cy)) * 2 - 1
    return u, v


def ellipse(u, v, cx, cy, rx, ry, ang=0.0):
    c, s = np.cos(ang), np.sin(ang)
    du, dv = u - cx, v - cy
    a = (du * c + dv * s) / rx
    b = (-du * s + dv * c) / ry
    return np.clip(1.0 - (a * a + b * b), 0, 1)


def damask():
    u, v = cell_coords(4, 3)
    au = np.abs(u)  # mirror symmetry
    m = np.zeros_like(u)
    # Ogee lattice: two sinusoidal bands that meet at the cell sides.
    for k in (-1, 1):
        curve = .92 - .55 * np.cos(np.pi * (v * .5 + .5)) ** 2
        band = np.abs(au - curve * (.5 + .5 * k * 0))
        m = np.maximum(m, np.clip(1 - band / .035, 0, 1))
    # Central fleur: tall teardrop, two flanking leaves, a crown of small petals, a base crescent.
    m = np.maximum(m, (ellipse(au, v, 0, -.05, .13, .42) > 0) * 1.0)
    for ang, cy, cx in ((.7, .05, .2), (1.1, .25, .3), (.4, -.25, .18)):
        m = np.maximum(m, (ellipse(au, v, cx, cy, .07, .26, ang) > 0) * 1.0)
    for i in range(5):
        a = np.pi * (.15 + .7 * i / 4)
        m = np.maximum(m, (ellipse(au, v, .3 * np.cos(a), -.5 - .25 * np.sin(a), .05, .11, a - np.pi / 2) > 0) * 1.0)
    crescent = (ellipse(au, v, 0, .48, .32, .12) > 0) * 1.0 - (ellipse(au, v, 0, .43, .28, .09) > 0) * 1.0
    m = np.maximum(m, np.clip(crescent, 0, 1))
    # Scrolls: rings off the lattice.
    r = np.sqrt((au - .62) ** 2 + (v - .55) ** 2)
    m = np.maximum(m, np.clip(1 - np.abs(r - .14) / .025, 0, 1) * (v > .45))
    r = np.sqrt((au - .62) ** 2 + (v + .55) ** 2)
    m = np.maximum(m, np.clip(1 - np.abs(r - .14) / .025, 0, 1) * (v < -.45))
    # Dots along the cell midline.
    for dv in (-.82, .82):
        m = np.maximum(m, (ellipse(au, v, 0, dv, .04, .04) > 0) * 1.0)
    return m


def floral():
    u, v = cell_coords(8, 8)
    m = np.zeros_like(u)
    for i in range(5):
        a = np.pi * 2 * i / 5
        m = np.maximum(m, (ellipse(u, v, .16 * np.cos(a), .16 * np.sin(a) - .1, .09, .15, a + np.pi / 2) > 0) * 1.0)
    m = np.maximum(m, (ellipse(u, v, 0, -.1, .06, .06) > 0) * .4)
    m = np.maximum(m, (ellipse(u, v, .28, .35, .07, .2, .8) > 0) * .8)
    m = np.maximum(m, (ellipse(u, v, -.25, .4, .06, .18, -.7) > 0) * .8)
    stem = np.clip(1 - np.abs(u - .05 * np.sin(v * 3)) / .02, 0, 1) * ((v > 0) & (v < .7))
    return np.maximum(m, stem * .8)


def stripes():
    y, x = np.mgrid[0:N, 0:N].astype(np.float64) / N
    p = (x * 16) % 1.0
    wide = ((p > .1) & (p < .45)) * 1.0
    hair = (np.abs(p - .72) < .012) * 1.0
    return np.maximum(wide, hair * .9)


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    chans = []
    for f in (damask, floral, stripes):
        img = Image.fromarray((np.clip(f(), 0, 1) * 255).astype(np.uint8))
        chans.append(img.filter(ImageFilter.GaussianBlur(1.2)))
    Image.merge("RGB", chans).save(OUT)
    print("wrote", OUT)


main()
