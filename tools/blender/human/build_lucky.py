"""Interior 0.68: Doctor Lucky, the Morboid: the boss of the hospital's secret laboratory (scripts/coop/lucky.gd).

  blender -b --factory-startup --python tools/blender/human/build_lucky.py -- [model] [clips] [brain] [preview] [export]

  model     the body: game/assets/characters/zombies/lucky.glb (mesh + rig, no clips)
  clips     his own clips on the 1x town rig (lucky_clips.py) -> lucky_anims.glb
  brain     the specimen brain floating in the laboratory's tanks -> game/assets/models/hospital/brain.glb
  preview   renders -> work/v68/lucky/*.png

He was one of the laboratory's doctors. Base: the game's downloaded base body (models/generic_body_rigged.glb, the
same one every townsperson is built on) dressed by the town wardrobe (a lab coat torn to the shoulders, the gown and
trousers under it rotted through), then grown wrong here:
  1. emaciated and tall: the arms lengthened from the shoulder (upper arm x1.15, forearm x1.4, hand x1.2: the bones
     too, along the T pose's arm line, so no bone turns and every town clip still fits), then the whole of him x1.12;
  2. the jaw unhinged: the lower face turned down about the jaw's hinge and stretched, hanging open to the
     sternum; a raw gullet behind it, rows of long needle teeth on the upper gum and the dropped jaw;
  3. the hands grown into claws: three long curved bone blades out of each hand's fingers;
  4. bone spurs out through the skin along the spine and the shoulder blades;
  5. the skin dead grey-violet, veined, the coat soaked (the town bake with its own horror profile).
"""
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector, noise

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import build_zombies as town

bh = town.bh
ROOT = bh.ROOT
OUT_DIR = os.path.join(ROOT, "game", "assets", "characters", "zombies")
MODEL_DIR = os.path.join(ROOT, "game", "assets", "models", "hospital")
WORK = os.path.join(ROOT, "work", "v68", "lucky")
SCALE = 1.12
K_UPPER = 1.15
K_FORE = 1.40
K_HAND = 1.20
JAW_OPEN = 62.0
JAW_STRETCH = 1.55

SPEC = dict(name="lucky", sex="m", seed=6801,
            shapes={"build": -0.75, "muscle": -0.35, "belly": -0.70, "cheeks": -1.0, "eyes_pop": 0.85,
                    "chin_long": 0.70, "nose_long": 0.30, "brow_heavy": 0.60},
            tone=(0.62, 0.60, 0.70), hair="patchy_rotted", hair_col=(0.05, 0.045, 0.04),
            horror=dict(decay="cyanotic", eye_style="milky", face_gore="ripped_cheek", veins=1.9, torso_gore=True),
            top=dict(kind="open_jacket", sleeve=0.22, hem=0.90, ragged=True, color=(0.80, 0.80, 0.76),
                     under_color=(0.34, 0.44, 0.46), blood=1.6),
            bottom=dict(kind="pants", color=(0.16, 0.18, 0.20), blood=1.1),
            gear=dict(coat_tail=dict(z0=0.36, open_front=True, color=(0.80, 0.80, 0.76), blood=1.5, ragged=True)))


def args():
    a = sys.argv
    return a[a.index("--") + 1:] if "--" in a else []


def coords(ob):
    v = np.empty(len(ob.data.vertices) * 3, np.float32)
    ob.data.vertices.foreach_get("co", v)
    return v.reshape(-1, 3)


def set_coords(ob, co):
    ob.data.vertices.foreach_set("co", co.astype(np.float32).ravel())
    ob.data.update()


def group_weights(ob, name):
    out = np.zeros(len(ob.data.vertices), np.float32)
    g = ob.vertex_groups.get(name)
    if g is None:
        return out
    gi = g.index
    for v in ob.data.vertices:
        for e in v.groups:
            if e.group == gi:
                out[v.index] = e.weight
    return out


def select_only(objs, active):
    for o in bpy.context.scene.objects:
        o.select_set(o in objs)
    bpy.context.view_layer.objects.active = active


