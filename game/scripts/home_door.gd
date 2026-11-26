extends Node3D
## 0.26: the street door of the player's own house (scripts/home_exterior.gd). The family uses the balcony stair;
## this one is bolted from inside. Trying it shakes the bolt and says so, at most every two seconds.

var uses := 0
var _voice: AudioStreamPlayer3D
var _last := -10.0
var _shake := 0.0

func _ready() -> void:
	add_to_group("usables")
	_voice = AudioStreamPlayer3D.new()
	_voice.name = "Bolt"
	_voice.unit_size = 3.0
	_voice.max_distance = 18.0
	var path := "res://assets/audio/sfx/lock_turn.ogg"
	if ResourceLoader.exists(path):
		_voice.stream = load(path)
	add_child(_voice)
	_voice.position = Vector3(.1, 1.0, 0)
	set_process(false)

func prompt_text() -> String:
	return "Try the door"

func toggle() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last < 2.0:
		return
	_last = now
	uses += 1
	_shake = .35
	set_process(true)
	if _voice.stream != null:
		_voice.pitch_scale = randf_range(.72, .82)
		_voice.volume_db = -7.0
		_voice.play()
	var story := get_tree().get_first_node_in_group("story")
	if story != null and story.has_method("notify"):
		story.notify("Bolted from the inside.")

func _process(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta)
	rotation.y = sin(_shake * 70.0) * .006 * (_shake / .35)
	if _shake <= 0.0:
		rotation.y = 0.0
		set_process(false)
