class_name InteriorNight
extends RefCounted
## Night time (0.7): one place for the moon, the sky colours and the night fog, shared by the balcony,
## the neighbourhood, the rice fields and the room's kitchen window. The full moon hangs about 20 degrees
## up toward -X/+Z: over the rooftops across street A from the balcony, ahead of the player on the dirt
## road, and low enough that its reflection lands in the canal, the paddies and the pond beside the road.

const MOON_DIRECTION := Vector3(-.539, .342, .770)
const MOON_COLOR := Color(.62, .72, 1.0)
const MOON_ENERGY := 1.05
const SKY_FILL_COLOR := Color(.32, .4, .62)
const SKY_FILL_ENERGY := .14
const SKY_SHADER := preload("res://scripts/night_sky.gdshader")
const MOON_TEXTURE := "res://assets/fields/sky/moon_color.jpg"
## Dark blue haze. The town keeps a closer fog than the open fields.
const FOG_TOWN := Color(.045, .055, .08)
const FOG_FIELDS := Color(.06, .075, .105)
const AMBIENT := Color(.16, .2, .32)
const SKY_PARAMS := {
	"moon_direction": MOON_DIRECTION,
	"moon_radius": .028,
	"moon_energy": 5.5,
	"zenith_color": Color(.004, .007, .02),
	"sky_color": Color(.012, .02, .045),
	"horizon_color": Color(.075, .09, .125),
	"halo_color": Color(.35, .42, .55),
	"star_density": .11,
	"star_energy": 2.2,
	"cloud_cover": .38,
}

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
