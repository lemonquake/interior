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
const NightAudioScript = preload("res://scripts/night_audio.gd")
const StrangerScript = preload("res://scripts/stranger.gd")
const StoryScript = preload("res://scripts/story.gd")
const AtmosphereScript = preload("res://scripts/atmosphere.gd")
const AtmosphereParticlesScript = preload("res://scripts/atmosphere_particles.gd")
var coop: Node
var grenades: InteriorGrenades
var player: InteriorPlayer
var touch: InteriorTouchControls
var ui: CanvasLayer
var hud: Control
var menu: PanelContainer
var menu_content: VBoxContainer
var status_label: Label
var prompt: Label
## 0.23: shown in the prompt line while nothing is targeted (scripts/town_siege.gd sets it at the hole).
var context_prompt := ""
var fps_label: Label
var clue_label: Label
var clues: Array[String] = []
var mobile := false
## 0.32: a review capture is running: the window takes no focus and no mouse, so it can run while the PC is in use.
var capturing := false
var solved := false
var started := false
var quality := 0
var camera_motion := 0
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
var story: InteriorStory
## 0.28: the infected (scripts/zombies.gd); the debug menu spawns them.
var zombies: InteriorZombies
var senses: InteriorSenses
## 0.34: the window panes that break (scripts/window_glass.gd).
var glass: InteriorWindowGlass
var body: InteriorBody
var sound_stage: InteriorSoundStage
var atmosphere: Node
var atmosphere_particles: Node3D
var _benchmark_impulse_timer := 0.0
var menu_street: Node3D
var menu_shade: ColorRect
## 0.31: what is on the main screen (assets/ui/menu_blood.png), and the wet edge along the top of a window.
var menu_blood: TextureRect
var menu_drip: TextureRect
## 0.54: the menus' cursor, a flashlight's pool on the chosen button (scripts/ui_menu.gd).
var menu_light: SleepMenu.MenuLight
var _options_return := "home"
var mobile_performance: Node
## Head bob (Options): Default, Low (a further 25 % less), Off.
const MOTION_LEVELS := [1.0, .75, 0.0]
## 0.26 desktop frame-rate keeper (scripts/performance.gd).
var performance: InteriorPerformance
## 0.26 body camera lens and its reactions (scripts/bodycam.gd).
var bodycam: InteriorBodycam
## 0.30: true while the world is still being built behind the loading screen (scripts/boot.gd).
var _booting := false

func _ready() -> void:
	if InteriorLoadClock.staged:
		# Behind the loading screen (scripts/boot.gd) the districts go up over several frames: wait for them.
		_booting = true
		var town := get_node_or_null("Balcony/Neighbourhood")
		while town != null and town.get("built") == false:
			await get_tree().process_frame
	InteriorLoadClock.mark("interior: start")
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
	if mobile:
		get_tree().quit_on_go_back = false
		# 0.64: a frame that runs long catches up at most three physics steps (60 a second, as always), so one heavy
		# moment slows the game for an instant instead of every frame doing eight steps and running longer still.
		Engine.max_physics_steps_per_frame = 3
		# (A phone fills a wide screen: project.godot `aspect.mobile`. A `--mobile-test` run on a PC does the same.)
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
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
		for baked_name in ["LivingRoom", "Balcony", "Fields"]:
			var baked_room := get_node_or_null(baked_name)
			if baked_room != null:
				remove_child(baked_room)
				baked_room.free()
		_build_control_test_room()
	if not control_lab:
		_setup_living_props()
		# Night (0.7): the kitchen window shows the night; the room keeps its own lamps.
		InteriorNight.apply_room(room)
	InteriorLoadClock.mark("interior: living room")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	player = PlayerScript.new()
	player.name = "Player"
	add_child(player)
	player.position = Vector3(0, 0.10, 2.15) if control_lab else _vector(room_manifest.get("spawn", [.62,.10,1.30]))
	player.grabbed.connect(_on_grabbed)
	player.target_changed.connect(_on_target_changed)
	player.console_requested.connect(_show_console)
	InteriorLoadClock.mark("interior: player")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_build_ui()
	var room_audio := RoomAudioScript.new()
	room_audio.name = "RoomAudio"
	add_child(room_audio)
	room_audio.setup(self, player)
	var night_audio := NightAudioScript.new()
	night_audio.name = "NightAudio"
	add_child(night_audio)
	night_audio.setup(self, player)
	InteriorLoadClock.mark("interior: ui and audio")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	if not control_lab and has_node("Balcony") and not "--no-stranger" in OS.get_cmdline_user_args():
		# 0.9: the man in the black hoodie at the courtyard gate (scripts/stranger.gd).
		add_child(StrangerScript.new())
	InteriorLoadClock.mark("interior: stranger")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	if not control_lab and has_node("Fields") and not "--no-hut" in OS.get_cmdline_user_args():
		# 0.10: the bahay kubo becomes a house with the key, the drawer and the Glock (scripts/story.gd).
		var hut := InteriorHutHouse.attach(get_node("Fields") as Node3D)
		if hut != null:
			story = StoryScript.new()
			add_child(story)
			story.setup(self, hut)
	InteriorLoadClock.mark("interior: hut and story")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	if not control_lab and has_node("Balcony") and not "--no-home-exterior" in OS.get_cmdline_user_args():
		# 0.26: the house the rooms belong to, seen from outside (scripts/home_exterior.gd).
		InteriorHomeExterior.attach(get_node("Balcony") as Node3D)
	InteriorLoadClock.mark("interior: home exterior")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	if not control_lab:
		atmosphere = AtmosphereScript.new()
		atmosphere.name = "Atmosphere"
		add_child(atmosphere)
		atmosphere.setup(self, player)
		atmosphere_particles = AtmosphereParticlesScript.new()
		atmosphere_particles.name = "AtmosphereParticles"
		add_child(atmosphere_particles)
		atmosphere_particles.setup(self, player)
		bodycam = InteriorBodycam.new()
		add_child(bodycam)
		bodycam.setup(self, player)
	InteriorLoadClock.mark("interior: atmosphere and lens")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	# 0.43: Low is the default on every machine; a level picked in Options is kept in user://settings.cfg.
	var initial_quality := 0 if mobile else int(GameSettings.get_value("quality", 0))
	# Test scripts (`--script`) were all written against the old High default; they keep it.
	if not mobile and ("--script" in OS.get_cmdline_args() or "-s" in OS.get_cmdline_args()):
		initial_quality = 2
	if "--quality-high" in OS.get_cmdline_user_args():
		initial_quality = 2
	elif "--quality-low" in OS.get_cmdline_user_args():
		initial_quality = 0
	_apply_quality(initial_quality)
	if benchmarking:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	InteriorLoadClock.mark("interior: quality")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	if not control_lab:
		senses = InteriorSenses.new()
		add_child(senses)
		senses.setup(self)
		glass = InteriorWindowGlass.new()
		add_child(glass)
		glass.setup(self)
		zombies = InteriorZombies.new()
		add_child(zombies)
		zombies.setup(self)
		body = InteriorBody.new()
		add_child(body)
		body.setup(self)
		sound_stage = InteriorSoundStage.new()
		add_child(sound_stage)
		sound_stage.setup(self)
		# 0.43: frag grenades (scripts/grenade.gd), 5.
		grenades = InteriorGrenades.new()
		add_child(grenades)
		grenades.setup(self)
	InteriorLoadClock.mark("interior: zombies")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	# 0.20: Q W E R T Y opens the debug menu (scripts/debug_menu.gd).
	var debug_menu := InteriorDebugMenu.new()
	add_child(debug_menu)
	debug_menu.setup(self)
	InteriorLoadClock.mark("interior: debug menu")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	if not control_lab:
		menu_street = preload("res://scripts/menu_neighborhood.gd").new()
		add_child(menu_street)
		menu_street.setup(self)
	if mobile and not "--no-mobile-budget" in OS.get_cmdline_user_args():
		mobile_performance = preload("res://scripts/mobile_performance.gd").new()
		add_child(mobile_performance)
		mobile_performance.setup(self)
	# 0.65: the town's infected read while a menu is open (scripts/phone_warm.gd).
	if (OS.has_feature("android") or "--phone-warm" in OS.get_cmdline_user_args()) and not control_lab:
		var warm := preload("res://scripts/phone_warm.gd").new()
		add_child(warm)
		warm.setup(self)
	# 0.64: on phones too (zones, trees, light fades, a render scale that keeps the frame rate).
	if not control_lab:
		performance = InteriorPerformance.new()
		performance.mobile = mobile
		add_child(performance)
		performance.setup(self)
		performance.frame_cap = int(GameSettings.get_value("frame_cap", performance.frame_cap))
		performance.apply_quality(quality)
	camera_motion = clampi(int(GameSettings.get_value("head_bob", camera_motion)), 0, 2)
	if is_instance_valid(player):
		player.camera_motion = MOTION_LEVELS[camera_motion]
	InteriorLoadClock.mark("interior: menu street and performance")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	# 0.64: phones play the squad game too (it was PC only).
	if not control_lab:
		coop = preload("res://scripts/coop/session.gd").new()
		coop.name = "Coop"
		add_child(coop)
		coop.setup(self)
	_show_menu("home")
	if "--autoplay" in OS.get_cmdline_user_args():
		_play()
	elif InteriorLoadClock.wish != "":
		# 0.35: asked for at the menu on the loading screen, before any of this stood.
		_early_wish(InteriorLoadClock.wish)
	InteriorLoadClock.wish = ""
	InteriorLoadClock.wish_ready = _early_wish
	InteriorLoadClock.mark("interior: done")
	_booting = false
	InteriorLoadClock.finish()
	if "--performance-audit" in OS.get_cmdline_user_args() or (OS.has_feature("android") and OS.is_debug_build() and FileAccess.file_exists("user://performance-audit.json")):
		var audit := preload("res://scripts/performance_audit.gd").new()
		add_child(audit)
		audit.start.call_deferred(self)
	if "--capture-menu" in OS.get_cmdline_user_args() or "--capture-play" in OS.get_cmdline_user_args():
		_capture_control_lab.call_deferred()
	if "--capture-review" in OS.get_cmdline_user_args():
		_capture_review.call_deferred()
	if "--capture-menus" in OS.get_cmdline_user_args():
		_capture_menus.call_deferred()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-menu-still="):
			_capture_menu_still.call_deferred(argument.trim_prefix("--capture-menu-still="))
		# 0.49: straight into a co-op mission (`-- --coop-jump=mart`, see _coop_jump_start).
		if argument.begins_with("--coop-jump="):
			_coop_jump_start.call_deferred(argument.trim_prefix("--coop-jump="))

## 0.49: straight into a co-op mission from the command line, the menu skipped:
##   Interior.exe -- --coop-jump=mart [--coop-bots=2] [--coop-mode=easy|normal|hard]
## hosts a game, adds the squad AI, starts it and jumps there (coop/mission.gd JUMPS: dodong, escort, keys, ramp,
## gate, storeroad, mart, siege, office, jonna, board, backdoor, backstreets, arcade, brickalley, school, lobby,
## floor2 .. floor5, teves, horde, sneak, firedoor, blast, room208, field, heavyarm, heavykey, reargate, pilcstout; or a
## stage number 0-15). Everything before the place is finished as play leaves it (0.55). The same jump is in the
## debug menu (Q W E R T Y, Missions) and its command line.
func _coop_jump_start(place: String) -> void:
	if coop == null:
		return
	for i in 10:
		await get_tree().process_frame
	var bots := 0
	var mode := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--coop-bots="):
			bots = clampi(int(a.trim_prefix("--coop-bots=")), 0, 4)
		elif a.begins_with("--coop-mode="):
			mode = a.trim_prefix("--coop-mode=")
	coop.host()
	if mode != "":
		coop.set_mode(mode)
	for i in bots:
		coop.add_bot()
	coop.start_game()
	for i in 30:
		await get_tree().physics_frame
	var reply: String = coop.mission.debug_command(1, "jump " + place)
	coop.personal(1, reply)
	print("INTERIOR_COOP_JUMP ", reply)
	# (`--coop-jump-capture=<dir>`: a picture of where it landed, then quit; for checking the built game.)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--coop-jump-capture="):
			for i in 90:
				await get_tree().process_frame
			# (0.63: past the chapter screen a jump into another chapter puts up: the picture is of the place.)
			for i in 900:
				var cs = coop.get("_chapter_screen")
				if coop.get("_catching") != true and (cs == null or not cs.visible): break
				await get_tree().process_frame
			for i in 30:
				await get_tree().process_frame
			await _save_review_image(a.trim_prefix("--coop-jump-capture="), "coop_jump_" + place)
			get_tree().quit()

## 0.35: a button of the menu on the loading screen (scripts/loading_screen.gd).
func _early_wish(what: String) -> void:
	if started:
		return
	InteriorLoadClock.mark("menu: '%s' (pressed on the loading screen)" % what)
	if what == "play" and coop == null:
		_play()
	elif what in ["play", "multiplayer"] and coop != null:
		coop.page()
	elif what == "options":
		_show_menu("options")

## `-- --capture-menu-still=<file.jpg>`: the home menu's street with the title and the buttons taken off. The
## loading screen shows it under its own title and buttons (tools/menu_still.py, run by tools/export_windows.py).
func _capture_menu_still(path: String) -> void:
	for i in 90:
		await get_tree().process_frame
	menu.hide()
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	var error := image.save_jpg(path, .93)
	print("INTERIOR_MENU_STILL ", image.get_size(), " error ", error, " ", path)
	get_tree().quit()

func _setup_inputs() -> void:
	var actions := {"forward": KEY_W, "back": KEY_S, "left": KEY_A,
		"right": KEY_D, "hold": KEY_E, "run": KEY_SHIFT, "jump": KEY_SPACE,
		"crouch": KEY_C, "pause": KEY_ESCAPE, "journal": KEY_J, "inspect": KEY_F, "channel": KEY_Q,
		# 0.33: Ctrl walks slowly and quietly, Z / X lean, V shoves, H binds a wound. (0.48: T shoves.)
		"sneak": KEY_CTRL, "lean_left": KEY_Z, "lean_right": KEY_X, "shove": KEY_T, "heal": KEY_H}
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
	# 0.11: the Glock (scripts/gun.gd): left click fires while it is drawn, R reloads, 1 or G draws / holsters.
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
		var shot := InputEventMouseButton.new()
		shot.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire", shot)
	# 0.26: the right mouse button brings the pistol's sights up (scripts/gun.gd).
	if not InputMap.has_action("aim"):
		InputMap.add_action("aim")
		var sights := InputEventMouseButton.new()
		sights.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("aim", sights)
	# 0.12: L switches the flashlight on and off (scripts/flashlight.gd).
	# 0.27: 2 brings up the secret rifle once the debug menu has given it, B is its fire selector.
	for spec in [["reload", [KEY_R]], ["gun", [KEY_1, KEY_G]], ["flashlight", [KEY_L]], ["rifle", [KEY_2]], ["fire_mode", [KEY_B]], ["shotgun", [KEY_3]], ["sniper", [KEY_4]], ["grenade", [KEY_5]]]:
		if not InputMap.has_action(spec[0]):
			InputMap.add_action(spec[0])
			for code in spec[1]:
				var key := InputEventKey.new()
				key.physical_keycode = code
				InputMap.action_add_event(spec[0], key)

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

## The TV turns on instead of being carried, and the digital clock shows nonsense times.
func _setup_living_props() -> void:
	var locked_door := room.get_node_or_null("LockedClosetDoor")
	if locked_door != null:
		locked_door.tried_locked_door.connect(_on_locked_room_door)
	for body in get_tree().get_nodes_in_group("movable"):
		var object := body as InteriorObject
		if object == null or (room != null and not room.is_ancestor_of(object)):
			continue
		if object.prop_id.begins_with("television"):
			InteriorTelevision.attach(object)
		elif object.prop_id.begins_with("digital_clock"):
			InteriorGlitchClock.attach(object)

func _on_locked_room_door() -> void:
	if is_instance_valid(story) and not story.ui.dialogue_active():
		story.ui.say("You", ["It's.. locked? Weird."], 0.0)

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
	dot.name = "Crosshair"
	# 0.26: a faint mark only; it goes away while the pistol is up (the muzzle is the aim then).
	dot.modulate.a = .55
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
	fps_label.visible = benchmarking or "--show-fps" in OS.get_cmdline_user_args()
	hud.add_child(fps_label)
	for label in [status_label, clue_label, prompt, fps_label, dot]:
		label.add_theme_color_override("font_outline_color", Color(.06,.04,.025,.95))
		label.add_theme_constant_override("outline_size", 4)
	touch = TouchScript.new()
	touch.player = player
	touch.main = self
	touch.theme = theme
	ui.add_child(touch)
	touch.hold_pressed.connect(player.hold_pressed)
	touch.hold_released.connect(player.hold_released)
	touch.throw_pressed.connect(player.touch_throw)
	touch.inspect_pressed.connect(func():
		if story != null and story.gun.drawn:
			story.inspect_carried_gun()
		else:
			player.inspect_object())
	# 0.64: in the squad game Pause is its own pause (the game goes on for the others), as Esc is there.
	touch.pause_pressed.connect(func():
		if coop != null and coop.active:
			InteriorTouchControls.send_action("pause", true)
			InteriorTouchControls.send_action("pause", false)
		else:
			_show_menu("pause"))
	touch.fire_held.connect(func(on: bool):
		if story != null:
			story.gun.trigger_held = on and story.gun.drawn)
	touch.aim_pressed.connect(func():
		if story != null:
			story.gun.touch_aim = not story.gun.touch_aim and story.gun.drawn
			touch.set_aim(story.gun.touch_aim))
	touch.swap_pressed.connect(func():
		if story != null:
			story.gun.cycle_weapon()
			touch.set_aim(false))
	touch.gun_pressed.connect(func():
		if story != null:
			story.gun.toggle())
	touch.reload_pressed.connect(func():
		if story != null:
			story.gun.reload())
	touch.light_pressed.connect(func():
		if story != null:
			story.flashlight.toggle())
	touch.shove_pressed.connect(func():
		# 0.64: the squad game's shove is its own (T), seen by the others.
		if coop != null and coop.active:
			InteriorTouchControls.send_key(KEY_T, true)
			InteriorTouchControls.send_key(KEY_T, false)
		elif body != null:
			body.shove())
	menu_shade = ColorRect.new()
	menu_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade := ShaderMaterial.new()
	shade.shader = preload("res://scripts/menu_shade.gdshader")
	menu_shade.material = shade
	ui.add_child(menu_shade)
	menu_blood = TextureRect.new()
	menu_blood.name = "MenuBlood"
	menu_blood.texture = load("res://assets/ui/menu_blood.png") as Texture2D
	menu_blood.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_blood.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_blood.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	menu_blood.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_blood.modulate = Color(1, 1, 1, .6)
	menu_blood.visible = false
	ui.add_child(menu_blood)
	var center := Control.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.theme = theme
	ui.add_child(center)
	center.resized.connect(func(): _layout_menu.call_deferred())
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
	# 0.31: the top edge of a window is wet, and runs (placed by _layout_menu).
	menu_drip = TextureRect.new()
	menu_drip.name = "MenuDrip"
	menu_drip.texture = load("res://assets/ui/panel_drip.png") as Texture2D
	menu_drip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_drip.stretch_mode = TextureRect.STRETCH_TILE
	menu_drip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_drip.visible = false
	center.add_child(menu_drip)
	menu_content = VBoxContainer.new()
	menu_content.add_theme_constant_override("separation", 12)
	menu.add_child(menu_content)
	menu.theme = theme.duplicate()
	menu.theme.set_color("font_color", "Label", InteriorBloodTitle.BONE)
	menu.theme.set_color("font_color", "Button", InteriorBloodTitle.BONE)
	menu.theme.set_color("font_hover_color", "Button", Color(.98,.93,.9))
	menu.theme.set_color("font_focus_color", "Button", Color(.98,.93,.9))
	var clean := StyleBoxFlat.new()
	clean.bg_color = Color(.03,.026,.03,.9)
	clean.content_margin_left = 18
	clean.content_margin_right = 18
	clean.content_margin_top = 10
	clean.content_margin_bottom = 10
	var over := clean.duplicate() as StyleBoxFlat
	over.bg_color = Color(.15,.028,.03,.95)
	over.border_color = Color(.5,.05,.05)
	over.border_width_left = 3
	# 0.54: the windows' buttons in the story's serif; the option pickers in the text face.
	menu.theme.set_font("font", "Button", SleepType.serif())
	menu.theme.set_font_size("font_size", "Button", 25)
	menu.theme.set_font("font", "OptionButton", SleepType.text(500))
	menu.theme.set_font_size("font_size", "OptionButton", 18)
	menu.theme.set_font("font", "PopupMenu", SleepType.text(500))
	menu.theme.set_font("font", "CheckBox", SleepType.text(500))
	menu.theme.set_font_size("font_size", "CheckBox", 18)
	menu.theme.set_color("font_disabled_color", "Button", Color(SleepType.BONE, .35))
	over.bg_color = Color(.11, .06, .035, .95)
	over.border_color = SleepType.SODIUM
	over.border_width_left = 2
	for type_name in ["Button", "OptionButton"]:
		menu.theme.set_stylebox("normal", type_name, clean)
		menu.theme.set_stylebox("hover", type_name, over)
		menu.theme.set_stylebox("pressed", type_name, over)
		var focus := StyleBoxFlat.new()
		focus.bg_color = Color(0,0,0,0)
		focus.border_color = Color(.42,.06,.06)
		focus.set_border_width_all(1)
		menu.theme.set_stylebox("focus", type_name, focus)
	menu_light = SleepMenu.light(center)

