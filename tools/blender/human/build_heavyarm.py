"""Interior 0.53: Heavy-arm, the mutant waiting at PILCST's rear gate (co-op stage 15; scripts/coop/heavyarm.gd).

  blender -b --factory-startup --python tools/blender/human/build_heavyarm.py -- [model] [clips] [preview] [export]

  model     build the mesh (bakes take a few minutes on the CPU)
  clips     the new clips on the 1x town rig (tools/blender/human/heavyarm_clips.py)
  preview   renders -> work/v53/heavyarm/*.png
  export    game/assets/characters/zombies/heavyarm.glb (mesh + rig, no clips) and heavyarm_anims.glb (rig + clips)

Base: "Boss Zombie Sculpted" by shaz13 (Sketchfab fa85d0ef26bd4dba9445ff5dd3baa1bd, CC BY 4.0), from the Objaverse
mirror (tools/assets/fetch_heavyarm.py -> .local/downloads/heavyarm/raw/boss_zombie.glb): a 1.56 M vertex sculpt of a
heavily muscled bald infected man in a relaxed A pose, untextured. Here:
  1. joined, decimated to ~LOW_VERTS vertices and unwrapped; the sculpt's detail is baked onto it as a normal map
     and its cavities as occlusion, both in the sculpt's own pose (a tangent-space map survives everything after);
  2. skinned to the game's 24-bone town skeleton (models/generic_body_rigged.glb) by copying the weights of the
     base body posed the same way, then turned into the skeleton's T pose;
  3. mutated: the right arm swollen into the heavy arm (from the shoulder down, a fist twice a man's), the left gone
     wrong another way (tumours, swelling), a hump of muscle over the right shoulder;
  4. scaled by SCALE, painted (a baked procedural skin: dead grey, bruising, veins; the heavy arm raw and striated;
     the left necrotic; torn dark shorts; blood), bone breaking through the heavy forearm, its knuckles and the left
     forearm (a plain bone material).
The game hangs a guard's lanyard and the rear gate's key on him (he kept that gate).
"""
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector, noise
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import build_human as bh
import crawl_clips as cc

ROOT = bh.ROOT
SCULPT = os.path.join(ROOT, ".local", "downloads", "heavyarm", "raw", "boss_zombie.glb")
OUT_DIR = os.path.join(ROOT, "game", "assets", "characters", "zombies")
WORK = os.path.join(ROOT, "work", "v53", "heavyarm")
SCALE = 1.25
TEX = 2048
AO_TEX = 1024
LOW_VERTS = 26000
ARM_DOWN = 63.0     # the sculpt's arms hang this far below the T pose's
LEG_OUT = 9.0       # and its legs stand this far apart
Y = Vector((0.0, 1.0, 0.0))
UPPER_LONG = 1.12   # the heavy arm's upper arm this much longer than a man's
FORE_LONG = 1.34    # and its forearm (the bones too: the clips turn bones, they never set their lengths)


def args():
    a = sys.argv
    return a[a.index("--") + 1:] if "--" in a else []


def select_only(objs, active):
    for o in bpy.context.scene.objects:
        o.select_set(o in objs)
    bpy.context.view_layer.objects.active = active


def apply_mod(ob, name):
    select_only([ob], ob)
    bpy.ops.object.modifier_apply(modifier=name)


def load_rig(keep=()):
    bpy.ops.import_scene.gltf(filepath=bh.SRC)
    arm = body = None
    for ob in list(bpy.data.objects):
        if ob.type == "ARMATURE":
            arm = ob
        elif ob.type == "MESH" and ob.parent is not None:
            body = ob
        else:
            bpy.data.objects.remove(ob)
    ad = arm.animation_data or arm.animation_data_create()
    for track in list(ad.nla_tracks):
        ad.nla_tracks.remove(track)
    for act in list(bpy.data.actions):
        if act.name in keep:
            act.use_fake_user = True
        else:
            bpy.data.actions.remove(act)
    ad.action = None
    body.shape_key_clear()
    me = body.data
    while len(me.uv_layers) > 1:
        me.uv_layers.remove(me.uv_layers[-1])
    for attr in list(me.color_attributes):
        me.color_attributes.remove(attr)
    print("RIG matrix", [list(r) for r in arm.matrix_world])
    return arm, body


def coords(ob):
    v = np.empty(len(ob.data.vertices) * 3, np.float32)
    ob.data.vertices.foreach_get("co", v)
    return v.reshape(-1, 3)


def set_coords(ob, co):
    ob.data.vertices.foreach_set("co", co.astype(np.float32).ravel())
    ob.data.update()


# ---------------------------------------------------------------- 1. the sculpt, high and low

def load_sculpt(top):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=SCULPT)
    new = [o for o in bpy.data.objects if o not in before]
    parts = [o for o in new if o.type == "MESH"]
    others = [o.name for o in new if o.type != "MESH"]
    select_only(parts, parts[0])
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.join()
    high = bpy.context.view_layer.objects.active
    for name in others:
        if name in bpy.data.objects:
            bpy.data.objects.remove(bpy.data.objects[name])
    select_only([high], high)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    high.name = "Sculpt high"
    co = coords(high)
    lo, hi = co.min(0), co.max(0)
    s = top / float(hi[2] - lo[2])
    m = Matrix.Scale(s, 4) @ Matrix.Translation((-(lo[0] + hi[0]) * .5, -(lo[1] + hi[1]) * .5, -lo[2]))
    high.data.transform(m)
    # (It already faces -Y, as the game's people do.)
    high.data.update()
    high.data.materials.clear()
    print("SCULPT verts", len(high.data.vertices), "scale", s)
    return high


def make_low(high):
    low = high.copy()
    low.data = high.data.copy()
    low.name = "Heavy-arm"
    bpy.context.scene.collection.objects.link(low)
    bm = bmesh.new()
    bm.from_mesh(low.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=.0004)
    bm.to_mesh(low.data)
    bm.free()
    ratio = LOW_VERTS / max(len(low.data.vertices), 1)
    dec = low.modifiers.new("dec", "DECIMATE")
    dec.ratio = ratio
    dec.use_collapse_triangulate = True
    apply_mod(low, "dec")
    # Bits of the sculpt that came loose (a few verts): gone.
    bm = bmesh.new()
    bm.from_mesh(low.data)
    islands = []
    seen = set()
    for v in bm.verts:
        if v.index in seen:
            continue
        stack = [v]
        part = []
        seen.add(v.index)
        while stack:
            x = stack.pop()
            part.append(x)
            for e in x.link_edges:
                o = e.other_vert(x)
                if o.index not in seen:
                    seen.add(o.index)
                    stack.append(o)
        islands.append(part)
    islands.sort(key=len, reverse=True)
    junk = [v for part in islands[1:] if len(part) < 200 for v in part]
    bmesh.ops.delete(bm, geom=junk, context="VERTS")
    bm.normal_update()
    bm.to_mesh(low.data)
    bm.free()
    for p in low.data.polygons:
        p.use_smooth = True
    low.data.update()
    print("LOW verts", len(low.data.vertices), "islands", len(islands), "dropped", len(junk))
    return low


def unwrap(low):
    select_only([low], low)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(78.0), island_margin=.003, area_weight=0.0)
    bpy.ops.object.mode_set(mode="OBJECT")
    low.data.uv_layers[0].name = "UVMap"


def image(name, size, color, non_color=False):
    img = bpy.data.images.new(name, size, size, alpha=False, float_buffer=False)
    img.generated_color = color
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    return img


def bake_target(ob, img):
    """A material on `ob` whose active node is an image node on `img` (what Cycles bakes into)."""
    mat = bpy.data.materials.new("bake " + img.name)
    mat.use_nodes = True
    nt = mat.node_tree
    node = nt.nodes.new("ShaderNodeTexImage")
    node.image = img
    nt.nodes.active = node
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    return mat


def cycles(samples):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.render.bake.margin = 6


def bake_detail(high, low):
    cycles(1)
    normal = image("heavyarm_normal", TEX, (.5, .5, 1.0, 1.0), True)
    bake_target(low, normal)
    select_only([high, low], low)
    bpy.ops.object.bake(type="NORMAL", use_selected_to_active=True, cage_extrusion=.03, max_ray_distance=.08,
                        normal_space="TANGENT")
    normal.filepath_raw = os.path.join(WORK, "heavyarm_normal.png")
    normal.file_format = "PNG"
    normal.save()
    print("BAKED normal")
    cycles(24)
    # (Occlusion from the low mesh alone: with both, the low one shades the sculpt's surface under it black.)
    ao = image("heavyarm_ao", AO_TEX, (1, 1, 1, 1), True)
    bake_target(low, ao)
    select_only([low], low)
    high.hide_render = True
    bpy.ops.object.bake(type="AO", use_selected_to_active=False)
    high.hide_render = False
    ao.filepath_raw = os.path.join(WORK, "heavyarm_ao.png")
    ao.file_format = "PNG"
    ao.save()
    print("BAKED ao")
    return normal, ao


# ---------------------------------------------------------------- 2. skin and pose

def pose_rig(arm, arm_down, leg_out):
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
        pb.scale = (1, 1, 1)
    bpy.context.view_layer.update()
    turns = {"upper_arm.L": Matrix.Rotation(math.radians(arm_down), 4, Y),
             "upper_arm.R": Matrix.Rotation(math.radians(-arm_down), 4, Y),
             "thigh.L": Matrix.Rotation(math.radians(-leg_out), 4, Y),
             "thigh.R": Matrix.Rotation(math.radians(leg_out), 4, Y)}
    for name, r in turns.items():
        pb = arm.pose.bones[name]
        head = pb.matrix.translation.copy()
        pb.matrix = cc.about(head, r) @ pb.matrix
        bpy.context.view_layer.update()


def copy_weights(arm, body, low):
    pose_rig(arm, ARM_DOWN, LEG_OUT)
    ref = body.copy()
    ref.data = body.data.copy()
    bpy.context.scene.collection.objects.link(ref)
    for m in list(ref.modifiers):
        apply_mod(ref, m.name)
    mw = ref.matrix_world.copy()
    ref.parent = None
    ref.matrix_world = mw
    for vg in ref.vertex_groups:
        if vg.name not in low.vertex_groups:
            low.vertex_groups.new(name=vg.name)
    m = low.modifiers.new("weights", "DATA_TRANSFER")
    m.object = ref
    m.use_vert_data = True
    m.data_types_verts = {"VGROUP_WEIGHTS"}
    m.vert_mapping = "POLYINTERP_NEAREST"
    m.layers_vgroup_select_src = "ALL"
    m.layers_vgroup_select_dst = "NAME"
    apply_mod(low, "weights")
    bpy.data.objects.remove(ref)
    select_only([low], low)
    bpy.ops.object.vertex_group_clean(group_select_mode="ALL", limit=.01)
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
    # Into the skeleton's T pose: the arms up and the legs in, about the same joints.
    pose_rig(arm, -ARM_DOWN, -LEG_OUT)
    mod = low.modifiers.new("unpose", "ARMATURE")
    mod.object = arm
    apply_mod(low, "unpose")
    pose_rig(arm, 0.0, 0.0)


def weights(low):
    names = [g.name for g in low.vertex_groups]
    w = {n: np.zeros(len(low.data.vertices), np.float32) for n in names}
    for v in low.data.vertices:
        for g in v.groups:
            w[names[g.group]][v.index] = g.weight
    return w


def smooth(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)


def interp(s, stops):
    xs = [p[0] for p in stops]
    ys = [p[1] for p in stops]
    return np.interp(s, xs, ys)


# ---------------------------------------------------------------- 3. mutation

def mutate(low):
    w = weights(low)
    co = coords(low)
    low.data.update()
    nrm = np.array([v.normal[:] for v in low.data.vertices], np.float32)
    get = lambda n: w.get(n, np.zeros(len(co), np.float32))
    marks = {}
    for side, sign in (("R", -1.0), ("L", 1.0)):
        member = np.clip(get("upper_arm." + side) + get("forearm." + side) + get("hand." + side) + .6 * get("shoulder." + side), 0, 1)
        fore = get("forearm." + side) > .6
        yc = float(co[fore, 1].mean()) if fore.any() else 0.0
        zc = float(co[fore, 2].mean()) if fore.any() else 1.44
        s = (sign * co[:, 0] - .19) / .617
        marks[side] = (member, s, yc, zc)
        if side == "R":
            k = interp(s, [(-.25, 1.0), (0.0, 1.45), (.25, 1.95), (.454, 2.1), (.6, 2.95), (.76, 3.05), (.875, 2.6)])
            hand_scale = (1.4, 2.8)
        else:
            k = interp(s, [(-.2, 1.0), (0.0, 1.1), (.3, 1.2), (.55, 1.36), (.8, 1.3), (.875, 1.2)])
            hand_scale = (1.15, 1.3)
        k = 1.0 + (k - 1.0) * member
        out = co.copy()
        out[:, 1] = yc + (co[:, 1] - yc) * k
        out[:, 2] = zc + (co[:, 2] - zc) * k
        wrist = np.array((sign * .73, yc, zc), np.float32)
        b = smooth((s - .82) / .08) * member
        # The hand: thicker and broader far more than longer (a club of a fist, not a glove).
        hand = wrist + (co - wrist) * np.array((hand_scale[0], hand_scale[1], hand_scale[1]), np.float32)
        out = out * (1 - b[:, None]) + hand * b[:, None]
        sel = member > .001
        co[sel] = out[sel]
    # The heavy arm's skin heaves over the muscle; the left one is studded with tumours.
    member_r, s_r = marks["R"][0], marks["R"][1]
    member_l, s_l = marks["L"][0], marks["L"][1]
    disp = np.zeros(len(co), np.float32)
    for i, p in enumerate(co):
        if member_r[i] > .01 and s_r[i] > -.1:
            q = Vector(p)
            lump = .012 * noise.noise(q * 7.0) + .016 * max(0.0, noise.noise(q * 2.6 + Vector((3.1, 0, 0))))
            disp[i] += member_r[i] * lump
        if member_l[i] > .01 and s_l[i] > -.05:
            q = Vector(p)
            t = noise.noise(q * 5.5 + Vector((9.0, 2.0, 1.0)))
            disp[i] += member_l[i] * .062 * float(smooth(np.array((t - .18) / .32)))
    # A hump of muscle over the right shoulder and up the neck.
    hump = np.array((-.17, .03, 1.47), np.float32)
    d = np.linalg.norm(co - hump, axis=1)
    near = (1.0 - smooth(d / .2)) * np.clip(get("chest") + get("shoulder.R") + get("neck") + get("upper_arm.R"), 0, 1)
    disp += .05 * near
    co += nrm * disp[:, None]
    # The heavy arm longer as well: the upper arm and the forearm stretched along it (the hand carried out).
    member_r = marks["R"][0]
    u = -co[:, 0]
    u2 = np.where(u <= .19, u, np.where(u <= .47, .19 + (u - .19) * UPPER_LONG,
                  np.where(u <= .73, .19 + .28 * UPPER_LONG + (u - .47) * FORE_LONG, .19 + .28 * UPPER_LONG + .26 * FORE_LONG + (u - .73))))
    side = (co[:, 0] < -.1) & (member_r > .001)
    co[side, 0] = -(u[side] + (u2[side] - u[side]) * member_r[side])
    set_coords(low, co)
    return marks


def stretch_bones(arm):
    """The heavy arm's bones as long as its flesh now is (along -X, so no bone turns: the clips still fit)."""
    elbow = -(.19 + .28 * UPPER_LONG)
    wrist = elbow - .26 * FORE_LONG
    select_only([arm], arm)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    shift = wrist - eb["hand.R"].head.x
    eb["upper_arm.R"].tail.x = elbow
    eb["forearm.R"].head.x = elbow
    eb["forearm.R"].tail.x = wrist
    eb["hand.R"].head.x = wrist
    eb["hand.R"].tail.x += shift
    if "weapon.R" in eb:
        eb["weapon.R"].head.x += shift
        eb["weapon.R"].tail.x += shift
    bpy.ops.object.mode_set(mode="OBJECT")


# ---------------------------------------------------------------- 4. paint

def masks(low, marks):
    """Colour attribute "mask": R the heavy arm, G the left arm gone wrong, B the shorts, A where the blood is."""
    co = coords(low)
    member_r, s_r = marks["R"][0], marks["R"][1]
    member_l, s_l = marks["L"][0], marks["L"][1]
    r = member_r * smooth((s_r + .05) / .15)
    g = member_l * smooth((s_l - .1) / .2)
    z = co[:, 2] / SCALE
    legs = (np.abs(co[:, 0]) / SCALE < .34) & (member_r < .2) & (member_l < .2)
    b = legs * smooth((z - .56) / .03) * smooth((1.0 - z) / .03)
    a = np.zeros(len(co), np.float32)
    for i, p in enumerate(co):
        q = Vector(p) / SCALE
        mouth = max(0.0, 1.0 - (q - Vector((0, -.11, 1.58))).length / .09)
        chest = max(0.0, 1.0 - (q - Vector((.03, -.16, 1.3))).length / .22) * max(0.0, noise.noise(q * 6.0) + .2)
        hands = max(0.0, 1.0 - abs(abs(q.x) - .76) / .12) * (1.0 if abs(q.z - 1.44) < .25 else 0.0)
        a[i] = min(1.0, mouth * 1.6 + chest + hands * .8)
    attr = low.data.color_attributes.new("mask", "FLOAT_COLOR", "POINT")
    attr.data.foreach_set("color", np.stack([r, g, b, a], 1).astype(np.float32).ravel())


