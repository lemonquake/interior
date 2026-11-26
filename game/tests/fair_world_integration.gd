extends SceneTree
## 0.37: the weapon, the infected and the world agree, headless:
##   godot --headless --path game --script res://tests/fair_world_integration.gd --fixed-fps 60
##
## The shot (scripts/gun.gd). A round leaves from the weapon, not from the lens on the forehead: over a wall the
## lens sees past but the barrel is under, at the hip, the round goes into the wall; on the sights, with the
## barrel just under the lens, the same wall is cleared. Rounds fly tick by tick: a target that steps out of the way
## after the trigger breaks is missed, one that steps into it is struck.
## Barriers (scripts/zombie.gd, zombies.gd, body.gd). Through a wall at arm's length it neither knows the player
## is there nor claws them, and the player's shove does not reach it; take the wall away and it does. Over a
## waist-high rail both reach. A door leaf hides, muffles and stops hands.
## One rule for sound and light (scripts/senses.gd, sound_stage.gd). A shot behind a wall carries less far, to
## them and to the player's own ears alike. The torch shows the player to eyes in its beam, not to eyes beside it;
## its spot on a wall draws one to look at the spot.
## Investigation. A faint sound stops it mid-step and turns its head; a loud one sends it to look, slower the less
## sure it is; there it looks down at the place, then about, and gives up.
## The changing world (scripts/zombie_nav.gd). A door shut across the street: no way through; opened, the way is
## found at once, and one called from the far side comes through; shut again, the way is gone. Stairs up to a
## narrow railed boardwalk are walked. A crate in a gap: it pushes, shuts that cell and goes by the other gap.

class ErrorCatcher extends Logger:
	var errors: Array[String] = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file, line, code, rationale])
	func _log_message(message: String, error: bool) -> void:
		pass

const ROAD := Vector3(21.0, -2.75, 62.0)
const STREET_Y := -2.9

var checks := 0
var failures: Array[String] = []
var main: Node
var player: InteriorPlayer
var zombies: InteriorZombies
var senses: InteriorSenses
var gun: InteriorGun
var built: Array[Node] = []
var catcher := ErrorCatcher.new()
var results := {}
var _yaw := 0.0

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

## A box standing on `foot` (the middle of its underside), turned by `yaw`.
func _box(foot: Vector3, size: Vector3, layer := 2, moving := false, yaw := 0.0) -> PhysicsBody3D:
	var body: PhysicsBody3D = AnimatableBody3D.new() if moving else StaticBody3D.new()
	if moving:
		(body as AnimatableBody3D).sync_to_physics = false
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	main.add_child(body)
	body.global_transform = Transform3D(Basis(Vector3.UP, yaw), foot + Vector3.UP * size.y * .5)
	built.append(body)
	return body

func _clear_built() -> void:
	for node in built:
		if is_instance_valid(node):
			node.queue_free()
	built.clear()
	await _frames(3)
	if zombies.nav != null:
		zombies.nav._cells.clear()
		zombies.nav._nudge.clear()
		zombies.nav._closed.clear()

func _stand(at: Vector3, yaw := 0.0) -> void:
	var spot := zombies.ground(at, false)
	player.reset_motion(spot if spot.is_finite() else at)
	player.rotation = Vector3(0, yaw, 0)
	player._look_pitch = 0.0
	_yaw = yaw
	await _frames(20)

func _forward() -> Vector3:
	var f := -player.global_basis.z
	f.y = 0.0
	return f.normalized()

func _spawn(at: Vector3, facing: float, kind := "walker") -> InteriorZombie:
	var kinds := InteriorZombie.KINDS.keys()
	var use := kind if kinds.has(kind) else str(kinds[0])
	for extra: Vector3 in [Vector3.ZERO, Vector3(.6, 0, 0), Vector3(-.6, 0, 0), Vector3(0, 0, .6), Vector3(0, 0, -.6)]:
		var spot := zombies.ground(at + extra, false)
		if spot.is_finite():
			return zombies.spawn(spot, "", facing, false, use)
	return null

