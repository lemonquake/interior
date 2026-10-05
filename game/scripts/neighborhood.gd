class_name InteriorNeighborhood
extends Node3D
## Runtime glue for the neighbourhood (built by scripts/neighborhood_builder.gd inside the baked
## balcony scene). It only matters while the balcony is visible (door open or player outside):
## - model instances (trees, AC units, chairs) go on the outdoor visual layer, foliage gets alpha
##   scissor and small plants fade out with distance;
## - the sky dome follows the camera and the camera's far plane opens up to it;
## - the room's WorldEnvironment gets depth fog (begins 14 m out, thick by ~220 m) and is restored
##   when the balcony hides again, so the room renders exactly as before with the door shut.

const OUTDOOR_LAYER := 2
const FAR := 900.0

var _env: Environment
var _saved_far := -1.0
var _active := false
var _tier := -2

func _ready() -> void:
	add_to_group("neighbourhood")
	var mobile := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	for node in find_children("*", "Node3D", true, false):
		if node.has_meta("keep_instance"):
			var fade := float(node.get_meta("fade", 0.0))
			if mobile and node.has_meta("tree") and fade == 0.0:
				fade = 160.0
			InteriorModelKit.prepare_instance(node, OUTDOOR_LAYER, fade, not mobile or node.has_meta("tree"), node.has_meta("tree"))

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var shown := is_visible_in_tree()
	if shown != _active:
		_active = shown
		_apply_fog(shown)
		if camera != null:
			if shown:
				_saved_far = camera.far if _saved_far < 0.0 else _saved_far
				camera.far = FAR
			elif _saved_far > 0.0:
				camera.far = _saved_far
	if not shown or camera == null:
		return
	var dome := get_node_or_null("Sky dome") as Node3D
	if dome != null:
		dome.global_position = camera.global_position
	var lighting := InteriorLighting.find_in(get_tree().current_scene if get_tree().current_scene != null else get_parent())
	var tier := lighting.tier if lighting != null else 2
	if tier != _tier:
		_tier = tier
		var sun := get_parent().get_node_or_null("Sun") as DirectionalLight3D
		if sun != null:
			sun.directional_shadow_max_distance = 70.0 if tier >= 3 else (45.0 if tier >= 2 else 30.0)

func _environment() -> Environment:
	if _env != null:
		return _env
	for node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		_env = (node as WorldEnvironment).environment
		break
	return _env

func _apply_fog(on: bool) -> void:
	var env := _environment()
	if env == null:
		return
	env.fog_enabled = on
	if not on:
		return
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(.70, .73, .76)
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = .1
	env.fog_depth_begin = 12.0
	env.fog_depth_end = 190.0
	env.fog_depth_curve = .78
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.0
