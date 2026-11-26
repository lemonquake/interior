"""Interior 0.11: the player's first-person arms holding the Glock 17.

  blender -b --factory-startup --python tools/blender/human/build_fp_arms.py -- [preview] [export]

  preview   eye-camera tiles + one outside view          -> work/v11/arms/*.png (+ sheet.txt for contact_sheet.py)
  export    game/assets/characters/fp_arms.glb  (armature + arms mesh + the empty `gun_grip`; NOT the Glock)

Built from the same rigged body as the stranger (models/generic_body_rigged.glb, helpers from build_human.py):
only the forearms and hands (+ a bit of upper arm) are kept, in dark grey long sleeves with ribbed cuffs; the hands
are the body's fists. The armature object sits at -EYE, so the scene origin is the eye point; the arms face -Y
like the body (Blender, Z up). In glTF / Godot (Y up) that is: the eye at the origin, the arms along +Z, i.e. a
Godot Camera3D (looking -Z) needs the fp_arms root turned 180 degrees about Y.

The clips (100 fps so the 0.12 s recoil has real frames) are baked from IK + copy-rotation helpers that put both
hands on a moving "gun" frame, the frame of glock17.glb's scene root:
  fp_idle 3 s (loop), fp_draw 0.45 s, fp_holster 0.35 s, fp_fire 0.12 s, fp_reload 1.6 s, fp_dry 0.25 s.
`gun_grip` is bone-parented to hand.R so that glock17.glb's root placed at gun_grip (identity) sits in the right fist.
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_human as bh  # noqa: E402
import fp_hands  # noqa: E402

ROOT = bh.ROOT
OUT_GLB = os.path.join(ROOT, "game", "assets", "characters", "fp_arms.glb")
GLOCK = os.path.join(ROOT, "game", "assets", "models", "story", "glock17.glb")
WORK = os.path.join(ROOT, "work", "v31", "arms")
FPS = 100
# The eye point in the body frame (between the eyes; the eye surface is at y -0.122, z 1.68, measured on the mesh).
EYE = Vector((0.0, -0.11, 1.68))

# The Glock in its own (scene root) frame, Blender axes: muzzle along -Y, top +Z, its left +X. 0.31: the model is the
# real size now (204 mm; tools/scale_glb_root.py), and these are measured on it (game/tests/_glock_dims.gd).
GRIP_C = Vector((0.0, 0.0507, -0.0141))    # the middle of the grip (what the gun turns about in the clips)
GRIP_TILT = math.radians(12.0)             # the lean the left hand's reload poses were built with
MAG_BASE = Vector((0.0, 0.0554, -0.0590))  # the left hand round the magazine's base plate
SLIDE_REAR = Vector((0.0, 0.0802, 0.0542))  # the left hand over the rear slide serrations
# The right hand on the grip. The hollow under the beavertail, where the web between thumb and index finger sits:
TANG = Vector((0.0, 0.0630, 0.0240))
# The grip leans back 22 degrees. Its own axis, pointing down it; and square to that, forward.
RAKE = math.radians(22.0)
# Seen from above, the hand is not flat on the grip's side: it comes round the back of it, the wrist behind the gun.
HAND_ROUND = math.radians(14.0)
# ...and it is rolled about its own length, the little finger's side toward the grip.
HAND_ROLL = math.radians(0.0)
# The point of the hand that sits in that hollow, in the hand bone's frame (wrist at the origin, +Y to the fingers,
# -Z the palm, the thumb on -X): between the thumb's and the index finger's knuckles, in the hollow of the palm.
WEB_R = Vector((-0.0370, 0.0700, -0.0250))
# Fist hole centres in each hand bone's frame, for the left hand's reload poses.
HOLE_R = Vector((-0.007, 0.07, -0.026))
HOLE_L = Vector((0.007, 0.07, -0.026))
# Aim pose: the grip centre in eye space (right is -X), 0.37 m ahead, low right; muzzle toed in 6 degrees.
AIM_GRIP = Vector((-0.15, -0.37, -0.125))
AIM_YAW = math.radians(6.0)

# fp_reload event times (s), for syncing magazine_7 and the slide in Godot.
RELOAD_MAG_OUT = 0.30        # the left hand pulls the empty magazine down out of the well
RELOAD_MAG_SEATED = 0.95     # the new magazine is pushed home
RELOAD_SLIDE_BACK = 1.27     # the left hand has the slide fully back
RELOAD_SLIDE_RELEASED = 1.30  # ...and lets it go (slide slams forward)

CLIPS = {"fp_idle": 3.0, "fp_draw": 0.45, "fp_holster": 0.35, "fp_fire": 0.12, "fp_reload": 1.6, "fp_dry": 0.25}


def smooth01(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3.0 - 2.0 * x)


def frame(x, y, z, origin):
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = origin
    return m


def blend(a, b, s):
    """Rigid blend of two 4x4 matrices (lerp + slerp)."""
    la, ra, _ = a.decompose()
    lb, rb, _ = b.decompose()
    m = ra.slerp(rb, s).to_matrix().to_4x4()
    m.translation = la.lerp(lb, s)
    return m


# ---------------------------------------------------------------- hands on the gun (gun frame)

def g_axis():
    return Vector((0.0, math.sin(GRIP_TILT), -math.cos(GRIP_TILT)))


def right_on_grip():
    """hand.R in the gun frame: the web of the hand in the hollow under the beavertail, the knuckle line down the
    grip, the hand come round the back of the grip so that the wrist is behind the gun."""
    down = Vector((0.0, math.sin(RAKE), -math.cos(RAKE)))        # down the grip
    ahead = Vector((0.0, -math.cos(RAKE), -math.sin(RAKE)))      # square to it, toward the muzzle
    left = Vector((1.0, 0.0, 0.0))
    c, sn = math.cos(HAND_ROUND), math.sin(HAND_ROUND)
    x = down
    y = ahead * c - left * sn
    z = x.cross(y)
    rot = frame(x, y, z, Vector()) @ Matrix.Rotation(HAND_ROLL, 4, "Y")
    return Matrix.Translation(TANG - rot.to_3x3() @ WEB_R) @ rot


def left_at(hole_c, x, z):
    rot = frame(x, z.cross(x), z, Vector())
    return Matrix.Translation(hole_c - rot.to_3x3() @ HOLE_L) @ rot


def left_support():
    """Thumbs-forward support grip: the left palm against the right fingers, left fingers over them."""
    g = g_axis()
    return left_at(GRIP_C + Vector((0.032, -0.012, -0.012)), -g, Vector((1.0, 0.0, 0.0)))


def left_mag(drop=0.0):
    """Left fist round the magazine base, palm up, fingers to the right; `drop` slides it down along the grip."""
    g = g_axis()
    return left_at(MAG_BASE + g * drop, Vector((0.0, -1.0, 0.0)), g)


def left_rack(pull=0.0):
    """Overhand rack: the left palm on top of the slide's rear, fingers over to the right side, thumb back."""
    return left_at(SLIDE_REAR + Vector((0.0, pull, 0.004)), Vector((0.0, 1.0, 0.0)), Vector((0.0, 0.0, 1.0)))


