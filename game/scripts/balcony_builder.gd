class_name InteriorBalconyBuilder
extends InteriorRoomSurroundings
## Procedural balcony behind the navy entry door, the concrete stair down along the
## yellow house wall and the small courtyard at its foot (owner photos work/v4/reference/2..5),
## modelled tidy. editor/bake_balcony.gd bakes the result into res://scenes/balcony/balcony.tscn,
## which is the editable source of truth afterwards.
##
## Frame (metres, Y up): room floor y=0, house outer wall z=2.9, doorway x 1.39..2.43.
## Balcony x 0.95..5.6, z 2.9..4.55 (parapet to 4.75), ceiling 2.75. Stair x 5.6..9.65,
## z 2.9..3.85, 16 risers down to the courtyard at y=-2.9 (x 9.65..12.6, z 2.9..5.3).
## Static structure batches by material; furniture and decor are named StaticBody3D
## nodes; outdoor meshes render on layer 2 (OUTDOOR_LAYER) so only the balcony sun lights them.

const BalconyScript = preload("res://scripts/balcony.gd")
const PetSpawnerScript = preload("res://scripts/pet_spawner.gd")
const OUTDOOR_LAYER := 2
## Loose props that may be carried indoors render on both layers.
const PROP_LAYERS := 3
const X0 := .95
const X_END := 5.6
const Z_WALL := 2.9
const Z_LEDGE := 4.55
const Z_OUT := 4.75
const CEIL := 2.75
const STAIR_Z := 3.85
const RISERS := 16
const RISE := 2.9 / 16.0
const TREAD := .27
const GROUND := -2.9
const YARD_X := 9.65
const FENCE_X := 12.6
const YARD_Z := 5.3

var _root: Node3D
var _saved: Array = []
## Visual layer of committed batches (the studio builder reuses these helpers indoors on layer 1).
var visual_layer := OUTDOOR_LAYER

## Builds everything beneath `root` (a Node3D, ideally inside the tree). Returns stats.
static func build(root: Node3D) -> Dictionary:
	var builder := InteriorBalconyBuilder.new()
	builder._root = root
	builder._stats = {"triangles_added": 0, "static_batches": 0, "colliders": 0, "props": [], "features": [], "dynamic_props": 0}
	builder._build_all()
	var stats: Dictionary = builder._stats
	builder.free()
	root.set_meta("balcony_stats", stats)
	print("INTERIOR_BALCONY_BUILT ", JSON.stringify(stats))
	return stats

func _build_all() -> void:
	_root.set_script(BalconyScript)
	_root.name = "Balcony"
	_prepare_balcony_materials()
	_shell = _static_body("BalconyStructure", Vector3.ZERO)
	_build_balcony_shell()
	_build_end_wall()
	_build_house_wall()
	_build_railing()
	_build_stair()
	_build_courtyard()
	_build_neighbourhood()
	_commit(_root, "Balcony detail - ")
	_build_bounds()
	_build_props()
	_build_lights()

# ---------------------------------------------------------------- materials

func _prepare_balcony_materials() -> void:
	_lib("plaster", "warm_plaster", Color(.97, .96, .93))
	_lib("yellow", "warm_plaster", Color(.90, .76, .42))
	_lib("concrete", "warm_plaster", Color(.66, .65, .62))
	_lib("concrete dark", "warm_plaster", Color(.50, .49, .47))
	_lib("block", "warm_plaster", Color(.60, .60, .57))
	_lib("neighbour green", "warm_plaster", Color(.62, .70, .58))
	_lib("neighbour beige", "warm_plaster", Color(.80, .72, .60))
	_lib("tile", "tile_white", Color(1, 1, 1))
	_lib("navy", "navy_enamel", Color(.12, .18, .31))
	_lib("maroon", "navy_enamel", Color(.42, .11, .09))
	_lib("white steel", "white_satin", Color(.93, .93, .91))
	_lib("black metal", "black_metal", Color(.11, .105, .1))
	_lib("steel", "brushed_steel", Color(.74, .73, .71))
	_lib("roof metal", "brushed_steel", Color(.60, .62, .62))
	_lib("roof rust", "brushed_steel", Color(.52, .40, .30))
	# Without reflection probes fully metallic paint reads black outdoors; keep it satin.
	for key in ["steel", "roof metal", "roof rust"]:
		(_materials[key] as BaseMaterial3D).metallic = .2
		(_materials[key] as BaseMaterial3D).roughness = .45
	_lib("rattan", "rattan", Color(1, 1, 1))
	_lib("walnut", "walnut", Color(1, 1, 1))
	_lib("oak", "oak", Color(1, 1, 1))
	_lib("bark", "walnut", Color(.55, .48, .42))
	_lib("ceramic", "ceramic_white", Color(.95, .93, .89))
	_lib("foliage", "foliage", Color(.85, 1.0, .82))
	_lib("foliage dark", "foliage_dark", Color(.55, .7, .55))
	_lib("plastic white", "plastic_white", Color(.90, .89, .86))
	_lib("plastic black", "plastic_black", Color(.05, .05, .05))
	_lib("rubber", "rubber_black", Color(.04, .04, .04))
	_lib("doormat", "rug_wool", Color(.48, .14, .11))
	_lib("fabric dark", "fabric_brown", Color(.30, .29, .28))
	_flat("petal yellow", Color(.95, .70, .10), .7)
	_flat("sunflower centre", Color(.28, .16, .06), .9)
	_flat("petal purple", Color(.58, .40, .78), .7)
	_flat("petal pink", Color(.93, .52, .68), .7)
	_flat("shoe pink", Color(.92, .62, .70), .5)
	_flat("shoe cream", Color(.86, .80, .70), .6)
	_flat("orange pvc", Color(.90, .45, .13), .5)
	_flat("tarp orange", Color(.86, .37, .14), .8)
	_flat("tarp blue", Color(.16, .42, .78), .8)
	_flat("bottle blue", Color(.22, .52, .92), .25)
	var glass := _flat("glass dark", Color(.30, .35, .40), .22)
	glass.metallic = .15
	glass.metallic_specular = .9
	var cover := _flat("plastic cover", Color(.92, .94, .96, .45), .2)
	cover.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cover.cull_mode = BaseMaterial3D.CULL_DISABLED
	var film := _image("film", "res://assets/balcony/floral_film.png", .8)
	film.uv1_triplanar = true
	film.uv1_scale = Vector3.ONE / .6
	film.emission_enabled = true
	film.emission_texture = film.albedo_texture
	film.emission_energy_multiplier = .35
	var damask := _image("damask", "res://assets/balcony/damask.png", .9)
	damask.uv1_triplanar = true
	damask.uv1_scale = Vector3.ONE / .22
	_image("sign worthwhile", "res://assets/balcony/sign_worthwhile.png", .6)
	_image("sign loves", "res://assets/balcony/sign_loves.png", .6)
	_image("print", "res://assets/art/art_1.jpg", .7)
	var sky := StandardMaterial3D.new()
	sky.resource_name = "Balcony / sky"
	sky.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sky.vertex_color_use_as_albedo = true
	sky.cull_mode = BaseMaterial3D.CULL_DISABLED
	sky.disable_fog = true
	_materials["sky"] = sky

