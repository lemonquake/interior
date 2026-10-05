extends SceneTree
## Contract 8.11: 80 awake bodies in a walled pen; reports physics frame time.

const Common = preload("res://tests/physics_common.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	Common.floor_slab(world)
	for side in [Vector3(2.1, 0.5, 0), Vector3(-2.1, 0.5, 0)]:
		Common.static_box(world, side, Vector3(0.2, 1.0, 4.4))
	for side in [Vector3(0, 0.5, 2.1), Vector3(0, 0.5, -2.1)]:
		Common.static_box(world, side, Vector3(4.4, 1.0, 0.2))
	var bodies: Array[InteriorObject] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 80:
		var position := Vector3(rng.randf_range(-1.6, 1.6), 0.3 + i * 0.06, rng.randf_range(-1.6, 1.6))
		match i % 3:
			0: bodies.append(Common.ball(world, 0.08, 0.4, position))
			1: bodies.append(Common.block(world, Vector3(0.18, 0.12, 0.25), 0.8, position))
			_: bodies.append(Common.prop(world, [{"kind": "cylinder", "center": [0, 0, 0], "radius": 0.06, "height": 0.2}], 0.5, "metal", position))
	# Headless script runs do not fill the Performance physics monitor, so the
	# whole wall-clock frame (physics + scripts + overhead) is timed: an upper
	# bound on the physics step.
	var samples: Array[float] = []
	var awake_min := 999
	var last := Time.get_ticks_usec()
	for frame in 300:
		await physics_frame
		var now := Time.get_ticks_usec()
		var frame_ms := (now - last) / 1000.0
		last = now
		if frame % 40 == 0:
			for body in bodies:
				body.apply_central_impulse(Vector3(rng.randf_range(-1, 1), 1.0, rng.randf_range(-1, 1)) * body.mass)
		if frame >= 30:
			samples.append(frame_ms)
			awake_min = mini(awake_min, bodies.filter(func(b): return not b.sleeping).size())
	samples.sort()
	var mean := 0.0
	for s in samples:
		mean += s
	mean /= samples.size()
	var p95: float = samples[int(samples.size() * 0.95)]
	var passed := mean <= 2.5 and awake_min >= 60
	print("INTERIOR_PHYSICS_PERF ", JSON.stringify({"passed": passed, "bodies": bodies.size(), "min_awake": awake_min, "frame_ms_mean_upper_bound": snappedf(mean, 0.001), "frame_ms_p95": snappedf(p95, 0.001), "frame_ms_max": snappedf(samples[-1], 0.001), "cpu": OS.get_processor_name()}))
	quit(0 if passed else 1)
