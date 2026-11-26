extends Node
## 0.40: the squad's voices. Every survivor has their own voice for each line of assets/audio/voices/lines.json
## (made by tools/squad_voices.py: ElevenLabs, or Windows placeholder voices until a key is given). A line is heard
## from where the speaker stands, and written in the radio feed at the lower left.
## `~` opens the voice menu for the player's own lines: 1-9 and 0 for the first ten, Shift with a number for the
## rest. Some lines are orders the squad AI follows (scripts/coop/bots.gd `heard`).
const MANIFEST := "res://assets/audio/voices/lines.json"
const FEED_LINES := 5
const FEED_TIME := 6.0
var session
var lines := {}
var menu: Array = []
var _streams := {}
var feed: VBoxContainer
var panel: PanelContainer
var open := false
var own_voice := AudioStreamPlayer.new()
var _cooldown := 0

func setup(owner_session) -> void:
	session = owner_session
	name = "Voices"
	var text := FileAccess.get_file_as_string(MANIFEST)
	var data: Variant = JSON.parse_string(text) if text != "" else null
	if data is Dictionary:
		lines = data.get("lines",{})
		menu = data.get("menu",[])
	own_voice.volume_db = -1.0
	add_child(own_voice)

func takes(key: String) -> int:
	return (lines.get(key,[]) as Array).size()

func words(key: String, take: int) -> String:
	var all: Array = lines.get(key,[])
	return str(all[clampi(take,0,all.size()-1)]) if not all.is_empty() else key

func stream(who: String, key: String, take: int) -> AudioStream:
	var id := "%s/%s_%d"%[who.to_lower(),key,take+1]
	if not _streams.has(id):
		var found: AudioStream = null
		for ext in [".mp3",".ogg",".wav"]:
			var path: String = "res://assets/audio/voices/"+id+ext
			if ResourceLoader.exists(path):
				found = load(path)
				break
		_streams[id] = found
	return _streams[id]

## Warm the clips of everyone in the squad, a few a frame, so the first callout never stalls a frame.
func warm(names: Array) -> void:
	var n := 0
	for who: String in names:
		for key: String in lines:
			for take in takes(key):
				stream(who,key,take)
				n += 1
				if n%6==0: await get_tree().process_frame

func build_hud(hud: Control) -> void:
	feed = VBoxContainer.new()
	feed.name = "RadioFeed"
	feed.add_theme_constant_override("separation",2)
	feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(feed)
	feed.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	feed.offset_left = 24
	# Above the dialogue box (session.gd: its top is 197 px up from the bottom).
	feed.offset_bottom = -212
	feed.offset_top = -212-FEED_LINES*20
	feed.offset_right = 460
	feed.alignment = BoxContainer.ALIGNMENT_END
	panel = PanelContainer.new()
	panel.name = "VoiceMenu"
	var back := StyleBoxFlat.new()
	back.bg_color = Color(.03,.035,.04,.86)
	back.border_color = Color(.55,.41,.27,.8)
	back.set_border_width_all(1)
	back.set_corner_radius_all(6)
	back.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel",back)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",1)
	panel.add_child(column)
	column.add_child(_row("Voice   ~",14,Color(.96,.9,.79)))
	for i in menu.size():
		var key_name := str((i+1)%10) if i<10 else "⇧"+str((i-9)%10)
		column.add_child(_row("%s   %s"%[key_name,str(menu[i][1])],13,Color(.93,.88,.8)))
	panel.hide()
	get_viewport().size_changed.connect(_place)
	_place.call_deferred()

func _place() -> void:
	if panel==null or not panel.is_inside_tree(): return
	var size := panel.get_combined_minimum_size()
	var bounds := panel.get_viewport_rect().size
	panel.size = size
	# On the right, clear of the objective lines, the radio feed and the dialogue.
	panel.position = Vector2(bounds.x-size.x-24,minf((bounds.y-size.y)*.5,bounds.y-size.y-120)).round()

func _row(text: String, font: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",font)
	label.add_theme_color_override("font_color",colour)
	label.add_theme_constant_override("outline_size",4)
	label.add_theme_color_override("font_outline_color",Color(0,0,0,.8))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## Someone said `key` (take `take`): heard from where they stand, written in the feed.
func play(id: int, key: String, take: int) -> void:
	if not session.team.has(id): return
	var p: Dictionary = session.team[id]
	var who: String = session.NAMES[p.slot]
	var clip := stream(who,key,take)
	# 0.60: a survivor voiced on ElevenLabs with only the first take of a line says that take (the robot-voice
	# placeholders are gone), with its own words in the feed.
	if clip==null and take>0:
		take = 0
		clip = stream(who,key,take)
	if id==session.local_id():
		own_voice.stream = clip
		if clip!=null: own_voice.play()
	elif session.avatars.has(id):
		session.avatars[id].say(clip)
	_post(who+(" (AI)" if session.is_bot(id) else ""),words(key,take),session.is_bot(id))

func _post(who: String, text: String, bot: bool) -> void:
	if feed==null: return
	var label := _row("%s:  %s"%[who,text],13,Color(.72,.86,1.0) if bot else Color(1.0,.92,.72))
	feed.add_child(label)
	while feed.get_child_count()>FEED_LINES: feed.get_child(0).free()
	var fade := label.create_tween()
	fade.tween_interval(FEED_TIME)
	fade.tween_property(label,"modulate:a",0.0,.8)
	fade.tween_callback(label.queue_free)

func _input(event: InputEvent) -> void:
	if not session.active or session.local_menu or session.last_results or session.chatting: return
	if not (event is InputEventKey) or not event.pressed or event.echo: return
	var key: Key = (event as InputEventKey).physical_keycode
	if key==KEY_QUOTELEFT:
		open = not open
		panel.visible = open
		_place()
		get_viewport().set_input_as_handled()
		return
	if not open: return
	if key==KEY_ESCAPE:
		open = false
		panel.hide()
		get_viewport().set_input_as_handled()
		return
	if key>=KEY_0 and key<=KEY_9:
		var index := (int(key)-int(KEY_1)) if key!=KEY_0 else 9
		if (event as InputEventKey).shift_pressed: index += 10
		get_viewport().set_input_as_handled()
		if index<menu.size():
			open = false
			panel.hide()
			if Time.get_ticks_msec()>=_cooldown:
				_cooldown = Time.get_ticks_msec()+900
				session.player_line(str(menu[index][0]))
