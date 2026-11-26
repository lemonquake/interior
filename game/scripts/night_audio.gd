class_name InteriorNightAudio
extends Node3D
## The night outside (0.7), all positional (3D):
## - Footsteps echo outdoors: the "Steps" bus gets a short slapback off the houses in town and a long,
##   faint echo across the fields (reverb + two delay taps), with short room reflections indoors.
## - Crickets chirp from the grass around you and fall silent when you walk right up to them.
## - Frog choruses rise from the paddies; single toads call close by; owls hoot from tree tops, now and
##   then a barn owl screeches; a tokay gecko calls "to-kay" from a house or the abandoned hut.
## - The wind comes and goes in gusts that sweep past you. Each gust also drives the global shader
##   value wind_gust, so the rice and the verge grass bow and the paddies ripple with what you hear.
## - Dogs bark far off (70-160 m) at random, long intervals; sometimes another dog answers from elsewhere.
## - Inside the house the night is muffled (low-passed) and quiet; with the door open it leaks in.
## Recordings: assets/audio/night (Wikimedia Commons; see licenses/NIGHT_SOUNDS.md).

const NIGHT := "res://assets/audio/night/"
const STEPS_BUS := "Steps"
const NATURE_BUS := "Night"
const WILDLIFE_BUS := "Wildlife"
const CRICKET_COUNT := 7
const FROG_COUNT := 4
const DOG_CLIPS := ["dog_bark_a", "dog_bark_b", "dog_bark_c", "dog_bark_d", "dog_bark_e", "dog_pack"]

var player: InteriorPlayer
var _ready_done := false
var _crickets: Array[AudioStreamPlayer3D] = []
var _cricket_quiet: Array[float] = []
var _frogs: Array[AudioStreamPlayer3D] = []
var _far_chorus: AudioStreamPlayer3D
var _caller: AudioStreamPlayer3D
var _toad: AudioStreamPlayer3D
var _creak: AudioStreamPlayer3D
var _wind: AudioStreamPlayer
var _gust: AudioStreamPlayer3D
var _drone: AudioStreamPlayer
var _knock: AudioStreamPlayer3D
var _dog: AudioStreamPlayer3D
var _dog_answer: AudioStreamPlayer3D
var _dog_wait := 0.0
var _answer_wait := -1.0
var _last_dog := ""
var _streams: Dictionary = {}
var _knocks: Array[AudioStream] = []
var _reverb: AudioEffectReverb
var _delay: AudioEffectDelay
var _night_reverb: AudioEffectReverb
var _muffle: AudioEffectLowPassFilter
var _owl_wait := 14.0
var _screech_wait := 150.0
var _gecko_wait := 35.0
var _toad_wait := 8.0
var _knock_wait := 12.0
var _gust_wait := 9.0
var _gust_time := -1.0
var _gust_length := 8.0
var _gust_from := Vector3.ZERO
var _gust_dir := Vector3(.8, 0, .6)
var _frog_poll := 0.0
var _exposure := 0.0
var _zone := 0.0
var _fields: Node3D
var _hut: Node3D
var _story: Node
var _outside_weight := 0.0
var _tension := 0.0
var _quiet_wait := 42.0
var _quiet_time := -1.0
var _quiet_length := 8.0
var _quiet_weight := 0.0
var _wildlife_db := 0.0
var _house_tone: AudioStreamPlayer
var _house_creak: AudioStreamPlayer3D
var _house_wait := 22.0
var _house_sounds: Array[AudioStream] = []
## 0.21: inside the Nichols house the footsteps ring through big empty rooms.
var _nichols: Node3D
var _mansion := 0.0
var rng := RandomNumberGenerator.new()

