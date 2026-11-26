extends Node3D
## Sparse, positional events; all state belongs to this scene and resets on Restart.
const LINES := ["I guess no one's home..", "Hello? ...Anyone there?", "Locked. No answer, either.",
	"Someone used to live here. Where did everybody go?", "I thought I heard something inside.",
	"No lights. Not a sound.", "Maybe I should leave this one alone."]
const ZONES := [Vector3(20.5, -2.9, 10.5), Vector3(-8, -2.9, 18), Vector3(21, -2.9, 39)]
## Covers both pavements at the courtyard lane / Malasugue Street mouth.
const PSST_APPROACH := Rect2(18.0, 5.5, 6.0, 11.0)
const PSST_SOURCE := Vector3(23.4, -1.45, 10.5)
var fired: Dictionary = {}
var event_count := 0
var _player: InteriorPlayer
var _story: InteriorStory
var _active_object: Node3D
var _elapsed := -1.0
var _gun_was_out := false
var _tap := 0
var _remark := 0
var _wait := 24.0
var _zone_wait := 0.0
var _step_time := -1.0
var _step_index := 0
var _step_origin := Vector3.ZERO
var _event_voice: AudioStreamPlayer3D
var _whisper_voice: AudioStreamPlayer3D
var _object_voice: AudioStreamPlayer3D
var _psst: AudioStreamWAV
var _knock: AudioStreamWAV
var _bell: AudioStreamWAV
var _arms: Node3D
var _arm_rest := Transform3D.IDENTITY
var _skeleton: Skeleton3D
var _knock_bone_poses: Array[Transform3D] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.randomize()
	_event_voice = _voice("Street sound", 50.0)
	_event_voice.unit_size = 12.0
	_event_voice.attenuation_filter_cutoff_hz = 12000.0
	_event_voice.attenuation_filter_db = -6.0
	_event_voice.bus = "Steps"
	_whisper_voice = _voice("Psst behind the east gate", 24.0)
	_whisper_voice.unit_size = 7.0
	_whisper_voice.bus = "Steps"
	_whisper_voice.attenuation_filter_cutoff_hz = 16000.0
	_whisper_voice.attenuation_filter_db = -3.0
	_object_voice = _voice("Object sound", 13.0)
	_psst = _synthesize("psst", .68)
	_knock = _synthesize("knock", .20)
	_bell = _synthesize("bell", 1.1)

func _voice(label: String, reach: float) -> AudioStreamPlayer3D:
	var voice := AudioStreamPlayer3D.new()
	voice.name = label
	voice.max_distance = reach
	voice.unit_size = 4.0
	voice.max_db = -3.0
	add_child(voice)
	return voice

func _resolve() -> bool:
	var scene := get_tree().current_scene
	if scene == null or not "player" in scene: return false
	_player = scene.player
	_story = get_tree().get_first_node_in_group("story") as InteriorStory
	return is_instance_valid(_player) and _player.playing and is_visible_in_tree()

func _outside() -> bool:
	if not _resolve(): return false
	var p := _player.global_position
	# The town streets, and (0.18) the canal settlement and its warren west of them.
	return p.y < -.7 and (Rect2(-24, -18, 74, 73).has_point(Vector2(p.x, p.z)) or Rect2(-124, -18, 92, 92).has_point(Vector2(p.x, p.z)))

func use_object(object: Node3D) -> bool:
	if not _outside() or _elapsed >= 0.0 or _story == null or _story.ui.dialogue_active(): return false
	if _player.camera.global_position.distance_to(object.global_position) > 2.4: return false
	if object.kind == "door" and not within_knocking_reach(object): return false
	# The knock needs the hands for a moment; the gun comes back up by itself when it is over (0.30).
	_gun_was_out = is_instance_valid(_story.gun) and _story.gun.drawn
	if is_instance_valid(_story.gun): _story.gun.holster(true)
	_active_object = object
	_elapsed = 0.0
	_player.set_meta("knocking", true)
	_tap = 0
	_object_voice.global_position = object.global_position + object.global_basis.z * .1
	if object.kind == "door":
		_ensure_arms()
		_reset_hand_pose()
		_update_hand_pose()
		_arms.reset_physics_interpolation()
		_play(_object_voice, load("res://assets/audio/sfx/lock_turn.ogg"), -15.0, .78)
	elif object.kind == "bell":
		_play(_object_voice, _bell, -16.0, .84)
	else:
		_play(_object_voice, load("res://assets/audio/sfx/impactMetal_light_000.ogg"), -17.0, .73)
	return true

func within_knocking_reach(object: Node3D) -> bool:
	var camera := get_viewport().get_camera_3d()
	return camera != null and camera.global_position.distance_to(_contact_point(object)) < .80

func _contact_point(object: Node3D) -> Vector3:
	# Use the same target for reach, aim and the fist, including when crouched.
	var camera := get_viewport().get_camera_3d()
	var height := clampf(camera.global_position.y - object.global_position.y - .09, -.35, .45) if camera != null else .30
	return object.global_position + Vector3.UP * height + object.global_basis.z * .10

