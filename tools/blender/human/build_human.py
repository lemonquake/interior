"""Interior 0.9 / 0.11: the game's people, built on the owner's base body (models/generic_body*).

  blender -b --factory-startup --python tools/blender/human/build_human.py -- [hair] [preview] [crouch] [export] [hood_down]

  hair      head renders of the hair candidates            -> work/v11/human/hair_<style>.png
  crouch    0.23 crouch_walk frames                 -> work/v11/human/crouch_*.png
  preview   the 0.11 hood sheet (poses x views, face shot)  -> work/v11/human/*.png (+ 01-hood-sheet.jpg)
  export    game/assets/characters/stranger.glb
  hood_down build the 0.9 look (hood folded on the back, side-part hair) instead of HOOD = "up"

Source: models/generic_body_rigged.glb is generic_body.obj skinned to a 24-bone humanoid skeleton with a
132-clip action library (made with the same owner's Beyond Heroes hero pipeline, tools/blender/hero/hero_body.py).
Space: metres, Z up, the figure faces -Y, its left is +X, feet on z = 0, T-pose (arms along X at z = 1.44).

The stranger: casual clothes made as offset shells of the body (so they share its skin weights exactly):
a loose black hoodie with the hood down, ribbed cuffs and hem, a kangaroo pocket and white drawstrings,
dark jeans, dark sneakers with pale soles, short black hair. The skin under the clothes is removed.
Clips: the civilian part of the library plus two new loops, gate_grip (both hands on the courtyard gate,
arms spread, leaning in, breathing hard, staring up) and stand_stare (standing still, breathing, head tilted).

0.11 (HOOD = "up"): the hood is up, a shell built from the body's head and neck (offset 3-5 cm, a brim 8 cm past
the forehead down to the eyebrows), with a near-black lining, a drawstring channel, a crown seam and the strings
hanging from the opening; no hair; the face is shadowed in the skin texture. New clips: hand_over (one-shot, the
right palm held out with the ammo box; HAND_OVER_RELEASE) and carry_box (walk, box on the raised right forearm).
An empty `box_grip` rides on hand.R where the box sits on his fist.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector, noise
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
from retarget_run import retarget_run

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
SRC = os.path.join(ROOT, "models", "generic_body_rigged.glb")
SKIN_TEX = os.path.join(ROOT, "models", "generic_body.jpg")
HAIR_DIR = os.path.join(ROOT, "models", "generic_body_hair")
OUT_GLB = os.path.join(ROOT, "game", "assets", "characters", "stranger.glb")
WORK = os.path.join(ROOT, "work", "v11", "human")
HAIR_STYLE = "sidepart"
FPS = 30
# "up": the 0.11 hooded man (hood over the head, no hair, face in shadow). "down": the 0.9 look (hood folded on the
# upper back, side-part hair). The `hood_down` CLI arg overrides it.
HOOD = "up"
# hand_over (one-shot, 2.6 s): the palm comes up by 0.85 s, holds still until 1.65 s, then the empty hand goes back
# to his side. HAND_OVER_RELEASE is the moment, inside the hold, when the player takes the box (stranger.gd moves the
# box from box_grip to the camera here).
HAND_OVER_LEN = 2.6
HAND_OVER_RELEASE = 1.2
HAND_OVER_HOLD = (0.85, 1.65)
# The wrist at full reach (model space): 0.45 m in front of his chest (the fist ~0.57 m in front of the body's
# centre line) at ~1.25 m, a little right of centre; the arm is slightly bent.
HAND_OVER_WRIST = Vector((-0.14, -0.50, 1.21))
# box_grip, in hand.R's bone frame (head at the wrist, +Y along the hand, the curled fingers / palm side at -Z):
# the ammo box (120 x 75 x 40 mm, X x Y x Z, origin at its centre) lies on the fist's curled fingers. The empty's X
# runs across the knuckles, its Z points out of the palm (so the box's 40 mm side stands off the hand).
BOX_GRIP_LOC = Vector((-0.025, 0.07, -0.088))
BOX_GRIP_ROT = Matrix.Rotation(math.pi, 4, "X")

KEEP_CLIPS = ["idle", "idle_look", "idle_adjust", "idle_hurt", "walk", "run", "walk_back", "strafe_l", "strafe_r",
              "walk_hurt", "run_hurt", "run_start", "run_stop", "turn_l", "turn_r", "dodge_step", "hit_light",
              "hit_heavy", "hit_front", "hit_back", "stagger_small", "knockback", "knockdown", "getup", "death",
              "death_back", "death_fwd", "death_crumple", "interact_pickup", "interact_talk", "hero_walk", "hero_run",
              "hero_stroll", "hero_alert"]

# Gate grip: where the wrists sit, in model space (the gate's bars are ~0.40 m in front of the body's centre).
GRIP_L = Vector((0.53, -0.32, 1.33))
GRIP_R = Vector((-0.53, -0.32, 1.33))
HEM_Z = 0.925
NECK_Z = 1.505


def args():
    a = sys.argv
    return a[a.index("--") + 1:] if "--" in a else []


# ---------------------------------------------------------------- scene

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS


def load_body():
    bpy.ops.import_scene.gltf(filepath=SRC)
    arm = body = None
    for ob in list(bpy.data.objects):
        if ob.type == "ARMATURE":
            arm = ob
        elif ob.type == "MESH" and ob.parent is not None:
            body = ob
        else:
            bpy.data.objects.remove(ob)
    ad = arm.animation_data
    for track in list(ad.nla_tracks):
        ad.nla_tracks.remove(track)
    for act in list(bpy.data.actions):
        if act.name in KEEP_CLIPS:
            act.use_fake_user = True
        else:
            bpy.data.actions.remove(act)
    # The male body is the basis; the creator's sliders (shape keys) are not used here.
    body.shape_key_clear()
    me = body.data
    while len(me.uv_layers) > 1:
        me.uv_layers.remove(me.uv_layers[-1])
    for attr in list(me.color_attributes):
        me.color_attributes.remove(attr)
    # Use the owner's downloaded run. Its rig has different rest rotations and
    # bone names; the shared retarget keeps the original timing and body motion.
    retarget_run(arm)
    return arm, body


def set_action(arm, act, frame=None):
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = act
    if act is not None and len(act.slots) and ad.action_slot is None:
        ad.action_slot = act.slots[0]
    if frame is not None:
        bpy.context.scene.frame_set(int(frame))


# ---------------------------------------------------------------- materials

def principled(name, color, rough, tex=None, sheen=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    if sheen > 0.0 and "Sheen Weight" in bsdf.inputs:
        bsdf.inputs["Sheen Weight"].default_value = sheen
    if tex:
        img = bpy.data.images.load(tex)
        node = m.node_tree.nodes.new("ShaderNodeTexImage")
        node.image = img
        m.node_tree.links.new(node.outputs["Color"], bsdf.inputs["Base Color"])
    return m


def materials():
    return {
        "skin": principled("Human skin", (0.7, 0.5, 0.4), 0.62, SKIN_TEX),
        "hoodie": principled("Hoodie black", (0.034, 0.034, 0.037), 0.9, sheen=0.3),
        "rib": principled("Hoodie rib", (0.026, 0.026, 0.028), 0.95),
        "string": principled("Hoodie drawstring", (0.62, 0.61, 0.58), 0.8),
        "jeans": principled("Jeans dark", (0.05, 0.058, 0.08), 0.86),
        "shoe": principled("Sneaker", (0.075, 0.075, 0.08), 0.68),
        "sole": principled("Sneaker sole", (0.66, 0.64, 0.6), 0.75),
        "hair": principled("Hair black", (0.014, 0.012, 0.011), 0.6),
        "hood_in": principled("Hood lining", (0.006, 0.006, 0.0068), 1.0),
    }


# ---------------------------------------------------------------- clothes

def neck_r(co):
    return math.hypot(co.x, co.y + 0.025)


def duplicate(ob, name):
    new = ob.copy()
    new.data = ob.data.copy()
    new.name = name
    new.data.name = name
    bpy.context.scene.collection.objects.link(new)
    return new


def cut(ob, planes, drop=None):
    """Bisects the mesh with each (point, normal) plane, clearing the side the normal points to; then deletes
    the vertices `drop(co)` marks."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    # The imported body is split along its UV seams; weld it, or inflate() opens cracks along every seam.
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    for co, no in planes:
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-5, plane_co=co, plane_no=no, clear_outer=True)
    if drop is not None:
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if drop(v.co)], context="VERTS")
    # Loose islands left by the cuts (e.g. bits of the other limb) go.
    bm.verts.ensure_lookup_table()
    bm.to_mesh(ob.data)
    bm.free()
    keep_largest_parts(ob)


