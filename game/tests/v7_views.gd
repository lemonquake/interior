extends SceneTree
## RENDERED review captures for run 7: the night, the way out of town and the moonlit rice fields
## (do not run with --headless).
##   godot --path game --script res://tests/v7_views.gd -- --views=night|fields|all --out=<dir> [--size=1600x900] [--quality=2]
## Writes one PNG per view; prints V7_VIEW <name> for each.

func _initialize() -> void:
	_run.call_deferred()

func _arg(name: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--" + name + "="):
			return argument.get_slice("=", 1)
	return fallback

func _wait(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame

func _v3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)

func _views(fields: Node3D) -> Array:
	var moon := InteriorNight.MOON_DIRECTION.normalized()
	var eye := -2.9 + 1.58
	var views := [
		# [name, set, camera, target, fov]
		["night-1-kitchen-window", "night", Vector3(-1.6, 1.58, 1.6), Vector3(-5.6, 1.9, -.3), 70.0],
		["night-2-balcony-moon", "night", Vector3(5.1, 1.58, 4.15), Vector3(3.2, 6.5, 22.0), 72.0],
		["night-3-courtyard-gate", "night", Vector3(10.0, eye, 3.7), Vector3(13.5, -1.8, 4.3), 72.0],
		["night-4-street-b", "night", Vector3(20.2, eye, 6.0), Vector3(20.5, -1.6, 30.0), 72.0],
		["night-5-way-out", "night", Vector3(21.0, eye, 38.0), Vector3(21.0, -1.7, 75.0), 72.0],
	]
	if fields == null:
		return views
	var road: PackedVector2Array = fields.get_meta("road_samples")
	var pond: Vector4 = fields.get_meta("pond")
	var hut: Vector3 = fields.get_meta("hut")
	var end: Vector3 = fields.get_meta("road_end")
	var tree: Vector3 = fields.get_meta("giant_tree")
	var at := func(i: int) -> Vector3: return _v3(road[clampi(i, 0, road.size() - 1)], eye)
	var ahead := func(i: int, k: int) -> Vector3: return _v3(road[clampi(i + k, 0, road.size() - 1)], eye - .2)
	# Nearest road sample to the pond: the jetty starts there.
	var pi := 0
	var best := INF
	for i in road.size():
		var d := road[i].distance_to(Vector2(pond.x, pond.y))
		if d < best:
			best = d
			pi = i
	var out := (Vector2(pond.x, pond.y) - road[pi]).normalized()
	var deck := _v3(road[pi] + out * 8.0, -2.96 + 1.58)
	var crow: Node3D = fields.find_child("Scarecrow", true, false)
	var ci := 0
	if crow != null:
		best = INF
		for i in road.size():
			var d := road[i].distance_to(Vector2(crow.global_position.x, crow.global_position.z))
			if d < best:
				best = d
				ci = i
	views.append_array([
		["fields-1-road-start", "fields", at.call(20), ahead.call(20, 40), 72.0],
		["fields-2-toward-moon", "fields", at.call(70), at.call(70) + moon * 30.0 + Vector3.DOWN * 9.0, 74.0],
		["fields-3-canal-glitter", "fields", at.call(150), at.call(150) + Vector3(moon.x, 0, moon.z).normalized() * 20.0 + Vector3.DOWN * 6.0, 74.0],
		["fields-4-pond-jetty", "fields", deck, deck + moon * 30.0 + Vector3.DOWN * 7.0, 74.0],
		["fields-5-pond-from-road", "fields", at.call(pi - 25), _v3(Vector2(pond.x, pond.y), -2.6), 74.0],
		["fields-6-hut", "fields", at.call(int(road.size() * .27)), hut + Vector3.UP * 1.6, 70.0],
		["fields-7-scarecrow", "fields", at.call(ci - 6), (crow.global_position + Vector3.UP * 1.2) if crow != null else ahead.call(ci, 20), 70.0],
		["fields-8-road-end-tree", "fields", at.call(road.size() - 40), tree + Vector3.UP * 7.0, 74.0],
		["fields-9-look-back", "fields", at.call(int(road.size() * .55)), at.call(int(road.size() * .3)) + Vector3.UP * 2.0, 74.0],
	])
	return views

func _run() -> void:
	var which := _arg("views", "all")
	var out := _arg("out", "user://v7")
	var size := _arg("size", "1600x900").split("x")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(int(size[0]), int(size[1]))
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	for i in 6:
		await process_frame
	main._apply_quality(int(_arg("quality", "2")))
	var player: Node = main.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var camera: Camera3D = player.camera
	for layer in main.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var fields: Node3D = main.get_node_or_null("Fields")
	for view: Array in _views(fields):
		if which != "all" and view[1] != which:
			continue
		camera.fov = view[4]
		camera.global_position = view[2]
		camera.look_at(view[3])
		await _wait(.9)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join(str(view[0]) + ".png"))
		print("V7_VIEW ", view[0], " ", camera.global_position)
	quit(0)
