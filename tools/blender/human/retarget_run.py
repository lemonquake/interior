"""Retarget the owner's downloaded Running clip, preserving its authored timing/poses.

Blender CLI: blender -b --factory-startup --python tools/blender/human/retarget_run.py
Only the run animation is replaced in stranger.glb; its mesh/material/other clip bytes
are retained. build_human.py also uses this retarget when rebuilding the character.
"""
import hashlib
import json
import os
import struct

import bpy
from mathutils import Matrix, Quaternion, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SOURCE = os.path.join(ROOT, "models", "generic_body_animation", "animation_run.glb")
TARGET = os.path.join(ROOT, "game", "assets", "characters", "stranger.glb")
WORK = os.path.join(ROOT, "work", "run-fix")
FPS = 30
BONES = {
    "hips": "Hips", "spine": "Spine02", "chest": "Spine", "neck": "neck", "head": "Head",
    **{f"{dst}.{side}": f"{src_side}{src}" for side, src_side in [("L", "Left"), ("R", "Right")]
       for dst, src in [("shoulder", "Shoulder"), ("upper_arm", "Arm"), ("forearm", "ForeArm"),
                        ("hand", "Hand"), ("thigh", "UpLeg"), ("shin", "Leg"),
                        ("foot", "Foot"), ("toe", "ToeBase")]},
}


def retarget_run(arm):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=SOURCE)
    imported = set(bpy.data.objects) - before
    source = next(o for o in imported if o.type == "ARMATURE")
    original = source.animation_data.action
    first, last = (int(round(v)) for v in original.frame_range)
    # The rigs share forward (-Y) and up (+Z), but their bone rolls and rest
    # poses differ. Transfer armature-space deltas, never raw quaternion keys.
    correction = {dst: source.data.bones[src].matrix_local.to_quaternion().inverted()
                  @ arm.data.bones[dst].matrix_local.to_quaternion() for dst, src in BONES.items()}
    source_leg = sum(source.data.bones[n].length for n in ["LeftUpLeg", "LeftLeg"])
    target_leg = sum(arm.data.bones[n].length for n in ["thigh.L", "shin.L"])
    proportion = target_leg / source_leg
    rest_hips = source.data.bones["Hips"].head_local.copy()
    old = bpy.data.actions.get("run")
    if old:
        bpy.data.actions.remove(old)
    action = bpy.data.actions.new("run")
    action.use_fake_user = True
    arm.animation_data_create().action = action
    for track in list(arm.animation_data.nla_tracks):
        arm.animation_data.nla_tracks.remove(track)
    feet = []
    previous_rotations = {}
    for frame in range(first, last + 1):
        bpy.context.scene.frame_set(frame)
        matrices = {}
        for bone in arm.data.bones:
            pb = arm.pose.bones[bone.name]
            rest_local = bone.parent.matrix_local.inverted() @ bone.matrix_local if bone.parent else bone.matrix_local
            parent = matrices[bone.parent.name] if bone.parent else Matrix.Identity(4)
            base = parent @ rest_local
            pb.rotation_mode = "QUATERNION"
            pb.location = (0, 0, 0)
            pb.scale = (1, 1, 1)
            if bone.name in BONES:
                desired = source.pose.bones[BONES[bone.name]].matrix.to_quaternion() @ correction[bone.name]
                pb.rotation_quaternion = base.to_quaternion().inverted() @ desired
            else:
                pb.rotation_quaternion = Quaternion()
            rotation = pb.rotation_quaternion.copy()
            if bone.name in previous_rotations:
                rotation.make_compatible(previous_rotations[bone.name])
            pb.rotation_quaternion = rotation
            previous_rotations[bone.name] = rotation.copy()
            if bone.name == "hips":
                delta = (source.pose.bones["Hips"].head - rest_hips) * proportion
                pb.location = base.to_3x3().inverted() @ delta
            matrices[bone.name] = base @ pb.matrix_basis
            for channel in ("location", "rotation_quaternion", "scale"):
                pb.keyframe_insert(channel, frame=frame - first, group=bone.name)
        bpy.context.view_layer.update()
        feet.append({side: tuple(arm.pose.bones[f"toe.{side}"].head) for side in ("L", "R")})
    # Export samples linearly; no procedural limb swing, gait replacement, or
    # invented bounce is layered over the downloaded animation.
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:
                        key.interpolation = "LINEAR"
    facts = {"source": os.path.relpath(SOURCE, ROOT).replace(os.sep, "/"),
             "sha256": hashlib.sha256(open(SOURCE, "rb").read()).hexdigest(),
             "source_clip": original.name, "length": (last - first) / FPS,
             "frames": last - first + 1, "leg_scale": proportion, "toe_positions": feet}
    for obj in imported:
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.actions.remove(original)
    return action, facts