def keep_largest_parts(ob, min_verts=40):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    seen = set()
    small = []
    for v in bm.verts:
        if v.index in seen:
            continue
        part = []
        stack = [v]
        seen.add(v.index)
        while stack:
            u = stack.pop()
            part.append(u)
            for e in u.link_edges:
                w = e.other_vert(u)
                if w.index not in seen:
                    seen.add(w.index)
                    stack.append(w)
        if len(part) < min_verts:
            small.extend(part)
    if small:
        bmesh.ops.delete(bm, geom=small, context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()


def inflate(ob, offset, smooth_iters=2, wrinkle=0.0):
    """Moves each vertex out along its normal by offset(co, n) (+ a little low-frequency cloth noise), then relaxes
    the result so the garment doesn't copy every muscle; open borders stay put."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.normal_update()
    base = {v: v.co.copy() for v in bm.verts}
    for v in bm.verts:
        d = offset(v.co, v.normal)
        if wrinkle > 0.0:
            d += wrinkle * noise.noise(v.co * 11.0) + wrinkle * 0.5 * noise.noise(v.co * 23.0 + Vector((3, 1, 7)))
        v.co = base[v] + v.normal * d
    for _ in range(smooth_iters):
        new = {}
        for v in bm.verts:
            if v.is_boundary or not v.link_edges:
                continue
            avg = sum((e.other_vert(v).co for e in v.link_edges), Vector()) / len(v.link_edges)
            new[v] = v.co.lerp(avg, 0.45)
        for v, co in new.items():
            v.co = co
    bm.to_mesh(ob.data)
    bm.free()


def set_material(ob, mat):
    ob.data.materials.clear()
    ob.data.materials.append(mat)


def assign_by_face(ob, mats, pick):
    """Gives each face the material `pick(centre)` names; mats is the ordered {key: material} for the slots."""
    ob.data.materials.clear()
    keys = list(mats)
    for k in keys:
        ob.data.materials.append(mats[k])
    for p in ob.data.polygons:
        p.material_index = keys.index(pick(p.center))


def hoodie(body, M):
    ob = duplicate(body, "Hoodie")
    # The hem stops above the crotch (z 0.82) so it hangs as one tube around the hips, not around each thigh.
    # Neckline: one plane across the base of the neck, lower at the front, so the opening is a clean ring.
    if HOOD == "up":
        # The plane neckline below also opens holes on top of the shoulders (the trapezius rises above it), which
        # the hood would sit on: with the hood up, cut only round the neck.
        cut(ob, [((0, 0, HEM_Z), (0, 0, -1)), ((0.705, 0, 0), (1, 0, 0)), ((-0.705, 0, 0), (-1, 0, 0)),
                 ((0, 0, 1.6), (0, 0, 1))], drop=lambda c: c.z > NECK_Z + 0.28 * c.y and neck_r(c) < 0.1)
    else:
        cut(ob, [((0, 0, HEM_Z), (0, 0, -1)), ((0.705, 0, 0), (1, 0, 0)), ((-0.705, 0, 0), (-1, 0, 0)),
                 ((0, 0, NECK_Z), (0, -0.28, 1))])

    def off(co, n):
        ax = abs(co.x)
        if ax > 0.2:                                   # sleeves: loose, gathered into the ribbed cuffs
            d = 0.025 + 0.007 * math.sin(min(1.0, (ax - 0.2) / 0.3) * math.pi)
            if ax > 0.645:
                d = 0.010 + 0.011 * max(0.0, (0.69 - ax) / 0.045)
            return d
        d = 0.022
        if co.z < 1.22:                                 # the body of the hoodie hangs loose over the belly
            d += 0.016 * min(1.0, (1.22 - co.z) / 0.25)
        if co.z < HEM_Z + 0.045:                        # ribbed hem pulls back in
            d -= 0.012 * min(1.0, (HEM_Z + 0.045 - co.z) / 0.04)
        return d
    inflate(ob, off, smooth_iters=3, wrinkle=0.0045)
    tidy_neckline(ob)
    assign_by_face(ob, {"hoodie": M["hoodie"], "rib": M["rib"]},
                   lambda c: "rib" if abs(c.x) > 0.648 or c.z < HEM_Z + 0.04 else "hoodie")
    return ob


def neck_loop(ob):
    """The hoodie's neck opening as an ordered list of vertex indices."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    edges = [e for e in bm.edges if e.is_boundary and all(v.co.z > 1.38 and abs(v.co.x) < 0.2 for v in e.verts)]
    nxt = {}
    for e in edges:
        a, b = e.verts[0].index, e.verts[1].index
        nxt.setdefault(a, []).append(b)
        nxt.setdefault(b, []).append(a)
    start = edges[0].verts[0].index
    loop, prev, cur = [start], None, start
    while True:
        options = [v for v in nxt[cur] if v != prev]
        if not options or options[0] == start:
            break
        prev, cur = cur, options[0]
        loop.append(cur)
    bm.free()
    return loop


def tidy_neckline(ob, iters=12):
    """Smooths the neck opening (the cut follows the body's triangles, so it is jagged) along its own loop."""
    loop = neck_loop(ob)
    print("NECK LOOP", len(loop))
    V = ob.data.vertices
    pts = [V[i].co.copy() for i in loop]
    n = len(pts)
    for _ in range(iters):
        pts = [pts[k].lerp((pts[k - 1] + pts[(k + 1) % n]) * 0.5, 0.6) for k in range(n)]
    for i, co in zip(loop, pts):
        V[i].co = co


def collar(shell, M):
    """A ribbed band rolled round the neck opening."""
    loop = neck_loop(shell)
    pts = [shell.data.vertices[i].co.copy() for i in loop]
    n = len(pts)
    centre = sum(pts, Vector()) / n
    verts, faces = [], []
    ring = 8
    for k in range(n):
        t = (pts[(k + 1) % n] - pts[k - 1]).normalized()
        out = (pts[k] - centre)
        out.z = 0.0
        out = (out - t * out.dot(t)).normalized()
        up = t.cross(out).normalized()
        for r in range(ring):
            a = r / ring * math.tau
            verts.append(pts[k] + out * 0.004 + (out * math.cos(a) + up * math.sin(a)) * 0.011)
    for k in range(n):
        for r in range(ring):
            a0 = k * ring + r
            a1 = k * ring + (r + 1) % ring
            b0 = ((k + 1) % n) * ring + r
            b1 = ((k + 1) % n) * ring + (r + 1) % ring
            faces.append((a0, a1, b1, b0))
    me = bpy.data.meshes.new("Collar")
    me.from_pydata([tuple(v) for v in verts], [], faces)
    ob = bpy.data.objects.new("Collar", me)
    bpy.context.scene.collection.objects.link(ob)
    set_material(ob, M["rib"])
    return ob


def pocket(hood_shell, M):
    """The kangaroo pocket: a second layer over the belly, cut from the hoodie's own front faces."""
    ob = duplicate(hood_shell, "Hoodie pocket")
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.normal_update()

    def inside(c, n):
        if n.y > -0.35 or not (HEM_Z + 0.05 <= c.z <= HEM_Z + 0.23):
            return False
        half = 0.145 - (c.z - HEM_Z - 0.05) * 0.30           # trapezoid: wider at the bottom
        return abs(c.x) <= half
    gone = [f for f in bm.faces if not inside(f.calc_center_median(), f.normal)]
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * 0.006
    bm.to_mesh(ob.data)
    bm.free()
    set_material(ob, M["hoodie"])
    mod = ob.modifiers.new("thick", "SOLIDIFY")
    mod.thickness = 0.004
    mod.offset = 1.0
    return ob


def hood(M, ref):
    """The hood, down: a soft fold lying on the upper back and around the collar."""
    me = bpy.data.meshes.new("Hood")
    verts, faces = [], []
    nu, nt = 34, 9
    for i in range(nu + 1):
        th = -1.15 + 2.3 * i / nu                    # around the neck; 0 = the back (+Y)
        w = math.cos(th / 1.15 * math.pi * 0.5) ** 1.2  # 1 at the back, small at the ends beside the neck
        collar = Vector((0.098 * math.sin(th), -0.025 + 0.092 * math.cos(th), 1.495 + 0.025 * math.cos(th)))
        out = Vector((math.sin(th), math.cos(th), 0.0))
        length = 0.07 + 0.2 * w
        for k in range(nt + 1):
            t = k / nt
            down = Vector((0, 0, -1)) * (0.15 + 0.85 * t)
            p = collar + (out * 0.55 + down).normalized() * length * t
            p += out * (0.03 * w) * math.sin(math.pi * min(1.0, t * 1.4))
            verts.append(p)
    for i in range(nu):
        for k in range(nt):
            a = i * (nt + 1) + k
            faces.append((a, a + 1, a + nt + 2, a + nt + 1))
    me.from_pydata([tuple(v) for v in verts], [], faces)
    ob = bpy.data.objects.new("Hood", me)
    bpy.context.scene.collection.objects.link(ob)
    sw = ob.modifiers.new("onto back", "SHRINKWRAP")
    sw.target = ref
    sw.wrap_method = "NEAREST_SURFACEPOINT"
    sw.wrap_mode = "OUTSIDE_SURFACE"
    sw.offset = 0.038
    sm = ob.modifiers.new("soft", "SMOOTH")
    sm.factor = 0.7
    sm.iterations = 8
    so = ob.modifiers.new("thick", "SOLIDIFY")
    so.thickness = 0.022
    so.offset = 1.0
    apply_modifiers(ob)
    set_material(ob, M["hoodie"])
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def drawstrings(M, ref):
    parts = []
    for side in (-1, 1):
        cu = bpy.data.curves.new("String", "CURVE")
        cu.dimensions = "3D"
        cu.bevel_depth = 0.0032
        cu.bevel_resolution = 2
        sp = cu.splines.new("POLY")
        pts = []
        for k in range(8):
            t = k / 7
            z = 1.47 - 0.17 * t
            x = side * (0.034 + 0.008 * t)
            pts.append(Vector((x, -0.2, z)))
        sp.points.add(len(pts) - 1)
        for p, co in zip(sp.points, pts):
            p.co = (*co, 1.0)
        ob = bpy.data.objects.new("String", cu)
        bpy.context.scene.collection.objects.link(ob)
        sw = ob.modifiers.new("onto chest", "SHRINKWRAP")
        sw.target = ref
        sw.wrap_method = "NEAREST_SURFACEPOINT"
        sw.wrap_mode = "OUTSIDE_SURFACE"
        sw.offset = 0.044
        bpy.context.view_layer.objects.active = ob
        for o in bpy.context.scene.objects:
            o.select_set(o == ob)
        bpy.ops.object.convert(target="MESH")
        ob = bpy.context.view_layer.objects.active
        set_material(ob, M["string"])
        parts.append(ob)
    return parts


# ---------------------------------------------------------------- 0.11: the hood up

def smooth01(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def piecewise(x, pts):
    if x <= pts[0][0]:
        return pts[0][1]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        if x <= x1:
            return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
    return pts[-1][1]


HOOD_C = Vector((0.0, -0.025, 1.655))          # the skull's centre: the hood is projected out from here
HOOD_NQ, HOOD_NT = 64, 26                      # around the face opening x from the opening to the neckline
# The face opening, from the middle of the brim over his left (+X) side to under the chin (mirrored for the right):
# the brim 8 cm past the forehead at eyebrow height, the sides forward to the cheekbones, closing under the chin.
HOOD_OPENING = [(0.0, -0.215, 1.722), (0.071, -0.193, 1.708), (0.095, -0.140, 1.636), (0.068, -0.118, 1.552),
                (0.0, -0.121, 1.486)]


def periodic_spline(pts, u):
    n = len(pts)
    x = (u % 1.0) * n
    i = int(math.floor(x))
    f = x - i
    p0, p1, p2, p3 = pts[(i - 1) % n], pts[i % n], pts[(i + 1) % n], pts[(i + 2) % n]
    return 0.5 * ((2.0 * p1) + (p2 - p0) * f + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f * f
                  + (3.0 * p1 - p0 - 3.0 * p2 + p3) * f * f * f)


def opening_point(u):
    half = [Vector(p) for p in HOOD_OPENING]
    loop = half + [Vector((-p.x, p.y, p.z)) for p in reversed(half[1:-1])]
    return periodic_spline(loop, u)


def hem_sampler(shell):
    """The hoodie's neckline as a function of the angle round the neck (0 at the back, pi/2 at his left): rays in
    out from the neck axis just under the neckline cut (z = NECK_Z + 0.28 y) find the hoodie's edge."""
    tree = BVHTree.FromObject(shell, bpy.context.evaluated_depsgraph_get())
    axis = Vector((0.0, -0.025, 0.0))

    def at(q):
        d = Vector((math.sin(q), math.cos(q), 0.0))
        y = 0.1 * d.y
        for _ in range(3):
            z = NECK_Z + 0.28 * y - 0.008
            hit = tree.ray_cast(axis + Vector((0, 0, z)), d, 0.3)[0]
            if hit is None:
                hit = axis + Vector((0, 0, z)) + d * 0.1
            y = hit.y
        return hit + Vector((0, 0, 0.008))
    return at


def region_tree(ref, keep):
    bm = bmesh.new()
    bm.from_mesh(ref.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not keep(v.co)], context="VERTS")
    tree = BVHTree.FromBMesh(bm)
    bm.free()
    return tree


def hood_offset(d):
    """How far the hood stands off the head along direction d: ~3.4 cm, more at the crown and the back."""
    return 0.034 + 0.012 * max(0.0, d.z) + 0.016 * max(0.0, d.y) + 0.045 * max(0.0, d.y) * max(0.0, -d.z)


def offset_radius(tree, d, off):
    r = 0.34
    while r > 0.03:
        loc, _n, _i, dist = tree.find_nearest(HOOD_C + d * r)
        if loc is not None and dist < off:
            return r
        r -= 0.0015
    return r


def push_out(tree, co, gap):
    loc, n, _i, dist = tree.find_nearest(co)
    if loc is None:
        return co
    d = co - loc
    if d.dot(n) < 0.0:                                   # inside the head: put it back outside
        return loc + n * gap
    if dist < gap:
        return loc + d.normalized() * gap
    return co


def hood_grid(ref, shell):
    """The hood-up surface: the body's head and neck (cut out of the reference body) inflated to an offset surface,
    sampled on a clean grid that runs from the face opening (row 0) to the hoodie's neckline (row NT-1), plus one
    row tucked inside the hoodie so no gap opens at the neck."""
    field = region_tree(ref, lambda c: c.z > 1.43 and abs(c.x) < 0.17)
    solid = region_tree(ref, lambda c: c.z > 1.36 and abs(c.x) < 0.3)
    hem = hem_sampler(shell)
    NQ, NT = HOOD_NQ, HOOD_NT
    grid = [[None] * (NT + 1) for _ in range(NQ)]
    for i in range(NQ):
        u = i / NQ
        q = u * math.tau
        O = opening_point(u)
        H = hem(q)
        radial = Vector((H.x, H.y + 0.025, 0.0)).normalized()
        H = H + radial * 0.004
        w = smooth01(-0.97, -0.5, math.cos(q))            # 0 under the chin: a short straight band there
        dm = Vector((math.sin(q), 0.45, math.cos(q))).normalized()
        K = ((O + H) * 0.5).lerp(HOOD_C + dm * 0.17, w)
        for k in range(NT):
            t = k / (NT - 1)
            P = O * (1 - t) ** 2 + K * (2 * t * (1 - t)) + H * t * t
            b = smooth01(0.0, 0.42, t) * (1.0 - smooth01(0.8, 1.0, t)) * w
            if b > 0.0:
                d = (P - HOOD_C).normalized()
                proj = HOOD_C + d * offset_radius(field, d, hood_offset(d))
                P = P.lerp(proj, b)
            grid[i][k] = P
        grid[i][NT] = H - radial * 0.008 - Vector((0, 0, 0.022))
        for k in range(2, NT - 2):                      # soft cloth: low-frequency rumple, more low on the back
            P = grid[i][k]
            amp = 0.0025 + 0.004 * smooth01(1.72, 1.56, P.z)
            grid[i][k] = P + (P - HOOD_C).normalized() * amp * (noise.noise(P * 9.0) + 0.5 * noise.noise(P * 19.0))
    for it in range(10):
        new = [[c.copy() for c in col] for col in grid]
        for i in range(NQ):
            for k in range(1, NT - 1):
                avg = (grid[i - 1][k] + grid[(i + 1) % NQ][k] + grid[i][k - 1] + grid[i][k + 1]) * 0.25
                new[i][k] = grid[i][k].lerp(avg, 0.5)
        grid = new
        if it % 3 == 2 or it == 9:
            for i in range(NQ):
                for k in range(1, NT - 2):
                    gap = 0.026 if grid[i][k].z > 1.56 else 0.03
                    grid[i][k] = push_out(solid, grid[i][k], gap)
    # Last, keep the skirt (down to the hem) just above the hoodie where it rounds over the shoulders: drop a ray
    # onto the hoodie's top surface under each point and lift the point if it is below it.
    cloth = BVHTree.FromObject(shell, bpy.context.evaluated_depsgraph_get())
    for i in range(NQ):
        for k in range(NT // 2, NT):
            P = grid[i][k]
            hit = cloth.ray_cast(Vector((P.x, P.y, 1.75)), Vector((0, 0, -1)), 0.4)
            if hit[0] is not None and hit[1].z > 0.3 and P.z < hit[0].z + 0.007:
                grid[i][k] = Vector((P.x, P.y, hit[0].z + 0.007))
    return grid


def tube(name, pts, radius, closed, mat, ring=8, centre=HOOD_C):
    """A round tube through pts (the channel, the hem, the seam); `centre` sets which way is 'out'."""
    n = len(pts)
    verts, faces = [], []
    for k in range(n):
        a = pts[k - 1] if (closed or k > 0) else pts[k]
        b = pts[(k + 1) % n] if (closed or k < n - 1) else pts[k]
        t = (b - a).normalized()
        out = pts[k] - centre
        out = (out - t * out.dot(t)).normalized()
        up = t.cross(out).normalized()
        for r in range(ring):
            a_ = r / ring * math.tau
            verts.append(pts[k] + (out * math.cos(a_) + up * math.sin(a_)) * radius)
    for k in range(n if closed else n - 1):
        for r in range(ring):
            a0, a1 = k * ring + r, k * ring + (r + 1) % ring
            b0, b1 = ((k + 1) % n) * ring + r, ((k + 1) % n) * ring + (r + 1) % ring
            faces.append((a0, a1, b1, b0))
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    set_material(ob, mat)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def hood_up(M, ref, shell):
    """The hood up: shell + lining (Solidify, the inner side gets the near-black lining), the drawstring channel
    round the opening, the hem at the neckline, the crown seam and the two strings hanging from the opening."""
    grid = hood_grid(ref, shell)
    NQ, NT = HOOD_NQ, HOOD_NT
    # The crown seam: the two side panels meet along the middle (column 0), a slight ridge.
    for k in range(1, NT - 1):
        grid[0][k] = grid[0][k] + (grid[0][k] - HOOD_C).normalized() * 0.0015
    verts = [grid[i][k] for i in range(NQ) for k in range(NT + 1)]

    def idx(i, k):
        return (i % NQ) * (NT + 1) + k
    faces = [(idx(i, k), idx(i + 1, k), idx(i + 1, k + 1), idx(i, k + 1)) for i in range(NQ) for k in range(NT)]
    me = bpy.data.meshes.new("Hood up")
    me.from_pydata([tuple(v) for v in verts], [], faces)
    ob = bpy.data.objects.new("Hood up", me)
    bpy.context.scene.collection.objects.link(ob)
    # Normals out (away from the skull), so Solidify grows the lining inwards.
    me.update()
    out = sum((p.normal.dot(p.center - HOOD_C) for p in me.polygons), 0.0)
    if out < 0.0:
        me.flip_normals()
    ob.data.materials.clear()
    ob.data.materials.append(M["hoodie"])
    ob.data.materials.append(M["hood_in"])
    so = ob.modifiers.new("lining", "SOLIDIFY")
    so.thickness = 0.009
    so.offset = -1.0
    so.material_offset = 1
    so.material_offset_rim = 1
    so.use_even_offset = False                          # even offset spikes on the short bands under the chin
    apply_modifiers(ob)
    for p in ob.data.polygons:
        p.use_smooth = True
    # Drawstring channel: a rolled hem just inside the opening edge.
    chan = []
    for i in range(NQ):
        a, b = grid[i][0], grid[i][1]
        chan.append(a + (b - a).normalized() * 0.005 - (a - HOOD_C).normalized() * 0.002)
    channel = tube("Hood channel", chan, 0.0095, True, M["rib"])
    hem_pts = [grid[i][NT - 1] + (grid[i][NT - 1] - Vector((0, -0.025, grid[i][NT - 1].z))).normalized() * 0.003
               for i in range(NQ)]
    hem_band = tube("Hood hem", hem_pts, 0.0065, True, M["rib"])
    seam = tube("Hood seam", [grid[0][k] for k in range(2, NT - 2)], 0.0024, False, M["hoodie"], ring=6)
    strings = hood_strings(M, shell, chan)
    return [ob, channel, hem_band, seam], strings


def hood_strings(M, shell, chan):
    """The two white drawstrings, out of the channel low on each side of the opening and down the chest."""
    tree = BVHTree.FromObject(shell, bpy.context.evaluated_depsgraph_get())
    parts = []
    for side in (1, -1):
        i = HOOD_NQ // 2 - side * 5
        e = chan[i] + Vector((0, -0.006, -0.004))
        pts = [e]
        for k in range(1, 9):
            z = e.z - 0.02 - k * 0.032
            x = e.x * (0.92 - 0.012 * k)
            hit = tree.ray_cast(Vector((x, -0.6, z)), Vector((0, 1, 0)))
            y = (hit[0].y if hit[0] is not None else -0.15) - 0.007
            pts.append(Vector((x, y, z)))
        # Ease the first drop off the channel.
        pts[1] = pts[1].lerp((pts[0] + pts[2]) * 0.5, 0.5)
        parts.append(tube("Hood string", pts, 0.0032, False, M["string"], ring=6,
                          centre=Vector((0, 0.1, e.z - 0.15))))
    return parts


def hood_weights(ob, arm):
    """Overrides the copied (skin_to) weights: the top and brim 100 % head; lower down, towards the back of the neck
    and the opening's lower edge, it blends into the copied weights (neck, chest and, at the wide neckline, the
    shoulders), so the hood turns with the head but its hem stays on the hoodie's neckline."""
    names = {g.index: g.name for g in ob.vertex_groups}
    plan = []
    for v in ob.data.vertices:
        c = v.co
        lo = 1.54 + 0.035 * smooth01(-0.02, 0.06, c.y)
        head = smooth01(lo, lo + 0.11, c.z)
        tw = {names[g.group]: g.weight for g in v.groups if g.weight > 1e-4}
        total = sum(tw.values())
        if total < 1e-4:
            chest = 1.0 - smooth01(1.465, 1.53, c.z)
            tw, total = {"neck": 1.0 - chest, "chest": chest}, 1.0
        w = {k: x / total * (1.0 - head) for k, x in tw.items()}
        w["head"] = w.get("head", 0.0) + head
        plan.append(w)
    for vg in list(ob.vertex_groups):
        ob.vertex_groups.remove(vg)
    groups = {}
    for i, w in enumerate(plan):
        for k, x in w.items():
            if x > 1e-4:
                if k not in groups:
                    groups[k] = ob.vertex_groups.new(name=k)
                groups[k].add([i], x, "REPLACE")
    if not any(m.type == "ARMATURE" for m in ob.modifiers):
        mod = ob.modifiers.new("Armature", "ARMATURE")
        mod.object = arm


def face_shade(co):
    """Skin multiplier for the hood's shadow: ~0.25 round the eyes and forehead, lighter towards mouth and jaw."""
    if co.z < 1.47 or abs(co.x) > 0.2:
        return 1.0
    return piecewise(co.z, [(1.47, 1.0), (1.52, 0.8), (1.56, 0.68), (1.60, 0.55), (1.635, 0.40), (1.66, 0.27),
                            (1.70, 0.24)])


def shade_face(body, mat):
    """Bakes the face shadow into a copy of the skin texture (no extra material, no vertex colours): every UV
    triangle of the head is filled with its vertices' face_shade, the result grown past the UV seams and blurred."""
    import numpy as np
    node = next(n for n in mat.node_tree.nodes if n.type == "TEX_IMAGE")
    src = node.image
    w, h = src.size
    px = np.empty(w * h * 4, np.float32)
    src.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    dark = np.zeros((h, w), np.float32)
    cov = np.zeros((h, w), bool)
    me = body.data
    me.calc_loop_triangles()
    uv = me.uv_layers.active.data
    fac = [face_shade(v.co) for v in me.vertices]
    for tri in me.loop_triangles:
        fs = [1.0 - fac[i] for i in tri.vertices]
        if max(fs) < 1e-3:
            continue
        P = np.array([[uv[l].uv[0] * w - 0.5, uv[l].uv[1] * h - 0.5] for l in tri.loops])
        x0, y0 = np.floor(P.min(0)).astype(int) - 1
        x1, y1 = np.ceil(P.max(0)).astype(int) + 1
        x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, w - 1), min(y1, h - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        (ax, ay), (bx, by), (cx, cy) = P
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-9:
            continue
        l0 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / den
        l1 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / den
        l2 = 1.0 - l0 - l1
        inside = (l0 >= -0.02) & (l1 >= -0.02) & (l2 >= -0.02)
        val = l0 * fs[0] + l1 * fs[1] + l2 * fs[2]
        sub = dark[y0:y1 + 1, x0:x1 + 1]
        sub[inside] = np.maximum(sub[inside], val[inside])
        cov[y0:y1 + 1, x0:x1 + 1] |= inside
    for _ in range(4):                                   # grow past the island borders (no bright seams)
        m = dark.copy()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            m = np.maximum(m, np.roll(np.roll(dark, dy, 0), dx, 1))
        dark = np.where(cov, dark, m)
        cov = cov | (m > 0)
    for _ in range(2):
        dark = (dark + np.roll(dark, 1, 0) + np.roll(dark, -1, 0) + np.roll(dark, 1, 1) + np.roll(dark, -1, 1)) / 5.0
    px[..., :3] *= (1.0 - np.clip(dark, 0.0, 0.8))[..., None]
    os.makedirs(WORK, exist_ok=True)
    path = os.path.join(WORK, "generic_body.jpg")
    tmp = bpy.data.images.new("shaded", w, h)
    tmp.pixels.foreach_set(px.ravel())
    tmp.filepath_raw = path
    tmp.file_format = "JPEG"
    tmp.save()
    bpy.data.images.remove(tmp)
    src.name = "generic_body_src"
    img = bpy.data.images.load(path)
    img.name = "generic_body.jpg"
    node.image = img
    print("FACE SHADE", path)


def jeans(body, M):
    ob = duplicate(body, "Jeans")
    cut(ob, [((0, 0, 1.0), (0, 0, 1)), ((0, 0, 0.108), (0, 0, -1))])

    def off(co, n):
        d = 0.015
        if 0.55 < co.z < 0.9:
            d += 0.006
        if co.z < 0.5:                                   # straight leg: loose round the shin, off the ankle
            d += 0.012 * min(1.0, (0.5 - co.z) / 0.3)
        return d
    inflate(ob, off, smooth_iters=2, wrinkle=0.003)
    set_material(ob, M["jeans"])
    return ob


def shoes(body, M):
    ob = duplicate(body, "Sneakers")
    cut(ob, [((0, 0, 0.128), (0, 0, 1))])

    def off(co, n):
        return 0.013
    inflate(ob, off, smooth_iters=3)
    assign_by_face(ob, {"shoe": M["shoe"], "sole": M["sole"]}, lambda c: "sole" if c.z < 0.022 else "shoe")
    return ob


def hair(M):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(HAIR_DIR, HAIR_STYLE + ".glb"))
    new = [o for o in bpy.data.objects if o not in before]
    ob = [o for o in new if o.type == "MESH"][0]
    for o in new:
        if o is not ob:
            bpy.data.objects.remove(o)
    ob.parent = None
    ob.data.transform(ob.matrix_world)
    ob.matrix_world = Matrix.Identity(4)
    ob.shape_key_clear()
    for attr in list(ob.data.color_attributes):
        ob.data.color_attributes.remove(attr)
    set_material(ob, M["hair"])
    vg = ob.vertex_groups.new(name="head")
    vg.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
    ob.name = "Hair"
    return ob


def hide_covered_skin(body):
    """Deletes the skin under the clothes (with a margin, so no gap shows at the hems and cuffs)."""
    bm = bmesh.new()
    bm.from_mesh(body.data)

    def covered(co):
        if co.z < 0.1:
            return True                                  # inside the shoes
        if 0.13 < co.z < 0.985 and abs(co.x) < 0.4:
            return True                                  # inside the jeans
        if HEM_Z + 0.03 < co.z < 1.53 and abs(co.x) < 0.675:
            return not (co.z > 1.42 and neck_r(co) < 0.105)
        return False
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if covered(v.co)], context="VERTS")
    bm.to_mesh(body.data)
    bm.free()


