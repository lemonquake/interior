class_name InteriorTouchControls
extends Control
## The phone's controls (0.64: laid out the way a phone shooter is played; before this they were rows of text boxes).
##
## Left thumb: a stick that appears where the thumb lands. Pushed all the way forward it sprints; barely pushed it is
## the quiet walk. Right thumb: drag anywhere free to look. FIRE is the big round button under the right thumb, and the
## thumb on it still aims: drag it while it fires (an automatic weapon keeps firing while it is held). A second FIRE
## sits on the left for two-thumb play. Round buttons around FIRE: ADS (raise the sights), RELOAD, JUMP, CROUCH, SHOVE
## and, in the squad game, GRENADE (hold, let go to throw). USE (the E of a keyboard: hold, drop, open, pull, help a
## teammate up) and INSPECT only show when there is something for them. The weapon row is at the top centre (GUN to draw
## or put it away, SWAP to the next weapon, MEDKIT and DROP in the squad game); PAUSE, LIGHT and CHAT top right.
## Everything is round and see-through, so the picture stays clear.

signal hold_pressed
## The USE finger lifted (0.7): ends a hold-to-pull.
signal hold_released
signal throw_pressed
signal pause_pressed
signal inspect_pressed
## 0.11: the Glock (scripts/gun.gd): GUN draws / holsters once it is owned; RELOAD while it is drawn.
signal gun_pressed
signal reload_pressed
## 0.12: LIGHT switches the flashlight on and off once it is owned (scripts/flashlight.gd).
signal light_pressed
## 0.34: Shove (V). Lean and Bind set the player's own touch flags.
signal shove_pressed
## 0.64: FIRE held keeps the trigger down; ADS raises the sights (until tapped again); SWAP brings up the next weapon.
signal fire_held(on: bool)
signal aim_pressed
signal swap_pressed

const INK := Color(.95, .91, .84, .93)
const FILL := Color(.05, .04, .035, .38)
const EDGE := Color(.93, .87, .76, .5)
const LIT := Color(.56, .16, .1, .58)
const LIT_EDGE := Color(1.0, .9, .78, .85)
const FIRE_FILL := Color(.34, .05, .04, .42)
## Share of the screen's width (from the left) where a thumb grabs the stick.
const STICK_SIDE := .42
## Stick pushed this far, mostly forward: sprint. Under QUIET: the quiet walk.
const SPRINT_AT := .94
const QUIET := .42

