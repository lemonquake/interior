class_name InteriorPushGate
extends Node3D
## The white steel double gate at the end of the courtyard (built by balcony_builder.gd). E only
## unlocks it, and after that the player has to push the leaves open by walking into them. They
## swing outward toward the lane, up to OPEN_LIMIT, carry a little momentum and creak.
## The leaves are AnimatableBody3D children carrying "open_sign" (+1 / -1) and "width" metas,
## with their hinge at the node origin and the leaf running along local +Z.
## Hold E (0.7) to take hold of a leaf and pull it toward you (or push it away) by hand; while it is
## locked, pulling only rattles it.

const OPEN_LIMIT := 1.75     # rad, about 100 degrees
const PLAYER_RADIUS := .24
const DAMPING := 2.2
const PUSH_RESPONSE := 7.0

@export var locked := true

var _leaves: Array[AnimatableBody3D] = []
var _base_yaw: Array[float] = []
var _angle: Array[float] = []
var _speed: Array[float] = []
var _player: CharacterBody3D
var _audio: AudioStreamPlayer3D
var _creak: AudioStreamPlayer3D
var _rattle_wait := 0.0
var _pull_leaf := -1
var _pull_angle := 0.0     # angle of the grab point around its hinge, in the leaf's frame
var _pull_hand := Vector3.ZERO
var _pull_start := 0.0
var _clank: Array[AudioStream] = []

func _ready() -> void:
	add_to_group("interior_doors")
	process_physics_priority = -1
	for child in get_children():
		if child is AnimatableBody3D:
			var leaf := child as AnimatableBody3D
			# Moved from _physics_process; sync_to_physics would reset baked transforms.
			leaf.sync_to_physics = false
			_leaves.append(leaf)
			_base_yaw.append(leaf.rotation.y)
			_angle.append(0.0)
			_speed.append(0.0)
	if DisplayServer.get_name() == "headless":
		return  # no sound nodes in bakes and simulation tests
	_audio = AudioStreamPlayer3D.new()
	_audio.unit_size = 4.0
	_audio.max_distance = 25.0
	add_child(_audio)
	_creak = AudioStreamPlayer3D.new()
	_creak.unit_size = 3.0
	_creak.max_distance = 20.0
	add_child(_creak)
	if not _leaves.is_empty():
		_audio.position = _leaves[0].position + Vector3(0, 1.0, .9)
		_creak.position = _audio.position
	for path in ["res://assets/audio/sfx/impactMetal_heavy_000.ogg", "res://assets/audio/sfx/impactMetal_heavy_001.ogg",
			"res://assets/audio/sfx/impactMetal_light_000.ogg", "res://assets/audio/sfx/impactMetal_light_001.ogg"]:
		if ResourceLoader.exists(path):
			_clank.append(load(path))
	_creak.stream = _creak_loop()

# ---------------------------------------------------------------- door interface (player / HUD)

func prompt_text() -> String:
	if locked:
		return "Unlock the gate"
	return "Unlocked • push to open"

func toggle() -> void:
	if locked:
		unlock()

## Hold E on a leaf: `point` is where the view ray met it.
func grab(point: Vector3, collider: Object = null) -> void:
	var best := -1
	var best_d := INF
	for i in _leaves.size():
		if collider == _leaves[i]:
			best = i
			break
		var d := _leaves[i].global_position.distance_to(point)
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return
	_pull_leaf = best
	var local := _leaves[best].to_local(point)
	_pull_angle = atan2(local.x, local.z)
	_pull_hand = point
	_pull_start = _angle[best]

func drag_to(hand: Vector3, _delta: float) -> void:
	_pull_hand = hand

## Lets go; the leaf swings on with its momentum. Returns how far (rad) it moved while held.
func release() -> float:
	var moved := absf(_angle[_pull_leaf] - _pull_start) if _pull_leaf >= 0 else 0.0
	_pull_leaf = -1
	return moved

## Opening angle (rad) that brings the held point of leaf i under the hand.
func _hand_angle(i: int) -> float:
	var leaf := _leaves[i]
	var rel := _pull_hand - leaf.global_position
	var parent_yaw := (leaf.get_parent() as Node3D).global_rotation.y if leaf.get_parent() is Node3D else 0.0
	var leaf_yaw := wrapf(atan2(rel.x, rel.z) - _pull_angle - parent_yaw, -PI, PI)
	var open_sign := float(leaf.get_meta("open_sign", 1.0))
	return clampf(wrapf(leaf_yaw - _base_yaw[i], -PI, PI) * open_sign, 0.0, OPEN_LIMIT)

func unlock() -> void:
	if not locked:
		return
	locked = false
	_play(0, -4.0, .9)
	# The latch springs back and the first leaf drifts ajar.
	if not _speed.is_empty():
		_speed[0] = .16

func is_open() -> bool:
	for a in _angle:
		if a > .15:
			return true
	return false

func is_moving() -> bool:
	for s in _speed:
		if absf(s) > .01:
			return true
	return false

func snap_open() -> void:
	locked = false
	for i in _leaves.size():
		_angle[i] = OPEN_LIMIT * (.85 if i == 0 else .35)
		_speed[i] = 0.0
		_apply(i)

func snap_closed() -> void:
	for i in _leaves.size():
		_angle[i] = 0.0
		_speed[i] = 0.0
		_apply(i)

# ---------------------------------------------------------------- swing

