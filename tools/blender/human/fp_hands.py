"""Interior 0.31: the player's hands (used by build_fp_arms.py).

The hands are real hand models, not built here: the Godot XR Tools hands by DigitalN8m4r3 (CC0, a MakeHuman hand,
left and right, rigged to the OpenXR hand skeleton, with nails and skin / normal / roughness textures), downloaded by
tools/assets/fetch_hands.py into .local/downloads/xr_hands. This module fits them onto the arm rig's wrists and
gives the arm rig their finger joints.

Each hand is brought into its hand bone's own frame:
    the wrist at the origin, +Y to the fingers, -Z the palm, +Z the back of the hand;
    the thumb on -X for the right hand and on +X for the left (the two are mirror images).
Finger bones are named `index.01.R` .. `pinky.03.L`, `thumb.01.R` .. (the model's Proximal / Intermediate / Distal
joints; the thumb's are its Metacarpal / Proximal / Distal). Every one has +Y down the finger and +Z out of its
back (the nail side), and its X is the joint's own hinge, taken from the way the model's finger is already bent, so:
    turning a bone about its X by a NEGATIVE angle curls it toward the palm (the same sign on both hands);
    turning it about its Z spreads it (the sign flips on the left hand).
scripts/arm_ik.gd poses the fingers with exactly that convention. The model's rest pose is a relaxed hand, fingers
a little bent: a curl of 0 is that, not a flat hand.
"""
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
SRC = os.path.join(ROOT, ".local", "downloads", "xr_hands")
MODEL = os.path.join(SRC, "model", "Hand_Nails_%s.gltf")
SKIN_TEX = os.path.join(ROOT, "game", "assets", "characters", "hands", "hand_skin.png")
NORMAL_TEX = os.path.join(ROOT, "game", "assets", "characters", "hands", "hand_normal.png")
# The model is a large hand (208 mm wrist to fingertip). The player's is 190 mm, a grown man's average, which is
# also what the weapons' grips were measured against.
HAND_LENGTH = 0.190
# How far the wrist is carried back into the sleeve, and how much narrower it is there.
WRIST_BACK = 0.085
DIGITS = {"index": "Index", "middle": "Middle", "ring": "Ring", "pinky": "Little", "thumb": "Thumb"}
# Which of the model's joints each of the rig's finger bones starts at (the last entry is where the finger ends).
CHAIN = ("Proximal", "Intermediate", "Distal", "Tip")
THUMB_CHAIN = ("Metacarpal", "Proximal", "Distal", "Tip")

_sources = {}


def bone_names():
    return [n + ".%02d" % k for n in ("index", "middle", "ring", "pinky", "thumb") for k in (1, 2, 3)]


def _joint_bone(name):
    """Which of the rig's bones a model joint's weights go to (without the side)."""
    part, joint = name.rsplit("_", 2)[0:2] if name.count("_") >= 2 else (name.split("_")[0], "")
    for ours, theirs in DIGITS.items():
        if part != theirs:
            continue
        chain = THUMB_CHAIN if ours == "thumb" else CHAIN
        if joint in chain:
            return "%s.%02d" % (ours, min(chain.index(joint), 2) + 1)
        return "hand"            # a finger's metacarpal: inside the palm
    return "hand"                # Wrist, Palm