## 0.54: a heading (30 px and up) is set in the story's serif, larger; a sub-heading (24-29) in its italic.
func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	if font_size >= 30:
		label.add_theme_font_override("font", SleepType.serif())
		font_size = int(font_size * 1.32)
	elif font_size >= 24:
		label.add_theme_font_override("font", SleepType.serif(true))
		font_size += 4
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
	if mobile: Engine.max_fps = 30
	if kind == "options" and current_menu != "options":
		# 0.67: Options from the squad game's pause goes back to that pause.
		_options_return = ("coop_pause" if current_menu == "coop_pause" else "pause") if started else "home"
	current_menu = kind
	player.playing = false
	player.release_object()
	touch.set_enabled(false)
	hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# The squad game never stops for one player's menu (the others play on).
	get_tree().paused = not (coop != null and coop.active and started)
	if menu_street != null:
		menu_street.set_active(not started)
	menu_shade.visible = not started
	menu_blood.visible = not started
	for child in menu_content.get_children():
		menu_content.remove_child(child)
		child.queue_free()
	menu.show()
	if coop != null and kind != "multiplayer": coop.hide_lobby_ui()
	# 0.54: cut from the dark, a hairline at the edge, a rust rule along the top (SleepType.panel).
	var panel := SleepType.panel(34, 24, 2)
	panel.content_margin_top = 44
	menu.add_theme_stylebox_override("panel", panel)
	menu.custom_minimum_size = Vector2(760 if kind == "options" else 480, 0)
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	menu.size = Vector2.ZERO
	if kind == "home":
		panel.bg_color = Color(0,0,0,0)
		panel.set_border_width_all(0)
		panel.content_margin_left = 0
		panel.content_margin_right = 0
		panel.content_margin_top = 24
		menu.custom_minimum_size = Vector2(310,0)
		menu.anchor_left = .075
		menu.anchor_right = .075
		menu.anchor_top = .22
		menu.anchor_bottom = .22
		menu.grow_horizontal = Control.GROW_DIRECTION_END
		menu.grow_vertical = Control.GROW_DIRECTION_END
		SleepMenu.title_block(menu_content, Color(.91,.92,.86))
		var gap := Control.new()
		gap.custom_minimum_size.y = 8
		menu_content.add_child(gap)
		# 0.66 (owner: "DISABLE the Single Player for now, so the PLAY NOW heads straight to Multiplayer"): Play opens
		# the squad game's lobby; the solo game has no button.
		_home_button("Play", coop.page if coop != null else _play)
		_home_button("Options", func(): _show_menu("options"))
		if not mobile: _home_button("Quit", func(): get_tree().quit())
	elif kind == "multiplayer" and coop != null:
		# 0.45: its own full-screen layout (scripts/coop/lobby_ui.gd), not the centred window.
		menu.hide()
		menu_blood.visible = false
		coop.show_lobby_ui()
	elif kind in ["coop_pause","coop_results","coop_board"] and coop != null:
		coop.build_overlay(kind)
	elif kind == "options":
		_build_options()
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
		_button("Options", func(): _show_menu("options"))
		if not mobile: _button("Quit", func(): get_tree().quit())
	if menu_light != null: menu_light.follow(_menu_buttons())
	# Keyboard/gamepad users can start immediately; mouse hover uses the same visible styles.
	_focus_menu.call_deferred()
	_layout_menu.call_deferred()

func _focus_menu() -> void:
	if not is_inside_tree() or not menu.visible: return
	for child in menu_content.get_children():
		if child is Button and child.is_inside_tree():
			child.grab_focus()
			break

func _layout_menu() -> void:
	if menu == null: return
	var bounds := (menu.get_parent() as Control).size
	menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	menu.scale = Vector2.ONE
	menu.size = menu.get_combined_minimum_size()
	# 0.30: a window never leaves the screen. One that is still too tall or too wide is drawn smaller, whole.
	var fit := minf(1.0, minf((bounds.y - 28.0) / maxf(1.0, menu.size.y), (bounds.x - 28.0) / maxf(1.0, menu.size.x)))
	menu.pivot_offset = Vector2.ZERO
	menu.scale = Vector2(fit, fit)
	var shown := menu.size * fit
	if current_menu == "home":
		menu.position = Vector2(bounds.x * .075, minf(bounds.y * .19, bounds.y - shown.y - 14.0))
	else:
		menu.position = ((bounds - shown) * .5).round()
	menu_drip.visible = menu.visible and current_menu != "home"
	menu_drip.position = menu.position
	menu_drip.size = Vector2(menu.size.x, 46.0)
	menu_drip.scale = Vector2(fit, fit)

## The buttons now in the menu (for the flashlight cursor), however deep (the options' grid holds some).
func _menu_buttons() -> Array:
	return menu_content.find_children("*", "BaseButton", true, false)

func _home_button(text: String, callback: Callable) -> void:
	var button := _button(text, callback)
	SleepMenu.home_button(button)

func _build_options() -> void:
	menu_content.add_child(_label("Options", 34))
	# 0.30: two columns. One column of seven selectors plus the controls was taller than a 720-line screen:
	# the title and the Back button fell off its top and bottom.
	var _options_grid := GridContainer.new()
	_options_grid.columns = 1 if mobile else 2
	_options_grid.add_theme_constant_override("h_separation", 12)
	_options_grid.add_theme_constant_override("v_separation", 10)
	menu_content.add_child(_options_grid)
	var quality_select := OptionButton.new()
	for label in ["Graphics: Low", "Graphics: Medium", "Graphics: High"] + ([] if mobile else ["Graphics: Ultra"]):
		quality_select.add_item(label)
	quality_select.selected = quality
	quality_select.custom_minimum_size.y = 46
	quality_select.item_selected.connect(func(index: int):
		_apply_quality(index)
		GameSettings.set_value("quality", quality))
	quality_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quality_select.clip_text = true
	quality_select.fit_to_longest_item = false
	_options_grid.add_child(quality_select)
	# 0.26: head bob is 55 % lower than it used to be by default; Low takes another quarter off, Off removes it
	# (with the lens' lean and tremor).
	var motion_select := OptionButton.new()
	for label in ["Head bob: Default", "Head bob: Low", "Head bob: Off"]:
		motion_select.add_item(label)
	motion_select.selected = camera_motion
	motion_select.custom_minimum_size.y = 46
	motion_select.item_selected.connect(func(index: int):
		camera_motion = index
		player.camera_motion = MOTION_LEVELS[index]
		GameSettings.set_value("head_bob", index))
	motion_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	motion_select.clip_text = true
	motion_select.fit_to_longest_item = false
	_options_grid.add_child(motion_select)
	if is_instance_valid(bodycam):
		var lens_select := OptionButton.new()
		lens_select.add_item("Lens: Body camera")
		lens_select.add_item("Lens: Clean")
		lens_select.selected = 0 if bodycam.enabled else 1
		lens_select.custom_minimum_size.y = 46
		lens_select.item_selected.connect(func(index: int): bodycam.set_enabled(index == 0))
		lens_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lens_select.clip_text = true
		lens_select.fit_to_longest_item = false
		_options_grid.add_child(lens_select)
	if story != null and story.get("gun") != null and not mobile:
		var aim_select := OptionButton.new()
		aim_select.add_item("Aim: The muzzle leads")
		aim_select.add_item("Aim: Centred")
		aim_select.selected = 0 if story.gun.free_aim else 1
		aim_select.custom_minimum_size.y = 46
		aim_select.item_selected.connect(func(index: int): story.gun.free_aim = index == 0)
		aim_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		aim_select.clip_text = true
		aim_select.fit_to_longest_item = false
		_options_grid.add_child(aim_select)
	if is_instance_valid(performance) and not mobile:
		var cap_select := OptionButton.new()
		for label: String in InteriorPerformance.FRAME_LABELS:
			cap_select.add_item(label)
		cap_select.selected = performance.frame_cap
		cap_select.custom_minimum_size.y = 46
		cap_select.item_selected.connect(func(index: int):
			performance.apply_frame_cap(index)
			GameSettings.set_value("frame_cap", index))
		cap_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cap_select.clip_text = true
		cap_select.fit_to_longest_item = false
		_options_grid.add_child(cap_select)
	if is_instance_valid(performance):
		var auto_select := OptionButton.new()
		auto_select.add_item("Keep the frame rate: On")
		auto_select.add_item("Keep the frame rate: Off")
		auto_select.selected = 0 if performance.adaptive else 1
		auto_select.custom_minimum_size.y = 46
		auto_select.item_selected.connect(func(index: int): performance.set_adaptive(index == 0))
		auto_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		auto_select.clip_text = true
		auto_select.fit_to_longest_item = false
		_options_grid.add_child(auto_select)
	if is_instance_valid(performance) and not mobile:
		var window_select := OptionButton.new()
		window_select.add_item("Display: Window")
		window_select.add_item("Display: Fullscreen")
		window_select.selected = 1 if get_window().mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN] else 0
		window_select.custom_minimum_size.y = 46
		window_select.item_selected.connect(func(index: int):
			get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN if index == 1 else Window.MODE_WINDOWED
			GameSettings.set_value("fullscreen", index == 1))
		window_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		window_select.clip_text = true
		window_select.fit_to_longest_item = false
		_options_grid.add_child(window_select)
	# 0.43: a volume for each kind of sound, kept between runs.
	menu_content.add_child(_label("Sound", 24))
	var sound_grid := GridContainer.new()
	sound_grid.columns = 1 if mobile else 2
	sound_grid.add_theme_constant_override("h_separation", 24)
	sound_grid.add_theme_constant_override("v_separation", 6)
	menu_content.add_child(sound_grid)
	for entry: Array in [["Master", "All sound"]] + InteriorSettings.CATEGORIES:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label := _label(entry[1], 17)
		name_label.custom_minimum_size.x = 190
		row.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 5
		slider.value = roundf(GameSettings.volume(entry[0]) * 100.0)
		slider.custom_minimum_size = Vector2(170, 30)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var amount := _label("%d%%" % int(slider.value), 17)
		amount.custom_minimum_size.x = 52
		var bus: String = entry[0]
		slider.value_changed.connect(func(value: float):
			amount.text = "%d%%" % int(value)
			GameSettings.set_volume(bus, value / 100.0))
		row.add_child(slider)
		row.add_child(amount)
		sound_grid.add_child(row)
	menu_content.add_child(_label("Controls", 24))
	menu_content.add_child(_label("Left thumb: the stick (all the way forward sprints, a light push is the quiet walk) • right thumb: drag to look\nFIRE (hold for automatic fire; drag it to aim while firing) • ADS • RELOAD • JUMP • CROUCH • SHOVE\nUSE holds, drops, opens and pulls (it shows when there is something to use) • INSPECT\nGUN draws or puts away the weapon • SWAP • LIGHT • squad game: hold GRENADE, MEDKIT or DROP • CHAT" if mobile else "WASD  Move     Shift  Sprint     Space  Jump / climb     C  Crouch     Ctrl  Slow, quiet walk\nZ / X  Lean     V  Shove     Hold H  Bind a wound\nMouse  Look     E  Hold / drop / use     Hold E and move  Pull doors, gates, props\nLeft click  Throw / fire     Right click  Raise the sights     R  Reload\nG or 1  Gun out / away (nothing else puts it away)     Hold 5  Grenade (let go to throw)     L  Flashlight\nF  Inspect     Q  TV channel     J  Notes     Esc  Pause     F3  FPS counter", 18))
	if not mobile and is_instance_valid(performance):
		var note := _label("Keep the frame rate lowers the 3D resolution a little while the graphics card is behind. The graphics level only changes here.", 15)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.modulate.a = .7
		menu_content.add_child(note)
	_button("Back", func(): _show_menu(_options_return))

func _play() -> void:
	Engine.max_fps = 60 if mobile else 120
	if is_instance_valid(performance):
		performance.apply_frame_cap(performance.frame_cap)
	if menu_street != null and menu_street.active:
		menu_street.set_active(false)
	menu_shade.hide()
	menu_blood.hide()
	menu_drip.hide()
	if not started:
		InteriorLoadClock.mark("play: the game begins")
	started = true
	menu.hide()
	hud.show()
	get_tree().paused = false
	player.playing = true
	touch.set_enabled(mobile)
	if not mobile and not capturing:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _restart() -> void:
	get_tree().paused = false
	if InteriorLoadClock.booted:
		# Back through the loading screen: the files are still in memory, only the world is rebuilt.
		get_tree().change_scene_to_file("res://boot.tscn")
		return
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
	for neighbourhood in get_tree().get_nodes_in_group("neighbourhood"):
		neighbourhood.refresh_quality()
	if is_instance_valid(atmosphere):
		atmosphere.set_quality(quality)
	if is_instance_valid(atmosphere_particles):
		atmosphere_particles.set_quality(quality)
	if is_instance_valid(bodycam):
		bodycam.set_quality(quality)
	if is_instance_valid(mobile_performance):
		mobile_performance.apply_quality(quality)
	if is_instance_valid(performance):
		performance.apply_quality(quality)
		performance.apply_frame_cap(performance.frame_cap)
	if mobile and not player.playing:
		Engine.max_fps = 30

func _notification(what: int) -> void:
	if not mobile or not is_instance_valid(player) or menu == null or has_meta("performance_audit"):
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and player.playing:
		_show_menu("pause")
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if player.playing:
			_show_menu("pause")
		elif started and current_menu == "pause":
			_play()
		else:
			_show_menu("pause" if started else "home")

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
	prompt.text = (("Use • " if mobile else "E • Hold ") + body.display_name) if body != null else ""
	if body != null and body.has_meta("interactor") and is_instance_valid(body.get_meta("interactor")):
		var text := str((body.get_meta("interactor") as Object).call("prompt_text"))
		prompt.text = ("Use • " + text.replace("Q • Change channel", "Throw • Channel")) if mobile else ("E • " + text)
	if body == null and player != null and is_instance_valid(player.door_target):
		prompt.text = ("Use • " if mobile else "E • ") + str(player.door_target.call("prompt_text"))
		if player.door_target is InteriorPushGate and not player.door_target.locked:
			prompt.text = "Keep holding and move • push / pull gate" if mobile else "Hold E and move • push / pull gate"
		elif player.door_target.is_in_group("usables") and str(player.door_target.call("prompt_text")) == "":
			prompt.text = ""
		elif player.door_hit.is_finite() and player.door_target.has_method("grab"):
			prompt.text += "     Keep holding • pull" if mobile else "     Hold E • pull"
	if player != null and player.is_pulling():
		prompt.text = "Move to push or pull • let go to release" if mobile else "Move to push or pull • release E to let go"
	if body != null and body.is_in_group("mystery_console"):
		prompt.text += "     Inspect" if mobile else "     F • Inspect"
	# 0.23: a place can ask for a hint while nothing is targeted (the crouch at the hole in the town wall).
	if prompt.text == "" and context_prompt != "":
		prompt.text = context_prompt

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

## `-- --capture-menus --capture-path=<dir>`: the home menu and the Options window as the player sees them.
func _capture_menus() -> void:
	var directory := ProjectSettings.globalize_path("res://../room/runtime")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-path="):
			directory = argument.trim_prefix("--capture-path=")
	DirAccess.make_dir_recursive_absolute(directory)
	for i in 60:
		await get_tree().process_frame
	for kind: String in ["home", "options", "pause"]:
		_show_menu(kind)
		for i in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join("menu-%s.png" % kind))
		print("INTERIOR_CAPTURE menu-", kind, " ", menu.size, " x", menu.scale.x, " at ", menu.position)
	# 0.67: the squad game's pause (the only game now) and the Options window opened from it.
	if coop != null:
		coop.host()
		coop.add_bot()
		coop.start_game()
		for i in 90:
			await get_tree().process_frame
		coop.show_pause()
		for kind: String in ["coop-pause", "coop-options"]:
			if kind == "coop-options": _show_menu("options")
			for i in 20:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(directory.path_join("menu-%s.png" % kind))
			print("INTERIOR_CAPTURE menu-", kind, " paused=", get_tree().paused)
		coop.end_session()
	get_tree().quit()

