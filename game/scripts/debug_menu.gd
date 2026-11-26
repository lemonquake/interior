class_name InteriorDebugMenu
extends CanvasLayer
## 0.20: the debug menu. Type Q W E R T Y in order (each key within 2 s of the last) while playing to open it; the
## same sequence, Esc or Close shuts it. The world keeps running behind it so lighting changes show live; the player
## stands still and the mouse is free until it closes.
##
## Items:    give the Glock, rounds (+17 / +60 / +200), fill the magazine, infinite ammo; the secret AR-15 (0.27:
##           summoned here only; 0.28: the pump shotgun, and "Arsenal" for all three with all the ammo); the flashlight, on/off, its
##           brightness and reach; the hut key; everything at once. Given items skip their hut scenes.
## Lighting: exposure (a camera multiplier), an ambient override, the moon's strength, a fill light that follows the
##           camera, street lamps on/off, fog on/off, reset.
## Player:   speed, noclip flight, field of view, time scale, the FPS counter, teleports.
## World:    open the hut drawer, start the alarm, restart; 0.28: spawn the infected (one ahead, 5 or 15 somewhere
##           in the neighbourhood), kill them, clear bodies and blood, make them ignore the player or harmless.
## Missions (co-op, 0.49): complete the objective, a command line (coop/mission.gd debug_command). 0.55: a jump to every
##           mission by chapter (everything before it finished as play leaves it: mission `_settle`; greyed when behind
##           the run) and a teleport to every known place for you or the whole squad (greyed when put away).
## Overrides that other systems also write (ambient, fog) are re-applied every frame while they are on.

const SEQUENCE := [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y]
const SEQUENCE_GAP := 2.0
## 0.30: a window in the middle of the screen, in logical pixels (the screen is 1280 x 720 of them).
const PANEL_WIDTH := 640.0
const PANEL_HEIGHT := 660.0
const C := preload("res://scripts/canal_settlement.gd")
const NICHOLS := preload("res://scripts/nichols_property.gd")
const W := preload("res://scripts/canal_warren.gd")

var main: Node
var player: InteriorPlayer
var story: InteriorStory
var open := false
var _progress := 0
var _last_key_time := -10.0
var _was_playing := false
var _panel: PanelContainer
var _info: Label
var _info_timer := 0.0
var _controls := {}
## Lighting state.
var _ambient_override := false
var _ambient_energy := 1.0
var _ambient_saved := -1.0
var _fog_off := false
var _fog_saved := {}
var _moon_scale := 1.0
var _moon_base := {}
var _fill: OmniLight3D
## 0.55: Player > Health > Invulnerable. Kept on while it is ticked (`_keep_god`): in single player the infected's
## director refuses every hurt (claws, falls, blasts) and the body stops bleeding; in co-op the host's session and mission
## refuse every hurt to anyone in the squad (infected, Heavy-arm, blasts, drums).
var god := false
var _attributes: CameraAttributesPractical

func setup(main_node: Node) -> void:
	main = main_node
	player = main.player
	story = main.story
	name = "DebugMenu"
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("debug_menu")
	_fill = OmniLight3D.new()
	_fill.name = "DebugFillLight"
	_fill.light_color = Color(1.0, .97, .92)
	_fill.omni_range = 18.0
	_fill.omni_attenuation = .8
	_fill.light_cull_mask = 0xFFFFF
	_fill.shadow_enabled = false
	_fill.visible = false
	main.add_child.call_deferred(_fill)
	_build()
	_panel.visible = false
	_fit.call_deferred()

# ---------------------------------------------------------------- opening

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: Key = (event as InputEventKey).physical_keycode
	if open and key == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
		return
	# (Q W E R T Y itself is read in `_poll_sequence`: in a co-op game T is the shove and is taken before it gets
	# here, which is why the menu never opened in multiplayer. Any other key breaks the sequence.)
	if not key in SEQUENCE:
		_progress = 0

## 0.49: the six keys read from the keyboard itself every frame, whoever handles the key events.
var _held := {}
func _poll_sequence() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	var typing := focus is LineEdit or focus is TextEdit
	for key: Key in SEQUENCE:
		var down := Input.is_physical_key_pressed(key)
		if down and not bool(_held.get(key, false)) and not typing:
			_sequence_key(key)
		_held[key] = down

func _sequence_key(key: Key) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_key_time > SEQUENCE_GAP:
		_progress = 0
	_last_key_time = now
	if key == SEQUENCE[_progress]:
		_progress += 1
	else:
		_progress = 1 if key == SEQUENCE[0] else 0
	if _progress == SEQUENCE.size():
		_progress = 0
		if open:
			close()
		elif can_open():
			show_menu()

func can_open() -> bool:
	# (In a co-op game the session's own screens use the menu window too; a game in progress counts as started.)
	var coop_live: bool = main.get("coop") != null and main.coop != null and main.coop.active
	if not (main.started or coop_live) or (main.menu.visible and not coop_live):
		return false
	if story != null and (story.ui.inspect_active() or story.ui.dialogue_active()):
		return false
	return true

func show_menu() -> void:
	open = true
	_was_playing = player.playing
	player.playing = false
	player.release_object()
	main.touch.set_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()
	_panel.visible = true
	_fit()
	_fit.call_deferred()

func close() -> void:
	open = false
	_panel.visible = false
	if _was_playing:
		main._play()

# ---------------------------------------------------------------- layout

