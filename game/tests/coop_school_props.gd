extends SceneTree
## 0.57: the school's chairs and classroom doors as bodies (scripts/coop/school_props.gd), host and client.
##   host:   godot --path game --script res://tests/coop_school_props.gd -- --network-host --sync=<dir>
##   client: godot --path game --script res://tests/coop_school_props.gd -- --peer --sync=<dir>
## The host: every chair and open door has a body; walking into a chair moves it and does not go through it; a tap
## of E shuts an open door and opens it again; walking into a shut door pushes it open; Hold E drags a chair. Then it
## writes where those props are; the client checks it has them in the same places, walks into a chair of its own
## (its push goes to the host and comes back) and writes where that chair is; the host checks it has it there too.
## Prints INTERIOR_SCHOOL_PROPS ok|FAIL.
var game
var session
var failed := []
var checks := 0
var sync_dir := ""
var finished := false

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed.append(label)
	print("PROPS CHECK ", label, " ", ok)

## While set (the host's own checks), the infected are taken away every tick: a crowd hunting the player at a door
## shoves it about (as it should) and would decide what the door does instead of the check.
var hush := false

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		if hush and session != null and session.mission != null:
			var m = session.mission
			for k in m.enemies.keys():
				if is_instance_valid(m.enemies[k]): m.enemies[k].queue_free()
				m.enemies.erase(k)

func stand(at: Vector3, yaw: float) -> void:
	var player: InteriorPlayer = game.player
	player.reset_motion(at)
	player.rotation.y = yaw
	if session.team.has(session.local_id()):
		session.team[session.local_id()].pos = at
		session.team[session.local_id()].yaw = yaw

## Face `target` from `from` (yaw as the game measures it: forward is -Z turned by yaw).
func yaw_to(from: Vector3, target: Vector3) -> float:
	var d := target - from
	return atan2(-d.x, -d.z)

func walk(count: int) -> void:
	game.player.touch_move = Vector2(0, -1)
	await frames(count)
	game.player.touch_move = Vector2.ZERO

## `-- --shots=<dir>` (a rendered run, not headless): the player's view saved at the moments that show the props.
var _shot_yet := false
func shot(name: String, look_at := Vector3.INF) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="): dir = a.trim_prefix("--shots=")
	if dir == "" or DisplayServer.get_name() == "headless": return
	if not _shot_yet:
		# (The chapter screen fades for a while after the catch-up.)
		_shot_yet = true
		var held: Vector3 = game.player.global_position
		for i in 240:
			await process_frame
		game.player.global_position = held
	if look_at.is_finite():
		var eye: Vector3 = game.player.camera.global_position
		var d := look_at - eye
		game.player.rotation.y = atan2(-d.x, -d.z)
		game.player.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	game.story.flashlight.set_on(true)
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))

func write(file: String, data: Dictionary) -> void:
	var f := FileAccess.open(sync_dir.path_join(file), FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()

func read(file: String, seconds: float) -> Dictionary:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if FileAccess.file_exists(sync_dir.path_join(file)):
			await frames(5)
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(sync_dir.path_join(file)))
			if parsed is Dictionary: return parsed
		await process_frame
	return {}

func v3(a: Array) -> Vector3: return Vector3(float(a[0]), float(a[1]), float(a[2]))
func arr(v: Vector3) -> Array: return [v.x, v.y, v.z]

## A chair of `props` standing upright on floor `k` inside a classroom, at least `room` m clear of other chairs and
## of `avoid`.
func upright_chair(props, k: int, H: float, avoid: Array) -> int:
	var best := -1
	for i in props.props.size():
		var e: Dictionary = props.props[i]
		if e.kind != "chair": continue
		var body: RigidBody3D = e.body
		var t: Transform3D = props._local(body)
		if absf(t.origin.y - k * H) > .05 or t.basis.y.dot(Vector3.UP) < .97: continue
		if t.origin.z > 520.6 or t.origin.z < 515.5 or t.origin.x < 1.5 or t.origin.x > 54.0: continue
		var clear := true
		for j in props.props.size():
			if j == i or props.props[j].kind != "chair": continue
			var c: Vector3 = props._local(props.props[j].body).origin
			if c.distance_to(t.origin) < .85 or c.distance_to(t.origin + Vector3(0, 0, 1.15)) < .7:
				clear = false
				break
		for a in avoid:
			if (a as Vector3).distance_to(t.origin) < 3.0: clear = false
		if clear:
			best = i
			break
	return best

func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sync="): sync_dir = a.trim_prefix("--sync=")
	if sync_dir != "": DirAccess.make_dir_recursive_absolute(sync_dir)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 20: await process_frame
	session = game.coop
	if "--peer" in OS.get_cmdline_user_args():
		await client()
	else:
		await host()
	finished = true
	report()

