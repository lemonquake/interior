extends SceneTree
## 0.63: Outer Street walked end to end by the real player body (forward held, facing the next point: the player's
## own movement, its steps and slopes), every objective done the way play does it:
##   the lane -> the avenue -> in at the bus's back door, along the aisle, out at its front door -> the shutter
##   (chained) -> up the yellow stair -> the hardware store's bolt cutters (its back room opens) -> back down, cut the
##   chain -> down the well -> the power room's main breaker -> through the faregates, down to the platform -> in at
##   the train's open door, through both cars, out of the cab and down onto the track -> the tunnel -> the cross
##   passage -> the long stair -> the river road -> 0.65: Market Row: in at Airah's Pizzahan's smashed door, over the
##   counter (a vault), out by the kitchen's back door -> the court -> through the flats -> the alley -> the mart's
##   loading door -> a food-court table dragged under the broken escalator (it sets), onto the table, a jump for the
##   escalator's end, up -> through the broken wall into Azrin & Azrael -> down its stair, out of its window (stage
##   17) -> the long bridge, between the wrecks and past the hole in the deck (WON).
## The infected are cleared before each leg (this checks the way, not the fight). Also: the students reach the river.
##   godot --headless --path game --script res://tests/outer_street_walk.gd
var game
var session
var m
var os
var o: Vector3
var checks := 0
var failed := []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed.append(label)
	print("OUTER_WALK CHECK ", label, " ", ok)

func frames(count: int) -> void:
	for i in count: await physics_frame

func clear_infected() -> void:
	for k in m.enemies.keys():
		var z = m.enemies[k]
		if is_instance_valid(z) and not z.has_meta("boss"): z.queue_free()
		m.enemies.erase(k)

func here() -> Vector3: return game.player.global_position - o

## Walks to each point (street-local) in turn; returns how far short of the last one it ended.
func walk(pts: Array, per := 900, jump := false) -> float:
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
			# Climbing: the jump key pressed again and again (a climb starts on a press), and held (a jump's
			# hands catch the ledge while it is held).
			if jump and n % 14 == 0: player.request_jump()
			n += 1
			await physics_frame
		var miss := Vector2(tgt.x - player.global_position.x, tgt.z - player.global_position.z).length()
		if miss > .7:
			var c := player.get_last_slide_collision()
			print("OUTER_WALK short of %s at %s (%.2f m) against %s" % [str(p), str(here().snapped(Vector3.ONE * .01)), miss, (str(c.get_collider()) + " " + str((c.get_position() - o).snapped(Vector3.ONE * .01))) if c != null else "nothing"])
	Input.action_release("forward")
	Input.action_release("jump")
	await frames(8)
	session.team[session.local_id()].pos = player.global_position
	await frames(4)
	var last: Vector3 = o + pts[pts.size() - 1]
	return Vector2(last.x - player.global_position.x, last.z - player.global_position.z).length()

