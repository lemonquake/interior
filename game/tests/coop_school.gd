extends SceneTree
## 0.50: the Prof. Ivan Lawrence College of Science and Technology (scripts/coop/school.gd, mission stages 8-11).
## - the school is built when the backstreets wake; the story comes up near its back gate and turns its pages;
## - Rommel talks behind the gate, then opens it; once everyone is in the yard he shuts it and the backstreets go;
## - only students come out in the school; a floor reached first has its own, and a rush above the ground floor;
## - the students piled into the stairs block them; the open stair takes the infected up and down between floors
##   (school.gd `steer`) and the squad AI follows a player up;
## - room 501 opens only with the corridor clear; then the survivors (0.52: the way out is tests/coop_escape.gd).
##   godot --path game --script res://tests/coop_school.gd   (prints INTERIOR_SCHOOL ok|FAIL)
var game
var session
var failed := []
var checks := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed.append(label)
	print("SCHOOL CHECK ", label, " ", ok)

func frames(count: int) -> void:
	for i in count: await physics_frame

func stand(at: Vector3, yaw: float) -> void:
	var player: InteriorPlayer = game.player
	player.reset_motion(at)
	player.rotation.y = yaw
	session.team[1].pos = at
	session.team[1].yaw = yaw

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
	var o: Vector3 = m.Street.ORIGIN
	var H: float = m.SCHOOL.H

	# --- built with the backstreets' wake
	check(m.school == null, "no school before the backstreets wake")
	var r: Array = m.debug_jump("brickalley")
	check(not r.is_empty() and m.stage == 8, "jumped to the brick alley (stage %d)" % m.stage)
	check(m.school != null, "the school is built when the backstreets wake")
	check(m.school.built_usec < 2000000, "built in %d ms" % int(m.school.built_usec / 1000))
	var shapes := 0
	for b in m.school.bodies: shapes += b.get_child_count()
	check(shapes > 400, "the school is solid (%d collision shapes)" % shapes)

	# --- the story near the gate
	stand(o + Vector3(28, 0, 472), PI)
	await frames(30)
	check(m.flags.has("story") and int(m.flags.story) == 0, "the story comes up near the back gate")
	check(m.candidate(1) == "story", "E turns the page (%s)" % m.candidate(1))
	for i in 12:
		if m.stage != 8: break
		m.interact(1, "story")
		await frames(6)
	check(m.stage == 9, "after the last page, stage 9: the guard (%d)" % m.stage)

	# --- Rommel
	stand(o + Vector3(28.6, 0, 498.6), PI)
	await frames(10)
	check(m.candidate(1) == "guard", "E speaks to the guard at the gate (%s)" % m.candidate(1))
	m.interact(1, "guard")
	for i in 40:
		if m.stage != 9: break
		await frames(4)
		if m.candidate(1) == "listen": m.interact(1, "listen")
	check(m.stage == 10 and m.flags.get("school_gate", false), "his account, then the gate opens: stage 10")
	await frames(240)
	check(m.school.gate.position.x < m.school.GATE.x - 3.3 + o.x * 0, "the gate slid aside (%.2f)" % m.school.gate.position.x)
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var through := space.intersect_ray(PhysicsRayQueryParameters3D.create(o + Vector3(28, 1.0, 498.0), o + Vector3(28, 1.0, 503.0), 2))
	check(through.is_empty(), "nothing solid in the open gateway")
	var students_only := true
	# (0.66: only those inside the gate count: a straggler of the backstreets' trickle may still be coming up the
	# brick alley behind the squad, which is play.)
	for z in m.enemies.values():
		if (z.position - o).z < 497.0: continue
		if int(z.get_meta("kind")) < m.STUDENT_FIRST and not int(z.get_meta("kind")) in m.PARENTS: students_only = false
	if not students_only:
		for z in m.enemies.values():
			print("SCHOOL yard: kind %d at %s asleep %s mode %s" % [int(z.get_meta("kind")), str((z.position - o).snapped(Vector3.ONE * .1)), str(z.asleep), str(z.idle_mode)])
	check(m.enemies.size() > 0 and students_only, "the school's own in the yard (%d)" % m.enemies.size())
	if not students_only:
		for z in m.enemies.values():
			if int(z.get_meta("kind")) < m.STUDENT_FIRST and not int(z.get_meta("kind")) in m.PARENTS:
				print("SCHOOL not the school's own: kind %d at %s asleep %s" % [int(z.get_meta("kind")), str((z.position - o).snapped(Vector3.ONE * .1)), str(z.asleep)])

	# --- everyone in: the gate is shut behind them, the backstreets go
	stand(o + Vector3(28, 0, 506), PI)
	await frames(240)
	check(m.flags.get("school_shut", false), "Rommel shuts the gate once everyone is in the yard")
	check(m.school_unloaded, "the backstreets are put away")
	var bot_id: int = 0
	for id in session.team:
		if session.is_bot(id): bot_id = id
	check(bot_id != 0 and m.school.in_grounds(session.team[bot_id].pos), "the squad AI is in the yard too (%s)" % str(((session.team[bot_id].pos as Vector3) - o).snapped(Vector3.ONE * .1)))

	# --- the ground floor: its own lying about, students only
	for k in m.enemies.keys():
		m.enemies[k].queue_free()
		m.enemies.erase(k)
	stand(o + Vector3(28, 0, 518), PI)
	await frames(30)
	check(m.flags.get("floor0", false) and m.enemies.size() >= 8, "the ground floor's own (%d)" % m.enemies.size())
	students_only = true
	for z in m.enemies.values():
		var kind := int(z.get_meta("kind"))
		if kind < m.STUDENT_FIRST and not kind in m.PARENTS: students_only = false
	check(students_only, "only the school's own in the school (students, staff, parents)")
	var mix := {}
	for i in 400: mix[m._school_kind()] = true
	var staff := 0
	for kind in mix.keys(): if int(kind) >= m.TEACHER_FIRST: staff += 1
	check(staff >= 7, "teachers and the maintenance staff come too (%d kinds)" % staff)

	# --- the stairs: blocked ones, and the open ones
	var blocked := space.intersect_ray(PhysicsRayQueryParameters3D.create(o + Vector3(1.65, .9, 525.9), o + Vector3(1.65, 2.6, 530.4), 2))
	check(not blocked.is_empty(), "the west stair from the ground floor is blocked")
	var shut_e := space.intersect_ray(PhysicsRayQueryParameters3D.create(o + Vector3(54.35, H + 1.0, 526.0), o + Vector3(54.35, H + 2.7, 530.3), 2))
	check(not shut_e.is_empty(), "0.51: the east stair from the second floor is blocked too")
	var open_w := space.intersect_ray(PhysicsRayQueryParameters3D.create(o + Vector3(1.65, 2 * H + 1.0, 526.0), o + Vector3(1.65, 2 * H + 2.7, 530.3), 2))
	check(open_w.is_empty(), "the west stair from the third floor is open")
	for st in [Vector3(1.65, 3 * H + 1.0, 526.0), Vector3(54.35, 3 * H + 1.0, 526.0)]:
		var shut := space.intersect_ray(PhysicsRayQueryParameters3D.create(o + st, o + st + Vector3(0, 1.7, 4.3), 2))
		check(not shut.is_empty(), "both stairs from the fourth floor are blocked (%s)" % str(st))
	var fire_door := space.intersect_ray(PhysicsRayQueryParameters3D.create(o + Vector3(54.5, H + 1.2, 523.5), o + Vector3(57.5, H + 1.2, 523.5), 2))
	check(fire_door.is_empty(), "the second floor's fire door is open onto the landing")
	var via: Vector3 = m.school.steer(o + Vector3(14, 0, 523.5), o + Vector3(40, 3 * H, 523.5)) - o
	check(via.distance_to(Vector3(28, 0, 523.5)) < .1, "from the ground floor up, the way is the grand stair (%s)" % str(via))
	via = m.school.steer(o + Vector3(20, 2 * H, 523.5), o + Vector3(20, H, 523.5)) - o
	check(via.distance_to(Vector3(52.0, 2 * H, 523.5)) < .1, "from the third floor down, the fire escape (%s)" % str(via))
	via = m.school.steer(o + Vector3(10, 3 * H, 523.5), o + Vector3(10, 4 * H, 523.5)) - o
	check(via.distance_to(Vector3(38.8, 3 * H, 523.5)) < .1, "from the fourth floor up, the maintenance room (%s)" % str(via))

	# --- the squad AI follows up a floor (no door bursting on the way: they are tested below)
	m.flags.fired = (1 << m.school.doors.size()) - 1
	for k in m.enemies.keys():
		m.enemies[k].queue_free()
		m.enemies.erase(k)
	m.school_wait = 1e6
	session.bots.bots[bot_id].body.global_position = o + Vector3(28, .05, 518.5)
	session.team[bot_id].pos = o + Vector3(28, .05, 518.5)
	stand(o + Vector3(25.2, H, 523.5), PI * .5)
	var bot_y := -9.0
	for i in 160:
		await frames(10)
		bot_y = maxf(bot_y, session.bots.bots[bot_id].body.global_position.y - o.y)
		if bot_y > H - .3: break
	check(bot_y > H - .3, "the squad AI follows up the grand stair (top %.2f)" % bot_y)

	while session.team.size() > session.humans(): session.remove_bot()
	await frames(5)

	# --- an infected follows a survivor up the grand stair, and another one down the east stair
	for k in m.enemies.keys():
		m.enemies[k].queue_free()
		m.enemies.erase(k)
	m.school_wait = 1e6
	m.flags.floor1 = true
	m.flags.floor2 = true
	stand(o + Vector3(40, H, 523.5), PI * .5)
	await frames(10)
	var climber = m.spawn(m.ground(o + Vector3(18, 0, 523.5)), false, true)
	var best_y := -9.0
	for i in 300:
		await frames(10)
		if not is_instance_valid(climber): break
		best_y = maxf(best_y, climber.global_position.y - o.y)
		if climber.global_position.y - o.y > H - .3 and climber.global_position.distance_to(session.team[1].pos) < 4.0: break
	check(best_y > H - .3, "an infected on the ground floor climbs to the survivor on the second (top %.2f)" % best_y)
	check(is_instance_valid(climber) and climber.global_position.distance_to(session.team[1].pos) < 6.0, "and reaches them (%.1f m)" % (climber.global_position.distance_to(session.team[1].pos) if is_instance_valid(climber) else -1.0))
	for k in m.enemies.keys():
		m.enemies[k].queue_free()
		m.enemies.erase(k)
	stand(o + Vector3(50, H, 523.5), -PI * .5)
	await frames(10)
	var descender = m.spawn(m.ground(o + Vector3(40, 2 * H, 523.5)), false, true)
	var low_y := 99.0
	for i in 220:
		await frames(10)
		if not is_instance_valid(descender): break
		low_y = minf(low_y, descender.global_position.y - o.y)
		if descender.global_position.y - o.y < H + .3 and descender.global_position.distance_to(session.team[1].pos) < 4.0: break
	check(low_y < H + .3, "an infected on the third floor comes down the fire escape to the second (low %.2f)" % low_y)
	for k in m.enemies.keys():
		m.enemies[k].queue_free()
		m.enemies.erase(k)

	# --- 0.51: one follows up the maintenance ladder and through the duct to the fifth floor
	m.flags.floor3 = true
	m.flags.floor4 = true
	stand(o + Vector3(26, 4 * H, 523.5), PI * .5)
	await frames(10)
	var vent = m.spawn(m.ground(o + Vector3(30, 3 * H, 523.5)), false, true, m.STUDENT_FIRST)
	var top_y := -9.0
	var crawled := false
	for i in 500:
		await frames(10)
		if not is_instance_valid(vent): break
		top_y = maxf(top_y, vent.global_position.y - o.y)
		if m.school.in_duct(vent.global_position): crawled = true
		if vent.global_position.y - o.y > 4 * H - .3 and vent.global_position.distance_to(session.team[1].pos) < 4.0: break
	check(top_y > 4 * H - .3, "an infected on the fourth floor climbs the ladder (top %.2f)" % top_y)
	check(crawled, "and crawls through the duct")
	var vent_d: float = vent.global_position.distance_to(session.team[1].pos) if is_instance_valid(vent) else -1.0
	var vent_at: String = str((vent.global_position - o).snapped(Vector3.ONE * .1)) if is_instance_valid(vent) else ""
	check(is_instance_valid(vent) and vent_d < 6.0, "and reaches the survivor on the fifth (%.1f m, at %s, dead %s)" % [vent_d, vent_at, str(vent.dead) if is_instance_valid(vent) else "-"])
	for k in m.enemies.keys():
		m.enemies[k].queue_free()
		m.enemies.erase(k)

	# --- 0.51: a survivor climbs the ladder
	var player: InteriorPlayer = game.player
	stand(o + Vector3(36.0, 3 * H + .05, 532.7), PI)
	await frames(5)
	Input.action_press("forward")
	var climbed := -9.0
	for i in 60:
		await frames(5)
		climbed = maxf(climbed, player.global_position.y - o.y)
		if not player.on_ladder and player.global_position.y - o.y > 4 * H - .2: break
	Input.action_release("forward")
	await frames(10)
	check(climbed > 4 * H - .2 and player.global_position.y - o.y > 4 * H - .3, "the player climbs the ladder to the fifth floor (top %.2f, now %.2f)" % [climbed, player.global_position.y - o.y])

	# --- 0.51: a row of shut classroom doors pounds, then bursts
	m.school_wait = 1e6
	m.flags.fired = 0
	var group := -1
	for g in m.SCHOOL.AMBUSH.size():
		if "304" in m.SCHOOL.AMBUSH[g]: group = g
	stand(o + Vector3(44, 2 * H, 523.5), PI * .5)
	await frames(30)
	var pounding: int = int(m.flags.get("pound", 0))
	check(pounding != 0, "the doors pound when a survivor comes near (%d)" % pounding)
	for i in 60:
		await frames(10)
		var all_broke := true
		for d: int in m.school.groups[group]:
			if not m.school.doors[d].broken: all_broke = false
		if all_broke: break
	var broken := 0
	for d: int in m.school.groups[group]:
		if m.school.doors[d].broken: broken += 1
	check(broken == m.school.groups[group].size() and broken > 0, "then they give, one after another (%d)" % broken)
	check(m.enemies.size() >= 2 * broken, "and the class inside pours out (%d)" % m.enemies.size())
	var door_ray := space.intersect_ray(PhysicsRayQueryParameters3D.create(o + Vector3(38.8, 2 * H + 1.0, 523.6), o + Vector3(38.8, 2 * H + 1.0, 527.0), 2))
	check(door_ray.is_empty(), "the doorway is open now")
	for k in m.enemies.keys():
		m.enemies[k].queue_free()
		m.enemies.erase(k)

	# --- room 501
	m.flags.floor3 = true
	m.flags.floor4 = true
	# (0.52: she does not open while a door down the hall is still being beaten: those classes were met already.)
	m.flags.fired = (1 << m.school.doors.size()) - 1
	var door: Vector3 = o + m.SCHOOL.DOOR_501
	stand(door + Vector3(0, 0, .9), 0.0)
	await frames(10)
	check(m.candidate(1) == "survivors", "E knocks at room 501 (%s)" % m.candidate(1))
	var near = m.spawn(m.ground(door + Vector3(6, 0, 1.0)), false, true)
	await frames(2)
	m.interact(1, "survivors")
	check(m.stage == 10, "nobody opens with one of them close")
	if is_instance_valid(near): near.queue_free()
	for k in m.enemies.keys():
		m.enemies[k].queue_free()
		m.enemies.erase(k)
	await frames(2)
	m.interact(1, "survivors")
	check(m.stage == 11, "with the corridor clear they open: survivors found, Ma'am Teves (stage %d)" % m.stage)
	await frames(60)
	check(not session.last_results and m.escape.people.size() == 5, "the night goes on: Ma'am Teves and four students (0.52, tests/coop_escape.gd)")
	print("INTERIOR_SCHOOL %s (%d checks) %s" % ["ok" if failed.is_empty() else "FAIL", checks, str(failed)])
	quit(0 if failed.is_empty() else 1)
