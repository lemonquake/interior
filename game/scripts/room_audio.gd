class_name InteriorRoomAudio
extends Node3D

## Reusable positional voices and deterministic authored sounds.
var player: InteriorPlayer
var voices: Array[AudioStreamPlayer3D] = []
var footsteps: AudioStreamPlayer3D
var fan: AudioStreamPlayer3D
var _soft: AudioStreamWAV
var _hard: AudioStreamWAV
var _ceramic: AudioStreamWAV
var _speeds: Dictionary = {}
var _cooldowns: Dictionary = {}
var _distance := 0.0
var _was_grounded := false
var _fall_speed := 0.0
var _voice := 0
var _elapsed := 0.0

func setup(room: Node3D, character: InteriorPlayer) -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	player = character
	# The headless dummy mixer does not consume queued WAV voices. Simulation
	# tests have no audible output and need no playback allocation.
	if DisplayServer.get_name() == "headless":
		set_physics_process(false)
		return
	_soft = _sound(0.16, 75.0, 0.0, 27)
	_hard = _sound(0.20, 125.0, 0.0, 57)
	_ceramic = _sound(0.27, 720.0, 0.30, 81)
	for i in 12:
		var voice := AudioStreamPlayer3D.new()
		voice.max_distance = 12.0
		voice.unit_size = 2.0
		add_child(voice)
		voices.append(voice)
	footsteps = AudioStreamPlayer3D.new()
	footsteps.stream = _sound(0.12, 100.0, 0.0, 19)
	footsteps.volume_db = -22.0
	footsteps.max_distance = 4.0
	add_child(footsteps)
	for body in get_tree().get_nodes_in_group("movable"):
		_speeds[body.get_instance_id()] = 0.0
		body.body_entered.connect(_impact.bind(body))
	var source: Node3D
	for body in get_tree().get_nodes_in_group("movable"):
		if "fan" in str(body.name).to_lower():
			source = body
			break
	if source != null:
		fan = AudioStreamPlayer3D.new()
		fan.process_mode = Node.PROCESS_MODE_PAUSABLE
		var stream := _sound(1.0, 60.0, 0.0, 45, true)
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = 22050
		fan.stream = stream
		fan.volume_db = -38.0
		fan.max_distance = 8.0
		source.add_child(fan)
		fan.position.y = 0.9
		fan.play()

func _exit_tree() -> void:
	for voice in voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null
	if is_instance_valid(footsteps):
		footsteps.stop()
		footsteps.stream = null
	if is_instance_valid(fan):
		fan.stop()
		fan.stream = null
	_soft = null
	_hard = null
	_ceramic = null

func _sound(duration: float, frequency: float, ring: float, seed_value: int, looped := false) -> AudioStreamWAV:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var data := PackedByteArray()
	var sample_count := int(duration * 22050.0)
	data.resize(sample_count * 2)
	var filtered := 0.0
	for i in sample_count:
		var t := float(i) / 22050.0
		filtered = lerpf(filtered, random.randf_range(-1.0, 1.0), 0.12)
		var envelope := 0.34 if looped else exp(-t * 22.0) * minf(t * 750.0, 1.0)
		var value := (filtered * 0.7 + sin(t * TAU * frequency) * 0.3) * envelope
		value += sin(t * TAU * frequency * 2.73) * ring * exp(-t * 15.0)
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 22000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	return stream

func _physics_process(delta: float) -> void:
	_elapsed += delta
	for body in get_tree().get_nodes_in_group("movable"):
		_speeds[body.get_instance_id()] = body.linear_velocity.length()
	if not is_instance_valid(player) or not player.playing:
		return
	var grounded := player.is_on_floor()
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	footsteps.global_position = player.global_position + Vector3.UP * 0.1
	if grounded and speed > 0.5:
		_distance += speed * delta
		var stride := 0.95 if speed > 3.5 else 0.70
		if _distance >= stride:
			_distance = fmod(_distance, stride)
			footsteps.pitch_scale = 1.0 + sin(_elapsed * 5.3) * 0.05
			footsteps.volume_db = -28.0 if player.camera.position.y < 1.3 else -22.0
			footsteps.play()
	else:
		_distance = minf(_distance, 0.25)
	if grounded and not _was_grounded and _fall_speed < -2.0:
		_play_at(player.global_position, _soft, clampf(-28.0 - _fall_speed, -25.0, -14.0), 0.85)
	_was_grounded = grounded
	_fall_speed = player.velocity.y

func _impact(other: Node, body: InteriorObject) -> void:
	if get_tree().paused or not is_instance_valid(body) or body.freeze or body.held:
		return
	var id := body.get_instance_id()
	if _elapsed - float(_cooldowns.get(id, -1.0)) < 0.22:
		return
	var speed := maxf(body.linear_velocity.length(), float(_speeds.get(id, 0.0)))
	if other is RigidBody3D:
		speed = maxf(speed, (other as RigidBody3D).linear_velocity.length())
	if speed < 0.65:
		return
	_cooldowns[id] = _elapsed
	var label := body.display_name.to_lower()
	var sound := _hard
	if "cushion" in label or "sofa" in label or "toy" in label:
		sound = _soft
	elif "pot" in label or "bowl" in label or "flower" in label:
		sound = _ceramic
	var strength := clampf(speed * sqrt(body.mass) * 0.06, 0.05, 1.0)
	_play_at(body.global_position, sound, linear_to_db(strength) - 12.0, clampf(1.1 - log(body.mass + 1.0) * 0.09, 0.65, 1.12))

func _play_at(location: Vector3, stream: AudioStreamWAV, volume: float, pitch: float) -> void:
	var voice := voices[_voice]
	_voice = (_voice + 1) % voices.size()
	voice.global_position = location
	voice.stream = stream
	voice.volume_db = volume
	voice.pitch_scale = pitch
	voice.play()
