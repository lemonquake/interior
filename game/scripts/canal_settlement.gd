extends Node3D
## 0.17 canal: an abandoned squatter settlement on a river ravine west of the house (replaces the 0.16 grid).
## Its stilt shanties and garbage are custom Blender models (tools/blender/canal/build_canal_kit.py, read through
## kit.json). This script lays the river-aligned terrain with a photographic bank shader, the retaining wall,
## the rusted catwalk under the cantilevered houses, the footbridge, the concrete road bridge (the view the
## owner's reference photo was taken from), the water, the overgrown far bank, rubbish, vandalism and the few
## lights still dying in the dark. Walking collision carries "surface" tags for footsteps.
##
## Everything is placed in river coordinates: u metres across the river from its centre line rx(z) (west
## negative), z along it. The east bank is a 3.9 m wall; the catwalk runs at its foot; the lane is on top.
const FLOOR := -2.10        # bank top: the lanes and the house floors
const CATWALK := -4.40      # catwalk deck
const WATER := -6.00
const BED := -6.55
const PATH := -5.45         # the far-bank footpath
const Z_SOUTH := -16.0
const Z_NORTH := 70.0
const WALL_U := 5.6         # east bank edge
const CAT_IN := 5.58        # catwalk deck spans u CAT_OUT..CAT_IN
const CAT_OUT := 3.72
const CAT_END := 50.0       # the catwalk climbs to the bridge from here
const STAIR_Z := 22.2       # trench stair from the lane down to the catwalk
const BRIDGE_Z := 60.2
const BRIDGE_HALF := 2.2
const FOOT_Z := -9.0        # plank footbridge to the far bank
const LANE_U := 12.9        # lane between the river houses and the lane houses
const BACK_U := 16.9
const KIT := "res://assets/models/canal/kit/"
const WARREN := preload("res://scripts/canal_warren.gd")
const TAGS := "res://assets/outdoor/canal/tags/"

var b: InteriorBalconyBuilder
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var solids: StaticBody3D
var bulbs: Array[Dictionary] = []
var elapsed := 0.0
var lighting: InteriorLighting
var light_tier := -1
var kit_materials: Dictionary = {}
var decal_names: Array[String] = []
var house_spans: Array[Vector2] = []
var kit_batches: Dictionary = {}
var kit_meshes: Dictionary = {}    # occupied z ranges on the far bank (no trees there)
## 0.60: the litter (cups, cans, bottles, bags, sachets...) as MultiMesh squares (scripts/trash_kit.gd).
var trash: InteriorTrash
var stats := {"houses": 0, "river_houses": 0, "lane_houses": 0, "far_houses": 0, "storeys": 0, "planks": 0,
	"models": 0, "kit_pieces": 0, "rubbish": 0, "decals": 0, "bulbs": 0, "colliders": 0, "wires": 0}

static func rx(z: float) -> float:
	return -66.0 + 2.4 * sin((z - 4.0) * .052)

static func rslope(z: float) -> float:
	return 2.4 * .052 * cos((z - 4.0) * .052)

static func at(u: float, y: float, z: float) -> Vector3:
	return Vector3(rx(z) + u, y, z)

## Local +X points out over the river from the east bank (west), Y up, Z back along the bank.
static func east_basis(z: float) -> Basis:
	var x := Vector3(-1, 0, rslope(z)).normalized()
	return Basis(x, Vector3.UP, x.cross(Vector3.UP))

static func west_basis(z: float) -> Basis:
	var x := Vector3(1, 0, -rslope(z)).normalized()
	return Basis(x, Vector3.UP, x.cross(Vector3.UP))

## Far-bank footpath height: it climbs to the bridge at the north end.
static func path_y(z: float) -> float:
	return lerpf(PATH, FLOOR, smoothstep(44.0, 57.0, z))

static func stair_y(u: float) -> float:
	return lerpf(CATWALK, FLOOR, clampf((u - 4.9) / 5.4, 0, 1))

func ground(u: float, z: float) -> float:
	var n := noise.get_noise_2d(rx(z) + u, z)
	var x := rx(z) + u
	if u < -28.4:
		return WARREN.ground(u, z, n)  # 0.18: the warren behind the far-bank fence, with its estero
	if x > -40.6 and z > 15.4 and z < 20.6 and u > 8.0:
		return FLOOR - 1.2  # under the entry ramp
	if u >= WALL_U - .001 and u <= 10.3 and absf(z - STAIR_Z) < .76:
		return stair_y(u) - .6  # the stair trench (under the cast steps)
	var py := path_y(z)
	if absf(z - WARREN.ENTRY_Z) < .9 and u > -13.6 and u < -7.3:
		return lerpf(py, FLOOR, (-7.3 - u) / 6.3) - .04  # 0.18: the steps to the warren, trodden into the bank
	if u <= -13.0:
		return FLOOR + n * .07
	if u < -7.9:
		var t := smoothstep(0.0, 1.0, (u + 13.0) / 5.1)
		return lerpf(FLOOR, py, t) + n * .22 * sin(t * PI)
	if u <= -6.3:
		return py + n * .03
	if u < -5.0:
		return lerpf(py, WATER - .12, (u + 6.3) / 1.3) + n * .05
	if u < -4.0:
		return lerpf(WATER - .12, BED, u + 5.0) + n * .05
	if u < 3.0:
		return BED + n * .1
	if u < 3.9:
		return lerpf(BED, WATER - .05, (u - 3.0) / .9) + n * .06
	if u < WALL_U - .004:
		return lerpf(WATER - .05, WATER + .95, (u - 3.9) / 1.695) + n * .16
	# The retaining wall: an irregular, battered face of patched concrete and rock that leans back
	# under the houses' rear edge, rather than a clean vertical.
	var rough := noise.get_noise_2d(z * 3.1, u * 9.0)
	if u < WALL_U + .01:
		return CATWALK + .25 + n * .35 + rough * .2
	if u < 5.67:
		return -3.75 + n * .3 + rough * .25
	if u < 5.73:
		return -3.3 + n * .3 + rough * .2
	if u < 5.85:
		return -2.6 + n * .2
	return FLOOR + n * .025

func build(town: Node3D) -> void:
	name = "Canal settlement"
	rng.seed = 170810
	noise.seed = 1717
	noise.frequency = .32
	noise.fractal_octaves = 3
	b = InteriorBalconyBuilder.new()
	b._stats = {"triangles_added": 0, "static_batches": 0, "colliders": 0}
	solids = StaticBody3D.new()
	solids.name = "Canal surfaces"
	solids.collision_layer = 2
	solids.collision_mask = 5
	add_child(solids)
	trash = InteriorTrash.new(self, 600017)
	trash.layers = 2
	trash.ground = func(q: Vector3) -> float:
		# On the terrain: follow it. Over a deck, a step or a boardwalk (the hint is well off the terrain): stay.
		var gy := ground(q.x - rx(q.z), q.z)
		return gy if absf(gy - q.y) < .18 else q.y
	_open_connection(town)
	InteriorLoadClock.mark("canal: open_connection")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_materials()
	InteriorLoadClock.mark("canal: materials")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_terrain()
	InteriorLoadClock.mark("canal: terrain")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_water()
	InteriorLoadClock.mark("canal: water")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_catwalk()
	InteriorLoadClock.mark("canal: catwalk")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_stairs()
	InteriorLoadClock.mark("canal: stairs")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_footbridge()
	InteriorLoadClock.mark("canal: footbridge")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_road_bridge()
	InteriorLoadClock.mark("canal: road_bridge")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_headwalls()
	InteriorLoadClock.mark("canal: headwalls")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_houses()
	InteriorLoadClock.mark("canal: houses")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_lane()
	InteriorLoadClock.mark("canal: lane")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_wall_dressing()
	InteriorLoadClock.mark("canal: wall_dressing")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_rubbish()
	InteriorLoadClock.mark("canal: rubbish")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_flora()
	InteriorLoadClock.mark("canal: flora")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_bounds()
	InteriorLoadClock.mark("canal: bounds")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	var warren := WARREN.new()
	add_child(warren)
	warren.build(self)
	InteriorLoadClock.mark("canal: warren")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	# Five lights still burn in the whole settlement: two caged bulbs, one on a lane wire, a dying street lamp
	# on the bridge and a votive candle at a roadside shrine on the far bank.
	_hanging_bulb(at(4.55, CATWALK + 2.02, STAIR_Z + 3.4), 0, "bracket")
	InteriorLoadClock.mark("canal: hanging_bulb")
	_hanging_bulb(at(14.7, FLOOR + 2.85, 18.4), 1, "wire")
	InteriorLoadClock.mark("canal: hanging_bulb")
	_hanging_bulb(at(4.55, CATWALK + 2.05, -11.5), 2, "bracket")
	InteriorLoadClock.mark("canal: hanging_bulb")
	_hanging_bulb(at(4.55, CATWALK + 2.0, 38.5), 5, "bracket")
	InteriorLoadClock.mark("canal: hanging_bulb")
	_hanging_bulb(at(4.55, CATWALK + 2.0, 7.0), 6, "bracket")
	InteriorLoadClock.mark("canal: hanging_bulb")
	_hanging_bulb(at(14.7, FLOOR + 2.9, 40.0), 7, "wire")
	InteriorLoadClock.mark("canal: hanging_bulb")
	_bridge_lamp(at(-1.0, FLOOR, BRIDGE_Z - BRIDGE_HALF + .25), 3)
	InteriorLoadClock.mark("canal: bridge_lamp")
	_shrine(at(-8.6, path_y(31.0), 31.0), 4)
	InteriorLoadClock.mark("canal: shrine")
	_mist_and_reflections()
	InteriorLoadClock.mark("canal: mist_and_reflections")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	b._commit(self, "Canal - ")
	InteriorLoadClock.mark("canal: b._commit")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_trash_drift()
	stats["trash_pieces"] = trash.count
	# (`-- --no-trash`: built and counted but not drawn, to measure what the litter costs.)
	stats["trash_draw_squares"] = 0 if "--no-trash" in OS.get_cmdline_user_args() else trash.commit("Canal trash")
	InteriorLoadClock.mark("canal: trash")
	_commit_kit()
	InteriorLoadClock.mark("canal: commit_kit")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	InteriorNeighborhoodWeathering.apply(self)
	InteriorLoadClock.mark("canal: InteriorNeighborhoodWeathering.apply")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	for child in find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		var mats: Array[Material] = [mi.material_override]
		for s in mi.get_surface_override_material_count():
			mats.append(mi.get_surface_override_material(s))
		for mat in mats:
			if mat is ShaderMaterial and "weathering" in (mat as ShaderMaterial).shader.resource_path:
				(mat as ShaderMaterial).set_shader_parameter("ground_y", FLOOR)
	# 0.66: the reeds, ferns, rocks, shrubs, bamboo and snags drawn instanced, a draw per mesh per 24 m square.
	var inst: Array = (preload("res://scripts/static_instancer.gd")).batch(self, ["reed", "fern", "rock", "boulder", "shrub", "bamboo", "snag", "dead trunk", "cattail"])
	stats["instanced"] = inst[0]
	stats["instanced_draws"] = inst[1]
	InteriorLoadClock.mark("canal: instanced %d models into %d draws" % [inst[0], inst[1]])
	stats["triangles"] = b._stats.triangles_added
	stats["bulbs"] = bulbs.size()
	set_meta("counts", stats)
	set_meta("bounds", Rect2(-123, Z_SOUTH, 89, Z_NORTH - Z_SOUTH))
	b.free()
	b = null

# ------------------------------------------------------------------------------------------------ materials

