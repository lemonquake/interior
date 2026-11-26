extends SceneTree
## 0.22 Nichols basement: a real player steps in through the front door and looks at the blood trail (the first-sight
## lines), follows it round the grand stair into the nook under the landing, pushes the half-open cellar door, turns
## on the light at the switch beside it, goes down the stair, across the cellar, through the hole behind the dragged
## shelf, down the steps and along the tunnel to the chained iron door. Also: the ground slab cut out under the house,
## floor heights, physical props (settled, carried), the bulbs coming on and flickering, the refrigerator's light.
##   Godot --headless --fixed-fps 60 --path game --script res://tests/basement_integration.gd
const N := preload("res://scripts/nichols_property.gd")
const BF := -2.7
const CF := -3.6
var main: Node
var player: InteriorPlayer
var failures: Array[String] = []
var checks := 0
var step_counts := {}

func _initialize() -> void: _run.call_deferred()

func frames(n: int) -> void:
	for i in n: await physics_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
	print(("PASS " if ok else "FAIL ") + label)

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
		if player.global_position.y < -12:
			break
		if i % 60 == 59:
			stuck = stuck + 1 if player.global_position.distance_to(last) < .15 else 0
			last = player.global_position
			if stuck >= 3: break
	player.touch_move = Vector2.ZERO
	return false

func leg(target: Vector3, label: String) -> bool:
	var ok := await walk(target)
	check(ok, "Walk " + label + " (at " + str(player.global_position) + ")")
	return ok

func H(x: float, depth: float, up := 0.0) -> Vector3:
	return N.local(x, depth, up)

