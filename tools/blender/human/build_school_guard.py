"""0.50: Rommel Sabado, the night guard of the Prof. Ivan Lawrence College of Science and Technology, alive and
badly hurt at the school's back gate.

  blender -b --factory-startup --python tools/blender/human/build_school_guard.py -- [preview]

Built like Jonna (build_jonna.py): a town variant's body and garment shells, clean skin, the layered hair kit.
Dressed in the agency's white guard shirt with navy shoulder boards, navy trousers and the duty belt (his cap
is on the ground by the gate). Blood down the right side of the shirt from the bite on his forearm (wrapped in his own handkerchief),
on the right trouser leg, and a gauze pad taped over his left brow.
-> game/assets/characters/survivors/school_guard.glb (+ work/v50/guard/guard_front.png, guard_head.png with preview)
"""
import copy
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import build_zombies as town

town.WORK = os.path.join(town.ROOT, "work", "coop", "atlases")
PREV_DIR = os.path.join(town.ROOT, "work", "v50", "guard")
os.makedirs(town.WORK, exist_ok=True)
os.makedirs(PREV_DIR, exist_ok=True)
PREVIEW = "preview" in town.bh.args()

source = next(v for v in town.VARIANTS if v["name"] == "guwardiya")
spec = copy.deepcopy(source)
spec.update(name="school_guard", seed=977, hair="buzz_fade", hair_col=(0.030, 0.027, 0.025), grey_mix=0.25,
            clean_hair=True, shapes={"belly": 0.30, "build": 0.25, "jaw_wide": 0.35, "cheeks": 0.2}, tone=(1.0, 1.0, 1.0))
spec.pop("horror", None)
spec["top"] = dict(kind="shirt", sleeve=0.38, color=(0.84, 0.84, 0.82), color2=(0.08, 0.12, 0.26),
                   pattern="button_placket", blood=0.75)
spec["bottom"] = dict(kind="pants", color=(0.06, 0.08, 0.16), blood=0.55)
spec["shoes"] = dict(style="boot", color=(0.04, 0.04, 0.045))
spec["gear"] = dict(belt=dict(color=(0.05, 0.05, 0.055), pouches=True),
                    head_bandage=dict(color=(0.82, 0.80, 0.74), eye_cover=False, blood=0.9))

hair_style = spec["hair"]
spec["hair"] = "bald"
town.bh.reset()
arm, body = town.load(["walk", "walk_hurt"])
town.shape_body(body, spec)
co = np.array([v.co[:] for v in body.data.vertices], np.float32)


def near(x, y, z):
    return co[np.argmin(np.linalg.norm(co - np.array((x, y, z), np.float32), axis=1))]


# The bite on the right forearm, a gash on the right thigh, and the brow.
spec["wounds"] = [(near(-0.30, -0.04, 0.98), 0.045), (near(-0.10, -0.10, 0.62), 0.035), (near(0.05, -0.11, 1.63), 0.02)]
town.paint_skin = lambda p, base, v: base
ref_head = town.bh.duplicate(body, "RefHead")
body = town.dress(arm, body, spec)
town.bake(body, spec)
h_mat = town.hair_kit.make_hair_material("Guard hair", "z_school_guard", spec["hair_col"], town.WORK, seed=spec["seed"],
                                         grey_mix=0.25, zombie_grime=0.0)
h_ob = town.hair_kit.build_hair(hair_style, ref_head, arm, h_mat, uv_name=town.UV_NAME[0], seed=spec["seed"])
town.bpy.data.objects.remove(ref_head)
if h_ob is not None:
    h_ob.name = h_ob.data.name = "DefaultHair"
    h_ob.parent = arm
    h_ob.modifiers.new("Armature", "ARMATURE").object = arm
    town.validate_mesh(arm, h_ob, "guard_hair")
town.validate_mesh(arm, body, "school_guard")
town.export(arm, os.path.join(town.ROOT, "game/assets/characters/survivors", "school_guard.glb"), False)
if PREVIEW:
    cam = town.bh.setup_render((420, 620))
    town.bh.shoot(cam, os.path.join(PREV_DIR, "guard_front.png"), (0.0, -3.1, 1.0), (0.0, 0.0, 0.96), lens=50)
    town.bh.shoot(cam, os.path.join(PREV_DIR, "guard_head.png"), (-0.52, -0.78, 1.72), (0.0, -0.02, 1.62), lens=65)
print("GUARD DONE")
