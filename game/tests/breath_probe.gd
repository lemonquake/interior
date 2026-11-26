extends SceneTree
## 0.36: records what the breathing really sounds like through the game's own mixer, for a machine to look at:
##   godot --path game --script res://tests/breath_probe.gd -- --out=<folder> [--no-heart]
## (windowed: headless there is no mixer). Three takes of the Master bus, each a WAV in <folder>:
##   quiet.wav   standing in the room, rested and well: the level everything else is heard against
##   pant.wav    the lungs empty (stamina held at nothing), then left to fill again
##   hurt.wav    health at 25, standing still
##   run.wav     twelve seconds of running down the field road from rested
## work/v36/breath_levels.py reads them.

var main: Node
var capture: AudioEffectCapture
var _logged := -1

func _initialize() -> void:
	call_deferred("_run")

func _seconds(s: float) -> void:
	for i in int(ceil(s * 60.0)):
		await physics_frame

func _take(path: String, seconds: float, hold: Callable) -> void:
	capture.clear_buffer()
	var frames := PackedVector2Array()
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
		hold.call()
		var ready := capture.get_frames_available()
		if ready > 0:
			frames.append_array(capture.get_buffer(ready))
	var rate := int(AudioServer.get_mix_rate())
	var data := PackedByteArray()
	data.resize(frames.size() * 2)
	for i in frames.size():
		data.encode_s16(i * 2, int(clampf((frames[i].x + frames[i].y) * .5, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	wav.save_to_wav(path)
	print("BREATH_PROBE ", path.get_file(), " ", snappedf(float(frames.size()) / rate, .1), " s")

func _run() -> void:
	var out := "user://"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await _seconds(1.0)
	var body: InteriorBody = main.body
	var zombies: InteriorZombies = main.zombies
	zombies.passive = true
	var man := main.get_node_or_null("Stranger") as Node3D
	if man != null:
		man.process_mode = Node.PROCESS_MODE_DISABLED
	if "--no-heart" in OS.get_cmdline_user_args():
		# The breath alone (the heart beats over it at these states).
		body._heart.stream = null
	capture = AudioEffectCapture.new()
	capture.buffer_length = 2.0
	AudioServer.add_bus_effect(0, capture)
	await _seconds(2.0)
	await _take(out.path_join("quiet.wav"), 6.0, func() -> void: pass)
	# Empty for six seconds, then left alone: the panting should slow and die away as the breath comes back.
	var started := Time.get_ticks_msec()
	await _take(out.path_join("pant.wav"), 16.0, func() -> void:
		if Time.get_ticks_msec() - started < 6000:
			body.stamina = 0.0
			body._since_sprint = 0.0
		var second := (Time.get_ticks_msec() - started) / 500
		if second != _logged:
			_logged = second
			print("BREATH_STATE %4.1f s  stamina %.2f  puff %.2f  panting %s  %.0f dB  x%.2f" % [second * .5, body.stamina, body.puff, body.panting, body._pant.volume_db, body._pant.pitch_scale]))
	body.heal()
	await _seconds(3.0)
	await _take(out.path_join("hurt.wav"), 12.0, func() -> void:
		zombies.health = 25.0)
	# A real run down the field road from rested: steps and the night alone at first, the panting from about
	# the fifth second.
	body.heal()
	var player: InteriorPlayer = main.player
	var road := zombies.ground(Vector3(21.0, -2.75, 62.0), false)
	player.reset_motion(road)
	player.rotation = Vector3(0, PI, 0)
	await _seconds(4.0)
	Input.action_press("run")
	Input.action_press("forward")
	await _take(out.path_join("run.wav"), 12.0, func() -> void: pass)
	Input.action_release("run")
	Input.action_release("forward")
	print("BREATH_PROBE run ended with stamina ", snappedf(body.stamina, .01), " puff ", snappedf(body.puff, .01))
	print("BREATH_PROBE done, slow breaths ", body.breaths)
	quit(0)
