extends Node3D
## 0.21: the Nichols property, an abandoned American-era mansion south-west of the house, beyond the end of street B.
## A dirt path leaves street B through the dragged-aside barricade, crosses a field of dead grass and reaches an
## open wrought-iron gate between two stone pillars. Inside: a gravel drive round a dry fountain, dead trees, statues
## and the house itself (tools/blender/nichols/build_nichols.py: walls, rooms, staircase, porch, mansard, tower).
## No light burns anywhere on the property: the moon is the only source. It shines into the house through the
## north and west windows (the interior is on its own visual layer, lit by the moon but not by the sky fill), each
## room has a near-black ambient (reflection probes) and a faint dust haze shows the beams.
## The first time the player walks through the gate they say "I've never been inside of the Nichols property..".
## Footsteps echo inside (night_audio.gd asks is_inside()). Doors: scripts/nichols_door.gd / nichols_locked.gd.

const GROUND := -2.9
const HOUSE_POS := Vector3(-12.0, GROUND + 1.2, -82.0)   # front facade centre, ground-floor boards
const GATE := Vector3(-12.0, GROUND, -60.0)
const GATE_HALF := 2.95
const ESTATE := Rect2(-40.0, -124.0, 54.0, 64.0)          # x -40..14, z -124..-60
const REGION := Rect2(-46.0, -130.0, 72.0, 112.0)         # walkable south region, x -46..26, z -130..-18
const DIR := "res://assets/models/nichols/"
const HOUSE_DIR := "res://assets/models/nichols/house/"
const TEX := "res://assets/outdoor/textures/"
const INTERIOR_LAYER := 1 << 10
const OUTDOOR_LAYER := 2
const SURFACE := preload("res://scripts/nichols_surface.gdshader")
const WALLPAPER := preload("res://scripts/nichols_wallpaper.gdshader")
const MARBLE := preload("res://scripts/nichols_marble.gdshader")
const GROUND_SHADER := preload("res://scripts/nichols_ground.gdshader")
const DoorScript := preload("res://scripts/nichols_door.gd")
const LockedScript := preload("res://scripts/nichols_locked.gd")
const ENTRY_LINE := "I've never been inside of the Nichols property.."
## The dirt path from street B to the gate (world XZ).
const PATH := [Vector2(20.6, -24.0), Vector2(20.2, -33.0), Vector2(17.0, -40.5), Vector2(10.0, -47.0), Vector2(1.0, -52.5), Vector2(-6.5, -57.0), Vector2(-12.0, -59.6)]

var b: InteriorBalconyBuilder
var rng := RandomNumberGenerator.new()
var noise_tex: NoiseTexture2D
var mats: Dictionary = {}
var layout: Dictionary = {}
var house: Node3D
var solids: StaticBody3D
var moon: DirectionalLight3D
var stats := {"colliders": 0, "doors": 0, "models": 0, "probes": 0, "trees": 0, "webs": 0}
var entered := false
var _tier := -9
var _rocking: Node3D
var _time := 0.0
var _chandelier: Node3D
var _inner_moon: DirectionalLight3D
var _inside := 0.0
const SHADOW_LAYER := 1 << 11
## 0.22: the basement's own visual layer: no moon, no sky fill, only its bulbs and a flashlight.
const BASEMENT_LAYER := 1 << 12
const BasementScript := preload("res://scripts/nichols_basement.gd")
var basement: Node3D
const BEAM := preload("res://scripts/nichols_beam.gdshader")
## Physics layer of a copy of the house's walls and floors that only the moonbeam ray-casts see.
const ARCH_LAYER := 1 << 19
## 0.22: the cellar under the house (house-local height of its floor, below the ground-floor boards).
const BASEMENT_FLOOR := -2.7
var beams: Array[MeshInstance3D] = []

static func local(x: float, depth: float, up := 0.0) -> Vector3:
	## House space in Blender terms (x east, depth from the front facade, height above the boards) to world.
	return HOUSE_POS + Vector3(x, up, -depth)

func build(town: Node3D) -> void:
	name = "Nichols property"
	add_to_group("nichols_property")
	rng.seed = 1906
	b = InteriorBalconyBuilder.new()
	b._stats = {"triangles_added": 0, "static_batches": 0, "colliders": 0}
	solids = StaticBody3D.new()
	solids.name = "Nichols surfaces"
	solids.collision_layer = 2
	solids.collision_mask = 5
	add_child(solids)
	layout = JSON.parse_string(FileAccess.get_file_as_string(HOUSE_DIR + "layout.json"))
	_noise()
	InteriorLoadClock.mark("nichols: noise")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_materials()
	InteriorLoadClock.mark("nichols: materials")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_open_street(town)
	InteriorLoadClock.mark("nichols: open_street")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_terrain()
	InteriorLoadClock.mark("nichols: terrain")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_house()
	InteriorLoadClock.mark("nichols: house")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_doors()
	InteriorLoadClock.mark("nichols: doors")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_interior_light()
	InteriorLoadClock.mark("nichols: interior_light")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_furnish()
	InteriorLoadClock.mark("nichols: furnish")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	basement = BasementScript.new()
	add_child(basement)
	basement.build(self, town)
	InteriorLoadClock.mark("nichols: basement")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_estate()
	InteriorLoadClock.mark("nichols: estate")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_grounds()
	InteriorLoadClock.mark("nichols: grounds")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_overgrowth()
	InteriorLoadClock.mark("nichols: overgrowth")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_bounds()
	InteriorLoadClock.mark("nichols: bounds")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	InteriorLoadClock.later(_beams)
	b._commit(self, "Nichols - ")
	InteriorLoadClock.mark("nichols: b._commit")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	for child in get_children():
		if child is MeshInstance3D and str(child.name).begins_with("Nichols - "):
			(child as MeshInstance3D).layers = OUTDOOR_LAYER
	stats["triangles"] = b._stats.triangles_added
	set_meta("counts", stats)
	b.free()
	b = null
	moon = town.get_parent().get_node_or_null("Moon") as DirectionalLight3D

# ------------------------------------------------------------------------------------------------ materials

func _noise() -> void:
	var fast := FastNoiseLite.new()
	fast.seed = 1906
	fast.frequency = .012
	fast.fractal_octaves = 4
	noise_tex = NoiseTexture2D.new()
	noise_tex.width = 512
	noise_tex.height = 512
	noise_tex.seamless = true
	noise_tex.generate_mipmaps = true
	noise_tex.noise = fast

func _tex(id: String, map: String) -> Texture2D:
	var path := TEX + id + "/" + map + ".jpg"
	return load(path) if ResourceLoader.exists(path) else null