def material(name, color, rough=0.5, metal=0.0, emit=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = (*color, 1.0)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if emit is not None:
        p.inputs["Emission Color"].default_value = (*emit, 1.0)
        p.inputs["Emission Strength"].default_value = 1.0
    return m


def bone_heads(arm, body):
    """Bone heads and tails in the body's own space (rest pose)."""
    to_body = body.matrix_world.inverted() @ arm.matrix_world
    out = {}
    for b in arm.data.bones:
        out[b.name] = (to_body @ b.head_local, to_body @ b.tail_local)
    return out


# ---------------------------------------------------------------- 1. the long arms

def arm_map(d, s, e, w, k_up, k_fore, k_hand):
    """Distance out along the arm line (from the body's middle) -> the lengthened arm's."""
    d = np.asarray(d, np.float32)
    e2 = s + (e - s) * k_up
    w2 = e2 + (w - e) * k_fore
    return np.where(d <= s, d, np.where(d <= e, s + (d - s) * k_up,
                    np.where(d <= w, e2 + (d - e) * k_fore, w2 + (d - w) * k_hand)))


def lengthen_arms(arm, body):
    heads = bone_heads(arm, body)
    co = coords(body)
    joints = {}
    for side, sign in (("L", 1.0), ("R", -1.0)):
        s = abs(heads["upper_arm." + side][0].x)
        e = abs(heads["forearm." + side][0].x)
        w = abs(heads["hand." + side][0].x)
        joints[side] = (s, e, w)
        mask = (co[:, 0] * sign) > s
        d = np.abs(co[mask, 0])
        co[mask, 0] = arm_map(d, s, e, w, K_UPPER, K_FORE, K_HAND) * sign
    set_coords(body, co)
    # The bones along with them (along X only: no bone turns).
    select_only([arm], arm)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    to_arm = arm.matrix_world.inverted() @ body.matrix_world
    to_body = body.matrix_world.inverted() @ arm.matrix_world
    for side, sign in (("L", 1.0), ("R", -1.0)):
        s, e, w = joints[side]
        for b in eb:
            if not b.name.endswith("." + side):
                continue
            if not any(b.name.startswith(k) for k in ("upper_arm", "forearm", "hand", "weapon", "f_", "thumb", "finger")):
                continue
            for attr in ("head", "tail"):
                p = to_body @ getattr(b, attr)
                if abs(p.x) > s - 1e-4:
                    p.x = float(arm_map([abs(p.x)], s, e, w, K_UPPER, K_FORE, K_HAND)[0]) * sign
                    setattr(b, attr, to_arm @ p)
    bpy.ops.object.mode_set(mode="OBJECT")
    return joints


# ---------------------------------------------------------------- 2. the jaw

def unhinge_jaw(arm, body, lm):
    co = coords(body)
    head_w = group_weights(body, "head")
    hc = Vector(lm["head_c"])
    nose = Vector(lm["nose"])
    mouth_z = float(nose.z) - 0.032
    hinge = Vector((0.0, hc.y + 0.035, mouth_z + 0.012))
    jaw = (head_w > 0.45) & (co[:, 2] < mouth_z) & (co[:, 1] < hc.y + 0.05)
    a = math.radians(JAW_OPEN)
    ca, sa = math.cos(a), math.sin(a)
    rel = co[jaw] - np.array(hinge, np.float32)
    # How far back on the jaw a vertex is (the hinge corner turns least: the cheeks tear there).
    front = np.clip((hinge.y - co[jaw, 1]) / 0.11, 0.0, 1.0)
    k = 0.35 + 0.65 * front
    y = rel[:, 1] * np.cos(a * k) - rel[:, 2] * np.sin(a * k)
    z = rel[:, 1] * np.sin(a * k) + rel[:, 2] * np.cos(a * k)
    z = np.where(z < 0, z * JAW_STRETCH, z)
    rel[:, 0] *= 1.0 + 0.18 * front
    rel[:, 1] = y
    rel[:, 2] = z
    co[jaw] = rel + np.array(hinge, np.float32)
    set_coords(body, co)
    lip = co[jaw]
    tip = lip[np.argmin(lip[:, 2])] if len(lip) else np.array((0.0, hc.y - 0.06, mouth_z - 0.2), np.float32)
    print("JAW", int(jaw.sum()), "verts, chin now at", [round(float(x), 3) for x in tip])
    return hinge, Vector(tip.tolist()), mouth_z


def gullet_and_teeth(arm, hinge, chin, mouth_z, lm, mats):
    """The raw throat behind the open jaw and the needle teeth, all on the head bone."""
    hc = Vector(lm["head_c"])
    front_y = float(lm["head_ymin"])
    parts = []
    # The gullet: a tapered tube from the open mouth back and down into the neck.
    bm = bmesh.new()
    rings = []
    for i in range(7):
        t = i / 6.0
        c = Vector((0.0, front_y + 0.03 + t * 0.09, mouth_z - 0.02 - t * 0.10 + (chin.z - mouth_z) * 0.35 * (1 - t)))
        r = 0.045 * (1.0 - t * 0.45)
        ring = []
        for j in range(12):
            ang = j / 12.0 * math.tau
            ring.append(bm.verts.new(c + Vector((math.cos(ang) * r * 1.2, 0.0, math.sin(ang) * r * 1.6))))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for j in range(12):
            bm.faces.new((rings[i][j], rings[i][(j + 1) % 12], rings[i + 1][(j + 1) % 12], rings[i + 1][j]))
    me = bpy.data.meshes.new("Gullet")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("Gullet", me)
    bpy.context.collection.objects.link(ob)
    me.materials.append(mats["gum"])
    parts.append(ob)
    # The teeth: long thin cones along the upper gum's arc and the dropped jaw's edge.
    bm = bmesh.new()

    def tooth(base, direction, length, radius):
        direction = direction.normalized()
        side = direction.cross(Vector((1, 0, 0)))
        if side.length < 1e-4:
            side = direction.cross(Vector((0, 1, 0)))
        side.normalize()
        up = direction.cross(side).normalized()
        ring = [bm.verts.new(base + (side * math.cos(a) + up * math.sin(a)) * radius) for a in
                [k / 5.0 * math.tau for k in range(5)]]
        apex = bm.verts.new(base + direction * length)
        for k in range(5):
            bm.faces.new((ring[k], ring[(k + 1) % 5], apex))

    rng = np.random.default_rng(68)
    upper_y = front_y + 0.012
    for i in range(13):
        t = i / 12.0
        ang = (t - 0.5) * 2.4
        x = math.sin(ang) * 0.040
        y = upper_y + (1.0 - math.cos(ang)) * 0.03
        base = Vector((x, y, mouth_z + 0.004))
        tooth(base, Vector((x * 0.5, 0.15, -1.0)), 0.028 + 0.03 * float(rng.random()) + (0.03 if i in (3, 9) else 0.0), 0.0045)
    # The jaw's teeth stand up from its broken edge (between the hinge corner and the chin).
    for i in range(15):
        t = i / 14.0
        ang = (t - 0.5) * 2.4
        x = math.sin(ang) * 0.05
        front = 1.0 - abs(t - 0.5) * 2.0
        y = chin.y + 0.02 + (1.0 - front) * 0.05
        z = chin.z + 0.03 + (1.0 - front) * (mouth_z - chin.z) * 0.45
        tooth(Vector((x, y, z)), Vector((x * 0.4, 0.35, 1.0)), 0.03 + 0.035 * float(rng.random()), 0.005)
    me = bpy.data.meshes.new("Teeth")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("Teeth", me)
    bpy.context.collection.objects.link(ob)
    me.materials.append(mats["tooth"])
    parts.append(ob)
    for p in parts:
        town.bind_single_bone(p, "head")
    return parts


# ---------------------------------------------------------------- 3. the claws

def claws(arm, body, mats):
    co = coords(body)
    parts = []
    bm = bmesh.new()
    for side, sign in (("L", 1.0), ("R", -1.0)):
        sel = co[(co[:, 0] * sign) > 0.0]
        tip_x = float(np.abs(sel[:, 0]).max())
        hand = sel[np.abs(sel[:, 0]) > tip_x - 0.09]
        cy = float(hand[:, 1].mean())
        cz = float(hand[:, 2].mean())
        for k, (dy, dz, length) in enumerate(((-0.032, 0.006, 0.50), (0.0, 0.012, 0.56), (0.032, 0.004, 0.47))):
            root = Vector((sign * (tip_x - 0.05), cy + dy, cz + dz))
            segs = 9
            prev = None
            for i in range(segs + 1):
                t = i / segs
                # Out along the arm, curving down and in toward the palm's side like a hook.
                p = root + Vector((sign * length * t, -0.06 * math.sin(t * math.pi * 0.5) + dy * 0.6 * t,
                                   -0.16 * t * t))
                w = 0.022 * (1.0 - t) ** 0.8 + 0.0015
                h = 0.010 * (1.0 - t) + 0.001
                ring = [bm.verts.new(p + Vector((0.0, w * math.cos(a), h * math.sin(a)))) for a in
                        [j / 6.0 * math.tau for j in range(6)]]
                if prev is not None:
                    for j in range(6):
                        bm.faces.new((prev[j], prev[(j + 1) % 6], ring[(j + 1) % 6], ring[j]))
                prev = ring
            tipv = bm.verts.new(root + Vector((sign * length * 1.04, -0.06 + dy * 0.6, -0.17)))
            for j in range(6):
                bm.faces.new((prev[j], prev[(j + 1) % 6], tipv))
    me = bpy.data.meshes.new("Claws")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("Claws", me)
    bpy.context.collection.objects.link(ob)
    me.materials.append(mats["claw"])
    # Each half on its own hand.
    for vg in list(ob.vertex_groups):
        ob.vertex_groups.remove(vg)
    gl = ob.vertex_groups.new(name="hand.L")
    gr = ob.vertex_groups.new(name="hand.R")
    left = [v.index for v in ob.data.vertices if v.co.x > 0]
    right = [v.index for v in ob.data.vertices if v.co.x <= 0]
    gl.add(left, 1.0, "REPLACE")
    gr.add(right, 1.0, "REPLACE")
    parts.append(ob)
    return parts


# ---------------------------------------------------------------- 4. the spurs

def spurs(arm, body, mats):
    co = coords(body)
    bm = bmesh.new()
    rng = np.random.default_rng(681)
    marks = []
    for i in range(9):
        z = 1.02 + i * 0.055
        band = co[(np.abs(co[:, 2] - z) < 0.02) & (np.abs(co[:, 0]) < 0.03)]
        if not len(band):
            continue
        y = float(band[:, 1].max())
        marks.append((Vector((0.0, y - 0.01, z)), Vector((0.0, 1.0, 0.55 + 0.1 * i)), 0.05 + 0.05 * float(rng.random()), z))
    for side in (1.0, -1.0):
        for j in range(3):
            z = 1.28 + j * 0.05
            band = co[(np.abs(co[:, 2] - z) < 0.02) & (np.abs(co[:, 0] - side * 0.09) < 0.03)]
            if not len(band):
                continue
            y = float(band[:, 1].max())
            marks.append((Vector((side * 0.09, y - 0.01, z)), Vector((side * 0.4, 1.0, 0.8)), 0.06 + 0.04 * float(rng.random()), z))
    for base, d, length, _z in marks:
        d = d.normalized()
        side = d.cross(Vector((0, 0, 1)))
        if side.length < 1e-4:
            side = Vector((1, 0, 0))
        side.normalize()
        up = d.cross(side).normalized()
        ring = [bm.verts.new(base + (side * math.cos(a) + up * math.sin(a)) * 0.012) for a in
                [k / 6.0 * math.tau for k in range(6)]]
        apex = bm.verts.new(base + d * length)
        for k in range(6):
            bm.faces.new((ring[k], ring[(k + 1) % 6], apex))
    me = bpy.data.meshes.new("Spurs")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("Spurs", me)
    bpy.context.collection.objects.link(ob)
    me.materials.append(mats["claw"])
    town.bind_z_blend(ob, [(1.0, {"spine": 1.0}), (1.22, {"spine": 0.5, "chest": 0.5}), (1.35, {"chest": 1.0})])
    return [ob]


# ---------------------------------------------------------------- the model

def build_model(a):
    bh.reset()
    os.makedirs(WORK, exist_ok=True)
    arm, body = town.load(["idle", "walk_hurt"])
    spec = dict(SPEC)
    town.shape_body(body, spec)
    lm = spec["lm"]
    body = town.dress(arm, body, spec)
    town.bake(body, spec)
    mats = {"gum": material("Lucky gullet", (0.20, 0.025, 0.03), 0.35),
            "tooth": material("Lucky teeth", (0.62, 0.55, 0.40), 0.45),
            "claw": material("Lucky bone", (0.56, 0.50, 0.40), 0.4)}
    lengthen_arms(arm, body)
    hinge, chin, mouth_z = unhinge_jaw(arm, body, lm)
    extra = gullet_and_teeth(arm, hinge, chin, mouth_z, lm, mats) + claws(arm, body, mats) + spurs(arm, body, mats)
    for ob in extra:
        ob.matrix_world = body.matrix_world.copy()
        ob.parent = arm
        ob.matrix_parent_inverse = arm.matrix_world.inverted()
        mod = ob.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
    # Everything to his size.
    for ob in [body] + extra:
        ob.data.transform(Matrix.Scale(SCALE, 4))
    arm.data.transform(Matrix.Scale(SCALE, 4))
    town.validate_mesh(arm, body, "lucky")
    body.data.calc_loop_triangles()
    tris = len(body.data.loop_triangles)
    for ob in extra:
        ob.data.calc_loop_triangles()
        tris += len(ob.data.loop_triangles)
    facts = {"triangles": tris, "height": float(coords(body)[:, 2].max()), "scale": SCALE}
    print("LUCKY", facts)
    with open(os.path.join(WORK, "model.json"), "w") as f:
        json.dump(facts, f, indent=1)
    if "export" in a:
        town.export(arm, os.path.join(OUT_DIR, "lucky.glb"), False)
    if "preview" in a:
        cam = bh.setup_render((560, 760))
        if bpy.data.actions.get("idle") is not None:
            bh.set_action(arm, bpy.data.actions["idle"], 1)
        S = SCALE
        bh.shoot(cam, os.path.join(WORK, "model_front.png"), (0.0, -4.0 * S, 1.1 * S), (0.0, 0.0, 1.0 * S), lens=50)
        bh.shoot(cam, os.path.join(WORK, "model_q.png"), (-2.4 * S, -2.8 * S, 1.4 * S), (0.0, 0.0, 1.0 * S), lens=50)
        bh.shoot(cam, os.path.join(WORK, "model_face.png"), (-.35 * S, -1.05 * S, 1.62 * S), (0.0, 0.0, 1.5 * S), lens=60)
        bh.shoot(cam, os.path.join(WORK, "model_back.png"), (1.4 * S, 3.4 * S, 1.3 * S), (0.0, 0.0, 1.0 * S), lens=50)


# ---------------------------------------------------------------- the clips

def build_clips(a):
    import build_heavyarm as ha
    import lucky_clips
    bh.reset()
    arm, body = ha.load_rig(lucky_clips.BASES)
    made = lucky_clips.make_all(arm)
    facts = {act.name: round((act.frame_range[1] - act.frame_range[0]) / bh.FPS, 3) for act in made}
    print("CLIPS", facts)
    os.makedirs(WORK, exist_ok=True)
    with open(os.path.join(WORK, "clips.json"), "w") as f:
        json.dump(facts, f, indent=1)
    if "preview" in a:
        import heavyarm_clips
        heavyarm_clips.preview(arm, made, WORK)
    if "export" in a:
        keep = {act.name for act in made}
        for act in list(bpy.data.actions):
            if act.name not in keep:
                bpy.data.actions.remove(act)
        ha.export(arm, os.path.join(OUT_DIR, "lucky_anims.glb"), True)


# ---------------------------------------------------------------- the specimen brain

def build_brain(a):
    bh.reset()
    os.makedirs(MODEL_DIR, exist_ok=True)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=32, radius=1.0)
    ob = bpy.context.active_object
    ob.name = "Brain"
    me = ob.data
    for v in me.vertices:
        p = v.co.copy()
        # Two hemispheres: a deep groove down the middle on top, the frontal lobes forward, the cerebellum tucked under.
        n = noise.noise(p * 3.2)
        folds = 0.06 * math.sin(14.0 * p.x + 6.0 * noise.noise(p * 2.0)) * math.cos(12.0 * p.y + 5.0 * n) \
            + 0.04 * noise.noise(p * 7.0)
        r = 1.0 + folds
        groove = math.exp(-(p.x * p.x) / 0.004) * max(0.0, p.z + 0.2) * 0.35
        r -= groove
        p = p * r
        p.x *= 0.72
        p.y *= 0.95
        p.z *= 0.62
        if p.z < -0.25 and p.y > 0.2:
            p.z -= 0.12
        v.co = p * 0.085
    me.update()
    for poly in me.polygons:
        poly.use_smooth = True
    me.materials.append(material("Specimen", (0.72, 0.52, 0.50), 0.32))
    select_only([ob], ob)
    bpy.ops.export_scene.gltf(filepath=os.path.join(MODEL_DIR, "brain.glb"), export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True)
    print("BRAIN exported")


def main():
    a = args()
    if "model" in a:
        build_model(a)
    if "clips" in a:
        build_clips(a)
    if "brain" in a:
        build_brain(a)


if __name__ == "__main__":
    main()