func _materials() -> void:
	for spec in [["earth", "muddy_tracks", 2.8, Color(.55, .51, .42)], ["bank", "brown_mud_02", 1.7, Color(.5, .5, .4)],
		["wood", "dark_wooden_planks", 1.7, Color(.74, .67, .55)], ["wood grey", "blue_painted_planks", 1.6, Color(.52, .55, .52)],
		["rust", "rusty_metal_04", 1.5, Color(.78, .64, .5)], ["roof", "rusty_corrugated_iron", 2.0, Color(.66, .6, .54)],
		["tin", "corrugated_iron_02", 2.0, Color(.62, .62, .58)], ["block", "concrete_block_wall", 2.0, Color(.72, .7, .64)],
		["cement", "rough_plaster_broken", 2.0, Color(.56, .55, .5)], ["moss", "leafy_grass", 1.3, Color(.27, .36, .2)],
		["rock", "concrete_wall_008", 1.6, Color(.5, .5, .46)], ["shutter", "painted_metal_shutter", 1.5, Color(.55, .6, .58)],
		["muck", "brown_mud_02", 1.0, Color(.16, .14, .1), .35],
		["concrete", "concrete_wall_008", 2.4, Color(.6, .6, .56)]]:
		b._pbr(spec[0], spec[1], spec[2], spec[3], spec[4] if spec.size() > 4 else 1.0)
	# Faded house paint: weathering turns these into peeling, stained plaster/plywood.
	var paints := [Color(.6, .5, .26), Color(.36, .48, .42), Color(.38, .44, .5), Color(.52, .38, .31), Color(.55, .54, .49), Color(.43, .5, .36)]
	var paint_shader := load("res://scripts/canal_paint.gdshader")
	for i in paints.size():
		var paint := ShaderMaterial.new()
		paint.resource_name = "Canal / paint %d" % i
		paint.shader = paint_shader
		paint.set_shader_parameter("paint_map", load("res://assets/outdoor/textures/peeling_painted_wall/albedo.jpg"))
		paint.set_shader_parameter("paint_normal", load("res://assets/outdoor/textures/peeling_painted_wall/normal.jpg"))
		paint.set_shader_parameter("tint", paints[i])
		paint.set_shader_parameter("ground_y", FLOOR)
		b._materials["paint %d" % i] = paint
	for key in ["wood", "wood grey"]: b._materials[key].resource_name = "PBR / n planks"
	b._materials["rust"].resource_name = "PBR / n rust"
	b._materials["shutter"].resource_name = "PBR / n shutter"
	b._materials["roof"].resource_name = "PBR / n roof rust"
	b._materials["tin"].resource_name = "PBR / n roof tin"
	b._materials["cement"].resource_name = "PBR / n concrete"
	b._materials["concrete"].resource_name = "PBR / n concrete"
	b._materials["block"].resource_name = "PBR / n block"
	var flats := {"inside": [Color(.012, .013, .012), .98], "wire": [Color(.018, .02, .02), .9], "rubber": [Color(.03, .03, .03), .85],
		"pvc": [Color(.55, .3, .12), .6], "pvc grey": [Color(.34, .35, .34), .6], "plastic blue": [Color(.1, .22, .42), .55],
		"plastic black": [Color(.025, .025, .028), .4], "plastic white": [Color(.46, .45, .4), .5], "plastic red": [Color(.36, .07, .05), .5],
		"plastic green": [Color(.1, .24, .12), .5], "plastic yellow": [Color(.5, .4, .1), .5], "pet": [Color(.42, .48, .5), .15],
		"glass green": [Color(.06, .16, .1), .1], "foam": [Color(.5, .49, .44), .9], "foam stained": [Color(.42, .37, .26), .95],
		"can": [Color(.35, .35, .36), .35], "cardboard": [Color(.3, .22, .13), .97], "foil": [Color(.5, .5, .52), .3],
		"scum": [Color(.12, .14, .07), .7], "paper": [Color(.4, .37, .3), .99], "glass": [Color(.05, .06, .065), .08],
		"tarp blue": [Color(.09, .2, .36), .7], "sack": [Color(.36, .35, .3), .95], "leaf": [Color(.15, .24, .08), .75], "tarp orange": [Color(.42, .2, .08), .7], "candle glass": [Color(.5, .05, .03), .2]}
	for key: String in flats:
		b._flat(key, flats[key][0], flats[key][1])
	(b._materials["can"] as StandardMaterial3D).metallic = .7
	(b._materials["foil"] as StandardMaterial3D).metallic = .8
	(b._materials["glass"] as StandardMaterial3D).metallic_specular = .9
	for key in ["tarp blue", "tarp orange"]:
		(b._materials[key] as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	var cloth := [Color(.32, .1, .08), Color(.16, .2, .3), Color(.45, .43, .38), Color(.27, .29, .18)]
	(b._materials["leaf"] as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	for key in ["plastic black", "plastic white", "plastic red", "plastic green", "plastic blue", "plastic yellow"]:
		(b._materials[key] as StandardMaterial3D).metallic_specular = .7
	for i in cloth.size():
		var mat := b._pbr("cloth %d" % i, "fabric_pattern_07", .6, cloth[i])
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	stats["textured_prop_materials"] = InteriorHorrorPropMaterials.dress_palette(b._materials)
	# Chain-link mesh for the catwalk railing, drawn once.
	var image := Image.create(128, 128, true, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for i in 128:
		for w in 3:
			for p in [Vector2i(i, (i + w) % 128), Vector2i(i, (127 - i + w) % 128)]:
				image.set_pixelv(p, Color(.3, .2, .14, 1))
	image.generate_mipmaps()
	var chain := StandardMaterial3D.new()
	chain.resource_name = "Canal / chain link"
	chain.albedo_texture = ImageTexture.create_from_image(image)
	chain.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	chain.alpha_scissor_threshold = .4
	chain.cull_mode = BaseMaterial3D.CULL_DISABLED
	chain.metallic = .5
	chain.roughness = .7
	chain.uv1_scale = Vector3.ONE / .16
	chain.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	b._materials["chain"] = chain
	var candle := StandardMaterial3D.new()
	candle.albedo_color = Color(.9, .8, .6)
	candle.emission_enabled = true
	candle.emission = Color(1, .55, .2)
	candle.emission_energy_multiplier = 2.0
	b._materials["flame"] = candle
	var dir := DirAccess.open(TAGS)
	if dir != null:
		# Exported builds list the imported "<name>.png.import" entries, not the PNGs themselves.
		for file in dir.get_files():
			var png := file.trim_suffix(".import")
			if png.ends_with(".png") and not decal_names.has(png.get_basename()):
				decal_names.append(png.get_basename())
	decal_names.sort()
	var water := load("res://assets/baked/fields/materials/fields_puddle_water.tres") as ShaderMaterial
	var river := ShaderMaterial.new()
	river.shader = load("res://scripts/canal_river.gdshader")
	for p: Dictionary in water.shader.get_shader_uniform_list():
		var value: Variant = water.get_shader_parameter(p.name)
		if value != null: river.set_shader_parameter(p.name, value)
	b._materials["water"] = river

## Material for a surface of a kit GLB, by its Blender material name.
func _kit_material(key: String) -> Material:
	if key.begins_with("decal "):
		return _decal_material(key.trim_prefix("decal "))
	if b._materials.has(key):
		return b._materials[key]
	return null

func _decal_material(tag: String, mirrored := false) -> Material:
	var key := ("bdecal " if mirrored else "decal ") + tag
	if not b._materials.has(key):
		var path := TAGS + tag + ".png"
		if not ResourceLoader.exists(path): return null
		var mat := StandardMaterial3D.new()
		mat.resource_name = "Canal / " + key
		mat.albedo_texture = load(path)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = .92
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		mat.render_priority = 1
		if mirrored: mat.uv1_scale = Vector3(-1, 1, 1)
		b._materials[key] = mat
	return b._materials[key]

# ------------------------------------------------------------------------------------------------ helpers

func _solid(label: String, p: Vector3, size: Vector3, surface := "wood", basis := Basis.IDENTITY) -> CollisionShape3D:
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

func _box(label: String, p: Vector3, size: Vector3, mat: String, solid := false, surface := "wood", basis := Basis.IDENTITY) -> void:
	b._box(label, p, size, mat, false, basis)
	if solid: _solid(label, p, size, surface, basis)

## Oriented box between two points (a slab, beam or ramp) with `up` as its local Y hint.
func _beam(label: String, a: Vector3, c: Vector3, width: float, thick: float, mat: String, solid := false, surface := "wood") -> void:
	var forward := (c - a).normalized()
	var right := Vector3.UP.cross(forward)
	if right.length() < .01: right = Vector3.RIGHT
	right = right.normalized()
	var basis := Basis(right, forward.cross(right), forward)
	_box(label, (a + c) * .5, Vector3(width, thick, a.distance_to(c)), mat, solid, surface, basis)

func _ramp(label: String, a: Vector3, c: Vector3, width: float, surface: String) -> void:
	# Collision only: top face runs exactly from a to c.
	var forward := (c - a).normalized()
	var right := Vector3.UP.cross(forward).normalized()
	var basis := Basis(right, forward.cross(right), forward)
	_solid(label, (a + c) * .5 - basis.y * .1, Vector3(width, .2, a.distance_to(c)), surface, basis)

func _decal(p: Vector3, normal: Vector3, width: float, tag := "") -> void:
	if decal_names.is_empty(): return
	if tag == "": tag = decal_names[rng.randi() % decal_names.size()]
	if _decal_material(tag, true) == null: return
	var tall := 1.0 if tag.begins_with("tag") else .5
	var up := Vector3.UP
	var right := up.cross(normal).normalized()
	var c := p + normal * .035
	var h := width * tall
	b._quad([c + right * width * .5 - up * h * .5, c - right * width * .5 - up * h * .5,
		c - right * width * .5 + up * h * .5, c + right * width * .5 + up * h * .5], normal, "bdecal " + tag)
	stats.decals += 1

func _model(path: String, p: Vector3, scale: float, yaw: float, label: String, collision := false, tilt := Vector3.ZERO) -> Node3D:
	var node := InteriorModelKit.place(self, path, p, yaw, scale, "bottom", tilt, label)
	_bind(node)
	var foliage := "plant" in label or "Fern" in label or "Reed" in label or "tree" in label or "Bamboo" in label or "Shrub" in label
	InteriorModelKit.prepare_instance(node, 2, 0.0 if collision else 90.0, true, foliage)
	if collision:
		var bounds := InteriorModelKit.bounds_in(node, self)
		_solid(label + " body", bounds.get_center(), bounds.size * Vector3(.85, 1, .85), "metal" if "drum" in label.to_lower() else "wood")
	stats.models += 1
	return node

## Custom kit models (houses, rubbish) are merged into per-material batches, a few per 24 m of
## river, instead of hundreds of separate instances: the district draws in a few hundred calls.
func _kit(name_: String, p: Vector3, basis: Basis, _label: String) -> void:
	var _t := Time.get_ticks_usec()
	_kit__timed(name_, p, basis, _label)
	InteriorLoadClock.tally("canal kit append", _t)

func _kit__timed(name_: String, p: Vector3, basis: Basis, _label: String) -> void:
	if name_.begins_with("litter_"):
		# 0.60: the old Blender litter (blobs and boxes) is now a heap of real-looking pieces.
		var sc := basis.get_scale().x
		trash.cluster(p, 1.25 * sc, int(26 * sc) + 4)
		return
	var xf := Transform3D(basis, p)
	var chunk := int(floor((p.z - Z_SOUTH) / 24.0))
	for part: Array in _kit_parts(KIT + name_ + ".glb"):
		var mesh: Mesh = part[0]
		for s in mesh.get_surface_count():
			var src := mesh.surface_get_material(s)
			var key := src.resource_name if src != null else ""
			var batch_key := key + "|" + str(chunk)
			if not kit_batches.has(batch_key):
				var mat := _kit_material(key)
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				# 0.30: the merged batch is read from InteriorBuildCache when it is there; nothing is copied then.
				kit_batches[batch_key] = [tool, mat if mat != null else src, key, InteriorBuildCache.mesh("Canal kit - " + batch_key.replace("|", " "))]
			if kit_batches[batch_key][3] == null:
				(kit_batches[batch_key][0] as SurfaceTool).append_from(mesh, s, xf * (part[1] as Transform3D))
	stats.kit_pieces += 1

func _kit_parts(path: String) -> Array:
	if not kit_meshes.has(path):
		var scene := InteriorModelKit.scene(path).instantiate() as Node3D
		var parts: Array = []
		for child in scene.find_children("*", "MeshInstance3D", true, false):
			var mi := child as MeshInstance3D
			var t := mi.transform
			var n := mi.get_parent()
			while n != null and n != scene:
				t = (n as Node3D).transform * t
				n = n.get_parent()
			parts.append([mi.mesh, t])
		scene.free()
		kit_meshes[path] = parts
	return kit_meshes[path]

func _commit_kit() -> void:
	var _t := Time.get_ticks_usec()
	_commit_kit__timed()
	InteriorLoadClock.tally("canal kit commit", _t)

func _commit_kit__timed() -> void:
	for batch_key: String in kit_batches:
		var item: Array = kit_batches[batch_key]
		var mesh := MeshInstance3D.new()
		mesh.name = "Canal kit - " + batch_key.replace("|", " ")
		mesh.mesh = item[3] as Mesh
		if mesh.mesh == null:
			mesh.mesh = (item[0] as SurfaceTool).commit()
			InteriorBuildCache.store(String(mesh.name), mesh.mesh)
		mesh.material_override = item[1]
		mesh.layers = 2
		if (item[2] as String).begins_with("decal "):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
	kit_batches.clear()

func _bind(node: Node) -> void:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		mi.layers = 2
		if mi.mesh == null: continue
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			if src == null: continue
			var mat := _kit_material(src.resource_name)
			if mat != null: mi.set_surface_override_material(s, mat)

func _wire(a: Vector3, c: Vector3, sag: float, radius := .008) -> void:
	var points: Array = []
	for i in 13:
		var t := i / 12.0
		points.append(a.lerp(c, t) + Vector3.DOWN * sin(t * PI) * sag)
	b._tube(points, radius, "wire", 4)
	stats.wires += 1

# ------------------------------------------------------------------------------------------------ terrain

func _terrain() -> void:
	var us: Array[float] = []
	var u := -55.0
	while u <= 34.01:
		us.append(u)
		u += .5
	for v in [-13.0, -7.9, -6.3, -5.0, -4.0, 3.0, 3.9, WALL_U - .005, WALL_U, 5.66, 5.72, 5.84, 5.92, 10.3]:
		us.append(v)
	us.sort()
	var zs: Array[float] = []
	var z := Z_SOUTH - 2.0
	while z <= Z_NORTH + 2.01:
		zs.append(z)
		z += .5
	for v in [STAIR_Z - .75, STAIR_Z + .75, 15.4, 20.6]:
		zs.append(v)
	zs.sort()
	us = _dedupe(us)
	zs = _dedupe(zs)
	var verts := PackedVector3Array()
	var cols := us.size()
	for zz in zs:
		for uu in us:
			verts.append(Vector3(rx(zz) + uu, ground(uu, zz), zz))
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	var indices := PackedInt32Array()
	for j in zs.size() - 1:
		for i in cols - 1:
			var a := j * cols + i
			var quad := [a, a + 1, a + cols + 1, a + cols]
			var centre := (verts[a] + verts[a + cols + 1]) * .5
			if centre.x > -35.4: continue
			# Split the wall quads along the vertical face, the rest along the shorter diagonal.
			for tri in [[quad[0], quad[1], quad[2]], [quad[0], quad[2], quad[3]]]:
				var n: Vector3 = (verts[tri[2]] - verts[tri[0]]).cross(verts[tri[1]] - verts[tri[0]])
				for k in tri:
					normals[k] += n
					indices.append(k)
	for k in normals.size():
		normals[k] = normals[k].normalized() if normals[k].length() > 0 else Vector3.UP
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var uvs := PackedVector2Array()
	for v in verts: uvs.append(Vector2(v.x, v.z))
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/canal_bank.gdshader")
	var t := "res://assets/outdoor/textures/"
	for pair in [["mud", "brown_mud_02"], ["track", "muddy_tracks"], ["grass", "withered_grass"], ["wall", "concrete_wall_008"], ["rock", "rough_plaster_broken"]]:
		mat.set_shader_parameter(pair[0] + "_albedo", load(t + pair[1] + "/albedo.jpg"))
		mat.set_shader_parameter(pair[0] + "_normal", load(t + pair[1] + "/normal.jpg"))
	mat.set_shader_parameter("water_y", WATER)
	mat.set_shader_parameter("floor_y", FLOOR)
	mesh.surface_set_material(0, mat)
	var terrain := MeshInstance3D.new()
	terrain.name = "Ravine terrain"
	terrain.mesh = mesh
	terrain.layers = 2
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(terrain)
	var faces := PackedVector3Array()
	for k in indices: faces.append(verts[k])
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var c := CollisionShape3D.new()
	c.name = "Ravine ground"
	c.shape = shape
	c.set_meta("surface", "dirt")
	solids.add_child(c)
	stats.colliders += 1
	# The entry ramp from the old street A, up to the lane.
	_beam("Entry dirt ramp", Vector3(-33, -2.87 - .12, 18), Vector3(-41.2, FLOOR - .12, 18), 4.2, .24, "earth", true, "dirt")

func _dedupe(values: Array[float]) -> Array[float]:
	var out: Array[float] = []
	for v in values:
		if out.is_empty() or v - out[-1] > .003: out.append(v)
	return out

func _water() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := Z_SOUTH - 3.0
	while z < Z_NORTH + 3.0:
		var z2 := z + 1.0
		var q := [at(-5.9, WATER, z), at(4.3, WATER, z), at(4.3, WATER, z2), at(-5.9, WATER, z2)]
		var uv := [Vector2(-5.9, z), Vector2(4.3, z), Vector2(4.3, z2), Vector2(-5.9, z2)]
		for i in [0, 1, 2, 0, 2, 3]:
			tool.set_normal(Vector3.UP)
			tool.set_uv(uv[i])
			tool.add_vertex(q[i])
		z = z2
	var water := MeshInstance3D.new()
	water.name = "River water"
	water.mesh = tool.commit()
	water.material_override = b._materials["water"]
	water.layers = 2
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

# ------------------------------------------------------------------------------------------------ catwalk

func _catwalk() -> void:
	var mid := (CAT_IN + CAT_OUT) * .5
	var width := CAT_IN - CAT_OUT
	var z := Z_SOUTH + .4
	var seg := 1.2
	var post_index := 0
	while z < CAT_END - .01:
		var z2 := minf(z + seg, CAT_END)
		var a := at(mid, CATWALK, z)
		var c := at(mid, CATWALK, z2)
		var forward := (c - a).normalized()
		var right := Vector3.UP.cross(forward).normalized()
		var basis := Basis(right, Vector3.UP, forward)
		_solid("Catwalk deck", (a + c) * .5 + Vector3.DOWN * .1, Vector3(width + .1, .2, a.distance_to(c) + .04), "wood", basis)
		# Steel stringers and a cross member, rusted through.
		for uu in [CAT_OUT + .05, CAT_IN - .05]:
			b._rod(at(uu, CATWALK - .1, z), at(uu, CATWALK - .1, z2), .045, "rust", 5)
		b._rod(at(CAT_OUT, CATWALK - .12, z), at(CAT_IN, CATWALK - .12, z), .035, "rust", 5)
		# Planks across the frame: warped, mismatched, a few missing or snapped.
		var pz := z
		while pz < z2 - .01:
			var roll := rng.randf()
			var w := rng.randf_range(.17, .23)
			var pc := at(mid + rng.randf_range(-.04, .04), CATWALK - .025 + rng.randf_range(-.008, .008), pz + w * .5)
			var len_ := width + rng.randf_range(-.06, .04)
			var tilt := Basis(forward, rng.randf_range(-.025, .025))
			if roll < .035:
				pass
			elif roll < .08:
				var short := len_ * rng.randf_range(.4, .7)
				_box("Snapped plank", pc + right * (len_ - short) * .5 * (1 if rng.randf() < .5 else -1), Vector3(short, .04, w - .02), "wood", false, "wood", Basis(right, Vector3.UP, forward) * Basis(Vector3.RIGHT, rng.randf_range(-.1, .1)))
			else:
				_box("Catwalk plank", pc, Vector3(len_, .04, w - .018), "wood" if roll > .2 else "wood grey", false, "wood", tilt * basis)
			stats.planks += 1
			pz += w
		# Stilts every 2.4 m: steel pipe outside, timber against the wall, braced.
		if post_index % 2 == 0:
			var outer := at(CAT_OUT + .05, CATWALK - .12, z)
			var inner := at(CAT_IN - .25, CATWALK - .12, z)
			var go := ground(CAT_OUT + .05, z) - .3
			var gi := ground(CAT_IN - .25, z) - .2
			b._rod(Vector3(outer.x + rng.randf_range(-.05, .05), go, outer.z), outer, .05, "rust", 7)
			b._rod(Vector3(inner.x, gi, inner.z), inner, .06, "wood", 6)
			b._rod(Vector3(outer.x, go + .4, outer.z), Vector3(inner.x, CATWALK - .3, inner.z), .018, "rust", 4)
			if z2 < CAT_END - 1: b._rod(Vector3(outer.x, go + .3, outer.z), at(CAT_OUT + .05, CATWALK - .25, z + 2.4), .018, "rust", 4)
		post_index += 1
		# Railing on the river side, chain link between posts; skip the footbridge gap.
		var gap := absf((z + z2) * .5 - FOOT_Z) < .9
		if not gap:
			var ra := at(CAT_OUT - .03, CATWALK, z)
			var rc := at(CAT_OUT - .03, CATWALK, z2)
			var lean := Vector3(-rng.randf_range(0, .08), 0, 0)
			b._rod(ra, ra + Vector3.UP * 1.05 + lean, .022, "rust", 6)
			b._rod(ra + Vector3.UP * 1.04 + lean, rc + Vector3.UP * 1.04, .02, "rust", 6)
			b._rod(ra + Vector3.UP * .5, rc + Vector3.UP * .5, .014, "rust", 5)
			var r := rng.randf()
			if r > .12:
				var top := 1.0 if r > .3 else rng.randf_range(.35, .7)
				var sag := Vector3(0, -rng.randf_range(0, .12), 0) if r < .3 else Vector3.ZERO
				b._plate([ra + Vector3.UP * .06, rc + Vector3.UP * .06, rc + Vector3.UP * top + sag, ra + Vector3.UP * top], "chain")
			_solid("Catwalk railing", (ra + rc) * .5 + Vector3.UP * .55, Vector3(.08, 1.1, ra.distance_to(rc) + .02), "metal", basis)
		z = z2

func _stairs() -> void:
	# Trench stair from the lane down to the catwalk, cut through the bank between two houses.
	var top := at(10.3, FLOOR, STAIR_Z)
	var bottom := at(4.9, CATWALK, STAIR_Z)
	# Walking surface: starts flush with the lane beyond the trench so there is no lip to catch on.
	_ramp("Lane stair", top, bottom, 1.4, "concrete")
	var steps := 15
	var rise := (FLOOR - CATWALK) / steps
	for i in steps:
		var t0 := float(i) / steps
		var t1 := float(i + 1) / steps
		var p := top.lerp(bottom, (t0 + t1) * .5)
		var y0 := lerpf(FLOOR, CATWALK, t0) - rise * .5
		_box("Cast concrete step", Vector3(p.x, y0 - (rise + .25) * .5, p.z), Vector3((top.x - bottom.x) / steps + .02, rise + .25, 1.36), "concrete")
	for side in [-1.0, 1.0]:
		var zz: float = STAIR_Z + side * .78
		var a := at(5.4, CATWALK - .3, zz)
		var c := at(10.3, FLOOR + .05, zz)
		_box("Stair trench wall", Vector3((a.x + c.x) * .5, (CATWALK - .4 + FLOOR + .25) * .5, zz), Vector3(c.x - a.x + .2, FLOOR + .25 - CATWALK + .4, .14), "block", true, "concrete")
		b._rod(at(10.0, FLOOR + .9, zz - side * .08), at(5.2, CATWALK + .95, zz - side * .08), .02, "rust", 6)
	_decal(at(7.2, FLOOR - .6, STAIR_Z - .7), Vector3(0, 0, 1), 1.1)
	_decal(at(6.4, FLOOR - 1.0, STAIR_Z + .7), Vector3(0, 0, -1), .9, "sign_00")
	# North end: the catwalk climbs along the wall to a landing that joins the road bridge.
	var s0 := at((CAT_IN + CAT_OUT) * .5, CATWALK, CAT_END)
	var s1 := at((CAT_IN + CAT_OUT) * .5, FLOOR, CAT_END + 5.4)
	_ramp("Catwalk stair", s0, s1, CAT_IN - CAT_OUT, "wood")
	for i in 18:
		var t := (i + .5) / 18.0
		var p := s0.lerp(s1, t)
		_box("Stair tread", p + Vector3.UP * .02, Vector3(CAT_IN - CAT_OUT, .05, .26), "wood" if i % 4 else "wood grey", false, "wood", Basis(Vector3.UP, atan(rslope(p.z))))
	for i in 3:
		var p := s0.lerp(s1, i / 2.0)
		b._rod(Vector3(p.x - .8, ground(CAT_OUT, p.z) - .2, p.z), Vector3(p.x - .8, p.y - .1, p.z), .05, "rust", 6)
	b._rod(s0 + Vector3(-.95, 1.0, 0), s1 + Vector3(-.95, 1.0, 0), .022, "rust", 6)
	_ramp("Stair rail", s0 + Vector3(-1.0, 1.1, 0), s1 + Vector3(-1.0, 1.1, 0), .1, "metal")
	var landing := at((CAT_IN + CAT_OUT) * .5 + .3, FLOOR, (CAT_END + 5.4 + BRIDGE_Z - BRIDGE_HALF) * .5)
	var landing_len := BRIDGE_Z - BRIDGE_HALF - CAT_END - 5.4 + .1
	_box("Stair landing", landing + Vector3.DOWN * .12, Vector3(CAT_IN - CAT_OUT + 1.2, .24, landing_len), "concrete", true, "concrete")
	var edge := Vector3(rx(landing.z) + CAT_OUT - .25, FLOOR, landing.z)
	b._rod(edge + Vector3(0, 1.0, -landing_len * .5), edge + Vector3(0, 1.0, landing_len * .5), .022, "rust", 6)
	for k in 3: b._rod(edge + Vector3(0, 0, (k - 1) * landing_len * .45), edge + Vector3(0, 1.0, (k - 1) * landing_len * .45), .025, "rust", 6)
	_solid("Landing rail", edge + Vector3.UP * .55, Vector3(.1, 1.1, landing_len), "metal")

func _footbridge() -> void:
	var a := at(CAT_OUT, CATWALK, FOOT_Z)
	var c := at(-6.7, path_y(FOOT_Z), FOOT_Z)
	_ramp("Plank footbridge", a, c, 1.15, "wood")
	var along := (c - a)
	var n := 34
	for i in n:
		var t := (i + .5) / n
		var p := a.lerp(c, t) + Vector3.DOWN * sin(t * PI) * .05
		if rng.randf() < .05: continue
		_box("Footbridge plank", p + Vector3.DOWN * .03, Vector3(along.length() / n - .03, .04, rng.randf_range(1.0, 1.2)), "wood grey" if rng.randf() < .4 else "wood", false, "wood", Basis(Vector3.FORWARD, atan2(along.y, -along.x)))
	for side in [-.5, .5]:
		b._rod(a + Vector3(0, -.1, side), c + Vector3(0, -.1, side), .07, "wood", 7)
		# Sagging wire hand line between leaning posts.
		var pa := a + Vector3(0, 0, side * 1.1)
		var pc := c + Vector3(0, 0, side * 1.1)
		b._rod(pa + Vector3.DOWN * .4, pa + Vector3(.05, 1.1, 0), .04, "wood", 6)
		b._rod(pc + Vector3.DOWN * .6, pc + Vector3(-.06, 1.05, 0), .04, "wood", 6)
		_wire(pa + Vector3.UP * 1.05, pc + Vector3.UP * 1.0, .35, .01)
		_solid("Footbridge side", (a + c) * .5 + Vector3(0, .55, side * 1.25), Vector3(along.length(), 1.1, .08), "wood", Basis(Vector3.FORWARD, atan2(along.y, -along.x)))
	# Mid-river support: posts and two oil drums wedged in the mud.
	var m := a.lerp(c, .5)
	for side in [-.45, .45]:
		b._rod(Vector3(m.x, BED - .2, m.z + side), Vector3(m.x, m.y - .1, m.z + side), .06, "wood", 6)
	_model("street/oil_drum", Vector3(m.x + .6, BED, m.z + .2), .8, 20, "Wedged drum", false, Vector3(12, 0, 8))

func _road_bridge() -> void:
	var z0 := BRIDGE_Z - BRIDGE_HALF
	var z1 := BRIDGE_Z + BRIDGE_HALF
	var xa := rx(BRIDGE_Z) - 15.0
	var xb := rx(BRIDGE_Z) + 8.0
	var cx := (xa + xb) * .5
	_box("Road bridge deck", Vector3(cx, FLOOR - .3, BRIDGE_Z), Vector3(xb - xa, .6, z1 - z0), "concrete", true, "concrete")
	_box("Bridge wearing course", Vector3(cx, FLOOR + .005, BRIDGE_Z), Vector3(xb - xa - .1, .02, z1 - z0 - .7), "earth")
	for x in [rx(BRIDGE_Z) - 5.6, rx(BRIDGE_Z) + 4.2]:
		_box("Bridge pier", Vector3(x, (BED - .4 + FLOOR - .6) * .5, BRIDGE_Z), Vector3(.9, FLOOR - .6 - BED + .4, z1 - z0 - .6), "concrete", true, "concrete")
	for side in [-1.0, 1.0]:
		var z: float = BRIDGE_Z + side * (BRIDGE_HALF - .15)
		var x := xa
		while x < xb - .01:
			var x2 := minf(x + 2.5, xb)
			var broken := rng.randf() < .15 and x > xa + 5 and x2 < xb - 3
			var hgt := rng.randf_range(.3, .55) if broken else .95
			_box("Bridge parapet", Vector3((x + x2) * .5, FLOOR + hgt * .5, z), Vector3(x2 - x - .04, hgt, .25), "concrete", true, "concrete")
			if not broken:
				b._rod(Vector3(x + .1, FLOOR + .95, z), Vector3(x + .1, FLOOR + 1.2, z), .025, "rust", 6)
				b._rod(Vector3(x, FLOOR + 1.2, z), Vector3(x2, FLOOR + 1.2 - rng.randf_range(0, .05), z), .02, "rust", 6)
			else:
				for k in 3: b._sphere(Vector3(x + rng.randf_range(.3, 2.2), FLOOR + .06, z + side * rng.randf_range(-.3, .1)), Vector3(.25, .14, .2), "concrete", 6)
			if rng.randf() < .55:
				_decal(Vector3((x + x2) * .5, FLOOR + .45, z - side * .13), Vector3(0, 0, -side), rng.randf_range(.9, 1.6))
			if rng.randf() < .3:
				_decal(Vector3((x + x2) * .5, FLOOR + .45, z + side * .13), Vector3(0, 0, side), rng.randf_range(.9, 1.6))
			x = x2
		_solid("Bridge rail guard", Vector3(cx, FLOOR + .8, z), Vector3(xb - xa, 1.6, .25), "concrete")
	# The underside: stained soffit, hanging roots and a nest of abandoned cable.
	for i in 6:
		var p := Vector3(rng.randf_range(xa + 6, xb - 4), FLOOR - .62, rng.randf_range(z0 + .3, z1 - .3))
		_wire(p, p + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-.5, .5)), rng.randf_range(.3, .9), .012)
	_decal(Vector3(rx(BRIDGE_Z) - 5.15, WATER + 1.6, BRIDGE_Z), Vector3(1, 0, 0), 1.6)
	_decal(Vector3(rx(BRIDGE_Z) + 3.75, WATER + 1.4, BRIDGE_Z), Vector3(-1, 0, 0), 1.3, "throw_02")

func _headwalls() -> void:
	# Concrete headwalls close the ravine at both ends; the river leaves through black box culverts.
	for spec in [[Z_SOUTH, 1.0], [Z_NORTH, -1.0]]:
		var z: float = spec[0]
		var inward: float = spec[1]
		var u := -14.0
		while u < 7.0:
			var u2 := u + .5
			var low := minf(ground(u, z), ground(u2, z)) - .6
			var culvert := u > -3.6 and u2 < 2.6
			var bottom := WATER + 1.8 if culvert else low
			var a := at(u, 0, z)
			var c := at(u2, 0, z)
			_box("Culvert headwall", Vector3((a.x + c.x) * .5, (bottom + FLOOR + .7) * .5, z - inward * .35), Vector3(c.x - a.x + .02, FLOOR + .7 - bottom, .7), "concrete", true, "concrete")
			if culvert:
				_box("Culvert dark", Vector3((a.x + c.x) * .5, WATER + .5, z - inward * 2.5), Vector3(c.x - a.x + .02, 3.5, .2), "inside")
			u = u2
		var ca := at(-3.6, 0, z)
		var cc := at(2.6, 0, z)
		for side in [ca.x, cc.x]:
			_box("Culvert side", Vector3(side, WATER + .6, z - inward * 1.5), Vector3(.3, 2.6, 3.0), "concrete")
		_box("Culvert roof", Vector3((ca.x + cc.x) * .5, WATER + 1.95, z - inward * 1.5), Vector3(cc.x - ca.x + .3, .3, 3.0), "concrete")
		# A bent grate, half torn away, with rubbish packed against it.
		var x := ca.x + .2
		while x < cc.x - .1:
			var bent := rng.randf() < .2
			b._rod(Vector3(x, BED, z + inward * .02), Vector3(x + (rng.randf_range(-.3, .3) if bent else 0), WATER + 1.8, z + inward * (.02 + (.25 if bent else 0))), .025, "rust", 5)
			x += .16
		for h in [WATER + .4, WATER + 1.2]:
			b._rod(Vector3(ca.x, h, z + inward * .03), Vector3(cc.x, h, z + inward * .03), .03, "rust", 5)
		_solid("Culvert grate", Vector3((ca.x + cc.x) * .5, WATER + .5, z + inward * .05), Vector3(cc.x - ca.x, 3.0, .1), "metal")
		_kit("floating_c", Vector3((ca.x + cc.x) * .5, WATER + .01, z + inward * 1.1), Basis(Vector3.UP, PI * .5), "Rubbish at grate")
		stats.rubbish += 1
		_decal(at(-8.0, FLOOR - .2, z + inward * .02), Vector3(0, 0, inward), 1.8, "sign_01")
		_decal(at(4.0, WATER + 2.6, z + inward * .02), Vector3(0, 0, inward), 1.4)

# ------------------------------------------------------------------------------------------------ houses

func _houses() -> void:
	var kit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(KIT + "kit.json"))
	var river: Array = []
	var lane: Array = []
	for spec: Dictionary in kit.houses:
		(river if spec.row == "river" else lane).append(spec)
	# East bank row: a continuous wall of shanties, gaps only for the trench stair and the climb to the bridge.
	var z := Z_SOUTH + 2.6
	var used := 0
	while used < river.size():
		var spec: Dictionary = river[used]
		var w: float = spec.width
		if z < STAIR_Z + 1.05 and z + w > STAIR_Z - 1.05:
			z = STAIR_Z + 1.05
		if z + w > CAT_END - 1.0: break
		var zc := z + w * .5
		_place_house(spec, at(WALL_U, FLOOR, zc), east_basis(zc), "River house")
		stats.river_houses += 1
		z += w + rng.randf_range(.12, .45)
		used += 1
	# The rest stand on the far bank among the trees, facing the water.
	var far_z := [2.0, 14.5, 38.0, -6.0, 27.0]
	var k := 0
	while used < river.size() and k < far_z.size():
		var spec: Dictionary = river[used]
		var zc: float = far_z[k]
		_place_house(spec, at(-13.2, FLOOR, zc), west_basis(zc), "Far bank house")
		house_spans.append(Vector2(zc - spec.width * .5 - 1.5, zc + spec.width * .5 + 1.5))
		stats.far_houses += 1
		used += 1
		k += 1
	# Lane row: doors toward the lane, a gap where the old street comes in.
	z = Z_SOUTH + 2.4
	for spec: Dictionary in lane:
		var w: float = spec.width
		if z < 20.9 and z + w > 15.1:
			z = 20.9
		if z + w > 55.0: break
		var zc := z + w * .5
		_place_house(spec, at(BACK_U, FLOOR, zc), east_basis(zc), "Lane house")
		stats.lane_houses += 1
		z += w + rng.randf_range(.1, .5)

