extends SceneTree
## 0.52: out of PILCST with the survivors of 501 (scripts/coop/escape.gd, mission stages 11-15).
## - 501 opens on Ma'am Teves and four students; her talk; the door shuts only once everyone is inside;
## - the horde comes up the east stair and goes past the door to stand in the corridor, asleep;
## - the quiet rules: crouched past one is not heard, running past is; a shot wakes the lot; the squad AI's lights go
##   off and it does not shoot the ones standing asleep;
## - the fifth floor's fire door unchains (inside, E); the survivors follow down the fire escape; halfway down the
##   gas store goes up: 208's door off, the gallery down on the grand stair;
## - 208's wall is open onto the lean-to's roof, the roof holds, the field is below; the survivors follow off it;
## - the field: stage 15; at the rear gate the board, the school and its dead put away; READY: out (WON).
##   godot --path game --script res://tests/coop_escape.gd   (prints INTERIOR_ESCAPE ok|FAIL)
var game
var session
var failed := []
var checks := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed.append(label)
	print("ESCAPE CHECK ", label, " ", ok)

func frames(count: int) -> void:
	for i in count: await physics_frame

func stand(at: Vector3, yaw: float) -> void:
	var player: InteriorPlayer = game.player
	player.reset_motion(at)
	player.rotation.y = yaw
	session.team[1].pos = at
	session.team[1].yaw = yaw

