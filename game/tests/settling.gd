extends SceneTree
## The REAL room. Phase A (gate): props start asleep at their authored pose and
## stay put through 3 s of play: asleep, drift < 3 mm, no jitter.
## Phase B (report + no-explosion gate): every movable prop is woken at once;
## all must be asleep again within 3 s and none may move > 10 cm. Props whose
## authored pose is not physically resting are listed as offenders.

const PET_NAMES := ["pet_enclosure", "fish_bowl", "Aquarium"]

func _initialize() -> void:
	call_deferred("_run")

func _is_pet(body: Node) -> bool:
	for word in PET_NAMES:
		if word in str(body.name):
			return true
	return false

func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main._play()
	main.player.playing = false
	await physics_frame
	var bodies: Array[InteriorObject] = []
	var start := {}
	for body in get_nodes_in_group("movable"):
		var object := body as InteriorObject
		if object == null or object.freeze or _is_pet(object):
			continue
		bodies.append(object)
		start[object] = object.global_transform
	var awake_late: Array[String] = []
	var worst_a := 0.0
	var offenders_a: Array[Dictionary] = []
	for frame in 180:
		await physics_frame
	for body in bodies:
		var drift: float = body.global_position.distance_to(start[body].origin)
		worst_a = maxf(worst_a, drift)
		if not body.sleeping:
			awake_late.append(str(body.name))
		if drift > 0.003:
			offenders_a.append({"object": str(body.name), "drift_mm": snappedf(drift * 1000.0, 0.1)})
	# Phase B.
	for body in bodies:
		start[body] = body.global_transform
		body.activate()
	var asleep_at := {}
	for frame in 300:
		await physics_frame
		for body in bodies:
			if body.sleeping and not asleep_at.has(body):
				asleep_at[body] = frame / 60.0
			elif not body.sleeping:
				asleep_at.erase(body)
	var offenders_b: Array[Dictionary] = []
	var worst_b := 0.0
	var latest_sleep := 0.0
	var within_3mm := 0
	for body in bodies:
		var drift: float = body.global_position.distance_to(start[body].origin)
		var slept: float = asleep_at.get(body, 99.0)
		worst_b = maxf(worst_b, drift)
		latest_sleep = maxf(latest_sleep, slept)
		if drift <= 0.003:
			within_3mm += 1
		else:
			offenders_b.append({"object": str(body.name), "drift_mm": snappedf(drift * 1000.0, 0.1), "asleep_at_s": slept})
	var passed_a := offenders_a.is_empty() and awake_late.is_empty() and bodies.size() > 20
	var passed_b := worst_b < 0.10 and latest_sleep <= 3.0
	print("INTERIOR_SETTLING ", JSON.stringify({"passed": passed_a and passed_b, "bodies": bodies.size(),
		"start_state": {"passed": passed_a, "worst_drift_mm": snappedf(worst_a * 1000.0, 0.01), "awake_after_3s": awake_late, "offenders": offenders_a},
		"wake_all": {"passed": passed_b, "worst_drift_mm": snappedf(worst_b * 1000.0, 0.1), "latest_sleep_s": latest_sleep, "within_3mm": within_3mm, "offenders": offenders_b}}))
	quit(0 if passed_a and passed_b else 1)
