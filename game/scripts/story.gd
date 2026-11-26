class_name InteriorStory
extends Node
## 0.10: the hut sequence, after the man in the black hoodie runs off the dirt road into the bahay kubo.
##
## 1. The key on the dresser sparkles. Taking it: "You now have the key."
## 2. The key unlocks the dresser's top drawer, which slides open on a Glock 17.
## 3. Taking the gun shows it on screen (drag to rotate, Rack the slide plays its animation, OK takes it).
## 4. The hooded man calls the player out from the yard: three lines of dialogue. Once the player is outside he runs
##    to the scarecrow down the road (waiting if the player falls behind), reaches under it and brings back a box:
##    "Received 60 Glock ammo", followed by the warning to return home.
## 5. Sirens wail across the town and the fields, the street lamps die one by one, and the moon is the only light.
##    Objective: get inside the house and close the navy door; all sirens then stop.
## 0.12: a flashlight lies in the drawer beside the Glock (scripts/flashlight.gd): take it any time once the drawer is
##    open; L (mobile: Light) switches it on and off.
## Restart reloads the scene, so it all plays again. scripts/stranger.gd moves him; scripts/hut_house.gd is the hut.

const SPEAKER := "Hooded man"
const CALL_LINES := ["You have to hurry!",
		"Your wife and 2 daughters are with the association, so you can breathe easy.",
		"Now, I have to give you something. Please follow me."]
const RUN_LINE := "Now, take these with you and go back! Hurry, before they notice!"
const AMMO_GIVEN := 60
const SIREN := "res://assets/audio/sfx/siren_wail.ogg"
## Siren towers: over the town, west and east across the paddies, and far up the road.
const SIREN_SPOTS := [Vector3(4.0, 22.0, 36.0), Vector3(-95.0, 22.0, 170.0), Vector3(115.0, 22.0, 255.0), Vector3(40.0, 22.0, 470.0)]

enum Phase { EXPLORE, HAVE_KEY, DRAWER_OPEN, INSPECTING, CALLED, FOLLOWING, RUN_HOME, HOME }

var phase := Phase.EXPLORE
var main: Node
var player: InteriorPlayer
var hut: InteriorHutHouse
var ui: InteriorStoryUI
var inventory_label: Label
var has_key := false
var has_gun := false
var ammo := 0
var lights_out := false
var _sirens: Array[AudioStreamPlayer3D] = []
var _sfx: AudioStreamPlayer
var _siren_tweens: Array[Tween] = []
var _entered_home := false
var _entry_was_open := false
## 0.11: the Glock, usable once taken (scripts/gun.gd). `ammo` is every round the player has (loaded + reserve).
var gun: InteriorGun
## 0.12: the flashlight from the same drawer.
var flashlight: InteriorFlashlight
var has_flashlight := false

func setup(main_node: Node, hut_house: InteriorHutHouse) -> void:
	main = main_node
	player = main.player
	hut = hut_house
	name = "Story"
	add_to_group("story")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	ui = InteriorStoryUI.new()
	ui.name = "StoryUI"
	ui.mobile = main.mobile
	ui.process_mode = Node.PROCESS_MODE_PAUSABLE
	main.hud.add_child(ui)
	ui.dialogue_finished.connect(_on_dialogue_finished)
	ui.inspect_closed.connect(_on_inspect_closed)
	inventory_label = Label.new()
	inventory_label.add_theme_font_size_override("font_size", 19)
	inventory_label.add_theme_color_override("font_outline_color", Color(.06, .04, .025, .95))
	inventory_label.add_theme_constant_override("outline_size", 4)
	inventory_label.add_theme_color_override("font_color", Color(.93, .82, .6))
	inventory_label.position = Vector2(24, 88)
	main.hud.add_child(inventory_label)
	_sfx = AudioStreamPlayer.new()
	_sfx.name = "StorySfx"
	add_child(_sfx)
	hut.key_taken.connect(_on_key_taken)
	hut.drawer_opened.connect(_on_drawer_opened)
	hut.gun_requested.connect(_on_gun_requested)
	hut.flashlight_picked.connect(_on_flashlight_picked)
	player.hold_hook = consume_hold
	gun = InteriorGun.new()
	add_child(gun)
	gun.setup(main, self)
	gun.ammo_changed.connect(_on_ammo_changed)
	flashlight = InteriorFlashlight.new()
	add_child(flashlight)
	flashlight.setup(main)

func stranger() -> InteriorStranger:
	return get_tree().get_first_node_in_group("stranger") as InteriorStranger

func notify(text: String) -> void:
	ui.notify(text)

