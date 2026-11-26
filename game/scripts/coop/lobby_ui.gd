extends Control
## 0.45: the multiplayer screens, full-screen over the menu street.
##
##  Browse   the open games (from the online lobby, no addresses), who is online right now and what they are
##           doing, the public lobby chat, your name (click to change), Host game, and Join by address for LAN
##           or VPN play.
##  Room     the squad you hosted or joined: five places with each survivor's name, character, Host / AI / You
##           badges and Ready; your survivor's look; the squad's own chat (only the squad sees it); Ready up, and
##           for the host Start mission once everyone is ready.
## session.gd owns the network; this file only draws and forwards clicks.

const BONE := Color(.9, .88, .84)
const DIM := Color(.6, .6, .62)
const FAINT := Color(.42, .42, .45)
const ACCENT := Color(.74, .07, .09)
const ACCENT_HI := Color(.86, .1, .12)
const GOOD := Color(.2, .66, .36)
const WARN := Color(.9, .62, .2)
const STATE_TEXT := {"menu": ["In menus", Color(.2, .66, .36)], "hosting": ["Hosting a game", Color(.9, .62, .2)],
	"in a lobby": ["In a squad", Color(.9, .62, .2)], "in a game": ["On a mission", Color(.78, .16, .16)]}

var session
var net
var view := ""
var _fonts := {}

var _body: Control
var _footer_left: HBoxContainer
var _footer_right: HBoxContainer
var _note: Label
var _name_label: Label
var _name_edit: LineEdit
var _initial: Label
var _dot: Panel
var _status: Label
# browse
var _games: VBoxContainer
var _games_empty: Control
var _games_count: Label
var _online: VBoxContainer
var _online_count: Label
var _lobby_chat: RichTextLabel
var _lobby_input: LineEdit
var _address_row: HBoxContainer
# room
var _squad: VBoxContainer
var _squad_count: Label
var _party_chat: RichTextLabel
var _party_input: LineEdit
var _ready: Button
var _start: Button
## 0.46: the game mode: the host's three buttons, everyone's line saying what it means.
var _mode_buttons := {}
var _mode_about: Label
var _room_title: Label
var _room_sub: Label
var _lobby_lines: Array = []

func setup(owner_session) -> void:
	session = owner_session
	net = session.lobby
	name = "LobbyUI"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = _theme()
	var shade := TextureRect.new()
	var g := GradientTexture2D.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(.012, .01, .012, .94))
	grad.set_color(1, Color(.012, .01, .012, .72))
	g.gradient = grad
	g.fill_from = Vector2(0, 0)
	g.fill_to = Vector2(1, 0)
	shade.texture = g
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 36)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	column.add_child(_header())
	var rule := ColorRect.new()
	rule.color = Color(1, 1, 1, .07)
	rule.custom_minimum_size.y = 1
	column.add_child(rule)
	_body = Control.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_body)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	footer.custom_minimum_size.y = 54
	column.add_child(footer)
	_footer_left = HBoxContainer.new()
	_footer_left.add_theme_constant_override("separation", 10)
	footer.add_child(_footer_left)
	_note = _text("", 14, DIM)
	_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_note.clip_text = true
	footer.add_child(_note)
	_footer_right = HBoxContainer.new()
	_footer_right.add_theme_constant_override("separation", 10)
	footer.add_child(_footer_right)
	net.changed.connect(_net_changed)
	net.chat.connect(_lobby_line)
	net.status.connect(_net_status)
	_net_status("Online" if net.online else "Connecting to the lobby…", net.online)

# ---------------------------------------------------------------- look

## 0.54: the game's own faces (SleepType), not Windows' Bahnschrift. Condensed is the street-sign capitals (set
## in capitals: `_text` and `_button` upper-case what they show in it); the rest is the text face at `weight`.
func font(weight: int, condensed := false, spacing := 0) -> Font:
	var key := "%d/%s/%d" % [weight, condensed, spacing]
	if _fonts.has(key): return _fonts[key]
	var f: Font = SleepType.street(spacing + 1) if condensed else SleepType.text(clampi(weight, 400, 800))
	_fonts[key] = f
	return f

