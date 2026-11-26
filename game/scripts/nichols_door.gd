extends InteriorHingedDoor
## A door of the Nichols house (0.21): the double front door and the interior doors. It swings and can be
## pulled by hand like every other door, but it is not one of the owner's "interior_doors" (those reveal the
## balcony); it joins "usables". Old hinges: a recorded squeal when it starts to move, another while it is
## dragged, and a heavy knock when it falls shut. Recordings: assets/audio/nichols (Wikimedia Commons, see
## licenses/NICHOLS_SOUNDS.md).

const OPENS := ["door_open_a", "door_open_b", "door_open_c", "door_open_d"]
const SHUTS := ["door_close_a", "door_close_b"]

var heavy := false
var _voice: AudioStreamPlayer3D
var _last := 0.0
var _was_closed := true
var _streams: Array[AudioStream] = []
var _shuts: Array[AudioStream] = []

func _ready() -> void:
	super._ready()
	remove_from_group("interior_doors")
	add_to_group("usables")
	add_to_group("nichols_doors")
	for clip: String in OPENS:
		var path := "res://assets/audio/nichols/" + clip + ".ogg"
		if ResourceLoader.exists(path):
			_streams.append(load(path))
	for clip: String in SHUTS:
		var path := "res://assets/audio/nichols/" + clip + ".ogg"
		if ResourceLoader.exists(path):
			_shuts.append(load(path))
	_voice = AudioStreamPlayer3D.new()
	_voice.name = "Hinges"
	_voice.max_distance = 30.0
	_voice.unit_size = 4.0 if heavy else 3.0
	_voice.volume_db = -2.0 if heavy else -6.0
	_voice.bus = "Steps" if AudioServer.get_bus_index("Steps") >= 0 else "Master"
	add_child(_voice)
	_last = _body.rotation.y if _body != null else 0.0
	_was_closed = absf(_last) < .03

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _body == null or not is_visible_in_tree():
		return
	var angle := _body.rotation.y
	var speed := absf(angle - _last) / maxf(delta, .001)
	var closing := absf(angle) < absf(_last)
	_last = angle
	var closed := absf(angle) < .02
	if _was_closed and not closed and not _streams.is_empty():
		_play(_streams[randi() % _streams.size()], randf_range(.82, .95) if heavy else randf_range(.92, 1.08))
	elif closed and not _was_closed and closing and not _shuts.is_empty():
		_play(_shuts[randi() % _shuts.size()], .8 if heavy else 1.0)
	elif speed > .6 and not _voice.playing and not _streams.is_empty():
		_play(_streams[randi() % _streams.size()], randf_range(.85, 1.1))
	_was_closed = closed

func _play(stream: AudioStream, pitch: float) -> void:
	_voice.stream = stream
	_voice.pitch_scale = pitch
	_voice.play()

func prompt_text() -> String:
	return ("Close " if is_open() else "Open ") + label
