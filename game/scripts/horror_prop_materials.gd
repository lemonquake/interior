class_name InteriorHorrorPropMaterials
extends RefCounted
## Shared texture treatment for the flat-colour refuse and loose props. Imported photographic
## materials are left intact. Metre-scaled triplanar mapping also covers the merged canal kit.

const ROOT := "res://assets/horror_textures/props/"
const FILES := {
	"bag": "refuse_plastic_black.png", "plastic": "weathered_plastic.png",
	"cardboard": "waterlogged_cardboard.png", "paper": "discarded_paper.png",
	"metal": "tarnished_metal.png", "fabric": "stained_fabric.png",
}
const PALETTE := {
	"plastic black": "bag", "plastic white": "plastic", "plastic red": "plastic",
	"plastic blue": "plastic", "plastic green": "plastic", "plastic yellow": "plastic",
	"pvc": "plastic", "pvc grey": "plastic", "pet": "plastic", "foam": "plastic",
	"foam stained": "fabric", "can": "metal", "foil": "metal", "cardboard": "cardboard",
	"paper": "paper", "sack": "fabric", "tarp blue": "fabric", "tarp orange": "fabric",
	"sachet a": "paper", "sachet b": "paper", "sachet c": "paper",
	"cloth a": "fabric", "cloth b": "fabric", "cloth c": "fabric", "cloth d": "fabric",
	"sheet white": "fabric", "sheet grey": "fabric", "umbrella": "fabric",
	"slipper blue": "plastic", "slipper green": "plastic", "slipper white": "plastic",
	"slipper strap": "plastic", "flag red": "plastic", "flag yellow": "plastic",
	"flag blue": "plastic", "flag white": "plastic", "flag green": "plastic", "flag pink": "plastic",
	"sd paper": "paper", "sd plastic bag": "bag", "sd cardboard": "cardboard",
}
const BAKED_LITTER := ["Balcony / sd paper", "Balcony / sd plastic bag", "Balcony / sd cardboard"]
static var _textures: Dictionary = {}

static func _texture(family: String) -> Texture2D:
	if not _textures.has(family):
		var path: String = ROOT + str(FILES.get(family, ""))
		if ResourceLoader.exists(path):
			_textures[family] = load(path)
	return _textures.get(family) as Texture2D

static func _tint(color: Color, family: String) -> Color:
	# The bag image already contains its dark colour; another near-black multiplier loses its folds.
	if family == "bag": return Color(.95, .98, .95, color.a)
	if family == "cardboard": return Color(.95, .91, .84, color.a)
	if family == "metal": return Color(.87, .9, .87, color.a)
	var peak := maxf(color.r, maxf(color.g, color.b))
	var boost := minf(2.0, .9 / maxf(peak, .02))
	return Color(color.r * boost, color.g * boost, color.b * boost, color.a)

static func dress(material: StandardMaterial3D, family: String, metres := .55) -> StandardMaterial3D:
	if material == null or material.albedo_texture != null or material.has_meta("horror_prop_family"):
		return material
	var texture := _texture(family)
	if texture == null: return material
	material.albedo_texture = texture
	material.albedo_color = _tint(material.albedo_color, family)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.uv1_triplanar = true
	material.uv1_triplanar_sharpness = 4.0
	material.uv1_scale = Vector3.ONE / metres
	material.normal_enabled = false
	material.normal_texture = null
	material.metallic = .35 if family == "metal" else 0.0
	material.metallic_specular = .45 if family == "bag" else (.4 if family == "metal" else .28)
	match family:
		"bag": material.roughness = .47
		"plastic": material.roughness = .68
		"cardboard", "paper": material.roughness = .97
		"metal": material.roughness = .72
		"fabric": material.roughness = .96
	material.set_meta("horror_prop_family", family)
	return material

static func make(color: Color, family: String, metres := .55) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "Worn prop / " + family
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return dress(material, family, metres)

static func dress_palette(materials: Dictionary) -> int:
	var count := 0
	for key: String in PALETTE:
		if not materials.has(key): continue
		var material := materials[key] as StandardMaterial3D
		if material == null or material.albedo_texture != null: continue
		dress(material, PALETTE[key], .65 if key.begins_with("tarp") else .45)
		if material.has_meta("horror_prop_family"): count += 1
	return count

static func worn_wood() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "Worn prop / splintered wood"
	material.albedo_texture = load("res://assets/outdoor/textures/dark_wooden_planks/albedo.jpg")
	material.normal_texture = load("res://assets/outdoor/textures/dark_wooden_planks/normal.jpg")
	material.normal_enabled = true
	material.normal_scale = .55
	material.roughness_texture = load("res://assets/outdoor/textures/dark_wooden_planks/roughness.jpg")
	material.roughness = .95
	material.albedo_color = Color(.72, .67, .57)
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE / .7
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material

static func dress_baked_litter(root: Node) -> int:
	var count := 0
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var source := mesh.material_override as StandardMaterial3D
		if source == null or source.resource_name not in BAKED_LITTER or source.albedo_texture != null:
			continue
		var material := source.duplicate() as StandardMaterial3D
		var key := source.resource_name.trim_prefix("Balcony / ")
		dress(material, PALETTE[key], .4)
		mesh.material_override = material
		if material.has_meta("horror_prop_family"): count += 1
	return count