func _place_house(spec: Dictionary, p: Vector3, basis: Basis, label: String) -> void:
	var file: String = spec.file
	_kit(file.get_basename(), p, basis, label)
	stats.houses += 1
	stats.storeys += int(spec.storeys)
	for box: Dictionary in spec.colliders:
		var c := Vector3(box.center[0], box.center[1], box.center[2])
		var s := Vector3(box.size[0], box.size[1], box.size[2])
		_solid(label + " body", p + basis * c, s, "wood", basis)

func _lane() -> void:
	# Leaning timber poles carry a tangle of live, dead and stolen connections over the lane.
	var poles: Array[Vector3] = []
	var z := Z_SOUTH + 3.0
	while z < 56.0:
		var u := LANE_U + rng.randf_range(.1, .4) if int(z) % 2 == 0 else BACK_U - .35
		var base := at(u, FLOOR, z)
		var top := base + Vector3(rng.randf_range(-.25, .25), 7.2, rng.randf_range(-.2, .2))
		b._rod(base + Vector3.DOWN * .3, top, .11, "wood", 7)
		b._rod(top + Vector3(-.7, -.4, 0), top + Vector3(.7, -.4, 0), .05, "wood", 5)
		_solid("Utility pole", (base + top) * .5, Vector3(.24, 7.2, .24), "wood")
		# Coils of slack cable and dead transformers.
		for k in 3:
			b._ring(top + Vector3(rng.randf_range(-.3, .3), -1.2 - k * .2, .12), rng.randf_range(.18, .3), "wire", Basis(Vector3.RIGHT, rng.randf_range(-.6, .6)), .012, 12)
		if poles.size() % 2 == 1:
			b._rod(top + Vector3(.18, -1.1, .2), top + Vector3(.18, -.4, .2), .22, "pvc grey", 10)
			b._sphere(top + Vector3(.5, -1.0, -.2), Vector3(.1, .1, .1), "rust", 6)
		poles.append(top)
		z += rng.randf_range(10.5, 13.0)
	for i in poles.size() - 1:
		for k in 7:
			var off := Vector3(rng.randf_range(-.7, .7), -.4 - rng.randf() * .4, 0)
			_wire(poles[i] + off, poles[i + 1] + Vector3(rng.randf_range(-.7, .7), -.4 - rng.randf() * .4, 0), rng.randf_range(.4, 1.3))
	# Service drops to the houses on both sides, some cut and hanging into the lane.
	for i in poles.size():
		for k in 6:
			var zz: float = poles[i].z + rng.randf_range(-6, 6)
			var house_side := rng.randf() < .5
			var end := at(LANE_U - .2 if house_side else BACK_U + .2, FLOOR + rng.randf_range(2.4, 4.6), zz)
			if rng.randf() < .15:
				var cut := poles[i].lerp(end, .55)
				_wire(poles[i] + Vector3(0, -.5, 0), cut, .3)
				b._tube([cut, cut + Vector3(.1, -1.2, .1), cut + Vector3(.05, -2.6, .3)], .008, "wire", 4)
			else:
				_wire(poles[i] + Vector3(rng.randf_range(-.5, .5), -.5, 0), end, rng.randf_range(.2, .7))
	_hanging_wires_over_river()
	# The lane itself: litter, abandoned furniture, a stripped tricycle and a rotten basketball hoop.
	var spots := 0
	z = Z_SOUTH + 2.0
	while z < 56.0:
		# Junk keeps to the lane edges; the middle stays a walkable (if filthy) line.
		var u := rng.randf_range(LANE_U + .2, 13.7) if rng.randf() < .5 else rng.randf_range(15.7, BACK_U - .4)
		var p := at(u, ground(u, z), z)
		var roll := rng.randf()
		if roll < .32:
			_kit("litter_a" if rng.randf() < .5 else "litter_b", p, Basis(Vector3.UP, rng.randf() * TAU), "Lane litter")
		elif roll < .48:
			_kit(["heap_small_a", "heap_small_b", "heap_medium_a"][rng.randi() % 3], p, Basis(Vector3.UP, rng.randf() * TAU), "Lane rubbish")
		elif roll < .58:
			_model("res://assets/models/canal/trashbag/trashbag.gltf", p, rng.randf_range(.75, 1.0), rng.randf() * 360, "Split sack")
		elif roll < .66:
			_model("street/plastic_monobloc_chair_01", p, .9, rng.randf() * 360, "Broken chair", false, Vector3(rng.randf_range(-90, 90) if rng.randf() < .5 else 0, 0, 0))
		elif roll < .74:
			_model("street/oil_drum", p, .8, rng.randf() * 360, "Rusted drum", true)
		elif roll < .8:
			_kit("mattress", p, Basis(Vector3.UP, rng.randf() * TAU), "Rotting mattress")
		elif roll < .86:
			_kit("cabinet", p, Basis(Vector3.UP, rng.randf() * TAU), "Rotten cabinet")
		else:
			_model("res://assets/models/canal/wooden_crate_01/wooden_crate_01.gltf", p, .8, rng.randf() * 360, "Broken crate", true)
		stats.rubbish += 1
		spots += 1
		z += rng.randf_range(1.0, 2.6)
	_model("street/tricycle_b", at(15.9, FLOOR, 34.0), 1.0, 170, "Stripped tricycle", true, Vector3(0, 0, 7))
	var hoop := at(BACK_U - .25, FLOOR, 41.5)
	b._rod(hoop, hoop + Vector3(0, 3.4, 0), .05, "rust", 7)
	b._rod(hoop + Vector3(0, 3.0, 0), hoop + Vector3(-.5, 3.1, 0), .03, "rust", 5)
	_box("Hoop backboard", hoop + Vector3(-.55, 3.25, 0), Vector3(.04, .75, 1.05), "wood grey", false, "wood", Basis(Vector3.FORWARD, .12))
	b._ring(hoop + Vector3(-.82, 2.92, 0), .22, "rust", Basis(Vector3.RIGHT, PI * .5).rotated(Vector3.FORWARD, .35), .01, 14)
	_solid("Hoop pole", hoop + Vector3(0, 1.7, 0), Vector3(.12, 3.4, .12), "metal")
	_decal(hoop + Vector3(-.58, 3.25, 0), Vector3(-1, 0, 0), .8)
	# Tin-sheet fences fill the gaps between lane houses; a few graffiti-covered boards.
	z = Z_SOUTH + 2.0
	while z < 55.0:
		if z > 14.6 and z < 21.4:
			z = 21.4
		var p := at(BACK_U + rng.randf_range(.05, .2), FLOOR, z)
		var height := rng.randf_range(1.7, 2.4)
		_box("Tin fence sheet", p + Vector3(0, height * .5, 0), Vector3(.03, height, rng.randf_range(.75, .9)), "roof" if rng.randf() < .7 else "tin", false, "metal", Basis(Vector3.FORWARD, rng.randf_range(-.06, .06)) * east_basis(z))
		z += rng.randf_range(.7, .85)
	for i in 14:
		var zz := rng.randf_range(Z_SOUTH + 3, 54)
		if absf(zz - 18) < 3.5: continue
		_decal(at(BACK_U, FLOOR + rng.randf_range(.6, 1.5), zz), Vector3(-1, 0, 0), rng.randf_range(.8, 1.6))
	_lane_details()