def source(side):
    """The downloaded hand of one side, in its hand bone's frame and at the player's size:
    {"verts", "faces", "uvs" (per face corner), "weights" (per vertex: {rig bone: weight}), "joints" {model joint: point}}."""
    if side in _sources:
        return _sources[side]
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=MODEL % side)
    new = [o for o in bpy.data.objects if o not in before]
    arm = next(o for o in new if o.type == "ARMATURE")
    # (The importer also makes a small sphere to draw the bones with: the hand is the mesh that is skinned.)
    ob = max((o for o in new if o.type == "MESH"), key=lambda o: (len(o.vertex_groups), len(o.data.vertices)))
    bpy.context.view_layer.update()
    joints = {b.name[:-2]: arm.matrix_world @ b.head_local for b in arm.data.bones}
    tips = {b.name[:-2]: arm.matrix_world @ b.tail_local for b in arm.data.bones}
    wrist = joints["Wrist"]
    y = (joints["Middle_Proximal"] - wrist).normalized()
    # Across the knuckles, toward the little finger on the right hand and toward the thumb side on the left: either
    # way x cross y is the back of the hand.
    across = joints["Little_Proximal"] - joints["Index_Proximal"]
    if side == "L":
        across = -across
    x = (across - y * across.dot(y)).normalized()
    z = x.cross(y)
    rot = Matrix((x, y, z))                       # rows: model space -> hand frame
    length = max((joints[d + "_Tip"] - wrist).dot(y) for d in DIGITS.values())
    scale = HAND_LENGTH / length

    def to_hand(p):
        return (rot @ (p - wrist)) * scale

    me = ob.data
    world = ob.matrix_world
    verts = [to_hand(world @ v.co) for v in me.vertices]
    names = {g.index: g.name for g in ob.vertex_groups}
    weights = []
    for v in me.vertices:
        w = {}
        for g in v.groups:
            if g.weight <= 0.0:
                continue
            bone = _joint_bone(names[g.group])
            w[bone] = w.get(bone, 0.0) + g.weight
        total = sum(w.values()) or 1.0
        weights.append({b: value / total for b, value in w.items()})
    uv = me.uv_layers.active.data
    faces = [tuple(p.vertices) for p in me.polygons]
    uvs = [tuple(tuple(uv[i].uv) for i in p.loop_indices) for p in me.polygons]
    out = {"verts": verts, "faces": faces, "uvs": uvs, "weights": weights,
           "joints": {k: to_hand(p) for k, p in joints.items()}, "tips": {k: to_hand(p) for k, p in tips.items()},
           "scale": scale}
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)
    _sources[side] = out
    print("HAND %s scale %.3f  knuckles index %s little %s  thumb base %s" % (
        side, scale, tuple(round(c, 4) for c in out["joints"]["Index_Proximal"]),
        tuple(round(c, 4) for c in out["joints"]["Little_Proximal"]), tuple(round(c, 4) for c in out["joints"]["Thumb_Metacarpal"])))
    return out


def digits(side="R"):
    """name, the four points of each digit (three joints and the end) in the hand frame, and its hinge (the bones' X)."""
    src = source(side)
    back = Vector((0.0, 0.0, 1.0))
    out = []
    for ours, theirs in DIGITS.items():
        chain = THUMB_CHAIN if ours == "thumb" else CHAIN
        pts = [src["joints"]["%s_%s" % (theirs, j)] for j in chain]
        d0 = (pts[1] - pts[0]).normalized()
        d2 = (pts[3] - pts[1]).normalized()
        hinge = d0.cross(d2)
        # The hinge a finger with its back up would have: bone direction cross back of the hand.
        if ours == "thumb":
            # The thumb's nail faces away from the palm and out to the thumb's side.
            nail = Vector((-0.62 if side == "R" else 0.62, -0.30, 0.72))
            guess = d0.cross((nail - d0 * nail.dot(d0)).normalized())
        else:
            guess = d0.cross((back - d0 * back.dot(d0)).normalized())
        if hinge.length < math.sin(math.radians(5.0)):
            hinge = guess                      # too straight to tell: take the anatomical guess
        elif hinge.dot(guess) < 0.0:
            hinge = -hinge
        out.append((ours, pts, hinge.normalized()))
    return out


def add_bones(arm):
    """The finger bones, children of hand.R / hand.L. Call before any clip is keyed."""
    layout = {side: digits(side) for side in ("R", "L")}
    bpy.context.view_layer.objects.active = arm
    for o in bpy.context.scene.objects:
        o.select_set(o == arm)
    bpy.ops.object.mode_set(mode="EDIT")
    ebs = arm.data.edit_bones
    for side in ("R", "L"):
        hand = ebs["hand." + side]
        m = hand.matrix.copy()
        r = m.to_3x3()
        for name, pts, hinge in layout[side]:
            parent = hand
            for k in range(3):
                eb = ebs.new("%s.%02d.%s" % (name, k + 1, side))
                eb.head = m @ pts[k]
                eb.tail = m @ pts[k + 1]
                d = (pts[k + 1] - pts[k]).normalized()
                # +Z out of the finger's back: square to the bone and to its hinge (X = Y cross Z).
                eb.align_roll(r @ hinge.cross(d))
                eb.parent = parent
                eb.use_connect = False
                eb.use_deform = True
                parent = eb
    bpy.ops.object.mode_set(mode="OBJECT")


def material():
    skin = bpy.data.materials.new("FP hand skin")
    skin.use_nodes = True
    tree = skin.node_tree
    bsdf = tree.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.6
    if os.path.exists(SKIN_TEX):
        tex = tree.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(SKIN_TEX, check_existing=True)
        tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if os.path.exists(NORMAL_TEX):
        tex = tree.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(NORMAL_TEX, check_existing=True)
        tex.image.colorspace_settings.name = "Non-Color"
        bump = tree.nodes.new("ShaderNodeNormalMap")
        tree.links.new(tex.outputs["Color"], bump.inputs["Color"])
        tree.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return skin


