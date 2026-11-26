"""0.68: the living at the hospital: Doctor Berido (hiding on its second floor) and the doctors, nurses and police
who stay outside by the ambulances.

  blender -b --factory-startup --python tools/blender/human/build_hospital_people.py -- [preview] [only=berido,...]

Built like Ma'am Teves and her students (build_school_survivors.py): a town variant's body and garment shells, clean
skin, the layered hair kit. Three days of a night shift that did not end: creased, sweat-dark, other people's blood
on the sleeves and knees.
-> game/assets/characters/survivors/hosp_<name>.glb (+ work/v68/people/<name>_front.png with preview)
"""
import copy
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import build_zombies as town

town.WORK = os.path.join(town.ROOT, "work", "coop", "atlases")
PREV_DIR = os.path.join(town.ROOT, "work", "v68", "people")
os.makedirs(town.WORK, exist_ok=True)
os.makedirs(PREV_DIR, exist_ok=True)
ARGS = town.bh.args()
PREVIEW = "preview" in ARGS
ONLY = []
for a in ARGS:
    if a.startswith("only="):
        ONLY = a[5:].split(",")

COAT = (0.90, 0.91, 0.90)
PEOPLE = [
    # Doctor Berido: sixties, grey thinning hair, glasses, the long lab coat over a pale blue shirt and a dark tie.
    dict(src="doktor", name="berido", seed=2301, hair="thinning_receding", hair_col=(0.30, 0.30, 0.30), grey_mix=0.85,
         shapes={"build": -0.10, "belly": 0.30, "cheeks": -0.15, "nose_long": 0.30, "chin_long": 0.20},
         top=dict(kind="open_jacket", sleeve=0.69, hem=0.92, color=COAT, under_color=(0.60, 0.70, 0.82), blood=0.25),
         bottom=dict(kind="pants", color=(0.20, 0.20, 0.22), blood=0.08),
         shoes=dict(style="dress", color=(0.06, 0.05, 0.045)),
         gear=dict(coat_tail=dict(z0=0.40, open_front=True, color=COAT, blood=0.2, ragged=False),
                   necktie=dict(color=(0.12, 0.14, 0.24), blood=0.0),
                   glasses=dict(color=(0.12, 0.12, 0.13), tilt=0.0)),
         wounds=[]),
    # The ER doctor: forties, short hair, lab coat over teal scrubs, stethoscope.
    dict(src="doktor", name="doctor_m", seed=2311, hair="textured_crop", hair_col=(0.03, 0.026, 0.024), grey_mix=0.2,
         shapes={"build": 0.10, "jaw_wide": 0.30, "brow_heavy": 0.30},
         top=dict(kind="open_jacket", sleeve=0.69, hem=0.92, color=COAT, under_color=(0.16, 0.46, 0.48), blood=0.35),
         bottom=dict(kind="pants", color=(0.15, 0.44, 0.46), blood=0.2),
         shoes=dict(style="sneaker", color=(0.70, 0.70, 0.68)),
         gear=dict(coat_tail=dict(z0=0.42, open_front=True, color=COAT, blood=0.3, ragged=False),
                   stethoscope=dict(color=(0.08, 0.09, 0.11))),
         wounds=[]),
    # The resident: thirties, ponytail, lab coat over navy scrubs, glasses.
    dict(src="teacher_f2", name="doctor_f", seed=2323, hair="ponytail", hair_col=(0.03, 0.025, 0.022),
         shapes={"female": 1.0, "build": -0.10, "chin_long": 0.10},
         top=dict(kind="open_jacket", sleeve=0.69, hem=0.90, color=COAT, under_color=(0.10, 0.14, 0.30), blood=0.3),
         bottom=dict(kind="pants", color=(0.10, 0.14, 0.30), blood=0.15),
         shoes=dict(style="sneaker", color=(0.74, 0.74, 0.72)),
         gear=dict(coat_tail=dict(z0=0.42, open_front=True, color=COAT, blood=0.25, ragged=False),
                   stethoscope=dict(color=(0.08, 0.09, 0.11)),
                   glasses=dict(color=(0.20, 0.16, 0.16), tilt=0.0)),
         wounds=[]),
    # A nurse: teal scrubs, mask pulled down, hair tied back.
    dict(src="nars", name="nurse_f", seed=2333, hair="ponytail", hair_col=(0.028, 0.023, 0.02),
         shapes={"female": 1.0, "belly": 0.15, "cheeks": 0.25},
         top=dict(kind="shirt", sleeve=0.36, color=(0.14, 0.52, 0.54), color2=(0.10, 0.40, 0.42),
                  pattern="button_placket", blood=0.3),
         bottom=dict(kind="pants", color=(0.13, 0.48, 0.50), blood=0.15),
         shoes=dict(style="sneaker", color=(0.76, 0.76, 0.74)),
         gear=dict(face_mask=dict(color=(0.56, 0.74, 0.76), blood=0.0, hanging=True)),
         wounds=[]),
    # A male nurse: navy scrubs, buzz cut.
    dict(src="nars", name="nurse_m", seed=2347, hair="buzz_fade", hair_col=(0.03, 0.026, 0.024),
         shapes={"build": 0.20, "muscle": 0.20},
         top=dict(kind="shirt", sleeve=0.36, color=(0.10, 0.14, 0.30), color2=(0.08, 0.11, 0.24),
                  pattern="button_placket", blood=0.4),
         bottom=dict(kind="pants", color=(0.10, 0.14, 0.30), blood=0.2),
         shoes=dict(style="sneaker", color=(0.70, 0.70, 0.70)),
         wounds=[]),
    # Police: navy uniform, cap, duty belt.
    dict(src="pulis", name="police_1", seed=2351, hair="buzz_fade", hair_col=(0.03, 0.028, 0.026),
         shapes={"build": 0.35, "muscle": 0.40, "jaw_wide": 0.45},
         top=dict(kind="shirt", sleeve=0.40, color=(0.07, 0.11, 0.22), color2=(0.75, 0.65, 0.22),
                  pattern="button_placket", blood=0.15),
         bottom=dict(kind="pants", color=(0.05, 0.07, 0.13), blood=0.05),
         shoes=dict(style="boot", color=(0.04, 0.04, 0.045)),
         gear=dict(cap=dict(color=(0.05, 0.08, 0.18), backwards=False, blood=0.0),
                   belt=dict(color=(0.05, 0.05, 0.055), pouches=True)),
         wounds=[]),
    dict(src="pulis", name="police_2", seed=2363, hair="textured_crop", hair_col=(0.03, 0.026, 0.024),
         shapes={"belly": 0.35, "cheeks": 0.30, "brow_heavy": 0.40},
         top=dict(kind="shirt", sleeve=0.40, color=(0.07, 0.11, 0.22), color2=(0.75, 0.65, 0.22),
                  pattern="button_placket", blood=0.3),
         bottom=dict(kind="pants", color=(0.05, 0.07, 0.13), blood=0.1),
         shoes=dict(style="boot", color=(0.04, 0.04, 0.045)),
         gear=dict(belt=dict(color=(0.05, 0.05, 0.055), pouches=True)),
         wounds=[]),
]


def build(person):
    source = next(v for v in town.VARIANTS if v["name"] == person["src"])
    spec = copy.deepcopy(source)
    spec.update(name="hosp_" + person["name"], seed=person["seed"], hair=person["hair"], hair_col=person["hair_col"],
                grey_mix=person.get("grey_mix", 0.0), clean_hair=True, shapes=person["shapes"], tone=(1.0, 1.0, 1.0))
    if "female" in person["shapes"]:
        spec["sex"] = "f"
    elif spec.get("sex") == "f":
        spec["sex"] = "m"
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
    print("SURVIVOR DONE", spec["name"])


for person in PEOPLE:
    if ONLY and person["name"] not in ONLY:
        continue
    build(person)
print("HOSPITAL PEOPLE DONE")