## 0.18: finer clutter in the lane, from its own random stream so the 0.17 layout stays put: washing strung
## between the house rows, and pails, basins, bottles and crates that are real rigid bodies (loose_props.gd).
func _lane_details() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 18018
	for z: float in [4.5, 11.0, 26.5, 33.5, 45.0, 51.0]:
		var a := at(LANE_U - .05, FLOOR + r.randf_range(2.4, 2.8), z)
		var c := at(BACK_U + .05, FLOOR + r.randf_range(2.3, 2.7), z + r.randf_range(-.6, .6))
		var sag := r.randf_range(.25, .45)
		b._tube([a, a.lerp(c, .5) + Vector3.DOWN * sag, c], .005, "wire", 3)
		var count := r.randi_range(3, 6)
		for j in count:
			var t := (j + r.randf_range(.2, .8)) / count
			var p := a.lerp(c, t) + Vector3.DOWN * sin(t * PI) * sag
			var q := p + (c - a).normalized() * r.randf_range(.25, .5)
			var drop := r.randf_range(.35, .8)
			b._quad([p, q, q + Vector3(.02, -drop, .03), p + Vector3(-.02, -drop * r.randf_range(.8, 1.1), .02)], Vector3.FORWARD, "cloth %d" % (r.randi() % 4))
	var plastic := ["plastic blue", "plastic red", "plastic green", "plastic yellow", "plastic white"]
	var z := Z_SOUTH + 2.5
	while z < 55.0:
		if absf(z - 18.4) > 2.6:
			var u := r.randf_range(LANE_U + .15, 13.4) if r.randf() < .5 else r.randf_range(16.2, BACK_U - .35)
			var xf := Transform3D(Basis(Vector3.UP, r.randf() * TAU), at(u, ground(u, z) + .04, z))
			match r.randi() % 5:
				0: InteriorLooseProps.bucket(self, xf, b._materials[plastic[r.randi() % 5]], b._materials["inside"], b._materials["wire"])
				1: InteriorLooseProps.basin(self, xf, b._materials[plastic[r.randi() % 5]], b._materials["inside"])
				2: InteriorLooseProps.crate(self, xf, b._materials["wood grey"])
				_:
					var tip := Basis(Vector3.RIGHT, PI * .5) if r.randf() < .6 else Basis.IDENTITY
					InteriorLooseProps.bottle(self, Transform3D(xf.basis * tip, xf.origin + Vector3.UP * .03), b._materials["glass green"])
			stats.rubbish += 1
		z += r.randf_range(2.2, 4.5)

