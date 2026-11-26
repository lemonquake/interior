"""Download everything the Nichols property needs (0.21): PBR surfaces, furniture, garden and trees, door sounds.

    python tools/assets/fetch_nichols.py

Textures go straight to game/assets/outdoor/textures/<id>/ (albedo, GL normal, roughness; 2k for the big
surfaces). Models land in .local/downloads/{polyhaven,objaverse}/ and are converted by
tools/blender/process_downloads.py (entries marked "0.21 Nichols") into game/assets/models/nichols/.
Sounds are trimmed, made mono and normalised into game/assets/audio/nichols/.
Credits: .local/downloads/nichols_credits.json (copied into game/licenses/).
"""
import gzip, json, os, re, sys, time, urllib.parse, urllib.request
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fetch_fields import get, ph_api, polyhaven_jobs, commons, DL, ROOT, UA  # noqa: E402

TEXTURE_OUT = os.path.join(ROOT, 'game', 'assets', 'outdoor', 'textures')
# id -> resolution
TEXTURES = {
    'decrepit_wallpaper': '2k', 'old_wood_floor': '2k', 'weathered_plank_siding': '2k', 'roof_slates_02': '2k',
    'old_stone_wall': '2k', 'dark_paneled_wood': '2k', 'wood_floor_worn': '1k', 'dirty_carpet': '1k',
    'wood_peeling_paint_weathered': '1k', 'mossy_stone_wall': '1k', 'worn_mossy_plasterwall': '2k',
    'mossy_cobblestone': '1k', 'gravel_road': '1k', 'stony_dirt_path': '1k', 'forest_leaves_02': '1k',
    'dry_decay_leaves': '1k', 'rusty_metal': '1k', 'floral_jacquard': '1k', 'velour_velvet': '1k',
    'weathered_planks': '1k', 'ceiling_interior': '1k', 'worn_cracked_plaster': '1k', 'marble_tiles': '1k',
    'wood_cabinet_worn_long': '1k', 'leaves_forest_ground': '1k', 'worn_planks': '1k', 'red_brick': '1k', 'mossy_brick': '1k',
}
# Poly Haven, CC0 (1k glTF).
POLYHAVEN = [
    'large_iron_gate', 'gothic_statue', 'marble_bust_01', 'lion_head', 'concrete_cat_statue', 'horse_statue_01',
    'dead_quiver_trunk', 'dry_branches_medium_01', 'tree_stump_02', 'root_cluster_02', 'pine_roots', 'bark_debris_01',
    'ArmChair_01', 'Sofa_01', 'GothicBed_01', 'GothicCabinet_01', 'GothicCommode_01', 'ClassicConsole_01',
    'ClassicNightstand_01', 'GreenChair_01', 'WoodenChair_01', 'Rockingchair_01', 'gothic_coffee_table', 'dining_table',
    'dining_chair_02', 'vintage_grandfather_clock_01', 'mantel_clock_01', 'ornate_mirror_01', 'fancy_picture_frame_02',
    'hanging_picture_frame_01', 'hanging_picture_frame_02', 'hanging_picture_frame_03', 'standing_picture_frame_01',
    'Chandelier_01', 'Chandelier_02', 'brass_candleholders', 'wooden_candlestick', 'vintage_oil_lamp',
    'antique_ceramic_vase_01', 'ceramic_vase_02', 'ceramic_vase_04', 'brass_vase_03', 'wooden_bookshelf_worn',
    'decorative_book_set_01', 'old_bed_frame', 'wheelchair_01', 'vintage_suitcase', 'vintage_cabinet_01',
    'spinning_wheel_01', 'tea_set_01', 'wine_bottles_01', 'Lantern_01', 'vintage_wooden_drawer_01', 'CoffeeTable_01',
    'Ottoman_01', 'round_wooden_table_01', 'chess_set', 'vintage_crutches_01', 'wooden_crate_02', 'treasure_chest',
]
# Sketchfab CC-BY through the Objaverse mirror.
OBJAVERSE = {
    'dusty_piano': 'abdb095ac525489a92236227f72631c4',        # "Dusty old piano"
    'antique_doll': 'a0a494a8c3db4cc4ad10cb433125fe78',       # "3D Antique Doll"
    'porcelain_doll': '9ef34eb03f0a42978b3a9d20f0f8f389',     # "Porcelain Polly"
    'rocking_horse': 'cef5f4c0aece4e8f8d670c0f27114d69',      # "Rocking Horse"
    'cobwebs': '2dd4798676d84bc7af5d2a8f5834563a',            # "Cobwebs Asset Pack"
    'candelabra': '1df1dc5fc6e84a189460329bc5715cea',         # "Old Candelabra"
    'crow': 'd5a9b0df4da3493688b63ce42c8a83e2',               # "Crow"
    'crow_b': '45a169ef98804f06a9b7a4af1a04d6f9',             # "Crow"
    'dead_tree_a': '3cb4d59eb4844dc4802480e9ee53785e',        # "Old tree"
    'dead_tree_b': 'fb210972a50049c48229e67d04d66995',        # "Dead Tree"
    'dead_tree_c': '3f050640e5d245ccb458aa5184f241e7',        # "Spooky Tree"
    'dead_tree_d': '14f1a670f2c0449abc5ba2320d462d92',        # "haunted tree"
    'dead_tree_e': 'df8cdc5ea25449d28306089cff616195',        # "Creepy Forest Tree"
    'iron_fence': 'fbe7e012b6ae49e3bcf9530147695351',         # "Decorative iron Fence"
    'lamp_post_victorian': 'c4c987c8e9c24969964749f1312ca3e1', # "Victorian Lamp Post #2"
    'cemetery': '8ff44ad4f5944d0493b5342e7def1d8d',           # "Cemetery Scene"
    'grand_piano_old': 'c7c82e2445544191b541f2240ae8c4e7',    # "Old Wooden Grand Piano"
}
# Wikimedia Commons recordings: out name -> (file title, start s, length s or 0 for all)
SOUNDS = {
    'door_open_a': ('Open squeaky door (Gravity Sound).wav', 0.0, 0),
    'door_open_b': ('Open squeaky door 2 (Gravity Sound).wav', 0.0, 0),
    'door_open_c': ('Open squeaky door 3 (Gravity Sound).wav', 0.0, 0),
    'door_open_d': ('Open squeaky door 4 (Gravity Sound).wav', 0.0, 0),
    'door_close_a': ('Close squeaky door (Gravity Sound).wav', 0.0, 0),
    'door_close_b': ('Close squeaky door 2 (Gravity Sound).wav', 0.0, 0),
    'hinge_squeak': ('Squeaky door hinge.ogg', 0.0, 0),
    'door_squeak': ('Squeaky door.ogg', 0.0, 0),
    'handle_creak': ('Door handle creaking.ogg', 0.0, 0),
    'gate_clasp': ('Rusty metal door clasp.ogg', 0.0, 0),
    'wind_howl': ('Howling wind.ogg', 0.0, 0),
}
AUDIO_OUT = os.path.join(ROOT, 'game', 'assets', 'audio', 'nichols')


