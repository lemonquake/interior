"""0.52: the survivors of room 501 at PILCST: Ma'am Teves (STEM 12-B's adviser) and four of her students, alive.

  blender -b --factory-startup --python tools/blender/human/build_school_survivors.py -- [preview] [only=teves,...]

Built like Jonna and Rommel (build_jonna.py, build_school_guard.py): a variant's body and garment shells, clean
skin, the layered hair kit. The students wear the same PILCST uniform as the infected students (white polo/blouse with
the crest, maroon necktie, navy slacks or pleated skirt), three days unwashed, dusty, a little of other people's blood
on the sleeves. Ma'am Teves wears the maroon faculty blazer; she has been holding a classroom door shut for three
nights. They are Group 3 from the board in one of the classrooms: Dela Cruz, Pagaduan, Uy, and Trisha Mendoza.
-> game/assets/characters/survivors/pilcst_<name>.glb (+ work/v52/survivors/<name>_front.png with preview)
"""
import copy
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import build_zombies as town

town.WORK = os.path.join(town.ROOT, "work", "coop", "atlases")
PREV_DIR = os.path.join(town.ROOT, "work", "v52", "survivors")
os.makedirs(town.WORK, exist_ok=True)
os.makedirs(PREV_DIR, exist_ok=True)
ARGS = town.bh.args()
PREVIEW = "preview" in ARGS
ONLY = []
for a in ARGS:
    if a.startswith("only="):
        ONLY = a[5:].split(",")

PEOPLE = [
    # Ma'am Teves: forties, hair pulled back hard, glasses, the faculty blazer, a cut on her forearm she tied off.
    dict(src="teacher_f1", name="teves", seed=2101, hair="high_bun", hair_col=(0.035, 0.028, 0.024), grey_mix=0.18,
         shapes={"female": 1.0, "belly": 0.10, "cheeks": -0.10, "chin_long": 0.15},
         top=dict(kind="open_jacket", sleeve=0.66, hem=0.94, color=(0.40, 0.06, 0.09), under_color=(0.86, 0.82, 0.72),
                  blood=0.22),
         skirt=dict(z0=0.42, flare=0.03, color=(0.12, 0.10, 0.10), blood=0.08),
         shoes=dict(style="dress", color=(0.05, 0.035, 0.03)),
         gear=dict(glasses=dict(color=(0.10, 0.08, 0.08), tilt=0.0)),
         wounds=[(-0.30, -0.04, 0.98, 0.03)]),
    # Paolo Uy: thin, curtain fringe, glasses, still has his backpack on.
    dict(src="pilcst_m1", name="paolo", seed=2117, hair="curtain_part", hair_col=(0.024, 0.021, 0.020),
         shapes={"build": -0.30, "belly": -0.20, "chin_long": 0.20},
         top=dict(kind="shirt", sleeve=0.36, color=(0.88, 0.87, 0.84), pattern="pilcst", blood=0.12),
         bottom=dict(kind="pants", color=(0.06, 0.08, 0.18), blood=0.05),
         shoes=dict(style="dress", color=(0.035, 0.035, 0.04)),
         gear=dict(necktie=dict(color=(0.40, 0.05, 0.08), blood=0.0),
                   glasses=dict(color=(0.08, 0.08, 0.09), tilt=0.0),
                   backpack=dict(color=(0.10, 0.16, 0.34), blood=0.0)),
         wounds=[]),
    # Jerome Dela Cruz: heavyset, neat side part, sling bag, a scrape on his brow.
    dict(src="pilcst_m3", name="jerome", seed=2129, hair="side_part", hair_col=(0.03, 0.025, 0.022),
         shapes={"belly": 0.50, "build": 0.30, "cheeks": 0.45, "nose_wide": 0.30},
         top=dict(kind="shirt", sleeve=0.36, color=(0.88, 0.87, 0.84), pattern="pilcst", blood=0.25),
         bottom=dict(kind="pants", color=(0.06, 0.08, 0.18), blood=0.1),
         shoes=dict(style="dress", color=(0.035, 0.035, 0.04)),
         gear=dict(necktie=dict(color=(0.40, 0.05, 0.08), blood=0.1),
                   sling_bag=dict(color=(0.08, 0.08, 0.09), blood=0.0)),
         wounds=[(0.05, -0.11, 1.64, 0.015)]),
    # Bea Pagaduan: the class president, ponytail, glasses.
    dict(src="pilcst_f2", name="bea", seed=2141, hair="ponytail", hair_col=(0.03, 0.024, 0.02),
         shapes={"female": 1.0, "build": -0.15, "lips_full": 0.20},
         top=dict(kind="shirt", sleeve=0.34, hem=1.0, color=(0.88, 0.87, 0.84), pattern="pilcst", blood=0.15),
         skirt=dict(z0=0.52, flare=0.06, pleats=True, color=(0.045, 0.055, 0.13), blood=0.05),
         shoes=dict(style="dress", color=(0.035, 0.035, 0.04)),
         gear=dict(necktie=dict(color=(0.40, 0.05, 0.08), blood=0.0),
                   glasses=dict(color=(0.30, 0.12, 0.14), tilt=0.0)),
         wounds=[]),
    # Trisha Mendoza: long straight hair, backpack, blood on her skirt that is not hers.
    dict(src="pilcst_f1", name="trisha", seed=2153, hair="long_straight", hair_col=(0.022, 0.019, 0.018),
         shapes={"female": 0.95, "build": -0.20, "chin_long": 0.10},
         top=dict(kind="shirt", sleeve=0.34, hem=1.0, color=(0.88, 0.87, 0.84), pattern="pilcst", blood=0.1),
         skirt=dict(z0=0.52, flare=0.06, pleats=True, color=(0.045, 0.055, 0.13), blood=0.3),
         shoes=dict(style="dress", color=(0.035, 0.035, 0.04)),
         gear=dict(necktie=dict(color=(0.40, 0.05, 0.08), blood=0.0),
                   backpack=dict(color=(0.36, 0.08, 0.12), blood=0.0)),
         wounds=[]),
]


