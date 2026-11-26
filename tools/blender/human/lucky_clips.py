"""0.68: Doctor Lucky's own clips, on the 1x town rig (build_lucky.py `clips` exports them to lucky_anims.glb; the
game plays them on his 1.12x skeleton with Skeleton3D.motion_scale, his long arms on longer bones).

  lucky_idle    2.4 s loop  hunched low on bent legs, the long arms hanging forward with the claws near the floor,
                            the head up and cocked, jerking now and then
  lucky_run     0.66 s loop the town's run thrown forward, the arms trailing back and out, claws behind him
  lucky_wind    0.8 s loop  the leap coming: down on his haunches, arms back and out, head up at the target, trembling
  lucky_leap    0.6 s loop  in the air: stretched out forward, the claws reaching ahead, the legs tucked behind
  lucky_land    0.55 s      down out of the leap onto one claw and both feet, up into the hunch
  lucky_swipe   0.9 s       the right claw down across from high behind, then the left
  lucky_scream  2.2 s       up out of the hunch, chest out, arms flung wide, head thrown back (the jaw hangs open)
  lucky_spider  1.2 s loop  face down, splayed like a spider, the limbs reaching and pulling in turn (on a wall the
                            game lays the figure's up along the wall's normal)
  lucky_cling   2.0 s loop  the same splay, still, breathing, the head lifting and turning
  lucky_hit     0.45 s      a round in him: the head and chest snapped back, the arms flinching in

Turns as in heavyarm_clips.py (crawl_clips.pose_at): "f" flexion, "s" out to the bone's side, "t" about the body's
long axis, "r" a roll toward the body's right.
"""
import math

import bpy

import crawl_clips as cc
import heavyarm_clips as hc

FPS = 30
BASES = ["idle", "run"]
ARMS = ["shoulder.L", "upper_arm.L", "forearm.L", "hand.L", "shoulder.R", "upper_arm.R", "forearm.R", "hand.R",
        "weapon.R", "weapon.L"]


def hunch(t=0.0, twitch=True):
    b = math.sin(t / 2.4 * math.tau)
    spec, drop = hc.crouch(34.0, 14.0)
    jerk = 0.0
    if twitch:
        q = (t * 1.7) % 1.0
        jerk = math.sin(q * math.pi) ** 8 * (1.0 if int(t * 1.7) % 2 == 0 else -1.0)
    spec.update({
        "spine": {"f": -20.0 + 1.5 * b},
        "chest": {"f": -18.0 + 3.0 * b},
        "neck": {"f": 30.0, "t": 6.0 * jerk},
        "head": {"f": 14.0, "r": 18.0 * jerk + 8.0, "t": 10.0 * jerk},
        "shoulder.L": {"f": 8.0},
        "shoulder.R": {"f": 8.0},
        "upper_arm.L": {"f": 34.0 + 3.0 * b, "s": 24.0},
        "upper_arm.R": {"f": 30.0 - 3.0 * b, "s": 26.0},
        "forearm.L": {"f": 22.0},
        "forearm.R": {"f": 28.0},
        "hand.L": {"f": -12.0},
        "hand.R": {"f": -12.0},
    })
    return spec, dict(drop=drop, lean=16.0)


def wind(t=0.0):
    shake = math.sin(t * 61.0) * 1.6
    spec, drop = hc.crouch(68.0, 20.0)
    spec.update({
        "spine": {"f": -16.0},
        "chest": {"f": -14.0 + shake},
        "neck": {"f": 38.0},
        "head": {"f": 16.0 + shake},
        "upper_arm.L": {"f": -34.0, "s": 44.0 + shake},
        "upper_arm.R": {"f": -34.0, "s": 44.0 - shake},
        "forearm.L": {"f": 46.0},
        "forearm.R": {"f": 46.0},
        "hand.L": {"f": -20.0},
        "hand.R": {"f": -20.0},
    })
    return spec, dict(drop=drop, lean=34.0)


