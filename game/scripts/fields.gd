class_name InteriorFields
extends Node3D
## Runtime glue for the baked rice fields (scenes/fields/fields.tscn, built by fields_builder.gd).
## - Shown only once the player is down at street level and north of street A, so the room, the
##   balcony and the courtyard cost exactly what they did before.
## - Downloaded models go on the outdoor layer; foliage gets alpha scissor; small plants fade out.
## - Android (Compatibility): half the rice and grass, shorter rice range, fewer fireflies, no stars
##   in the water.
## - The hut lantern flickers. The scarecrow turns to face you whenever you are not looking at it.

const OUTDOOR_LAYER := 2

var mobile := false
var _lantern: OmniLight3D
var _flame: MeshInstance3D
var _crow: Node3D
var _crow_yaw := 0.0
var _flicker := 0.0
var _shown := true

func _ready() -> void:
	add_to_group("fields")
	mobile = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	for node in find_children("*", "Node3D", true, false):
		if node.has_meta("keep_instance"):
			var fade := float(node.get_meta("fade", 0.0))
			if mobile and node.has_meta("tree") and fade == 0.0:
				fade = 150.0
			var small := fade > 0.0 and fade < 130.0
			InteriorModelKit.prepare_instance(node, OUTDOOR_LAYER, fade, not small and (not mobile or node.has_meta("tree")), node.has_meta("tree") or small)
	_lantern = find_child("HutLanternLight", true, false) as OmniLight3D
	_flame = find_child("HutLanternFlame", true, false) as MeshInstance3D
	_crow = find_child("Scarecrow", true, false) as Node3D
	if _crow != null:
		_crow_yaw = _crow.rotation.y
	if mobile:
		_mobile_budget()

func _mobile_budget() -> void:
	for node in find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := node as MultiMeshInstance3D
		if mmi.multimesh != null:
			mmi.multimesh.visible_instance_count = mmi.multimesh.instance_count / 2
		mmi.visibility_range_end = 24.0 if String(mmi.name).begins_with("Rice") else 20.0
	for node in find_children("*", "GPUParticles3D", true, false):
		(node as GPUParticles3D).amount = maxi(6, (node as GPUParticles3D).amount / 2)
	for node in find_children("Paddy water*", "MeshInstance3D", true, false):
		var material := (node as MeshInstance3D).material_override as ShaderMaterial
		if material != null:
			material.set_shader_parameter("reflect_stars", false)
			break

## 0 in the town, 1 out on the dirt road (by distance north along street B).
static func zone_weight(position: Vector3) -> float:
	if position.y > -.4:
		return 0.0
	return smoothstep(50.0, 92.0, position.z)

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var show := camera != null and camera.global_position.y < -.4 and camera.global_position.z > 22.0
	if show != _shown:
		_shown = show
		visible = show
	if not show:
		return
	_flicker += delta
	if _lantern != null:
		var n := sin(_flicker * 13.0) * .5 + sin(_flicker * 7.3 + 1.7) * .3 + sin(_flicker * 29.0) * .2
		_lantern.light_energy = 1.0 + n * .22
		if _flame != null:
			_flame.scale = Vector3.ONE * (1.0 + n * .08)
	_scarecrow(camera)

func _scarecrow(camera: Camera3D) -> void:
	if _crow == null:
		return
	var to_crow := _crow.global_position - camera.global_position
	var distance := to_crow.length()
	if distance > 45.0 or distance < 2.0:
		return
	var forward := -camera.global_basis.z
	var seen := forward.dot(to_crow / distance) > cos(deg_to_rad(camera.fov * .5 + 22.0))
	if seen:
		return
	# Out of sight: it turns toward you, a little at a time.
	var want := atan2(-to_crow.x, -to_crow.z)
	_crow_yaw = lerp_angle(_crow_yaw, want, .08)
	_crow.rotation.y = _crow_yaw
