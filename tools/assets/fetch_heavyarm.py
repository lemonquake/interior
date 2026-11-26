"""0.53: download the CC-BY sculpt behind Heavy-arm ("Boss Zombie Sculpted" by shaz13, Sketchfab
fa85d0ef26bd4dba9445ff5dd3baa1bd) from the Objaverse mirror on Hugging Face, like tools/assets/fetch_guns.py.
tools/blender/human/build_heavyarm.py turns it into game/assets/characters/zombies/heavyarm.glb.

    python -I tools/assets/fetch_heavyarm.py   # into .local/downloads/heavyarm/raw/boss_zombie.glb
"""
import os, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, '.local', 'downloads', 'heavyarm', 'raw', 'boss_zombie.glb')
URL = 'https://huggingface.co/datasets/allenai/objaverse/resolve/main/glbs/000-040/fa85d0ef26bd4dba9445ff5dd3baa1bd.glb'

if __name__ == '__main__':
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    if not os.path.exists(OUT):
        urllib.request.urlretrieve(URL, OUT + '.part')
        os.replace(OUT + '.part', OUT)
    print(OUT, os.path.getsize(OUT) // 1024, 'KB')
