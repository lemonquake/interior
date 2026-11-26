extends SceneTree
## 0.33: what the infected see and hear (scripts/senses.gd), headless:
##   godot --headless --path game --script res://tests/senses_integration.gd --fixed-fps 60
## They are blind in the dark: one standing nine metres in front of the player on the unlit field road does not
## notice them, and goes quiet. The torch coming on shows the player: it comes. The torch going off, and the
## player gone a few steps aside, it loses them within seconds and gropes on to where they were, dazed. They hear:
## a slow walk past one is not heard, a walk turns its head, running feet bring it over, a thing landing draws it
## to where it landed. A street lamp lights the ground under it; a round through its head puts it out for good,
## and the place is dark. Holding Ctrl walks at about a metre a second with a step that carries under two metres.

class ErrorCatcher extends Logger:
	var errors: Array[String] = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file, line, code, rationale])
	func _log_message(message: String, error: bool) -> void:
		pass

const ROAD := Vector3(21.0, -2.75, 62.0)

var checks := 0
var failures: Array[String] = []
var main: Node
var player: InteriorPlayer
var zombies: InteriorZombies
var senses: InteriorSenses
var catcher := ErrorCatcher.new()

func _initialize() -> void:
	OS.add_logger(catcher)
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL " + message)
	print(("PASS " if condition else "FAIL ") + message)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _seconds(s: float) -> void:
	await _frames(int(ceil(s * 60.0)))

func _stand(at: Vector3, yaw := 0.0) -> void:
	var spot := zombies.ground(at, false)
	player.reset_motion(spot if spot.is_finite() else at)
	player.rotation = Vector3(0, yaw, 0)
	await _frames(20)

func _one(distance: float, kind := "walker", facing_player := true) -> InteriorZombie:
	var ahead := -player.global_basis.z
	for extra: float in [0.0, .8, -.8, 1.6]:
		var spot := zombies.ground(player.global_position + ahead * (distance + extra), false)
		if spot.is_finite():
			return zombies.spawn(spot, "", atan2(ahead.x, ahead.z) + (0.0 if facing_player else PI), false, kind)
	return null

func _calm(zombie: InteriorZombie) -> bool:
	return zombie.state == InteriorZombie.State.IDLE or zombie.state == InteriorZombie.State.ROAM or zombie.state == InteriorZombie.State.LISTEN