def process_audio(src, dst, start, length):
    import numpy as np, soundfile as sf
    from scipy.signal import butter, sosfiltfilt, resample_poly
    data, rate = sf.read(src, always_2d=True)
    mono = data.mean(axis=1)
    a = int(start * rate)
    mono = mono[a:a + int(length * rate)] if length else mono[a:]
    if rate != 44100:
        from math import gcd
        g = gcd(int(rate), 44100)
        mono = resample_poly(mono, 44100 // g, int(rate) // g)
        rate = 44100
    mono = sosfiltfilt(butter(4, 60, 'highpass', fs=rate, output='sos'), mono)
    # Trim leading / trailing silence (keep 20 ms of air either side).
    level = np.abs(mono)
    loud = np.where(level > level.max() * .02)[0]
    if loud.size:
        pad = int(rate * .02)
        mono = mono[max(0, loud[0] - pad):min(len(mono), loud[-1] + pad * 10)]
    mono = mono / (np.max(np.abs(mono)) or 1.0) * .89
    fade = int(rate * .01)
    mono[:fade] *= np.linspace(0, 1, fade)
    mono[-fade * 4:] *= np.linspace(1, 0, fade * 4)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with sf.SoundFile(dst, 'w', rate, 1, format='OGG', subtype='VORBIS') as out:
        block = mono.astype('float32')
        for i in range(0, len(block), 2048):
            out.write(block[i:i + 2048])
    return round(len(mono) / rate, 2)


def main():
    credits = {'polyhaven': {}, 'objaverse': {}, 'sounds': {}}
    jobs = []
    for asset, res in TEXTURES.items():
        files = ph_api('files/' + asset)
        for key, name in [('Diffuse', 'albedo'), ('nor_gl', 'normal'), ('Rough', 'roughness')]:
            if key in files:
                r = res if res in files[key] else '1k'
                jobs.append((files[key][r]['jpg']['url'], os.path.join(TEXTURE_OUT, asset, name + '.jpg')))
    for asset in POLYHAVEN:
        try:
            jobs += polyhaven_jobs(asset)
        except Exception as error:
            print('polyhaven missing', asset, error)
    with ThreadPoolExecutor(8) as pool:
        list(pool.map(lambda job: get(*job), jobs))
    info = ph_api('assets?t=all')
    for asset in list(TEXTURES) + POLYHAVEN:
        if asset in info:
            credits['polyhaven'][asset] = dict(name=info[asset]['name'], authors=list(info[asset].get('authors', {})),
                                               license='CC0', url='https://polyhaven.com/a/' + asset)
    print('polyhaven:', len(jobs), 'files')
    index = os.path.join(DL, 'objaverse', 'object-paths.json.gz')
    get('https://huggingface.co/datasets/allenai/objaverse/resolve/main/object-paths.json.gz', index)
    paths = json.load(gzip.open(index, 'rt'))
    for name, uid in OBJAVERSE.items():
        try:
            get('https://huggingface.co/datasets/allenai/objaverse/resolve/main/' + paths[uid], os.path.join(DL, 'objaverse', name + '.glb'))
        except Exception as error:
            print('objaverse failed', name, error)
            continue
        try:
            meta = json.load(urllib.request.urlopen(urllib.request.Request('https://api.sketchfab.com/v3/models/' + uid, headers=UA), timeout=30))
            credits['objaverse'][name] = dict(title=meta.get('name'), author=meta.get('user', {}).get('displayName'),
                                              username=meta.get('user', {}).get('username'), license=(meta.get('license') or {}).get('label'),
                                              url='https://sketchfab.com/3d-models/' + uid)
        except Exception as error:
            credits['objaverse'][name] = dict(uid=uid, error=str(error))
        print('objaverse:', name, os.path.getsize(os.path.join(DL, 'objaverse', name + '.glb')) // 1024, 'KB', credits['objaverse'][name].get('license'))
    titles = ['File:' + spec[0] for spec in SOUNDS.values()]
    pages = {}
    for i in range(0, len(titles), 10):
        res = commons({'action': 'query', 'titles': '|'.join(titles[i:i + 10]), 'prop': 'imageinfo',
                       'iiprop': 'url|extmetadata', 'iiextmetadatafilter': 'LicenseShortName|Artist|Credit'})
        for page in res['query']['pages'].values():
            pages[page['title']] = page
        time.sleep(2)
    for out, (title, start, length) in SOUNDS.items():
        page = pages.get('File:' + title)
        if page is None or 'imageinfo' not in page:
            print('missing sound', title)
            continue
        ii = page['imageinfo'][0]
        meta = ii.get('extmetadata', {})
        try:
            src = get(ii['url'], os.path.join(DL, 'commons', re.sub(r'[^\w.\-]+', '_', title)))
        except Exception as error:
            print('skipped sound', title, error)
            continue
        time.sleep(6)
        try:
            seconds = process_audio(src, os.path.join(AUDIO_OUT, out + '.ogg'), start, length)
        except Exception as error:
            print('unreadable sound', title, error)
            continue
        credits['sounds'][out] = dict(title=title, author=re.sub('<[^>]+>', '', meta.get('Artist', {}).get('value', '')).strip(),
                                      license=meta.get('LicenseShortName', {}).get('value'), seconds=seconds,
                                      url='https://commons.wikimedia.org/wiki/File:' + urllib.parse.quote(title.replace(' ', '_')))
        print('sound:', out, seconds, 's', credits['sounds'][out]['license'])
    json.dump(credits, open(os.path.join(DL, 'nichols_credits.json'), 'w', encoding='utf-8'), indent=1, ensure_ascii=False)


if __name__ == '__main__':
    sys.exit(main())