def leap(t=0.0):
    w = math.sin(t / 0.6 * math.tau)
    spec = {
        "thigh.L": {"f": -18.0 + 4.0 * w, "s": 10.0},
        "thigh.R": {"f": -14.0 - 4.0 * w, "s": 10.0},
        "shin.L": {"f": -62.0},
        "shin.R": {"f": -55.0},
        "foot.L": {"f": -30.0},
        "foot.R": {"f": -30.0},
        "spine": {"f": -4.0},
        "chest": {"f": -6.0},
        "neck": {"f": 26.0},
        "head": {"f": 12.0},
        "upper_arm.L": {"f": 150.0 + 3.0 * w, "s": 22.0},
        "upper_arm.R": {"f": 146.0 - 3.0 * w, "s": 22.0},
        "forearm.L": {"f": 14.0},
        "forearm.R": {"f": 18.0},
        "hand.L": {"f": -16.0},
        "hand.R": {"f": -16.0},
    }
    return spec, dict(drop=0.0, lean=38.0)


def swipe_r_high():
    spec, r = hunch(0.0, False)
    spec = dict(spec)
    spec["upper_arm.R"] = {"f": 158.0, "s": 52.0, "t": -20.0}
    spec["forearm.R"] = {"f": 48.0}
    spec["chest"] = {"f": -10.0, "t": 18.0}
    return spec, dict(r, lean=10.0)


def swipe_r_low():
    spec, r = hunch(0.0, False)
    spec = dict(spec)
    spec["upper_arm.R"] = {"f": 42.0, "s": -24.0, "t": 30.0}
    spec["forearm.R"] = {"f": 12.0}
    spec["upper_arm.L"] = {"f": 150.0, "s": 50.0, "t": 20.0}
    spec["forearm.L"] = {"f": 46.0}
    spec["chest"] = {"f": -26.0, "t": -22.0}
    return spec, dict(r, lean=30.0)


def swipe_l_low():
    spec, r = hunch(0.0, False)
    spec = dict(spec)
    spec["upper_arm.L"] = {"f": 40.0, "s": -26.0, "t": -30.0}
    spec["forearm.L"] = {"f": 12.0}
    spec["upper_arm.R"] = {"f": 20.0, "s": 30.0}
    spec["chest"] = {"f": -28.0, "t": 20.0}
    return spec, dict(r, lean=32.0)


def scream_up(t=0.0):
    shake = math.sin(t * 47.0) * 2.0
    spec, drop = hc.crouch(14.0, 12.0)
    spec.update({
        "spine": {"f": 8.0},
        "chest": {"f": 16.0 + shake},
        "neck": {"f": 26.0},
        "head": {"f": 26.0 + shake},
        "upper_arm.L": {"f": 30.0, "s": 84.0 + shake},
        "upper_arm.R": {"f": 30.0, "s": 84.0 - shake},
        "forearm.L": {"f": 34.0},
        "forearm.R": {"f": 34.0},
        "hand.L": {"f": -24.0},
        "hand.R": {"f": -24.0},
    })
    return spec, dict(drop=drop, lean=-6.0)


def spider_turns(p, still=False):
    """Splayed face down: the crawl's arms reaching wider, the legs bent out like a frog's, pushing in turn."""
    turns = cc.crawl_turns(p if not still else 0.2)[0]
    for side, ph in (("L", 0.0), ("R", 0.5)):
        q = (p + ph) % 1.0
        push = 0.0 if still else math.sin(q * math.tau)
        turns["upper_arm." + side] = turns["upper_arm." + side] @ cc.side_out(side, 32.0)
        turns["thigh." + side] = cc.flex(48.0 + 18.0 * push) @ cc.side_out(side, 52.0)
        turns["shin." + side] = cc.flex(-88.0 + 14.0 * push)
        turns["foot." + side] = cc.flex(-20.0)
    turns["neck"] = cc.flex(-34.0)
    turns["head"] = cc.flex(-18.0) @ cc.twist(10.0 * math.sin(p * math.tau))
    return turns


def make_all(arm):
    idle = hc.base_at(arm, "idle", 0.0)
    made = []

    def still(fn):
        return lambda t: (idle, fn(t)[0], lambda base, r=fn(t)[1]: hc.root(base, **r))

    made.append(hc.build(arm, "lucky_idle", 2.4, still(hunch), step=2))

    run_len = 0.66
    act = bpy.data.actions["run"]
    src_len = (act.frame_range[1] - act.frame_range[0]) / FPS

    def run(t):
        base = hc.base_at(arm, "run", t / run_len * src_len)
        hc.graft(arm, base, idle, ARMS)
        ph = math.sin(t / run_len * math.tau)
        spec = {
            "spine": {"f": -12.0},
            "chest": {"f": -12.0, "t": 6.0 * ph},
            "neck": {"f": 30.0},
            "head": {"f": 10.0},
            "upper_arm.L": {"f": -38.0 + 10.0 * ph, "s": 34.0},
            "upper_arm.R": {"f": -38.0 - 10.0 * ph, "s": 34.0},
            "forearm.L": {"f": 26.0},
            "forearm.R": {"f": 26.0},
            "hand.L": {"f": -10.0},
            "hand.R": {"f": -10.0},
        }
        return base, spec, lambda b: hc.root(b, lean=24.0)

    made.append(hc.build(arm, "lucky_run", run_len, run))
    made.append(hc.build(arm, "lucky_wind", 0.8, still(wind)))
    made.append(hc.build(arm, "lucky_leap", 0.6, still(leap)))

    def land(t):
        keys = [(0.0, leap(0.0)), (0.12, wind(0.0)), (0.2, (dict(wind(0.0)[0], **{
            "upper_arm.R": {"f": 74.0, "s": 20.0}, "forearm.R": {"f": 8.0}}), dict(wind(0.0)[1], lean=46.0))),
            (0.55, hunch(0.0, False))]
        return hc.keyed(keys, t)

    made.append(hc.build(arm, "lucky_land", 0.55, still(land)))

    def swipe(t):
        keys = [(0.0, hunch(0.0, False)), (0.22, swipe_r_high()), (0.36, swipe_r_low()), (0.5, swipe_r_low()),
                (0.64, swipe_l_low()), (0.9, hunch(0.0, False))]
        return hc.keyed(keys, t)

    made.append(hc.build(arm, "lucky_swipe", 0.9, still(swipe)))

    def scream(t):
        keys = [(0.0, hunch(0.0, False)), (0.45, scream_up(t)), (1.7, scream_up(t)), (2.2, hunch(0.0, False))]
        return hc.keyed(keys, t)

    made.append(hc.build(arm, "lucky_scream", 2.2, still(scream)))

    def hit(t):
        back = hunch(0.0, False)
        spec, r = back
        snap = dict(spec)
        snap["chest"] = {"f": 6.0}
        snap["neck"] = {"f": 44.0}
        snap["head"] = {"f": 30.0, "r": -10.0}
        snap["upper_arm.L"] = {"f": 60.0, "s": 4.0}
        snap["upper_arm.R"] = {"f": 60.0, "s": 4.0}
        snap["forearm.L"] = {"f": 70.0}
        snap["forearm.R"] = {"f": 70.0}
        return hc.keyed([(0.0, back), (0.1, (snap, dict(r, lean=-4.0))), (0.45, back)], t)

    made.append(hc.build(arm, "lucky_hit", 0.45, still(hit)))

    # The splay: crawl_clips' prone frame, the turns its own.
    def spider_clip(name, length, still_pose):
        frames = int(round(length * FPS))
        ad = arm.animation_data
        ad.action = None
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        ad.action = act
        for f in range(0, frames + 1, 2):
            p = f / frames
            turns = spider_turns(p, still_pose)
            if still_pose:
                breathe = math.sin(p * math.tau)
                turns["chest"] = cc.flex(-4.0 * breathe)
                turns["head"] = cc.flex(-18.0 - 8.0 * breathe) @ cc.twist(25.0 * math.sin(p * math.tau * 2.0))
            surge = 0.0 if still_pose else 0.06 * math.sin(p * math.tau * 2.0)
            cc.pose_at(arm, idle, turns, cc.prone_root(idle, surge, 4.0 * math.sin(p * math.tau)))
            cc.key_all(arm, f)
        print("CLIP", name, frames)
        return act

    made.append(spider_clip("lucky_spider", 1.2, False))
    made.append(spider_clip("lucky_cling", 2.0, True))
    return made
