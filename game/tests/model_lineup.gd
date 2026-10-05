extends SceneTree
## RENDERED contact sheet of the downloaded models (orientation check, not a pass/fail test).
##   godot --path game --script res://tests/model_lineup.gd -- --group=studio --out=<dir>
## Each model sits at yaw 0 on a grid with a red +X / blue +Z marker; renders a front view
## (camera on +Z looking toward -Z) and a top view.

func _initialize() -> void:
	var group := "studio"
	var out := "user://lineup"
	var only: PackedStringArray = []
	var spacing_arg := 0.0
	var columns_arg := 0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			only = argument.get_slice("=", 1).split(",")
		elif argument.begins_with("--columns="):
			columns_arg = int(argument.get_slice("=", 1))
		elif argument.begins_with("--spacing="):
			spacing_arg = float(argument.get_slice("=", 1))
		if argument.begins_with("--group="):
			group = argument.get_slice("=", 1)
		elif argument.begins_with("--out="):
			out = argument.get_slice("=", 1)
	_run.call_deferred(group, out, only, spacing_arg, columns_arg)

func _run(group: String, out: String, only: PackedStringArray = [], spacing_arg := 0.0, columns_arg := 0) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1800, 1000)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.55, .57, .6)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(.8, .8, .82)
	env.environment.ambient_light_energy = .6
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	world.add_child(sun)
	var files: Array[String] = []
	for file in DirAccess.get_files_at("res://assets/models/" + group):
		if file.ends_with(".glb") and (only.is_empty() or only.has(file.get_basename())):
			files.append(file)
	var columns := 6 if columns_arg <= 0 else columns_arg
	var spacing := 2.2 if group != "nature" else 14.0
	if spacing_arg > 0.0:
		spacing = spacing_arg
	var labels: Array[Label3D] = []
	for i in files.size():
		var at := Vector3((i % columns) * spacing, 0, -(i / columns) * spacing)
		var node := InteriorModelKit.place(world, group + "/" + files[i].get_basename(), at, 0.0, 1.0, "bottom")
		InteriorModelKit.prepare_instance(node, 1)
		var label := Label3D.new()
		label.text = files[i].get_basename()
		label.pixel_size = .004 * spacing / 2.2
		label.position = at + Vector3(0, -.12 * spacing / 2.2, .4 * spacing / 2.2)
		label.modulate = Color.BLACK
		label.outline_size = 0
		world.add_child(label)
		labels.append(label)
		for axis: Array in [[Vector3.RIGHT, Color.RED], [Vector3.BACK, Color.BLUE]]:
			var marker := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3.ONE * .03 * spacing / 2.2 + (axis[0] as Vector3).abs() * .5 * spacing / 2.2
			marker.mesh = box
			var material := StandardMaterial3D.new()
			material.albedo_color = axis[1]
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			marker.material_override = material
			marker.position = at + (axis[0] as Vector3) * .25 * spacing / 2.2 + Vector3(0, .01, 0)
			world.add_child(marker)
	var rows := ceili(files.size() / float(columns))
	var center := Vector3((columns - 1) * spacing * .5, 0, -(rows - 1) * spacing * .5)
	var camera := Camera3D.new()
	camera.far = 2000.0
	world.add_child(camera)
	camera.fov = 40.0
	var distance := maxf(columns, rows) * spacing * .72
	camera.position = center + Vector3(0, distance * .3, distance + (rows - 1) * spacing * .5)
	camera.look_at(center + Vector3(0, spacing * .2, 0))
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(group + "_front.png"))
	camera.position = center + Vector3(0, distance * 1.25, .01)
	camera.look_at(center)
	for label in labels:
		label.rotation_degrees = Vector3(-90, 0, 0)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(group + "_top.png"))
	print("LINEUP_SAVED ", out, " ", files.size())
	quit(0)
