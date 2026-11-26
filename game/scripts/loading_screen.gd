class_name InteriorLoadingScreen
extends CanvasLayer
## 0.30: the loading screen. Black, with the title where the main menu has it, so the menu's street fades in
## under the same word. A thin bar, what is being done right now, and one line about the controls.
##
## 0.35 had the home menu's buttons on this screen from the first frame. 0.57 (owner: "the loading screen should
## be at center, not letting the player do anything yet unless everything is loaded, then show the main menu items
## after loading"): the title, the bar, what is being done and a tip sit in the middle of the screen, every key and
## click is swallowed while the world goes up, and only when it stands does the screen fade to the real menu.
## (`InteriorLoadClock.wish` / `press` stay for test runs: `--early-wish=play:ready` still clicks Play once the menu
## is there.)
##
## The bar has two halves: reading the files (driven by scripts/boot.gd: `set_files`) and building the world
## (driven by InteriorLoadClock.mark -> `stage`, using the share of the build each step took when
## tools/boot_manifest.py last measured it).

const FILES_SHARE := .42
const INK := Color(.91, .92, .86)
const DIM := Color(.96, .90, .79, .62)
const STILL := "res://assets/ui/menu_still.jpg"
const TIPS := [
	"Hold E on a door, a gate or a chair to pull it.",
	"G puts the gun away. Nothing else does.",
	"Right mouse button brings the sights up.",
	"L switches the flashlight on and off.",
	"C crouches. Some gaps are only that tall.",
	"Esc pauses. Graphics and frame rate are under Options.",
]
## 0.64: the same tips on a phone, by its touch buttons' names.
const PHONE_TIPS := [
	"Keep holding USE on a door, a gate or a chair to pull it.",
	"HOLSTER puts the gun away. Nothing else does.",
	"ADS brings the sights up.",
	"LIGHT switches the flashlight on and off.",
	"CROUCH gets you low. Some gaps are only that tall.",
	"PAUSE stops the game. Graphics are under Options.",
]

static func tips() -> Array:
	return PHONE_TIPS if OS.has_feature("android") or "--mobile-test" in OS.get_cmdline_user_args() else TIPS
## What the player reads while each part of the world is put together (label prefix -> caption).
const CAPTIONS := [
	["boot: engine", "Opening the files"],
	["boot: files", "Laying out the rooms"],
	["boot: inst", "Laying out the rooms"],
	["neighbourhood: start", "Standing the street up"],
	["neighbourhood: model", "Standing the street up"],
	["neighbourhood: decay", "Letting the town go to ruin"],
	["neighbourhood: seals", "Closing the gaps"],
	["neighbourhood", "Closing the gaps"],
	["interior: living", "Furnishing the room"],
	["interior: player", "Furnishing the room"],
	["interior: ui", "Tuning the night"],
	["interior: stranger", "Someone is at the gate"],
	["interior: hut", "Lighting the hut lantern"],
	["interior", "Tuning the night"],
	["deferred", "Hanging the gates"],
]

var shares: Dictionary = {}
var _root: Control
var _fill: ColorRect
var _track: ColorRect
var _caption: Label
var _percent: Label
var _tip: Label
var _target := 0.0
var _shown := 0.0
var _files := 0.0
var _build := 0.0
var _time := 0.0
var _tip_index := 0
var _leaving := false
var _wished := false

func _init() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "LoadingScreen"

func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var black := ColorRect.new()
	black.color = Color(0, 0, 0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(black)
	if ResourceLoader.exists(STILL):
		var still := TextureRect.new()
		still.texture = load(STILL) as Texture2D
		still.set_anchors_preset(Control.PRESET_FULL_RECT)
		still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		still.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		still.mouse_filter = Control.MOUSE_FILTER_IGNORE
		still.modulate.a = 0.0
		_root.add_child(still)
		var arrive := create_tween()
		arrive.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		arrive.tween_property(still, "modulate:a", 1.0, .45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		# 0.57: the street is shaded under the centred words, so they read over its lamps.
		var shade := ColorRect.new()
		shade.color = Color(0, 0, 0, .5)
		shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(shade)
	# 0.57: one column in the middle of the screen: the title, the bar with its caption and percentage, a tip.
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(centre)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.custom_minimum_size.x = 520
	centre.add_child(column)
	# 0.54: the shared title block (scripts/ui_menu.gd), the same as the home menu's, centred.
	SleepMenu.title_block(column, INK)
	for child in column.get_children():
		if child is Label:
			(child as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if child is Control:
			(child as Control).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gap := Control.new()
	gap.custom_minimum_size.y = 26
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(gap)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	_caption = _text("Opening the files", 17, Color(.96, .90, .79))
	_caption.add_theme_font_override("font", SleepType.text(500, true))
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_caption)
	_percent = _text("0%", 17, DIM)
	_percent.add_theme_font_override("font", SleepType.mono())
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_percent)
	_track = ColorRect.new()
	_track.color = Color(.96, .90, .79, .14)
	_track.custom_minimum_size = Vector2(0, 3)
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.clip_contents = true
	column.add_child(_track)
	_fill = ColorRect.new()
	_fill.color = SleepType.SODIUM
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.add_child(_fill)
	_tip_index = int(Time.get_unix_time_from_system()) % tips().size()
	_tip = _text(tips()[_tip_index], 15, DIM)
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_tip)

## 0.57: nothing gets past this screen while the world goes up: no key, no click, no pad (Esc, the debug keys, a
## stray Enter on a menu that is not there yet). Test clicks (`click`) go straight to `press`.
func _input(event: InputEvent) -> void:
	if not _leaving:
		get_viewport().set_input_as_handled()