func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
	var creak := 0.0
	for i in _leaves.size():
		var push := _push_rate(i)
		if i == _pull_leaf:
			if locked:
				if _pull_hand.distance_to(_leaves[i].global_position) > .2 and absf(_hand_angle(i) - _angle[i]) > .05:
					_rattle(delta)
				continue
			push = clampf((_hand_angle(i) - _angle[i]) * 8.0, -2.6, 2.6)
			if absf(push) < .02:
				push = 0.0
				_speed[i] *= exp(-12.0 * delta)
		if locked:
			if absf(push) > .05:
				_rattle(delta)
			continue
		if push != 0.0:
			_speed[i] = lerpf(_speed[i], push, 1.0 - exp(-PUSH_RESPONSE * delta))
		else:
			_speed[i] *= exp(-DAMPING * delta)
		var blocked := _blocked(i, signf(_speed[i]))
		if blocked:
			_speed[i] = 0.0
		var previous := _angle[i]
		_angle[i] = clampf(_angle[i] + _speed[i] * delta, 0.0, OPEN_LIMIT)
		if (_angle[i] >= OPEN_LIMIT and _speed[i] > 0.0) or (_angle[i] <= 0.0 and _speed[i] < 0.0):
			if absf(_speed[i]) > .6:
				_play(2 + i % 2, linear_to_db(clampf(absf(_speed[i]) * .5, .2, 1.0)) - 6.0, 1.0)
			_speed[i] = -_speed[i] * .15
		if absf(_speed[i]) < .004:
			_speed[i] = 0.0
		if _angle[i] != previous:
			_apply(i)
		creak = maxf(creak, absf(_speed[i]))
	_update_creak(creak)

func _apply(i: int) -> void:
	var leaf := _leaves[i]
	leaf.rotation.y = _base_yaw[i] + float(leaf.get_meta("open_sign", 1.0)) * _angle[i]

## Frame of leaf i: along its length (d) and its opening side (n).
func _frame(i: int) -> Array:
	var leaf := _leaves[i]
	var yaw := leaf.global_rotation.y
	var d := Vector3(sin(yaw), 0, cos(yaw))
	var n := Vector3(d.z, 0, -d.x) * float(leaf.get_meta("open_sign", 1.0))
	return [leaf.global_position, d, n, float(leaf.get_meta("width", 1.1))]

## Angular speed the player's push asks for (rad/s, + opens), or 0 when not pushing this leaf.
func _push_rate(i: int) -> float:
	if _player == null:
		return 0.0
	var f := _frame(i)
	var rel: Vector3 = _player.global_position - f[0]
	if rel.y < -.5 or rel.y > 2.0:
		return 0.0
	var along: float = rel.dot(f[1])
	var across: float = rel.dot(f[2])
	if along < .05 or along > float(f[3]) + .15:
		return 0.0
	var wish: Vector3 = _player.get("wish_velocity") if "wish_velocity" in _player else Vector3.ZERO
	var toward: float = wish.dot(f[2])
	var reach := PLAYER_RADIUS + .14
	var lever := maxf(along, .45)
	# Behind the leaf pushing it open, or in front of it pushing it shut.
	if across < .05 and across > -reach and toward > .05:
		return clampf(toward / lever, 0.0, 2.6)
	if across > -.05 and across < reach and toward < -.05:
		return clampf(toward / lever, -2.6, 0.0)
	return 0.0

## True when moving in `direction` would swing leaf i into the player.
func _blocked(i: int, direction: float) -> bool:
	if _player == null or direction == 0.0:
		return false
	var f := _frame(i)
	var rel: Vector3 = _player.global_position - f[0]
	var along: float = rel.dot(f[1])
	var across: float = rel.dot(f[2])
	if along < 0.0 or along > float(f[3]) + .1 or rel.y < -.5 or rel.y > 2.0:
		return false
	return across * direction > 0.0 and absf(across) < PLAYER_RADIUS + .06

func _find_player() -> CharacterBody3D:
	var scene := get_tree().current_scene
	if scene != null and "player" in scene and scene.player is CharacterBody3D:
		return scene.player
	return null

# ---------------------------------------------------------------- sound

func _play(index: int, volume: float, pitch: float) -> void:
	if _clank.is_empty() or _audio == null:
		return
	_audio.stream = _clank[index % _clank.size()]
	_audio.volume_db = volume
	_audio.pitch_scale = pitch * randf_range(.95, 1.05)
	_audio.play()

func _rattle(delta: float) -> void:
	_rattle_wait -= delta
	if _rattle_wait <= 0.0:
		_rattle_wait = .45
		_play(2 + randi() % 2, -10.0, .8)

func _update_creak(speed: float) -> void:
	if _creak == null or _creak.stream == null:
		return
	if speed > .05:
		_creak.volume_db = linear_to_db(clampf(speed * .7, .05, .9)) - 8.0
		_creak.pitch_scale = clampf(.75 + speed * .3, .7, 1.4)
		if not _creak.playing:
			_creak.play()
	elif _creak.playing:
		_creak.stop()

## Rusty hinge: a slow, irregular stick-slip squeal.
func _creak_loop() -> AudioStreamWAV:
	var rate := 22050
	var count := rate * 2
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var phase := 0.0
	var lp := 0.0
	for i in count:
		var t := float(i) / rate
		var pitch := 420.0 + 160.0 * sin(t * TAU * .7) + 60.0 * sin(t * TAU * 3.1)
		phase += pitch / rate
		# Stick-slip pulses: bursts of a buzzy tone.
		var grab := pow(maxf(0.0, sin(t * TAU * 9.0 + sin(t * 5.0) * 2.0)), 6.0)
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), .2)
		var saw := fmod(phase, 1.0) * 2.0 - 1.0
		var value := (saw * .5 + lp * .3) * (.25 + grab * .75) * .55
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 26000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = count
	return stream
