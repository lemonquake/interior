class_name InteriorVoiceLines
extends RefCounted
## 0.60: spoken dialogue. Every line in assets/audio/voices/dialogue.json (tools/dialogue_lines.py) has a clip
## assets/audio/voices/dialogue/<key>.ogg, key = the first 12 hex digits of sha1("<speaker>\n<text>"). The co-op
## subtitle box (session.gd `_set_dialogue`) and the single-player dialogue box (story_ui.gd) call `speak` with
## what they show; a line without a clip stays silent (text only). One line at a time: a new line cuts the last.

const DIR := "res://assets/audio/voices/dialogue/"

static var _player: AudioStreamPlayer
static var _last := ""

## "<speaker>\n<text>" as shown (or just "<text>" for narration). Strips the stage direction "(whispering) ".
static func key_of(speaker: String, text: String) -> String:
	var t := text.strip_edges().trim_prefix("(whispering) ").replace("’", "'")
	return (speaker.strip_edges() + "\n" + t).sha1_text().substr(0, 12)

static func has_clip(speaker: String, text: String) -> bool:
	return ResourceLoader.exists(DIR + key_of(speaker, text) + ".ogg")

## Plays the line once (calling again with the same line does nothing, so it can be called every frame).
static func speak(host: Node, speaker: String, text: String) -> void:
	var id := speaker + "\n" + text
	if id == _last:
		return
	_last = id
	if text.strip_edges() == "":
		return
	var path := DIR + key_of(speaker, text) + ".ogg"
	if not ResourceLoader.exists(path):
		return
	if _player == null or not is_instance_valid(_player):
		_player = AudioStreamPlayer.new()
		_player.name = "Dialogue voice"
		_player.bus = "Voices" if AudioServer.get_bus_index("Voices") >= 0 else "Master"
		_player.process_mode = Node.PROCESS_MODE_ALWAYS
		host.get_tree().root.add_child(_player)
	_player.stop()
	_player.stream = load(path)
	_player.play()

## The next `speak` plays even if it is the same line again (the single-player box: each line is its own event).
static func forget() -> void:
	_last = ""

## Stops the current line (a scene change, the dialogue closed).
static func hush() -> void:
	_last = ""
	if _player != null and is_instance_valid(_player):
		_player.stop()