func _run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await _frames(6)
	player = main.player
	zombies = main.zombies
	senses = main.senses
	check(senses != null and zombies != null and zombies.senses == senses, "The scene has the senses, and the director knows them")
	if senses == null or zombies == null:
		_finish()
		return
	var man := main.get_node_or_null("Stranger") as Node3D
	if man != null:
		man.process_mode = Node.PROCESS_MODE_DISABLED
	zombies.invulnerable = true
	await _seconds(1.0)
	var kinds := InteriorZombie.KINDS.keys()
	var kind: String = "walker" if kinds.has("walker") else str(kinds[0])

	# ---- blind in the dark
	await _stand(ROAD, PI)
	await _seconds(.6)
	var dark := senses.light_at(player.global_position + Vector3.UP)
	check(dark < InteriorSenses.DARK and senses.visibility() < InteriorSenses.DARK, "The field road is dark, and the player does not show there (light %.3f, shown %.2f)" % [dark, senses.visibility()])
	var a := _one(9.0, kind)
	check(a != null, "One of them stands nine metres ahead, facing the player")
	if a == null:
		_finish()
		return
	await _seconds(4.0)
	check(_calm(a) and not a.sees, "In the dark it does not see the player (%s)" % InteriorZombie.State.keys()[a.state])
	check(a.lit < InteriorSenses.DARK and a._docile > .6, "It stands in the dark and has gone quiet (light %.3f, quiet %.2f)" % [a.lit, a._docile])

	# ---- the torch shows the player
	main.story.debug_give_flashlight()
	var torch: InteriorFlashlight = main.story.flashlight
	torch.set_on(true)
	await _seconds(.4)
	var in_beam := senses.exposure_to(a.global_position + Vector3.UP * 1.5)
	check(in_beam > .9, "The torch on and pointed at it: the player shows plainly to it (%.2f)" % in_beam)
	var noticed := false
	for i in 240:
		await _frames(1)
		if a.state == InteriorZombie.State.ALERT or a.state == InteriorZombie.State.CHASE or a.state == InteriorZombie.State.ATTACK:
			noticed = true
			break
	check(noticed and a.sees, "It sees the light and comes (%s)" % InteriorZombie.State.keys()[a.state])
	for i in 240:
		if a.state == InteriorZombie.State.CHASE:
			break
		await _frames(1)

	# ---- the torch off, a few steps aside: lost
	torch.set_on(false)
	var was := player.global_position
	var aside := player.global_position + player.global_basis.x * 7.0 - player.global_basis.z * -5.0
	var spot := zombies.ground(aside, false)
	player.reset_motion(spot if spot.is_finite() else aside)
	var lost_after := -1.0
	for i in 600:
		await _frames(1)
		if a.state == InteriorZombie.State.SEARCH:
			lost_after = i / 60.0
			break
		if a.state == InteriorZombie.State.ATTACK:
			# It was already on them when the light went: it has its swing.
			continue
	check(lost_after >= 0.0 and lost_after < 5.5, "The torch off and the player gone aside: it has lost them in seconds (%.1f s)" % lost_after)
	check(a._dazed and a._goal.distance_to(was) < 3.0 and a._goal.distance_to(player.global_position) > 4.0, "It gropes on to where they were, dazed (goal %.1f m from there)" % a._goal.distance_to(was))
	var gave_up := false
	for i in 900:
		await _frames(1)
		if _calm(a):
			gave_up = true
			break
	check(gave_up and not a.sees, "And gives up, without having found them")

	# ---- hearing
	zombies.clear()
	await _frames(4)
	await _stand(ROAD + Vector3(0, 0, 6.0), PI)
	check(InteriorSenses.step_loudness(.12, "concrete") < 2.0 and InteriorSenses.step_loudness(1.0, "concrete") > 14.0 and InteriorSenses.step_loudness(.55, "concrete") > 5.0,
		"A slow step carries under 2 m, a walking one over 5, a running one over 14 (%.1f / %.1f / %.1f)" % [InteriorSenses.step_loudness(.12, "concrete"), InteriorSenses.step_loudness(.55, "concrete"), InteriorSenses.step_loudness(1.0, "concrete")])
	var b := _one(5.0, kind, false)
	check(b != null, "One stands five metres off with its back turned")
	if b != null:
		await _seconds(1.0)
		for i in 8:
			senses._on_step("concrete", .12)
			await _seconds(.4)
		check(_calm(b) and b.state != InteriorZombie.State.LISTEN, "Eight slow steps five metres behind it: nothing (%s)" % InteriorZombie.State.keys()[b.state])
		senses._on_step("concrete", .55)
		await _frames(3)
		check(b.state == InteriorZombie.State.LISTEN, "One walking step: it turns its head to listen (%s)" % InteriorZombie.State.keys()[b.state])
		var before := b.rotation.y
		await _seconds(1.2)
		check(absf(angle_difference(before, b.rotation.y)) > .5, "It turns toward the sound (%.2f rad)" % absf(angle_difference(before, b.rotation.y)))
		for i in 4:
			senses._on_step("concrete", 1.0)
			await _seconds(.3)
		check(b.state == InteriorZombie.State.SEARCH or b.state == InteriorZombie.State.CHASE, "Running feet: it comes to the sound (%s)" % InteriorZombie.State.keys()[b.state])
		check(not b.sees or b.global_position.distance_to(player.global_position) < 2.6, "It comes by ear, not by sight")

	# ---- a thing landing draws them to it
	zombies.clear()
	await _frames(4)
	await _stand(ROAD + Vector3(0, 0, 12.0), PI)
	var c := _one(8.0, kind, false)
	if c != null:
		await _seconds(1.0)
		var thrown := c.global_position - player.global_basis.z * 4.0
		senses._on_impact(9.0, thrown, "wood")
		await _frames(3)
		check(c.state == InteriorZombie.State.SEARCH and c._goal.distance_to(thrown) < 1.0, "A thing landing four metres beyond it: it goes there, not to the player (%s)" % InteriorZombie.State.keys()[c.state])
	zombies.clear()
	await _frames(4)

	# ---- the slow walk itself
	await _stand(ROAD + Vector3(0, 0, 4.0), PI)
	senses.noises.clear()
	Input.action_press("sneak")
	Input.action_press("forward")
	await _seconds(2.5)
	var pace := Vector2(player.velocity.x, player.velocity.z).length()
	Input.action_release("forward")
	Input.action_release("sneak")
	var loudest := 0.0
	for entry: Dictionary in senses.noises:
		if entry.kind == "step":
			loudest = maxf(loudest, float(entry.loudness))
	check(player.sneaking and pace > .8 and pace < 1.3, "Ctrl held: a slow walk (%.2f m/s)" % pace)
	check(not senses.noises.is_empty() and loudest < 2.0, "Its steps carry under two metres (%d steps, loudest %.1f m)" % [senses.noises.size(), loudest])
	await _seconds(.5)
	senses.noises.clear()
	Input.action_press("forward")
	Input.action_press("run")
	await _seconds(2.0)
	Input.action_release("forward")
	Input.action_release("run")
	loudest = 0.0
	for entry: Dictionary in senses.noises:
		loudest = maxf(loudest, float(entry.loudness))
	check(loudest > 9.0, "Running carries far (%.1f m)" % loudest)
	await _seconds(.5)

	# ---- a lamp, lit and shot out
	var lamp: Light3D = null
	for node in main.find_children("Street lamp*", "Light3D", true, false):
		if (node as Light3D).is_visible_in_tree():
			lamp = node
			break
	check(lamp != null, "There is a street lamp burning")
	if lamp != null:
		var under := lamp.global_position
		await _stand(Vector3(under.x, -2.75, under.z))
		lamp.light_energy = maxf(lamp.light_energy, .9)
		await _seconds(.8)
		var lit := senses.light_at(player.global_position + Vector3.UP)
		check(lit > InteriorSenses.LIT and senses.visibility() > InteriorSenses.LIT, "Under the lamp the player is lit and shows (light %.2f, shown %.2f)" % [lit, senses.visibility()])
		# From a few steps off, so the lamp is not straight overhead.
		for offset: Vector3 in [Vector3(4.5, 0, 0), Vector3(-4.5, 0, 0), Vector3(0, 0, 4.5), Vector3(0, 0, -4.5)]:
			var place := zombies.ground(Vector3(under.x, -2.75, under.z) + offset, false)
			if place.is_finite() and main.get_viewport().world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(place + Vector3.UP * 1.58, under, 2)).is_empty():
				player.reset_motion(place)
				break
		await _frames(20)
		var eye := player.camera.global_position
		check(senses.lamp_on_path(eye, eye + (under - eye) * 1.3) == lamp, "A round's path through the lamp's head finds the lamp")
		check(senses.lamp_on_path(eye, eye + Vector3(4, 0, 0)) == null, "A level shot under it does not")
		# With the pistol, for real.
		main.story.debug_give_gun()
		var gun: InteriorGun = main.story.gun
		gun.draw()
		await _seconds(1.2)
		gun.spread_scale = 0.0
		var to := under - player.camera.global_position
		player.rotation = Vector3(0, atan2(-to.x, -to.z), 0)
		player.set("_look_pitch", atan2(to.y, Vector2(to.x, to.z).length()))
		player.recoil = 0.0
		player.aim_offset = Vector2.ZERO
		player.camera.rotation.x = player.get("_look_pitch")
		await _frames(3)
		for i in 240:
			if gun.ready_to_fire():
				break
			await _frames(1)
		gun.mag = gun.mag_size()
		gun.chambered = true
		var here := senses.light_at(player.global_position + Vector3.UP)
		var fired := gun.try_fire()
		await _frames(4)
		check(not lamp.visible and lamp.has_meta("shot_out") and senses.shot_out.has(lamp), "A pistol round through it puts it out")
		await _seconds(3.0)
		var after := senses.light_at(player.global_position + Vector3.UP)
		check(not lamp.is_visible_in_tree() and after < here - .08, "It stays out, and the ground by it is darker (light %.2f, was %.2f)" % [after, here])
		var glass := false
		for entry: Dictionary in senses.noises:
			glass = glass or entry.kind == "glass"
		check(glass, "The breaking glass is a sound of its own")
	_finish()

func _finish() -> void:
	await _frames(4)
	check(catcher.errors.is_empty(), "No errors in the log (%d)" % catcher.errors.size())
	for line in catcher.errors.slice(0, 12):
		print("  ERROR ", line)
	print("SENSES_INTEGRATION ", JSON.stringify({"checks": checks, "passed": failures.is_empty(), "failures": failures}))
	quit(1 if not failures.is_empty() else 0)
