class_name InteriorBalcony
extends Node3D
## Runtime glue for the baked balcony scene (scenes/balcony/balcony.tscn).
## Outdoor geometry renders on layer 2; the Sun/SkyFill/GroundBounce lights only light
## that layer, so daylight never reaches the room. In turn the room's lights are masked
## off layer 2 so unshadowed downlights cannot shine through walls onto the balcony.

const OUTDOOR_LAYER := 2

var _tier := -2
var _poll := 0.0

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
	return get_node_or_null("Sun") as DirectionalLight3D

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

func _process(delta: float) -> void:
	_update_visibility()
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
		# Low never casts dynamic shadows; Android keeps the sun shadow for High only.
		light.shadow_enabled = tier >= (2 if mobile else 1)
		# Without shadows the sun also reaches under the roof slab; soften it there.
		# Overcast ghost-town afternoon (run 6): a weak, cool sun behind the haze.
		light.light_energy = .85 if light.shadow_enabled else .6
		light.light_color = Color(.86, .88, .9)
		light.shadow_blur = 2.5
		var fill := get_node_or_null("SkyFill") as DirectionalLight3D
		if fill != null:
			fill.light_energy = .75
			fill.light_color = Color(.72, .76, .8)
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if tier < 3 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
