class_name InteriorTelevision
extends Node3D
## The living-room TV (prop television_4). It can't be carried: E turns it on or off, and Q or the
## mouse wheel changes channel. About two seconds after power-on, channel 3 shows the "News Order -
## Davao City" emergency broadcast. Every other channel is static. The picture renders into a
## SubViewport and goes through scripts/crt_screen.gdshader.

const NEWS_CHANNEL := 3
const CHANNELS := 12
const WARM_UP := 2.0
const CRT_SHADER = preload("res://scripts/crt_screen.gdshader")
const MESSAGES := [
	["STAY AT HOME", "UNTIL FURTHER NOTICE"],
	["LOCK YOUR DOORS", "AND WINDOWS"],
	["DO NOT GO OUTSIDE", "FOR ANY REASON"],
	["PABILIN SA BALAY", "HANGTUD SA DUGANG PAHIBALO"],
	["DO NOT OPEN YOUR DOOR", "FOR ANYONE"],
]
const TICKER := "ADVISORY: ALL RESIDENTS OF DAVAO CITY ARE ORDERED TO REMAIN INDOORS UNTIL FURTHER NOTICE  •  LOCK ALL DOORS AND WINDOWS  •  DO NOT LEAVE YOUR HOMES  •  I-LOCK ANG INYONG MGA PULTAHAN  •  STAY TUNED TO NEWS ORDER FOR FURTHER INSTRUCTIONS  •  "

var body: InteriorObject
var screen: MeshInstance3D
var powered := false
var channel := NEWS_CHANNEL
var _off_material: Material
var _material: ShaderMaterial
var _viewport: SubViewport
var _news: Control
var _headline: Label
var _subline: Label
var _ticker: Label
var _live: Label
var _clock: Label
var _osd: Label
var _light: SpotLight3D
var _audio: AudioStreamPlayer3D
var _hum: AudioStreamPlayer3D
var _streams: Dictionary = {}
var _on_time := 0.0
var _power_anim := 0.0
var _osd_left := 0.0
var _message := 0
var _message_time := 0.0
var _glitch_wait := 9.0
var _glitch_left := 0.0
var _ticker_x := 0.0
var _beep_wait := 6.0

## Wires the controller to the TV body; the body stays anchored and can no longer be grabbed.
static func attach(tv_body: InteriorObject) -> InteriorTelevision:
	var tv := InteriorTelevision.new()
	tv.name = "TelevisionController"
	tv.body = tv_body
	tv_body.add_child(tv)
	return tv

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	body.grab_mode = "none"
	body.display_name = "Television"
	body.set_meta("interactor", self)
	screen = body.find_child("Screen glass surface", true, false) as MeshInstance3D
	if screen != null:
		_off_material = screen.material_override
	var mobile := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(480, 270) if mobile else Vector2i(640, 360)
	_viewport.transparent_bg = false
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_build_news()
	_material = ShaderMaterial.new()
	_material.shader = CRT_SHADER
	_material.set_shader_parameter("screen_tex", _viewport.get_texture())
	_material.set_shader_parameter("resolution", Vector2(_viewport.size))
	_light = SpotLight3D.new()
	_light.light_color = Color(.55, .65, 1.0)
	_light.light_energy = 0.0
	_light.spot_range = 4.5
	_light.spot_angle = 70.0
	_light.shadow_enabled = false
	_light.visible = false
	_light.light_cull_mask = 1
	# The screen faces the body's +Z; a spot light shines along its own -Z.
	_light.rotation = Vector3(0, PI, 0)
	_light.position = Vector3(0, 0, .12)
	add_child(_light)
	_audio = AudioStreamPlayer3D.new()
	_audio.unit_size = 3.0
	_audio.max_distance = 14.0
	add_child(_audio)
	_hum = AudioStreamPlayer3D.new()
	_hum.unit_size = 2.0
	_hum.max_distance = 12.0
	add_child(_hum)
	if DisplayServer.get_name() != "headless":
		_streams["static"] = _noise_loop(2.0, 0.55, 11)
		_streams["news"] = _news_bed()
		_streams["click"] = _click()
		_streams["beep"] = _attention_tone()
	set_process(false)

func prompt_text() -> String:
	if not powered:
		return "Turn on the TV"
	return "Turn off the TV     Q • Change channel (CH %02d)" % channel

func interact() -> void:
	set_power(not powered)

func set_power(on: bool) -> void:
	if on == powered:
		return
	powered = on
	_play_once("click", -6.0)
	if on:
		_on_time = 0.0
		_power_anim = 0.0
		_glitch_wait = randf_range(7.0, 14.0)
		if screen != null:
			screen.material_override = _material
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_light.visible = true
		set_process(true)
	else:
		_hum.stop()
		_osd_left = 0.0

