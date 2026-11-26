extends SceneTree
## 0.65 (diagnostic): what the camera draws, grouped by where it hangs in the tree. Every visible geometry instance
## inside its distance range and the camera's frustum counts its surfaces (one draw each, before shadows).
##   godot --path game --rendering-method gl_compatibility --script res://tests/draw_census.gd -- --mobile-test --quality=0 [--where=store|outer]
var main

func _initialize() -> void: call_deferred("_run")

func frames(n: int) -> void:
	for i in n: await process_frame

func _surfaces(g: GeometryInstance3D) -> int:
	if g is MeshInstance3D:
		var m: Mesh = (g as MeshInstance3D).mesh
		return m.get_surface_count() if m != null else 0
	if g is MultiMeshInstance3D:
		var mm: MultiMesh = (g as MultiMeshInstance3D).multimesh
		return mm.mesh.get_surface_count() if mm != null and mm.mesh != null and mm.visible_instance_count != 0 and mm.instance_count > 0 else 0
	if g is CPUParticles3D:
		var cm: Mesh = (g as CPUParticles3D).mesh
		return cm.get_surface_count() if cm != null and (g as CPUParticles3D).emitting else 0
	return 1

func census(label: String) -> void:
	await frames(30)
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	var planes := cam.get_frustum()
	var groups := {}
	var kinds := {}
	var total := 0
	var count := 0
	var small := 0
	for n in main.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree(): continue
		if not (g.layers & cam.cull_mask): continue
		var aabb := g.get_global_transform() * g.get_aabb()
		var c := aabb.get_center()
		var d := cam.global_position.distance_to(c)
		if g.visibility_range_end > 0.0 and d > g.visibility_range_end + g.visibility_range_end_margin: continue
		var inside := true
		for p: Plane in planes:
			# The AABB's corner furthest along the plane's normal (planes face outward).
			var far := Vector3(aabb.end.x if p.normal.x < 0 else aabb.position.x, aabb.end.y if p.normal.y < 0 else aabb.position.y, aabb.end.z if p.normal.z < 0 else aabb.position.z)
			if p.distance_to(far) > 0.0:
				inside = false
				break
		if not inside: continue
		var s := _surfaces(g)
		if s == 0: continue
		var path := str(main.get_path_to(g)).split("/")
		var key := "/".join(path.slice(0, mini(3, path.size() - 1)))
		if path.size() > 2 and path[2].begins_with("@CharacterBody3D"): key = "a figure (%s)" % g.get_class()
		if path.size() > 4 and path[2].begins_with("@Node3D"):
			# Inside a district: by the node it hangs from (named) and the mesh's own kind.
			var parent_name := str(g.get_parent().name)
			var mesh_kind := ""
			if g is MeshInstance3D and (g as MeshInstance3D).mesh != null:
				mesh_kind = (g as MeshInstance3D).mesh.get_class() + ("/shared" if (g as MeshInstance3D).mesh.resource_path != "" else "")
			key = "%s .. %s [%s] depth %d" % ["/".join(path.slice(0, 3)), parent_name.left(28), mesh_kind, path.size()]
		groups[key] = int(groups.get(key, 0)) + s
		var kind := g.get_class()
		kinds[kind] = int(kinds.get(kind, 0)) + s
		total += s
		count += 1
		if aabb.get_longest_axis_size() < .6: small += s
	var rows := []
	for k in groups: rows.append([groups[k], k])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	print("CENSUS %s: %d surfaces in %d instances (%d in things under 0.6 m), draw calls %d, objects %d" % [label, total, count, small,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))])
	print("CENSUS kinds ", kinds)
	for r in rows.slice(0, 40): print("CENSUS   %5d  %s" % [r[0], r[1]])

