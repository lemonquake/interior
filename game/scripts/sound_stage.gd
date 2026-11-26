class_name InteriorSoundStage
extends Node
## 0.33: the place is heard. Until now a shot or a step sounded by where the map said the player was (in the
## house, in the hut, in town, in the fields); a cellar, a tunnel, a lane between two walls were "outdoors".
##
## 1. The space round the lens is measured, five times a second: eight rays level, four up at an angle, one
##    straight up, 24 m, against the fixed world (not its unseen walls: InteriorSurfaces.seen_ray). `roofed` is how much of the sky is shut, `walled` how much of the
##    horizon, `size` how far off the faces are, `nearest` the closest wall.
##    - Under a roof the gun's reverb is that room: a tunnel is tight, bright and loud; a hall is long. No tail
##      off the fields (scripts/gun.gd asks `open_sky()`).
##    - Between walls with the sky open, a shot slaps back off them after the time sound takes to go
##      there and return (their mean distance); in the open there is no slap.
##    - Footsteps under a roof the map does not know as indoors (the cellar, the tunnels) get the room, not the
##      town's echo (scripts/night_audio.gd calls `shape_steps`).
## 2. What is behind a wall is muffled. Every positional voice on the Gun, Steps and Master buses (the infected,
##    breaking glass, impacts, doors, knocks) is looked at a few times a second: with fixed world between it and
##    the lens it loses its top and some of its level, and gets them back when it comes into the open.

const REACH := 24.0
const MASK := 2
const SPEED_OF_SOUND := 343.0
const OCCLUDED_BUSES := ["Gun", "Steps", "Master"]
const PER_FRAME := 5
const MUFFLED_HZ := 650.0

var main: Node
var player: InteriorPlayer
var roofed := 0.0
var walled := 0.0
var size := REACH
var nearest := REACH
## The walls' mean distance on the level: what a slap comes back from.
var around := REACH
## How many voices are muffled now (debug read-out, tests).
var muffled := 0
var _wait := 0.0
var _turn := 0.0
var _voices: Array[AudioStreamPlayer3D] = []
var _next := 0
var _slap: AudioEffectDelay
var _measured := false

func setup(main_node: Node) -> void:
	main = main_node
	name = "SoundStage"
	player = main.player
	get_tree().node_added.connect(_on_node_added)
	for node in main.find_children("*", "AudioStreamPlayer3D", true, false):
		_on_node_added(node)

func open_sky() -> bool:
	return not _measured or roofed < .5

func _on_node_added(node: Node) -> void:
	if node is AudioStreamPlayer3D:
		# (Its bus and place are set after it is added.)
		_watch.call_deferred(node)

func _watch(voice: AudioStreamPlayer3D) -> void:
	if not is_instance_valid(voice) or not voice.is_inside_tree() or _voices.has(voice) or not OCCLUDED_BUSES.has(String(voice.bus)):
		return
	voice.set_meta("stage_base", [voice.attenuation_filter_cutoff_hz, voice.attenuation_filter_db, voice.max_db])
	voice.set_meta("stage_shut", -1.0)
	_voices.append(voice)
	_hear(voice, 1.0)

func _process(delta: float) -> void:
	if player == null or player.camera == null:
		return
	_wait -= delta
	if _wait <= 0.0:
		_wait = .2
		_measure()
		_shape_gun_bus()
	var count := mini(PER_FRAME, _voices.size())
	for i in count:
		_next = (_next + 1) % _voices.size()
		var voice := _voices[_next]
		if not is_instance_valid(voice):
			_voices.remove_at(_next)
			if _voices.is_empty():
				break
			continue
		_hear(voice, delta * float(_voices.size()) / float(count))

## Is the fixed world between the lens and this voice? Its top and its level follow.
func _hear(voice: AudioStreamPlayer3D, delta: float) -> void:
	var shut: float = voice.get_meta("stage_shut", -1.0)
	if not voice.playing and shut >= 0.0:
		return
	var ear := player.camera.global_position
	var at := voice.global_position
	var blocked := 0.0
	var far := ear.distance_to(at)
	if far > .6 and far < voice.max_distance + 1.0 or (far > .6 and voice.max_distance <= 0.0):
		# 0.37: the rule the infected hear by (scripts/senses.gd `muffle`): a pane or a door muffles less than a wall.
		var senses: Variant = main.get("senses")
		if senses != null and is_instance_valid(senses):
			blocked = minf((senses as InteriorSenses).muffle(ear, at, .35), 1.0)
		else:
			var hit := InteriorSurfaces.seen_ray(main.get_viewport().world_3d.direct_space_state, ear, at, MASK)
			if hit and ear.distance_to(hit.position) < far - .35:
				blocked = 1.0
	var was := shut
	shut = blocked if shut < 0.0 else move_toward(shut, blocked, delta * 5.0)
	if shut == was:
		return
	voice.set_meta("stage_shut", shut)
	var base: Array = voice.get_meta("stage_base")
	voice.attenuation_filter_cutoff_hz = exp(lerpf(log(float(base[0])), log(MUFFLED_HZ), shut))
	voice.attenuation_filter_db = lerpf(float(base[1]), minf(float(base[1]), -36.0), shut)
	voice.max_db = float(base[2]) - 7.0 * shut
	if (was > .5) != (shut > .5) or was < 0.0:
		muffled += (1 if shut > .5 else 0) - (1 if was > .5 else 0)

