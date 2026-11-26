extends SceneTree
## 0.23: the walled town (scripts/town_siege.gd, scripts/town_horror.gd), checked with the real player and physics:
## - the wall, its posts, the survivors' path, its bulbs and the dressing are all built;
## - standing, nobody leaves the town except through the slum passage: a walkability fill (tests/world_audit.gd) that
##   allows only a standing body reaches the canal but neither the rice fields nor the Nichols side; allowing
##   crouching, it reaches both (the hole and the secret crawl);
## - the real player, walking at the hole upright, stays inside; crouching (C), goes through and comes back;
## - crouching, the player finds the way under the leaned sheets and out under the south wall;
## - the passage is walked upright into the settlement;
## - standing at the hole the HUD offers the crouch; something knocks on the wall from outside it;
## - the owner's house and courtyard stay clean.
##   godot --headless --path game --script res://tests/siege_integration.gd --fixed-fps 60

const Audit := preload("res://tests/world_audit.gd")

var checks := 0
var failures: Array[String] = []
var results := {}
var main: Node
var player: InteriorPlayer
var siege: InteriorTownSiege

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

## Walks the player through `points` (XZ), steering each frame; returns how many points were reached.
func _walk(points: Array, crouch: bool, max_frames: int) -> int:
	player.touch_crouching = crouch
	var index := 0
	for i in max_frames:
		if index >= points.size():
			break
		var target: Vector3 = points[index]
		var to := Vector3(target.x - player.global_position.x, 0, target.z - player.global_position.z)
		if to.length() < .3:
			index += 1
			continue
		player.rotation.y = atan2(-to.x, -to.z)
		player.touch_move = Vector2(0, -1)
		await physics_frame
	player.touch_move = Vector2.ZERO
	await _frames(10)
	return index

