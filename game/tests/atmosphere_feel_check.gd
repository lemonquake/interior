extends SceneTree
## Run with a native mixer, not --headless: checks actual shelter mixing and camera limits.
## godot --path game --script res://tests/atmosphere_feel_check.gd --resolution 320x180

var failures: Array[String] = []
var checks := 0
var metrics := {}

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _advance(audio: InteriorNightAudio, ticks: int) -> void:
	for i in ticks:
		audio._process(.1)
		await process_frame

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("atmosphere_feel_check requires a native display/audio mixer")
		quit(1)
		return
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 10:
		await process_frame
	paused = true
	var player: InteriorPlayer = main.player
	var audio: InteriorNightAudio = main.get_node("NightAudio")
	player.set_process(false)
	audio.set_process(false)
	check(audio._ready_done, "Native night audio initialized")
	var wildlife := AudioServer.get_bus_index("Wildlife")
	check(wildlife >= 0 and AudioServer.get_bus_send(wildlife) == "Night", "Wildlife has its own bus under Night")
	check(audio._caller.bus == "Wildlife" and audio._wind.bus == "Night", "Wildlife changes leave wind and story bus independent")
	check(audio._crickets[0].volume_db <= -70.0, "New wildlife loops start quietly")

	player.camera.global_position = Vector3(0.0, 1.58, 0.0)
	await _advance(audio, 55)
	metrics.home_exposure = audio._exposure
	check(audio._exposure < .08 and audio._muffle.cutoff_hz < 1400.0, "Closed home muffles outdoor sounds")
	check(audio._outside_weight < .01, "Home uses small-room acoustics")
	var hut: InteriorHutHouse = main.story.hut
	player.camera.global_position = hut.global_transform * Vector3(0.0, 1.7, 0.0)
	check(hut.is_inside(player.camera.global_position), "Hut fixture is inside the real building")
	await _advance(audio, 55)
	metrics.hut_exposure = audio._exposure
	check(absf(audio._exposure - .36) < .01 and audio._outside_weight < .01, "Hut has sheltered acoustics despite outdoor ground height")
	check(audio._zone > .8, "Hut keeps the surrounding field wildlife region")

	player.camera.global_position = Vector3(21.0, -1.3, 70.0)
	await _advance(audio, 55)
	check(audio._exposure > .99 and audio._outside_weight > .99, "Returning outdoors restores open-air acoustics")
	var night_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Night"))
	audio._quiet_wait = 0.0
	audio._quiet_time = -1.0
	audio._update_quiet(.1, true)
	audio._quiet_length = 10.0
	for i in 50:
		audio._update_quiet(.1, true)
	metrics.quiet_wildlife_db = AudioServer.get_bus_volume_db(wildlife)
	check(float(metrics.quiet_wildlife_db) < -11.0, "Quiet interval lowers wildlife gradually")
	check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Night")), night_db), "Quiet intervals do not lower the siren/stranger bus")
	main.story.lights_out = true
	audio._quiet_time = -1.0
	audio._quiet_weight = 0.0
	for i in 150:
		audio._update_quiet(.1, true)
	check(audio._tension > .99 and audio._wildlife_db < -9.8, "Alarm creates a sustained quieter wildlife bed")

	player.velocity = Vector3.ZERO
	player.camera_motion = 1.0
	player._landing_offset = 0.0
	player._landing_velocity = -.85
	var lowest := 0.0
	for i in 90:
		player._update_camera(1.0 / 60.0, false)
		lowest = minf(lowest, player._landing_offset)
	metrics.landing_compression_m = -lowest
	check(lowest > -.045 and lowest < -.01, "Hard landing compression is perceptible and bounded")
	check(absf(player._landing_offset) < .0001, "Landing settles without prolonged bounce")
	player.velocity = Vector3(InteriorPlayer.RUN_SPEED, 0.0, 0.0)
	for i in 100:
		player._update_camera(1.0 / 60.0, true)
	check(player.camera.fov > player._base_fov + 3.0 and player.camera.fov <= player._base_fov + 3.51, "Sprint FOV remains bounded")
	player.camera_motion = 0.0
	for i in 120:
		player._update_camera(1.0 / 60.0, true)
	check(absf(player.camera.fov - player._base_fov) < .01, "Camera motion Off removes sprint FOV")
	check(is_zero_approx(player.camera.position.x) and is_zero_approx(player.camera.rotation.z) and is_equal_approx(player.camera.position.y, player._eye_y), "Camera motion Off removes bob, roll, landing and breath")
	player.kick(1.0)
	check(player.recoil > 0.0, "Camera motion Off preserves gun feedback")
	player.reset_motion(Vector3(0.0, .1, 0.0))
	check(is_zero_approx(player.recoil) and is_zero_approx(player._landing_velocity), "Teleport clears pending camera impulses")
	print("ATMOSPHERE_FEEL_CHECK ", JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "metrics": metrics}))
	quit(0 if failures.is_empty() else 1)