static func box(bg: Color, border := Color(0, 0, 0, 0), width := 0, radius := 3, mx := 14, my := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = mx
	s.content_margin_right = mx
	s.content_margin_top = my
	s.content_margin_bottom = my
	s.anti_aliasing = true
	return s

func _theme() -> Theme:
	var t := Theme.new()
	t.default_font = font(400)
	t.default_font_size = 16
	t.set_color("font_color", "Label", BONE)
	# Buttons: quiet by default, the accent on hover; a primary (red), a ready (green) and a ghost variation.
	t.set_font("font", "Button", font(600, true, 1))
	t.set_font_size("font_size", "Button", 16)
	for c in ["font_color", "font_focus_color"]: t.set_color(c, "Button", BONE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(.5, .5, .52))
	t.set_stylebox("normal", "Button", box(Color(1, 1, 1, .05), Color(1, 1, 1, .14), 1, 3, 18, 9))
	t.set_stylebox("hover", "Button", box(Color(1, 1, 1, .1), ACCENT, 1, 3, 18, 9))
	t.set_stylebox("pressed", "Button", box(ACCENT.darkened(.35), ACCENT, 1, 3, 18, 9))
	t.set_stylebox("disabled", "Button", box(Color(1, 1, 1, .025), Color(1, 1, 1, .06), 1, 3, 18, 9))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), Color(1, 1, 1, .35), 1, 3))
	for variant: Array in [["Primary", ACCENT, ACCENT_HI, ACCENT.darkened(.3)], ["Ready", Color(.15, .5, .27), Color(.2, .62, .34), Color(.12, .4, .22)]]:
		var n: String = variant[0]
		t.set_type_variation(n, "Button")
		var normal := box(variant[1], (variant[1] as Color).darkened(.45), 0, 3, 22, 10)
		normal.border_width_bottom = 3
		var hover := box(variant[2], (variant[2] as Color).darkened(.45), 0, 3, 22, 10)
		hover.border_width_bottom = 3
		hover.shadow_color = Color(variant[2], .35)
		hover.shadow_size = 10
		t.set_stylebox("normal", n, normal)
		t.set_stylebox("hover", n, hover)
		t.set_stylebox("pressed", n, box(variant[3], Color(0, 0, 0, 0), 0, 3, 22, 10))
		t.set_stylebox("disabled", n, box(Color(.16, .1, .1, .8), Color(1, 1, 1, .05), 1, 3, 22, 10))
		t.set_color("font_color", n, Color.WHITE)
	t.set_type_variation("Ghost", "Button")
	t.set_stylebox("normal", "Ghost", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 3, 10, 6))
	t.set_stylebox("hover", "Ghost", box(Color(1, 1, 1, .07), Color(0, 0, 0, 0), 0, 3, 10, 6))
	t.set_stylebox("pressed", "Ghost", box(Color(1, 1, 1, .12), Color(0, 0, 0, 0), 0, 3, 10, 6))
	t.set_color("font_color", "Ghost", DIM)
	t.set_font_size("font_size", "Ghost", 14)
	# Fields.
	t.set_stylebox("normal", "LineEdit", box(Color(0, 0, 0, .5), Color(1, 1, 1, .12), 1, 3, 12, 9))
	t.set_stylebox("focus", "LineEdit", box(Color(0, 0, 0, .55), ACCENT, 1, 3, 12, 9))
	t.set_stylebox("read_only", "LineEdit", box(Color(0, 0, 0, .3), Color(1, 1, 1, .06), 1, 3, 12, 9))
	t.set_color("font_color", "LineEdit", BONE)
	t.set_color("font_placeholder_color", "LineEdit", FAINT)
	t.set_color("caret_color", "LineEdit", ACCENT_HI)
	t.set_color("selection_color", "LineEdit", Color(ACCENT, .5))
	# Panels and lists.
	var panel := box(Color(.028, .027, .032, .9), Color(1, 1, 1, .065), 1, 4, 18, 14)
	panel.shadow_color = Color(0, 0, 0, .5)
	panel.shadow_size = 18
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("normal", "RichTextLabel", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 0, 0))
	t.set_font("normal_font", "RichTextLabel", font(400))
	t.set_font("bold_font", "RichTextLabel", font(700))
	t.set_font("italics_font", "RichTextLabel", font(300))
	t.set_font_size("normal_font_size", "RichTextLabel", 15)
	t.set_font_size("bold_font_size", "RichTextLabel", 15)
	t.set_font_size("italics_font_size", "RichTextLabel", 14)
	t.set_color("default_color", "RichTextLabel", BONE)
	var grab := box(Color(1, 1, 1, .16), Color(0, 0, 0, 0), 0, 3, 0, 0)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", box(Color(1, 1, 1, .3), Color(0, 0, 0, 0), 0, 3, 0, 0))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(ACCENT, Color(0, 0, 0, 0), 0, 3, 0, 0))
	var track := box(Color(1, 1, 1, .03), Color(0, 0, 0, 0), 0, 3, 3, 0)
	t.set_stylebox("scroll", "VScrollBar", track)
	# Option buttons (the survivor's look) and their lists.
	t.set_font("font", "OptionButton", font(400))
	t.set_font_size("font_size", "OptionButton", 15)
	t.set_stylebox("normal", "OptionButton", box(Color(0, 0, 0, .45), Color(1, 1, 1, .12), 1, 3, 12, 7))
	t.set_stylebox("hover", "OptionButton", box(Color(1, 1, 1, .06), ACCENT, 1, 3, 12, 7))
	t.set_stylebox("pressed", "OptionButton", box(Color(1, 1, 1, .08), ACCENT, 1, 3, 12, 7))
	t.set_stylebox("focus", "OptionButton", box(Color(0, 0, 0, 0), Color(1, 1, 1, .3), 1, 3))
	t.set_stylebox("panel", "PopupMenu", box(Color(.05, .05, .06, .98), Color(1, 1, 1, .1), 1, 3, 6, 6))
	t.set_stylebox("hover", "PopupMenu", box(Color(ACCENT, .7), Color(0, 0, 0, 0), 0, 2, 6, 4))
	t.set_font("font", "PopupMenu", font(400))
	t.set_color("font_color", "PopupMenu", BONE)
	return t