func _text(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## A wish for one of the menu's buttons (test runs only since 0.57). Quit leaves at once. Play and Options are
## carried out now if the world stands, and otherwise kept until it does.
func press(what: String) -> void:
	if what == "quit":
		get_tree().quit()
		return
	if _wished or not what in ["play", "multiplayer", "options"]:
		return
	_wished = true
	if InteriorLoadClock.wish_ready.is_valid():
		InteriorLoadClock.wish_ready.call(what)
	else:
		InteriorLoadClock.wish = what

## `-- --early-wish=play:3.0`: a real click on that button when the game has been running that many seconds, or
## `play:ready` for the frame after the world stands, while this screen is still up (timing and test runs: the
## click goes the way a mouse's does, through a paused tree with the world going up behind it). The clock is the
## wall's: a scene-tree timer loses time in every long frame of the build.
func click(what: String, at_second: String) -> void:
	if at_second.begins_with("ready"):
		while not InteriorLoadClock.wish_ready.is_valid():
			await get_tree().process_frame
		# `ready+0.3`: that long after it stands (this screen is fading by then).
		var until := Time.get_ticks_msec() + int(float(at_second.trim_prefix("ready")) * 1000.0)
		while Time.get_ticks_msec() < until:
			await get_tree().process_frame
	else:
		while Time.get_ticks_msec() < int(float(at_second) * 1000.0):
			await get_tree().process_frame
	await get_tree().process_frame
	InteriorLoadClock.mark("test: click on '%s'" % what)
	press(what)

## The boot scene moves this screen to the root when the world is added, and a node taken out of the tree loses
## the keyboard: Play has it again.
func refocus() -> void:
	pass

## Share of the files read so far (0..1), from the boot scene.
func set_files(fraction: float) -> void:
	_files = clampf(fraction, 0.0, 1.0)
	_retarget()

func set_caption(text: String) -> void:
	if _caption != null and _caption.text != text:
		_caption.text = text

## A start-up mark was passed (InteriorLoadClock.mark).
func stage(label: String) -> void:
	for pair: Array in CAPTIONS:
		if label.begins_with(pair[0]):
			set_caption(pair[1])
			break
	if shares.has(label):
		_build = maxf(_build, float(shares[label]))
	else:
		# A step the manifest has never seen still nudges the bar on.
		_build = minf(.98, _build + .004)
	_retarget()

func _retarget() -> void:
	var before := _target
	_target = maxf(_target, _files * FILES_SHARE + _build * (1.0 - FILES_SHARE))
	if _target > before + .0001:
		_moved_at = Time.get_ticks_msec()

## 0.43: when the bar has not moved for STUCK_MS, say so on the screen and where the log is, instead of leaving
## the player looking at a bar that never ends (a script that failed to load stops the world being built).
const STUCK_MS := 75000
var _moved_at := 0
var _stuck_shown := false

## 0.64: once the world stands ("boot: done") only the first frames' shaders are left to compile: slow on a phone's
## first run (over a minute on the 2 GB test phone) but never stuck, so the watchdog stands down. A phone also
## waits longer before it says anything (its log is not somewhere a player can reach).
var _world_done := false

## (load_clock.gd `finish`: the world stands.)
func world_done() -> void:
	_world_done = true

func _check_stuck() -> void:
	var limit := STUCK_MS * 3 if OS.has_feature("android") else STUCK_MS
	if _stuck_shown or _leaving or _world_done or _moved_at == 0 or Time.get_ticks_msec() - _moved_at < limit:
		return
	_stuck_shown = true
	var log_path := ProjectSettings.globalize_path("user://logs/godot.log")
	push_error("Loading made no progress for %d s at %d%%." % [STUCK_MS / 1000, int(_target * 100.0)])
	set_caption("Loading has stopped at %d%%. Please send this file to the developer:
%s" % [int(_target * 100.0), log_path])
	if _caption != null:
		_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_caption.add_theme_color_override("font_color", Color(1.0, .55, .45))

func _process(delta: float) -> void:
	if _fill == null:
		return
	# Building blocks the thread for a few hundred milliseconds at a time: never ease by more than one frame's worth.
	delta = minf(delta, .05)
	_time += delta
	_check_stuck()
	_shown = lerpf(_shown, _target, 1.0 - exp(-delta * 9.0))
	if _target - _shown < .002:
		_shown = _target
	var width := _track.size.x
	_fill.position = Vector2.ZERO
	_fill.size = Vector2(width * _shown, _track.size.y)
	_percent.text = "%d%%" % int(round(_shown * 100.0))
	if not _leaving and int(_time / 4.5) != int((_time - delta) / 4.5):
		_tip_index = (_tip_index + 1) % tips().size()
		_tip.text = tips()[_tip_index]

## The world stands: fill the bar, then fade to whatever is underneath (the main menu).
func finish() -> void:
	if _leaving:
		return
	_leaving = true
	_target = 1.0
	_shown = 1.0
	# From here a click lands on the real menu underneath, fading in as this screen goes.
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(.12)
	tween.tween_property(_root, "modulate:a", 0.0, .5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(queue_free)

## `-- --capture-loading --capture-path=<directory>`: saves this screen at a few points of its bar.
func capture(directory: String) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var shot := 0
	var last := -1.0
	while not _leaving:
		await RenderingServer.frame_post_draw
		if _shown - last >= .2:
			last = _shown
			shot += 1
			get_viewport().get_texture().get_image().save_png("%s/loading-%02d.png" % [directory, shot])
