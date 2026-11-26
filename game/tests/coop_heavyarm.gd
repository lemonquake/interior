extends SceneTree
## 0.53: Heavy-arm at PILCST's rear gate (scripts/coop/heavyarm.gd, heavyarm_body.gd).
## - he sits against the shut rear gate (chained: it does not open, no way through); his own clips and his size;
## - seen from across the field: the squad's lines, then up and roaring, the boss bar up;
## - rounds barely mark him; a fuel drum going up beside him takes a big piece and dazes him;
## - the charge: wound up (the lane shown), then run, the squad member in it thrown and hurt; a drum in its lane goes
##   up on him; the throw: three rings, the slabs land and hurt whoever is under them; the roar: a pack from behind
##   the squad (the arrow);
## - dead: the shining key; taken, the rear gate unlocks and swings open; at the gate the board (loading the next
##   chapter, READY waits for it); everyone ready: out (WON);
## - teammates' names are drawn however far, with the distance.
##   godot --path game --script res://tests/coop_heavyarm.gd   (prints INTERIOR_HEAVYARM ok|FAIL)
var game
var session
var failed := []
var checks := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed.append(label)
	print("HEAVYARM CHECK ", label, " ", ok)

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
	var bot: int = -1
	for id: int in session.team:
		if session.is_bot(id): bot = id
	game.story.flashlight.on = false

	# --- at the gate
	var r: Array = m.debug_jump("heavyarm")
	check(not r.is_empty() and m.stage == 15, "in the field (stage %d)" % m.stage)
	stand(o + Vector3(30.0, 0, 545.0), PI)
	var fight = m.escape.fight
	await frames(30)
	var boss = fight.boss
	check(boss != null and is_instance_valid(boss) and boss.has_meta("boss") and int(boss.get_meta("kind")) == m.HEAVY_KIND, "Heavy-arm is there")
	check(fight.state == "sit" and boss.anim_name == "heavy_sit", "sitting against the gate (%s, %s)" % [fight.state, boss.anim_name])
	check(boss.position.distance_to(o + fight.SEAT) < 1.0, "at the rear gate")
	check(is_equal_approx(boss.skeleton.motion_scale, 1.25), "his skeleton at his size (motion scale %.2f)" % boss.skeleton.motion_scale)
	for clip in ["heavy_sit", "heavy_rise", "heavy_walk", "heavy_wind", "heavy_charge", "heavy_dig", "heavy_throw", "heavy_inhale", "heavy_daze", "boss_roar", "boss_slam"]:
		if not boss.clips.has_animation(clip): check(false, "clip %s" % clip)
	await frames(30)
	var hips: Vector3 = boss.skeleton.global_transform * boss.skeleton.get_bone_global_pose(boss.skeleton.find_bone("hips")).origin
	check(hips.y - boss.position.y < .45, "sat on the ground (hips %.2f up)" % (hips.y - boss.position.y))
	check(fight.barrels.size() == fight.BARRELS.size(), "the fuel drums stand along the far end (%d)" % fight.barrels.size())
	var space: PhysicsDirectSpaceState3D = m.get_world_3d().direct_space_state
	var g: Vector3 = o + m.SCHOOL.REAR_GATE
	check(not space.intersect_ray(PhysicsRayQueryParameters3D.create(g + Vector3(.6, 1.0, -1.0), g + Vector3(.6, 1.0, 1.5), 2)).is_empty(), "the rear gate is shut (solid)")
	check(m.candidate(1) == "", "nothing to do from across the field")
	await frames(10)
	check(fight.state == "sit", "still sitting, the squad far off")

	# --- seen (from west of the covered court's stage: its back wall hides the gate from the court)
	stand(o + Vector3(30.0, 0, 580.0), 0.0)
	await frames(20)
	check(fight.state == "talk", "seen from across the field: the talk (%s)" % fight.state)
	var said := false
	for i in 110:
		await frames(20)
		if m.text_line.find("Mang Dado") >= 0: said = true
		if fight.state != "talk": break
	check(said, "Ma'am Teves knows him: Mang Dado")
	await frames(10)
	check(fight.state in ["rise", "fight"], "he gets up (%s)" % fight.state)
	for i in 40:
		await frames(10)
		if fight.state != "rise": break
	check(fight.state != "sit" and fight.state != "rise", "up and fighting (%s)" % fight.state)
	await process_frame
	check(fight._bar_box.visible, "the boss bar is up")
	check(m.objective().find("Heavy-arm") >= 0, "the objective names him")
	# The gate: shut, and no key yet.
	boss.position = m.ground(o + Vector3(30.0, 0, 580.0))
	boss.reset_physics_interpolation()
	fight.melee_wait = 99.0
	fight.special_wait = 99.0
	stand(g + Vector3(-1.8, 0, -1.4), 0.0)
	await frames(2)
	check(m.candidate(1) == "gatelocked", "at the gate: chained and padlocked (%s)" % m.candidate(1))
	stand(o + Vector3(36.0, 0, 570.0), 0.0)

	# --- rounds barely mark him
	fight.melee_wait = 99.0
	fight.special_wait = 99.0
	var before: float = fight.hp
	m.damage(1, boss.key, "chest", boss.position + Vector3.UP * 1.5, Vector3.FORWARD, 50.0, 60.0)
	var chest_cut: float = before - fight.hp
	before = fight.hp
	m.damage(1, boss.key, "head", boss.position + Vector3.UP * 2.1, Vector3.FORWARD, 50.0, 60.0)
	var head_cut: float = before - fight.hp
	check(chest_cut > 0.0 and chest_cut < 15.0 and head_cut > chest_cut, "rounds barely mark him (chest %.1f, head %.1f of %.0f)" % [chest_cut, head_cut, fight.max_hp])

	# --- a drum beside him
	var drum: int = 1
	var drum_at: Vector3 = fight.barrel_at(drum)
	boss.position = m.ground(drum_at + Vector3(1.6, 0, 0))
	boss.reset_physics_interpolation()
	before = fight.hp
	fight.barrel_hit(1, drum, 100.0)
	await frames(30)
	check((int(m.flags.get("drums", 0)) & (1 << drum)) != 0, "the drum went up")
	check(before - fight.hp > fight.BARREL_DAMAGE * .5, "it took a big piece of him (%.0f)" % (before - fight.hp))
	check((int(m.flags.get("drums", 0)) & 1) != 0, "the drum beside it went up too")
	check(fight.state == "daze", "dazed by it (%s)" % fight.state)
	check(fight.barrels[drum] == null, "gone from the field")
	for i in 30:
		await frames(10)
		if fight.state != "daze": break

	# --- the charge
	session.harmless = false
	session.team[1].hp = 200
	if bot != -1: session.team[bot].hp = 0
	boss.position = m.ground(o + Vector3(24.0, 0, 567.0))
	boss.reset_physics_interpolation()
	stand(o + Vector3(24.0, 0, 553.0), 0.0)
	await frames(2)
	fight.debug_force("charge")
	await frames(10)
	var b: Dictionary = m.flags.get("boss", {})
	check(fight.state == "wind_charge" and b.has("lane"), "the charge wound up, the lane shown (%s)" % fight.state)
	await frames(1)
	check(fight._lane != null and fight._lane.visible, "the lane drawn on the ground")
	for i in 40:
		await frames(5)
		stand(o + Vector3(24.0, 0, 553.0), 0.0)
		if fight.state == "charge": break
	check(fight.state == "charge", "then he runs it")
	for i in 60:
		await frames(2)
		stand(game.player.global_position, 0.0)
		if fight.state != "charge": break
	check(int(session.team[1].hp) < 200, "in the lane: thrown and hurt (%d)" % int(session.team[1].hp))
	check(game.player._thrown.length() > .5 or game.player.velocity.length() > 2.0 or int(session.team[1].hp) < 200, "thrown")
	await frames(120)
	# A drum in the lane goes up on him.
	session.team[1].hp = 200
	drum = 9
	drum_at = fight.barrel_at(drum)
	fight._go("fight")
	boss.position = m.ground(drum_at + Vector3(0, 0, -9.0))
	boss.reset_physics_interpolation()
	stand(drum_at + Vector3(0, 0, 4.0), 0.0)
	await frames(2)
	before = fight.hp
	fight.debug_force("charge")
	for i in 120:
		await frames(4)
		stand(drum_at + Vector3(0, 0, 4.0), 0.0)
		if (int(m.flags.get("drums", 0)) & (1 << drum)) != 0: break
	check((int(m.flags.get("drums", 0)) & (1 << drum)) != 0, "a drum in his lane went up on him")
	check(before - fight.hp > fight.BARREL_DAMAGE * .5 and fight.state == "daze", "and hurt and dazed him (%.0f, %s)" % [before - fight.hp, fight.state])
	for i in 30:
		await frames(10)
		if fight.state != "daze": break

	# --- the throw
	session.team[1].hp = 200
	boss.position = m.ground(o + Vector3(20.0, 0, 580.0))
	boss.reset_physics_interpolation()
	stand(o + Vector3(20.0, 0, 560.0), PI)
	await frames(2)
	fight.debug_force("throw")
	await frames(20)
	b = m.flags.get("boss", {})
	check(fight.state == "wind_throw" and (b.get("marks", []) as Array).size() == 3, "the throw wound up: three rings")
	for i in 60:
		await frames(5)
		stand(o + Vector3(20.0, 0, 560.0), PI)
		if fight.state == "throw": break
	for i in 60:
		await frames(5)
		stand(o + Vector3(20.0, 0, 560.0), PI)
		if not fight.rocks.is_empty(): break
	check(not fight.rocks.is_empty() and (m.flags.boss.get("rocks", []) as Array).size() >= 3, "three slabs in the air")
	await frames(2)
	check(fight._rocks.size() >= 3, "drawn flying")
	for i in 60:
		await frames(5)
		stand(o + Vector3(20.0, 0, 560.0), PI)
		if fight.rocks.is_empty(): break
	check(fight.rocks.is_empty() and int(session.team[1].hp) < 200, "they landed, on the one under them (%d)" % int(session.team[1].hp))

	# --- the roar
	session.harmless = true
	for i in 30:
		await frames(5)
		if fight.state == "fight": break
	var count: int = m.enemies.size()
	stand(o + Vector3(20.0, 0, 560.0), PI)
	fight.debug_force("roar")
	check(fight.state == "wind_roar", "the roar wound up")
	for i in 80:
		await frames(5)
		stand(o + Vector3(20.0, 0, 560.0), PI)
		if fight.horde_at.is_finite(): break
	check(m.enemies.size() >= count + 4, "a pack called (%d -> %d)" % [count, m.enemies.size()])
	var centre: Vector3 = session.team[1].pos
	var from_boss: Vector3 = Vector3(centre.x - fight.horde_boss.x, 0, centre.z - fight.horde_boss.z).normalized()
	check((fight.horde_at - centre).normalized().dot(from_boss) > .3, "from behind the squad (away from him)")
	await process_frame
	await process_frame
	check(fight._arrow.visible, "the arrow toward them")

	# --- down: the key, the gate
	m.escape.fight.blast(1, 99999.0)
	await frames(30)
	check(fight.state == "dead" and boss.dead and m.corpses.has(boss), "Heavy-arm down, a ragdoll")
	var key = m.flags.get("heavy_key")
	check(key is Vector3, "the key dropped")
	await process_frame
	check(fight._key_node != null and fight._key_node.is_inside_tree(), "shining where it fell")
	stand(key, 0.0)
	await frames(2)
	check(m.candidate(1) == "heavykey", "E takes it (%s)" % m.candidate(1))
	m.interact(1, "heavykey")
	for i in 3: await process_frame
	check(bool(m.flags.get("heavy_key_taken", false)) and fight._key_node == null, "taken")
	stand(g + Vector3(-1.8, 0, -1.4), 0.0)
	await frames(2)
	check(m.candidate(1) == "reargate", "at the gate with the key (%s)" % m.candidate(1))
	m.interact(1, "reargate")
	for i in 30:
		await frames(10)
		m.school.sync(m.flags, 1.0 / 60.0, game.player.global_position)
	check(space.intersect_ray(PhysicsRayQueryParameters3D.create(g + Vector3(.6, 1.0, -1.0), g + Vector3(.6, 1.0, 1.5), 2)).is_empty(), "the gate swung open, the way clear")

	# --- names however far
	if bot != -1:
		session.team[bot].hp = 200
		session.team[bot].pos = game.player.global_position + Vector3(0, 0, -60.0)
		session.update_avatars()
		await process_frame
		session.update_avatars()
		var a = session.avatars.get(bot)
		check(a != null and a.caption.fixed_size and a.caption.visibility_range_end == 0.0 and a.caption.text.ends_with(" m"), "a teammate's name 60 m off, with the distance (%s)" % (a.caption.text if a != null else "none"))

	# --- out
	stand(g + Vector3(0, 0, -1.5), 0.0)
	if bot != -1: session.team[bot].pos = g + Vector3(1, 0, -1.5)
	for i in 40:
		await frames(5)
		if bool(m.flags.get("board", false)): break
	check(bool(m.flags.get("board", false)), "at the open gate: the board")
	for i in 60:
		await process_frame
		if session._load_done: break
	check(session._load_done, "the board loaded what comes next (%s)" % session._load_caption)
	session._board_ready()
	for i in 30:
		await frames(5)
		if m.stage == 16: break
	check(m.stage == 16 and m.outer_street != null, "everyone ready: entered Outer Street from PILCST (stage %d)" % m.stage)
	print("INTERIOR_HEAVYARM %s (%d checks) %s" % ["ok" if failed.is_empty() else "FAIL", checks, str(failed)])
	quit(0 if failed.is_empty() else 1)