func _text(words: String, size: int, colour := BONE, weight := 400, condensed := false, spacing := 0) -> Label:
	var l := Label.new()
	l.text = words
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	if weight != 400 or condensed or spacing != 0: l.add_theme_font_override("font", font(weight, condensed, spacing))
	l.uppercase = condensed
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _button(words: String, variant: String, call: Callable, min_size := Vector2.ZERO, size := 16) -> Button:
	var b := Button.new()
	b.text = words.to_upper()
	if variant != "": b.theme_type_variation = variant
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(call)
	return b

func _panel(title: String, side := "") -> Array:
	var p := PanelContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	var tick := ColorRect.new()
	tick.color = ACCENT
	tick.custom_minimum_size = Vector2(3, 16)
	tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(tick)
	head.add_child(_text(title, 15, BONE, 700, true, 2))
	var count := _text(side, 13, FAINT, 500, true, 1)
	count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(count)
	return [p, v, count, head]

func _chip(words: String, colour: Color, filled := false) -> PanelContainer:
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", box(Color(colour, .9) if filled else Color(colour, .14), Color(colour, .7), 0 if filled else 1, 2, 8, 2))
	c.add_child(_text(words, 11, Color.WHITE if filled else colour.lightened(.25), 700, true, 1))
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _dot_panel(colour: Color, d := 9) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(d, d)
	p.add_theme_stylebox_override("panel", box(colour, Color(0, 0, 0, 0), 0, d))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _scroll(content: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(content)
	return s

func _chat_box(placeholder: String, on_send: Callable) -> Array:
	var log := RichTextLabel.new()
	log.bbcode_enabled = true
	log.scroll_following = true
	log.selection_enabled = true
	log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log.custom_minimum_size.y = 80
	log.add_theme_constant_override("line_separation", 3)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	input.max_length = 160
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.add_theme_font_size_override("font_size", 15)
	input.text_submitted.connect(func(_t): _send_from(input, on_send))
	row.add_child(input)
	row.add_child(_button("SEND", "Primary", func(): _send_from(input, on_send), Vector2(64, 0), 14))
	return [log, row, input]

func _send_from(input: LineEdit, on_send: Callable) -> void:
	var t := input.text.strip_edges()
	if t.is_empty(): return
	input.clear()
	on_send.call(t)
	input.grab_focus()

static func escape(t: String) -> String: return t.replace("[", "[lb]")

func _stamp() -> String:
	var now := Time.get_time_dict_from_system()
	return "[color=#5d5d63]%02d:%02d[/color]  " % [now.hour, now.minute]

# ---------------------------------------------------------------- header

func _header() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.custom_minimum_size.y = 62
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	h.add_child(titles)
	_room_sub = _text("CO-OP  •  UP TO FIVE SURVIVORS", 12, ACCENT_HI, 700, true, 3)
	titles.add_child(_room_sub)
	_room_title = _text("MULTIPLAYER", 40, BONE, 700, true, 2)
	titles.add_child(_room_title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(spacer)
	# Your name: click to change it.
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", box(Color(1, 1, 1, .045), Color(1, 1, 1, .1), 1, 4, 10, 6))
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(chip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	chip.add_child(row)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", box(ACCENT, Color(0, 0, 0, 0), 0, 18, 0, 0))
	badge.custom_minimum_size = Vector2(36, 36)
	row.add_child(badge)
	_initial = _text("", 17, Color.WHITE, 700, true)
	_initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(_initial)
	var who := VBoxContainer.new()
	who.add_theme_constant_override("separation", -3)
	row.add_child(who)
	who.add_child(_text("PLAYER NAME", 10, FAINT, 700, true, 2))
	_name_label = _text("", 17, BONE, 600)
	who.add_child(_name_label)
	_name_edit = LineEdit.new()
	_name_edit.max_length = 18
	_name_edit.custom_minimum_size.x = 170
	_name_edit.visible = false
	_name_edit.text_submitted.connect(func(_t): _finish_rename())
	_name_edit.focus_exited.connect(_finish_rename)
	who.add_child(_name_edit)
	row.add_child(_button("RENAME", "Ghost", _begin_rename))
	# The lobby connection.
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", box(Color(0, 0, 0, .35), Color(1, 1, 1, .08), 1, 14, 12, 6))
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(pill)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 8)
	pill.add_child(prow)
	_dot = _dot_panel(WARN)
	prow.add_child(_dot)
	_status = _text("", 13, BONE, 600, true, 1)
	prow.add_child(_status)
	_refresh_name()
	return h

func _refresh_name() -> void:
	_name_label.text = net.player_name
	_initial.text = net.player_name.substr(0, 1).to_upper()

func _begin_rename() -> void:
	if session.peer != null:
		note("Change your name before you host or join a game.")
		return
	_name_label.hide()
	_name_edit.text = net.player_name
	_name_edit.show()
	_name_edit.grab_focus()
	_name_edit.select_all()

func _finish_rename() -> void:
	if not _name_edit.visible: return
	_name_edit.hide()
	_name_label.show()
	if not net.set_player_name(_name_edit.text): note("A name needs at least two letters.")
	else: note("You are now %s." % net.player_name)
	_refresh_name()

func _net_status(text: String, ok: bool) -> void:
	if not is_instance_valid(_status): return
	var n: int = net.players.size() + 1
	_status.text = ("ONLINE  •  %d PLAYER%s" % [n, "" if n == 1 else "S"]) if ok else text.to_upper()
	_dot.add_theme_stylebox_override("panel", box(GOOD if ok else (WARN if text.begins_with("Connecting") else Color(.8, .2, .2)), Color(0, 0, 0, 0), 0, 9))
	if ok and _lobby_lines.is_empty():
		_add_lobby("", "You are online as %s. The lobby chat is public: everyone running the game sees it." % net.player_name, false, true)

# ---------------------------------------------------------------- views

func show_view() -> void:
	var want := "room" if session.peer != null else "browse"
	visible = true
	_refresh_name()
	if want != view:
		view = want
		for c in _body.get_children(): c.queue_free()
		for c in _footer_left.get_children(): c.queue_free()
		for c in _footer_right.get_children(): c.queue_free()
		if view == "browse": _build_browse()
		else: _build_room()
		_body.modulate.a = 0.0
		create_tween().tween_property(_body, "modulate:a", 1.0, .2)
	refresh()
	note(session.status)

func refresh() -> void:
	if view == "browse": _refresh_games(); _refresh_online()
	else: refresh_room()
	_net_status("Online" if net.online else "Connecting to the lobby…", net.online)

func note(text: String) -> void:
	if is_instance_valid(_note): _note.text = text

func _net_changed() -> void:
	if not visible: return
	if view == "browse":
		_refresh_games()
		_refresh_online()
	_net_status("Online" if net.online else "Lobby offline. Retrying…", net.online)

# ---------------------------------------------------------------- browse

func _build_browse() -> void:
	_room_sub.text = "CO-OP  •  UP TO FIVE SURVIVORS"
	_room_title.text = "MULTIPLAYER"
	var cols := HBoxContainer.new()
	cols.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cols.add_theme_constant_override("separation", 18)
	_body.add_child(cols)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.75
	left.add_theme_constant_override("separation", 12)
	cols.add_child(left)
	var games: Array = _panel("OPEN GAMES")
	(games[0] as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(games[0])
	_games_count = games[2]
	var head: HBoxContainer = games[3]
	head.add_child(_button("REFRESH", "Ghost", _refresh_pressed))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	(games[1] as VBoxContainer).add_child(columns)
	for spec in [["HOST", 2.2], ["MISSION", 2.0], ["SURVIVORS", 1.3], ["STATUS", 1.1]]:
		var l := _text(spec[0], 11, FAINT, 700, true, 2)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.size_flags_stretch_ratio = spec[1]
		columns.add_child(l)
	var pad := Control.new()
	pad.custom_minimum_size.x = 104
	columns.add_child(pad)
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(games[1] as VBoxContainer).add_child(stack)
	_games = VBoxContainer.new()
	_games.add_theme_constant_override("separation", 6)
	var scroll := _scroll(_games)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(scroll)
	var empty := VBoxContainer.new()
	empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	empty.alignment = BoxContainer.ALIGNMENT_CENTER
	empty.add_theme_constant_override("separation", 6)
	empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(empty)
	var e1 := _text("NO OPEN GAMES RIGHT NOW", 20, DIM, 700, true, 2)
	e1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.add_child(e1)
	var e2 := _text("Host one: everyone online sees it here straight away.", 15, FAINT)
	e2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.add_child(e2)
	_games_empty = empty
	# Host, and the old way in for LAN / VPN.
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	left.add_child(actions)
	actions.add_child(_button("HOST GAME", "Primary", func(): session.host_public(), Vector2(230, 54), 20))
	actions.add_child(_button("JOIN BY ADDRESS", "", _toggle_address, Vector2(0, 54), 15))
	_address_row = HBoxContainer.new()
	_address_row.add_theme_constant_override("separation", 8)
	_address_row.visible = false
	_address_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(_address_row)
	var address := LineEdit.new()
	address.placeholder_text = "Host address (LAN or VPN)"
	address.text = session.address
	address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	address.text_changed.connect(func(v): session.address = v.strip_edges())
	address.text_submitted.connect(func(_v): session.join_game())
	_address_row.add_child(address)
	_address_row.add_child(_button("CONNECT", "", func(): session.join_game(), Vector2(0, 0), 14))
	# Who is online, and the lobby chat.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	cols.add_child(right)
	var online: Array = _panel("ONLINE NOW")
	(online[0] as Control).custom_minimum_size.y = 200
	(online[0] as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
	(online[0] as Control).size_flags_stretch_ratio = .75
	right.add_child(online[0])
	_online_count = online[2]
	_online = VBoxContainer.new()
	_online.add_theme_constant_override("separation", 2)
	(online[1] as VBoxContainer).add_child(_scroll(_online))
	var chat: Array = _panel("LOBBY CHAT", "PUBLIC")
	(chat[0] as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(chat[0])
	var parts: Array = _chat_box("Say something to everyone online…", _say_lobby)
	_lobby_chat = parts[0]
	_lobby_input = parts[2]
	(chat[1] as VBoxContainer).add_child(parts[0])
	(chat[1] as VBoxContainer).add_child(parts[1])
	for line: String in _lobby_lines: _lobby_chat.append_text(line + "\n")
	_footer_left.add_child(_button("‹  BACK", "", func(): session.leave_lobby(), Vector2(120, 46), 15))
	_footer_right.add_child(_text("v" + net.version, 12, FAINT, 500, true, 1))

## From the relay. Our own lines come back from it as well: they were written when sent.
func _lobby_line(who: String, text: String, own: bool, system: bool) -> void:
	if own and not system: return
	_add_lobby(who, text, false, system)

func _add_lobby(who: String, text: String, own: bool, system: bool) -> void:
	var line := ""
	if system: line = _stamp() + "[i][color=#8b8b90]%s[/color][/i]" % escape(text)
	else: line = _stamp() + "[b][color=%s]%s[/color][/b]  %s" % ["#e05050" if own else "#e8c9a0", escape(who), escape(text)]
	_lobby_lines.append(line)
	if _lobby_lines.size() > 120: _lobby_lines.pop_front()
	if is_instance_valid(_lobby_chat) and view == "browse": _lobby_chat.append_text(line + "\n")

func _refresh_games() -> void:
	if not is_instance_valid(_games): return
	for c in _games.get_children(): c.queue_free()
	var list: Array = net.games()
	_games_empty.visible = list.is_empty()
	_games_count.text = "%d LISTED" % list.size() if net.online else "LOBBY OFFLINE"
	for g: Dictionary in list: _games.add_child(_game_row(g))

func _game_row(g: Dictionary) -> Control:
	var row := PanelContainer.new()
	var normal := box(Color(1, 1, 1, .035), Color(1, 1, 1, .05), 1, 3, 14, 10)
	var hot := box(Color(1, 1, 1, .075), Color(ACCENT, .7), 1, 3, 14, 10)
	row.add_theme_stylebox_override("panel", normal)
	row.mouse_entered.connect(func(): row.add_theme_stylebox_override("panel", hot))
	row.mouse_exited.connect(func(): row.add_theme_stylebox_override("panel", normal))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)
	var host := VBoxContainer.new()
	host.add_theme_constant_override("separation", -2)
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_stretch_ratio = 2.2
	h.add_child(host)
	host.add_child(_text(str(g.get("host", "?")), 17, BONE, 600))
	var same: bool = g.get("same_version", true)
	host.add_child(_text("Same version" if same else "Different version", 12, FAINT if same else WARN))
	var mission := _text(str(g.get("mission", "Olivar Family Mart")), 15, DIM)
	mission.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mission.size_flags_stretch_ratio = 2.0
	h.add_child(mission)
	var people := HBoxContainer.new()
	people.add_theme_constant_override("separation", 3)
	people.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	people.size_flags_stretch_ratio = 1.3
	h.add_child(people)
	var humans := int(g.get("p", 1))
	var bots := int(g.get("b", 0))
	for k in 5:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(9, 16)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.add_theme_stylebox_override("panel", box(ACCENT_HI if k < humans else (Color(.35, .45, .6) if k < humans + bots else Color(1, 1, 1, .1)), Color(0, 0, 0, 0), 0, 2, 0, 0))
		people.add_child(pip)
	people.add_child(_text("  %d / 5" % humans, 14, DIM, 600, true))
	var playing := str(g.get("st", "lobby")) != "lobby"
	var state := HBoxContainer.new()
	state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state.size_flags_stretch_ratio = 1.1
	state.add_child(_chip("ON A MISSION" if playing else "IN LOBBY", WARN if playing else GOOD))
	h.add_child(state)
	var why := ""
	if playing: why = "STARTED"
	elif humans >= 5: why = "FULL"
	elif not same: why = "UPDATE"
	var join := _button("JOIN" if why == "" else why, "Primary", func(): session.join_listing(g), Vector2(96, 38), 15)
	join.disabled = why != ""
	if not same: join.tooltip_text = "Both of you need the same version of the game."
	h.add_child(join)
	row.gui_input.connect(_row_input.bind(g, join))
	return row

func _row_input(e: InputEvent, g: Dictionary, join: Button) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).double_click and not join.disabled: session.join_listing(g)

func _refresh_pressed() -> void:
	net.announce()
	_refresh_games()
	note("The list updates by itself as games open and close.")

func _toggle_address() -> void:
	_address_row.visible = not _address_row.visible
	if _address_row.visible: (_address_row.get_child(0) as LineEdit).grab_focus()

func _say_lobby(t: String) -> void:
	if not net.online:
		note("The lobby is offline: the chat will work once it reconnects.")
		return
	net.say(t)
	_add_lobby(net.player_name, t, true, false)

func _refresh_online() -> void:
	if not is_instance_valid(_online): return
	for c in _online.get_children(): c.queue_free()
	var everyone: Array = [[net.player_name + "  (you)", net.state, true]]
	var ids: Array = net.players.keys()
	ids.sort_custom(func(a, b): return str(net.players[a].get("n", "")) < str(net.players[b].get("n", "")))
	for who in ids: everyone.append([str(net.players[who].get("n", "?")), str(net.players[who].get("s", "menu")), false])
	_online_count.text = "%d" % everyone.size() if net.online else "OFFLINE"
	for p: Array in everyone:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		var st: Array = STATE_TEXT.get(p[1], STATE_TEXT.menu)
		r.add_child(_dot_panel(st[1], 8))
		var n := _text(p[0], 15, ACCENT_HI.lightened(.2) if p[2] else BONE, 600 if p[2] else 400)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		n.clip_text = true
		r.add_child(n)
		r.add_child(_text(st[0], 12, FAINT))
		var holder := MarginContainer.new()
		holder.add_theme_constant_override("margin_top", 5)
		holder.add_theme_constant_override("margin_bottom", 5)
		holder.add_child(r)
		_online.add_child(holder)
	if not net.online:
		_online.add_child(_text("Can't reach the lobby. LAN and VPN games still work through Join by address.", 13, FAINT))
		(_online.get_child(-1) as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

# ---------------------------------------------------------------- room

func _build_room() -> void:
	var cols := HBoxContainer.new()
	cols.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cols.add_theme_constant_override("separation", 18)
	_body.add_child(cols)
	var squad: Array = _panel("SQUAD")
	(squad[0] as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(squad[0])
	_squad_count = squad[2]
	_squad = VBoxContainer.new()
	_squad.add_theme_constant_override("separation", 6)
	_squad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(squad[1] as VBoxContainer).add_child(_squad)
	if session.multiplayer.is_server():
		var ai := HBoxContainer.new()
		ai.add_theme_constant_override("separation", 8)
		(squad[1] as VBoxContainer).add_child(ai)
		ai.add_child(_text("SQUAD AI", 11, FAINT, 700, true, 2))
		for spec in [["+ ADD", func(): session.add_bot()], ["FILL", func(): session.fill_bots()], ["− REMOVE", func(): session.remove_bot()]]:
			ai.add_child(_button(spec[0], "", spec[1], Vector2(0, 34), 13))
	else:
		(squad[1] as VBoxContainer).add_child(_text("The host can fill empty places with squad AI.", 13, FAINT))
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 8)
	(squad[1] as VBoxContainer).add_child(modes)
	modes.add_child(_text("MODE", 11, FAINT, 700, true, 2))
	_mode_buttons.clear()
	for key: String in ["easy", "normal", "hard"]:
		var b := _button(str(session.MODES[key].label), "", func(): session.set_mode(key), Vector2(92, 34), 13)
		b.disabled = not session.multiplayer.is_server()
		modes.add_child(b)
		_mode_buttons[key] = b
	_mode_about = _text("", 12, DIM)
	_mode_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	(squad[1] as VBoxContainer).add_child(_mode_about)
	# The survivor: the turning preview and the look.
	var look: Array = _panel("YOUR SURVIVOR")
	cols.add_child(look[0])
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	(look[1] as VBoxContainer).add_child(inner)
	session._build_preview_panel(inner)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 8)
	form.custom_minimum_size.x = 226
	inner.add_child(form)
	session._build_customizer(form, false)
	# The squad's own chat.
	var chat: Array = _panel("SQUAD CHAT", "ONLY YOUR SQUAD")
	(chat[0] as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(chat[0] as Control).size_flags_stretch_ratio = 1.0
	cols.add_child(chat[0])
	var parts: Array = _chat_box("Message squad…", func(t: String): session.send_party(t))
	_party_chat = parts[0]
	_party_input = parts[2]
	(chat[1] as VBoxContainer).add_child(parts[0])
	(chat[1] as VBoxContainer).add_child(parts[1])
	for entry: Array in session.party_log: _party_chat.append_text(_party_text(entry[0], entry[1]) + "\n")
	_footer_left.add_child(_button("‹  LEAVE", "", func(): session.leave_lobby(), Vector2(120, 46), 15))
	if session.multiplayer.is_server():
		_start = _button("START MISSION", "Primary", func(): session.start_game(), Vector2(280, 54), 20)
		_footer_right.add_child(_start)
	else:
		_ready = _button("READY UP", "Primary", func(): session.toggle_ready(), Vector2(240, 54), 20)
		_footer_right.add_child(_ready)

func _party_text(who: String, text: String) -> String:
	if who == "": return _stamp() + "[i][color=#8b8b90]%s[/color][/i]" % escape(text)
	var mine: bool = who == session.display_name(session.local_id())
	return _stamp() + "[b][color=%s]%s[/color][/b]  %s" % ["#e05050" if mine else "#e8c9a0", escape(who), escape(text)]

func add_party_line(who: String, text: String) -> void:
	if is_instance_valid(_party_chat) and view == "room": _party_chat.append_text(_party_text(who, text) + "\n")

func refresh_room() -> void:
	if view != "room" or not is_instance_valid(_squad): return
	var host_name: String = session.display_name(1) if session.team.has(1) else "…"
	_room_sub.text = "MISSION 1  •  %s  •  HOSTED BY %s" % [str(session.MODES[session.mode].label), host_name.to_upper()]
	for key: String in _mode_buttons:
		var b: Button = _mode_buttons[key]
		if is_instance_valid(b): b.theme_type_variation = "Primary" if key == session.mode else ""
	if is_instance_valid(_mode_about):
		_mode_about.text = str(session.MODES[session.mode].about) + ("" if session.multiplayer.is_server() else "  (the host picks)")
	_room_title.text = "OLIVAR FAMILY MART"
	for c in _squad.get_children(): c.queue_free()
	var by_slot := {}
	for id: int in session.team: by_slot[int(session.team[id].slot)] = id
	for slot in 5: _squad.add_child(_slot_card(slot, by_slot.get(slot, null)))
	_squad_count.text = "%d / 5" % session.team.size()
	var waiting: int = session.waiting_count()
	if is_instance_valid(_start):
		_start.disabled = waiting > 0
		_start.text = "START MISSION" if waiting == 0 else "WAITING FOR %d" % waiting
	if is_instance_valid(_ready):
		var on: bool = session.team.has(session.local_id()) and bool(session.team[session.local_id()].get("ready", false))
		_ready.theme_type_variation = "Ready" if on else "Primary"
		_ready.text = "READY  ✓" if on else "READY UP"

func _slot_card(slot: int, id) -> Control:
	var card := PanelContainer.new()
	var filled: bool = id != null
	var p: Dictionary = session.team[id] if filled else {}
	var ready: bool = filled and bool(p.get("ready", false))
	var st := box(Color(1, 1, 1, .045) if filled else Color(1, 1, 1, .015), Color(1, 1, 1, .05), 1, 3, 12, 8)
	st.border_width_left = 4
	st.border_color = (GOOD if ready else Color(.45, .45, .48)) if filled else Color(1, 1, 1, .05)
	card.add_theme_stylebox_override("panel", st)
	card.custom_minimum_size.y = 58
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	card.add_child(h)
	h.add_child(_text("%02d" % (slot + 1), 20, FAINT, 700, true))
	var who := VBoxContainer.new()
	who.add_theme_constant_override("separation", -2)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(who)
	if not filled:
		who.add_child(_text("OPEN", 15, FAINT, 700, true, 2))
		who.add_child(_text("Waiting for a survivor…", 12, Color(1, 1, 1, .25)))
		return card
	var bot: bool = session.is_bot(id)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	who.add_child(line)
	line.add_child(_text(session.NAMES[int(p.slot)] if bot else session.display_name(id), 17, BONE, 600))
	if id == session.local_id(): line.add_child(_chip("YOU", ACCENT_HI))
	if id == 1: line.add_child(_chip("HOST", WARN))
	if bot: line.add_child(_chip("AI", Color(.45, .6, .85)))
	who.add_child(_text("%s  •  %s" % [session.NAMES[int(p.slot)], session._outfit_label(str(p.get("outfit", "default")))], 12, DIM))
	h.add_child(_chip("READY" if ready else "NOT READY", GOOD if ready else Color(.55, .55, .58), ready))
	return card

# ---------------------------------------------------------------- keys

func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		session.leave_lobby()
