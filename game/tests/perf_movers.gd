extends SceneTree
## 0.26: which shadow-casting instances move every frame (each one makes every light that reaches it redraw its shadow).
var main: Node
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	for i in 200: await process_frame
	var before := {}
	var all := main.find_children("*", "GeometryInstance3D", true, false)
	for gi: GeometryInstance3D in all:
		before[gi] = gi.global_transform
	for i in 7: await process_frame
	var movers := {}
	for gi: GeometryInstance3D in all:
		if is_instance_valid(gi) and not gi.global_transform.is_equal_approx(before[gi]):
			var path := str(main.get_path_to(gi))
			var key := "/".join(path.split("/").slice(0, 3))
			if not movers.has(key): movers[key] = [0, 0]
			movers[key][0] += 1
			if gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: movers[key][1] += 1
	for key in movers:
		print("PERF_MOVER %4d moving, %4d cast shadows  %s" % [movers[key][0], movers[key][1], key])
	var skeletons := main.find_children("*", "Skeleton3D", true, false)
	var players := 0
	for ap: AnimationPlayer in main.find_children("*", "AnimationPlayer", true, false):
		if ap.is_playing(): 
			players += 1
			print("PERF_ANIM playing ", main.get_path_to(ap))
	print("PERF_SKELETONS ", skeletons.size(), " playing=", players)
	quit()
