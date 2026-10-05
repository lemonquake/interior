"""Download everything the 0.7 night fields need (rice paddies, dirt road, pond, night sky, night sounds).

    python tools/assets/fetch_fields.py                 # downloads + processes the audio and the moon map

Models land in .local/downloads/{polyhaven,objaverse}/ and are converted by
tools/blender/process_downloads.py (entries marked "0.7 fields"). The moon colour map goes straight to
game/assets/fields/sky/, the night recordings are trimmed, made mono, high-passed, normalised (and
crossfaded where they loop) into game/assets/audio/night/. Credits: .local/downloads/fields_credits.json,
copied by hand into game/licenses/THIRD_PARTY_MODELS.md and game/licenses/NIGHT_SOUNDS.md.
"""
import gzip, json, os, re, sys, time, urllib.parse, urllib.request
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DL = os.path.join(ROOT, '.local', 'downloads')
UA = {'User-Agent': 'interior-asset-fetch/1.0 (Interior game by Aljay Leodones; github.com/lemonquake/interior)'}

# Poly Haven, CC0 (1k glTF).
POLYHAVEN = ['grass_medium_01', 'grass_medium_02', 'fern_02', 'nettle_plant', 'weed_plant_02', 'dead_tree_trunk',
             'dead_tree_trunk_02', 'tree_stump_01', 'root_cluster_01', 'rock_moss_set_01', 'boulder_01',
             'modular_electricity_poles', 'wooden_lantern_01', 'wooden_bucket_02', 'island_tree_03']
# Poly Haven, CC0 PBR surfaces (1k albedo, GL normal, roughness) into game/assets/outdoor/textures/<id>/.
TEXTURES = ['muddy_tracks', 'brown_mud_02', 'withered_grass', 'leafy_grass']
TEXTURE_OUT = os.path.join(ROOT, 'game', 'assets', 'outdoor', 'textures')
# Sketchfab CC-BY, through the Objaverse mirror (Sketchfab uid).
OBJAVERSE = {
    'bahay_kubo_a': '9d4f540f5a2b4aa1aaf755250eda6875',      # "Bahay Kubo" by kidomanait
    'bahay_kubo_b': '306744c239b9421b882bbb3c52e2e125',      # "Bahay Kubo" by 97burzummayhem
    'nipa_hut': 'aebcebfc4eea4cd1b19dc704f523e955',          # "Building Nipa Hut" by tworeelersgames
    'scarecrow': '537a7926a30049e2b89a22e813a70f94',         # "Scarecrow" by drop05
    'scarecrow_b': '3c5c4892653144449265056f891b8949',       # "Scarecrow Sally" by samir.kazah
    'banyan': '704d83ff28c84dd487ef7dbfdbcdf2fb',            # "BANYAN TREE" by jimmygunawan
    'banyan_b': '9f762442261f43a89b6abaa7e5707e62',          # "Banyan Tree 001" by lawrencetrigg1989
    'bamboo': 'a02bf0e3ffe44617ad49daf3cd94fe59',            # "bamboo" by evolveduk
    'bamboo_set': 'e9f9fa5397814f81bf85ad06acf5bf30',        # "Free Bamboo Set" by JonhGillessen
    'lily_pads': '771d7afe86c74a66aa79f51e831b78e2',         # "Lily pads" by maxkuilman
    'cattails': '2f35ed566d3d4d74abd6e7c48d82f8eb',          # "Cattails" by AlkaliDragon
    'reeds_pack': 'bc77ea5218e44f2dbc23b2a4aef0c898',        # "Reed Plants Pack" by Nicholas01
    'carabao': 'a36a1abfa5ff4fb8b6131e821d94dff2',           # "Carabao" by salarchana55
    'rice_field': '7a077bd3c27c41f0a831c6a11b005c8b',        # "Rice Field" by jessica.novita
    'wooden_bridge': 'fad4dce3ee1541e38b5186a0bc163549',     # "Simple Wooden Bridge" by Memorie
}
# NASA SVS CGI Moon Kit (LRO colour mosaic), public domain.
MOON = 'https://svs.gsfc.nasa.gov/vis/a000000/a004700/a004720/lroc_color_poles_1k.jpg'
# Wikimedia Commons recordings: out name -> (file title, start s, length s, loop)
SOUNDS = {
    'owl_tawny': ('Strix aluco male.oga', 0.0, 8.3, False),
    'owl_barn_screech': ('Tyto alba - Western Barn Owl XC436946.mp3', 0.0, 7.9, False),
    'gecko_tokay': ('Mating call of a male Tokay gecko (Gekko gecko).ogg', 0.0, 29.0, False),
    'frog_kaloula': ('Kaloula pulchra - dringsim - 1446567.ogg', 0.0, 30.0, True),
    'frog_chorus': ('Frogs croak calling chorus at night.ogg', 10.0, 48.0, True),
    'frog_chorus_b': ('Night Chorus of Frogs and Toads in Niger Delta.ogg', 0.0, 26.0, True),
    'toad_bufo': ('Bufo bufo call1.ogg', 0.0, 17.4, False),
    'cricket_field': ('Field cricket unedited.ogg', 0.0, 10.4, True),
    'cricket_gryllus': ('Cricket Gryllus bimaculatus Chirps.oga', 0.0, 34.0, True),
    'nightjar': ('Caprimulgus europaeus - European Nightjar XC1008591.mp3', 0.0, 15.7, False),
}
AUDIO_OUT = os.path.join(ROOT, 'game', 'assets', 'audio', 'night')
MOON_OUT = os.path.join(ROOT, 'game', 'assets', 'fields', 'sky', 'moon_color.jpg')

def get(url, dst):
    if os.path.exists(dst) and os.path.getsize(dst) > 0:
        return dst
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    for attempt in range(5):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120) as r, open(dst + '.part', 'wb') as f:
                f.write(r.read())
            os.replace(dst + '.part', dst)
            return dst
        except Exception as error:
            if attempt == 4:
                raise
            time.sleep(4 + attempt * 4)

def ph_api(path):
    return json.load(urllib.request.urlopen(urllib.request.Request('https://api.polyhaven.com/' + path, headers=UA)))

def polyhaven_jobs(asset):
    g = ph_api('files/' + asset)['gltf']['1k']['gltf']
    base = os.path.join(DL, 'polyhaven', 'models', asset)
    return [(g['url'], os.path.join(base, asset + '.gltf'))] + [(v['url'], os.path.join(base, rel)) for rel, v in g['include'].items()]

def commons(params):
    url = 'https://commons.wikimedia.org/w/api.php?' + urllib.parse.urlencode(dict(params, format='json'))
    for attempt in range(6):
        try:
            return json.load(urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30))
        except Exception:
            time.sleep(5 + attempt * 5)
    raise RuntimeError('Commons API unavailable')

def process_audio(src, dst, start, length, loop):
    import numpy as np, soundfile as sf
    from scipy.signal import butter, sosfiltfilt, resample_poly
    data, rate = sf.read(src, always_2d=True)
    mono = data.mean(axis=1)
    a = int(start * rate)
    mono = mono[a:a + int(length * rate)]
    if rate != 44100:
        from math import gcd
        g = gcd(int(rate), 44100)
        mono = resample_poly(mono, 44100 // g, int(rate) // g)
        rate = 44100
    # Rumble and handling noise out; keep everything an owl or a toad makes.
    mono = sosfiltfilt(butter(4, 120, 'highpass', fs=rate, output='sos'), mono)
    peak = np.max(np.abs(mono)) or 1.0
    mono = mono / peak * 0.89
    fade = int(rate * (1.5 if loop else 0.05))
    if loop and len(mono) > fade * 3:
        # Equal-power crossfade of the tail into the head: the loop point never clicks.
        w = np.linspace(0, 1, fade)
        head = mono[:fade] * np.sqrt(w) + mono[-fade:] * np.sqrt(1 - w)
        mono = np.concatenate([head, mono[fade:-fade]])
    else:
        mono[:fade] *= np.linspace(0, 1, fade)
        mono[-fade:] *= np.linspace(1, 0, fade)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    # libsndfile 1.2.0 crashes on large single Vorbis writes; small blocks are fine.
    with sf.SoundFile(dst, 'w', rate, 1, format='OGG', subtype='VORBIS') as out:
        block = mono.astype('float32')
        for i in range(0, len(block), 2048):
            out.write(block[i:i + 2048])
    return round(len(mono) / rate, 2)

def main():
    credits = {'polyhaven': {}, 'objaverse': {}, 'sounds': {}, 'moon': {}}
    jobs = []
    for asset in POLYHAVEN:
        jobs += polyhaven_jobs(asset)
    for asset in TEXTURES:
        files = ph_api('files/' + asset)
        for key, name in [('Diffuse', 'albedo'), ('nor_gl', 'normal'), ('Rough', 'roughness')]:
            if key in files:
                jobs.append((files[key]['1k']['jpg']['url'], os.path.join(TEXTURE_OUT, asset, name + '.jpg')))
    with ThreadPoolExecutor(8) as pool:
        list(pool.map(lambda job: get(*job), jobs))
    info = ph_api('assets?t=all')
    for asset in POLYHAVEN + TEXTURES:
        credits['polyhaven'][asset] = dict(name=info[asset]['name'], authors=list(info[asset].get('authors', {})),
                                           license='CC0', url='https://polyhaven.com/a/' + asset)
    print('polyhaven:', len(jobs), 'files')
    index = os.path.join(DL, 'objaverse', 'object-paths.json.gz')
    get('https://huggingface.co/datasets/allenai/objaverse/resolve/main/object-paths.json.gz', index)
    paths = json.load(gzip.open(index, 'rt'))
    for name, uid in OBJAVERSE.items():
        get('https://huggingface.co/datasets/allenai/objaverse/resolve/main/' + paths[uid], os.path.join(DL, 'objaverse', name + '.glb'))
        try:
            meta = json.load(urllib.request.urlopen(urllib.request.Request('https://api.sketchfab.com/v3/models/' + uid, headers=UA), timeout=30))
            credits['objaverse'][name] = dict(title=meta.get('name'), author=meta.get('user', {}).get('displayName'),
                                              username=meta.get('user', {}).get('username'), license=(meta.get('license') or {}).get('label'),
                                              url='https://sketchfab.com/3d-models/' + uid)
        except Exception as error:
            credits['objaverse'][name] = dict(uid=uid, error=str(error))
        print('objaverse:', name, os.path.getsize(os.path.join(DL, 'objaverse', name + '.glb')) // 1024, 'KB')
    get(MOON, MOON_OUT)
    credits['moon'] = dict(title='CGI Moon Kit, LROC colour mosaic (1k)', author='NASA Scientific Visualization Studio / Ernie Wright',
                           license='Public domain (NASA)', url='https://svs.gsfc.nasa.gov/4720')
    titles = ['File:' + spec[0] for spec in SOUNDS.values()]
    pages = {}
    for i in range(0, len(titles), 10):
        res = commons({'action': 'query', 'titles': '|'.join(titles[i:i + 10]), 'prop': 'imageinfo',
                       'iiprop': 'url|extmetadata', 'iiextmetadatafilter': 'LicenseShortName|Artist|Credit'})
        for page in res['query']['pages'].values():
            pages[page['title']] = page
        time.sleep(2)
    for out, (title, start, length, loop) in SOUNDS.items():
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
        time.sleep(1.5)
        seconds = process_audio(src, os.path.join(AUDIO_OUT, out + '.ogg'), start, length, loop)
        credits['sounds'][out] = dict(title=title, author=re.sub('<[^>]+>', '', meta.get('Artist', {}).get('value', '')).strip(),
                                      license=meta.get('LicenseShortName', {}).get('value'), seconds=seconds, loop=loop,
                                      url='https://commons.wikimedia.org/wiki/File:' + urllib.parse.quote(title.replace(' ', '_')))
        print('sound:', out, seconds, 's', credits['sounds'][out]['license'])
    json.dump(credits, open(os.path.join(DL, 'fields_credits.json'), 'w', encoding='utf-8'), indent=1, ensure_ascii=False)

if __name__ == '__main__':
    sys.exit(main())
