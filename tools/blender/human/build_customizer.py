"""Builds modular multiplayer customization assets:
  - 17 standalone skinned hairstyles -> game/assets/characters/hair/hair_<style>.glb (tintable to any color)
  - 14 clean survivor outfits (hairless, ready for any modular hairstyle) -> game/assets/characters/survivors/outfits/outfit_<key>.glb

Run in Blender:
  blender -b --factory-startup --python tools/blender/human/build_customizer.py -- [hair] [outfits]
"""
import copy
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import build_human as bh
import build_zombies as town
import hair_kit

HAIR_OUT = os.path.join(town.ROOT, "game", "assets", "characters", "hair")
OUTFIT_OUT = os.path.join(town.ROOT, "game", "assets", "characters", "survivors", "outfits")
WORK_CUST = os.path.join(town.ROOT, "work", "v44", "customizer")

OUTFITS = [
    dict(key="tactical", seed=901,
         top=dict(kind="shirt", sleeve=0.68, color=(0.14, 0.16, 0.14), blood=0.0),
         bottom=dict(kind="pants", loose=0.012, color=(0.12, 0.13, 0.12), blood=0.0),
         shoes=dict(style="boot", color=(0.06, 0.06, 0.065)),
         gear=dict(vest=dict(color=(0.18, 0.22, 0.16), blood=0.0),
                   belt=dict(color=(0.08, 0.08, 0.085), pouches=True))),
    dict(key="hoodie_dark", seed=902,
         top=dict(kind="hoodie", sleeve=0.69, hem=0.91, color=(0.12, 0.13, 0.15), blood=0.0),
         bottom=dict(kind="pants", color=(0.10, 0.13, 0.20), pattern="denim", blood=0.0),
         shoes=dict(style="sneaker", color=(0.14, 0.14, 0.16))),
    dict(key="hoodie_crimson", seed=903,
         top=dict(kind="hoodie", sleeve=0.69, hem=0.91, color=(0.48, 0.10, 0.14), blood=0.0),
         bottom=dict(kind="pants", color=(0.09, 0.095, 0.11), pattern="denim", blood=0.0),
         shoes=dict(style="sneaker", color=(0.76, 0.76, 0.74))),
    dict(key="biker", seed=904,
         top=dict(kind="open_jacket", sleeve=0.69, hem=0.93, color=(0.07, 0.07, 0.08),
                  under_color=(0.82, 0.82, 0.80), pattern="leather", blood=0.0),
         bottom=dict(kind="pants", color=(0.10, 0.12, 0.18), pattern="denim", blood=0.0),
         shoes=dict(style="boot", color=(0.06, 0.055, 0.055)),
         gear=dict(belt=dict(color=(0.07, 0.07, 0.075), pouches=False))),
    dict(key="paramedic", seed=905,
         top=dict(kind="shirt", sleeve=0.68, color=(0.10, 0.26, 0.60), color2=(0.82, 0.88, 0.18),
                  pattern="hivis", blood=0.0),
         bottom=dict(kind="pants", loose=0.012, color=(0.08, 0.12, 0.22), blood=0.0),
         shoes=dict(style="boot", color=(0.06, 0.06, 0.065)),
         gear=dict(belt=dict(color=(0.07, 0.07, 0.08), pouches=True))),
    dict(key="flannel", seed=906,
         top=dict(kind="shirt", sleeve=0.66, color=(0.60, 0.12, 0.12), color2=(0.09, 0.09, 0.10),
                  pattern="plaid", blood=0.0),
         bottom=dict(kind="pants", color=(0.18, 0.26, 0.42), pattern="denim", blood=0.0),
         shoes=dict(style="boot", color=(0.28, 0.17, 0.09))),
    dict(key="police", seed=907,
         top=dict(kind="shirt", sleeve=0.38, color=(0.08, 0.14, 0.28), color2=(0.78, 0.68, 0.24),
                  pattern="button_placket", blood=0.0),
         bottom=dict(kind="pants", color=(0.06, 0.09, 0.18), blood=0.0),
         shoes=dict(style="boot", color=(0.05, 0.05, 0.055)),
         gear=dict(belt=dict(color=(0.06, 0.06, 0.065), pouches=True))),
    dict(key="doctor", seed=908,
         top=dict(kind="open_jacket", sleeve=0.68, hem=0.92, color=(0.86, 0.87, 0.86),
                  under_color=(0.16, 0.52, 0.54), blood=0.0),
         bottom=dict(kind="pants", color=(0.14, 0.16, 0.20), blood=0.0),
         shoes=dict(style="dress", color=(0.09, 0.08, 0.08)),
         gear=dict(coat_tail=dict(z0=0.46, open_front=True, color=(0.86, 0.87, 0.86), blood=0.0),
                   stethoscope=dict(color=(0.10, 0.11, 0.13)))),
    dict(key="athlete", seed=909,
         top=dict(kind="sando", color=(0.70, 0.12, 0.14), color2=(0.10, 0.10, 0.12), pattern="jersey", blood=0.0),
         bottom=dict(kind="shorts", z0=0.48, loose=0.020, color=(0.10, 0.10, 0.12), color2=(0.70, 0.12, 0.14),
                     pattern="side_stripe", blood=0.0),
         shoes=dict(style="sneaker", color=(0.76, 0.16, 0.16))),
    dict(key="mechanic", seed=910,
         top=dict(kind="coveralls", sleeve=0.66, color=(0.14, 0.22, 0.36), color2=(0.72, 0.24, 0.12),
                  pattern="chest_band", blood=0.0),
         bottom=dict(kind="pants", color=(0.14, 0.22, 0.36), blood=0.0),
         shoes=dict(style="boot", color=(0.16, 0.11, 0.07))),
    dict(key="barong", seed=911,
         top=dict(kind="shirt", sleeve=0.68, hem=0.89, color=(0.88, 0.84, 0.72), color2=(0.72, 0.65, 0.48),
                  pattern="barong", blood=0.0),
         bottom=dict(kind="pants", color=(0.11, 0.11, 0.13), blood=0.0),
         shoes=dict(style="dress", color=(0.08, 0.06, 0.05))),
    dict(key="raincoat", seed=912,
         top=dict(kind="hoodie", sleeve=0.69, hem=0.90, color=(0.84, 0.68, 0.10), blood=0.0),
         bottom=dict(kind="pants", color=(0.14, 0.16, 0.18), blood=0.0),
         shoes=dict(style="boot", color=(0.14, 0.28, 0.16)),
         gear=dict(coat_tail=dict(z0=0.54, open_front=True, color=(0.84, 0.68, 0.10), blood=0.0))),
    dict(key="camo", seed=913,
         top=dict(kind="shirt", sleeve=0.68, color=(0.24, 0.32, 0.19), color2=(0.14, 0.18, 0.10),
                  pattern="camo", blood=0.0),
         bottom=dict(kind="pants", loose=0.014, color=(0.22, 0.30, 0.18), color2=(0.13, 0.17, 0.10),
                     pattern="camo", blood=0.0),
         shoes=dict(style="boot", color=(0.08, 0.075, 0.06)),
         gear=dict(vest=dict(color=(0.16, 0.20, 0.13), blood=0.0),
                   belt=dict(color=(0.11, 0.12, 0.09), pouches=True))),
    dict(key="office", seed=914,
         top=dict(kind="shirt", sleeve=0.68, color=(0.68, 0.78, 0.88), color2=(0.54, 0.64, 0.76),
                  pattern="button_placket", blood=0.0),
         bottom=dict(kind="pants", color=(0.13, 0.14, 0.16), blood=0.0),
         shoes=dict(style="dress", color=(0.06, 0.055, 0.055)),
         gear=dict(necktie=dict(color=(0.58, 0.10, 0.12), color2=(0.82, 0.70, 0.28), pattern="stripes_h", blood=0.0))),
]


