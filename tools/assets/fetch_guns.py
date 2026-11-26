"""0.48: download the CC-BY Sketchfab gun models behind the named arsenal (scripts/arsenal.gd).

They come from the Objaverse mirror on Hugging Face (allenai/objaverse), keyed by Sketchfab uid, like
tools/assets/fetch_objaverse.py. tools/blender/story/process_guns.py turns them into game/assets/models/guns/*.glb.

    python -I tools/assets/fetch_guns.py   # into .local/downloads/guns/raw
"""
import gzip, json, os, sys, time, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CACHE = os.path.join(ROOT, '.local', 'downloads', 'guns')
HF = 'https://huggingface.co/datasets/allenai/objaverse/resolve/main/'

# game id -> Sketchfab uid (titles and authors: game/licenses/THIRD_PARTY_MODELS.md)
MODELS = {
    # pistols
    "beretta_hi91": "94b88255551048d7990252946b5195be",
    "eruption_ad15": "cabde59f5cf24effaf80536e35d04e95",
    "sauer_p9": "d1200d9aa28f466484f7d3fdd7724e76",
    "magnum_vex": "360c6276282e48109fcca66f31004d81",
    # rifles
    "gtk44": "46a36e92379341d495fdcd7750a7ebc3",
    "kestrel_k74": "9084c3bae8224d338103997bc3101480",
    "viper_v9": "609166faf8e5416f957c88e0af657e09",
    "hornet_mp9": "c503d96157614fb78b5953d49e643b78",
    "bastion_s17": "0d425f857113401ea36031a293d98a1c",
    "garrison_m1": "1be4bb0f8c05423abdccb50b779de6e6",
    "corsair_m4": "c417b8a56e4447fe9d627000dd305f32",
    "sentry_sk45": "ea48b79acd354e4d8aa5ac901218ae5e",
    "auger_a3": "5d6189495ac4406f82eca848bbb6fa95",
    "talon_p90": "9874e6e36c1244acbdcd1ab00980c834",
    # sniper rifles
    "longreach_m40": "9167543c8cee476a9c027dd9e6f5aee4",
    "drakon_svd": "d4a9412275aa4974b146ad8ce9dc5fc2",
    "titan_b50": "1b35aaab9d454a169b66513767607124",
    # shotguns
    "gausser_db": "99734ee367dc4872b6183412c9d76a4c",
    "spartan_s12": "a0f118ec8a984f09b602fb3a54f56a9e",
    "tempest_a14": "7f88ac8b30084142b74443bfd173b33d",
    "ironside_m37": "afba0a8e8ab341c7a8d1f7b8019c5c49",
}

def main():
    raw = os.path.join(CACHE, 'raw')
    os.makedirs(raw, exist_ok=True)
    index = os.path.join(CACHE, 'paths.json.gz')
    if not os.path.exists(index):
        urllib.request.urlretrieve(HF + 'object-paths.json.gz', index)
    paths = json.load(gzip.open(index, 'rt'))
    only = sys.argv[1:]
    for name, uid in MODELS.items():
        if only and name not in only:
            continue
        dst = os.path.join(raw, name + '.glb')
        for attempt in range(5):
            if os.path.exists(dst):
                break
            try:
                urllib.request.urlretrieve(HF + paths[uid], dst + '.part')
                os.replace(dst + '.part', dst)
            except Exception as e:
                print('retry', name, e)
                time.sleep(3 + attempt * 3)
        print(name, os.path.getsize(dst) // 1024 if os.path.exists(dst) else 'FAILED', 'KB')

if __name__ == '__main__':
    main()
