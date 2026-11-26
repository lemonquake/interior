extends SceneTree
## 0.18 canal warren and physical chairs: a real player walks the hidden route from the far bank through
## the fence, along both tunnels (crouching under the cave-in), through the three rooms and the courtyard
## and out again; the warren's doors, knocks, radio, switch and pump work; chairs everywhere collide.
##   Godot --headless --fixed-fps 60 --path game --script res://tests/warren_integration.gd
const W := preload("res://scripts/canal_warren.gd")
var main: Node
var player: InteriorPlayer
var failures: Array[String] = []
var checks := 0
var lowest := 99.0
var route_log: Array = []

func _initialize() -> void: _run.call_deferred()

func frames(n: int) -> void:
	for i in n: await physics_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func walk(target: Vector3, budget := 1800) -> bool:
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
		lowest = minf(lowest, player.global_position.y)
		if i % 60 == 59:
			stuck = stuck + 1 if player.global_position.distance_to(last) < .15 else 0
			last = player.global_position
			if stuck >= 3: break
	player.touch_move = Vector2.ZERO
	return false

func leg(target: Vector3, label: String) -> bool:
	var ok := await walk(target)
	route_log.append({"leg": label, "reached": ok, "at": str(player.global_position)})
	check(ok, "Walk " + label + " to " + str(target) + ", stopped at " + str(player.global_position))
	return ok

## Along a boardwalk at offset d from the estero, in short legs that follow its curve.
func follow(d: float, z0: float, z1: float, label: String) -> bool:
	var steps := maxi(1, int(ceil(absf(z1 - z0) / 2.5)))
	for i in steps:
		var z := lerpf(z0, z1, float(i + 1) / steps)
		if not await leg(W.pos(d, 0, z), label + " z%.1f" % z): return false
	return true

func nearest(group: String, p: Vector3) -> Node3D:
	var best: Node3D = null
	for node: Node3D in get_nodes_in_group(group):
		if best == null or node.global_position.distance_to(p) < best.global_position.distance_to(p):
			best = node
	return best

func open_door(p: Vector3, label: String) -> bool:
	var door := nearest("warren_doors", p)
	check(door != null and door.global_position.distance_to(p) < 1.5, label + " exists near " + str(p))
	if door == null: return false
	if not door.is_open(): door.toggle()
	await frames(75)
	check(door.is_open(), label + " opens")
	return door.is_open()