func _surface(key: String, id: String, tile: float, opts := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SURFACE
	m.resource_name = "Nichols / " + key
	m.set_shader_parameter("albedo_tex", _tex(id, "albedo"))
	m.set_shader_parameter("normal_tex", _tex(id, "normal"))
	m.set_shader_parameter("rough_tex", _tex(id, "roughness"))
	m.set_shader_parameter("noise_tex", noise_tex)
	m.set_shader_parameter("tile", tile)
	for k: String in opts:
		m.set_shader_parameter(k, opts[k])
	mats[key] = m
	return m

func _wallpaper(key: String, channel: int, paper: Color, ink: Color, opts := {}) -> void:
	var m := ShaderMaterial.new()
	m.shader = WALLPAPER
	m.resource_name = "Nichols / " + key
	m.set_shader_parameter("paper_tex", _tex("decrepit_wallpaper", "albedo"))
	m.set_shader_parameter("paper_normal", _tex("decrepit_wallpaper", "normal"))
	m.set_shader_parameter("plaster_tex", _tex("worn_cracked_plaster", "albedo"))
	m.set_shader_parameter("plaster_normal", _tex("worn_cracked_plaster", "normal"))
	m.set_shader_parameter("pattern_tex", load("res://assets/nichols/wallpaper_masks.png"))
	m.set_shader_parameter("noise_tex", noise_tex)
	m.set_shader_parameter("channel", channel)
	m.set_shader_parameter("paper_color", paper)
	m.set_shader_parameter("ink_color", ink)
	for k: String in opts:
		m.set_shader_parameter(k, opts[k])
	mats[key] = m

func _flat(key: String, color: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = "Nichols / " + key
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	mats[key] = m
	return m

func _materials() -> void:
	# Outside.
	_surface("siding", "weathered_plank_siding", 2.2, {"tint": Color(.7, .68, .66), "paint_color": Color(.5, .5, .47), "paint_amount": .78, "grime": .65, "streaks": .75,
		"damp": .7, "damp_height": 1.1, "normal_strength": 1.3})
	_surface("trim ext", "wood_peeling_paint_weathered", 1.2, {"tint": Color(.5, .52, .52), "paint_color": Color(.58, .57, .53), "paint_amount": .75,
		"grime": .55, "streaks": .45})
	_surface("sash", "wood_peeling_paint_weathered", .9, {"tint": Color(.5, .5, .5), "paint_color": Color(.1, .11, .1), "paint_amount": .7, "grime": .4})
	_surface("shutter", "wood_peeling_paint_weathered", .9, {"tint": Color(.6, .6, .6), "paint_color": Color(.1, .17, .14), "paint_amount": .6, "grime": .5})
	_surface("stone", "old_stone_wall", 2.4, {"tint": Color(.62, .6, .56), "grime": .55, "damp": 1.0, "damp_height": 1.0, "base_height": -1.2, "streaks": .4})
	_surface("step", "worn_planks", 1.3, {"tint": Color(.6, .58, .55), "grime": .6, "dust": .2})
	_surface("slate", "roof_slates_02", 2.2, {"tint": Color(.42, .46, .52), "grime": .5, "streaks": .45, "rough_bias": -.05})
	_surface("roof metal", "rusty_metal", 2.0, {"tint": Color(.42, .34, .3), "grime": .4, "metallic": .3})
	_surface("porch floor", "worn_planks", 1.4, {"tint": Color(.62, .58, .54), "grime": .55, "dust": .25})
	_surface("porch ceiling", "weathered_planks", 1.2, {"paint_color": Color(.36, .46, .48), "paint_amount": .6, "grime": .5})
	_surface("board", "weathered_planks", 1.1, {"tint": Color(.7, .66, .6), "grime": .45})
	_surface("lattice", "wood_peeling_paint_weathered", .6, {"paint_color": Color(.6, .6, .56), "paint_amount": .5, "grime": .6})
	_surface("iron", "rusty_metal", .7, {"tint": Color(.22, .19, .17), "grime": .3, "metallic": .55})
	_surface("brick", "red_brick", 1.6, {"tint": Color(.62, .5, .45), "grime": .6, "streaks": .6})
	_surface("door wood", "wood_cabinet_worn_long", 1.0, {"tint": Color(.42, .32, .26), "grime": .5})
	_surface("panel", "wood_cabinet_worn_long", 1.0, {"tint": Color(.33, .24, .2), "grime": .55})
	_flat("clay", Color(.32, .18, .12), .9)
	_flat("void", Color(.004, .004, .005), 1.0)
	_flat("brass", Color(.36, .28, .14), .5, .85)
	var glass := _flat("glass", Color(.05, .06, .065, .32), .12)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.metallic_specular = .9
	var grime := _flat("glass grime", Color(.14, .13, .1, .62), .55)
	grime.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grime.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Inside.
	_wallpaper("wp hall", 0, Color(.33, .39, .43), Color(.2, .25, .3), {"peel": .24})
	_wallpaper("wp parlour", 0, Color(.25, .35, .31), Color(.14, .21, .18), {"peel": .3})
	_wallpaper("wp dining", 2, Color(.36, .14, .13), Color(.24, .08, .08), {"pattern_scale": 2.2, "peel": .24})
	_wallpaper("wp corridor", 0, Color(.28, .34, .44), Color(.16, .2, .28), {"peel": .32, "stains": .8})
	_wallpaper("wp bedroom", 1, Color(.46, .36, .34), Color(.28, .2, .2), {"pattern_scale": 1.2, "peel": .26})
	_wallpaper("wp nursery", 1, Color(.5, .48, .38), Color(.36, .3, .24), {"pattern_scale": 1.0, "peel": .34})
	_surface("wainscot", "dark_paneled_wood", 1.3, {"tint": Color(.62, .5, .45), "grime": .45, "dust": .3})
	_surface("trim", "wood_cabinet_worn_long", .9, {"tint": Color(.46, .36, .3), "grime": .4, "dust": .4})
	_surface("newel", "wood_cabinet_worn_long", .9, {"tint": Color(.4, .3, .25), "grime": .45, "dust": .3})
	mats["rail"] = mats["newel"]
	mats["baluster"] = mats["trim"]
	_surface("ceiling", "ceiling_interior", 2.4, {"tint": Color(.62, .6, .55), "grime": .7, "streaks": .5})
	_surface("plaster", "worn_cracked_plaster", 2.0, {"tint": Color(.66, .63, .56), "grime": .55, "damp": .6, "damp_height": .7})
	_surface("plaster dark", "worn_cracked_plaster", 2.0, {"tint": Color(.3, .29, .27), "grime": .6})
	_surface("floor", "old_wood_floor", 2.2, {"tint": Color(.8, .74, .7), "dust": .55, "grime": .35})
	_surface("floor b", "wood_floor_worn", 2.4, {"tint": Color(.42, .34, .3), "dust": .5, "grime": .4})
	_surface("tile", "marble_tiles", 1.6, {"tint": Color(.62, .6, .55), "dust": .45, "grime": .6})
	_surface("carpet", "dirty_carpet", 1.0, {"tint": Color(.8, .66, .66), "dust": .4, "grime": .4})
	_surface("tread", "wood_cabinet_worn_long", 1.0, {"tint": Color(.42, .31, .24), "dust": .55, "grime": .35})
	_surface("riser", "wood_cabinet_worn_long", 1.0, {"tint": Color(.32, .24, .19), "grime": .5})
	_surface("joist", "weathered_planks", 1.0, {"tint": Color(.45, .4, .35), "grime": .5})
	mats["lath"] = mats["joist"]
	_flat("soot", Color(.018, .016, .015), 1.0)
	var marble := ShaderMaterial.new()
	marble.shader = MARBLE
	marble.set_shader_parameter("noise_tex", noise_tex)
	marble.set_shader_parameter("grit_normal", _tex("worn_cracked_plaster", "normal"))
	mats["marble"] = marble
	var fire := ShaderMaterial.new()
	fire.shader = MARBLE
	fire.set_shader_parameter("noise_tex", noise_tex)
	fire.set_shader_parameter("grit_normal", _tex("worn_cracked_plaster", "normal"))
	fire.set_shader_parameter("checker", false)
	fire.set_shader_parameter("tile_size", 40.0)
	fire.set_shader_parameter("dust", .35)
	mats["marble fire"] = fire
	# Cloth: dark wine drapes, torn lace (its holes cut the moon's shadow into a pattern), dust sheets.
	var two_sided := Shader.new()
	two_sided.code = SURFACE.code.replace("cull_back", "cull_disabled")
	for spec in [["drape", "floral_jacquard", .9, {"tint": Color(.62, .26, .26), "grime": .45, "dust": .3}],
			["sheet", "decrepit_wallpaper", 1.4, {"tint": Color(.92, .9, .84), "grime": .5, "dust": .45}]]:
		var cm := _surface(spec[0], spec[1], spec[2], spec[3])
		cm.shader = two_sided
	var lace := StandardMaterial3D.new()
	lace.resource_name = "Nichols / lace"
	lace.albedo_texture = _lace_texture()
	lace.albedo_color = Color(.78, .77, .72)
	lace.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	lace.alpha_scissor_threshold = .5
	lace.cull_mode = BaseMaterial3D.CULL_DISABLED
	lace.roughness = .95
	lace.uv1_scale = Vector3(2.4, 2.4, 1)
	lace.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mats["lace"] = lace
	# Builder keys (gate, walls, fountain, grounds) share the same materials.
	for key: String in mats:
		b._materials[key] = mats[key]
	_surface("plaster ext", "worn_mossy_plasterwall", 3.0, {"tint": Color(.62, .62, .58), "grime": .5, "damp": 1.0, "damp_height": 1.4, "base_height": GROUND, "streaks": .6})
	_surface("wall stone", "mossy_stone_wall", 2.0, {"tint": Color(.62, .62, .6), "grime": .5, "damp": .6, "base_height": GROUND})
	_surface("cap stone", "old_stone_wall", 1.6, {"tint": Color(.55, .54, .5), "grime": .6, "streaks": .5})
	for key in ["plaster ext", "wall stone", "cap stone"]:
		b._materials[key] = mats[key]
	_basement_materials()

## 0.22: the cellar, its stair and the tunnel under the house (tools/blender/nichols/nichols_basement.py).
func _basement_materials() -> void:
	var cellar_y := HOUSE_POS.y + BASEMENT_FLOOR
	var tunnel_y := HOUSE_POS.y + BASEMENT_FLOOR - .9
	_surface("cellar floor", "damaged_concrete_floor", 2.6, {"tint": Color(.6, .56, .52), "grime": .75, "dust": .2, "rough_bias": -.32})
	_surface("cellar stone", "rustic_stone_wall_02", 1.7, {"tint": Color(.5, .47, .43), "grime": .7, "damp": 1.0, "damp_height": 1.2,
		"base_height": cellar_y, "streaks": .65, "normal_strength": 1.5})
	_surface("cellar plaster", "rough_plaster_brick_04", 1.8, {"tint": Color(.6, .58, .53), "grime": .65, "damp": .9, "damp_height": 1.0,
		"base_height": cellar_y, "streaks": .55})
	_surface("subfloor", "weathered_planks", 1.2, {"tint": Color(.38, .32, .26), "grime": .75})
	_surface("post", "weathered_planks", .8, {"tint": Color(.42, .35, .28), "grime": .65, "dust": .3})
	_surface("stair", "worn_planks", 1.1, {"tint": Color(.5, .44, .38), "grime": .6, "dust": .55})
	_surface("bench top", "wood_cabinet_worn_long", .9, {"tint": Color(.36, .28, .22), "grime": .85, "dust": .25})
	_surface("pegboard", "weathered_planks", .6, {"tint": Color(.5, .42, .32), "grime": .6})
	_surface("block wood", "weathered_planks", .7, {"tint": Color(.45, .36, .28), "grime": .6})
	_surface("pipe", "rusty_metal_03", 1.4, {"tint": Color(.4, .3, .25), "grime": .55, "metallic": .45, "streaks": .35})
	_surface("chain", "rusty_metal_03", 3.0, {"tint": Color(.3, .25, .21), "metallic": .6, "grime": .3})
	_surface("cage iron", "rusty_metal_03", 2.0, {"tint": Color(.26, .23, .2), "metallic": .5, "grime": .45})
	_surface("tub", "rusty_metal_sheet", 1.2, {"tint": Color(.55, .56, .56), "metallic": .65, "grime": .5})
	_surface("step concrete", "damaged_concrete_floor", 1.6, {"tint": Color(.52, .5, .47), "grime": .75})
	_surface("corridor wall", "dirty_concrete", 1.7, {"tint": Color(.6, .6, .58), "grime": .55, "streaks": .25, "damp": .85,
		"damp_height": .8, "base_height": tunnel_y})
	_surface("corridor floor", "damaged_concrete_floor", 2.2, {"tint": Color(.4, .38, .36), "grime": .85, "dust": .05, "rough_bias": -.45})
	_surface("corridor ceiling", "rough_concrete", 1.6, {"tint": Color(.42, .42, .4), "grime": .8, "streaks": .2})
	_surface("vent", "rusty_metal_03", 1.0, {"tint": Color(.24, .2, .17), "metallic": .5, "grime": .5})
	_surface("door frame", "rusty_metal_sheet", 1.0, {"tint": Color(.4, .39, .37), "metallic": .5, "grime": .5})
	_surface("steel door", "rusty_metal_sheet", 1.2, {"tint": Color(.11, .1, .1), "metallic": .6, "grime": .35, "streaks": .4})
	_surface("cellar door", "weathered_planks", .9, {"tint": Color(.42, .35, .28), "grime": .7})
	mats["rail wood"] = mats["newel"]
	_flat("iron dark", Color(.035, .03, .028), .7, .5)
	_flat("cord", Color(.03, .028, .025), .8)
	_flat("coal", Color(.022, .022, .025), .5)
	_flat("outline", Color(.4, .36, .29), .9)
	_flat("lid", Color(.22, .16, .09), .55, .6)
	_flat("jar dark", Color(.05, .035, .025), .3)
	_flat("jar red", Color(.13, .025, .02), .3)
	_flat("jar murk", Color(.12, .11, .05), .35)
	_flat("block top", Color(.09, .025, .02), .45)
	_flat("tarp", Color(.07, .09, .11), .5)
	_flat("wet band", Color(.045, .04, .034), .25)
	_flat("conduit", Color(.36, .28, .04), .6, .2)
	_flat("rag", Color(.2, .17, .13), .95)
	_flat("enamel", Color(.55, .53, .48), .25)
	_flat("enamel stain", Color(.2, .1, .06), .4)
	_flat("valve", Color(.22, .035, .025), .6, .4)
	_flat("collar", Color(.2, .05, .04), .5)
	_flat("padlock", Color(.62, .6, .55), .25, 1.0)
	var jar := _flat("jar", Color(.3, .34, .32, .3), .12)
	jar.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	jar.metallic_specular = .8
	# The kitchen: chipped enamel over rusting steel, a painted cabinet, a lit refrigerator.
	_surface("cab paint", "wood_peeling_paint_weathered", .9, {"tint": Color(.5, .5, .46), "paint_color": Color(.4, .46, .37), "paint_amount": .78, "grime": .65})
	_surface("stove enamel", "rusty_metal_sheet", 1.0, {"tint": Color(.6, .55, .5), "paint_color": Color(.66, .63, .54), "paint_amount": .88,
		"grime": .6, "streaks": .4})
	_surface("fridge enamel", "rusty_metal_sheet", 1.0, {"tint": Color(.55, .5, .45), "paint_color": Color(.55, .52, .45), "paint_amount": .86,
		"grime": .8, "streaks": .7})
	_flat("fridge liner", Color(.6, .58, .52), .45)
	_flat("wire", Color(.42, .42, .4), .35, .8)
	_flat("meat", Color(.16, .025, .02), .22)
	_flat("plate", Color(.64, .62, .56), .2)
	_flat("chrome", Color(.55, .55, .55), .2, 1.0)
	var bottle := _flat("bottle glass", Color(.1, .18, .1, .55), .1)
	bottle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# The jumper: a new cable, a new power strip with its rocker lit.
	_flat("cable", Color(.42, .14, .03), .45)
	_flat("strip", Color(.55, .54, .5), .4)
	var lamp := _flat("strip lamp", Color(.9, .4, .08), .3)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, .42, .08)
	lamp.emission_energy_multiplier = 3.0

## Machine lace: a fine diagonal net with rows of flowers.
func _lace_texture() -> ImageTexture:
	var n := 256
	var img := Image.create(n, n, true, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	for y in n:
		for x in n:
			var a := 0.0
			if (x + y) % 9 == 0 or (x - y + n) % 9 == 0:
				a = 1.0
			var cx := float(x % 64) - 32.0
			var cy := float(y % 64) - 32.0
			var r := sqrt(cx * cx + cy * cy)
			var ang := atan2(cy, cx)
			var petal := 13.0 + 6.0 * cos(ang * 6.0)
			if absf(r - petal) < 1.6 or r < 3.0:
				a = 1.0
			elif r < petal - 1.6:
				a = 0.0 if r > 5.0 else a
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _material_for(key: String) -> Material:
	return mats.get(key, null)

func _bind(node: Node, layers: int, shadows := true) -> void:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		mi.layers = layers
		if not shadows:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			if src == null:
				continue
			var mat := _material_for(src.resource_name)
			if mat != null:
				mi.set_surface_override_material(s, mat)

# ------------------------------------------------------------------------------------------------ house

func _house() -> void:
	var arch := StaticBody3D.new()
	arch.name = "Beam blockers"
	arch.collision_layer = ARCH_LAYER
	arch.collision_mask = 0
	add_child(arch)
	house = Node3D.new()
	house.name = "Nichols house"
	house.position = HOUSE_POS
	add_child(house)
	for spec in [["house_ext", OUTDOOR_LAYER, true], ["house_int", INTERIOR_LAYER, true], ["house_glass", OUTDOOR_LAYER | INTERIOR_LAYER, false],
			["house_void", OUTDOOR_LAYER | INTERIOR_LAYER, true], ["house_cloth", INTERIOR_LAYER, true], ["house_base", BASEMENT_LAYER, true]]:
		var path: String = HOUSE_DIR + spec[0] + ".glb"
		if not ResourceLoader.exists(path):
			continue
		var node := (load(path) as PackedScene).instantiate() as Node3D
		node.name = spec[0]
		house.add_child(node)
		_bind(node, spec[1], spec[2])
	for box: Dictionary in layout.get("boxes", []):
		var c := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(box.s[0], box.s[1], box.s[2])
		shape.margin = .002
		c.shape = shape
		var cols: Array = box.b
		var basis := Basis(Vector3(cols[0][0], cols[0][1], cols[0][2]), Vector3(cols[1][0], cols[1][1], cols[1][2]), Vector3(cols[2][0], cols[2][1], cols[2][2]))
		c.transform = Transform3D(basis, HOUSE_POS + Vector3(box.c[0], box.c[1], box.c[2]))
		c.set_meta("surface", box.surface)
		c.name = str(box.label).validate_node_name()
		solids.add_child(c, true)
		stats.colliders += 1
		if box.surface != "glass":
			var arch_shape := c.duplicate() as CollisionShape3D
			arch.add_child(arch_shape)

func _v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])