func setup(main: Node, character: InteriorPlayer) -> void:
	player = character
	process_mode = Node.PROCESS_MODE_PAUSABLE
	rng.randomize()
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_buses()
	var room_audio := main.get_node_or_null("RoomAudio")
	if room_audio != null and room_audio.get("footsteps") is AudioStreamPlayer:
		(room_audio.get("footsteps") as AudioStreamPlayer).bus = STEPS_BUS
	for name: String in DOG_CLIPS + ["cricket_field", "cricket_gryllus", "frog_kaloula", "frog_chorus", "frog_chorus_b", "toad_bufo", "owl_tawny", "owl_barn_screech", "gecko_tokay"]:
		var path := NIGHT + name + ".ogg"
		if ResourceLoader.exists(path):
			var stream := (load(path) as AudioStream).duplicate() as AudioStream
			if stream is AudioStreamOggVorbis:
				(stream as AudioStreamOggVorbis).loop = name.begins_with("cricket") or name.begins_with("frog")
			_streams[name] = stream
	for i in CRICKET_COUNT:
		var cricket := _voice3d(3.2, 40.0, -5.0)
		cricket.bus = WILDLIFE_BUS
		cricket.stream = _streams.get("cricket_field" if i % 2 == 0 else "cricket_gryllus")
		cricket.pitch_scale = rng.randf_range(.88, 1.18)
		_crickets.append(cricket)
		_cricket_quiet.append(0.0)
	for i in FROG_COUNT:
		var frog := _voice3d(9.0, 110.0, -9.0)
		frog.bus = WILDLIFE_BUS
		frog.stream = _streams.get(["frog_kaloula", "frog_chorus", "frog_chorus_b", "frog_kaloula"][i])
		frog.pitch_scale = rng.randf_range(.92, 1.06)
		_frogs.append(frog)
	_far_chorus = _voice3d(26.0, 180.0, -8.0)
	_far_chorus.bus = WILDLIFE_BUS
	_far_chorus.stream = _streams.get("frog_chorus")
	_far_chorus.position = Vector3(21, -3.0, 96)
	_caller = _voice3d(16.0, 140.0, -3.0)
	_caller.bus = WILDLIFE_BUS
	_toad = _voice3d(5.0, 60.0, -6.0)
	_toad.bus = WILDLIFE_BUS
	_creak = _voice3d(4.0, 40.0, -10.0)
	_creak.stream = _bamboo_creak()
	_wind = AudioStreamPlayer.new()
	_wind.stream = _wind_loop()
	_wind.bus = NATURE_BUS
	_wind.volume_db = -80.0
	add_child(_wind)
	_gust = _voice3d(8.0, 80.0, -80.0)
	_gust.stream = _wind.stream
	# Quiet air behind the walls, with only occasional timber settling overhead.
	# Both use existing sound material; there is no continuous musical horror sting.
	_house_tone = AudioStreamPlayer.new()
	_house_tone.stream = _wind.stream
	_house_tone.pitch_scale = .38
	_house_tone.volume_db = -80.0
	_house_tone.bus = STEPS_BUS
	add_child(_house_tone)
	_house_creak = _voice3d(2.0, 10.0, -25.0)
	_house_creak.bus = STEPS_BUS
	_house_creak.attenuation_filter_cutoff_hz = 1600.0
	for path in ["res://assets/audio/sfx/hit_wood.ogg", "res://assets/audio/sfx/drawer_open.ogg"]:
		if ResourceLoader.exists(path):
			_house_sounds.append(load(path))
	_drone = AudioStreamPlayer.new()
	_drone.stream = _drone_loop()
	_drone.bus = NATURE_BUS
	_drone.volume_db = -80.0
	add_child(_drone)
	_knock = _voice3d(10.0, 60.0, -2.0)
	_knock.attenuation_filter_cutoff_hz = 2500.0
	for path in ["res://assets/audio/sfx/impactMetal_heavy_002.ogg", "res://assets/audio/sfx/impactMetal_light_001.ogg", "res://assets/audio/sfx/impactPlate_medium_000.ogg"]:
		if ResourceLoader.exists(path):
			_knocks.append(load(path))
	# Far dogs: big unit size so they carry, dull and reverberant like a bark across the rooftops.
	for i in 2:
		var dog := _voice3d(15.0, 260.0, -2.0)
		dog.bus = WILDLIFE_BUS
		dog.attenuation_filter_cutoff_hz = 2400.0
		dog.attenuation_filter_db = -24.0
		if i == 0:
			_dog = dog
		else:
			_dog_answer = dog
	_dog_wait = rng.randf_range(25.0, 55.0)
	_quiet_wait = rng.randf_range(38.0, 66.0)
	# Buses survive a scene reload. Reset any fade from the previous playthrough.
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(WILDLIFE_BUS), 0.0)
	_ready_done = true

