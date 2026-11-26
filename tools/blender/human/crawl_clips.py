"""0.43: the prone clips for the shared character library (build_zombies.py puts them in zombie_anims.glb).

  crawl      a downed survivor dragging themself along on their elbows: face down, chest up, head up to see ahead,
             the arms reaching and pulling in turn, the legs trailing with a weak push. 1.6 s, loops, in place.
  down_idle  lying face down where they fell, propped on one forearm, breathing hard. 3.2 s, loops.

Built in armature space on top of the library's own idle pose, so the rig's bone rolls never matter: every bone
is turned about its own head by a rotation given in the body's axes (the figure faces -Y, up is +Z, its left is
+X), each child carried by its parent's turn. The whole body is then laid face down about the hips.
"""
import math

import bpy
from mathutils import Matrix, Vector

FPS = 30
F = Vector((0.0, -1.0, 0.0))        # where the body faces
UP = Vector((0.0, 0.0, 1.0))
RIGHT = Vector((-1.0, 0.0, 0.0))    # the body's right
LEFT = -RIGHT
LYING = 0.15                        # hips this high off the ground, face down
BACK = 0.5                          # the body lies this far behind the figure's origin, so the head is near it


def rot(axis, deg):
    return Matrix.Rotation(math.radians(deg), 4, axis)


def about(point, m):
    return Matrix.Translation(point) @ m @ Matrix.Translation(-point)


def flex(deg):
    """Turns a limb that hangs down toward the front (shoulder flexion, hip flexion, elbow flexion)."""
    return rot(RIGHT, deg)


def side_out(side, deg):
    """Turns a hanging limb out to its own side (abduction): about the facing axis, the sign by side."""
    return rot(F, deg if side == "L" else -deg)


def twist(deg):
    """About the long axis of the standing body (the spine)."""
    return rot(UP, deg)


def smooth(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3.0 - 2.0 * x)


def depth_order(arm):
    def depth(b):
        n = 0
        while b.parent is not None:
            b = b.parent
            n += 1
        return n
    return sorted(arm.pose.bones, key=lambda pb: depth(pb.bone))


def base_pose(arm, act_name="idle"):
    act = bpy.data.actions[act_name]
    ad = arm.animation_data
    ad.action = act
    if len(act.slots) and ad.action_slot is None:
        ad.action_slot = act.slots[0]
    bpy.context.scene.frame_set(int(act.frame_range[0]))
    bpy.context.view_layer.update()
    return {pb.name: pb.matrix.copy() for pb in arm.pose.bones}


def pose_at(arm, base, turns, root):
    """Sets the pose: `turns[bone]` (4x4 rotation in body axes) about each bone's head, `root` laid over all."""
    carried = {}
    for pb in depth_order(arm):
        parent = carried.get(pb.parent.name) if pb.parent is not None else root
        head = base[pb.name].translation
        t = parent @ about(head, turns.get(pb.name, Matrix.Identity(4)))
        carried[pb.name] = t
        pb.rotation_mode = "QUATERNION"
        pb.matrix = t @ base[pb.name]
        bpy.context.view_layer.update()


def key_all(arm, frame):
    for pb in arm.pose.bones:
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        pb.keyframe_insert("location", frame=frame)


def prone_root(base, surge, roll):
    """Face down about the hips, lowered to the ground, a little forward with each pull, rocking with the arms."""
    hips = base["hips"].translation
    lay = rot(RIGHT, -90.0)              # up turns to face forward: the chest goes to the ground
    drop = Vector((0.0, 0.0, LYING - hips.z)) - F * (BACK - surge)
    return Matrix.Translation(drop) @ about(hips, lay @ rot(UP, roll))


def crawl_turns(p):
    """The crawl at phase p (0..1). Each arm: a reach forward along the ground, then a pull back under the chest."""
    turns = {}

    def arm(side, phase):
        # (Every shoulder angle here is 23 less than on flat ground: the arched chest has already turned the arms
        # that way.)
        # Shoulder flexion 140 with the elbow at 40 lays the forearm flat ahead on the ground (the reach); 80 / 110
        # puts the elbow under the shoulder with the forearm forward (the end of the pull, propped up).
        q = phase % 1.0
        if q < 0.35:                          # reach: the forearm slides forward, lifting a little off the ground
            k = smooth(q / 0.35)
            shoulder, elbow = 57.0 + 60.0 * k, 110.0 - 70.0 * k + math.sin(k * math.pi) * 18.0
        else:                                 # planted: pulled back under the chest
            k = smooth((q - 0.35) / 0.65)
            shoulder, elbow = 117.0 - 60.0 * k, 40.0 + 70.0 * k
        turns["upper_arm." + side] = flex(shoulder) @ side_out(side, 30.0)
        turns["forearm." + side] = flex(elbow)
        turns["hand." + side] = flex(-8.0)

    arm("L", p)
    arm("R", p + 0.5)
    sway = math.sin(p * math.tau)
    pull = abs(math.sin(p * math.tau))
    # Chest up off the ground, head up to see where it is going.
    # (flex() turns toward the front: the back arches with negative... the spine's "front" is the ground here, so
    # raising the chest is a turn toward the back, a positive flex for a bone that points up.)
    turns["spine"] = flex(9.0 + 3.0 * pull) @ twist(4.0 * sway)
    turns["chest"] = flex(12.0 + 4.0 * pull) @ twist(7.0 * sway)
    turns["neck"] = flex(24.0)
    turns["head"] = flex(30.0) @ twist(-5.0 * sway)
    # The legs drag; now and then one knee comes up a little and pushes.
    for side, phase in (("L", p), ("R", p + 0.5)):
        push = max(0.0, math.sin((phase % 1.0) * math.tau))
        turns["thigh." + side] = side_out(side, 10.0 + 9.0 * push) @ flex(6.0 * push)
        turns["shin." + side] = flex(-(6.0 + 16.0 * push))
        turns["foot." + side] = flex(-62.0)
    return turns, 0.06 * pull, 5.0 * sway


