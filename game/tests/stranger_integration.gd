extends SceneTree
## 0.9: the man in the black hoodie (scripts/stranger.gd), driven with the real player:
## - he waits at the courtyard gate in gate_grip, on the outdoor render layer, with his loops looping;
## - he is not set off from inside the room, nor by a player on the stair looking the other way;
## - turning to look at the gate sets him off within a fraction of a second, and the pause holds him;
## - his routes (lane, street B, the barricade gap, the first 60 m of the dirt road) are clear of every
##   street collider for a 0.25 m capsule;
## - 0.23: being seen starts the cutscene (its own camera, the player held, the HUD hidden, the pause holding it): a
##   shot from behind him, his head turning, walk_back, then he walks (not runs) off and the view comes back;
## - opening the courtyard gate puts him in front of the hole in the north wall at once; seen from the corner of
##   street B, he crouches through it (crouch_walk) - a crouched capsule fits, a standing one does not -
##   and runs down the middle of the dirt road, (0.10) turns off at the footpath to the bahay kubo and disappears
##   inside (hidden, for scripts/story.gd to call back later).
##   godot --headless --path game --script res://tests/stranger_integration.gd --fixed-fps 60

var checks := 0
var failures: Array[String] = []
var results := {}
var main: Node
var player: InteriorPlayer
var stranger: InteriorStranger

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _look(at: Vector3, eye: Vector3, target: Vector3) -> void:
	player.reset_motion(at)
	var to := target - eye
	player.rotation = Vector3(0, atan2(-to.x, -to.z), 0)
	player.set("_look_pitch", atan2(to.y, Vector2(to.x, to.z).length()))
	player.camera.rotation.x = player.get("_look_pitch")
	await _frames(2)

func _state() -> String:
	return InteriorStranger.State.keys()[stranger.state] if is_instance_valid(stranger) else "FREED"

func _wait_state(want: String, max_frames: int) -> int:
	for i in max_frames:
		if _state() == want:
			return i
		await physics_frame
	return -1

