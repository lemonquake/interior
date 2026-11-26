extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	main.player.playing = false
	for i in 180: await physics_frame
	var rows: Array[Dictionary] = []
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	for body: InteriorObject in get_nodes_in_group("movable"):
		if body.home_transform.origin.distance_to(body.global_position) < .5: continue
		var home := body.home_transform.origin
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(home+Vector3.UP,home+Vector3.DOWN*15,2))
		rows.append({"path":str(body.get_path()),"home":str(home),"now":str(body.global_position),"floor":str(hit.get("position","none")),"support":str(hit.collider.get_path()) if hit.has("collider") else "none"})
	print("PROP_SPAWN_AUDIT ",JSON.stringify(rows))
	quit()