func _run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await _frames(20)
	player = main.player
	var stranger := main.get_node_or_null("Stranger")
	if stranger != null: stranger.process_mode = Node.PROCESS_MODE_DISABLED
	siege = main.find_child("Town siege", true, false) as InteriorTownSiege
	check(siege != null, "The town siege is built under the neighbourhood")
	if siege == null:
		_finish()
		return
	var counts: Dictionary = siege.get_meta("counts", {})
	var horror: Dictionary = siege.horror.get_meta("counts", {}) if siege.horror != null else {}
	results["siege"] = counts
	results["horror"] = horror
	check(int(counts.get("sheets", 0)) > 450, "Hundreds of corrugated sheets (%d)" % counts.get("sheets", 0))
	check(int(counts.get("upper_sheets", 0)) > 150, "Most bays two sheets high (%d upper)" % counts.get("upper_sheets", 0))
	check(int(counts.get("posts", 0)) > 80 and int(counts.get("braces", 0)) > 25, "Posts and braces hold it up (%d, %d)" % [counts.get("posts", 0), counts.get("braces", 0)])
	check(int(counts.get("barbs", 0)) > 400, "Barbed wire along the top (%d barbs)" % counts.get("barbs", 0))
	check(int(counts.get("pallets", 0)) >= 28, "A pallet path along street A (%d)" % counts.get("pallets", 0))
	check(int(counts.get("bulbs", 0)) >= 4, "Bulbs strung along the route and over the passage (%d)" % counts.get("bulbs", 0))
	check(int(counts.get("colliders", 0)) > 60, "The wall, posts, braces and pallets collide (%d shapes)" % counts.get("colliders", 0))
	check(int(horror.get("wall_splatter", 0)) >= 25, "Blood on the walls (%d)" % horror.get("wall_splatter", 0))
	check(int(horror.get("trails", 0)) >= 8, "Drag trails (%d)" % horror.get("trails", 0))
	check(int(horror.get("bodies", 0)) >= 8, "Covered bodies (%d)" % horror.get("bodies", 0))
	check(int(horror.get("arrows", 0)) >= 7, "Arrows on the route to the passage (%d)" % horror.get("arrows", 0))
	check(int(horror.get("door_marks", 0)) >= 3, "Searched doors marked (%d)" % horror.get("door_marks", 0))
	check(int(horror.get("flags", 0)) > 120, "Fiesta bunting over the streets (%d flags)" % horror.get("flags", 0))
	var lights := 0
	for light in siege.find_children("Siege bulb light*", "OmniLight3D", true, false):
		lights += 1
		check((light as OmniLight3D).light_cull_mask == 2, "Bulb light %s lights the outdoor layer only" % light.name)
	check(lights == int(counts.get("bulbs", 0)), "Every bulb has its light (%d)" % lights)
	var clean := true
	for d in siege.horror.find_children("*", "Decal", true, false):
		var p := (d as Decal).global_position
		if p.x > -8.0 and p.x < 14.0 and p.z > -5.0 and p.z < 9.2: clean = false
	check(clean, "No blood in the owner's house or courtyard")

	# The wall closes the town: standing, only the passage leads out.
	var audit := Audit.new()
	audit.space = player.get_world_3d().direct_space_state
	audit.out = ProjectSettings.globalize_path("res://../work/v23/integration")
	DirAccess.make_dir_recursive_absolute(audit.out)
	audit.allow_crouch = false
	audit._fill()
	var standing := _regions(audit.cells)
	audit.cells.clear()
	audit.allow_crouch = true
	audit._fill()
	var crouching := _regions(audit.cells)
	audit.free()
	results["regions_standing"] = standing
	results["regions_crouching"] = crouching
	check(standing.fields == 0, "Standing, nobody gets out to the rice fields (%d cells)" % standing.fields)
	check(standing.nichols == 0, "Standing, nobody gets out to the Nichols side (%d cells)" % standing.nichols)
	check(standing.canal > 500, "Standing, the passage leads into the settlement (%d cells)" % standing.canal)
	check(crouching.fields > 30, "Crouching, the hole leads out to the rice fields (%d cells)" % crouching.fields)
	check(crouching.nichols > 300, "Crouching, the secret crawl leads to the Nichols side (%d cells)" % crouching.nichols)

	# The real player at the hole: upright they stay in, crouching they get through and back.
	var hole := InteriorTownSiege.HOLE_X
	var wall := InteriorTownSiege.NORTH_Z
	player.reset_motion(Vector3(hole, -2.9, wall - 1.6))
	await _frames(5)
	await _walk([Vector3(hole, 0, wall + 2.5)], false, 240)
	results["hole_standing_z"] = snappedf(player.global_position.z, .01)
	check(player.global_position.z < wall - .1, "Upright, the player cannot get through the hole (z %.2f)" % player.global_position.z)
	check("rouch" in String(main.prompt.text), "At the hole the HUD offers the crouch (\"%s\")" % main.prompt.text)
	await _walk([Vector3(hole, 0, wall + 2.5)], true, 600)
	results["hole_crouching_z"] = snappedf(player.global_position.z, .01)
	check(player.global_position.z > wall + 1.5, "Crouching, the player squeezes out to the road (z %.2f)" % player.global_position.z)
	await _walk([Vector3(hole, 0, wall - 2.0)], true, 600)
	check(player.global_position.z < wall - 1.2, "And crouches back in (z %.2f)" % player.global_position.z)
	player.touch_crouching = false
	await _frames(20)
	check(not player.crouching, "Clear of the hole, the player stands up")

	# The secret crawl: round the open end of the lean-to, along the wall, out under it.
	var sx := InteriorTownSiege.SECRET_X
	var sz := InteriorTownSiege.SOUTH_Z
	player.reset_motion(Vector3(sx + 1.9, -2.9, sz + 2.6))
	await _frames(5)
	var reached := await _walk([Vector3(sx + 1.25, 0, sz + .6), Vector3(sx, 0, sz + .55), Vector3(sx, 0, sz - 1.4)], true, 1500)
	results["secret_end"] = [snappedf(player.global_position.x, .01), snappedf(player.global_position.z, .01)]
	check(reached == 3 and player.global_position.z < sz - 1.0, "Crouching, the secret way leads out under the south wall (%s)" % player.global_position)
	player.reset_motion(Vector3(sx, -2.9, sz + 2.6))
	await _frames(5)
	await _walk([Vector3(sx, 0, sz - 1.4)], true, 500)
	check(player.global_position.z > sz + .2, "Straight at the lean-to, the player is stopped by it (z %.2f)" % player.global_position.z)
	player.touch_crouching = false

	# The passage, upright.
	player.reset_motion(Vector3(-17.0, -2.9, 18.1))
	await _frames(5)
	await _walk([Vector3(-22.0, 0, 18.1), Vector3(-28.0, 0, 18.0)], false, 900)
	results["passage_x"] = snappedf(player.global_position.x, .01)
	check(player.global_position.x < -27.0, "Upright through the passage toward the estero (x %.2f)" % player.global_position.x)

	# Something knocks on the wall, from outside it.
	player.reset_motion(Vector3(10.0, -2.9, 18.2))
	await _frames(5)
	siege._knock(player)
	var knocks := siege.get_node("Wall knocks") as AudioStreamPlayer3D
	check(knocks.stream != null, "A knock was played")
	check(_outside_face(knocks.global_position), "It comes from outside the wall (%s)" % knocks.global_position)
	_finish()

func _outside_face(p: Vector3) -> bool:
	return p.x > InteriorTownSiege.EAST_X or p.x < InteriorTownSiege.WEST_X or p.z > InteriorTownSiege.NORTH_Z or p.z < InteriorTownSiege.SOUTH_Z

## Walkable cells beyond the wall: the fields (north of the north wall, by street B), the Nichols side (south of the
## south wall) and the canal (west of the west wall).
func _regions(cells: Dictionary) -> Dictionary:
	var out := {"fields": 0, "nichols": 0, "canal": 0, "inside": 0}
	for key in cells:
		var c: Vector2i = cells[key].c
		var x := Audit.REGION.position.x + (c.x + .5) * Audit.CELL
		var z := Audit.REGION.position.y + (c.y + .5) * Audit.CELL
		if z > InteriorTownSiege.NORTH_Z + .8 and x > InteriorTownSiege.WEST_X: out.fields += 1
		elif z < InteriorTownSiege.SOUTH_Z - .8: out.nichols += 1
		elif x < InteriorTownSiege.WEST_X - 1.0: out.canal += 1
		else: out.inside += 1
	return out

func _finish() -> void:
	print("INTERIOR_SIEGE_INTEGRATION ", JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "results": results}))
	quit(0 if failures.is_empty() else 1)