func _voice3d(unit: float, max_distance: float, volume: float) -> AudioStreamPlayer3D:
	var voice := AudioStreamPlayer3D.new()
	voice.unit_size = unit
	voice.max_distance = max_distance
	voice.volume_db = -80.0
	voice.bus = NATURE_BUS
	voice.attenuation_filter_cutoff_hz = 6000.0
	voice.attenuation_filter_db = -16.0
	voice.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	add_child(voice)
	voice.set_meta("base_db", volume)
	return voice

func _buses() -> void:
	if AudioServer.get_bus_index(STEPS_BUS) < 0:
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, STEPS_BUS)
		AudioServer.set_bus_send(index, "Master")
		_reverb = AudioEffectReverb.new()
		_reverb.room_size = .8
		_reverb.damping = .55
		_reverb.spread = .85
		_reverb.hipass = .3
		_reverb.dry = 1.0
		_reverb.wet = 0.0
		_reverb.predelay_msec = 55.0
		_reverb.predelay_feedback = .3
		AudioServer.add_bus_effect(index, _reverb)
		_delay = AudioEffectDelay.new()
		_delay.dry = 1.0
		_delay.tap1_active = true
		_delay.tap1_delay_ms = 160.0
		_delay.tap1_level_db = -80.0
		_delay.tap1_pan = -.35
		_delay.tap2_active = true
		_delay.tap2_delay_ms = 340.0
		_delay.tap2_level_db = -80.0
		_delay.tap2_pan = .4
		_delay.feedback_active = false
		AudioServer.add_bus_effect(index, _delay)
	else:
		var index := AudioServer.get_bus_index(STEPS_BUS)
		_reverb = AudioServer.get_bus_effect(index, 0) as AudioEffectReverb
		_delay = AudioServer.get_bus_effect(index, 1) as AudioEffectDelay
	if AudioServer.get_bus_index(NATURE_BUS) < 0:
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, NATURE_BUS)
		AudioServer.set_bus_send(index, "Master")
		_night_reverb = AudioEffectReverb.new()
		_night_reverb.room_size = .95
		_night_reverb.damping = .7
		_night_reverb.hipass = .2
		_night_reverb.dry = 1.0
		_night_reverb.wet = .14
		_night_reverb.predelay_msec = 90.0
		AudioServer.add_bus_effect(index, _night_reverb)
		_muffle = AudioEffectLowPassFilter.new()
		_muffle.cutoff_hz = 20000.0
		AudioServer.add_bus_effect(index, _muffle)
	else:
		var index := AudioServer.get_bus_index(NATURE_BUS)
		_night_reverb = AudioServer.get_bus_effect(index, 0) as AudioEffectReverb
		_muffle = AudioServer.get_bus_effect(index, 1) as AudioEffectLowPassFilter
	if AudioServer.get_bus_index(WILDLIFE_BUS) < 0:
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, WILDLIFE_BUS)
		AudioServer.set_bus_send(index, NATURE_BUS)

func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("wind_gust", 0.0)
	var wildlife := AudioServer.get_bus_index(WILDLIFE_BUS)
	if wildlife >= 0:
		AudioServer.set_bus_volume_db(wildlife, 0.0)

