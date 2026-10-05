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

func _ready() -> void:
	add_to_group("balcony")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mask_room_lights.call_deferred()

func _mask_room_lights() -> void:
	var scene := get_parent()
	if scene == null:
		return
	for light in scene.find_children("*", "Light3D", true, false):
		if not is_ancestor_of(light):
			(light as Light3D).light_cull_mask &= ~OUTDOOR_LAYER

func sun() -> DirectionalLight3D:
	return get_node_or_null("Moon") as DirectionalLight3D

## The balcony can only be seen through the open doorway or from outside: hide it (and
## its shadowed sun) otherwise, so the closed room costs exactly what it did before.
func _update_visibility() -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	# x > 0.8 excludes the studio alcove, which also lies beyond z 2.62.
	# Below the room floor means the stair foot, the courtyard or the street.
	var outside := camera != null and ((camera.global_position.z > 2.62 and camera.global_position.x > .8) or camera.global_position.y < -.4)
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
		if light == null:
			continue
		var base := float(light.get_meta("base_energy"))
		var seed := float(light.get_instance_id() % 97)
		var dip := sin(_flicker_time * 1.3 + seed) * sin(_flicker_time * .37 + seed * 2.0)
		var out := 1.0
		if dip > .82:
			# A burst of stutter, as if the ballast is failing.
			out = .15 if fmod(_flicker_time * 23.0 + seed, 1.0) < .5 else .9
		light.light_energy = base * out

func _process(delta: float) -> void:
	_update_visibility()
	if visible:
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
		var fill := get_node_or_null("SkyFill") as DirectionalLight3D
		if fill != null:
			fill.light_energy = InteriorNight.SKY_FILL_ENERGY * (1.6 if mobile else 1.0)
			fill.light_color = InteriorNight.SKY_FILL_COLOR
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if tier < 3 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