func _capture_review() -> void:
	capturing = true
	get_window().set_flag(Window.FLAG_NO_FOCUS, true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var directory := ProjectSettings.globalize_path("res://../work/lemondev/2026-10-05/captures")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-path="):
			directory = argument.trim_prefix("--capture-path=")
	DirAccess.make_dir_recursive_absolute(directory)
	var only_balcony := "--capture-views=balcony" in OS.get_cmdline_user_args()
	if "--capture-views=canal" in OS.get_cmdline_user_args():
		await _capture_canal_views(directory)
		print("INTERIOR_REVIEW_CAPTURE ",directory)
		get_tree().quit()
		return
	if "--capture-views=siege" in OS.get_cmdline_user_args():
		await _capture_siege_views(directory)
		print("INTERIOR_REVIEW_CAPTURE ",directory)
		get_tree().quit()
		return
	if "--capture-views=basement" in OS.get_cmdline_user_args():
		await _capture_basement_views(directory)
		print("INTERIOR_REVIEW_CAPTURE ",directory)
		get_tree().quit()
		return
	if "--capture-views=nichols" in OS.get_cmdline_user_args():
		await _capture_nichols_views(directory)
		print("INTERIOR_REVIEW_CAPTURE ",directory)
		get_tree().quit()
		return
	if "--capture-views=warren" in OS.get_cmdline_user_args():
		await _capture_warren_views(directory)
		print("INTERIOR_REVIEW_CAPTURE ",directory)
		get_tree().quit()
		return
	if "--capture-views=neighborhood" in OS.get_cmdline_user_args():
		await _capture_neighborhood_views(directory)
		get_tree().quit()
		return
	await get_tree().create_timer(2.0).timeout
	if "--capture-views=arsenal" in OS.get_cmdline_user_args():
		await _capture_arsenal_views(directory)
		print("INTERIOR_REVIEW_CAPTURE ",directory)
		get_tree().quit()
		return
	if "--capture-views=weapons" in OS.get_cmdline_user_args():
		await _capture_weapon_views(directory)
		print("INTERIOR_REVIEW_CAPTURE ",directory)
		get_tree().quit()
		return
	if "--capture-views=fit" in OS.get_cmdline_user_args():
		# 0.31: close every finger on every weapon by contact and write assets/hand_fits.json (scripts/gun.gd).
		_play()
		story.gun.give()
		await get_tree().create_timer(.5).timeout
		await story.gun.fit_hands()
		get_tree().quit()
		return
	if "--capture-views=hands" in OS.get_cmdline_user_args():
		await _capture_hand_views(directory)
		print("INTERIOR_REVIEW_CAPTURE ",directory)
		get_tree().quit()
		return
	if "--capture-views=gore" in OS.get_cmdline_user_args():
		await _capture_gore_views(directory)
		print("INTERIOR_REVIEW_CAPTURE ",directory)
		get_tree().quit()
		return
	if "--capture-views=grenade" in OS.get_cmdline_user_args():
		await _capture_grenade_views(directory)
		print("INTERIOR_REVIEW_CAPTURE ",directory)
		get_tree().quit()
		return
	if "--capture-views=coop" in OS.get_cmdline_user_args():
		await _capture_coop_views(directory)
		print("INTERIOR_REVIEW_CAPTURE ",directory)
		get_tree().quit()
		return
	if "--capture-views=coop_lobby" in OS.get_cmdline_user_args():
		await _capture_coop_lobby_views(directory)
		print("INTERIOR_REVIEW_CAPTURE ",directory)
		get_tree().quit()
		return
	if "--capture-views=coop_chapter" in OS.get_cmdline_user_args():
		await _capture_coop_chapter_views(directory)
		print("INTERIOR_REVIEW_CAPTURE ",directory)
		get_tree().quit()
		return
	if "--capture-views=coop_school" in OS.get_cmdline_user_args():
		await _capture_coop_school_views(directory)
		print("INTERIOR_REVIEW_CAPTURE ",directory)
		get_tree().quit()
		return
	if "--capture-views=coop_escape" in OS.get_cmdline_user_args():
		await _capture_coop_escape_views(directory)
		print("INTERIOR_REVIEW_CAPTURE ",directory)
		get_tree().quit()
		return
	if "--capture-views=coop_heavyarm" in OS.get_cmdline_user_args():
		await _capture_coop_heavyarm_views(directory)
		print("INTERIOR_REVIEW_CAPTURE ",directory)
		get_tree().quit()
		return
	if "--capture-views=coop_route" in OS.get_cmdline_user_args():
		await _capture_coop_route_views(directory)
		print("INTERIOR_REVIEW_CAPTURE ",directory)
		get_tree().quit()
		return
	if "--capture-views=coop_jumps" in OS.get_cmdline_user_args():
		await _capture_coop_jump_views(directory)
		print("INTERIOR_REVIEW_CAPTURE ",directory)
		get_tree().quit()
		return
	if "--capture-views=zombies" in OS.get_cmdline_user_args():
		await _capture_zombie_views(directory)
		print("INTERIOR_REVIEW_CAPTURE ",directory)
		get_tree().quit()
		return
	if "--capture-views=glass" in OS.get_cmdline_user_args():
		await _capture_glass_views(directory)
		print("INTERIOR_REVIEW_CAPTURE ",directory)
		get_tree().quit()
		return
	if "--capture-views=body" in OS.get_cmdline_user_args():
		await _capture_body_views(directory)
		print("INTERIOR_REVIEW_CAPTURE ",directory)
		get_tree().quit()
		return
	if "--capture-views=gun" in OS.get_cmdline_user_args():
		await _capture_gun_views(directory)
		print("INTERIOR_REVIEW_CAPTURE ",directory)
		get_tree().quit()
		return
	if "--capture-views=debug" in OS.get_cmdline_user_args():
		await _capture_debug_views(directory)
		print("INTERIOR_REVIEW_CAPTURE ",directory)
		get_tree().quit()
		return
	if "--capture-views=hut" in OS.get_cmdline_user_args():
		await _capture_hut_views(directory)
		print("INTERIOR_REVIEW_CAPTURE ",directory)
		get_tree().quit()
		return
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

func _capture_neighborhood_views(directory: String) -> void:
	# Exported release builds cannot execute the editor's --script review harness.
	# Keep a built-in capture route so the shipped EXE can verify its own packed assets.
	_play()
	_apply_quality(2)
	await get_tree().process_frame
	player.process_mode = Node.PROCESS_MODE_DISABLED
	for layer in find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var neighborhood := get_tree().get_first_node_in_group("neighbourhood")
	var stats: Dictionary = neighborhood.get_meta("abandoned_town", {}) if neighborhood != null else {}
	print("INTERIOR_NEIGHBORHOOD_PACKED ", JSON.stringify(stats))
	if stats.is_empty():
		push_error("Neighborhood details are missing from the executable")
		get_tree().quit(2)
		return
	if DisplayServer.get_name() == "headless":
		return
	var views := [
		["01-street-arrival", Vector3(20.2, -1.32, 6.0), Vector3(20.5, -1.65, 31.0), 72.0],
		["02-west-street", Vector3(17.8, -1.32, 18.2), Vector3(-8.0, -1.7, 18.0), 72.0],
		["03-east-wall-detail", Vector3(21.7, -1.10, 30.0), Vector3(24.25, -1.45, 33.0), 60.0],
		["04-road-and-curb", Vector3(20.8, -1.25, 37.0), Vector3(22.85, -2.71, 42.5), 65.0],
		["05-north-street", Vector3(17.3, -1.32, 48.8), Vector3(-8.0, -1.8, 49.0), 72.0],
		["06-neighborhood-overview", Vector3(38.0, 18.0, 6.0), Vector3(8.0, -1.4, 30.0), 68.0],
	]
	for view: Array in views:
		player.global_position = view[1] - Vector3.UP * InteriorPlayer.STANDING_EYE
		player.camera.global_position = view[1]
		player.camera.look_at(view[2])
		player.camera.fov = view[3]
		await get_tree().create_timer(2.5).timeout
		await _save_review_image(directory, view[0])
		print("INTERIOR_NEIGHBORHOOD_VIEW ", view[0])
	print("INTERIOR_NEIGHBORHOOD_REVIEW_COMPLETE")

func _capture_balcony_views(directory: String) -> void:
	var door := entry_door()
	if door == null:
		return
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

## 0.10: the hut from the footpath, its candle-lit room, the open drawer and the Glock on screen (proves a build
## contains the hut sequence: `Interior.exe -- --capture-review --capture-views=hut --capture-path=<dir>`).
func _capture_hut_views(directory: String) -> void:
	if story == null:
		return
	_play()
	# Let the first played second run: straight from the menu, a frozen player leaves the 3D view black.
	await get_tree().create_timer(1.0).timeout
	var hut := story.hut
	player.process_mode = Node.PROCESS_MODE_DISABLED
	touch.visible = false
	var views := [["hut-1-footpath", Vector3(9.0, 1.6, -.3), Vector3(0, 1.3, -.3)],
		["hut-2-room", Vector3(.9, 2.0, -.1), Vector3(-1.5, 1.2, -.35)],
		["hut-3-key", Vector3(-.75, 1.75, -.3), Vector3(-1.4, 1.26, -.45)]]
	for view in views:
		var eye: Vector3 = hut.global_transform * (view[1] as Vector3)
		player.global_position = eye - Vector3(0, 1.58, 0)
		player.camera.global_position = eye
		player.camera.look_at(hut.global_transform * (view[2] as Vector3))
		await get_tree().create_timer(.6).timeout
		await _save_review_image(directory, view[0])
	hut.use("key")
	hut.use("drawer")
	await get_tree().create_timer(2.2).timeout
	var eye2: Vector3 = hut.global_transform * Vector3(-.62, 1.9, -.3)
	player.global_position = eye2 - Vector3(0, 1.58, 0)
	player.camera.global_position = eye2
	player.camera.look_at(hut.global_transform * Vector3(-1.1, 1.0, -.31))
	await get_tree().create_timer(.5).timeout
	await _save_review_image(directory, "hut-4-drawer-open")
	# 0.12: the flashlight beside the Glock, close up.
	if hut.get_node_or_null("Dresser/TopDrawer/Flashlight") != null:
		_capture_eye(hut.global_transform * Vector3(-.74, 1.62, -.5), hut.global_transform * Vector3(-1.12, 1.03, -.5))
		await get_tree().create_timer(.5).timeout
		await _save_review_image(directory, "hut-4b-drawer-flashlight")
	hut.use("gun")
	await get_tree().create_timer(.6).timeout
	await _save_review_image(directory, "hut-5-inspect")
	# 0.11: take it; the hooded man (hood up) calls from the yard; the box behind the scarecrow; the dike.
	story.ui.close_inspect(true)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(1.6).timeout
	hud.visible = false
	var man := story.stranger()
	if man != null:
		var face := man.global_position + Vector3.UP * 1.6
		var from := face + (hut.door_point() - man.global_position).normalized() * 1.6
		from.y = face.y - .05
		_capture_eye(from, face + Vector3.DOWN * .15)
		await get_tree().create_timer(.5).timeout
		await _save_review_image(directory, "hut-6-hooded-man")
	var frame := hut.crow_frame()
	if not frame.is_empty():
		var box := hut.box_spot()
		var to_road: Vector3 = frame[1]
		var side := Vector3(-to_road.z, 0, to_road.x)
		_capture_eye(box - to_road * .45 + side * .3 + Vector3.UP * .6, box)
		await get_tree().create_timer(.6).timeout
		await _save_review_image(directory, "hut-7-box-at-scarecrow")
		_capture_eye(hut.crow_route[0] + Vector3.UP * 1.62, (frame[0] as Vector3) + Vector3.UP * .8)
		await get_tree().create_timer(.6).timeout
		await _save_review_image(directory, "hut-8-scarecrow-dike")
	# 0.12: take the flashlight and switch it on: the room, then the dark road.
	hut.use("flashlight")
	story.flashlight.set_on(true)
	var eye3: Vector3 = hut.global_transform * Vector3(1.0, 2.0, .6)
	_capture_eye(eye3, hut.global_transform * Vector3(-1.5, 1.0, -.8))
	await get_tree().create_timer(.6).timeout
	await _save_review_image(directory, "hut-9-flashlight-room")
	_capture_eye(hut.route_in[0] + Vector3.UP * 1.62, hut.route_in[0] + (hut.route_in[0] - hut.route_in[2]).normalized().rotated(Vector3.UP, PI * .5) * 9.0 + Vector3.UP * .3)
	await get_tree().create_timer(.6).timeout
	await _save_review_image(directory, "hut-10-flashlight-road")
	hud.visible = true

## 0.17: the abandoned canal settlement, from inside the packed build
## (`Interior.exe -- --capture-review --capture-views=canal --capture-path=<dir>`).
func _capture_canal_views(directory: String) -> void:
	const C := preload("res://scripts/canal_settlement.gd")
	_play()
	_apply_quality(2)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	await get_tree().create_timer(1.0).timeout
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var stranger := get_node_or_null("Stranger")
	if stranger != null:
		stranger.process_mode = Node.PROCESS_MODE_DISABLED
	for layer in find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var canal := find_child("Canal settlement", true, false)
	print("INTERIOR_CANAL_PACKED ", JSON.stringify(canal.get_meta("counts", {}) if canal != null else {}))
	var F := C.FLOOR
	var views := [
		["canal-1-bridge", C.at(-.5, F + 1.62, C.BRIDGE_Z - 1.6), C.at(1.5, C.WATER + 1.8, 22.0)],
		["canal-2-catwalk", C.at(4.7, C.CATWALK + 1.6, 6.0), C.at(4.3, C.CATWALK + 1.3, 22.0)],
		["canal-3-far-path", C.at(-7.1, C.PATH + 1.6, 12.0), C.at(5.0, C.FLOOR + .5, 26.0)],
		["canal-4-lane", C.at(14.9, F + 1.6, 27.0), C.at(14.4, F + 1.4, 10.0)],
		["canal-5-shrine", C.at(-7.0, C.path_y(28.0) + 1.6, 28.6), C.at(-8.8, C.path_y(31.0) + 1.0, 31.0)],
		# 0.60: the litter close up, under the lane bulb and the catwalk bulb.
		["canal-6-lane-trash", C.at(14.9, F + 1.5, 15.2), C.at(14.6, F, 19.0)],
		["canal-7-catwalk-trash", C.at(4.6, C.CATWALK + 1.5, 4.2), C.at(4.9, C.CATWALK, 7.6)],
	]
	# 0.60: the litter close-ups get a flashlight-like fill at the eye (the lane is pitch dark at night).
	var fill := SpotLight3D.new()
	fill.light_energy = 0.0
	fill.spot_range = 9.0
	fill.spot_angle = 40.0
	fill.layers = 0xFFFFF
	add_child(fill)
	for view in views:
		_capture_eye(view[1], view[2])
		var lit: bool = "trash" in String(view[0])
		fill.light_energy = 3.0 if lit else 0.0
		if lit: fill.look_at_from_position(view[1], view[2])
		await get_tree().create_timer(1.2).timeout
		await _save_review_image(directory, view[0])
		# 0.60: what the frame cost (the trash report compares runs with and without -- --no-trash).
		var rs := RenderingServer
		print("INTERIOR_CANAL_FRAME ", view[0], " ", JSON.stringify({"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			"video_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, .1),
			"static_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, .1),
			"cpu_ms": snappedf(rs.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()), .01),
			"gpu_ms": snappedf(rs.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()), .01)}))
	fill.queue_free()

## 0.23: the walled town from inside the packed build: the wall at the street ends, the survivors' path to the
## passage, the camp, the hole, the secret crawl, and two frames of the hooded man's cutscene
## (`Interior.exe -- --capture-review --capture-views=siege --capture-path=<dir>`).
func _capture_siege_views(directory: String) -> void:
	_play()
	_apply_quality(2)
	await get_tree().create_timer(1.0).timeout
	var man := get_node_or_null("Stranger")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	if man != null:
		man.process_mode = Node.PROCESS_MODE_DISABLED
	for layer in find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var siege := find_child("Town siege", true, false)
	print("INTERIOR_SIEGE_PACKED ", JSON.stringify(siege.get_meta("counts", {}) if siege != null else {}))
	var views := [
		["siege-1-corner-east", Vector3(21.0, -1.32, 16.0), Vector3(60.0, -1.6, 18.0)],
		["siege-2-path-to-passage", Vector3(-12.0, -1.32, 18.6), Vector3(-40.0, -1.8, 18.0)],
		["siege-3-street-a", Vector3(17.5, -1.32, 19.0), Vector3(-30.0, -1.6, 18.0)],
		["siege-4-hole", Vector3(20.0, -1.32, 47.0), Vector3(22.5, -2.2, 56.0)],
		["siege-5-street-c-east", Vector3(19.0, -1.32, 49.0), Vector3(60.0, -1.6, 49.0)],
		["siege-6-secret", Vector3(21.8, -1.32, -14.5), Vector3(19.4, -2.2, -18.4)],
		["siege-7-checkpoint", Vector3(-16.5, -1.32, 17.6), Vector3(-22.5, -2.5, 13.0)],
	]
	for view in views:
		_capture_eye(view[1], view[2])
		await get_tree().create_timer(1.2).timeout
		await _save_review_image(directory, view[0])
	if man != null:
		# The cutscene, as when the player sees him from the stair.
		player.process_mode = Node.PROCESS_MODE_INHERIT
		man.process_mode = Node.PROCESS_MODE_PAUSABLE
		player.reset_motion(Vector3(5.25, -.08, 3.3))
		man.call("_start_cutscene")
		await get_tree().create_timer(1.4).timeout
		await _save_review_image(directory, "siege-8-cutscene-behind")
		await get_tree().create_timer(3.4).timeout
		await _save_review_image(directory, "siege-9-cutscene-side")

## 0.21: the Nichols property from inside the packed build: the view from the courtyard gate, the iron gate, the
## porch, the moonlit parlour and corridor, and the foyer stair by flashlight
## (`Interior.exe -- --capture-review --capture-views=nichols --capture-path=<dir>`).
func _capture_nichols_views(directory: String) -> void:
	const N := preload("res://scripts/nichols_property.gd")
	_play()
	_apply_quality(2)
	await get_tree().create_timer(1.0).timeout
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var stranger := get_node_or_null("Stranger")
	if stranger != null:
		stranger.process_mode = Node.PROCESS_MODE_DISABLED
	for layer in find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var nichols := find_child("Nichols property", true, false)
	print("INTERIOR_NICHOLS_PACKED ", JSON.stringify(nichols.get_meta("counts", {}) if nichols != null else {}))
	var views := [
		["nichols-1-from-the-gate", Vector3(13.4, -1.32, 4.3), Vector3(-12.0, 6.0, -90.0)],
		["nichols-2-iron-gate", Vector3(-11.0, -1.3, -52.5), Vector3(-12.0, 1.5, -82.0)],
		["nichols-3-drive", Vector3(-4.0, -1.3, -71.5), Vector3(-12.0, 2.5, -84.0)],
		["nichols-4-parlour", Vector3(-16.6, -.1, -90.8), Vector3(-24.1, .0, -87.2)],
		["nichols-5-corridor", Vector3(-16.5, 4.3, -83.3), Vector3(-25.0, 3.6, -83.4)],
	]
	for view in views:
		_capture_eye(view[1], view[2])
		await get_tree().create_timer(1.5).timeout
		await _save_review_image(directory, view[0])
	if story != null:
		story.debug_give_flashlight()
		story.flashlight.set_on(true)
	_capture_eye(Vector3(-12.0, -.1, -83.2), Vector3(-12.0, .6, -89.5))
	await get_tree().create_timer(1.2).timeout
	await _save_review_image(directory, "nichols-6-foyer-flashlight")
	_capture_eye(Vector3(-7.2, 4.3, -85.2), Vector3(-1.0, 3.2, -90.0))
	await get_tree().create_timer(1.2).timeout
	await _save_review_image(directory, "nichols-7-nursery-flashlight")