func _lib(key: String, library_key: String, tint: Color) -> void:
	var mat := (InteriorMaterials.material(library_key) as BaseMaterial3D).duplicate() as BaseMaterial3D
	mat.resource_name = "Balcony / " + key
	if tint != Color(1, 1, 1):
		mat.albedo_color = tint
	_materials[key] = mat

func _flat(key: String, color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = "Balcony / " + key
	mat.albedo_color = color
	mat.roughness = roughness
	_materials[key] = mat
	return mat

func _image(key: String, path: String, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = "Balcony / " + key
	mat.albedo_texture = load(path)
	mat.roughness = roughness
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_materials[key] = mat
	return mat

## Poly Haven PBR set from res://assets/outdoor/textures/<id>/ (albedo, GL normal, roughness).
## Builder UVs are in metres, so `tile` is the texture's real-world size.
func _pbr(key: String, id: String, tile: float, tint := Color(1, 1, 1), roughness := 1.0, normal := 1.0) -> StandardMaterial3D:
	var dir := "res://assets/outdoor/textures/" + id + "/"
	var mat := StandardMaterial3D.new()
	mat.resource_name = "PBR / " + key
	mat.albedo_texture = load(dir + "albedo.jpg")
	mat.albedo_color = tint
	if ResourceLoader.exists(dir + "normal.jpg"):
		mat.normal_enabled = true
		mat.normal_texture = load(dir + "normal.jpg")
		mat.normal_scale = normal
	if ResourceLoader.exists(dir + "roughness.jpg"):
		mat.roughness_texture = load(dir + "roughness.jpg")
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	mat.roughness = roughness
	mat.uv1_scale = Vector3.ONE / tile
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_materials[key] = mat
	return mat

# ---------------------------------------------------------------- batching helpers

func _static_body(label: String, at: Vector3, yaw := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = 2
	body.collision_mask = 5
	body.physics_material_override = PhysicsMaterial.new()
	body.physics_material_override.friction = .75
	_root.add_child(body)
	body.position = at
	body.rotation.y = yaw
	return body

## Geometry built between _begin_prop and _end_prop lands in its own named body,
## authored in that body's local space.
func _begin_prop(label: String, at: Vector3, yaw := 0.0) -> StaticBody3D:
	_saved.push_back([_batches, _shell])
	_batches = {}
	_shell = _static_body(label, at, yaw)
	(_stats.props as Array).append(label)
	return _shell

func _end_prop() -> void:
	_commit(_shell, "")
	var previous: Array = _saved.pop_back()
	_batches = previous[0]
	_shell = previous[1]

func _commit(parent: Node3D, prefix: String) -> void:
	for key: String in _batches:
		var tool := _batches[key] as SurfaceTool
		tool.index()
		tool.generate_tangents()
		var mesh := MeshInstance3D.new()
		mesh.name = prefix + key
		mesh.mesh = tool.commit()
		mesh.material_override = _materials[key]
		mesh.layers = visual_layer
		parent.add_child(mesh)
		if parent == _root:
			_stats.static_batches += 1
	_batches.clear()

func _plate(points: Array, key: String) -> void:
	# Double-sided quad (thin film, tarp, greenery mat).
	var normal: Vector3 = (points[1] - points[0]).cross(points[3] - points[0]).normalized()
	_quad(points, -normal, key)
	_quad([points[1], points[0], points[3], points[2]], normal, key)

func _ring(center: Vector3, radius: float, key: String, axis_basis: Basis, thickness := .006, segments := 14) -> void:
	var pts: Array = []
	for i in segments + 1:
		var a := TAU * i / segments
		pts.append(center + axis_basis * Vector3(cos(a) * radius, sin(a) * radius, 0))
	_tube(pts, thickness, key, 5)

# ---------------------------------------------------------------- structure

func _build_balcony_shell() -> void:
	_feature("Tiled balcony with roof slab behind the navy entry door")
	_box("Balcony floor slab", Vector3((X0 - .15 + X_END) * .5, -.12, (Z_WALL + Z_OUT) * .5), Vector3(X_END - X0 + .15, .24, Z_OUT - Z_WALL), "concrete", false)
	_box("Balcony tiles", Vector3((X0 + X_END) * .5, -.005, (Z_WALL + Z_LEDGE) * .5), Vector3(X_END - X0, .012, Z_LEDGE - Z_WALL), "tile", false)
	_collider("Balcony floor", Vector3((X0 - .15 + X_END) * .5, -.095, (Z_WALL + Z_OUT) * .5), Vector3(X_END - X0 + .15, .2, Z_OUT - Z_WALL))
	# Roof slab with a white soffit and a concrete fascia.
	_box("Balcony roof slab", Vector3((X0 + X_END) * .5, CEIL + .1, (Z_WALL + Z_OUT + .1) * .5), Vector3(X_END - X0 + .3, .2, Z_OUT + .1 - Z_WALL), "plaster", true)
	_box("Roof fascia", Vector3((X0 + X_END) * .5, CEIL + .05, Z_OUT + .08), Vector3(X_END - X0 + .3, .32, .06), "concrete", false)
	# Slab edge seen from the courtyard.
	_box("Balcony slab fascia", Vector3((X0 + X_END) * .5, -.2, Z_OUT + .02), Vector3(X_END - X0 + .15, .22, .05), "concrete", false)

func _build_end_wall() -> void:
	_feature("Aquarium end wall: navy window, plaques and ring planters")
	var x := X0 - .075
	_box("Balcony end wall", Vector3(x, (CEIL + .2) * .5, (Z_WALL + Z_OUT) * .5), Vector3(.15, CEIL + .2, Z_OUT - Z_WALL + .1), "plaster", true)
	# Navy-framed window with dark reflective glass, centred over the aquarium and rack.
	var wz := 3.88
	var wy := 1.80
	var w := .92
	var h := .84
	_box("End window glass", Vector3(X0 + .004, wy, wz), Vector3(.008, h, w), "glass dark")
	for side in [-1, 1]:
		_box("End window frame side", Vector3(X0 + .02, wy, wz + side * (w * .5 + .035)), Vector3(.04, h + .14, .07), "navy")
		_box("End window frame rail", Vector3(X0 + .02, wy + side * (h * .5 + .035), wz), Vector3(.04, .07, w), "navy")
	_box("End window sill", Vector3(X0 + .045, wy - h * .5 - .075, wz), Vector3(.09, .025, w + .16), "navy")
	_box("End window mullion", Vector3(X0 + .012, wy, wz), Vector3(.02, h, .03), "navy")
	# Two small plaques above the window.
	_sign(Vector3(X0 + .012, 2.50, 4.22), .44, .11, "sign worthwhile")
	_sign(Vector3(X0 + .012, 2.50, 3.50), .33, .11, "sign loves")

func _sign(center: Vector3, width: float, height: float, key: String) -> void:
	_box("Plaque board", center + Vector3(-.004, 0, 0), Vector3(.012, height + .012, width + .012), "walnut")
	var x := center.x + .003
	_quad([Vector3(x, center.y - height * .5, center.z + width * .5), Vector3(x, center.y - height * .5, center.z - width * .5),
		Vector3(x, center.y + height * .5, center.z - width * .5), Vector3(x, center.y + height * .5, center.z + width * .5)], Vector3.RIGHT, key)

func _build_house_wall() -> void:
	_feature("House wall: navy exterior door frame, plant print, yellow paint with maroon windows")
	var z := Z_WALL + .012
	# White plaster facade around the door (covers the room wall's outer face).
	_box("House facade near", Vector3((X0 + 1.31) * .5, CEIL * .5, z), Vector3(1.31 - X0, CEIL, .024), "plaster")
	_box("House facade over door", Vector3(1.91, (2.40 + CEIL) * .5, z), Vector3(1.2, CEIL - 2.40, .024), "plaster")
	_box("House facade far", Vector3((2.51 + 3.8) * .5, CEIL * .5, z), Vector3(3.8 - 2.51, CEIL, .024), "plaster")
	# Navy painted exterior casing around the doorway.
	for x in [1.35, 2.47]:
		_box("Exterior door casing", Vector3(x, 1.20, Z_WALL + .02), Vector3(.08, 2.40, .04), "navy")
	_box("Exterior door head casing", Vector3(1.91, 2.36, Z_WALL + .02), Vector3(1.20, .08, .04), "navy")
	# Beyond the corner the outer wall is painted yellow, as in the stair photos.
	_box("Yellow house wall", Vector3((3.8 + FENCE_X) * .5, (GROUND + CEIL + .2) * .5, Z_WALL - .1), Vector3(FENCE_X - 3.8, CEIL + .2 - GROUND, .2), "yellow", false)
	_box("Ground floor wall under the facade", Vector3((3.3 + 3.8) * .5, (GROUND - .2) * .5, Z_WALL - .1), Vector3(.5, -GROUND - .2, .2), "yellow", false)
	_box("Grey wall base", Vector3((X_END + FENCE_X) * .5, GROUND + .2, Z_WALL + .008), Vector3(FENCE_X - X_END, .4, .02), "concrete dark")
	_collider("House outer wall", Vector3((3.3 + FENCE_X) * .5, (GROUND + CEIL + .2) * .5, Z_WALL - .1), Vector3(FENCE_X - 3.3, CEIL + .2 - GROUND, .2))
	# Corner trim between the white and yellow paint.
	_box("Paint corner trim", Vector3(3.8, CEIL * .5, z + .004), Vector3(.03, CEIL, .03), "plaster")
	# Maroon-framed louvre window on the yellow wall (balcony level).
	_window(Vector3(4.55, 1.55, Z_WALL), 1.05, 1.10)
	# Orange PVC conduit and a small switch box along the stair.
	_tube([Vector3(5.82, 2.70, Z_WALL + .03), Vector3(5.82, .95, Z_WALL + .03), Vector3(5.82, GROUND + .25, Z_WALL + .03)], .012, "orange pvc", 8)
	_tube([Vector3(3.95, 2.66, Z_WALL + .03), Vector3(5.82, 2.66, Z_WALL + .03)], .012, "orange pvc", 8)
	_box("Switch box", Vector3(5.82, .95, Z_WALL + .04), Vector3(.09, .13, .045), "plastic white")
	_box("Switch rocker", Vector3(5.82, .97, Z_WALL + .066), Vector3(.03, .05, .01), "plastic black")

func _window(center: Vector3, width: float, height: float) -> void:
	var z := center.z + .01
	_box("Maroon window glass", Vector3(center.x, center.y, z + .002), Vector3(width, height, .008), "glass dark")
	for side in [-1, 1]:
		_box("Maroon window jamb", Vector3(center.x + side * (width * .5 + .035), center.y, z + .025), Vector3(.07, height + .14, .05), "maroon")
		_box("Maroon window rail", Vector3(center.x, center.y + side * (height * .5 + .035), z + .025), Vector3(width, .07, .05), "maroon")
	_box("Maroon window mullion", Vector3(center.x, center.y, z + .02), Vector3(.035, height, .035), "maroon")
	_box("Maroon window sill", Vector3(center.x, center.y - height * .5 - .08, z + .06), Vector3(width + .2, .03, .12), "maroon")
	for i in 9:
		_box("Window glass louvre", Vector3(center.x, center.y - height * .45 + i * height * .11, z + .012), Vector3(width - .04, .012, .02), "glass dark", false, Basis(Vector3.RIGHT, -.35))

func _build_railing() -> void:
	_feature("White steel railing on a concrete ledge with frosted floral screen and greenery")
	# Concrete parapet with a ledge the bottle stands on; white steel bars on its outer edge.
	_box("Balcony parapet", Vector3((X0 + X_END) * .5, .425, (Z_LEDGE + Z_OUT) * .5), Vector3(X_END - X0, .85, Z_OUT - Z_LEDGE), "concrete")
	_collider("Balcony parapet", Vector3((X0 + X_END) * .5, .4375, (Z_LEDGE + Z_OUT) * .5), Vector3(X_END - X0, .875, Z_OUT - Z_LEDGE))
	_box("Parapet cap", Vector3((X0 + X_END) * .5, .862, (Z_LEDGE + Z_OUT) * .5), Vector3(X_END - X0, .025, Z_OUT - Z_LEDGE + .03), "plaster")
	_box("Parapet inner skin", Vector3((X0 + X_END) * .5, .425, Z_LEDGE - .004), Vector3(X_END - X0, .85, .008), "plaster")
	var top := 1.22
	var rail_z := Z_OUT - .04
	_rod(Vector3(X0, top, rail_z), Vector3(X_END, top, rail_z), .022, "white steel", 10)
	_rod(Vector3(X0, .93, rail_z), Vector3(X_END, .93, rail_z), .012, "white steel", 6)
	var x := X0 + .08
	while x < X_END:
		_rod(Vector3(x, .875, rail_z), Vector3(x, top, rail_z), .008, "white steel", 6)
		x += .12
	# Balcony end beside the stair top.
	_box("Balcony end parapet", Vector3(X_END + .075, .425, (STAIR_Z + Z_OUT) * .5), Vector3(.15, .85, Z_OUT - STAIR_Z), "concrete", true)
	_rod(Vector3(X_END + .075, top, STAIR_Z), Vector3(X_END + .075, top, Z_OUT), .022, "white steel", 10)
	var z := STAIR_Z + .1
	while z < Z_OUT:
		_rod(Vector3(X_END + .075, .875, z), Vector3(X_END + .075, top, z), .008, "white steel", 6)
		z += .12
	# Frosted floral privacy film above the rail on the aquarium half, in a slim white frame.
	var film_x1 := 3.35
	_plate([Vector3(X0, top + .03, rail_z), Vector3(film_x1, top + .03, rail_z), Vector3(film_x1, CEIL, rail_z), Vector3(X0, CEIL, rail_z)], "film")
	_box("Screen frame post", Vector3(film_x1, (top + CEIL) * .5, rail_z), Vector3(.035, CEIL - top, .035), "white steel")
	_box("Screen frame post", Vector3((X0 + film_x1) * .5, (top + CEIL) * .5, rail_z), Vector3(.025, CEIL - top, .03), "white steel")

func _build_stair() -> void:
	_feature("Concrete stair down along the yellow wall, white steel handrail, doormat")
	for i in range(1, RISERS):
		var top := -i * RISE
		var x0 := X_END + (i - 1) * TREAD
		_box("Stair step", Vector3(x0 + TREAD * .5, (top + GROUND) * .5, (Z_WALL + STAIR_Z) * .5), Vector3(TREAD, top - GROUND, STAIR_Z - Z_WALL), "concrete")
		_box("Stair nosing", Vector3(x0 + .015, top - .012, (Z_WALL + STAIR_Z) * .5), Vector3(.03, .026, STAIR_Z - Z_WALL), "concrete dark")
	# One smooth ramp under the treads so the character walks up and down without snagging.
	var run := RISERS * TREAD - TREAD
	var length := Vector2(run, -GROUND).length()
	var slope := atan2(-GROUND, run)
	var basis := Basis(Vector3.BACK, -slope)
	var thickness := .3
	var mid := Vector3(X_END + run * .5, GROUND * .5, (Z_WALL + STAIR_Z) * .5) - basis.y * thickness * .5
	_collider("Stair ramp", mid, Vector3(length, thickness, STAIR_Z - Z_WALL), basis)
	_stats["stair"] = {"risers": RISERS, "rise": RISE, "tread": TREAD, "slope_deg": rad_to_deg(slope), "top": [X_END, 0.0], "bottom": [X_END + run, GROUND]}
	# White steel handrail on the open side.
	var rail_h := .92
	var z := STAIR_Z + .03
	var a := Vector3(X_END + .075, rail_h + .3, z)
	var b := Vector3(X_END + run + .1, GROUND + rail_h, z)
	_rod(a, b, .024, "white steel", 10)
	_rod(Vector3(a.x, .35, z), Vector3(b.x, GROUND + .3, z), .012, "white steel", 6)
	var x := X_END + .14
	while x < X_END + run:
		var step := clampi(int((x - X_END) / TREAD) + 1, 1, RISERS - 1)
		var foot := -step * RISE
		var t := (x - a.x) / (b.x - a.x)
		var head := lerpf(a.y, b.y, t)
		_rod(Vector3(x, foot, z), Vector3(x, head, z), .008, "white steel", 6)
		x += .12
	for post in [0.0, .5, 1.0]:
		var px := lerpf(a.x, b.x, post)
		var step := clampi(int((px - X_END) / TREAD) + 1, 1, RISERS - 1)
		_rod(Vector3(px, -step * RISE if px > X_END + .01 else 0.0, z), Vector3(px, lerpf(a.y, b.y, post), z), .022, "white steel", 10)

func _build_courtyard() -> void:
	_feature("Small concrete courtyard with white grille gate and neighbour block wall")
	var cx := (YARD_X + FENCE_X) * .5
	_box("Courtyard slab", Vector3((X_END + FENCE_X) * .5, GROUND - .15, (Z_WALL + YARD_Z) * .5), Vector3(FENCE_X - X_END, .3, YARD_Z - Z_WALL), "concrete", false)
	_collider("Courtyard floor", Vector3(cx, GROUND - .15 + .005, (Z_WALL + YARD_Z) * .5), Vector3(FENCE_X - YARD_X + .4, .3, YARD_Z - Z_WALL))
	# Ground floor facade beneath the balcony, behind the low wall.
	_box("Ground floor wall", Vector3(X_END - .075, (GROUND - .2) * .5, (Z_WALL + YARD_Z) * .5), Vector3(.15, -GROUND - .2, YARD_Z - Z_WALL), "yellow", false)
	# Low block wall closing the gap beside the stair foot.
	_box("Low block wall", Vector3(YARD_X - .05, GROUND + .5, (STAIR_Z + YARD_Z) * .5), Vector3(.12, 1.0, YARD_Z - STAIR_Z), "block", false)
	_box("Low wall cap", Vector3(YARD_X - .05, GROUND + 1.01, (STAIR_Z + YARD_Z) * .5), Vector3(.16, .03, YARD_Z - STAIR_Z), "concrete")
	# Neighbour's block wall with a caged window air conditioner and an orange tarp edge.
	_box("Neighbour block wall", Vector3((X_END + FENCE_X) * .5, (GROUND + .25) * .5, YARD_Z + .07), Vector3(FENCE_X - X_END, .25 - GROUND, .14), "block", false)
	for i in 6:
		_box("Block course line", Vector3((X_END + FENCE_X) * .5, GROUND + .4 + i * .5, YARD_Z - .002), Vector3(FENCE_X - X_END, .012, .006), "concrete dark")
	var ac := Vector3(8.6, -.55, YARD_Z - .2)
	_box("Air conditioner", ac, Vector3(.66, .42, .5), "plastic white")
	_box("AC grille", ac + Vector3(0, 0, -.252), Vector3(.56, .32, .006), "plastic black")
	for i in 7:
		_rod(ac + Vector3(-.36 + i * .12, -.24, -.29), ac + Vector3(-.36 + i * .12, .24, -.29), .006, "black metal", 4)
	for y in [-.24, 0.0, .24]:
		_rod(ac + Vector3(-.37, y, -.29), ac + Vector3(.37, y, -.29), .006, "black metal", 4)
	_box("AC bracket", ac + Vector3(0, -.25, 0), Vector3(.75, .04, .55), "black metal")
	_plate([Vector3(9.1, .30, YARD_Z), Vector3(10.6, .30, YARD_Z), Vector3(10.6, .75, YARD_Z + 1.3), Vector3(9.1, .75, YARD_Z + 1.3)], "tarp orange")
	_plate([Vector3(9.15, -.55, YARD_Z - .02), Vector3(10.55, -.55, YARD_Z - .02), Vector3(10.55, .30, YARD_Z - .02), Vector3(9.15, .30, YARD_Z - .02)], "tarp orange")
	_plate([Vector3(10.6, .30, YARD_Z), Vector3(11.3, .30, YARD_Z), Vector3(11.3, .7, YARD_Z + 1.0), Vector3(10.6, .7, YARD_Z + 1.0)], "tarp blue")
	# White decorative steel grille gate across the courtyard end.
	var fy0 := GROUND
	var fy1 := GROUND + 2.05
	for z in [Z_WALL + .06, 4.1, YARD_Z - .02]:
		_box("Gate post", Vector3(FENCE_X, (fy0 + fy1) * .5, z), Vector3(.07, fy1 - fy0, .07), "white steel")
	for y in [fy0 + .08, fy0 + 1.0, fy1 - .04]:
		_rod(Vector3(FENCE_X, y, Z_WALL + .06), Vector3(FENCE_X, y, YARD_Z - .02), .018, "white steel", 6)
	var d := .28
	for row in [[fy0 + .08, fy0 + 1.0], [fy0 + 1.0, fy1 - .04]]:
		var z := Z_WALL + .06
		while z < YARD_Z - .03:
			var z1 := minf(z + d, YARD_Z - .02)
			var y0: float = row[0]
			var y1: float = row[1]
			_rod(Vector3(FENCE_X, y0, z), Vector3(FENCE_X, y1, z1), .008, "white steel", 4)
			_rod(Vector3(FENCE_X, y0, z1), Vector3(FENCE_X, y1, z), .008, "white steel", 4)
			_ring(Vector3(FENCE_X, (y0 + y1) * .5, (z + z1) * .5), .06, "white steel", Basis(Vector3.UP, PI * .5), .006, 10)
			z += d

## Sun at about 3 pm: 40 degrees up, behind the stair view and out over the street (-X, +Z), so the
## houses across the streets are lit from the front and the view down the stair is not into the sun.
const SUN_DIRECTION := Vector3(-.627, .643, .440)

func _build_neighbourhood() -> void:
	# Streets, houses, trees, poles and the sky dome: scripts/neighborhood_builder.gd.
	InteriorNeighborhoodBuilder.build(self, _root, SUN_DIRECTION.normalized())

func _wire(a: Vector3, b: Vector3, sag: float) -> void:
	var pts: Array = []
	for i in 9:
		var t := float(i) / 8
		pts.append(a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1 - t))
	_tube(pts, .007, "rubber", 4)

## Invisible walls above every railing and around the yard, plus a lid, so neither the
## player nor a thrown prop can leave the playable space.
func _build_bounds() -> void:
	var saved := _shell
	_shell = _static_body("BalconyBounds", Vector3.ZERO)
	var lid_y := CEIL + .1
	_collider("Railing bound", Vector3((X0 + X_END) * .5, (.85 + CEIL) * .5, Z_OUT - .02), Vector3(X_END - X0, CEIL - .85, .14))
	_collider("Stair top end bound", Vector3(X_END + .075, (.85 + CEIL) * .5, (STAIR_Z + Z_OUT) * .5), Vector3(.15, CEIL - .85, Z_OUT - STAIR_Z))
	_collider("Stair open side bound", Vector3((X_END + YARD_X) * .5, (GROUND + lid_y) * .5, STAIR_Z + .06), Vector3(YARD_X - X_END + .1, lid_y - GROUND, .12))
	_collider("Low wall bound", Vector3(YARD_X - .05, (GROUND + lid_y) * .5, (STAIR_Z + YARD_Z) * .5), Vector3(.14, lid_y - GROUND, YARD_Z - STAIR_Z + .1))
	_collider("Neighbour wall bound", Vector3((YARD_X + FENCE_X) * .5, (GROUND + lid_y) * .5, YARD_Z + .07), Vector3(FENCE_X - YARD_X + .2, lid_y - GROUND, .14))
	_collider("Gate bound", Vector3(FENCE_X + .02, (GROUND + lid_y) * .5, (Z_WALL + YARD_Z) * .5), Vector3(.12, lid_y - GROUND, YARD_Z - Z_WALL + .2))
	_collider("Open sky lid", Vector3((X_END + FENCE_X) * .5, lid_y + .1, (Z_WALL + YARD_Z) * .5), Vector3(FENCE_X - X_END + .3, .2, YARD_Z - Z_WALL + .3))
	_shell = saved

# ---------------------------------------------------------------- props (named, editable)

func _build_props() -> void:
	_shoe_rack()
	_flower_vase()
	_aquarium()
	for item: Array in [["RingPlanterEndLeft", Vector3(X0 + .16, 1.86, 4.46), PI * .5], ["RingPlanterEndRight", Vector3(X0 + .16, 1.86, 3.20), PI * .5],
			["RingPlanterHouse", Vector3(2.85, 1.86, Z_WALL + .16), 0.0], ["RingPlanterScreen", Vector3(1.25, 1.95, Z_OUT - .2), PI]]:
		_ring_planter(item[0], item[1], item[2])
	_greenery_panel()
	_plant_print()
	for item: Array in [["RattanChair1", Vector3(2.2, 0, 4.15), -PI * .5 + .2], ["RattanChair2", Vector3(2.95, 0, 4.2), -PI * .5 - .15]]:
		_rattan_chair(item[0], item[1], item[2])
	_begin_prop("Doormat", Vector3(X_END - .32, 0, (Z_WALL + STAIR_Z) * .5 + .02))
	_box("Doormat pile", Vector3(0, .006, 0), Vector3(.42, .012, .66), "doormat")
	_end_prop()
	_blue_bottle()
	_ladder()
	_covered_cabinet()
	_plank_stack()

func _shoe_rack() -> void:
	# White five-tier plastic rack in the corner beside the door, shoes in neat pairs.
	_begin_prop("ShoeRack", Vector3(X0 + .17, 0, 3.20), PI * .5)
	var w := .50
	var d := .30
	var h := 1.0
	for x in [-1, 1]:
		for z in [-1, 1]:
			_box("Rack post", Vector3(x * (w * .5 - .015), h * .5, z * (d * .5 - .015)), Vector3(.03, h, .03), "plastic white")
	var shoes := [["shoe pink", "shoe pink"], ["plastic black", "shoe pink"], ["shoe cream", "plastic black"], ["plastic white", "shoe cream"], ["plastic black", "plastic black"]]
	for tier in 5:
		var y := .05 + tier * .225
		_box("Rack shelf", Vector3(0, y, 0), Vector3(w, .018, d), "plastic white", true)
		_box("Rack lip", Vector3(0, y + .02, d * .5 - .01), Vector3(w, .025, .012), "plastic white")
		if tier < 4:
			for pair in 2:
				var key: String = shoes[tier][pair]
				for foot in 2:
					var x := -.17 + pair * .23 + foot * .085
					_box("Shoe sole", Vector3(x, y + .016, 0), Vector3(.075, .014, .22), "rubber")
					_box("Shoe upper", Vector3(x, y + .045, -.02), Vector3(.072, .05, .16), key)
					_sphere(Vector3(x, y + .03, .07), Vector3(.072, .05, .08), key, 8)
	_end_prop()

func _flower_vase() -> void:
	_begin_prop("FlowerVase", Vector3(X0 + .12, 0, 3.56))
	_box("Wooden box vase", Vector3(0, .28, 0), Vector3(.16, .56, .16), "walnut", true)
	_box("Vase label", Vector3(.081, .38, 0), Vector3(.004, .07, .11), "plastic white")
	for i in 9:
		var a := TAU * i / 9
		var tip := Vector3(cos(a) * .12, .86 + (i % 3) * .07, sin(a) * .12)
		_rod(Vector3(0, .54, 0), tip, .004, "foliage dark", 4)
		_sphere(tip, Vector3(.07, .055, .07), "petal pink" if i % 2 else "petal purple", 8)
		_sphere(tip * Vector3(.6, .94, .6), Vector3(.05, .025, .03), "foliage", 6)
	_end_prop()

func _aquarium() -> void:
	# Low damask-upholstered bench with the aquarium on top, against the end wall.
	var bench := Vector3(X0 + .25, 0, 4.12)
	_begin_prop("AquariumBench", bench)
	_box("Bench base", Vector3(0, .19, 0), Vector3(.46, .34, .86), "fabric dark", true)
	_box("Bench damask top", Vector3(0, .385, 0), Vector3(.48, .07, .88), "damask", true)
	for x in [-1, 1]:
		for z in [-1, 1]:
			_box("Bench foot", Vector3(x * .2, .015, z * .39), Vector3(.04, .03, .04), "walnut")
	_end_prop()
	var body := ObjectScript.new() as InteriorObject
	body.name = "Aquarium"
	body.display_name = "Aquarium"
	body.anchored = true
	body.grab_mode = "none"
	body.physics_material = "glass"
	body.set_meta("visual_layers", PROP_LAYERS)
	_root.add_child(body)
	body.position = bench + Vector3(0, .42, 0)
	body.rotation.y = PI * .5
	InteriorAquarium.attach_to(body, 1.0, Vector3(.88, .44, .38))
	for node in body.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).layers = PROP_LAYERS
	body.home_transform = body.global_transform
	_stats.dynamic_props += 1
	(_stats.props as Array).append("Aquarium")

func _ring_planter(label: String, at: Vector3, yaw: float) -> void:
	# Black wire ring on a wall bracket holding a white pot with pink flowers.
	_begin_prop(label, at, yaw)
	var z := -.14
	_rod(Vector3(0, .02, z), Vector3(0, .02, z + .03), .012, "black metal", 6)
	_ring(Vector3(0, 0, 0), .11, "black metal", Basis.IDENTITY, .005)
	_ring(Vector3(0, -.03, 0), .085, "black metal", Basis(Vector3.RIGHT, PI * .5), .005)
	_lathe(Vector3(0, -.07, 0), [Vector2(0, 0), Vector2(.055, 0), Vector2(.075, .09), Vector2(.08, .10), Vector2(.0, .10)], "ceramic", 16)
	for i in 5:
		var a := TAU * i / 5
		_sphere(Vector3(cos(a) * .045, .07 + (i % 2) * .03, sin(a) * .045), Vector3(.07, .05, .07), "foliage", 8)
	for i in 3:
		var a := TAU * i / 3 + .5
		_sphere(Vector3(cos(a) * .035, .11, sin(a) * .035), Vector3(.045, .04, .045), "petal pink", 8)
	_end_prop()

func _greenery_panel() -> void:
	# Artificial greenery mat with sunflowers and purple wisteria strands, hung at the top
	# of the screen near the aquarium corner.
	var origin := Vector3(X0 + .05, 2.05, Z_OUT - .09)
	_begin_prop("GreeneryPanel", origin)
	_box("Greenery mat", Vector3(.48, .33, 0), Vector3(.96, .64, .03), "foliage", false)
	var random := RandomNumberGenerator.new()
	random.seed = 5521
	for i in 26:
		_sphere(Vector3(random.randf_range(.05, .92), random.randf_range(.05, .62), -.02), Vector3(.12, .1, .05), "foliage dark" if i % 3 else "foliage", 6)
	for item: Vector2 in [Vector2(.25, .42), Vector2(.52, .22), Vector2(.70, .48), Vector2(.40, .12)]:
		var p := Vector3(item.x, item.y, -.05)
		_sphere(p, Vector3(.13, .13, .02), "petal yellow", 10)
		_sphere(p + Vector3(0, 0, -.01), Vector3(.055, .055, .02), "sunflower centre", 8)
	for i in 7:
		var x := .1 + i * .13
		var length := random.randf_range(.25, .5)
		for j in 6:
			var t := float(j) / 5
			_sphere(Vector3(x + sin(t * 3.0 + i) * .01, -t * length, -.04), Vector3(.028, .04, .028) * (1.0 - t * .4), "petal purple", 6)
	_end_prop()

func _plant_print() -> void:
	_begin_prop("PlantPrint", Vector3(3.10, 1.62, Z_WALL + .025))
	var w := .46
	var h := .58
	for x in [-1, 1]: _box("Print frame side", Vector3(x * (w + .03) * .5, 0, 0), Vector3(.03, h + .06, .025), "walnut")
	for y in [-1, 1]: _box("Print frame rail", Vector3(0, y * (h + .03) * .5, 0), Vector3(w, .03, .025), "walnut")
	_quad([Vector3(-w * .5, -h * .5, .004), Vector3(w * .5, -h * .5, .004), Vector3(w * .5, h * .5, .004), Vector3(-w * .5, h * .5, .004)], Vector3.BACK, "print")
	_end_prop()

func _rattan_chair(label: String, at: Vector3, yaw: float) -> void:
	# White steel frame, woven rattan seat and curved back (front faces local +Z).
	_begin_prop(label, at, yaw)
	for x in [-1, 1]:
		for z in [-1, 1]:
			_rod(Vector3(x * .2, 0, z * .2), Vector3(x * .21, .45, z * .21), .012, "white steel", 6)
		_rod(Vector3(x * .21, .45, -.21), Vector3(x * .22, .86, -.27), .012, "white steel", 6)
	_box("Rattan seat", Vector3(0, .465, 0), Vector3(.46, .04, .46), "rattan", true)
	var back := Basis(Vector3.RIGHT, -.14)
	_box("Rattan back", Vector3(0, .70, -.245), Vector3(.44, .30, .03), "rattan", false, back)
	_rod(Vector3(-.22, .86, -.27), Vector3(.22, .86, -.27), .012, "white steel", 6)
	_collider("Chair legs", Vector3(0, .22, 0), Vector3(.44, .44, .44))
	_collider("Chair back", Vector3(0, .70, -.25), Vector3(.44, .32, .05), back)
	_end_prop()

func _blue_bottle() -> void:
	# Small blue bottle on the ledge: a real, knockable rigid body.
	var body := ObjectScript.new() as InteriorObject
	body.name = "BlueBottle"
	body.display_name = "Blue bottle"
	body.mass = .6
	body.physics_material = "plastic"
	body.rolls = true
	body.start_asleep = true
	_root.add_child(body)
	body.position = Vector3(1.62, .875, Z_LEDGE + .05)
	var visual := MeshInstance3D.new()
	visual.name = "Visual"
	visual.mesh = _lathe_mesh([Vector2(0, 0), Vector2(.045, 0), Vector2(.047, .008), Vector2(.047, .17), Vector2(.03, .2), Vector2(.018, .215), Vector2(.018, .24), Vector2(0, .24)], 20)
	visual.material_override = _materials["bottle blue"]
	visual.layers = PROP_LAYERS
	body.add_child(visual)
	var cap := MeshInstance3D.new()
	cap.name = "Cap"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = .02
	cylinder.bottom_radius = .02
	cylinder.height = .03
	cap.mesh = cylinder
	cap.position.y = .25
	cap.material_override = _materials["plastic white"]
	cap.layers = PROP_LAYERS
	body.add_child(cap)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = .046
	shape.height = .24
	shape.margin = .001
	collision.shape = shape
	collision.position.y = .12
	body.add_child(collision)
	body.home_transform = body.global_transform
	_stats.dynamic_props += 1
	(_stats.props as Array).append("BlueBottle")

func _ladder() -> void:
	# Aluminium A-frame ladder, folded and leaning neatly against the house wall.
	_begin_prop("Ladder", Vector3(11.05, GROUND, Z_WALL + .32))
	var lean := Basis(Vector3.RIGHT, -.16)
	for x in [-.21, .21]:
		_box("Ladder rail", lean * Vector3(x, 1.0, 0), Vector3(.05, 2.0, .025), "steel", false, lean)
		_box("Ladder rear rail", lean * Vector3(x * .92, 1.0, -.04), Vector3(.04, 2.0, .02), "steel", false, lean)
	for i in 6:
		_box("Ladder rung", lean * Vector3(0, .25 + i * .3, 0), Vector3(.42, .025, .06), "steel", false, lean)
	_box("Ladder top cap", lean * Vector3(0, 2.0, -.02), Vector3(.48, .05, .09), "plastic black", false, lean)
	_collider("Ladder volume", lean * Vector3(0, 1.0, -.02), Vector3(.48, 2.0, .1), lean)
	_end_prop()

func _covered_cabinet() -> void:
	_begin_prop("CoveredCabinet", Vector3(12.15, GROUND, 4.55))
	_box("Cabinet body", Vector3(0, .6, 0), Vector3(.62, 1.2, .44), "walnut", true)
	_box("Plastic dust cover", Vector3(0, .63, 0), Vector3(.68, 1.26, .50), "plastic cover")
	_end_prop()

func _plank_stack() -> void:
	_begin_prop("PlankStack", Vector3(10.75, GROUND, 4.95))
	for i in 6:
		_box("Plank", Vector3(0, .016 + i * .032, (i % 2) * .01), Vector3(1.6, .03, .2), "oak", false)
	_collider("Plank stack", Vector3(0, .1, 0), Vector3(1.6, .2, .22))
	_end_prop()

# ---------------------------------------------------------------- lights

func _build_lights() -> void:
	# Daylight that only reaches the outdoor layer: the room never sees it, even on Low
	# where nothing casts shadows.
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, .93, .82)
	sun.light_energy = 1.6
	sun.light_cull_mask = OUTDOOR_LAYER
	sun.basis = Basis.looking_at(-SUN_DIRECTION.normalized(), Vector3.UP)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 30.0
	sun.shadow_bias = .04
	sun.shadow_normal_bias = 1.2
	_root.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.light_color = Color(.78, .86, 1.0)
	fill.light_energy = .55
	fill.light_cull_mask = OUTDOOR_LAYER
	fill.rotation_degrees = Vector3(-70, 200, 0)
	fill.shadow_enabled = false
	fill.light_specular = .2
	_root.add_child(fill)
	var bounce := DirectionalLight3D.new()
	bounce.name = "GroundBounce"
	bounce.light_color = Color(.95, .90, .82)
	bounce.light_energy = .3
	bounce.light_cull_mask = OUTDOOR_LAYER
	bounce.rotation_degrees = Vector3(35, 120, 0)
	bounce.shadow_enabled = false
	bounce.light_specular = 0.0
	_root.add_child(bounce)
