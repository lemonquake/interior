extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const RoomBuilder = preload("res://scripts/room_builder.gd")
const BAKED_ROOM := "res://scenes/room/living_room.tscn"
const ObjectScript = preload("res://scripts/physics_object.gd")
const TouchScript = preload("res://scripts/mobile_controls.gd")
const RoomAudioScript = preload("res://scripts/room_audio.gd")
const PropColliders = preload("res://scripts/prop_colliders.gd")
const RoomVisuals = preload("res://scripts/room_visuals.gd")
const EnclosureScript = preload("res://scripts/hamster_enclosure.gd")
const AquariumScript = preload("res://scripts/aquarium.gd")
const RoomSurroundings = preload("res://scripts/room_surroundings.gd")
var player: InteriorPlayer
var touch: InteriorTouchControls
var ui: CanvasLayer
var hud: Control
var menu: PanelContainer
var menu_content: VBoxContainer
var status_label: Label
var prompt: Label
var fps_label: Label
var clue_label: Label
var clues: Array[String] = []
var mobile := false
var solved := false
var started := false
var quality := 0
var current_menu := ""
var time_elapsed := 0.0
var frame_samples: Array[float] = []
var _fps_timer := 0.0
var benchmarking := false
var _last_frame_usec := 0
var control_lab := false
var room_manifest: Dictionary = {}
var _room_lights: Array[OmniLight3D] = []
var room: Node3D
var _benchmark_impulse_timer := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--render-size="):
			var dimensions := argument.trim_prefix("--render-size=").split("x")
			if dimensions.size() == 2:
				get_window().mode = Window.MODE_WINDOWED
				get_window().borderless = true
				get_window().size = Vector2i(clampi(int(dimensions[0]),640,3840),clampi(int(dimensions[1]),360,2160))
	_setup_inputs()
	mobile = OS.has_feature("android") or "--mobile-test" in OS.get_cmdline_user_args()
	benchmarking = "--benchmark" in OS.get_cmdline_user_args()
	control_lab = control_lab or "--control-lab" in OS.get_cmdline_user_args()
	if "--no-balcony" in OS.get_cmdline_user_args() and has_node("Balcony"):
		# Debug switch: proves the closed-door room renders the same without the balcony.
		var balcony := get_node("Balcony")
		remove_child(balcony)
		balcony.free()
	if not control_lab and not _build_living_room():
		control_lab = true
	if control_lab:
		# The control lab replaces the furnished room that main.tscn instances.
		for baked_name in ["LivingRoom", "Balcony"]:
			var baked_room := get_node_or_null(baked_name)
			if baked_room != null:
				remove_child(baked_room)
				baked_room.free()
		_build_control_test_room()
	player = PlayerScript.new()
	player.name = "Player"
	add_child(player)
	player.position = Vector3(0, 0.10, 2.15) if control_lab else _vector(room_manifest.get("spawn", [.62,.10,1.30]))
	player.grabbed.connect(_on_grabbed)
	player.target_changed.connect(_on_target_changed)
	player.console_requested.connect(_show_console)
	_build_ui()
	var room_audio := RoomAudioScript.new()
	room_audio.name = "RoomAudio"
	add_child(room_audio)
	room_audio.setup(self, player)
	var initial_quality := 0 if mobile else 2
	if "--quality-high" in OS.get_cmdline_user_args():
		initial_quality = 2
	elif "--quality-low" in OS.get_cmdline_user_args():
		initial_quality = 0
	_apply_quality(initial_quality)
	if benchmarking:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_show_menu("home")
	if "--autoplay" in OS.get_cmdline_user_args():
		_play()
	if "--capture-menu" in OS.get_cmdline_user_args() or "--capture-play" in OS.get_cmdline_user_args():
		_capture_control_lab.call_deferred()
	if "--capture-review" in OS.get_cmdline_user_args():
		_capture_review.call_deferred()