# ---------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	if not _ready_done or player == null or player.camera == null:
		return
	var listener := get_viewport().get_camera_3d()
	var cam := listener.global_position if listener != null else player.camera.global_position
	if not is_instance_valid(_hut):
		_hut = get_tree().get_first_node_in_group("hut_house") as Node3D
	if not is_instance_valid(_story):
		_story = get_tree().get_first_node_in_group("story")
	var in_hut := _hut != null and bool(_hut.call("is_inside", cam))
	if not is_instance_valid(_nichols):
		_nichols = get_tree().get_first_node_in_group("nichols_property") as Node3D
	var in_house := _nichols != null and bool(_nichols.call("is_inside", cam))
	_mansion = lerpf(_mansion, 1.0 if in_house else 0.0, 1.0 - exp(-2.5 * delta))
	var outdoors := not in_hut and not in_house and (cam.y < -.4 or cam.z < -17.0 or cam.x < -33.0 or (cam.z > 2.62 and cam.x > .8))
	var door_open := false
	var main := get_parent()
	if main != null and main.has_method("entry_door"):
		var door: Variant = main.call("entry_door")
		door_open = door != null and (door.is_open() or door.is_moving())
	# How much of the night reaches the ear: all of it outside, a little through an open door.
	# 0.22: below the boards (the Nichols cellar and tunnel) the night is a faint rumble through stone.
	var below := in_house and _nichols.has_method("is_below") and bool(_nichols.call("is_below", cam))
	var exposure := 1.0 if outdoors else (.36 if in_hut else (.08 if below else (.45 if in_house else (.32 if door_open else .07))))
	_exposure = lerpf(_exposure, exposure, 1.0 - exp(-2.0 * delta))
	_outside_weight = lerpf(_outside_weight, 1.0 if outdoors else 0.0, 1.0 - exp(-2.4 * delta))
	if _fields == null or not is_instance_valid(_fields):
		_fields = get_tree().get_first_node_in_group("fields") as Node3D
	var zone := InteriorFields.zone_weight(cam) if outdoors or in_hut else 0.0
	_zone = lerpf(_zone, zone, 1.0 - exp(-1.4 * delta))
	_update_quiet(delta, outdoors)
	_update_buses(outdoors)
	_update_house(delta, cam, outdoors, in_hut)
	_update_wind(delta, cam, outdoors)
	_update_crickets(delta, cam)
	_frog_poll -= delta
	if _frog_poll <= 0.0:
		_frog_poll = 1.0
		_update_frogs(cam)
	_update_frog_levels(delta)
	_update_calls(delta, cam, outdoors)
	_update_dogs(delta, cam)
	_update_town(delta, cam, outdoors)

func _update_buses(_outdoors: bool) -> void:
	if _reverb != null:
		var town := 1.0 - _zone
		_reverb.wet = lerpf(.045, .2 * town + .13 * _zone, _outside_weight)
		_reverb.room_size = lerpf(.28, lerpf(.72, .96, _zone), _outside_weight)
	if _delay != null:
		_delay.tap1_delay_ms = lerpf(150.0, 390.0, _zone)
		_delay.tap2_delay_ms = lerpf(320.0, 860.0, _zone)
		var outdoor_db := linear_to_db(maxf(_outside_weight, .0001))
		_delay.tap1_level_db = lerpf(-17.0, -21.0, _zone) + outdoor_db
		_delay.tap2_level_db = lerpf(-25.0, -28.0, _zone) + outdoor_db
	if _muffle != null:
		_muffle.cutoff_hz = exp(lerpf(log(900.0), log(20000.0), _exposure))
	# The Nichols house: a long, bright hall reverb and a hard slapback off the bare walls and floors.
	if _reverb != null:
		_reverb.wet = lerpf(_reverb.wet, .38, _mansion)
		_reverb.room_size = lerpf(_reverb.room_size, .92, _mansion)
		_reverb.damping = lerpf(.55, .28, _mansion)
		_reverb.predelay_msec = lerpf(55.0, 38.0, _mansion)
	if _delay != null:
		_delay.tap1_delay_ms = lerpf(_delay.tap1_delay_ms, 125.0, _mansion)
		_delay.tap1_level_db = lerpf(_delay.tap1_level_db, -12.0, _mansion)
		_delay.tap2_delay_ms = lerpf(_delay.tap2_delay_ms, 290.0, _mansion)
		_delay.tap2_level_db = lerpf(_delay.tap2_level_db, -17.0, _mansion)
	# 0.33: under a roof the map calls outdoors (the cellar, the tunnels): scripts/sound_stage.gd.
	var stage: Variant = get_parent().get("sound_stage") if get_parent() != null else null
	if stage != null and is_instance_valid(stage):
		(stage as InteriorSoundStage).shape_steps(_reverb, _delay, _outside_weight)
	var steps := AudioServer.get_bus_index(STEPS_BUS)
	if steps >= 0:
		AudioServer.set_bus_volume_db(steps, 3.5 * _mansion)
	if _night_reverb != null:
		_night_reverb.wet = lerpf(.08, .17, _outside_weight)
		_night_reverb.room_size = lerpf(.65, .96, _zone)