def gun_pose(dx=0.0, dy=0.0, dz=0.0, pitch=0.0, roll=0.0, yaw=0.0):
    """The gun root in eye space: the aim pose, moved by (dx, dy, dz) and turned about the grip centre
    (pitch + = muzzle up, roll + = top to the right, yaw + = muzzle left), all in degrees."""
    rot = (Matrix.Rotation(AIM_YAW + math.radians(yaw), 4, "Z") @ Matrix.Rotation(-math.radians(pitch), 4, "X")
           @ Matrix.Rotation(math.radians(roll), 4, "Y"))
    return Matrix.Translation(AIM_GRIP + Vector((dx, dy, dz))) @ rot @ Matrix.Translation(-GRIP_C)


def track(keys, t):
    """keys: [(time, value)] with values dicts of floats -> smoothstep-interpolated dict at t."""
    if t <= keys[0][0]:
        return dict(keys[0][1])
    for (t0, a), (t1, b) in zip(keys, keys[1:]):
        if t <= t1:
            s = smooth01((t - t0) / max(1e-6, t1 - t0))
            names = set(a) | set(b)
            return {k: a.get(k, 0.0) + (b.get(k, 0.0) - a.get(k, 0.0)) * s for k in names}
    return dict(keys[-1][1])


def hand_track(keys, t, G, low):
    """keys: [(time, spec)], spec a function (G, low) -> left-hand world matrix; blends between neighbours."""
    if t <= keys[0][0]:
        return keys[0][1](G, low)
    for (t0, a), (t1, b) in zip(keys, keys[1:]):
        if t <= t1:
            return blend(a(G, low), b(G, low), smooth01((t - t0) / max(1e-6, t1 - t0)))
    return keys[-1][1](G, low)


