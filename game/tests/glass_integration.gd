extends SceneTree
## 0.34: window glass breaks (scripts/window_glass.gd), headless:
##   godot --headless --path game --script res://tests/glass_integration.gd --fixed-fps 60
## The panes of the town's houses and of the Nichols house are found. A round breaks a house pane and stops there,
## and the next one into the hole breaks nothing. A round through a Nichols pane takes its glass out of the mesh
## and goes on into the room; the next goes through the opening. A thing thrown hard breaks one. They hear it.

class ErrorCatcher extends Logger:
	var errors: Array[String] = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file, line, code, rationale])
	func _log_message(message: String, error: bool) -> void:
		pass

var checks := 0
var failures: Array[String] = []
var main: Node
var player: InteriorPlayer
var zombies: InteriorZombies
var gun: InteriorGun
var glass: InteriorWindowGlass
var catcher := ErrorCatcher.new()

func _initialize() -> void:
	OS.add_logger(catcher)
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL " + message)
	print(("PASS " if condition else "FAIL ") + message)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _seconds(s: float) -> void:
	await _frames(int(ceil(s * 60.0)))

func _shot() -> Array:
	gun.mag = gun.mag_size()
	gun.chambered = true
	for i in 120:
		if gun.ready_to_fire():
			break
		await physics_frame
	gun.try_fire()
	await _frames(3)
	var hits: Array = gun.last_hits.duplicate()
	await _seconds(.5)
	return hits

## A whole pane with a clear line to it from a place to stand `back` metres out from it: [pane, place to stand].
func _pane_in_view(solid: bool, back: float, near: Vector3, top := 99.0) -> Array:
	var space := player.get_world_3d().direct_space_state
	var order: Array = []
	for i in glass.panes.size():
		var pane := glass.panes[i]
		if bool(pane.broken) or bool(pane.solid) != solid or (pane.at as Vector3).y > top:
			continue
		order.append([(pane.at as Vector3).distance_to(near), i])
	order.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for entry: Array in order:
		var pane := glass.panes[int(entry[1])]
		var out: Vector3 = (pane.at as Vector3) + (pane.n as Vector3) * back
		var stand := zombies.ground(Vector3(out.x, (pane.at as Vector3).y, out.z), false)
		if not stand.is_finite() or stand.y > (pane.at as Vector3).y:
			continue
		var eye := stand + Vector3.UP * 1.6
		var hit := InteriorSurfaces.seen_ray(space, eye, (pane.at as Vector3) - (pane.n as Vector3) * .4, 2 | 4)
		if hit.is_empty() or hit.collider != pane.body or (hit.position as Vector3).distance_to(pane.at) > .35:
			continue
		# 0.37: the round leaves from the weapon, a forearm under the lens at the hip (scripts/gun.gd BARREL): the pane
		# must be in its line too, not hidden behind the sill.
		var low := InteriorSurfaces.seen_ray(space, eye + Vector3.DOWN * .3, (pane.at as Vector3) - (pane.n as Vector3) * .4, 2 | 4)
		if low.is_empty() or low.collider != pane.body or (low.position as Vector3).distance_to(pane.at) > .4:
			continue
		return [int(entry[1]), stand]
	return [-1, Vector3.ZERO]

## Whole panes within 1.5 m of `at`.
func _whole_near(at: Vector3) -> int:
	var count := 0
	for pane: Dictionary in glass.panes:
		if not bool(pane.broken) and (pane.at as Vector3).distance_to(at) < 1.5:
			count += 1
	return count

func _stand_and_aim(stand: Vector3, at: Vector3) -> void:
	player.reset_motion(stand)
	await _frames(20)
	for i in 3:
		var from := player.camera.global_position
		var way := (at - from).normalized()
		player.rotation = Vector3(0, atan2(-way.x, -way.z), 0)
		player.camera.rotation.x = asin(clampf(way.y, -1.0, 1.0))
		await _frames(6)