## The night occasionally falls quieter, leaving the wind and footsteps exposed.
## The alarm sustains that absence without hiding story voices, footsteps or sirens.
func _update_quiet(delta: float, outdoors: bool) -> void:
	var alarm: bool = is_instance_valid(_story) and _story.get("lights_out") == true
	_tension = lerpf(_tension, 1.0 if alarm else 0.0, 1.0 - exp(-.35 * delta))
	if _quiet_time >= 0.0:
		_quiet_time += delta
		var progress := clampf(_quiet_time / _quiet_length, 0.0, 1.0)
		_quiet_weight = sin(progress * PI)
		if progress >= 1.0:
			_quiet_time = -1.0
			_quiet_weight = 0.0
	elif outdoors and not alarm:
		_quiet_wait -= delta
		if _quiet_wait <= 0.0:
			_quiet_wait = rng.randf_range(45.0, 90.0)
			_quiet_length = rng.randf_range(7.0, 12.0)
			_quiet_time = 0.0
	var target_db := -13.0 * _quiet_weight - 10.0 * _tension
	_wildlife_db = lerpf(_wildlife_db, target_db, 1.0 - exp(-1.6 * delta))
	var wildlife := AudioServer.get_bus_index(WILDLIFE_BUS)
	if wildlife >= 0:
		AudioServer.set_bus_volume_db(wildlife, _wildlife_db)

func _update_house(delta: float, cam: Vector3, outdoors: bool, in_hut: bool) -> void:
	var shelter := 1.0 - _outside_weight
	_house_tone.volume_db = -37.0 + linear_to_db(maxf(shelter, .0001))
	_play_if_bg(_house_tone)
	# Let a creak finish naturally when leaving. New ones only originate in a shelter.
	if outdoors or _house_sounds.is_empty():
		return
	_house_wait -= delta
	if _house_wait > 0.0 or _house_creak.playing:
		return
	_house_wait = rng.randf_range(30.0, 65.0)
	var angle := rng.randf() * TAU
	_house_creak.global_position = cam + Vector3(cos(angle) * 2.3, 1.1, sin(angle) * 2.3)
	_house_creak.stream = _house_sounds[rng.randi_range(0, _house_sounds.size() - 1)]
	_house_creak.pitch_scale = rng.randf_range(.52, .73)
	_house_creak.volume_db = rng.randf_range(-28.0, -23.0) + (2.0 if in_hut else 0.0)
	_house_creak.play()

func _faded(voice: AudioStreamPlayer3D, extra_db := 0.0) -> float:
	return float(voice.get_meta("base_db", 0.0)) + extra_db + linear_to_db(maxf(_exposure, .0001))

func _play_if(voice: AudioStreamPlayer3D, audible: bool) -> void:
	if audible and not voice.playing and voice.stream != null:
		voice.play(rng.randf_range(0.0, maxf(voice.stream.get_length() - .5, 0.0)))
	elif not audible and voice.playing:
		voice.stop()

func _fade_loop(voice: AudioStreamPlayer3D, target_db: float, delta: float, rate := 2.0) -> void:
	# Fade amplitude, so a newly audible loop cannot begin at its unfaded base volume.
	var gain := lerpf(db_to_linear(voice.volume_db), db_to_linear(target_db), 1.0 - exp(-rate * delta))
	voice.volume_db = linear_to_db(maxf(gain, .0001))
	_play_if(voice, voice.volume_db > -68.0)

