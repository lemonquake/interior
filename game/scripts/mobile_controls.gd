class_name InteriorTouchControls
extends Control

signal hold_pressed
signal throw_pressed
signal pause_pressed
signal inspect_pressed
var player: InteriorPlayer
var enabled := false
var move_finger := -1
var look_finger := -1
var origin := Vector2.ZERO
var knob := Vector2.ZERO
var radius := 68.0
var _buttons: Array[Button] = []
var _button_fingers: Dictionary[int, Button] = {}
var _sprint_button: Button
var _crouch_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button("Hold / Drop", Vector2(-205, -110), hold_pressed.emit)
	_button("Throw", Vector2(-205, -192), throw_pressed.emit)
	_button("Inspect", Vector2(-205, -274), inspect_pressed.emit)
	_button("Pause", Vector2(-120, 20), pause_pressed.emit, true)
	_button("Jump", Vector2(-405, -110), _jump_pressed)
	_crouch_button = _button("Crouch", Vector2(-405, -192), _crouch_pressed)
	_crouch_button.toggle_mode = true
	_sprint_button = _button("Sprint", Vector2(-405, -274), _sprint_pressed)
	_sprint_button.toggle_mode = true

func _button(text: String, offset: Vector2, action: Callable, top := false) -> Button:
	var b := Button.new()
	b.text = text
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 0.0 if top else 1.0
	b.anchor_bottom = b.anchor_top
	b.position = offset
	b.size = Vector2(185, 64) if not top else Vector2(100, 52)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(action)
	b.focus_mode = Control.FOCUS_NONE
	# Handle every touch finger directly; ordinary mouse emulation uses one finger.
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(b)
	_buttons.append(b)
	return b

func _jump_pressed() -> void:
	if player != null:
		player.request_jump()

func _crouch_pressed() -> void:
	if player != null:
		player.touch_crouching = not player.touch_crouching
		_crouch_button.button_pressed = player.touch_crouching
		_crouch_button.text = "Stand" if player.touch_crouching else "Crouch"

func _sprint_pressed() -> void:
	if player != null:
		player.touch_sprinting = true
		_sprint_button.button_pressed = true

func set_enabled(value: bool) -> void:
	enabled = value
	visible = value
	move_finger = -1
	look_finger = -1
	_button_fingers.clear()
	if _sprint_button != null:
		_sprint_button.button_pressed = false
	if _crouch_button != null:
		_crouch_button.button_pressed = false
		_crouch_button.text = "Crouch"
	if player != null:
		player.touch_move = Vector2.ZERO
		player.touch_sprinting = false
		player.touch_crouching = false
	queue_redraw()

func _over_button(point: Vector2) -> bool:
	for b in _buttons:
		if b.get_global_rect().grow(12.0).has_point(point):
			return true
	return false

func _input(event: InputEvent) -> void:
	if not enabled or player == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _over_button(event.position):
				for button in _buttons:
					if button.get_global_rect().has_point(event.position):
						_button_fingers[event.index] = button
						button.pressed.emit()
						get_viewport().set_input_as_handled()
						break
				return
			if event.position.x < size.x * 0.45 and move_finger == -1:
				move_finger = event.index
				origin = event.position
				knob = origin
			elif event.position.x >= size.x * 0.45 and look_finger == -1:
				look_finger = event.index
		else:
			if _button_fingers.has(event.index):
				var was_sprinting := _button_fingers[event.index] == _sprint_button
				_button_fingers.erase(event.index)
				if was_sprinting:
					player.touch_sprinting = _button_fingers.values().has(_sprint_button)
					_sprint_button.button_pressed = player.touch_sprinting
			if event.index == move_finger:
				move_finger = -1
				player.touch_move = Vector2.ZERO
			if event.index == look_finger:
				look_finger = -1
		queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index == move_finger:
			var offset: Vector2 = (event.position - origin).limit_length(radius)
			knob = origin + offset
			player.touch_move = offset / radius if offset.length() > 9.0 else Vector2.ZERO
			queue_redraw()
		elif event.index == look_finger:
			player.look(event.relative * 1.4)

func _draw() -> void:
	if not enabled:
		return
	var center := origin if move_finger != -1 else Vector2(110, size.y - 115)
	draw_circle(center, radius, Color(0.08, 0.06, 0.04, 0.45))
	draw_arc(center, radius, 0, TAU, 40, Color(0.92, 0.85, 0.73, 0.6), 2.0)
	draw_circle(knob if move_finger != -1 else center, 26, Color(0.85, 0.74, 0.57, 0.65))
