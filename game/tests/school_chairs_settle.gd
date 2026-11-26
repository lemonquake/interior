extends SceneTree
## 0.59: every chair PILCST builds (school_props.gd bodies, put to sleep where they were laid) woken and let fall for
## two and a half seconds: one that drops more than 25 cm was hanging in the air, one thrown more than 80 cm sideways
## was inside something. Smaller moves (a chair on a flight easing down a step) are printed, not failed.
##   godot --headless --path game --script res://tests/school_chairs_settle.gd   (prints CHAIRS ok|FAIL)
var game

func _initialize() -> void: run.call_deferred()

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 30: await process_frame
	var s = game.coop
	s.host()
	s.start_game()
	for i in 20: await physics_frame
	var m = s.mission
	s.harmless = true
	m.debug_jump("floor2")
	for i in 30: await physics_frame
	for i in 1500:
		if not s._catching: break
		await process_frame
	for k in m.enemies.keys():
		if is_instance_valid(m.enemies[k]): m.enemies[k].queue_free()
		m.enemies.erase(k)
	var props = m.school.props
	var off: Vector3 = m.Street.ORIGIN
	var before := {}
	for i in props.props.size():
		var e: Dictionary = props.props[i]
		if e.kind != "chair": continue
		var body: RigidBody3D = e.body
		before[i] = body.global_position
		body.sleeping = false
	for i in 150: await physics_frame
	var bad: Array = []
	for i in before:
		var body: RigidBody3D = props.props[i].body
		var d: Vector3 = body.global_position - before[i]
		if d.y < -.06 or Vector2(d.x, d.z).length() > .3:
			print("CHAIR_MOVED dy %.2f at %s moved %s" % [d.y, str((before[i] - off).snapped(Vector3.ONE * .01)), str(d.snapped(Vector3.ONE * .01))])
		if d.y < -.25 or Vector2(d.x, d.z).length() > .8:
			bad.append([d.y, before[i] - off, d])
	bad.sort_custom(func(a, b): return a[0] < b[0])
	for b in bad: print("CHAIR_FELL dy %.2f at %s moved %s" % [b[0], str((b[1] as Vector3).snapped(Vector3.ONE * .01)), str((b[2] as Vector3).snapped(Vector3.ONE * .01))])
	print("CHAIRS %s checked %d fell %d" % ["ok" if bad.is_empty() else "FAIL", before.size(), bad.size()])
	s.end_session()
	quit(0)