## Crickets sit in the grass 8-28 m away and move on as you walk; close up they go quiet.
func _update_crickets(delta: float, cam: Vector3) -> void:
	var active := int(lerpf(4.0, float(CRICKET_COUNT), _zone))
	for i in _crickets.size():
		var cricket := _crickets[i]
		var ground := Vector3(cam.x, -2.85, cam.z)
		if i >= active or _exposure < .02:
			_fade_loop(cricket, -80.0, delta)
			continue
		var far := cricket.global_position.distance_to(ground) > 34.0 or cricket.global_position == Vector3.ZERO
		if far:
			cricket.stop()
			cricket.volume_db = -80.0
			var angle := rng.randf() * TAU
			cricket.global_position = ground + Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(8.0, 26.0)
		var distance := Vector2(cricket.global_position.x - cam.x, cricket.global_position.z - cam.z).length()
		if distance < 3.2:
			_cricket_quiet[i] = rng.randf_range(7.0, 14.0)
		_cricket_quiet[i] = maxf(0.0, _cricket_quiet[i] - delta)
		var quiet := _cricket_quiet[i] > 0.0 and distance < 9.0
		var target := _faded(cricket, -60.0 if quiet else 0.0)
		_fade_loop(cricket, target, delta, 3.0 if quiet else 1.2)

## Frogs: the paddies nearest to you croak; from town only a far chorus to the north is heard.
func _update_frogs(cam: Vector3) -> void:
	var spots: PackedVector3Array = _fields.get_meta("audio_frog", PackedVector3Array()) if _fields != null else PackedVector3Array()
	var chosen: Array[Vector3] = []
	if _zone > .05 and not spots.is_empty():
		var sorted := Array(spots)
		sorted.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(cam) < b.distance_squared_to(cam))
		for k in mini(_frogs.size(), sorted.size()):
			chosen.append(sorted[k])
	for i in _frogs.size():
		var frog := _frogs[i]
		if i < chosen.size():
			if frog.global_position.distance_to(chosen[i]) > 1.0:
				frog.stop()
				frog.volume_db = -80.0
				frog.global_position = chosen[i]
			frog.set_meta("active", true)
		else:
			frog.set_meta("active", false)

func _update_frog_levels(delta: float) -> void:
	for frog in _frogs:
		var active := bool(frog.get_meta("active", false)) and _exposure > .02
		var target := _faded(frog, linear_to_db(maxf(_zone, .001))) if active else -80.0
		_fade_loop(frog, target, delta, 1.4)
	# The far chorus at the edge of town fades as the near frogs take over.
	var chorus := _faded(_far_chorus, linear_to_db(maxf(1.0 - _zone, .001)) - 4.0)
	_fade_loop(_far_chorus, chorus if _exposure > .02 and _zone < .95 else -80.0, delta)

## One-shot calls: owls, a rare barn owl screech, the tokay gecko and close toads.
func _update_calls(delta: float, cam: Vector3, outdoors: bool) -> void:
	_owl_wait -= delta
	_screech_wait -= delta
	_gecko_wait -= delta
	_toad_wait -= delta
	if _caller.playing or _exposure < .05 or _quiet_weight > .5 or _tension > .65:
		return
	if _owl_wait <= 0.0:
		_owl_wait = rng.randf_range(28.0, 70.0)
		_call("owl_tawny", _spot("audio_owl", cam, 22.0, 70.0, 11.0), rng.randf_range(.92, 1.04), 0.0)
	elif _screech_wait <= 0.0 and outdoors:
		_screech_wait = rng.randf_range(140.0, 260.0)
		_call("owl_barn_screech", _spot("audio_owl", cam, 25.0, 60.0, 9.0), rng.randf_range(.9, 1.0), -2.0)
	elif _gecko_wait <= 0.0:
		_gecko_wait = rng.randf_range(45.0, 110.0)
		_call("gecko_tokay", _spot("audio_gecko", cam, 12.0, 45.0, 2.5), 1.0, 1.0)
	if _toad_wait <= 0.0 and _zone > .3 and not _toad.playing:
		_toad_wait = rng.randf_range(12.0, 34.0)
		var angle := rng.randf() * TAU
		_toad.global_position = Vector3(cam.x, -3.3, cam.z) + Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(6.0, 20.0)
		_toad.stream = _streams.get("toad_bufo")
		_toad.pitch_scale = rng.randf_range(.85, 1.1)
		_toad.volume_db = _faded(_toad)
		if _toad.stream != null:
			_toad.play()

