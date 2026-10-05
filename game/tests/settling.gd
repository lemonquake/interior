extends SceneTree
## The REAL room: every movable prop is woken at its authored pose and must fall
## asleep again within 3 s with < 3 mm drift and no residual jitter.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main._play()
	main.player.playing = false
	for i in 3:
		await physics_frame
	var bodies: Array[InteriorObject] = []
	var start := {}
	var initially_asleep := 0
	for body in get_nodes_in_group("movable"):
		var object := body as InteriorObject
		if object == null or object.freeze:
			continue
		if object.sleeping:
			initially_asleep += 1
		bodies.append(object)
		start[object] = object.global_transform
		object.activate()
	var asleep_at := {}
	var late_speed := {}
	for frame in 360:
		await physics_frame
		for body in bodies:
			if body.sleeping and not asleep_at.has(body):
				asleep_at[body] = frame / 60.0
			elif not body.sleeping:
				asleep_at.erase(body)
			if frame >= 300:
				late_speed[body] = maxf(late_speed.get(body, 0.0), body.linear_velocity.length() + body.angular_velocity.length() * 0.1)
	var failures: Array[Dictionary] = []
	var worst_drift := 0.0
	var latest_sleep := 0.0
	for body in bodies:
		var drift: float = body.global_position.distance_to(start[body].origin)
		var tilt: float = rad_to_deg(start[body].basis.orthonormalized().get_rotation_quaternion().angle_to(body.global_basis.orthonormalized().get_rotation_quaternion()))
		var slept: float = asleep_at.get(body, 99.0)
		worst_drift = maxf(worst_drift, drift)
		latest_sleep = maxf(latest_sleep, slept)
		if drift > 0.003 or tilt > 1.0 or slept > 3.0 or late_speed.get(body, 0.0) > 0.01:
			failures.append({"object": str(body.name), "drift_mm": snappedf(drift * 1000.0, 0.1), "tilt_deg": snappedf(tilt, 0.01), "asleep_at_s": slept, "late_speed": late_speed.get(body, 0.0), "home": str(start[body].origin), "now": str(body.global_position)})
	var passed := failures.is_empty() and bodies.size() > 20
	print("INTERIOR_SETTLING ", JSON.stringify({"passed": passed, "bodies": bodies.size(), "initially_asleep": initially_asleep, "worst_drift_mm": snappedf(worst_drift * 1000.0, 0.01), "latest_sleep_s": latest_sleep, "failures": failures, "seconds": 6}))
	quit(0 if passed else 1)
