extends SceneTree
## 0.64 diagnostic: which parts of the world the drawn objects belong to, in the squad game on a phone.
##   Godot --path game --rendering-method gl_compatibility --script res://tests/phone_draws.gd -- --mobile-test [--place=storeroad]
var game

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 30:
		await physics_frame
	var place := "storeroad"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--place="):
			place = a.trim_prefix("--place=")
	var session = game.coop
	session.host()
	for i in 4:
		session.add_bot()
	session.start_game()
	for i in 30:
		await physics_frame
	print("PHONE_DRAWS jump ", session.mission.debug_command(1, "jump " + place))
	for i in 240:
		await process_frame
	var camera := root.get_camera_3d()
	var eye := camera.global_position
	var planes := camera.get_frustum()
	var groups := {}
	var kinds := {}
	var total := 0
	for node in game.find_children("*", "GeometryInstance3D", true, false):
		var gi := node as GeometryInstance3D
		if not gi.is_visible_in_tree() or (gi.layers & camera.cull_mask) == 0:
			continue
		var box := gi.global_transform * gi.get_aabb()
		var inside := true
		for plane: Plane in planes:
			var far := box.get_support(-plane.normal)
			if plane.is_point_over(far):
				inside = false
				break
		if not inside:
			continue
		var d := box.get_center().distance_to(eye)
		if gi.visibility_range_end > 0.0 and d > gi.visibility_range_end + gi.visibility_range_end_margin:
			continue
		var surfaces := 1
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null:
			surfaces = (gi as MeshInstance3D).mesh.get_surface_count()
		total += surfaces
		var path := str(game.get_path_to(gi)).split("/")
		var key := "/".join(path.slice(0, mini(3, path.size() - 1)))
		groups[key] = int(groups.get(key, 0)) + surfaces
		var kind := gi.get_class() + (" ranged" if gi.visibility_range_end > 0.0 else " unranged")
		kinds[kind] = int(kinds.get(kind, 0)) + surfaces
	var rows := []
	for k in groups:
		rows.append([groups[k], k])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	print("PHONE_DRAWS eye ", eye, " total surfaces in view ", total, " draw calls ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	for r in rows.slice(0, 25):
		print("PHONE_DRAWS %5d  %s" % [r[0], r[1]])
	print("PHONE_DRAWS kinds ", JSON.stringify(kinds))
	quit(0)
