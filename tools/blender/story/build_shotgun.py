"""Interior 0.28: the debug-only pump shotgun, a generic 12 gauge of the kind the town's security guards carry.

  blender -b --factory-startup --python tools/blender/story/build_shotgun.py -- [preview] [export]

  preview   two renders                          -> work/v28/shotgun/shotgun-side.png, shotgun-eye.png
  export    game/assets/models/story/shotgun.glb

No maker's marks: a steel receiver, a 20 inch barrel over a full-length magazine tube, a ribbed pump, a pistol-grip
stock, a bead front sight, a carrier of five spare shells on the left of the receiver.

Same frame as build_ar15.py (bore along +Y in Blender, -Z in Godot; y = 0 is the rear face of the receiver).
Objects: `sg_body`, `sg_forend` (the pump: slides back 85 mm), `sg_bolt`, and the empties `grip_r`, `grip_l`
(under the pump), `muzzle`, `eject`, `rear_sight`, `front_sight`, `butt`.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
# The AR-15 builder's primitives (box, tube, rod, prism, ring, join...), without running its build.
_source = open(os.path.join(HERE, "build_ar15.py"), encoding="utf-8").read()
exec(_source[:_source.index("def build():")] + _source[_source.index("def join("):_source.index("def assemble():")]
     + _source[_source.index("def render("):_source.index("def preview():")])

OUT_GLB = os.path.join(ROOT, "game", "assets", "models", "story", "shotgun.glb")
WORK = os.path.join(ROOT, "work", "v28", "shotgun")
MATERIALS.update({
    "sg_steel": ((0.085, 0.088, 0.095), 0.7, 0.42),
    "sg_polymer": ((0.045, 0.045, 0.048), 0.0, 0.72),
    "sg_bolt": ((0.50, 0.49, 0.47), 1.0, 0.28),
    "sg_shell": ((0.50, 0.045, 0.035), 0.0, 0.45),
})
GROUPS.clear()
GROUPS.update({"body": [], "forend": [], "bolt": []})
MAG_Z = -0.031


def build():
    # ---- receiver
    box("receiver", (0.040, 0.215, 0.064), (0.0, 0.1075, -0.010), mat="sg_steel", bevel=0.004)
    box("receiver_top", (0.024, 0.200, 0.006), (0.0, 0.105, 0.0245), mat="sg_steel", bevel=0.0015)
    box("port", (0.0012, 0.072, 0.022), (0.0204, 0.135, 0.004), mat="ar_dark", bevel=0.0)
    box("bolt_face", (0.0016, 0.066, 0.017), (0.0208, 0.135, 0.004), mat="sg_bolt", group="bolt", bevel=0.0)
    box("loading_port", (0.026, 0.085, 0.0012), (0.0, 0.130, -0.0424), mat="ar_dark", bevel=0.0)
    box("trigger_guard", (0.012, 0.080, 0.0035), (0.0, 0.040, -0.076), mat="sg_polymer", bevel=0.001)
    box("trigger_plate", (0.030, 0.090, 0.012), (0.0, 0.045, -0.046), mat="sg_polymer", bevel=0.002)
    box("trigger", (0.0055, 0.0062, 0.022), (0.0, 0.050, -0.060), rot=(-16, 0, 0), mat="ar_steel", bevel=0.0012)
    rod("safety", 0.0045, (-0.0205, 0.012, -0.040), (0.0205, 0.012, -0.040), mat="ar_steel")
    # ---- pistol-grip stock
    box("grip", (0.032, 0.045, 0.110), (0.0, -0.0275, -0.1165), rot=(-25, 0, 0), mat="sg_polymer", bevel=0.006)
    box("grip_tang", (0.034, 0.050, 0.030), (0.0, -0.018, -0.052), mat="sg_polymer", bevel=0.004)
    prism("stock", [(0.004, 0.020), (-0.300, 0.012), (-0.322, 0.004), (-0.322, -0.118), (-0.300, -0.122),
                    (-0.150, -0.060), (-0.050, -0.040), (0.004, -0.040)], 0.040, mat="sg_polymer")
    box("butt_pad", (0.043, 0.014, 0.130), (0.0, -0.329, -0.057), mat="ar_rubber", bevel=0.004)
    # ---- barrel and magazine tube
    tube("barrel", 0.0118, 0.205, 0.720, mat="sg_steel", segments=24)
    tube("barrel_bore", 0.0092, 0.7195, 0.7205, mat="ar_dark", segments=20)
    tube("barrel_seat", 0.0165, 0.205, 0.245, mat="sg_steel", segments=24)
    tube("magazine_tube", 0.0128, 0.210, 0.675, z=MAG_Z, mat="sg_steel", segments=24)
    tube("magazine_cap", 0.0142, 0.672, 0.690, z=MAG_Z, mat="sg_steel", segments=16)
    box("barrel_clamp", (0.036, 0.016, 0.060), (0.0, 0.610, -0.016), mat="sg_steel", bevel=0.004)
    rod("bead", 0.0022, (0.0, 0.705, 0.0115), (0.0, 0.705, 0.0180), mat="ar_brass", segments=10)
    box("bead_base", (0.008, 0.018, 0.004), (0.0, 0.705, 0.0125), mat="sg_steel", bevel=0.001)
    # ---- the pump
    tube("forend", 0.0255, 0.300, 0.480, z=MAG_Z, mat="sg_polymer", group="forend", segments=20)
    for k in range(9):
        tube("forend_rib_%d" % k, 0.0272, 0.312 + 0.0185 * k, 0.320 + 0.0185 * k, z=MAG_Z, mat="sg_polymer",
             group="forend", segments=20)
    for side in (-1.0, 1.0):
        box("action_bar_%d" % side, (0.003, 0.150, 0.008), (side * 0.0165, 0.235, MAG_Z + 0.004), mat="sg_steel",
            group="forend", bevel=0.0)
    # ---- five spare shells on the left of the receiver
    box("shell_carrier", (0.004, 0.130, 0.040), (-0.0225, 0.110, -0.006), mat="sg_polymer", bevel=0.001)
    for k in range(5):
        y = 0.062 + 0.024 * k
        rod("shell_%d" % k, 0.0102, (-0.0345, y, -0.030), (-0.0345, y, 0.020), mat="sg_shell", segments=14)
        rod("shell_brass_%d" % k, 0.0106, (-0.0345, y, -0.036), (-0.0345, y, -0.026), mat="ar_brass", segments=14)


SOCKETS = {
    "grip_r": (0.0, -0.027, -0.114),
    "grip_l": (0.0, 0.390, MAG_Z - 0.026),
    "muzzle": (0.0, 0.722, 0.0),
    "eject": (0.0230, 0.135, 0.006),
    "rear_sight": (0.0, 0.012, 0.0285),
    "front_sight": (0.0, 0.705, 0.0180),
    "butt": (0.0, -0.336, -0.050),
}
ORIGINS = {"forend": (0.0, 0.390, MAG_Z), "bolt": (0.0208, 0.135, 0.004)}


def assemble():
    root = bpy.data.objects.new("shotgun", None)
    bpy.context.scene.collection.objects.link(root)
    parts = []
    for group, objects in GROUPS.items():
        part = join(objects, "sg_" + group, ORIGINS.get(group))
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
        lamp.rotation_euler = (Vector((0, 0.2, 0)) - Vector(at)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(lamp)
    os.makedirs(WORK, exist_ok=True)
    render(os.path.join(WORK, "shotgun-side.png"), (-1.15, 0.20, 0.14), (0.0, 0.20, -0.03), lens=60.0)
    render(os.path.join(WORK, "shotgun-eye.png"), (-0.02, -0.16, 0.10), (0.0, 0.60, 0.05), lens=14.0)


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
    print("SHOTGUN parts", [p.name for p in parts], "faces", sum(len(p.data.polygons) for p in parts))
    if "export" in args:
        export()
    if "preview" in args:
        preview()


main()