## True when `p` (world) is inside the house walls, cellar and tunnel included (night_audio.gd: the echo).
func is_inside(p: Vector3) -> bool:
	var q := p - HOUSE_POS
	return q.x > -12.85 and q.x < 12.85 and q.z < .45 and q.z > -19.85 and q.y > -3.9 and q.y < 8.4

## 0.22: below the ground-floor boards (the cellar stair, the cellar, the tunnel).
func is_below(p: Vector3) -> bool:
	return is_inside(p) and p.y - HOUSE_POS.y < -.35

# ------------------------------------------------------------------------------------------------ doors

func _door(hinge: Vector3, latch: Vector3, swing: Vector3, height: float, width: float, leaf_path: String, label: String,
		start := 0.0, heavy := false, native := 0.0) -> Node3D:
	var u := (latch - hinge).normalized()
	var x := -u
	var basis := Basis(x, Vector3.UP, x.cross(Vector3.UP))
	var sign := 1.0 if basis.z.dot(swing) > 0.0 else -1.0
	var door := DoorScript.new()
	door.name = ("Nichols " + label).validate_node_name()
	door.label = label.to_lower() if label != "Front door" else "the front door"
	door.open_angle_deg = 100.0 * sign
	door.swing_seconds = 1.6 if heavy else 1.1
	door.heavy = heavy
	var leaf := AnimatableBody3D.new()
	leaf.name = "Leaf"
	leaf.collision_layer = 2
	leaf.collision_mask = 5
	leaf.sync_to_physics = true
	door.add_child(leaf)
	var c := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, .06)
	box.margin = .002
	c.shape = box
	c.position = Vector3(-width * .5, height * .5, 0)
	c.set_meta("surface", "wood")
	leaf.add_child(c)
	if ResourceLoader.exists(leaf_path):
		var mesh := (load(leaf_path) as PackedScene).instantiate() as Node3D
		leaf.add_child(mesh)
		if native <= 0.0:
			native = .92 if "front" in leaf_path else .98
		mesh.scale = Vector3(width / native, 1, 1)
		_bind(mesh, OUTDOOR_LAYER | INTERIOR_LAYER)
	door.transform = Transform3D(basis, hinge)
	add_child(door)
	if start > 0.0:
		door.set("_manual", true)
		door.set("_t", start)
		door.call("_apply")
		door.set("_last", leaf.rotation.y)
		door.set("_was_closed", false)
	stats.doors += 1
	return door

func _doors() -> void:
	var fd: Dictionary = layout.get("front_door", {})
	if not fd.is_empty():
		var hl := HOUSE_POS + _v(fd.hinge_l)
		var hr := HOUSE_POS + _v(fd.hinge_r)
		var inward := -_v(fd.out)
		var leaf := float(fd.leaf)
		# The left leaf stands a hand's width open: the house was never locked.
		_door(hl, hl + (hr - hl).normalized() * leaf, inward, float(fd.height), leaf, HOUSE_DIR + "house_leaf.glb", "Front door", .1, true)
		_door(hr, hr + (hl - hr).normalized() * leaf, inward, float(fd.height), leaf, HOUSE_DIR + "house_leaf.glb", "Front door", 0.0, true)
	for d: Dictionary in layout.get("doors", []):
		var hinge := HOUSE_POS + _v(d.hinge)
		var latch := HOUSE_POS + _v(d.latch)
		var swing := _v(d.swing)
		var state := str(d.state)
		var label := str(d.label)
		if state == "locked":
			var lock := LockedScript.new()
			lock.name = ("Nichols " + label).validate_node_name()
			lock.label = label.to_lower()
			add_child(lock)
			var body := StaticBody3D.new()
			body.collision_layer = 2
			body.collision_mask = 5
			lock.add_child(body)
			var u := (latch - hinge).normalized()
			var basis := Basis(-u, Vector3.UP, (-u).cross(Vector3.UP))
			var c := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(float(d.width), float(d.height), .06)
			c.shape = box
			c.set_meta("surface", "wood")
			body.add_child(c)
			body.transform = Transform3D(basis, hinge)
			c.position = Vector3(-float(d.width) * .5, float(d.height) * .5, 0)
			if ResourceLoader.exists(HOUSE_DIR + "house_leaf_door.glb"):
				var mesh := (load(HOUSE_DIR + "house_leaf_door.glb") as PackedScene).instantiate() as Node3D
				body.add_child(mesh)
				mesh.scale = Vector3(float(d.width) / .98, 1, 1)
				_bind(mesh, INTERIOR_LAYER)
			continue
		var start := 0.0
		if state in ["ajar", "open"]:
			start = clampf(float(d.angle) / 100.0, 0.0, 1.0)
		_door(hinge, latch, swing, float(d.height), float(d.width), HOUSE_DIR + "house_leaf_door.glb", label, start)

# ------------------------------------------------------------------------------------------------ light

func _interior_light() -> void:
	# Each room: a reflection probe whose ambient is near black, so only the moon through the windows (and a
	# flashlight) shows anything. The probes also give the floors faint, correct reflections of the beams.
	for room: Dictionary in layout.get("rooms", []):
		for r: Array in room.rects:
			var a := _v(r[0])
			var c := _v(r[1])
			var lo := Vector3(minf(a.x, c.x), minf(a.y, c.y), minf(a.z, c.z))
			var hi := Vector3(maxf(a.x, c.x), maxf(a.y, c.y), maxf(a.z, c.z))
			var probe := ReflectionProbe.new()
			probe.name = ("Probe " + str(room.name)).validate_node_name()
			probe.size = (hi - lo) + Vector3(.1, .2, .1)
			probe.position = HOUSE_POS + (lo + hi) * .5
			probe.interior = true
			probe.box_projection = true
			probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
			# Moonlight bouncing off the walls: a faint blue fill (more in the moonlit rooms), the corners still black.
			var lit_room := str(room.name) in ["parlour", "corridor_w", "corridor_e", "bridge", "foyer", "master", "hall", "gallery_w", "gallery_e"]
			probe.ambient_color = Color(.03, .036, .052) if lit_room else Color(.016, .019, .028)
			probe.ambient_color_energy = 1.0
			probe.intensity = .35
			probe.cull_mask = OUTDOOR_LAYER | INTERIOR_LAYER
			probe.update_mode = ReflectionProbe.UPDATE_ONCE
			add_child(probe)
			stats.probes += 1
	# Dust in the air: the moon's beams show in it (volumetric fog, desktop High and Ultra).
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		var fog := FogVolume.new()
		fog.name = "House dust"
		fog.size = Vector3(25.6, 8.4, 19.6)
		fog.position = HOUSE_POS + Vector3(0, 4.2, -10.0)
		var fm := FogMaterial.new()
		fm.density = .004
		fm.albedo = Color(.8, .84, .9)
		fm.edge_fade = .05
		fog.material = fm
		add_child(fog)
	# The interior moon: the same moon, stronger, lighting only the inside layer, so its beams through the
	# windows can be tuned without brightening the night outside. The house shell casts its shadows through a
	# shadow-only copy on a layer of its own.
	_inner_moon = DirectionalLight3D.new()
	_inner_moon.name = "Moon through the windows"
	_inner_moon.light_energy = 2.3
	_inner_moon.light_cull_mask = INTERIOR_LAYER | SHADOW_LAYER
	_inner_moon.shadow_enabled = true
	_inner_moon.shadow_bias = .03
	_inner_moon.shadow_normal_bias = .8
	_inner_moon.shadow_blur = 1.2
	_inner_moon.directional_shadow_max_distance = 40.0
	_inner_moon.directional_shadow_blend_splits = true
	_inner_moon.light_volumetric_fog_energy = .7
	_inner_moon.light_specular = .4
	_inner_moon.basis = InteriorNight.moon_basis()
	add_child(_inner_moon)
	var shell := house.get_node_or_null("house_ext") as Node3D
	if shell != null:
		var caster := shell.duplicate() as Node3D
		caster.name = "Shell shadow"
		house.add_child(caster)
		for mi in caster.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).layers = SHADOW_LAYER
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

var _env_node: WorldEnvironment
var _env_retry := 0.0
var _suns: Array[DirectionalLight3D] = []
var _suns_retry := 0.0

func _update_light() -> void:
	if moon == null or not is_instance_valid(moon):
		moon = get_tree().current_scene.find_child("Moon", true, false) as DirectionalLight3D if get_tree().current_scene != null else null
		if moon == null:
			return
	# Without moon shadows (Low) the beams would come straight through the roof: keep the interior unlit then.
	if _inner_moon == null:
		return
	# Global lights belong to the owner's room or the night outside: none of them may reach the house's inside
	# (the room's key light has no shadows and would light every room and the dust in the air).
	# 0.30: the scene's few directional lights are listed every eight seconds, not every 15 frames (that walk over
	# the whole tree was a 5 ms hitch twelve times a second).
	if _suns.is_empty() or _time >= _suns_retry:
		_suns_retry = _time + 8.0
		_suns.clear()
		for node in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
			_suns.append(node as DirectionalLight3D)
	for light: DirectionalLight3D in _suns:
		if not is_instance_valid(light) or light == _inner_moon:
			continue
		if light.light_cull_mask & (INTERIOR_LAYER | BASEMENT_LAYER):
			light.light_cull_mask &= ~(INTERIOR_LAYER | BASEMENT_LAYER)
		if not light.has_meta("nichols_fog"):
			light.set_meta("nichols_fog", light.light_volumetric_fog_energy)
		light.light_volumetric_fog_energy = float(light.get_meta("nichols_fog")) * (1.0 - _inside)
	_inner_moon.basis = moon.global_basis
	_inner_moon.light_color = moon.light_color
	# Without moon shadows (Low) the beams would come straight through the roof: no interior moon then.
	var cam := get_viewport().get_camera_3d()
	var near := cam != null and cam.global_position.distance_to(HOUSE_POS + Vector3(0, 4, -10)) < 70.0
	_inner_moon.visible = moon.shadow_enabled and near
	_inner_moon.directional_shadow_mode = moon.directional_shadow_mode

## Shafts of moonlight: each moonlit window's corners are cast along the moon onto the walls and floors that
## stop them, and the prism between is drawn with the additive dust shader (nichols_beam.gdshader).
func _beams() -> void:
	if not is_inside_tree(): return
	await get_tree().physics_frame
	# (0.66: the squad game lets go of the whole property at its start, maybe between these two frames.)
	if not is_inside_tree(): return
	await get_tree().physics_frame
	if not is_inside_tree(): return
	var space := get_world_3d().direct_space_state
	var L := -InteriorNight.MOON_DIRECTION.normalized()
	var m := ShaderMaterial.new()
	m.shader = BEAM
	m.set_shader_parameter("noise_tex", noise_tex)
	for w: Dictionary in layout.get("windows", []):
		if not w.moonlit or w.boarded or w.blind or str(w.room) in ["sealed", ""]:
			continue
		var n := _v(w.normal)
		var along := _v(w.along)
		var base := HOUSE_POS + _v(w.inner) - n * .03
		var half := float(w.width) * .5 - .1
		var h := float(w.height) - .12
		var corners: Array[Vector3] = [base - along * half + Vector3.UP * .06, base + along * half + Vector3.UP * .06,
			base + along * half + Vector3.UP * h, base - along * half + Vector3.UP * h]
		var far: Array[Vector3] = []
		var lengths: Array[float] = []
		for c in corners:
			var q := PhysicsRayQueryParameters3D.create(c, c + L * 40.0, ARCH_LAYER)
			var hit := space.intersect_ray(q)
			var end: Vector3 = hit.position if hit else c + L * 40.0
			far.append(end)
			lengths.append(c.distance_to(end))
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Soft cards: slices across the width (vertical) and across the height (horizontal), each running from
		# the window to where the light lands.
		var at := func(u: float, v: float, far_end: bool) -> Vector3:
			var src: Array[Vector3] = far if far_end else corners
			var bottom: Vector3 = src[0].lerp(src[1], u)
			var top: Vector3 = src[3].lerp(src[2], u)
			return bottom.lerp(top, v)
		for k in 6:
			var u := (k + .5) / 6.0
			_card(st, at.call(u, 0.0, false), at.call(u, 1.0, false), at.call(u, 1.0, true), at.call(u, 0.0, true), L)
		for k in 5:
			var v := (k + .5) / 5.0
			_card(st, at.call(0.0, v, false), at.call(1.0, v, false), at.call(1.0, v, true), at.call(0.0, v, true), L)
		# Bounce: the moonlit patch on the floor and the window itself lift the walls and furniture around them.
		var patch := (far[0] + far[1] + far[2] + far[3]) * .25 + Vector3.UP * .45
		for spec in [[patch, .55, 5.5], [base + Vector3.UP * (h * .55) - n * .7, .3, 3.8]]:
			var bounce := OmniLight3D.new()
			bounce.name = "Moon bounce " + str(w.room)
			bounce.light_color = Color(.56, .64, .84)
			bounce.light_energy = spec[1]
			bounce.omni_range = spec[2]
			bounce.omni_attenuation = 1.6
			bounce.light_cull_mask = INTERIOR_LAYER
			bounce.shadow_enabled = false
			bounce.light_specular = .15
			bounce.light_volumetric_fog_energy = 0.0
			add_child(bounce)
			bounce.global_position = spec[0]
		var mi := MeshInstance3D.new()
		mi.name = "Moonbeam " + str(w.room)
		mi.mesh = st.commit()
		var mat := m.duplicate() as ShaderMaterial
		mat.set_shader_parameter("intensity", .022)
		mi.material_override = mat
		mi.layers = INTERIOR_LAYER
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		beams.append(mi)
	stats["beams"] = beams.size()

