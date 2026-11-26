"""Download the human hand models the player's first-person arms are built on.

They are the Godot XR Tools hands by DigitalN8m4r3 (Miodrag Sejic): a MakeHuman hand, left and right, rigged to the
OpenXR hand skeleton, with nails, skin textures, a normal map and an occlusion/roughness/metallic map. CC0 1.0.
https://github.com/GodotVR/godot-xr-tools/tree/master/addons/godot-xr-tools/hands

    python -I tools/assets/fetch_hands.py   # into .local/downloads/xr_hands
"""
import os
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CACHE = os.path.join(ROOT, ".local", "downloads", "xr_hands")
# Pinned to a commit so the files cannot change under the build.
BASE = "https://raw.githubusercontent.com/GodotVR/godot-xr-tools/%s/addons/godot-xr-tools/hands/"
FILES = [
    "License.md",
    "About.md",
    "model/Hand_Nails_L.gltf",
    "model/Hand_Nails_R.gltf",
    "model/Hand_Nails_low_L.gltf",
    "model/Hand_Nails_low_R.gltf",
    "model/Hand_Glove_L.gltf",
    "model/Hand_Glove_R.gltf",
    "textures/caucasian_realistic_baseColor.png",
    "textures/african_realistic_baseColor.png",
    "textures/caucasian_baseColor.png",
    "textures/african_baseColor.png",
    "textures/hands_normal.png",
    "textures/hands_occlusionRoughnessMetallic.png",
]


def main():
    commit = "master"
    pin = os.path.join(CACHE, "COMMIT.txt")
    os.makedirs(CACHE, exist_ok=True)
    if os.path.exists(pin):
        commit = open(pin).read().strip()
    else:
        import json
        with urllib.request.urlopen("https://api.github.com/repos/GodotVR/godot-xr-tools/commits/master") as reply:
            commit = json.load(reply)["sha"]
        open(pin, "w").write(commit + "\n")
    for name in FILES:
        dst = os.path.join(CACHE, name.replace("/", os.sep))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if not os.path.exists(dst):
            urllib.request.urlretrieve(BASE % commit + name, dst)
        print(name, os.path.getsize(dst) // 1024, "KB")
    print("commit", commit)


if __name__ == "__main__":
    main()