func _hanging_wires_over_river() -> void:
	# Lines strung across the ravine from roof to far-bank trees: a dense overhead silhouette.
	for i in 9:
		var z := rng.randf_range(Z_SOUTH + 4, 50)
		var a := at(WALL_U + rng.randf_range(.5, 3.0), FLOOR + rng.randf_range(4.5, 7.5), z)
		var c := at(-13.5 - rng.randf_range(0, 3), FLOOR + rng.randf_range(3.5, 6.0), z + rng.randf_range(-4, 4))
		_wire(a, c, rng.randf_range(1.0, 2.6))
		if rng.randf() < .35:
			# A rag or plastic bag snagged on the line.
			var p := a.lerp(c, rng.randf_range(.3, .7)) + Vector3.DOWN * 1.1
			b._plate([p, p + Vector3(.25, 0, .05), p + Vector3(.2, -.45, .1), p + Vector3(-.05, -.35, 0)], ["cloth 0", "plastic white", "tarp blue"][rng.randi() % 3])

func _wall_dressing() -> void:
	# Spray paint and painted warnings along the retaining wall, at catwalk eye level.
	var z := Z_SOUTH + 2.0
	while z < CAT_END - 1:
		var roll := rng.randf()
		var p := at(WALL_U - .04, CATWALK + rng.randf_range(.8, 1.9), z)
		var normal := east_basis(z).x
		if roll < .55:
			_decal(p, normal, rng.randf_range(.8, 1.7))
		elif roll < .7:
			_decal(p, normal, rng.randf_range(1.4, 2.0), decal_names.filter(func(n: String) -> bool: return n.begins_with("sign")).pick_random() if decal_names.size() > 0 else "")
		z += rng.randf_range(1.5, 3.2)
	# Broken rock and concrete slabs heaped against the foot of the wall.
	z = Z_SOUTH + 1.0
	while z < Z_NORTH - 2:
		var u := rng.randf_range(4.3, 5.4)
		_model("fields/rock_moss_set" if rng.randf() < .5 else "fields/boulder", at(u, ground(u, z) - .15, z), rng.randf_range(.3, .6), rng.randf() * 360, "Wall foot rock")
		z += rng.randf_range(2.0, 4.5)
	# Ferns and vines rooted in the cracks; slime-green drain stains.
	z = Z_SOUTH + 1.0
	while z < CAT_END:
		if rng.randf() < .55:
			_model("fields/fern", at(WALL_U - .25, ground(WALL_U - .25, z), z), rng.randf_range(.35, .7), rng.randf() * 360, "Fern in wall")
		if rng.randf() < .45:
			_vine(at(WALL_U - .06, FLOOR - .05, z), east_basis(z).x)
		z += rng.randf_range(1.2, 2.6)