def down_turns(t):
    """Lying where they fell: propped on the right forearm, the left arm out ahead, breathing hard."""
    breath = math.sin(t / 1.6 * math.tau)
    turns = {
        "upper_arm.R": flex(66.0) @ side_out("R", 32.0),
        "forearm.R": flex(108.0),
        "upper_arm.L": flex(122.0) @ side_out("L", 30.0),
        "forearm.L": flex(42.0),
        "hand.L": flex(-15.0),
        "spine": flex(6.0 + 1.5 * breath) @ twist(6.0),
        "chest": flex(10.0 + 2.5 * breath) @ twist(9.0),
        "neck": flex(16.0) @ twist(-6.0),
        "head": flex(20.0 - 2.0 * breath) @ twist(-10.0),
        "thigh.L": side_out("L", 14.0) @ flex(10.0),
        "shin.L": flex(-22.0),
        "thigh.R": side_out("R", 8.0),
        "shin.R": flex(-10.0),
        "foot.L": flex(-60.0),
        "foot.R": flex(-62.0),
    }
    return turns, 0.0, 2.0 + breath * 0.6


def build(arm, name, length_s, turns_at):
    base = base_pose(arm)
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data.action = act
    frames = int(round(length_s * FPS))
    for f in range(frames + 1):
        t = f / FPS
        turns, surge, roll = turns_at((f % frames) / frames if name == "crawl" else t)
        pose_at(arm, base, turns, prone_root(base, surge, roll))
        key_all(arm, f)
    return act


def make_crawl(arm):
    return build(arm, "crawl", 1.6, crawl_turns)


def make_down_idle(arm):
    return build(arm, "down_idle", 3.2, down_turns)


# 0.44: Jonna in the mart's back office: sat on the floor against the wall, legs out, the right hand pressed
# to the wound in her left side, the left arm on her thigh, head back against the wall, breathing hard; now and
# then she lifts her head to look at whoever is talking to her.
SIT_HIPS = 0.13                     # hips this high off the floor


def sit_root(base, lean):
    hips = base["hips"].translation
    back = rot(RIGHT, lean)          # leaned back against the wall
    drop = Vector((0.0, 0.0, SIT_HIPS - hips.z))
    return Matrix.Translation(drop) @ about(hips, back)


def sit_turns(t):
    breath = math.sin(t / 1.6 * math.tau)
    look = smooth(min(1.0, max(0.0, (math.sin(t / 4.8 * math.tau) + .2) * 1.6)))
    lean = 14.0
    turns = {
        # Legs out ahead, a little apart, the left knee raised (her weight on the right hip, away from the wound).
        "thigh.L": flex(80.0 - lean + 18.0) @ side_out("L", 9.0),
        "shin.L": flex(-46.0),
        "thigh.R": flex(84.0 - lean) @ side_out("R", 12.0) @ twist(-8.0),
        "shin.R": flex(-12.0),
        "foot.L": flex(-18.0),
        "foot.R": flex(-28.0),
        # The right hand across to the left side of her belly, pressing: the arm hangs, turned in, the elbow bent
        # so the forearm lies across her.
        "upper_arm.R": flex(14.0) @ twist(58.0),
        "forearm.R": flex(96.0),
        "hand.R": flex(-6.0),
        # The left forearm rests on the raised knee.
        "upper_arm.L": flex(38.0) @ twist(-12.0),
        "forearm.L": flex(34.0),
        "hand.L": flex(20.0),
        "spine": flex(4.0 + 1.2 * breath) @ twist(-5.0),
        "chest": flex(6.0 + 2.6 * breath) @ twist(-4.0),
        "neck": flex(-6.0 + 14.0 * look),
        "head": flex(-10.0 + 16.0 * look - 1.5 * breath) @ twist(12.0 * (1.0 - look)) @ side_out("L", 8.0 * (1.0 - look)),
    }
    return turns, lean


def make_sit_hurt(arm):
    base = base_pose(arm)
    act = bpy.data.actions.new("sit_hurt")
    act.use_fake_user = True
    arm.animation_data.action = act
    frames = int(round(9.6 * FPS))
    for f in range(0, frames + 1, 2):
        turns, lean = sit_turns(f / FPS)
        pose_at(arm, base, turns, sit_root(base, lean))
        key_all(arm, f)
    return act