func _run() -> void:
	var quality := 0
	var where := "store"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quality="): quality = int(a.trim_prefix("--quality="))
		if a.begins_with("--where="): where = a.trim_prefix("--where=")
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(40)
	main.set_meta("performance_audit", true)
	var s = main.coop
	s.host()
	s.fill_bots()
	s.start_game()
	await frames(20)
	main._apply_quality(quality)
	var m = s.mission
	m.harmless = true
	if where == "store":
		for i in 4: m.debug_skip()
		m.wave_left = 0
		var stand: Vector3 = m.ground(m.Street.ORIGIN + Vector3(0, 0, 20))
		main.player.reset_motion(stand)
		main.player.rotation = Vector3(0, PI, 0)
		for id in s.bots.bots: s.bots.bots[id].body.global_position = stand + Vector3(randf_range(-1.5, 1.5), .1, -1.5)
		await census("store run")
		for i in 20: m.spawn(m.ground(stand + Vector3(randf_range(-3, 3), 0, 14 + i * .8)))
		await census("store run, 20 infected")
		for id in s.bots.bots:
			s.bots.bots[id].reserve = 300
			s.bots.bots[id].mag = 17
		await frames(150)
		await census("store run, squad shooting")
		await frames(200)
		await census("store run, after")
	elif where == "places":
		# 0.66: `--places=go:bridge,jump:siege` (the debug commands, in order, one game).
		var list := ""
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--places="): list = a.trim_prefix("--places=")
		for spec in list.split(","):
			var parts := spec.split(":")
			print("CENSUS > ", m.debug_command(1, "%s %s" % [parts[0], parts[1]]))
			for i in 1200:
				var cs = s.get("_chapter_screen")
				if s.get("_catching") != true and (cs == null or not cs.visible): break
				await process_frame
			await frames(90)
			await census(spec)
	else:
		for spot: Array in [["outerstreet", "Outer Street start"], ["outermart", "the mart"], ["outerbridge", "the bridge"]]:
			m.debug_jump(spot[0])
			await frames(120)
			await census(spot[1])
	if "--kits" in OS.get_cmdline_user_args(): _kit_report(m.street)
	s.end_session()
	quit()

## The district's kit meshes (direct children with a material override): what merging by everything but the colour
## would leave, and how many vertices.
var _tsolo := {}
func _kit_report(street: Node) -> void:
	var sigs := {}
	var total := 0
	var meshes := 0
	for c in street.get_children():
		var mi := c as MeshInstance3D
		if mi == null or mi.mesh == null or not (mi.material_override is StandardMaterial3D): continue
		var m := mi.material_override as StandardMaterial3D
		var verts := 0
		for i in mi.mesh.get_surface_count(): verts += (mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var sig := "x"
		if m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and not m.emission_enabled and m.next_pass == null and m.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL:
			sig = "%s|%s|%s|%.2f|%.2f|%.2f" % [m.albedo_texture.resource_path if m.albedo_texture != null else "-", str(m.uv1_triplanar), str(m.uv1_scale), m.roughness, m.metallic, m.metallic_specular]
		else:
			sig = "SOLO %s%s%s%s" % ["T" if m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED else "", "E%.1f" % m.emission_energy_multiplier if m.emission_enabled else "", "N" if m.next_pass != null else "", "U" if m.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL else ""]
		if sig == "SOLO T":
			var tk := "%s %s cull%d" % [m.albedo_texture.resource_path if m.albedo_texture else "-", str(m.albedo_color), m.cull_mode]
			_tsolo[tk] = int(_tsolo.get(tk, 0)) + 1
		if not sigs.has(sig): sigs[sig] = [0, 0]
		sigs[sig][0] += 1
		sigs[sig][1] += verts
		total += verts
		meshes += 1
	var trows := []
	for k in _tsolo: trows.append([_tsolo[k], k])
	trows.sort_custom(func(a, b): return a[0] > b[0])
	for r in trows.slice(0, 12): print("KITS  T x%d %s" % [r[0], r[1]])
	print("KITS %d meshes, %d vertices, %d groups after merging by colour" % [meshes, total, sigs.size()])
	var rows := []
	for k in sigs: rows.append([sigs[k][1], sigs[k][0], k])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for r in rows.slice(0, 30): print("KITS   %7d verts  %3d meshes  %s" % [r[0], r[1], str(r[2]).left(110)])
