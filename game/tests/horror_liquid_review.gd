extends SceneTree
## Render and inspect the integrated liquid on actual town receivers in both renderers.
const Liquid := preload("res://scripts/horror_liquid.gd")
var out := "res://../docs/horror-textures/liquid-forward"
var main: Node
var player: Node3D
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n:
		await process_frame

func shot(label: String, d: Decal) -> void:
	var up := d.global_basis.y.normalized()
	var eye := d.global_position + up * (1.5 if absf(up.y) < .3 else 1.8)
	if up.y > .5:
		eye += Vector3(0, 0, 1.3)
	player.camera.global_position = eye
	player.camera.look_at(d.global_position, Vector3.UP if up.y < .5 else Vector3.FORWARD)
	player.camera.fov = 68.0
	await frames(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(label + ".png"))

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	main._apply_quality(2)
	await frames(30)
	player = main.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	for layer: CanvasLayer in main.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var lamp := OmniLight3D.new()
	lamp.light_energy = 1.4
	lamp.omni_range = 6.0
	lamp.light_cull_mask = 0xFFFFF
	player.camera.add_child(lamp)
	var generated := get_nodes_in_group("red_liquid_decals")
	var fallback := get_nodes_in_group("compatibility_surface_decals")
	var wall: Decal
	var pool: Decal
	var smear: Decal
	for item in generated:
		var d := item as Decal
		if d.get_parent().name != "Town horror":
			continue
		if absf(d.global_basis.y.y) < .3 and wall == null:
			wall = d
		if d.texture_albedo.resource_path.ends_with("pool.png"):
			if pool == null or d.global_position.distance_to(Vector3(21.6, -2.84, 24.6)) < pool.global_position.distance_to(Vector3(21.6, -2.84, 24.6)):
				pool = d
		if d.texture_albedo.resource_path.ends_with("drag_smear.png"):
			if smear == null or d.global_position.distance_to(Vector3(21.6, -2.84, 24.6)) < smear.global_position.distance_to(Vector3(21.6, -2.84, 24.6)):
				smear = d
	if generated.size() < 100:
		failures.append("Expected integrated town and basement generated liquid decals")
	if RenderingServer.get_current_rendering_method() == "gl_compatibility" and fallback.size() < 100:
		failures.append("Expected Compatibility receiver meshes for the integrated decals")
	if RenderingServer.get_current_rendering_method() == "gl_compatibility" and smear != null:
		var road_mesh := smear.get_node_or_null(smear.get_meta("compatibility_mesh", NodePath())) as MeshInstance3D
		if road_mesh == null:
			failures.append("Open street smear has no Compatibility mesh")
		elif (road_mesh.global_transform * road_mesh.get_aabb()).position.y < -2.87:
			failures.append("Road smear is buried below the decorative asphalt sheets")
	for spec: Array in [["wall-splatter", wall], ["pooled-liquid", pool], ["drag-smear", smear]]:
		if spec[1] == null:
			failures.append("Missing " + spec[0])
		else:
			await shot(spec[0], spec[1])
	var triangles := 0
	for mesh: MeshInstance3D in fallback:
		triangles += mesh.mesh.surface_get_array_len(0) / 3
	var report := {"passed": failures.is_empty(), "failures": failures,
		"renderer": RenderingServer.get_current_rendering_method(), "generated_decals": generated.size(),
		"compatibility_meshes": fallback.size(), "compatibility_triangles": triangles}
	FileAccess.open(out.path_join("verification.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("HORROR_LIQUID_REVIEW ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
