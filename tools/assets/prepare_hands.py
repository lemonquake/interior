"""The player's hand textures, from the downloaded hand set (tools/assets/fetch_hands.py, CC0).

    python -I tools/assets/prepare_hands.py [mix]   # into game/assets/characters/hands/

  hand_skin.png    base colour: the set's two realistic skins mixed (`mix` of the darker one, default 0.42), so the
                   hands are a Filipino brown rather than either extreme
  hand_normal.png  the set's normal map
  hand_orm.png     occlusion / roughness / metallic
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, ".local", "downloads", "xr_hands", "textures")
OUT = os.path.join(ROOT, "game", "assets", "characters", "hands")


def main():
    mix = float(sys.argv[1]) if len(sys.argv) > 1 else 0.42
    os.makedirs(OUT, exist_ok=True)
    light = Image.open(os.path.join(SRC, "caucasian_realistic_baseColor.png")).convert("RGB")
    dark = Image.open(os.path.join(SRC, "african_realistic_baseColor.png")).convert("RGB")
    Image.blend(light, dark, mix).save(os.path.join(OUT, "hand_skin.png"))
    Image.open(os.path.join(SRC, "hands_normal.png")).convert("RGB").save(os.path.join(OUT, "hand_normal.png"))
    Image.open(os.path.join(SRC, "hands_occlusionRoughnessMetallic.png")).convert("RGB").save(os.path.join(OUT, "hand_orm.png"))
    for name in ("hand_skin.png", "hand_normal.png", "hand_orm.png"):
        print(name, os.path.getsize(os.path.join(OUT, name)) // 1024, "KB")


if __name__ == "__main__":
    main()