func _shot() -> Array:
	gun.mag = gun.mag_size()
	gun.chambered = true
	for i in 120:
		if gun.ready_to_fire():
			break
		await physics_frame
	gun.try_fire()
	await _seconds(.5)
	return gun.last_hits.duplicate()

## The lens level again after the last shot's kick.
func _level() -> void:
	await _seconds(.6)
	player._look_pitch = 0.0
	player.rotation.y = _yaw
	# 0.40: rounds go where the weapon is drawn pointing, and a snapped turn swings it: let it settle.
	await _seconds(.6)

## The trigger, with a round ready.
func _pull() -> void:
	gun.mag = gun.mag_size()
	gun.chambered = true
	gun._next_shot = 0.0
	gun.try_fire()

func _struck(hits: Array, body: Object) -> bool:
	for hit: Dictionary in hits:
		if hit.collider == body:
			return true
	return false

func _run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await _frames(6)
	player = main.player
	zombies = main.zombies
	senses = main.senses
	var man := main.get_node_or_null("Stranger") as Node3D
	if man != null:
		man.process_mode = Node.PROCESS_MODE_DISABLED
	zombies.invulnerable = true
	await _seconds(1.0)
	await _the_shot()
	await _barriers()
	await _one_rule()
	await _investigation()
	await _changing_world()
	_finish()

# ---------------------------------------------------------------- the shot

func _the_shot() -> void:
	await _stand(ROAD, PI)
	main.story.debug_give_gun()
	gun = main.story.gun
	gun.draw()
	gun.spread_scale = 0.0
	gun.instant_hits = false
	gun.infinite_ammo = true
	player.free_aim = false
	await _seconds(1.3)
	var eye := player.camera.global_position
	var ground := player.global_position.y
	var ahead := _forward()

	# A wall top a fifth of a metre under the lens, 1.2 m ahead.
	var wall := _box(player.global_position + ahead * 1.35, Vector3(2.4, (eye.y - .2) - ground, .3), 2, false, player.rotation.y)
	await _frames(4)
	var space := player.get_world_3d().direct_space_state
	var lens_clear := InteriorSurfaces.seen_ray(space, eye, eye + ahead * 6.0, 2 | 4, [player.get_rid()])
	check(lens_clear.is_empty() or lens_clear.collider != wall, "The lens sees over the wall")
	var hits := await _shot()
	check(gun.last_shot_origin.y < eye.y - .2, "At the hip the round leaves from the weapon, a forearm under the lens (%.2f m under)" % (eye.y - gun.last_shot_origin.y))
	check(_struck(hits, wall), "...and goes into the wall the lens sees over (%d hits)" % hits.size())
	Input.action_press("aim")
	await _seconds(.8)
	check(gun._ads > .9, "On the sights (%.2f)" % gun._ads)
	hits = await _shot()
	check(not _struck(hits, wall) and gun.last_shot_origin.y > eye.y - .2, "On the sights the barrel is just under the lens and clears the same wall (%d hits, %.2f m under)" % [hits.size(), eye.y - gun.last_shot_origin.y])
	Input.action_release("aim")
	await _seconds(.6)
	wall.queue_free()
	built.erase(wall)

	# Up against a wall: tucked, and the round goes into it.
	var close := _box(player.global_position + ahead * .55, Vector3(2.4, 2.6, .3), 2, false, player.rotation.y)
	await _seconds(.6)
	check(gun._tuck > .5, "Against a wall the weapon is tucked in (%.2f)" % gun._tuck)
	hits = await _shot()
	check(_struck(hits, close), "A round fired tucked against the wall goes into it")
	close.queue_free()
	built.erase(close)
	await _seconds(.4)

	# Moving targets at 60 m (a 9 mm takes about a sixth of a second to get there).
	var far := 60.0
	var target_at := eye + ahead * far + Vector3.DOWN * 1.1
	var open := InteriorSurfaces.seen_ray(space, eye, eye + ahead * (far + 4.0), 2 | 4, [player.get_rid()])
	check(open.is_empty(), "Sixty metres of open road ahead")
	var side := ahead.cross(Vector3.UP).normalized()
	var target := _box(target_at, Vector3(1.0, 2.2, .4), 2, true, player.rotation.y)
	await _frames(3)
	# Standing still, it is struck (the control). 0.40: rounds go where the drawn weapon points, and a winded
	# body's weapon wanders at the hip: sixty metres is a shot taken on the sights.
	Input.action_press("aim")
	await _level()
	var hits_still := await _shot()
	check(_struck(hits_still, target), "A target standing still 60 m off is struck (%d hits)" % hits_still.size())
	await _level()
	_pull()
	await _frames(1)
	check(gun.rounds_in_flight() > 0, "The round is still in the air a tick after the shot")
	target.global_position += side * 4.0
	await _seconds(.5)
	check(not _struck(gun.last_hits, target) and gun.rounds_in_flight() == 0, "A target that steps out of the way after the trigger breaks is missed")
	await _level()
	_pull()
	await _frames(2)
	target.global_position -= side * 4.0
	await _seconds(.5)
	check(_struck(gun.last_hits, target), "A target that steps into the path while the round flies is struck (%d hits)" % gun.last_hits.size())
	Input.action_release("aim")
	await _clear_built()
	if gun.has_method("holster"):
		gun.holster()
	await _seconds(.5)