## A dog somewhere far off barks now and then (every 40-110 s); about a third of the time another dog,
## farther and in another direction, answers a few seconds later. Never the same clip twice in a row.
func _update_dogs(delta: float, cam: Vector3) -> void:
	if _answer_wait >= 0.0 and not _dog.playing:
		_answer_wait -= delta
		if _answer_wait < 0.0:
			var away := Vector3(_dog.global_position.x - cam.x, 0, _dog.global_position.z - cam.z).normalized()
			_bark(_dog_answer, away.rotated(Vector3.UP, rng.randf_range(1.4, 4.9)), 110.0, 170.0)
	_dog_wait -= delta
	if _dog_wait > 0.0 or _dog.playing or _dog_answer.playing:
		return
	_dog_wait = rng.randf_range(40.0, 110.0)
	if _exposure < .05 or _quiet_weight > .5 or _tension > .65:
		return
	var angle := rng.randf() * TAU
	_bark(_dog, Vector3(cos(angle), 0, sin(angle)), 70.0, 130.0)
	_answer_wait = rng.randf_range(1.5, 5.0) if rng.randf() < .35 else -1.0

func _bark(voice: AudioStreamPlayer3D, direction: Vector3, near: float, far: float) -> void:
	var options: Array[String] = []
	for name: String in DOG_CLIPS:
		if name != _last_dog and _streams.has(name):
			options.append(name)
	if options.is_empty():
		return
	_last_dog = options[rng.randi_range(0, options.size() - 1)]
	var cam := player.camera.global_position
	voice.stream = _streams[_last_dog]
	voice.global_position = Vector3(cam.x, -1.8, cam.z) + direction.normalized() * rng.randf_range(near, far)
	voice.pitch_scale = rng.randf_range(.9, 1.08)
	voice.volume_db = _faded(voice, rng.randf_range(-3.0, 0.0))
	voice.play()

func _call(name: String, at: Vector3, pitch: float, gain: float) -> void:
	var stream: AudioStream = _streams.get(name)
	if stream == null:
		return
	_caller.stream = stream
	_caller.global_position = at
	_caller.pitch_scale = pitch
	_caller.volume_db = _faded(_caller, gain)
	_caller.play()

## A spot from the fields' list (tree tops, the hut) within reach, else somewhere around in the dark.
func _spot(key: String, cam: Vector3, near: float, far: float, height: float) -> Vector3:
	if _fields != null and _zone > .2:
		var spots: PackedVector3Array = _fields.get_meta(key, PackedVector3Array())
		var options: Array[Vector3] = []
		for p in spots:
			var d := p.distance_to(cam)
			if d > near * .6 and d < far * 1.4:
				options.append(p)
		if not options.is_empty():
			return options[rng.randi_range(0, options.size() - 1)]
	var angle := rng.randf() * TAU
	return Vector3(cam.x, -2.9 + height, cam.z) + Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(near, far)

## A low outdoor drone; distant knocks in town, or farther afield once the alarm starts.
func _update_town(delta: float, cam: Vector3, outdoors: bool) -> void:
	var street := outdoors and cam.y < -.4
	var town := 1.0 - _zone
	var drone_db := lerpf(-28.0, -35.0, _zone) + _tension * 7.0
	_drone.volume_db = move_toward(_drone.volume_db, drone_db if street else -80.0, delta * 8.0)
	_play_if_bg(_drone)
	if street and (town > .5 or _tension > .5) and not _knocks.is_empty():
		_knock_wait -= delta
		if _knock_wait <= 0.0:
			_knock_wait = rng.randf_range(16.0, 40.0)
			var angle := rng.randf() * TAU
			_knock.global_position = cam + Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(18.0, 35.0)
			_knock.stream = _knocks[rng.randi_range(0, _knocks.size() - 1)]
			_knock.pitch_scale = rng.randf_range(.45, .7)
			_knock.volume_db = rng.randf_range(-14.0, -9.0)
			_knock.play()

func _play_if_bg(voice: AudioStreamPlayer) -> void:
	var audible := voice.volume_db > -70.0
	if audible and not voice.playing:
		voice.play()
	elif not audible and voice.playing:
		voice.stop()

