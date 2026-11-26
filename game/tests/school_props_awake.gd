extends SceneTree
## 0.57: how many of the school's props are awake (simulated) after a jump in, second by second, and which kinds and
## floors: props that never settle cost every physics tick. Prints INTERIOR_PROPS_AWAKE lines.
##   godot --headless --path game --script res://tests/school_props_awake.gd
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 20: await process_frame
	var session = game.coop
	session.host()
	seed(57)
	session.start_game()
	for i in 8: await physics_frame
	var m = session.mission
	session.harmless = true
	m.debug_jump("floor2")
	var props = m.school.props
	for second in 20:
		for i in 60: await physics_frame
		var kinds := {}
		var spots := []
		for i: int in props._active:
			var e: Dictionary = props.props[i]
			var at: Vector3 = props._local(e.body).origin
			var key := "%s f%d" % [e.kind, int(round(at.y / 3.6))]
			kinds[key] = int(kinds.get(key, 0)) + 1
			if spots.size() < 6: spots.append("%s %s v%.2f" % [e.kind, at.snapped(Vector3.ONE * .1), (e.body as RigidBody3D).linear_velocity.length()])
		print("INTERIOR_PROPS_AWAKE t=%d awake=%d infected=%d %s %s" % [second + 1, props._active.size(), m.enemies.size(), kinds, spots])
	quit()
