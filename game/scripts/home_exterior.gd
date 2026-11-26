class_name InteriorHomeExterior
extends Node3D
## 0.26: the outside of the player's own house.
##
## Until now the furnished rooms were a shell hanging 2.9 m over an empty lot: no ground floor, no roof, flat
## single-colour panels for walls, and the "yellow house wall" along the stair was a free-standing slab. This builds
## the house those rooms belong to, around them and under them, without touching the baked room or balcony:
## - the main block (the living room and kitchen upstairs, and the rest of the family's rooms east of the locked
##   closet door) and the studio wing, both two storeys of painted hollow-block: yellow, as on the stair wall,
##   with a grey splash band, stained and patched;
## - maroon louvre windows with rusted grilles downstairs, the street door on the east face (bolted from inside,
##   a "usable" that only rattles), a back door boarded shut, an air-conditioner on its bracket, a water tank,
##   the electric meter and its service mast;
## - a corrugated-iron gable roof over the main block and a lean-to over the wing, with fascia and gutter;
## - collision for the ground storey, so nobody walks under the rooms.
## Everything is on the outdoor visual layer (moonlit, not lit by the room's lamps) and merged into one mesh per
## material. Built at runtime under the Balcony root, so it shows and hides with the rest of the outdoors.

const OUTDOOR_LAYER := 2
const TEX := "res://assets/outdoor/textures/"
const GROUND := -2.9
const FLOOR := 0.0
const EAVE := 3.08
## Main block and studio wing footprints (x0, x1, z0, z1), just outside the baked room shells.
const MAIN := [-6.02, 12.58, -3.12, 2.58]
const MAIN_WEST := [-6.02, 3.6, -3.12, 2.98]
const WING := [-6.02, -.92, 2.98, 7.68]
const SKIN := .09

var _tools := {}
var _materials := {}
var _body: StaticBody3D
var door: Node3D

static func attach(balcony: Node3D) -> InteriorHomeExterior:
	if balcony == null or balcony.has_node("Home exterior"):
		return null
	var exterior := InteriorHomeExterior.new()
	exterior.name = "Home exterior"
	balcony.add_child(exterior)
	exterior._build()
	return exterior

# ---------------------------------------------------------------- materials

