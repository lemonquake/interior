extends SceneTree
## Real imported-asset checks: source clip duration, loop continuity, planted feet
## and playback matched to path movement. No full-world scene is needed.

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var model := load("res://assets/characters/stranger.glb").instantiate() as Node3D
	root.add_child(model)
	await process_frame
	var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var skeleton: Skeleton3D
	for node in model.find_children("*", "Skeleton3D", true, false):
		skeleton = node as Skeleton3D
	check(anim != null and skeleton != null, "The imported character has an animation player and skeleton")
	if anim == null or skeleton == null:
		_finish({})
		return
	var run := anim.get_animation("run")
	check(absf(run.length - 19.0 / 30.0) < .0001, "Run uses the downloaded 19-frame Running cycle")
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	anim.play("run")
	var poses: Array = []
	for frame in 20:
		anim.seek(float(frame) / 30.0, true)
		skeleton.force_update_all_bone_transforms()
		var pose := {}
		for side in ["L", "R"]:
			for part in ["toe", "foot", "shin", "thigh", "forearm", "hand"]:
				var bone_name: String = part + "." + side
				pose[bone_name] = skeleton.get_bone_global_pose(skeleton.find_bone(bone_name))
		poses.append(pose)
	var seam := 0.0
	for bone in poses[0]:
		seam = maxf(seam, poses[0][bone].origin.distance_to(poses[-1][bone].origin))
	check(seam < .001, "The authored loop closes without a limb-position jump")
	var slide := 0.0
	var ground_height := 0.0
	for side in ["L", "R"]:
		var start := 6 if side == "L" else 16
		for frame in range(start, start + 3):
			var current: Vector3 = poses[frame]["toe." + side].origin
			var next: Vector3 = poses[frame + 1]["toe." + side].origin
			var planted_velocity := (next.z - current.z) * 30.0 + InteriorStranger.RUN_CLIP_SPEED
			slide = maxf(slide, absf(planted_velocity))
			ground_height = maxf(ground_height, absf(current.y - .05))
	check(slide < .6, "Foot contact travel matches the movement speed (residual %.3f m/s)" % slide)
	check(ground_height < .03, "Stance toes stay at shoe height above the floor")
	var swing_height := 0.0
	for pose in poses:
		swing_height = maxf(swing_height, maxf(pose["foot.L"].origin.y, pose["foot.R"].origin.y))
	check(swing_height > .5, "The downloaded running leg recovery is retained")
	_finish({"duration": run.length, "loop_seam_m": seam, "stance_sliding_mps": slide,
			"stance_height_error_m": ground_height, "foot_recovery_m": swing_height})

func _finish(results: Dictionary) -> void:
	print("INTERIOR_STRANGER_RUN ", JSON.stringify({"passed": failures.is_empty(), "checks": checks,
			"failures": failures, "results": results}))
	quit(0 if failures.is_empty() else 1)
