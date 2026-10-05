class_name InteriorMaterials
extends RefCounted
## Shared, cached material library (contract section 5).
##   InteriorMaterials.material("oak_slat")            -> desktop material
##   InteriorMaterials.material("oak_slat", true)      -> mobile variant (no normal maps)
## Every texture is a res:// image file, so materials survive the editor bake unchanged.
## Unknown keys fall back to a neutral material and print a warning.

const MAT_DIR := "res://assets/materials/"
const SURF_DIR := "res://assets/surfaces/"

## key: [texture set ("" = none), albedo tint, roughness, metallic, triplanar metres per tile
##       (0 = use mesh UVs), normal strength, specular]
const SPECS := {
	# Woods
	"oak": ["materials/oak", Color(1.0, 0.96, 0.9), 0.62, 0.0, 1.0, 0.35, 0.4],
	"oak_slat": ["materials/oak_slat", Color(1.02, 0.96, 0.88), 0.58, 0.0, 1.2, 0.8, 0.45],
	"walnut": ["materials/walnut", Color(1, 1, 1), 0.5, 0.0, 1.0, 0.35, 0.45],
	"rattan": ["materials/rattan", Color(1, 1, 1), 0.7, 0.0, 0.25, 0.8, 0.35],
	"bamboo": ["materials/bamboo", Color(1, 1, 1), 0.6, 0.0, 0.6, 0.5, 0.4],
	# Paints and finishes
	"white_satin": ["materials/paint_micro", Color(0.90, 0.88, 0.84), 0.36, 0.0, 0.5, 0.12, 0.5],
	"white_matte": ["materials/paint_micro", Color(0.86, 0.84, 0.79), 0.82, 0.0, 0.5, 0.1, 0.35],
	"warm_plaster": ["surfaces/plaster", Color(0.95, 0.92, 0.86), 0.9, 0.0, 1.6, 0.18, 0.3],
	"ceiling_white": ["materials/paint_micro", Color(0.92, 0.90, 0.86), 0.9, 0.0, 0.8, 0.06, 0.25],
	"navy_enamel": ["materials/paint_micro", Color(0.085, 0.12, 0.2), 0.34, 0.0, 0.5, 0.1, 0.5],
	"black_metal": ["materials/brushed", Color(0.11, 0.105, 0.1), 0.42, 0.75, 0.4, 0.25, 0.5],
	"brushed_steel": ["materials/brushed", Color(0.74, 0.73, 0.71), 0.32, 1.0, 0.4, 0.3, 0.5],
	"chrome": ["", Color(0.85, 0.85, 0.86), 0.08, 1.0, 0.0, 0.0, 0.5],
	"brass": ["materials/brushed", Color(0.78, 0.6, 0.34), 0.3, 1.0, 0.4, 0.2, 0.5],
	# Stone / ceramic
	"marble_gold": ["materials/marble_gold", Color(1, 1, 1), 0.22, 0.0, 1.6, 0.4, 0.5],
	"marble_floor": ["materials/marble_floor", Color(1.0, 0.98, 0.95), 0.3, 0.0, 1.8, 0.3, 0.5],
	"quartz_counter": ["materials/quartz", Color(1, 1, 1), 0.25, 0.0, 1.2, 0.0, 0.5],
	"tile_white": ["materials/tile_white", Color(1, 1, 1), 0.22, 0.0, 0.6, 0.5, 0.5],
	"tile_navy": ["materials/tile_navy", Color(1, 1, 1), 0.22, 0.0, 0.6, 0.5, 0.5],
	"grout": ["", Color(0.55, 0.52, 0.48), 0.95, 0.0, 0.0, 0.0, 0.2],
	"ceramic_white": ["materials/ceramic", Color(0.95, 0.93, 0.89), 0.18, 0.0, 0.3, 0.2, 0.5],
	"ceramic_sage": ["materials/ceramic", Color(0.62, 0.7, 0.6), 0.22, 0.0, 0.3, 0.2, 0.5],
	"terracotta": ["materials/terracotta", Color(1, 1, 1), 0.85, 0.0, 0.3, 0.5, 0.3],
	# Textiles
	"fabric_brown": ["surfaces/brown_weave", Color(0.92, 0.84, 0.76), 0.95, 0.0, 0.3, 0.8, 0.25],
	"leather_brown": ["surfaces/leather", Color(0.82, 0.72, 0.66), 0.48, 0.0, 0.35, 0.55, 0.45],
	"linen_beige": ["surfaces/linen", Color(0.96, 0.9, 0.82), 0.95, 0.0, 0.3, 0.6, 0.25],
	"linen_white": ["surfaces/linen", Color(1.08, 1.06, 1.02), 0.95, 0.0, 0.3, 0.5, 0.25],
	"rug_wool": ["surfaces/rug", Color(1.04, 1.0, 0.94), 0.98, 0.0, 0.8, 0.7, 0.2],
	"canvas_gray": ["surfaces/crib_canvas", Color(1, 1, 1), 0.92, 0.0, 0.3, 0.6, 0.25],
	"sheer_curtain": ["surfaces/linen", Color(0.95, 0.93, 0.88, 0.8), 0.95, 0.0, 0.5, 0.3, 0.2],
	# Plastics / rubber
	"plastic_white": ["", Color(0.88, 0.87, 0.84), 0.4, 0.0, 0.0, 0.0, 0.5],
	"plastic_black": ["", Color(0.05, 0.05, 0.05), 0.4, 0.0, 0.0, 0.0, 0.5],
	"rubber_black": ["", Color(0.04, 0.04, 0.04), 0.85, 0.0, 0.0, 0.0, 0.3],
	"toy_red": ["", Color(0.72, 0.12, 0.09), 0.5, 0.0, 0.0, 0.0, 0.5],
	"toy_yellow": ["", Color(0.9, 0.68, 0.15), 0.5, 0.0, 0.0, 0.0, 0.5],
	"toy_blue": ["", Color(0.16, 0.34, 0.62), 0.5, 0.0, 0.0, 0.0, 0.5],
	"toy_green": ["", Color(0.26, 0.5, 0.26), 0.5, 0.0, 0.0, 0.0, 0.5],
	"toy_pink": ["", Color(0.85, 0.5, 0.58), 0.5, 0.0, 0.0, 0.0, 0.5],
	"tennis_felt": ["materials/tennis_felt", Color(1, 1, 1), 0.95, 0.0, 0.0, 0.8, 0.2],
	# Glass / emissive
	"glass_clear": ["", Color(0.85, 0.9, 0.9, 0.12), 0.05, 0.0, 0.0, 0.0, 0.5],
	"glass_frosted": ["", Color(0.92, 0.92, 0.9, 0.55), 0.45, 0.0, 0.0, 0.0, 0.5],
	"mirror": ["", Color(0.9, 0.9, 0.9), 0.03, 1.0, 0.0, 0.0, 0.5],
	"screen_off": ["", Color(0.012, 0.013, 0.016), 0.12, 0.0, 0.0, 0.0, 0.6],
	"screen": ["", Color(0.012, 0.013, 0.016), 0.1, 0.0, 0.0, 0.0, 0.6],
	"led_warm": ["", Color(1.0, 0.8, 0.55), 0.4, 0.0, 0.0, 0.0, 0.5],
	"clock_digits": ["", Color(1.0, 0.25, 0.15), 0.4, 0.0, 0.0, 0.0, 0.5],
	"water": ["", Color(0.55, 0.7, 0.68, 0.22), 0.04, 0.0, 0.0, 0.0, 0.5],
	# Organic
	"foliage": ["materials/foliage", Color(0.85, 1.0, 0.82), 0.62, 0.0, 0.0, 0.5, 0.4],
	"foliage_dark": ["materials/foliage", Color(0.55, 0.7, 0.55), 0.62, 0.0, 0.0, 0.5, 0.4],
	"soil": ["materials/soil", Color(1, 1, 1), 0.95, 0.0, 0.2, 0.6, 0.2],
	"petal_red": ["", Color(0.62, 0.08, 0.08), 0.7, 0.0, 0.0, 0.0, 0.3],
	"petal_yellow": ["", Color(0.88, 0.66, 0.16), 0.7, 0.0, 0.0, 0.0, 0.3],
	"petal_purple": ["", Color(0.42, 0.22, 0.52), 0.7, 0.0, 0.0, 0.0, 0.3],
	"petal_white": ["", Color(0.92, 0.9, 0.86), 0.7, 0.0, 0.0, 0.0, 0.3],
	"orange_peel": ["materials/orange_peel", Color(1, 1, 1), 0.55, 0.0, 0.0, 0.6, 0.45],
	"apple_red": ["materials/apple", Color(1, 1, 1), 0.4, 0.0, 0.0, 0.4, 0.5],
	"paper": ["materials/paper", Color(1, 1, 1), 0.9, 0.0, 0.3, 0.3, 0.3],
	"book_cover_a": ["", Color(0.48, 0.3, 0.22), 0.7, 0.0, 0.0, 0.0, 0.3],
	"book_cover_b": ["", Color(0.24, 0.32, 0.3), 0.7, 0.0, 0.0, 0.0, 0.3],
	"book_cover_c": ["", Color(0.78, 0.72, 0.6), 0.7, 0.0, 0.0, 0.0, 0.3],
}

