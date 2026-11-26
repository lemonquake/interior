# Hooded man's run

The hooded man's `run` comes from the owner's
`models/generic_body_animation/animation_run.glb`, animation `Running`.
The original source file is unchanged (SHA-256
`3572da3e97ae51bec8af7cc36cfde3802e4e713d5f2ee7d09991817df9d848eb`).

The downloaded rig and the clothed character use different bone names, rest
rotations, and limb lengths. `tools/blender/human/retarget_run.py` transfers the
authored armature-space rotations through their rest poses, scales the hip
translation for leg length, and collapses the source's extra spine segment.
It retains the source's 19-frame cycle at 30 fps, including hip motion, arm
swing, and leg recovery. It does not generate replacement limb motion.

Run the script with Blender to replace only the `run` clip in the existing
`game/assets/characters/stranger.glb`. All original mesh, texture, skin and
other animation data remain in the asset. `build_human.py` calls the same
retarget function during a full character rebuild.

The runtime uses 5.62 m/s as the clip's ground speed, measured from stance-foot
travel. Animation playback scales with actual movement speed. Footstep sounds
follow the animation clock, with contacts at frames 6 and 16; changing speed,
switching clips and pausing no longer let a separate footstep timer drift.

Verification:

```text
godot --headless --path game --script res://tests/stranger_run.gd
godot --headless --fixed-fps 60 --path game --script res://tests/stranger_integration.gd
```

The asset test checks the imported clip's duration, loop seam, stance-foot
height/travel and leg recovery. The full-scene test checks the pursuit,
path clearance, waiting, pause and arrival at the hut.