func _vine(p: Vector3, out: Vector3) -> void:
	for strand in rng.randi_range(3, 6):
		var prev := p + Vector3(0, rng.randf_range(-.15, .1), strand * .12)
		for j in rng.randi_range(8, 22):
			var next := prev + out * rng.randf_range(-.01, .03) + Vector3(0, -.12, rng.randf_range(-.06, .06))
			b._rod(prev, next, .005, "wood", 4)
			for leaf in 2:
				var side := -1.0 if (j + leaf) % 2 else 1.0
				var at_ := prev.lerp(next, .3 + leaf * .5)
				var tip := at_ + out * rng.randf_range(.02, .06) + Vector3(0, -.05, side * rng.randf_range(.05, .08))
				var mid := at_.lerp(tip, .5)
				var across := Vector3(0, .035, 0)
				b._plate([at_, mid - across + out * .01, tip, mid + across + out * .01], "leaf")
			prev = next

# ------------------------------------------------------------------------------------------------ rubbish

func _rubbish() -> void:
	# The rubble bank under the catwalk is one long dump.
	var z := Z_SOUTH + 1.0
	while z < Z_NORTH - 2:
		var u := rng.randf_range(3.95, 5.2)
		var p := at(u, ground(u, z) - .05, z)
		var pick: String = ["heap_medium_a", "heap_medium_b", "heap_small_a", "heap_small_b", "rubble_a", "litter_a"][rng.randi() % 6]
		_kit(pick, p, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-.25, .25)), "Bank rubbish")
		stats.rubbish += 1
		z += rng.randf_range(1.2, 2.8)
	# Rafts of floating rubbish caught along both banks, at stilts and in the bends.
	z = Z_SOUTH + 1.0
	while z < Z_NORTH - 1:
		var u := rng.randf_range(2.6, 3.6) if rng.randf() < .6 else rng.randf_range(-5.0, -3.6)
		_kit(["floating_a", "floating_b", "floating_c"][rng.randi() % 3], at(u, WATER + .005, z), Basis(Vector3.UP, rng.randf_range(-.3, .3) + PI * .5), "Floating rubbish")
		stats.rubbish += 1
		z += rng.randf_range(2.5, 6.0)
	for i in 70:
		var p := at(rng.randf_range(-4.5, 3.4), WATER + .01, rng.randf_range(Z_SOUTH, Z_NORTH))
		# 0.60: floating cups, bottles, bags and boxes (the same rng calls as the 0.17 blobs, so the rest stays put).
		if rng.randf() < .5:
			var _sz := Vector3(rng.randf_range(.15, .3), .08, rng.randf_range(.12, .25))
			var _m: int = rng.randi() % 4
			trash.floating(Vector3(p.x, WATER + .01, p.z), .5, 3)
		else:
			var _d := Vector3(rng.randf_range(-.25, .25), 0, rng.randf_range(-.25, .25))
			var _m: int = rng.randi() % 2
			trash.floating(Vector3(p.x, WATER + .01, p.z), .35, 2)
	# The far bank: dumped bags and heaps along the path, rubble and a mattress at the waterline.
	z = Z_SOUTH + 1.5
	while z < 55:
		var u := rng.randf_range(-12.5, -8.2) if rng.randf() < .65 else rng.randf_range(-6.0, -5.3)
		if absf(z - 31.0) < 3.0 and u > -11.5:
			z += 3.0
			continue
		var p := at(u, ground(u, z) - .04, z)
		var pick: String = ["heap_large_a", "heap_large_b", "heap_medium_a", "heap_medium_b", "litter_b", "rubble_b", "mattress", "heap_small_a"][rng.randi() % 8]
		_kit(pick, p, Basis(Vector3.UP, rng.randf() * TAU), "Far bank rubbish")
		stats.rubbish += 1
		if rng.randf() < .3:
			_model("res://assets/models/canal/trashbag/trashbag.gltf", at(u + .8, ground(u + .8, z + .6), z + .6), rng.randf_range(.8, 1.1), rng.randf() * 360, "Split sack")
		z += rng.randf_range(1.4, 3.4)
	for i in 30:
		var zz := rng.randf_range(Z_SOUTH + 1, 56)
		var u := rng.randf_range(-7.8, -6.4)
		_kit("litter_a" if i % 2 else "litter_b", at(u, ground(u, zz) - .02, zz), Basis(Vector3.UP, rng.randf() * TAU), "Path litter")

## 0.60: litter drifted where litter collects: along both edges of the lane against the house fronts, at the
## foot of the wall on the catwalk, along the far-bank path, and in knots around the heaps.
func _trash_drift() -> void:
	var r := trash.rng
	var z := Z_SOUTH + 2.0
	while z < 56.0:
		var z2 := minf(z + 4.0, 56.0)
		for u in [LANE_U + .3, BACK_U - .3]:
			trash.line(at(u, FLOOR, z), at(u, FLOOR, z2), 3.4, .45)
		if r.randf() < .8:
			var u := r.randf_range(LANE_U + .5, BACK_U - .5)
			trash.cluster(at(u, FLOOR, r.randf_range(z, z2)), r.randf_range(.4, 1.0), r.randi_range(6, 16))
		# Loose pieces across the whole lane: kicked about, blown, trodden flat.
		for k in 7:
			var u := r.randf_range(LANE_U + .2, BACK_U - .2)
			trash.add(trash._pick(InteriorTrash.STREET_MIX), at(u, FLOOR, r.randf_range(z, z2)))
		z = z2
	z = Z_SOUTH + 1.0
	while z < CAT_END - 1.0:
		var z2 := minf(z + 3.0, CAT_END - 1.0)
		trash.line(at(5.25, CATWALK, z), at(5.25, CATWALK, z2), 1.8, .22)
		z = z2
	z = Z_SOUTH + 2.0
	while z < 55.0:
		var z2 := minf(z + 3.0, 55.0)
		trash.line(at(-7.7, path_y(z), z), at(-7.7, path_y(z2), z2), 2.2, .45)
		trash.line(at(-6.45, path_y(z), z), at(-6.45, path_y(z2), z2), 1.4, .25)
		z = z2
	# The rubble bank under the catwalk and the far bank: loose pieces between the heaps.
	for i in 90:
		var zz := r.randf_range(Z_SOUTH + 1.0, Z_NORTH - 2.0)
		var u := r.randf_range(3.95, 5.1)
		trash.cluster(at(u, ground(u, zz), zz), .5, r.randi_range(2, 6))
	for i in 50:
		var zz := r.randf_range(Z_SOUTH + 1.5, 54.0)
		var u := r.randf_range(-12.0, -8.3)
		trash.cluster(at(u, ground(u, zz), zz), .6, r.randi_range(3, 8))

# ------------------------------------------------------------------------------------------------ flora

func _occupied(z: float) -> bool:
	for span in house_spans:
		if z > span.x and z < span.y: return true
	return false

func _flora() -> void:
	# The far bank is overgrown: tall trees leaning over the water, bananas, bamboo, shrubs and ferns.
	var z := Z_SOUTH + 1.0
	while z < Z_NORTH - 1.0:
		if not _occupied(z) and absf(z - BRIDGE_Z) > 4.5:
			var u := rng.randf_range(-15.5, -13.6)
			var pick: String = ["nature/island_tree_01", "nature/island_tree_02", "nature/tree_small_02", "nature/island_tree_02"][rng.randi() % 4]
			_model(pick, at(u, ground(u, z) - .1, z), rng.randf_range(.75, 1.05), rng.randf() * 360, "Bank tree", false, Vector3(0, 0, rng.randf_range(-8, 2)))
		z += rng.randf_range(5.0, 8.0)
	z = Z_SOUTH + 1.0
	while z < Z_NORTH - 1:
		var u := rng.randf_range(-27, -14.5)
		var gate_path := u < -15.0 and (absf(z - WARREN.ENTRY_Z) < 1.8 or absf(z - WARREN.EXIT_Z) < 1.8)
		if not (_occupied(z) and u > -21) and not (absf(z - BRIDGE_Z) < 4.0 and u > -20) and not gate_path:
			var roll := rng.randf()
			var p := at(u, ground(u, z) - .05, z)
			if roll < .25: _model("nature/banana_plant", p, rng.randf_range(.7, 1.0), rng.randf() * 360, "Banana plant")
			elif roll < .4: _model("fields/bamboo_clump", p, rng.randf_range(.6, .9), rng.randf() * 360, "Bamboo clump")
			elif roll < .6: _model("nature/shrub_02", p, rng.randf_range(.8, 1.3), rng.randf() * 360, "Shrub")
			elif roll < .72: _model("nature/island_tree_01", p, rng.randf_range(.8, 1.1), rng.randf() * 360, "Back tree")
			elif roll < .8: _model("fields/dead_trunk_b", p, rng.randf_range(.7, 1.0), rng.randf() * 360, "Dead trunk")
			elif roll < .88: _model("nature/palm_coconut_a", p, rng.randf_range(.8, 1.0), rng.randf() * 360, "Coconut palm tree")
			else: _model("nature/banana_small", p, rng.randf_range(.7, 1.0), rng.randf() * 360, "Banana plant")
		z += rng.randf_range(1.6, 3.4)
	# Slope growth, reeds and cattails at the waterline.
	z = Z_SOUTH + .5
	while z < Z_NORTH - 1:
		var u := rng.randf_range(-12.5, -8.4)
		if rng.randf() < .7:
			_model("fields/fern", at(u, ground(u, z) - .03, z), rng.randf_range(.5, .95), rng.randf() * 360, "Fern slope plant")
		if rng.randf() < .45:
			var w := rng.randf_range(-5.4, -4.6)
			_model("fields/reeds" if rng.randf() < .6 else "fields/cattails", at(w, ground(w, z) - .05, z), rng.randf_range(.6, .9), rng.randf() * 360, "Reed water plant")
		if rng.randf() < .2:
			var w := rng.randf_range(3.4, 3.9)
			_model("fields/reeds", at(w, ground(w, z) - .05, z), rng.randf_range(.5, .8), rng.randf() * 360, "Reed water plant")
		z += rng.randf_range(.9, 2.0)
	for i in 5:
		var zz := rng.randf_range(Z_SOUTH + 3, 50)
		_model("fields/fallen_trunk" if i % 2 else "fields/root_cluster", at(-5.2, ground(-5.2, zz) - .1, zz), rng.randf_range(.6, .9), rng.randf_range(-30, 30), "Snag in river")
	# Wind-driven weeds over the slopes and the lane edges.
	var builder := InteriorFieldsBuilder.new()
	var mesh := builder._blade_clump(7, 0, .024, .25, 1717)
	var material := ShaderMaterial.new()
	material.shader = load("res://scripts/field_blades.gdshader")
	material.set_shader_parameter("sway", .1)
	material.set_shader_parameter("tip_color", Color(.25, .31, .14))
	material.set_shader_parameter("root_color", Color(.05, .07, .03))
	var count := 2600
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = count
	for i in count:
		var zz := rng.randf_range(Z_SOUTH, Z_NORTH)
		var roll := rng.randf()
		var u := rng.randf_range(-28, -6.4) if roll < .75 else (rng.randf_range(BACK_U - .6, BACK_U) if roll < .87 else rng.randf_range(LANE_U - .3, LANE_U + .2))
		if u > -7.9 and u < -6.3 and rng.randf() < .8: u -= 1.8  # keep the footpath trodden bare
		var p := at(u, ground(u, zz), zz)
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(.3, .85)), p))
		mm.set_instance_custom_data(i, Color(rng.randf(), 1, rng.randf() * 6, .2))
	var grass := MultiMeshInstance3D.new()
	grass.name = "Windblown bank weeds"
	grass.multimesh = mm
	grass.material_override = material
	grass.layers = 2
	add_child(grass)

