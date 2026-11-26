"""Sleep 0.27: the debug-only automatic rifle, a generic AR-15 pattern carbine.

  blender -b --factory-startup --python tools/blender/story/build_ar15.py -- [preview] [export]

  preview   two renders                          -> work/v27/rifle/ar15-side.png, ar15-eye.png
  export    game/assets/models/story/ar15.glb

No maker's marks: a flat-top upper with a full rail, a 13 inch free-float handguard with slots, a 16 inch barrel with a
birdcage flash hider, flip-up iron sights (aperture rear, post front), a collapsible stock, a 30-round magazine.

Frame (Blender, Z up): the bore is the Y axis, muzzle toward +Y, the shooter's right is +X, y = 0 is the rear face of
the upper receiver. In glTF / Godot (Y up) that is: muzzle along -Z, right +X, so the rifle sits under a Camera3D
without turning. Objects: `ar15_body`, `ar15_magazine`, `ar15_bolt`, `ar15_charging_handle` (the last three move in
the game), and empties for where things are: `grip_r` (the fist round the pistol grip), `grip_l` (the hand under the
handguard), `muzzle`, `eject`, `rear_sight`, `front_sight`, `butt`.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
OUT_GLB = os.path.join(ROOT, "game", "assets", "models", "story", "ar15.glb")
WORK = os.path.join(ROOT, "work", "v27", "rifle")

MATERIALS = {
    # name: (colour, metallic, roughness)
    "ar_anodised": ((0.170, 0.175, 0.185), 0.35, 0.50),
    "ar_polymer": ((0.100, 0.100, 0.106), 0.0, 0.70),
    "ar_steel": ((0.230, 0.230, 0.240), 0.5, 0.42),
    "ar_bolt": ((0.42, 0.41, 0.39), 1.0, 0.30),
    "ar_dark": ((0.004, 0.004, 0.004), 0.0, 0.9),
    "ar_rubber": ((0.016, 0.016, 0.016), 0.0, 0.85),
    "ar_magazine": ((0.120, 0.120, 0.127), 0.0, 0.55),
    "ar_brass": ((0.70, 0.52, 0.22), 1.0, 0.35),
}
GROUPS = {"body": [], "magazine": [], "bolt": [], "charging_handle": []}
_materials = {}


def material(name):
    if name not in _materials:
        colour, metallic, roughness = MATERIALS[name]
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = (*colour, 1.0)
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness
        _materials[name] = m
    return _materials[name]


def finish(bm, name, mat, group, matrix=None, smooth_axis=None):
    """A bmesh becomes an object in a group. Faces whose normal is across `smooth_axis` are smooth (a tube's wall)."""
    if matrix is not None:
        bmesh.ops.transform(bm, matrix=matrix, verts=bm.verts)
    bm.normal_update()
    if smooth_axis is not None:
        axis = (matrix.to_3x3() @ Vector(smooth_axis)).normalized() if matrix is not None else Vector(smooth_axis)
        for face in bm.faces:
            face.smooth = abs(face.normal.dot(axis)) < 0.5
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(material(mat))
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    GROUPS[group].append(obj)
    return obj


def place(loc, rot=(0.0, 0.0, 0.0)):
    return Matrix.Translation(Vector(loc)) @ Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4()


def box(name, size, loc, rot=(0.0, 0.0, 0.0), mat="ar_anodised", group="body", bevel=0.0012):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    if bevel > 0.0 and min(size) > bevel * 2.5:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=2, profile=0.5, affect="EDGES")
    return finish(bm, name, mat, group, place(loc, rot))


def tube(name, radius, y0, y1, z=0.0, x=0.0, mat="ar_steel", group="body", segments=28, radius_end=None, spin=0.0):
    """A cylinder along the bore (Y) from y0 to y1."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments, radius1=radius,
                          radius2=radius if radius_end is None else radius_end, depth=abs(y1 - y0))
    # create_cone runs along Z with radius1 at -Z: turn -Z to the rear (-Y).
    matrix = place((x, (y0 + y1) / 2.0, z)) @ Matrix.Rotation(math.radians(-90.0), 4, "X") @ Matrix.Rotation(spin, 4, "Z")
    return finish(bm, name, mat, group, matrix, smooth_axis=(0, 0, 1) if segments > 12 else None)


def rod(name, radius, a, b, mat="ar_steel", group="body", segments=16):
    """A cylinder from point a to point b."""
    a, b = Vector(a), Vector(b)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments, radius1=radius, radius2=radius,
                          depth=(b - a).length)
    turn = Vector((0, 0, 1)).rotation_difference((b - a).normalized()).to_matrix().to_4x4()
    return finish(bm, name, mat, group, Matrix.Translation((a + b) / 2.0) @ turn, smooth_axis=(0, 0, 1))


def prism(name, profile, width, mat="ar_polymer", group="body", bevel=0.0018):
    """A side profile [(y, z), ...] given clockwise seen from the right, extruded across X."""
    bm = bmesh.new()
    right = [bm.verts.new((width / 2.0, y, z)) for y, z in profile]
    left = [bm.verts.new((-width / 2.0, y, z)) for y, z in profile]
    bm.faces.new(right)
    bm.faces.new(list(reversed(left)))
    count = len(profile)
    for i in range(count):
        j = (i + 1) % count
        bm.faces.new([right[j], right[i], left[i], left[j]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if bevel > 0.0:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=2, profile=0.5, affect="EDGES")
    return finish(bm, name, mat, group)


def ring(name, major, minor, loc, mat="ar_steel", group="body"):
    """A torus whose hole looks along the bore."""
    bm = bmesh.new()
    seg_major, seg_minor = 28, 10
    rows = []
    for i in range(seg_major):
        a = 2.0 * math.pi * i / seg_major
        row = []
        for j in range(seg_minor):
            b = 2.0 * math.pi * j / seg_minor
            r = major + minor * math.cos(b)
            row.append(bm.verts.new((r * math.cos(a), minor * math.sin(b), r * math.sin(a))))
        rows.append(row)
    for i in range(seg_major):
        for j in range(seg_minor):
            bm.faces.new([rows[i][j], rows[(i + 1) % seg_major][j], rows[(i + 1) % seg_major][(j + 1) % seg_minor],
                          rows[i][(j + 1) % seg_minor]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for face in bm.faces:
        face.smooth = True
    return finish(bm, name, mat, group, place(loc))


def rail(prefix, y0, y1, top, group="body"):
    """Cross-slotted accessory rail: a strip of teeth 10 mm apart."""
    y = y0
    index = 0
    while y + 0.0055 <= y1:
        box("%s_tooth_%d" % (prefix, index), (0.0212, 0.0055, 0.0034), (0.0, y + 0.00275, top - 0.0017), group=group,
            bevel=0.0005)
        y += 0.010
        index += 1


def build():
    # ---- upper receiver
    box("upper", (0.036, 0.200, 0.050), (0.0, 0.100, 0.003), bevel=0.003)
    tube("upper_round", 0.0226, 0.0, 0.200, z=0.004, mat="ar_anodised")
    box("upper_riser", (0.0225, 0.192, 0.0085), (0.0, 0.100, 0.0335), bevel=0.0008)
    rail("upper_rail", 0.008, 0.196, 0.0412)
    tube("forward_assist", 0.0072, 0.012, 0.050, z=0.006, x=0.0265, mat="ar_anodised", segments=16)
    tube("forward_assist_cap", 0.0086, 0.004, 0.013, z=0.006, x=0.0265, mat="ar_anodised", segments=16)
    box("deflector", (0.011, 0.020, 0.017), (0.0245, 0.064, 0.007), rot=(0, 0, 18), bevel=0.002)
    box("port", (0.0012, 0.066, 0.019), (0.0224, 0.108, 0.005), mat="ar_dark", bevel=0.0)
    box("dust_cover", (0.0026, 0.070, 0.022), (0.0262, 0.108, -0.015), rot=(0, 18, 0), bevel=0.0006)
    # ---- the parts that move
    box("bolt_carrier", (0.0016, 0.060, 0.0145), (0.0230, 0.108, 0.005), mat="ar_bolt", group="bolt", bevel=0.0)
    box("bolt_lugs", (0.0018, 0.010, 0.011), (0.0232, 0.134, 0.005), mat="ar_steel", group="bolt", bevel=0.0)
    box("charging_bar", (0.014, 0.034, 0.0075), (0.0, 0.003, 0.0262), group="charging_handle", bevel=0.001)
    box("charging_wings", (0.058, 0.011, 0.0080), (0.0, -0.0105, 0.0262), group="charging_handle", bevel=0.0015)
    box("charging_latch", (0.016, 0.017, 0.0082), (-0.0235, -0.004, 0.0262), group="charging_handle", bevel=0.001)
    # ---- lower receiver
    box("lower", (0.036, 0.192, 0.050), (0.0, 0.084, -0.045), bevel=0.003)
    tube("extension_ring", 0.0195, -0.020, 0.002, z=-0.004, mat="ar_anodised")
    box("magwell", (0.035, 0.070, 0.074), (0.0, 0.123, -0.075), bevel=0.0025)
    box("magwell_lip", (0.038, 0.074, 0.006), (0.0, 0.123, -0.110), bevel=0.0015)
    box("trigger_guard", (0.011, 0.074, 0.0032), (0.0, 0.046, -0.099), bevel=0.0008)
    box("trigger", (0.0055, 0.0062, 0.022), (0.0, 0.054, -0.082), rot=(-16, 0, 0), mat="ar_steel", bevel=0.0012)
    box("grip", (0.030, 0.043, 0.108), (0.0, -0.0275, -0.1165), rot=(-25, 0, 0), mat="ar_polymer", bevel=0.005)
    box("grip_tang", (0.028, 0.032, 0.016), (0.0, -0.020, -0.064), mat="ar_polymer", bevel=0.003)
    box("grip_cap", (0.031, 0.045, 0.006), (0.0, -0.0505, -0.1655), rot=(-25, 0, 0), mat="ar_polymer", bevel=0.002)
    rod("selector_pin", 0.0048, (-0.0215, 0.012, -0.036), (-0.0180, 0.012, -0.036), mat="ar_steel")
    box("selector_lever", (0.0030, 0.020, 0.0055), (-0.0225, 0.020, -0.036), mat="ar_steel", bevel=0.0008)
    box("bolt_catch", (0.0040, 0.012, 0.026), (-0.0200, 0.090, -0.016), mat="ar_steel", bevel=0.001)
    rod("mag_release", 0.0052, (0.0180, 0.078, -0.040), (0.0222, 0.078, -0.040), mat="ar_steel")
    for name, y, z in (("takedown_pin", 0.012, -0.021), ("pivot_pin", 0.180, -0.030)):
        rod(name, 0.0034, (-0.0188, y, z), (0.0188, y, z), mat="ar_steel", segments=12)
    # ---- magazine (its own object; it drops out for a reload)
    box("mag_upper", (0.0228, 0.062, 0.096), (0.0, 0.123, -0.100), mat="ar_magazine", group="magazine", bevel=0.002)
    box("mag_lower", (0.0228, 0.062, 0.104), (0.0, 0.1335, -0.186), rot=(12, 0, 0), mat="ar_magazine", group="magazine",
        bevel=0.002)
    box("mag_base", (0.0262, 0.067, 0.008), (0.0, 0.1448, -0.2385), rot=(12, 0, 0), mat="ar_magazine", group="magazine",
        bevel=0.0015)
    for side in (-1.0, 1.0):
        for k, y in enumerate((0.108, 0.123, 0.138)):
            box("mag_rib_%d_%d" % (k, side), (0.0012, 0.004, 0.150), (side * 0.0118, y + 0.006, -0.158), rot=(7, 0, 0),
                mat="ar_magazine", group="magazine", bevel=0.0)
    # ---- buffer tube and stock
    tube("buffer_tube", 0.0146, -0.218, 0.0, z=-0.004, mat="ar_anodised")
    tube("castle_nut", 0.0192, -0.030, -0.018, z=-0.004, mat="ar_steel", segments=12)
    box("end_plate", (0.040, 0.004, 0.046), (0.0, -0.016, -0.008), mat="ar_steel", bevel=0.001)
    prism("stock", [(-0.070, 0.016), (-0.250, 0.016), (-0.262, 0.010), (-0.262, -0.112), (-0.240, -0.116),
                    (-0.165, -0.034), (-0.070, -0.026)], 0.040)
    box("stock_latch", (0.022, 0.050, 0.008), (0.0, -0.120, -0.034), mat="ar_polymer", bevel=0.002)
    box("butt_pad", (0.043, 0.011, 0.134), (0.0, -0.2685, -0.051), mat="ar_rubber", bevel=0.003)
    # ---- handguard, barrel, muzzle
    tube("barrel_nut", 0.0245, 0.198, 0.214, z=0.002, mat="ar_anodised")
    tube("handguard", 0.0238, 0.212, 0.530, z=0.002, mat="ar_anodised", segments=8, spin=math.radians(22.5))
    tube("handguard_end", 0.0218, 0.528, 0.534, z=0.002, mat="ar_dark", segments=8, spin=math.radians(22.5))
    box("handguard_riser", (0.0225, 0.320, 0.0150), (0.0, 0.371, 0.0305), bevel=0.0008)
    rail("handguard_rail", 0.214, 0.530, 0.0412)
    flat = 0.0238 * math.cos(math.radians(22.5))
    for k in range(5):
        y = 0.250 + 0.054 * k
        for side in (-1.0, 1.0):
            box("slot_side_%d_%d" % (k, side), (0.0008, 0.032, 0.0072), (side * (flat + 0.0002), y, 0.002), mat="ar_dark",
                bevel=0.0)
            diagonal = (flat + 0.0002) * math.sin(math.radians(45.0))
            box("slot_low_%d_%d" % (k, side), (0.0008, 0.032, 0.0072), (side * diagonal, y, 0.002 - diagonal),
                rot=(0, side * 45.0, 0), mat="ar_dark", bevel=0.0)
        box("slot_under_%d" % k, (0.0072, 0.032, 0.0008), (0.0, y, 0.002 - flat - 0.0002), mat="ar_dark", bevel=0.0)
    tube("barrel", 0.0086, 0.200, 0.606, mat="ar_steel", segments=20)
    tube("gas_block", 0.0125, 0.430, 0.458, mat="ar_steel", segments=16)
    tube("crush_washer", 0.0102, 0.600, 0.606, mat="ar_steel", segments=16)
    tube("flash_hider", 0.0110, 0.606, 0.650, mat="ar_steel", segments=20)
    tube("flash_hider_bore", 0.0048, 0.6495, 0.6505, mat="ar_dark", segments=16)
    for k in range(5):
        angle = math.radians(-60.0 + 30.0 * k + 90.0)
        x, z = 0.0111 * math.cos(angle), 0.0111 * math.sin(angle)
        box("flash_slot_%d" % k, (0.0026, 0.024, 0.0010), (x, 0.630, z), rot=(0, 90.0 - math.degrees(angle), 0),
            mat="ar_dark", bevel=0.0)
    # ---- iron sights, both flipped up
    box("rear_sight_base", (0.0235, 0.034, 0.0105), (0.0, 0.024, 0.0462), bevel=0.0012)
    for side in (-1.0, 1.0):
        box("rear_sight_ear_%d" % side, (0.0030, 0.0050, 0.029), (side * 0.0122, 0.016, 0.0640), bevel=0.0008)
    box("rear_sight_bar", (0.0274, 0.0050, 0.0040), (0.0, 0.016, 0.0520), bevel=0.0006)
    ring("rear_sight_aperture", 0.0088, 0.0017, (0.0, 0.016, 0.0660), mat="ar_anodised")
    box("front_sight_base", (0.0235, 0.030, 0.0105), (0.0, 0.505, 0.0462), bevel=0.0012)
    for side in (-1.0, 1.0):
        box("front_sight_ear_%d" % side, (0.0030, 0.011, 0.030), (side * 0.0085, 0.505, 0.0650), rot=(0, side * -8.0, 0),
            bevel=0.0008)
    box("front_sight_block", (0.0140, 0.0090, 0.0100), (0.0, 0.505, 0.0540), bevel=0.0008)
    rod("front_sight_post", 0.0011, (0.0, 0.505, 0.0560), (0.0, 0.505, 0.0668), mat="ar_steel", segments=8)


SOCKETS = {
    "grip_r": (0.0, -0.027, -0.114),
    "grip_l": (0.0, 0.262, -0.024),
    "muzzle": (0.0, 0.652, 0.0),
    "eject": (0.0245, 0.108, 0.007),
    "rear_sight": (0.0, 0.016, 0.0660),
    "front_sight": (0.0, 0.505, 0.0660),
    "butt": (0.0, -0.274, -0.040),
}
ORIGINS = {"magazine": (0.0, 0.123, -0.110), "bolt": (0.0230, 0.108, 0.005), "charging_handle": (0.0, 0.0, 0.0262)}


def join(objects, name, origin=None):
    for o in bpy.context.scene.objects:
        o.select_set(o in objects)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    result = bpy.context.view_layer.objects.active
    result.name = name
    result.data.name = name
    if origin is not None:
        offset = Vector(origin)
        result.data.transform(Matrix.Translation(-offset))
        result.location = offset
    return result


def assemble():
    root = bpy.data.objects.new("ar15", None)
    bpy.context.scene.collection.objects.link(root)
    parts = []
    for group, objects in GROUPS.items():
        part = join(objects, "ar15_" + group, ORIGINS.get(group))
        part.parent = root
        parts.append(part)
    for name, at in SOCKETS.items():
        empty = bpy.data.objects.new(name, None)
        empty.empty_display_size = 0.02
        empty.location = at
        empty.parent = root
        bpy.context.scene.collection.objects.link(empty)
    return root, parts


def render(path, eye, target, lens=50.0):
    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("cam")
    cam_data.lens = lens
    cam_data.clip_start = 0.01
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = eye
    cam.rotation_euler = (Vector(target) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)


def preview():
    scene = bpy.context.scene
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "BLENDER_WORKBENCH"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 640
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
    render(os.path.join(WORK, "ar15-side.png"), (1.05, 0.20, 0.12), (0.0, 0.20, -0.03), lens=60.0)
    render(os.path.join(WORK, "ar15-left.png"), (-0.75, -0.25, 0.30), (0.0, 0.22, -0.02), lens=50.0)
    # Roughly the body camera's view of it, sights up.
    render(os.path.join(WORK, "ar15-eye.png"), (-0.02, -0.16, 0.10), (0.0, 0.60, 0.05), lens=14.0)


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
    triangles = sum(len(p.data.polygons) for p in parts)
    print("AR15 parts", [p.name for p in parts], "faces", triangles)
    if "export" in args:
        export()
    if "preview" in args:
        preview()


main()