def apply_modifiers(ob):
    bpy.context.view_layer.objects.active = ob
    for o in bpy.context.scene.objects:
        o.select_set(o == ob)
    for mod in list(ob.modifiers):
        if mod.type != "ARMATURE":
            bpy.ops.object.modifier_apply(modifier=mod.name)


def skin_to(ob, ref, arm):
    """Copies skin weights from the reference body (nearest surface) and binds to the armature."""
    for vg in list(ob.vertex_groups):
        ob.vertex_groups.remove(vg)
    for vg in ref.vertex_groups:
        ob.vertex_groups.new(name=vg.name)
    dt = ob.modifiers.new("weights", "DATA_TRANSFER")
    dt.object = ref
    dt.use_vert_data = True
    dt.data_types_verts = {"VGROUP_WEIGHTS"}
    dt.vert_mapping = "POLYINTERP_NEAREST"
    dt.layers_vgroup_select_src = "ALL"
    dt.layers_vgroup_select_dst = "NAME"
    apply_modifiers(ob)


def dress(arm, body):
    M = materials()
    set_material(body, M["skin"])
    ref = duplicate(body, "Reference body")
    hood_shell = hoodie(body, M)
    parts = [hood_shell, pocket(hood_shell, M), jeans(body, M), shoes(body, M)]
    for p in parts:
        apply_modifiers(p)
    if HOOD == "up":
        hood_parts, strings = hood_up(M, ref, hood_shell)
        for p in hood_parts + strings:
            skin_to(p, ref, arm)
        for p in hood_parts:
            hood_weights(p, arm)
        parts += hood_parts + strings
        shade_face(body, M["skin"])
    else:
        hood_ob = hood(M, hood_shell)
        strings = drawstrings(M, hood_shell)
        band = collar(hood_shell, M)
        for p in [hood_ob, band] + strings:
            skin_to(p, ref, arm)
        parts += [hood_ob, band] + strings + [hair(M)]
    hide_covered_skin(body)
    bpy.data.objects.remove(ref)
    # One skinned mesh, one surface per material.
    for o in bpy.context.scene.objects:
        o.select_set(o == body or o in parts)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    body.name = "Stranger"
    body.data.name = "Stranger"
    for p in body.data.polygons:
        p.use_smooth = True
    if not any(m.type == "ARMATURE" for m in body.modifiers):
        mod = body.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
    body.parent = arm
    return body