func _bounds() -> void:
	# Patched fences and walls bound the settlement; nothing invisible except the river ends.
	var z := Z_SOUTH
	while z < Z_NORTH:
		var z2 := z + 2.5
		for u in [-28.5, 23.5]:
			if u > 0 and z < 21 and z2 > 15: continue
			# 0.18: the warren's pried tin sheets replace two fence panels (canal_warren.gd _gates).
			if u < 0 and (absf(z + 1.25 - WARREN.ENTRY_Z) < 1.3 or absf(z + 1.25 - WARREN.EXIT_Z) < 1.3): continue
			var a := at(u, FLOOR, z)
			var c := at(u, FLOOR, z2)
			_box("Boundary fence", (a + c) * .5 + Vector3.UP * 1.2, Vector3(.08, 2.4, a.distance_to(c) + .05), "roof" if rng.randf() < .6 else "tin", true, "metal", Basis(Vector3.UP, -atan(rslope(z))))
		z = z2
	for zz in [Z_SOUTH - .4, Z_NORTH + .4]:
		for span in [[-28.5, -13.0], [WALL_U, 23.5]]:
			var a := at(span[0], FLOOR, zz)
			var c := at(span[1], FLOOR, zz)
			_box("Boundary wall", (a + c) * .5 + Vector3.UP * 1.25, Vector3(c.x - a.x, 2.5, .2), "block", true, "concrete")
			for i in 3: _decal(a.lerp(c, rng.randf_range(.1, .9)) + Vector3(0, rng.randf_range(.7, 1.6), -.12 * signf(zz)), Vector3(0, 0, -signf(zz)), rng.randf_range(1.0, 1.8))
	# The street-A mouth: a wider gap in the old boundary, flanked by fence ends.
	_solid("Ravine north void", at(-4, FLOOR + 2, Z_NORTH + 1.4), Vector3(22, 12, .6), "concrete")
	_solid("Ravine south void", at(-4, FLOOR + 2, Z_SOUTH - 1.4), Vector3(22, 12, .6), "concrete")

# ------------------------------------------------------------------------------------------------ lights

func _hanging_bulb(p: Vector3, index: int, mount: String) -> void:
	if mount == "bracket":
		# An arm bolted into the retaining wall over the catwalk.
		var wall := Vector3(rx(p.z) + WALL_U, p.y + .32, p.z)
		b._rod(wall, Vector3(p.x, p.y + .32, p.z), .022, "rust", 6)
		b._rod(wall + Vector3.DOWN * .35, Vector3(lerpf(wall.x, p.x, .5), p.y + .32, p.z), .015, "rust", 5)
		_wire(wall + Vector3(0, .1, .1), wall + Vector3(0, 2.2, .3), .05)
	else:
		_wire(at(LANE_U - .2, FLOOR + 3.6, p.z - .4), at(BACK_U + .2, FLOOR + 3.5, p.z + .3), .25)
	var pivot := Node3D.new()
	pivot.name = "Swinging bulb %d" % index
	pivot.position = p + Vector3.UP * .32
	add_child(pivot)
	var cord := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = .006
	cylinder.bottom_radius = .006
	cylinder.height = .3
	cylinder.radial_segments = 5
	cord.mesh = cylinder
	cord.material_override = b._materials["wire"]
	cord.position.y = -.15
	cord.layers = 2
	pivot.add_child(cord)
	var socket := MeshInstance3D.new()
	var socket_mesh := CylinderMesh.new()
	socket_mesh.top_radius = .024
	socket_mesh.bottom_radius = .03
	socket_mesh.height = .06
	socket.mesh = socket_mesh
	socket.material_override = b._materials["rust"]
	socket.position.y = -.31
	socket.layers = 2
	pivot.add_child(socket)
	# A rusted wire cage around the bulb.
	var cage := MeshInstance3D.new()
	var cage_mesh := CylinderMesh.new()
	cage_mesh.top_radius = .05
	cage_mesh.bottom_radius = .06
	cage_mesh.height = .14
	cage_mesh.radial_segments = 8
	cage.mesh = cage_mesh
	cage.material_override = b._materials["chain"]
	cage.position.y = -.39
	cage.layers = 2
	pivot.add_child(cage)
	_bulb(pivot, Vector3(0, -.39, 0), index, Color(1, .62, .3), 4.6 if mount == "bracket" else 7.5, .8 if mount == "bracket" else 1.25)

func _bulb(parent: Node3D, offset: Vector3, index: int, color: Color, reach: float, energy := .8) -> void:
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = .04
	sphere.height = .1
	sphere.radial_segments = 10
	sphere.rings = 5
	bulb.mesh = sphere
	bulb.position = offset
	bulb.layers = 2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(.7, .6, .4)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	bulb.material_override = mat
	parent.add_child(bulb)
	var light := OmniLight3D.new()
	light.position = offset + Vector3.DOWN * .04
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.7
	light.light_cull_mask = 2
	light.shadow_enabled = index < 2
	parent.add_child(light)
	bulbs.append({"pivot": parent, "light": light, "material": mat, "phase": index * 1.77, "energy": energy, "kind": "bulb"})

func _bridge_lamp(base: Vector3, index: int) -> void:
	# A bent street-light pole on the parapet; its sodium lamp barely holds on.
	var top := base + Vector3(.15, 5.2, 0)
	b._rod(base, top, .07, "rust", 8)
	b._rod(top, top + Vector3(.2, .25, 1.2), .05, "rust", 7)
	var head := top + Vector3(.2, .2, 1.3)
	_box("Lamp head", head, Vector3(.28, .1, .55), "rust")
	_solid("Lamp pole", base + Vector3(0, 2.6, 0), Vector3(.16, 5.2, .16), "metal")
	var holder := Node3D.new()
	holder.name = "Bridge lamp"
	holder.position = head
	add_child(holder)
	_bulb(holder, Vector3(0, -.08, 0), index, Color(1, .58, .25), 9.0, 1.4)
	bulbs[-1]["kind"] = "lamp"

func _shrine(p: Vector3, index: int) -> void:
	# A roadside shrine box on a post: a faded framed picture and one votive candle still burning.
	var post := p + Vector3(-.3, 0, 0)
	b._rod(post + Vector3.DOWN * .3, post + Vector3.UP * 1.05, .045, "wood", 6)
	_box("Shrine box", post + Vector3(0, 1.3, 0), Vector3(.42, .5, .5), "wood grey")
	_box("Shrine dark", post + Vector3(.2, 1.3, 0), Vector3(.02, .42, .42), "inside")
	_box("Shrine roof", post + Vector3(.02, 1.6, 0), Vector3(.55, .04, .62), "roof", false, "metal", Basis(Vector3.FORWARD, .2))
	_box("Shrine picture", post + Vector3(.08, 1.36, 0), Vector3(.02, .26, .2), "paper")
	_solid("Shrine", post + Vector3(0, .9, 0), Vector3(.45, 1.8, .5), "wood")
	var holder := Node3D.new()
	holder.name = "Votive candle"
	holder.position = post + Vector3(.12, 1.1, 0)
	add_child(holder)
	var glass := MeshInstance3D.new()
	var cup := CylinderMesh.new()
	cup.top_radius = .035
	cup.bottom_radius = .03
	cup.height = .1
	glass.mesh = cup
	glass.material_override = b._materials["candle glass"]
	glass.position.y = .05
	glass.layers = 2
	holder.add_child(glass)
	_bulb(holder, Vector3(0, .09, 0), index, Color(1, .32, .14), 2.6, .55)
	bulbs[-1]["kind"] = "candle"
	_decal(p + Vector3(-.15, .4, .9), Vector3(1, 0, 0), .9)

func _mist_and_reflections() -> void:
	# Faint mist lying in the ravine (volumetric fog only on desktop tiers that enable it).
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		var fog := FogVolume.new()
		fog.name = "Ravine mist"
		fog.size = Vector3(16, 2.2, Z_NORTH - Z_SOUTH)
		fog.position = Vector3(rx(27) + 0.5, WATER + .9, (Z_NORTH + Z_SOUTH) * .5)
		var fm := FogMaterial.new()
		fm.density = .045
		fm.albedo = Color(.55, .6, .65)
		fm.height_falloff = 1.6
		fm.edge_fade = .5
		fog.material = fm
		add_child(fog)
	# Box-projected probes give the water real reflections of the houses, bulbs and sky.
	for zc in [-2.0, 26.0, 54.0]:
		var probe := ReflectionProbe.new()
		probe.name = "River reflections"
		probe.position = Vector3(rx(zc), WATER + 1.4, zc)
		probe.size = Vector3(30, 20, 30)
		probe.origin_offset = Vector3(0, 0, 0)
		probe.box_projection = true
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		probe.intensity = .9
		probe.max_distance = 80
		probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
		add_child(probe)

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	elapsed += delta
	var gust := .5 + .5 * sin(elapsed * .31)
	var scene := get_tree().current_scene
	if not is_instance_valid(lighting) and scene != null: lighting = InteriorLighting.find_in(scene)
	if lighting != null and lighting.tier != light_tier:
		light_tier = lighting.tier
		for i in bulbs.size(): bulbs[i].light.shadow_enabled = i < 2 and light_tier >= 2
	if scene != null:
		var audio := scene.get_node_or_null("NightAudio")
		if audio != null and "_gust_time" in audio and audio._gust_time >= 0:
			gust = maxf(gust, sin(clampf(audio._gust_time / audio._gust_length, 0, 1) * PI))
	for i in bulbs.size():
		var item := bulbs[i]
		var phase: float = item.phase
		var base: float = item.energy
		var energy := base
		match item.kind:
			"bulb":
				item.pivot.rotation.z = sin(elapsed * 1.63 + phase) * (.035 + .07 * gust)
				item.pivot.rotation.x = sin(elapsed * 1.19 + phase) * .038
				var cycle := fmod(elapsed + phase * 7.0, 17.0 + i * 3.1)
				if cycle < 1.4:
					energy = base * (.05 if sin(elapsed * 43 + phase) > -.2 else .7)
				elif i == 2 and cycle < 6.0:
					energy = 0.0
			"lamp":
				# Mostly dead: a few weak pulses, then darkness for a long while.
				var cycle := fmod(elapsed + 3.0, 23.0)
				energy = base * (.5 + .5 * sin(elapsed * 31.0)) if cycle < 2.6 else (base * .25 if cycle < 3.4 else 0.0)
			"candle":
				energy = base * (.82 + .12 * sin(elapsed * 9.1 + phase) + .06 * sin(elapsed * 23.7))
		item.light.light_energy = energy
		item.material.emission_energy_multiplier = energy * 3.8

