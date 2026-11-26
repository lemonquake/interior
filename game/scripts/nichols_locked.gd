extends Node3D
## A Nichols-house door that will not open (0.21): the handle turns, the latch rattles, nothing gives.

var label := "door"
var lines: Array = ["It won't open.", "Locked. Or something's holding it from the other side.", "It's stuck fast."]
var _uses := 0
var _voice: AudioStreamPlayer3D
var _cool := 0.0

func _ready() -> void:
	add_to_group("usables")
	add_to_group("nichols_locked")
	_voice = AudioStreamPlayer3D.new()
	_voice.max_distance = 16.0
	_voice.unit_size = 2.5
	_voice.volume_db = -8.0
	var path := "res://assets/audio/nichols/door_close_b.ogg"
	if ResourceLoader.exists(path):
		_voice.stream = load(path)
	add_child(_voice)

func prompt_text() -> String:
	return "Open " + label

func toggle() -> void:
	if _cool > 0.0:
		return
	_cool = 1.2
	if _voice.stream != null:
		_voice.pitch_scale = randf_range(1.25, 1.45)
		_voice.play()
	var story := get_tree().get_first_node_in_group("story")
	if story != null and not story.ui.dialogue_active():
		story.ui.say("You", [lines[mini(_uses, lines.size() - 1)]], 3.0)
	_uses += 1

func _process(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)