def node(nt, kind, loc, **inputs):
    n = nt.nodes.new(kind)
    n.location = loc
    for k, v in inputs.items():
        if hasattr(n, k):
            setattr(n, k, v)
        else:
            n.inputs[k].default_value = v
    return n


def mix(nt, a, b, fac, loc):
    m = nt.nodes.new("ShaderNodeMix")
    m.data_type = "RGBA"
    m.location = loc
    link = nt.links.new
    for i, src in ((6, a), (7, b)):
        if isinstance(src, tuple):
            m.inputs[i].default_value = src + (1.0,) if len(src) == 3 else src
        else:
            link(src, m.inputs[i])
    if isinstance(fac, float):
        m.inputs[0].default_value = fac
    else:
        link(fac, m.inputs[0])
    return m.outputs[2]


def ramp(nt, src, stops, loc):
    r = nt.nodes.new("ShaderNodeValToRGB")
    r.location = loc
    els = r.color_ramp.elements
    els[0].position, els[0].color = stops[0][0], (stops[0][1],) * 3 + (1,)
    els[1].position, els[1].color = stops[1][0], (stops[1][1],) * 3 + (1,)
    nt.links.new(src, r.inputs[0])
    return r.outputs[0]


def paint(low, ao):
    cycles(1)
    albedo = image("heavyarm_albedo", TEX, (.4, .38, .35, 1))
    mat = bpy.data.materials.new("paint")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    L = nt.links.new
    tc = node(nt, "ShaderNodeTexCoord", (-1600, 0))
    p = tc.outputs["Object"]
    attr = node(nt, "ShaderNodeVertexColor", (-1600, -400), layer_name="mask")
    sep = node(nt, "ShaderNodeSeparateColor", (-1400, -400))
    L(attr.outputs["Color"], sep.inputs[0])
    m_heavy, m_left, m_shorts = sep.outputs[0], sep.outputs[1], sep.outputs[2]
    m_blood = attr.outputs["Alpha"]
    n1 = node(nt, "ShaderNodeTexNoise", (-1300, 300), **{"Scale": 3.5, "Detail": 6.0, "Roughness": .55})
    L(p, n1.inputs["Vector"])
    n2 = node(nt, "ShaderNodeTexNoise", (-1300, 100), **{"Scale": 1.1, "Detail": 3.0})
    L(p, n2.inputs["Vector"])
    vor = node(nt, "ShaderNodeTexNoise", (-1300, -100), **{"Scale": 4.5, "Detail": 3.0, "Roughness": .45, "Distortion": .6})
    L(p, vor.inputs["Vector"])
    # Thin wandering lines where the noise crosses its middle (veins), not cells.
    ridge = node(nt, "ShaderNodeMath", (-1150, -100), operation="SUBTRACT")
    L(vor.outputs["Fac"], ridge.inputs[0])
    ridge.inputs[1].default_value = .5
    ridge_abs = node(nt, "ShaderNodeMath", (-1050, -100), operation="ABSOLUTE")
    L(ridge.outputs[0], ridge_abs.inputs[0])
    vein_n = node(nt, "ShaderNodeTexNoise", (-1300, -250), **{"Scale": 2.2})
    L(p, vein_n.inputs["Vector"])
    # Skin: dead grey going green, bruised in places, purple veins under it.
    mottle = ramp(nt, n1.outputs["Fac"], [(.35, 0.0), (.68, 1.0)], (-1000, 300))
    skin = mix(nt, (.25, .235, .205), (.16, .18, .14), mottle, (-800, 300))
    bruise = ramp(nt, n2.outputs["Fac"], [(.55, 0.0), (.72, 1.0)], (-1000, 120))
    skin = mix(nt, skin, (.21, .11, .16), bruise, (-600, 250))
    veins = ramp(nt, ridge_abs.outputs[0], [(.0, 1.0), (.018, 0.0)], (-1000, -80))
    vein_where = ramp(nt, vein_n.outputs["Fac"], [(.45, 0.0), (.6, 1.0)], (-1000, -250))
    vm = node(nt, "ShaderNodeMath", (-800, -120), operation="MULTIPLY")
    L(veins, vm.inputs[0])
    L(vein_where, vm.inputs[1])
    skin = mix(nt, skin, (.13, .05, .11), vm.outputs[0], (-400, 200))
    # The heavy arm: raw, striated muscle through stretched, split skin, the veins standing out.
    wave = node(nt, "ShaderNodeTexWave", (-1300, -500), wave_type="BANDS", bands_direction="X",
                **{"Scale": 16.0, "Distortion": 14.0, "Detail": 6.0, "Detail Scale": 2.0})
    L(p, wave.inputs["Vector"])
    fibre = ramp(nt, wave.outputs["Fac"], [(.2, .35), (.9, .75)], (-1000, -500))
    fibre = mix(nt, fibre, n1.outputs["Fac"], .45, (-900, -500))
    meat = mix(nt, (.12, .018, .02), (.33, .05, .045), fibre, (-800, -500))
    split = ramp(nt, n1.outputs["Fac"], [(.45, 0.0), (.58, 1.0)], (-1000, -650))
    raw = mix(nt, meat, (.36, .22, .2), split, (-600, -550))
    raw = mix(nt, raw, (.10, .02, .06), vm.outputs[0], (-400, -550))
    col = mix(nt, skin, raw, m_heavy, (-200, 100))
    # The left arm: blackened, necrotic, the tumours purple.
    nec = mix(nt, (.07, .065, .06), (.24, .19, .16), mottle, (-600, -800))
    nec = mix(nt, nec, (.26, .11, .19), bruise, (-400, -800))
    col = mix(nt, col, nec, m_left, (0, 0))
    # Torn dark shorts, dirty, the skin through the tears.
    tear = ramp(nt, n2.outputs["Fac"], [(.62, 1.0), (.66, 0.0)], (-600, -1000))
    cloth = mix(nt, (.05, .06, .11), (.11, .09, .07), mottle, (-400, -1000))
    sm = node(nt, "ShaderNodeMath", (-200, -1000), operation="MULTIPLY")
    L(m_shorts, sm.inputs[0])
    L(tear, sm.inputs[1])
    col = mix(nt, col, cloth, sm.outputs[0], (200, 0))
    # Old blood: the mouth, down the chest, the hands.
    blood_n = ramp(nt, n1.outputs["Fac"], [(.3, 0.0), (.55, 1.0)], (-200, -1200))
    bm_ = node(nt, "ShaderNodeMath", (0, -1200), operation="MULTIPLY")
    L(m_blood, bm_.inputs[0])
    L(blood_n, bm_.inputs[1])
    col = mix(nt, col, (.16, .012, .01), bm_.outputs[0], (400, 0))
    # The sculpt's cavities.
    uv = node(nt, "ShaderNodeUVMap", (0, -1500), uv_map="UVMap")
    ao_img = node(nt, "ShaderNodeTexImage", (200, -1500))
    ao_img.image = ao
    L(uv.outputs["UV"], ao_img.inputs["Vector"])
    shade = ramp(nt, ao_img.outputs["Color"], [(0.0, .3), (1.0, 1.0)], (400, -1500))
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.location = (600, 0)
    mul.inputs[0].default_value = 1.0
    L(col, mul.inputs[6])
    L(shade, mul.inputs[7])
    emit = node(nt, "ShaderNodeEmission", (800, 0))
    L(mul.outputs[2], emit.inputs["Color"])
    out = node(nt, "ShaderNodeOutputMaterial", (1000, 0))
    L(emit.outputs[0], out.inputs["Surface"])
    target = node(nt, "ShaderNodeTexImage", (800, 300))
    target.image = albedo
    nt.nodes.active = target
    low.data.materials.clear()
    low.data.materials.append(mat)
    select_only([low], low)
    bpy.ops.object.bake(type="EMIT", use_selected_to_active=False)
    albedo.filepath_raw = os.path.join(WORK, "heavyarm_albedo.jpg")
    albedo.file_format = "JPEG"
    albedo.save()
    print("BAKED albedo")
    return albedo