func _pbr(key: String, folder: String, tint: Color, metres := 2.4, rough := 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = "Home exterior / " + key
	mat.albedo_color = tint
	var base := TEX + folder + "/"
	if ResourceLoader.exists(base + "albedo.jpg"):
		mat.albedo_texture = load(base + "albedo.jpg")
	if ResourceLoader.exists(base + "normal.jpg"):
		mat.normal_enabled = true
		mat.normal_texture = load(base + "normal.jpg")
		mat.normal_scale = 1.1
	if ResourceLoader.exists(base + "roughness.jpg"):
		mat.roughness_texture = load(base + "roughness.jpg")
	mat.roughness = rough
	mat.metallic_specular = .25
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE / metres
	_materials[key] = mat
	return mat

func _plaster(key: String, tint: Color) -> void:
	var source := InteriorMaterials.material("warm_plaster") as BaseMaterial3D
	var mat: BaseMaterial3D = source.duplicate() as BaseMaterial3D if source != null else StandardMaterial3D.new()
	mat.resource_name = "Home exterior / " + key
	mat.albedo_color = tint
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE / 2.4
	_materials[key] = mat

func _flat(key: String, colour: Color, rough := .8, metal := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = "Home exterior / " + key
	mat.albedo_color = colour
	mat.roughness = rough
	mat.metallic = metal
	mat.metallic_specular = .3
	_materials[key] = mat
	return mat

func _prepare() -> void:
	# The same warm plaster and paint as the stair wall the balcony builder made (Color(.90, .76, .42)), a
	# shade dirtier where the rain runs down the wing.
	_plaster("yellow", Color(.88, .74, .41))
	_plaster("yellow stained", Color(.72, .6, .35))
	_pbr("band", "dirty_concrete", Color(.5, .5, .47), 2.2)
	_pbr("block", "concrete_block_wall", Color(.72, .7, .66), 1.6)
	_pbr("concrete", "rough_concrete", Color(.62, .61, .58), 2.0)
	_pbr("roof", "rusty_corrugated_iron", Color(.62, .52, .46), 2.2, .8)
	_pbr("rust", "rusty_metal_02", Color(.62, .5, .42), 1.0, .85)
	_pbr("shutter", "painted_metal_shutter", Color(.44, .5, .52), 1.6, .7)
	_pbr("door", "wood_peeling_paint_weathered", Color(.44, .16, .13), 1.2)
	_pbr("planks", "weathered_planks", Color(.6, .55, .48), 1.3)
	_flat("maroon", Color(.33, .09, .075), .55)
	_flat("glass", Color(.03, .04, .05), .18)
	_flat("louvre", Color(.1, .12, .13), .3)
	_flat("white", Color(.78, .77, .72), .6)
	_flat("black", Color(.04, .04, .045), .7)
	_flat("tank", Color(.07, .16, .3), .5)
	_flat("steel", Color(.42, .43, .44), .45, .8)

# ---------------------------------------------------------------- geometry

## 0.34: the boxes and pipes of each material, added to its tool in one go at the end (scripts/box_kit.gd).
var _kits := {}

func _kit(key: String) -> InteriorBoxKit:
	_tool(key)
	if not _kits.has(key):
		_kits[key] = InteriorBoxKit.new()
	return _kits[key]

func _tool(key: String) -> SurfaceTool:
	if not _tools.has(key):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[key] = tool
	return _tools[key]

## A box by its centre and size, optionally turned (Euler, radians).
func _box(key: String, centre: Vector3, size: Vector3, turn := Vector3.ZERO) -> void:
	_kit(key).box(size, Transform3D(Basis.from_euler(turn), centre))

## A box between two corners.
func _slab(key: String, a: Vector3, b: Vector3) -> void:
	_box(key, (a + b) * .5, (b - a).abs())

func _cylinder(key: String, centre: Vector3, radius: float, height: float, turn := Vector3.ZERO, sides := 14) -> void:
	_kit(key).cylinder(radius, height, sides, Transform3D(Basis.from_euler(turn), centre))

## A triangle prism (a gable end): three points and a thickness along `normal`.
func _gable(key: String, a: Vector3, b: Vector3, top: Vector3, normal: Vector3, thickness: float) -> void:
	var tool := _tool(key)
	var back := -normal.normalized() * thickness
	var faces := [[a, b, top], [b + back, a + back, top + back]]
	for face: Array in faces:
		var n := ((face[1] as Vector3) - (face[0] as Vector3)).cross((face[2] as Vector3) - (face[0] as Vector3)).normalized()
		for p: Vector3 in face:
			tool.set_normal(-n)
			tool.set_uv(Vector2(p.x + p.z, p.y) * .4)
			tool.add_vertex(p)

func _collide(a: Vector3, b: Vector3, label: String, surface := "concrete") -> void:
	var shape := BoxShape3D.new()
	shape.size = (b - a).abs()
	var collision := CollisionShape3D.new()
	collision.name = label
	collision.shape = shape
	collision.position = (a + b) * .5
	collision.set_meta("surface", surface)
	_body.add_child(collision)

## A wall of the house facing `out` (unit, along x or z): the splash band at the foot, yellow above, a cornice line
## at each floor.
func _wall(from: Vector3, to: Vector3, out: Vector3, y0: float, y1: float, key := "yellow") -> void:
	var depth := out * SKIN
	var band_top := minf(y0 + .82, y1)
	if y0 < FLOOR - .5:
		_slab("band", Vector3(from.x, y0, from.z) - depth * .2, Vector3(to.x, band_top, to.z) + depth * 1.25)
		_slab(key, Vector3(from.x, band_top, from.z), Vector3(to.x, y1, to.z) + depth)
		# The floor line between the storeys.
		_slab("concrete", Vector3(from.x, FLOOR - .16, from.z), Vector3(to.x, FLOOR + .04, to.z) + depth * 1.8)
	else:
		_slab(key, Vector3(from.x, y0, from.z), Vector3(to.x, y1, to.z) + depth)

## A louvre window on a wall facing `out`, centred at `at`. Downstairs windows get a rusted grille.
func _window(at: Vector3, out: Vector3, width: float, height: float, grille := false, boarded := false) -> void:
	var along := Vector3(absf(out.z), 0, absf(out.x))
	var face := at + out * (SKIN + .012)
	var frame := .07
	var thick := Vector3(absf(out.x), 0, absf(out.z)) * .07
	_box("glass", face, along * width + Vector3.UP * height + thick * .4)
	_box("maroon", face + Vector3.UP * (height * .5 + frame * .5), along * (width + frame * 2.0) + Vector3.UP * frame + thick)
	_box("maroon", face - Vector3.UP * (height * .5 + frame * .5), along * (width + frame * 2.0) + Vector3.UP * frame + thick)
	_box("maroon", face + along * (width * .5 + frame * .5), along * frame + Vector3.UP * height + thick)
	_box("maroon", face - along * (width * .5 + frame * .5), along * frame + Vector3.UP * height + thick)
	_box("maroon", face, along * .045 + Vector3.UP * height + thick)
	# Glass louvres: tilted blades, a few of them missing.
	var blades := int(height / .105)
	for k in blades:
		if (k * 7 + int(absf(at.x) * 3.0 + absf(at.z) * 5.0)) % 9 == 0:
			continue
		var y := -height * .5 + (k + .5) * height / blades
		_box("louvre", face + Vector3.UP * y + out * .03, along * (width - .02) + Vector3.UP * .085 + thick * .2, Vector3(out.z, 0, -out.x) * .5)
	# The sill.
	_box("concrete", face - Vector3.UP * (height * .5 + frame + .03) + out * .04, along * (width + .3) + Vector3.UP * .06 + thick * 2.6)
	if grille:
		var bars := int(width / .14)
		for k in bars + 1:
			var x := -width * .5 + k * width / bars
			_box("rust", face + along * x + out * .11, along * .018 + Vector3.UP * (height + .1) + thick * .25)
		for y in [-height * .28, height * .28]:
			_box("rust", face + Vector3.UP * y + out * .11, along * (width + .08) + Vector3.UP * .022 + thick * .25)
	if boarded:
		for k in 3:
			var y := -height * .3 + k * height * .3
			_box("planks", face + Vector3.UP * y + out * .14, along * (width + .34) + Vector3.UP * .15 + thick * .3, Vector3(out.x, 0, out.z) * (.07 - k * .06))

func _door_leaf(at: Vector3, out: Vector3, width: float, height: float, key := "door") -> void:
	var along := Vector3(absf(out.z), 0, absf(out.x))
	var face := at + out * (SKIN + .02)
	var thick := Vector3(absf(out.x), 0, absf(out.z))
	_box("maroon", face + Vector3.UP * (height + .05), along * (width + .2) + Vector3.UP * .1 + thick * .1)
	_box("maroon", face + Vector3.UP * height * .5 + along * (width * .5 + .05), along * .1 + Vector3.UP * height + thick * .1)
	_box("maroon", face + Vector3.UP * height * .5 - along * (width * .5 + .05), along * .1 + Vector3.UP * height + thick * .1)
	_box(key, face + Vector3.UP * height * .5, along * width + Vector3.UP * height + thick * .05)
	# Two sunk panels and a knob.
	for y in [height * .3, height * .72]:
		_box("maroon", face + Vector3.UP * y + out * .012, along * (width - .28) + Vector3.UP * (height * .3) + thick * .04)
	_box("steel", face + Vector3.UP * 1.0 + along * (width * .5 - .1) + out * .045, Vector3.ONE * .055)
	# The step.
	_box("concrete", at + out * .28 + Vector3.UP * .07, along * (width + .5) + Vector3.UP * .14 + thick * .5)

# ---------------------------------------------------------------- the house

func _build() -> void:
	_prepare()
	_body = StaticBody3D.new()
	_body.name = "Home exterior colliders"
	_body.collision_layer = 2
	_body.collision_mask = 0
	add_child(_body)
	_main_block()
	_studio_wing()
	_roofs()
	_fittings()
	_colliders()
	_commit()
	_street_door()
	set_meta("home_exterior", {"materials": _materials.size(), "colliders": _body.get_child_count()})

func _main_block() -> void:
	var x0: float = MAIN[0]
	var x1: float = MAIN[1]
	var z0: float = MAIN[2]
	var z1: float = MAIN[3]
	# South face: the long back of the house over the empty lot.
	_wall(Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(0, 0, -1), GROUND, EAVE)
	for x in [-4.3, -1.2, 1.6, 6.2, 9.7]:
		_window(Vector3(x, 1.55, z0), Vector3(0, 0, -1), 1.15, 1.05)
	for x in [-2.9, 1.9, 9.4]:
		_window(Vector3(x, GROUND + 1.55, z0), Vector3(0, 0, -1), 1.05, .95, true, x > 0.0 and x < 4.0)
	_door_leaf(Vector3(5.6, GROUND, z0), Vector3(0, 0, -1), .88, 2.02)
	for k in 4:
		_box("planks", Vector3(5.6, GROUND + .45 + k * .42, z0 - SKIN - .07), Vector3(1.32, .14, .028), Vector3(0, 0, .09 - k * .07))
	# West face: the kitchen end.
	_wall(Vector3(x0, 0, z0), Vector3(x0, 0, MAIN_WEST[3]), Vector3(-1, 0, 0), GROUND, EAVE)
	_window(Vector3(x0, 1.62, -.1), Vector3(-1, 0, 0), 1.5, 1.0)
	_window(Vector3(x0, GROUND + 1.55, -.6), Vector3(-1, 0, 0), .95, .9, true)
	# East face: the front of the house, on the lane.
	_wall(Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(1, 0, 0), GROUND, EAVE)
	_window(Vector3(x1, 1.55, -1.75), Vector3(1, 0, 0), 1.2, 1.05)
	_window(Vector3(x1, 1.55, 1.1), Vector3(1, 0, 0), 1.2, 1.05)
	_window(Vector3(x1, GROUND + 1.55, -1.85), Vector3(1, 0, 0), 1.2, .95, true)
	# A concrete canopy over the street door.
	_slab("concrete", Vector3(x1, GROUND + 2.2, .2), Vector3(x1 + .95, GROUND + 2.32, 1.85))
	# North face east of the living room is the existing stair wall; what shows above and beside it is closed here.
	_slab("yellow", Vector3(3.62, FLOOR + 2.98, z1), Vector3(x1, EAVE, z1 + .12))
	# The closet's bump on the old shell is inside this block now; the upstairs floor edge over the stair wall.
	_slab("concrete", Vector3(3.62, FLOOR - .16, z1 - .02), Vector3(x1, FLOOR + .04, z1 + .1))

func _studio_wing() -> void:
	var x0: float = WING[0]
	var x1: float = WING[1]
	var z0: float = WING[2]
	var z1: float = WING[3]
	_wall(Vector3(x0, 0, z0), Vector3(x0, 0, z1), Vector3(-1, 0, 0), GROUND, EAVE)
	_wall(Vector3(x0, 0, z1), Vector3(x1, 0, z1), Vector3(0, 0, 1), GROUND, EAVE, "yellow stained")
	_wall(Vector3(x1, 0, z0 + 1.75), Vector3(x1, 0, z1), Vector3(1, 0, 0), GROUND, EAVE)
	# Under the balcony's west end the wing's wall only needs its ground storey.
	_wall(Vector3(x1, 0, z0), Vector3(x1, 0, z0 + 1.75), Vector3(1, 0, 0), GROUND, FLOOR - .16)
	# The studio is acoustically lined: its windows are bricked up from inside and shuttered outside.
	_window(Vector3(x0, 1.55, 5.3), Vector3(-1, 0, 0), 1.1, 1.0, false, true)
	_window(Vector3(-3.5, 1.55, z1), Vector3(0, 0, 1), 1.3, 1.0, false, true)
	_window(Vector3(-3.5, GROUND + 1.55, z1), Vector3(0, 0, 1), 1.1, .9, true)
	# A roll-up shutter on the wing's ground floor: the family's old store front, long shut.
	_slab("shutter", Vector3(x1 + SKIN, GROUND + .08, 5.05), Vector3(x1 + SKIN + .05, GROUND + 2.2, 7.2))
	_slab("rust", Vector3(x1 + SKIN, GROUND + 2.2, 4.95), Vector3(x1 + SKIN + .16, GROUND + 2.42, 7.3))

func _roofs() -> void:
	var x0: float = MAIN[0] - .55
	var x1: float = MAIN[1] + .55
	var z0: float = MAIN[2] - .6
	var z1: float = MAIN[3] + .12
	var ridge_z := (MAIN[2] + MAIN[3]) * .5
	var rise := 1.5
	var south_run := ridge_z - z0
	var north_run := z1 - ridge_z
	var south_pitch := atan2(rise, south_run)
	var north_pitch := atan2(rise * north_run / south_run, north_run)
	var ridge_y := EAVE + rise * (ridge_z - MAIN[2]) / south_run + .12
	# Two slopes of corrugated iron, a ridge cap, fascia boards and the gutter along the south eave.
	var south_len := south_run / cos(south_pitch)
	_box("roof", Vector3((x0 + x1) * .5, ridge_y - sin(south_pitch) * south_len * .5, ridge_z - cos(south_pitch) * south_len * .5),
		Vector3(x1 - x0, .045, south_len), Vector3(-south_pitch, 0, 0))
	var north_len := north_run / cos(north_pitch)
	_box("roof", Vector3((x0 + x1) * .5, ridge_y - sin(north_pitch) * north_len * .5, ridge_z + cos(north_pitch) * north_len * .5),
		Vector3(x1 - x0, .045, north_len), Vector3(north_pitch, 0, 0))
	_box("rust", Vector3((x0 + x1) * .5, ridge_y + .03, ridge_z), Vector3(x1 - x0, .06, .34))
	_slab("white", Vector3(x0, EAVE - .22, z0 + .02), Vector3(x1, EAVE - .02, z0 + .07))
	_cylinder("steel", Vector3((x0 + x1) * .5, EAVE - .2, z0 - .04), .07, x1 - x0, Vector3(0, 0, PI * .5), 8)
	_cylinder("steel", Vector3(MAIN[1] + .2, (EAVE - .2 + GROUND) * .5, z0 + .55), .045, EAVE - .2 - GROUND, Vector3.ZERO, 8)
	# Gable ends, east and west.
	for x in [MAIN[0], MAIN[1]]:
		var out := Vector3(-1 if x < 0.0 else 1, 0, 0)
		_gable("yellow", Vector3(x, EAVE, MAIN[2]) + out * SKIN, Vector3(x, EAVE, MAIN[3]) + out * SKIN, Vector3(x, ridge_y - .06, ridge_z) + out * SKIN, out if x > 0.0 else -out, .12)
		_gable("yellow", Vector3(x, EAVE, MAIN[3]) + out * SKIN, Vector3(x, EAVE, MAIN[2]) + out * SKIN, Vector3(x, ridge_y - .06, ridge_z) + out * SKIN, out if x > 0.0 else -out, .12)
		# A louvred vent in the gable.
		_box("maroon", Vector3(x, EAVE + .62, ridge_z) + out * (SKIN + .02), Vector3(.05, .5, .62))
		for k in 4:
			_box("louvre", Vector3(x, EAVE + .45 + k * .11, ridge_z) + out * (SKIN + .05), Vector3(.03, .07, .54), Vector3(0, 0, .5 * out.x))
	# The lean-to over the studio wing, falling to the north.
	var wx0: float = WING[0] - .5
	var wx1: float = WING[1] + .42
	var wz0: float = WING[2] - .1
	var wz1: float = WING[3] + .55
	var fall := .62
	var wing_len := sqrt((wz1 - wz0) * (wz1 - wz0) + fall * fall)
	var wing_pitch := atan2(fall, wz1 - wz0)
	_box("roof", Vector3((wx0 + wx1) * .5, EAVE + .14 + fall * .5, (wz0 + wz1) * .5), Vector3(wx1 - wx0, .045, wing_len), Vector3(wing_pitch, 0, 0))
	_slab("white", Vector3(wx0, EAVE - .2, wz1 - .07), Vector3(wx1, EAVE + .02, wz1 - .02))
	# The wall between the two roofs.
	_slab("yellow", Vector3(WING[0], EAVE, WING[2] - .12), Vector3(WING[1], EAVE + .78, WING[2]))

func _fittings() -> void:
	var z0: float = MAIN[2]
	# Window air-conditioner on its bracket, south face, with a rust streak under it.
	_slab("white", Vector3(3.55, 1.05, z0 - .46), Vector3(4.25, 1.5, z0))
	_slab("black", Vector3(3.6, 1.1, z0 - .47), Vector3(4.2, 1.45, z0 - .455))
	_box("rust", Vector3(3.9, .98, z0 - .22), Vector3(.72, .03, .46))
	_slab("yellow stained", Vector3(3.7, -.9, z0 - SKIN - .006), Vector3(4.1, 1.0, z0 - SKIN))
	# Water tank on a steel stand against the west wall.
	var tx: float = MAIN[0] - .75
	for dx in [-.42, .42]:
		for dz in [-.42, .42]:
			_cylinder("rust", Vector3(tx + dx, GROUND + 1.1, 1.6 + dz), .03, 2.2, Vector3.ZERO, 6)
	_box("rust", Vector3(tx, GROUND + 2.2, 1.6), Vector3(1.0, .05, 1.0))
	_cylinder("tank", Vector3(tx, GROUND + 2.86, 1.6), .5, 1.25, Vector3.ZERO, 18)
	_cylinder("black", Vector3(tx, GROUND + 3.5, 1.6), .2, .06, Vector3.ZERO, 12)
	_cylinder("steel", Vector3(tx + .46, GROUND + 1.3, 1.6), .02, 2.6, Vector3.ZERO, 6)
	# Electric meter and the service mast on the front.
	var x1: float = MAIN[1]
	_slab("steel", Vector3(x1 + SKIN, GROUND + 1.35, -.62), Vector3(x1 + SKIN + .12, GROUND + 1.72, -.36))
	_slab("glass", Vector3(x1 + SKIN + .12, GROUND + 1.48, -.56), Vector3(x1 + SKIN + .13, GROUND + 1.66, -.42))
	_cylinder("steel", Vector3(x1 + SKIN + .05, (GROUND + 1.72 + EAVE + 1.0) * .5, -.49), .022, EAVE + 1.0 - GROUND - 1.72, Vector3.ZERO, 6)
	# House number plate beside the door.
	_slab("white", Vector3(x1 + SKIN, GROUND + 1.72, 1.92), Vector3(x1 + SKIN + .012, GROUND + 1.86, 2.16))
	# A drain pipe down the wing and a patch of bare block where the render fell off.
	_cylinder("steel", Vector3(WING[0] - SKIN - .06, (GROUND + EAVE) * .5, 7.3), .04, EAVE - GROUND, Vector3.ZERO, 8)
	_slab("block", Vector3(-1.7, GROUND + .82, z0 - SKIN - .008), Vector3(.3, GROUND + 1.95, z0 - SKIN))
	_slab("block", Vector3(7.4, FLOOR + .3, z0 - SKIN - .008), Vector3(8.5, FLOOR + .95, z0 - SKIN))

func _colliders() -> void:
	# Ground storey under the rooms, and the east half of the house at full height.
	_collide(Vector3(MAIN_WEST[0], GROUND, MAIN_WEST[2]), Vector3(3.62, FLOOR - .2, 2.6), "Ground storey under the living room")
	_collide(Vector3(3.62, GROUND, MAIN[2]), Vector3(MAIN[1], EAVE, MAIN[3] - .12), "East rooms of the house")
	_collide(Vector3(WING[0], GROUND, 2.6), Vector3(WING[1], FLOOR - .2, WING[3]), "Ground storey under the studio")
	_collide(Vector3(MAIN[0] - 1.3, GROUND, 1.05), Vector3(MAIN[0], GROUND + 3.6, 2.15), "Water tank stand", "metal")

func _commit() -> void:
	for key: String in _tools:
		var tool: SurfaceTool = _tools[key]
		if _kits.has(key):
			(_kits[key] as InteriorBoxKit).pour(tool)
		tool.generate_tangents()
		var mesh := tool.commit()
		var instance := MeshInstance3D.new()
		instance.name = "Home exterior - " + key
		instance.mesh = mesh
		instance.material_override = _materials.get(key)
		instance.layers = OUTDOOR_LAYER
		instance.set_meta("no_range", true)
		add_child(instance)
	_tools.clear()

## The street door on the lane: bolted from inside. Trying it only rattles the bolt (a "usable", like the
## neighbours' doors).
func _street_door() -> void:
	var x1: float = MAIN[1]
	var holder := Node3D.new()
	holder.name = "Home street door"
	holder.set_script(preload("res://scripts/home_door.gd"))
	add_child(holder)
	holder.position = Vector3(x1 + SKIN, GROUND, 1.0)
	door = holder
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tools["door"] = tool
	_tools["maroon"] = SurfaceTool.new()
	(_tools["maroon"] as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)
	_tools["steel"] = SurfaceTool.new()
	(_tools["steel"] as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)
	_tools["concrete"] = SurfaceTool.new()
	(_tools["concrete"] as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)
	_door_leaf(Vector3(-SKIN, 0, 0), Vector3(1, 0, 0), .92, 2.05)
	for key: String in _tools:
		var part: SurfaceTool = _tools[key]
		if _kits.has(key):
			(_kits[key] as InteriorBoxKit).pour(part)
		part.generate_tangents()
		var instance := MeshInstance3D.new()
		instance.name = "Street door - " + key
		instance.mesh = part.commit()
		instance.material_override = _materials.get(key)
		instance.layers = OUTDOOR_LAYER
		instance.set_meta("no_range", true)
		holder.add_child(instance)
	_tools.clear()
	var body := StaticBody3D.new()
	body.name = "Street door body"
	body.collision_layer = 2
	body.collision_mask = 0
	body.set_meta("surface", "wood")
	var shape := BoxShape3D.new()
	shape.size = Vector3(.12, 2.05, .95)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(.03, 1.03, 0)
	body.add_child(collision)
	holder.add_child(body)
