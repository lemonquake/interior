extends SceneTree
## 0.26: where a physics tick's time goes. Godot --headless --path game --script res://tests/perf_physics.gd
var main: Node

func _initialize() -> void:
	_run.call_deferred()

func _measure(label: String) -> void:
	for i in 20: await process_frame
	var begin := Time.get_ticks_usec()
	for i in 400: await process_frame
	print("PERF_PHYSICS %-34s %.3f ms a frame (one 60 Hz tick each)" % [label, (Time.get_ticks_usec() - begin) / 400000.0])

func _run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	for i in 60: await process_frame
	for i in 240: await physics_frame
	await _measure("everything")
	paused = true
	await _measure("tree paused")
	paused = false
	main.player.set_process(false)
	for node in main.find_children("*", "", true, false):
		if node.is_processing(): node.set_process(false)
	await _measure("no script _process")
	var by_script := {}
	for node in main.find_children("*", "", true, false):
		if node.is_physics_processing():
			var script: Script = node.get_script()
			var key := script.resource_path.get_file() if script != null else node.get_class()
			if not by_script.has(key): by_script[key] = []
			by_script[key].append(node)
	for key in by_script:
		for node: Node in by_script[key]: node.set_physics_process(false)
		await _measure("without %s x%d" % [key, by_script[key].size()])
	var animatable := main.find_children("*", "AnimatableBody3D", true, false)
	for body: AnimatableBody3D in animatable: body.sync_to_physics = false
	await _measure("no animatable sync x%d" % animatable.size())
	for node in main.find_children("*", "", true, false):
		if node.is_physics_processing_internal():
			node.set_physics_process_internal(false)
	await _measure("no internal physics process")
	PhysicsServer3D.set_active(false)
	await _measure("physics server off")
	quit()