SUPPORT = lambda G, low: G @ left_support()  # noqa: E731
def LOW(G, low):
    """The left hand down by the belt (fetching the new magazine), palm up as on the magazine."""
    m = G @ left_mag(0.0)
    m.translation = Vector((0.03, -0.22, -0.55))
    return m


def mag(drop):
    return lambda G, low: G @ left_mag(drop)


def rack(pull):
    return lambda G, low: G @ left_rack(pull)


def fly(G, low):
    return G @ Matrix.Translation(Vector((0.05, 0.05, 0.04))) @ left_rack(0.05)


# ---------------------------------------------------------------- clips

LOW_GUN = {"dx": -0.04, "dy": 0.10, "dz": -0.32, "pitch": -45.0, "roll": 15.0}


# During the rack the gun comes in low and turns its left side / rear to the left hand.
RACK_GUN = {"dx": 0.03, "dy": 0.0, "dz": -0.12, "pitch": 10.0, "roll": 14.0, "yaw": 22.0}


def clip_poses(name, t, low_l):
    """(gun matrix, left-hand matrix) in eye space at time t of clip `name`."""
    if name == "fp_idle":
        p = t / 3.0 * math.tau
        G = gun_pose(dx=0.0012 * math.sin(p + 0.7), dz=0.003 * math.sin(p), pitch=0.45 * math.sin(p + 0.5))
        return G, SUPPORT(G, low_l), 1.0
    if name in ("fp_draw", "fp_holster"):
        L = CLIPS[name]
        s = t / L if name == "fp_draw" else 1.0 - t / L
        e = 1.0 - (1.0 - s) ** 2.2 if name == "fp_draw" else s ** 1.6       # draw eases out, holster drops away
        G = gun_pose(**{k: v * (1.0 - e) for k, v in LOW_GUN.items()})
        sl = smooth01((s - 0.35) / 0.55)
        return G, SUPPORT(G, low_l), sl            # the left arm hangs (FK idle) until it joins
    if name in ("fp_fire", "fp_dry"):
        if name == "fp_fire":
            k = smooth01(t / 0.028) if t < 0.028 else (1.0 - smooth01((t - 0.028) / 0.092)) ** 1.2
            G = gun_pose(dy=0.02 * k, dz=0.009 * k, pitch=4.5 * k)
        else:
            k = math.sin(math.pi * min(1.0, t / 0.25)) ** 2
            G = gun_pose(dy=0.0015 * k, pitch=0.35 * k)
        return G, SUPPORT(G, low_l), 1.0
    if name == "fp_reload":
        gun = [(0.0, {}), (0.18, {"dx": 0.035, "dy": 0.04, "dz": -0.03, "pitch": 16.0, "roll": -32.0}),
               (0.92, {"dx": 0.035, "dy": 0.04, "dz": -0.03, "pitch": 16.0, "roll": -32.0}),
               (1.08, RACK_GUN), (1.27, RACK_GUN),
               (1.32, dict(RACK_GUN, dy=RACK_GUN["dy"] + 0.012, pitch=RACK_GUN["pitch"] + 2.0)),
               (1.6, {})]
        G = gun_pose(**track(gun, t))
        left = [(0.0, SUPPORT), (0.12, SUPPORT), (0.24, mag(0.0)), (RELOAD_MAG_OUT, mag(0.05)),
                (0.40, mag(0.13)), (0.55, LOW), (0.62, LOW), (0.80, mag(0.07)), (RELOAD_MAG_SEATED, mag(0.0)),
                (1.0, mag(0.0)), (1.12, rack(0.0)), (RELOAD_SLIDE_BACK, rack(0.055)),
                (RELOAD_SLIDE_RELEASED, rack(0.055)), (1.38, fly), (1.6, SUPPORT)]
        return G, hand_track(left, t, G, low_l), 1.0
    raise KeyError(name)


