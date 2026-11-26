"""0.53: Heavy-arm's own clips, on the 1x town rig (build_heavyarm.py `clips` exports them to heavyarm_anims.glb; the
game plays them on his 1.25x skeleton with Skeleton3D.motion_scale).

  heavy_sit    6.0 s loop  sat on the ground against the rear gate, knees up, the heavy fist on the ground beside
                           him, the left forearm on a knee, head hung; slow heavy breaths; now and then the head jerks
  heavy_rise   2.0 s       up off the ground, pushing off it with the heavy arm, leaning over his feet, head coming up
  heavy_idle   3.0 s loop  stood over the heavy arm, a little crouched, heaving
  heavy_walk   1.25 s loop the town's hurt walk slowed, leaning to the heavy side, the arm swinging low and late
  heavy_wind   1.0 s loop  the charge coming: crouched, the fist cocked back past the hip, the left hand out, trembling
  heavy_charge 0.6 s loop  the run, leant into it, the heavy arm held forward and low like a ram
  heavy_dig    1.2 s loop  the throw coming: squatting, the heavy hand in the ground tearing up a slab
  heavy_throw  1.2 s       up with it overhead and over (let go at THROW_RELEASE), into a stand
  heavy_inhale 1.2 s loop  the roar coming: chest up and back, arms spread, head going back, breathing in
  heavy_daze   1.8 s loop  stunned after a blast or a wall: swaying, the left hand to the head, the arm limp

Turns are given in the body's axes about each bone's head (crawl_clips.pose_at): "f" flexion (a hanging limb
swings forward; a bone pointing up tilts back), "s" out to its own side, "t" about the standing body's long axis,
"r" a roll toward the body's right. A body leant forward by L carries a hanging arm back by L: where a turn has to
reach a place in front of him the arm's flexion includes the lean.
"""
import math
import os

import bpy
from mathutils import Matrix, Vector

import crawl_clips as cc

FPS = 30
BASES = ["idle", "walk_hurt", "run"]
THROW_RELEASE = 0.52
R_CHAIN = ["shoulder.R", "upper_arm.R", "forearm.R", "hand.R", "weapon.R"]
NAMES = ["heavy_sit", "heavy_rise", "heavy_idle", "heavy_walk", "heavy_wind", "heavy_charge", "heavy_dig",
         "heavy_throw", "heavy_inhale", "heavy_daze"]


def turn(bone, kinds):
    side = "L" if bone.endswith(".L") else "R"
    m = Matrix.Identity(4)
    for kind in ("f", "s", "t", "r"):
        deg = kinds.get(kind, 0.0)
        if deg == 0.0:
            continue
        if kind == "f":
            m = m @ cc.flex(deg)
        elif kind == "s":
            m = m @ cc.side_out(side, deg)
        elif kind == "t":
            m = m @ cc.twist(deg)
        else:
            m = m @ cc.rot(cc.F, deg)
    return m


def turns(spec):
    return {b: turn(b, k) for b, k in spec.items()}


def lerp_spec(a, b, k):
    out = {}
    for bone in set(a) | set(b):
        ka, kb = a.get(bone, {}), b.get(bone, {})
        out[bone] = {kind: ka.get(kind, 0.0) + (kb.get(kind, 0.0) - ka.get(kind, 0.0)) * k for kind in set(ka) | set(kb)}
    return out


def add_spec(a, b, k=1.0):
    out = {bone: dict(v) for bone, v in a.items()}
    for bone, kinds in b.items():
        d = out.setdefault(bone, {})
        for kind, deg in kinds.items():
            d[kind] = d.get(kind, 0.0) + deg * k
    return out


def root(base, drop=0.0, lean=0.0, roll=0.0, back=0.0):
    """Lowered by `drop`, leant forward by `lean` (back if negative) and rolled to his right by `roll` about the hips."""
    hips = base["hips"].translation
    m = cc.about(hips, cc.rot(cc.RIGHT, -lean) @ cc.rot(cc.F, roll))
    return Matrix.Translation(Vector((0.0, back, -drop))) @ m


def crouch(a, spread=8.0):
    """Both legs bent by `a` with the feet staying flat under the hips; returns (spec, drop)."""
    spec = {}
    for side in "LR":
        spec["thigh." + side] = {"f": a, "s": spread}
        spec["shin." + side] = {"f": -2.0 * a}
        spec["foot." + side] = {"f": a}
    return spec, .86 * (1.0 - math.cos(math.radians(a)))


def base_at(arm, name, t):
    act = bpy.data.actions[name]
    ad = arm.animation_data
    ad.action = act
    if len(act.slots) and ad.action_slot is None:
        ad.action_slot = act.slots[0]
    f0, f1 = act.frame_range
    f = f0 + (t * FPS) % max(f1 - f0, 1.0)
    bpy.context.scene.frame_set(int(f), subframe=f - int(f))
    bpy.context.view_layer.update()
    return {pb.name: pb.matrix.copy() for pb in arm.pose.bones}


def graft(arm, base, idle, chain):
    """`chain` as it hangs in the idle pose, carried by its parent as it is in `base`."""
    for bone in chain:
        pb = arm.pose.bones.get(bone)
        if pb is None or pb.parent is None:
            continue
        parent = pb.parent.name
        base[bone] = base[parent] @ idle[parent].inverted() @ idle[bone]
    return base


def build(arm, name, length_s, sample, step=1):
    """`sample(t)` -> (base, spec, root matrix fn(base)); keyed every `step` frames, the last frame on the end."""
    frames = int(round(length_s * FPS))
    poses = []
    for f in range(0, frames + 1, step):
        poses.append((f, sample(f / FPS)))
    if poses[-1][0] != frames:
        poses.append((frames, sample(frames / FPS)))
    ad = arm.animation_data
    ad.action = None
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    ad.action = act
    for f, (base, spec, rootfn) in poses:
        cc.pose_at(arm, base, turns(spec), rootfn(base))
        cc.key_all(arm, f)
    print("CLIP", name, frames)
    return act


# ---------------------------------------------------------------- the poses

def sit_spec(t):
    b = math.sin(t / 2.0 * math.tau)
    tw = math.sin(min(max((t - 3.6) / .5, 0.0), 1.0) * math.pi)
    lean = 16.0
    spec = {
        # (Leant back by `lean`, a thigh's flexion here is its angle from hanging less the lean. The left knee up,
        # the foot on the ground under it; the right leg out ahead, the heel down.)
        "thigh.L": {"f": 115.0 - lean, "s": 10.0},
        "shin.L": {"f": -85.0},
        "foot.L": {"f": -22.0},
        "thigh.R": {"f": 92.0 - lean, "s": 16.0, "t": -10.0},
        "shin.R": {"f": -22.0},
        "foot.R": {"f": -30.0},
        "shoulder.R": {"s": -8.0},
        "upper_arm.R": {"f": -22.0, "s": 25.0},
        "forearm.R": {"f": 18.0},
        "hand.R": {"f": -12.0},
        "upper_arm.L": {"f": 44.0, "s": 6.0},
        "forearm.L": {"f": 52.0},
        "hand.L": {"f": 15.0},
        "spine": {"f": -6.0 + 1.2 * b},
        "chest": {"f": -10.0 + 2.4 * b},
        "neck": {"f": -28.0 + 12.0 * tw},
        "head": {"f": -22.0 + 20.0 * tw, "t": 14.0 * tw},
    }
    return spec, dict(drop=.98 - .14, lean=-lean)


def stand_spec(t=0.0):
    b = math.sin(t / 1.5 * math.tau)
    spec, drop = crouch(11.0, 9.0)
    spec.update({
        "spine": {"f": -5.0 + .8 * b},
        "chest": {"f": -8.0 + 2.2 * b, "r": 3.0},
        "neck": {"f": 9.0},
        "head": {"f": 5.0},
        "shoulder.R": {"s": -6.0},
        "upper_arm.R": {"f": 20.0, "s": 12.0},
        "forearm.R": {"f": 16.0},
        "upper_arm.L": {"f": 16.0, "s": 9.0},
        "forearm.L": {"f": 24.0},
        "hand.L": {"f": 10.0},
    })
    return spec, dict(drop=drop, lean=0.0)


def mix_pose(a, b, k):
    sa, ra = a
    sb, rb = b
    r = {key: ra.get(key, 0.0) + (rb.get(key, 0.0) - ra.get(key, 0.0)) * k for key in set(ra) | set(rb)}
    return lerp_spec(sa, sb, k), r


def keyed(keys, t):
    """Between the poses keyed at times (eased)."""
    for i in range(len(keys) - 1):
        t0, p0 = keys[i]
        t1, p1 = keys[i + 1]
        if t <= t1:
            return mix_pose(p0, p1, cc.smooth((t - t0) / max(t1 - t0, 1e-4)))
    return keys[-1][1]


def make_all(arm):
    idle = base_at(arm, "idle", 0.0)
    made = []

    def still(fn):
        return lambda t: (idle, fn(t)[0], lambda base, r=fn(t)[1]: root(base, **r))

    made.append(build(arm, "heavy_sit", 6.0, still(sit_spec), step=2))

    def rise(t):
        k = cc.smooth(t / 2.0)
        p = math.sin(k * math.pi)
        spec, r = mix_pose(sit_spec(0.0), stand_spec(0.0), k)
        spec = add_spec(spec, {"chest": {"f": -26.0}, "spine": {"f": -12.0}, "upper_arm.R": {"f": -18.0},
                               "forearm.R": {"f": 30.0}, "thigh.L": {"f": 22.0}, "thigh.R": {"f": 22.0},
                               "neck": {"f": 18.0}}, p)
        r = dict(r)
        r["lean"] = r.get("lean", 0.0) + 22.0 * p
        return spec, r

    made.append(build(arm, "heavy_rise", 2.0, still(rise)))
    made.append(build(arm, "heavy_idle", 3.0, still(stand_spec), step=2))

    # The walk: the town's hurt walk, slowed, his weight over the heavy side.
    walk_len = 1.25
    src_len = (bpy.data.actions["walk_hurt"].frame_range[1] - bpy.data.actions["walk_hurt"].frame_range[0]) / FPS

    def walk(t):
        base = base_at(arm, "walk_hurt", t / walk_len * src_len)
        graft(arm, base, idle, R_CHAIN)
        ph = math.sin(t / walk_len * math.tau)
        spec = {
            "spine": {"f": -6.0, "r": 3.0},
            "chest": {"f": -8.0, "r": 6.0},
            "neck": {"f": 10.0, "r": -4.0},
            "head": {"f": 4.0, "r": -4.0},
            "shoulder.R": {"s": -9.0},
            "upper_arm.R": {"f": 16.0 + 13.0 * ph, "s": 13.0},
            "forearm.R": {"f": 14.0 + 6.0 * max(0.0, ph)},
        }
        return base, spec, lambda b: root(b)

    made.append(build(arm, "heavy_walk", walk_len, walk))

    def wind(t):
        tr = math.sin(t * math.tau * 9.0) * 1.3 + math.sin(t * math.tau * 13.0) * .8
        b = math.sin(t * math.tau)
        spec, drop = crouch(36.0, 10.0)
        spec["thigh.R"] = {"f": 16.0, "s": 12.0}
        spec["shin.R"] = {"f": -46.0}
        spec["foot.R"] = {"f": 30.0}
        spec["thigh.L"] = {"f": 52.0, "s": 8.0}
        spec["shin.L"] = {"f": -84.0}
        lean = 40.0
        spec.update({
            "spine": {"f": -lean * .45, "t": 8.0},
            "chest": {"f": -lean * .55 + 3.0 * b, "t": 12.0 + tr},
            "neck": {"f": 24.0, "t": -10.0},
            "head": {"f": 16.0 + tr * .4, "t": -10.0},
            "shoulder.R": {"s": -10.0},
            "upper_arm.R": {"f": -12.0 + tr * 1.5, "s": 30.0},
            "forearm.R": {"f": 82.0},
            "hand.R": {"f": -20.0},
            "upper_arm.L": {"f": 82.0, "s": 14.0},
            "forearm.L": {"f": 38.0},
            "hand.L": {"f": -10.0},
        })
        return idle, spec, lambda base: root(base, drop=drop)

    made.append(build(arm, "heavy_wind", 1.0, wind))

    run_len = .6
    src_run = (bpy.data.actions["run"].frame_range[1] - bpy.data.actions["run"].frame_range[0]) / FPS

    def charge(t):
        base = base_at(arm, "run", t / run_len * src_run)
        graft(arm, base, idle, R_CHAIN)
        lean = 30.0
        bob = math.sin(t / run_len * math.tau * 2.0)
        spec = {
            "spine": {"f": -lean * .45},
            "chest": {"f": -lean * .55, "t": 10.0},
            "neck": {"f": 20.0, "t": -6.0},
            "head": {"f": 12.0, "t": -4.0},
            "shoulder.R": {"s": -6.0},
            "upper_arm.R": {"f": 64.0 + 4.0 * bob, "s": 14.0, "t": -10.0},
            "forearm.R": {"f": 30.0},
            "hand.R": {"f": -15.0},
        }
        return base, spec, lambda b: root(b)

    made.append(build(arm, "heavy_charge", run_len, charge))

    def dig_spec(t):
        tug = math.sin(t / .6 * math.tau)
        spec, drop = crouch(55.0, 16.0)
        lean = 50.0
        spec.update({
            "spine": {"f": -lean * .5},
            "chest": {"f": -lean * .5, "t": 6.0 * tug},
            "neck": {"f": 26.0},
            "head": {"f": 8.0},
            "shoulder.R": {"s": -12.0},
            "upper_arm.R": {"f": 72.0 + 4.0 * tug, "s": 10.0},
            "forearm.R": {"f": 14.0 + 8.0 * tug},
            "hand.R": {"f": -26.0 + 10.0 * tug},
            "upper_arm.L": {"f": 68.0, "s": 16.0},
            "forearm.L": {"f": 42.0},
        })
        return spec, dict(drop=drop, lean=0.0)

    made.append(build(arm, "heavy_dig", 1.2, still(dig_spec)))

    def overhead():
        spec, drop = crouch(16.0, 12.0)
        spec["thigh.L"] = {"f": 34.0, "s": 10.0}
        spec["shin.L"] = {"f": -30.0}
        spec.update({
            "spine": {"f": 6.0},
            "chest": {"f": 12.0, "t": 16.0},
            "neck": {"f": -6.0},
            "head": {"f": -4.0},
            "shoulder.R": {"s": 14.0},
            "upper_arm.R": {"f": 172.0, "s": 14.0},
            "forearm.R": {"f": 78.0},
            "hand.R": {"f": -20.0},
            "upper_arm.L": {"f": 70.0, "s": 20.0},
            "forearm.L": {"f": 20.0},
        })
        return spec, dict(drop=drop, lean=-8.0)

    def release():
        spec, drop = crouch(22.0, 12.0)
        spec["thigh.L"] = {"f": 48.0, "s": 8.0}
        spec["shin.L"] = {"f": -36.0}
        spec["thigh.R"] = {"f": -6.0, "s": 12.0}
        spec["shin.R"] = {"f": -30.0}
        spec.update({
            "spine": {"f": -16.0},
            "chest": {"f": -22.0, "t": -14.0},
            "neck": {"f": 26.0},
            "head": {"f": 12.0},
            "upper_arm.R": {"f": 96.0, "s": 8.0},
            "forearm.R": {"f": 6.0},
            "hand.R": {"f": 10.0},
            "upper_arm.L": {"f": -10.0, "s": 24.0},
            "forearm.L": {"f": 30.0},
        })
        return spec, dict(drop=drop, lean=8.0)

    throw_keys = [(0.0, dig_spec(0.0)), (.4, overhead()), (THROW_RELEASE + .1, release()), (.8, release()), (1.2, stand_spec(0.0))]
    made.append(build(arm, "heavy_throw", 1.2, still(lambda t: keyed(throw_keys, t))))

    def inhale(t):
        b = .5 - .5 * math.cos(t / 1.2 * math.tau)
        tr = math.sin(t * math.tau * 11.0) * .7
        spec, drop = crouch(12.0, 15.0)
        spec.update({
            "spine": {"f": 5.0 + 3.0 * b},
            "chest": {"f": 10.0 + 7.0 * b + tr},
            "neck": {"f": 14.0 + 8.0 * b},
            "head": {"f": 10.0 + 7.0 * b},
            "shoulder.R": {"s": 6.0 + 6.0 * b},
            "shoulder.L": {"s": 6.0 + 6.0 * b},
            "upper_arm.R": {"f": -16.0, "s": 32.0 + 8.0 * b},
            "forearm.R": {"f": 30.0},
            "upper_arm.L": {"f": -20.0, "s": 36.0 + 8.0 * b},
            "forearm.L": {"f": 40.0},
            "hand.L": {"f": 20.0},
        })
        return spec, dict(drop=drop, lean=-(4.0 + 6.0 * b))

    made.append(build(arm, "heavy_inhale", 1.2, still(inhale)))

    def daze(t):
        sway = math.sin(t / 1.8 * math.tau)
        lol = math.sin(t / 1.8 * math.tau + 1.2)
        spec, drop = crouch(15.0, 10.0)
        spec.update({
            "spine": {"f": -10.0, "r": 4.0 * sway},
            "chest": {"f": -12.0, "r": 5.0 * sway},
            "neck": {"f": -12.0, "r": 8.0 * lol},
            "head": {"f": -10.0, "r": 10.0 * lol},
            "upper_arm.R": {"f": 22.0, "s": 4.0},
            "forearm.R": {"f": 6.0},
            "upper_arm.L": {"f": 118.0, "s": 32.0},
            "forearm.L": {"f": 122.0},
            "hand.L": {"f": -30.0},
        })
        return spec, dict(drop=drop, lean=0.0, roll=3.0 * sway)

    made.append(build(arm, "heavy_daze", 1.8, still(daze)))
    return made


def preview(arm, made, out):
    """Frames of each clip on the town body (the shapes of the poses; the game shows them on Heavy-arm)."""
    import build_human as bh
    cam = bh.setup_render((300, 380))
    ad = arm.animation_data
    for act in made:
        ad.action = act
        if len(act.slots) and ad.action_slot is None:
            ad.action_slot = act.slots[0]
        f0, f1 = act.frame_range
        for k, t in enumerate((0.0, .35, .6, .85)):
            bpy.context.scene.frame_set(int(f0 + (f1 - f0) * t))
            bh.shoot(cam, os.path.join(out, "clip_%s_%d.png" % (act.name, k)), (-2.4, -3.6, 1.2), (0.0, 0.0, .8), lens=40)