## E / Hold while the dialogue box is up moves it on instead of using things.
func consume_hold() -> bool:
	if ui.inspect_active():
		return true
	if ui.dialogue_active():
		ui.advance()
		return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if ui.dialogue_active() and player.playing and (event.is_action_pressed("hold") or event.is_action_pressed("throw")):
		ui.advance()
		get_viewport().set_input_as_handled()

func _update_inventory() -> void:
	var items: Array[String] = []
	if has_key:
		items.append("Key")
	if has_gun:
		items.append("Glock 17" + (" • %d rounds" % ammo if ammo > 0 else ""))
	if has_flashlight:
		items.append("Flashlight")
	inventory_label.text = "  •  ".join(items)

func _play(path: String, volume := 0.0, pitch := 1.0) -> void:
	if ResourceLoader.exists(path):
		_sfx.stream = load(path)
		_sfx.volume_db = volume
		_sfx.pitch_scale = pitch
		_sfx.play()

# ---------------------------------------------------------------- the hut

func _on_key_taken() -> void:
	has_key = true
	phase = Phase.HAVE_KEY
	notify("You now have the key.")
	_update_inventory()

func _on_drawer_opened() -> void:
	phase = Phase.DRAWER_OPEN
	notify("You unlocked the drawer.")

func _on_flashlight_picked() -> void:
	has_flashlight = true
	flashlight.give()
	_update_inventory()
	notify("You took the flashlight. " + ("Tap Light to switch it on." if main.mobile else "Press L to switch it on."))

func _on_gun_requested() -> void:
	phase = Phase.INSPECTING
	player.playing = false
	player.release_object()
	main.touch.set_enabled(false)
	main.prompt.text = ""
	ui.open_inspect()
	_play("res://assets/audio/sfx/gun_pickup.ogg", -4.0)

func _on_inspect_closed(taken: bool) -> void:
	main._play()
	if ui.inspect_carried:
		return
	if not taken:
		phase = Phase.DRAWER_OPEN
		return
	hut.take_gun()
	has_gun = true
	gun.give()
	_update_inventory()
	notify("You took the Glock 17.")
	phase = Phase.CALLED
	await get_tree().create_timer(1.1, false).timeout
	var man := stranger()
	if man != null:
		man.call_out(hut)
	ui.say(SPEAKER, CALL_LINES, 7.0)

func _on_dialogue_finished() -> void:
	# The player's remarks use this dialogue box without advancing the man's story.
	if ui.current_speaker() != SPEAKER:
		return
	match phase:
		Phase.CALLED:
			phase = Phase.FOLLOWING
			var man := stranger()
			if man != null:
				man.lead_to_scarecrow(hut)
		Phase.RUN_HOME:
			var man := stranger()
			if man != null:
				man.leave()

## Called by the stranger when he puts the box in the player's hands.
func receive_ammo() -> void:
	gun.add_rounds(AMMO_GIVEN)
	_update_inventory()
	notify("Received %d Glock ammo" % AMMO_GIVEN)
	_play("res://assets/audio/sfx/ammo_pickup.ogg", -2.0)
	await get_tree().create_timer(1.3, false).timeout
	phase = Phase.RUN_HOME
	ui.say(SPEAKER, [RUN_LINE], 7.0)
	await get_tree().create_timer(.8, false).timeout
	start_alarm()

func _on_ammo_changed() -> void:
	ammo = gun.total()
	_update_inventory()

## F while the gun is drawn: the inspect screen, on the gun in hand (OK / F / Esc closes it).
func inspect_carried_gun() -> void:
	if ui.inspect_active() or ui.dialogue_active():
		return
	player.playing = false
	main.touch.set_enabled(false)
	main.prompt.text = ""
	ui.open_inspect(true)

# ---------------------------------------------------------------- debug menu (scripts/debug_menu.gd)
## These hand items over directly: the hut scenes they skip (the inspect screen, the call-out) do not play.

func debug_give_key() -> void:
	if has_key:
		return
	hut.has_key = true
	var key := hut.find_child("Key", false, false)
	if key != null:
		key.queue_free()
	has_key = true
	if phase == Phase.EXPLORE:
		phase = Phase.HAVE_KEY
	_update_inventory()
	notify("Debug: key")

func debug_give_gun() -> void:
	if has_gun:
		return
	if not hut.gun_taken:
		hut.take_gun()
	has_gun = true
	gun.give()
	_update_inventory()
	notify("Debug: Glock 17")

func debug_give_flashlight() -> void:
	if has_flashlight:
		return
	if not hut.flashlight_taken:
		hut.remove_flashlight()
	has_flashlight = true
	flashlight.give()
	_update_inventory()
	notify("Debug: flashlight")

# ---------------------------------------------------------------- the alarm