def build(person):
    source = next(v for v in town.VARIANTS if v["name"] == person["src"])
    spec = copy.deepcopy(source)
    spec.update(name="pilcst_" + person["name"], seed=person["seed"], hair=person["hair"], hair_col=person["hair_col"],
                grey_mix=person.get("grey_mix", 0.0), clean_hair=True, shapes=person["shapes"], tone=(1.0, 1.0, 1.0))
    spec.pop("horror", None)
    for key in ("top", "bottom", "skirt", "shoes", "gear"):
        spec.pop(key, None)
        if key in person:
            spec[key] = copy.deepcopy(person[key])
    hair_style = spec["hair"]
    spec["hair"] = "bald"
    town.bh.reset()
    arm, body = town.load(["walk", "walk_hurt"])
    town.shape_body(body, spec)
    co = np.array([v.co[:] for v in body.data.vertices], np.float32)

    def near(x, y, z):
        return co[np.argmin(np.linalg.norm(co - np.array((x, y, z), np.float32), axis=1))]

    spec["wounds"] = [(near(w[0], w[1], w[2]), w[3]) for w in person["wounds"]]
    town.paint_skin = lambda p, base, v: base
    ref_head = town.bh.duplicate(body, "RefHead")
    body = town.dress(arm, body, spec)
    town.bake(body, spec)
    h_mat = town.hair_kit.make_hair_material(spec["name"] + " hair", "z_" + spec["name"], spec["hair_col"], town.WORK,
                                             seed=spec["seed"], grey_mix=spec["grey_mix"], zombie_grime=0.0)
    h_ob = town.hair_kit.build_hair(hair_style, ref_head, arm, h_mat, uv_name=town.UV_NAME[0], seed=spec["seed"])
    town.bpy.data.objects.remove(ref_head)
    if h_ob is not None:
        h_ob.name = h_ob.data.name = "DefaultHair"
        h_ob.parent = arm
        h_ob.modifiers.new("Armature", "ARMATURE").object = arm
        town.validate_mesh(arm, h_ob, spec["name"] + "_hair")
    town.validate_mesh(arm, body, spec["name"])
    town.export(arm, os.path.join(town.ROOT, "game/assets/characters/survivors", spec["name"] + ".glb"), False)
    if PREVIEW:
        cam = town.bh.setup_render((420, 640))
        town.bh.shoot(cam, os.path.join(PREV_DIR, person["name"] + "_front.png"), (0.0, -3.1, 1.0), (0.0, 0.0, 0.92), lens=50)
        town.bh.shoot(cam, os.path.join(PREV_DIR, person["name"] + "_head.png"), (-0.52, -0.78, 1.66), (0.0, -0.02, 1.56), lens=65)
    print("SURVIVOR DONE", spec["name"])


for person in PEOPLE:
    if ONLY and person["name"] not in ONLY:
        continue
    build(person)
print("SURVIVORS DONE")