def left_low(arm):
    """The relaxed left hand (idle, at his side) as a world matrix: the left hand's 'pocket' pose."""
    bh.set_action(arm, bpy.data.actions["idle"], 0)
    bpy.context.view_layer.update()
    pb = arm.pose.bones["hand.L"]
    m = arm.matrix_world @ pb.matrix
    m = m.copy()
    m.translation += Vector((-0.05, -0.12, 0.12))
    return m


def bake_clip(arm, name, low_l, base):
    length = CLIPS[name]
    frames = int(round(length * FPS))
    act = bpy.data.actions.new(name + "_src")
    bh.set_action(arm, None)
    arm.animation_data.action = act
    for f in range(frames + 1):
        bh.key_pose(arm, f, base, {})
    tg = {}
    for side in ("R", "L"):
        sx = -1.0 if side == "R" else 1.0
        tgt = bpy.data.objects.new("IK target " + side, None)
        pole = bpy.data.objects.new("IK pole " + side, None)
        for o in (tgt, pole):
            bpy.context.scene.collection.objects.link(o)
        pole.location = Vector((sx * 0.55, 0.15, -0.65))       # elbows down and a little out
        tgt.rotation_mode = "QUATERNION"
        ik = arm.pose.bones["forearm." + side].constraints.new("IK")
        ik.target, ik.pole_target, ik.chain_count = tgt, pole, 2
        ik.pole_angle = math.radians(bh.POLE_ANGLE[side])
        cr = arm.pose.bones["hand." + side].constraints.new("COPY_ROTATION")
        cr.target = tgt
        tg[side] = tgt
        if side == "L":
            cons_l = (ik, cr)
    for f in range(frames + 1):
        G, L, wl = clip_poses(name, f / FPS, low_l)
        for side, m in (("R", G @ right_on_grip()), ("L", L)):
            loc, rot, _ = m.decompose()
            tg[side].location = loc
            tg[side].rotation_quaternion = rot
            tg[side].keyframe_insert("location", frame=f)
            tg[side].keyframe_insert("rotation_quaternion", frame=f)
        for c in cons_l:
            c.influence = wl
            c.keyframe_insert("influence", frame=f)
    return bh.bake_action(arm, name, frames, act)


# ---------------------------------------------------------------- mesh

def arms_mesh(arm, body):
    M = {"skin": bh.principled("FP skin", (0.7, 0.5, 0.4), 0.62, bh.SKIN_TEX),
         "sleeve": bh.principled("FP sleeve grey", (0.085, 0.087, 0.092), 0.9, sheen=0.25),
         "rib": bh.principled("FP sleeve rib", (0.062, 0.063, 0.067), 0.95)}
    sleeve = bh.duplicate(body, "FP sleeves")
    bh.cut(sleeve, [], drop=lambda c: abs(c.x) < 0.33 or abs(c.x) > 0.702 or c.z < 1.25)

    def off(co, n):
        ax = abs(co.x)
        d = 0.015 + 0.005 * math.sin(min(1.0, (ax - 0.2) / 0.3) * math.pi)
        if ax > 0.665:
            d = 0.008 + 0.007 * max(0.0, (0.70 - ax) / 0.035)
        return d
    bh.inflate(sleeve, off, smooth_iters=3, wrinkle=0.004)
    bh.assign_by_face(sleeve, {"sleeve": M["sleeve"], "rib": M["rib"]},
                      lambda c: "rib" if abs(c.x) > 0.668 else "sleeve")
    # 0.31: the body's fists are not used any more; the hands have fingers (fp_hands.py) and reach up into the cuffs.
    bh.apply_modifiers(sleeve)
    hands = fp_hands.build(arm)
    for o in bpy.context.scene.objects:
        o.select_set(o in (sleeve, hands))
    bpy.context.view_layer.objects.active = hands
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = ob.data.name = "FPArms"
    for p in ob.data.polygons:
        p.use_smooth = True
    bpy.data.objects.remove(body)
    return ob