## Wind: a quiet bed, and every 14-40 s a gust that swells, sweeps past and bends the rice.
func _update_wind(delta: float, cam: Vector3, outdoors: bool) -> void:
	var envelope := 0.0
	if _gust_time >= 0.0:
		_gust_time += delta
		var t := _gust_time / _gust_length
		envelope = sin(clampf(t, 0.0, 1.0) * PI)
		envelope = envelope * envelope * (3.0 - 2.0 * envelope)
		_gust.global_position = _gust_from + _gust_dir * _gust_time * 7.0
		if t >= 1.0:
			_gust_time = -1.0
			_gust.stop()
	else:
		_gust_wait -= delta
		if _gust_wait <= 0.0 and outdoors:
			_gust_wait = rng.randf_range(14.0, 40.0)
			_gust_length = rng.randf_range(6.0, 11.0)
			_gust_time = 0.0
			var angle := rng.randf_range(-.5, .5)
			_gust_dir = Vector3(.8, 0, .6).rotated(Vector3.UP, angle).normalized()
			var side := _gust_dir.cross(Vector3.UP) * rng.randf_range(-12.0, 12.0)
			_gust_from = cam - _gust_dir * _gust_length * 3.5 + side
			_gust.pitch_scale = rng.randf_range(.8, 1.15)
			_gust.play(rng.randf_range(0.0, 4.0))
			if _fields != null and _zone > .3:
				_bamboo(cam)
	RenderingServer.global_shader_parameter_set("wind_gust", envelope * _outside_weight)
	var bed := (-26.0 + 14.0 * envelope) if outdoors else -34.0
	_wind.volume_db = move_toward(_wind.volume_db, bed + linear_to_db(maxf(_exposure, .0001)), delta * 20.0)
	_gust.volume_db = -8.0 + linear_to_db(maxf(envelope * _exposure, .0001))
	_play_if_bg(_wind)

func _bamboo(cam: Vector3) -> void:
	var spots: PackedVector3Array = _fields.get_meta("audio_bamboo", PackedVector3Array())
	for p in spots:
		if p.distance_to(cam) < 30.0:
			_creak.global_position = p
			_creak.pitch_scale = rng.randf_range(.8, 1.2)
			_creak.volume_db = _faded(_creak)
			_creak.play()
			return

# ---------------------------------------------------------------- generated loops

func _wav(samples: PackedFloat32Array, looped := true) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 26000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = samples.size()
	return stream

## Band-limited noise with slow gusts; the loop is crossfaded so it never clicks.
func _wind_loop() -> AudioStreamWAV:
	var rate := 22050
	var count := rate * 8
	var r := RandomNumberGenerator.new()
	r.seed = 99
	var raw := PackedFloat32Array()
	raw.resize(count)
	var lp1 := 0.0
	var lp2 := 0.0
	for i in count:
		var t := float(i) / rate
		var gust := .45 + .35 * sin(t * TAU / 8.0) + .2 * sin(t * TAU * 3.0 / 8.0 + 1.3)
		var cutoff := .02 + .05 * gust
		lp1 = lerpf(lp1, r.randf_range(-1.0, 1.0), cutoff)
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

## Bamboo stems rubbing in a gust: slow, woody stick-slip knocks and groans.
func _bamboo_creak() -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * 2.4)
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var out := PackedFloat32Array()
	out.resize(count)
	var phase := 0.0
	var lp := 0.0
	for i in count:
		var t := float(i) / rate
		var pitch := 150.0 + 60.0 * sin(t * 2.1) + 25.0 * sin(t * 7.3)
		phase += pitch / rate
		var grab := pow(maxf(0.0, sin(t * TAU * 5.5 + sin(t * 3.0) * 1.5)), 10.0)
		lp = lerpf(lp, r.randf_range(-1.0, 1.0), .08)
		var body := sin(phase * TAU) * .6 + (fmod(phase, 1.0) * 2.0 - 1.0) * .25
		var envelope := sin(clampf(t / 2.4, 0.0, 1.0) * PI)
		out[i] = (body * (.15 + grab * .85) + lp * .2) * envelope * .7
	return _wav(out, false)