def build_modular_hairs():
    os.makedirs(HAIR_OUT, exist_ok=True)
    os.makedirs(WORK_CUST, exist_ok=True)
    for idx, st in enumerate(hair_kit.STYLES):
        bh.reset()
        arm, body = town.load(["walk_hurt"])
        body.shape_key_clear()
        # Neutral light base color so Godot can tint albedo_color cleanly to any of the 8 hair colors!
        mat = hair_kit.make_hair_material(
            "ModHair_" + st, "mod_" + st, (0.76, 0.76, 0.76), WORK_CUST,
            seed=900 + idx * 13, grey_mix=0.0, zombie_grime=0.0
        )
        h_ob = hair_kit.build_hair(st, body, arm, mat, uv_name=body.data.uv_layers[0].name, seed=900 + idx * 13)
        bpy.data.objects.remove(body)
        h_ob.name = h_ob.data.name = "CustomHair"
        h_ob.parent = arm
        h_ob.modifiers.new("Armature", "ARMATURE").object = arm
        town.validate_mesh(arm, h_ob, "hair_" + st)
        town.export(arm, os.path.join(HAIR_OUT, f"hair_{st}.glb"), False)


def build_modular_outfits():
    os.makedirs(OUTFIT_OUT, exist_ok=True)
    town.WORK = os.path.join(WORK_CUST, "outfits")
    os.makedirs(town.WORK, exist_ok=True)
    orig_paint_skin = town.paint_skin
    orig_paint_cloth = town.paint_cloth

    # Clean survivor cloth painter: strips heavy dirt/mud so multiplayer outfits look crisp and wearable!
    def clean_cloth(p, spec, v, salt):
        s2 = copy.deepcopy(spec)
        s2["blood"] = 0.0
        col = orig_paint_cloth(p, s2, v, salt)
        return col

    for o in OUTFITS:
        spec = copy.deepcopy(o)
        spec.update(name="outfit_" + o["key"], sex="m", shapes={"muscle": 0.25}, tone=(1.0, 1.0, 1.0),
                    hair="bald", hair_col=(0.03, 0.03, 0.03), clean_hair=True)
        bh.reset()
        arm, body = town.load(["walk_hurt"])
        town.shape_body(body, spec)
        spec["wounds"] = []
        town.paint_skin = lambda p, base, v: base
        town.paint_cloth = clean_cloth
        body = town.dress(arm, body, spec)
        town.bake(body, spec)
        town.validate_mesh(arm, body, spec["name"])
        town.export(arm, os.path.join(OUTFIT_OUT, f"outfit_{o['key']}.glb"), False)

    town.paint_skin = orig_paint_skin
    town.paint_cloth = orig_paint_cloth


def main():
    a = bh.args()
    do_hair = "hair" in a or not a
    do_outfits = "outfits" in a or not a
    if do_hair:
        build_modular_hairs()
    if do_outfits:
        build_modular_outfits()


if __name__ == "__main__":
    main()