# ---------------------------------------------------------------- custom clips

def rest_pose(arm, act_name="idle"):
    set_action(arm, bpy.data.actions[act_name], bpy.data.actions[act_name].frame_range[0])
    return {pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in arm.pose.bones}


def local_axis(arm, bone, axis):
    return (arm.data.bones[bone].matrix_local.to_3x3().inverted() @ Vector(axis)).normalized()


def key_pose(arm, frame, base, extra):
    """Keys every bone at `frame`: the base pose times extra[bone] = [(armature-space axis, degrees), ...]."""
    for pb in arm.pose.bones:
        loc, rot = base[pb.name]
        q = rot.copy()
        for axis, deg in extra.get(pb.name, []):
            q = q @ Quaternion(local_axis(arm, pb.name, axis), math.radians(deg))
        pb.rotation_mode = "QUATERNION"
        pb.location = loc
        pb.rotation_quaternion = q
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        pb.keyframe_insert("location", frame=frame)


def breath(t, period):
    """0..1 lungs; a quick inhale and a longer exhale, like someone who has been running."""
    p = (t / period) % 1.0
    return math.sin(p / 0.42 * math.pi * 0.5) ** 2 if p < 0.42 else math.cos((p - 0.42) / 0.58 * math.pi * 0.5) ** 2