func _setup_inputs() -> void:
	var actions := {"forward": KEY_W, "back": KEY_S, "left": KEY_A,
		"right": KEY_D, "hold": KEY_E, "run": KEY_SHIFT, "jump": KEY_SPACE,
		"crouch": KEY_C, "pause": KEY_ESCAPE, "journal": KEY_J, "inspect": KEY_F}
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var key := InputEventKey.new()
			key.physical_keycode = actions[action]
			InputMap.action_add_event(action, key)
	if not InputMap.has_action("throw"):
		InputMap.add_action("throw")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("throw", click)

func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material

func _box(parent: Node3D, location: Vector3, dimensions: Vector3, color: Color, collide := true) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	mesh.mesh = box
	mesh.material_override = _mat(color)
	parent.add_child(mesh)
	mesh.position = location
	if collide:
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = dimensions
		shape.shape = box_shape
		parent.add_child(shape)
		shape.position = location
	return mesh

func _vector(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))

func _build_living_room() -> bool:
	room_manifest = RoomBuilder.load_manifest()
	if room_manifest.is_empty():
		return false
	# main.tscn normally contains the baked, editable room scene. Without it, load the
	# baked scene from disk, or assemble the room procedurally as a fallback.
	room = get_node_or_null("LivingRoom") as Node3D
	if room == null and ResourceLoader.exists(BAKED_ROOM):
		room = (load(BAKED_ROOM) as PackedScene).instantiate() as Node3D
		add_child(room)
	if room == null:
		room = Node3D.new()
		room.name = "LivingRoom"
		add_child(room)
		if RoomBuilder.build(room).is_empty():
			return false
	_room_lights.clear()
	for light in get_tree().get_nodes_in_group("room_lights"):
		if light is OmniLight3D and room.is_ancestor_of(light):
			_room_lights.append(light)
	return true

