class_name InteriorBalcony
extends Node3D
## Runtime glue for the baked balcony scene (scenes/balcony/balcony.tscn).
## Outdoor geometry renders on layer 2; the Moon/SkyFill and the practical lights only light
## that layer, so daylight never reaches the room. In turn the room's lights are masked
## off layer 2 so unshadowed downlights cannot shine through walls onto the balcony.

const OUTDOOR_LAYER := 2

var _tier := -2
var _poll := 0.0
var _flickering: Array = []
var _flicker_time := 0.0
var _lamp_lens: ShaderMaterial
var _street_lamps: Array[Light3D] = []
var _lamp_rng := RandomNumberGenerator.new()
var _lamp_cycles: Dictionary = {}

func _ready() -> void:
	InteriorLoadClock.mark("balcony: children ready")
	add_to_group("balcony")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_night_lamps()
	InteriorLoadClock.later(_mask_room_lights)

func _setup_night_lamps() -> void:
	_lamp_rng.seed = 140014
	for node: Node in find_children("Street lamp*", "Light3D", true, false):
		var lamp := node as OmniLight3D
		lamp.light_energy = .95
		lamp.omni_range = 10.0
		lamp.omni_attenuation = 1.5
		lamp.set_meta("flicker", true)
		_street_lamps.append(lamp)
		_lamp_cycles[lamp] = {"wait": _lamp_rng.randf_range(3.0, 13.0), "time": -1.0}
	for label in ["CourtyardLight", "PorchLight"]:
		var light := find_child(label, true, false) as Light3D
		if light != null:
			light.light_energy *= .32
	_lamp_lens = ShaderMaterial.new()
	_lamp_lens.shader = preload("res://scripts/street_lamp_lens.gdshader")
	for node: Node in find_children("*n lamp lens on", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = _lamp_lens
	_sync_lenses()

func _sync_lenses() -> void:
	for i in mini(_street_lamps.size(), 3):
		var lamp := _street_lamps[i]
		var at := lamp.global_position
		_lamp_lens.set_shader_parameter(["lamp_a", "lamp_b", "lamp_c"][i],
			Vector4(at.x, at.y, at.z, lamp.light_energy if lamp.visible else 0.0))

func _street_flicker(lamp: Light3D, delta: float) -> float:
	var cycle: Dictionary = _lamp_cycles[lamp]
	if cycle.time < 0.0:
		cycle.wait -= delta
		if cycle.wait <= 0.0:
			cycle.time = 0.0
		return 1.0
	cycle.time += delta
	var t: float = cycle.time
	# Two brief failures, then a weak recovery; quiet intervals differ for each fixture.
	if t < .16:
		return .04
	if t < .37:
		return .62
	if t < .65:
		return .02
	if t < 1.35:
		return lerpf(.18, 1.0, smoothstep(.65, 1.35, t))
	cycle.time = -1.0
	cycle.wait = _lamp_rng.randf_range(9.0, 24.0)
	return 1.0

func _mask_room_lights() -> void:
	var scene := get_parent()
	if scene == null:
		return
	for light in scene.find_children("*", "Light3D", true, false):
		# Outdoor-only lights (the fields' hut lantern, the 0.10 hut candle) keep their layer.
		# The debug menu's fill light is meant to reach everything, outdoors included. (Behind the loading screen
		# it already exists when this runs; started in one go it is made a frame later and was never masked.)
		if light.name == &"DebugFillLight":
			continue
		# 0.44: the co-op street's lights are outdoors and far from the rooms: they light the ground too.
		if light.has_meta("outdoor"):
			continue
		if not is_ancestor_of(light) and (light as Light3D).light_cull_mask != OUTDOOR_LAYER:
			(light as Light3D).light_cull_mask &= ~OUTDOOR_LAYER

func sun() -> DirectionalLight3D:
	return get_node_or_null("Moon") as DirectionalLight3D

## The balcony can only be seen through the open doorway or from outside: hide it (and
## its shadowed sun) otherwise, so the closed room costs exactly what it did before.
func _update_visibility() -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	# x > 0.8 excludes the studio alcove, which also lies beyond z 2.62.
	# Below the room floor means the stair foot, the courtyard or the street.
	var outside := camera != null and ((camera.global_position.z > 2.62 and camera.global_position.x > .8) or camera.global_position.y < -.4 or camera.global_position.z < -17.0 or camera.global_position.x < -33.0)
	var door_open := false
	for door in get_tree().get_nodes_in_group("interior_doors"):
		if not door is InteriorHingedDoor or door is InteriorSlidingDoor:
			continue  # the studio slider and the courtyard gate don't reveal the balcony
		if door.is_open() or door.is_moving():
			door_open = true
	var show := outside or door_open
	if visible != show:
		visible = show

## The courtyard security lamp and the street lamps marked "flicker" buzz and dip now and then.
func _flicker(delta: float) -> void:
	if _flickering.is_empty():
		for node in find_children("*", "Light3D", true, false):
			if node.has_meta("flicker"):
				_flickering.append(node)
				node.set_meta("base_energy", (node as Light3D).light_energy)
		if _flickering.is_empty():
			_flickering.append(null)
	_flicker_time += delta
	for light: Light3D in _flickering:
		if not is_instance_valid(light) or not light.has_meta("flicker") or not light.visible or light.has_meta("alarm_controlled"):
			continue
		var base := float(light.get_meta("base_energy"))
		var seed := float(String(light.get_path()).hash() % 97)
		var dip := sin(_flicker_time * .71 + seed) * sin(_flicker_time * .23 + seed * 2.0)
		# Infrequent, soft ballast dips. No rapid square-wave strobe while exploring.
		var out := 1.0 - smoothstep(.66, .97, dip) * .68
		out *= .994 + sin(_flicker_time * 3.7 + seed) * .006
		light.light_energy = base * (_street_flicker(light, delta) if _lamp_cycles.has(light) else out)
	_sync_lenses()

func _process(delta: float) -> void:
	_update_visibility()
	var camera := get_viewport().get_camera_3d()
	if visible and (not get_tree().paused or (camera != null and camera.has_meta("menu_camera"))):
		_flicker(delta)
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = .5
	var lighting := InteriorLighting.find_in(get_parent())
	var tier := lighting.tier if lighting != null else 2
	var mobile := lighting.mobile if lighting != null else false
	if tier == _tier:
		return
	_tier = tier
	var light := sun()
	if light != null:
		# Low never casts dynamic shadows; Android keeps the moon shadow for High only.
		light.shadow_enabled = tier >= (2 if mobile else 1)
		# Night (0.7): a cool full moon. Without shadows it also reaches under the roof slab, so it is
		# a little dimmer then.
		light.light_energy = InteriorNight.MOON_ENERGY * (1.0 if light.shadow_enabled else .8)
		light.light_color = InteriorNight.MOON_COLOR
		light.shadow_blur = 2.0
		# 0.8: cross-fade between the shadow cascades, so no cascade edge ever shows as a line on the ground.
		light.directional_shadow_blend_splits = tier >= 3
		light.directional_shadow_fade_start = .7
		var fill := get_node_or_null("SkyFill") as DirectionalLight3D
		if fill != null:
			fill.light_energy = InteriorNight.SKY_FILL_ENERGY * (1.6 if mobile else 1.0)
			fill.light_color = InteriorNight.SKY_FILL_COLOR
		# 0.33: below Ultra the moon's shadow is one map over the near ground (it was two, cross-faded: every caster drawn
		# up to four times). One map has no cascade edge to show at all.
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if tier < 3 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