func _build() -> void:
	var theme := Theme.new()
	theme.default_font_size = 17
	var button := StyleBoxFlat.new()
	button.bg_color = Color(.2, .16, .12, .95)
	button.border_color = Color(.55, .41, .27)
	button.set_border_width_all(1)
	button.set_corner_radius_all(5)
	button.content_margin_left = 10
	button.content_margin_right = 10
	button.content_margin_top = 6
	button.content_margin_bottom = 6
	theme.set_stylebox("normal", "Button", button)
	var hover := button.duplicate() as StyleBoxFlat
	hover.bg_color = Color(.36, .26, .16)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", hover)
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for type in ["Label", "Button", "CheckBox"]:
		theme.set_color("font_color", type, Color(.96, .9, .79))
	_panel = PanelContainer.new()
	_panel.name = "DebugPanel"
	_panel.theme = theme
	var back := StyleBoxFlat.new()
	back.bg_color = Color(.03, .035, .04, .94)
	back.border_color = Color(.55, .41, .27, .8)
	back.set_border_width_all(2)
	back.set_corner_radius_all(8)
	back.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", back)
	add_child(_panel)
	get_viewport().size_changed.connect(_fit)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)
	var title := HBoxContainer.new()
	column.add_child(title)
	var heading := Label.new()
	heading.text = "Debug"
	heading.add_theme_font_size_override("font_size", 26)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(heading)
	var close_button := Button.new()
	close_button.text = "Close  (Esc)"
	close_button.pressed.connect(close)
	title.add_child(close_button)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 14)
	_info.add_theme_color_override("font_color", Color(.75, .8, .85))
	# One long status line made the whole window wider than the screen had room for: it can no longer widen it.
	_info.clip_text = true
	column.add_child(_info)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tabs)
	_items_tab(_tab(tabs, "Items"))
	_lighting_tab(_tab(tabs, "Lighting"))
	_player_tab(_tab(tabs, "Player"))
	_world_tab(_tab(tabs, "World"))
	_missions_tab(_tab(tabs, "Missions"))

## Centres the window and keeps all of it on the screen: never wider or taller than the screen less a margin, and
## drawn smaller, whole, if what is inside still needs more room than that.
func _fit() -> void:
	if _panel == null or not _panel.is_inside_tree():
		return
	var bounds := _panel.get_viewport_rect().size
	var room := bounds - Vector2(48, 48)
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.scale = Vector2.ONE
	var wanted := Vector2(minf(PANEL_WIDTH, room.x), minf(PANEL_HEIGHT, room.y))
	var least := _panel.get_combined_minimum_size()
	_panel.size = Vector2(maxf(wanted.x, least.x), maxf(wanted.y, least.y))
	var shrink := minf(1.0, minf(room.x / _panel.size.x, room.y / _panel.size.y))
	_panel.pivot_offset = Vector2.ZERO
	_panel.scale = Vector2(shrink, shrink)
	_panel.position = ((bounds - _panel.size * shrink) * .5).round()