## 0.22: the blood trail, the cellar door, the cellar and the tunnel under the Nichols house, and its kitchen, from
## inside the packed build (`Interior.exe -- --capture-review --capture-views=basement --capture-path=<dir>`).
func _capture_basement_views(directory: String) -> void:
	const N := preload("res://scripts/nichols_property.gd")
	_play()
	_apply_quality(2)
	await get_tree().create_timer(1.0).timeout
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var stranger := get_node_or_null("Stranger")
	if stranger != null:
		stranger.process_mode = Node.PROCESS_MODE_DISABLED
	for layer in find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var basement := get_tree().get_first_node_in_group("nichols_basement")
	print("INTERIOR_BASEMENT_PACKED ", JSON.stringify(basement.stats if basement != null else {}))
	var dark := [
		["basement-1-kitchen-fridge", N.local(7.2, 15.2, 1.58), N.local(12.3, 16.9, .9)],
	]
	for view in dark:
		_capture_eye(view[1], view[2])
		await get_tree().create_timer(1.5).timeout
		await _save_review_image(directory, view[0])
	if story != null:
		story.debug_give_flashlight()
		story.flashlight.set_on(true)
	var torch := [
		["basement-2-entry-trail", N.local(-.3, .1, 1.58), N.local(.7, 3.2, 0.0)],
		["basement-3-nook", N.local(2.0, 4.4, 1.58), N.local(1.95, 9.4, .9)],
		["basement-4-cellar-door", N.local(2.0, 7.9, 1.58), N.local(1.95, 9.4, .9)],
	]
	for view in torch:
		_capture_eye(view[1], view[2])
		await get_tree().create_timer(1.2).timeout
		await _save_review_image(directory, view[0])
	if story != null:
		story.flashlight.set_on(false)
	if basement != null:
		basement.flicker_enabled = false
		basement.set_basement_lights(true, true)
	var lit := [
		["basement-5-stair", N.local(-3.4, 10.2, -1.12), N.local(2.0, 10.2, .6)],
		["basement-6-cellar", N.local(-3.4, 11.2, -1.12), N.local(-8.5, 17.0, -2.4)],
		["basement-7-tunnel", N.local(1.6, 16.8, -2.02), N.local(12.4, 16.8, -2.4)],
		["basement-8-iron-door", N.local(9.0, 16.6, -2.02), N.local(12.4, 16.8, -2.0)],
	]
	for view in lit:
		_capture_eye(view[1], view[2])
		await get_tree().create_timer(1.5).timeout
		await _save_review_image(directory, view[0])

## 0.18: the hidden canal warren and its physical chairs, from inside the packed build
## (`Interior.exe -- --capture-review --capture-views=warren --capture-path=<dir>`).
func _capture_warren_views(directory: String) -> void:
	const W := preload("res://scripts/canal_warren.gd")
	_play()
	_apply_quality(2)
	await get_tree().create_timer(1.0).timeout
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var stranger := get_node_or_null("Stranger")
	if stranger != null:
		stranger.process_mode = Node.PROCESS_MODE_DISABLED
	for layer in find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var warren := find_child("Canal warren", true, false)
	var chairs := get_tree().get_nodes_in_group("movable").filter(func(b: Node) -> bool: return b.get_meta("loose_prop", "") == "chair").size()
	print("INTERIOR_WARREN_PACKED ", JSON.stringify(warren.get_meta("counts", {}) if warren != null else {}), " chairs ", chairs)
	var D := W.DECK + 1.58
	var views := [
		["warren-1-gate", W.at(-22.0, W.FLOOR + 1.6, 9.5), W.at(-28.5, W.FLOOR + 1.1, 8.0)],
		["warren-2-east-tunnel", W.pos(1.6, D, 6.6), W.pos(1.5, D - .3, -3.0)],
		["warren-3-family-room", W.pos(-1.5, D, 1.35), W.pos(-4.6, W.DECK + .5, 4.6)],
		["warren-4-altar", W.pos(-1.5, D, 18.4), W.pos(-6.3, W.FLOOR + 1.2, 20.5)],
		["warren-5-yard", W.pos(-1.7, D, 26.6), W.pos(-5.2, W.FLOOR + .9, 31.5)],
		["warren-6-store", W.pos(-1.4, D, 40.5), W.pos(-3.2, W.FLOOR + 1.3, 43.0)],
		["warren-7-west-tunnel", W.pos(-1.7, D, 8.0), W.pos(-1.7, D - .3, 16.0)],
	]
	for view in views:
		_capture_eye(view[1], view[2])
		await get_tree().create_timer(1.2).timeout
		await _save_review_image(directory, view[0])

## 0.20: the debug menu's four tabs over the courtyard, then the flashlight and fill light it turns on
## (`Interior.exe -- --capture-review --capture-views=debug --capture-path=<dir>`).
func _capture_debug_views(directory: String) -> void:
	_play()
	await get_tree().create_timer(1.0).timeout
	var debug_menu := get_node_or_null("DebugMenu") as InteriorDebugMenu
	if debug_menu == null:
		return
	debug_menu._teleport(Vector3(10.0, -2.75, 4.0))
	await get_tree().create_timer(.5).timeout
	debug_menu.show_menu()
	var tabs := debug_menu.find_children("*", "TabContainer", true, false)[0] as TabContainer
	for i in tabs.get_tab_count():
		tabs.current_tab = i
		await get_tree().create_timer(.4).timeout
		await _save_review_image(directory, "debug-%d-%s" % [i + 1, tabs.get_tab_title(i).to_lower()])
		print("INTERIOR_DEBUG_WINDOW ", tabs.get_tab_title(i), " ", debug_menu._panel.position, " ", debug_menu._panel.size, " x", debug_menu._panel.scale.x, " of ", debug_menu._panel.get_viewport_rect().size)
	if story != null:
		debug_menu._give_everything()
		story.flashlight.set_on(true)
	(debug_menu._controls["fill"] as HSlider).value = 1.5
	debug_menu.close()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	_capture_eye(Vector3(10.0, -1.27, 4.0), Vector3(16.0, -2.4, 6.0))
	await get_tree().create_timer(.8).timeout
	await _save_review_image(directory, "debug-5-items-and-fill")

func _capture_eye(eye: Vector3, at: Vector3) -> void:
	player.global_position = eye - Vector3(0, 1.58, 0)
	player.camera.global_position = eye
	player.camera.look_at(at)

## 0.27: both weapons as the body camera sees them, for comparing with the reference video frame by frame: ready,
## the muzzle swung off-centre (the arms follow), sights up, a shot frame by frame, the rifle's automatic fire and
## its reload (`Interior.exe -- --capture-review --capture-views=weapons --capture-path=<dir>`).
## 0.48: the named arsenal (`-- --capture-review --capture-views=arsenal --capture-path=<dir>`): every weapon in
## the hands in the lit room, on its sights (the sniper rifles through their scopes), then in co-op the drops: a
## weapon, the three healthkits and the three ammunition boxes lying on Store Road.
func _capture_arsenal_views(directory: String) -> void:
	if story == null:
		return
	_play()
	_apply_quality(2)
	var man := get_node_or_null("Stranger") as Node3D
	if man != null:
		man.process_mode = Node.PROCESS_MODE_DISABLED
		man.visible = false
	var gun := story.gun
	gun.infinite_ammo = true
	var room_eye := Vector3(.62, 1.6, 1.3)
	var room_at := Vector3(.62, 1.4, -2.4)
	var only: Array = []
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-weapons="):
			only = argument.trim_prefix("--capture-weapons=").split(",")
	for id: String in InteriorArsenal.WEAPONS:
		if not only.is_empty() and not id in only:
			continue
		var cls := InteriorArsenal.class_of(id)
		_gun_look(room_eye, room_at)
		gun.give_model(id, 60)
		gun.select(cls)
		await get_tree().create_timer(1.5).timeout
		await _save_review_image(directory, "%s-1-hip" % id)
		Input.action_press("aim")
		await get_tree().create_timer(1.1).timeout
		await _save_review_image(directory, "%s-2-sights" % id)
		Input.action_release("aim")
		await get_tree().create_timer(.5).timeout
		gun.try_fire()
		await get_tree().create_timer(.03).timeout
		await _save_review_image(directory, "%s-3-shot" % id)
		await get_tree().create_timer(.6).timeout
	if coop == null:
		return
	story.gun.holster(true)
	coop.host()
	coop.start_game()
	var m: Node = coop.mission
	var o: Vector3 = m.Street.ORIGIN
	for i in 60:
		await get_tree().process_frame
	var road: Vector3 = m.ground(o + Vector3(0, 0, 30))
	var kinds := ["weapon:eruption_ad15", "weapon:gtk44", "weapon:titan_b50", "weapon:gausser_db", "healthkit:small", "healthkit:medium", "healthkit:large", "ammo:small", "ammo:medium", "ammo:large"]
	for i in kinds.size():
		var at: Vector3 = m.ground(road + Vector3(-1.8 + (i % 5) * .9, 0, -1.6 - (i / 5) * 1.0))
		var key: int = 900000 + i
		if str(kinds[i]).begins_with("weapon:"):
			m.drops[key] = [at, kinds[i], [7, true, 14]]
		else:
			m.drops[key] = [at, kinds[i]]
	story.flashlight.set_on(true)
	player.reset_motion(road + Vector3(0, 0, .6))
	player.look_at(road + Vector3(0, 0, -3.0))
	player.camera.look_at(road + Vector3(0, -.2, -2.4) + Vector3.UP * .05)
	for i in 40:
		await get_tree().process_frame
	await _save_review_image(directory, "drops-store-road")

func _capture_weapon_views(directory: String) -> void:
	if story == null:
		return
	_play()
	_apply_quality(2)
	var man := get_node_or_null("Stranger") as Node3D
	if man != null:
		man.process_mode = Node.PROCESS_MODE_DISABLED
		man.visible = false
	var gun := story.gun
	gun.give()
	gun.infinite_ammo = true
	gun.debug_fill()
	gun.give_rifle()
	var room_eye := Vector3(.62, 1.6, 1.3)
	var room_at := Vector3(.62, 1.4, -2.4)
	var street_eye := Vector3(20.6, -1.32, 30.0)
	var street_at := Vector3(23.6, -1.5, 36.0)
	for which: String in ["pistol", "rifle"]:
		_gun_look(room_eye, room_at)
		gun.select(which)
		await get_tree().create_timer(1.4).timeout
		await _save_review_image(directory, which + "-01-ready")
		# The muzzle swung right and down, then left and up: the hands go there and the arms follow.
		player.look(Vector2(150, 60))
		await get_tree().create_timer(.12).timeout
		await _save_review_image(directory, which + "-02-swing-right")
		await get_tree().create_timer(1.0).timeout
		player.look(Vector2(-170, -70))
		await get_tree().create_timer(.12).timeout
		await _save_review_image(directory, which + "-03-swing-left")
		await get_tree().create_timer(1.0).timeout
		_gun_look(room_eye, room_at)
		Input.action_press("aim")
		await get_tree().create_timer(.7).timeout
		await _save_review_image(directory, which + "-04-sights")
		Input.action_release("aim")
		await get_tree().create_timer(.7).timeout
		# One shot, frame by frame.
		gun.try_fire()
		for frame in 8:
			await _save_review_image(directory, "%s-05-shot-%d" % [which, frame])
		await get_tree().create_timer(.8).timeout
		# A string: six fast pistol shots, or the rifle's trigger held for a second and a half.
		_gun_look(room_eye, room_at)
		await get_tree().create_timer(.3).timeout
		var frames := 0
		var motion := []
		if which == "pistol":
			for shot in 6:
				gun.try_fire()
				for frame in 7:
					await _save_review_image(directory, "pistol-06-string-%02d" % frames)
					frames += 1
					motion.append([player.camera.global_rotation, player.aim_offset, gun.get("_kick")])
		else:
			gun.trigger_held = true
			for frame in 90:
				if frame < 40:
					await _save_review_image(directory, "rifle-06-auto-%02d" % frames)
				else:
					await get_tree().process_frame
				frames += 1
				motion.append([player.camera.global_rotation, player.aim_offset, gun.get("_kick")])
			gun.trigger_held = false
		print("INTERIOR_WEAPON_MOTION ", which, " ", JSON.stringify(motion.map(func(m: Array) -> Array: return [rad_to_deg(m[0].x), rad_to_deg(m[0].y), rad_to_deg(m[0].z), rad_to_deg(m[1].x), rad_to_deg(m[1].y), rad_to_deg(m[2].x), rad_to_deg(m[2].y), rad_to_deg(m[2].z)])))
		print("INTERIOR_WEAPON_STRING ", which, " shots ", gun.shots_in_burst, " view ", player.camera.rotation, " aim ", player.aim_offset)
		await get_tree().create_timer(1.2).timeout
		_gun_look(room_eye, room_at)
		gun.infinite_ammo = false
		gun.mag = 3
		gun.reserve = 90
		gun.reload()
		var marks := [.4, .8, 1.1, 1.5] if which == "pistol" else [.5, .8, 1.3, 1.7, 2.0]
		var clock := 0.0
		for mark: float in marks:
			await get_tree().create_timer(mark - clock).timeout
			clock = mark
			await _save_review_image(directory, "%s-07-reload-%.1f" % [which, mark])
		gun.infinite_ammo = true
		await get_tree().create_timer(1.6).timeout
		# Outside at night, with the torch.
		_gun_look(street_eye, street_at)
		if story.flashlight != null:
			story.flashlight.give()
			story.flashlight.set_on(true)
		await get_tree().create_timer(1.2).timeout
		await _save_review_image(directory, which + "-08-street")
		Input.action_press("forward")
		Input.action_press("run")
		await get_tree().create_timer(1.0).timeout
		await _save_review_image(directory, which + "-09-running")
		Input.action_release("run")
		Input.action_release("forward")
		await get_tree().create_timer(.9).timeout
		gun.try_fire()
		await _save_review_image(directory, which + "-10-street-shot")
		await _save_review_image(directory, which + "-11-street-after")
		for later in 3:
			await get_tree().create_timer(.07).timeout
			await _save_review_image(directory, "%s-12-street-smoke-%d" % [which, later])
		if story.flashlight != null:
			story.flashlight.set_on(false)
		await get_tree().create_timer(.6).timeout

## 0.11: the Glock drawn in the room, fired once at a wall (the flash, then the hole), mid-reload, in the hut and on
## the moonlit road (`Interior.exe -- --capture-review --capture-views=gun --capture-path=<dir>`).
func _capture_gun_views(directory: String) -> void:
	if story == null:
		return
	_play()
	var gun := story.gun
	gun.give()
	gun.reserve = 43
	gun.mag = 16
	gun.chambered = true
	gun.ammo_changed.emit()
	touch.visible = mobile
	var eye := Vector3(.62, 1.6, 1.3)
	var wall := Vector3.INF
	var space := get_world_3d().direct_space_state
	for k in 24:
		var a := TAU * k / 24.0
		var query := PhysicsRayQueryParameters3D.create(eye, eye + Vector3(sin(a), -.08, -cos(a)) * 4.0, 6)
		query.exclude = [player.get_rid()]
		var hit := space.intersect_ray(query)
		if hit and hit.collider is StaticBody3D and eye.distance_to(hit.position) > 1.5 and absf(hit.normal.y) < .2:
			wall = hit.position
			break
	if not wall.is_finite():
		wall = Vector3(.62, 1.4, -2.4)
	_gun_look(eye, wall)
	gun.draw()
	await get_tree().create_timer(.9).timeout
	await _save_review_image(directory, "gun-1-room-drawn")
	gun.try_fire()
	await _save_review_image(directory, "gun-2-muzzle-flash")
	await get_tree().create_timer(.6).timeout
	await _save_review_image(directory, "gun-3-after-shot")
	if not gun.last_hit.is_empty():
		var at: Vector3 = gun.last_hit.position
		var normal: Vector3 = gun.last_hit.normal
		print("INTERIOR_GUN_HIT ", gun.last_hit.collider, " ", at, " ", gun.last_hit.surface)
		_gun_look(at + normal * .45 + Vector3(.05, .04, 0), at)
		gun.holster(true)
		await get_tree().create_timer(.3).timeout
		await _save_review_image(directory, "gun-4-hole-close")
		gun.draw()
		_gun_look(eye, wall)
		await get_tree().create_timer(.7).timeout
	gun.mag = 3
	gun.reload()
	await get_tree().create_timer(.5).timeout
	await _save_review_image(directory, "gun-5-reload-mag-out")
	await get_tree().create_timer(.75).timeout
	await _save_review_image(directory, "gun-6-reload-rack")
	await get_tree().create_timer(.6).timeout
	if mobile:
		touch.set_enabled(true)
		await get_tree().create_timer(.3).timeout
		await _save_review_image(directory, "gun-7-mobile-buttons")
		touch.visible = false
	var hut := story.hut
	_gun_look(hut.global_transform * Vector3(.9, 2.0, -.1), hut.global_transform * Vector3(-1.5, 1.2, -.35))
	await get_tree().create_timer(1.2).timeout
	await _save_review_image(directory, "gun-8-hut")
	_gun_look(Vector3(21.0, -1.32, 62.0), Vector3(19.0, -1.6, 110.0))
	await get_tree().create_timer(1.2).timeout
	await _save_review_image(directory, "gun-9-road")
	gun.try_fire()
	await _save_review_image(directory, "gun-10-road-flash")
	# 0.26 body-camera handling: sights up, the muzzle swung off-centre, running, and the torch with the pistol.
	await get_tree().create_timer(.8).timeout
	Input.action_press("aim")
	await get_tree().create_timer(.6).timeout
	await _save_review_image(directory, "gun-11-sights-up")
	Input.action_release("aim")
	await get_tree().create_timer(.5).timeout
	player.look(Vector2(-75, -30))
	await _save_review_image(directory, "gun-12-muzzle-leads-left")
	await get_tree().create_timer(.8).timeout
	Input.action_press("forward")
	Input.action_press("run")
	await get_tree().create_timer(1.1).timeout
	await _save_review_image(directory, "gun-13-running")
	Input.action_release("run")
	Input.action_release("forward")
	await get_tree().create_timer(.8).timeout
	if story.flashlight != null:
		story.flashlight.give()
		story.flashlight.set_on(true)
		await get_tree().create_timer(.7).timeout
		await _save_review_image(directory, "gun-14-torch-road")
		_gun_look(Vector3(20.6, -1.32, 30.0), Vector3(23.6, -1.5, 36.0))
		await get_tree().create_timer(.9).timeout
		await _save_review_image(directory, "gun-15-torch-street")
		gun.try_fire()
		await _save_review_image(directory, "gun-16-torch-street-flash")
		# 0.26: the player's own house from outside, by torch: from the courtyard and from the lane.
		# The hooded man is put away first: seeing him at the gate starts his film, which takes the camera.
		var man := get_node_or_null("Stranger") as Node3D
		if man != null:
			man.process_mode = Node.PROCESS_MODE_DISABLED
			man.visible = false
		await get_tree().create_timer(.8).timeout
		_gun_look(Vector3(11.6, -1.3, 4.2), Vector3(4.0, .6, 3.6))
		await get_tree().create_timer(.9).timeout
		await _save_review_image(directory, "gun-17-house-courtyard")
		_gun_look(Vector3(17.5, -1.3, 4.6), Vector3(4.0, .5, 2.0))
		await get_tree().create_timer(.9).timeout
		await _save_review_image(directory, "gun-18-house-lane")