# ---------------------------------------------------------------- barriers

func _barriers() -> void:
	await _stand(ROAD, PI)
	var ahead := _forward()
	var foot := player.global_position
	# The wall is in the world before the figure is (a body added this tick is not seen by rays until the next).
	var wall := _box(foot + ahead * .6, Vector3(3.0, 2.6, .2), 2, false, player.rotation.y)
	await _frames(3)
	var z := _spawn(foot + ahead * 1.15, atan2(ahead.x, ahead.z))
	check(z != null, "One of them stands just the far side of a wall, an arm's length off")
	if z == null:
		return
	# Held where it stands: the wall is only 3 m wide, and walking round it is not the point here.
	z.roam_speed = 0.0
	z.chase_speed = 0.0
	zombies.invulnerable = false
	zombies.health = 100.0
	await _seconds(2.0)
	check(not z.sees and z.awareness() != "hunting", "Through the wall it does not see the player, nor hunt them (%s)" % z.awareness())
	check(not zombies.within_reach(z), "...and its claws cannot get at them")
	# Made to swing at them, again and again: nothing lands.
	for i in 4:
		z._enter(InteriorZombie.State.ATTACK)
		await _seconds(.75)
	check(zombies.health >= 100.0, "Swinging at them through the wall, it cannot claw them (health %.0f)" % zombies.health)
	await _seconds(1.0)
	zombies.body._since_shove = 10.0
	check(zombies.body.shove() == 0, "The player's shove does not reach it through the wall either")
	wall.queue_free()
	built.erase(wall)
	await _frames(4)
	check(zombies.within_reach(z), "With the wall gone it can reach them")
	var hurt := false
	for i in 4:
		z._enter(InteriorZombie.State.ATTACK)
		await _seconds(.75)
		if zombies.health < 100.0:
			hurt = true
			break
	check(hurt, "...and it does (health %.0f)" % zombies.health)
	zombies.invulnerable = true
	zombies.health = 100.0
	# A waist-high rail: hands go over it.
	var rail := _box(foot + ahead * .6, Vector3(3.0, .95, .1), 2, false, player.rotation.y)
	await _frames(4)
	check(zombies.within_reach(z), "Over a waist-high rail its arms reach the player")
	await _seconds(1.0)
	zombies.body._since_shove = 10.0
	check(zombies.body.shove() >= 1, "...and the player's shove reaches it")
	rail.queue_free()
	built.erase(rail)
	# A door leaf: it hides, it muffles less than a wall, it stops hands.
	var leaf := _box(foot + ahead * .6, Vector3(1.2, 2.2, .06), 2, true, player.rotation.y)
	await _frames(4)
	var eye := z.where() + Vector3.UP * 1.5
	check(not senses.sight_clear(eye, player.camera.global_position), "A door leaf hides the player")
	var through := senses.muffle(player.camera.global_position, eye)
	check(absf(through - InteriorSenses.THROUGH_LEAF) < .01, "A door leaf muffles a sound by %.2f (a wall 1)" % through)
	check(not zombies.within_reach(z), "...and stops its hands")
	zombies.clear()
	await _clear_built()

