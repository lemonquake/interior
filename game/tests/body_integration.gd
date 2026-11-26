extends SceneTree
## 0.33: the body in danger and the new movement (scripts/body.gd, scripts/player.gd), headless:
##   godot --headless --path game --script res://tests/body_integration.gd --fixed-fps 60
## On the field road, against blocks put there for the test: Space at a chest-high block climbs it; a low thin
## wall is gone over; a wall too tall is only jumped at; a ledge out of reach from the ground is caught off a jump.
## Z / X lean the eye sideways, and not through a wall. A blow bleeds until H binds it (the gun is down meanwhile);
## under 35 the limp is full, there is no running and the heart is heard; healed, the run comes back; winded, it
## sags. A long fall hurts. V sends what stands in front reeling.

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
var body: InteriorBody
var catcher := ErrorCatcher.new()
var blocks: Array[StaticBody3D] = []

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

func _stand(at: Vector3, yaw := PI) -> void:
	for block in blocks:
		block.queue_free()
	blocks.clear()
	var spot := zombies.ground(at, false)
	player.reset_motion(spot if spot.is_finite() else at)
	player.rotation = Vector3(0, yaw, 0)
	await _frames(24)

## A block of the fixed world `ahead` metres in front of the player (to its near face), standing on the player's ground.
func _block(ahead: float, size: Vector3, side := 0.0, lift := 0.0) -> StaticBody3D:
	var forward := -player.global_basis.z
	var block := StaticBody3D.new()
	block.collision_layer = 2
	block.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	block.add_child(shape)
	main.add_child(block)
	block.global_transform = Transform3D(player.global_basis, player.global_position + forward * (ahead + size.z * .5) + player.global_basis.x * side + Vector3.UP * (size.y * .5 + lift))
	blocks.append(block)
	return block