## 0.28: the infected on the street by the fields: the seven of them in a row, one noticing the player and coming,
## the rifle's automatic fire into three, what is left on the road, a shotgun blast at arm's length, and one shot
## against a wall (`Interior.exe -- --capture-review --capture-views=zombies --capture-path=<dir>`).
## 0.33 (`--capture-views=body`): a lean round a corner, a climb caught half way up something that is really
## there (the first place found near the courtyard and the street where Space would climb), and the picture at 30.
func _capture_body_views(directory: String) -> void:
	if story == null or zombies == null or body == null:
		return
	_play()
	_apply_quality(2)
	var man := get_node_or_null("Stranger") as Node3D
	if man != null:
		man.process_mode = Node.PROCESS_MODE_DISABLED
		man.visible = false
	zombies.passive = true
	var gun := story.gun
	gun.give()
	gun.debug_fill()
	var debug_menu := get_node_or_null("DebugMenu") as InteriorDebugMenu
	if debug_menu != null:
		(debug_menu._controls["fill"] as HSlider).value = 2.2
	player.reset_motion(Vector3(18.9, -2.75, 6.0))
	player.rotation = Vector3(0, PI * .5, 0)
	gun.draw()
	await get_tree().create_timer(1.4).timeout
	Input.action_press("lean_right")
	await get_tree().create_timer(.7).timeout
	await _save_review_image(directory, "body-01-lean-right")
	Input.action_release("lean_right")
	Input.action_press("lean_left")
	await get_tree().create_timer(.7).timeout
	await _save_review_image(directory, "body-02-lean-left")
	Input.action_release("lean_left")
	await get_tree().create_timer(.4).timeout
	# Somewhere real to climb.
	var found := 0
	for origin: Vector3 in [Vector3(10.0, -2.75, 4.0), Vector3(18.9, -2.75, 6.0), Vector3(18.9, -2.75, 20.0), Vector3(21.0, -2.75, 46.0)]:
		for turn in 16:
			var yaw := TAU * turn / 16.0
			var way := -Basis(Vector3.UP, yaw).z
			for step in 22:
				var spot := zombies.ground(origin + way * (.8 + step * .4), false)
				if not spot.is_finite():
					continue
				player.global_position = spot
				player.rotation = Vector3(0, yaw, 0)
				player.force_update_transform()
				if player._try_mantle(true):
					found += 1
					var m: Dictionary = player._mantle
					print("INTERIOR_BODY climb at ", spot.snapped(Vector3.ONE * .01), " yaw ", snappedf(yaw, .01), " height ", snappedf(float(m.height), .01), " over ", m.over)
					player.reset_physics_interpolation()
					await get_tree().create_timer(float(m.time) * .5).timeout
					await _save_review_image(directory, "body-0%d-%s" % [2 + found, "vault" if m.over else "climb"])
					await get_tree().create_timer(float(m.time) * .5 + .5).timeout
					await _save_review_image(directory, "body-0%d-after" % (2 + found))
					break
			if found >= 2:
				break
		if found >= 2:
			break
	print("INTERIOR_BODY climbs found ", found)
	# Critical.
	player.reset_motion(Vector3(18.9, -2.75, 6.0))
	player.rotation = Vector3(0, PI * .5, 0)
	await get_tree().create_timer(.5).timeout
	zombies.hurt_player(70.0, player.global_position + player.global_basis.x)
	Input.action_press("forward")
	await get_tree().create_timer(2.2).timeout
	await _save_review_image(directory, "body-07-critical-limp")
	Input.action_release("forward")
	print("INTERIOR_BODY health ", snappedf(zombies.health, .1), " limp ", snappedf(player.limp, .01), " bleeding ", snappedf(body.bleeding, .01))

## 0.34 (`--capture-views=glass`): a house window on the street before a round and after two, and a Nichols
## sash from the garden before and after.
func _capture_glass_views(directory: String) -> void:
	if story == null or zombies == null or glass == null:
		return
	_play()
	_apply_quality(2)
	var man := get_node_or_null("Stranger") as Node3D
	if man != null:
		man.process_mode = Node.PROCESS_MODE_DISABLED
		man.visible = false
	zombies.passive = true
	var gun := story.gun
	gun.give()
	gun.infinite_ammo = true
	gun.debug_fill()
	gun.spread_scale = 0.0
	var debug_menu := get_node_or_null("DebugMenu") as InteriorDebugMenu
	if debug_menu != null:
		(debug_menu._controls["fill"] as HSlider).value = 2.2
	gun.draw()
	await get_tree().create_timer(1.4).timeout
	var space := player.get_world_3d().direct_space_state
	var property := get_tree().get_first_node_in_group("nichols_property") as Node3D
	var sets: Array = [["house", true, 2.2, Vector3(2.0, -1.8, 18.0), -1.2]]
	if property != null:
		var house_at := (property.get("house") as Node3D).global_position
		sets.append(["nichols-outside", false, 2.6, house_at + Vector3(0, 2.0, 3.0), house_at.y + 4.2])
		sets.append(["nichols-inside", false, -1.7, house_at + Vector3(-8.0, 2.0, -1.0), house_at.y + 4.2])
	for spec: Array in sets:
		var order: Array = []
		for i in glass.panes.size():
			var pane := glass.panes[i]
			if bool(pane.broken) or bool(pane.solid) != bool(spec[1]) or (pane.at as Vector3).y > float(spec[4]) or bool(pane.get("boarded", false)):
				continue
			order.append([(pane.at as Vector3).distance_to(spec[3]), i])
		order.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		for entry: Array in order:
			var pane := glass.panes[int(entry[1])]
			var at: Vector3 = pane.at
			var out: Vector3 = at + (pane.n as Vector3) * float(spec[2])
			var stand := zombies.ground(Vector3(out.x, at.y, out.z), false)
			if not stand.is_finite() or stand.y > at.y or (bool(spec[1]) and stand.y > -2.6):
				continue
			var eye := stand + Vector3.UP * InteriorPlayer.STANDING_EYE
			var hit := InteriorSurfaces.seen_ray(space, eye, at - (pane.n as Vector3) * .4 * signf(float(spec[2])), 2 | 4)
			if hit.is_empty() or hit.collider != pane.body or (hit.position as Vector3).distance_to(at) > .35:
				continue
			# Look at the middle of the window, a little off square, and fire at this light and the one beside it.
			var middle := at + (pane.x as Vector3) * (float(pane.w) * .5 + .02) * (1.0 if int(entry[1]) % 2 == 0 else -1.0)
			_gun_look(eye, middle)
			await get_tree().create_timer(.8).timeout
			await _save_review_image(directory, "glass-%s-1-whole" % spec[0])
			_gun_look(eye, at + Vector3(.08, .12, 0))
			await get_tree().create_timer(.5).timeout
			gun.try_fire()
			await get_tree().create_timer(.12).timeout
			_gun_look(eye, middle)
			await _save_review_image(directory, "glass-%s-2-breaking" % spec[0])
			await get_tree().create_timer(1.6).timeout
			await _save_review_image(directory, "glass-%s-3-broken" % spec[0])
			print("INTERIOR_GLASS_VIEW ", spec[0], " pane ", entry[1], " at ", at.snapped(Vector3.ONE * .01), " broken ", glass.broken)
			break

## 0.44: the new co-op route from the built game (`-- --capture-review --capture-views=coop_route
## --capture-path=<dir>`): the floodwall ramp and the gate, Jonna's office (door open, Jonna sat), and the backstreets
## to the school. The host alone, the infected left out, the session paused so the shots hold still.
func _capture_coop_route_views(directory: String) -> void:
	if coop == null:
		return
	_apply_quality(2)
	coop.host()
	coop.start_game()
	coop.set_physics_process(false)
	coop.set_process(false)
	story.gun.holster(true)
	hud.hide()
	var m: Node = coop.mission
	var o: Vector3 = m.Street.ORIGIN
	for i in 60:
		await get_tree().process_frame
	var shot := func(label: String, at: Vector3, aim: Vector3) -> void:
		player.reset_motion(o + at)
		player.look_at(Vector3(o.x + aim.x, o.y + at.y, o.z + aim.z))
		player.camera.look_at(o + aim)
		m.street.sync(m.flags)
		for i in 30:
			await get_tree().process_frame
		await _save_review_image(directory, label)
	var G: float = m.Street.APPROACH.G
	await shot.call("route_ramp", Vector3(11.6, G, -5.2), Vector3(2, -1.2, -1.8))
	await shot.call("route_gate", Vector3(1.8, 0, -2.3), Vector3(0, 1.5, 1))
	m.stage = 6
	m.flags.office = true
	m.jonna.visible = true
	for i in 90:
		m.street.sync(m.flags)
		await get_tree().physics_frame
	await shot.call("route_office_door", Vector3(4.1, 0, 66.4), Vector3(4.4, 1.3, 70.0))
	m.jonna.position = o + m.BackOffice.SEAT
	m.jonna.rotation.y = 0.0
	m.jonna.pose("sit_hurt")
	await shot.call("route_office", Vector3(6.9, 0, 70.0), Vector3(2.4, .5, 73.0))
	m.flags.backdoor_open = true
	m.flags.alley = true
	# 0.49: the backstreets are put away until the run reaches them.
	m.wake_ahead()
	for i in 120:
		m.street.sync(m.flags)
		await get_tree().physics_frame
	await shot.call("route_lane", Vector3(-2, 0, 84), Vector3(-2, 2.2, 120))
	await shot.call("route_arcade", Vector3(43, 0, 152), Vector3(43, 2.6, 200))
	await shot.call("route_parol", Vector3(43.0, 1.0, 247.5), Vector3(45.3, 4.4, 252))
	await shot.call("route_poles", Vector3(27.5, 0, 314), Vector3(27.5, 3.2, 380))
	await shot.call("route_school", Vector3(28, 0, 489), Vector3(28, 2.6, 500))
	# 0.45: the darker lanes, with the torch on, and the torch someone dropped.
	story.flashlight.set_on(true)
	for i in 6:
		await get_tree().process_frame
	await shot.call("route_lit_lane", Vector3(-2, 0, 100), Vector3(-2.6, -.4, 108))
	await shot.call("route_lit_poles", Vector3(27.5, 0, 320), Vector3(27.0, -.3, 328))
	story.flashlight.set_on(false)
	await shot.call("route_dropped_torch", Vector3(-1.2, 0, 111.5), Vector3(-3.4, .3, 119.0))

## 0.50: the Prof. Ivan Lawrence College from the built game (`-- --capture-review --capture-views=coop_school
## --capture-path=<dir>`): the story box at the back gate, Rommel behind it, the yard and the facade, the lobby, a
## corridor with students, a classroom by torchlight, a blocked stair, the fifth floor and room 501.
func _capture_coop_school_views(directory: String) -> void:
	if coop == null:
		return
	_apply_quality(2)
	coop.host()
	coop.start_game()
	coop.set_physics_process(false)
	coop.set_process(false)
	story.gun.holster(true)
	var m: Node = coop.mission
	var o: Vector3 = m.Street.ORIGIN
	for i in 60:
		await get_tree().process_frame
	m.debug_jump("school")
	var H: float = m.SCHOOL.H
	var shot := func(label: String, at: Vector3, aim: Vector3, with_hud: bool) -> void:
		player.reset_motion(o + at)
		player.look_at(Vector3(o.x + aim.x, o.y + at.y, o.z + aim.z))
		player.camera.look_at(o + aim)
		hud.visible = with_hud
		for i in 30:
			m.street.sync(m.flags)
			m.school.sync(m.flags, 1.0 / 60.0, player.global_position)
			if with_hud: coop._story_box()
			await get_tree().process_frame
		await _save_review_image(directory, label)
	var pose := func(at: Vector3, yaw: float, clip: String) -> void:
		var z = m.spawn(m.ground(o + at), true, true)
		if z != null:
			z.rotation.y = yaw
			z.pose(clip)
	m.flags.story = 0
	await shot.call("school_story", Vector3(28, 0, 484), Vector3(28, 4.0, 500), true)
	m.flags.story = m.STORY.size()
	m.story_wait = 1e6
	await shot.call("school_gate", Vector3(28, 0, 491), Vector3(28, 4.0, 500), false)
	m.open_school()
	for i in 200:
		m.school.sync(m.flags, 1.0 / 60.0, player.global_position)
		await get_tree().physics_frame
	for e in m.enemies.values(): e.queue_free()
	m.enemies.clear()
	await shot.call("school_guard", Vector3(29.6, 0, 503.4), Vector3(31.55, .55, 502.25), false)
	await shot.call("school_yard", Vector3(28, 0, 501.5), Vector3(28, 6, 514), false)
	await shot.call("school_lobby", Vector3(28, 0, 515.0), Vector3(28, 1.7, 524), false)
	pose.call(Vector3(14, 0, 523.4), PI * .5, "walk_hurt")
	pose.call(Vector3(10, 0, 523.8), PI * .5, "run_hurt")
	await shot.call("school_corridor", Vector3(26, 0, 523.5), Vector3(2, 1.6, 523.5), false)
	await shot.call("school_grand_stair", Vector3(28, 0, 521.5), Vector3(28, 3.0, 532), false)
	story.flashlight.set_on(true)
	for i in 6:
		await get_tree().process_frame
	await shot.call("school_classroom_lit", Vector3(15.0, H, 521.0), Vector3(9, H + .8, 517.5), false)
	await shot.call("school_chem_lit", Vector3(14.5, 2 * H, 520.8), Vector3(3, 2 * H + .8, 517.5), false)
	story.flashlight.set_on(false)
	await shot.call("school_barricade", Vector3(1.65, H, 525.6), Vector3(1.65, H + 2.0, 530), false)
	# 0.51: the dark halls, the desk wall, the fire escape, the ladder, the duct, a class still standing, the
	# staff, a door giving.
	m.flags.fired = (1 << m.school.doors.size()) - 1
	await shot.call("school_dark_hall", Vector3(27, H, 523.5), Vector3(54, H + 1.4, 523.5), false)
	story.flashlight.set_on(true)
	for i in 6:
		await get_tree().process_frame
	await shot.call("school_desk_wall_lit", Vector3(37.5, H, 523.5), Vector3(42, H + 1.2, 523.5), false)
	await shot.call("school_fire_escape_lit", Vector3(57.0, H, 522.0), Vector3(57.6, H + 2.6, 529.5), false)
	for kind in [m.TEACHER_FIRST + 3, m.JANITOR_FIRST + 1, m.TEACHER_FIRST]:
		var z = m.spawn(m.ground(o + Vector3(30 + (kind % 3) * 2.5, 3 * H, 523.2 + (kind % 2) * .6)), true, false, kind)
		if z != null: z.rotation.y = -PI * .5
	await shot.call("school_staff_lit", Vector3(24, 3 * H, 523.5), Vector3(40, 3 * H + 1.3, 523.5), false)
	await shot.call("school_ladder_lit", Vector3(37.8, 3 * H, 527.6), Vector3(36, 3 * H + 2.0, 533.6), false)
	await shot.call("school_duct_lit", Vector3(29.5, 4 * H, 527.0), Vector3(26, 4 * H + .5, 533.2), false)
	for row in 3:
		for col in 3:
			var st = m.spawn(m.ground(o + Vector3(19.5 + row * 1.6, 4 * H, 527.6 + col * 1.7)), true, false, m.STUDENT_FIRST + (row * 3 + col) % 10)
			if st != null: st.rotation.y = PI * .5
	var t2 = m.spawn(m.ground(o + Vector3(17.1, 4 * H, 529.4)), true, false, m.TEACHER_FIRST + 1)
	if t2 != null: t2.rotation.y = -PI * .5
	await shot.call("school_class_standing_lit", Vector3(23.2, 4 * H, 526.2), Vector3(17, 4 * H + 1.2, 530.0), false)
	var d := -1
	for i in m.school.doors.size():
		if m.school.doors[i].room == "304": d = i
	if d >= 0:
		m.flags.broke = 1 << d
		for at: Vector3 in m.school.behind(d, 3):
			var z = m.spawn(m.ground(at), true, true)
			if z != null:
				z.rotation.y = PI
				z.pose("run_hurt")
		for i in 12: await get_tree().physics_frame
		await shot.call("school_door_burst_lit", Vector3(36.0, 2 * H, 522.6), Vector3(38.8, 2 * H + 1.0, 525.5), false)
	story.flashlight.set_on(false)
	pose.call(Vector3(20, 4 * H, 523.4), PI * .5, "walk_hurt")
	await shot.call("school_floor5", Vector3(50, 4 * H, 523.5), Vector3(2, 4 * H + 1.5, 523.5), false)
	await shot.call("school_501", Vector3(7.5, 4 * H, 524.2), Vector3(6.9, 4 * H + 1.3, 522.0), false)

