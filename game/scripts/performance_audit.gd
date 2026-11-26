extends Node
## Rendered, wall-clock comparison. Never use --fixed-fps for this audit.
var main: Node
var out := "user://mobile-performance" if OS.has_feature("android") else "res://../docs/mobile-performance/optimized"
var seconds := 3.0
var rows: Array[Dictionary] = []
var boot_ms := 0

func start(scene: Node) -> void:
	main = scene
	main.set_meta("performance_audit",true)
	if OS.has_feature("android"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://performance-audit.json"))
	var root := get_tree().root
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg.begins_with("--seconds="): seconds = float(arg.trim_prefix("--seconds="))
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	if not OS.has_feature("android"):
		root.size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	boot_ms = Time.get_ticks_msec()
	print("MOBILE_PERFORMANCE_BOOT_MS ",boot_ms)
	main._play()
	var tier := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--audit-quality="): tier = int(arg.trim_prefix("--audit-quality="))
	main._apply_quality(tier)
	if "--baseline-mobile-shadows" in OS.get_cmdline_user_args():
		var rig := InteriorLighting.find_in(main.room)
		for light in rig._lights:
			if light.visible and light.get_meta("shadow",false):
				light.shadow_enabled = true
				break
	Engine.max_fps = 0
	main.player.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 5: await get_tree().process_frame
	var C := preload("res://scripts/canal_settlement.gd")
	var W := preload("res://scripts/canal_warren.gd")
	var views := [
		["room", Vector3(.62,1.58,1.3), Vector3(-.2,1.3,-2.35)],
		["street", Vector3(20.2,-1.32,6), Vector3(20.5,-1.65,31)],
		["town", Vector3(17.3,-1.32,48.8), Vector3(-8,-1.8,49)],
		["canal", C.at(4.7,C.CATWALK+1.6,6), C.at(4.3,C.CATWALK+1.3,22)],
		["warren", W.pos(1.75,W.DECK+1.58,6.6), W.pos(1.6,W.DECK+1.28,-3)],
		["fields", Vector3(22,-1.3,130), Vector3(0,-2,185)],
		["nichols", Vector3(-10,0,-66), Vector3(-12,1,-90)],
		["basement", Vector3(-15.4,-2.82,-93.2), Vector3(-20.5,-4.1,-99)]
	]
	var only := PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--views="): only = arg.trim_prefix("--views=").split(",")
		if arg == "--audit-no-interp": get_tree().physics_interpolation = false
		if arg.begins_with("--audit-ticks="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--audit-ticks="))
	for view in views:
		if only.is_empty() or str(view[0]) in only:
			await _view(view)
	var inventory := {"meshes":main.find_children("*","MeshInstance3D",true,false).size(),
		"bodies":get_tree().get_nodes_in_group("movable").size(),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)}
	var textures: Array[Dictionary] = []
	for path in ["res://assets/models/nature/tree_small_02_tree_small_02_leaves_diff_1k.png",
		"res://assets/models/nature/island_tree_01_island_tree_01_nor_gl_1k.jpg",
		"res://assets/outdoor/textures/rusty_metal_04/albedo.jpg"]:
		var texture := load(path) as Texture2D
		if texture != null: textures.append({"path":path,"size":str(texture.get_size()),"type":texture.get_class()})
	var report := {"renderer":RenderingServer.get_current_rendering_method(),
		"adapter":RenderingServer.get_video_adapter_name(),"boot_ms":boot_ms,
		"mobile":main.mobile,"viewport":str(root.size),"scale":root.scaling_3d_scale,
		"inventory":inventory,"textures":textures,"views":rows,"platform":OS.get_name(),"physical_phone_verified":false}
	FileAccess.open(out.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("MOBILE_PERFORMANCE ",JSON.stringify(report))
	get_tree().quit()

func _view(view: Array) -> void:
	var root := get_tree().root
	main.player.global_position = view[1] - Vector3.UP * 1.58
	main.player.camera.global_position = view[1]
	main.player.camera.look_at(view[2])
	main.player.camera.fov = 72
	main.player.reset_physics_interpolation()
	var warm_begin := Time.get_ticks_msec()
	var warm_frames := 0
	while Time.get_ticks_msec() - warm_begin < 2000 or warm_frames < 90:
		await get_tree().process_frame
		warm_frames += 1
	var samples: Array[float] = []
	var rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var cpu_render := 0.0
	var gpu_render := 0.0
	var setup_cpu := 0.0
	var draw_sum := 0.0
	var primitives_sum := 0.0
	var cpu_sum := 0.0
	var physics_sum := 0.0
	var begin := Time.get_ticks_usec()
	var previous := begin
	while Time.get_ticks_usec() - begin < seconds * 1000000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		samples.append((now-previous)/1000.0)
		previous = now
		draw_sum += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		primitives_sum += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		cpu_sum += Performance.get_monitor(Performance.TIME_PROCESS)*1000
		physics_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
		cpu_render += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		gpu_render += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		setup_cpu += RenderingServer.get_frame_setup_time_cpu()
	samples.sort()
	var count := samples.size()
	var row := {"view":view[0],"warmup_ms":Time.get_ticks_msec()-warm_begin-int(seconds*1000),"frames":count,"median_ms":samples[count/2],
		"p95_ms":samples[int(count*.95)],"p99_ms":samples[int(count*.99)],
		"mean_draws":draw_sum/count,"mean_primitives":primitives_sum/count,
		"mean_process_ms":cpu_sum/count,"render_cpu_ms":cpu_render/count,"render_gpu_ms":gpu_render/count,"setup_cpu_ms":setup_cpu/count,"mean_physics_ms":physics_sum/count,
		"video_memory_mb":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0,
		"active_bodies":Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)}
	rows.append(row)
	if "--breakdown" in OS.get_cmdline_user_args():
		_breakdown(str(view[0]))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(str(view[0])+".png"))
	print("MOBILE_PERFORMANCE_VIEW ",JSON.stringify(row))

