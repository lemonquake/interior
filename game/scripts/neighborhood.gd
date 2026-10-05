class_name InteriorNeighborhood
extends Node3D
## Runtime glue for the neighbourhood (built by scripts/neighborhood_builder.gd inside the baked
## balcony scene). It only matters while the balcony is visible (door open or player outside):
## - model instances (trees, AC units, chairs) go on the outdoor visual layer, foliage gets alpha
##   scissor and small plants fade out with distance;
## - the night sky dome follows the camera and the camera's far plane opens up to it;
## - night (0.7): the room's WorldEnvironment gets a dark blue haze while the balcony shows. Outdoors
##   the ambient light turns moonlit blue and the colour grade cools; out on the dirt road the haze
##   opens up (the fields stretch to the horizon), mist gathers over the paddies and, on desktop
##   High and Ultra, volumetric fog scatters the moonlight. Everything is restored indoors, so the
##   room renders exactly as before with the door shut.
## The night sounds live in scripts/night_audio.gd.

const OUTDOOR_LAYER := 2
const FAR := 900.0

var _env: Environment
var _saved_far := -1.0
var _active := false
var _tier := -2
var _saved: Dictionary = {}
var _outdoors := false
var _zone := -1.0
var _mobile := false

func _ready() -> void:
	add_to_group("neighbourhood")
	_mobile = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	for node in find_children("*", "Node3D", true, false):
		if node.has_meta("keep_instance"):
			var fade := float(node.get_meta("fade", 0.0))
			if _mobile and node.has_meta("tree") and fade == 0.0:
				fade = 160.0
			InteriorModelKit.prepare_instance(node, OUTDOOR_LAYER, fade, not _mobile or node.has_meta("tree"), node.has_meta("tree"))
	var dome := get_node_or_null("Sky dome") as MeshInstance3D
	if dome != null and dome.material_override is ShaderMaterial:
		InteriorNight.configure_sky(dome.material_override as ShaderMaterial)

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
	var outdoors := shown and camera != null and (camera.global_position.y < -.4 or (camera.global_position.z > 2.62 and camera.global_position.x > .8))
	if outdoors != _outdoors:
		_outdoors = outdoors
		_apply_outdoors(outdoors)
	if not shown or camera == null:
		return
	if outdoors:
		_update_zone(InteriorFields.zone_weight(camera.global_position))
	var dome := get_node_or_null("Sky dome") as Node3D
	if dome != null:
		dome.global_position = camera.global_position
	var lighting := InteriorLighting.find_in(get_tree().current_scene if get_tree().current_scene != null else get_parent())
	var tier := lighting.tier if lighting != null else 2
	if tier != _tier:
		_tier = tier
		_zone = -1.0
		var moon := get_parent().get_node_or_null("Moon") as DirectionalLight3D
		if moon != null:
			moon.directional_shadow_max_distance = 70.0 if tier >= 3 else (45.0 if tier >= 2 else 30.0)

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
	env.fog_light_color = InteriorNight.FOG_TOWN
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = .04
	env.fog_depth_begin = 4.0
	env.fog_depth_end = 110.0
	env.fog_depth_curve = 1.4
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.0
	env.fog_height = -2.2
	env.fog_height_density = 0.0

## Outdoors: moonlit ambient, a cooler grade and a touch more exposure. Indoors: the room's own values.
func _apply_outdoors(on: bool) -> void:
	var env := _environment()
	if env == null:
		return
	if on:
		_saved = {"source": env.ambient_light_source, "color": env.ambient_light_color, "energy": env.ambient_light_energy,
			"sky": env.ambient_light_sky_contribution, "adjust": env.adjustment_enabled, "sat": env.adjustment_saturation,
			"contrast": env.adjustment_contrast, "bright": env.adjustment_brightness, "exposure": env.tonemap_exposure,
			"glow": env.glow_intensity, "bloom": env.glow_bloom}
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = InteriorNight.AMBIENT
		env.ambient_light_energy = .6 if _mobile else .38
		env.ambient_light_sky_contribution = 0.0
		env.adjustment_enabled = true
		env.adjustment_saturation = .82
		env.adjustment_contrast = 1.08
		env.adjustment_brightness = 1.0
		env.tonemap_exposure = (1.0 if _mobile else 1.3)
		env.glow_intensity = .9
		env.glow_bloom = .06
		_zone = -1.0
	elif not _saved.is_empty():
		env.ambient_light_source = _saved.source
		env.ambient_light_color = _saved.color
		env.ambient_light_energy = _saved.energy
		env.ambient_light_sky_contribution = _saved.sky
		env.adjustment_enabled = _saved.adjust
		env.adjustment_saturation = _saved.sat
		env.adjustment_contrast = _saved.contrast
		env.adjustment_brightness = _saved.bright
		env.tonemap_exposure = _saved.exposure
		env.glow_intensity = _saved.glow
		env.glow_bloom = _saved.bloom
		env.volumetric_fog_enabled = false
		_apply_fog(_active)

## Blends the haze from the close town fog to the open fields (weight 0..1).
func _update_zone(weight: float) -> void:
	if absf(weight - _zone) < .01:
		return
	_zone = weight
	var env := _environment()
	if env == null:
		return
	env.fog_light_color = InteriorNight.FOG_TOWN.lerp(InteriorNight.FOG_FIELDS, weight)
	env.fog_depth_begin = lerpf(4.0, 14.0, weight)
	env.fog_depth_end = lerpf(110.0, 300.0, weight)
	env.fog_depth_curve = lerpf(1.4, 1.1, weight)
	var volumetric := not _mobile and _tier >= 2 and weight > .2
	env.volumetric_fog_enabled = volumetric
	if volumetric:
		# No global density: only the low mist volume over the paddies (fields_builder.gd) shows, so
		# palms and bamboo stay dark against the sky instead of glowing with scattered moonlight.
		env.volumetric_fog_density = 0.0
		env.volumetric_fog_albedo = Color(.62, .68, .85)
		env.volumetric_fog_emission_energy = 0.0
		env.volumetric_fog_anisotropy = .55
		env.volumetric_fog_length = 90.0 if _tier >= 3 else 64.0
		env.volumetric_fog_detail_spread = 1.6
		env.volumetric_fog_ambient_inject = 0.0
		env.volumetric_fog_sky_affect = 0.0
		env.volumetric_fog_temporal_reprojection_enabled = true