# ---------------------------------------------------------------- one rule for sound and light

func _one_rule() -> void:
	await _stand(ROAD, PI)
	var ahead := _forward()
	var foot := player.global_position
	# A shot behind a wall, heard 36 m off.
	var z := _spawn(foot + ahead * 36.0, atan2(ahead.x, ahead.z) + PI)
	check(z != null, "One of them stands 36 m up the road")
	if z != null:
		await _seconds(1.0)
		var wall := _box(foot + ahead * 2.0, Vector3(8.0, 4.0, .3), 2, false, player.rotation.y)
		await _frames(4)
		var heard := senses.noise(foot, InteriorZombies.HEARING, "shot")
		check(heard == 0 and z.awareness() == "calm", "A shot behind a wall does not carry 36 m to it (%d heard, carries %.0f m)" % [heard, InteriorZombies.HEARING * InteriorSenses.carry(1.0)])
		# The player's own ears: a voice on the other side of the wall is muffled by the same rule.
		var voice := AudioStreamPlayer3D.new()
		voice.bus = "Gun"
		var wav := AudioStreamWAV.new()
		wav.data = PackedByteArray()
		wav.data.resize(16000)
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = 8000
		voice.stream = wav
		voice.max_distance = 60.0
		main.add_child(voice)
		voice.global_position = foot + ahead * 3.5 + Vector3.UP * 1.2
		voice.play()
		# (scripts/sound_stage.gd looks at five voices a frame in turn: with many in the scene a voice waits its turn.)
		var shut := -1.0
		for i in 600:
			await physics_frame
			shut = float(voice.get_meta("stage_shut", -1.0))
			if shut > .9:
				break
		check(shut > .9, "To the player's ears a sound behind the wall is muffled by the same rule (%.2f)" % shut)
		wall.queue_free()
		built.erase(wall)
		var leaf := _box(foot + ahead * 2.0, Vector3(8.0, 4.0, .06), 2, true, player.rotation.y)
		for i in 600:
			await physics_frame
			shut = float(voice.get_meta("stage_shut", -1.0))
			if absf(shut - InteriorSenses.THROUGH_LEAF) < .08:
				break
		check(absf(shut - InteriorSenses.THROUGH_LEAF) < .08, "...a door muffles it less (%.2f)" % shut)
		leaf.queue_free()
		built.erase(leaf)
		voice.queue_free()
		await _frames(4)
		heard = senses.noise(foot, InteriorZombies.HEARING, "shot")
		check(heard == 1 and z.awareness() == "searching", "With nothing between, it is heard and it comes to look (%s)" % z.awareness())
	zombies.clear()
	await _clear_built()

	# The torch: shown to eyes in its beam, not beside it.
	await _stand(ROAD, PI)
	ahead = _forward()
	foot = player.global_position
	main.story.debug_give_flashlight()
	var torch: InteriorFlashlight = main.story.flashlight
	var a := _spawn(foot + ahead * 9.0, atan2(ahead.x, ahead.z))
	check(a != null, "One of them nine metres ahead in the dark, facing the player")
	if a == null:
		return
	await _seconds(1.0)
	player.rotation.y += PI
	torch.set_on(true)
	await _seconds(2.0)
	var eye := a.where() + Vector3.UP * 1.5
	check(senses.exposure_to(eye) < .5 and not a.sees, "The torch on but pointed away: it does not see the player (shown %.2f)" % senses.exposure_to(eye))
	player.rotation.y -= PI
	var seen := false
	for i in 150:
		await physics_frame
		if a.sees:
			seen = true
			break
	check(senses.exposure_to(eye) > .9 and seen, "Turned on it, the beam shows the player plainly (shown %.2f)" % senses.exposure_to(eye))
	torch.set_on(false)
	zombies.clear()
	await _seconds(.5)
	# Its spot on a wall: one beside the beam goes to look at the spot, not at the player.
	await _stand(ROAD, PI)
	ahead = _forward()
	var right := ahead.cross(Vector3.UP).normalized()
	foot = player.global_position
	_box(foot + ahead * 6.0, Vector3(6.0, 3.0, .3), 2, false, player.rotation.y)
	var b := _spawn(foot + right * 4.5 + ahead * 3.5, atan2(right.x, right.z))
	check(b != null, "One of them stands off to the side of the beam, facing across it")
	if b == null:
		return
	await _seconds(1.0)
	torch.set_on(true)
	var looked := false
	for i in 300:
		await physics_frame
		if b.sees:
			break
		if b.awareness() == "searching" and senses.beam_spot.is_finite() and b._goal.distance_to(senses.beam_spot) < 1.6:
			looked = true
			break
	check(looked and not b.sees, "It sees the torch's spot on the wall and goes to look at it, not at the player (%s, spot %s)" % [b.awareness(), senses.beam_spot])
	torch.set_on(false)
	zombies.clear()
	await _clear_built()

