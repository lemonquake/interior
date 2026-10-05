class_name InteriorNeighborhood
extends Node3D
## Runtime glue for the neighbourhood (built by scripts/neighborhood_builder.gd inside the baked
## balcony scene). It only matters while the balcony is visible (door open or player outside):
## - model instances (trees, AC units, chairs) go on the outdoor visual layer, foliage gets alpha
##   scissor and small plants fade out with distance;
## - the sky dome follows the camera and the camera's far plane opens up to it;
## - the room's WorldEnvironment gets depth fog (begins 14 m out, thick by ~220 m) and is restored
##   when the balcony hides again, so the room renders exactly as before with the door shut.

const OUTDOOR_LAYER := 2
const FAR := 900.0
const FOG_COLOR := Color(.58, .61, .62)

var _env: Environment
var _saved_far := -1.0
var _active := false
var _tier := -2
## Ghost-town ambience (run 6): gusty wind and a low drone that swell at street level, and
## distant metal knocks somewhere in the empty streets.
var _wind: AudioStreamPlayer
var _drone: AudioStreamPlayer
var _knock: AudioStreamPlayer3D
var _knocks: Array[AudioStream] = []
var _knock_wait := 8.0
var _saved_grade: Array = []
var _graded := false

func _ready() -> void:
	add_to_group("neighbourhood")
	var mobile := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	for node in find_children("*", "Node3D", true, false):
		if node.has_meta("keep_instance"):
			var fade := float(node.get_meta("fade", 0.0))
			if mobile and node.has_meta("tree") and fade == 0.0:
				fade = 160.0
			InteriorModelKit.prepare_instance(node, OUTDOOR_LAYER, fade, not mobile or node.has_meta("tree"), node.has_meta("tree"))
	if DisplayServer.get_name() != "headless":
		_setup_ambience()
	# Overcast sky: no visible sun disc, a dimmer grey panorama melting into the fog colour.
	var dome := get_node_or_null("Sky dome") as MeshInstance3D
	if dome != null and dome.material_override is ShaderMaterial:
		var sky := dome.material_override as ShaderMaterial
		sky.set_shader_parameter("exposure", .36)
		sky.set_shader_parameter("sun_color", Color(.22, .22, .22))
		sky.set_shader_parameter("horizon_color", FOG_COLOR)
		sky.set_shader_parameter("horizon_band", .3)

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var shown := is_visible_in_tree()
	if shown != _active:
		_active = shown
		_apply_fog(shown)
		if camera != null:
			if shown:
				_saved_far = camera.far if _saved_far < 0.0 else _saved_far
				camera.far = FAR
			elif _saved_far > 0.0:
				camera.far = _saved_far
	_update_ambience(shown, camera, delta)
	var outdoors := shown and camera != null and (camera.global_position.y < -.4 or (camera.global_position.z > 2.62 and camera.global_position.x > .8))
	if outdoors != _graded:
		_graded = outdoors
		_apply_grade(outdoors)
	if not shown or camera == null:
		return
	var dome := get_node_or_null("Sky dome") as Node3D
	if dome != null:
		dome.global_position = camera.global_position
	var lighting := InteriorLighting.find_in(get_tree().current_scene if get_tree().current_scene != null else get_parent())
	var tier := lighting.tier if lighting != null else 2
	if tier != _tier:
		_tier = tier
		var sun := get_parent().get_node_or_null("Sun") as DirectionalLight3D
		if sun != null:
			sun.directional_shadow_max_distance = 70.0 if tier >= 3 else (45.0 if tier >= 2 else 30.0)

func _environment() -> Environment:
	if _env != null:
		return _env
	for node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		_env = (node as WorldEnvironment).environment
		break
	return _env

func _apply_fog(on: bool) -> void:
	var env := _environment()
	if env == null:
		return
	env.fog_enabled = on
	if not on:
		return
	# Thick, colourless haze: the far end of every street dissolves (ghost town, run 6).
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = FOG_COLOR
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = .03
	env.fog_depth_begin = 3.0
	env.fog_depth_end = 70.0
	env.fog_depth_curve = 1.1
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.0


# ---------------------------------------------------------------- ambience