func _build_control_test_room() -> void:
	# A separate control lab. The photographed room cannot be exported before Form approval.
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.15, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.94, 0.86, 0.73)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.light_color = Color(1.0, 0.89, 0.73)
	light.light_energy = 1.0
	light.shadow_enabled = false
	add_child(light)
	var shell := StaticBody3D.new()
	shell.name = "ControlLabShell"
	shell.collision_layer = 2
	shell.collision_mask = 5
	add_child(shell)
	_box(shell, Vector3(0,-0.10,0), Vector3(7,0.20,6), Color(0.62,0.52,0.4))
	for x in [-3.5,3.5]:
		_box(shell, Vector3(x,1.5,0), Vector3(0.2,3,6), Color(0.36,0.29,0.23))
	for z in [-3.0,3.0]:
		_box(shell, Vector3(0,1.5,z), Vector3(7,3,0.2), Color(0.36,0.29,0.23))
	_box(shell, Vector3(0,3.05,0), Vector3(7,0.1,6), Color(0.5,0.46,0.39))
	for i in 3:
		var body := ObjectScript.new() as InteriorObject
		body.name = "Clue" + str(i + 1)
		body.display_name = ["Clock note", "Plant note", "Frame note"][i]
		body.clue_digit = ["5", "0", "8"][i]
		body.clue_text = ["The hour is the first digit: 5.", "The first minute digit is 0.", "The last minute digit is 8."][i]
		body.mass = 0.5
		body.position = Vector3((i - 1) * 1.25, 0.5, -0.5)
		add_child(body)
		_box(body, Vector3.ZERO, Vector3(0.25,0.25,0.25), [Color(0.7,0.26,0.2),Color(0.25,0.5,0.22),Color(0.35,0.3,0.65)][i])
	var chair := ObjectScript.new() as InteriorObject
	chair.name = "HeavyFurniture"
	chair.display_name = "Chair • push or hold"
	chair.mass = 12
	chair.position = Vector3(2.2, 0, -1.4)
	add_child(chair)
	_box(chair, Vector3(0,0.5,0),Vector3(0.7,0.1,0.7),Color(0.19,0.09,0.035))
	_box(chair, Vector3(0,0.85,-0.3),Vector3(0.7,0.7,0.08),Color(0.19,0.09,0.035))
	for x in [-0.28,0.28]:
		for z in [-0.28,0.28]:
			_box(chair,Vector3(x,0.25,z),Vector3(0.06,0.5,0.06),Color(0.19,0.09,0.035))
	var console := StaticBody3D.new()
	console.name = "MysteryConsole"
	console.collision_layer = 2
	console.add_to_group("mystery_console")
	add_child(console)
	_box(console, Vector3(0,1.3,-2.82),Vector3(1.4,0.8,0.10),Color(0.03,0.035,0.03))

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var theme := Theme.new()
	theme.default_font_size = 20
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.24, 0.18, 0.13, 0.96)
	normal.border_color = Color(0.58, 0.43, 0.29)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(7)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 13
	normal.content_margin_bottom = 13
	theme.set_stylebox("normal", "Button", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.38,0.27,0.17)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", hover)
	theme.set_color("font_color", "Label", Color(0.96,0.90,0.79))
	theme.set_color("font_color", "Button", Color(0.96,0.90,0.79))
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.theme = theme
	ui.add_child(hud)
	var dot := Label.new()
	dot.text = "+"
	dot.add_theme_font_size_override("font_size", 26)
	dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	dot.position = Vector2(-7,-16)
	hud.add_child(dot)
	status_label = _label("Find the three notes, then unlock the screen.", 22)
	status_label.position = Vector2(24,24)
	hud.add_child(status_label)
	clue_label = _label("Notes found: 0 / 3", 20)
	clue_label.position = Vector2(24,58)
	hud.add_child(clue_label)
	prompt = _label("", 22)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.position = Vector2(-280,-85)
	prompt.size = Vector2(560,55)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(prompt)
	fps_label = _label("", 18)
	fps_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	fps_label.position = Vector2(-270 if mobile else -170,24)
	fps_label.size = Vector2(140,30)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(fps_label)
	for label in [status_label, clue_label, prompt, fps_label, dot]:
		label.add_theme_color_override("font_outline_color", Color(.06,.04,.025,.95))
		label.add_theme_constant_override("outline_size", 4)
	touch = TouchScript.new()
	touch.player = player
	touch.theme = theme
	ui.add_child(touch)
	touch.hold_pressed.connect(player.toggle_hold)
	touch.throw_pressed.connect(player.throw_object)
	touch.inspect_pressed.connect(player.inspect_object)
	touch.pause_pressed.connect(func(): _show_menu("pause"))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.theme = theme
	ui.add_child(center)
	menu = PanelContainer.new()
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.075,0.055,0.04,0.96)
	panel.set_corner_radius_all(12)
	panel.content_margin_left = 32
	panel.content_margin_right = 32
	panel.content_margin_top = 24
	panel.content_margin_bottom = 24
	menu.add_theme_stylebox_override("panel", panel)
	menu.custom_minimum_size.x = 520
	center.add_child(menu)
	menu_content = VBoxContainer.new()
	menu_content.add_theme_constant_override("separation", 12)
	menu.add_child(menu_content)

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _button(text: String, callable: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 49
	button.pressed.connect(callable)
	menu_content.add_child(button)
	return button

func _show_menu(kind: String) -> void:
	current_menu = kind
	player.playing = false
	player.release_object()
	touch.set_enabled(false)
	hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	for child in menu_content.get_children():
		menu_content.remove_child(child)
		child.queue_free()
	menu.show()
	if kind == "home":
		menu_content.add_child(_label("Interior", 58))
		menu_content.add_child(_label("By Aljay Leodones", 22))
		menu_content.add_child(_label("Control test room" if control_lab else "A physics mystery in a familiar room", 18))
		_button("Play", _play)
	elif kind == "journal":
		menu_content.add_child(_label("Notes", 34))
		for body in get_tree().get_nodes_in_group("movable"):
			if body.discovered:
				menu_content.add_child(_label(body.clue_text, 20))
		if clues.is_empty():
			menu_content.add_child(_label("Hold objects to find the notes.", 20))
		_button("Resume", _play)
	else:
		menu_content.add_child(_label("Pause", 34))
		_button("Resume", _play)
		_button("Notes", func(): _show_menu("journal"))
		_button("Restart", _restart)
	var quality_select := OptionButton.new()
	for label in ["Graphics: Low", "Graphics: Medium", "Graphics: High"] + ([] if mobile else ["Graphics: Ultra"]):
		quality_select.add_item(label)
	quality_select.selected = quality
	quality_select.custom_minimum_size.y = 49
	quality_select.item_selected.connect(_apply_quality)
	menu_content.add_child(quality_select)
	menu_content.add_child(_label("Drag left to move • drag right to look\nSprint • Jump • Crouch • Hold / Drop • Throw\nInspect to open the TV screen" if mobile else "WASD move • Shift sprint • Space jump • C crouch\nMouse look • E hold / drop • Left click throw\nF inspect • J notes • Esc pause", 18))
	if not mobile:
		_button("Quit", func(): get_tree().quit())

func _play() -> void:
	started = true
	menu.hide()
	hud.show()
	get_tree().paused = false
	player.playing = true
	touch.set_enabled(mobile)
	if not mobile:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _apply_quality(index: int) -> void:
	# Tiers: 0 Low, 1 Medium, 2 High (desktop default), 3 Ultra (desktop only).
	quality = clampi(index, 0, 2 if mobile else 3)
	Engine.max_fps = 60 if mobile else 120
	var lighting := InteriorLighting.find_in(room) if room != null else null
	if lighting != null:
		lighting.mobile = mobile
		lighting.apply_quality(quality)
	else:
		get_viewport().msaa_3d = [Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X,Viewport.MSAA_4X][quality]
		get_viewport().scaling_3d_scale = [0.65,0.85,1.0][quality] if mobile else [0.75,1.0,1.0,1.0][quality]
		get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	for light in _room_lights:
		light.shadow_enabled = quality >= 2 and not mobile
	RoomVisuals.apply_quality(self, quality, mobile)

func _on_grabbed(body: InteriorObject) -> void:
	if body.clue_digit.is_empty() or body.discovered:
		return
	body.discovered = true
	clues.append(body.clue_digit)
	clue_label.text = "Notes found: %d / 3" % clues.size()
	status_label.text = body.clue_text
	if clues.size() == 3:
		status_label.text = "All notes found. Inspect the TV and enter the time."

func _on_target_changed(body: InteriorObject) -> void:
	prompt.text = (("Hold / Drop • " if mobile else "E • Hold ") + body.display_name) if body != null else ""
	if body == null and player != null and is_instance_valid(player.door_target):
		prompt.text = ("Hold / Drop • " if mobile else "E • ") + str(player.door_target.call("prompt_text"))
	if body != null and body.is_in_group("mystery_console"):
		prompt.text += "     Inspect" if mobile else "     F • Inspect"

func _show_console() -> void:
	_show_menu("pause")
	for child in menu_content.get_children():
		menu_content.remove_child(child)
		child.queue_free()
	menu_content.add_child(_label("Screen lock", 34))
	menu_content.add_child(_label("Enter the three digits from the room’s clock.", 20))
	var entry := LineEdit.new()
	entry.placeholder_text = "3-digit code"
	entry.max_length = 3
	entry.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	entry.custom_minimum_size.y = 54
	menu_content.add_child(entry)
	var result := _label("", 20)
	menu_content.add_child(result)
	_button("Unlock", func(): result.text = try_unlock(entry.text))
	_button("Resume", _play)
	entry.grab_focus()

func try_unlock(code: String) -> String:
	if code == "508" and clues.size() == 3:
		solved = true
		status_label.text = "Mystery solved • continue exploring the room."
		return "Mystery solved. The missing recording is safe."
	if clues.size() < 3:
		return "Find all three notes first."
	return "Try the digits from the clock notes."

func _capture_control_lab() -> void:
	await get_tree().create_timer(3.0).timeout
	await RenderingServer.frame_post_draw
	var prefix := "control-lab" if control_lab else "living-room"
	if mobile:
		prefix += "-mobile"
	var filename := prefix + ("-play.png" if player.playing else "-menu.png")
	var capture_directory := ProjectSettings.globalize_path("res://../room/runtime")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-path="):
			capture_directory = argument.trim_prefix("--capture-path=")
	DirAccess.make_dir_recursive_absolute(capture_directory)
	var path := capture_directory.path_join(filename)
	var image := get_viewport().get_texture().get_image()
	var saved := image.save_png(path)
	if saved != OK:
		push_error("Could not save runtime capture: " + str(saved))
		get_tree().quit(1)
		return
	print("INTERIOR_CAPTURE ", path)
	get_tree().quit()

func _capture_review() -> void:
	var directory := ProjectSettings.globalize_path("res://../work/lemondev/2026-10-05/captures")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-path="):
			directory = argument.trim_prefix("--capture-path=")
	DirAccess.make_dir_recursive_absolute(directory)
	var only_balcony := "--capture-views=balcony" in OS.get_cmdline_user_args()
	await get_tree().create_timer(2.0).timeout
	if not only_balcony:
		await _save_review_image(directory, "home")
	_play()
	await get_tree().create_timer(1.0).timeout
	if not only_balcony:
		await _save_review_image(directory, "play")
	player.playing = false
	hud.hide()
	await _capture_balcony_views(directory)
	if only_balcony:
		print("INTERIOR_REVIEW_CAPTURE ",directory)
		get_tree().quit()
		return
	var views := [
		["room-wide", Vector3(.62,1.58,1.30), Vector3(-.20,1.30,-2.35)],
		["sofa-surfaces", Vector3(.10,1.55,.20), Vector3(-2.05,.65,.40)],
		["table-surfaces", Vector3(.75,1.35,.30), Vector3(-.30,.80,.30)],
		["wall-and-photos", Vector3(.20,1.58,-.90), Vector3(.45,1.80,-2.58)],
		["room-reverse", Vector3(.75,1.58,-1.30), Vector3(-.30,1.20,2.70)],
		["kitchen", Vector3(-2.3,1.6,1.70), Vector3(-5.15,1.20,-.25)],
		["right-wall", Vector3(-.25,1.58,.35), Vector3(3.25,1.42,.30)]
	]
	for view in views:
		player.camera.global_position = view[1]
		player.camera.look_at(view[2])
		await get_tree().create_timer(.3).timeout
		await _save_review_image(directory, view[0])
	var enclosure := find_child("pet_enclosure_11", true, false) as Node3D
	if enclosure != null:
		player.camera.global_position = enclosure.to_global(Vector3(.10,1.20,1.18))
		player.camera.look_at(enclosure.to_global(Vector3(0,1.06,0)))
		await get_tree().create_timer(.5).timeout
		for i in 4:
			await _save_review_image(directory, "hamsters-" + str(i))
			await get_tree().create_timer(1.5).timeout
		player.camera.global_position = enclosure.to_global(Vector3(-.5,.46,.67))
		player.camera.look_at(enclosure.to_global(Vector3(0,.30,0)))
		await get_tree().create_timer(.3).timeout
		await _save_review_image(directory,"aquariums")
	_show_menu("pause")
	await _save_review_image(directory, "pause")
	_show_menu("journal")
	await _save_review_image(directory, "notes")
	print("INTERIOR_REVIEW_CAPTURE ",directory)
	get_tree().quit()

## Views matching the owner's door / balcony / stair photos (work/v4/reference/1..5).
const BALCONY_VIEWS := [
	["balcony-1-door-closed", Vector3(1.75,1.58,.95), Vector3(1.85,1.25,2.7), false, 75.0],
	["balcony-2-door-open", Vector3(2.15,1.55,1.0), Vector3(1.55,1.15,3.6), true, 75.0],
	["balcony-3-aquarium-wall", Vector3(3.45,1.5,4.05), Vector3(.95,1.2,3.72), true, 62.0],
	["balcony-4-toward-stairs", Vector3(2.7,1.55,3.6), Vector3(8.6,-1.0,3.4), true, 62.0],
	["balcony-5-stairs-down", Vector3(5.25,1.5,3.3), Vector3(8.6,-1.9,3.55), true, 62.0],
	["balcony-6-courtyard-up", Vector3(12.0,-1.35,4.35), Vector3(7.2,-.4,3.4), true, 62.0],
]

func _capture_balcony_views(directory: String) -> void:
	var doors := get_tree().get_nodes_in_group("interior_doors")
	if doors.is_empty():
		return
	var door := doors[0] as InteriorHingedDoor
	var fov := player.camera.fov
	for view in BALCONY_VIEWS:
		# Outdoor views use a narrower, phone-like field of view to match the photos.
		player.camera.fov = view[4]
		if view[3] != door.is_open():
			door.toggle()
			await get_tree().create_timer(door.swing_seconds + .25).timeout
		player.camera.global_position = view[1]
		player.camera.look_at(view[2])
		await get_tree().create_timer(.35).timeout
		await _save_review_image(directory, view[0])
	player.camera.fov = fov
	door.snap(false)

func _save_review_image(directory: String, label: String) -> void:
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))
	if result != OK:
		push_error("Review capture failed: " + label)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and started:
		if player.playing:
			_show_menu("pause")
		else:
			_play()
	if event.is_action_pressed("journal") and player.playing:
		_show_menu("journal")

