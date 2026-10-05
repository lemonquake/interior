"""Download the CC-BY Sketchfab models used by the studio and neighbourhood.

They come from the Objaverse mirror on Hugging Face (allenai/objaverse), keyed by Sketchfab uid.

    python tools/assets/fetch_objaverse.py   # into .local/downloads/objaverse
"""
import gzip, json, os, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CACHE = os.path.join(ROOT, '.local', 'downloads', 'objaverse')
HF = 'https://huggingface.co/datasets/allenai/objaverse/resolve/main/'

MODELS = {
    "guitar_ibanez": "daeadd913644438aa3096bb357a02016",
    "guitar_sg": "2007af7561fe46958d1f7e92dff8a40d",
    "guitar_lespaul": "d75216a52ff14a56aa40b6fec844ecd2",
    "guitar_acoustic_a": "f8ccd75e8c2648ffbbc9e6208ed919c1",
    "guitar_acoustic_b": "b52fcec4b641493f8939c50c253c4ac3",
    "bass_precision": "79294354b1f5484cb8881feba4684af1",
    "drum_kit": "99218427e7a2424ea8afc9b8c668a5c7",
    "synth_wood": "736c46af07c54a7fb0eb6f93a6398cdf",
    "synth_b": "d08405ec155e429fa7f608e03552a4cc",
    "midi_controller": "1d5198102a4746c48f68fc30817479ba",
    "amp_marshall": "cd52e1b5299a40968f44c209899b4597",
    "amp_orange": "be36a541b49e4187966ba83a50a24138",
    "audio_interface": "ff1fa96845354c189d6e8df6e4264ae1",
    "studio_monitor_krk": "5c03f6b1082a4decb33ae7511209271a",
    "mic_boom_stand": "9bee76120cd8472b9f68db91d820f5ff",
    "headphones_sony": "05735b74d3524f00b648231138122a28",
    "gaming_chair": "601afdea98f14c488ee0be0ffb4b92dd",
    "guitar_stand": "f542226cabfd48a9b3e61bc0b285c3a1",
    "monitor_curved_pc": "ad00f460c13743a8bd1f91c230c7142c",
    "palm_coconut_a": "26e787f2ff2e4c0fb004c3b0210805a3",
    "palm_coconut_b": "20f8a8d5054b4191afb7cf3270dbd586",
    "tree_mango": "4b186052228d43d8b3fbb63213677de8",
    "banana_small": "7186ebfc24fc42c599f81713cd28d55e",
    "banana_plant": "3b658ecad29f4d9a9606dbf8fea7c9bb"
}

def main():
    os.makedirs(CACHE, exist_ok=True)
    index = os.path.join(CACHE, 'object-paths.json.gz')
    if not os.path.exists(index):
        urllib.request.urlretrieve(HF + 'object-paths.json.gz', index)
    paths = json.load(gzip.open(index, 'rt'))
    for name, uid in MODELS.items():
        dst = os.path.join(CACHE, name + '.glb')
        if not os.path.exists(dst):
            urllib.request.urlretrieve(HF + paths[uid], dst)
        print(name, os.path.getsize(dst) // 1024, 'KB')

if __name__ == '__main__':
    main()