func host() -> void:
	session.host()
	var networked := "--network-host" in OS.get_cmdline_user_args()
	if networked:
		var limit := Time.get_ticks_msec() + 85000
		while session.team.size() < 2 and Time.get_ticks_msec() < limit: await process_frame
		check(session.team.size() == 2, "the client joined")
	# (The run's seed picks the school's layout: the same one every time this test runs.)
	seed(57)
	session.start_game()
	await frames(8)
	if networked:
		var until := Time.get_ticks_msec() + 30000
		while session.network_ready.size() < session.team.size() and Time.get_ticks_msec() < until: await process_frame
		check(session.network_ready.size() == session.team.size(), "the client is ready")
	var wait_until := Time.get_ticks_msec() + 60000
	while session.mission == null and Time.get_ticks_msec() < wait_until: await process_frame
	await frames(30)
	var m = session.mission
	session.harmless = true
	var r: Array = m.debug_jump("floor2")
	check(not r.is_empty() and m.school != null, "jumped to the second floor")
	m.flags.fired = (1 << m.school.doors.size()) - 1
	hush = true
	var props = m.school.props
	var o: Vector3 = m.Street.ORIGIN
	var H: float = m.SCHOOL.H
	stand(r[0], r[1])
	await frames(30)
	# (A jump this far catches the run up behind the chapter screen; nobody moves until it has gone.)
	var catch_until := Time.get_ticks_msec() + 60000
	while session.get("_catching") and Time.get_ticks_msec() < catch_until: await frames(5)
	await frames(30)

	# --- what has a body
	var count := {}
	var bodies := 0
	for e: Dictionary in props.props:
		count[e.kind] = int(count.get(e.kind, 0)) + 1
		if e.body != null and (e.body as RigidBody3D).get_child_count() > 0: bodies += 1
	print("PROPS kinds ", count)
	check(int(count.get("chair", 0)) >= 1000, "every chair is a body (%d)" % int(count.get("chair", 0)))
	check(int(count.get("door", 0)) >= 20, "the open and ajar doors are bodies (%d)" % int(count.get("door", 0)))
	check(not (props.props[0].body as RigidBody3D).freeze, "the host simulates them")

	# --- a door on the second floor, south side: tap shuts it, tap opens it, walking into it pushes it open
	var door := -1
	for i in props.props.size():
		var e: Dictionary = props.props[i]
		if e.kind == "door" and float(e.sign) > 0.0 and absf((e.body as Node3D).global_position.y - (o.y + H + 1.06)) < .1:
			# (One whose swing is clear: a classroom's rows of chairs packed behind a door hold it, as they would.)
			var h: Vector3 = (e.body as Node3D).global_position - o
			var clear := true
			for j in props.props.size():
				if props.props[j].kind != "chair": continue
				var c: Vector3 = props._local(props.props[j].body).origin
				if absf(c.y - H) < 1.0 and c.z < h.z + .3 and Vector2(c.x - h.x, c.z - h.z).length() < 1.45: clear = false
			if clear:
				door = i
				break
	check(door >= 0, "found an open door on the second floor")
	var dbody: RigidBody3D = props.body_of(door)
	var hinge := dbody.global_position
	var mouth := Vector3(hinge.x + .49, o.y + H, o.z + 523.4)
	stand(mouth, PI)
	await frames(10)
	var was: float = props.opening(door)
	print("PROPS door %d left open %.2f rad" % [door, was])
	await shot("01_door_left_open", hinge + Vector3(.3, -.3, -.6))
	session.handle(1, "prop/%d/.5,0,0" % door)
	await frames(2)
	session.handle(1, "letgo")
	await frames(200)
	check(props.opening(door) < .08, "a tap of E shuts the open door (%.2f -> %.2f)" % [was, props.opening(door)])
	await shot("02_door_tapped_shut", hinge + Vector3(.49, -.3, 0))
	check(props.opening(door) > -.05, "it stops in its frame, not through it (%.2f)" % props.opening(door))
	session.handle(1, "prop/%d/.5,0,0" % door)
	await frames(2)
	session.handle(1, "letgo")
	await frames(200)
	check(absf(props.opening(door) - props.DOOR_OPEN) < .15, "a second tap opens it (%.2f)" % props.opening(door))
	session.handle(1, "prop/%d/.5,0,0" % door)
	await frames(2)
	session.handle(1, "letgo")
	await frames(200)
	var shut: float = props.opening(door)
	# Walk at it from the corridor: it swings into the room.
	stand(mouth + Vector3(0, 0, 1.0), 0.0)
	var pushes := 0
	game.player.touch_move = Vector2(0, -1)
	var seen := {}
	# (Two chairs lie in this doorway: the player kicks them through ahead of the door.)
	for f in 300:
		await frames(1)
		for key in props._intents: if int(props._intents[key][0]) == door: pushes += 1
		for c in game.player.get_slide_collision_count():
			var sc: KinematicCollision3D = game.player.get_slide_collision(c)
			var who = sc.get_collider()
			var tag := "%s n=%s y=%.2f" % [who.name if who != null else "?", sc.get_normal().snapped(Vector3.ONE * .01), sc.get_position().y - game.player.global_position.y]
			seen[tag] = int(seen.get(tag, 0)) + 1
	print("PROPS contacts walking to the door: ", seen)
	game.player.touch_move = Vector2.ZERO
	await frames(30)
	print("PROPS walked to %s (door at z %.2f), %d ticks pushing it" % [game.player.global_position - o, hinge.z - o.z, pushes])
	for hgt in [.15, .5, 1.0, 1.6]:
		var eye: Vector3 = game.player.global_position + Vector3.UP * hgt
		var rq := PhysicsRayQueryParameters3D.create(eye, eye + Vector3(0, 0, -1.2), 2 | 4 | 32)
		rq.exclude = [game.player.get_rid()]
		var rh: Dictionary = game.player.get_world_3d().direct_space_state.intersect_ray(rq)
		if rh: print("PROPS ahead at %.2f m: %s %s meta=%s at z %.2f" % [hgt, rh.collider.name, rh.collider.get_class(), rh.collider.get_meta("coop_prop", -1), rh.position.z - o.z])
	check(props.opening(door) > shut + .35, "walking into the shut door pushes it open (%.2f -> %.2f)" % [shut, props.opening(door)])
	stand(mouth + Vector3(.25, 0, .5), 0.0)
	await shot("03_door_pushed_open_chairs_kicked", hinge + Vector3(.1, -.5, -.7))
	check(props.opening(door) <= props.DOOR_MAX + .1, "no further than its hinge lets it (%.2f)" % props.opening(door))
	# Hold E on its far edge from the doorway and back out into the corridor: it comes round after you.
	props.swing_to(door, props.DOOR_OPEN)
	await frames(200)
	var opened: float = props.opening(door)
	stand(mouth + Vector3(0, 0, -.45), 0.0)
	await frames(5)
	session.handle(1, "prop/%d/.8,0,0" % door)
	await frames(2)
	check(session.team[1].pdrag == door, "Hold E takes hold of the door")
	var pull_from: Vector3 = game.player.global_position
	for step in 90:
		var at := pull_from + Vector3(0, 0, step * .015)
		game.player.global_position = at
		session.team[1].pos = at
		await frames(1)
	session.handle(1, "letgo")
	await frames(30)
	check(props.opening(door) < opened - .3, "Hold E drags the door round (%.2f -> %.2f)" % [opened, props.opening(door)])

	# --- a chair: walking into it shoves it and does not pass through it
	var chair := upright_chair(props, 1, H, [hinge - o])
	check(chair >= 0, "found an upright chair in a second-floor classroom")
	var cbody: RigidBody3D = props.body_of(chair)
	var start := cbody.global_position
	var from := start + Vector3(.0, 0, 1.15)
	stand(from, yaw_to(from, start))
	await walk(70)
	await frames(30)
	var moved := cbody.global_position.distance_to(start)
	check(moved > .3, "walking into a chair shoves it (%.2f m)" % moved)
	var gap := Vector2(game.player.global_position.x - cbody.global_position.x, game.player.global_position.z - cbody.global_position.z).length()
	check(gap > .25, "the player did not walk through it (%.2f m apart)" % gap)
	check(cbody.global_basis.y.dot(Vector3.UP) > .8, "it slid on its feet (up %.2f)" % cbody.global_basis.y.dot(Vector3.UP))
	check(moved < 2.5, "it was pushed, not launched (%.2f m)" % moved)
	# Drag it with Hold E.
	var cstart := cbody.global_position
	stand(cstart + Vector3(0, 0, .9), 0.0)
	await frames(5)
	session.handle(1, "prop/%d/0,.45,0" % chair)
	await frames(2)
	check(session.team[1].pdrag == chair, "Hold E takes hold of the chair")
	var dfrom: Vector3 = game.player.global_position
	for step in 90:
		var at := dfrom + Vector3(0, 0, step * .015)
		game.player.global_position = at
		session.team[1].pos = at
		await frames(1)
	var grip_at := cbody.to_global(Vector3(0, .45, 0))
	var hand_at: Vector3 = game.player.global_position + Vector3(0, 0, -.9)
	var lag := Vector2(grip_at.x - hand_at.x, grip_at.z - hand_at.z).length()
	session.handle(1, "letgo")
	await frames(60)
	var dragged := cbody.global_position.distance_to(cstart)
	print("PROPS chair drag: hand to grip %.2f m at the end" % lag)
	check(dragged > .8, "the chair came along (%.2f m)" % dragged)
	stand(cbody.global_position + Vector3(1.7, 0, -.5), 0.0)
	await shot("04_chair_dragged", cbody.global_position + Vector3(0, .35, 0))
	# (A classroom chair dragged through its row shoves the next ones along: it can trail a little.)
	check(lag < .8, "it kept up with the hand (%.2f m behind)" % lag)
	check(session.team[1].pdrag == -1, "letting go leaves it")
	# The infected shove a chair as they walk through.
	await frames(60)

	# --- the client sees them where the host has them, and pushes one of its own
	if networked and sync_dir != "":
		var other := upright_chair(props, 1, H, [hinge - o, cbody.global_position - o, start - o])
		var settled := 0
		while settled < 400 and not props._active.is_empty():
			settled += 1
			await frames(1)
		await frames(20)
		var data := {"door": door, "chair": chair, "other": other, "at": {}}
		for i in [door, chair, other]:
			var t: Transform3D = props._local(props.body_of(i))
			data.at[str(i)] = arr(t.origin) + arr(t.basis.x) + arr(t.basis.y)
		# (The host takes a jump of more than 10 m in a client's pose for a glitch: a debug jump moves everyone from
		# here. This puts the client's place by the chair it is about to walk into.)
		for cid: int in session.team:
			if cid != 1 and not session.is_bot(cid): session.team[cid].pos = props.body_of(other).global_position + Vector3(0, 0, 1.15)
		write("host.json", data)
		var reply: Dictionary = await read("client.json", 60.0)
		check(not reply.is_empty(), "the client answered")
		if not reply.is_empty():
			var mine: Vector3 = props._local(props.body_of(other)).origin
			var theirs := v3(reply.at)
			check(mine.distance_to(v3(data.at[str(other)])) > .3, "the client's push moved the chair on the host (%.2f m)" % mine.distance_to(v3(data.at[str(other)])))
			check(mine.distance_to(theirs) < .08, "host and client agree where it ended (%.3f m)" % mine.distance_to(theirs))
			check(bool(reply.get("ok", false)), "the client's own checks passed")
		await frames(30)

