"""Download the CC0 1K PBR sets used by the dim neighborhood and retain provenance."""
import hashlib
import json
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2] / "game/assets/outdoor/textures"
SETS = {
    "rusty_metal_04": ("Rusty Metal 04", "Amal Kumar"),
    "damaged_plaster": ("Damaged Plaster", "Amal Kumar"),
    "rough_plaster_broken": ("Rough Plaster Broken", "Rob Tuytel"),
}


def get(url):
    return urlopen(Request(url, headers={"User-Agent": "InteriorGameAssetImport/0.14"}), timeout=60).read()


for asset, (title, author) in SETS.items():
    folder = ROOT / asset
    folder.mkdir(parents=True, exist_ok=True)
    if (folder / "source.json").exists() and all((folder / f).exists() for f in ("albedo.jpg", "normal.jpg", "roughness.jpg")):
        continue
    data = json.loads(get("https://api.polyhaven.com/files/" + asset))
    maps = []
    for aliases, filename in [(("Diffuse", "diff"), "albedo.jpg"), (("nor_gl",), "normal.jpg"), (("Rough", "rough"), "roughness.jpg")]:
        key = next(k for k in aliases if k in data)
        spec = data[key]["1k"]["jpg"]
        content = get(spec["url"])
        if hashlib.md5(content).hexdigest() != spec["md5"]:
            raise ValueError("Download checksum mismatch: " + filename)
        (folder / filename).write_bytes(content)
        maps.append({"file": filename, "url": spec["url"], "sha256": hashlib.sha256(content).hexdigest()})
    (folder / "source.json").write_text(json.dumps({"asset": title, "author": author,
        "source": "https://polyhaven.com/a/" + asset, "license": "CC0-1.0", "retrieved": "2026-10-07", "maps": maps}, indent=2))
    print("Downloaded " + title)
