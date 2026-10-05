extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	check(not main.control_lab, "Final room must load instead of the control lab")
	check(main.room_manifest.actors.size() == 48, "Export must include all 48 object assemblies")
	main._play()
	for i in 3:
		await physics_frame
	var bodies := get_nodes_in_group("movable")
	check(get_nodes_in_group("original_room_props").size() == main.room_manifest.actors.size(), "Every exported actor must have a physics body")
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = main.player.get_child(0).shape
	query.transform = main.player.global_transform.translated(Vector3(0,.85,0))
	query.collision_mask = 6
	query.exclude = [main.player.get_rid()]
	var spawn_hits: Array = main.get_world_3d().direct_space_state.intersect_shape(query)
	check(spawn_hits.is_empty(), "Player spawn must not overlap furniture or the room")
	var clue_count := 0
	var anchored_count := 0
	for body in bodies:
		if not body.clue_digit.is_empty():
			clue_count += 1
		if body.anchored:
			anchored_count += 1
			check(body.freeze, "Wall fixture must start attached: " + body.name)
		check(body.get_child_count() >= 2, "Movable objects require visible geometry and collisions: " + body.name)
	check(clue_count == 3, "Final room must contain exactly three unique clue objects")
	check(anchored_count >= 10, "Wall decor must be detachable rather than fixed architecture")
	# The real player capsule must be able to walk along the approved aisle.
	main.player.touch_move = Vector2(0,-1)
	for i in 75:
		await physics_frame
	main.player.touch_move = Vector2.ZERO
	check(main.player.position.z < .5, "Player must be able to walk forward through the room aisle")
	main.player.velocity = Vector3.ZERO
	for actor in main.room_manifest.actors:
		if not actor.has("clueDigit"):
			continue
		var body := main.room.get_node(NodePath(actor.nodeName)) as InteriorObject
		body.recover()
		body.freeze = true
		var stand := Vector3.ZERO
		match actor.clueDigit:
			"5": stand = Vector3(.10,.1,-1.3)
			"0": stand = Vector3(.65,.1,.25)
			"8": stand = Vector3(-.4,.1,-1.4)
		main.player.global_position = stand
		main.player.velocity = Vector3.ZERO
		var collider := body.get_child(1) as CollisionShape3D
		var center := collider.global_position
		main.player.camera.look_at(center)
		await physics_frame
		await physics_frame
		main.player.update_target()
		check(main.player.target == body, "Clue must be reachable with an unobstructed grab ray: " + actor.clueDigit)
		main.player.toggle_hold()
		check(main.player.held == body, "E must grab the real clue object: " + actor.clueDigit)
		check(not body.freeze, "Grabbing must detach an anchored object: " + actor.clueDigit)
		main.player.toggle_hold()
	check(main.clues.size() == 3, "Grabbing the three room clues must update the journal")
	main.try_unlock("508")
	check(main.solved, "The final room mystery must be solvable")
	print("INTERIOR_ROOM_INTEGRATION ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"objects":bodies.size(),"clues":clue_count,"anchored":anchored_count}))
	quit(0 if failures.is_empty() else 1)
