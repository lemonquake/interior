extends SceneTree
## 0.60: the trash kit (scripts/trash_kit.gd) under plain light, out of the game's night: a line-up of every kind
## and a messy patch as the canal lays it, plus the kit's numbers (triangles per kind, bytes).
##   godot --path game --script res://tests/trash_kit_review.gd -- --out=<dir>
var out := "res://../work/v60/trash"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	root.size = Vector2i(1280, 720)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.08, .08, .09)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(.55, .55, .6)
	env.environment.ambient_light_energy = .08 if "--dark" in OS.get_cmdline_user_args() else .6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(.24, .22, .2)
	gm.roughness = .9
	ground.material_override = gm
	world.add_child(ground)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.current = true
	# Line-up: each kind three times (its poses), labelled by order in KINDS.
	var lineup := Node3D.new()
	world.add_child(lineup)
	var t := InteriorTrash.new(lineup, 11)
	for i in InteriorTrash.KINDS.size():
		for k in 3:
			t.add(InteriorTrash.KINDS[i], Vector3(-2.75 + i * .5, 0, -.35 + k * .35))
	t.commit("Lineup")
	cam.global_position = Vector3(0, 1.25, 1.75)
	cam.look_at(Vector3(0, 0, -.05))
	cam.fov = 60
	await _shot("trash-lineup")
	cam.global_position = Vector3(-1.6, .5, .75)
	cam.look_at(Vector3(-1.6, 0, -.1))
	cam.fov = 50
	await _shot("trash-lineup-close-left")
	cam.global_position = Vector3(1.4, .5, .75)
	cam.look_at(Vector3(1.4, 0, -.1))
	await _shot("trash-lineup-close-right")
	lineup.queue_free()
	# A messy patch: a heap, a drift along a "wall" line, strays.
	var patch := Node3D.new()
	world.add_child(patch)
	var p := InteriorTrash.new(patch, 600017)
	p.cluster(Vector3(0, 0, 0), 1.25, 30)
	p.line(Vector3(-3, 0, -1.6), Vector3(3, 0, -1.6), 1.6, .3)
	p.cluster(Vector3(1.8, 0, .6), .6, 9)
	var squares := p.commit("Patch")
	cam.global_position = Vector3(0, 1.6, 3.0)
	cam.look_at(Vector3(0, 0, -.4))
	cam.fov = 62
	await _shot("trash-patch")
	cam.global_position = Vector3(.3, .75, 1.3)
	cam.look_at(Vector3(0, 0, 0))
	cam.fov = 55
	await _shot("trash-patch-close")
	var tris := InteriorTrash.triangle_counts()
	var verts := 0
	for k: String in tris: verts += int(tris[k]) * 3
	print("TRASH_KIT ", JSON.stringify({"triangles": tris, "kit_vertices": verts,
		"kit_vertex_bytes_approx": verts * 28, "instance_bytes": 64, "patch_pieces": p.count, "patch_squares": squares,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}))
	quit()

func _shot(label: String) -> void:
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(out.path_join(label + ".png")))