func change_channel(step := 1) -> void:
	if not powered:
		return
	channel = wrapi(channel + step, 1, CHANNELS + 1)
	_osd_left = 2.5
	_glitch_left = .25
	_play_once("click", -14.0)
	_update_sound()

func is_news() -> bool:
	return powered and channel == NEWS_CHANNEL and _on_time >= WARM_UP

func _process(delta: float) -> void:
	if powered:
		_on_time += delta
		_power_anim = minf(1.0, _power_anim + delta / .35)
	else:
		_power_anim = maxf(0.0, _power_anim - delta / .3)
		if _power_anim <= 0.0:
			if screen != null:
				screen.material_override = _off_material
			_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			_light.visible = false
			set_process(false)
			return
	var warming := _on_time < WARM_UP
	var news := channel == NEWS_CHANNEL and not warming
	# Warm-up: the raster opens, then two seconds of dark, hissing snow before the picture locks.
	var static_amount := 1.0
	if news:
		static_amount = clampf(1.0 - (_on_time - WARM_UP) / .4, 0.03, 1.0)
	elif warming:
		static_amount = lerpf(.25, .7, clampf(_on_time / WARM_UP, 0.0, 1.0))
	_glitch_wait -= delta
	if news and _glitch_wait <= 0.0:
		_glitch_wait = randf_range(8.0, 18.0)
		_glitch_left = randf_range(.15, .5)
	_glitch_left = maxf(0.0, _glitch_left - delta)
	_material.set_shader_parameter("power", _power_anim)
	_material.set_shader_parameter("static_mix", static_amount)
	_material.set_shader_parameter("picture", 1.0 if news else 0.0)
	_material.set_shader_parameter("glitch", minf(1.0, _glitch_left * 3.0))
	_material.set_shader_parameter("brightness", 1.0 if (warming and channel == NEWS_CHANNEL and _on_time > .4) else 1.35)
	_news.visible = news
	_osd_left = maxf(0.0, _osd_left - delta)
	_osd.visible = powered and (_osd_left > 0.0 or (not warming and not news))
	_osd.text = "CH %02d" % channel
	if news:
		_animate_news(delta)
	var flicker := .85 + .15 * sin(Time.get_ticks_msec() * .031) + randf_range(-.1, .1)
	_light.light_energy = _power_anim * (1.1 if news else .7) * flicker
	_light.light_color = Color(.5, .6, 1.0) if news else Color(.85, .88, .95)
	if powered:
		_update_sound()

func _animate_news(delta: float) -> void:
	_message_time += delta
	if _message_time > 5.5:
		_message_time = 0.0
		_message = (_message + 1) % MESSAGES.size()
		_headline.text = MESSAGES[_message][0]
		_subline.text = MESSAGES[_message][1]
	_ticker_x -= delta * 70.0
	var width := _ticker.get_minimum_size().x * .5
	if _ticker_x < -width:
		_ticker_x += width
	_ticker.position.x = 118.0 + _ticker_x
	_live.modulate.a = 1.0 if fmod(_on_time, 1.2) < .8 else .25
	var t := Time.get_time_dict_from_system()
	_clock.text = "%02d:%02d" % [t.hour, t.minute]
	_beep_wait -= delta
	if _beep_wait <= 0.0:
		_beep_wait = randf_range(14.0, 22.0)
		_play_once("beep", -17.0)

func _update_sound() -> void:
	if _streams.is_empty():
		return
	var want := "news" if is_news() else ("static" if powered else "")
	var current: AudioStream = _hum.stream
	if want == "":
		_hum.stop()
		return
	if current != _streams[want] or not _hum.playing:
		_hum.stream = _streams[want]
		_hum.volume_db = -20.0 if want == "news" else -19.0
		_hum.play()

func _play_once(key: String, volume: float) -> void:
	if not _streams.has(key):
		return
	_audio.stream = _streams[key]
	_audio.volume_db = volume
	_audio.play()

# ---------------------------------------------------------------- broadcast layout (640 x 360)