def add_gun_grip(arm):
    """`gun_grip` on hand.R: the gun root relative to the right hand = inverse of the hand's place on the grip."""
    e = bpy.data.objects.new("gun_grip", None)
    e.empty_display_size = 0.05
    bpy.context.scene.collection.objects.link(e)
    e.parent = arm
    e.parent_type = "BONE"
    e.parent_bone = "hand.R"
    bh.set_action(arm, None)
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    e.matrix_world = arm.matrix_world @ arm.data.bones["hand.R"].matrix_local @ right_on_grip().inverted()
    bpy.context.view_layer.update()
    arm.data.pose_position = "POSE"
    bpy.context.view_layer.update()
    return e


# ---------------------------------------------------------------- preview / export

def import_glock(grip):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=GLOCK)
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        if o.animation_data:
            o.animation_data.action = None
    root = bpy.data.objects["Glock17"]
    m = root.matrix_world.copy()
    root.parent = grip
    root.matrix_parent_inverse = Matrix.Identity(4)
    root.matrix_basis = m
    return new


def eye_shot(cam, path):
    cam.location = (0, 0, 0)
    cam.rotation_euler = Vector((0, -1, 0)).to_track_quat("-Z", "Y").to_euler()
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle_y = math.radians(55.0)
    cam.data.clip_start = 0.02
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("RENDER", path)


def preview(arm, grip):
    os.makedirs(WORK, exist_ok=True)
    cam = bh.setup_render((640, 360))
    import_glock(grip)
    tiles = []
    shots = [("fp_idle", 0.0, "idle"), ("fp_draw", 0.22, "draw mid (0.22 s)"),
             ("fp_fire", 0.03, "fire peak (0.03 s)"), ("fp_reload", RELOAD_MAG_OUT, "reload mag out (%.2f s)" % RELOAD_MAG_OUT),
             ("fp_reload", 0.62, "reload new mag (0.62 s)"), ("fp_reload", RELOAD_MAG_SEATED, "reload seated (%.2f s)" % RELOAD_MAG_SEATED),
             ("fp_reload", RELOAD_SLIDE_BACK, "reload rack (%.2f s)" % RELOAD_SLIDE_BACK),
             ("fp_holster", 0.2, "holster (0.20 s)"), ("fp_draw", 0.0, "draw start / holstered")]
    for clip, t, label in shots:
        bh.set_action(arm, bpy.data.actions[clip], int(round(t * FPS)))
        path = os.path.join(WORK, "%s_%03d.png" % (clip, int(round(t * 100))))
        eye_shot(cam, path)
        tiles.append((path, label))
    for clip, t, tag in (("fp_idle", 0.0, "idle"), ("fp_reload", RELOAD_SLIDE_BACK, "rack"),
                         ("fp_holster", 0.2, "holster")):
        bh.set_action(arm, bpy.data.actions[clip], int(round(t * FPS)))
        for vname, eye, look in (("out_side", (0.75, -0.35, 0.05), (-0.06, -0.33, -0.12)),
                                 ("out_front", (-0.25, -1.1, 0.05), (-0.06, -0.3, -0.12))):
            path = os.path.join(WORK, "%s_%s.png" % (tag, vname))
            bh.shoot(cam, path, eye, look, lens=40)
            tiles.append((path, "%s, outside (%s)" % (tag, vname.split("_")[1])))
    with open(os.path.join(WORK, "sheet.txt"), "w") as f:
        for path, label in tiles:
            f.write(path + "\t" + label + "\n")