def final_material(low, albedo, normal):
    mat = bpy.data.materials.new("heavyarm_skin")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = .58
    a = nt.nodes.new("ShaderNodeTexImage")
    a.image = bpy.data.images.load(albedo.filepath_raw)
    nt.links.new(a.outputs["Color"], bsdf.inputs["Base Color"])
    n = nt.nodes.new("ShaderNodeTexImage")
    n.image = bpy.data.images.load(normal.filepath_raw)
    n.image.colorspace_settings.name = "Non-Color"
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nm.uv_map = "UVMap"
    nt.links.new(n.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    low.data.materials.clear()
    low.data.materials.append(mat)


# ---------------------------------------------------------------- bone through the skin

def bone_material():
    mat = bpy.data.materials.new("heavyarm_bone")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (.4, .33, .22, 1)
    bsdf.inputs["Roughness"].default_value = .42
    return mat


def spurs(low, marks):
    """Bone breaking out: along the top of the heavy forearm, from its knuckles, over the right shoulder, out of
    the left forearm toward the elbow, and a few knuckles of spine."""
    low.data.update()
    bvh = BVHTree.FromObject(low, bpy.context.evaluated_depsgraph_get())
    S = SCALE
    _, _, yr, zr = marks["R"]
    _, _, yl, zl = marks["L"]
    specs = []   # (ray from, ray dir, spur dir, length, radius, bone)

    def top(x, y, z, bone, d, length, radius):
        specs.append((Vector((x, y, z + .8)) * 1.0, Vector((0, 0, -1)), Vector(d).normalized(), length, radius, bone))

    def along(s):
        u = .19 + .617 * s
        if u <= .47:
            return .19 + (u - .19) * UPPER_LONG
        if u <= .73:
            return .19 + .28 * UPPER_LONG + (u - .47) * FORE_LONG
        return .19 + .28 * UPPER_LONG + .26 * FORE_LONG + (u - .73)

    for i, s in enumerate((.5, .6, .69, .79)):
        x = -along(s) * S
        top(x, (yr + (.03 if i % 2 else -.03)) * S, zr * S, "forearm.R", (.55, (.25 if i % 2 else -.25), 1.0), (.13 + .03 * (i % 3)) * S, .028 * S)
    for s, y in ((.1, .0), (.2, .05)):
        top(-along(s) * S, y * S, zr * S, "upper_arm.R", (.3, .35, 1.0), .11 * S, .026 * S)
    for y in (-.05, .0, .05):
        specs.append((Vector((-1.6 * S, y * S, zr * S)), Vector((1, 0, 0)), Vector((-1, y * 2, .15)).normalized(), .07 * S, .018 * S, "hand.R"))
    for i, s in enumerate((.5, .58, .66, .74, .8)):
        x = (.19 + .617 * s) * S
        top(x, (yl + .02 * ((i % 3) - 1)) * S, zl * S, "forearm.L", (-.85, .15 * ((i % 3) - 1), .65), (.13 + .035 * (i % 3)) * S, .015 * S)
    for s in (.25, .35):
        top((.19 + .617 * s) * S, (yl - .02) * S, zl * S, "upper_arm.L", (-.4, -.3, 1.0), .07 * S, .014 * S)
    for z in (1.18, 1.28, 1.38):
        specs.append((Vector((0, .6 * S, z * S)), Vector((0, -1, 0)), Vector((0, 1, .35)).normalized(), .035 * S, .014 * S, "chest" if z > 1.26 else "spine"))
    bm = bmesh.new()
    groups = []
    for origin, ray, d, length, radius, bone in specs:
        hit, _, _, _ = bvh.ray_cast(origin, ray, 3.0)
        if hit is None:
            print("SPUR missed", bone)
            continue
        base = hit - d * length * .22
        rot = Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4()
        m = Matrix.Translation(base + d * length * .5) @ rot
        before = len(bm.verts)
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=7, radius1=radius, radius2=radius * .1, depth=length, matrix=m)
        bm.verts.ensure_lookup_table()
        # Curved like a claw or a horn toward the tip, the surface rough.
        bend = d.cross(Vector((0, 0, 1)) if abs(d.z) < .9 else Vector((1, 0, 0))).normalized()
        bend = bend.cross(d).normalized()
        foot = base
        for v in bm.verts[before:]:
            t = max(0.0, min(1.0, (v.co - foot).dot(d) / length))
            v.co += bend * (t * t) * length * .28
            v.co += Vector((noise.noise(v.co * 40.0), noise.noise(v.co * 40.0 + Vector((5, 0, 0))), noise.noise(v.co * 40.0 + Vector((0, 7, 0))))) * radius * .3
        groups.append((before, len(bm.verts), bone))
    me = bpy.data.meshes.new("Spurs")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("Spurs", me)
    bpy.context.scene.collection.objects.link(ob)
    for a, b, bone in groups:
        g = ob.vertex_groups.get(bone) or ob.vertex_groups.new(name=bone)
        g.add(list(range(a, b)), 1.0, "REPLACE")
    me.materials.append(bone_material())
    for p in me.polygons:
        p.use_smooth = False
    select_only([low, ob], low)
    bpy.ops.object.join()
    print("SPURS", len(groups))