func _run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await frames(12)
	player = main.player
	main.get_node("Stranger").process_mode = Node.PROCESS_MODE_DISABLED
	player.stepped.connect(func(surface: String, _s: float): step_counts[surface] = int(step_counts.get(surface, 0)) + 1)
	var prop := get_first_node_in_group("nichols_property")
	var basement := get_first_node_in_group("nichols_basement")
	check(prop != null and basement != null, "Nichols property and its basement installed")
	if basement == null:
		_finish()
		return
	var stats: Dictionary = basement.stats
	print("BASEMENT ", stats)
	check(int(stats.bulbs) == 8 and int(stats.lights) == 7, "Eight bulbs, seven working (%d / %d)" % [stats.bulbs, stats.lights])
	check(int(stats.decals) >= 100, "Blood trail, pools and splatter decals (%d)" % stats.decals)
	check(int(stats.props) >= 40, "Cellar, tunnel and kitchen props (%d)" % stats.props)
	check(int(stats.ground_cut) >= 1 and int(stats.meshes_cut) >= 1, "Town ground slab and its mesh cut under the house")
	# No town ground box left inside the house's walls.
	var overlapping := 0
	var colliders := main.find_child("NeighbourhoodColliders", true, false)
	for c in colliders.get_children():
		if c is CollisionShape3D and not c.disabled and c.shape is BoxShape3D and str(c.name).begins_with("Ground"):
			var size: Vector3 = c.shape.size
			var r := Rect2(c.position.x - size.x * .5, c.position.z - size.z * .5, size.x, size.z)
			if r.intersects(Rect2(-24.6, -101.6, 25.2, 19.2)):
				overlapping += 1
	check(overlapping == 0, "No ground slab under the cellar (%d boxes)" % overlapping)
	var space := player.get_world_3d().direct_space_state
	var down := func(p: Vector3) -> float:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.2, p + Vector3.DOWN * 8, 2))
		return float(hit.position.y) if hit else -99.0
	var y0: float = N.HOUSE_POS.y
	check(absf(down.call(H(2.4, 10.2, .5)) - y0) < .05, "Landing behind the cellar door at the boards")
	check(absf(down.call(H(-3.4, 10.2, BF + 1.0)) - (y0 + BF)) < .05, "Stair foot on the shaft floor")
	check(absf(down.call(H(-6.0, 14.0, BF + 1.0)) - (y0 + BF)) < .05, "Cellar floor (%.2f), no old ground above it" % down.call(H(-6.0, 14.0, BF + 1.0)))
	check(absf(down.call(H(6.0, 16.9, CF + 1.0)) - (y0 + CF)) < .05, "Tunnel floor")
	check(absf(down.call(Vector3(-20, -2.0, -118)) - N.GROUND) < .3, "Ground behind the house unchanged")
	check(absf(down.call(H(-30.0, 6.0, 1.0) + Vector3(0, -1.2, 0)) - N.GROUND) < .3, "Ground beside the house unchanged")
	# Props: everything in the house is physical and settles where it was put.
	var props: Array = prop.props
	check(props.size() >= 110, "Physical props in the house, cellar, tunnel and kitchen (%d)" % props.size())
	var start := {}
	for b in props: start[b] = (b as Node3D).global_position
	await frames(240)
	var moved := 0
	for b in props:
		if is_instance_valid(b) and (b as Node3D).global_position.distance_to(start[b]) > .2:
			moved += 1
			print("  moved ", b.get_meta("nichols_prop"), " ", (b as Node3D).global_position.distance_to(start[b]))
	check(moved == 0, "Every prop settles in place (%d moved)" % moved)
	check(props.filter(func(b): return b.anchored).size() >= 6, "Frames and mirrors hang until grabbed")
	# Into the house: the trail is there; the first look at it.
	var story := get_first_node_in_group("story")
	check(story != null and not basement.saw_blood, "Nobody has seen the trail yet")
	# Stepping in backwards, facing the door: the trail is behind and nothing is said.
	player.reset_motion(H(-.2, .3, .05))
	player.rotation = Vector3(0, PI, 0)
	await frames(20)
	check(not basement.saw_blood, "Facing the door, the trail behind: no line yet")
	player.rotation = Vector3(0, atan2(-(H(.7, 3.0) - player.global_position).x, -(H(.7, 3.0) - player.global_position).z), 0)
	player.camera.rotation.x = -.55
	await frames(30)
	check(basement.saw_blood, "Looking down the foyer at the trail is seeing it")
	check(story != null and story.ui.dialogue_active() and story.ui.current_line() == "Shit..", "First line: \"Shit..\" (got \"%s\")" % (story.ui.current_line() if story else ""))
	if story != null:
		story.ui.advance()
		story.ui.advance()
		await frames(2)
		check(story.ui.current_line() == "I thought this place was empty decades ago?", "Second line (got \"%s\")" % story.ui.current_line())
		story.ui.advance()
		story.ui.advance()
	player.camera.rotation.x = 0.0
	# Follow it round the stair into the nook.
	for item in [[H(.6, 2.0), "into the foyer"], [H(1.9, 3.4), "round the stair foot"], [H(2.0, 6.0), "into the nook"], [H(1.95, 8.6), "to the cellar door"]]:
		if not await leg(item[0], item[1]): break
	var door: Node3D = basement.cellar_door
	check(door != null and door.is_in_group("nichols_doors"), "The cellar door is a Nichols door")
	var ajar := absf((door.get("_body") as Node3D).rotation.y)
	check(ajar > .6 and ajar < 1.1, "It stands half open (%.2f rad)" % ajar)
	check(str(door.call("prompt_text")).to_lower().contains("cellar door"), "Prompt: " + str(door.call("prompt_text")))
	door.call("toggle")
	await frames(120)
	var opened := absf((door.get("_body") as Node3D).rotation.y)
	check(opened > 1.4 or opened < .05, "Pushed, it swings (%.2f rad)" % opened)
	if opened < .05:
		door.call("toggle")
		await frames(120)
	# The switch beside it.
	var sw: Node = basement.switch_node
	check(sw.is_in_group("usables") and str(sw.call("prompt_text")) == "Turn on the light", "Switch: " + str(sw.call("prompt_text")))
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(H(1.95, 8.9, 1.55), (sw as Node3D).global_position, 6))
	check(hit and (hit.collider as Node).get_parent() == sw, "The switch can be aimed at from the nook")
	sw.call("toggle")
	await frames(150)
	var lit := 0
	for b in basement.bulbs:
		if (b.light as Light3D).visible and b.level > .5: lit += 1
	check(lit >= 5, "Bulbs on after the switch (%d of %d)" % [lit, basement.bulbs.size()])
	check(str(sw.call("prompt_text")) == "Turn off the light", "Switch now: " + str(sw.call("prompt_text")))
	# Down the stair.
	for item in [[H(2.15, 10.15), "through the cellar door to the landing"], [H(1.1, 10.2), "to the top step"], [H(-3.25, 10.2, BF), "down the cellar stair"]]:
		if not await leg(item[0], item[1]): break
	check(absf(player.global_position.y - (y0 + BF)) < .15, "At the foot of the stair (y %.2f)" % (player.global_position.y - y0))
	check(prop.is_below(player.camera.global_position), "Below the boards")
	# Across the cellar to the hole, down the steps, along the tunnel.
	for item in [[H(-3.35, 11.7, BF), "into the cellar"], [H(-3.0, 13.4, BF), "across the cellar"], [H(-1.9, 15.5, BF), "toward the dragged shelf"],
			[H(-.75, 16.85, BF), "to the hole"], [H(.4, 16.85, BF), "through the hole"], [H(1.8, 16.85, CF), "down the steps"],
			[H(4.6, 16.9, CF), "past the desk"], [H(6.4, 16.95, CF), "past the hanging bundle"], [H(8.2, 16.85, CF), "along the tunnel"], [H(11.5, 16.8, CF), "to the iron door"]]:
		if not await leg(item[0], item[1]): break
	check(absf(player.global_position.y - (y0 + CF)) < .15, "On the tunnel floor (y %.2f)" % (player.global_position.y - y0))
	var lock := main.find_child("Nichols iron door", true, false)
	check(lock != null and lock.is_in_group("usables"), "The iron door is usable")
	if lock != null and story != null:
		lock.call("toggle")
		await frames(4)
		check(story.ui.current_line() == "Chained shut.", "Iron door: \"%s\"" % story.ui.current_line())
	check(int(step_counts.get("concrete", 0)) > 10, "Concrete footsteps down there (%d)" % int(step_counts.get("concrete", 0)))
	# Pick something up: the crowbar by the hole.
	var crowbar: InteriorObject = null
	for b in props:
		if b.get_meta("nichols_prop") == "crowbar_01": crowbar = b
	check(crowbar != null and crowbar.grab_mode == "carry", "The crowbar is a carried prop")
	if story != null:
		while story.ui.dialogue_active():
			story.ui.advance()
			await frames(1)
	if crowbar != null:
		var stand := crowbar.global_position + Vector3(.9, 0, 0)
		player.reset_motion(Vector3(stand.x, y0 + BF + .02, stand.z))
		var to := crowbar.global_position - player.global_position
		player.rotation = Vector3(0, atan2(-to.x, -to.z), 0)
		await frames(6)
		# Look down at it, take it, then look up: it comes up with the view.
		var eye := player.camera.global_position
		player.camera.rotation.x = -atan2(eye.y - crowbar.global_position.y, Vector2(to.x, to.z).length())
		await frames(2)
		player.grab_object(crowbar)
		for i in 40:
			player.camera.rotation.x = lerpf(player.camera.rotation.x, -.15, .08)
			await physics_frame
		check(player.held == crowbar and crowbar.global_position.y > y0 + BF + .4, "Crowbar lifted (y %.2f)" % (crowbar.global_position.y - y0))
		player.release_object()
	# The failing bulbs flicker: over ten seconds at least one dips while on.
	var dipped := false
	for i in 600:
		await physics_frame
		for b in basement.bulbs:
			if b.flicker > .5 and b.level < .35:
				dipped = true
	check(dipped, "A failing bulb flickers")
	# Off again.
	sw.call("toggle")
	await frames(90)
	var still := 0
	for b in basement.bulbs:
		if (b.light as Light3D).visible: still += 1
	check(still == 0, "Switch off: dark again (%d still lit)" % still)
	# The kitchen: the refrigerator's bulb burns, on a new cable.
	var fridge := main.find_child("Refrigerator bulb", true, false) as Light3D
	check(fridge != null and fridge.visible and fridge.light_energy > .2, "The refrigerator's light is on")
	check(prop.layout.basement.has("jumper"), "The new cable and power strip (the jumper) are in the kitchen")
	_finish()

func _finish() -> void:
	print("BASEMENT_INTEGRATION %d/%d" % [checks - failures.size(), checks])
	for f in failures: print("  FAILED: ", f)
	quit(1 if failures.size() > 0 else 0)
