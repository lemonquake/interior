"""Download what the Nichols basement needs (0.22): PBR surfaces for the cellar and the corridor under the house,
cellar, tunnel and kitchen props (all Poly Haven, CC0).

    python tools/assets/fetch_basement.py

Textures go to game/assets/outdoor/textures/<id>/ (albedo, GL normal, roughness). Models land in
.local/downloads/polyhaven/models/ and are converted by tools/blender/process_downloads.py (entries marked
"0.22 Nichols basement") into game/assets/models/nichols/. The basement's sounds are synthesised by
tools/assets/make_basement_sounds.py.
Credits: .local/downloads/basement_credits.json (copied into game/licenses/).
"""
import json, os, sys
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fetch_fields import get, ph_api, polyhaven_jobs, DL, ROOT  # noqa: E402

TEXTURE_OUT = os.path.join(ROOT, 'game', 'assets', 'outdoor', 'textures')
# id -> resolution (Poly Haven, CC0)
TEXTURES = {
    'damaged_concrete_floor': '2k',   # cellar floor
    'rustic_stone_wall_02': '2k',     # 1906 fieldstone foundation walls
    'rough_plaster_brick_04': '1k',   # whitewash fallen off the brick round the stair
    'dirty_concrete': '2k',           # the corridor walls (the owner's 3rd reference)
    'rough_concrete': '1k',           # corridor ceiling
    'rusty_metal_03': '1k',           # pipes, hooks, chains
    'rusty_metal_sheet': '1k',        # the steel door
}
POLYHAVEN = [
    # shelving, work bench, tools
    'worn_metal_rack', 'steel_frame_shelves_02', 'wooden_display_shelves_01', 'painted_wooden_shelves',
    'metal_tool_chest', 'bench_vice_01', 'hatchet', 'machete', 'sledgehammer_01', 'crowbar_01', 'handsaw_wood',
    'rusted_hacksaw', 'bolt_cutters_01', 'pipe_wrench',
    # containers and junk
    'wine_barrel_01', 'Barrel_01', 'wooden_crate_01', 'cardboard_box_01', 'trashbag', 'wooden_bucket_01', 'can_rusted',
    # the tunnel
    'street_rat', 'mousetrap', 'medical_box', 'metal_office_desk', 'metal_stool_01', 'wooden_ladder', 'old_tyre', 'propane_tank', 'barrel_stove',
    # the kitchen
    'pot_enamel_01', 'brass_pan_01', 'wooden_cutting_board', 'jug_01', 'wooden_bowl_01', 'fish_knife',
]
def main():
    credits = {'polyhaven': {}}
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
    json.dump(credits, open(os.path.join(DL, 'basement_credits.json'), 'w', encoding='utf-8'), indent=1, ensure_ascii=False)


if __name__ == '__main__':
    sys.exit(main())