## 0.52: out of PILCST with the survivors of 501 from the built game (`-- --capture-review --capture-views=coop_escape
## --capture-path=<dir>`): Ma'am Teves at 501's door, the room dark for the horde, the horde going by and standing
## in the corridor, the chained fire door, the fire escape to the fifth floor, the gallery down, room 208 blown open,
## the lean-to's roof, the field, the covered court, the rear gate and the city, the chapter's board.
func _capture_coop_escape_views(directory: String) -> void:
	if coop == null:
		return
	_apply_quality(2)
	coop.host()
	coop.start_game()
	coop.set_physics_process(false)
	coop.set_process(false)
	story.gun.holster(true)
	var m: Node = coop.mission
	var o: Vector3 = m.Street.ORIGIN
	for i in 60:
		await get_tree().process_frame
	m.debug_jump("floor5")
	for f in 5: m.flags["floor%d" % f] = true
	m.flags.fired = (1 << m.school.doors.size()) - 1
	for e in m.enemies.values(): e.queue_free()
	m.enemies.clear()
	var H: float = m.SCHOOL.H
	var esc = m.escape
	var shot := func(label: String, at: Vector3, aim: Vector3, with_hud: bool) -> void:
		player.reset_motion(o + at)
		player.look_at(Vector3(o.x + aim.x, o.y + at.y, o.z + aim.z))
		player.camera.look_at(o + aim)
		hud.visible = with_hud
		for i in 40:
			m.street.sync(m.flags)
			m.school.sync(m.flags, 1.0 / 60.0, player.global_position)
			await get_tree().process_frame
		await _save_review_image(directory, label)
	var people := func(spots: Array, clips: Array, yaw: float) -> void:
		for i in esc.people.size():
			var f = esc.people[i]
			var g: Vector3 = m.ground(o + (spots[i] as Vector3))
			f.position = g if g.is_finite() else o + (spots[i] as Vector3)
			f.rotation.y = yaw
			f.pose(clips[i % clips.size()])
	var walker := func(at: Vector3, yaw: float, clip: String) -> void:
		var z = m.spawn(m.ground(o + at), true, true)
		if z != null:
			z.rotation.y = yaw
			z.pose(clip)
	# 501 opens: Ma'am Teves at the door, the four behind her on the mats.
	esc.knocked(1)
	esc.people[0].pose("idle")
	for i in range(1, 5): esc.people[i].pose("sit_hurt")
	await shot.call("escape_teves", Vector3(7.9, 4 * H, 524.4), Vector3(6.6, 4 * H + 1.25, 520.0), false)
	await shot.call("escape_501_inside", Vector3(1.6, 4 * H, 516.0), Vector3(6.6, 4 * H + .9, 521.0), false)
	# Lights off, the door shut; the horde goes by outside.
	m.flags.door501 = 0
	esc.people[0].position = m.ground(o + Vector3(5.2, 4 * H, 520.8))
	esc.people[0].pose("sit_hurt")
	await shot.call("escape_501_dark", Vector3(2.0, 4 * H, 516.4), Vector3(6.9, 4 * H + 1.0, 521.8), false)
	for i in 8:
		walker.call(Vector3(9.0 + i * 1.9, 4 * H, 523.5 + (.6 if i % 2 == 0 else -.6)), PI * .5, "walk_hurt")
	await shot.call("escape_horde_passing", Vector3(1.4, 4 * H, 523.3), Vector3(20.0, 4 * H + 1.3, 523.5), false)
	story.flashlight.set_on(true)
	for i in 6: await get_tree().process_frame
	await shot.call("escape_horde_passing_lit", Vector3(1.4, 4 * H, 523.3), Vector3(20.0, 4 * H + 1.3, 523.5), false)
	story.flashlight.set_on(false)
	for e in m.enemies.values(): e.queue_free()
	m.enemies.clear()
	# After: standing in the dark the length of the hall; the students behind, crouched.
	m.stage = esc.HIDE
	esc.debug_step()
	for z in esc.horde:
		if is_instance_valid(z): z.pose("idle_hurt")
	m.flags.door501 = 1
	people.call([Vector3(6.4, 4 * H, 521.2), Vector3(5.6, 4 * H, 520.4), Vector3(4.8, 4 * H, 520.9), Vector3(4.0, 4 * H, 520.3), Vector3(3.2, 4 * H, 520.8)], ["crouch_walk"], -PI * .5)
	await shot.call("escape_horde_standing", Vector3(7.4, 4 * H, 522.6), Vector3(30.0, 4 * H + 1.2, 523.6), false)
	story.flashlight.set_on(true)
	for i in 6: await get_tree().process_frame
	await shot.call("escape_horde_standing_lit", Vector3(7.4, 4 * H, 522.6), Vector3(30.0, 4 * H + 1.2, 523.6), false)
	await shot.call("escape_fire_door5_lit", Vector3(52.0, 4 * H, 523.5), Vector3(55.8, 4 * H + 1.2, 523.5), false)
	story.flashlight.set_on(false)
	for e in m.enemies.values(): e.queue_free()
	m.enemies.clear()
	# The chain off, out onto the fire escape: the students coming down behind.
	esc.unchain()
	for i in 90:
		m.school.sync(m.flags, 1.0 / 60.0, player.global_position)
		await get_tree().process_frame
	people.call([Vector3(56.65, 4 * H, 524.6), Vector3(56.65, 3 * H + 2.7, 527.0), Vector3(56.8, 4 * H, 523.0), Vector3(55.2, 4 * H, 523.5), Vector3(54.0, 4 * H, 523.5)], ["crouch_walk"], PI)
	await shot.call("escape_fire_escape_5f", Vector3(57.9, 4 * H, 522.2), Vector3(56.65, 3 * H + 1.0, 528.5), false)
	await shot.call("escape_fire_escape_full", Vector3(61.6, 1.6, 515.0), Vector3(57.0, 9.0, 527.0), false)
	# The gas store goes up: the gallery down on the grand stair, 208 blown open, the field full of them.
	m.stage = esc.SNEAK
	esc.blast()
	for e in m.enemies.values(): e.pose("walk_hurt")
	for i in 60:
		m.school.sync(m.flags, 1.0 / 60.0, player.global_position)
		await get_tree().physics_frame
	await shot.call("escape_collapse", Vector3(28.0, H, 523.2), Vector3(28.0, H + 1.0, 526.5), false)
	await shot.call("escape_208", Vector3(14.6, H, 523.4), Vector3(11.0, H + 1.0, 531.5), false)
	people.call([Vector3(13.2, H, 531.6), Vector3(11.8, H, 532.4), Vector3(10.4, H, 531.4), Vector3(14.4, H, 529.6), Vector3(9.4, H, 532.0)], ["idle_hurt"], PI)
	await shot.call("escape_breach", Vector3(12.0, H, 528.6), Vector3(11.0, 2.0, 545.0), false)
	people.call([Vector3(11.0, 2.9, 535.6), Vector3(12.4, 2.7, 537.0), Vector3(9.6, 2.6, 538.0), Vector3(13.4, 3.0, 534.8), Vector3(10.6, 2.5, 538.8)], ["crouch_walk"], PI)
	await shot.call("escape_roof", Vector3(12.6, 2.9, 534.6), Vector3(20.0, 1.0, 556.0), false)
	await shot.call("escape_back", Vector3(24.0, 0, 552.0), Vector3(12.0, 4.5, 534.0), false)
	people.call([Vector3(10.2, 0, 544.0), Vector3(9.0, 0, 543.0), Vector3(11.6, 0, 542.6), Vector3(8.4, 0, 541.8), Vector3(10.4, 0, 541.4)], ["fem_run", "run", "run", "fem_run", "fem_run"], PI)
	for e in m.enemies.values():
		e.asleep = false
		e.pose("run_hurt")
		e.rotation.y = atan2(-(o.x + 11.0 - e.position.x), -(o.z + 544.0 - e.position.z))
	await shot.call("escape_field", Vector3(11.6, 0, 540.8), Vector3(22.0, 1.2, 566.0), false)
	await shot.call("escape_court", Vector3(30.0, 0, 560.0), Vector3(49.0, 2.5, 572.0), false)
	for e in m.enemies.values(): e.queue_free()
	m.enemies.clear()
	people.call([Vector3(43.0, 0, 596.0), Vector3(44.6, 0, 595.4), Vector3(42.2, 0, 594.6), Vector3(45.4, 0, 596.6), Vector3(43.8, 0, 594.0)], ["idle_hurt"], PI)
	await shot.call("escape_rear_gate", Vector3(41.0, 0, 588.0), Vector3(44.0, 2.4, 604.0), false)
	await shot.call("escape_city", Vector3(44.0, 0, 603.5), Vector3(52.0, 4.0, 616.0), false)
	# Out: the chapter's board.
	m.stage = esc.FIELD
	esc.out()
	coop.local_menu = true
	_show_menu("coop_board")
	for i in 20: await get_tree().process_frame
	await _save_review_image(directory, "escape_board")

## 0.53: Heavy-arm at PILCST's rear gate from the built game (`-- --capture-review --capture-views=coop_heavyarm
## --capture-path=<dir>`): sat against the shut gate among the fuel drums, close, the squad's lines, up and roaring
## with the boss bar, the charge's lane and the charge, the throw's rings and the slabs in the air, a drum going up on
## him, dazed, the roar's arrow, a close look, dead with the key shining, the gate open, a teammate's name far off,
## the board loading the next chapter and the loading screen into it. Host and one squad AI, harmless.
func _capture_coop_heavyarm_views(directory: String) -> void:
	if coop == null:
		return
	_apply_quality(2)
	coop.host()
	coop.add_bot()
	coop.start_game()
	coop.harmless = true
	var m: Node = coop.mission
	var o: Vector3 = m.Street.ORIGIN
	for i in 60:
		await get_tree().process_frame
	m.debug_jump("heavyarm")
	for i in 30:
		await get_tree().physics_frame
	coop.set_physics_process(false)
	story.gun.holster(true)
	var f = m.escape.fight
	f._ensure_boss()
	var boss = f.boss
	for e in m.enemies.values():
		if e != boss: e.queue_free()
	for k in m.enemies.keys():
		if m.enemies[k] != boss: m.enemies.erase(k)
	for id: int in coop.team:
		if coop.is_bot(id): coop.team[id].pos = o + Vector3(6.0, 0, 545.0)
	var shot := func(label: String, at: Vector3, aim: Vector3, with_hud: bool) -> void:
		player.reset_motion(o + at)
		player.look_at(Vector3(o.x + aim.x, o.y + at.y, o.z + aim.z))
		player.camera.look_at(o + aim)
		coop.team[1].pos = player.global_position
		hud.visible = with_hud
		for i in 40:
			f._publish()
			m.school.sync(m.flags, 1.0 / 60.0, player.global_position)
			await get_tree().process_frame
		await _save_review_image(directory, label)
	var put := func(at: Vector3, yaw: float, clip: String, seek := 0.0) -> void:
		var g: Vector3 = m.ground(o + at)
		boss.position = g if g.is_finite() else o + at
		boss.rotation.y = yaw
		boss.reset_physics_interpolation()
		boss.pose(clip)
		boss.clips.seek(seek, true)
	# Sat against the shut gate, waiting.
	await shot.call("heavy_gate_far", Vector3(30.0, 0, 583.0), Vector3(44.0, 1.0, 598.0), false)
	story.flashlight.set_on(true)
	await shot.call("heavy_gate_close", Vector3(41.0, 0, 592.4), Vector3(44.0, .8, 598.0), false)
	story.flashlight.set_on(false)
	# Seen: the squad's lines.
	f.spotter = 1
	f.talk_i = 1
	f.talk_wait = 99.0
	f._go("talk")
	m.say("Ma'am Teves\nDiyos ko... Mang Dado? That's Mang Dado. He kept this gate. He locked it every night at nine.", 30)
	await shot.call("heavy_talk", Vector3(36.5, 0, 589.0), Vector3(44.0, 1.0, 598.0), true)
	m.say("", .1)
	# Up and roaring: the bar.
	f._go("fight")
	story.flashlight.set_on(true)
	put.call(Vector3(43.0, 0, 594.5), atan2(5.0, 6.0), "boss_roar", .5)
	await shot.call("heavy_roar_up", Vector3(38.0, 0, 588.5), Vector3(43.0, 1.8, 594.5), true)
	put.call(Vector3(33.0, 0, 591.0), atan2(5.0, 8.0), "heavy_walk", .3)
	await shot.call("heavy_walk", Vector3(28.0, 0, 583.0), Vector3(33.0, 1.6, 591.0), true)
	# The charge.
	put.call(Vector3(24.0, 0, 580.0), 0.0, "heavy_wind", .4)
	f.target = 1
	f.lane_from = boss.position
	f.lane_dir = Vector3(0, 0, -1)
	f.lane_len = 22.0
	f._go("wind_charge")
	# 0.54: still hunting (the flashlight lags and flickers), then held (steady, the lane where he will run), then
	# stood in it looking back up the beam (the lens flares).
	f.state_time = .8
	await shot.call("heavy_charge_track", Vector3(27.0, 0, 562.0), Vector3(24.0, .4, 574.0), true)
	f.state_time = 2.0
	f.render(1.0 / 60.0)
	await shot.call("heavy_charge_wind", Vector3(25.5, 0, 563.0), Vector3(24.0, .4, 576.0), true)
	await shot.call("heavy_charge_glare", Vector3(24.0, 0, 565.0), Vector3(24.0, 1.8, 580.0), true)
	f._go("charge")
	put.call(Vector3(24.0, 0, 570.0), 0.0, "heavy_charge", .2)
	await shot.call("heavy_charge", Vector3(25.0, 0, 563.0), Vector3(24.0, 1.6, 570.0), true)
	# The throw.
	put.call(Vector3(20.0, 0, 584.0), 0.0, "heavy_dig", .3)
	f._go("wind_throw")
	f._marks_host = [[o + Vector3(20.0, 0, 566.0), 3.0], [o + Vector3(23.5, 0, 568.0), 1.9], [o + Vector3(17.0, 0, 563.5), 1.9]]
	await shot.call("heavy_throw_wind", Vector3(24.0, 0, 560.0), Vector3(20.0, .6, 574.0), true)
	f._marks_host.clear()
	f._go("throw")
	put.call(Vector3(20.0, 0, 584.0), 0.0, "heavy_throw", .45)
	var hand: Vector3 = boss.position + Vector3.UP * 2.7
	f.rocks = [[901, hand, o + Vector3(20.0, 0, 566.0), f.clock - .55, 1.2, 1.0, 3.0], [902, hand, o + Vector3(23.5, 0, 568.0), f.clock - .5, 1.3, .55, 1.9], [903, hand, o + Vector3(17.0, 0, 563.5), f.clock - .45, 1.4, .55, 1.9]]
	f._publish()
	for i in 3:
		f.render(1.0 / 60.0)
		await get_tree().process_frame
	player.reset_motion(o + Vector3(24.0, 0, 560.0))
	player.look_at(Vector3(o.x + 20.0, o.y, o.z + 576.0))
	player.camera.look_at(o + Vector3(20.0, 2.5, 575.0))
	hud.visible = true
	for i in 4:
		f.render(1.0 / 60.0)
		await get_tree().process_frame
	await _save_review_image(directory, "heavy_throw_slabs")
	f.rocks.clear()
	# A drum going up on him; dazed.
	put.call(Vector3(29.6, 0, 593.0), PI * .3, "stagger_heavy", .3)
	f._go("daze")
	m.flags.drums = int(m.flags.get("drums", 0)) | 1
	f.render(1.0 / 60.0)
	for i in 6: await get_tree().process_frame
	player.reset_motion(o + Vector3(25.5, 0, 586.0))
	player.look_at(Vector3(o.x + 30.0, o.y, o.z + 593.0))
	player.camera.look_at(o + Vector3(30.0, 1.4, 593.0))
	await _save_review_image(directory, "heavy_drum_blast")
	for i in 50: await get_tree().process_frame
	put.call(Vector3(29.6, 0, 593.0), PI * .3, "heavy_daze", .5)
	await shot.call("heavy_dazed", Vector3(26.0, 0, 588.0), Vector3(29.6, 1.5, 593.0), true)
	# 0.54: breathing in through the whistle, the flashlight turned up into the sky.
	f._go("wind_roar")
	f.state_time = 1.9
	put.call(Vector3(32.0, 0, 592.0), atan2(2.0, 12.0), "heavy_inhale", .6)
	await shot.call("heavy_roar_beacon", Vector3(25.0, 0, 572.0), Vector3(31.0, 7.0, 590.0), true)
	# The roar: the arrow toward the pack behind.
	f._go("roar")
	put.call(Vector3(32.0, 0, 592.0), atan2(2.0, 12.0), "boss_roar", .6)
	f.horde_at = o + Vector3(20.0, 0, 545.0)
	f.horde_until = f.clock + 99.0
	await shot.call("heavy_roar_arrow", Vector3(30.0, 0, 580.0), Vector3(32.0, 1.8, 592.0), true)
	f.horde_until = 0.0
	# Close: the heavy arm.
	f._go("fight")
	put.call(Vector3(40.0, 0, 592.0), atan2(3.0, 4.0), "heavy_idle", .4)
	await shot.call("heavy_close", Vector3(37.0, 0, 588.0), Vector3(40.0, 1.6, 592.0), false)
	put.call(Vector3(40.0, 0, 592.0), atan2(3.0, 4.0), "heavy_inhale", .6)
	await shot.call("heavy_inhale", Vector3(37.0, 0, 588.0), Vector3(40.0, 1.8, 592.0), false)
	story.flashlight.set_on(false)
	# Down: the key shining where he fell; the gate open.
	f.hp = 1.0
	f._take(1, 10.0, true)
	for i in 90: await get_tree().physics_frame
	await shot.call("heavy_dead_key", Vector3(42.0, 0, 586.0), Vector3(44.0, .3, 591.0), true)
	f.take_key(1)
	f.unlock()
	for i in 200:
		m.school.sync(m.flags, 1.0 / 60.0, player.global_position)
		await get_tree().process_frame
	await shot.call("heavy_gate_open", Vector3(44.0, 0, 590.0), Vector3(44.0, 1.6, 604.0), true)
	# A teammate's name far off, with the distance.
	for id: int in coop.team:
		if coop.is_bot(id):
			coop.team[id].pos = o + Vector3(30.0, 0, 548.0)
			coop.team[id].yaw = 0.0
	coop.update_avatars()
	for i in 3:
		coop.update_avatars()
		await get_tree().process_frame
	await shot.call("heavy_teammate_far", Vector3(30.0, 0, 592.0), Vector3(30.0, 1.6, 548.0), true)
	# The board: the next chapter loading; then the loading screen into it (the mart's, into the backstreets).
	m.escape.out()
	coop.set_process(true)
	for i in 4: await get_tree().process_frame
	await _save_review_image(directory, "heavy_board_loading")
	for i in 120:
		await get_tree().process_frame
		if coop._load_done: break
	coop._board_sig = ""
	for i in 6: await get_tree().process_frame
	await _save_review_image(directory, "heavy_board_ready")
	coop.set_process(false)
	coop._load_title = "The backstreets"
	coop._show_chapter_screen()
	coop._screen_time = .5
	coop._chapter_screen_tick()
	for i in 3: await get_tree().process_frame
	await _save_review_image(directory, "chapter_loading_screen")

## 0.49: the end of the mart chapter from the built game (`-- --capture-review --capture-views=coop_chapter
## --capture-path=<dir>`): Jonna at the front pulling the shutter down, the shutter locked, the chapter board with
## READY, and the backstreets after it. The host and one squad AI, the infected cleared, harmless.
func _capture_coop_chapter_views(directory: String) -> void:
	if coop == null:
		return
	_apply_quality(2)
	coop.host()
	coop.add_bot()
	coop.start_game()
	coop.harmless = true
	story.gun.holster(true)
	hud.hide()
	var m: Node = coop.mission
	var o: Vector3 = m.Street.ORIGIN
	var store: Vector3 = o + m.Street.STORE
	for i in 60:
		await get_tree().process_frame
	for k in m.enemies.keys():
		m.enemies[k].queue_free()
		m.enemies.erase(k)
	m.wave_left = 0
	m.flags.office = true
	m.flags.backdoor_open = true
	m.jonna.visible = true
	m.jonna.position = o + m.BackOffice.SEAT
	m.stage = 7
	m.talker = 1
	m.talk_index = m.TALK.size() - 1
	m.talk_wait = 0.0
	var look := func(at: Vector3, aim: Vector3) -> void:
		player.reset_motion(at)
		player.look_at(Vector3(aim.x, at.y, aim.z))
		player.camera.look_at(aim)
	var waited := 0
	while not (int(m.flags.get("lockup", 0)) == 2 and float(m.flags.get("shutter", 0.0)) > .45) and waited < 4000:
		look.call(store + Vector3(2.6, 0, -3.2), store + Vector3(-.6, 1.4, -9.0))
		await get_tree().physics_frame
		waited += 1
	await _save_review_image(directory, "chapter_shutter_coming_down")
	while not bool(m.flags.get("locked", false)) and waited < 6000:
		look.call(store + Vector3(2.6, 0, -3.2), store + Vector3(-.6, 1.4, -9.0))
		await get_tree().physics_frame
		waited += 1
	for i in 20:
		await get_tree().process_frame
	await _save_review_image(directory, "chapter_shutter_locked")
	for i in 40:
		await get_tree().process_frame
	await _save_review_image(directory, "chapter_board")
	coop._board_ready()
	for i in 30:
		await get_tree().physics_frame
	m.flags.alley = true
	for i in 90:
		m.street.sync(m.flags)
		await get_tree().physics_frame
	look.call(o + Vector3(-2, 0, 84), o + Vector3(-2, 2.2, 120))
	for i in 30:
		await get_tree().process_frame
	await _save_review_image(directory, "chapter_backstreets_awake")
	print("INTERIOR_COOP_CHAPTER stage %d board %s" % [int(m.stage), str(coop.board_open)])

