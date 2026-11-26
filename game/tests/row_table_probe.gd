extends SceneTree
## 0.65 (diagnostic): the mart's table puzzle alone. Jumps to the mart, drags the first row table under the broken
## escalator the way the walk test does, printing where the table and the player are as it goes.
##   godot --headless --path game --script res://tests/row_table_probe.gd
var game
var session
var m
var os
var o: Vector3

func _initialize() -> void: run.call_deferred()

func frames(count: int) -> void:
	for i in count: await physics_frame

func here() -> Vector3: return game.player.global_position - o

func table_at(ti: int) -> Vector3: return (m.street.tables[ti] as RigidBody3D).global_position - o

func walk(pts: Array, ti: int, per := 900, jump := false) -> void:
	var player: InteriorPlayer = game.player
	Input.action_press("forward")
	if jump: Input.action_press("jump")
	var n := 0
	for p: Vector3 in pts:
		var tgt: Vector3 = o + p
		for step in per:
			var d := Vector2(tgt.x - player.global_position.x, tgt.z - player.global_position.z)
			if d.length() < .5: break
			player.rotation.y = atan2(-d.x, -d.y)
			session.team[session.local_id()].pos = player.global_position
			session.team[session.local_id()].yaw = player.rotation.y
			if jump and n % 14 == 0: player.request_jump()
			if n % 15 == 0: print("PROBE n=%d player %s table %s drag %s" % [n, str(here().snapped(Vector3.ONE * .01)), str(table_at(ti).snapped(Vector3.ONE * .01)), str(m.draggers.has(session.local_id()))])
			n += 1
			await physics_frame
		var c := player.get_last_slide_collision()
		print("PROBE reached-ish %s at %s against %s" % [str(p), str(here().snapped(Vector3.ONE * .01)), (str(c.get_collider()) + " " + str((c.get_position() - o).snapped(Vector3.ONE * .01))) if c != null else "nothing"])
	Input.action_release("forward")
	Input.action_release("jump")
	await frames(8)

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 20: await process_frame
	session = game.coop
	session.host()
	session.start_game()
	await frames(20)
	m = session.mission
	session.harmless = true
	o = m.Street.ORIGIN
	m.debug_jump("outermart")
	await frames(120)
	os = m.outer_street
	for k in m.enemies.keys():
		var z = m.enemies[k]
		if is_instance_valid(z): z.queue_free()
		m.enemies.erase(k)
	var ti: int = os.row_tables[0]
	var t := m.street.tables[ti] as RigidBody3D
	t.contact_monitor = true
	t.max_contacts_reported = 8
	print("PROBE start table %s yaw %.2f" % [str(table_at(ti)), t.global_rotation.y])
	game.player.reset_motion(o + Vector3(53.2, .15, 767.0))
	await frames(10)
	if "--no-table" in OS.get_cmdline_user_args():
		await walk([Vector3(50.0, .15, 773.6), Vector3(50.0, .15, 774.7)], ti)
		await walk([Vector3(50.0, 2.5, 775.8)], ti, 600, true)
		await walk([Vector3(50.0, 4.55, 780.6)], ti, 300)
		print("PROBE no-table climb at %s upstairs %s" % [str(here().snapped(Vector3.ONE * .01)), str(m.flags.get("outer_upstairs", false))])
		quit(0)
		return
	await walk([Vector3(47.4, .15, 768.9)], ti)
	m.grab(session.local_id(), ti)
	print("PROBE grab ", m.draggers.get(session.local_id()))
	await frames(4)
	await walk([Vector3(48.6, .15, 770.6), Vector3(50.0, .15, 772.4), Vector3(50.0, .15, 773.0)], ti, 1200)
	for k in 4:
		await frames(10)
		print("PROBE hold table %s yaw %.2f player %s contacts %s" % [str(table_at(ti).snapped(Vector3.ONE * .01)), t.global_rotation.y, str(here().snapped(Vector3.ONE * .01)), str(t.get_colliding_bodies().map(func(b): return b.name))])
	m.release(session.local_id())
	await frames(30)
	print("PROBE end table %s flag %s step %s" % [str(table_at(ti).snapped(Vector3.ONE * .01)), str(m.flags.get("outer_table", false)), str(os.table_step != null)])
	await walk([Vector3(50.0, .91, 774.3), Vector3(50.0, 2.5, 775.8)], ti, 500, true)
	await walk([Vector3(50.0, 4.55, 780.6)], ti)
	print("PROBE climb at %s upstairs %s" % [str(here().snapped(Vector3.ONE * .01)), str(m.flags.get("outer_upstairs", false))])
	quit(0)