def torso_extra(t, period, lean, look_up, tilt, heave):
    b = breath(t, period)
    X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
    sway = math.sin(t / 4.0 * math.tau) * 0.8
    return {
        "hips": [(Y, sway * 0.6)],
        "spine": [(X, lean * 0.5 - heave * 0.6 * b)],
        "chest": [(X, lean * 0.5 - heave * b), (Y, -sway * 0.5)],
        "shoulder.L": [(Y, -heave * 0.9 * b)],
        "shoulder.R": [(Y, heave * 0.9 * b)],
        "neck": [(X, -look_up * 0.4 + heave * 0.5 * b), (Y, tilt * 0.4)],
        "head": [(X, -look_up * 0.6 + heave * 0.4 * b), (Y, tilt * 0.6)],
    }


def make_loop(arm, name, length_s, period, lean, look_up, tilt, heave, grip=False):
    base = rest_pose(arm)
    act = bpy.data.actions.new(name + "_src")
    set_action(arm, None)
    arm.animation_data.action = act
    frames = int(round(length_s * FPS))
    for f in range(frames + 1):
        key_pose(arm, f, base, torso_extra(f / FPS, period, lean, look_up, tilt, heave))
    if grip:
        add_grip_ik(arm)
    return bake_action(arm, name, frames, act)


