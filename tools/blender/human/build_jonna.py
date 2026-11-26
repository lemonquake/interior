"""0.44: Jonna, the Olivar Family Mart's shift supervisor, alive and badly hurt in the back office.

  blender -b --factory-startup --python tools/blender/human/build_jonna.py -- [preview]

Built like the five survivors (build_survivors.py): the nurse variant's body and garment shells, clean skin, the
layered hair kit. Dressed in the mart's red staff polo and black work trousers; blood soaked through the left
side of the polo from the wound she is holding, down the trouser leg, and a gauze wrap round her head.
-> game/assets/characters/survivors/jonna.glb (+ work/v44/office/jonna_front.png, jonna_head.png with preview)
"""
import copy
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import build_zombies as town

town.WORK = os.path.join(town.ROOT, "work", "coop", "atlases")
PREV_DIR = os.path.join(town.ROOT, "work", "v44", "office")
os.makedirs(town.WORK, exist_ok=True)
os.makedirs(PREV_DIR, exist_ok=True)
PREVIEW = "preview" in town.bh.args()

source = next(v for v in town.VARIANTS if v["name"] == "nars")
spec = copy.deepcopy(source)
spec.update(name="jonna", seed=911, hair="ponytail", hair_col=(0.030, 0.024, 0.020), grey_mix=0.0, clean_hair=True,
            shapes={"female": 1.0, "build": -0.05, "cheeks": 0.2}, tone=(1.0, 1.0, 1.0))
spec.pop("horror", None)
spec["top"] = dict(kind="shirt", sleeve=0.30, hem=0.97, color=(0.52, 0.07, 0.07), color2=(0.44, 0.05, 0.05),
                   pattern="button_placket", blood=0.8)
spec["bottom"] = dict(kind="pants", color=(0.06, 0.06, 0.07), blood=0.45)
spec["shoes"] = dict(style="sneaker", color=(0.86, 0.85, 0.82))
spec["gear"] = dict(head_bandage=dict(color=(0.82, 0.80, 0.74), eye_cover=False, blood=1.25))

hair_style = spec["hair"]
spec["hair"] = "bald"
town.bh.reset()
arm, body = town.load(["walk", "walk_hurt"])
town.shape_body(body, spec)
# Where she is hurt: a deep gash low on her left side (she holds it), a cut on the right thigh, the left forearm.
co = np.array([v.co[:] for v in body.data.vertices], np.float32)


def near(x, y, z):
    return co[np.argmin(np.linalg.norm(co - np.array((x, y, z), np.float32), axis=1))]


spec["wounds"] = [(near(0.11, -0.12, 1.00), 0.05), (near(0.08, -0.12, 0.93), 0.035), (near(-0.09, -0.10, 0.60), 0.03)]
town.paint_skin = lambda p, base, v: base
ref_head = town.bh.duplicate(body, "RefHead")
body = town.dress(arm, body, spec)
town.bake(body, spec)
h_mat = town.hair_kit.make_hair_material("Jonna hair", "z_jonna", spec["hair_col"], town.WORK, seed=spec["seed"],
                                         grey_mix=0.0, zombie_grime=0.0)
h_ob = town.hair_kit.build_hair(hair_style, ref_head, arm, h_mat, uv_name=town.UV_NAME[0], seed=spec["seed"])
town.bpy.data.objects.remove(ref_head)
if h_ob is not None:
    h_ob.name = h_ob.data.name = "DefaultHair"
    h_ob.parent = arm
    h_ob.modifiers.new("Armature", "ARMATURE").object = arm
    town.validate_mesh(arm, h_ob, "jonna_hair")
town.validate_mesh(arm, body, "jonna")
town.export(arm, os.path.join(town.ROOT, "game/assets/characters/survivors", "jonna.glb"), False)
if PREVIEW:
    cam = town.bh.setup_render((420, 620))
    town.bh.shoot(cam, os.path.join(PREV_DIR, "jonna_front.png"), (0.0, -3.1, 1.0), (0.0, 0.0, 0.96), lens=50)
    town.bh.shoot(cam, os.path.join(PREV_DIR, "jonna_head.png"), (-0.52, -0.78, 1.72), (0.0, -0.02, 1.62), lens=65)
print("JONNA DONE")
