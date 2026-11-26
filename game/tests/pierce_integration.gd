extends SceneTree
## 0.33: thin cover does not stop a round (scripts/gun.gd), headless:
##   godot --headless --path game --script res://tests/pierce_integration.gd --fixed-fps 60
## On the field road, against things put there for the test: a pistol round goes through a five-centimetre board
## and strikes the wall behind it with less than it had; a half-metre baulk keeps it; so does a thin slab of
## concrete. Sheet iron as the world builds it stops the pistol and not the rifle. One of them standing behind a
## board is hit through it.

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
var gun: InteriorGun
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

func _clear() -> void:
	for block in blocks:
		block.queue_free()
	blocks.clear()
	await _frames(3)

## A slab `ahead` metres in front of the lens, `thick` deep, of `surface` ("" for bare concrete).
func _slab(ahead: float, thick: float, surface: String) -> StaticBody3D:
	var forward := -player.global_basis.z
	var block := StaticBody3D.new()
	block.collision_layer = 2
	block.collision_mask = 0
	if surface != "":
		block.set_meta("surface", surface)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 2.4, thick)
	shape.shape = box
	block.add_child(shape)
	main.add_child(block)
	block.global_transform = Transform3D(player.global_basis, player.global_position + forward * (ahead + thick * .5) + Vector3.UP * 1.2)
	blocks.append(block)
	return block

func _shot() -> Array:
	gun.mag = gun.mag_size()
	gun.chambered = true
	for i in 120:
		if gun.ready_to_fire():
			break
		await physics_frame
	gun.try_fire()
	await _frames(3)
	var hits: Array = gun.last_hits.duplicate()
	await _seconds(.5)
	return hits

func _run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await _frames(6)
	player = main.player
	zombies = main.zombies
	var man := main.get_node_or_null("Stranger") as Node3D
	if man != null:
		man.process_mode = Node.PROCESS_MODE_DISABLED
	zombies.passive = true
	zombies.invulnerable = true
	await _seconds(1.0)
	var spot := zombies.ground(ROAD, false)
	player.reset_motion(spot if spot.is_finite() else ROAD)
	player.rotation = Vector3(0, PI, 0)
	await _frames(24)
	main.story.debug_give_gun()
	gun = main.story.gun
	gun.draw()
	gun.spread_scale = 0.0
	gun.instant_hits = true
	gun.infinite_ammo = true
	player.free_aim = false
	await _seconds(1.3)

	# ---- a board, and a wall behind it
	_slab(3.0, .05, "wood")
	_slab(5.0, .6, "")
	await _frames(3)
	var was := gun.pierced
	var hits: Array = await _shot()
	check(hits.size() == 2 and str(hits[0].surface) == "wood" and str(hits[1].surface) == "stone", "A pistol round goes through a 5 cm board and strikes the wall behind (%d struck)" % hits.size())
	if hits.size() == 2:
		check(float(hits[1].power) < float(hits[0].power) * .6 and float(hits[1].power) > .05, "...with less than it had (%.2f, then %.2f)" % [hits[0].power, hits[1].power])
		check(absf(float(hits[1].distance) - float(hits[0].distance) - 2.0) < .12, "...two metres further on (%.2f m)" % (float(hits[1].distance) - float(hits[0].distance)))
	check(gun.pierced == was + 1, "It tore a hole coming out")
	await _clear()

	# ---- too thick; and stone
	_slab(3.0, .5, "wood")
	_slab(5.0, .6, "")
	await _frames(3)
	hits = await _shot()
	check(hits.size() == 1 and str(hits[0].surface) == "wood", "A half-metre baulk keeps it (%d struck)" % hits.size())
	await _clear()
	_slab(3.0, .05, "")
	_slab(5.0, .6, "")
	await _frames(3)
	hits = await _shot()
	check(hits.size() == 1 and str(hits[0].surface) == "stone", "So does a thin slab of concrete (%d struck)" % hits.size())
	await _clear()

	# ---- sheet iron: the pistol no, the rifle yes
	_slab(3.0, .22, "metal")
	_slab(5.0, .6, "")
	await _frames(3)
	hits = await _shot()
	check(hits.size() == 1, "A fence of roofing iron stops the pistol (%d struck)" % hits.size())
	gun.give_rifle()
	gun.select("rifle")
	await _seconds(2.0)
	gun.automatic = false
	hits = await _shot()
	check(gun.weapon == "rifle" and hits.size() == 2 and str(hits[0].surface) == "metal", "...and not the rifle (%d struck)" % hits.size())
	await _clear()

	# ---- someone behind a board
	_slab(2.5, .04, "wood")
	var forward := -player.global_basis.z
	var kinds := InteriorZombie.KINDS.keys()
	var one := zombies.spawn(player.global_position + forward * 3.6, "", atan2(-forward.x, -forward.z), false, "walker" if kinds.has("walker") else str(kinds[0]))
	await _seconds(.8)
	var before := one.health if one != null else 0.0
	player.camera.rotation.x = -.12
	await _frames(2)
	hits = await _shot()
	check(one != null and one.health < before and hits.size() >= 2 and str(hits[1].surface) == "flesh", "One of them behind a board is hit through it (%.0f of %.0f left)" % [one.health if one != null else 0.0, before])
	_finish()

func _finish() -> void:
	await _frames(4)
	check(catcher.errors.is_empty(), "No errors in the log (%d)" % catcher.errors.size())
	for line in catcher.errors.slice(0, 12):
		print("  ERROR ", line)
	print("PIERCE_INTEGRATION ", JSON.stringify({"checks": checks, "passed": failures.is_empty(), "failures": failures}))
	quit(1 if not failures.is_empty() else 0)
