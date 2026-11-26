extends SceneTree
## 0.63 (owner: "no proper and visible path for the players to go down after the explosion", "a door that cannot be
## opened once you climb the ladder"). Walks a real player body:
##  1. the fifth floor's mechanical room door (up the ladder) is forced from inside and walked through into the corridor;
##  2. after the blast: the second floor's corridor is open from the fire escape's door to 208 (the desk wall thrown
##     down), through 208's blown-out wall, onto the lean-to's roof, down the rubble ramp into the field, and back up.
##   godot --headless --path game --script res://tests/school_way_down.gd
var game
var session
var m
var checks := 0
var failed := []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed.append(label)
	print("WAY_DOWN CHECK ", label, " ", ok)

func frames(count: int) -> void:
	for i in count: await physics_frame

## Walks the player to each point in turn (street-local) the way play does (forward held, facing the point: the
## player's own movement, steps, wading through chairs); returns how far from the last point it ended.
func walk(o: Vector3, pts: Array, _speed := 3.6, per := 140) -> float:
	var player: InteriorPlayer = game.player
	Input.action_press("forward")
	for p: Vector3 in pts:
		var tgt := o + p
		for step in per:
			var d := Vector2(tgt.x - player.global_position.x, tgt.z - player.global_position.z)
			if d.length() < .45: break
			player.rotation.y = atan2(-d.x, -d.y)
			session.team[session.local_id()].pos = player.global_position
			await physics_frame
		var miss := Vector2(tgt.x - player.global_position.x, tgt.z - player.global_position.z).length()
		if miss > .6:
			var c := player.get_last_slide_collision()
			print("WAY_DOWN short of %s at %s (%.2f m) against %s" % [str(p), str((player.global_position - o).snapped(Vector3.ONE * .01)), miss, (str(c.get_collider()) + " " + str((c.get_position() - o).snapped(Vector3.ONE * .01))) if c != null else "nothing"])
	Input.action_release("forward")
	await frames(10)
	var last: Vector3 = o + pts[pts.size() - 1]
	return Vector2(last.x - player.global_position.x, last.z - player.global_position.z).length()

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
	var o: Vector3 = m.Street.ORIGIN
	var H: float = m.SCHOOL.H
	var player: InteriorPlayer = game.player
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state

	# 1. The mechanical room's door.
	m.debug_jump("duct")
	await frames(40)
	var sc = m.school
	var dx: float = sc.mech_door_x
	player.reset_motion(o + Vector3(dx, 4 * H + .05, 526.0))
	session.team[session.local_id()].pos = player.global_position
	await frames(4)
	check(m.candidate(session.local_id()) == "mechdoor", "E at the mechanical room's door offers to force it (%s)" % m.candidate(session.local_id()))
	var ray := PhysicsRayQueryParameters3D.create(o + Vector3(dx, 4 * H + 1.0, 526.2), o + Vector3(dx, 4 * H + 1.0, 523.0), 2)
	check(not space.intersect_ray(ray).is_empty(), "shut, the door blocks the way out")
	m.interact(session.local_id(), "mechdoor")
	await frames(60)
	check(bool(m.flags.get("mechdoor", false)) and sc.mech_open, "forced open")
	check(space.intersect_ray(ray).is_empty(), "open, nothing between the room and the corridor at the door")
	player.reset_motion(o + Vector3(36.0, 4 * H + .05, 530.6))
	await frames(4)
	var left := await walk(o, [Vector3(36.0, 4 * H, 527.6), Vector3(dx, 4 * H, 527.2), Vector3(dx, 4 * H, 523.2)])
	check(left < .8, "walked from the ladder's top through the door into the corridor (%.2f m short)" % left)
	var r3: Array = sc.route(3)
	check(r3.size() == 8, "bots and the infected take the door now (route has %d points)" % r3.size())

	# 2. After the blast.
	m.debug_jump("blast")
	await frames(40)
	check(sc.blasted, "the gas store has gone up")
	ray = PhysicsRayQueryParameters3D.create(o + Vector3(53.5, H + .9, 523.3), o + Vector3(16.5, H + .9, 523.3), 2)
	var hit := space.intersect_ray(ray)
	check(hit.is_empty(), "second floor corridor open from the fire escape's door to 208 (%s)" % (str((hit.position - o).snapped(Vector3.ONE * .1)) if not hit.is_empty() else "clear"))
	player.reset_motion(o + Vector3(54.0, H + .05, 523.5))
	await frames(4)
	left = await walk(o, [Vector3(30.0, H, 523.2), Vector3(14.8, H, 523.4), Vector3(14.8, H, 526.0), Vector3(12.0, H, 530.5), Vector3(11.0, H, 533.0), Vector3(11.0, 3.0, 535.6), Vector3(11.0, 2.5, 539.0), Vector3(11.0, 0.0, 546.0), Vector3(11.0, 0.0, 548.0)], 3.6, 400)
	var lp: Vector3 = player.global_position - o
	check(left < .8 and absf(lp.y) < .5, "walked the corridor, through 208, over the roof and down the ramp into the field (%s, %.2f m short)" % [str(lp.snapped(Vector3.ONE * .1)), left])
	left = await walk(o, [Vector3(11.0, 0.0, 546.0), Vector3(11.0, 2.4, 539.4), Vector3(11.0, 3.0, 535.6), Vector3(11.0, H, 532.6)], 3.6, 200)
	lp = player.global_position - o
	check(left < .8 and lp.y > H - .4, "and back up the ramp and the slope into 208 (%s)" % str(lp.snapped(Vector3.ONE * .1)))
	print("INTERIOR_SCHOOL_WAY_DOWN %s (%d checks) %s" % ["ok" if failed.is_empty() else "FAIL", checks, str(failed)])
	quit(0 if failed.is_empty() else 1)