def hand_sheet(arm):
    """The bare hands in the rest pose and curled, from above, below and the thumb's side."""
    os.makedirs(WORK, exist_ok=True)
    cam = bh.setup_render((560, 420))
    bh.set_action(arm, None)
    tiles = []
    poses = {"open": {}, "grip": {"index": (20, 35, 15), "middle": (68, 92, 35), "ring": (70, 95, 38), "pinky": (72, 96, 40),
                                   "thumb": (18, 25, 18, 25)},
             "fist": {n: (80, 100, 60) for n in ("index", "middle", "ring", "pinky")} | {"thumb": (35, 20, 40, 50)}}
    for tag, pose in poses.items():
        for pb in arm.pose.bones:
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = (1, 0, 0, 0)
            pb.location = (0, 0, 0)
        fp_hands.curl(arm, "R", pose)
        bpy.context.view_layer.update()
        c = arm.matrix_world @ arm.pose.bones["hand.R"].head + Vector((-0.085, 0.0, 0.0))
        for vname, off in (("back", (0.0, 0.02, 0.42)), ("palm", (0.0, -0.02, -0.42)), ("thumb side", (-0.05, -0.42, 0.06)),
                           ("tips", (-0.42, -0.10, 0.10))):
            path = os.path.join(WORK, "hand_%s_%s.png" % (tag, vname.replace(" ", "_")))
            bh.shoot(cam, path, tuple(c + Vector(off)), tuple(c), lens=85)
            tiles.append((path, "%s, %s" % (tag, vname)))
    with open(os.path.join(WORK, "hands.txt"), "w") as f:
        for path, label in tiles:
            f.write(path + chr(9) + label + chr(10))
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)


def check(arm, grip):
    """How well the baked hands follow the IK targets: the gun root (via gun_grip) vs the intended gun pose."""
    worst = {}
    low_l = left_low(arm)
    for name, length in CLIPS.items():
        bh.set_action(arm, bpy.data.actions[name])
        err = 0.0
        for f in range(0, int(round(length * FPS)) + 1, 2):
            bpy.context.scene.frame_set(f)
            G, _, _ = clip_poses(name, f / FPS, low_l)
            err = max(err, (grip.matrix_world.translation - G.translation).length)
        worst[name] = round(err * 1000, 2)
    print("GUN_GRIP ERROR mm", worst)
    return worst


def export(arm, mesh, grip):
    os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
    for act in list(bpy.data.actions):
        if act.name not in CLIPS:
            bpy.data.actions.remove(act)
    bh.set_action(arm, None)
    for o in bpy.context.scene.objects:
        o.select_set(o in (arm, mesh, grip))
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", use_selection=True, export_animations=True,
                              export_animation_mode="ACTIONS", export_skins=True, export_morph=False,
                              export_yup=True, export_apply=False, export_force_sampling=True,
                              export_optimize_animation_size=True, export_def_bones=False,
                              # The hands' textures are files of their own (game/assets/characters/hands).
                              export_image_format="NONE")
    print("EXPORTED", OUT_GLB, os.path.getsize(OUT_GLB))


def main():
    a = bh.args()
    bh.reset()
    bpy.context.scene.render.fps = FPS
    arm, body = bh.load_body()
    arm.location = -EYE
    bpy.context.view_layer.update()
    fp_hands.add_bones(arm)
    bpy.context.view_layer.update()
    base = bh.rest_pose(arm)
    low_l = left_low(arm)
    for name in CLIPS:
        bake_clip(arm, name, low_l, base)
    mesh = arms_mesh(arm, body)
    grip = add_gun_grip(arm)
    check(arm, grip)
    mesh.data.calc_loop_triangles()
    print("MESH", len(mesh.data.loop_triangles), [m.name for m in mesh.data.materials])
    if "hands" in a:
        hand_sheet(arm)
    if "preview" in a:
        preview(arm, grip)
    if "export" in a:
        export(arm, mesh, grip)


if __name__ == "__main__":
    main()