func _reset_hand_pose() -> void:
	for bone in _knock_bone_poses.size():
		_skeleton.set_bone_pose(bone, _knock_bone_poses[bone])
	_skeleton.force_update_all_bone_transforms()
	_arms.hide()

func _place_hand(object: Node3D) -> void:
	_arms.position = Vector3(-.06, .11, -.13)
	_arms.rotation = Vector3(0, PI, -.28)
	var hand_pose := _skeleton.get_bone_global_pose(_skeleton.find_bone("hand.R"))
	var knuckles := _player.camera.to_local(_skeleton.to_global(hand_pose * Vector3(0, .065, .01)))
	var contact := _player.camera.to_local(_contact_point(object))
	_arms.position += contact - knuckles
	_arm_rest = _arms.transform

func _update_hand_pose() -> void:
	# Re-anchor to the door each frame: small player movement cannot drag the fist through it.
	_place_hand(_active_object)
	var rise := smoothstep(.08, .36, _elapsed) * (1.0 - smoothstep(1.55, 1.9, _elapsed))
	var pulse := 0.0
	for t in [.63, .96, 1.29]:
		pulse += exp(-pow((_elapsed - t) / .048, 2.0))
	var outward := _player.camera.global_basis.inverse() * _active_object.global_basis.z
	_arms.position += Vector3.DOWN * .60 * (1.0 - rise) + outward * .08 * (1.0 - pulse)
	_arms.visible = rise > .005

func _process(delta: float) -> void:
	if not _outside():
		_cancel_action()
		_event_voice.stop()
		_whisper_voice.stop()
		_step_time = -1.0
		return
	_update_action(delta)
	# Story dialogue and the siren sequence take priority over incidental scares.
	if _elapsed >= 0.0 or (_story != null and (_story.ui.dialogue_active() or _story.phase >= InteriorStory.Phase.CALLED)):
		_event_voice.stop()
		_whisper_voice.stop()
		_step_time = -1.0
		return
	_wait -= delta
	_zone_wait = maxf(0.0, _zone_wait - delta)
	for i in ZONES.size():
		var p := _player.global_position
		var inside := PSST_APPROACH.has_point(Vector2(p.x, p.z)) if i == 0 else Vector2(p.x, p.z).distance_to(Vector2(ZONES[i].x, ZONES[i].z)) < 3.2
		if not fired.has(i) and inside and _zone_wait <= 0.0 and not _event_voice.playing and not _whisper_voice.playing and _step_time < 0.0:
			trigger_zone(i)
			break
	if _step_time >= 0.0:
		_update_steps(delta)
	elif _wait <= 0.0 and not _whisper_voice.playing:
		_start_steps()

func trigger_zone(index: int) -> bool:
	if fired.has(index) or index < 0 or index >= ZONES.size(): return false
	fired[index] = true
	event_count += 1
	_zone_wait = 18.0
	_wait = _rng.randf_range(38.0, 62.0)
	if index == 0:
		_whisper_voice.global_position = PSST_SOURCE
		_play(_whisper_voice, _psst, -3.5, 1.0)
	else:
		_start_steps()
	return true

func _start_steps() -> void:
	# Do not overwrite a whisper or begin a sequence while it is still audible.
	if _whisper_voice.playing: return
	_wait = _rng.randf_range(42.0, 72.0)
	if _player == null: return
	_step_origin = _player.global_position + _player.camera.global_basis.z * 12.0 + _player.camera.global_basis.x * _rng.randf_range(-5.0, 5.0)
	_step_origin.y = -2.75
	_step_index = 0
	_step_time = 0.0

func _update_steps(delta: float) -> void:
	var toward := (_step_origin - _player.camera.global_position).normalized()
	if (-_player.camera.global_basis.z).dot(toward) > .70 or _player.global_position.distance_to(_step_origin) < 5.0:
		_step_time = -1.0
		_event_voice.stop()
		return
	_step_time -= delta
	if _step_time > 0.0: return
	_event_voice.global_position = _step_origin + Vector3(.45, 0, .30) * _step_index
	_play(_event_voice, load("res://assets/audio/footsteps/footstep_concrete_%03d.ogg" % (_step_index % 5)), 1.0, _rng.randf_range(.84, .98))
	_step_index += 1
	_step_time = _rng.randf_range(.55, .88) if _step_index < 5 else -1.0