def bake_action(arm, name, frames, act):
    """Bakes the keyed pose + constraints (IK helpers) into a new action `name`; removes the source and helpers."""
    bpy.context.scene.frame_start = 0
    bpy.context.scene.frame_end = frames
    bpy.context.view_layer.objects.active = arm
    for o in bpy.context.scene.objects:
        o.select_set(o == arm)
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.select_all(action="SELECT")
    bpy.ops.nla.bake(frame_start=0, frame_end=frames, step=1, only_selected=False, visual_keying=True,
                     clear_constraints=True, use_current_action=False, bake_types={"POSE"})
    bpy.ops.object.mode_set(mode="OBJECT")
    baked = arm.animation_data.action
    baked.name = name
    baked.use_fake_user = True
    bpy.data.actions.remove(act)
    for ob in [o for o in bpy.data.objects if o.name.startswith("IK ")]:
        if ob.animation_data and ob.animation_data.action:
            bpy.data.actions.remove(ob.animation_data.action)
        bpy.data.objects.remove(ob)
    return baked


def add_grip_ik(arm):
    for side, grip in (("L", GRIP_L), ("R", GRIP_R)):
        sx = 1.0 if side == "L" else -1.0
        tgt = bpy.data.objects.new("IK target " + side, None)
        pole = bpy.data.objects.new("IK pole " + side, None)
        for e in (tgt, pole):
            bpy.context.scene.collection.objects.link(e)
        tgt.location = grip
        pole.location = Vector((sx * 0.62, 0.35, 0.85))   # elbows out, back and down
        c = arm.pose.bones["forearm." + side].constraints.new("IK")
        c.target = tgt
        c.pole_target = pole
        c.pole_angle = math.radians(POLE_ANGLE[side])
        c.chain_count = 2
        # Fists turned so the knuckles face the gate.
        h = arm.pose.bones["hand." + side].constraints.new("DAMPED_TRACK")
        aim = bpy.data.objects.new("IK aim " + side, None)
        bpy.context.scene.collection.objects.link(aim)
        aim.location = grip + Vector((sx * 0.025, -0.09, 0.03))
        h.target = aim
        h.track_axis = "TRACK_Y"


# Found by trying the four quarter turns per side (the mirrored arms have opposite rolls): these hang the
# elbows down and out (x +-0.45, z 1.33) like someone hanging on to the bars; others put them up or inward.
POLE_ANGLE = {"L": 180.0, "R": 0.0}


def elbow_report(arm, act, frame=10):
    set_action(arm, act, frame)
    dg = bpy.context.evaluated_depsgraph_get()
    ev = arm.evaluated_get(dg)
    out = {}
    for side in ("L", "R"):
        e = ev.pose.bones["forearm." + side].head
        w = ev.pose.bones["hand." + side].head
        out[side] = (tuple(round(v, 3) for v in e), tuple(round(v, 3) for v in w))
    return out


def evaluated_head(arm, bone):
    dg = bpy.context.evaluated_depsgraph_get()
    return arm.matrix_world @ arm.evaluated_get(dg).pose.bones[bone].head


def palm_up_matrix(loc):
    """hand.R turned palm up (the curled fingers on top), the hand pointing at the player, fingers raised a little."""
    y = Vector((0.05, -1.0, 0.12)).normalized()
    x = Vector((1.0, 0.0, 0.0))
    x = (x - y * x.dot(y)).normalized()
    z = x.cross(y)
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = loc
    return m


def hand_over_env(t):
    """0 at his side -> 1 at full reach (held from HAND_OVER_HOLD[0] to HAND_OVER_HOLD[1]) -> 0 back at his side."""
    a, b = HAND_OVER_HOLD
    if t < a:
        return smooth01(0.0, a, t)
    if t <= b:
        return 1.0
    return 1.0 - smooth01(b, b + 0.8, t)


def make_hand_over(arm):
    """hand_over (not a loop, 2.6 s): the right hand comes up from his side, palm up with the box on the fist, to
    HAND_OVER_WRIST; he leans in a little and his head drops to look at the player's hands; he holds it, and at
    HAND_OVER_RELEASE the box is taken; then the empty hand goes back to his side. The left arm stays relaxed."""
    base = rest_pose(arm)
    wrist0 = evaluated_head(arm, "hand.R")
    act = bpy.data.actions.new("hand_over_src")
    set_action(arm, None)
    arm.animation_data.action = act
    frames = int(round(HAND_OVER_LEN * FPS))
    envs = [hand_over_env(f / FPS) for f in range(frames + 1)]
    for f, e in enumerate(envs):
        t = f / FPS
        key_pose(arm, f, base, torso_extra(t, 2.4, lean=6.0 * e, look_up=-26.0 * e, tilt=4.0 * e, heave=1.2 * e))
    tgt = bpy.data.objects.new("IK target R", None)
    pole = bpy.data.objects.new("IK pole R", None)
    for o in (tgt, pole):
        bpy.context.scene.collection.objects.link(o)
    pole.location = Vector((-0.55, 0.15, 0.75))           # elbow down, a little out and back
    rot = palm_up_matrix(Vector())
    tgt.rotation_mode = "QUATERNION"
    tgt.rotation_quaternion = rot.to_quaternion()
    ik = arm.pose.bones["forearm.R"].constraints.new("IK")
    ik.target, ik.pole_target, ik.chain_count = tgt, pole, 2
    ik.pole_angle = math.radians(POLE_ANGLE["R"])
    cr = arm.pose.bones["hand.R"].constraints.new("COPY_ROTATION")
    cr.target = tgt
    for f, e in enumerate(envs):
        tgt.location = wrist0.lerp(HAND_OVER_WRIST, e) + Vector((0.0, -0.07, 0.02)) * math.sin(math.pi * e)
        tgt.keyframe_insert("location", frame=f)
        ik.influence = smooth01(0.0, 0.3, e)
        ik.keyframe_insert("influence", frame=f)
        cr.influence = smooth01(0.12, 0.85, e)
        cr.keyframe_insert("influence", frame=f)
    return bake_action(arm, "hand_over", frames, act)


