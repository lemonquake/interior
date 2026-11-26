extends SceneTree
## 0.33: the place is heard (scripts/sound_stage.gd), headless:
##   godot --headless --path game --script res://tests/sound_integration.gd --fixed-fps 60
## The field road is open sky; the living room is a small roofed room; the Nichols tunnel is roofed and tight
## although the map calls it outdoors, and a shot there gets the tunnel's reverb and no tail off the fields. In
## the street a shot slaps back off the houses; in the fields it does not. A voice behind a wall is muffled and
## comes back when the wall is gone.

class ErrorCatcher extends Logger:
	var errors: Array[String] = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file, line, code, rationale])
	func _log_message(message: String, error: bool) -> void:
		pass

const FIELDS := Vector3(21.0, -2.75, 118.0)
const NICHOLS := preload("res://scripts/nichols_property.gd")

var checks := 0
var failures: Array[String] = []
var main: Node
var player: InteriorPlayer
var stage: InteriorSoundStage
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

func _go(at: Vector3) -> void:
	player.reset_motion(at)
	await _seconds(2.2)

func _run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await _frames(6)
	player = main.player
	stage = main.get("sound_stage")
	check(stage != null, "The scene has a sound stage")
	if stage == null:
		_finish()
		return
	var man := main.get_node_or_null("Stranger") as Node3D
	if man != null:
		man.process_mode = Node.PROCESS_MODE_DISABLED
	main.zombies.passive = true
	await _seconds(2.0)

	# ---- the living room
	check(stage.roofed > .8 and stage.size < 9.0 and not stage.open_sky(), "The living room: a roof, and the walls close (roofed %.2f, %.1f m)" % [stage.roofed, stage.size])

	# ---- the fields
	var route: Array = main.story.hut.crow_route
	var open: Vector3 = route[route.size() / 2]
	open = main.zombies.ground(open, false) if main.zombies.ground(open, false).is_finite() else open
	await _go(open if open.is_finite() else FIELDS)
	check(stage.roofed < .15 and stage.open_sky() and stage.walled < .4, "The road through the fields: open sky, nothing round it (roofed %.2f, walled %.2f)" % [stage.roofed, stage.walled])
	main.story.debug_give_gun()
	var gun: InteriorGun = main.story.gun
	gun.draw()
	gun.infinite_ammo = true
	await _seconds(1.4)
	gun.mag = gun.mag_size()
	gun.chambered = true
	gun.try_fire()
	await _seconds(.4)
	var bus := AudioServer.get_bus_index("Gun")
	var reverb := AudioServer.get_bus_effect(bus, 0) as AudioEffectReverb
	var slap: AudioEffectDelay = null
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) is AudioEffectDelay:
			slap = AudioServer.get_bus_effect(bus, i)
	var field_room := reverb.room_size
	check(slap != null and slap.tap1_level_db < -45.0 and gun._tail_voice.playing, "A shot there: no slap off any wall (%.0f dB), and the tail comes back off the fields" % (slap.tap1_level_db if slap != null else 0.0))

	# ---- the street
	await _go(Vector3(18.9, -2.75, 6.0))
	check(stage.open_sky() and stage.walled > .5, "The lane by the gate: open sky between walls (walled %.2f, nearest %.1f m)" % [stage.walled, stage.nearest])
	check(slap != null and slap.tap1_level_db > -30.0 and slap.tap1_delay_ms < 120.0, "A shot there slaps back off the nearest wall (%.0f dB after %.0f ms)" % [slap.tap1_level_db if slap != null else 0.0, slap.tap1_delay_ms if slap != null else 0.0])

	# ---- the tunnel under the Nichols house
	await _go(NICHOLS.local(2.6, 16.8, -3.4))
	check(stage.roofed > .8 and stage.size < 7.0 and not stage.open_sky(), "The tunnel: shut in and tight, though the map calls it outdoors (roofed %.2f, %.1f m)" % [stage.roofed, stage.size])
	gun.mag = gun.mag_size()
	gun.chambered = true
	gun._tail_voice.stop()
	gun.try_fire()
	await _frames(3)
	check(reverb.room_size < field_room - .2 and reverb.wet > .3 and not gun._tail_voice.playing, "A shot there has the tunnel's reverb, tight and loud (room %.2f, wet %.2f), and no tail" % [reverb.room_size, reverb.wet])
	check(slap != null and slap.tap1_level_db < -45.0, "...and no outdoor slap")

	# ---- behind a wall
	await _go(open if open.is_finite() else FIELDS)
	player.rotation = Vector3(0, PI, 0)
	await _frames(4)
	gun.holster(true)
	var forward := -player.global_basis.z
	var voice := AudioStreamPlayer3D.new()
	voice.bus = "Gun"
	voice.stream = InteriorBody._heartbeat()
	voice.max_distance = 40.0
	main.add_child(voice)
	voice.global_position = player.camera.global_position + forward * 8.0
	await _frames(3)
	var base_hz := voice.attenuation_filter_cutoff_hz
	var base_db := voice.max_db
	for i in 60:
		voice.play()
		await _frames(2)
	check(absf(voice.attenuation_filter_cutoff_hz - base_hz) < 1.0 and float(voice.get_meta("stage_shut", -1.0)) == 0.0, "A voice eight metres off in the open is heard whole (%.0f Hz)" % voice.attenuation_filter_cutoff_hz)
	var wall := StaticBody3D.new()
	wall.collision_layer = 2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 5.0, .3)
	shape.shape = box
	wall.add_child(shape)
	main.add_child(wall)
	wall.global_transform = Transform3D(player.global_basis, player.camera.global_position + forward * 4.0)
	for i in 60:
		voice.play()
		await _frames(2)
	check(voice.attenuation_filter_cutoff_hz < 900.0 and voice.max_db < base_db - 5.0 and stage.muffled >= 1, "A wall between: it loses its top and some of its level (%.0f Hz, %.0f dB)" % [voice.attenuation_filter_cutoff_hz, voice.max_db - base_db])
	wall.queue_free()
	for i in 60:
		voice.play()
		await _frames(2)
	check(absf(voice.attenuation_filter_cutoff_hz - base_hz) < 1.0 and absf(voice.max_db - base_db) < .1, "The wall gone, it is whole again")
	_finish()

func _finish() -> void:
	await _frames(4)
	check(catcher.errors.is_empty(), "No errors in the log (%d)" % catcher.errors.size())
	for line in catcher.errors.slice(0, 12):
		print("  ERROR ", line)
	print("SOUND_INTEGRATION ", JSON.stringify({"checks": checks, "passed": failures.is_empty(), "failures": failures}))
	quit(1 if not failures.is_empty() else 0)
