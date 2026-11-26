extends SceneTree
## 0.17 canal settlement: a real player walks the whole loop from the house street, and every path,
## stair, bridge and recovery route is checked with the game's own movement and footstep resolver.
##   Godot --headless --fixed-fps 60 --path game --script res://tests/canal_integration.gd
const C := preload("res://scripts/canal_settlement.gd")
var main: Node
var player: InteriorPlayer
var failures: Array[String] = []
var checks := 0
var routes: Array = []
var step_counts := {}

func _initialize() -> void: _run.call_deferred()

func frames(n: int) -> void:
	for i in n: await physics_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func walk(target: Vector3, budget := 2400) -> bool:
	var stuck := 0
	var last := player.global_position
	for i in budget:
		var d := target - player.global_position
		d.y = 0
		if d.length() < .3:
			player.touch_move = Vector2.ZERO
			return true
		player.rotation = Vector3(0, atan2(-d.x, -d.z), 0)
		player.touch_move = Vector2(0, -1)
		await physics_frame
		if player.global_position.y < -8:
			break
		if i % 60 == 59:
			stuck = stuck + 1 if player.global_position.distance_to(last) < .15 else 0
			last = player.global_position
			if stuck >= 3: break
	player.touch_move = Vector2.ZERO
	return false

func leg(target: Vector3, label: String) -> bool:
	var ok := await walk(target)
	routes.append({"leg": label, "target": str(target), "reached": ok, "actual": str(player.global_position)})
	check(ok, "Walk " + label + " to " + str(target) + ", stopped at " + str(player.global_position))
	return ok