func _setup_ambience() -> void:
	_wind = AudioStreamPlayer.new()
	_wind.stream = _wind_loop()
	_wind.volume_db = -80.0
	add_child(_wind)
	_drone = AudioStreamPlayer.new()
	_drone.stream = _drone_loop()
	_drone.volume_db = -80.0
	add_child(_drone)
	_knock = AudioStreamPlayer3D.new()
	_knock.unit_size = 10.0
	_knock.max_distance = 60.0
	_knock.attenuation_filter_cutoff_hz = 2500.0
	add_child(_knock)
	for path in ["res://assets/audio/sfx/impactMetal_heavy_002.ogg", "res://assets/audio/sfx/impactMetal_light_001.ogg", "res://assets/audio/sfx/impactPlate_medium_000.ogg"]:
		if ResourceLoader.exists(path):
			_knocks.append(load(path))

func _update_ambience(shown: bool, camera: Camera3D, delta: float) -> void:
	if _wind == null:
		return
	var street := shown and camera != null and camera.global_position.y < -.4
	var wind_db := -13.0 if street else (-22.0 if shown else -80.0)
	var drone_db := -20.0 if street else -80.0
	_wind.volume_db = move_toward(_wind.volume_db, wind_db, delta * 18.0)
	_drone.volume_db = move_toward(_drone.volume_db, drone_db, delta * 12.0)
	for player in [_wind, _drone]:
		var audible: bool = player.volume_db > -70.0
		if audible and not player.playing:
			player.play()
		elif not audible and player.playing:
			player.stop()
	if street and not _knocks.is_empty():
		_knock_wait -= delta
		if _knock_wait <= 0.0:
			_knock_wait = randf_range(9.0, 24.0)
			var angle := randf() * TAU
			_knock.global_position = camera.global_position + Vector3(cos(angle), 0, sin(angle)) * randf_range(18.0, 35.0)
			_knock.stream = _knocks[randi() % _knocks.size()]
			_knock.pitch_scale = randf_range(.45, .7)
			_knock.volume_db = randf_range(-6.0, 0.0)
			_knock.play()

func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 26000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = samples.size()
	return stream

## Band-limited noise with slow gusts; the loop is crossfaded so it never clicks.
func _wind_loop() -> AudioStreamWAV:
	var rate := 22050
	var count := rate * 8
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var raw := PackedFloat32Array()
	raw.resize(count)
	var lp1 := 0.0
	var lp2 := 0.0
	for i in count:
		var t := float(i) / rate
		var gust := .45 + .35 * sin(t * TAU / 8.0) + .2 * sin(t * TAU * 3.0 / 8.0 + 1.3)
		var cutoff := .02 + .05 * gust
		lp1 = lerpf(lp1, rng.randf_range(-1.0, 1.0), cutoff)
		lp2 = lerpf(lp2, lp1, cutoff)
		raw[i] = lp2 * 3.2 * gust
	var fade := rate
	for i in fade:
		var w := float(i) / fade
		raw[i] = raw[i] * w + raw[count - fade + i] * (1.0 - w)
	raw.resize(count - fade)
	return _wav(raw)

## Two low detuned tones beating against each other, barely there.
func _drone_loop() -> AudioStreamWAV:
	var rate := 22050
	var count := rate * 6
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		var t := float(i) / rate
		out[i] = (sin(t * TAU * 55.0) * .5 + sin(t * TAU * 55.5) * .5 + sin(t * TAU * 82.5) * .25 * (.5 + .5 * sin(t * TAU / 6.0))) * .35
	return _wav(out)

## Drained, slightly darker colour while the player is outdoors; the room's own grading returns inside.
func _apply_grade(on: bool) -> void:
	var env := _environment()
	if env == null:
		return
	if on:
		_saved_grade = [env.adjustment_enabled, env.adjustment_saturation, env.adjustment_contrast, env.adjustment_brightness]
		env.adjustment_enabled = true
		env.adjustment_saturation = .68
		env.adjustment_contrast = 1.06
		env.adjustment_brightness = .94
	elif not _saved_grade.is_empty():
		env.adjustment_enabled = _saved_grade[0]
		env.adjustment_saturation = _saved_grade[1]
		env.adjustment_contrast = _saved_grade[2]
		env.adjustment_brightness = _saved_grade[3]
