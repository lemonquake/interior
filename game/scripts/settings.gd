class_name InteriorSettings
extends Node
## 0.43: the player's settings, kept in user://settings.cfg, and the sound categories the Options sliders move.
## Autoloaded as GameSettings (project.godot), so it is up before the boot scene, every test and every capture.
##
## Sound categories are buses that send to Master. Players that ask for a bus of their own are routed by bus name
## (the gun's "Gun" bus -> Guns, the night's "Night" and "Wildlife" -> Background, "Steps" -> Effects); players left
## on Master are sorted by the script that owns them when they enter the tree.
##
## Any run started with game arguments (`-- --anything`: every test, capture, audit and bake) is silent: the
## owner hears test windows otherwise. `-- --sound` keeps the sound on for such a run.

const PATH := "user://settings.cfg"
## Bus name, Options label.
const CATEGORIES := [["Guns", "Guns and explosions"], ["Effects", "Effects"], ["Zombies", "Zombies"],
	["Voices", "Voices"], ["Background", "Background"]]
const ROUTES := {"Gun": "Guns", "Night": "Background", "Wildlife": "Background", "Steps": "Effects"}

var config := ConfigFile.new()
var muted_for_testing := false

func _enter_tree() -> void:
	config.load(PATH)
	var arguments := OS.get_cmdline_user_args()
	muted_for_testing = OS.get_environment("INTERIOR_MUTE") == "1" or (not arguments.is_empty() and not "--sound" in arguments)
	for entry: Array in CATEGORIES:
		if AudioServer.get_bus_index(entry[0]) < 0:
			var index := AudioServer.bus_count
			AudioServer.add_bus(index)
			AudioServer.set_bus_name(index, entry[0])
			AudioServer.set_bus_send(index, "Master")
	AudioServer.bus_layout_changed.connect(_route_buses)
	_route_buses()
	apply_volumes()
	get_tree().node_added.connect(_on_node_added)

func get_value(key: String, fallback: Variant) -> Variant:
	return config.get_value("game", key, fallback)

func set_value(key: String, value: Variant) -> void:
	config.set_value("game", key, value)
	config.save(PATH)

## 0..1 for "Master" or a category.
func volume(bus: String) -> float:
	return float(config.get_value("sound", bus, 1.0))

func set_volume(bus: String, linear: float) -> void:
	config.set_value("sound", bus, clampf(linear, 0.0, 1.0))
	config.save(PATH)
	apply_volumes()

func apply_volumes() -> void:
	for bus: String in ["Master"] + CATEGORIES.map(func(entry: Array) -> String: return entry[0]):
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			continue
		var linear := volume(bus)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(index, linear <= 0.001)
	if muted_for_testing:
		AudioServer.set_bus_mute(0, true)

func _route_buses() -> void:
	for index in AudioServer.bus_count:
		var target: String = ROUTES.get(AudioServer.get_bus_name(index), "")
		if target != "" and AudioServer.get_bus_send(index) != target and AudioServer.get_bus_index(target) >= 0:
			AudioServer.set_bus_send(index, target)

func _on_node_added(node: Node) -> void:
	if not (node is AudioStreamPlayer3D or node is AudioStreamPlayer or node is AudioStreamPlayer2D):
		return
	if str(node.get("bus")) != "Master":
		return
	node.set("bus", category_for(node))

## Which category a player left on Master belongs to, from the scripts above it.
static func category_for(node: Node) -> String:
	var walk := node
	for i in 8:
		if walk == null:
			break
		var script := walk.get_script() as Script
		if script != null:
			var path := script.resource_path.get_file()
			if path.begins_with("zombie") or path == "figure.gd":
				return "Zombies"
			if path in ["voices.gd", "body.gd", "stranger.gd", "stranger_cutscene.gd"]:
				return "Voices"
			if path in ["room_audio.gd", "night_audio.gd", "television.gd", "atmosphere.gd", "menu_neighborhood.gd"]:
				return "Background"
			if path in ["gun.gd", "grenade.gd"]:
				return "Guns"
		walk = walk.get_parent()
	return "Effects"
