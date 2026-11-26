extends SceneTree
## 0.26 spot checks anywhere in the world: work-light renders and collision probes.
##   Godot --path game --script res://tests/spot_review.gd -- --out=<dir> [--night]
##       "--shots=name:x,y,z:lookx,looky,lookz;..."     camera at the first point looking at the second
##       "--probe=x0,z0,x1,z1,count,top"                rays straight down along a line: what is under each point
var main: Node
var out := "res://../work/v26/spots"

func _initialize() -> void:
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n: await process_frame

func _v(text: String) -> Vector3:
	var f := text.split_floats(",")
	return Vector3(f[0], f[1], f[2])

func _run() -> void:
	var shots: Array = []
	var probes: Array = []
	var night := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg == "--night": night = true
		if arg.begins_with("--shots="):
			for part in arg.trim_prefix("--shots=").split(";", false):
				var bits := part.split(":")
				shots.append([bits[0], _v(bits[1]), _v(bits[2])])
		if arg.begins_with("--probe="): probes.append(arg.trim_prefix("--probe=").split_floats(","))
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await frames(40)
	var player: InteriorPlayer = main.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var stranger := main.get_node_or_null("Stranger")
	if stranger != null:
		stranger.process_mode = Node.PROCESS_MODE_DISABLED
		stranger.visible = false
	for i in 10: await physics_frame
	var space := player.get_world_3d().direct_space_state
	for probe: PackedFloat64Array in probes:
		var count := int(probe[4])
		for i in count:
			var t := float(i) / maxf(1.0, count - 1.0)
			var x := lerpf(probe[0], probe[2], t)
			var z := lerpf(probe[1], probe[3], t)
			var line := "PROBE %.2f %.2f:" % [x, z]
			var exclude: Array[RID] = []
			for hit_index in 4:
				var query := PhysicsRayQueryParameters3D.create(Vector3(x, probe[5], z), Vector3(x, probe[5] - 20.0, z), 6)
				query.exclude = exclude
				var hit := space.intersect_ray(query)
				if hit.is_empty(): break
				var node := hit.collider as Node
				line += "  y %.2f %s" % [(hit.position as Vector3).y, str(main.get_path_to(node)).right(46)]
				exclude.append(hit.rid)
			print(line)
	if shots.is_empty():
		quit()
		return
	for layer: CanvasLayer in main.find_children("*", "CanvasLayer", true, false): layer.visible = false
	if not night:
		var sun := DirectionalLight3D.new()
		sun.light_energy = 1.1
		sun.light_cull_mask = 0xFFFFF
		sun.shadow_enabled = false
		main.add_child(sun)
		sun.look_at_from_position(Vector3.ZERO, Vector3(-.5, -1.0, -.35), Vector3.UP)
		var fill := DirectionalLight3D.new()
		fill.light_energy = .5
		fill.light_cull_mask = 0xFFFFF
		main.add_child(fill)
		fill.look_at_from_position(Vector3.ZERO, Vector3(.6, -.4, .7), Vector3.UP)
	var camera: Camera3D = player.camera
	for shot: Array in shots:
		player.global_position = (shot[1] as Vector3) - Vector3.UP * 1.58
		camera.global_position = shot[1]
		var to: Vector3 = shot[2]
		var flat := Vector2(to.x - shot[1].x, to.z - shot[1].z).length()
		camera.look_at(to, Vector3(0, 0, 1) if flat < .01 else Vector3.UP)
		camera.fov = 75.0
		await frames(14)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("%s.png" % shot[0]))
	print("SPOT_REVIEW ", out)
	quit()