func _card(st: SurfaceTool, a: Vector3, c: Vector3, fc: Vector3, fa: Vector3, L: Vector3) -> void:
	var nrm := (c - a).cross(L).normalized()
	var quad := [a, c, fc, fa]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_normal(nrm)
		st.set_uv(uvs[idx])
		st.add_vertex(quad[idx])

# ------------------------------------------------------------------------------------------------ furniture

## 0.22: nearly everything inside the house is a physical prop (InteriorObject): small things are picked up and
## carried with E, heavy furniture is dragged (hold E) or shoved, wall frames and mirrors hang until grabbed.
## Kept static: the hanging chandelier and the one that came down onto the dining table.
const STATIC_PROPS := ["chandelier_01", "chandelier_02", "bench_vice_01", "hatchet"]
## name: [mass kg, physics material, label]. Props of 15 kg and more are dragged, not lifted.
const PROP_SPECS := {
	"vintage_suitcase": [6.0, "leather", "Old suitcase"], "wheelchair_01": [16.0, "metal", "Wheelchair"],
	"classicconsole_01": [22.0, "wood", "Console table"], "antique_ceramic_vase_01": [1.6, "ceramic", "Vase"],
	"armchair_01": [18.0, "fabric", "Armchair"], "gothic_coffee_table": [12.0, "wood", "Coffee table"],
	"dusty_piano": [220.0, "wood", "Piano"], "rockingchair_01": [9.0, "wood", "Rocking chair"],
	"ornate_mirror_01": [9.0, "glass", "Mirror"], "mantel_clock_01": [2.5, "wood", "Mantel clock"],
	"candelabra": [1.8, "metal", "Candelabra"], "spinning_wheel_01": [7.0, "wood", "Spinning wheel"],
	"fancy_picture_frame_02": [3.0, "wood", "Picture frame"], "dining_table": [45.0, "wood", "Dining table"],
	"dining_chair_02": [5.0, "wood", "Dining chair"], "tea_set_01": [1.5, "ceramic", "Tea set"],
	"wine_bottles_01": [3.0, "glass", "Wine bottles"], "vintage_cabinet_01": [55.0, "wood", "Cabinet"],
	"gothiccommode_01": [40.0, "wood", "Commode"], "vintage_grandfather_clock_01": [60.0, "wood", "Grandfather clock"],
	"porcelain_doll": [.8, "ceramic", "Porcelain doll"], "hanging_picture_frame_01": [2.5, "wood", "Picture frame"],
	"hanging_picture_frame_02": [2.5, "wood", "Picture frame"], "hanging_picture_frame_03": [2.5, "wood", "Picture frame"],
	"wooden_bookshelf_worn": [45.0, "wood", "Bookshelf"], "round_wooden_table_01": [14.0, "wood", "Round table"],
	"chess_set": [1.5, "wood", "Chess set"], "woodenchair_01": [4.0, "wood", "Wooden chair"],
	"lantern_01": [1.2, "metal", "Lantern"], "wooden_crate_02": [6.0, "wood", "Crate"],
	"vintage_oil_lamp": [1.2, "glass", "Oil lamp"], "greenchair_01": [9.0, "fabric", "Chair"],
	"gothicbed_01": [90.0, "wood", "Bed"], "classicnightstand_01": [12.0, "wood", "Nightstand"],
	"standing_picture_frame_01": [.8, "wood", "Photo frame"], "wooden_candlestick": [.5, "wood", "Candlestick"],
	"old_bed_frame": [28.0, "metal", "Iron cot"], "rocking_horse": [9.0, "wood", "Rocking horse"],
	"antique_doll": [.7, "ceramic", "Doll"], "treasure_chest": [18.0, "wood", "Chest"],
	"coffeetable_01": [10.0, "wood", "Low table"], "vintage_crutches_01": [2.2, "wood", "Crutches"],
	"ceramic_vase_02": [1.4, "ceramic", "Vase"], "ceramic_vase_04": [1.4, "ceramic", "Vase"],
	"brass_candleholders": [1.2, "metal", "Candleholders"], "ottoman_01": [6.0, "fabric", "Footstool"],
	"vintage_wooden_drawer_01": [6.0, "wood", "Drawer"], "gothiccabinet_01": [45.0, "wood", "Cabinet"],
	"sofa_01": [45.0, "fabric", "Sofa"], "horse_statue_01": [4.0, "metal", "Horse statue"],
	"sheet_sofa": [50.0, "fabric", "Covered sofa"], "sheet_armchair": [18.0, "fabric", "Covered armchair"],
	"sheet_table": [20.0, "fabric", "Covered table"], "sheet_tall": [80.0, "fabric", "Covered wardrobe"],
	# 0.22 cellar, tunnel and kitchen.
	"wine_barrel_01": [60.0, "wood", "Barrel"], "barrel_01": [35.0, "metal", "Oil drum"],
	"barrel_stove": [45.0, "metal", "Iron stove"], "worn_metal_rack": [25.0, "metal", "Metal rack"],
	"steel_frame_shelves_02": [15.0, "metal", "Shelves"], "wooden_display_shelves_01": [14.0, "wood", "Shelves"],
	"painted_wooden_shelves": [9.0, "wood", "Shelf"], "metal_tool_chest": [40.0, "metal", "Tool chest"],
	"cardboard_box_01": [2.0, "cardboard", "Box"], "wooden_crate_01": [8.0, "wood", "Crate"], "old_tyre": [8.0, "rubber", "Old tyre"],
	"wooden_ladder": [6.0, "wood", "Step ladder"], "propane_tank": [12.0, "metal", "Gas tank"], "trashbag": [2.5, "plastic", "Garbage bag"],
	"wooden_bucket_01": [3.0, "wood", "Bucket"], "can_rusted": [.4, "metal", "Rusted can"], "handsaw_wood": [.9, "metal", "Saw"],
	"rusted_hacksaw": [.6, "metal", "Hacksaw"], "machete": [.7, "metal", "Machete"], "sledgehammer_01": [6.0, "metal", "Sledgehammer"],
	"crowbar_01": [1.5, "metal", "Crowbar"], "bolt_cutters_01": [3.0, "metal", "Bolt cutters"], "pipe_wrench": [1.5, "metal", "Pipe wrench"],
	"mousetrap": [.1, "wood", "Mousetrap"], "street_rat": [.3, "fabric", "Dead rat"], "metal_office_desk": [50.0, "metal", "Metal desk"],
	"medical_box": [1.5, "metal", "First-aid box"], "metal_stool_01": [5.0, "metal", "Stool"],
	"pot_enamel_01": [1.2, "metal", "Enamel pot"], "brass_pan_01": [1.0, "metal", "Pan"],
	"wooden_cutting_board": [1.0, "wood", "Chopping board"], "jug_01": [1.0, "ceramic", "Jug"], "wooden_bowl_01": [.6, "wood", "Bowl"],
	"fish_knife": [.2, "metal", "Knife"],
}
var props: Array[InteriorObject] = []

## Wraps a placed model in a rigid body at the same pose (the scale stays on the visual), with a box fitted to
## the model's own bounds. `hung` props (frames, mirrors) stay frozen on the wall until grabbed.
func _physical(visual: Node3D, name_: String, hung := false, floor_clip := false) -> InteriorObject:
	var spec: Array = PROP_SPECS.get(name_, [])
	var box := InteriorModelKit.local_bounds(visual)
	var xf := visual.global_transform
	var s := xf.basis.get_scale()
	var size := box.size * s
	var mass: float = spec[0] if spec.size() > 0 else clampf(size.x * size.y * size.z * 90.0, .5, 60.0)
	var body := InteriorObject.new()
	body.name = ("Nichols " + name_).validate_node_name()
	body.display_name = spec[2] if spec.size() > 2 else name_.capitalize()
	body.physics_material = spec[1] if spec.size() > 1 else "wood"
	body.mass = mass
	body.outdoor = true
	body.anchored = hung
	body.grab_mode = "carry" if mass < 15.0 else "drag"
	body.set_meta("loose_prop", "nichols")
	body.set_meta("nichols_prop", name_)
	var parent := visual.get_parent()
	parent.add_child(body, true)
	body.global_transform = Transform3D(xf.basis.orthonormalized(), xf.origin)
	parent.remove_child(visual)
	body.add_child(visual)
	visual.transform = Transform3D(Basis.IDENTITY.scaled(s), Vector3.ZERO)
	if SEATS.has(name_):
		_seat_shapes(body, visual, SEATS[name_])
	else:
		var fitted := AABB(box.position * s, size)
		if floor_clip and fitted.position.y < 0.0:
			# Dust sheets drape a little below the boards: their box starts at the floor.
			fitted.size.y += fitted.position.y
			fitted.position.y = 0.0
		# A sheet's drape spreads over the floor well beyond the furniture under it.
		_box_shape(body, fitted, Vector3(.68, 1.0, .68) if floor_clip else Vector3(.9, 1.0, .9))
	body.home_transform = body.global_transform
	props.append(body)
	return body

## Seat height (fraction of the model's height) of things that others sit or lie on: a solid base up to the seat,
## then boxes round the parts above it at the two ends of the long side (a chair back, a bed's head and foot boards),
## so a doll can sit on the chair and lie on the cot.
const SEATS := {"dining_chair_02": .47, "rockingchair_01": .42, "wheelchair_01": .45, "old_bed_frame": .4, "gothicbed_01": .42}

func _box_shape(body: CollisionObject3D, box: AABB, shrink := Vector3.ONE) -> void:
	var c := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = (box.size * shrink).max(Vector3.ONE * .03)
	shape.margin = InteriorPropPhysics.SHAPE_MARGIN
	c.shape = shape
	c.position = box.get_center()
	body.add_child(c)

func _seat_shapes(body: InteriorObject, visual: Node3D, seat_frac: float) -> void:
	var pts := PackedVector3Array()
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var walker: Node = mi
		while walker != body and walker != null:
			if walker is Node3D:
				xf = (walker as Node3D).transform * xf
			walker = walker.get_parent()
		for si in mi.mesh.get_surface_count():
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
			var step := maxi(1, verts.size() / 3000)
			for k in range(0, verts.size(), step):
				pts.append(xf * verts[k])
	if pts.is_empty():
		return
	var all := AABB(pts[0], Vector3.ZERO)
	for q in pts:
		all = all.expand(q)
	var seat_y := all.position.y + all.size.y * seat_frac
	_box_shape(body, AABB(all.position, Vector3(all.size.x, seat_y - all.position.y, all.size.z)), Vector3(.92, 1, .92))
	var axis := 0 if all.size.x > all.size.z else 2
	for end in 2:
		var part := AABB()
		var found := false
		for q in pts:
			if q.y < seat_y + .03:
				continue
			var t := (q[axis] - all.position[axis]) / maxf(all.size[axis], .001)
			if (end == 0 and t > .3) or (end == 1 and t < .7):
				continue
			part = part.expand(q) if found else AABB(q, Vector3.ZERO)
			found = true
		if found and part.end.y - seat_y > .06:
			part.size.y = part.end.y - seat_y
			part.position.y = seat_y
			_box_shape(body, part, Vector3(.95, 1, .95))