static var _cache: Dictionary = {}

static func has_key(key: String) -> bool:
	return SPECS.has(_clean(key)) or _clean(key).begins_with("photo_") or _clean(key).begins_with("art_") or _clean(key) == "clock_face"

static func _clean(key: String) -> String:
	var k := key.trim_prefix("M_")
	var dot := k.find(".")
	return k.substr(0, dot) if dot >= 0 else k

static func material(key: String, mobile := false) -> Material:
	var k := _clean(key)
	var cache_key := k + ("|m" if mobile else "")
	if _cache.has(cache_key):
		return _cache[cache_key]
	var mat: BaseMaterial3D
	if k.begins_with("photo_") or k.begins_with("art_"):
		mat = _image(("res://assets/family/family_%s.jpg" % k.trim_prefix("photo_")) if k.begins_with("photo_") else ("res://assets/art/%s.jpg" % k), 0.7)
	elif k == "clock_face":
		mat = _image(MAT_DIR + "clock_face.png", 0.4)
		mat.emission_enabled = true
		mat.emission_texture = mat.albedo_texture
		mat.emission_energy_multiplier = 1.2
	elif SPECS.has(k):
		mat = _build(k, SPECS[k], mobile)
	else:
		push_warning("InteriorMaterials: unknown key '%s'" % key)
		mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.7, 0.68, 0.64)
		mat.roughness = 0.7
	mat.resource_name = "M_" + k
	_cache[cache_key] = mat
	return mat

