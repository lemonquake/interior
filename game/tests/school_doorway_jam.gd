extends SceneTree
## 0.61 (owner: chairs heaped in a classroom doorway, and neither E nor T got the player past them): no chair is
## built standing in a doorway; a doorway jammed with a dozen chairs is walked through (player.gd wades through
## chairs that will not give); T flings the chairs in front clear (mission.gd `shove`).
##   godot --headless --path game --script res://tests/school_doorway_jam.gd   (prints DOORWAY_JAM ok|FAIL)
var game
var failed := []
var shots := ""

func shot(label: String) -> void:
	if shots == "": return
	for i in 3: await process_frame
	root.get_texture().get_image().save_png(shots.path_join(label + ".png"))
	print("JAM shot ", label)

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failed.append(label)
	print("JAM CHECK ", label, " ", ok)

func frames(n: int) -> void:
	for i in n: await physics_frame

func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(shots)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 30: await process_frame
	var s = game.coop
	s.host()
	s.start_game()
	await frames(20)
	var m = s.mission
	s.harmless = true
	m.debug_jump("floor2")
	await frames(30)
	for i in 1500:
		if not s._catching: break
		await process_frame
	for k in m.enemies.keys():
		if is_instance_valid(m.enemies[k]): m.enemies[k].queue_free()
		m.enemies.erase(k)
	var school = m.school
	var props = school.props
	var chairs: Array = []
	for e: Dictionary in props.props:
		if e.kind == "chair": chairs.append(e.body)

	# 1. No chair stands in a doorway as built.
	var in_lane := 0
	for lane: Array in school._door_lanes:
		for body: RigidBody3D in chairs:
			var t: Vector3 = body.position
			var inside := (t.z - float(lane[2])) * float(lane[3])
			if int(t.y / school.H + .2) == int(lane[0]) and absf(t.x - float(lane[1])) < .9 and inside > -1.2 and inside < 1.8: in_lane += 1
	check(in_lane == 0, "no chair built in a doorway (%d)" % in_lane)

	# An open doorway on this floor (no shut door in it).
	var lane: Array = []
	for l: Array in school._door_lanes:
		if int(l[0]) != 1: continue
		var shut := false
		for d: Dictionary in school.doors:
			if int(d.k) == 1 and absf(float(d.x) - float(l[1])) < .1: shut = true
		if not shut:
			lane = l
			break
	check(not lane.is_empty(), "an open doorway on the second floor")
	if lane.is_empty():
		finish(s)
		return
	var dx: float = lane[1]
	var wz: float = lane[2]
	var into: float = lane[3]
	var y: float = school.H
	# Any door leaf on its hinge out of the way: the jam is the chairs.
	for e: Dictionary in props.props:
		if e.kind == "door" and (e.body as Node3D).position.distance_to(Vector3(dx, y + 1.0, wz)) < 1.6:
			(e.body as RigidBody3D).collision_layer = 0
			(e.body as RigidBody3D).collision_mask = 0

	# 2. A dozen chairs jammed in the doorway, two high, the way the infected leave them.
	var jam: Array = []
	var n := 0
	for body: RigidBody3D in chairs:
		if n >= 14: break
		if body.position.y < y - .3 or body.position.y > y + 2.0: continue
		var row := n % 7
		var high := n / 7
		var p := Vector3(dx + (row % 3 - 1) * .42, y + .02 + high * .5, wz + into * (-.5 + (row / 3) * .5))
		body.transform = Transform3D(Basis(Vector3.UP, n * 1.3) * Basis(Vector3.RIGHT, .3 * (n % 2)), p)
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.sleeping = false
		props.woke(int(body.get_meta("coop_prop")))
		jam.append(body)
		n += 1
	await frames(90)
	var player: InteriorPlayer = game.player
	var start: Vector3 = school.to_global(Vector3(dx, y + .05, wz - into * 2.2))
	var goal_dir: Vector3 = (school.to_global(Vector3(dx, y, wz + into)) - school.to_global(Vector3(dx, y, wz))).normalized()
	var yaw := atan2(-goal_dir.x, -goal_dir.z)
	player.reset_motion(start)
	player.rotation.y = yaw
	s.team[1].pos = start
	s.team[1].yaw = yaw
	await frames(10)
	if not game.story.flashlight.on: game.story.flashlight.toggle()
	await shot("1-jammed-doorway")
	Input.action_press("forward")
	var got_in := false
	for i in 360:
		await physics_frame
		player.rotation.y = yaw
		var local: Vector3 = school.to_local(player.global_position)
		if i == 70: await shot("2-wading-through")
		if (local.z - wz) * into > 1.2:
			got_in = true
			print("JAM walked in after %.2f s" % (i / 60.0))
			break
	# On a little further: the chairs waded through stand in the way again once the player is off them.
	for i in 60:
		await physics_frame
		player.rotation.y = yaw
	Input.action_release("forward")
	var local: Vector3 = school.to_local(player.global_position)
	check(got_in, "walked through the jammed doorway (ended %.2f m in)" % ((local.z - wz) * into))
	await frames(100)
	var still := 0
	for chair: RigidBody3D in player._wading:
		var gap: Vector3 = chair.global_position - player.global_position
		if Vector2(gap.x, gap.z).length() > 1.3: still += 1
	check(still == 0, "the waded chairs block again once the player is off them (%d far ones left)" % still)

	# 3. T flings the chairs in front clear: pile them again in front of the player and shove.
	player.reset_motion(start)
	player.rotation.y = yaw
	s.team[1].pos = start
	s.team[1].yaw = yaw
	await frames(5)
	var before := {}
	var k := 0
	for body: RigidBody3D in jam:
		var p := Vector3(dx + (k % 3 - 1) * .42, y + .02 + (k / 6) * .5, wz - into * (1.2 - ((k / 3) % 2) * .5))
		body.transform = Transform3D(Basis(Vector3.UP, k * .9), p)
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.sleeping = false
		k += 1
	await frames(60)
	for body: RigidBody3D in jam: before[body] = body.global_position
	await shot("3-before-T")
	m._shove_ready.clear()
	m.shove(1)
	await frames(60)
	await shot("4-after-T")
	var moved := 0
	for body: RigidBody3D in jam:
		var d: Vector3 = body.global_position - before[body]
		print("JAM chair moved %.2f along, %.2f in all" % [d.dot(goal_dir), d.length()])
		if d.length() > .5: moved += 1
	print("JAM shove moved %d of %d chairs more than 0.5 m" % [moved, jam.size()])
	check(moved >= 6, "T threw the chairs in front aside (%d)" % moved)
	finish(s)

func finish(s) -> void:
	print("DOORWAY_JAM %s %s" % ["ok" if failed.is_empty() else "FAIL", str(failed)])
	s.end_session()
	quit(0)