func _model(name_: String, p: Vector3, yaw: float, scale := 1.0, collide := true, tilt := Vector3.ZERO, layer := INTERIOR_LAYER) -> Node3D:
	var path := DIR + "nh_" + name_ + ".glb"
	if not ResourceLoader.exists(path):
		return null
	var inside := layer != OUTDOOR_LAYER
	var node := InteriorModelKit.place(house if inside else self, path, house.to_local(p) if inside else p, yaw, scale, "bottom", tilt, name_)
	InteriorModelKit.prepare_instance(node, layer, 0.0, true, false)
	_age(node)
	if inside and not name_ in STATIC_PROPS:
		# Frames and mirrors well above a floor hang on the wall; the same models lying on the floor are loose.
		var rel := p.y - HOUSE_POS.y
		var above := rel - (F1() if rel > F1() - .3 else (BASEMENT_FLOOR if rel < -.3 else 0.0))
		var hung := ("frame" in name_ or "mirror" in name_) and not "standing" in name_ and above > .9 and absf(tilt.x) < 30.0
		_physical(node, name_, hung)
		stats.models += 1
		return node
	if collide:
		var box := InteriorModelKit.bounds_in(node, self)
		if box.size.y > .25:
			var c := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = box.size * Vector3(.85, 1, .85)
			c.shape = shape
			c.position = box.get_center()
			c.set_meta("surface", "wood")
			solids.add_child(c)
	stats.models += 1
	return node

## Old furniture: duller, darker, dustier than the clean scans.
func _age(node: Node) -> void:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if src == null:
				continue
			var key := "aged " + str(src.get_instance_id())
			if not mats.has(key):
				var m := src.duplicate() as BaseMaterial3D
				m.albedo_color = m.albedo_color * Color(.62, .6, .58, 1.0)
				m.roughness = minf(1.0, m.roughness + .25)
				m.next_pass = _dust_pass()
				mats[key] = m
			mi.set_surface_override_material(s, mats[key])

## Weathered bark: the downloaded trees are far too pale for a moonlit night.
func _tint(node: Node, c: Color) -> void:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s) as BaseMaterial3D
			if m != null:
				m = m.duplicate() as BaseMaterial3D
				m.albedo_color = c
				m.next_pass = null
				mi.set_surface_override_material(s, m)

var _dust: ShaderMaterial
func _dust_pass() -> ShaderMaterial:
	if _dust == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
