"""Interior 0.29: the debug-only sniper rifle, a generic bolt-action .338 with a variable 2-8x scope.

  blender -b --factory-startup --python tools/blender/story/build_sniper.py -- [preview] [export]

  preview   two renders                          -> work/v29/sniper/sniper-side.png, sniper-eye.png
  export    game/assets/models/story/sniper.glb

No maker's marks: a round steel receiver with a two-lug bolt (the handle on the right, turned down), a heavy 26 inch
barrel with a three-port brake, a polymer stock with a pistol grip and a raised cheek piece, a five-round box
magazine, a folded bipod, and a 30 mm scope in two rings: ocular bell, power ring, two turrets, objective bell.

Same frame as build_ar15.py (bore along +Y in Blender, -Z in Godot; y = 0 is the rear face of the receiver, the
bore is z = 0). Objects: `sn_body`, `sn_bolt` (origin on the bore: it turns up 60 degrees about it and slides back
95 mm), `sn_magazine`, and the empties `grip_r`, `grip_l` (under the forend), `muzzle`, `eject`, `rear_sight` (the
middle of the ocular lens: the eye goes behind it), `front_sight` (the middle of the objective), `butt`,
`bolt_handle`, `mag`.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
# The AR-15 builder's primitives (box, tube, rod, prism, ring, join...), without running its build.
_source = open(os.path.join(HERE, "build_ar15.py"), encoding="utf-8").read()
exec(_source[:_source.index("def build():")] + _source[_source.index("def join("):_source.index("def assemble():")]
     + _source[_source.index("def render("):_source.index("def preview():")])

OUT_GLB = os.path.join(ROOT, "game", "assets", "models", "story", "sniper.glb")
WORK = os.path.join(ROOT, "work", "v29", "sniper")
MATERIALS.update({
    "sn_steel": ((0.075, 0.078, 0.085), 0.75, 0.40),
    "sn_stock": ((0.072, 0.082, 0.066), 0.0, 0.78),
    "sn_bolt": ((0.52, 0.51, 0.49), 1.0, 0.24),
    "sn_scope": ((0.022, 0.022, 0.024), 0.4, 0.48),
    "sn_glass": ((0.030, 0.050, 0.085), 0.9, 0.06),
    "sn_mark": ((0.82, 0.82, 0.80), 0.0, 0.6),
})
GROUPS.clear()
GROUPS.update({"body": [], "bolt": [], "magazine": []})
SCOPE_Z = 0.052


def build():
    # ---- receiver and barrel
    tube("receiver", 0.0170, 0.000, 0.215, mat="sn_steel", segments=28)
    box("receiver_flat", (0.030, 0.200, 0.014), (0.0, 0.108, -0.014), mat="sn_steel", bevel=0.002)
    box("port", (0.0012, 0.078, 0.016), (0.0166, 0.120, 0.004), mat="ar_dark", bevel=0.0)
    box("recoil_lug", (0.030, 0.008, 0.030), (0.0, 0.219, -0.008), mat="sn_steel", bevel=0.001)
    tube("barrel_shank", 0.0160, 0.215, 0.290, mat="sn_steel", segments=28)
    tube("barrel", 0.0150, 0.290, 0.860, mat="sn_steel", segments=28, radius_end=0.0105)
    tube("brake", 0.0135, 0.860, 0.915, mat="sn_steel", segments=24)
    tube("brake_bore", 0.0050, 0.9145, 0.9155, mat="ar_dark", segments=16)
    for k in range(3):
        box("brake_port_%d" % k, (0.030, 0.007, 0.010), (0.0, 0.872 + 0.013 * k, 0.0), mat="ar_dark", bevel=0.0)
    # ---- the stock: forend, action bed, pistol grip, butt with a raised cheek piece
    prism("stock", [(0.540, -0.012), (0.540, -0.046), (0.250, -0.052), (0.180, -0.050), (0.020, -0.046), (-0.020, -0.040),
                    (-0.300, -0.034), (-0.340, -0.034), (-0.340, 0.022), (-0.060, 0.016), (-0.020, -0.012)], 0.046, mat="sn_stock")
    prism("butt_lower", [(-0.060, -0.036), (-0.200, -0.110), (-0.340, -0.122), (-0.340, -0.034)], 0.040, mat="sn_stock")
    prism("cheek", [(-0.080, 0.016), (-0.090, 0.040), (-0.250, 0.040), (-0.262, 0.020)], 0.036, mat="sn_stock")
    box("butt_pad", (0.046, 0.016, 0.150), (0.0, -0.348, -0.050), mat="ar_rubber", bevel=0.004)
    box("grip", (0.034, 0.046, 0.108), (0.0, -0.030, -0.100), rot=(-22, 0, 0), mat="sn_stock", bevel=0.007)
    box("trigger_guard", (0.012, 0.074, 0.0035), (0.0, 0.040, -0.082), mat="sn_steel", bevel=0.001)
    box("trigger_guard_front", (0.012, 0.0035, 0.032), (0.0, 0.077, -0.066), mat="sn_steel", bevel=0.001)
    box("trigger", (0.0055, 0.0060, 0.022), (0.0, 0.038, -0.064), rot=(-14, 0, 0), mat="sn_bolt", bevel=0.0012)
    box("forend_flat", (0.050, 0.240, 0.010), (0.0, 0.400, -0.050), mat="sn_stock", bevel=0.003)
    rod("sling_stud", 0.0035, (0.0, 0.500, -0.050), (0.0, 0.500, -0.064), mat="sn_steel", segments=10)
    # ---- the bipod, folded forward under the forend
    box("bipod_base", (0.040, 0.030, 0.012), (0.0, 0.470, -0.062), mat="sn_steel", bevel=0.002)
    for side in (-1.0, 1.0):
        rod("bipod_leg_%d" % side, 0.0055, (side * 0.020, 0.480, -0.068), (side * 0.026, 0.700, -0.060), mat="sn_steel", segments=10)
        rod("bipod_foot_%d" % side, 0.0075, (side * 0.026, 0.700, -0.060), (side * 0.0265, 0.722, -0.059), mat="ar_rubber", segments=10)
    # ---- the magazine
    box("magazine", (0.026, 0.084, 0.062), (0.0, 0.128, -0.080), rot=(4, 0, 0), mat="sn_steel", group="magazine", bevel=0.003)
    box("magazine_floor", (0.030, 0.090, 0.006), (0.0, 0.126, -0.112), rot=(4, 0, 0), mat="sn_stock", group="magazine", bevel=0.002)
    box("magazine_catch", (0.010, 0.006, 0.016), (0.0, 0.082, -0.070), mat="sn_steel", bevel=0.001)
    # ---- the bolt: body, shroud, handle and knob
    tube("bolt_body", 0.0098, -0.020, 0.160, mat="sn_bolt", group="bolt", segments=20)
    tube("bolt_shroud", 0.0135, -0.040, 0.000, mat="sn_steel", group="bolt", segments=20)
    tube("bolt_cocking", 0.0060, -0.052, -0.040, mat="sn_bolt", group="bolt", segments=12)
    rod("bolt_handle", 0.0052, (0.012, 0.012, -0.004), (0.050, 0.004, -0.034), mat="sn_bolt", group="bolt", segments=12)
    rod("bolt_knob", 0.0105, (0.047, 0.005, -0.031), (0.062, 0.001, -0.044), mat="sn_steel", group="bolt", segments=14)
    # ---- the scope: rail, rings, tube, bells, turrets
    box("rail", (0.022, 0.190, 0.008), (0.0, 0.105, 0.0205), mat="sn_steel", bevel=0.001)
    for k in range(9):
        box("rail_slot_%d" % k, (0.0225, 0.005, 0.003), (0.0, 0.025 + 0.020 * k, 0.0245), mat="ar_dark", bevel=0.0)
    for y in (0.045, 0.165):
        box("ring_base_%d" % int(y * 1000), (0.024, 0.016, 0.016), (0.0, y, 0.031), mat="sn_scope", bevel=0.002)
        tube("ring_%d" % int(y * 1000), 0.0185, y - 0.008, y + 0.008, z=SCOPE_Z, mat="sn_scope", segments=24)
        box("ring_cap_%d" % int(y * 1000), (0.012, 0.016, 0.006), (0.0, y, SCOPE_Z + 0.0195), mat="sn_scope", bevel=0.001)
    tube("scope_tube", 0.0150, -0.010, 0.250, z=SCOPE_Z, mat="sn_scope", segments=28)
    tube("ocular_flare", 0.0150, -0.012, -0.030, z=SCOPE_Z, mat="sn_scope", segments=28, radius_end=0.0205)
    tube("ocular", 0.0205, -0.030, -0.075, z=SCOPE_Z, mat="sn_scope", segments=28)
    tube("ocular_rubber", 0.0215, -0.075, -0.083, z=SCOPE_Z, mat="ar_rubber", segments=28)
    tube("ocular_lens", 0.0180, -0.0832, -0.0838, z=SCOPE_Z, mat="sn_glass", segments=24)
    tube("power_ring", 0.0222, -0.034, -0.022, z=SCOPE_Z, mat="sn_scope", segments=18)
    box("power_fin", (0.004, 0.010, 0.006), (0.0, -0.028, SCOPE_Z + 0.0235), mat="sn_scope", bevel=0.001)
    box("power_mark", (0.0015, 0.004, 0.0006), (0.0, -0.016, SCOPE_Z + 0.0152), mat="sn_mark", bevel=0.0)
    box("turret_block", (0.036, 0.034, 0.036), (0.0, 0.105, SCOPE_Z), mat="sn_scope", bevel=0.004)
    rod("turret_up", 0.0125, (0.0, 0.105, SCOPE_Z + 0.016), (0.0, 0.105, SCOPE_Z + 0.040), mat="sn_scope", segments=20)
    rod("turret_up_cap", 0.0135, (0.0, 0.105, SCOPE_Z + 0.034), (0.0, 0.105, SCOPE_Z + 0.040), mat="sn_scope", segments=20)
    rod("turret_side", 0.0125, (0.016, 0.105, SCOPE_Z), (0.040, 0.105, SCOPE_Z), mat="sn_scope", segments=20)
    rod("turret_focus", 0.0135, (-0.016, 0.105, SCOPE_Z), (-0.034, 0.105, SCOPE_Z), mat="sn_scope", segments=20)
    tube("objective_flare", 0.0150, 0.250, 0.300, z=SCOPE_Z, mat="sn_scope", segments=28, radius_end=0.0265)
    tube("objective", 0.0265, 0.300, 0.368, z=SCOPE_Z, mat="sn_scope", segments=28)
    tube("objective_lens", 0.0240, 0.3625, 0.3632, z=SCOPE_Z, mat="sn_glass", segments=24)


SOCKETS = {
    "grip_r": (0.0, -0.030, -0.098),
    "grip_l": (0.0, 0.340, -0.058),
    "muzzle": (0.0, 0.918, 0.0),
    "eject": (0.0200, 0.120, 0.006),
    "rear_sight": (0.0, -0.084, SCOPE_Z),
    "front_sight": (0.0, 0.363, SCOPE_Z),
    "butt": (0.0, -0.356, -0.040),
    "bolt_handle": (0.055, 0.003, -0.038),
    "mag": (0.0, 0.128, -0.090),
}
ORIGINS = {"bolt": (0.0, 0.0, 0.0), "magazine": (0.0, 0.128, -0.080)}


def assemble():
    root = bpy.data.objects.new("sniper", None)
    bpy.context.scene.collection.objects.link(root)
    parts = []
    for group, objects in GROUPS.items():
        part = join(objects, "sn_" + group, ORIGINS.get(group))
        part.parent = root
        parts.append(part)
    for name, at in SOCKETS.items():
        empty = bpy.data.objects.new(name, None)
        empty.empty_display_size = 0.02
        empty.location = at
        empty.parent = root
        bpy.context.scene.collection.objects.link(empty)
    return root, parts


def preview():
    scene = bpy.context.scene
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "BLENDER_WORKBENCH"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 560
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.35, 0.36, 0.38, 1.0)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    scene.world = world
    for name, at, energy in (("key", (0.9, 0.2, 0.9), 55.0), ("fill", (-0.9, 0.6, 0.3), 22.0), ("rim", (0.1, -0.9, 0.5), 18.0)):
        data = bpy.data.lights.new(name, "AREA")
        data.energy = energy
        data.size = 0.8
        lamp = bpy.data.objects.new(name, data)
        lamp.location = at
        lamp.rotation_euler = (Vector((0, 0.3, 0)) - Vector(at)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(lamp)
    os.makedirs(WORK, exist_ok=True)
    render(os.path.join(WORK, "sniper-side.png"), (1.45, 0.28, 0.16), (0.0, 0.28, -0.01), lens=60.0)
    render(os.path.join(WORK, "sniper-eye.png"), (-0.10, -0.42, 0.16), (0.0, 0.50, 0.03), lens=22.0)


def export():
    os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
    for o in bpy.context.scene.objects:
        o.select_set(o.type in ("MESH", "EMPTY"))
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", use_selection=True, export_animations=False,
                              export_yup=True, export_apply=True)
    print("EXPORTED", OUT_GLB, os.path.getsize(OUT_GLB))


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build()
    root, parts = assemble()
    print("SNIPER parts", [p.name for p in parts], "faces", sum(len(p.data.polygons) for p in parts))
    if "export" in args:
        export()
    if "preview" in args:
        preview()


main()