## 0.55: the debug missions from the built game (`-- --capture-review --capture-views=coop_jumps --capture-path=<dir>`):
## straight from the start to the brick alley (the mart's chapter loading caught up behind its screen), the Missions
## tab (its jumps by chapter, greyed behind the run, then the teleports), then on to the third floor, Ma'am Teves at
## 501's door (nothing rushing in: the floors below crossed), the landing after the blast (the survivors on it with
## the squad), Heavy-arm's key where he fell, and a teleport to the covered court. Host and one squad AI, harmless.
func _capture_coop_jump_views(directory: String) -> void:
	if coop == null:
		return
	_apply_quality(2)
	coop.host()
	coop.add_bot()
	coop.start_game()
	coop.harmless = true
	for i in 60:
		await get_tree().process_frame
	var m: Node = coop.mission
	var o: Vector3 = m.Street.ORIGIN
	var menu := get_node_or_null("DebugMenu") as InteriorDebugMenu
	var run := func(line: String) -> void:
		menu.coop_as(1, "cmd:" + line, player.global_position)
		print("INTERIOR_COOP_JUMP_VIEW %s -> stage %d at %s" % [line, int(m.stage), str((player.global_position - o).snapped(Vector3.ONE * .1))])
	var look := func(aim: Vector3) -> void:
		player.look_at(Vector3(aim.x, player.global_position.y, aim.z))
		# (The lens is turned from the player's own pitch every frame.)
		var eye: Vector3 = player.camera.global_position
		player._look_pitch = atan2(aim.y - eye.y, Vector2(aim.x - eye.x, aim.z - eye.z).length())
	var wait := func(seconds: float) -> void:
		var t := 0.0
		while t < seconds:
			await get_tree().process_frame
			t += get_process_delta_time()
	run.call("jump brickalley")
	for i in 4:
		await get_tree().process_frame
	await _save_review_image(directory, "jump_1_chapter_loading")
	var waited := 0
	while not coop.chapters_loaded.has("backstreets") and waited < 900:
		await get_tree().process_frame
		waited += 1
	await wait.call(2.2)
	look.call(o + Vector3(28.0, 1.8, 470.0))
	await wait.call(.4)
	await _save_review_image(directory, "jump_2_brickalley")
	menu.show_menu()
	var tabs := menu.find_children("*", "TabContainer", true, false)[0] as TabContainer
	for i in tabs.get_tab_count():
		if tabs.get_tab_title(i) == "Missions": tabs.current_tab = i
	await wait.call(.4)
	await _save_review_image(directory, "jump_3_missions_tab")
	var scroll := tabs.get_current_tab_control() as ScrollContainer
	var first_jump: Control = (menu._jump_buttons["dodong"] as Control).get_parent()
	scroll.scroll_vertical = int(first_jump.position.y) - 70
	await wait.call(.4)
	await _save_review_image(directory, "jump_4_missions_jumps")
	var first_go: Control = (menu._go_buttons["bridge"] as Control).get_parent()
	scroll.scroll_vertical = int(first_go.position.y) - 150
	await wait.call(.4)
	await _save_review_image(directory, "jump_5_missions_teleports")
	menu.close()
	run.call("jump floor3")
	await wait.call(1.6)
	look.call(o + Vector3(30.0, 2 * m.SCHOOL.H + 1.4, 523.5))
	await wait.call(.3)
	await _save_review_image(directory, "jump_6_floor3")
	run.call("jump teves")
	await wait.call(2.4)
	look.call(o + Vector3(6.9, 4 * m.SCHOOL.H + 1.3, 520.4))
	await wait.call(.3)
	await _save_review_image(directory, "jump_7_teves_no_rush")
	run.call("jump blast")
	await wait.call(1.4)
	# (Along the landing, where the squad AI and the students stand.)
	look.call(o + Vector3(57.3, m.SCHOOL.H + 1.0, 528.0))
	await wait.call(.3)
	await _save_review_image(directory, "jump_8_blast_landing")
	run.call("jump heavykey")
	await wait.call(2.0)
	var key = m.flags.get("heavy_key")
	look.call((key if key is Vector3 else o + Vector3(44.0, 0, 597.0)) + Vector3.UP * .2)
	await wait.call(.3)
	await _save_review_image(directory, "jump_9_heavykey")
	run.call("go court")
	await wait.call(1.2)
	look.call(o + Vector3(49.0, 1.6, 580.0))
	await wait.call(.3)
	await _save_review_image(directory, "jump_10_go_court")
	print("INTERIOR_COOP_JUMP_VIEW done: stage %d, chapters %s, cleaned %s" % [int(m.stage), str(coop.chapters_loaded.keys()), str(m.cleaned)])

## 0.45: the multiplayer screens from the built game (`-- --capture-review --capture-views=coop_lobby
## --capture-path=<dir>`): the browser once the online lobby answers, the squad room after hosting (two squad AI,
## a chat line), and the squad chat open during the mission.
func _capture_coop_lobby_views(directory: String) -> void:
	if coop == null:
		return
	coop.lobby.set_player_name("Capture")
	coop.page()
	var until := Time.get_ticks_msec() + 15000
	while not coop.lobby.online and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	print("LOBBY_ONLINE ", coop.lobby.online, " players ", coop.lobby.players.size(), " games ", coop.lobby.games().size())
	for i in 20:
		await get_tree().process_frame
	await _save_review_image(directory, "lobby_browse")
	await coop.host_public()
	coop.add_bot()
	coop.add_bot()
	coop.send_party("Two AI with us. Ready when you are.")
	for i in 30:
		await get_tree().process_frame
	await _save_review_image(directory, "lobby_room")
	coop.start_game()
	for i in 90:
		await get_tree().process_frame
	coop.party_line("Capture", "Stay together past the gate.")
	coop.chat_input.show()
	coop.chat_input.text = "Flashlights on in the alleys"
	for i in 20:
		await get_tree().process_frame
	await _save_review_image(directory, "mission_chat")
	coop.lobby.stop()

## 0.40: co-op from the built game (`Interior.exe -- --capture-review --capture-views=coop --capture-path=<dir>`):
## the host with a full squad of AI on Store Road, a buckshot kill falling as a ragdoll, the voice menu, the rifle
## on its sights. Prints what the squad did.
func _capture_coop_views(directory: String) -> void:
	if coop == null:
		return
	_apply_quality(2)
	coop.host()
	coop.fill_bots()
	coop.start_game()
	for i in 30:
		await get_tree().process_frame
	var m: Node = coop.mission
	for i in 4:
		m.debug_skip()
	m.harmless = true
	m.wave_left = 0
	var stand: Vector3 = m.ground(m.Street.ORIGIN + Vector3(0, 0, 22))
	player.reset_motion(stand)
	coop.team[1].pos = stand
	for id in coop.bots.bots:
		coop.bots.bots[id].body.global_position = stand + Vector3(randf_range(-1.5, 1.5), .1, 1.0 + randf())
	for k in m.enemies.keys():
		m.enemies[k].queue_free()
		m.enemies.erase(k)
	var look := func(p: Vector3) -> void:
		var to: Vector3 = p - player.camera.global_position
		player.rotation = Vector3(0, atan2(-to.x, -to.z), 0)
		player.set("_look_pitch", atan2(to.y, Vector2(to.x, to.z).length()))
		player.camera.rotation.x = player.get("_look_pitch")
		player.aim_offset = Vector2.ZERO
	for i in 8:
		m.spawn(m.ground(stand + Vector3(randf_range(-3, 3), 0, -12 - i * 1.2)))
	look.call(stand + Vector3(0, 1.0, -14))
	for i in 240:
		await get_tree().process_frame
	await _save_review_image(directory, "coop_squad")
	var gun := story.gun
	gun.give_shotgun()
	gun.select("shotgun")
	for id in coop.bots.bots:
		coop.bots.bots[id].mag = 0
		coop.bots.bots[id].reserve = 0
	for i in 80:
		await get_tree().process_frame
	m.spawn(m.ground(stand + Vector3(0, 0, -4)))
	var z = m.enemies[m.next_id]
	z.asleep = true
	for i in 30:
		await get_tree().process_frame
	look.call(z.global_position + Vector3.UP)
	gun.instant_hits = true
	var eye: Vector3 = player.camera.global_position
	var chest: Vector3 = (z.bodies["chest"] as Node3D).global_position
	for i in 9:
		gun._fire_round(eye, ((chest - eye).normalized() + Vector3(randf_range(-.02, .02), randf_range(-.02, .02), 0)).normalized(), InteriorGun.PROFILES.shotgun, i)
	for i in 12:
		await get_tree().process_frame
	await _save_review_image(directory, "coop_ragdoll_falling")
	for i in 150:
		await get_tree().process_frame
	look.call(z.where() + Vector3.UP * .2)
	await get_tree().process_frame
	await _save_review_image(directory, "coop_ragdoll_down")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_QUOTELEFT
	ev.pressed = true
	coop.player_line("lets_go")
	coop.voices._input(ev)
	for i in 20:
		await get_tree().process_frame
	await _save_review_image(directory, "coop_voice_menu")
	coop.voices._input(ev)
	gun.give_rifle()
	gun.select("rifle")
	for i in 90:
		await get_tree().process_frame
	look.call(stand + Vector3(0, 1.4, -20))
	Input.action_press("aim")
	for i in 70:
		await get_tree().process_frame
	await _save_review_image(directory, "coop_rifle_sights")
	Input.action_release("aim")
	# 0.41: Store Road and Mabini Mart, the doorway held with tables, and what a shotgun does to them close up.
	var o: Vector3 = m.Street.ORIGIN
	for spec in [["coop_map_lane", Vector3(-.4, 0, 2.6), Vector3(.6, 1.9, 16)], ["coop_map_road", Vector3(.6, 0, 18.4), Vector3(-.3, 1.6, 40)],
			["coop_map_checkpoint", Vector3(.3, 0, 42.8), Vector3(0, 1.2, 52)], ["coop_map_store", Vector3(1, 0, 47), Vector3(0, 2.5, 59)],
			["coop_map_inside", Vector3(.2, 0, 57.4), Vector3(0, 1.6, 70)]]:
		var at: Vector3 = m.ground(o + spec[1])
		player.reset_motion(at)
		coop.team[1].pos = at
		look.call(o + spec[2])
		for i in 40:
			await get_tree().process_frame
		await _save_review_image(directory, spec[0])
	for k in m.enemies.keys():
		m.enemies[k].queue_free()
		m.enemies.erase(k)
	var tables: Array = m.street.tables
	tables[0].global_position = o + Vector3(0, .08, 56.0)
	tables[0].rotation = Vector3.ZERO
	tables[1].global_position = o + Vector3(0, .08, 55.1)
	tables[1].rotation = Vector3.ZERO
	var inside: Vector3 = m.ground(o + Vector3(0, 0, 60.5))
	player.reset_motion(inside)
	coop.team[1].pos = inside
	for id in coop.bots.bots:
		coop.bots.bots[id].body.global_position = inside + Vector3(randf_range(-2, 2), .1, 2.0)
	for i in 5:
		m.spawn(m.ground(o + Vector3(-1.6 + i * .8, 0, 51.5 - (i % 2) * .8)))
	look.call(o + Vector3(0, 1.0, 54))
	for i in 260:
		await get_tree().process_frame
	await _save_review_image(directory, "coop_barricade")
	var shoved: float = tables[1].global_position.distance_to(o + Vector3(0, .08, 55.1))
	for k in m.enemies.keys():
		m.enemies[k].queue_free()
		m.enemies.erase(k)
	gun.select("shotgun")
	m.spawn(m.ground(inside + Vector3(0, 0, -3.2)))
	var torn = m.enemies[m.next_id]
	torn.asleep = true
	for i in 20:
		await get_tree().process_frame
	look.call(torn.global_position + Vector3.UP * 1.5)
	eye = player.camera.global_position
	var head: Vector3 = (torn.bodies["head"] as Node3D).global_position
	for i in 9:
		gun._fire_round(eye, ((head - eye).normalized() + Vector3(randf_range(-.015, .015), randf_range(-.015, .015), 0)).normalized(), InteriorGun.PROFILES.shotgun, i)
	for i in 10:
		await get_tree().process_frame
	await _save_review_image(directory, "coop_gore_head")
	for i in 90:
		await get_tree().process_frame
	look.call(torn.where() + Vector3.UP * .2)
	await get_tree().process_frame
	await _save_review_image(directory, "coop_gore_down")
	print("INTERIOR_COOP_MAP ", JSON.stringify({"table_shoved_m": shoved, "head_off": torn.severed.has("head"), "parts_off": torn.severed.size(), "seed": coop.run_seed}))
	var kills := 0
	var lines := 0
	for id in coop.team:
		if coop.is_bot(id):
			kills += int(coop.team[id].kills)
	print("INTERIOR_COOP_CAPTURE ", JSON.stringify({"squad": coop.team.size(), "ai_kills": kills, "dead_ragdoll": z.dead and z.sim.is_simulating_physics(),
		"bodies": m.corpses.size(), "voice_clip": coop.voices.stream("Louie", "reloading", 0) != null, "debug_menu_host": get_node("DebugMenu").process_mode != Node.PROCESS_MODE_DISABLED}))
	coop.end_session()

func _capture_zombie_views(directory: String) -> void:
	if story == null or zombies == null:
		return
	_play()
	_apply_quality(2)
	var man := get_node_or_null("Stranger") as Node3D
	if man != null:
		man.process_mode = Node.PROCESS_MODE_DISABLED
		man.visible = false
	var gun := story.gun
	gun.give()
	gun.infinite_ammo = true
	gun.debug_fill()
	gun.give_rifle()
	gun.give_shotgun()
	zombies.passive = true
	zombies.invulnerable = true
	var debug_menu := get_node_or_null("DebugMenu") as InteriorDebugMenu
	if debug_menu != null:
		(debug_menu._controls["fill"] as HSlider).value = 2.2
	var eye := Vector3(20.6, -1.32, 30.0)
	var at := Vector3(23.6, -1.5, 36.0)
	var ahead := (at - eye)
	ahead.y = 0.0
	ahead = ahead.normalized()
	var side := ahead.cross(Vector3.UP).normalized()
	var facing := atan2(ahead.x, ahead.z)
	_gun_look(eye, at)
	await get_tree().create_timer(.3).timeout
	# The seven, side by side.
	for k in InteriorZombie.VARIANTS.size():
		var spot := zombies.ground(eye + ahead * 4.2 + side * (k - 3) * .95, false)
		if spot.is_finite():
			zombies.spawn(spot, InteriorZombie.VARIANTS[k], facing)
	await get_tree().create_timer(1.6).timeout
	await _save_review_image(directory, "zombies-01-the-seven")
	_gun_look(eye + ahead * 1.6, eye + ahead * 4.2 + Vector3(0, -.05, 0))
	await get_tree().create_timer(.4).timeout
	await _save_review_image(directory, "zombies-02-close")
	zombies.clear()
	await get_tree().create_timer(.3).timeout
	# One sees the player, screams and comes.
	_gun_look(eye, at)
	var runner := _capture_zombie(eye + ahead * 9.0, ahead, "kuya", facing)
	zombies.passive = false
	await get_tree().create_timer(.7).timeout
	await _save_review_image(directory, "zombies-03-scream")
	await get_tree().create_timer(1.3).timeout
	await _save_review_image(directory, "zombies-04-coming")
	await get_tree().create_timer(.9).timeout
	await _save_review_image(directory, "zombies-05-in-reach")
	print("INTERIOR_ZOMBIE_CHASE state=", InteriorZombie.State.keys()[runner.state] if is_instance_valid(runner) else "gone",
		" distance=", snappedf(runner.global_position.distance_to(player.global_position), .01) if is_instance_valid(runner) else -1.0)
	zombies.passive = true
	zombies.clear()
	await get_tree().create_timer(.3).timeout
	# The rifle, trigger held, into three of them: out on the open road by the fields.
	var town_eye := eye
	eye = Vector3(21.0, -1.17, 56.0)
	at = Vector3(21.0, -1.4, 64.0)
	ahead = Vector3(at.x - eye.x, 0, at.z - eye.z).normalized()
	side = ahead.cross(Vector3.UP).normalized()
	facing = atan2(ahead.x, ahead.z)
	_gun_look(eye, at)
	for k in 3:
		_capture_zombie(eye + ahead * (5.0 + k * 1.1) + side * (k - 1) * .8, ahead, InteriorZombie.VARIANTS[(k * 2 + 1) % 7], facing)
	gun.select("rifle")
	await get_tree().create_timer(1.3).timeout
	_gun_look(eye, eye + ahead * 5.0 + Vector3(0, -.25, 0))
	await get_tree().create_timer(.3).timeout
	gun.trigger_held = true
	for frame in 10:
		await get_tree().create_timer(.07).timeout
		await _save_review_image(directory, "zombies-06-rifle-%02d" % frame)
		if frame == 4:
			player.look(Vector2(-55, 0))
		if frame == 7:
			player.look(Vector2(110, 0))
	gun.trigger_held = false
	await get_tree().create_timer(2.2).timeout
	await _save_review_image(directory, "zombies-07-after-the-string")
	print("INTERIOR_ZOMBIES alive=", zombies.alive().size(), " kills=", zombies.kills, " blood=", zombies.blood.count())
	gun.holster(true)
	_gun_look(eye + ahead * 3.0 + Vector3(0, .4, 0), eye + ahead * 6.0 + Vector3(0, -1.3, 0))
	await get_tree().create_timer(1.5).timeout
	await _save_review_image(directory, "zombies-08-the-road")
	# The shotgun at arm's length.
	zombies.clear()
	await get_tree().create_timer(.3).timeout
	_gun_look(eye, at)
	_capture_zombie(eye + ahead * 2.6, ahead, "tambay", facing)
	gun.select("shotgun")
	await get_tree().create_timer(1.4).timeout
	_gun_look(eye, eye + ahead * 2.6 + Vector3(0, -.2, 0))
	await get_tree().create_timer(.3).timeout
	await _save_review_image(directory, "zombies-09-shotgun-ready")
	gun.try_fire()
	for frame in 6:
		await _save_review_image(directory, "zombies-10-blast-%d" % frame)
		await get_tree().create_timer(.05).timeout
	await get_tree().create_timer(.5).timeout
	await _save_review_image(directory, "zombies-11-thrown")
	await get_tree().create_timer(2.0).timeout
	await _save_review_image(directory, "zombies-12-where-it-landed")
	for corpse in get_tree().get_nodes_in_group("zombie_corpses"):
		print("INTERIOR_ZOMBIE_THROWN ", snappedf((corpse as InteriorZombie).chest_position().distance_to(eye + ahead * 2.6), .01), " m")
	# One against a wall.
	eye = town_eye
	zombies.clear()
	gun.holster(true)
	await get_tree().create_timer(.3).timeout
	var space := get_world_3d().direct_space_state
	var wall := Vector3.INF
	var wall_normal := Vector3.ZERO
	for k in 36:
		var a := TAU * k / 36.0
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + Vector3(sin(a), 0, cos(a)) * 14.0, 2))
		if hit and absf((hit.normal as Vector3).y) < .2 and eye.distance_to(hit.position) > 4.5:
			wall = hit.position
			wall_normal = hit.normal
			break
	if wall.is_finite():
		var stand := zombies.ground(wall + wall_normal * .9, false)
		if stand.is_finite():
			var to_wall := (wall - eye)
			to_wall.y = 0.0
			zombies.spawn(stand, "nanay", atan2(-to_wall.x, -to_wall.z) + PI)
			var from := wall + wall_normal * 4.2
			from.y = eye.y
			_gun_look(from, stand + Vector3(0, 1.25, 0))
			gun.select("rifle")
			await get_tree().create_timer(1.4).timeout
			gun.trigger_held = true
			await get_tree().create_timer(.45).timeout
			gun.trigger_held = false
			await _save_review_image(directory, "zombies-13-wall-shot")
			await get_tree().create_timer(2.0).timeout
			gun.holster(true)
			await get_tree().create_timer(.3).timeout
			await _save_review_image(directory, "zombies-14-wall-after")
	print("INTERIOR_ZOMBIES end kills=", zombies.kills, " blood=", zombies.blood.count())

