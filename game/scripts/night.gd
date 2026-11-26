class_name InteriorNight
extends RefCounted
## Night time (0.7): one place for the moon, the sky colours and the night fog, shared by the balcony,
## the neighbourhood, the rice fields and the room's kitchen window. The full moon hangs about 20 degrees
## up toward -X/+Z: over the rooftops across street A from the balcony, ahead of the player on the dirt
## road, and low enough that its reflection lands in the canal, the paddies and the pond beside the road.

const MOON_DIRECTION := Vector3(-.539, .342, .770)
const MOON_COLOR := Color(.62, .72, 1.0)
const MOON_ENERGY := .42
const SKY_FILL_COLOR := Color(.32, .4, .62)
const SKY_FILL_ENERGY := .045
const SKY_SHADER := preload("res://scripts/night_sky.gdshader")
const MOON_TEXTURE := "res://assets/fields/sky/moon_color.jpg"
## Dark blue haze. The town keeps a closer fog than the open fields.
const FOG_TOWN := Color(.018, .024, .035)
const FOG_FIELDS := Color(.029, .038, .057)
const AMBIENT := Color(.16, .2, .32)
## 0.39: ONE grade for the whole night, inside the house and out. Until 0.38 the room had its own daylight grade (a
## warm procedural sky as ambient at energy 1.0, more exposure, full saturation) and the town swapped in the night
## values as the camera crossed the navy door, so the doorway showed the change. Now the room is lit only by its own
## lamps against the same dim moonlit ambient as the street, and nothing in the grade depends on where the camera is.
## The colour drifts toward AMBIENT only out in the rice fields (InteriorFields.zone_weight).
const AMBIENT_TOWN := Color(.24, .28, .36)
const AMBIENT_ENERGY := .24
const AMBIENT_ENERGY_MOBILE := .26
const SATURATION := .80
const CONTRAST := 1.06
const EXPOSURE := 1.02
const EXPOSURE_MOBILE := .84
const GLOW := .42
const BLOOM := .008
const SKY_PARAMS := {
	"moon_direction": MOON_DIRECTION,
	"moon_radius": .028,
	"moon_energy": 5.5,
	"zenith_color": Color(.004, .007, .02),
	"sky_color": Color(.012, .02, .045),
	"horizon_color": Color(.032, .043, .065),
	"halo_color": Color(.18, .23, .33),
	"star_count": 20,
	"star_energy": 2.6,
	"cloud_cover": .56,
	"cloud_speed": .0015,
}
const CLOUD_NOISE := "res://assets/fields/sky/cloud_noise.png"

static func sky_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.resource_name = "Night sky"
	material.shader = SKY_SHADER
	configure_sky(material)
	return material

## Sets the moon, gradient and stars on any material that includes night_common.gdshaderinc.
static func configure_sky(material: ShaderMaterial) -> void:
	for key in SKY_PARAMS:
		material.set_shader_parameter(key, SKY_PARAMS[key])
	if ResourceLoader.exists(MOON_TEXTURE):
		material.set_shader_parameter("moon_texture", load(MOON_TEXTURE))
	if material.shader == SKY_SHADER and ResourceLoader.exists(CLOUD_NOISE):
		material.set_shader_parameter("cloud_noise", load(CLOUD_NOISE))
		material.set_shader_parameter("cloud_scale", .22)
		material.set_shader_parameter("cloud_lit", Color(.06, .072, .1))

## The night grade on the shared environment. `ambient_scale` is the graphics tier's small lift for tiers without
## ambient occlusion; `zone` 0 town .. 1 open fields.
static func apply_grade(env: Environment, mobile: bool, ambient_scale := 1.0, zone := 0.0) -> void:
	if env == null:
		return
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_sky_contribution = 0.0
	env.ambient_light_color = ambient_color(zone)
	env.ambient_light_energy = (AMBIENT_ENERGY_MOBILE if mobile else AMBIENT_ENERGY) * ambient_scale
	env.adjustment_enabled = true
	env.adjustment_saturation = SATURATION
	env.adjustment_contrast = CONTRAST
	env.adjustment_brightness = 1.0
	env.tonemap_exposure = EXPOSURE_MOBILE if mobile else EXPOSURE
	env.glow_intensity = GLOW
	env.glow_bloom = BLOOM

static func ambient_color(zone: float) -> Color:
	return AMBIENT_TOWN.lerp(AMBIENT, clampf(zone, 0.0, 1.0))

static func moon_basis() -> Basis:
	return Basis.looking_at(-MOON_DIRECTION.normalized(), Vector3.UP)

## The room stays lit by its own lamps; the kitchen window turns from daylight to a dim blue night.
static func apply_room(room: Node) -> void:
	if room == null:
		return
	for node in room.find_children("Light_window_daylight", "Node3D", true, false):
		for light in node.find_children("*", "SpotLight3D", true, false):
			var spot := light as SpotLight3D
			spot.light_color = Color(.42, .55, .95)
			spot.set_meta("base_energy", .45)
			spot.set_meta("mobile_energy", .35)
			spot.light_energy = .45
	for mesh in room.find_children("*sunlit window*", "MeshInstance3D", true, false):
		var mi := mesh as MeshInstance3D
		var material := mi.material_override as StandardMaterial3D
		if material == null:
			continue
		material = material.duplicate() as StandardMaterial3D
		material.albedo_color = Color(.04, .05, .08)
		material.emission = Color(.1, .14, .26)
		material.emission_energy_multiplier = .6
		mi.material_override = material
	add_room_bounce(room)

## 0.39: the lamplight thrown back off the pale floor and the table onto the walls and the ceiling. Before, a bright
## warm ambient did this for the whole world (and read as daylight); now it is light that belongs to the room, on
## the room's own render layer, so it looks the same from the sofa and from the balcony. No shadows and no
## highlights, desktop renderer only (the Compatibility renderer keeps its two-light budget).
const ROOM_BOUNCE := [
	# [position, range, energy]: the living room, the TV wall and the kitchen.
	[Vector3(-.5, 1.25, .1), 5.2, .32],
	[Vector3(-.6, 1.6, -1.9), 3.0, .14],
	[Vector3(-4.4, 1.3, -.2), 3.0, .18],
]

static func add_room_bounce(room: Node) -> void:
	if room == null or room.has_node("Lamp bounce") or RenderingServer.get_current_rendering_method() == "gl_compatibility":
		return
	var root := Node3D.new()
	root.name = "Lamp bounce"
	room.add_child(root)
	for spec: Array in ROOM_BOUNCE:
		var omni := OmniLight3D.new()
		omni.name = "Bounce"
		omni.position = spec[0]
		omni.omni_range = spec[1]
		omni.omni_attenuation = .8
		omni.light_energy = spec[2]
		omni.light_color = Color(1.0, .8, .6)
		omni.light_specular = 0.0
		omni.shadow_enabled = false
		omni.light_cull_mask = 1
		root.add_child(omni)