# ---------------------------------------------------------------- investigation

func _investigation() -> void:
	await _stand(ROAD, PI)
	var ahead := _forward()
	var right := ahead.cross(Vector3.UP).normalized()
	var foot := player.global_position
	# It faces along the road, side on to the player.
	var z := _spawn(foot + ahead * 11.0, atan2(right.x, right.z))
	check(z != null, "One of them stands on the dark road")
	if z == null:
		return
	await _seconds(1.5)
	var at := z.where() - right * 1.0 + ahead * 3.8
	var stood := z.where()
	senses.noise(at, 6.0, "step")
	await _frames(4)
	check(z.awareness() == "suspicious" and z._hold > 0.0 and z.anim.speed_scale < .1, "A faint sound: it stops dead, mid-step (%s)" % z.awareness())
	await _seconds(.9)
	var want := z._yaw_to(at)
	check(absf(z._head_yaw) > .25 and (absf(want) < .25 or signf(z._head_yaw) == signf(want)), "...its head comes round toward it (head %.2f rad, sound at %.2f rad)" % [z._head_yaw, want])
	check(z.where().distance_to(stood) < .6 and z.certainty < .3, "...it does not go anywhere yet (%.2f m, sure %.2f)" % [z.where().distance_to(stood), z.certainty])
	await _seconds(3.0)
	# A loud one: it goes to look, not running.
	senses.noise(at, 40.0, "thing")
	await _frames(2)
	var sure := z.certainty
	check(z.awareness() == "searching" and sure > .3 and sure < .8, "A loud sound: it goes to look, not sure what it is (sure %.2f)" % sure)
	var fastest := 0.0
	var looked_down := false
	var gave_up := -1.0
	for i in 60 * 30:
		await physics_frame
		fastest = maxf(fastest, Vector2(z.velocity.x, z.velocity.z).length())
		looked_down = looked_down or (z._examined and z._head_pitch > .25)
		if z.awareness() == "calm":
			gave_up = i / 60.0
			break
	check(fastest < z.chase_speed * .75, "It does not run to a sound (%.1f m/s at most, runs at %.1f)" % [fastest, z.chase_speed])
	check(looked_down, "At the place it stands over it and looks down at it")
	check(gave_up > 0.0 and z.certainty == 0.0, "...then gives up and wanders off (%.1f s)" % gave_up)
	# Sure (it had just lost them) it goes quicker than unsure.
	var speeds := []
	for how: float in [.95, .3]:
		await _stand(ROAD, PI)
		z.certainty = how
		z.last_seen = player.global_position + _forward() * 20.0 + right * 0.0
		z._enter(InteriorZombie.State.SEARCH)
		var moved := 0.0
		var last := z.where()
		for i in 150:
			await physics_frame
			moved += Vector2(z.where().x - last.x, z.where().z - last.z).length()
			last = z.where()
		speeds.append(moved / 2.5)
		z.forget()
		await _seconds(.5)
	check(float(speeds[0]) > float(speeds[1]) * 1.3, "Sure, it goes to look quicker than unsure (%.2f against %.2f m/s)" % [float(speeds[0]), float(speeds[1])])
	zombies.clear()
	await _clear_built()