## Triangles inside the camera frustum and within their visibility range, by area and by instance.
func _breakdown(label: String) -> void:
	var camera := main.player.camera as Camera3D
	var planes := camera.get_frustum()
	var eye := camera.global_position
	var by_area := {}
	var top: Array = []
	var cache := {}
	for node in main.find_children("*", "GeometryInstance3D", true, false):
		var gi := node as GeometryInstance3D
		if not gi.is_visible_in_tree():
			continue
		var mesh: Mesh = null
		var count := 1
		if gi is MeshInstance3D:
			mesh = (gi as MeshInstance3D).mesh
		elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh != null:
			mesh = (gi as MultiMeshInstance3D).multimesh.mesh
			count = (gi as MultiMeshInstance3D).multimesh.instance_count
		if mesh == null:
			continue
		var box := gi.global_transform * gi.get_aabb()
		var centre := box.get_center()
		var radius := box.size.length() * .5
		if gi.visibility_range_end > 0.0 and centre.distance_to(eye) - radius > gi.visibility_range_end:
			continue
		var inside := true
		for plane: Plane in planes:
			if plane.distance_to(centre) > radius:
				inside = false
				break
		if not inside:
			continue
		if not cache.has(mesh):
			var tris := 0
			for s in mesh.get_surface_count():
				if mesh is ArrayMesh:
					var n := (mesh as ArrayMesh).surface_get_array_index_len(s)
					tris += (n if n > 0 else (mesh as ArrayMesh).surface_get_array_len(s)) / 3
			cache[mesh] = tris
		var total: int = int(cache[mesh]) * count
		var parts := str(main.get_path_to(gi)).split("/")
		var key := "/".join(parts.slice(0, mini(3, parts.size())))
		by_area[key] = int(by_area.get(key, 0)) + total
		top.append([total, str(main.get_path_to(gi)), centre.distance_to(eye), gi.cast_shadow])
	top.sort_custom(func(a, b): return a[0] > b[0])
	var keys := by_area.keys()
	keys.sort_custom(func(a, b): return by_area[a] > by_area[b])
	print("PERF_BREAKDOWN ", label)
	for key in keys.slice(0, 8):
		print("   area %9d  %s" % [by_area[key], key])
	for row: Array in top.slice(0, 14):
		print("   inst %9d  %5.0f m  shadow=%d  %s" % [row[0], row[2], row[3], row[1]])