func _run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await frames(12)
	player = main.player
	main.get_node("Stranger").process_mode = Node.PROCESS_MODE_DISABLED
	var town := get_first_node_in_group("neighbourhood")
	var warren: Node3D = town.find_child("Canal warren", true, false)
	check(warren != null, "Warren installed")
	var counts: Dictionary = warren.stats
	print("WARREN_COUNTS ", counts)
	check(counts.houses >= 25, "Shanty rows (%d)" % counts.houses)
	check(counts.locked >= 8, "Locked doors to knock on (%d)" % counts.locked)
	check(counts.doors == 8, "Six room doors and two fence sheets (%d)" % counts.doors)
	check(warren.lights.size() == 4, "Only four lamps in the whole warren (%d)" % warren.lights.size())
	check(counts.props >= 30, "Loose props (%d)" % counts.props)
	# Every monobloc chair in the town became a physical chair.
	var chairs := get_nodes_in_group("movable").filter(func(b: Node) -> bool: return b.get_meta("loose_prop", "") == "chair")
	print("WARREN_CHAIRS ", chairs.size())
	check(chairs.size() >= 15, "Physical chairs in the neighbourhood (%d)" % chairs.size())
	var stray := 0
	for node in town.find_children("*", "Node3D", true, false):
		if InteriorLooseProps.CHAIR_MODEL in node.scene_file_path and not node.get_parent() is InteriorObject: stray += 1
	check(stray == 0, "No chair left without collision (%d)" % stray)
	for chair: InteriorObject in chairs:
		var shapes := chair.get_children().filter(func(c: Node) -> bool: return c is CollisionShape3D)
		if shapes.size() != 8:
			check(false, "Chair %s has the fitted collider" % chair.name)
			break
	# The estero lies below the walks.
	var space := player.get_world_3d().direct_space_state
	var down := func(p: Vector3) -> float:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.5, p + Vector3.DOWN * 8, 2))
		return float(hit.position.y) if hit else -99.0
	check(down.call(W.pos(0, W.DECK + .5, 20)) < W.EW - .3, "Estero bed below its water")
	check(absf(down.call(W.pos(-1.7, W.DECK + .5, 12)) - W.DECK) < .04, "West boardwalk deck height")
	check(absf(down.call(W.pos(1.7, W.DECK + .5, -6)) - W.DECK) < .04, "East boardwalk deck height")
	# The route on foot.
	const C := preload("res://scripts/canal_settlement.gd")
	player.reset_motion(C.at(-7.1, C.path_y(W.ENTRY_Z) + .1, W.ENTRY_Z))
	await frames(20)
	var ok := await leg(W.at(-19.0, 0, W.ENTRY_Z), "up the far-bank slope on the litter trail")
	ok = ok and await leg(W.at(-27.4, 0, W.ENTRY_Z), "far bank to the fence")
	ok = ok and await open_door(W.at(-28.5, W.FLOOR, W.ENTRY_Z + .48), "Entry tin sheet")
	ok = ok and await leg(W.at(-31.0, 0, W.ENTRY_Z), "through the fence")
	lowest = 99.0  # from here on the walks are inside the warren
	ok = ok and await leg(W.pos(1.6, 0, W.ENTRY_Z), "down the alley")
	ok = ok and await follow(1.6, W.ENTRY_Z, W.SAG.y + .8, "east tunnel")
	if ok:
		# Standing, the cave-in stops you; crouched you get under.
		var before := player.global_position
		await walk(W.pos(1.6, 0, W.SAG.x - 1.0), 200)
		check(player.global_position.z > W.SAG.y - .2, "Cave-in blocks a standing player (at %s)" % str(player.global_position))
		player.touch_crouching = true
		await frames(30)
		ok = await leg(W.pos(1.6, 0, W.SAG.x - 1.0), "crouching under the cave-in")
		player.touch_crouching = false
		await frames(40)
		check(not player.crouching, "Stands up again past the cave-in")
	ok = ok and await follow(1.6, W.SAG.x - 1.0, W.B1_Z, "east tunnel south")
	ok = ok and await leg(W.pos(-1.75, 0, W.B1_Z), "across the plank bridge")
	for room: Array in W.ROOMS:
		ok = ok and await follow(-1.72, W.B1_Z if room[0] == "family" else W.ROOMS[W.ROOMS.find(room) - 1][2] + .7, room[1] - .7, "west tunnel")
		ok = ok and await open_door(W.pos(-1.26, W.DECK, room[1]), "%s room south door" % room[0])
		ok = ok and await leg(W.pos(-1.72, 0, room[2] - .7), "through the %s room" % room[0])
		ok = ok and await open_door(W.pos(-1.26, W.DECK, room[2]), "%s room north door" % room[0])
		ok = ok and await leg(W.pos(-1.72, 0, room[2] + .7), "out of the %s room" % room[0])
	ok = ok and await follow(-1.72, W.ROOMS[2][2] + .7, W.B2_Z, "west tunnel north")
	ok = ok and await leg(W.pos(1.6, 0, W.B2_Z), "across the second bridge")
	ok = ok and await leg(W.pos(1.6, 0, W.EXIT_Z), "to the exit alley")
	ok = ok and await leg(W.at(-30.0, 0, W.EXIT_Z), "up the exit alley")
	ok = ok and await open_door(W.at(-28.5, W.FLOOR, W.EXIT_Z + .48), "Exit tin sheet")
	ok = ok and await leg(W.at(-25.0, 0, W.EXIT_Z), "out to the far bank")
	check(lowest > W.DECK - .4, "Never fell into the estero (lowest %.2f)" % lowest)
	# Rails keep you out of the water.
	player.reset_motion(W.pos(-1.7, W.DECK + .05, 14.0))
	await frames(10)
	await walk(W.pos(1.5, 0, 14.0), 200)
	check(player.global_position.y > W.DECK - .2, "Rail holds on the west walk")
	check(InteriorSurfaces.under(player) == "wood", "Wood footsteps on the boardwalk (%s)" % InteriorSurfaces.under(player))
	# A chair is solid: walking into it shoves it, you never pass through.
	var chair: InteriorObject = null
	for c: InteriorObject in chairs:
		if warren.get_parent().is_ancestor_of(c) and c.global_position.distance_to(W.pos(-4.6, W.FLOOR, W.YARD.x + 4.0)) < .8: chair = c
	check(chair != null, "Yard chair is physical")
	if chair != null:
		await frames(60)
		var start := chair.global_position
		player.reset_motion(start + W.along(start.z).z * 1.5 + Vector3(0, .1, 0))
		await frames(10)
		var through := false
		for i in 90:
			var d := chair.global_position - player.global_position
			d.y = 0
			player.rotation = Vector3(0, atan2(-d.x, -d.z), 0)
			player.touch_move = Vector2(0, -1)
			await physics_frame
			# Passing through = getting beyond the chair's start while the chair has not moved at all.
			var ahead := (player.global_position - start).dot(-W.along(start.z).z)
			through = through or (ahead > .3 and chair.global_position.distance_to(start) < .05)
		player.touch_move = Vector2.ZERO
		print("CHAIR_PUSH start ", start, " chair ", chair.global_position, " player ", player.global_position, " sleeping ", chair.sleeping, " freeze ", chair.freeze)
		check(not through, "Player never walks through the chair")
		check(chair.global_position.distance_to(start) > .15, "Walking into the chair shoves it (%.2f m)" % chair.global_position.distance_to(start))
	# Knock on a warren door: the town's knock gesture and a warren remark.
	var door := nearest("warren_locked", W.pos(-2.45, W.DECK, 12.0))
	check(door != null and door.controller != null, "Warren doors use the knock controller")
	if door != null and door.controller != null:
		var n := door.global_basis.z
		player.reset_motion(door.global_position + n * .62 + Vector3.DOWN * (door.global_position.y - W.DECK - .03))
		player.rotation = Vector3(0, atan2(n.x, n.z), 0)
		player.camera.rotation = Vector3.ZERO
		await frames(15)
		door.toggle()
		check(door.uses == 1, "Knock starts on a warren door")
		await frames(160)
		var story: InteriorStory = get_first_node_in_group("story")
		check(story != null and story.ui.dialogue_active(), "A remark follows the knock")
	# Radio, light switch and pump.
	var radio: Node3D = warren.radio
	radio.toggle()
	await frames(5)
	check(radio.on and radio._voice.playing, "Radio plays")
	await frames(30)
	radio.toggle()
	check(not radio.on, "Radio switches off")
	warren.light_switch.toggle()
	warren._process(.1)
	var tube: OmniLight3D = warren.lights[0].light
	check(warren.lights[0].kind == "tube" and tube.light_energy == 0.0, "Switch turns the tube light off")
	await frames(30)
	warren.light_switch.toggle()
	warren._process(.1)
	check(tube.light_energy > 0.0 or fmod(warren.elapsed, 13.0) > 9.5, "Switch turns it back on")
	var pump: Node3D = warren.pump
	pump.toggle()
	for i in 20:
		await process_frame
	check(absf(pump._handle.rotation.z) > .05, "Pump handle strokes")
	var report := {"checks": checks, "failures": failures, "route": route_log, "counts": counts, "chairs": chairs.size()}
	print("WARREN_RESULT ", JSON.stringify(report))
	print("%d/%d passed" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