func act(want: String) -> bool:
	var id: int = session.local_id()
	session.team[id].pos = game.player.global_position
	var c: String = m.candidate(id)
	if c != want:
		print("OUTER_WALK candidate here is '%s', wanted '%s'" % [c, want])
		return false
	m.interact(id, want)
	await frames(20)
	return true

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
	m.debug_jump("outerstreet")
	await frames(90)
	os = m.outer_street
	check(os != null and m.stage == 16, "in Outer Street (stage %d)" % m.stage)
	# `-- --from=mart`: straight to the mart's loading door (the row's second half, the bridge).
	var left := 0.0
	if "--from=mart" in OS.get_cmdline_user_args():
		m.debug_jump("outermart")
		await frames(120)
		game.player.reset_motion(o + Vector3(58.25, .15, 757.6))
		session.team[session.local_id()].pos = game.player.global_position
		await frames(10)
	else:
		clear_infected()
		left = await walk([Vector3(44.0, 0, 612.0), Vector3(44.0, 0, 630.0), Vector3(40.2, 0, 644.0), Vector3(40.2, 0, 650.6)])
		check(left < .8 and bool(m.flags.get("outer_avenue", false)), "the lane, the avenue, to the bus's back door (%.2f short)" % left)
		clear_infected()
		left = await walk([Vector3(40.2, 0, 652.0), Vector3(39.5, .1, 652.0), Vector3(38.0, .36, 652.0), Vector3(38.0, .36, 655.0), Vector3(38.0, .36, 659.4), Vector3(38.4, .36, 660.3), Vector3(40.3, 0, 660.3), Vector3(40.3, 0, 664.5)])
		check(left < .8 and bool(m.flags.get("outer_pileup", false)), "in at the back door, along the aisle, out at the front (%s)" % str(here().snapped(Vector3.ONE * .1)))
		left = await walk([Vector3(36.0, 0, 666.5), Vector3(33.0, .15, 669.8)])
		check(bool(m.flags.get("outer_shutter_seen", false)), "at the subway's shutter")
		check(m.candidate(session.local_id()) == "outer_chained", "it is chained (%s)" % m.candidate(session.local_id()))
		clear_infected()
		left = await walk([Vector3(29.5, .15, 667.0), Vector3(16.0, 5.0, 667.0), Vector3(12.0, 5.0, 670.0), Vector3(9.0, 5.0, 684.6), Vector3(3.2, 5.0, 684.6), Vector3(2.0, 5.0, 684.5)])
		check(left < .8 and here().y > 4.5, "up the yellow stair, into the hardware store (%s)" % str(here().snapped(Vector3.ONE * .1)))
		check(await act("outer_cutters"), "took the bolt cutters")
		await frames(30)
		check(bool(m.flags.get("outer_cutters", false)) and os.back_door.collision_layer == 0, "the back room's door gave")
		check(m.enemies.size() >= 4, "what was in the back room is out (%d)" % m.enemies.size())
		clear_infected()
		left = await walk([Vector3(8.0, 5.0, 684.6), Vector3(12.0, 5.0, 670.0), Vector3(15.0, 5.0, 667.0), Vector3(28.6, .15, 667.0), Vector3(33.0, .15, 669.8)])
		check(left < .8, "back down the stair to the shutter (%.2f short)" % left)
		check(await act("outer_chain"), "cut the chain")
		await frames(160)
		check(bool(m.flags.get("outer_shutter", false)) and os._shutter_at > .9, "the shutter is up")
		clear_infected()
		left = await walk([Vector3(33.0, .15, 672.5), Vector3(33.0, -5.2, 683.4), Vector3(33.0, -5.2, 687.0), Vector3(47.0, -5.2, 687.0), Vector3(54.4, -5.2, 686.8)])
		check(left < .8 and here().y < -4.5, "down the well, across the concourse, into the power room (%s)" % str(here().snapped(Vector3.ONE * .1)))
		check(await act("outer_power"), "threw the main breaker")
		await frames(30)
		check(bool(m.flags.get("outer_power", false)) and os.flaps_shape.disabled, "the power's back, the faregates open")
		check(m.enemies.size() >= 5, "the platform came up (%d)" % m.enemies.size())
		clear_infected()
		left = await walk([Vector3(47.0, -5.2, 687.0), Vector3(33.0, -5.2, 692.0), Vector3(32.0, -5.2, 698.6), Vector3(29.5, -5.2, 699.6), Vector3(29.5, -10.2, 711.6), Vector3(30.0, -10.2, 718.0), Vector3(31.6, -10.2, 722.3)])
		check(left < .8 and bool(m.flags.get("outer_platform", false)), "through the faregates, down to the platform (%s)" % str(here().snapped(Vector3.ONE * .1)))
		clear_infected()
		left = await walk([Vector3(34.6, -10.15, 722.3), Vector3(34.6, -10.15, 731.0), Vector3(34.6, -10.15, 733.0), Vector3(34.6, -10.15, 748.0), Vector3(34.6, -10.15, 750.6), Vector3(34.6, -11.3, 753.8), Vector3(34.6, -11.3, 756.0)])
		check(left < .8 and bool(m.flags.get("outer_train", false)), "in at the train's door, through both cars, out of the cab onto the track (%s)" % str(here().snapped(Vector3.ONE * .1)))
		clear_infected()
		left = await walk([Vector3(34.6, -11.3, 770.0), Vector3(34.4, -11.3, 782.0), Vector3(31.4, -11.3, 782.0)])
		check(left < .8 and bool(m.flags.get("outer_exit", false)), "the tunnel to the emergency exit (%s)" % str(here().snapped(Vector3.ONE * .1)))
		left = await walk([Vector3(29.6, -11.0, 782.0), Vector3(10.0, 0, 782.0), Vector3(6.5, 0, 783.6), Vector3(6.5, 0, 788.5)])
		check(left < .8 and bool(m.flags.get("outer_up", false)) and m.stage == 16, "up the long stair, out onto the river road (stage %d, %s)" % [m.stage, str(here().snapped(Vector3.ONE * .1))])
		clear_infected()
		# Market Row. The road east is buried: in at the pizza place's broken door, over its counter.
		left = await walk([Vector3(14.0, 0, 790.0), Vector3(23.0, 0, 789.4), Vector3(23.0, .15, 786.6), Vector3(23.0, .15, 779.2)])
		check(left < .8, "in at Airah's Pizzahan's smashed door, to the counter (%s)" % str(here().snapped(Vector3.ONE * .1)))
		clear_infected()
		left = await walk([Vector3(23.0, .15, 776.2)], 400, true)
		check(here().z < 777.0 and bool(m.flags.get("outer_pizza", false)), "over the counter into the kitchen (%s)" % str(here().snapped(Vector3.ONE * .1)))
		left = await walk([Vector3(22.1, .15, 773.0), Vector3(22.1, .15, 771.0), Vector3(22.1, .15, 768.8)])
		check(left < .8 and bool(m.flags.get("outer_court", false)), "out by the kitchen's back door into the court (%s)" % str(here().snapped(Vector3.ONE * .1)))
		clear_infected()
		left = await walk([Vector3(28.0, .15, 763.0), Vector3(32.6, .15, 763.0), Vector3(34.6, .15, 758.0), Vector3(36.6, .15, 755.4), Vector3(40.8, .15, 755.4)])
		check(left < .8 and bool(m.flags.get("outer_alley", false)), "through the flats into the alley (%s)" % str(here().snapped(Vector3.ONE * .1)))
	clear_infected()
	left = await walk([Vector3(52.0, .15, 756.0), Vector3(58.25, .15, 758.4), Vector3(58.25, .15, 761.8), Vector3(53.2, .15, 762.6), Vector3(53.2, .15, 765.8)])
	check(left < .8 and bool(m.flags.get("outer_mart", false)), "in at the mart's loading door, through the stockroom (%s)" % str(here().snapped(Vector3.ONE * .1)))
	clear_infected()
	# The climb: a food-court table dragged under the broken escalator's end; onto it; a jump for the end.
	var ti: int = os.row_tables[0]
	left = await walk([Vector3(47.4, .15, 768.9)])
	m.grab(session.local_id(), ti)
	await frames(4)
	left = await walk([Vector3(48.6, .15, 770.6), Vector3(50.0, .15, 772.4), Vector3(50.0, .15, 773.0)], 1200)
	await frames(40)
	m.release(session.local_id())
	await frames(20)
	var tp: Vector3 = (m.street.tables[ti] as RigidBody3D).global_position - o
	check(bool(m.flags.get("outer_table", false)) and os.table_step != null, "dragged a table under the escalator's end: it set (%s)" % str(tp.snapped(Vector3.ONE * .01)))
	check(m.candidate(session.local_id()) != "table%d" % ti, "the set table is no longer offered to drag")
	left = await walk([Vector3(50.0, .91, 774.3), Vector3(50.0, 2.5, 775.8)], 500, true)
	left = await walk([Vector3(50.0, 4.55, 780.6)])
	check(here().y > 4.0 and bool(m.flags.get("outer_upstairs", false)), "onto the table, a jump for the escalator, up it (%s)" % str(here().snapped(Vector3.ONE * .1)))
	clear_infected()
	left = await walk([Vector3(52.0, 4.55, 780.6), Vector3(61.4, 4.55, 779.6), Vector3(62.0, 4.55, 774.8), Vector3(65.8, 4.55, 774.5), Vector3(68.8, 4.55, 774.5)])
	check(left < .8 and bool(m.flags.get("outer_boutique", false)), "across the top floor, through the broken wall into Azrin & Azrael (%s)" % str(here().snapped(Vector3.ONE * .1)))
	clear_infected()
	left = await walk([Vector3(70.0, 4.55, 771.2), Vector3(77.2, 4.55, 771.2), Vector3(78.1, 4.55, 771.6), Vector3(78.1, 4.55, 772.8), Vector3(78.1, .15, 779.4), Vector3(77.2, .15, 781.2), Vector3(76.3, .15, 784.4), Vector3(76.3, .15, 787.8)])
	check(left < .8 and m.stage == 17, "down the boutique's stair and out of its window: the finale (stage %d, %s)" % [m.stage, str(here().snapped(Vector3.ONE * .1))])
	check(m.enemies.size() >= 8, "the horde is coming (%d)" % m.enemies.size())
	# The students came the whole way behind the squad (the bus, the stairs, the train, the long stair, the row).
	var with_us := 0
	if m.escape != null:
		for f in m.escape.people:
			if is_instance_valid(f) and f.position.distance_to(game.player.global_position) < 24.0: with_us += 1
	check(m.escape == null or with_us >= 3, "Ma'am Teves and her students out on the road with the squad (%d of %d)" % [with_us, m.escape.people.size() if m.escape != null else 0])
	clear_infected()
	left = await walk([Vector3(80.0, 0, 795.0), Vector3(94.0, 0, 798.0), Vector3(94.0, 2.0, 816.0), Vector3(93.4, 2.0, 840.0), Vector3(94.0, 2.0, 870.0), Vector3(94.6, 2.0, 879.0), Vector3(94.6, 2.0, 888.0),
		Vector3(89.6, 2.15, 894.5), Vector3(89.6, 2.15, 906.0), Vector3(92.4, 2.0, 912.0), Vector3(94.6, 2.0, 919.0), Vector3(91.6, 2.0, 926.0), Vector3(91.6, 2.0, 950.0), Vector3(94.2, 2.0, 958.0)])
	check(left < .8, "up onto the bridge, round the wrecks, past the hole in the deck (%s)" % str(here().snapped(Vector3.ONE * .1)))
	clear_infected()
	left = await walk([Vector3(92.0, 2.0, 974.0), Vector3(92.6, 2.0, 990.0), Vector3(95.2, 2.0, 1018.0), Vector3(92.6, 2.0, 1034.0), Vector3(95.6, 2.0, 1048.0), Vector3(94.0, 2.0, 1064.0)])
	await frames(10)
	check(m.stage == m.WON, "across the bridge: WON (stage %d, %s)" % [m.stage, str(here().snapped(Vector3.ONE * .1))])
	print("INTERIOR_OUTER_WALK %s (%d checks) %s" % ["ok" if failed.is_empty() else "FAIL", checks, str(failed)])
	quit(0 if failed.is_empty() else 1)