# ---------------------------------------------------------------- build

def build_model(a):
    bh.reset()
    os.makedirs(WORK, exist_ok=True)
    arm, body = load_rig()
    top = float(coords(body)[:, 2].max())
    high = load_sculpt(top)
    low = make_low(high)
    unwrap(low)
    normal, ao = bake_detail(high, low)
    bpy.data.objects.remove(high)
    copy_weights(arm, body, low)
    bpy.data.objects.remove(body)
    marks = mutate(low)
    stretch_bones(arm)
    # Everything to his size.
    low.data.transform(Matrix.Scale(SCALE, 4))
    arm.data.transform(Matrix.Scale(SCALE, 4))
    masks(low, marks)
    albedo = paint(low, ao)
    final_material(low, albedo, normal)
    low.data.color_attributes.remove(low.data.color_attributes["mask"])
    low.parent = arm
    mod = low.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    spurs(low, {k: (m, s, y, z) for k, (m, s, y, z) in marks.items()})
    low.data.calc_loop_triangles()
    facts = {"triangles": len(low.data.loop_triangles), "vertices": len(low.data.vertices),
             "height": float(coords(low)[:, 2].max()), "scale": SCALE}
    print("HEAVYARM", facts)
    with open(os.path.join(WORK, "model.json"), "w") as f:
        json.dump(facts, f, indent=1)
    if "export" in a:
        export(arm, os.path.join(OUT_DIR, "heavyarm.glb"), False)
    if "preview" in a:
        preview(arm, low)