static func _image(path: String, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	if ResourceLoader.exists(path):
		mat.albedo_texture = load(path)
	mat.roughness = roughness
	mat.metallic_specular = 0.3
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat

static func _tex(base: String, suffix: String) -> Texture2D:
	for ext: String in [".jpg", ".png"]:
		var path := "res://assets/" + base + "_" + suffix + ext
		if ResourceLoader.exists(path):
			return load(path)
	return null

static func _build(k: String, s: Array, mobile: bool) -> BaseMaterial3D:
	var base: String = s[0]
	var tint: Color = s[1]
	var mat: BaseMaterial3D
	var orm := _tex(base, "orm") if not base.is_empty() else null
	if orm != null:
		var o := ORMMaterial3D.new()
		o.orm_texture = orm
		mat = o
	else:
		mat = StandardMaterial3D.new()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.albedo_color = Color(minf(tint.r, 1.0), minf(tint.g, 1.0), minf(tint.b, 1.0), tint.a)
	mat.roughness = float(s[2])
	mat.metallic = float(s[3])
	mat.metallic_specular = float(s[6])
	if tint.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if not base.is_empty():
		var color := _tex(base, "color")
		if color != null:
			mat.albedo_texture = color
			# Brighten tints above 1 via a lighter albedo multiplier on detail-free maps.
			if tint.r > 1.0 or tint.g > 1.0:
				mat.albedo_color = Color(1, 1, 1, tint.a)
		var rough := _tex(base, "roughness") if orm == null else null
		if rough != null:
			mat.roughness_texture = rough
			mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			# Texture values multiply the scalar; keep the scalar as the finish ceiling.
			mat.roughness = clampf(float(s[2]) * 1.6, 0.0, 1.0)
		var normal := _tex(base, "normal")
		if normal != null and not mobile and float(s[5]) > 0.0:
			mat.normal_enabled = true
			mat.normal_texture = normal
			mat.normal_scale = float(s[5])
		var metres := float(s[4])
		if metres > 0.0:
			mat.uv1_triplanar = true
			mat.uv1_triplanar_sharpness = 6.0
			mat.uv1_scale = Vector3.ONE / metres
	if k in ["led_warm", "clock_digits"]:
		mat.emission_enabled = true
		mat.emission = tint
		mat.emission_energy_multiplier = 3.0
	if k in ["fabric_brown", "linen_beige", "linen_white", "rug_wool", "canvas_gray", "tennis_felt"]:
		# Soft goods: a little sheen at grazing angles instead of plastic highlights.
		if mat is StandardMaterial3D or mat is ORMMaterial3D:
			mat.rim_enabled = not mobile
			mat.rim = 0.25
			mat.rim_tint = 0.6
	return mat