func _run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await _frames(6)
	player = main.player
	zombies = main.zombies
	glass = main.glass
	var man := main.get_node_or_null("Stranger") as Node3D
	if man != null:
		man.process_mode = Node.PROCESS_MODE_DISABLED
	zombies.passive = true
	zombies.invulnerable = true
	await _seconds(1.0)

	# ---- the list
	var town := 0
	var nichols := 0
	for pane: Dictionary in glass.panes:
		if bool(pane.solid):
			town += 1
		else:
			nichols += 1
	check(glass.built and town > 150, "The panes of the town's houses are found (%d)" % town)
	check(nichols >= 120, "...and the lights of the Nichols windows (%d)" % nichols)
	var whole := 0
	for pane: Dictionary in glass.panes:
		if not bool(pane.solid) and not bool(pane.broken):
			whole += 1
			if (pane.tris as Array).size() < 4:
				check(false, "A whole Nichols light has its glass in the mesh (%d triangles)" % (pane.tris as Array).size())
				break
	check(whole > 40 and glass.open_from_the_start > 10, "Most are whole, some were built broken (%d whole, %d open)" % [whole, glass.open_from_the_start])

	main.story.debug_give_gun()
	gun = main.story.gun
	gun.draw()
	gun.spread_scale = 0.0
	gun.instant_hits = true
	gun.infinite_ammo = true
	player.free_aim = false
	await _seconds(1.3)

	# ---- a house in the town
	var found := _pane_in_view(true, 3.2, Vector3(2.0, -1.8, 18.0), -1.2)
	check(int(found[0]) >= 0, "A ground-floor pane on street A can be stood in front of")
	if int(found[0]) >= 0:
		var i := int(found[0])
		var pane := glass.panes[i]
		await _stand_and_aim(found[1], pane.at)
		var decals_before := gun._decals.size()
		var heard_before: int = main.senses.noises.size()
		var whole_near := _whole_near(pane.at)
		var hits: Array = await _shot()
		check(hits.size() == 1 and str(hits[0].surface) == "glass", "A round at a house pane strikes glass and stops (%d struck, %s)" % [hits.size(), str(hits[0].surface) if hits.size() > 0 else "-"])
		check(glass.is_broken(i) and glass.broken == 1, "The pane is broken")
		var left := pane.get("left") as MeshInstance3D
		check(left != null and left.mesh != null and left.mesh.get_surface_count() == 2, "The dark of the room and the glass left in the frame are drawn")
		check(gun._decals.size() == decals_before, "No bullet hole is left hanging in the opening")
		var noise: Dictionary = main.senses.noises[-1] if main.senses.noises.size() > 0 else {}
		var kinds: Array = []
		for entry: Dictionary in main.senses.noises:
			kinds.append(str(entry.kind))
		check(kinds.has("glass") and main.senses.noises.size() > heard_before, "Breaking glass is a sound they can hear")
		hits = await _shot()
		check(hits.is_empty() and glass.broken == 1, "The next round goes into the hole and breaks nothing more (%d struck)" % hits.size())
		# Its neighbour across the mullion is untouched.
		var left_whole := _whole_near(pane.at)
		check(left_whole == whole_near - 1, "The panes beside it are still whole (%d of %d near it)" % [left_whole, whole_near])

	# ---- the Nichols house
	var property := get_first_node_in_group("nichols_property") as Node3D
	var house_at: Vector3 = property.house.global_position if property != null else Vector3.ZERO
	found = _pane_in_view(false, 5.0, house_at + Vector3(0, 2.0, 3.0), house_at.y + 4.2)
	check(int(found[0]) >= 0, "A whole ground-floor Nichols light can be seen from outside")
	if int(found[0]) >= 0:
		var i := int(found[0])
		var pane := glass.panes[i]
		var sheet: Dictionary = glass._sheets[int((pane.tris as Array)[0][0])]
		var instance := sheet.instance as MeshInstance3D
		var before := 0
		for surface in instance.mesh.get_surface_count():
			before += (instance.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		await _stand_and_aim(found[1], pane.at)
		var was := glass.broken
		var hits: Array = await _shot()
		check(hits.size() >= 1 and str(hits[0].surface) == "glass" and glass.is_broken(i) and glass.broken == was + 1, "A round breaks a Nichols light (%d struck)" % hits.size())
		check(hits.size() >= 2 and float(hits[1].distance) > float(hits[0].distance) + .25, "...and goes on into the room behind (%d struck)" % hits.size())
		var after := 0
		for surface in instance.mesh.get_surface_count():
			after += (instance.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		check(after == before - (pane.tris as Array).size() and (pane.tris as Array).size() >= 4, "Its glass is out of the mesh (%d triangles, then %d)" % [before, after])
		check(pane.get("left") != null, "Glass is left standing in the frame")
		hits = await _shot()
		check(hits.size() >= 1 and str(hits[0].surface) != "glass" and glass.broken == was + 1, "The next round goes through the opening (%s)" % (str(hits[0].surface) if hits.size() > 0 else "-"))

	# ---- a thing thrown
	var target := glass.nearest(Vector3(2.0, -1.8, 18.0), 60.0, true)
	if target >= 0:
		var pane := glass.panes[target]
		var was := glass.broken
		check(not glass.thing_hit((pane.at as Vector3) + (pane.n as Vector3) * .12, 1.2, .4), "A thing that only taps a pane does not break it")
		check(glass.thing_hit((pane.at as Vector3) + (pane.n as Vector3) * .12, 7.0, .4) and glass.broken == was + 1, "A thing thrown hard does")
	_finish()

func _finish() -> void:
	await _frames(40)
	check(catcher.errors.is_empty(), "No errors in the log (%d)" % catcher.errors.size())
	for line in catcher.errors.slice(0, 12):
		print("  ERROR ", line)
	print("INTERIOR_GLASS ", JSON.stringify({"checks": checks, "passed": failures.is_empty(), "failures": failures}))
	quit(1 if not failures.is_empty() else 0)
