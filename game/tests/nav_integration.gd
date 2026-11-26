extends SceneTree
## 0.33: the infected find a way round (scripts/zombie_nav.gd), headless:
##   godot --headless --path game --script res://tests/nav_integration.gd --fixed-fps 60
## In street B a wall with two wings is put up, open toward the south: a pocket. One of them stands in the pocket,
## the player beyond the wall. Called by a sound from there, without the route finder it presses against the wall
## and stays; with it, it backs out of the pocket, goes round and arrives. A search costs little and is remembered.

class ErrorCatcher extends Logger:
	var errors: Array[String] = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file, line, code, rationale])
	func _log_message(message: String, error: bool) -> void:
		pass

const POCKET := Vector3(21.0, -2.9, 32.4)
const BEYOND := Vector3(21.0, -2.9, 38.5)

var checks := 0
var failures: Array[String] = []
var main: Node
var player: InteriorPlayer
var zombies: InteriorZombies
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

func _wall(centre: Vector3, size: Vector3) -> void:
	var block := StaticBody3D.new()
	block.collision_layer = 2
	block.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	block.add_child(shape)
	main.add_child(block)
	block.global_position = centre + Vector3.UP * size.y * .5

## One of them in the pocket, called to where the player stands; how near it has come after `seconds`.
func _called(seconds: float) -> Dictionary:
	zombies.clear()
	await _frames(4)
	var kinds := InteriorZombie.KINDS.keys()
	var spot := zombies.ground(POCKET, false)
	var one := zombies.spawn(spot if spot.is_finite() else POCKET, "", 0.0, false, "walker" if kinds.has("walker") else str(kinds[0]))
	await _seconds(.5)
	var from := one.where()
	one.heard(player.global_position, 1.0, "shot")
	var nearest := 99.0
	var took := seconds
	for i in int(seconds * 60.0):
		await physics_frame
		if not is_instance_valid(one):
			break
		var far := Vector2(one.where().x - player.global_position.x, one.where().z - player.global_position.z).length()
		if far < nearest:
			nearest = far
		if far < 1.8:
			took = i / 60.0
			break
		if one.state != InteriorZombie.State.SEARCH and one.state != InteriorZombie.State.CHASE and one.state != InteriorZombie.State.ATTACK and one.state != InteriorZombie.State.ALERT:
			one.heard(player.global_position, 1.0, "shot")
	return {"nearest": nearest, "took": took, "from": from, "end": one.where() if is_instance_valid(one) else Vector3.ZERO}

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
	zombies.invulnerable = true
	await _seconds(1.0)
	check(zombies.nav != null, "The director has a route finder")
	var nav := zombies.nav
	var spot := zombies.ground(BEYOND, false)
	player.reset_motion(spot if spot.is_finite() else BEYOND)
	await _frames(20)
	# The pocket: a wall across the middle of the street at z 34.6, wings back to z 31.
	_wall(Vector3(21.0, -2.9, 34.6), Vector3(3.6, 2.3, .3))
	_wall(Vector3(19.35, -2.9, 32.8), Vector3(.3, 2.3, 3.6))
	_wall(Vector3(22.65, -2.9, 32.8), Vector3(.3, 2.3, 3.6))
	await _frames(4)

	zombies.nav = null
	var without: Dictionary = await _called(11.0)
	check(float(without.nearest) > 3.0, "Without it, one called from beyond the wall presses against it and stays (%.1f m off at best)" % float(without.nearest))
	zombies.nav = nav
	var with: Dictionary = await _called(22.0)
	check(float(with.nearest) < 1.8, "With it, it backs out of the pocket, goes round and arrives (%.1f m off, %.1f s)" % [float(with.nearest), float(with.took)])
	check(nav.searches >= 1 and nav.searches < 40, "It asked for a way a few times, not every frame (%d)" % nav.searches)

	# What a search costs.
	nav.space = main.get_viewport().world_3d.direct_space_state
	var started := Time.get_ticks_usec()
	var way := nav.path(Vector3(21.0, -2.9, 32.4), player.global_position)
	var warm := (Time.get_ticks_usec() - started) / 1000.0
	check(way.size() > 6 and warm < 12.0, "The same way again, remembered: %d points in %.1f ms (%d cells looked at)" % [way.size(), warm, nav.last_expanded])
	var probes := nav.probes
	started = Time.get_ticks_usec()
	var far := nav.path(Vector3(21.0, -2.9, 6.0), Vector3(21.0, -2.9, 30.0))
	var cold := (Time.get_ticks_usec() - started) / 1000.0
	check(far.size() > 20 and cold < 60.0, "A new way down 24 m of street: %d points in %.1f ms (%d cells looked at, %d new)" % [far.size(), cold, nav.last_expanded, nav.probes - probes])
	var bends := 0
	for i in range(2, far.size()):
		if absf((far[i] - far[i - 1]).normalized().dot((far[i - 1] - far[i - 2]).normalized())) < .99:
			bends += 1
	check(bends < far.size() / 2, "...and it does not zigzag (%d bends)" % bends)
	# Nowhere to stand: out in the paddy water.
	var none := nav.path(Vector3(40.0, -2.9, 120.0), Vector3(21.0, -2.9, 60.0))
	check(none.size() >= 0, "Asked from where nothing can stand, it answers without fuss (%d points)" % none.size())
	_finish()

func _finish() -> void:
	await _frames(4)
	check(catcher.errors.is_empty(), "No errors in the log (%d)" % catcher.errors.size())
	for line in catcher.errors.slice(0, 12):
		print("  ERROR ", line)
	print("NAV_INTEGRATION ", JSON.stringify({"checks": checks, "passed": failures.is_empty(), "failures": failures}))
	quit(1 if not failures.is_empty() else 0)
