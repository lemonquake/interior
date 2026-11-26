class_name InteriorAtmosphere
extends Node
## World-only atmosphere, kept behind the HUD and frozen with the game.

const GRADE := preload("res://scripts/atmosphere_grade.gdshader")
var _main: Node
var _player: InteriorPlayer
var _veil: ColorRect
var _material: ShaderMaterial
var _elapsed := 0.0
var _unease := 0.0

func setup(main: Node, character: InteriorPlayer) -> void:
	_main = main
	_player = character
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_material = ShaderMaterial.new()
	_material.shader = GRADE
	_veil = ColorRect.new()
	_veil.name = "AtmosphereGrade"
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.material = _material
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.ui.add_child(_veil)
	main.ui.move_child(_veil, 0)

func set_quality(tier: int) -> void:
	if _material != null:
		_material.set_shader_parameter("grain_amount", .006 if tier >= 1 else 0.0)

func _process(delta: float) -> void:
	if not is_instance_valid(_player) or _material == null:
		return
	_elapsed += delta
	var camera := _player.get_viewport().get_camera_3d()
	var eye := camera.global_position if camera != null else _player.camera.global_position
	var outdoors := eye.y < -.4 or eye.z < -17.0 or eye.x < -33.0 or (eye.z > 2.62 and eye.x > .8)
	var target := .4 if outdoors else 0.0
	if is_instance_valid(_main.story) and _main.story.lights_out:
		target = .45 if InteriorStory.is_home(_player.global_position) else 1.0
	_unease = lerpf(_unease, target, 1.0 - exp(-delta * .7))
	_material.set_shader_parameter("strength", lerpf(.07, .16, _unease))
	_material.set_shader_parameter("elapsed", _elapsed)

func _exit_tree() -> void:
	if is_instance_valid(_veil):
		_veil.queue_free()