def make_carry_box(arm):
    """carry_box: the library walk with the right forearm raised, palm up, the box held close to his chest."""
    walk = bpy.data.actions["walk"]
    src = walk.copy()
    src.name = "carry_box_src"
    set_action(arm, None)
    arm.animation_data.action = src
    if len(src.slots) and arm.animation_data.action_slot is None:
        arm.animation_data.action_slot = src.slots[0]
    frames = int(walk.frame_range[1])
    bpy.context.scene.frame_set(0)
    bpy.context.view_layer.update()
    tgt = bpy.data.objects.new("IK target R", None)
    pole = bpy.data.objects.new("IK pole R", None)
    for o in (tgt, pole):
        bpy.context.scene.collection.objects.link(o)
        o.parent = arm
        o.parent_type = "BONE"
        o.parent_bone = "chest"
    bpy.context.view_layer.update()
    tgt.matrix_world = palm_up_matrix(Vector((-0.13, -0.27, 1.07))) @ Matrix.Rotation(math.radians(-14), 4, "Z")
    pole.matrix_world = Matrix.Translation(Vector((-0.45, 0.35, 0.8)))
    ik = arm.pose.bones["forearm.R"].constraints.new("IK")
    ik.target, ik.pole_target, ik.chain_count = tgt, pole, 2
    ik.pole_angle = math.radians(POLE_ANGLE["R"])
    cr = arm.pose.bones["hand.R"].constraints.new("COPY_ROTATION")
    cr.target = tgt
    return bake_action(arm, "carry_box", frames, src)



# 0.23: crouch_walk, for squeezing through the broken hole in the town's sheet-iron wall (~1.2 m high).
CROUCH_DROP = 0.40      # the hips come down this far
CROUCH_STRIDE = 0.72    # footfalls closer together than the walk's
CROUCH_LEAN = {"hips": 12.0, "spine": 17.0, "chest": 15.0, "neck": -13.0, "head": -18.0}


