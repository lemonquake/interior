"""Deterministic, small material maps for the owner's three room references.

Room photographs remain reference evidence, never pasted across a room wall.
The family inserts reuse the already-authorized full-image family textures.
Run: python tools/prepare_reference_room.py
"""
from pathlib import Path
import hashlib
import json
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game/assets/reference_room"
EVIDENCE = ROOT / "work/lemondev/2026-10-05/reference-sides"
RNG = np.random.default_rng(51005)
SIZE = 512


def write_maps(name, rgb, height, roughness=.75, strength=2.0):
    rgb = np.broadcast_to(rgb, (SIZE, SIZE, 3))
    Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).save(OUT / f"{name}_color.jpg", quality=94)
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * strength
    dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * strength
    norm = np.stack([-dx, dy, np.ones_like(height)], axis=-1)
    norm /= np.linalg.norm(norm, axis=-1, keepdims=True)
    Image.fromarray(((norm * .5 + .5) * 255).astype(np.uint8)).save(OUT / f"{name}_normal.png")
    r = np.broadcast_to(roughness, (SIZE, SIZE))
    Image.fromarray(np.clip(r * 255, 0, 255).astype(np.uint8)).save(OUT / f"{name}_roughness.jpg", quality=94)


def make_maps():
    OUT.mkdir(parents=True, exist_ok=True)
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    y, x = np.indices((SIZE, SIZE))
    noise = RNG.random((SIZE, SIZE))
    h = noise * .04 + (np.sin(y * .093 + np.sin(x * .025)) ** 2) * .028
    write_maps("blue_ceiling", np.array([80, 118, 143])[None, None, :] * (.96 + h[..., None]), h, .68 + noise * .06)
    write_maps("navy_enamel", np.array([30, 47, 66])[None, None, :] * (.96 + h[..., None]), h * .6, .38 + noise * .05)
    grain = np.sin(y * .11 + np.sin(x * .046) * 1.5) * .03 + noise * .025
    write_maps("pale_slat", np.array([181, 153, 113])[None, None, :] * (.95 + grain[..., None]), grain, .60 + noise * .04)

    # The soft leaf pattern and its woven surface belong to the real doorway.
    curtain = Image.new("RGB", (SIZE, SIZE), (204, 193, 180))
    d = ImageDraw.Draw(curtain)
    for row in range(4):
        for col in range(4):
            cx = col * 128 + 40 + (row % 2) * 45
            cy = row * 128 + 57
            angle = -.6 if (row + col) % 2 else .7
            length, width = 52, 25
            def rotate(px, py):
                return (cx + px * math.cos(angle) - py * math.sin(angle), cy + px * math.sin(angle) + py * math.cos(angle))
            points = [rotate(math.sin(t * math.pi) * width, (t - .5) * length * 2) for t in np.linspace(0, 1, 18)]
            points += [rotate(-math.sin(t * math.pi) * width, (t - .5) * length * 2) for t in np.linspace(1, 0, 18)]
            d.polygon(points, fill=(182, 176, 162), outline=(154, 154, 139))
            d.line([rotate(0, -length), rotate(0, length + 8)], fill=(143, 143, 128), width=2)
            for pos in range(-32, 38, 9):
                w = math.cos(pos / length * math.pi / 2) * width * .8
                for side in [-1, 1]:
                    d.line([rotate(0, pos + 8), rotate(side * w, pos - 7)], fill=(151, 151, 136), width=1)
    rgb = np.asarray(curtain).astype(float)
    weave = np.sin(x * math.pi / 2) * .5 + np.sin(y * math.pi / 2) * .5
    write_maps("leaf_curtain", rgb * (1 + weave[..., None] * .012), weave * .015 + noise * .025, .87)

    # Small colored alphabet magnets printed into a local fridge-door decal.
    magnets = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    draw = ImageDraw.Draw(magnets)
    fonts = [Path("C:/Windows/Fonts/arialbd.ttf"), Path("C:/Windows/Fonts/calibrib.ttf")]
    font = ImageFont.truetype(str(next(p for p in fonts if p.exists())), 79)
    colors = [(224, 155, 48), (172, 186, 86), (205, 91, 76), (82, 160, 166), (194, 146, 166)]
    for i, character in enumerate("abcdefghijklmnopqrstuvxyz"):
        px = 16 + (i % 5) * 99 + int(RNG.integers(-6, 7))
        py = 4 + (i // 5) * 97 + int(RNG.integers(-5, 5))
        draw.text((px + 3, py + 5), character, font=font, fill=(8, 11, 14, 235), stroke_width=3)
        draw.text((px, py), character, font=font, fill=(*colors[i % len(colors)], 255), stroke_width=1)
    magnets.save(OUT / "fridge_magnets.png")
    records = []
    for file in sorted(OUT.iterdir()):
        if file.suffix in [".jpg", ".png"]:
            records.append(dict(file=file.name, sha256=hashlib.sha256(file.read_bytes()).hexdigest(), bytes=file.stat().st_size))
    (OUT / "provenance.json").write_text(json.dumps(dict(method="Deterministic local procedural PBR maps, no downloaded content or full-room photographic planes", seed=51005, sources="Owner room-reference photos; existing licensed project surface maps; owner's family inserts", maps=records), indent=2))
    print(json.dumps(dict(maps=len(records), bytes=sum(r["bytes"] for r in records))))


if __name__ == "__main__":
    make_maps()