func awake(m) -> int:
	var n := 0
	for z in m.enemies.values():
		if is_instance_valid(z) and not z.dead and z.hp > 0 and not z.asleep: n += 1
	return n

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 20: await process_frame
	session = game.coop
	session.host()
	session.add_bot()
	session.start_game()
	await frames(20)
	var m = session.mission
	session.harmless = true
	m.log_wakes = true
	var o: Vector3 = m.Street.ORIGIN
	var H: float = m.SCHOOL.H
	var bot: int = -1
	for id: int in session.team:
		if session.is_bot(id): bot = id
	game.story.flashlight.on = false
	session.team[1].light = false

	# --- 501
	var r: Array = m.debug_jump("floor5")
	check(not r.is_empty() and m.stage == 10, "on the fifth floor (stage %d)" % m.stage)
	# (Every floor already reached: nothing more comes out for arriving.)
	for f in 5: m.flags["floor%d" % f] = true
	# (The classes behind the shut doors were met on the way up.)
	m.flags.fired = (1 << m.school.doors.size()) - 1
	await frames(5)
	for k in m.enemies.keys():
		m.enemies[k].queue_free()
		m.enemies.erase(k)
	var door: Vector3 = o + m.SCHOOL.DOOR_501
	stand(door + Vector3(0, 0, .9), 0.0)
	await frames(10)
	m.interact(1, "survivors")
	check(m.stage == 11 and m.escape.people.size() == 5, "501 opens: Ma'am Teves and four students (stage %d, %d)" % [m.stage, m.escape.people.size()])
	await frames(90)
	check(m.school._door_501.rotation.y > 1.2, "the door swings in, the desks dragged aside (%.2f)" % m.school._door_501.rotation.y)
	var space: PhysicsDirectSpaceState3D = m.get_world_3d().direct_space_state
	check(space.intersect_ray(PhysicsRayQueryParameters3D.create(door + Vector3(.1, 1.0, .8), door + Vector3(.1, 1.0, -1.6), 2)).is_empty(), "the doorway is clear")
	check(m.candidate(1) == "listen", "E: listen to her (%s)" % m.candidate(1))
	for i in 40:
		if m.stage != 11: break
		m.interact(1, "listen")
		await frames(4)
	check(m.stage == 12, "after her talk, stage 12: the horde (%d)" % m.stage)

	# --- the door shuts once everyone is inside
	stand(door + Vector3(-1.0, 0, 1.0), 0.0)
	await frames(90)
	check(int(m.flags.get("horde", 0)) == 0 and int(m.flags.get("door501", 1)) == 1, "with someone still outside, the door waits")
	stand(o + Vector3(3.0, 4 * H, 516.2), PI)
	await frames(30)
	var bot_in: bool = bot == -1 or m.escape.in_501(session.team[bot].pos)
	check(bot_in, "the squad AI is in the room")
	for i in 60:
		if int(m.flags.get("horde", 0)) >= 1: break
		await frames(5)
	check(int(m.flags.get("door501", 1)) == 0 and int(m.flags.get("horde", 0)) >= 1, "everyone in: the door shuts, they are coming (%s)" % str(m.flags.get("horde")))
	check(bot == -1 or not bool(session.team[bot].light), "the squad AI's light is off")
	for i in 120:
		if int(m.flags.get("horde", 0)) >= 2: break
		await frames(5)
	# (0.66: they are made a few a tick, mission `later`: all of them in a few frames.)
	for i in 120:
		if m._later.is_empty(): break
		await frames(1)
	check(m.escape.horde.size() >= 16, "the horde comes up the east stair (%d)" % m.escape.horde.size())
	# (Faster than they would go, so the test does not stand an hour in the dark.)
	for z in m.escape.horde:
		if is_instance_valid(z):
			z.march_pace = 3.2
			z.stun = minf(z.stun, .4)
	for i in 400:
		if m.stage != 12: break
		await frames(5)
	check(m.stage == 13, "they have gone past and stopped: stage 13 (%d)" % m.stage)
	check(awake(m) == 0, "nobody heard: none of them awake (%d)" % awake(m))
	var west := 0
	for z in m.escape.horde:
		if is_instance_valid(z) and (z.position - o).x < 6.4 and absf((z.position - o).z - m.SCHOOL.CZ) < 1.6: west += 1
	check(west >= 3, "some of them went past 501's door to the west end (%d)" % west)
	for z in m.escape.horde:
		if is_instance_valid(z): print("HORDE %s %s asleep %s" % [z.idle_mode, str((z.position - o).snapped(Vector3.ONE * .1)), str(z.asleep)])

	# --- quiet rules
	var sleeper = null
	for z in m.escape.horde:
		if is_instance_valid(z) and z.idle_mode == "sleep" and (z.position - o).x > 18.0 and (z.position - o).x < 34.0:
			sleeper = z
			break
	check(sleeper != null, "one standing in the corridor")
	if sleeper != null:
		# Everyone else out of the way of it.
		var at: Vector3 = sleeper.position
		var side: float = -1.0 if (at - o).z > m.SCHOOL.CZ else 1.0
		var lane: float = o.z + m.SCHOOL.CZ + side * 1.08
		var p := Vector3(at.x - .6, at.y, lane)
		# (Only this one matters here: the others stand still too, and the squad AI waits out of it.)
		for z in m.escape.horde:
			if is_instance_valid(z) and z.asleep: z.idle_mode = "sleep"
		# (0.59: and none of the others standing in the lane itself, within touching distance of the walk: the horde
		# stands differently every run, and one in the lane was touched, failing the check one run in three.)
		for k in m.enemies.keys():
			var z = m.enemies[k]
			if not is_instance_valid(z) or z == sleeper: continue
			if absf(z.position.z - lane) < 1.0 and z.position.x > p.x - 1.0 and z.position.x < p.x + 2.4:
				z.queue_free()
				m.enemies.erase(k)
		while session.team.size() > session.humans(): session.remove_bot()
		stand(p, -PI * .5)
		m.moving[1] = [p, 0.0]
		await frames(20)
		# (Past it on the far side of the hall, in the gap between its neighbours on that side, at a crouch.)
		for i in 66:
			p.x += 1.1 / 60.0
			session.team[1].pos = p
			game.player.reset_motion(p)
			await physics_frame
		check(sleeper.asleep, "crouched past it (%.1f m) it does not hear" % absf(lane - at.z))
		p = Vector3(at.x + 3.0, at.y, o.z + m.SCHOOL.CZ)
		stand(p, PI * .5)
		m.moving[1] = [p, 0.0]
		await frames(30)
		for i in 60:
			p.x -= 4.6 / 60.0
			session.team[1].pos = p
			game.player.reset_motion(p)
			await physics_frame
		await frames(30)
		check(not sleeper.asleep, "running past it, it does")
	var before: int = awake(m)
	m.fired(1)
	await frames(90)
	# (0.59: "the rest": every one still asleep, however many the run past had already woken; it was "5 more",
	# which failed whenever running past had woken all but four.)
	var still := 0
	for z in m.enemies.values():
		if is_instance_valid(z) and not z.dead and z.hp > 0 and z.asleep: still += 1
	check(still == 0 and awake(m) > before, "a shot wakes the rest of them (%d -> %d, %d still asleep)" % [before, awake(m), still])
	for k in m.enemies.keys():
		m.enemies[k].queue_free()
		m.enemies.erase(k)

	# --- the fire door
	stand(o + Vector3(54.9, 4 * H, 523.5), -PI * .5)
	await frames(10)
	check(m.candidate(1) == "unchain", "E at the fire door: the chain (%s)" % m.candidate(1))
	m.interact(1, "unchain")
	await frames(100)
	check(bool(m.flags.get("fire5", false)) and m.school._fire_5.rotation.y > 1.2, "it swings out onto the landing")
	check(space.intersect_ray(PhysicsRayQueryParameters3D.create(o + Vector3(54.6, 4 * H + 1.0, 523.6), o + Vector3(57.4, 4 * H + 1.0, 523.6), 2)).is_empty(), "the way out onto the fire escape is open")

	# --- down the fire escape, the survivors behind; the blast
	m.escape.debug_place(o + Vector3(53.0, 4 * H, 523.5), -PI * .5)
	var mid := o + Vector3(57.9, 3 * H + 1.2, 527.6)
	stand(m.ground(mid), PI)
	var teves = m.escape.people[0]
	for i in 160:
		if (teves.position - o).x > 56.2: break
		await frames(5)
	check((teves.position - o).x > 56.0, "Ma'am Teves follows out onto the fire escape (%s)" % str((teves.position - o).snapped(Vector3.ONE * .1)))
	check(m.stage == 13, "still stage 13 above the fourth floor's landing")
	stand(m.ground(o + Vector3(56.65, 2 * H + 1.0, 527.4)), 0.0)
	await frames(10)
	check(m.stage == 14 and bool(m.flags.get("blast", false)), "halfway down: the gas store goes up, stage 14 (%d)" % m.stage)
	await frames(30)
	check(m.school._collapse.visible and m.school._collapse_body.collision_layer == 2, "the gallery comes down")
	var gallery: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(o + Vector3(25.2, H + 1.0, 523.8), o + Vector3(25.2, H + 1.0, 528.0), 2))
	check(not gallery.is_empty(), "the grand stair is buried (nothing gets into the gallery)")
	var i208 := -1
	for i in m.school.doors.size():
		if m.school.doors[i].room == "208": i208 = i
	check(i208 >= 0 and m.school.doors[i208].broken, "208's door is blown off")

	# --- 208's wall, the roof, the field
	var out: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(o + Vector3(11.0, H + .8, 530.5), o + Vector3(11.0, H + .8, 536.0), 2))
	check(out.is_empty(), "208's outer wall is open")
	var roof: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(o + Vector3(11.0, 5.0, 536.0), o + Vector3(11.0, 0.0, 536.0), 2))
	check(not roof.is_empty() and (roof.position.y - o.y) > 2.5 and (roof.position.y - o.y) < 3.2 and (roof.position.y - o.y) < H - .3, "the lean-to's roof is under it (%.2f)" % ((roof.position.y - o.y) if not roof.is_empty() else -1.0))
	# (0.63: a rubble ramp from the eave down into the field, its foot about 6 m out.)
	var ramp: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(o + Vector3(11.0, 3.0, 541.0), o + Vector3(11.0, -1.0, 541.0), 2))
	check(not ramp.is_empty() and (ramp.position.y - o.y) > 1.0 and (ramp.position.y - o.y) < 2.3, "the ramp down from the eave (%.2f)" % ((ramp.position.y - o.y) if not ramp.is_empty() else -1.0))
	var below: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(o + Vector3(11.0, 2.0, 547.0), o + Vector3(11.0, -1.0, 547.0), 2))
	check(not below.is_empty() and absf(below.position.y - o.y) < .2, "the field at the ramp's foot")
	m.escape.debug_place(o + Vector3(14.8, H, 523.5), 0.0)
	stand(m.ground(o + Vector3(11.0, 0, 546.0)), PI)
	await frames(10)
	check(m.stage == 15, "into the field: stage 15 (%d)" % m.stage)
	for i in 240:
		if (teves.position - o).z > 539.6 and (teves.position - o).y < 1.0: break
		await frames(5)
	check((teves.position - o).z > 539.6 and (teves.position - o).y < 1.0, "Ma'am Teves comes out through 208 and down off the roof (%s)" % str((teves.position - o).snapped(Vector3.ONE * .1)))
	var down_off := 0
	for i in 300:
		down_off = 0
		for f in m.escape.people:
			if (f.position - o).z > 536.0: down_off += 1
		if down_off >= 5: break
		await frames(5)
	var where: Array = []
	for f in m.escape.people: where.append((f.position - o).snapped(Vector3.ONE * .1))
	check(down_off >= 4, "the students behind her (%d of 5 outside: %s)" % [down_off, str(where)])
	var field := 0
	for z in m.enemies.values():
		if is_instance_valid(z) and (z.position - o).z > 536.0: field += 1
	check(field >= 8, "the field is full of them after the blast (%d)" % field)

	# --- the rear gate (0.53: shut until Heavy-arm's key opens it: tests/coop_heavyarm.gd has the fight)
	m.escape.fight.debug_finish()
	stand(m.ground(o + m.SCHOOL.REAR_GATE + Vector3(0, 0, -2.5)), PI)
	await frames(40)
	check(bool(m.flags.get("board", false)) and bool(m.flags.get("pilcst_out", false)), "at the rear gate: the board")
	# (0.66: Outer Street, once built at this board, brings Market Row's own posed dead (z > 700): not the college's.)
	var college_dead: Array = m.victims.filter(func(v): return is_instance_valid(v) and (v.where() - o).z < 616.0)
	check(m.enemies.is_empty() and m.corpses.is_empty() and college_dead.is_empty(), "the infected and the dead are gone (%d, %d, %d)" % [m.enemies.size(), m.corpses.size(), college_dead.size()])
	check(not m.school.roots[4].is_visible_in_tree(), "the school is put away")
	for id: int in session.team: session.team[id].next_ready = true
	await frames(60)
	check(m.stage == 16 and m.outer_street != null and bool(m.flags.get("outer_sealed_behind", false)), "everyone ready: entered Outer Street from PILCST (stage %d)" % m.stage)
	print("INTERIOR_ESCAPE %s (%d checks) %s" % ["ok" if failed.is_empty() else "FAIL", checks, str(failed)])
	quit(0 if failed.is_empty() else 1)