func _process(delta: float) -> void:
	if not started or not player.playing:
		_last_frame_usec = 0
		return
	var now_usec := Time.get_ticks_usec()
	var frame_ms := float(now_usec - _last_frame_usec) / 1000.0 if _last_frame_usec > 0 else 0.0
	_last_frame_usec = now_usec
	time_elapsed += delta
	_fps_timer += delta
	if benchmarking and not control_lab:
		# Sweep the full room and keep sixteen furnishing bodies awake.
		player.rotate_y(delta * .24)
		_benchmark_impulse_timer += delta
		if _benchmark_impulse_timer >= 1.5:
			_benchmark_impulse_timer = 0.0
			var active := 0
			for body in get_tree().get_nodes_in_group("movable"):
				if not body.anchored and active < 16:
					body.activate()
					body.apply_central_impulse(Vector3(.03,.14,.02) * body.mass)
					active += 1
	if benchmarking and time_elapsed > 2.0 and frame_ms > 0.0:
		frame_samples.append(frame_ms)
	if _fps_timer > 0.5:
		_fps_timer = 0
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	if player.held != null:
		prompt.text = ("Hold / Drop • drop     Throw • throw" if mobile else "E • Drop     Left click • Throw")
	else:
		_on_target_changed(player.target)
	if benchmarking and time_elapsed > 62:
		frame_samples.sort()
		var slow_frames := 0
		for sample in frame_samples:
			if sample > 16.67:
				slow_frames += 1
		var report := {"scene":"control-lab" if control_lab else "living-room", "scenario":"camera sweep and sixteen active bodies with three animated hamsters" if not control_lab else "stationary control lab", "warmup_seconds":2,"sample_seconds":60,"frames":frame_samples.size(),"renderer":RenderingServer.get_video_adapter_name(),"logical_viewport":str(get_viewport().get_visible_rect().size),"window_pixels":str(get_window().size),"render_scale":get_viewport().scaling_3d_scale,"quality":quality,"median_frame_ms":frame_samples[frame_samples.size()/2],"p95_frame_ms":frame_samples[int(frame_samples.size()*.95)],"p99_frame_ms":frame_samples[int(frame_samples.size()*.99)],"max_frame_ms":frame_samples[-1],"frames_above_16_67ms":slow_frames,"mobile_controls":mobile,"objects":get_tree().get_nodes_in_group("movable").size()}
		print("INTERIOR_BENCHMARK ",JSON.stringify(report))
		get_tree().quit()
