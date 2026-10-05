"""Rebuild tactile room maps and faithful family-photo inserts.

Run with Python + Pillow + numpy. Photos are only EXIF-oriented, uniformly
resampled, and fitted inside the existing portrait aperture. Originals remain
untouched. No generative editing or content retouching is used.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game/assets/surfaces"
FAMILY = ROOT / "game/assets/family"
EVIDENCE = ROOT / "work/lemondev/2026-10-05/visuals"
SIZE = 512
RNG = np.random.default_rng(3803)


def noise(freq: int, size: int = SIZE) -> np.ndarray:
    source = (RNG.random((freq, freq)) * 255).astype(np.uint8)
    return np.asarray(Image.fromarray(source).resize((size, size), Image.Resampling.BICUBIC), dtype=float) / 255


def maps(name: str, color: np.ndarray, height: np.ndarray, roughness: np.ndarray, strength: float = 1.0) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    color = np.broadcast_to(color, (*height.shape, 3))
    Image.fromarray(np.clip(color, 0, 255).astype(np.uint8)).save(OUT / f"{name}_color.jpg", quality=94, subsampling=0)
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * strength
    dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * strength
    normal = np.stack((-dx, dy, np.ones_like(height)), axis=-1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    Image.fromarray(((normal * .5 + .5) * 255).astype(np.uint8)).save(OUT / f"{name}_normal.png", optimize=True)
    Image.fromarray((np.clip(roughness, 0, 1) * 255).astype(np.uint8)).save(OUT / f"{name}_roughness.jpg", quality=95)


def cloth(name: str, color: tuple[int, int, int], roughness: float, grain: float = 1.0) -> None:
    y, x = np.indices((SIZE, SIZE))
    warp = np.sin(x * np.pi / 3) * .5 + .5
    weft = np.sin(y * np.pi / 3) * .5 + .5
    crossing = np.where((x // 3 + y // 3) % 2 == 0, warp * .8 + weft * .2, warp * .2 + weft * .8)
    fiber = noise(220)
    h = crossing * .52 + fiber * .16 + noise(30) * .08
    c = np.array(color)[None, None, :] * (.91 + crossing[..., None] * .13 + (fiber[..., None] - .5) * .09)
    maps(name, c, h, roughness + (crossing - .5) * .08, grain)


def generate() -> dict:
    cloth("brown_weave", (109, 79, 56), .87, .66)
    cloth("linen", (193, 175, 147), .93, .47)
    cloth("crib_canvas", (135, 139, 140), .92, .59)
    cloth("rug", (171, 154, 130), .99, .95)
    h = noise(210) * .68 + noise(80) * .20 + noise(16) * .12
    y, x = np.indices((SIZE, SIZE))
    wrinkles = np.sin(x * .026 + noise(25) * 5) ** 12 * .04
    maps("leather", np.array([79, 51, 40])[None, None, :] * (.87 + h[..., None] * .25), h + wrinkles, .48 + (h - .5) * .13, .60)
    grain = np.sin(y * .28 + np.sin(x * .021) * 2.7 + noise(16) * 4)
    pores = noise(170)
    h = grain * .06 + pores * .09
    c = np.array([142, 93, 53])[None, None, :] * (1 + grain[..., None] * .055 + (pores[..., None] - .5) * .11)
    maps("oak", c, h, .50 + grain * .04 + (pores - .5) * .07, 1.4)
    maps("darkwood", c * np.array([.58, .56, .58])[None, None, :], h, .39 + grain * .045, 1.2)
    plaster = noise(140) * .7 + noise(36) * .3
    maps("plaster", np.array([213, 204, 188])[None, None, :] * (.985 + plaster[..., None] * .025), plaster * .12, .84 + (plaster - .5) * .05, .65)
    # Fine stone veins, with a calm base that preserves the room's cream palette.
    size = 1024
    base = Image.new("RGB", (size, size), (210, 203, 189))
    d = ImageDraw.Draw(base)
    veins = Image.new("L", (size, size), 0)
    vd = ImageDraw.Draw(veins)
    r = np.random.default_rng(3800)
    for i in range(9):
        start = int(r.integers(-600, 1000))
        pts = [(int(start + z * .8 + 27 * np.sin(z * .008 + i) + r.uniform(-9, 9)), z) for z in range(-40, 1070, 18)]
        width = int(r.choice([1, 1, 2, 3, 4]))
        vd.line(pts, fill=int(r.integers(60, 175)), width=width)
        if i % 3 == 0:
            px, py = pts[30]
            vd.line([(px, py), (px + 55, py + 23), (px + 92, py + 78), (px + 167, py + 102)], fill=90, width=1)
    vein = np.asarray(veins.filter(ImageFilter.GaussianBlur(.8)), dtype=float) / 255
    mottled = noise(28, size) * .55 + noise(130, size) * .45
    stone = np.array([210, 203, 189])[None, None, :] * (.977 + mottled[..., None] * .043)
    stone -= vein[..., None] * np.array([93, 82, 64])[None, None, :]
    maps("marble", stone, vein * .035 + mottled * .02, .26 + mottled * .065 + vein * .075, 1)
    # Leaf color, ribbing and veins are aligned to each leaf's UVs.
    y, x = np.indices((256, 256))
    u, v = x / 255, y / 255
    rib = np.exp(-((u - .5) / .012) ** 2)
    lines = np.exp(-(np.sin((v * 12 + abs(u - .5) * 8) * np.pi) / .1) ** 2)
    shade = 1 - abs(u - .5) * .55 + noise(38, 256) * .08
    c = np.array([54, 94, 43])[None, None, :] * shade[..., None]
    c += (rib * 8 + lines * 3)[..., None]
    maps("leaf", c, rib * .15 + lines * .07, .55 + abs(u - .5) * .12, 1.5)
    # Screen is off until solved; a restrained gradient gives the glass a surface.
    y, x = np.indices((256, 512))
    sheen = np.clip(1 - ((x - 80) / 500 + y / 300), 0, 1) ** 2
    Image.fromarray(np.clip(np.array([9, 12, 14])[None, None, :] + sheen[..., None] * np.array([7, 10, 12])[None, None, :], 0, 255).astype(np.uint8)).save(OUT / "screen_color.jpg", quality=94)
    return {"seed": 3803, "maps": sorted(p.name for p in OUT.iterdir() if p.is_file() and not p.name.endswith(".import")), "normalEncoding": "OpenGL +Y tangent normals, no alpha", "memoryBudget": "512 primary detail maps, 1024 shared marble, 256 leaf"}


def photos() -> list[dict]:
    sources = [
        Path(r"E:/DSLR/000 - My Babies/_DSF3803.JPG"),
        Path(r"E:/DSLR/000 - My Babies/_DSF3800.JPG"),
        Path(r"E:/DSLR/000 - My Babies/Azrin Pic1.png"),
        Path(r"E:/DSLR/000 - My Babies/Azraellll.png"),
        Path(r"E:/DSLR/000 - My Babies/Azrin and Azrael.png"),
        Path(r"E:/DSLR/000 - My Family/2 Bbs.jpg"),
        Path(r"E:/DSLR/000 - My Family/15ed4ec2-8954-4d3b-84f9-3550b80f3a69.jpg"),
        Path(r"E:/DSLR/000 - My Family/870671d7-24d2-4cac-9f24-b6e876dbfff2.jpg"),
    ]
    FAMILY.mkdir(parents=True, exist_ok=True)
    manifest = []
    for i, source in enumerate(sources):
        before = hashlib.sha256(source.read_bytes()).hexdigest()
        with Image.open(source) as photo:
            original_size = list(photo.size)
            oriented = ImageOps.exif_transpose(photo).convert("RGB")
            resized = ImageOps.contain(oriented, (756, 1024), Image.Resampling.LANCZOS)
            canvas = Image.new("RGB", (756, 1024), (226, 218, 201))
            canvas.paste(resized, ((756 - resized.width) // 2, (1024 - resized.height) // 2))
            target = FAMILY / f"family_{i}.jpg"
            canvas.save(target, quality=95, subsampling=0)
        after = hashlib.sha256(source.read_bytes()).hexdigest()
        assert before == after, source
        manifest.append({"index": i, "source": str(source), "sourceSha256": before, "sourceUnchanged": before == after, "originalSize": original_size, "imageSize": list(oriented.size), "resampledContentSize": list(resized.size), "texture": f"res://assets/family/family_{i}.jpg", "textureSha256": hashlib.sha256(target.read_bytes()).hexdigest(), "method": "EXIF orientation; full-image uniform Lanczos fit; warm paper margin; no crop or retouch"})
    return manifest


if __name__ == "__main__":
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    report = {"surfaces": generate(), "photos": photos()}

    # These sidecars are created on first Godot import. Tracked import settings
    # make mip behavior and normal-map compression reproducible in exports.
    for directory in (OUT, FAMILY):
        for sidecar in directory.glob("*.import"):
            config = sidecar.read_text(encoding="utf-8")
            config = config.replace("mipmaps/generate=false", "mipmaps/generate=true")
            config = config.replace("compress/mode=0", "compress/mode=2")
            if "_normal." in sidecar.name:
                config = config.replace("compress/normal_map=0", "compress/normal_map=1")
            sidecar.write_text(config, encoding="utf-8")
    (FAMILY / "provenance.json").write_text(json.dumps(report["photos"], indent=2), encoding="utf-8")
    (EVIDENCE / "asset-generation.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps({"maps": len(report["surfaces"]["maps"]), "photos": len(report["photos"]), "originalsUnchanged": all(p["sourceUnchanged"] for p in report["photos"])}))