func _run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await _frames(4)
	player = main.player
	stranger = main.get_node_or_null("Stranger") as InteriorStranger
	check(stranger != null, "The stranger is in the main scene")
	if stranger == null:
		_finish()
		return
	var anim := stranger.find_child("AnimationPlayer", true, false) as AnimationPlayer

	# 1. At the gate.
	check(stranger.global_position.distance_to(InteriorStranger.GATE_SPOT) < .05, "He starts outside the courtyard gate")
	check(anim != null and anim.current_animation == "gate_grip", "He holds the gate (gate_grip)")
	check(anim != null and anim.get_animation("gate_grip").loop_mode == Animation.LOOP_LINEAR and anim.get_animation("run").loop_mode == Animation.LOOP_LINEAR, "gate_grip and run loop")
	var layers_ok := true
	var surfaces := 0
	for node in stranger.find_children("*", "MeshInstance3D", true, false):
		layers_ok = layers_ok and (node as MeshInstance3D).layers == InteriorStranger.OUTDOOR_LAYER
		surfaces += (node as MeshInstance3D).mesh.get_surface_count()
	check(layers_ok, "His meshes are on the outdoor layer (lit by the moon)")
	check(surfaces >= 7, "Skin, hoodie (hood up), rib, drawstring, jeans, sneaker and sole surfaces (%d)" % surfaces)
	# 0.11: every clip stranger.gd plays exists (0.10 asked for "talk" / "pickup", which the GLB doesn't have).
	var missing: Array[String] = []
	for clip in InteriorStranger.CLIPS:
		if anim == null or not anim.has_animation(clip):
			missing.append(clip)
	check(missing.is_empty(), "Every clip he plays is in stranger.glb (missing: %s)" % ", ".join(missing))
	check(anim != null and anim.get_animation_list().size() >= 30, "A full clip library (%d clips)" % (anim.get_animation_list().size() if anim else 0))

	# 2. Not seen from the room, nor from the stair while looking at the house.
	await _look(Vector3(.62, .1, 1.3), Vector3(.62, 1.68, 1.3), Vector3(13.0, -1.6, 4.1))
	await _frames(60)
	check(_state() == "AT_GATE", "Looking toward the gate from inside the room doesn't set him off")
	var stair := Vector3(5.25, -.08, 3.3)
	await _look(stair, stair + Vector3.UP * 1.58, Vector3(1.0, 1.4, 2.0))
	await _frames(90)
	check(_state() == "AT_GATE", "On the stair, looking back at the house, he stays")

	# 3. Looking at the gate: the cutscene (0.23).
	await _look(stair, stair + Vector3.UP * 1.58, Vector3(12.6, -1.6, 4.4))
	var took := await _wait_state("CUTSCENE", 90)
	results["cutscene_frames"] = took
	check(took >= 0 and took < 40, "Seen from the stair, the cutscene starts within 0.7 s (%d frames)" % took)
	await _frames(3)
	var cut := main.find_child("Stranger cutscene", true, false)
	check(cut != null, "The cutscene node runs")
	var cam := root.get_viewport().get_camera_3d()
	check(cam != null and cam != player.camera, "The cutscene camera has the view")
	check(player.cutscene and not main.hud.visible, "The player is held and the HUD hidden")
	var held_at := player.global_position
	await _frames(20)
	var before := stranger.global_position
	paused = true
	await _frames(30)
	check(stranger.global_position.distance_to(before) < .001, "Pause holds him")
	paused = false
	# Behind him at first: the camera is east of him (outside the gate) looking west at the house.
	if cam != null:
		check(cam.global_position.x > stranger.global_position.x + 1.0, "The first shot is from behind him (camera x %.2f)" % cam.global_position.x)
	var look := stranger.find_child("Head look", true, false)
	check(look != null, "His head can turn (LookAtModifier3D on the head bone)")
	var peak_look := 0.0
	var max_speed := 0.0
	var backed := false
	var last := stranger.global_position
	for i in 560:
		await physics_frame
		if look != null: peak_look = maxf(peak_look, float(look.get("influence")))
		var step := Vector2(stranger.global_position.x - last.x, stranger.global_position.z - last.z).length() * 60.0
		last = stranger.global_position
		if stranger.get("_cut_time") > InteriorStranger.CUT_TURN + .4:
			max_speed = maxf(max_speed, step)
		if anim != null and anim.current_animation == "walk_back":
			backed = true
		if not is_instance_valid(main.find_child("Stranger cutscene", true, false)):
			break
	results["cutscene_head_influence"] = snappedf(peak_look, .01)
	results["cutscene_walk_speed"] = snappedf(max_speed, .01)
	check(peak_look > .9, "He turns his head toward the player (influence %.2f)" % peak_look)
	check(backed, "He backs off the gate (walk_back)")
	check(max_speed > .8 and max_speed < InteriorStranger.WALK_SPEED + .25, "He walks away, he does not run (%.2f m/s)" % max_speed)
	check(main.find_child("Stranger cutscene", true, false) == null, "The cutscene ends")
	check(root.get_viewport().get_camera_3d() == player.camera and not player.cutscene and main.hud.visible, "The view, control and HUD are back")
	check(player.global_position.distance_to(held_at) < .05, "The player did not move during it")
	check(_state() in ["WALK_AWAY", "POSTED"], "He keeps walking to his spot (%s)" % _state())

	# 4. His routes are clear of the street's colliders (the lane, and the dirt road from the hole).
	var route: Array[Vector3] = [InteriorStranger.GATE_SPOT]
	route.append_array(InteriorStranger.ROUTE_TO_ROAD)
	var road := stranger.road_path()
	check(road.size() > 50, "The dirt road's centre line is available (%d waypoints)" % road.size())
	var out_route: Array[Vector3] = [InteriorTownSiege.STRANGER_OUT]
	for p in road:
		if p.z < 120.0:
			out_route.append(p)
	var blocked := _route_hits(route)
	blocked.append_array(_route_hits(out_route))
	results["route_hits"] = blocked
	check(blocked.is_empty(), "His routes are clear of houses, walls, poles, carts and barricades: " + str(blocked))
	var crawl := _route_hits([InteriorTownSiege.STRANGER_WAIT, InteriorTownSiege.STRANGER_OUT], .7)
	check(crawl.is_empty(), "Crouched, he fits through the hole: " + str(crawl))
	var standing := _route_hits([InteriorTownSiege.STRANGER_WAIT, InteriorTownSiege.STRANGER_OUT])
	check(not standing.is_empty(), "Standing, nobody fits through the hole")

	# 5. The gate opens: he is at the hole at once.
	var gate: Node = stranger.get("_gate")
	check(gate != null, "He knows the courtyard gate")
	took = await _wait_state("POSTED", 900)
	if gate != null:
		gate.unlock()
		gate.snap_open()
	took = await _wait_state("AT_HOLE", 5)
	check(took >= 0, "Opening the gate sends him to the hole at once (%d frames)" % took)
	check(stranger.global_position.distance_to(InteriorTownSiege.STRANGER_WAIT) < .05, "He stands in front of the hole (%s)" % stranger.global_position)
	await _frames(60)
	check(_state() == "AT_HOLE", "Unseen, he waits there")

	# 6. Seen from up street B (past the parked tricycle): he crouches through the hole and runs for the hut.
	await _look(Vector3(20.2, -2.9, 30.0), Vector3(20.2, -1.32, 30.0), Vector3(21.3, -1.8, 53.0))
	took = await _wait_state("CRAWLING", 90)
	check(took >= 0, "Seen down street B, he goes for the hole (%d frames)" % took)
	await _frames(50)
	check(anim != null and anim.current_animation == "crouch_walk", "He crouches through (crouch_walk)")
	check(stranger.global_position.z > InteriorTownSiege.STRANGER_WAIT.z + .1, "He moves through the hole")
	took = await _wait_state("FLEEING", 400)
	check(took >= 0, "Out on the dirt road he stands and runs")
	var off_centre := 0.0
	var reached := 0.0
	var hut := main.get_tree().get_first_node_in_group("hut_house") as InteriorHutHouse
	check(hut != null and hut.route_in.size() > 4, "The bahay kubo has a way in from the road")
	var turn: Vector3 = hut.route_in[0] if hut != null else Vector3(0, 0, INF)
	var left_road := false
	for i in 2400:
		await physics_frame
		if not is_instance_valid(stranger) or _state() == "HIDDEN":
			break
		var at := stranger.global_position
		reached = maxf(reached, at.z)
		if Vector2(at.x - turn.x, at.z - turn.z).length() < 3.0:
			left_road = true
		if at.z > 60.0 and not left_road:
			var nearest := INF
			for k in road.size() - 1:
				var c := Geometry2D.get_closest_point_to_segment(Vector2(at.x, at.z), Vector2(road[k].x, road[k].z), Vector2(road[k + 1].x, road[k + 1].z))
				nearest = minf(nearest, c.distance_to(Vector2(at.x, at.z)))
			off_centre = maxf(off_centre, nearest)
	results["road_off_centre_m"] = snappedf(off_centre, .01)
	results["reached_z"] = snappedf(reached, .1)
	check(reached > 100.0, "He runs far out along the dirt road (z %.0f)" % reached)
	check(off_centre < .6, "He keeps to the middle of the road (%.2f m off the centre line)" % off_centre)
	took = await _wait_state("HIDDEN", 3000)
	check(took >= 0, "He runs into the bahay kubo and is gone")
	if hut != null and is_instance_valid(stranger):
		check(not stranger.visible, "Inside, he is hidden")
		check(hut.is_inside(stranger.global_position), "He vanished inside the hut, behind its walls (%s)" % stranger.global_position)
	_finish()

