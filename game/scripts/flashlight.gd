class_name InteriorFlashlight
extends Node
## 0.12: the flashlight from the hut's drawer, lying beside the Glock (owned by scripts/story.gd).
##
## Pick it up from the open drawer (E / Hold). L switches it on and off (mobile: the Light button, shown once it is
## owned). It works alongside the Glock: drawing, firing and reloading never touch it.
## The beam is a SpotLight3D carried a little left of and below the eye, aimed at what the crosshair sees ~8 m out;
## its aim trails the view slightly, like a hand. The hot spot is the cone's angle falloff (a projector texture blanked
## the light in Forward+); shadows are on outside Compatibility. It lights every layer, indoor and outdoor.
## The model (make_model) is built from primitives: tail switch, knurled black body with a pocket clip, flared head,
## bezel and lens, ~17 cm long along -Z (the beam's way).

signal toggled(on: bool)

const RANGE := 30.0
## 0.26: hotter and a little wider: close surfaces burn out on the body camera, as in the reference footage.
const ANGLE := 33.0
const ENERGY := 13.0
const ATTENUATION := .85
const COLOUR := Color(1.0, .95, .86)
## Where the light rides relative to the camera: left of centre and low, like a torch held in the off hand.
const HAND := Vector3(-.16, -.17, -.12)
const AIM_DISTANCE := 8.0
const LENGTH := .172

var owned := false
var on := false
var main: Node
var player: InteriorPlayer
var mobile := false
var light: SpotLight3D
## Debug menu: brightness multiplier on top of ENERGY.
var energy_scale := 1.0
var _aim := Basis.IDENTITY
var _click: AudioStreamPlayer
var _flicker := -1.0

func setup(main_node: Node) -> void:
	main = main_node
	player = main.player
	mobile = main.mobile
	name = "Flashlight"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("flashlight")
	light = SpotLight3D.new()
	light.name = "FlashlightBeam"
	light.light_color = COLOUR
	light.light_energy = ENERGY * (.85 if mobile else 1.0)
	light.light_specular = .55
	light.spot_range = RANGE * (.85 if mobile else 1.0)
	light.spot_attenuation = ATTENUATION
	light.spot_angle = ANGLE
	light.spot_angle_attenuation = 2.1
	light.light_cull_mask = 0xFFFFF
	light.light_volumetric_fog_energy = .35
	light.shadow_enabled = not mobile
	light.shadow_bias = .03
	light.shadow_normal_bias = 1.2
	light.shadow_blur = 1.4
	light.visible = false
	add_child(light)
	_click = AudioStreamPlayer.new()
	_click.name = "FlashlightClick"
	_click.stream = _click_sound()
	_click.volume_db = -9.0
	add_child(_click)
	_update_touch()

func give() -> void:
	owned = true
	_update_touch()

func toggle() -> void:
	if not owned:
		return
	set_on(not on)

func set_on(value: bool) -> void:
	if value == on or not owned:
		return
	on = value
	_click.pitch_scale = 1.0 if on else .86
	_click.play()
	if on and main != null and main.get("bodycam") != null and is_instance_valid(main.bodycam):
		main.bodycam.glare(.7)
	if on:
		_aim = _target_basis()
		_flicker = 0.0
	light.visible = on
	_update_touch()
	toggled.emit(on)

func _update_touch() -> void:
	if main != null and main.touch != null and main.touch.has_method("set_light_state"):
		main.touch.set_light_state(owned, on)

func _unhandled_input(event: InputEvent) -> void:
	if player == null or not player.playing or mobile or not owned:
		return
	if event.is_action_pressed("flashlight"):
		toggle()
		get_viewport().set_input_as_handled()

func _camera() -> Camera3D:
	var viewport_camera := get_viewport().get_camera_3d()
	return viewport_camera if viewport_camera != null else player.camera

## Points the beam from the hand at what lies AIM_DISTANCE ahead of the eye, so the hot spot sits on the crosshair.
func _target_basis() -> Basis:
	var camera := _camera()
	if camera == null:
		return Basis.IDENTITY
	var eye := camera.global_transform
	var from := eye * HAND
	# 0.26: with the pistol up the torch rides with the hands, so the beam goes where the muzzle goes.
	var ahead := -eye.basis.z
	if camera == player.camera and player.free_aim:
		ahead = -player.aim_basis().z
	var to := eye.origin + ahead * AIM_DISTANCE
	var forward := (to - from).normalized()
	return Basis.looking_at(forward, eye.basis.y)