func _tab(tabs: TabContainer, label: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = label
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	return box

func _section(box: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", Color(.93, .74, .45))
	box.add_child(label)

func _note(box: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(.65, .66, .66))
	box.add_child(label)

## A row of buttons: [[text, callable], ...].
func _buttons(box: VBoxContainer, specs: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	for spec in specs:
		var b := Button.new()
		b.text = spec[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.pressed.connect(func():
			(spec[1] as Callable).call()
			_refresh())
		row.add_child(b)

func _check(box: VBoxContainer, key: String, text: String, apply: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.focus_mode = Control.FOCUS_NONE
	c.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	c.toggled.connect(func(on: bool):
		apply.call(on)
		_refresh())
	box.add_child(c)
	_controls[key] = c
	return c

func _slider(box: VBoxContainer, key: String, text: String, lo: float, hi: float, value: float, apply: Callable, step := .05) -> HSlider:
	var row := HBoxContainer.new()
	box.add_child(row)
	var name_label := Label.new()
	name_label.text = text
	name_label.custom_minimum_size.x = 150
	row.add_child(name_label)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_NONE
	row.add_child(s)
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 52
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = "%.2f" % value
	row.add_child(value_label)
	s.value_changed.connect(func(v: float):
		value_label.text = "%.2f" % v
		apply.call(v))
	_controls[key] = s
	return s

# ---------------------------------------------------------------- items

func _items_tab(box: VBoxContainer) -> void:
	if story == null:
		_note(box, "No hut story in this scene (control lab): items are unavailable.")
		return
	_section(box, "Glock 17")
	_buttons(box, [["Give Glock", story.debug_give_gun], ["Draw / holster", _draw_gun]])
	_section(box, "Bullets")
	_buttons(box, [["+17", func(): _rounds(17)], ["+60", func(): _rounds(60)], ["+200", func(): _rounds(200)]])
	_buttons(box, [["Fill magazine", _fill_magazine]])
	_check(box, "infinite", "Infinite ammo (the magazine never empties)", func(on: bool): story.gun.infinite_ammo = on)
	_section(box, "Secret weapons")
	_buttons(box, [["Summon AR-15", _summon_rifle], ["Draw / holster", _draw_rifle]])
	_note(box, "An automatic rifle, here only, with 300 rounds. Hold the left mouse button and it keeps firing; right button for the sights, R reloads, B switches automatic / single shots, 2 brings it up and 1 the pistol.")
	_buttons(box, [["Summon shotgun", _summon_shotgun], ["Draw / holster", _draw_shotgun]])
	_note(box, "A pump 12 gauge with 64 shells: nine pellets a shot, pumped after each, R loads shells one at a time (fire to stop loading), 3 brings it up. The bullet buttons above fill whichever weapon is in the hands.")
	_buttons(box, [["Summon sniper rifle", _summon_sniper], ["Draw / holster", _draw_sniper]])
	_note(box, "A bolt-action .338 with 40 rounds: five in the magazine, the bolt worked after each shot, 4 brings it up. Hold the right button to look through the scope: 8x, and the mouse wheel turns it down to 2x and back; Shift holds your breath. It takes off whatever it hits and goes through two bodies.")
	_buttons(box, [["Summon 10 grenades", _summon_grenades]])
	_buttons(box, [["Arsenal: every weapon, all the ammo", _arsenal]])
	# 0.48: the named arsenal (scripts/arsenal.gd): one of each kind is carried; summoning one swaps it in.
	for cls: String in ["pistol", "rifle", "shotgun", "sniper"]:
		_section(box, {"pistol": "Pistols (1)", "rifle": "Rifles (2)", "shotgun": "Shotguns (3)", "sniper": "Sniper rifles (4)"}[cls])
		var row: Array = []
		for id: String in InteriorArsenal.of_class(cls):
			row.append([InteriorArsenal.display_name(id), func(): _summon_model(id)])
			if row.size() == 3:
				_buttons(box, row)
				row = []
		if not row.is_empty():
			_buttons(box, row)
	_section(box, "Flashlight")
	_buttons(box, [["Give flashlight", story.debug_give_flashlight], ["On / off", _toggle_flashlight]])
	_slider(box, "torch_energy", "Brightness ×", .1, 4.0, 1.0, func(v: float): story.flashlight.energy_scale = v)
	_slider(box, "torch_range", "Reach (m)", 5.0, 80.0, InteriorFlashlight.RANGE, func(v: float): story.flashlight.light.spot_range = v, 1.0)
	_slider(box, "torch_angle", "Cone (°)", 8.0, 60.0, InteriorFlashlight.ANGLE, func(v: float): story.flashlight.light.spot_angle = v, 1.0)
	_section(box, "Other")
	_buttons(box, [["Give hut key", story.debug_give_key], ["Give everything", _give_everything]])
	_note(box, "Given items skip their hut scenes: taking the Glock here does not start the hooded man's call-out.")

func _draw_gun() -> void:
	if story.gun.owned:
		story.gun._key_weapon("pistol")

func _fill_magazine() -> void:
	story.debug_give_gun()
	story.gun.debug_fill()

## 0.27: the secret rifle, with a full magazine and three spare, straight into the hands.
func _summon_rifle() -> void:
	story.gun.give_rifle()
	story.gun.select("rifle")
	story.notify("Debug: AR-15 (2 draws it, B: automatic / single)")

func _draw_rifle() -> void:
	if story.gun.rifle_owned:
		story.gun._key_weapon("rifle")

## 0.28: the pump shotgun, loaded, with 64 shells.
func _summon_shotgun() -> void:
	story.gun.give_shotgun()
	story.gun.select("shotgun")
	story.notify("Debug: shotgun (3 draws it)")

func _draw_shotgun() -> void:
	if story.gun.shotgun_owned:
		story.gun._key_weapon("shotgun")

## 0.29: the sniper rifle, loaded, with 40 rounds.
func _summon_sniper() -> void:
	story.gun.give_sniper()
	story.gun.select("sniper")
	story.notify("Debug: sniper rifle (4 draws it, right button for the scope)")

func _draw_sniper() -> void:
	if story.gun.sniper_owned:
		story.gun._key_weapon("sniper")

## 0.28: the pistol, the rifle and the shotgun, each loaded, with 400 / 600 / 120 rounds more, and the rifle up.
## 0.29: and the sniper rifle with 80.
func _arsenal() -> void:
	story.debug_give_gun()
	story.debug_give_flashlight()
	var gun := story.gun
	gun.give_rifle()
	gun.give_shotgun()
	gun.add_rounds(400, "pistol")
	gun.add_rounds(600, "rifle")
	gun.add_rounds(120, "shotgun")
	gun.give_sniper()
	gun.add_rounds(80, "sniper")
	if gun.weapon == "pistol" and gun.loaded() == 0:
		gun.debug_fill()
	gun.select("rifle")
	if main.get("grenades") != null:
		main.grenades.give(10)
	story.notify("Debug: arsenal (1 pistol, 2 rifle, 3 shotgun, 4 sniper, hold 5 grenade)")

## 0.48: a named weapon, loaded, with plenty spare, into the hands (it takes the place of its kind).
func _summon_model(id: String) -> void:
	var gun := story.gun
	var size := int(gun.profile_of(id).mag)
	gun.give_model(id, size * 8)
	gun.select(InteriorArsenal.class_of(id))
	story.notify("Debug: %s" % InteriorArsenal.display_name(id))

## 0.43: ten frag grenades (hold 5, let go to throw).
func _summon_grenades() -> void:
	if main.get("grenades") != null:
		main.grenades.give(10)
		story.notify("Debug: 10 grenades (hold 5 to cook, let go to throw; sights up for a lob)")

func _toggle_flashlight() -> void:
	story.debug_give_flashlight()
	story.flashlight.toggle()

func _give_everything() -> void:
	story.debug_give_key()
	story.debug_give_gun()
	story.debug_give_flashlight()
	_rounds(60)

func _rounds(count: int) -> void:
	story.debug_give_gun()
	story.gun.add_rounds(count, story.gun.weapon)
	story.notify("Debug: +%d rounds" % count)

# ---------------------------------------------------------------- lighting

func _lighting_tab(box: VBoxContainer) -> void:
	_section(box, "Camera")
	_slider(box, "exposure", "Exposure ×", .25, 6.0, 1.0, _set_exposure)
	_section(box, "Ambient")
	_check(box, "ambient_on", "Override ambient light", func(on: bool):
		_ambient_override = on
		var env := _environment()
		if env == null:
			return
		if on:
			_ambient_saved = env.ambient_light_energy
		elif _ambient_saved >= 0.0:
			env.ambient_light_energy = _ambient_saved)
	_slider(box, "ambient", "Ambient energy", 0.0, 4.0, 1.0, func(v: float): _ambient_energy = v)
	_section(box, "Lights")
	_slider(box, "moon", "Moon ×", 0.0, 6.0, 1.0, _set_moon)
	_slider(box, "fill", "Fill light (follows you)", 0.0, 6.0, 0.0, func(v: float):
		_fill.light_energy = v
		_fill.visible = v > .001)
	_check(box, "lamps", "Street lamps on", _set_lamps)
	_check(box, "fog", "Fog", func(on: bool):
		_fog_off = not on
		var env := _environment()
		if env != null and on and not _fog_saved.is_empty():
			env.fog_enabled = _fog_saved.fog
			env.volumetric_fog_enabled = _fog_saved.volumetric
			_fog_saved.clear())
	_buttons(box, [["Reset lighting", _reset_lighting]])
	_note(box, "Exposure is a camera multiplier on top of the scene's own grade. Street lamps off is what the alarm does.")

func _environment() -> Environment:
	var world := main.get_viewport().world_3d
	if world != null and world.environment != null:
		return world.environment
	for node in main.find_children("*", "WorldEnvironment", true, false):
		if (node as Node).get_viewport() == main.get_viewport():
			return (node as WorldEnvironment).environment
	return null

func _set_exposure(v: float) -> void:
	if _attributes == null:
		_attributes = player.camera.attributes as CameraAttributesPractical
		if _attributes == null:
			_attributes = CameraAttributesPractical.new()
			player.camera.attributes = _attributes
	_attributes.exposure_multiplier = v

func _moon_lights() -> Array[DirectionalLight3D]:
	var out: Array[DirectionalLight3D] = []
	for label in ["Moon", "SkyFill"]:
		var light := main.find_child(label, true, false) as DirectionalLight3D
		if light != null:
			out.append(light)
	return out

func _set_moon(v: float) -> void:
	_moon_scale = v
	for light in _moon_lights():
		if not _moon_base.has(light):
			_moon_base[light] = light.light_energy
		light.light_energy = _moon_base[light] * v

func _street_lamps() -> Array[Light3D]:
	var out: Array[Light3D] = []
	for node in main.find_children("Street lamp*", "Light3D", true, false):
		out.append(node as Light3D)
	return out

func _set_lamps(on: bool) -> void:
	for lamp in _street_lamps():
		if lamp.has_meta("shot_out"):
			continue
		lamp.visible = on
		if on and lamp.light_energy < .05:
			lamp.light_energy = float(lamp.get_meta("debug_energy", 1.0))
			if lamp.has_meta("base_energy"):
				lamp.set_meta("base_energy", lamp.light_energy)
		elif not on and lamp.light_energy >= .05:
			lamp.set_meta("debug_energy", lamp.light_energy)

func _reset_lighting() -> void:
	(_controls["exposure"] as HSlider).value = 1.0
	(_controls["ambient_on"] as CheckBox).button_pressed = false
	(_controls["ambient"] as HSlider).value = 1.0
	(_controls["moon"] as HSlider).value = 1.0
	(_controls["fill"] as HSlider).value = 0.0
	(_controls["fog"] as CheckBox).button_pressed = true

# ---------------------------------------------------------------- player

func _player_tab(box: VBoxContainer) -> void:
	# 0.55: health in one place, single player and co-op alike (what a button does is decided when it is pressed: the
	# co-op session does not exist yet when this menu is built, which is why its own health controls never showed).
	_section(box, "Health")
	_check(box, "god", "Invulnerable: no damage of any kind (co-op: the whole squad)", _set_god)
	_buttons(box, [["Heal me", _heal_me], ["Heal the squad", _heal_squad]])
	_buttons(box, [["Hurt me 20", func(): _hurt_me(20)], ["To critical (30)", _to_critical]])
	_buttons(box, [["Healthkit +1 (me)", func(): _coop_health("kitme")], ["Healthkits: full (me)", func(): _coop_health("kitsme")],
		["Healthkits: full (squad)", func(): _coop_health("kitssquad")]])
	_note(box, "Invulnerable blocks everything: the infected, Heavy-arm (his charge, slabs, fists, pack), grenades and fuel drums, falls, bleeding. In co-op the host's switch covers every player and the squad AI. Heal brings you back to full (and up again if you are down, in co-op); in single player it also stops the bleeding. Healthkits are co-op's (hold F on yourself, E on a teammate; up to %d each); in single player you bind wounds with H." % COOP_MISSION.MAX_KITS)
	_section(box, "Movement")
	_slider(box, "speed", "Speed ×", .25, 6.0, 1.0, func(v: float): player.debug_speed = v)
	_check(box, "noclip", "Noclip (fly: WASD, Space up, C down, Shift fast)", func(on: bool): player.noclip = on)
	_slider(box, "fov", "Field of view", 50.0, 110.0, float(player.get("_base_fov")), func(v: float): player.set("_base_fov", v), 1.0)
	if main.get("body") != null and main.body != null:
		_note(box, "0.33: no health bar. A blow bleeds until it clots or you bind it (stand still, hold H). Under 62 you start to limp; under 35 the limp is full and you cannot run until you are back over 45. Running empties the lungs in about 13 s. Falls over 2.5 m hurt. V shoves what is in arm's reach. Z / X lean. Space at a ledge up to chest height climbs it; a low thin wall is vaulted.")
	_section(box, "Game")
	_slider(box, "timescale", "Time scale", .1, 3.0, 1.0, func(v: float): Engine.time_scale = v)
	_check(box, "fps", "FPS counter", func(on: bool): main.fps_label.visible = on)
	_section(box, "Teleport")
	_buttons(box, [["Living room", func(): _teleport(player.get("_spawn_position"), false)], ["Courtyard", func(): _teleport(Vector3(10.0, -2.75, 4.0))]])
	_buttons(box, [["Street", func(): _teleport(Vector3(18.9, -2.75, 6.0))], ["Field road", func(): _teleport(Vector3(21.0, -2.75, 58.0))]])
	if story != null:
		_buttons(box, [["Hut yard", func(): _teleport(story.hut.call_spot())], ["Scarecrow", _to_scarecrow]])
	_buttons(box, [["Canal bridge", func(): _teleport(C.at(-.5, C.FLOOR, C.BRIDGE_Z - 1.6))], ["Warren gate", func(): _teleport(W.at(-22.0, W.FLOOR, 9.5))]])
	# 0.21: the Nichols property.
	_buttons(box, [["Nichols gate", func(): _teleport(Vector3(-12.0, -2.75, -55.0))], ["Nichols foyer", func(): _teleport(NICHOLS.local(0.0, 2.0, .2))]])
	_buttons(box, [["Nichols upstairs", func(): _teleport(NICHOLS.local(-6.5, 1.3, 4.6))], ["Nichols parlour", func(): _teleport(NICHOLS.local(-8.0, 3.0, .2))]])
	# 0.22: the cellar door under the landing, the cellar, the tunnel; the cellar's bulbs.
	_buttons(box, [["Cellar door", func(): _teleport(NICHOLS.local(1.95, 7.4, .2))], ["Cellar", func(): _teleport(NICHOLS.local(-6.0, 14.0, -2.5))]])
	_buttons(box, [["Tunnel", func(): _teleport(NICHOLS.local(2.6, 16.8, -3.4))], ["Cellar lights", _toggle_cellar_lights]])
	# 0.23: the walled town's ways through (scripts/town_siege.gd).
	_buttons(box, [["Wall hole", func(): _teleport(Vector3(InteriorTownSiege.HOLE_X, -2.75, InteriorTownSiege.NORTH_Z - 2.0))],
		["Slum passage", func(): _teleport(Vector3(-20.5, -2.75, 18.1))]])
	_buttons(box, [["Secret crawl", func(): _teleport(Vector3(InteriorTownSiege.SECRET_X + 1.9, -2.75, InteriorTownSiege.SOUTH_Z + 2.6))],
		["Hooded man to hole", _stranger_to_hole]])

func _toggle_cellar_lights() -> void:
	var basement := get_tree().get_first_node_in_group("nichols_basement")
	if basement != null:
		basement.set_basement_lights(not basement.lights_on)

## Skips the gate scene: the hooded man waits at the hole in the north wall, as if the gate had been opened.
func _stranger_to_hole() -> void:
	var man := get_tree().get_first_node_in_group("stranger")
	if man != null and man.has_method("to_hole") and int(man.get("state")) in [InteriorStranger.State.AT_GATE,
			InteriorStranger.State.CUTSCENE, InteriorStranger.State.WALK_AWAY, InteriorStranger.State.POSTED]:
		man.to_hole()

func _to_scarecrow() -> void:
	if story.hut.crow_route.size() >= 3:
		_teleport(story.hut.crow_route[2])

## Puts the player on the floor under `at` (a ray from 1.2 m above it); `drop` false uses `at` as it is.
func _teleport(at: Vector3, drop := true) -> void:
	var target := at
	if drop:
		var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.2, at + Vector3.DOWN * 8.0, player.collision_mask)
		query.exclude = [player.get_rid()]
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			target = (hit.position as Vector3) + Vector3.UP * .05
		else:
			target = at + Vector3.UP * .3
	player.reset_motion(target)

# ---------------------------------------------------------------- 0.49: missions (0.55: every mission, every place)

const COOP_MISSION := preload("res://scripts/coop/mission.gd")
## The Missions tab's jumps by chapter: [heading, [[mission.JUMPS key, button], ...]], in the order the run goes.
const MISSION_JUMPS := [
	["The canal and Store Road", [["dodong", "Dodong (start)"], ["escort", "Escort Dodong"], ["keys", "Dodong's house"],
		["ramp", "Floodwall ramp"], ["gate", "Old Salmonan gate"], ["storeroad", "Store Road"], ["mart", "Mart front"]]],
	["Olivar Family Mart", [["siege", "Mart siege"], ["office", "Office calls"], ["jonna", "Jonna talks"],
		["board", "Chapter board"]]],
	["The backstreets", [["backdoor", "Back door (key)"], ["backstreets", "Service gate"], ["arcade", "Avenida arcade"],
		["brickalley", "Brick alley"], ["school", "School gate"]]],
	["PILCST: up to the fifth floor", [["lobby", "Lobby"], ["floor2", "Second floor"], ["fireescape", "Fire escape"],
		["floor3", "Third floor"], ["floor4", "Fourth floor"], ["ladder", "Maintenance ladder"], ["duct", "Mechanical room"],
		["floor5", "Fifth floor"]]],
	["PILCST: the way out", [["teves", "Ma'am Teves"], ["horde", "The horde"], ["sneak", "Sneak past"],
		["firedoor", "Fire door (5F)"], ["blast", "After the blast"], ["room208", "Room 208"], ["field", "School field"],
		["heavyarm", "Heavy-arm"], ["heavykey", "Heavy-arm's key"], ["reargate", "Rear gate open"],
		["pilcstout", "Out (the board)"]]],
	["Outer Street", [["outerstreet", "The lane"], ["outerbus", "The bus"], ["outerplaza", "The plaza"],
		["outerterrace", "The terrace"], ["outerstation", "The concourse"], ["outerplatform", "The platform"],
		["outertunnel", "The tunnel"], ["outerriver", "The river road"], ["outermart", "The mart"], ["outerbridge", "The bridge"]]],
	["Davao Central Laboratory", [["hospital", "Outside"], ["hosplobby", "The lobby"], ["hospstairs", "Back stairwell"],
		["hosp2f", "Second floor"], ["berido", "Doctor Berido"], ["kitchen", "Kitchen ladder"], ["records", "Records room"],
		["hosp3f", "Third floor"], ["labdoor", "Lab door"], ["lab", "The laboratory"], ["lucky", "Doctor Lucky"], ["hosproof", "The roof"]]],
]
var _console: LineEdit
var _console_out: Label
var _mission_now: Label
var _jump_buttons := {}
var _go_buttons := {}

func _missions_tab(box: VBoxContainer) -> void:
	_section(box, "Objective")
	_mission_now = Label.new()
	_mission_now.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mission_now.add_theme_font_size_override("font_size", 14)
	_mission_now.add_theme_color_override("font_color", Color(.85, .82, .74))
	box.add_child(_mission_now)
	_buttons(box, [["Complete current objective", func(): _coop("cmd:complete")], ["Where am I?", func(): _coop("cmd:where")]])
	_note(box, "Completes it the way play would (Dodong walked home, the keys taken, the gate opened, the siege won, Jonna's talk and lockup...) and puts the squad where the next one begins, one stage at a time.")
	_section(box, "Command")
	var line := HBoxContainer.new()
	box.add_child(line)
	_console = LineEdit.new()
	_console.placeholder_text = "help, complete, jump mart, go lobby, squad, spawn 5, give ar15, god on ..."
	_console.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_console.text_submitted.connect(func(_t: String): _run_console())
	line.add_child(_console)
	var run := Button.new()
	run.text = "Run"
	run.pressed.connect(_run_console)
	line.add_child(run)
	_console_out = Label.new()
	_console_out.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_console_out.add_theme_font_size_override("font_size", 14)
	_console_out.add_theme_color_override("font_color", Color(.8, .9, .8))
	_console_out.text = "Type help."
	box.add_child(_console_out)
	_section(box, "Jump to a mission")
	_note(box, "Forward only. Everything before it is finished the way play leaves it: Dodong home and his doors open, the keys and the gate, the mart's rifles taken, Jonna's talk, the lockup and the chapter's loading, out the back door and through the service gate, the story told, Rommel's gate shut behind you, the college's floors crossed (their rushes, classes and bells behind you), 501 opened, the horde gone by, the blast, Heavy-arm. What is behind the spot is cleared; what play has waiting ahead of it stays. Everyone is back on their feet and the whole squad is put there. Greyed: behind the run (leave and host again to go back).")
	for chapter: Array in MISSION_JUMPS:
		_subheading(box, chapter[0])
		_place_rows(box, chapter[1], func(place: String): _coop("cmd:jump " + place), _jump_buttons)
	_section(box, "Teleport")
	_check(box, "coop_bring", "Bring the squad (the other players and the squad AI)", func(_on: bool): pass).set_pressed_no_signal(true)
	_buttons(box, [["Bring the squad to me", func(): _coop("cmd:squad")]])
	_note(box, "Moves you, or the whole squad, without changing the mission. Greyed: put away behind the run. Places ahead of it (the backstreets, the college) are woken early.")
	var groups: Array = []
	var items := {}
	for spot: Array in COOP_MISSION.places():
		var group: String = spot[2]
		if not items.has(group):
			groups.append(group)
			items[group] = []
		(items[group] as Array).append([spot[0], spot[1]])
	for group: String in groups:
		_subheading(box, group)
		_place_rows(box, items[group], func(key: String): _coop("cmd:go %s%s" % [key, "" if _bring_squad() else " me"]), _go_buttons)
	_note(box, "Straight into a mission from the start: Interior.exe -- --coop-jump=mart  (also --coop-bots=2, --coop-mode=easy|normal|hard). Any mission above by its command name (places lists them), or a stage 0-17.")

func _subheading(box: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(.8, .66, .47))
	box.add_child(label)

## Rows of three buttons for places: [[key, button], ...]; a press hands `press` the key. Each is kept in `store`
## by its key (`_refresh_missions` greys out the ones that cannot be used).
func _place_rows(box: VBoxContainer, entries: Array, press: Callable, store: Dictionary) -> void:
	var row: HBoxContainer = null
	for i in entries.size():
		if i % 3 == 0:
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			box.add_child(row)
		var key: String = entries[i][0]
		var b := Button.new()
		b.text = entries[i][1]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.pressed.connect(func():
			press.call(key)
			_refresh())
		row.add_child(b)
		store[key] = b
	# (A short last row: its buttons as wide as the others.)
	if row != null:
		for j in (3 - entries.size() % 3) % 3:
			var gap := Control.new()
			gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(gap)

func _bring_squad() -> bool:
	return not _controls.has("coop_bring") or (_controls["coop_bring"] as CheckBox).button_pressed

## The Missions tab as the run stands: where it is, which missions are behind it, which places are put away.
func _refresh_missions() -> void:
	if _mission_now == null:
		return
	var coop: Node = main.get("coop")
	var m: Node = coop.mission if coop != null and coop.active and coop.mission != null else null
	_mission_now.text = ("Now: stage %d. %s" % [m.stage, m.objective()]) if m != null else "Start or join a co-op game first (Multiplayer)."
	for key: String in _jump_buttons:
		var spec: Array = COOP_MISSION.JUMPS[key]
		var why: String = m.jump_blocked(key) if m != null else "No co-op game"
		var b: Button = _jump_buttons[key]
		b.disabled = why != ""
		b.tooltip_text = "jump %s  •  stage %d: %s%s" % [key, int(spec[0]), spec[3], "" if why == "" else "\n" + why]
	for key: String in _go_buttons:
		var why: String = m.place_closed(key) if m != null else "No co-op game"
		var b: Button = _go_buttons[key]
		b.disabled = why != ""
		b.tooltip_text = "go %s%s" % [key, "" if why == "" else "  •  " + why]

func _run_console() -> void:
	var text := _console.text.strip_edges()
	if text == "":
		return
	_console.text = ""
	show_reply("> " + text)
	_coop("cmd:" + text)
	_refresh()

## The host's answer to a command (session.notice passes it on while the menu is open).
func show_reply(text: String) -> void:
	if _console_out != null:
		_console_out.text = text

# ---------------------------------------------------------------- world

func _world_tab(box: VBoxContainer) -> void:
	# 0.49: anyone in the squad: a client's button is carried out by the host, for that client. (0.55: always built:
	# the co-op session is made after this menu, so `main.coop` was never there yet and the section never showed.
	# Health, invulnerability and healthkits are on the Player tab now.)
	_section(box, "Co-op")
	_buttons(box, [["Add AI squadmate", func(): _coop("add")], ["Fill squad with AI", func(): _coop("fill")], ["Remove AI", func(): _coop("remove")]])
	_buttons(box, [["Infected: 1 ahead", func(): _coop("one")], ["Infected: 5 round me", func(): _coop("five")], ["Kill all infected", func(): _coop("kill")]])
	_buttons(box, [["Team: full ammo", func(): _coop("ammo")], ["Next objective", func(): _coop("cmd:complete")]])
	_note(box, "Co-op only. Health, invulnerability and healthkits: Player tab. The squad AI follow the nearest player, cover them, give ground, reload, call things out and take orders from the voice menu (~ in a co-op game).")
	if story != null:
		_section(box, "Hut")
		_buttons(box, [["Open the drawer", _open_drawer]])
		_section(box, "Story")
		_buttons(box, [["Start the alarm", story.start_alarm]])
		_note(box, "The alarm: sirens over the town and fields, the street lamps die one by one. Objective: get home and close the door.")
	if main.get("zombies") != null and main.zombies != null:
		# 0.28: the infected (scripts/zombies.gd).
		_section(box, "Zombies")
		_buttons(box, [["Spawn 1 ahead", func(): _spawn_zombies(0)], ["Spawn 5", func(): _spawn_zombies(5)], ["Spawn 15", func(): _spawn_zombies(15)]])
		_buttons(box, [["Kill all", main.zombies.kill_all], ["Clear bodies and blood", main.zombies.clear]])
		# 0.31: thirteen kinds (scripts/zombie.gd KINDS). One of each in an arc ahead, or one of a kind.
		_buttons(box, [["One of every kind", func():
			var made: int = main.zombies.spawn_every_kind()
			if story != null:
				story.notify("Debug: %d kinds spawned ahead" % made)]])
		var kinds: Array = InteriorZombie.KINDS.keys()
		var row := []
		for kind: String in kinds:
			row.append([str((InteriorZombie.KINDS[kind] as Dictionary).label), func(): _spawn_kind(kind)])
			if row.size() == 3:
				_buttons(box, row)
				row = []
		if not row.is_empty():
			_buttons(box, row)
		_check(box, "zombies_passive", "They ignore me", func(on: bool):
			main.zombies.passive = on
			if on:
				for zombie in main.zombies.alive():
					zombie.forget())
		_check(box, "zombies_slow", "Slow motion (a quarter speed)", func(on: bool): main.zombies.slow_motion = on)
		_check(box, "senses_daylight", "They see in the dark (as before 0.33)", func(on: bool): main.senses.daylight = on)
		_check(box, "senses", "Show light and sound (what they can see and hear of me)", func(on: bool): main.senses.readout = on)
		_note(box, "0.33: they are blind in the dark. Out of the lamps, with the torch off, they see you only at arm's length, lose you in a couple of seconds and go quiet. They hear: running carries about 15 m, walking 7, crouching 3, a slow walk (hold Ctrl) under 2; a shot 55. A thrown thing or a breaking bulb draws them to where it landed. Shoot a lamp to put it out.")
		_note(box, "Spawn 5 / 15 puts them somewhere in the neighbourhood round you (14 to 42 m off, outdoors), wandering until they see or hear you; some are crouched over something. They hear gunshots from 55 m. Bodies and blood stay where they fall. A wound bleeds where it is; hands, forearms, arms, feet, shins, legs and heads come off when they have taken enough (the rifle in a few rounds, buckshot close up, the sniper in one), a chest or a belly that takes enough comes apart, and one without a leg crawls. Thirteen kinds: shambler, limper, freshly turned, runner, rager, leaper, slow-witted, crawler, lurker (plays dead), brute, twitcher, screamer, stalker (moves only when you look away).")
	_section(box, "Scene")
	_buttons(box, [["Restart", _restart]])

func _coop(what: String) -> void:
	var coop: Node = main.coop
	if coop == null or not coop.active or coop.mission == null:
		story.notify("Debug: start or join a co-op game first")
		return
	var ahead := player.global_position - player.global_basis.z * 7.0
	if coop.multiplayer.is_server():
		coop_as(1, what, ahead)
	else:
		coop.debug_request.rpc_id(1, what, ahead)
		story.notify("Debug: sent to the host (%s)" % what)

## 0.49 (host): a debug action for squad member `id` (the host, or a client through session.debug_request).
## `ahead` is a spot seven metres in front of them.
func coop_as(id: int, what: String, ahead: Vector3) -> void:
	var coop: Node = main.coop
	if coop == null or not coop.active or not coop.team.has(id):
		return
	var m: Node = coop.mission
	# 0.49: the Missions tab and the command line (mission.debug_command): the reply goes back to whoever asked.
	if what.begins_with("cmd:"):
		var reply: String = m.debug_command(id, what.trim_prefix("cmd:"))
		if reply != "":
			coop.personal(id, reply)
		return
	var me: Dictionary = coop.team[id]
	match what:
		"add":
			coop.add_bot()
		"fill":
			coop.fill_bots()
		"remove":
			coop.remove_bot()
		"one":
			m.spawn(m.ground(ahead))
		"five":
			var made := 0
			for i in 5:
				if m.spawn_near(me):
					made += 1
			coop.personal(id, "Debug: %d infected" % made)
		"kill":
			for k in m.enemies.keys():
				var z = m.enemies[k]
				m.damage(id, k, "head", z.global_position + Vector3.UP * 1.5, (z.global_position - (me.pos as Vector3)).normalized(), 999.0, 120.0)
		"heal":
			for who in coop.team:
				coop.team[who].hp = COOP_MISSION.MAX_HP
				coop.team[who].kits = maxi(int(coop.team[who].kits), 3)
				coop.reward(who, "refill")
		"kits":
			for who in coop.team:
				coop.team[who].kits = m.MAX_KITS
		"kit":
			me.kits = mini(int(me.kits) + 1, m.MAX_KITS)
		"hurt":
			me.hp = maxi(1, int(me.hp) - 40)
		# 0.55: Player > Health.
		"healme", "healsquad":
			var who_all: Array = [id] if what == "healme" else coop.team.keys()
			for who: int in who_all:
				_coop_heal(coop, m, who)
			coop.personal(id, "Healed: you, 100 HP" if what == "healme" else "Healed: the whole squad, 100 HP")
			return
		"hurt20", "critical":
			if bool(coop.harmless) or bool(m.harmless):
				coop.personal(id, "Invulnerable: untick it (Player > Health) to be hurt")
				return
			me.hp = maxi(1, int(me.hp) - 20) if what == "hurt20" else mini(int(me.hp), 30)
			coop.personal(id, "Hurt: %d HP" % int(me.hp))
			return
		"kitme", "kitsme", "kitssquad":
			var to_fill: Array = coop.team.keys() if what == "kitssquad" else [id]
			for who: int in to_fill:
				var p: Dictionary = coop.team[who]
				var want: int = mini(int(p.kits) + 1, m.MAX_KITS) if what == "kitme" else m.MAX_KITS
				while int(p.kits) < want:
					m.add_kit(p, "medium")
			coop.personal(id, ("Healthkits: %d (hold F to use one)" % int(me.kits)) if what != "kitssquad" else "Healthkits: everyone at %d" % m.MAX_KITS)
			return
		"ammo":
			for who in coop.team:
				coop.reward(who, "refill")
		"skip":
			var to: Vector3 = m.debug_skip()
			if to.is_finite():
				if id == 1: _teleport(to + Vector3.UP * .1)
				else: coop.debug_teleport.rpc_id(id, to + Vector3.UP * .1)
		"harmless":
			m.harmless = true
			coop.harmless = true
			coop.personal(id, "Invulnerable: the whole squad, no damage of any kind")
			return
		"harmful":
			m.harmless = false
			coop.harmless = false
			coop.personal(id, "Invulnerable off: the squad can be hurt again")
			return
	coop.personal(id, "Debug: squad %d, infected %d, objective %d" % [coop.team.size(), m.enemies.size(), m.stage])

# ---------------------------------------------------------------- 0.55: health (Player tab)

func _coop_live() -> bool:
	var coop: Node = main.get("coop")
	return coop != null and coop.active and coop.mission != null

## Invulnerable on or off, single player and co-op at once (whichever is being played; `_keep_god` holds it).
func _set_god(on: bool) -> void:
	god = on
	if main.get("zombies") != null and main.zombies != null:
		main.zombies.invulnerable = on
	if on and main.get("body") != null and main.body != null:
		main.body.bleeding = 0.0
	if _coop_live():
		_coop("harmless" if on else "harmful")
	elif story != null:
		story.notify("Invulnerable: no damage of any kind" if on else "Invulnerable off")

## Every frame: while the box is ticked it stays so (a co-op game started or hosted after ticking it, the single-player
## director remade by a restart). The host decides for the whole squad.
func _keep_god() -> void:
	if not god:
		return
	if main.get("zombies") != null and main.zombies != null and not main.zombies.invulnerable:
		main.zombies.invulnerable = true
	if main.get("body") != null and main.body != null and main.body.bleeding > 0.0:
		main.body.bleeding = 0.0
	if _coop_live() and main.coop.multiplayer.is_server() and not (bool(main.coop.harmless) and bool(main.coop.mission.harmless)):
		main.coop.harmless = true
		main.coop.mission.harmless = true

## Co-op (host): `who` back to full, up again if down, any patch-up on them ended.
func _coop_heal(coop: Node, m: Node, who: int) -> void:
	if not coop.team.has(who):
		return
	m._end_heal(who)
	coop.team[who].hp = COOP_MISSION.MAX_HP
	coop.team[who].held = false
	coop.team[who].heal_t = -1.0

func _heal_me() -> void:
	if _coop_live():
		_coop("healme")
		return
	_solo_heal()

func _heal_squad() -> void:
	if _coop_live():
		_coop("healsquad")
		return
	_solo_heal()

## Single player: full health, the bleeding stopped, rest's ceiling back to full.
func _solo_heal() -> void:
	if main.get("body") != null and main.body != null:
		main.body.heal()
	elif main.get("zombies") != null and main.zombies != null:
		main.zombies.health = 100.0
	if story != null:
		story.notify("Healed: 100")

func _hurt_me(amount: int) -> void:
	if _coop_live():
		_coop("hurt20")
		return
	if main.get("zombies") == null or main.zombies == null:
		return
	if main.zombies.invulnerable:
		if story != null:
			story.notify("Invulnerable: untick it to be hurt")
		return
	main.zombies.hurt_player(float(amount), player.global_position + player.global_basis.x)

func _to_critical() -> void:
	if _coop_live():
		_coop("critical")
		return
	if main.get("zombies") == null or main.zombies == null:
		return
	if main.zombies.invulnerable:
		if story != null:
			story.notify("Invulnerable: untick it to be hurt")
		return
	main.zombies.hurt_player(maxf(1.0, main.zombies.health - 30.0), player.global_position + player.global_basis.x)

## Healthkits belong to co-op (single player binds wounds with H).
func _coop_health(what: String) -> void:
	if not _coop_live():
		if story != null:
			story.notify("Healthkits are co-op's: in single player, stand still and hold H to bind a wound")
		return
	_coop(what)

func _spawn_zombies(count: int) -> void:
	var made := 0
	if count <= 0:
		made = 1 if main.zombies.spawn_ahead() != null else 0
	else:
		made = main.zombies.spawn_around(count)
	if story != null:
		story.notify("Debug: %d infected spawned (%d alive)" % [made, main.zombies.alive().size()])

func _spawn_kind(kind: String) -> void:
	var zombie: InteriorZombie = main.zombies.spawn_ahead(8.0, kind)
	if story != null:
		story.notify("Debug: %s" % (str((InteriorZombie.KINDS[kind] as Dictionary).label) if zombie != null else "no room to spawn"))

func _open_drawer() -> void:
	story.debug_give_key()
	if not story.hut.drawer_open:
		story.hut.use("drawer")

func _restart() -> void:
	Engine.time_scale = 1.0
	main._restart()

# ---------------------------------------------------------------- per frame

func _refresh() -> void:
	if _controls.has("lamps"):
		var lit := false
		for lamp in _street_lamps():
			lit = lit or (lamp.visible and lamp.light_energy > .05)
		(_controls["lamps"] as CheckBox).set_pressed_no_signal(lit)
	if _controls.has("fog"):
		(_controls["fog"] as CheckBox).set_pressed_no_signal(not _fog_off)
	if _controls.has("fps"):
		(_controls["fps"] as CheckBox).set_pressed_no_signal(main.fps_label.visible)
	if _controls.has("noclip"):
		(_controls["noclip"] as CheckBox).set_pressed_no_signal(player.noclip)
	if _controls.has("zombies_passive"):
		(_controls["zombies_passive"] as CheckBox).set_pressed_no_signal(main.zombies.passive)
		if _controls.has("zombies_slow"):
			(_controls["zombies_slow"] as CheckBox).set_pressed_no_signal(main.zombies.slow_motion)
	if _controls.has("god"):
		(_controls["god"] as CheckBox).set_pressed_no_signal(god)
	if story != null and _controls.has("infinite"):
		(_controls["infinite"] as CheckBox).set_pressed_no_signal(story.gun.infinite_ammo)
	_refresh_missions()
	_update_info()

func _update_info() -> void:
	var p := player.global_position
	var text := "FPS %d   •   at (%.1f, %.1f, %.1f)" % [Engine.get_frames_per_second(), p.x, p.y, p.z]
	if story != null:
		var gun := story.gun
		text += "\nStory: %s   •   %s: %s" % [InteriorStory.Phase.keys()[story.phase], gun.weapon_name(),
				("%d + %d" % [gun.loaded(), gun.reserve]) if gun.has_weapon(gun.weapon) else "no"]
		text += "   •   Flashlight: %s" % (("on" if story.flashlight.on else "off") if story.flashlight.owned else "no")
	if main.get("coop") != null and main.coop != null and main.coop.active and main.coop.mission != null:
		var m: Node = main.coop.mission
		text += "\nCo-op: objective %d   •   squad %d (%d AI)   •   infected %d   •   bodies %d" % [m.stage, main.coop.team.size(),
				main.coop.team.size() - main.coop.humans(), m.enemies.size(), m.corpses.size()]
	elif main.get("zombies") != null and main.zombies != null:
		text += "\nInfected: %d alive, %d killed   •   Health %d\nBlood: %d splats, %d drops, %d wounds bleeding, %d parts" % [
				main.zombies.alive().size(), main.zombies.kills, int(main.zombies.health), main.zombies.blood.count(),
				main.zombies.blood.spots(), main.zombies.blood.bleeders(), main.zombies.blood.parts()]
	_info.text = text

func _process(delta: float) -> void:
	_poll_sequence()
	_keep_god()
	var env := _environment()
	if env != null:
		if _ambient_override:
			env.ambient_light_energy = _ambient_energy
		if _fog_off:
			if _fog_saved.is_empty():
				_fog_saved = {"fog": env.fog_enabled, "volumetric": env.volumetric_fog_enabled}
			env.fog_enabled = false
			env.volumetric_fog_enabled = false
	if _fill.visible and _fill.is_inside_tree():
		var camera := main.get_viewport().get_camera_3d()
		if camera != null:
			_fill.global_position = camera.global_position + Vector3.UP * .4
	if open:
		_info_timer -= delta
		if _info_timer <= 0.0:
			_info_timer = .25
			_update_info()