varying vec3 wpos;
varying vec3 wn;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment() {
	float up = smoothstep(.35, .85, wn.y);
	float n = texture(noise_tex, wpos.xz * .9).r * .6 + texture(noise_tex, wpos.xz * 3.7).r * .4;
	ALBEDO = vec3(.42, .4, .37) * (.8 + .4 * n);
	ROUGHNESS = 1.0;
	ALPHA = clamp(up * (.35 + .6 * n) + .08, 0.0, .85);
}"""
		_dust = ShaderMaterial.new()
		_dust.shader = sh
		_dust.set_shader_parameter("noise_tex", noise_tex)
	return _dust

func _furnish() -> void:
	# Foyer: the chandelier hangs crooked on its chain; luggage left by the door; a wheelchair in the dark under the landing.
	_chandelier = _model("chandelier_01", local(0, 5.6, 5.9), 12.0, 1.4, false, Vector3(4, 0, -3))
	if _chandelier != null:
		b._rod(local(0, 5.6, 8.0), local(0, 5.6, 5.9 + 1.1), .012, "iron", 5)
	_model("vintage_suitcase", local(-2.2, .9), 70.0, .7, true)
	_model("wheelchair_01", local(-2.0, 8.7), 160.0)
	# (0.22: the console stood across the dining room's open pocket doorway; it now stands in the rear hall.)
	_model("classicconsole_01", local(1.8, 11.4), 0.0)
	_model("antique_ceramic_vase_01", local(1.3, 11.4, .96), 0.0, 1.0, false)
	# Parlour: a sitting room round the fireplace, the piano at the back, a rocking chair at the window.
	_sheet("sheet_sofa", local(-9.2, 5.5), -90.0)
	_model("armchair_01", local(-10.9, 3.6), -125.0)
	_sheet("sheet_armchair", local(-10.9, 7.6), -60.0)
	_model("gothic_coffee_table", local(-10.4, 5.5), 0.0, .7)
	_model("dusty_piano", local(-11.3, 9.9), 180.0)
	_rocking = _model("rockingchair_01", local(-6.8, 1.5), 170.0)
	_model("ornate_mirror_01", local(-12.12, 5.5, 1.7), 90.0, 1.3, false)
	_model("mantel_clock_01", local(-12.0, 5.5, 1.36), 90.0, 1.0, false)
	_model("candelabra", local(-12.0, 4.85, 1.36), 0.0, 1.0, false)
	# The other one has fallen off the mantel onto the floor boards.
	_model("candelabra", local(-11.3, 4.15, .01), 35.0, 1.0, false, Vector3(0, 0, 88))
	_model("spinning_wheel_01", local(-5.0, 9.8), 220.0)
	_model("fancy_picture_frame_02", local(-4.15, 7.2, 1.7), -90.0, 1.2, false)
	# Dining room: the chandelier has come down onto the table; chairs pushed back, two on the floor.
	_model("dining_table", local(8.4, 5.6), 90.0)
	_model("chandelier_02", local(8.6, 5.3, .88), 0.0, 1.2, false, Vector3(24, 30, 52))
	b._rod(local(8.4, 5.6, C0()), local(8.4, 5.6, C0() - .8), .01, "iron", 5)
	for k in 3:
		_model("dining_chair_02", local(7.2, 4.6 + k * 1.0), 90.0 + rng.randf_range(-15, 15))
		_model("dining_chair_02", local(9.6, 4.6 + k * 1.0), -90.0 + rng.randf_range(-15, 15))
	_model("dining_chair_02", local(8.4, 7.9), 180.0, 1.0, true, Vector3(88, 0, 0))
	_model("tea_set_01", local(8.3, 5.0, .89), 10.0, .8, false)
	_model("wine_bottles_01", local(8.6, 6.6, .88), 80.0, .8, false)
	_model("vintage_cabinet_01", local(12.3, 5.6), -90.0)
	_model("gothiccommode_01", local(8.4, 10.6), 180.0)
	# Rear hall: the clock stopped long ago; a doll sits under the moonlit end window.
	_model("vintage_grandfather_clock_01", local(-2.6, 13.1), 180.0)
	_model("porcelain_doll", local(-12.2, 12.2), 90.0)
	_model("hanging_picture_frame_01", local(2.0, 13.32, 1.6), 180.0, 1.0, false, Vector3(0, 0, 6))
	# (0.22: this frame hung in mid-air inside the parlour doorway.)
	_model("hanging_picture_frame_02", local(-10.2, 11.09, 1.7), 0.0, 1.0, false)
	# Library.
	# Bookcases line the solid east wall and stand between the west windows (0.22: they used to cover them).
	for k in 3:
		_model("wooden_bookshelf_worn", local(-4.4, 14.25 + k * 1.45), -90.0)
	_model("wooden_bookshelf_worn", local(-12.38, 14.25), 90.0)
	_model("wooden_bookshelf_worn", local(-12.38, 16.9), 90.0)
	_model("round_wooden_table_01", local(-8.0, 16.6), 0.0, .8)
	_model("chess_set", local(-8.0, 16.6, .81), 15.0, 1.0, false)
	_sheet("sheet_armchair", local(-9.2, 17.8), 140.0)
	_sheet("sheet_table", local(-5.4, 14.6), 90.0)
	_model("woodenchair_01", local(-7.0, 15.8), -40.0, .6)
	_model("lantern_01", local(-7.6, 16.3, .81), 0.0, 1.0, false)
	# Kitchen and pantry.
	_model("wooden_crate_02", local(11.8, 19.0), 10.0)
	_model("wooden_crate_02", local(-2.8, 19.0), -5.0)
	_model("wine_bottles_01", local(2.6, 19.4, .0), 180.0, 1.0, false)
	# Upstairs corridor: a console, frames hung crooked.
	_model("classicconsole_01", local(-5.5, 2.0, F1()), 180.0)
	_model("vintage_oil_lamp", local(-5.3, 2.0, F1() + .96), 0.0, 1.0, false)
	_model("hanging_picture_frame_03", local(-10.0, 2.32, F1() + 1.6), 180.0, 1.1, false, Vector3(0, 0, -9))
	_model("hanging_picture_frame_02", local(10.0, 2.32, F1() + 1.7), 180.0, 1.0, false)
	_model("greenchair_01", local(-12.2, 1.3, F1()), -90.0)
	_model("dining_chair_02", local(-10.6, 1.5, F1()), 30.0, 1.0, false, Vector3(90, 0, 0))
	_model("hanging_picture_frame_01", local(-7.6, 1.9, F1()), 0.0, 1.0, false, Vector3(-86, 0, 0))
	# Master bedroom.
	_model("gothicbed_01", local(-8.4, 9.86, F1()), 180.0)
	_model("classicnightstand_01", local(-10.0, 10.7, F1()), 180.0)
	_model("classicnightstand_01", local(-6.8, 10.7, F1()), 180.0)
	_sheet("sheet_tall", local(-12.25, 10.2, F1()), 90.0)
	_model("gothiccommode_01", local(-4.4, 6.0, F1()), -90.0)
	_model("ornate_mirror_01", local(-4.12, 6.0, F1() + 1.75), -90.0, 1.2, false)
	_model("vintage_suitcase", local(-6.0, 4.0, F1()), 30.0, .7)
	_model("standing_picture_frame_01", local(-12.0, 5.2, F1() + 1.36), 90.0, 1.0, false)
	_model("wooden_candlestick", local(-12.0, 6.0, F1() + 1.36), 0.0, 1.0, false)
	# Nursery: an iron cot, a rocking horse, a doll on a chair facing the door.
	_model("old_bed_frame", local(11.7, 6.0, F1()), 0.0)
	_model("rocking_horse", local(7.0, 7.0, F1()), 40.0)
	_model("antique_doll", local(11.7, 6.5, F1() + .56), 20.0, 1.0, false, Vector3(0, 0, 80))
	_model("dining_chair_02", local(8.5, 5.2, F1()), 180.0)
	_model("porcelain_doll", local(8.5, 5.25, F1() + .47), 180.0, .9, false)
	_model("treasure_chest", local(11.6, 10.4, F1()), 180.0, .8)
	_model("coffeetable_01", local(6.5, 9.5, F1()), 15.0, .6)
	# Leftovers of a life: crutches against the hall wall, vases, a footstool, a drawer pulled out and dropped.
	_model("vintage_crutches_01", local(4.6, 13.2), 180.0, 1.0, false, Vector3(-14, 0, 0))
	_model("ceramic_vase_02", local(-9.9, 9.0, .02), 30.0, 1.0, false, Vector3(90, 0, 0))
	_model("ceramic_vase_04", local(-4.95, 2.0, F1() + .96), 0.0, 1.0, false)
	_model("brass_candleholders", local(8.4, 10.6, 1.22), 180.0, .8, false)
	_model("ottoman_01", local(-8.0, 3.4), 20.0, .9)
	_model("vintage_wooden_drawer_01", local(-11.6, 6.2, F1()), 75.0, 1.0, true, Vector3(0, 0, 0))
	_model("gothiccabinet_01", local(4.6, 9.4), 90.0, .85)
	_model("sofa_01", local(-10.6, 18.9), 180.0)
	_model("horse_statue_01", local(2.2, 11.4, .96), 30.0, 1.4, false)
	_webs()
	_rubble()

## A dust sheet thrown over a piece of furniture (shapes from tools/blender/nichols/nichols_cloth.py).
func _sheet(name_: String, p: Vector3, yaw: float) -> void:
	var path := HOUSE_DIR + "house_" + name_ + ".glb"
	if not ResourceLoader.exists(path):
		return
	var node := (load(path) as PackedScene).instantiate() as Node3D
	house.add_child(node)
	node.position = house.to_local(p)
	node.rotation.y = deg_to_rad(yaw)
	_bind(node, INTERIOR_LAYER)
	_physical(node, name_, false, true)
	stats.models += 1

func C0() -> float: return 4.0
func F1() -> float: return 4.4

## Plaster, laths and boards fallen from the parlour ceiling.
func _rubble() -> void:
	# Inside debris lives on the inside layer (lit by the moon through the windows, not by the sky fill).
	var ib := InteriorBalconyBuilder.new()
	ib._stats = {"triangles_added": 0, "static_batches": 0, "colliders": 0}
	ib._materials = b._materials
	ib.visual_layer = INTERIOR_LAYER
	if not ib._materials.has("paper"):
		# _plate builds both faces of a sheet: culling stays on (two-sided faces would z-fight and show black).
		ib._materials["paper"] = _flat("paper", Color(.42, .39, .32), .95)
		ib._materials["dead leaf"] = _flat("dead leaf", Color(.16, .11, .07), .9)
	var c := HOUSE_POS + _v(layout.spots.parlour_rubble)
	for i in 70:
		var p := c + Vector3(rng.randf_range(-1.4, 1.4), 0, rng.randf_range(-1.2, 1.2))
		var sz := Vector3(rng.randf_range(.08, .4), rng.randf_range(.015, .05), rng.randf_range(.06, .3))
		var basis := Basis.from_euler(Vector3(rng.randf_range(-.4, .4), rng.randf() * TAU, rng.randf_range(-.4, .4)))
		ib._box("Plaster chunk", p + Vector3.UP * (sz.y * .5 + rng.randf() * .06), sz, "plaster", false, basis)
	for i in 14:
		var p := c + Vector3(rng.randf_range(-1.3, 1.3), .05, rng.randf_range(-1.1, 1.1))
		var basis := Basis.from_euler(Vector3(rng.randf_range(-.3, .3), rng.randf() * TAU, rng.randf_range(-.2, .2)))
		ib._box("Lath", p, Vector3(rng.randf_range(.5, 1.2), .008, .035), "lath", false, basis)
	# Every room: plaster fallen along the skirting, old papers, and leaves blown in under the broken windows.
	for room: Dictionary in layout.get("rooms", []):
		if str(room.name) in ["sealed", "closet"]:
			continue
		var r: Array = room.rects[0]
		var a := HOUSE_POS + _v(r[0])
		var e := HOUSE_POS + _v(r[1])
		var lo := Vector3(minf(a.x, e.x), a.y, minf(a.z, e.z))
		var hi := Vector3(maxf(a.x, e.x), a.y, maxf(a.z, e.z))
		var area := (hi.x - lo.x) * (hi.z - lo.z)
		for i in int(area * 1.2):
			var side := rng.randi() % 4
			var t := rng.randf()
			var p := Vector3(lerpf(lo.x, hi.x, t), lo.y, lo.z + rng.randf_range(.05, .5)) if side == 0 else (
				Vector3(lerpf(lo.x, hi.x, t), lo.y, hi.z - rng.randf_range(.05, .5)) if side == 1 else (
				Vector3(lo.x + rng.randf_range(.05, .5), lo.y, lerpf(lo.z, hi.z, t)) if side == 2 else
				Vector3(hi.x - rng.randf_range(.05, .5), lo.y, lerpf(lo.z, hi.z, t))))
			var sz := Vector3(rng.randf_range(.04, .2), rng.randf_range(.01, .035), rng.randf_range(.03, .15))
			ib._box("Fallen plaster", p + Vector3.UP * sz.y * .5, sz, "plaster", false, Basis(Vector3.UP, rng.randf() * TAU))
		for i in int(area * .25):
			var p := Vector3(rng.randf_range(lo.x + .4, hi.x - .4), lo.y + .004, rng.randf_range(lo.z + .4, hi.z - .4))
			var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-.08, .08))
			var w := rng.randf_range(.18, .3)
			var d := w * 1.35
			# One face, wound like a box top (the builder's _quad has a fixed winding; reversed corners faced down).
			ib._quad([p + basis * Vector3(-w * .5, .02, d * .5), p + basis * Vector3(w * .5, .01, d * .5), p + basis * Vector3(w * .5, 0, -d * .5), p + basis * Vector3(-w * .5, 0, -d * .5)], basis * Vector3.UP, "paper")
	for w: Dictionary in layout.get("windows", []):
		if w.blind or str(w.room) in ["sealed", ""]:
			continue
		var base := HOUSE_POS + _v(w.inner)
		var floor_y := HOUSE_POS.y + (4.4 if base.y - HOUSE_POS.y > 3.0 else 0.0)
		var n := _v(w.normal)
		var along := _v(w.along)
		for i in 26:
			var p := Vector3(base.x, floor_y + .006, base.z) - n * rng.randf_range(.1, 1.8) + along * rng.randf_range(-1.0, 1.0)
			var basis := Basis(Vector3.UP, rng.randf() * TAU)
			var l := rng.randf_range(.04, .08)
			ib._quad([p + basis * Vector3(0, 0, l * .45), p + basis * Vector3(l, .01, 0), p + basis * Vector3(0, .004, -l * .45), p + basis * Vector3(-l, 0, 0)], Vector3.UP, "dead leaf")
	var node := Node3D.new()
	node.name = "House debris"
	add_child(node)
	ib._commit(node, "Debris - ")
	for child in node.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).layers = INTERIOR_LAYER
	ib.free()

## Cobwebs across the upper corners of every room and over the stair.
func _webs() -> void:
	var image := Image.create(256, 256, true, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var centre := Vector2(4, 4)
	var spokes := 11
	for k in spokes:
		var a := PI * .5 * (k + .3 * sin(k * 7.0)) / (spokes - 1)
		for t in 360:
			var p := centre + Vector2(cos(a), sin(a)) * t * .7
			if p.x < 255 and p.y < 255 and p.x >= 0 and p.y >= 0:
				image.set_pixelv(Vector2i(p), Color(.85, .85, .82, .75))
	for ring in range(10, 250, 9):
		var r := float(ring) + sin(ring) * 3.0
		for k in 300:
			var a := PI * .5 * k / 299.0
			var sag := 1.0 - .08 * sin(a * spokes * 2.0)
			var p := centre + Vector2(cos(a), sin(a)) * r * sag
			if p.x < 255 and p.y < 255 and p.x >= 0 and p.y >= 0:
				image.set_pixelv(Vector2i(p), Color(.8, .8, .78, .55))
	image.generate_mipmaps()
	var web := StandardMaterial3D.new()
	web.albedo_texture = ImageTexture.create_from_image(image)
	web.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	web.cull_mode = BaseMaterial3D.CULL_DISABLED
	web.roughness = .6
	web.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mats["web"] = web
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for room: Dictionary in layout.get("rooms", []):
		if str(room.name) in ["closet", "sealed", "gallery_w", "gallery_e"]:
			continue
		var r: Array = room.rects[0]
		var a := _v(r[0])
		var c := _v(r[1])
		var lo := Vector3(minf(a.x, c.x), 0, minf(a.z, c.z))
		var hi := Vector3(maxf(a.x, c.x), 0, maxf(a.z, c.z))
		var top := float(room.ceiling) - .02
		for corner: Vector3 in [Vector3(lo.x, top, lo.z), Vector3(hi.x, top, lo.z), Vector3(lo.x, top, hi.z), Vector3(hi.x, top, hi.z)]:
			if rng.randf() < .3:
				continue
			var sx := 1.0 if corner.x == lo.x else -1.0
			var sz := 1.0 if corner.z == lo.z else -1.0
			var size := rng.randf_range(.5, 1.1)
			var p0 := HOUSE_POS + corner + Vector3(.15 * sx, -.05, .15 * sz)
			var px := p0 + Vector3(sx * size, 0, 0)
			var pz := p0 + Vector3(0, 0, sz * size)
			var pd := p0 + Vector3(0, -size * .9, 0)
			# Two sheets: one across the ceiling corner, one sagging down the wall corner.
			for tri: Array in [[p0, px, pz], [p0, px + Vector3(0, -size * .4, 0), pd]]:
				var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)]
				for k in 3:
					st.set_uv(uvs[k])
					st.set_normal(Vector3.DOWN)
					st.add_vertex(tri[k])
			stats.webs += 1
	var mi := MeshInstance3D.new()
	mi.name = "Cobwebs"
	mi.mesh = st.commit()
	mi.material_override = web
	mi.layers = INTERIOR_LAYER
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

# ------------------------------------------------------------------------------------------------ street, terrain, bounds

func _open_street(town: Node3D) -> void:
	# Street B's south barricade: the middle sawhorses were dragged aside, like the north end.
	var colliders := town.get_node_or_null("NeighbourhoodColliders")
	if colliders != null:
		for child in colliders.get_children():
			if not child is CollisionShape3D:
				continue
			var n := str(child.name)
			var p: Vector3 = child.position
			if n.begins_with("Barricade") and absf(p.z + 17.1) < .6 and p.x > 19.6 and p.x < 22.4:
				child.disabled = true
			if n.begins_with("Bound edge south"):
				child.disabled = true
	for child in town.get_children():
		if not child is MeshInstance3D or not "sd stripe" in str(child.name):
			continue
		var mi := child as MeshInstance3D
		var replacement := ArrayMesh.new()
		for s in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var kept := PackedInt32Array()
			for j in range(0, indices.size(), 3):
				var center: Vector3 = (verts[indices[j]] + verts[indices[j + 1]] + verts[indices[j + 2]]) / 3
				if center.x > 19.5 and center.x < 22.5 and absf(center.z + 17.1) < .7: continue
				for k in 3: kept.append(indices[j + k])
			if not kept.is_empty():
				arrays[Mesh.ARRAY_INDEX] = kept
				replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				replacement.surface_set_material(replacement.get_surface_count() - 1, mi.get_active_material(s))
		mi.mesh = replacement
	# The two sawhorses, dragged to the kerb, one on its side.
	_flat("stripe yellow", Color(.55, .45, .08), .7)
	_flat("stripe black", Color(.03, .03, .03), .7)
	b._materials["stripe yellow"] = mats["stripe yellow"]
	b._materials["stripe black"] = mats["stripe black"]
	_sawhorse(Vector3(18.6, GROUND, -16.2), Basis(Vector3.UP, .5))
	_sawhorse(Vector3(23.5, GROUND + .3, -17.8), Basis(Vector3.UP, -.3) * Basis(Vector3.FORWARD, 1.45))

func _sawhorse(at: Vector3, basis: Basis) -> void:
	for side: float in [-1.0, 1.0]:
		for d: float in [-.28, .28]:
			b._rod(at + basis * Vector3(side * .57, 0, d), at + basis * Vector3(side * .57, .95, 0), .025, "stripe black", 6)
	for y: float in [.88, .55]:
		for s in 6:
			b._box("Sawhorse stripe", at + basis * Vector3(-.675 + (s + .5) * .225, y, 0), Vector3(.225, .16, .025), "stripe yellow" if s % 2 == 0 else "stripe black", false, basis)

func _path_dist(p: Vector2) -> float:
	var best := 1e9
	for i in PATH.size() - 1:
		var a: Vector2 = PATH[i]
		var c: Vector2 = PATH[i + 1]
		var t := clampf((p - a).dot(c - a) / (c - a).length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + (c - a) * t))
	return best

func _drive_dist(p: Vector2) -> float:
	# Gravel: gate to fountain, a ring round the fountain, fountain to the porch steps, and the forecourt.
	var fountain := Vector2(GATE.x, -68.5)
	var d := absf(p.distance_to(fountain) - 4.6) - 1.4
	if absf(p.x - GATE.x) < 2.2 and p.y < GATE.z and p.y > -64.0: d = minf(d, 0.0)
	if absf(p.x - GATE.x) < 2.4 and p.y < -72.0 and p.y > -79.0: d = minf(d, 0.0)
	if absf(p.x - GATE.x) < 15.0 and p.y < -77.2 and p.y > -79.6: d = minf(d, 0.0)
	return d

func _terrain() -> void:
	# A mask for the ground shader (4 px per metre): R path, G gravel, B leaf litter.
	var w := int(REGION.size.x * 4)
	var h := int(REGION.size.y * 4)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var fn := FastNoiseLite.new()
	fn.seed = 77
	fn.frequency = .08
	for y in h:
		for x in w:
			var p := REGION.position + Vector2(x + .5, y + .5) / 4.0
			var pd := _path_dist(p)
			var path := 1.0 - smoothstep(.8, 1.6, pd + fn.get_noise_2dv(p) * .4)
			var ruts := (1.0 - smoothstep(.0, .25, absf(pd - .55))) * .15
			var drive := 1.0 - smoothstep(0.0, .6, _drive_dist(p) + fn.get_noise_2dv(p * 1.7) * .5) if ESTATE.has_point(p) else 0.0
			var litter := clampf(.5 + fn.get_noise_2dv(p * .4) * .9, 0.0, 1.0) * (1.0 if ESTATE.has_point(p) else .4)
			img.set_pixel(x, y, Color(clampf(path - ruts, 0, 1), drive, litter * .6, 1))
	var mask := ImageTexture.create_from_image(img)
	var m := ShaderMaterial.new()
	m.shader = GROUND_SHADER
	m.set_shader_parameter("grass_tex", _tex("withered_grass", "albedo"))
	m.set_shader_parameter("grass_normal", _tex("withered_grass", "normal"))
	m.set_shader_parameter("leaves_tex", _tex("forest_leaves_02", "albedo"))
	m.set_shader_parameter("leaves_normal", _tex("forest_leaves_02", "normal"))
	m.set_shader_parameter("dirt_tex", _tex("stony_dirt_path", "albedo"))
	m.set_shader_parameter("dirt_normal", _tex("stony_dirt_path", "normal"))
	m.set_shader_parameter("gravel_tex", _tex("gravel_road", "albedo"))
	m.set_shader_parameter("mask_tex", mask)
	m.set_shader_parameter("noise_tex", noise_tex)
	m.set_shader_parameter("mask_rect", Vector4(REGION.position.x, REGION.position.y, REGION.size.x, REGION.size.y))
	mats["ground"] = m
	# Mesh: 1 m grid lying 2-4 cm above the town's grass, sunk below it along street B's asphalt.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := int(REGION.size.x)
	var nz := int(REGION.size.y)
	var hn := FastNoiseLite.new()
	hn.seed = 9
	hn.frequency = .15
	var height := func(x: float, z: float) -> float:
		if x > 17.4 and x < 24.6 and z > -40.5:
			return GROUND - .3
		return GROUND + .035 + hn.get_noise_2d(x, z) * .02
	for iz in nz:
		for ix in nx:
			var x0 := REGION.position.x + ix
			var z0 := REGION.position.y + iz
			# 0.22: the cellar lies under the house: no ground inside its outer walls.
			if x0 + .5 > HOUSE_POS.x - 12.7 and x0 + .5 < HOUSE_POS.x + 12.7 and z0 + .5 < HOUSE_POS.z - .3 and z0 + .5 > HOUSE_POS.z - 19.7:
				continue
			var q := [Vector3(x0, height.call(x0, z0), z0), Vector3(x0 + 1, height.call(x0 + 1, z0), z0),
				Vector3(x0 + 1, height.call(x0 + 1, z0 + 1), z0 + 1), Vector3(x0, height.call(x0, z0 + 1), z0 + 1)]
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_normal(Vector3.UP)
				st.add_vertex(q[k])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Nichols ground"
	mi.mesh = st.commit()
	mi.material_override = m
	mi.layers = OUTDOOR_LAYER
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# The town ground ends at z -110; carry the walking surface on to the back of the estate.
	_solid("Ground south", Vector3(-10, GROUND - .25, -120.5), Vector3(72, .5, 21), "grass")

func _solid(label: String, p: Vector3, size: Vector3, surface := "grass", basis := Basis.IDENTITY) -> CollisionShape3D:
	var c := CollisionShape3D.new()
	c.name = label.validate_node_name()
	var shape := BoxShape3D.new()
	shape.size = size
	shape.margin = .002
	c.shape = shape
	c.transform = Transform3D(basis, p)
	c.set_meta("surface", surface)
	solids.add_child(c, true)
	stats.colliders += 1
	return c

func _bounds() -> void:
	var y := GROUND + 6.0
	var r := REGION
	_solid("Bound south region west", Vector3(r.position.x - .5, y, r.get_center().y), Vector3(1, 12, r.size.y), "concrete")
	_solid("Bound south region east", Vector3(r.end.x + .5, y, r.get_center().y), Vector3(1, 12, r.size.y), "concrete")
	_solid("Bound south region back", Vector3(r.get_center().x, y, r.position.y - .5), Vector3(r.size.x, 12, 1), "concrete")
	# North edge, leaving street B open (the town's "Bound edge south" is off).
	_solid("Bound south region north west", Vector3((r.position.x + 17.56) * .5, y, -18.5), Vector3(17.56 - r.position.x, 12, 1), "concrete")
	_solid("Bound south region north east", Vector3((24.44 + r.end.x) * .5, y, -18.5), Vector3(r.end.x - 24.44, 12, 1), "concrete")
	# Lots east of street B down to z -30: keep the player on the road there.
	_solid("Bound street B east", Vector3(24.9, y, -24.0), Vector3(.6, 12, 12.0), "concrete")

# ------------------------------------------------------------------------------------------------ estate: gate, walls, drive

func _estate() -> void:
	var gz := GATE.z
	# Gate pillars: rendered stone with a moulded cap, a ball-and-urn finial and a dead lantern on a bracket.
	for sx: float in [-1.0, 1.0]:
		var p := Vector3(GATE.x + sx * (GATE_HALF + .5), GROUND, gz)
		b._box("Pillar plinth", p + Vector3.UP * .35, Vector3(1.25, .7, 1.25), "cap stone")
		b._box("Pillar", p + Vector3.UP * 2.1, Vector3(1.0, 2.8, 1.0), "wall stone")
		for k in 4:
			b._box("Pillar rustication", p + Vector3.UP * (1.0 + k * .7), Vector3(1.04, .04, 1.04), "cap stone")
		b._box("Pillar cap", p + Vector3.UP * 3.6, Vector3(1.3, .2, 1.3), "cap stone")
		b._box("Pillar cap top", p + Vector3.UP * 3.78, Vector3(1.1, .16, 1.1), "cap stone")
		b._lathe(p + Vector3.UP * 3.86, [Vector2(.3, 0), Vector2(.32, .06), Vector2(.18, .14), Vector2(.22, .22), Vector2(.4, .42), Vector2(.42, .58),
			Vector2(.3, .72), Vector2(.12, .78), Vector2(.18, .86), Vector2(.0, .9)], "cap stone", 18)
		_solid("Gate pillar", p + Vector3.UP * 2.0, Vector3(1.25, 4.0, 1.25), "concrete")
		# Brass plaque.
		var plate := p + Vector3(0, 1.75, .51)
		b._box("Plaque", plate, Vector3(.5, .34, .03), "brass")
		if sx < 0:
			var label := Label3D.new()
			label.text = "NICHOLS\n1906"
			label.font_size = 64
			label.pixel_size = .0016
			label.modulate = Color(.12, .1, .06)
			label.outline_size = 0
			label.position = plate + Vector3(0, 0, .02)
			label.layers = OUTDOOR_LAYER
			label.shaded = true
			label.double_sided = false
			add_child(label)
		# Lantern on a scroll bracket (unlit for many years).
		var lp := p + Vector3(-sx * .0, 2.9, .5)
		b._rod(lp, lp + Vector3(0, 0, .35), .02, "iron", 6)
		b._rod(lp + Vector3(0, .35, .35), lp + Vector3(0, -.1, .35), .012, "iron", 5)
		b._box("Lantern roof", lp + Vector3(0, .02, .4), Vector3(.26, .05, .26), "iron")
		for cx: float in [-.1, .1]:
			for cz: float in [-.1, .1]:
				b._rod(lp + Vector3(cx, -.4, .4 + cz), lp + Vector3(cx, 0, .4 + cz), .006, "iron", 4)
		b._box("Lantern glass", lp + Vector3(0, -.2, .4), Vector3(.19, .36, .19), "glass grime")
		# Curved wing wall sweeping down from the pillar to the boundary wall (the owner's gate reference):
		# continuous faces under a smooth concave top.
		var x0 := p.x + sx * .5
		var tops: Array[Vector2] = []
		for i in 31:
			var t := i / 30.0
			tops.append(Vector2(x0 + sx * t * 2.4, lerpf(3.3, 1.05, sin(t * PI * .5)) + .15 * sin(t * PI)))
		for i in 30:
			var a2: Vector2 = tops[i]
			var c2: Vector2 = tops[i + 1]
			for zz: float in [-.25, .25]:
				var n := Vector3(0, 0, signf(zz))
				var quad := [Vector3(a2.x, GROUND, gz + zz), Vector3(c2.x, GROUND, gz + zz), Vector3(c2.x, GROUND + c2.y, gz + zz), Vector3(a2.x, GROUND + a2.y, gz + zz)]
				if (zz > 0.0) != (sx > 0.0):
					b._quad([quad[1], quad[0], quad[3], quad[2]], n, "plaster ext", Vector2(absf(c2.x - a2.x), maxf(a2.y, c2.y)))
				else:
					b._quad(quad, n, "plaster ext", Vector2(absf(c2.x - a2.x), maxf(a2.y, c2.y)))
			var top_quad := [Vector3(a2.x, GROUND + a2.y, gz - .28), Vector3(c2.x, GROUND + c2.y, gz - .28), Vector3(c2.x, GROUND + c2.y, gz + .28), Vector3(a2.x, GROUND + a2.y, gz + .28)]
			var tn := Vector3(-(c2.y - a2.y), absf(c2.x - a2.x), 0).normalized()
			if sx > 0.0:
				b._quad([top_quad[1], top_quad[0], top_quad[3], top_quad[2]], tn, "cap stone", Vector2(.56, absf(c2.x - a2.x)))
			else:
				b._quad(top_quad, Vector3(-tn.x, tn.y, 0), "cap stone", Vector2(.56, absf(c2.x - a2.x)))
		_solid("Wing wall", Vector3(x0 + sx * 1.2, GROUND + 1.5, gz), Vector3(2.4, 3.0, .5), "concrete")
	# The gate: two tall wrought-iron leaves, both standing open; the left one sags off its lower hinge.
	var leaf_scale := Vector3(1.0, 1.0, 1.0)
	for spec in [[-1.0, 78.0, Vector3(0, 0, 4)], [1.0, -36.0, Vector3(0, 0, 0)]]:
		var sx: float = spec[0]
		var hinge := Vector3(GATE.x + sx * GATE_HALF, GROUND, gz)
		var pivot := Node3D.new()
		pivot.name = "Gate leaf"
		add_child(pivot)
		pivot.position = hinge
		pivot.rotation_degrees = Vector3(0, spec[1], 0) + spec[2]
		var leaf := InteriorModelKit.place(pivot, DIR + "nh_large_iron_gate.glb", Vector3(-sx * 1.475, 0, 0), 0.0, 1.0, "bottom")
		InteriorModelKit.prepare_instance(leaf, OUTDOOR_LAYER, 0.0, true, false)
		_age(leaf)
		var c := _solid("Gate leaf", Vector3.ZERO, Vector3(2.95, 2.9, .12), "metal")
		c.global_transform = pivot.global_transform * Transform3D(Basis.IDENTITY, Vector3(-sx * 1.475, 1.45, 0))
	# A chain hangs from the right leaf, its padlock snapped open in the weeds.
	# Boundary: a rendered wall with iron railings on top, both ways from the wing walls to the corners.
	for seg: Array in [[ESTATE.position.x, GATE.x - GATE_HALF - 3.4], [GATE.x + GATE_HALF + 3.4, ESTATE.end.x]]:
		_railing_wall(Vector3(seg[0], GROUND, gz), Vector3(seg[1], GROUND, gz))
	_railing_wall(Vector3(ESTATE.position.x, GROUND, gz), Vector3(ESTATE.position.x, GROUND, ESTATE.position.y))
	_railing_wall(Vector3(ESTATE.end.x, GROUND, gz), Vector3(ESTATE.end.x, GROUND, ESTATE.position.y))
	_railing_wall(Vector3(ESTATE.position.x, GROUND, ESTATE.position.y), Vector3(ESTATE.end.x, GROUND, ESTATE.position.y))
	_fountain(Vector3(GATE.x, GROUND, -68.5))
	# Ground mist over the grounds (volumetric, desktop High and Ultra): faint, lying in the grass, in four boxes
	# round the house so none of it drifts indoors.
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		var mm := FogMaterial.new()
		mm.density = .014
		mm.height_falloff = 1.6
		mm.edge_fade = .35
		mm.albedo = Color(.78, .82, .9)
		var hx0 := HOUSE_POS.x - 13.8
		var hx1 := HOUSE_POS.x + 13.8
		var hz0 := HOUSE_POS.z - 20.8
		var hz1 := HOUSE_POS.z + 6.0
		for r: Rect2 in [Rect2(ESTATE.position.x, hz1, ESTATE.size.x, ESTATE.end.y - hz1), Rect2(ESTATE.position.x, ESTATE.position.y, ESTATE.size.x, hz0 - ESTATE.position.y),
				Rect2(ESTATE.position.x, hz0, hx0 - ESTATE.position.x, hz1 - hz0), Rect2(hx1, hz0, ESTATE.end.x - hx1, hz1 - hz0)]:
			var mist := FogVolume.new()
			mist.name = "Estate mist"
			mist.size = Vector3(r.size.x, 2.4, r.size.y)
			mist.position = Vector3(r.get_center().x, GROUND + 1.0, r.get_center().y)
			mist.material = mm
			add_child(mist)
	

func _railing_wall(a: Vector3, c: Vector3) -> void:
	var d := c - a
	var length := d.length()
	var dir := d / length
	var basis := Basis(dir, Vector3.UP, dir.cross(Vector3.UP))
	var mid := (a + c) * .5
	b._box("Boundary wall", mid + Vector3.UP * .45, Vector3(length, .9, .42), "plaster ext", false, basis)
	b._box("Boundary coping", mid + Vector3.UP * .95, Vector3(length + .1, .1, .52), "cap stone", false, basis)
	_solid("Boundary", mid + Vector3.UP * 2.0, Vector3(length, 4.0, .5), "concrete", basis)
	# Piers every ~4 m, railings between them; some pickets bent, a few gone.
	var piers := maxi(1, int(length / 4.2))
	for i in piers + 1:
		var p := a + dir * (length * i / piers)
		b._box("Pier", p + Vector3.UP * 1.1, Vector3(.55, 2.2, .55), "plaster ext", false, basis)
		b._box("Pier cap", p + Vector3.UP * 2.25, Vector3(.65, .1, .65), "cap stone", false, basis)
		b._lathe(p + Vector3.UP * 2.3, [Vector2(.12, 0), Vector2(.2, .1), Vector2(.16, .22), Vector2(0, .3)], "cap stone", 10)
	var x := .35
	while x < length - .2:
		var p := a + dir * x
		if fmod(x, length / piers) > .35 and fmod(x, length / piers) < length / piers - .35 and rng.randf() > .04:
			var lean := Vector3(rng.randf_range(-.04, .04), 0, rng.randf_range(-.04, .04)) if rng.randf() < .85 else dir.cross(Vector3.UP) * rng.randf_range(-.4, .4)
			var top := p + Vector3.UP * 2.2 + lean
			b._rod(p + Vector3.UP * 1.0, top, .011, "iron", 5)
			b._lathe(top, [Vector2(.03, 0), Vector2(0, .1)], "iron", 4)
		x += .14
	for hh: float in [1.15, 2.0]:
		b._rod(a + Vector3.UP * hh, c + Vector3.UP * hh, .014, "iron", 5)

func _fountain(c: Vector3) -> void:
	# A dry three-tier fountain: cracked basin full of dead leaves, a broken bowl, a weathered figure.
	b._lathe(c, [Vector2(3.0, 0), Vector2(3.0, .55), Vector2(3.15, .6), Vector2(3.15, .7), Vector2(2.75, .7), Vector2(2.75, .25), Vector2(0, .25)], "cap stone", 40)
	b._lathe(c + Vector3.UP * .25, [Vector2(.55, 0), Vector2(.4, .3), Vector2(.32, 1.0), Vector2(.5, 1.2), Vector2(1.3, 1.45), Vector2(1.35, 1.55),
		Vector2(1.2, 1.55), Vector2(.4, 1.35), Vector2(.25, 1.6), Vector2(.22, 2.0), Vector2(.0, 2.05)], "cap stone", 28)
	_solid("Fountain", c + Vector3.UP * .4, Vector3(5.8, .8, 5.8), "concrete")
	_solid("Fountain column", c + Vector3.UP * 1.2, Vector3(1.0, 2.4, 1.0), "concrete")
	_model("gothic_statue", c + Vector3.UP * 2.25, 180.0, .75, false, Vector3.ZERO, OUTDOOR_LAYER)
	for i in 40:
		var a := rng.randf() * TAU
		var r := rng.randf_range(.5, 2.6)
		b._box("Basin leaf", c + Vector3(cos(a) * r, .27, sin(a) * r), Vector3(.12, .01, .08), "board", false, Basis(Vector3.UP, rng.randf() * TAU))

# ------------------------------------------------------------------------------------------------ grounds

func _grounds() -> void:
	# Dead trees round the house and along the path; a gnarled leaning one by the gate.
	var spots := [["dead_tree_c", Vector3(-24.0, GROUND, -72.0), 30.0, 1.0], ["dead_tree_a", Vector3(4.5, GROUND, -70.0), 150.0, 1.1],
		["dead_tree_e", Vector3(-18.5, GROUND, -63.0), 200.0, .9], ["dead_tree_c", Vector3(6.0, GROUND, -98.0), 260.0, 1.25],
		["dead_tree_a", Vector3(-33.0, GROUND, -95.0), 80.0, 1.2], ["dead_tree_b", Vector3(-30.0, GROUND, -110.0), 10.0, 1.1],
		["dead_tree_c", Vector3(9.0, GROUND, -116.0), 120.0, 1.0], ["dead_tree_a", Vector3(-6.0, GROUND, -118.0), 300.0, 1.3],
		["dead_tree_e", Vector3(12.0, GROUND, -50.0), 40.0, 1.0], ["dead_tree_c", Vector3(-2.0, GROUND, -45.0), 170.0, .9],
		["dead_tree_a", Vector3(-30.0, GROUND, -50.0), 220.0, 1.0], ["dead_tree_b", Vector3(-38.0, GROUND, -66.0), 90.0, 1.2],
		["dead_tree_c", Vector3(22.0, GROUND, -60.0), 60.0, 1.1], ["dead_tree_a", Vector3(-42.0, GROUND, -125.0), 10.0, 1.4],
		["dead_tree_c", Vector3(20.0, GROUND, -126.0), 200.0, 1.3], ["dead_tree_b", Vector3(-20.0, GROUND, -127.0), 300.0, 1.5]]
	for s: Array in spots:
		var node := _model(s[0], s[1], s[2], s[3], false, Vector3.ZERO, OUTDOOR_LAYER)
		if node != null:
			_tint(node, Color(.32, .29, .27))
			_solid("Tree trunk", (s[1] as Vector3) + Vector3.UP * 1.5, Vector3(.6, 3.0, .6), "wood")
			stats.trees += 1
	# Stumps, roots, fallen wood and a garden statue lost in the grass.
	_model("tree_stump_02", Vector3(-26.0, GROUND, -84.0), 30.0, 1.0, true, Vector3.ZERO, OUTDOOR_LAYER)
	_model("root_cluster_02", Vector3(-27.0, GROUND, -86.0), 70.0, 1.0, false, Vector3.ZERO, OUTDOOR_LAYER)
	_model("bark_debris_01", Vector3(-10.0, GROUND, -66.0), 20.0, 1.0, false, Vector3.ZERO, OUTDOOR_LAYER)
	_model("dry_branches_medium_01", Vector3(-15.5, GROUND, -74.0), 80.0, 1.3, false, Vector3.ZERO, OUTDOOR_LAYER)
	_model("dry_branches_medium_01", Vector3(-5.0, GROUND, -60.8), 190.0, 1.0, false, Vector3.ZERO, OUTDOOR_LAYER)
	_model("marble_bust_01", Vector3(-22.0, GROUND + .9, -77.0), 120.0, 1.4, false, Vector3.ZERO, OUTDOOR_LAYER)
	b._box("Bust pedestal", Vector3(-22.0, GROUND + .45, -77.0), Vector3(.5, .9, .5), "cap stone")
	_model("lion_head", Vector3(-12.0 - GATE_HALF - .5, GROUND + .8, -59.4), 0.0, 1.0, false, Vector3.ZERO, OUTDOOR_LAYER)
	_model("concrete_cat_statue", Vector3(-1.5, GROUND, -78.5), 200.0, 1.6, false, Vector3.ZERO, OUTDOOR_LAYER)
	_model("dead_quiver_trunk", Vector3(-30.0, GROUND, -72.0), 40.0, 1.6, false, Vector3(84, 0, 0), OUTDOOR_LAYER)
	_model("pine_roots", Vector3(5.0, GROUND, -101.0), 120.0, 1.2, false, Vector3.ZERO, OUTDOOR_LAYER)
	_model("crow", local(-2.6, -3.3, 3.9), 120.0, 1.0, false, Vector3.ZERO, OUTDOOR_LAYER)
	_model("crow_b", Vector3(GATE.x + GATE_HALF + .5, GROUND + 4.75, GATE.z), 200.0, 1.0, false, Vector3.ZERO, OUTDOOR_LAYER)

## Dead grass and weeds, waist-high on the lawn, thinner in the field, kept off the path, drive and house.
func _overgrowth() -> void:
	var fb := InteriorFieldsBuilder.new()
	var meshes := {"tall": fb._blade_clump(16, 4, .034, .32, 41), "low": fb._blade_clump(15, 0, .028, .24, 42)}
	var store := {}
	var fn := FastNoiseLite.new()
	fn.seed = 5
	fn.frequency = .07
	var house := Rect2(HOUSE_POS.x - 13.6, HOUSE_POS.z - 20.6, 27.2, 26.2)
	var fountain := Vector2(GATE.x, -68.5)
	var z := REGION.position.y + .4
	while z < REGION.end.y - .4:
		var x := REGION.position.x + .4
		while x < REGION.end.x - .4:
			var p := Vector2(x + rng.randf_range(-.3, .3), z + rng.randf_range(-.3, .3))
			x += .48
			if p.x > 17.0 and p.y > -41.0:
				continue  # street B
			if house.has_point(p) or p.distance_to(fountain) < 3.4:
				continue
			var inside := ESTATE.has_point(p)
			var density := .55 + fn.get_noise_2dv(p) * .45 + (.25 if inside else -.15)
			if _path_dist(p) < 1.5 + fn.get_noise_2dv(p * 3.0) * .3:
				density -= .7
			if inside and _drive_dist(p) < .5:
				density -= .9
			if rng.randf() > density:
				continue
			var tall := inside or rng.randf() < .35
			var height := rng.randf_range(.65, 1.25) if tall else rng.randf_range(.3, .6)
			var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * height), Vector3(p.x, GROUND + .02, p.y))
			var key := "%s|%d|%d" % ["tall" if tall else "low", int(floorf(p.x / 16.0)), int(floorf(p.y / 16.0))]
			if not store.has(key):
				store[key] = [[], []]
			store[key][0].append(t)
			store[key][1].append(Color(rng.randf(), height, rng.randf() * 6.0, rng.randf_range(.55, 1.0)))
		z += .48
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/field_blades.gdshader")
	material.set_shader_parameter("root_color", Color(.04, .04, .028))
	material.set_shader_parameter("tip_color", Color(.2, .2, .13))
	material.set_shader_parameter("ripe_color", Color(.3, .27, .17))
	var count := 0
	for key: String in store:
		var parts := key.split("|")
		var transforms: Array = store[key][0]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = meshes[parts[0]]
		mm.instance_count = transforms.size()
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		for k in transforms.size():
			var t: Transform3D = transforms[k]
			mm.set_instance_transform(k, t)
			mm.set_instance_custom_data(k, store[key][1][k])
			lo = lo.min(t.origin)
			hi = hi.max(t.origin)
		var node := MultiMeshInstance3D.new()
		node.name = "Dead grass %s %s" % [parts[1], parts[2]]
		node.multimesh = mm
		node.material_override = material
		node.layers = OUTDOOR_LAYER
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = 45.0
		node.visibility_range_end_margin = 8.0
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		node.custom_aabb = AABB(lo - Vector3(1, .2, 1), hi - lo + Vector3(2, 1.8, 2))
		add_child(node)
		count += transforms.size()
	stats["grass"] = count

# ------------------------------------------------------------------------------------------------ runtime

## Inside, the haze is lit by the moonbeams alone: the sky's ambient glow would fill the rooms with mist.
func _fog_inside(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	_inside = lerpf(_inside, 1.0 if is_inside(cam.global_position) else 0.0, 1.0 - exp(-3.0 * delta))
	var env := get_viewport().world_3d.environment if get_viewport().world_3d != null else null
	if env == null:
		# 0.30: looked for once (and again every two seconds while there is none), not on every frame: this walk
		# over the whole scene tree was a millisecond of every frame, anywhere on the map.
		if not is_instance_valid(_env_node) and _time >= _env_retry:
			_env_retry = _time + 2.0
			for node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
				_env_node = node as WorldEnvironment
				break
		if is_instance_valid(_env_node):
			env = _env_node.environment
	if env != null and env.volumetric_fog_enabled:
		env.volumetric_fog_ambient_inject = lerpf(.2, 0.0, _inside)

func _process(delta: float) -> void:
	_time += delta
	if Engine.get_process_frames() % 15 == 0:
		_update_light()
	_fog_inside(delta)
	# The rocking chair by the parlour window moves by itself, just a little.
	if is_instance_valid(_rocking) and (not _rocking.get_parent() is RigidBody3D or (_rocking.get_parent() as RigidBody3D).sleeping):
		_rocking.rotation.x = sin(_time * 1.3) * .05 * (.6 + .4 * sin(_time * .21))
	if is_instance_valid(_chandelier):
		_chandelier.rotation.z = deg_to_rad(-3.0) + sin(_time * .35) * .02
	if entered:
		return
	var scene := get_tree().current_scene
	if scene == null or not "player" in scene or scene.player == null:
		return
	var p: Vector3 = scene.player.global_position
	if p.z < GATE.z - 1.0 and p.z > GATE.z - 6.0 and absf(p.x - GATE.x) < GATE_HALF + .5:
		var story := get_tree().get_first_node_in_group("story")
		if story != null and not story.ui.dialogue_active():
			story.ui.say("You", [ENTRY_LINE], 4.5)
			entered = true