## The town's street-level ground slab used to run under this whole area; the ravine needs a hole in it.
const HOLE := Rect2(-123.5, -18.5, 88.1, 91.0)

func _open_connection(town: Node3D) -> void:
	var old := town.get_node("NeighbourhoodColliders")
	for child in old.get_children():
		if not child is CollisionShape3D: continue
		if child.shape is BoxShape3D and str(child.name).begins_with("Ground"):
			_split_ground(old, child as CollisionShape3D)
		elif child.shape is ConvexPolygonShape3D and not child.disabled:
			# Kerbs along the streets run west into the hole: cut them off at its east edge.
			var shape := child.shape as ConvexPolygonShape3D
			var pts: PackedVector3Array = shape.points
			var box := AABB(child.transform * pts[0], Vector3.ZERO)
			for q in pts: box = box.expand(child.transform * q)
			if box.position.y < 0 and box.position.x < HOLE.end.x and box.end.z > HOLE.position.y and box.position.z < HOLE.end.y:
				if box.end.x <= HOLE.end.x:
					child.disabled = true
				else:
					var cut := PackedVector3Array()
					var inverse: Transform3D = child.transform.affine_inverse()
					for q in pts:
						var w: Vector3 = child.transform * q
						w.x = maxf(w.x, HOLE.end.x)
						cut.append(inverse * w)
					var trimmed := ConvexPolygonShape3D.new()
					trimmed.points = cut
					child.shape = trimmed
		if str(child.name).begins_with("Bound edge west"):
			child.disabled = true
			_solid("West boundary south of opening", Vector3(-24.5, 2, -1.5), Vector3(1, 12, 33), "concrete")
			_solid("West boundary north of opening", Vector3(-24.5, 2, 37.5), Vector3(1, 12, 35), "concrete")
		if str(child.name).begins_with("Barricade") and child.position.x < -22 and absf(child.position.z - 18) < 4:
			child.disabled = true
	# Remove only the west street-A barricade triangles from the two shared stripe batches.
	for child in town.get_children():
		if not child is MeshInstance3D or not "sd stripe" in str(child.name): continue
		var replacement := ArrayMesh.new()
		for s in child.mesh.get_surface_count():
			var arrays: Array = child.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var kept := PackedInt32Array()
			for j in range(0, indices.size(), 3):
				var center: Vector3 = (verts[indices[j]] + verts[indices[j + 1]] + verts[indices[j + 2]]) / 3
				if center.x < -22 and center.x > -24.2 and absf(center.z - 18) < 3.3: continue
				for k in 3: kept.append(indices[j + k])
			if not kept.is_empty():
				arrays[Mesh.ARRAY_INDEX] = kept
				replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				replacement.surface_set_material(replacement.get_surface_count() - 1, child.get_active_material(s))
		child.mesh = replacement
	for child in town.get_children():
		if child is MeshInstance3D and child != self:
			_carve_mesh(child as MeshInstance3D)
	# The original scenery trees outside the old playable fence must not grow through the settlement.
	var models := town.get_node_or_null("Models")
	if models != null:
		for model in models.get_children():
			if model is Node3D and model.position.x < -35 and model.position.x > -123.5 and model.position.z > -20 and model.position.z < 74:
				model.visible = false

## Replaces a ground box that overlaps the hole with up to four boxes around it (same top, same depth).
func _split_ground(parent: Node, c: CollisionShape3D) -> void:
	var size: Vector3 = (c.shape as BoxShape3D).size
	var lo := Vector2(c.position.x - size.x * .5, c.position.z - size.z * .5)
	var hi := Vector2(c.position.x + size.x * .5, c.position.z + size.z * .5)
	var h0 := HOLE.position
	var h1 := HOLE.end
	if hi.x <= h0.x or lo.x >= h1.x or hi.y <= h0.y or lo.y >= h1.y: return
	c.disabled = true
	if c.get_parent() == null: return
	var pieces: Array[Rect2] = []
	if lo.y < h0.y: pieces.append(Rect2(lo.x, lo.y, hi.x - lo.x, h0.y - lo.y))
	if hi.y > h1.y: pieces.append(Rect2(lo.x, h1.y, hi.x - lo.x, hi.y - h1.y))
	var zlo := maxf(lo.y, h0.y)
	var zhi := minf(hi.y, h1.y)
	if lo.x < h0.x: pieces.append(Rect2(lo.x, zlo, h0.x - lo.x, zhi - zlo))
	if hi.x > h1.x: pieces.append(Rect2(h1.x, zlo, hi.x - h1.x, zhi - zlo))
	for r in pieces:
		var piece := CollisionShape3D.new()
		piece.name = str(c.name) + " around canal"
		var box := BoxShape3D.new()
		box.size = Vector3(r.size.x, size.y, r.size.y)
		piece.shape = box
		piece.position = Vector3(r.get_center().x, c.position.y, r.get_center().y)
		for key in c.get_meta_list(): piece.set_meta(key, c.get_meta(key))
		parent.add_child(piece)

## Cuts the hole (or `hole`: 0.22, the Nichols cellar) out of a street-level town mesh. Triangles straddling the edge are clipped exactly,
## with their attributes interpolated, so the town ground meets the ravine terrain without gaps.
func _carve_mesh(mi: MeshInstance3D, hole := HOLE) -> void:
	if mi.mesh == null or not mi.mesh is ArrayMesh: return
	var box := mi.global_transform * mi.get_aabb()
	if box.position.y > 0.0 or box.end.x < hole.position.x or box.position.x > hole.end.x or box.end.z < hole.position.y or box.position.z > hole.end.y:
		return
	var xf := mi.global_transform
	var replacement := ArrayMesh.new()
	var changed := false
	for s in mi.mesh.get_surface_count():
		var arrays: Array = mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			indices.resize(verts.size())
			for i in verts.size(): indices[i] = i
		var kept := PackedInt32Array()
		var extra: Array = []
		var surface_changed := false
		for j in range(0, indices.size(), 3):
			var t := [indices[j], indices[j + 1], indices[j + 2]]
			var p0: Vector3 = xf * verts[t[0]]
			var p1: Vector3 = xf * verts[t[1]]
			var p2: Vector3 = xf * verts[t[2]]
			var mn := Vector2(minf(p0.x, minf(p1.x, p2.x)), minf(p0.z, minf(p1.z, p2.z)))
			var mx := Vector2(maxf(p0.x, maxf(p1.x, p2.x)), maxf(p0.z, maxf(p1.z, p2.z)))
			if (p0.y + p1.y + p2.y) / 3.0 > 0.0 or mx.x <= hole.position.x or mn.x >= hole.end.x or mx.y <= hole.position.y or mn.y >= hole.end.y:
				kept.append(t[0])
				kept.append(t[1])
				kept.append(t[2])
				continue
			surface_changed = true
			# Barycentric weights travel with each corner so every attribute can be rebuilt.
			var poly: Array = [[p0, Vector3(1, 0, 0)], [p1, Vector3(0, 1, 0)], [p2, Vector3(0, 0, 1)]]
			for piece: Array in _outside_pieces(poly, hole):
				if piece.size() >= 3: extra.append([t, piece])
		if not surface_changed:
			replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			replacement.surface_set_material(replacement.get_surface_count() - 1, mi.mesh.surface_get_material(s))
			continue
		changed = true
		var out := arrays.duplicate()
		for a in Mesh.ARRAY_MAX:
			if a != Mesh.ARRAY_INDEX and out[a] != null: out[a] = out[a].duplicate()
		for item: Array in extra:
			var t: Array = item[0]
			var piece: Array = item[1]
			var base := (out[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			for corner: Array in piece:
				var w: Vector3 = corner[1]
				for a in Mesh.ARRAY_MAX:
					if a == Mesh.ARRAY_INDEX or out[a] == null: continue
					out[a] = _append_interp(out[a], arrays[a], t, w, a)
			for k in range(1, piece.size() - 1):
				kept.append(base)
				kept.append(base + k)
				kept.append(base + k + 1)
		out[Mesh.ARRAY_INDEX] = kept
		replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
		replacement.surface_set_material(replacement.get_surface_count() - 1, mi.mesh.surface_get_material(s))
	if changed:
		var mats: Array[Material] = []
		for s in mi.get_surface_override_material_count(): mats.append(mi.get_surface_override_material(s))
		mi.mesh = replacement
		for s in mats.size(): mi.set_surface_override_material(s, mats[s])

func _append_interp(dst: Variant, src: Variant, t: Array, w: Vector3, kind: int) -> Variant:
	match kind:
		Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL:
			var a := src as PackedVector3Array
			var v: Vector3 = a[t[0]] * w.x + a[t[1]] * w.y + a[t[2]] * w.z
			if kind == Mesh.ARRAY_NORMAL: v = v.normalized()
			var d := dst as PackedVector3Array
			d.append(v)
			return d
		Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2:
			var a := src as PackedVector2Array
			var d := dst as PackedVector2Array
			d.append(a[t[0]] * w.x + a[t[1]] * w.y + a[t[2]] * w.z)
			return d
		Mesh.ARRAY_COLOR:
			var a := src as PackedColorArray
			var d := dst as PackedColorArray
			d.append(a[t[0]] * w.x + a[t[1]] * w.y + a[t[2]] * w.z)
			return d
		Mesh.ARRAY_TANGENT:
			var a := src as PackedFloat32Array
			var d := dst as PackedFloat32Array
			for k in 4:
				d.append(a[t[0] * 4 + k] * w.x + a[t[1] * 4 + k] * w.y + a[t[2] * 4 + k] * w.z)
			return d
	push_warning("Canal ground carve: unsupported array %d" % kind)
	return dst

## Pieces of a convex polygon outside HOLE: x < x0, x > x1, or between them with z < z0 or z > z1.
func _outside_pieces(poly: Array, hole := HOLE) -> Array:
	var x0 := hole.position.x
	var x1 := hole.end.x
	var middle := _clip(_clip(poly, 0, x0, false), 0, x1, true)
	return [_clip(poly, 0, x0, true), _clip(poly, 0, x1, false), _clip(middle, 2, hole.position.y, true), _clip(middle, 2, hole.end.y, false)]

## Keeps the part of `poly` with coordinate[axis] below `value` (below=true) or above it. Rows: [position, barycentric].
func _clip(poly: Array, axis: int, value: float, below: bool) -> Array:
	var result: Array = []
	if poly.size() < 3: return result
	for i in poly.size():
		var a: Array = poly[i]
		var c: Array = poly[(i + 1) % poly.size()]
		var da: float = (a[0] as Vector3)[axis] - value
		var dc: float = (c[0] as Vector3)[axis] - value
		if not below:
			da = -da
			dc = -dc
		if da <= 0: result.append(a)
		if (da < 0 and dc > 0) or (da > 0 and dc < 0):
			var f := da / (da - dc)
			result.append([(a[0] as Vector3).lerp(c[0], f), (a[1] as Vector3).lerp(c[1], f)])
	return result
