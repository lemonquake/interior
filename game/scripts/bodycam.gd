class_name InteriorBodycam
extends Node
## 0.26: the body camera's lens and its reactions (scripts/bodycam_lens.gdshader). The camera's own movement (roll
## into turns, hand tremor, the muzzle leading the view) is in scripts/player.gd; the hands and the pistol are in
## scripts/gun.gd.
##
## One full-screen pass under the HUD text and over the hands: barrel distortion, the image circle's dark corners
## with a warm fringe, colour fringing, grain, a smear on fast turns. `shot()` whites the frame out for a moment
## and dips the gain after it; `glare()` does the softer version when the torch comes on.
## Options: "Lens: Body camera / Clean". On Low the fringing and the smear are left out (one texture read).

const LENS := preload("res://scripts/bodycam_lens.gdshader")
## Lens strength, and how much wider the camera has to see for the middle of the frame to stay natural.
const DISTORTION := .34
const BASE_FOV := 92.0
const CLEAN_FOV := 78.0

var main: Node
var player: InteriorPlayer
var enabled := true
var rect: ColorRect
var material: ShaderMaterial
var _copy: BackBufferCopy
var _elapsed := 0.0
var _flash := 0.0
var _flash_rate := 9.0
var _gain := 1.0
var _last_basis := Basis.IDENTITY
var _smear := Vector2.ZERO
var _tier := 2
## 0.26 low-light gain (see the shader): follows where the camera is, drops while the torch or a shot lights things.
var _night := 0.0

func setup(scene: Node, character: InteriorPlayer) -> void:
	main = scene
	player = character
	name = "Bodycam"
	process_mode = Node.PROCESS_MODE_ALWAYS
	material = ShaderMaterial.new()
	material.shader = LENS
	material.set_shader_parameter("distortion", DISTORTION)
	_copy = BackBufferCopy.new()
	_copy.name = "LensCopy"
	_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	rect = ColorRect.new()
	rect.name = "BodycamLens"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = material
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	(main.hud as Control).add_child(_copy)
	(main.hud as Control).add_child(rect)
	place()
	set_enabled(not "--no-lens" in OS.get_cmdline_user_args())

## Over the gun's view (the hands are behind the same glass), under every label.
func place() -> void:
	var hud: Control = main.hud
	var gun_view: Node = hud.get_node_or_null("GunView")
	var index: int = gun_view.get_index() + 1 if gun_view != null else 0
	hud.move_child(_copy, index)
	hud.move_child(rect, index + 1)

func set_enabled(on: bool) -> void:
	enabled = on
	rect.visible = on
	_copy.visible = on
	if is_instance_valid(player):
		player.set_fov(BASE_FOV if on else CLEAN_FOV)

func set_quality(tier: int) -> void:
	_tier = tier
	material.set_shader_parameter("detail", 1.0 if tier >= 1 else 0.0)
	material.set_shader_parameter("grain", .05 if tier >= 1 else .035)

## A shot: the flash lights the frame warm for a frame or two (0.27: the reference's flash is one frame of its
## thirty a second, not a white-out), then the automatic gain sits a little darker and comes back.
func shot(strength := 1.0) -> void:
	_flash = maxf(_flash, strength * .62)
	_flash_rate = 26.0
	_gain = minf(_gain, 1.0 - .12 * strength)

## A light coming on in the dark (the torch): a softer glare.
func glare(strength := .6) -> void:
	_flash = maxf(_flash, strength * .5)
	_flash_rate = 9.0
	_gain = minf(_gain, 1.0 - .12 * strength)

func _process(delta: float) -> void:
	if not enabled or material == null:
		return
	_elapsed += delta
	_flash = move_toward(_flash, 0.0, delta * _flash_rate)
	_gain = lerpf(_gain, 1.0, 1.0 - exp(-3.2 * delta))
	var size: Vector2 = main.get_viewport().get_visible_rect().size
	var aspect: float = size.x / maxf(size.y, 1.0)
	var smear := Vector2.ZERO
	var camera: Camera3D = main.get_viewport().get_camera_3d()
	if camera != null and delta > 0.0 and _tier >= 1:
		var basis := camera.global_basis
		var turn := (_last_basis.inverse() * basis).get_euler()
		_last_basis = basis
		# Exposure is about half the frame time: how far the picture travelled while the shutter was open.
		var per_radian := 1.0 / deg_to_rad(maxf(camera.fov, 1.0))
		var raw := Vector2(turn.y * per_radian / aspect, -turn.x * per_radian) * .5 * clampf(1.0 / (delta * 60.0), .5, 2.0)
		# Only real swings smear; a slow pan stays sharp.
		if raw.length() < .0035:
			raw = Vector2.ZERO
		smear = raw.limit_length(.03)
	_smear = _smear.lerp(smear, .6)
	material.set_shader_parameter("smear", _smear if not get_tree().paused else Vector2.ZERO)
	material.set_shader_parameter("aspect", aspect)
	material.set_shader_parameter("elapsed", _elapsed)
	material.set_shader_parameter("flash", _flash)
	material.set_shader_parameter("exposure", _gain)
	var night := 0.0
	if camera != null and not camera.has_meta("menu_camera"):
		# 0.39: the same camera gain everywhere, inside the house too. It lifts only the dark pixels (see the shader),
		# so lamp-lit parts of the room are left as they are; until 0.38 it switched on at the navy door.
		night = 1.0
		var story: Variant = main.get("story")
		if story != null and is_instance_valid(story):
			if story.get("lights_out") == true:
				night = 1.0
			var torch: Variant = story.get("flashlight")
			if torch != null and is_instance_valid(torch) and torch.get("on") == true:
				night *= .55
	_night = lerpf(_night, night * clampf(_gain, 0.0, 1.0), 1.0 - exp(-(1.4 if night > _night else 5.0) * delta))
	material.set_shader_parameter("night_gain", _night)

func _exit_tree() -> void:
	if is_instance_valid(rect):
		rect.queue_free()
	if is_instance_valid(_copy):
		_copy.queue_free()