def make_crouch_walk(arm):
    """crouch_walk: the library walk bent double. The hips drop CROUCH_DROP, the back leans forward and the head
    comes up to see ahead; the legs are IK'd to the walk's own footfalls (stride x CROUCH_STRIDE, feet keep their
    roll and lift), so the knees bend deep instead of the feet sinking."""
    walk = bpy.data.actions["walk"]
    frames = int(walk.frame_range[1])
    scene = bpy.context.scene
    set_action(arm, walk)
    feet = []
    for f in range(frames + 1):
        scene.frame_set(f)
        bpy.context.view_layer.update()
        feet.append({s: (arm.matrix_world @ arm.pose.bones["foot." + s].matrix).copy() for s in "LR"})
    src = walk.copy()
    src.name = "crouch_walk_src"
    set_action(arm, None)
    arm.animation_data.action = src
    if len(src.slots) and arm.animation_data.action_slot is None:
        arm.animation_data.action_slot = src.slots[0]
    hips = arm.pose.bones["hips"]
    for f in range(frames + 1):
        scene.frame_set(f)
        bpy.context.view_layer.update()
        m = hips.matrix.copy()
        m.translation.z -= CROUCH_DROP
        hips.matrix = m
        bpy.context.view_layer.update()
        for bone, deg in CROUCH_LEAN.items():
            pb = arm.pose.bones[bone]
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = pb.rotation_quaternion @ Quaternion(local_axis(arm, bone, (1, 0, 0)), math.radians(deg))
            pb.keyframe_insert("rotation_quaternion", frame=f)
        hips.keyframe_insert("location", frame=f)
    helpers = {}
    for side in "LR":
        sx = 1.0 if side == "L" else -1.0
        tgt = bpy.data.objects.new("IK target " + side, None)
        pole = bpy.data.objects.new("IK pole " + side, None)
        for o in (tgt, pole):
            scene.collection.objects.link(o)
        pole.location = Vector((sx * 0.16, -1.2, 0.6))   # knees forward (the figure faces -Y)
        for f in range(frames + 1):
            m = feet[f][side]
            loc = m.translation.copy()
            loc.y *= CROUCH_STRIDE
            tgt.matrix_world = Matrix.Translation(loc) @ m.to_quaternion().to_matrix().to_4x4()
            tgt.keyframe_insert("location", frame=f)
            tgt.keyframe_insert("rotation_euler", frame=f)
        ik = arm.pose.bones["shin." + side].constraints.new("IK")
        ik.target, ik.pole_target, ik.chain_count = tgt, pole, 2
        cr = arm.pose.bones["foot." + side].constraints.new("COPY_ROTATION")
        cr.target = tgt
        helpers[side] = ik
    # The rig's leg rolls are unknown here: take the pole angle that puts both knees furthest forward.
    best = None
    for angle in (0.0, 90.0, 180.0, -90.0):
        for side in "LR":
            helpers[side].pole_angle = math.radians(angle)
        knees = 0.0
        for f in (0, frames // 2):
            scene.frame_set(f)
            bpy.context.view_layer.update()
            knees += sum((arm.matrix_world @ arm.pose.bones["shin." + s].head).y for s in "LR")
        if best is None or knees < best[1]:
            best = (angle, knees)
    for side in "LR":
        helpers[side].pole_angle = math.radians(best[0])
    print("CROUCH_POLE", best)
    return bake_action(arm, "crouch_walk", frames, src)


def add_box_grip(arm):
    """The empty `box_grip`, bone-parented to hand.R (glTF: a child node of the hand.R joint)."""
    e = bpy.data.objects.new("box_grip", None)
    e.empty_display_size = 0.04
    bpy.context.scene.collection.objects.link(e)
    e.parent = arm
    e.parent_type = "BONE"
    e.parent_bone = "hand.R"
    set_action(arm, None)
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    e.matrix_world = (arm.matrix_world @ arm.data.bones["hand.R"].matrix_local @ Matrix.Translation(BOX_GRIP_LOC)
                      @ BOX_GRIP_ROT)
    bpy.context.view_layer.update()
    arm.data.pose_position = "POSE"
    bpy.context.view_layer.update()
    return e


def pickup_lowest(arm):
    """The frame of interact_pickup where hand.R (the wrist) is lowest: when the box leaves the ground."""
    act = bpy.data.actions["interact_pickup"]
    set_action(arm, act)
    best = None
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    for f in range(f0, f1 + 1):
        bpy.context.scene.frame_set(f)
        z = evaluated_head(arm, "hand.R").z
        if best is None or z < best[1]:
            best = (f, z)
    grip = bpy.data.objects.get("box_grip")
    bpy.context.scene.frame_set(best[0])
    gz = grip.matrix_world.translation.z if grip else None
    return {"frame": best[0], "time": (best[0] - f0) / FPS, "wrist_z": round(best[1], 3),
            "box_grip_z": round(gz, 3) if gz is not None else None}


# ---------------------------------------------------------------- preview and export

def setup_render(res=(720, 960)):
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            continue
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.film_transparent = False
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.33, 0.36, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    sc.world = world
    for name, rot, energy in (("key", (50, 0, 35), 3.2), ("fill", (60, 0, -60), 1.2), ("rim", (60, 0, 170), 2.5)):
        l = bpy.data.lights.new(name, "SUN")
        l.energy = energy
        o = bpy.data.objects.new(name, l)
        o.rotation_euler = [math.radians(a) for a in rot]
        sc.collection.objects.link(o)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    return cam


def shoot(cam, path, eye, look, lens=50):
    cam.data.lens = lens
    cam.location = eye
    d = (Vector(look) - Vector(eye)).normalized()
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("RENDER", path)


SHEET_VIEWS = [("front", (0.0, -1.0)), ("three_q", (-0.64, -0.77)), ("side", (1.0, 0.0)), ("back", (0.0, 1.0))]


def box_placeholder(grip):
    """A 120 x 75 x 40 mm box at box_grip (identity), for the hand_over preview."""
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    ob = bpy.context.active_object
    ob.name = "Box placeholder"
    ob.scale = (0.12, 0.075, 0.04)
    ob.parent = grip
    ob.matrix_parent_inverse = Matrix.Identity(4)
    ob.location = (0, 0, 0)
    ob.data.materials.append(principled("Box card", (0.42, 0.38, 0.22), 0.8))
    return ob


def lights_for_face(night):
    for o in bpy.context.scene.objects:
        if o.type == "LIGHT":
            o.hide_render = night != (o.name == "moon")
    world = bpy.context.scene.world.node_tree.nodes["Background"].inputs
    world[0].default_value = (0.05, 0.07, 0.12, 1) if night else (0.32, 0.33, 0.36, 1)
    world[1].default_value = 0.25 if night else 0.6


def preview(arm, facts):
    """The 0.11 hood sheet: five poses x four views plus a head close-up each, and the face in daylight and under a
    dim cool (moon) light; tiles in WORK, listed in WORK/sheet.txt for tools/blender/contact_sheet.py."""
    os.makedirs(WORK, exist_ok=True)
    cam = setup_render((360, 480))
    moon = bpy.data.lights.new("moon", "SUN")
    moon.energy = 0.9
    moon.color = (0.62, 0.72, 1.0)
    mo = bpy.data.objects.new("moon", moon)
    mo.rotation_euler = [math.radians(a) for a in (48, 0, -25)]
    bpy.context.scene.collection.objects.link(mo)
    mo.hide_render = True
    box = box_placeholder(bpy.data.objects["box_grip"])
    tiles = []
    poses = [("idle", "idle", 0), ("run", "run", 4), ("gate_grip", "gate_grip", 15),
             ("pickup", "interact_pickup", facts["pickup_lowest"]["frame"]),
             ("hand_over", "hand_over", int(round(HAND_OVER_RELEASE * FPS)))]
    for label, clip, frame in poses:
        act = bpy.data.actions[clip]
        set_action(arm, act, act.frame_range[0] + frame)
        box.hide_render = clip != "hand_over"
        look_z = 0.62 if clip == "interact_pickup" else 0.95
        for vname, (dx, dy) in SHEET_VIEWS:
            path = os.path.join(WORK, "%s_%s.png" % (label, vname))
            shoot(cam, path, (dx * 3.6, dy * 3.6 - 0.1, 1.25), (0, -0.1, look_z))
            tiles.append((path, "%s %s" % (label, vname)))
        head = evaluated_head(arm, "head")
        path = os.path.join(WORK, "%s_head.png" % label)
        shoot(cam, path, head + Vector((-0.55, -0.75, 0.12)), head + Vector((0, -0.04, 0.02)), lens=75)
        tiles.append((path, "%s head" % label))
    set_action(arm, bpy.data.actions["idle"], 0)
    box.hide_render = True
    for night in (False, True):
        lights_for_face(night)
        path = os.path.join(WORK, "face_%s.png" % ("moon" if night else "day"))
        shoot(cam, path, (0.28, -1.05, 1.68), (0, -0.05, 1.64), lens=85)
        tiles.append((path, "face, dim cool light" if night else "face, daylight"))
    lights_for_face(False)
    for vname, eye in (("back_close", (0.35, 0.95, 1.85)), ("top_close", (0.0, -0.55, 2.25))):
        path = os.path.join(WORK, "hood_%s.png" % vname)
        shoot(cam, path, eye, (0, 0, 1.58), lens=60)
        tiles.append((path, "hood " + vname.replace("_", " ")))
    with open(os.path.join(WORK, "sheet.txt"), "w") as f:
        for path, label in tiles:
            f.write(path + "\t" + label + "\n")


def crouch_sheet(arm):
    """0.23: crouch_walk side and three-quarter frames -> WORK/crouch_<view>_<frame>.png."""
    os.makedirs(WORK, exist_ok=True)
    cam = setup_render((360, 480))
    act = bpy.data.actions["crouch_walk"]
    for f in (0, 5, 10, 15):
        set_action(arm, act, f)
        for vname, (dx, dy) in (("side", (1.0, 0.0)), ("three_q", (-0.64, -0.77))):
            shoot(cam, os.path.join(WORK, "crouch_%s_%02d.png" % (vname, f)), (dx * 3.2, dy * 3.2 - 0.1, 0.9), (0, -0.1, 0.6))


def hair_sheet():
    os.makedirs(WORK, exist_ok=True)
    global HAIR_STYLE
    styles = sorted(f[:-4] for f in os.listdir(HAIR_DIR) if f.endswith(".glb"))
    for style in styles:
        reset()
        arm, body = load_body()
        M = materials()
        set_material(body, M["skin"])
        HAIR_STYLE = style
        h = hair(M)
        mod = h.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
        cam = setup_render((520, 520))
        shoot(cam, os.path.join(WORK, "hair_" + style + ".png"), (0.9, -1.25, 1.72), (0, 0, 1.68), lens=70)


def export():
    os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
    for o in bpy.context.scene.objects:
        o.select_set((o.type in ("ARMATURE", "MESH") and (o.type == "ARMATURE" or o.parent is not None))
                     or o.name == "box_grip")
    set_action(bpy.data.objects["Armature"], None)
    keep = set(KEEP_CLIPS) | {"gate_grip", "stand_stare", "hand_over", "carry_box", "crouch_walk"}
    for act in list(bpy.data.actions):
        if act.name not in keep:
            bpy.data.actions.remove(act)
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", use_selection=True, export_animations=True,
                              export_animation_mode="ACTIONS", export_skins=True, export_morph=False,
                              export_yup=True, export_apply=False, export_force_sampling=True,
                              export_optimize_animation_size=True, export_def_bones=False)
    print("EXPORTED", OUT_GLB, os.path.getsize(OUT_GLB))


def mesh_facts(ob):
    ob.data.calc_loop_triangles()
    return {"triangles": len(ob.data.loop_triangles), "materials": [m.name for m in ob.data.materials]}


def main():
    global HOOD
    a = args()
    if "hood_down" in a:
        HOOD = "down"
    if "hair" in a:
        hair_sheet()
        if len(a) == 1:
            return
    reset()
    arm, body = load_body()
    grip = make_loop(arm, "gate_grip", 4.0, 2.0, lean=9.0, look_up=14.0, tilt=9.0, heave=2.6, grip=True)
    make_loop(arm, "stand_stare", 4.0, 2.0, lean=3.0, look_up=2.0, tilt=11.0, heave=2.0)
    print("ELBOWS", elbow_report(arm, grip))
    hand_over = make_hand_over(arm)
    print("HAND_OVER ELBOW/WRIST", elbow_report(arm, hand_over, int(round(HAND_OVER_RELEASE * FPS))))
    carry = make_carry_box(arm)
    print("CARRY ELBOW/WRIST", elbow_report(arm, carry, 6))
    make_crouch_walk(arm)
    dress(arm, body)
    add_box_grip(arm)
    facts = {"hood": HOOD, "mesh": mesh_facts(body), "pickup_lowest": pickup_lowest(arm),
             "hand_over_release": HAND_OVER_RELEASE,
             "clips": {n: (bpy.data.actions[n].frame_range[1] - bpy.data.actions[n].frame_range[0]) / FPS
                       for n in ("run", "gate_grip", "stand_stare", "hand_over", "carry_box", "interact_pickup", "crouch_walk")}}
    set_action(arm, hand_over, int(round(HAND_OVER_RELEASE * FPS)))
    facts["box_grip_world_at_release"] = [round(v, 3) for v in bpy.data.objects["box_grip"].matrix_world.translation]
    print("FACTS", facts)
    os.makedirs(WORK, exist_ok=True)
    import json
    with open(os.path.join(WORK, "facts.json"), "w") as f:
        json.dump(facts, f, indent=1)
    if "preview" in a:
        preview(arm, facts)
    if "crouch" in a:
        crouch_sheet(arm)
    if "export" in a:
        export()


if __name__ == "__main__":
    main()
