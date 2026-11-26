class_name InteriorStoryUI
extends Control
## 0.10: the story's on-screen pieces, over the HUD: notifications ("You now have the key."), the dialogue box
## for the hooded man, and the inspect screen for the Glock (drag to rotate, OK to take it).

signal dialogue_finished
signal inspect_closed(taken: bool)

const GLOCK := preload("res://assets/models/story/glock17.glb")

var mobile := false
var _toasts: VBoxContainer
var _dialogue: PanelContainer
var _speaker: Label
var _line: Label
var _hint: Label
var _lines: Array = []
var _line_index := -1
var _shown_chars := 0.0
var _line_time := 0.0
var _auto_advance := 0.0
var _inspect: Control
var _viewport: SubViewport
var _pivot: Node3D
var _gun: Node3D
var _gun_anim: AnimationPlayer
var _yaw := -.55
var _pitch := .18
var _spin_velocity := 0.0
var _dragging := false
var _rack_sfx: AudioStreamPlayer
## 0.11: the inspect screen opened on the gun the player carries (F while drawn): no "Put back".
var inspect_carried := false
var _put_back: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toasts.position = Vector2(-300, 104)
	_toasts.size = Vector2(600, 10)
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.add_theme_constant_override("separation", 8)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)
	_build_dialogue()
	_rack_sfx = AudioStreamPlayer.new()
	_rack_sfx.name = "InspectSfx"
	add_child(_rack_sfx)

# ---------------------------------------------------------------- notifications

func notify(text: String, seconds := 3.6) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.06, .045, .03, .86)
	style.border_color = Color(.78, .62, .36, .9)
	style.border_width_left = 3
	style.set_corner_radius_all(6)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 21)
	label.add_theme_color_override("font_color", Color(.98, .92, .8))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	_toasts.add_child(panel)
	panel.modulate.a = 0.0
	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, .25)
	tween.tween_interval(seconds)
	tween.tween_property(panel, "modulate:a", 0.0, .6)
	tween.tween_callback(panel.queue_free)

func last_notification() -> String:
	var count := _toasts.get_child_count()
	if count == 0:
		return ""
	return ((_toasts.get_child(count - 1) as PanelContainer).get_child(0) as Label).text

# ---------------------------------------------------------------- dialogue

func _build_dialogue() -> void:
	_dialogue = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.035, .03, .025, .9)
	style.border_color = Color(.5, .4, .28, .9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	_dialogue.add_theme_stylebox_override("panel", style)
	_dialogue.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_dialogue.position = Vector2(-390, -290)
	_dialogue.size = Vector2(780, 150)
	_dialogue.custom_minimum_size = Vector2(780, 150)
	_dialogue.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialogue.gui_input.connect(func(event: InputEvent):
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
			advance())
	add_child(_dialogue)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue.add_child(box)
	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", 18)
	_speaker.add_theme_color_override("font_color", Color(.85, .68, .42))
	box.add_child(_speaker)
	_line = Label.new()
	_line.add_theme_font_size_override("font_size", 25)
	_line.add_theme_color_override("font_color", Color(.97, .93, .86))
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size.y = 64
	box.add_child(_line)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(.7, .64, .55))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_hint)
	_dialogue.hide()

## Shows `lines` one at a time (typed out). E, a click or a tap goes on; each line also moves on by itself
## after `auto` seconds once fully shown (0 = wait for the player).
func say(speaker: String, lines: Array, auto := 7.0) -> void:
	_speaker.text = speaker
	_lines = lines
	_line_index = -1
	_auto_advance = auto
	_dialogue.show()
	_next_line()

func dialogue_active() -> bool:
	return _dialogue.visible

func current_speaker() -> String:
	return _speaker.text

func current_line() -> String:
	return str(_lines[_line_index]) if _line_index >= 0 and _line_index < _lines.size() else ""

func advance() -> void:
	if not _dialogue.visible:
		return
	var full := str(_lines[_line_index])
	if int(_shown_chars) < full.length():
		_shown_chars = full.length()
		_line.visible_characters = -1
		return
	_next_line()

func _next_line() -> void:
	_line_index += 1
	if _line_index >= _lines.size():
		_dialogue.hide()
		dialogue_finished.emit()
		return
	_line.text = str(_lines[_line_index])
	# 0.60: spoken too, when the line has a clip (scripts/voice_lines.gd).
	InteriorVoiceLines.forget()
	InteriorVoiceLines.speak(self, _speaker.text, _line.text)
	_line.visible_characters = 0
	_shown_chars = 0.0
	_line_time = 0.0
	_hint.text = ("Tap to continue" if mobile else "E / click to continue")

# ---------------------------------------------------------------- inspect

func inspect_active() -> bool:
	return _inspect != null and _inspect.visible

func open_inspect(carried := false) -> void:
	if _inspect == null:
		_build_inspect()
	inspect_carried = carried
	_put_back.visible = not carried
	_yaw = -.55
	_pitch = .18
	_spin_velocity = 0.0
	if _gun_anim != null:
		_gun_anim.stop()
		_gun_anim.seek(0.0, true)
	_inspect.show()
	_toasts.visible = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_inspect(taken: bool) -> void:
	if _inspect == null or not _inspect.visible:
		return
	_inspect.hide()
	_toasts.visible = true
	for toast in _toasts.get_children():
		toast.queue_free()
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	inspect_closed.emit(taken)