func _measure() -> void:
	var space := main.get_viewport().world_3d.direct_space_state
	var eye := player.camera.global_position
	_turn = fmod(_turn + .37, TAU)
	var walls := 0
	var roof := 0.0
	var total := 0.0
	var hits := 0
	var close := REACH
	var level := 0.0
	for i in 13:
		var dir := Vector3.UP
		if i < 8:
			dir = Vector3(cos(_turn + i * TAU / 8.0), 0.0, sin(_turn + i * TAU / 8.0))
		elif i < 12:
			dir = Vector3(cos(_turn + i * TAU / 4.0), 1.0, sin(_turn + i * TAU / 4.0)).normalized()
		var hit := InteriorSurfaces.seen_ray(space, eye, eye + dir * REACH, MASK)
		if hit.is_empty():
			continue
		var far := eye.distance_to(hit.position)
		hits += 1
		total += far
		if i < 8:
			walls += 1
			level += far
			close = minf(close, far)
		else:
			roof += 2.0 if i == 12 else 1.0
	var rate := .45 if _measured else 1.0
	roofed = lerpf(roofed, roof / 6.0, rate)
	walled = lerpf(walled, walls / 8.0, rate)
	size = lerpf(size, total / hits if hits > 0 else REACH, rate)
	nearest = lerpf(nearest, close, rate)
	around = lerpf(around, level / walls if walls > 0 else REACH, rate)
	_measured = true

## The Gun bus (scripts/gun.gd makes it): a slap back off the nearest wall when the sky is open.
func _shape_gun_bus() -> void:
	var index := AudioServer.get_bus_index("Gun")
	if index < 0:
		return
	if _slap == null:
		for i in AudioServer.get_bus_effect_count(index):
			if AudioServer.get_bus_effect(index, i) is AudioEffectDelay:
				_slap = AudioServer.get_bus_effect(index, i)
		if _slap == null:
			_slap = AudioEffectDelay.new()
			_slap.dry = 1.0
			_slap.tap1_active = true
			_slap.tap1_pan = .15
			_slap.tap2_active = false
			_slap.feedback_active = false
			AudioServer.add_bus_effect(index, _slap)
	var open := 1.0 - smoothstep(.35, .7, roofed)
	var faces := smoothstep(.2, .6, walled) * open * (1.0 - smoothstep(14.0, REACH, nearest))
	_slap.tap1_delay_ms = clampf(2.0 * around / SPEED_OF_SOUND * 1000.0, 30.0, 150.0)
	_slap.tap1_level_db = lerpf(-60.0, -10.0, faces)

## The gun's reverb for where it is fired (scripts/gun.gd has set it for the map's zone already).
func shape_gun(reverb: AudioEffectReverb) -> void:
	if not _measured:
		return
	var room := smoothstep(.45, .8, roofed)
	if room <= 0.0:
		return
	var big := clampf(inverse_lerp(2.0, 18.0, size), 0.0, 1.0)
	var tight := walled * (1.0 - big)
	reverb.room_size = lerpf(reverb.room_size, lerpf(.2, .85, big), room)
	reverb.wet = lerpf(reverb.wet, lerpf(.24, .44, maxf(tight, big * .7)), room)
	reverb.damping = lerpf(.5, lerpf(.25, .5, big), room)

## Footsteps under a roof the map calls outdoors: the room, not the town.
func shape_steps(reverb: AudioEffectReverb, delay: AudioEffectDelay, outside: float) -> void:
	if not _measured or reverb == null:
		return
	var room := smoothstep(.5, .85, roofed) * outside
	if room <= 0.001:
		return
	var big := clampf(inverse_lerp(2.0, 18.0, size), 0.0, 1.0)
	reverb.room_size = lerpf(reverb.room_size, lerpf(.25, .8, big), room)
	reverb.wet = lerpf(reverb.wet, lerpf(.16, .3, walled), room)
	if delay != null:
		delay.tap1_level_db = lerpf(delay.tap1_level_db, -60.0, room)
		delay.tap2_level_db = lerpf(delay.tap2_level_db, -60.0, room)
