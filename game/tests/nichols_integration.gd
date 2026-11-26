extends SceneTree
## 0.21 Nichols property: a real player walks from the courtyard gate down street B, (0.23) crouches through the secret
## crawl under the town wall, along the dirt path, through the open iron gate (the first-time line), round the fountain, up the porch
## steps, opens the front door, climbs the imperial stair to the galleries, crosses the bridge and enters the master
## bedroom. Also: footstep surfaces, the echo zone, a locked door, the balustrades, and the moon beams.
##   Godot --headless --fixed-fps 60 --path game --script res://tests/nichols_integration.gd
const N := preload("res://scripts/nichols_property.gd")
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
		if d.length() < .35:
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
	check(ok, "Walk " + label + " to " + str(target) + " (at " + str(player.global_position) + ")")
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
	check(prop != null, "Nichols property installed")
	var counts: Dictionary = prop.get_meta("counts", {})
	print("COUNTS ", counts)
	check(int(counts.get("doors", 0)) >= 9, "Front door leaves and interior doors (%d)" % counts.get("doors", 0))
	check(int(counts.get("models", 0)) >= 60, "Furniture, statues and trees placed (%d)" % counts.get("models", 0))
	check(int(counts.get("colliders", 0)) >= 250, "House collision (%d)" % counts.get("colliders", 0))
	await frames(6)
	check(prop.beams.size() >= 8, "Moonbeams through the north and west windows (%d)" % prop.beams.size())
	var space := player.get_world_3d().direct_space_state
	var down := func(p: Vector3) -> float:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.2, p + Vector3.DOWN * 6, 2))
		return float(hit.position.y) if hit else -99.0
	check(absf(down.call(H(2.0, 2.0, 1.0)) - N.HOUSE_POS.y) < .05, "Foyer floor height")
	check(absf(down.call(H(-8, 6, F1() + 1.0)) - (N.HOUSE_POS.y + 4.4)) < .05, "Upper floor height")
	check(absf(down.call(Vector3(-20, -2.0, -118)) - N.GROUND) < .3, "Ground behind the house")
	# The walk.
	player.reset_motion(Vector3(13.6, -2.83, 4.4))
	await frames(20)
	# 0.23: the town wall closes street B's south end; the way through is the secret crawl behind the leaned sheets.
	var sx := InteriorTownSiege.SECRET_X
	var sz := InteriorTownSiege.SOUTH_Z
	var route := [[Vector3(20.6, 0, 4.4), "out of the courtyard gate to street B"], [Vector3(20.6, 0, -14.0), "south down street B"],
		[Vector3(sx + 1.9, 0, sz + 2.6), "to the leaned sheets"], ["crouch"], [Vector3(sx + 1.25, 0, sz + .6), "into the lean-to"],
		[Vector3(sx, 0, sz + .55), "along the wall"], [Vector3(sx, 0, sz - 1.4), "out under the wall"], ["stand"],
		[Vector3(20.8, 0, -24.0), "past the old barricade"], [Vector3(20.2, 0, -33.0), "end of the asphalt"],
		[Vector3(17.0, 0, -40.5), "onto the dirt path"], [Vector3(10.0, 0, -47.0), "dirt path"], [Vector3(1.0, 0, -52.5), "dirt path toward the gate"],
		[Vector3(-6.5, 0, -57.0), "approach"], [Vector3(-12.0, 0, -58.8), "at the gate"], [Vector3(-12.0, 0, -63.0), "through the open gate"]]
	for item in route:
		if item[0] is String:
			player.touch_crouching = item[0] == "crouch"
			await frames(20)
			continue
		if not await leg(item[0], item[1]): break
	await frames(10)
	var story := get_first_node_in_group("story")
	check(story != null and story.ui.dialogue_active() and story.ui.current_line() == N.ENTRY_LINE,
		"First time through the gate: \"" + N.ENTRY_LINE + "\" (got " + (story.ui.current_line() if story else "no story") + ")")
	if story != null and story.ui.dialogue_active():
		story.ui.advance()
		story.ui.advance()
	for item in [[Vector3(-6.4, 0, -67.0), "round the fountain"], [Vector3(-7.0, 0, -73.5), "past the fountain"], [Vector3(-12.0, 0, -74.5), "to the steps"],
			[Vector3(-12.0, 0, -78.6), "up the porch steps"], [Vector3(-12.0, 0, -81.1), "across the porch to the door"]]:
		if not await leg(item[0], item[1]): break
	check(player.global_position.y > N.HOUSE_POS.y - .2, "Standing on the porch (y %.2f)" % player.global_position.y)
	# Push the front door open (both leaves) and walk in.
	var front: Array = []
	for d in get_nodes_in_group("nichols_doors"):
		if (d as Node3D).global_position.distance_to(H(0, -.45)) < 1.5:
			front.append(d)
	check(front.size() == 2, "Two front door leaves (%d)" % front.size())
	for d in front:
		# The left leaf stands ajar a hand's width: push both wide.
		if absf((d.get("_body") as Node3D).rotation.y) < 1.0: d.toggle()
	await frames(150)
	for d in front:
		check(absf((d.get("_body") as Node3D).rotation.y) > 1.4, "Front leaf swung wide (%.2f rad)" % absf((d.get("_body") as Node3D).rotation.y))
	for item in [[H(0, 1.5), "into the foyer"], [H(0, 3.6), "to the stair foot"]]:
		if not await leg(item[0], item[1]): break
	await frames(60)
	check(prop.is_inside(player.camera.global_position), "Inside the house")
	var audio := main.find_child("NightAudio", true, false)
	if audio == null:
		for n in main.find_children("*", "Node3D", true, false):
			if n is InteriorNightAudio: audio = n
	if audio != null and DisplayServer.get_name() != "headless":
		check(float(audio.get("_mansion")) > .8, "Echo zone active inside (%.2f)" % float(audio.get("_mansion")))
		var rev: AudioEffectReverb = audio.get("_reverb")
		if rev != null:
			check(rev.wet > .3, "Footsteps ring with a hall reverb (wet %.2f)" % rev.wet)
	check(InteriorSurfaces.under(player) == "tile", "Marble foyer footsteps (" + InteriorSurfaces.under(player) + ")")
	# Up the imperial stair: centre flight, landing, west return flight, gallery, bridge.
	for item in [[H(0, 7.9), "up the centre flight"], [H(-3.25, 8.3), "across the landing"], [H(-3.25, 3.4), "up the west return flight"],
			[H(-3.25, 1.8), "onto the gallery"], [H(0, 1.2), "onto the bridge over the door"], [H(-6.5, 1.3), "into the upstairs corridor"]]:
		if not await leg(item[0], item[1]): break
	check(player.global_position.y > N.HOUSE_POS.y + 4.2, "Upstairs (y %.2f)" % player.global_position.y)
	# The bridge balustrade holds over the stair hall.
	player.reset_motion(H(0, 1.6, 4.45))
	await frames(10)
	await walk(H(0, 5.0, 4.4), 200)
	check(player.global_position.y > N.HOUSE_POS.y + 4.2, "The bridge balustrade keeps the player upstairs")
	# Master bedroom: push the ajar door open, walk in.
	player.reset_motion(H(-8.5, 1.6, 4.45))
	await frames(10)
	for d in get_nodes_in_group("nichols_doors"):
		if str(d.name).contains("Bedroom"):
			d.toggle()
	await frames(120)
	check(await leg(H(-8.5, 4.0), "through the bedroom door"), "Into the master bedroom")
	# A locked door answers.
	var locks := get_nodes_in_group("nichols_locked")
	check(locks.size() >= 1, "A locked door in the hall")
	if story != null and story.ui.dialogue_active():
		story.ui.advance()
		story.ui.advance()
	if not locks.is_empty():
		locks[0].toggle()
		await frames(5)
		check(story != null and story.ui.dialogue_active() and story.ui.current_line().length() > 3, "Locked door: the player remarks on it")
	check(int(step_counts.get("wood", 0)) > 10, "Wooden floor footsteps (%d)" % int(step_counts.get("wood", 0)))
	check(int(step_counts.get("tile", 0)) > 2, "Marble footsteps (%d)" % int(step_counts.get("tile", 0)))
	print("NICHOLS_INTEGRATION ", checks - failures.size(), "/", checks)
	for f in failures: print("  FAILED: ", f)
	quit(1 if failures.size() > 0 else 0)

func F1() -> float: return 4.4