func _process(delta: float) -> void:
	if not on or light == null:
		return
	var camera := _camera()
	if camera == null:
		return
	# A torch in a hand trails a quick turn a little, then catches up.
	var k := 1.0 - exp(-16.0 * delta)
	_aim = _aim.slerp(_target_basis(), k).orthonormalized()
	light.global_transform = Transform3D(_aim, camera.global_transform * HAND)
	# balcony.gd keeps the outdoor layer off room lights; the beam must light both.
	light.light_cull_mask = 0xFFFFF
	var energy := ENERGY * (.85 if mobile else 1.0) * energy_scale
	if _flicker >= 0.0:
		# The bulb catches with a stutter when it's switched on.
		_flicker += delta
		var steps := [.35, 1.0, .55, 1.0]
		var i := int(_flicker / .035)
		if i < steps.size():
			energy *= steps[i]
		else:
			_flicker = -1.0
	light.light_energy = energy

## A tail-switch click: a sharp tick, then a softer one as the button comes back.
static func _click_sound() -> AudioStreamWAV:
	var rate := 44100
	var frames := int(rate * .075)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var state := 7.0
	for i in frames:
		var t := float(i) / rate
		state = fmod(state * 16807.0, 2147483647.0)
		var noise := state / 2147483647.0 * 2.0 - 1.0
		var tick := exp(-t / .0016) * (noise * .6 + sin(t * TAU * 3100.0) * .5)
		var t2 := t - .038
		if t2 > 0.0:
			tick += exp(-t2 / .0012) * (noise * .35 + sin(t2 * TAU * 2400.0) * .3)
		data.encode_s16(i * 2, int(clampf(tick, -1.0, 1.0) * 26000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream

## The flashlight as a model: along local -Z (tail at +Z, lens at -Z), centred on its length. `layers` sets the
## render layers (the hut's things are on the outdoor layer, 2).
static func make_model(layers := 1) -> Node3D:
	var root := Node3D.new()
	root.name = "Flashlight"
	var anodised := StandardMaterial3D.new()
	anodised.resource_name = "Flashlight / anodised"
	anodised.albedo_color = Color(.07, .072, .08)
	anodised.metallic = .6
	anodised.roughness = .34
	var grip := anodised.duplicate() as StandardMaterial3D
	grip.resource_name = "Flashlight / knurling"
	grip.roughness = .7
	var rubber := StandardMaterial3D.new()
	rubber.resource_name = "Flashlight / rubber"
	rubber.albedo_color = Color(.02, .02, .02)
	rubber.roughness = .95
	var steel := StandardMaterial3D.new()
	steel.resource_name = "Flashlight / steel"
	steel.albedo_color = Color(.55, .56, .58)
	steel.metallic = 1.0
	steel.roughness = .3
	var reflector := StandardMaterial3D.new()
	reflector.resource_name = "Flashlight / reflector"
	reflector.albedo_color = Color(.85, .86, .88)
	reflector.metallic = 1.0
	reflector.roughness = .12
	var lens := StandardMaterial3D.new()
	lens.resource_name = "Flashlight / lens"
	lens.albedo_color = Color(.75, .8, .82, .35)
	lens.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lens.roughness = .05
	lens.metallic_specular = 1.0
	var half := LENGTH * .5
	# s runs from the tail (0) to the lens (LENGTH).
	var part := func(label: String, s0: float, s1: float, r0: float, r1: float, mat: Material, segments := 24) -> MeshInstance3D:
		var mesh := MeshInstance3D.new()
		mesh.name = label
		var c := CylinderMesh.new()
		c.bottom_radius = r0
		c.top_radius = r1
		c.height = s1 - s0
		c.radial_segments = segments
		c.rings = 1
		mesh.mesh = c
		mesh.material_override = mat
		mesh.layers = layers
		root.add_child(mesh, true)
		# Cylinder +Y -> model -Z.
		mesh.transform = Transform3D(Basis(Vector3.RIGHT, -PI * .5), Vector3(0, 0, half - (s0 + s1) * .5))
		return mesh
	part.call("Tail button", -.004, .001, .0068, .0062, rubber, 16)
	part.call("Tail cap", 0.0, .018, .0146, .0146, anodised)
	part.call("Tail ring", .018, .021, .0138, .0138, steel)
	part.call("Body", .021, .105, .0133, .0133, grip)
	for k in 7:
		var s := .03 + k * .0105
		part.call("Knurl ring", s, s + .0035, .0139, .0139, anodised)
	part.call("Neck", .105, .13, .0136, .0205, anodised)
	part.call("Head", .13, .163, .0205, .0205, anodised)
	part.call("Bezel", .163, .171, .0214, .0214, steel)
	part.call("Reflector", .1655, .1705, .0105, .0178, reflector)
	part.call("Lens", .1705, LENGTH, .018, .018, lens)
	var clip := MeshInstance3D.new()
	clip.name = "Pocket clip"
	var box := BoxMesh.new()
	box.size = Vector3(.0012, .0065, .062)
	clip.mesh = box
	clip.material_override = steel
	clip.layers = layers
	root.add_child(clip)
	clip.position = Vector3(.0147, 0, half - .058)
	return root