func start_alarm() -> void:
	if lights_out:
		return
	lights_out = true
	main.status_label.text = "Get back home."
	_start_sirens()
	_kill_street_lamps()

func _start_sirens() -> void:
	if not ResourceLoader.exists(SIREN):
		return
	var stream := load(SIREN) as AudioStream
	if stream is AudioStreamOggVorbis:
		stream = stream.duplicate()
		(stream as AudioStreamOggVorbis).loop = true
	var bus := "Night" if AudioServer.get_bus_index("Night") >= 0 else "Master"
	for i in SIREN_SPOTS.size():
		var siren := AudioStreamPlayer3D.new()
		siren.name = "Siren%d" % i
		siren.stream = stream
		siren.bus = bus
		siren.unit_size = 55.0
		siren.max_distance = 3000.0
		siren.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		siren.volume_db = -6.0
		siren.max_db = 0.0
		siren.pitch_scale = [1.0, .96, 1.03, .985][i]
		siren.attenuation_filter_cutoff_hz = 6000.0
		siren.attenuation_filter_db = -12.0
		add_child(siren)
		siren.global_position = SIREN_SPOTS[i]
		siren.play(randf_range(0.0, 20.0))
		siren.volume_db = -60.0
		var fade := create_tween()
		fade.tween_property(siren, "volume_db", -6.0, 4.0 + i * 1.5).set_delay(i * .7)
		_siren_tweens.append(fade)
		_sirens.append(siren)

## The street lamps stutter and die one after another, then the lenses go dark: only the moon is left.
func _kill_street_lamps() -> void:
	var lamps: Array[Light3D] = []
	for node in main.find_children("Street lamp*", "Light3D", true, false):
		lamps.append(node as Light3D)
	lamps.sort_custom(func(a: Light3D, b: Light3D): return a.global_position.z > b.global_position.z)
	var delay := 1.2
	for lamp in lamps:
		var base := lamp.light_energy
		lamp.set_meta("alarm_controlled", true)
		lamp.set_meta("base_energy", base)
		var tween := create_tween()
		tween.tween_interval(delay)
		for k in 4:
			tween.tween_callback(func(): lamp.set_meta("base_energy", base * .1); lamp.light_energy = base * .1)
			tween.tween_interval(.07 + k * .03)
			tween.tween_callback(func(): lamp.set_meta("base_energy", base * .8); lamp.light_energy = base * .8)
			tween.tween_interval(.12)
		tween.tween_callback(func():
			lamp.set_meta("base_energy", 0.0)
			lamp.remove_meta("flicker")
			lamp.light_energy = 0.0
			lamp.visible = false
			_play("res://assets/audio/sfx/impactMetal_light_001.ogg", -22.0, .55))
		delay += .9
	var lens_tween := create_tween()
	lens_tween.tween_interval(delay)
	lens_tween.tween_callback(_darken_lenses)

func _darken_lenses() -> void:
	for node in main.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not String(mi.name).ends_with("n lamp lens on"):
			continue
		var mat := mi.material_override as StandardMaterial3D
		if mat == null:
			continue
		mat = mat.duplicate() as StandardMaterial3D
		mat.emission_enabled = false
		mat.albedo_color = Color(.1, .1, .09)
		mi.material_override = mat

func lamps_lit() -> int:
	var lit := 0
	for node in main.find_children("Street lamp*", "Light3D", true, false):
		if (node as Light3D).visible and (node as Light3D).light_energy > .05:
			lit += 1
	return lit

## Home: inside the courtyard gate, the stair, the balcony or the house.
static func is_home(at: Vector3) -> bool:
	return at.x < 12.4 and at.z < 9.0 and at.z > -4.0

## Upstairs, fully through the navy door. Courtyard, balcony, fields and hut do not count.
static func is_inside_house(at: Vector3) -> bool:
	return at.y > -.2 and at.y < 3.2 and at.x > -6.1 and at.x < 3.15 and at.z > -2.65 and at.z < 2.35

func _process(_delta: float) -> void:
	if phase != Phase.RUN_HOME or not lights_out:
		return
	var door: InteriorHingedDoor = main.entry_door()
	if door == null:
		return
	_entry_was_open = _entry_was_open or door.is_open()
	_entered_home = is_inside_house(player.global_position)
	if _entered_home:
		main.status_label.text = "Close the door."
	else:
		main.status_label.text = "Get back home."
	if _entered_home and _entry_was_open and not door.is_open() and not door.is_moving():
		phase = Phase.HOME
		for fade in _siren_tweens:
			if fade.is_valid():
				fade.kill()
		_siren_tweens.clear()
		for siren in _sirens:
			siren.stop()
		main.status_label.text = "You made it home."
		notify("You made it home.")