## Sweeps a 0.25 m capsule (0.3..1.8 m above the ground, or 0.3 m up to `height` + 0.3 crouched) along the route
## against the street colliders.
func _route_hits(route: Array[Vector3], height := 1.5) -> Array:
	var space := (main as Node3D).get_world_3d().direct_space_state
	var shape := CapsuleShape3D.new()
	shape.radius = .25
	shape.height = height
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 2
	query.exclude = [player.get_rid()]
	var hits := []
	for i in route.size() - 1:
		var a: Vector3 = route[i]
		var b: Vector3 = route[i + 1]
		var n := maxi(1, int(a.distance_to(b) / .25))
		for k in n + 1:
			var p := a.lerp(b, float(k) / n)
			query.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, InteriorStranger.GROUND + .3 + height * .5, p.z))
			for hit in space.intersect_shape(query, 4):
				var collider: Object = hit.collider
				var label := String(collider.name) if collider is Node else str(collider)
				var shape_owner := ""
				if collider is CollisionObject3D:
					var owner_id := (collider as CollisionObject3D).shape_find_owner(hit.shape)
					var owner_node := (collider as CollisionObject3D).shape_owner_get_owner(owner_id) as Node
					shape_owner = String(owner_node.name) if owner_node != null else ""
				var entry := "%s/%s at (%.1f, %.1f)" % [label, shape_owner, p.x, p.z]
				if hits.size() < 30 and not entry in hits:
					hits.append(entry)
	return hits

func _finish() -> void:
	print("INTERIOR_STRANGER_INTEGRATION ", JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "results": results}))
	quit(0 if failures.is_empty() else 1)