func _build_inspect() -> void:
	_inspect = Control.new()
	_inspect.name = "Inspect"
	_inspect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inspect.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_inspect)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, .72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspect.add_child(shade)
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.gui_input.connect(_on_inspect_input)
	_inspect.add_child(container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X if not mobile else Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	container.add_child(_viewport)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.55, .52, .5)
	env.ambient_light_energy = .18
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	_viewport.add_child(world)
	var camera := Camera3D.new()
	camera.fov = 28.0
	camera.position = Vector3(0, 0, .52)
	camera.near = .01
	_viewport.add_child(camera)
	# Gentle light: the gun is black polymer and dark steel, and should read as black, with a cool rim on its edges.
	for spec in [[Vector3(-.5, .8, .35), Color(1.0, .95, .88), .5], [Vector3(.6, .3, -.6), Color(.65, .75, 1.0), .4], [Vector3(.1, -.6, .4), Color(1, 1, 1), .1]]:
		var light := DirectionalLight3D.new()
		light.light_color = spec[1]
		# The Compatibility renderer (Android) lights it brighter: tone it down so it still reads as black.
		light.light_energy = float(spec[2]) * (.55 if mobile else 1.0)
		_viewport.add_child(light)
		light.look_at_from_position(Vector3.ZERO, -(spec[0] as Vector3), Vector3.UP)
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	_gun = GLOCK.instantiate() as Node3D
	_pivot.add_child(_gun)
	# Centre it: the model is about 0.19 m long along Z; turn it side-on to the camera.
	_gun.rotation = Vector3(0, -PI * .5, 0)
	var box := InteriorModelKit.local_bounds(_gun)
	_gun.position = -(_gun.transform * box).get_center()
	_gun_anim = _gun.find_child("AnimationPlayer", true, false) as AnimationPlayer
	# Labels and buttons.
	var title := Label.new()
	title.text = "Glock 17"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(.97, .92, .82))
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-200, 48)
	title.size = Vector2(400, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspect.add_child(title)
	var hint := Label.new()
	hint.text = "Drag to rotate" + ("" if mobile else "  •  Esc to put it back")
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(.75, .7, .62))
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	hint.position = Vector2(-250, 100)
	hint.size = Vector2(500, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspect.add_child(hint)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	row.position = Vector2(-330, -110)
	row.size = Vector2(660, 56)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	_inspect.add_child(row)
	var buttons := [["Put back", func(): close_inspect(false)], ["Rack the slide", _rack], ["OK", func(): close_inspect(true)]]
	for spec in buttons:
		var button := Button.new()
		button.text = spec[0]
		button.custom_minimum_size = Vector2(170 if spec[0] != "OK" else 150, 54)
		button.pressed.connect(spec[1])
		button.name = String(spec[0]).replace(" ", "")
		row.add_child(button)
		if spec[0] == "Put back":
			_put_back = button

## Plays the model's own firing-cycle animation slowed down: the trigger, the slide snapping back, a round out.
func _rack() -> void:
	if _gun_anim == null or _gun_anim.get_animation_list().is_empty():
		return
	var clip: String = "fire" if _gun_anim.has_animation("fire") else _gun_anim.get_animation_list()[0]
	_gun_anim.stop()
	_gun_anim.play(clip, -1, .3)
	if ResourceLoader.exists("res://assets/audio/sfx/gun_pickup.ogg"):
		_rack_sfx.stream = load("res://assets/audio/sfx/gun_pickup.ogg")
		_rack_sfx.pitch_scale = 1.25
		_rack_sfx.play()

func _on_inspect_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_dragging = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		_dragging = event.pressed
	var motion := Vector2.ZERO
	if event is InputEventMouseMotion and (_dragging or (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0):
		motion = event.relative
	elif event is InputEventScreenDrag:
		motion = event.relative
	if motion != Vector2.ZERO:
		_yaw += motion.x * .009
		_pitch = clampf(_pitch + motion.y * .007, -1.2, 1.2)
		_spin_velocity = motion.x * .009 / maxf(get_process_delta_time(), .001)

func rotate_view(yaw_delta: float, pitch_delta: float) -> void:
	_yaw += yaw_delta
	_pitch = clampf(_pitch + pitch_delta, -1.2, 1.2)

func _unhandled_input(event: InputEvent) -> void:
	if inspect_active() and (event.is_action_pressed("pause") or (inspect_carried and event.is_action_pressed("inspect"))):
		close_inspect(inspect_carried)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if _dialogue.visible and _line_index >= 0 and _line_index < _lines.size():
		var full := str(_lines[_line_index])
		_shown_chars = minf(full.length(), _shown_chars + delta * 38.0)
		_line.visible_characters = int(_shown_chars) if int(_shown_chars) < full.length() else -1
		if int(_shown_chars) >= full.length():
			_line_time += delta
			if _auto_advance > 0.0 and _line_time > _auto_advance:
				_next_line()
	if inspect_active() and _pivot != null:
		if not _dragging:
			_yaw += _spin_velocity * delta
			_spin_velocity = move_toward(_spin_velocity, 0.0, delta * 6.0)
		_pivot.rotation = Vector3(_pitch, _yaw, 0)