func client() -> void:
	session.address = "127.0.0.1"
	session.join_game()
	var limit := Time.get_ticks_msec() + 85000
	while not session.active and Time.get_ticks_msec() < limit: await process_frame
	check(session.active, "joined the host's run")
	if not session.active: return
	var m = session.mission
	while (m.school == null or m.school.props.props.size() < 1000) and Time.get_ticks_msec() < limit + 60000: await process_frame
	check(m.school != null, "the school stands on the client")
	if m.school == null: return
	var props = m.school.props
	check((props.props[0].body as RigidBody3D).freeze, "the client's props are frozen and follow the host")
	var data: Dictionary = await read("host.json", 120.0)
	check(not data.is_empty(), "the host wrote where its props are")
	if data.is_empty(): return
	await frames(90)
	var ok := true
	for key: String in data.at:
		var want: Array = data.at[key]
		var t: Transform3D = props._local(props.body_of(int(key)))
		var off := t.origin.distance_to(v3(want))
		var turned := t.basis.x.dot(Vector3(want[3], want[4], want[5]))
		var good := off < .05 and turned > .995
		ok = ok and good
		check(good, "prop %s where the host has it (%.3f m, %.4f)" % [key, off, turned])
	# Its own push: stand by the host's chosen chair and walk into it.
	var other := int(data.other)
	var cbody: RigidBody3D = props.body_of(other)
	var start := cbody.global_position
	var from := start + Vector3(0, 0, 1.15)
	var catch_until := Time.get_ticks_msec() + 60000
	while session.get("_catching") and Time.get_ticks_msec() < catch_until: await frames(5)
	stand(from, yaw_to(from, start))
	await frames(20)
	var sent := 0
	game.player.touch_move = Vector2(0, -1)
	for f in 120:
		await frames(1)
		if not session._pushes.is_empty(): sent += 1
	game.player.touch_move = Vector2.ZERO
	print("PROPS client walked from %s to %s, %d ticks with a push queued; chapter screen %s" % [from, game.player.global_position, sent, session.get("_catching")])
	await frames(120)
	var moved := cbody.global_position.distance_to(start)
	check(moved > .3, "the client's walk into a chair moved it (round trip through the host: %.2f m)" % moved)
	ok = ok and moved > .3
	await frames(60)
	write("client.json", {"ok": ok and failed.is_empty(), "at": arr(props._local(cbody).origin)})
	await create_timer(3.0, true).timeout

func report() -> void:
	if not finished or checks < 6: failed.append("the run stopped early (%d checks)" % checks)
	print("PROPS %d checks, %d failed" % [checks, failed.size()])
	for f in failed: print("PROPS FAILED ", f)
	print("INTERIOR_SCHOOL_PROPS ", "ok" if failed.is_empty() else "FAIL")
	quit(0 if failed.is_empty() else 1)