# ---------------------------------------------------------------- the changing world

func _street_wall(z: float, gaps: Array) -> void:
	# A wall across the whole street at `z`, with gaps [x, width].
	var edges: Array = [-12.0]
	for gap: Array in gaps:
		edges.append(float(gap[0]) - float(gap[1]) * .5)
		edges.append(float(gap[0]) + float(gap[1]) * .5)
	edges.append(54.0)
	for i in range(0, edges.size(), 2):
		var x0: float = edges[i]
		var x1: float = edges[i + 1]
		_box(Vector3((x0 + x1) * .5, STREET_Y - .3, z), Vector3(x1 - x0, 3.0, .3))

func _called(one: InteriorZombie, goal: Vector3, seconds: float) -> float:
	one.heard(goal, 1.0, "shot")
	var nearest := 99.0
	for i in int(seconds * 60.0):
		await physics_frame
		if not is_instance_valid(one):
			break
		var far := Vector2(one.where().x - goal.x, one.where().z - goal.z).length()
		nearest = minf(nearest, far)
		if far < 1.6:
			break
		if one.state != InteriorZombie.State.SEARCH and one.state != InteriorZombie.State.CHASE and one.state != InteriorZombie.State.ATTACK and one.state != InteriorZombie.State.ALERT:
			one.heard(goal, 1.0, "shot")
	return nearest