func _build_news() -> void:
	var s := Vector2(_viewport.size) / Vector2(640, 360)
	var root := Control.new()
	root.size = Vector2(640, 360)
	root.scale = s
	_viewport.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(.02, .025, .05)
	bg.size = Vector2(640, 360)
	root.add_child(bg)
	_news = Control.new()
	_news.size = Vector2(640, 360)
	root.add_child(_news)
	var grad := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(.05, .09, .2))
	gradient.set_color(1, Color(.01, .015, .04))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(.5, .45)
	tex.fill_to = Vector2(1.1, 1.1)
	tex.width = 128
	tex.height = 72
	grad.texture = tex
	grad.size = Vector2(640, 360)
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_news.add_child(grad)
	# Station bug, top left.
	_rect(_news, Vector2(22, 18), Vector2(196, 50), Color(.72, .05, .05))
	_rect(_news, Vector2(22, 68), Vector2(196, 20), Color(.95, .95, .95))
	_text(_news, "NEWS ORDER", Vector2(30, 20), 32, Color.WHITE, true)
	_text(_news, "DAVAO CITY", Vector2(30, 67), 15, Color(.1, .08, .1), true)
	_live = _text(_news, "LIVE", Vector2(548, 22), 22, Color(1, .2, .18), true)
	var dot := _rect(_live, Vector2(-20, 9), Vector2(12, 12), Color(1, .2, .18))
	dot.show_behind_parent = true
	_clock = _text(_news, "00:00", Vector2(540, 50), 18, Color(.9, .92, .95), false)
	# Advisory banner and the message.
	_rect(_news, Vector2(0, 112), Vector2(640, 34), Color(.95, .78, .08))
	_text(_news, "EMERGENCY ADVISORY  •  ABISO", Vector2(24, 114), 22, Color(.08, .05, .02), true)
	_headline = _text(_news, MESSAGES[0][0], Vector2(24, 156), 50, Color.WHITE, true)
	_subline = _text(_news, MESSAGES[0][1], Vector2(26, 218), 30, Color(.82, .87, .95), true)
	_text(_news, "By order of the City Government. Keep your doors locked.", Vector2(26, 262), 16, Color(.6, .65, .75), false)
	# Ticker.
	_rect(_news, Vector2(0, 308), Vector2(640, 34), Color(.08, .08, .12))
	var ticker_clip := Control.new()
	ticker_clip.position = Vector2(0, 308)
	ticker_clip.size = Vector2(640, 34)
	ticker_clip.clip_contents = true
	_news.add_child(ticker_clip)
	_ticker = _text(ticker_clip, TICKER + TICKER, Vector2(118, 3), 20, Color.WHITE, false)
	_rect(ticker_clip, Vector2(0, 0), Vector2(110, 34), Color(.72, .05, .05))
	_text(ticker_clip, "ABISO", Vector2(18, 3), 22, Color.WHITE, true)
	_osd = _text(root, "CH 03", Vector2(500, 300), 34, Color(.3, 1.0, .35), true)
	_osd.add_theme_color_override("font_outline_color", Color(0, .15, 0))
	_osd.add_theme_constant_override("outline_size", 6)

func _rect(parent: Control, at: Vector2, size: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = at
	r.size = size
	r.color = color
	parent.add_child(r)
	return r

func _text(parent: Control, text: String, at: Vector2, font_size: int, color: Color, bold: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if bold:
		var font := FontVariation.new()
		font.base_font = ThemeDB.fallback_font
		font.variation_embolden = .9
		label.add_theme_font_override("font", font)
	parent.add_child(label)
	return label

# ---------------------------------------------------------------- generated sounds

func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 26000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = samples.size()
	return stream

func _noise_loop(seconds: float, level: float, seed_value: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := PackedFloat32Array()
	out.resize(int(seconds * 22050))
	var hp := 0.0
	var last := 0.0
	for i in out.size():
		var n := rng.randf_range(-1.0, 1.0)
		hp = .7 * (hp + n - last)  # high-passed hiss
		last = n
		var t := float(i) / 22050.0
		out[i] = (hp * .8 + sin(t * TAU * 15734.0 * .1) * .02) * level
	return _wav(out, true)

## A low, uneasy broadcast bed: mains hum, a soft carrier whine and a slow swell.
func _news_bed() -> AudioStreamWAV:
	var out := PackedFloat32Array()
	out.resize(22050 * 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lp := 0.0
	for i in out.size():
		var t := float(i) / 22050.0
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), .05)
		var swell := .6 + .4 * sin(t * TAU * .25)
		out[i] = (sin(t * TAU * 60.0) * .18 + sin(t * TAU * 120.0) * .08 + sin(t * TAU * 220.0) * .05 * swell + lp * .12) * .8
	return _wav(out, true)

func _click() -> AudioStreamWAV:
	var out := PackedFloat32Array()
	out.resize(int(.25 * 22050))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in out.size():
		var t := float(i) / 22050.0
		out[i] = (rng.randf_range(-1.0, 1.0) * exp(-t * 90.0) + sin(t * TAU * 95.0) * exp(-t * 18.0) * .6) * .9
	return _wav(out, false)

## Two-tone (853 + 960 Hz) emergency attention signal, short and quiet.
func _attention_tone() -> AudioStreamWAV:
	var out := PackedFloat32Array()
	out.resize(int(1.6 * 22050))
	for i in out.size():
		var t := float(i) / 22050.0
		var env := minf(t * 40.0, 1.0) * minf((1.6 - t) * 20.0, 1.0)
		out[i] = (sin(t * TAU * 853.0) + sin(t * TAU * 960.0)) * .3 * env
	return _wav(out, false)
