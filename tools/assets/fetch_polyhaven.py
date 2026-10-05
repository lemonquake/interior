"""Download the CC0 Poly Haven assets used by the neighbourhood, studio and house decor.

    python tools/assets/fetch_polyhaven.py            # into .local/downloads/polyhaven

Models arrive as glTF (1k textures) and are converted by tools/blender/process_downloads.py.
Textures are copied straight into game/assets/outdoor/textures/<id>/ (albedo, GL normal, roughness).
The sky HDRI is tone-mapped into a backdrop panorama by tools/assets/make_sky.py.
"""
import json, os, sys, urllib.request
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CACHE = os.path.join(ROOT, '.local', 'downloads', 'polyhaven')
TEXTURE_OUT = os.path.join(ROOT, 'game', 'assets', 'outdoor', 'textures')
UA = {'User-Agent': 'interior-asset-fetch/1.0'}

MODELS = [
    # Trees and planting for the neighbourhood.
    'island_tree_01', 'island_tree_02', 'searsia_lucida', 'tree_small_02', 'jacaranda_tree',
    'shrub_02', 'shrub_04', 'shrub_03',
    # Street and house details.
    'exterior_aircon_unit', 'power_box_01', 'street_lamp_01', 'plastic_monobloc_chair_01', 'security_light',
    # Studio and house interior.
    'potted_plant_01', 'potted_plant_02', 'potted_plant_04', 'sofa_02', 'modern_ceiling_lamp_01',
    'steel_frame_shelves_01', 'ceramic_vase_01', 'ceramic_vase_03', 'book_encyclopedia_set_01',
    'throw_pillows_01', 'side_table_01', 'desk_lamp_arm_01', 'boombox', 'cassette_player',
    'alarm_clock_01', 'wicker_basket_01', 'brass_vase_01', 'fancy_picture_frame_01',
]
TEXTURES = [
    'painted_plaster_wall', 'white_plaster_02', 'beige_wall_001', 'concrete_block_wall', 'peeling_painted_wall',
    'brick_wall_02', 'concrete_wall_008', 'corrugated_iron', 'corrugated_iron_02', 'rusty_corrugated_iron',
    'clay_roof_tiles_02', 'grey_roof_tiles', 'asphalt_02', 'concrete_pavement', 'sparse_grass', 'concrete_floor_02',
    'painted_metal_shutter', 'blue_painted_planks', 'rusty_metal_02', 'dark_wooden_planks', 'fabric_pattern_07',
]
HDRI = 'kloofendal_28d_misty_puresky'

def api(path):
    return json.load(urllib.request.urlopen(urllib.request.Request('https://api.polyhaven.com/' + path, headers=UA)))

def fetch(url, dst):
    if os.path.exists(dst) and os.path.getsize(dst) > 0:
        return
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA)) as r, open(dst + '.part', 'wb') as f:
        f.write(r.read())
    os.replace(dst + '.part', dst)

def model_jobs(asset):
    g = api('files/' + asset)['gltf']['1k']['gltf']
    base = os.path.join(CACHE, 'models', asset)
    jobs = [(g['url'], os.path.join(base, asset + '.gltf'))]
    jobs += [(v['url'], os.path.join(base, rel)) for rel, v in g['include'].items()]
    return jobs

def texture_jobs(asset):
    f = api('files/' + asset)
    jobs = []
    if 'Diffuse' not in f:  # fabric sets ship colour variants instead (col_1, col_2, ...)
        f['Diffuse'] = f[sorted(k for k in f if k.startswith('col_'))[0]]
    for key, name in [('Diffuse', 'albedo'), ('nor_gl', 'normal'), ('Rough', 'roughness')]:
        if key in f:
            jobs.append((f[key]['1k']['jpg']['url'], os.path.join(TEXTURE_OUT, asset, name + '.jpg')))
    return jobs

def main():
    jobs, missing = [], []
    for asset in MODELS + TEXTURES:
        try:
            jobs += model_jobs(asset) if asset in MODELS else texture_jobs(asset)
        except Exception as error:
            missing.append(asset + ': ' + str(error))
    jobs.append((api('files/' + HDRI)['hdri']['4k']['hdr']['url'], os.path.join(CACHE, 'hdri', HDRI + '_4k.hdr')))
    with ThreadPoolExecutor(8) as pool:
        list(pool.map(lambda job: fetch(*job), jobs))
    print('downloaded', len(jobs), 'files; missing:', missing or 'none')
    info = api('assets?t=all')
    credits = {a: dict(name=info[a]['name'], authors=list(info[a].get('authors', {})), license='CC0', url='https://polyhaven.com/a/' + a)
               for a in MODELS + TEXTURES + [HDRI] if a in info}
    os.makedirs(CACHE, exist_ok=True)
    json.dump(credits, open(os.path.join(CACHE, 'credits.json'), 'w'), indent=1)

if __name__ == '__main__':
    sys.exit(main())