## 0.29: what a round does to the infected, seen from beside them with the torch on: a pistol hit to the body frame by
## frame, a head shot's fall, an arm taken off by the rifle and the stump after, a leg taken off by the sniper rifle
## and the crawl, a head under a load of buckshot, a load of buckshot in the chest; then through the sniper's scope
## at 8x and 3x with a shot (`Interior.exe -- --capture-review --capture-views=gore --capture-path=<dir>`).
func _capture_gore_views(directory: String) -> void:
	if story == null or zombies == null:
		return
	_play()
	_apply_quality(2)
	var man := get_node_or_null("Stranger") as Node3D
	if man != null:
		man.process_mode = Node.PROCESS_MODE_DISABLED
		man.visible = false
	var gun := story.gun
	gun.give()
	gun.infinite_ammo = true
	gun.debug_fill()
	gun.give_rifle()
	gun.give_shotgun()
	gun.give_sniper()
	gun.spread_scale = 0.0
	gun.free_aim = false
	zombies.passive = true
	zombies.invulnerable = true
	story.debug_give_flashlight()
	if not story.flashlight.on:
		story.flashlight.toggle()
	var debug_menu := get_node_or_null("DebugMenu") as InteriorDebugMenu
	if debug_menu != null:
		(debug_menu._controls["fill"] as HSlider).value = 1.6
	var eye := Vector3(21.0, -1.17, 56.0)
	var at := Vector3(21.0, -1.4, 64.0)
	var ahead := Vector3(at.x - eye.x, 0, at.z - eye.z).normalized()
	var side := ahead.cross(Vector3.UP).normalized()
	var facing := atan2(ahead.x, ahead.z)
	var stand := eye + ahead * 4.0
	var view := ahead * -1.5 + side * 1.5
	_gun_look(eye, at)
	await get_tree().create_timer(.3).timeout
	# ---- a pistol round into the chest: the flinch, frame by frame
	var one := _capture_zombie(stand, ahead, "kuya", facing)
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(one):
		_gore_view(one, view, 1.25)
		await get_tree().create_timer(.4).timeout
		await _save_review_image(directory, "gore-01-before")
		_gore_shot(one, "chest", "pistol", ahead)
		for frame in 6:
			await _save_review_image(directory, "gore-02-chest-hit-%d" % frame)
			await get_tree().create_timer(.05).timeout
		await get_tree().create_timer(1.6).timeout
		await _save_review_image(directory, "gore-03-bleeding")
		_gore_shot(one, "head", "pistol", ahead)
		for frame in 8:
			await _save_review_image(directory, "gore-04-head-shot-%d" % frame)
			await get_tree().create_timer(.09).timeout
		await get_tree().create_timer(2.2).timeout
		_gore_view(one, view * .8, .3)
		await get_tree().create_timer(.3).timeout
		await _save_review_image(directory, "gore-05-where-it-fell")
		print("INTERIOR_GORE one: state ", InteriorZombie.State.keys()[one.state], " severed ", one.severed.keys())
	zombies.clear()
	await get_tree().create_timer(.3).timeout
	# ---- the rifle takes an arm off
	var two := _capture_zombie(stand, ahead, "tambay", facing)
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(two):
		_gore_view(two, ahead * -1.7 - side * 1.0, 1.25)
		await get_tree().create_timer(.4).timeout
		for shot in 4:
			if not two._bodies.has("upper_arm.L"):
				break
			_gore_shot(two, "upper_arm.L", "rifle", ahead)
			await get_tree().create_timer(.1).timeout
		for frame in 6:
			await _save_review_image(directory, "gore-06-arm-off-%d" % frame)
			await get_tree().create_timer(.08).timeout
		await get_tree().create_timer(1.0).timeout
		if not two.ragdolled:
			_gore_view(two, ahead * -1.0 - side * .9, 1.35)
			await get_tree().create_timer(.5).timeout
			await _save_review_image(directory, "gore-08-the-stump")
			await get_tree().create_timer(.35).timeout
			await _save_review_image(directory, "gore-08-the-stump-pumping")
		await get_tree().create_timer(2.5).timeout
		_gore_view(two, ahead * -1.6 - side * 1.2 + Vector3(0, 1.0, 0), .1)
		await get_tree().create_timer(.3).timeout
		await _save_review_image(directory, "gore-09-what-dripped")
		print("INTERIOR_GORE two: state ", InteriorZombie.State.keys()[two.state], " severed ", two.severed.keys(), " health ", snappedf(two.health, .1),
			" spots ", zombies.blood.spots(), " parts ", zombies.blood.parts())
	zombies.clear()
	await get_tree().create_timer(.3).timeout
	# ---- the sniper's round takes a leg; then it crawls
	var three := _capture_zombie(stand, ahead, "obrero", facing)
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(three):
		_gore_view(three, view, .9)
		await get_tree().create_timer(.4).timeout
		_gore_shot(three, "shin.R", "sniper", ahead)
		for frame in 8:
			await _save_review_image(directory, "gore-11-leg-off-%d" % frame)
			await get_tree().create_timer(.1).timeout
		await get_tree().create_timer(2.4).timeout
		zombies.passive = false
		await get_tree().create_timer(1.5).timeout
		var from := three.where()
		_gun_look(player.camera.global_position, three.where())
		await get_tree().create_timer(.2).timeout
		await _save_review_image(directory, "gore-12-crawling")
		await get_tree().create_timer(3.0).timeout
		_gun_look(player.camera.global_position, three.where())
		await get_tree().create_timer(.2).timeout
		await _save_review_image(directory, "gore-13-still-coming")
		print("INTERIOR_GORE three: state ", InteriorZombie.State.keys()[three.state], " severed ", three.severed.keys(), " crawled ",
			snappedf(three.where().distance_to(from), .01), " m in 3 s, health ", snappedf(three.health, .1))
		zombies.passive = true
	zombies.clear()
	await get_tree().create_timer(.3).timeout
	# ---- buckshot into a head at arm's length
	var four := _capture_zombie(stand, ahead, "dalaga", facing)
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(four):
		_gore_view(four, view, 1.3)
		await get_tree().create_timer(.4).timeout
		for pellet in 6:
			_gore_shot(four, "head", "shotgun", (ahead + Vector3(randf_range(-.05, .05), randf_range(-.05, .05), 0)).normalized())
		for frame in 7:
			await _save_review_image(directory, "gore-14-buckshot-head-%d" % frame)
			await get_tree().create_timer(.07).timeout
		await get_tree().create_timer(2.2).timeout
		_gore_view(four, view * .8, .3)
		await get_tree().create_timer(.4).timeout
		await _save_review_image(directory, "gore-15-after")
		print("INTERIOR_GORE four: state ", InteriorZombie.State.keys()[four.state], " severed ", four.severed.keys(), " parts ", zombies.blood.parts())
	zombies.clear()
	await get_tree().create_timer(.3).timeout
	# ---- and a whole load into the chest
	var five := _capture_zombie(stand, ahead, "tanod", facing)
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(five):
		_gore_view(five, view * 1.25, .9)
		await get_tree().create_timer(.4).timeout
		var was := five.global_position
		for pellet in 9:
			_gore_shot(five, "chest" if pellet < 6 else "spine", "shotgun", (ahead + Vector3(randf_range(-.04, .04), randf_range(-.04, .04), 0)).normalized())
		for frame in 8:
			await _save_review_image(directory, "gore-16-buckshot-chest-%d" % frame)
			await get_tree().create_timer(.09).timeout
		await get_tree().create_timer(2.0).timeout
		print("INTERIOR_GORE five: state ", InteriorZombie.State.keys()[five.state], " thrown ", snappedf(five.where().distance_to(was), .01), " m")
	zombies.clear()
	await get_tree().create_timer(.3).timeout
	# ---- the sniper rifle in the hands, and its scope: three of them far down the road
	_gun_look(eye, at)
	var far: Array[InteriorZombie] = []
	for k in 3:
		var target := _capture_zombie(eye + ahead * (24.0 + 9.0 * k) + side * (k - 1) * 1.6, ahead, InteriorZombie.VARIANTS[(k * 3 + 2) % 7], facing + PI)
		if target != null:
			far.append(target)
	gun.select("sniper")
	await get_tree().create_timer(1.8).timeout
	await _save_review_image(directory, "gore-17-sniper-in-the-hands")
	if not far.is_empty():
		await _gore_aim(far[0], "chest")
		Input.action_press("aim")
		for frame in 4:
			await get_tree().create_timer(.09).timeout
			await _save_review_image(directory, "gore-18-eye-to-the-scope-%d" % frame)
		await get_tree().create_timer(.8).timeout
		await _gore_aim(far[0], "head")
		await get_tree().create_timer(.4).timeout
		await _save_review_image(directory, "gore-19-scope-8x")
		print("INTERIOR_SCOPE zoom ", gun.scope_zoom, " scoped ", snappedf(gun.scoped, .01), " fov ", snappedf(player.camera.fov, .01), " look ", snappedf(player.look_scale, .001))
		gun.turn_scope(-5)
		await get_tree().create_timer(.1).timeout
		await _save_review_image(directory, "gore-20-turning-the-ring")
		await get_tree().create_timer(.9).timeout
		await _save_review_image(directory, "gore-21-scope-3x")
		print("INTERIOR_SCOPE zoom ", gun.scope_zoom, " fov ", snappedf(player.camera.fov, .01))
		gun.turn_scope(5)
		Input.action_press("run")
		await get_tree().create_timer(.9).timeout
		await _gore_aim(far[0], "chest")
		gun.try_fire()
		Input.action_release("run")
		for frame in 6:
			await _save_review_image(directory, "gore-22-scope-shot-%d" % frame)
			await get_tree().create_timer(.08).timeout
		await get_tree().create_timer(1.2).timeout
		await _save_review_image(directory, "gore-23-scope-after")
		print("INTERIOR_GORE far: state ", InteriorZombie.State.keys()[far[0].state], " severed ", far[0].severed.keys(), " distance ",
			snappedf(far[0].where().distance_to(player.global_position), .1))
		Input.action_release("aim")
	await get_tree().create_timer(.4).timeout
	print("INTERIOR_GORE end kills=", zombies.kills, " splats=", zombies.blood.count(), " spots=", zombies.blood.spots(), " parts=", zombies.blood.parts())

## The lens beside one of the infected: `offset` from where it is, looking at it `height` above its feet.
func _gore_view(zombie: InteriorZombie, offset: Vector3, height: float) -> void:
	var target := zombie.where() if zombie.ragdolled else zombie.global_position + Vector3(0, height, 0)
	_gun_look(target + offset + (Vector3(0, .25, 0) if not zombie.ragdolled else Vector3(0, 1.3, 0)), target)

## One round of `weapon` into `bone`, travelling along `way`, as scripts/gun.gd would deliver it at arm's length.
func _gore_shot(zombie: InteriorZombie, bone: String, weapon: String, way: Vector3) -> void:
	var body := zombie._bodies.get(bone) as PhysicalBone3D
	if body == null:
		return
	var p: Dictionary = InteriorGun.PROFILES[weapon]
	zombie.shot(body, body.global_position - way * float((InteriorZombie.BODIES[bone] as Array)[1]), way, float(p.damage), float(p.knock), weapon,
		float(p.damage) * float(p.get("sever", .5)))

## 0.43: a grenade among four infected on the open road: the throw from the hands, the blast frame by frame, where
## they were thrown, and a shotgun and a sniper hit for the throw by heavy rounds
## (`-- --capture-review --capture-views=grenade --capture-path=<dir>`).
func _capture_grenade_views(directory: String) -> void:
	if story == null or zombies == null or grenades == null:
		return
	_play()
	_apply_quality(2)
	var man := get_node_or_null("Stranger") as Node3D
	if man != null:
		man.process_mode = Node.PROCESS_MODE_DISABLED
		man.visible = false
	zombies.passive = true
	zombies.invulnerable = true
	story.debug_give_flashlight()
	if not story.flashlight.on:
		story.flashlight.toggle()
	var eye := Vector3(21.0, -1.17, 56.0)
	var at := Vector3(21.0, -1.4, 64.0)
	var ahead := Vector3(at.x - eye.x, 0, at.z - eye.z).normalized()
	var side := ahead.cross(Vector3.UP).normalized()
	var facing := atan2(-ahead.x, -ahead.z)
	var centre := eye + ahead * 9.0
	var crowd: Array = []
	for offset: Vector3 in [Vector3.ZERO, side * 1.4, -side * 1.3, ahead * 1.5, side * 3.2]:
		var z := _capture_zombie(centre + offset, ahead, ["kuya", "tambay", "obrero", "tanod", "kuya"][crowd.size()], facing)
		if z != null:
			crowd.append(z)
	_gun_look(eye, centre + Vector3.UP * .6)
	await get_tree().create_timer(1.2).timeout
	await _save_review_image(directory, "grenade-01-before")
	grenades.give(3)
	var start: Array = []
	for z: InteriorZombie in crowd:
		start.append(z.where())
	# The throw, as the player makes it: the pin, a moment's cook, let go.
	var from := player.camera.global_position
	grenades.call("_spawn", "capture:1", from + ahead * .5 + Vector3.DOWN * .1, (centre - from).normalized() * 8.6 + Vector3.UP * 3.0, 1.6, true)
	for frame in 6:
		await get_tree().create_timer(.22).timeout
		await _save_review_image(directory, "grenade-02-flight-%d" % frame)
	await get_tree().create_timer(.2).timeout
	for frame in 8:
		await _save_review_image(directory, "grenade-03-blast-%d" % frame)
		await get_tree().create_timer(.06).timeout
	await get_tree().create_timer(2.5).timeout
	await _save_review_image(directory, "grenade-04-after")
	var thrown: Array = []
	for i in crowd.size():
		var z: InteriorZombie = crowd[i]
		if is_instance_valid(z):
			thrown.append("%s %.1f m %s severed %s" % [InteriorZombie.State.keys()[z.state], z.where().distance_to(start[i]), "dead" if z.health <= 0.0 else "alive", z.severed.keys()])
	print("INTERIOR_GRENADE ", thrown)
	_gun_look(eye + side * 4.0 + Vector3.UP * 1.5, centre)
	await get_tree().create_timer(.4).timeout
	await _save_review_image(directory, "grenade-05-side")
	zombies.clear()
	await get_tree().create_timer(.3).timeout
	# Buckshot up close and the sniper: thrown, not just dropped.
	for weapon: String in ["shotgun", "sniper"]:
		var z := _capture_zombie(eye + ahead * 4.0, ahead, "tambay", facing)
		if z == null:
			continue
		await get_tree().create_timer(.8).timeout
		var where := z.where()
		if weapon == "shotgun":
			for pellet in 8:
				_gore_shot(z, ["chest", "spine", "chest", "upper_arm.L", "chest", "hips", "spine", "head"][pellet], "shotgun", ahead)
		else:
			_gore_shot(z, "chest", "sniper", ahead)
		_gun_look(eye + side * 3.0 + Vector3.UP * .8, eye + ahead * 6.0)
		for frame in 5:
			await get_tree().create_timer(.12).timeout
			await _save_review_image(directory, "grenade-06-%s-%d" % [weapon, frame])
		await get_tree().create_timer(2.0).timeout
		print("INTERIOR_THROWN ", weapon, " %.1f m" % z.where().distance_to(where))
		zombies.clear()
		await get_tree().create_timer(.3).timeout
		_gun_look(eye, centre)

## The lens onto one of an infected's hit boxes.
func _gore_aim(zombie: InteriorZombie, bone: String) -> void:
	for pass_index in 2:
		var body := zombie._bodies.get(bone) as PhysicalBone3D
		if body == null:
			return
		var to := body.global_position - player.camera.global_position
		player.rotation = Vector3(0, atan2(-to.x, -to.z), 0)
		player.set("_look_pitch", atan2(to.y, Vector2(to.x, to.z).length()))
		player.aim_offset = Vector2.ZERO
		await get_tree().physics_frame
		await get_tree().process_frame

## An infected on open ground at `spot`, or the nearest place along `ahead` that has room.
func _capture_zombie(spot: Vector3, ahead: Vector3, variant: String, facing: float) -> InteriorZombie:
	for extra: float in [0.0, -.9, .9, -1.8, 1.8, 2.7]:
		var place := zombies.ground(spot + ahead * extra, false)
		if place.is_finite():
			return zombies.spawn(place, variant, facing, false, "runner")
	return null

## 0.31: how the hands hold each weapon: the body camera's own picture (ready, sights up, mid-reload) and the same
## hands looked at from outside, from both sides, from below and from above
## (`Interior.exe -- --capture-review --capture-views=hands [--hands=pistol,rifle] --capture-path=<dir>`).
func _capture_hand_views(directory: String) -> void:
	if story == null:
		return
	_play()
	_apply_quality(2)
	var man := get_node_or_null("Stranger") as Node3D
	if man != null:
		man.process_mode = Node.PROCESS_MODE_DISABLED
		man.visible = false
	var gun := story.gun
	gun.give()
	gun.infinite_ammo = true
	gun.debug_fill()
	gun.give_rifle()
	gun.give_shotgun()
	gun.give_sniper()
	var which_ones := ["pistol", "rifle", "shotgun", "sniper"]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--hands="):
			which_ones = Array(argument.trim_prefix("--hands=").split(","))
	var pov := "--hands-pov" in OS.get_cmdline_user_args()
	var eye := Vector3(.62, 1.6, 1.3)
	var at := Vector3(.62, 1.4, -2.4)
	for which: String in which_ones:
		_gun_look(eye, at)
		gun.select(which)
		await get_tree().create_timer(1.7).timeout
		await _save_review_image(directory, which + "-1-ready")
		var long := which != "pistol"
		var mid := Vector3(.0, -.11, -.34) if long else Vector3(.01, -.12, -.25)
		var far := .62 if long else .4
		var views := [["2-left", Vector3(-far, .03, .0)], ["3-right", Vector3(far, .03, .0)], ["4-below", Vector3(.06, -far * .75, -far * .6)],
			["5-above", Vector3(-.04, far * .85, far * .45)], ["6-front", Vector3(-.08, .02, -far)]]
		for view: Array in ([] if pov else views):
			gun.inspect_view(mid + (view[1] as Vector3), mid)
			await get_tree().process_frame
			await get_tree().process_frame
			await _save_review_image(directory, "%s-%s" % [which, view[0]])
		gun.inspect_view()
		Input.action_press("aim")
		await get_tree().create_timer(.75).timeout
		await _save_review_image(directory, which + "-7-sights")
		Input.action_release("aim")
		await get_tree().create_timer(.6).timeout
		gun.infinite_ammo = false
		gun.mag = 1
		gun.reserve = 60
		gun.reload()
		var marks := [.5, 1.2] if which == "pistol" else ([.3, .45] if which == "shotgun" else [.75, 1.86])
		var clock := 0.0
		for index in marks.size():
			await get_tree().create_timer(float(marks[index]) - clock).timeout
			clock = float(marks[index])
			await _save_review_image(directory, "%s-8-reload-%d" % [which, index])
		gun.inspect_view(mid + (views[0][1] as Vector3), mid)
		await get_tree().process_frame
		await _save_review_image(directory, which + "-9-reload-left")
		gun.inspect_view()
		gun.infinite_ammo = true
		await get_tree().create_timer(3.2).timeout
		gun.debug_fill()

func _gun_look(eye: Vector3, at: Vector3) -> void:
	player.reset_motion(eye - Vector3(0, InteriorPlayer.STANDING_EYE, 0))
	var to := at - eye
	player.rotation = Vector3(0, atan2(-to.x, -to.z), 0)
	player.set("_look_pitch", atan2(to.y, Vector2(to.x, to.z).length()))
	player.recoil = 0.0
	player.camera.rotation.x = player.get("_look_pitch")

func _save_review_image(directory: String, label: String) -> void:
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))
	if result != OK:
		push_error("Review capture failed: " + label)

func _unhandled_input(event: InputEvent) -> void:
	if coop != null and coop.active: return
	if _booting:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		fps_label.visible = not fps_label.visible
	if story != null and story.ui.inspect_active():
		return
	if event.is_action_pressed("pause") and current_menu == "options" and menu.visible:
		_show_menu(_options_return)
		return
	if event.is_action_pressed("pause") and started:
		if player.playing:
			_show_menu("pause")
		else:
			_play()
	if event.is_action_pressed("journal") and player.playing:
		_show_menu("journal")

func _process(delta: float) -> void:
	if _booting or not started or not player.playing:
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
		prompt.text = ("Use • drop     Throw • throw" if mobile else "E • Drop     Left click • Throw")
		if player._grabbed_on_press and player._hold_down:
			prompt.text = "Dragging • let go to drop" if mobile else "Dragging • release E to drop"
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

## The navy balcony door (the studio's glass slider shares the "interior_doors" group).
func entry_door() -> InteriorHingedDoor:
	for door in get_tree().get_nodes_in_group("interior_doors"):
		if door is InteriorHingedDoor and not door is InteriorSlidingDoor:
			return door as InteriorHingedDoor
	return null
