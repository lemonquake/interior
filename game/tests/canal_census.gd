extends SceneTree
## 0.66 (diagnostic): what the canal settlement draws from the canal bridge, grouped by kind of node.
##   godot --path game --script res://tests/canal_census.gd -- [--place=bridge]
var main

func _initialize() -> void: call_deferred("_run")

func frames(n: int) -> void:
	for i in n: await process_frame

func _run() -> void:
	var place := "bridge"
	var node_name := "Canal settlement"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--place="): place = a.trim_prefix("--place=")
		if a.begins_with("--node="): node_name = a.trim_prefix("--node=")
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(40)
	var s = main.coop
	s.host()
	s.start_game()
	await frames(20)
	var m = s.mission
	m.harmless = true
	print(m.debug_command(1, "go " + place))
	await frames(90)
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	var planes := cam.get_frustum()
	var canal: Node = main.find_child(node_name, true, false)
	var groups := {}
	var total := 0
	var all := 0
	for n in canal.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree(): continue
		all += 1
		var aabb := g.get_global_transform() * g.get_aabb()
		var d := cam.global_position.distance_to(aabb.get_center())
		if g.visibility_range_end > 0.0 and d > g.visibility_range_end + g.visibility_range_end_margin: continue
		var inside := true
		for p: Plane in planes:
			var far := Vector3(aabb.end.x if p.normal.x < 0 else aabb.position.x, aabb.end.y if p.normal.y < 0 else aabb.position.y, aabb.end.z if p.normal.z < 0 else aabb.position.z)
			if p.distance_to(far) > 0.0:
				inside = false
				break
		if not inside: continue
		var surf := 1
		if g is MeshInstance3D: surf = (g as MeshInstance3D).mesh.get_surface_count() if (g as MeshInstance3D).mesh != null else 0
		var name := String(g.name)
		var cut := name.find(" - ")
		var key := g.get_class() + " " + (name.left(cut) if cut > 0 else name.rstrip("0123456789_ ").left(26)) + " <" + String(g.get_parent().name).rstrip("0123456789_ ").left(22) + ">"
		groups[key] = int(groups.get(key, 0)) + surf
		total += surf
	var rows := []
	for k in groups: rows.append([groups[k], k])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	print("CANAL %s: %d surfaces in view (%d instances visible in all)" % [place, total, all])
	for r in rows.slice(0, 45): print("CANAL   %4d  %s" % [r[0], r[1]])
	s.end_session()
	quit()