def export(arm, path, animations):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    for o in bpy.context.scene.objects:
        o.select_set(o == arm or (o.type == "MESH" and o.parent == arm))
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = None
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_animations=animations,
                              export_animation_mode="ACTIONS", export_skins=True, export_morph=False, export_yup=True,
                              export_apply=False, export_force_sampling=True, export_optimize_animation_size=True,
                              export_def_bones=False, export_image_format="AUTO")
    print("EXPORTED", path, os.path.getsize(path))


def preview(arm, low):
    cam = bh.setup_render((560, 760))
    pose_rig(arm, 72.0, 2.0)
    S = SCALE
    bh.shoot(cam, os.path.join(WORK, "model_front.png"), (0.0, -4.4 * S, 1.0 * S), (0.0, 0.0, .95 * S), lens=50)
    bh.shoot(cam, os.path.join(WORK, "model_q.png"), (-2.6 * S, -3.0 * S, 1.3 * S), (0.0, 0.0, .95 * S), lens=50)
    bh.shoot(cam, os.path.join(WORK, "model_back.png"), (1.6 * S, 3.6 * S, 1.2 * S), (0.0, 0.0, .95 * S), lens=50)
    bh.shoot(cam, os.path.join(WORK, "model_arm.png"), (-1.6 * S, -1.5 * S, 1.3 * S), (-.3 * S, 0.0, 1.05 * S), lens=55)
    bh.shoot(cam, os.path.join(WORK, "model_face.png"), (-.3 * S, -1.0 * S, 1.6 * S), (0.0, 0.0, 1.55 * S), lens=70)
    pose_rig(arm, 0.0, 0.0)
    bh.shoot(cam, os.path.join(WORK, "model_t.png"), (0.0, -5.0 * S, 1.2 * S), (0.0, 0.0, 1.0 * S), lens=45)


def build_clips(a):
    import heavyarm_clips
    bh.reset()
    arm, body = load_rig(heavyarm_clips.BASES)
    made = heavyarm_clips.make_all(arm)
    facts = {act.name: round((act.frame_range[1] - act.frame_range[0]) / bh.FPS, 3) for act in made}
    print("CLIPS", facts)
    os.makedirs(WORK, exist_ok=True)
    with open(os.path.join(WORK, "clips.json"), "w") as f:
        json.dump(facts, f, indent=1)
    if "preview" in a:
        heavyarm_clips.preview(arm, made, WORK)
    if "export" in a:
        keep = {act.name for act in made}
        for act in list(bpy.data.actions):
            if act.name not in keep:
                bpy.data.actions.remove(act)
        export(arm, os.path.join(OUT_DIR, "heavyarm_anims.glb"), True)


def main():
    a = args()
    if "model" in a:
        build_model(a)
    if "clips" in a:
        build_clips(a)


if __name__ == "__main__":
    main()