def texture_colour(uvs):
    """The skin texture's mean colour at these UVs (linear, as a material's base colour is)."""
    if not uvs or not os.path.exists(SKIN_TEX):
        return (0.42, 0.24, 0.16)
    image = bpy.data.images.load(SKIN_TEX, check_existing=True)
    w, h = image.size
    px = image.pixels[:]
    total = [0.0, 0.0, 0.0]
    for uv in uvs:
        x = min(w - 1, max(0, int(uv.x % 1.0 * w)))
        y = min(h - 1, max(0, int(uv.y % 1.0 * h)))
        i = (y * w + x) * 4
        for c in range(3):
            total[c] += px[i + c]
    # (The pixels are as stored, sRGB: a base colour is linear.)
    return tuple(((t / len(uvs) + 0.055) / 1.055) ** 2.4 for t in total)


def build(arm, name="FP hands"):
    """Both hands as one mesh in the armature's space, skinned, with the material `FP hand skin` (the game gives it
    its textures: scripts/gun.gd `_skin_hands`)."""
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("UVMap")
    deform = bm.verts.layers.deform.new()
    me = bpy.data.meshes.new(name)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = arm
    groups = {}
    for side in ("R", "L"):
        for b in ["forearm", "hand"] + bone_names():
            groups[b + "." + side] = ob.vertex_groups.new(name=b + "." + side).index
    me.materials.append(material())
    wrist_skin = bpy.data.materials.new("FP wrist skin")
    wrist_skin.use_nodes = True
    wrist_skin.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.62
    me.materials.append(wrist_skin)
    rim_uvs = []
    for side in ("R", "L"):
        src = source(side)
        m = arm.data.bones["hand." + side].matrix_local
        made = []
        for p, w in zip(src["verts"], src["weights"]):
            v = bm.verts.new(m @ p)
            for b, weight in w.items():
                v[deform][groups[b + "." + side]] = weight
            made.append(v)
        faces = []
        for f, corner_uvs in zip(src["faces"], src["uvs"]):
            try:
                face = bm.faces.new([made[i] for i in f])
            except ValueError:
                continue
            face.smooth = True
            for loop, uv in zip(face.loops, corner_uvs):
                loop[uv_layer].uv = uv
            faces.append(face)
        # The model stops just behind the wrist. Carry its open end back up the forearm, into the sleeve.
        rim = [e for e in bm.edges if e.is_boundary and all(v in set(made) for v in e.verts)
               and all((m.inverted() @ v.co).y < 0.02 for v in e.verts)]
        if rim:
            rim_verts = {v for e in rim for v in e.verts}
            wrist = arm.data.bones["hand." + side].head_local
            fore = arm.data.bones["forearm." + side]
            # (An imported bone's tail is not at the next joint: the forearm's line is elbow to wrist.)
            axis = (wrist - fore.head_local).normalized()
            for v in rim_verts:
                # The rim itself bends half with the forearm.
                v[deform][groups["hand." + side]] = 0.5
                v[deform][groups["forearm." + side]] = 0.5
            grown = bmesh.ops.extrude_edge_only(bm, edges=rim)
            for v in [g for g in grown["geom"] if isinstance(g, bmesh.types.BMVert)]:
                # ...and its end lies up the forearm's own line, a little narrower, inside the cuff.
                rel = v.co - wrist
                radial = rel - axis * rel.dot(axis)
                v.co = wrist - axis * WRIST_BACK + radial * 0.8
                for g in list(v[deform].keys()):
                    del v[deform][g]
                v[deform][groups["forearm." + side]] = 1.0
            for f in [g for g in grown["geom"] if isinstance(g, bmesh.types.BMFace)]:
                f.smooth = True
                # The forearm is plain skin, the colour of the hand's own wrist (the second material).
                f.material_index = 1
                for loop in f.loops:
                    if loop.vert in rim_verts:
                        inner = next((l for l in loop.vert.link_loops if l.face not in grown["geom"]), None)
                        if inner is not None:
                            rim_uvs.append(inner[uv_layer].uv.copy())
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    wrist_skin.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*texture_colour(rim_uvs), 1.0)
    bm.to_mesh(me)
    bm.free()
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return ob


def curl(arm, side, pose):
    """Preview only: pose = {finger: (a, b, c)} degrees of curl at each joint, thumb (flex, spread, b, c)."""
    for name, v in pose.items():
        for k in range(3):
            pb = arm.pose.bones["%s.%02d.%s" % (name, k + 1, side)]
            pb.rotation_mode = "QUATERNION"
            q = Matrix.Rotation(-math.radians(v[k if name != "thumb" or k == 0 else k + 1]), 4, "X")
            if name == "thumb" and k == 0:
                q = Matrix.Rotation(math.radians(v[1]) * (1.0 if side == "R" else -1.0), 4, "Z") @ q
            pb.rotation_quaternion = q.to_quaternion()
