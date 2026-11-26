extends Node3D
## Small usable things in the canal warren (E / touch Hold, like doors): a battery radio that still finds a
## station, a light switch for the dying fluorescent tube, the hand pump in the courtyard and the shrine's
## bell. Their state lives here; the warren (scripts/canal_warren.gd) reads it each frame.

var kind := "radio"
var on := false
var uses := 0
var warren: Node
var cooldown := 0.0
var _voice: AudioStreamPlayer3D
var _handle: Node3D
var _pump_time := -1.0

func _ready() -> void:
	add_to_group("usables")
	add_to_group("warren_usables")
	_voice = AudioStreamPlayer3D.new()
	_voice.name = "Sound"
	_voice.max_distance = 14.0
	_voice.unit_size = 2.5
	add_child(_voice)
	match kind:
		"radio":
			_voice.stream = _radio_loop()
			_voice.volume_db = -13.0
		"switch":
			_voice.stream = _click()
			_voice.volume_db = -10.0
		"pump":
			_voice.stream = load("res://assets/audio/sfx/hit_water.ogg")
			_voice.volume_db = -9.0
			_handle = get_node_or_null("Handle") as Node3D

func prompt_text() -> String:
	match kind:
		"radio": return "Turn off radio" if on else "Turn on radio"
		"switch": return "Flip light switch"
		"pump": return "Work the hand pump"
	return "Use"

func toggle() -> void:
	if cooldown > 0.0: return
	uses += 1
	match kind:
		"radio":
			on = not on
			if on: _voice.play()
			else: _voice.stop()
			cooldown = .3
		"switch":
			on = not on
			_voice.play()
			cooldown = .25
		"pump":
			_pump_time = 0.0
			cooldown = 1.6
			_voice.pitch_scale = randf_range(.75, .9)
			_voice.play()
	if is_instance_valid(warren) and warren.has_method("usable_changed"):
		warren.usable_changed(self)

func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if kind == "radio" and on and not _voice.playing and is_visible_in_tree():
		_voice.play()
	if _handle != null and _pump_time >= 0.0:
		_pump_time += delta
		var stroke := sin(clampf(_pump_time / 1.4, 0, 1) * PI * 2.0)
		_handle.rotation.z = -.55 * stroke
		if _pump_time > 1.4:
			_pump_time = -1.0
			_handle.rotation.z = 0.0

static func _wav(samples: PackedFloat32Array, rate: int, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1, 1) * 22000))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav

## Six seconds of AM hiss: crackle, a whistling carrier and a far-off, unintelligible voice that fades in and out.
static func _radio_loop() -> AudioStreamWAV:
	var rate := 22050
	var n := rate * 6
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var low := 0.0
	var band := 0.0
	var voice_phase := 0.0
	for i in n:
		var t := float(i) / rate
		var noise := rng.randf_range(-1, 1)
		low += (noise - low) * .25
		band = low - band * .2
		var crackle := (rng.randf_range(-1, 1) * 1.6) if rng.randf() < .0009 else 0.0
		# Syllable-like bursts of a band-limited buzz, as if someone talks under the static.
		var syllable := maxf(0.0, sin(t * 7.3) * sin(t * 2.1 + 1.0)) * (.5 + .5 * sin(t * .9))
		var pitch := 140.0 + 40.0 * sin(t * 3.7) + 25.0 * sin(t * 11.0)
		voice_phase += pitch / rate * TAU
		var voice := (sin(voice_phase) + .5 * sin(voice_phase * 3.0) + .3 * sin(voice_phase * 5.0)) * syllable * .22
		var whistle := sin(t * TAU * (1800.0 + 30.0 * sin(t * .7))) * .03
		var fade := minf(1.0, minf(t / .05, (6.0 - t) / .05))
		out[i] = (band * .45 + crackle + voice + whistle) * fade
	return _wav(out, rate, true)

static func _click() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * .08)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in n:
		var t := float(i) / rate
		out[i] = (rng.randf_range(-1, 1) * .7 + sin(t * TAU * 2400.0) * .4) * exp(-t * 90.0)
	return _wav(out, rate)