def read_glb(path):
    raw = open(path, "rb").read()
    json_size = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20:20 + json_size])
    binary_at = 20 + json_size
    binary_size = struct.unpack_from("<I", raw, binary_at)[0]
    return doc, raw[binary_at + 8:binary_at + 8 + binary_size]


def replace_animation(target_path, donor_path, facts):
    """Append only donor animation accessors/buffer bytes; retain the target's assets."""
    doc, binary = read_glb(target_path)
    donor, donor_binary = read_glb(donor_path)
    clip = next(a for a in donor["animations"] if a["name"] == "run")
    names = {n["name"]: i for i, n in enumerate(doc["nodes"]) if "name" in n}
    accessors = {}
    views = {}
    data = bytearray(binary)
    for sampler in clip["samplers"]:
        for field in ("input", "output"):
            old_id = sampler[field]
            if old_id not in accessors:
                accessor = dict(donor["accessors"][old_id])
                old_view = accessor["bufferView"]
                if old_view not in views:
                    view = dict(donor["bufferViews"][old_view])
                    data.extend(b"\0" * (-len(data) % 4))
                    start = view.get("byteOffset", 0)
                    data.extend(donor_binary[start:start + view["byteLength"]])
                    view["byteOffset"] = len(data) - view["byteLength"]
                    view["buffer"] = 0
                    views[old_view] = len(doc["bufferViews"])
                    doc["bufferViews"].append(view)
                accessor["bufferView"] = views[old_view]
                accessors[old_id] = len(doc["accessors"])
                doc["accessors"].append(accessor)
            sampler[field] = accessors[old_id]
    for channel in clip["channels"]:
        channel["target"]["node"] = names[donor["nodes"][channel["target"]["node"]]["name"]]
    clip["extras"] = {k: v for k, v in facts.items() if k != "toe_positions"}
    doc["animations"] = [clip if a["name"] == "run" else a for a in doc["animations"]]
    doc["buffers"][0]["byteLength"] = len(data)
    encoded = json.dumps(doc, separators=(",", ":")).encode()
    encoded += b" " * (-len(encoded) % 4)
    data.extend(b"\0" * (-len(data) % 4))
    with open(target_path, "wb") as out:
        out.write(struct.pack("<III", 0x46546C67, 2, 28 + len(encoded) + len(data)))
        out.write(struct.pack("<II", len(encoded), 0x4E4F534A) + encoded)
        out.write(struct.pack("<II", len(data), 0x004E4942) + data)


def main():
    os.makedirs(WORK, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    bpy.ops.import_scene.gltf(filepath=TARGET)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    action, facts = retarget_run(arm)
    for old in list(bpy.data.actions):
        if old != action:
            bpy.data.actions.remove(old)
    for obj in bpy.context.scene.objects:
        obj.select_set(obj == arm)
    donor = os.path.join(WORK, "run-retarget.glb")
    bpy.ops.export_scene.gltf(filepath=donor, export_format="GLB", use_selection=True,
                              export_animations=True, export_animation_mode="ACTIONS",
                              export_force_sampling=True, export_def_bones=False)
    replace_animation(TARGET, donor, facts)
    with open(os.path.join(WORK, "run-retarget.json"), "w") as out:
        json.dump(facts, out, indent=2)
    print("RETARGET_RUN", {k: v for k, v in facts.items() if k != "toe_positions"})


if __name__ == "__main__":
    main()