var player: InteriorPlayer
## The game (interior.gd): which buttons apply is read from it a few times a second.
var main: Node
var enabled := false
var move_finger := -1
var look_finger := -1
var origin := Vector2.ZERO
var knob := Vector2.ZERO
var radius := 74.0
var _buttons: Array[Button] = []
var _button_fingers: Dictionary[int, Button] = {}
## Buttons that keep their own lit state (toggles); the rest light only while a finger is on them.
var _toggles: Array[Button] = []
## Buttons that act for as long as the finger stays down: what runs when it lifts.
var _on_lift: Dictionary = {}
## FIRE fingers also look while they are down.
var _aiming_buttons: Array[Button] = []
var _state_t := 0.0
var _sprinting_by_stick := false
var _hold_button: Button
var _crouch_button: Button
var _throw_button: Button
var _fire_left: Button
var _gun_button: Button
var _reload_button: Button
var _light_button: Button
var _shove_button: Button
var _bind_button: Button
var _inspect_button: Button
var _jump_button: Button
var _pause_button: Button
var _lean_left: Button
var _lean_right: Button
var _aim_button: Button
var _swap_button: Button
var _grenade_button: Button
var _kit_button: Button
var _drop_button: Button
var _chat_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var br := Vector2(1, 1)
	_throw_button = _round("THROW", br, Vector2(-190, -215), 132, throw_pressed.emit, true)
	_aiming_buttons.append(_throw_button)
	_on_lift[_throw_button] = func(): fire_held.emit(false)
	_aim_button = _round("ADS", br, Vector2(-342, -300), 86, aim_pressed.emit)
	_toggles.append(_aim_button)
	_reload_button = _round("RELOAD", br, Vector2(-80, -338), 76, reload_pressed.emit)
	_jump_button = _round("JUMP", br, Vector2(-78, -92), 92, _jump_pressed)
	_crouch_button = _round("CROUCH", br, Vector2(-208, -70), 78, _crouch_pressed)
	_toggles.append(_crouch_button)
	_shove_button = _round("SHOVE", br, Vector2(-342, -150), 74, shove_pressed.emit)
	_grenade_button = _round("GRENADE", br, Vector2(-215, -375), 74, func(): send_action("grenade", true))
	_on_lift[_grenade_button] = func(): send_action("grenade", false)
	_hold_button = _round("USE", br, Vector2(-478, -228), 90, hold_pressed.emit)
	_on_lift[_hold_button] = func(): hold_released.emit()
	_inspect_button = _round("INSPECT", br, Vector2(-478, -350), 70, inspect_pressed.emit)
	_bind_button = _round("BIND", br, Vector2(-478, -108), 74, _bind_pressed)
	_on_lift[_bind_button] = func(): _bind_lifted()
	var bl := Vector2(0, 1)
	_fire_left = _round("FIRE", bl, Vector2(150, -365), 98, throw_pressed.emit, true)
	_aiming_buttons.append(_fire_left)
	_on_lift[_fire_left] = func(): fire_held.emit(false)
	_lean_left = _round("< LEAN", bl, Vector2(62, -482), 66, _lean_pressed.bind(-1.0))
	_lean_right = _round("LEAN >", bl, Vector2(142, -482), 66, _lean_pressed.bind(1.0))
	_on_lift[_lean_left] = func(): _lean_lifted()
	_on_lift[_lean_right] = func(): _lean_lifted()
	var tc := Vector2(.5, 0)
	_gun_button = _pill("GUN", tc, Vector2(-180, 40), Vector2(112, 46), gun_pressed.emit)
	_swap_button = _pill("SWAP", tc, Vector2(-60, 40), Vector2(112, 46), swap_pressed.emit)
	_kit_button = _pill("MEDKIT", tc, Vector2(60, 40), Vector2(112, 46), func(): send_key(KEY_F, true))
	_on_lift[_kit_button] = func(): send_key(KEY_F, false)
	_drop_button = _pill("DROP", tc, Vector2(180, 40), Vector2(112, 46), func(): send_key(KEY_G, true))
	_on_lift[_drop_button] = func(): send_key(KEY_G, false)
	var tr := Vector2(1, 0)
	_pause_button = _round("PAUSE", tr, Vector2(-60, 48), 66, pause_pressed.emit)
	_light_button = _round("LIGHT", tr, Vector2(-140, 48), 66, light_pressed.emit)
	_toggles.append(_light_button)
	_chat_button = _round("CHAT", tr, Vector2(-220, 48), 66, func():
		send_key(KEY_ENTER, true)
		send_key(KEY_ENTER, false))
	for b: Button in [_aim_button, _reload_button, _gun_button, _swap_button, _grenade_button, _kit_button,
			_drop_button, _chat_button, _light_button, _bind_button, _inspect_button, _fire_left, _hold_button]:
		b.visible = false
	set_gun_state(false, false)
	set_light_state(false, false)

## A key as if typed on a keyboard (the squad game reads F, G, T and Enter as keys).
static func send_key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)

static func send_action(action: String, down: bool) -> void:
	if not InputMap.has_action(action):
		return
	var e := InputEventAction.new()
	e.action = action
	e.pressed = down
	Input.parse_input_event(e)

# ---------------------------------------------------------------- the buttons

func _style(fill: Color, edge: Color, width: int, round_px: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(width)
	s.set_corner_radius_all(round_px)
	s.anti_aliasing = true
	return s

## A round button of `diameter` centred `at` from the `anchor` corner (0..1 of the screen each way).
func _round(text: String, anchor: Vector2, at: Vector2, diameter: float, action: Callable, fire := false) -> Button:
	return _make(text, anchor, at, Vector2(diameter, diameter), action, fire)

## A rounded pill (the weapon row).
func _pill(text: String, anchor: Vector2, at: Vector2, size_px: Vector2, action: Callable) -> Button:
	return _make(text, anchor, at, size_px, action, false)

func _make(text: String, anchor: Vector2, at: Vector2, size_px: Vector2, action: Callable, fire: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.anchor_left = anchor.x
	b.anchor_right = anchor.x
	b.anchor_top = anchor.y
	b.anchor_bottom = anchor.y
	b.offset_left = at.x - size_px.x * .5
	b.offset_right = at.x + size_px.x * .5
	b.offset_top = at.y - size_px.y * .5
	b.offset_bottom = at.y + size_px.y * .5
	var round_px := int(minf(size_px.x, size_px.y) * .5)
	var normal := _style(FIRE_FILL if fire else FILL, EDGE, 3 if fire else 2, round_px)
	var lit := _style(LIT, LIT_EDGE, 3 if fire else 2, round_px)
	for state: String in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, normal)
	for state: String in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, lit)
	var smallest := minf(size_px.x, size_px.y)
	b.add_theme_font_size_override("font_size", 21 if smallest >= 120 else (15 if smallest >= 80 else 13))
	for state: String in ["font_color", "font_pressed_color", "font_hover_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, INK)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, .7))
	b.add_theme_constant_override("outline_size", 3)
	b.toggle_mode = true
	b.clip_text = false
	b.pressed.connect(action)
	b.focus_mode = Control.FOCUS_NONE
	# Handle every touch finger directly; ordinary mouse emulation uses one finger.
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(b)
	_buttons.append(b)
	return b

func _bind_pressed() -> void:
	if player != null:
		player.touch_binding = true

func _bind_lifted() -> void:
	if player != null:
		player.touch_binding = _button_fingers.values().has(_bind_button)

func _lean_pressed(side: float) -> void:
	if player != null:
		player.touch_peek = side

func _lean_lifted() -> void:
	if player == null:
		return
	var still: Array = _button_fingers.values()
	player.touch_peek = -1.0 if still.has(_lean_left) else (1.0 if still.has(_lean_right) else 0.0)

## BIND shows only while there is a wound to bind (scripts/body.gd).
func set_wound_state(open: bool) -> void:
	if _bind_button == null or _bind_button.visible == open:
		return
	_bind_button.visible = open
	if not open and player != null:
		player.touch_binding = false

## GUN shows once a weapon is owned; while it is drawn THROW becomes FIRE, and RELOAD, ADS and the left FIRE appear.
func set_gun_state(owned: bool, drawn: bool) -> void:
	if _gun_button == null:
		return
	_gun_button.visible = owned
	_gun_button.text = "HOLSTER" if drawn else "GUN"
	_gun_button.button_pressed = drawn
	_reload_button.visible = drawn
	_aim_button.visible = drawn
	_fire_left.visible = drawn
	_throw_button.text = "FIRE" if drawn else "THROW"
	if not drawn:
		set_aim(false)

func set_aim(on: bool) -> void:
	if _aim_button != null:
		_aim_button.button_pressed = on

func set_light_state(owned: bool, on: bool) -> void:
	if _light_button == null:
		return
	_light_button.visible = owned
	_light_button.button_pressed = on

func _jump_pressed() -> void:
	if player != null:
		player.request_jump()

func _crouch_pressed() -> void:
	if player != null:
		player.touch_crouching = not player.touch_crouching
		_crouch_button.button_pressed = player.touch_crouching
		_crouch_button.text = "STAND" if player.touch_crouching else "CROUCH"

func set_enabled(value: bool) -> void:
	# Whatever was being held is let go (a menu or a lost focus ends the touch with no lift).
	for finger: int in _button_fingers:
		var b: Button = _button_fingers[finger]
		if _on_lift.has(b):
			(_on_lift[b] as Callable).call()
		if not b in _toggles:
			b.button_pressed = false
	enabled = value
	visible = value
	move_finger = -1
	look_finger = -1
	_button_fingers.clear()
	_sprinting_by_stick = false
	if _crouch_button != null:
		_crouch_button.button_pressed = false
		_crouch_button.text = "CROUCH"
	if player != null:
		player.touch_move = Vector2.ZERO
		player.touch_sprinting = false
		player.touch_crouching = false
		player.touch_sneaking = false
		player.touch_binding = false
		player.touch_peek = 0.0
	queue_redraw()

## The buttons that depend on the moment, a few times a second.
func _process(delta: float) -> void:
	if not enabled or main == null:
		return
	_state_t -= delta
	if _state_t > 0.0:
		return
	_state_t = .2
	var coop: Node = main.get("coop")
	var squad: bool = coop != null and bool(coop.get("active"))
	var gun: Node = main.story.gun if main.get("story") != null else null
	var carried := 0
	if gun != null:
		for w: String in ["pistol", "rifle", "shotgun", "sniper"]:
			carried += 1 if gun.has_weapon(w) else 0
	_swap_button.visible = carried > 1
	_grenade_button.visible = squad
	_kit_button.visible = squad
	_drop_button.visible = squad
	_chat_button.visible = squad and coop.has_method("humans") and int(coop.humans()) > 1
	# USE and INSPECT: only when there is something to use or look at (the prompt says so), or something is held.
	var prompt: Label = main.get("prompt")
	var said := prompt.text if prompt != null and prompt.is_visible_in_tree() else ""
	var holding := player != null and is_instance_valid(player.get("held"))
	_hold_button.visible = said != "" or holding or _button_fingers.values().has(_hold_button)
	_inspect_button.visible = said.contains("Inspect") or _button_fingers.values().has(_inspect_button)

func _over_button(point: Vector2) -> Button:
	var best: Button = null
	var best_d := INF
	for b in _buttons:
		if not b.visible:
			continue
		var r := b.get_global_rect()
		# A round button takes a touch a little outside its edge, the nearest one when two are close.
		var centre := r.get_center()
		var reach := minf(r.size.x, r.size.y) * .5 + 10.0
		var d := point.distance_to(centre)
		if r.size.x > r.size.y * 1.4:
			d = 0.0 if r.grow(8.0).has_point(point) else INF
		if d <= reach and d < best_d:
			best = b
			best_d = d
	return best

func _input(event: InputEvent) -> void:
	if not enabled or player == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var b := _over_button(event.position)
			if b != null:
				_button_fingers[event.index] = b
				if not b in _toggles:
					b.button_pressed = true
				b.pressed.emit()
				if b in _aiming_buttons:
					fire_held.emit(true)
				get_viewport().set_input_as_handled()
				return
			if event.position.x < size.x * STICK_SIDE and move_finger == -1:
				move_finger = event.index
				origin = event.position
				knob = origin
			elif event.position.x >= size.x * STICK_SIDE and look_finger == -1:
				look_finger = event.index
		else:
			if _button_fingers.has(event.index):
				var lifted := _button_fingers[event.index]
				_button_fingers.erase(event.index)
				var still_down := _button_fingers.values().has(lifted)
				if not still_down:
					if not lifted in _toggles:
						lifted.button_pressed = false
					if _on_lift.has(lifted):
						(_on_lift[lifted] as Callable).call()
			if event.index == move_finger:
				move_finger = -1
				player.touch_move = Vector2.ZERO
				player.touch_sneaking = false
				if _sprinting_by_stick:
					_sprinting_by_stick = false
					player.touch_sprinting = false
			if event.index == look_finger:
				look_finger = -1
		queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index == move_finger:
			var offset: Vector2 = (event.position - origin).limit_length(radius)
			knob = origin + offset
			var push := offset.length() / radius
			player.touch_move = offset / radius if offset.length() > 9.0 else Vector2.ZERO
			# All the way forward: sprint. Barely pushed: the quiet walk.
			var sprint := push >= SPRINT_AT and offset.y < -radius * .7
			if sprint != _sprinting_by_stick:
				_sprinting_by_stick = sprint
				player.touch_sprinting = sprint
			player.touch_sneaking = push > .12 and push < QUIET
			queue_redraw()
		elif event.index == look_finger:
			player.look(event.relative * 1.4)
		elif _button_fingers.has(event.index) and _button_fingers[event.index] in _aiming_buttons:
			# The thumb on FIRE aims while it fires.
			player.look(event.relative * 1.4)

func _draw() -> void:
	if not enabled:
		return
	var center := origin if move_finger != -1 else Vector2(130, size.y - 130)
	draw_circle(center, radius, Color(0.06, 0.05, 0.04, 0.32))
	draw_arc(center, radius, 0, TAU, 48, Color(0.93, 0.87, 0.76, 0.5), 2.0, true)
	# The sprint mark above the ring: lit while the stick is pushed all the way forward.
	var tip := center + Vector2(0, -radius - 16)
	var lit := Color(1.0, .75, .55, .95) if _sprinting_by_stick else Color(.93, .87, .76, .45)
	draw_polyline(PackedVector2Array([tip + Vector2(-12, 7), tip, tip + Vector2(12, 7)]), lit, 3.0, true)
	draw_polyline(PackedVector2Array([tip + Vector2(-12, 15), tip + Vector2(0, 8), tip + Vector2(12, 15)]), lit, 3.0, true)
	draw_circle(knob if move_finger != -1 else center, 30, Color(0.88, 0.8, 0.66, 0.6))