func _changing_world() -> void:
	var nav := zombies.nav
	zombies.passive = false
	var near := Vector3(21.0, STREET_Y, 16.0)
	var beyond := Vector3(21.0, STREET_Y, 24.0)
	await _stand(beyond + Vector3(0, 0, 4.0), 0.0)
	nav.space = main.get_viewport().world_3d.direct_space_state
	_street_wall(20.0, [[21.0, 1.2]])
	var hinge := Vector3(20.4, STREET_Y - .3, 20.0)
	var leaf := _box(hinge + Vector3(.6, 0, 0), Vector3(1.2, 2.4, .08), 2, true)
	await _seconds(.5)
	var way := nav.path(near, beyond)
	check(way.is_empty() or way[-1].z < 20.0, "The door shut: no way through (ends at z %.1f)" % (way[-1].z if not way.is_empty() else 0.0))
	var changes := zombies.mover_changes
	var epoch := nav.epoch
	leaf.global_transform = Transform3D(Basis(Vector3.UP, -PI * .5), hinge + Vector3(-.04, 1.2, .6))
	await _seconds(.5)
	check(zombies.mover_changes > changes and nav.epoch > epoch, "The door opening is noticed (%d moves, epoch %d)" % [zombies.mover_changes - changes, nav.epoch])
	way = nav.path(near, beyond)
	check(not way.is_empty() and way[-1].distance_to(beyond) < 1.0, "Opened: the way through is found at once (%d points)" % way.size())
	leaf.global_transform = Transform3D(Basis.IDENTITY, hinge + Vector3(.6, 1.2, 0))
	await _seconds(.5)
	way = nav.path(near, beyond)
	check(way.is_empty() or way[-1].z < 20.0, "Shut again: the way is gone")
	# Pursuit: called from the far side, through the shut door and then the open one.
	var one := _spawn(near, 0.0)
	await _seconds(.5)
	var nearest := await _called(one, player.global_position, 6.0)
	check(nearest > 3.0, "Called through the shut door, it cannot come (%.1f m off at best)" % nearest)
	leaf.global_transform = Transform3D(Basis(Vector3.UP, -PI * .5), hinge + Vector3(-.04, 1.2, .6))
	nearest = await _called(one, player.global_position, 15.0)
	check(nearest < 1.6, "The door opened, it comes through (%.1f m off)" % nearest)
	zombies.clear()
	await _clear_built()

	# Stairs up to a platform, a railed boardwalk 0.7 m wide, a second platform (x 22, from z 13: street B is clear).
	var top := STREET_Y + 1.02
	var x := 22.0
	var z0 := 13.0
	for step in 6:
		var rise := .17 * (step + 1)
		_box(Vector3(x, STREET_Y - .3, z0 + .15 + step * .3), Vector3(1.2, rise + .3, .3))
	_box(Vector3(x, STREET_Y - .3, z0 + 2.4), Vector3(1.2, 1.32, 1.2))
	_box(Vector3(x, STREET_Y - .3, z0 + 5.0), Vector3(.7, 1.32, 4.0))
	_box(Vector3(x - .4, top, z0 + 5.0), Vector3(.05, 1.0, 4.0))
	_box(Vector3(x + .4, top, z0 + 5.0), Vector3(.05, 1.0, 4.0))
	_box(Vector3(x, STREET_Y - .3, z0 + 7.6), Vector3(1.4, 1.32, 1.2))
	await _frames(4)
	var start := Vector3(x, STREET_Y, z0 - 2.0)
	var landing := Vector3(x, top, z0 + 7.6)
	way = nav.path(start, landing)
	var on_walk := true
	for p: Vector3 in way:
		if p.z > z0 + 3.3 and p.z < z0 + 6.7 and p.y < top - .25:
			on_walk = false
	check(not way.is_empty() and way[-1].distance_to(landing) < .9 and on_walk, "Up the stairs and along the narrow railed boardwalk (%d points, ends %.1f m off)" % [way.size(), way[-1].distance_to(landing) if not way.is_empty() else 99.0])
	await _stand(landing, 0.0)
	one = _spawn(start, 0.0)
	await _seconds(.5)
	nearest = await _called(one, player.global_position, 25.0)
	check(nearest < 1.6 and one.where().y > top - .4, "One of them climbs the stairs and comes along the boardwalk (%.1f m off, %.2f m up)" % [nearest, one.where().y - STREET_Y])
	zombies.clear()
	await _clear_built()

	# A crate in the near gap: it pushes, gives that cell up, and goes by the other gap (z 22: clear from x 18 to 24).
	_street_wall(22.0, [[19.2, 1.2], [23.0, 1.2]])
	_box(Vector3(19.2, STREET_Y - .3, 22.0), Vector3(1.2, 1.4, 1.2), 4)
	await _stand(Vector3(19.2, STREET_Y, 26.0), 0.0)
	one = _spawn(Vector3(19.2, STREET_Y, 18.0), 0.0)
	await _seconds(.5)
	nearest = await _called(one, player.global_position, 30.0)
	check(nearest < 1.6, "Stopped by the crate it goes round by the other gap (%.1f m off)" % nearest)
	results["shut_cells"] = nav._closed.size()
	zombies.clear()
	await _clear_built()

func _finish() -> void:
	await _frames(4)
	check(catcher.errors.is_empty(), "No errors in the log (%d)" % catcher.errors.size())
	for line in catcher.errors.slice(0, 12):
		print("  ERROR ", line)
	print("INTERIOR_FAIR_WORLD ", JSON.stringify({"checks": checks, "passed": failures.is_empty(), "failures": failures, "results": results}))
	quit(1 if not failures.is_empty() else 0)
