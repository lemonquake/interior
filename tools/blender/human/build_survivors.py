"""Build the five co-op player survivors from the project's rig, garment shells, and upgraded hair_kit."""
import copy
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import build_zombies as town

# Five distinct player hairstyles using the upgraded layered-strand hair_kit (clean_hair=True).
ROSTER = [
    ("Alex", 0, "textured_crop", (0.032, 0.026, 0.022), 0.0, (.16, .47, .50), (.15, .17, .24)),
    ("Aljay", 1, "undercut_quiff", (0.028, 0.024, 0.020), 0.0, (.67, .37, .13), (.15, .21, .31)),
    ("Louie", 3, "side_part", (0.040, 0.030, 0.024), 0.0, (.41, .54, .70), (.23, .24, .19)),
    ("Anthony", 2, "slick_back", (0.026, 0.024, 0.022), 0.12, (.28, .35, .21), (.15, .13, .11)),
    ("Clyde", 1, "wavy_shag", (0.045, 0.032, 0.024), 0.0, (.50, .15, .16), (.32, .29, .24)),
]
town.WORK = os.path.join(town.ROOT, "work", "coop", "atlases")
PREV_DIR = os.path.join(town.ROOT, "work", "v44", "survivors")
os.makedirs(town.WORK, exist_ok=True)
os.makedirs(PREV_DIR, exist_ok=True)
PREVIEW = "preview" in town.bh.args()

for idx, (name, source, hair, hair_col, grey_mix, shirt, trousers) in enumerate(ROSTER):
    spec = copy.deepcopy(town.VARIANTS[source])
    spec.update(name=name.lower(), hair=hair, hair_col=hair_col, grey_mix=grey_mix, clean_hair=True, seed=700 + idx * 17)
    # Strip zombie-only wear, gear, and torn clothing so survivors look clean & sharp!
    spec.pop("gear", None)
    spec.pop("horror", None)
    spec["top"].pop("torn_sleeve", None)
    spec["top"].pop("ragged", None)
    spec["top"].pop("grease", None)
    spec["top"].pop("scorch", None)
    spec["bottom"].pop("torn_leg", None)
    if name == "Alex":
        # Clean short-sleeve tee & sneakers for Alex.
        spec["top"]["kind"] = "shirt"
        spec["top"]["sleeve"] = 0.36
        spec["top"]["pattern"] = ""
        spec["bottom"]["kind"] = "pants"
        spec["bottom"]["z0"] = 0.108
        spec["bottom"]["loose"] = 0.008
        spec["bottom"]["pattern"] = ""
        spec["shoes"] = dict(style="sneaker", color=(0.18, 0.19, 0.22))
    elif name == "Aljay":
        spec["top"]["pattern"] = ""
        spec["shoes"] = dict(style="sneaker", color=(0.14, 0.14, 0.16))
    elif name == "Clyde":
        spec["shapes"] = {"build": -.4, "ears_out": .6, "chin_long": .7}
        spec["top"]["sleeve"] = .42
        spec["top"]["pattern"] = ""
        spec["shoes"] = dict(style="sneaker", color=(0.24, 0.22, 0.20))
    else:
        spec["top"]["pattern"] = ""
    spec["top"].update(color=shirt, blood=0)
    spec["bottom"].update(color=trousers, blood=0)

    # Build body + clothes without baked hair, then attach default hair as a separate named mesh ("DefaultHair")
    # so multiplayer players can swap or hide hair cleanly on top of any default survivor outfit too!
    hair_style = spec["hair"]
    spec["hair"] = "bald"
    town.bh.reset()
    arm, body = town.load(["walk", "walk_hurt"])
    town.shape_body(body, spec)
    spec["wounds"] = []
    town.paint_skin = lambda p, base, v: base
    ref_head = town.bh.duplicate(body, "RefHead")
    body = town.dress(arm, body, spec)
    town.bake(body, spec)
    h_mat = town.hair_kit.make_hair_material(
        "Survivor hair " + spec["name"], "z_" + spec["name"], hair_col, town.WORK,
        seed=spec["seed"], grey_mix=grey_mix, zombie_grime=0.0
    )
    h_ob = town.hair_kit.build_hair(hair_style, ref_head, arm, h_mat, uv_name=town.UV_NAME[0], seed=spec["seed"])
    town.bpy.data.objects.remove(ref_head)
    if h_ob is not None:
        h_ob.name = h_ob.data.name = "DefaultHair"
        h_ob.parent = arm
        h_ob.modifiers.new("Armature", "ARMATURE").object = arm
        town.validate_mesh(arm, h_ob, spec["name"] + "_hair")
    town.validate_mesh(arm, body, spec["name"])
    town.export(arm, os.path.join(town.ROOT, "game/assets/characters/survivors", name.lower() + ".glb"), False)
    if PREVIEW:
        cam = town.bh.setup_render((420, 620))
        town.bh.shoot(cam, os.path.join(PREV_DIR, f"{name.lower()}_front.png"), (0.0, -3.1, 1.0), (0.0, 0.0, 0.96), lens=50)
        town.bh.shoot(cam, os.path.join(PREV_DIR, f"{name.lower()}_head.png"), (-0.52, -0.78, 1.72), (0.0, -0.02, 1.62), lens=65)