func _update_action(delta: float) -> void:
	if _elapsed < 0.0: return
	if not is_instance_valid(_active_object) or _player.camera.global_position.distance_to(_active_object.global_position) > 2.65:
		_cancel_action()
		return
	# Looking or walking away cancels the gesture instead of knocking into empty space.
	var contact := _contact_point(_active_object) if _active_object.kind == "door" else _active_object.global_position
	var toward := (contact - _player.camera.global_position).normalized()
	var looking_away := (-_player.camera.global_basis.z).dot(toward) < .80
	if _active_object.kind == "door":
		# Aiming at any part of the actual door counts; a centre-angle test incorrectly
		# cancelled valid close-up attempts aimed at its handle or upper panels.
		var hit := _player.ray_hit(InteriorPlayer.REACH, 6)
		var collider := hit.get("collider") as Node
		looking_away = collider == null or collider.get_parent() != _active_object
	# A small reach margin prevents normal breathing/head movement cancelling at the boundary.
	if looking_away or (_active_object.kind == "door" and _player.camera.global_position.distance_to(contact) > .90):
		_cancel_action()
		return
	_elapsed += delta
	if _active_object.kind == "door":
		_update_hand_pose()
		if _tap < 3 and _elapsed >= [.63, .96, 1.29][_tap]:
			_play(_object_voice, _knock, -9.0 + float(_tap % 2) * -2.0, _rng.randf_range(.92, 1.06))
			_tap += 1
	if _elapsed >= 2.25:
		var line: String
		match _active_object.kind:
			"bell": line = "The bell still works. Nobody's coming." if _active_object.uses <= 1 else "Still no answer."
			"mailbox": line = "Just damp envelopes. They've been here a long time." if _active_object.uses <= 1 else "Nothing new. Only the same wet letters."
			_:
				if _active_object.has_meta("lines"):
					var lines: Array = _active_object.get_meta("lines")
					line = lines[(_active_object.index + _active_object.uses - 1) % lines.size()]
				else:
					line = LINES[_remark % LINES.size()]
					_remark += 1
		if _story != null and not _story.ui.dialogue_active(): _story.ui.say("You", [line], 3.5)
		_cancel_action()

func _cancel_action() -> void:
	if is_instance_valid(_active_object) and _active_object.kind == "door":
		_active_object.cooldown = 0.0
	_elapsed = -1.0
	_active_object = null
	_object_voice.stop()
	if is_instance_valid(_player): _player.set_meta("knocking", false)
	if _gun_was_out and _story != null and is_instance_valid(_story.gun):
		_gun_was_out = false
		_story.gun.draw()
	if is_instance_valid(_arms):
		_arms.hide()
		_arms.transform = _arm_rest
		_arms.reset_physics_interpolation()

func _ensure_arms() -> void:
	if is_instance_valid(_arms): return
	_arms = (load("res://assets/characters/fp_arms.glb") as PackedScene).instantiate()
	_arms.name = "Knocking hand"
	_player.camera.add_child(_arms)
	_arms.rotation.y = PI
	var animation := _arms.find_child("AnimationPlayer", true, false) as AnimationPlayer
	animation.play("fp_idle")
	animation.seek(0, true)
	animation.pause()
	animation.process_mode = Node.PROCESS_MODE_DISABLED
	var skeleton := _arms.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_skeleton = skeleton
	skeleton.set_bone_pose_scale(skeleton.find_bone("upper_arm.L"), Vector3.ONE * .001)
	var forearm := skeleton.find_bone("forearm.R")
	skeleton.set_bone_pose_rotation(forearm, skeleton.get_bone_pose_rotation(forearm) * Quaternion(Vector3.UP, -1.2))
	# The existing closed right fist has the same skin and sleeve as the gun arms.
	# Raise it, with the knuckles facing the door; the forearm follows the tapping wrist.
	_arms.position = Vector3(-.06, .11, -.13)
	_arms.rotation.z = -.28
	for mesh in _arms.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = 2
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arm_rest = _arms.transform
	for bone in skeleton.get_bone_count():
		_knock_bone_poses.append(skeleton.get_bone_pose(bone))
	_arms.hide()

func _play(voice: AudioStreamPlayer3D, stream: AudioStream, db: float, pitch: float) -> void:
	voice.stream = stream
	voice.volume_db = db
	voice.pitch_scale = pitch
	voice.play()

func _synthesize(kind: String, duration: float) -> AudioStreamWAV:
	var rate := 22050
	var count := int(duration * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1917
	var low := 0.0
	for i in count:
		var t := float(i) / rate
		var noise := rng.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, .17)
		var sample := 0.0
		match kind:
			"psst":
				# Breath-only p / s / t: a lip burst, sustained high-pass hiss and clipped ending.
				var envelope := smoothstep(.02, .09, t) * (1.0 - smoothstep(.38, .64, t))
				sample = (noise - low) * envelope * (.36 + .05 * sin(t * 31.0)) + low * exp(-t * 75.0) * .5
			"knock":
				sample = (sin(t * TAU * 137) * .6 + sin(t * TAU * 293) * .23) * exp(-t * 36.0) + noise * exp(-t * 340.0) * .3
			"bell":
				sample = (sin(t * TAU * 612) + .4 * sin(t * TAU * 921.3)) * exp(-t * 4.2) * .30 + noise * exp(-t * 95) * .1
		sample *= minf(t * 900.0, 1.0) * minf((duration - t) * 150.0, 1.0)
		data.encode_s16(i * 2, int(clampf(sample, -.95, .95) * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream
