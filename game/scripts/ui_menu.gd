class_name SleepMenu
extends RefCounted
## 0.54: what the home menu, the loading screen (which is the home menu until the world stands) and the windows
## share: the title block, the menu's buttons, and the cursor, which is a flashlight.
##
## The cursor: whichever button is under the mouse (or has the keyboard's focus) is lit by a warm pool of light
## with the rings of a cheap reflector in it (the same light Heavy-arm's flashlight throws), drifting after the
## choice like a hand-held light and never quite still. It is added over the buttons (additive, like light), so the
## words it falls on warm up too.

const POOL := preload("res://assets/coop/heavyarm/menu_pool.png")

## The title block: the title in the serif with blood running from it, the byline. `parent` is the menu's column.
## (0.57: the line above the title is gone: the owner never asked for it. No taglines or descriptions here unless the
## owner gives the words.)
static func title_block(parent: Container, ink: Color, size := 104) -> void:
	parent.add_child(InteriorBloodTitle.make("Sleep", size, ink))
	var by := SleepType.label("by Aljay Leodones", SleepType.text(400, true), 19, Color(SleepType.BONE, .66))
	parent.add_child(by)

## A home-menu button (Play, Multiplayer, Options, Quit): the serif, left-aligned, no box; chosen, it steps right
## and a short sodium rule shows at its left.
static func home_button(button: Button, size := 33) -> void:
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(310, 42)
	button.add_theme_font_override("font", SleepType.serif())
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_color_override("font_color", Color(SleepType.BONE, .78))
	for c in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(c, Color(1.0, .96, .9))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.content_margin_left = 18
	var lit := normal.duplicate() as StyleBoxFlat
	lit.content_margin_left = 30
	lit.border_color = SleepType.SODIUM
	lit.border_width_left = 2
	lit.expand_margin_top = -12
	lit.expand_margin_bottom = -12
	var focus := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", lit)
	button.add_theme_stylebox_override("pressed", lit)
	button.add_theme_stylebox_override("hover_pressed", lit)
	button.add_theme_stylebox_override("focus", focus)

## A window's button (Resume, Ready, Leave game...): the serif on a dark bar, lit when chosen.
static func window_button(button: Button, size := 25) -> void:
	button.add_theme_font_override("font", SleepType.serif())
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_color_override("font_color", Color(SleepType.BONE, .84))
	for c in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(c, Color(1.0, .96, .9))
	button.add_theme_color_override("font_disabled_color", Color(SleepType.BONE, .35))

## The flashlight cursor over `host` (a Control covering the buttons' area: it is drawn over them).
static func light(host: Control) -> MenuLight:
	var l := MenuLight.new()
	host.add_child(l)
	return l

class MenuLight extends TextureRect:
	var _target: Control
	var _at := Vector2.INF
	var _shown := 0.0
	var _t := 0.0

	func _init() -> void:
		texture = POOL
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_SCALE
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = add
		modulate = Color(1.0, .78, .5, 0.0)
		process_mode = Node.PROCESS_MODE_ALWAYS
		z_index = 1
		top_level = true

	## Light whichever of `buttons` is chosen.
	func follow(buttons: Array) -> void:
		for b in buttons:
			if not (b is Button): continue
			var button := b as Button
			button.mouse_entered.connect(_pick.bind(button))
			button.focus_entered.connect(_pick.bind(button))
			button.mouse_exited.connect(_drop.bind(button))
			button.tree_exiting.connect(_gone.bind(button))
			if button.has_focus(): _target = button

	func _pick(button: Control) -> void:
		_target = button

	func _drop(button: Control) -> void:
		if _target == button and not button.has_focus(): _target = null

	func _gone(button: Control) -> void:
		if _target == button: _target = null

	func _process(delta: float) -> void:
		_t += delta
		var on := _target != null and is_instance_valid(_target) and _target.is_visible_in_tree() and not (_target as Button).disabled
		_shown = move_toward(_shown, 1.0 if on else 0.0, delta * (5.0 if on else 3.0))
		if on:
			var r := _target.get_global_rect()
			var centred := (_target as Button).alignment == HORIZONTAL_ALIGNMENT_CENTER
			var want := Vector2(r.get_center().x if centred else r.position.x + minf(r.size.x * .3, 120.0), r.get_center().y)
			if not _at.is_finite(): _at = want
			# A hand-held light: it drifts after the choice and never quite stops.
			_at = _at.lerp(want, 1.0 - exp(-11.0 * delta))
			var sway := Vector2(sin(_t * 1.7) * 3.0 + sin(_t * 4.3) * 1.2, cos(_t * 1.3) * 1.6)
			var s := Vector2(maxf(r.size.y * 6.4, 260.0), maxf(r.size.y * 2.3, 96.0))
			size = s
			global_position = _at + sway - s * .5
		var flicker := .94 + .06 * sin(_t * 23.0) * sin(_t * 7.1)
		modulate.a = _shown * .42 * flicker
		visible = _shown > .01