func _run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await frames(12)
	player = main.player
	main.get_node("Stranger").process_mode = Node.PROCESS_MODE_DISABLED
	player.stepped.connect(func(surface: String, _strength: float): step_counts[surface] = int(step_counts.get(surface, 0)) + 1)
	var town := get_first_node_in_group("neighbourhood")
	var canal := town.get_node("Canal settlement")
	check(canal != null, "Canal installed")
	var counts: Dictionary = canal.stats
	check(counts.river_houses >= 10, "Continuous river row (%d)" % counts.river_houses)
	check(counts.lane_houses >= 10, "Lane row (%d)" % counts.lane_houses)
	check(counts.rubbish >= 100, "Rubbish everywhere (%d)" % counts.rubbish)
	check(counts.decals >= 50, "Vandalism (%d)" % counts.decals)
	check(canal.bulbs.size() == 8, "Eight dying lights")
	# The ravine is open: the town's old street slab no longer covers it.
	var space := player.get_world_3d().direct_space_state
	var down := func(p: Vector3) -> float:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 12, p + Vector3.DOWN * 20, 2))
		return float(hit.position.y) if hit else -99.0
	check(down.call(C.at(0, 0, 20)) < C.WATER - .3, "River bed below the water")
	check(absf(down.call(C.at(4.6, 0, 30)) - C.CATWALK) < .05, "Catwalk deck height")
	check(absf(down.call(C.at(14.5, 0, 30)) - C.FLOOR) < .1, "Lane at bank top")
	# The whole loop on foot.
	player.reset_motion(Vector3(13.6, -2.83, 4.4))
	await frames(20)
	var route := [[Vector3(21, 0, 4.4), "town street"], [Vector3(22.3, 0, 18.4), "town corner past the cart"], [Vector3(-19, 0, 18.4), "street A between the cart and the stall"],
		[Vector3(-33, 0, 18.4), "old barricade gap"], [C.at(14.4, 0, 18), "entry ramp to the lane"], [C.at(14.4, 0, C.STAIR_Z), "lane"],
		[C.at(9.2, 0, C.STAIR_Z), "trench stair head"], [C.at(4.7, 0, C.STAIR_Z), "down the stair to the catwalk"],
		[C.at(4.7, 0, C.FOOT_Z), "catwalk south"], [C.at(-7.1, 0, C.FOOT_Z), "plank footbridge"],
		[C.at(-7.1, 0, 30.0), "far-bank path"], [C.at(-7.1, 0, 56.6), "path climbing to the bridge"],
		[C.at(-17.0, 0, 56.6), "far bank top"], [C.at(-17.0, 0, C.BRIDGE_Z), "bridge west approach"],
		[C.at(9.5, 0, C.BRIDGE_Z), "across the road bridge"], [C.at(9.5, 0, 56.5), "off the bridge"],
		[C.at(5.3, 0, 56.6), "stair landing"], [C.at(4.7, 0, 49.0), "down the catwalk stair"],
		[C.at(4.7, 0, 30.0), "catwalk north"], [C.at(4.7, 0, C.STAIR_Z), "catwalk to the stair foot"], [C.at(5.3, 0, C.STAIR_Z), "onto the stair"],
		[C.at(9.2, 0, C.STAIR_Z), "up the trench stair"], [C.at(14.4, 0, C.STAIR_Z), "back in the lane"],
		[C.at(14.4, 0, 18), "lane south"], [Vector3(-33, 0, 18.4), "out through the ramp"], [Vector3(-19, 0, 18.4), "back on street A"]]
	for item in route:
		if not await leg(item[0], item[1]): break
	# Footstep surfaces resolved by the runtime resolver at the real places.
	for spec in [[C.at(14.4, C.FLOOR + .05, 30), "dirt"], [C.at(4.6, C.CATWALK + .05, 30), "wood"],
		[C.at(-1.0, C.FLOOR + .05, C.BRIDGE_Z), "concrete"], [C.at(-7.1, C.path_y(20) + .05, 20), "dirt"],
		[C.at(-1.0, C.PATH + .7, C.FOOT_Z), "wood"], [C.at(7.5, C.stair_y(7.5) + .05, C.STAIR_Z), "concrete"]]:
		player.reset_motion(spec[0])
		await frames(25)
		check(InteriorSurfaces.under(player) == spec[1], "Footstep surface " + spec[1] + " at " + str(spec[0]) + " got " + InteriorSurfaces.under(player))
		check(player.is_on_floor(), "Supported at " + str(spec[0]))
	check(int(step_counts.get("dirt", 0)) > 20, "Dirt footsteps while walking")
	check(int(step_counts.get("wood", 0)) > 20, "Wood footsteps on the catwalk")
	check(int(step_counts.get("concrete", 0)) > 5, "Concrete footsteps on the bridge and stair")
	# The catwalk railing holds; a player who falls in the river can wade out up the far bank.
	player.reset_motion(C.at(4.6, C.CATWALK + .05, 12))
	await frames(10)
	await walk(C.at(1.0, 0, 12), 240)
	check(player.global_position.y > C.CATWALK - .2, "Railing keeps the player on the catwalk")
	player.reset_motion(C.at(0, C.BED + .2, 14))
	await frames(25)
	check(await walk(C.at(-7.1, 0, 14)), "Wade out of the river onto the far-bank path, at " + str(player.global_position))
	check(player.global_position.y > C.PATH - .3, "Back up on the path")
	# Lights move and fail.
	var pivot: Node3D = canal.bulbs[0].pivot
	var initial := pivot.rotation
	var lo := 10.0
	var hi := 0.0
	var lamp_off := false
	for i in 300:
		canal._process(.1)
		lo = minf(lo, canal.bulbs[0].light.light_energy)
		hi = maxf(hi, canal.bulbs[0].light.light_energy)
		for item: Dictionary in canal.bulbs:
			if item.kind == "lamp" and item.light.light_energy == 0.0: lamp_off = true
	check(pivot.rotation.distance_to(initial) > .001, "Bulb swings")
	check(hi - lo > .5, "Bulb flickers")
	check(lamp_off, "Bridge lamp dies for long stretches")
	player.reset_motion(Vector3(.6, .08, 1.3))
	await frames(300)
	check(not canal.is_visible_in_tree(), "Settlement hidden after returning inside the closed house")
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "routes": routes, "steps": step_counts, "counts": canal.stats}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../docs/canal-v17"))
	var file := FileAccess.open("res://../docs/canal-v17/integration.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("CANAL_INTEGRATION ", JSON.stringify({"passed": report.passed, "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
