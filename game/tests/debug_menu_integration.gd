extends SceneTree
## 0.20: the debug menu (scripts/debug_menu.gd), headless:
## - Q W E R T Y opens it (a broken or slow sequence does not); Esc and the sequence close it; play resumes;
## - items: the Glock, rounds, fill, infinite ammo, the flashlight and its brightness, the key, everything;
## - lighting: exposure, the ambient override, the moon, the fill light, lamps, fog;
## - player: speed, noclip flight through a wall, teleports onto the floor; world: the drawer, the alarm.
##   godot --headless --fixed-fps 60 --path game --script res://tests/debug_menu_integration.gd

var checks := 0
var failures: Array[String] = []
var main: Node
var player: InteriorPlayer
var story: InteriorStory
var menu: InteriorDebugMenu

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
	print(("PASS " if condition else "FAIL ") + message)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _key(code: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = code
	down.keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame

func _type(codes: Array) -> void:
	for code in codes:
		await _key(code)

func _press(tab: String, text: String) -> void:
	for node in menu.find_children("*", "Button", true, false):
		var b := node as Button
		if b.text == text and b.get_parent().get_parent().get_parent().name == tab:
			b.pressed.emit()
			return
	check(false, "Button %s / %s exists" % [tab, text])

func _run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await _frames(4)
	player = main.player
	story = main.story
	menu = main.get_node_or_null("DebugMenu") as InteriorDebugMenu
	check(menu != null and story != null, "The debug menu and the story are in the scene")
	if menu == null or story == null:
		_finish()
		return
	# 1. Opening.
	await _type([KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T])
	check(not menu.open, "Q W E R T alone does not open it")
	await _type([KEY_Q, KEY_W, KEY_X, KEY_E, KEY_R, KEY_T, KEY_Y])
	check(not menu.open, "A wrong key in the middle breaks the sequence")
	await _type([KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y])
	check(menu.open and menu._panel.visible, "Q W E R T Y opens the debug menu")
	check(not player.playing and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "The player stops and the mouse is free")
	await _key(KEY_ESCAPE)
	check(not menu.open and not menu._panel.visible and player.playing, "Esc closes it and play resumes")
	check(not main.menu.visible, "Esc does not also open the pause menu")
	await _type([KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y])
	check(menu.open, "It opens again")
	# 2. Items.
	check(not story.has_gun, "No Glock before")
	_press("Items", "Give Glock")
	check(story.has_gun and story.gun.owned and story.hut.gun_taken, "Give Glock: owned, gone from the drawer")
	_press("Items", "+60")
	_press("Items", "+200")
	check(story.gun.reserve == 260, "+60 and +200 rounds go to the reserve (%d)" % story.gun.reserve)
	_press("Items", "Fill magazine")
	check(story.gun.loaded() == InteriorGun.MAG_SIZE + 1, "Fill magazine: 17 + 1 (%d)" % story.gun.loaded())
	check(story.inventory_label.text.contains("Glock 17"), "The inventory shows the Glock (%s)" % story.inventory_label.text)
	_press("Items", "Give flashlight")
	check(story.has_flashlight and story.flashlight.owned and story.hut.flashlight_taken, "Give flashlight: owned, gone from the drawer")
	_press("Items", "On / off")
	check(story.flashlight.on, "The flashlight switches on from the menu")
	(menu._controls["torch_energy"] as HSlider).value = 2.0
	await _frames(3)
	# (The bulb's switch-on stutter lasts 0.14 s; headless frames can be shorter: wait for it, not for frames.)
	for i in 120:
		if story.flashlight._flicker < 0.0: break
		await _frames(1)
	await _frames(1)
	check(is_equal_approx(story.flashlight.light.light_energy, InteriorFlashlight.ENERGY * 2.0), "Brightness × 2 (%.1f)" % story.flashlight.light.light_energy)
	(menu._controls["torch_range"] as HSlider).value = 50.0
	check(is_equal_approx(story.flashlight.light.spot_range, 50.0), "Reach 50 m")
	_press("Items", "Give hut key")
	check(story.has_key and story.hut.has_key, "Give hut key")
	(menu._controls["infinite"] as CheckBox).button_pressed = true
	check(story.gun.infinite_ammo, "Infinite ammo on")
	# 3. Lighting.
	(menu._controls["exposure"] as HSlider).value = 2.5
	var attributes := player.camera.attributes as CameraAttributesPractical
	check(attributes != null and is_equal_approx(attributes.exposure_multiplier, 2.5), "Exposure × 2.5 on the camera")
	(menu._controls["ambient"] as HSlider).value = 3.0
	(menu._controls["ambient_on"] as CheckBox).button_pressed = true
	await _frames(3)
	var env := menu._environment()
	check(env != null and is_equal_approx(env.ambient_light_energy, 3.0), "Ambient override holds at 3.0 (%.2f)" % (env.ambient_light_energy if env != null else -1.0))
	var moons := menu._moon_lights()
	var moon_before := moons[0].light_energy if not moons.is_empty() else 0.0
	(menu._controls["moon"] as HSlider).value = 3.0
	check(not moons.is_empty() and is_equal_approx(moons[0].light_energy, moon_before * 3.0), "Moon × 3")
	(menu._controls["fill"] as HSlider).value = 2.0
	await _frames(3)
	check(menu._fill.visible and menu._fill.global_position.distance_to(player.camera.global_position) < 1.0, "The fill light follows the camera")
	var fog_before := env.fog_enabled
	(menu._controls["fog"] as CheckBox).button_pressed = false
	await _frames(3)
	check(env != null and not env.fog_enabled, "Fog off holds")
	(menu._controls["lamps"] as CheckBox).button_pressed = false
	check(story.lamps_lit() == 0, "Street lamps off (%d lit)" % story.lamps_lit())
	(menu._controls["lamps"] as CheckBox).button_pressed = true
	check(story.lamps_lit() > 0, "Street lamps back on (%d lit)" % story.lamps_lit())
	_press("Lighting", "Reset lighting")
	await _frames(3)
	check(is_equal_approx(attributes.exposure_multiplier, 1.0) and not menu._ambient_override and not menu._fill.visible and env.fog_enabled == fog_before, "Reset lighting")
	# 4. Player.
	(menu._controls["speed"] as HSlider).value = 2.0
	check(is_equal_approx(player.debug_speed, 2.0), "Speed × 2")
	(menu._controls["speed"] as HSlider).value = 1.0
	_press("Player", "Courtyard")
	await _frames(20)
	check(player.global_position.distance_to(Vector3(10.0, -2.85, 4.0)) < .6, "Teleport: courtyard, on the floor (%s)" % player.global_position)
	_press("Player", "Hut yard")
	await _frames(30)
	var yard := story.hut.call_spot()
	check(Vector2(player.global_position.x - yard.x, player.global_position.z - yard.z).length() < .5, "Teleport: the hut yard (%s)" % player.global_position)
	# 0.23: the walled town's ways through.
	_press("Player", "Wall hole")
	await _frames(20)
	check(Vector2(player.global_position.x - InteriorTownSiege.HOLE_X, player.global_position.z - (InteriorTownSiege.NORTH_Z - 2.0)).length() < .5 and player.global_position.y < -2.6, "Teleport: in front of the wall hole, on the street (%s)" % player.global_position)
	_press("Player", "Slum passage")
	await _frames(20)
	check(player.global_position.distance_to(Vector3(-20.5, -2.75, 18.1)) < .6, "Teleport: the slum passage (%s)" % player.global_position)
	_press("Player", "Hooded man to hole")
	await _frames(3)
	var man := get_first_node_in_group("stranger")
	check(man == null or man.global_position.distance_to(InteriorTownSiege.STRANGER_WAIT) < .1, "The hooded man can be sent to the hole")
	await _key(KEY_ESCAPE)
	# Noclip: fly up through nothing and stay there (no gravity).
	player.noclip = true
	var start := player.global_position
	Input.action_press("jump")
	await _frames(30)
	Input.action_release("jump")
	await _frames(30)
	check(player.global_position.y > start.y + 1.5, "Noclip: Space flies up and stays (%.2f m)" % (player.global_position.y - start.y))
	player.noclip = false
	await _frames(60)
	check(player.global_position.y < start.y + .5, "Noclip off: gravity again")
	# 5. World.
	await _type([KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y])
	_press("World", "Open the drawer")
	await _frames(150)
	check(story.hut.drawer_open, "Open the drawer")
	_press("World", "Start the alarm")
	await _frames(5)
	check(story.lights_out and story._sirens.size() == 4, "Start the alarm: sirens")
	await _type([KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y])
	check(not menu.open and player.playing, "The sequence closes it too")
	# 6. Infinite ammo: shots leave the magazine full.
	story.gun.toggle()
	await _frames(60)
	for i in 5:
		story.gun.try_fire()
		await _frames(20)
	check(story.gun.loaded() == InteriorGun.MAG_SIZE + 1, "Infinite ammo: still 17 + 1 after 5 shots (%d)" % story.gun.loaded())
	_finish()

func _finish() -> void:
	print("DEBUG_MENU ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