func _run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await _frames(6)
	player = main.player
	zombies = main.zombies
	body = main.get("body")
	check(body != null and zombies != null and zombies.body == body, "The scene has a body, and the director knows it")
	if body == null:
		_finish()
		return
	var man := main.get_node_or_null("Stranger") as Node3D
	if man != null:
		man.process_mode = Node.PROCESS_MODE_DISABLED
	zombies.passive = true
	await _seconds(1.0)

	# ---- climb
	await _stand(ROAD)
	var forward := -player.global_basis.z
	var start := player.global_position
	_block(.55, Vector3(3.0, 1.0, 2.0))
	await _frames(3)
	player.request_jump()
	await _frames(3)
	check(player.mantling and not bool(player._mantle.over), "Space at a block a metre high: the hands go onto it")
	var dipped := 0.0
	var tipped := 0.0
	for i in 90:
		await physics_frame
		dipped = minf(dipped, player._mantle_eye)
		tipped = minf(tipped, player._mantle_tilt.x)
		if not player.mantling:
			break
	await _frames(10)
	var rose := player.global_position.y - start.y
	var went := (player.global_position - start).dot(forward)
	check(not player.mantling and absf(rose - 1.0) < .06 and went > .7 and player.is_on_floor(), "...and the body is on top of it (up %.2f m, forward %.2f m)" % [rose, went])
	check(dipped < -.2 and tipped < -.1, "The eye sank and the lens tipped over the edge on the way (%.2f m, %.2f rad)" % [dipped, tipped])

	# ---- lean
	Input.action_press("lean_right")
	await _seconds(.6)
	var out := (player.camera.global_position - player.global_position).dot(player.global_basis.x)
	var roll := player.camera.rotation.z
	Input.action_release("lean_right")
	check(player.peek > .3 and out > .3 and roll < -.08, "X leans the eye to the right and rolls it (%.2f m, %.2f rad)" % [out, roll])
	await _seconds(.6)
	check(absf(player.peek) < .01, "Let go, it comes back")
	_block(-.5, Vector3(.2, 2.4, 2.0), -.45, 1.0)
	await _frames(3)
	Input.action_press("lean_left")
	await _seconds(.6)
	var left := -player.peek
	Input.action_release("lean_left")
	check(left < .2 and left >= 0.0, "Z with a wall a hand away on the left: the head stops short of it (%.2f m)" % left)
	await _seconds(.4)

	# ---- vault
	await _stand(ROAD + Vector3(0, 0, 6.0))
	forward = -player.global_basis.z
	start = player.global_position
	_block(.5, Vector3(3.0, .9, .2))
	await _frames(3)
	player.request_jump()
	await _frames(3)
	check(player.mantling and bool(player._mantle.over), "Space at a low thin wall: over it")
	await _seconds(1.3)
	went = (player.global_position - start).dot(forward)
	check(not player.mantling and went > 1.2 and absf(player.global_position.y - start.y) < .08, "...and down on the far side (%.2f m on, %.2f m up)" % [went, player.global_position.y - start.y])

	# ---- too tall; and off a jump
	await _stand(ROAD + Vector3(0, 0, 12.0))
	start = player.global_position
	_block(.5, Vector3(3.0, 2.6, .4))
	await _frames(3)
	player.request_jump()
	await _frames(4)
	check(not player.mantling and player.velocity.y > 2.0, "A wall taller than the hands reach is only jumped at")
	await _seconds(1.0)
	await _stand(ROAD + Vector3(0, 0, 18.0))
	forward = -player.global_basis.z
	start = player.global_position
	_block(.5, Vector3(3.0, 1.7, 2.0))
	await _frames(3)
	player.request_jump()
	await _frames(3)
	var jumped := not player.mantling and player.velocity.y > 2.0
	Input.action_press("jump")
	Input.action_press("forward")
	var caught := false
	for i in 50:
		await physics_frame
		caught = caught or player.mantling
	Input.action_release("jump")
	Input.action_release("forward")
	await _seconds(1.4)
	rose = player.global_position.y - start.y
	check(jumped and caught and absf(rose - 1.7) < .08, "A ledge 1.7 m up: a jump first, and the hands catch it (jumped %s, caught %s, up %.2f m)" % [jumped, caught, rose])

	# ---- wounds
	await _stand(ROAD + Vector3(0, 0, 24.0))
	main.story.debug_give_gun()
	var gun: InteriorGun = main.story.gun
	gun.draw()
	await _seconds(1.2)
	zombies.hurt_player(30.0, player.global_position + player.global_basis.x)
	await _frames(2)
	check(absf(zombies.health - 70.0) < 1.0 and body.bleeding > .5 and player.limp_side == 1.0, "A blow from the right takes 30 and opens a wound on that side (bleeding %.2f a second)" % body.bleeding)
	await _seconds(3.0)
	var bled := 70.0 - zombies.health
	check(bled > 1.5 and bled < 6.0, "Left alone it bleeds (%.1f more in three seconds)" % bled)
	Input.action_press("heal")
	await _seconds(1.0)
	var stowed := gun._stow
	gun.mag = gun.mag_size()
	gun.chambered = true
	var before := gun.loaded()
	gun.try_fire()
	await _frames(2)
	check(player.hands_busy and stowed > .6 and gun.loaded() == before, "H held: the hands are busy, the gun is down and does not fire (%.2f)" % stowed)
	await _seconds(2.0)
	Input.action_release("heal")
	await _frames(3)
	check(body.bleeding == 0.0 and not player.hands_busy, "Two and a half seconds: bound, and the hands are free")
	var held_at := zombies.health
	await _seconds(8.0)
	check(zombies.health > held_at + 2.0 and zombies.health <= body.ceiling + .01 and body.ceiling < 95.0, "Rest brings some of it back, not all (%.0f, of %.0f at most for now)" % [zombies.health, body.ceiling])

	# ---- critical: the limp
	zombies.hurt_player(zombies.health - 30.0, player.global_position - player.global_basis.x)
	body.bleeding = 0.0
	await _seconds(2.0)
	check(body.critical and not player.can_run and player.limp > .9 and player.limp_side == -1.0, "At 30 it is critical: a full limp, on the left now (%.2f)" % player.limp)
	gun.holster(true)
	Input.action_press("run")
	Input.action_press("forward")
	await _seconds(1.0)
	var from := player.global_position
	var fastest := 0.0
	var slowest := 99.0
	var pitched := 0.0
	for i in 180:
		await physics_frame
		var pace := Vector2(player.velocity.x, player.velocity.z).length()
		fastest = maxf(fastest, pace)
		slowest = minf(slowest, pace)
		pitched = minf(pitched, player._limp_pitch)
	var mean := player.global_position.distance_to(from) / 3.0
	Input.action_release("run")
	Input.action_release("forward")
	check(mean < 1.75 and mean > .9 and not player.is_sprinting, "Shift does nothing: a hobble (%.2f m/s)" % mean)
	check(fastest - slowest > .3 and pitched < -.015, "...uneven: the pace sags and the lens dips on the bad leg (%.2f to %.2f m/s, %.3f rad)" % [slowest, fastest, pitched])
	check(body._heart.volume_db > -24.0 and body._beat_env >= 0.0 and zombies.pulse >= 0.0, "The heart is heard (%.0f dB)" % body._heart.volume_db)
	check(body._heavy.size() >= 8 and body._pant.stream is AudioStreamWAV and (body._pant.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "The breathing recordings are there (%d slow breaths and the panting loop)" % body._heavy.size())
	check(body.breaths >= 1 and not body.panting and body._breath.volume_db > -16.0, "...and the breath: slow and heavy (%d so far, %.0f dB), no panting" % [body.breaths, body._breath.volume_db])
	player.request_jump()
	await _frames(3)
	check(player.velocity.y > 2.0 and player.velocity.y < InteriorPlayer.JUMP_SPEED * .75, "A jump on it is a poor one (%.1f m/s up)" % player.velocity.y)
	await _seconds(1.0)

	# ---- well again; breath
	body.heal()
	await _seconds(2.5)
	check(not body.critical and player.can_run and player.limp < .02, "Healed: no limp")
	var heavy_before := body.breaths
	await _seconds(4.5)
	check(body.breaths == heavy_before and not body.panting, "...and the breath is quiet (%d more)" % (body.breaths - heavy_before))
	Input.action_press("run")
	Input.action_press("forward")
	await _seconds(2.0)
	var run := Vector2(player.velocity.x, player.velocity.z).length()
	check(run > 4.3 and body.stamina < .9, "It runs again (%.1f m/s), and running costs breath (%.2f left)" % [run, body.stamina])
	body.stamina = .0
	await _seconds(1.0)
	var jog := Vector2(player.velocity.x, player.velocity.z).length()
	Input.action_release("run")
	Input.action_release("forward")
	check(jog < 3.8 and player.winded > .9, "Out of breath the run is a jog (%.1f m/s)" % jog)
	check(body.panting and body.puff > .6 and body._pant.volume_db > -17.0, "...and it pants (%.2f, %.0f dB)" % [body.puff, body._pant.volume_db])
	await _seconds(.5)

	# ---- a fall
	body.heal()
	await _stand(ROAD + Vector3(0, 0, 30.0))
	player.global_position += Vector3.UP * 4.5
	player.reset_physics_interpolation()
	await _seconds(1.6)
	check(zombies.health < 85.0 and zombies.health > 55.0 and player.is_on_floor(), "A fall of four and a half metres hurts (%.0f left)" % zombies.health)
	check(body.bleeding == 0.0, "...but opens no wound")
	body.heal()
	player.global_position += Vector3.UP * 1.2
	await _seconds(1.2)
	check(zombies.health == 100.0, "A drop of a metre does not")
	check(not body.panting and body.puff < .05, "Rested, the panting has stopped (%.2f)" % body.puff)

	# ---- shove
	await _stand(ROAD + Vector3(0, 0, 36.0))
	forward = -player.global_basis.z
	var kinds := InteriorZombie.KINDS.keys()
	var one := zombies.spawn(player.global_position + forward * 1.2, "", atan2(-forward.x, -forward.z), false, "walker" if kinds.has("walker") else str(kinds[0]))
	check(one != null, "One of them stands at arm's length")
	if one != null:
		await _seconds(.6)
		var was := one.where().distance_to(player.global_position)
		var struck := body.shove()
		await _frames(3)
		check(struck == 1 and one.state == InteriorZombie.State.STAGGER, "V: it reels (%d struck)" % struck)
		await _seconds(.7)
		var now := one.where().distance_to(player.global_position)
		check(now > was + .25, "...back out of reach (%.2f m to %.2f m)" % [was, now])
		check(body.shove() == -1 or body._since_shove < InteriorBody.SHOVE_WAIT, "It cannot be done again at once")
	_finish()

func _finish() -> void:
	await _frames(4)
	check(catcher.errors.is_empty(), "No errors in the log (%d)" % catcher.errors.size())
	for line in catcher.errors.slice(0, 12):
		print("  ERROR ", line)
	print("BODY_INTEGRATION ", JSON.stringify({"checks": checks, "passed": failures.is_empty(), "failures": failures}))
	quit(1 if not failures.is_empty() else 0)
