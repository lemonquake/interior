class_name InteriorNeighborhoodBuilder
extends RefCounted
## The neighbourhood seen from the balcony, stair and courtyard: streets, ~50 procedurally designed
## houses with Poly Haven PBR surfaces (painted plaster, hollow block, brick, corrugated iron and clay
## tile roofs, window grilles, gates, AC units), downloaded trees (coconut palms, mango, jacaranda,
## island trees, bananas), utility poles with sagging wires and a misty HDRI sky dome.
## Called by InteriorBalconyBuilder; everything lives under the "Neighbourhood" node (runtime glue:
## scripts/neighborhood.gd). Deterministic: the same seed always lays out the same street.
##
## Frame: ground y = -2.9 (the courtyard level). Our house occupies x -7..13, z -4..8.

const NeighborhoodScript = preload("res://scripts/neighborhood.gd")
const SKY_SHADER = preload("res://scripts/sky_dome.gdshader")
const GROUND := -2.9
const STOREY := 2.95
## Streets: [axis, centre, from, to, width]. "x" streets run along X at z = centre.
const STREETS := [["x", 18.0, -70.0, 80.0, 6.0], ["z", 21.0, -40.0, 90.0, 6.0], ["x", 49.0, -70.0, 80.0, 6.0], ["z", -19.0, -40.0, 90.0, 6.0]]
## Lot rows: [axis the row runs along, row line (front of lots), from, to, facing (+1/-1 along the other axis), depth, max storeys]
const ROWS := [
	["x", 15.0, -16.0, 18.0, 1, 7.0, 2],    # near row: backs toward our balcony, fronts on street A
	["x", 21.0, -16.0, 18.0, -1, 11.0, 3],  # across street A, facing us
	["x", 46.0, -16.0, 18.0, 1, 11.0, 3],
	["x", 52.0, -16.0, 18.0, -1, 11.0, 2],
	["z", 24.0, 21.0, 46.0, -1, 11.0, 3],   # east of street B
	["z", 24.0, -30.0, 15.0, -1, 11.0, 2],
	["z", 46.5, 21.0, 46.0, 1, 11.0, 2],    # back-to-back row on a lane
	["z", 46.5, -30.0, 15.0, 1, 11.0, 3],
	["z", 18.0, -14.0, 1.0, 1, 5.0, 2],     # behind the courtyard gate
	["z", -22.0, -30.0, 15.0, 1, 11.0, 3],  # west of street D
	["z", -22.0, 21.0, 46.0, 1, 11.0, 2],
	["z", -22.0, 52.0, 75.0, 1, 11.0, 3],
]
const WALL_COLOURS := [Color(.95, .92, .84), Color(.86, .93, .86), Color(.97, .84, .74), Color(.80, .88, .95), Color(.94, .90, .70),
		Color(.90, .80, .86), Color(.78, .80, .78), Color(.98, .97, .95), Color(.83, .72, .60), Color(.70, .82, .80)]
const ROOF_COLOURS := [Color(.62, .18, .14), Color(.20, .38, .56), Color(.24, .44, .30), Color(.55, .55, .56), Color(.42, .24, .16)]

var b: InteriorBalconyBuilder
var root: Node3D
var models: Node3D
var rng := RandomNumberGenerator.new()
var _houses := 0
var _trees := 0
## Placement guards (XZ rectangles). No tree crown may overlap a house (roof overhang included) or
## our own house; no trunk may stand on a road, sidewalk, wall or pole. Trees are queued while the
## lots are laid out and planted last, each moved to a nearby clear spot or dropped.
var _no_canopy: Array[Rect2] = []
var _no_trunk: Array[Rect2] = []
var _crowns: Array[Rect2] = []
var _wanted: Array = []
var _dropped := 0

static func build(builder: InteriorBalconyBuilder, parent: Node3D, sun_direction: Vector3) -> Dictionary:
	var n := InteriorNeighborhoodBuilder.new()
	n.b = builder
	n.root = Node3D.new()
	n.root.name = "Neighbourhood"
	n.root.set_script(NeighborhoodScript)
	parent.add_child(n.root)
	n.models = Node3D.new()
	n.models.name = "Models"
	n.root.add_child(n.models)
	n.rng.seed = 20261005
	var saved: Dictionary = builder._batches
	builder._batches = {}
	n._materials()
	n._ground()
	n._streets()
	n._lots()
	n._our_house_shell()
	n._hero_trees()
	n._poles()
	n._plant()
	builder._commit(n.root, "Neighbourhood - ")
	builder._batches = saved
	n._sky(sun_direction)
	var stats := {"houses": n._houses, "trees": n._trees, "trees_dropped": n._dropped}
	n.root.set_meta("neighbourhood_stats", stats)
	return stats

# ---------------------------------------------------------------- materials

func _materials() -> void:
	b._pbr("n grass", "sparse_grass", 3.0, Color(.82, .86, .78))
	b._pbr("n asphalt", "asphalt_02", 4.0, Color(.85, .85, .85))
	b._pbr("n pavement", "concrete_pavement", 2.0)
	b._pbr("n yard", "concrete_floor_02", 3.0, Color(.92, .91, .88))
	b._pbr("n block", "concrete_block_wall", 2.4)
	b._pbr("n brick", "brick_wall_02", 2.2)
	b._pbr("n concrete", "concrete_wall_008", 3.0)
	b._pbr("n peeling", "peeling_painted_wall", 2.5, Color(.95, .95, .92))
	b._pbr("n shutter", "painted_metal_shutter", 2.0)
	b._pbr("n planks", "blue_painted_planks", 1.6)
	b._pbr("n rust", "rusty_metal_02", 2.0)
	for i in WALL_COLOURS.size():
		b._pbr("n plaster %d" % i, "white_plaster_02" if i % 3 != 2 else "beige_wall_001", 2.5, WALL_COLOURS[i])
	for i in ROOF_COLOURS.size():
		var roof := b._pbr("n roof %d" % i, "corrugated_iron" if i % 2 == 0 else "corrugated_iron_02", 2.0, ROOF_COLOURS[i])
		roof.metallic = .35
		roof.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rusty := b._pbr("n roof rust", "rusty_corrugated_iron", 2.0)
	rusty.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tile := b._pbr("n roof tile", "clay_roof_tiles_02", 2.0)
	tile.cull_mode = BaseMaterial3D.CULL_DISABLED
	var grey_tile := b._pbr("n roof grey", "grey_roof_tiles", 2.0)
	grey_tile.cull_mode = BaseMaterial3D.CULL_DISABLED
	var glass := StandardMaterial3D.new()
	glass.resource_name = "Neighbourhood / window glass"
	glass.albedo_color = Color(.16, .2, .24)
	glass.metallic = .5
	glass.roughness = .08
	b._materials["n glass"] = glass
	for spec: Array in [["n curtain a", Color(.75, .62, .45)], ["n curtain b", Color(.55, .65, .75)], ["n curtain c", Color(.85, .82, .76)]]:
		var curtain := StandardMaterial3D.new()
		curtain.resource_name = "Neighbourhood / " + spec[0]
		curtain.albedo_color = spec[1]
		curtain.roughness = .9
		b._materials[spec[0]] = curtain
	for spec: Array in [["n frame white", Color(.9, .9, .88), .5], ["n frame dark", Color(.12, .12, .13), .45], ["n frame brown", Color(.32, .2, .12), .55],
			["n grille", Color(.08, .08, .08), .5], ["n tank blue", Color(.15, .35, .7), .5], ["n tank black", Color(.06, .06, .07), .6],
			["n wire", Color(.03, .03, .03), .7], ["n pole", Color(.62, .61, .58), .9], ["n gate green", Color(.13, .3, .2), .45],
			["n gate maroon", Color(.38, .1, .08), .45], ["n tarp", Color(.18, .4, .72), .8], ["n sign", Color(.92, .85, .2), .6]]:
		b._flat(spec[0], spec[1], spec[2])

# ---------------------------------------------------------------- ground and streets

func _ground() -> void:
	b._feature("Neighbourhood: streets, ~50 houses, trees, poles and a misty 3 pm sky")
	# Grass base, then concrete yards drawn per lot. The courtyard keeps its own floor above this.
	b._box("Ground", Vector3(10, GROUND - .06, 20), Vector3(260, .1, 260), "n grass")

func _streets() -> void:
	for street: Array in STREETS:
		var along_x: bool = street[0] == "x"
		var centre: float = street[1]
		var length: float = street[3] - street[2]
		var mid: float = (street[2] + street[3]) * .5
		var w: float = street[4]
		var road := Vector3(mid, GROUND + .005, centre) if along_x else Vector3(centre, GROUND + .006, mid)
		var road_size := Vector3(length, .02, w - 2.0) if along_x else Vector3(w - 2.0, .02, length)
		b._box("Road", road, road_size, "n asphalt")
		_no_trunk.append(Rect2(street[2], centre - w * .5, length, w) if along_x else Rect2(centre - w * .5, street[2], w, length))
		for side in [-1.0, 1.0]:
			var offset: float = side * (w * .5 - .5)
			var walk := Vector3(mid, GROUND + .06, centre + offset) if along_x else Vector3(centre + offset, GROUND + .061, mid)
			var walk_size := Vector3(length, .12, 1.0) if along_x else Vector3(1.0, .12, length)
			b._box("Sidewalk", walk, walk_size, "n pavement")
			# A painted centre line, dashed.
		var dash := -length * .5
		while dash < length * .5:
			var p := Vector3(mid + dash, GROUND + .017, centre) if along_x else Vector3(centre, GROUND + .018, mid + dash)
			b._box("Lane dash", p, Vector3(1.6, .004, .1) if along_x else Vector3(.1, .004, 1.6), "n frame white")
			dash += 4.0

# ---------------------------------------------------------------- lots and houses

func _lots() -> void:
	for row: Array in ROWS:
		var along_x: bool = row[0] == "x"
		var line: float = row[1]
		var cursor: float = row[2]
		var end: float = row[3]
		var facing: int = row[4]
		var depth: float = row[5]
		while cursor < end - 6.0:
			var frontage := minf(rng.randf_range(7.5, 11.5), end - cursor)
			if end - cursor - frontage < 6.0:
				frontage = end - cursor
			_lot(along_x, line, cursor, frontage, facing, depth, int(row[6]))
			cursor += frontage

## One lot: concrete yard, a front wall with a gate, side walls and a house set back from the street.
## `line` is the lot's street edge; the lot extends `depth` away from the street (opposite to `facing`).
func _lot(along_x: bool, line: float, start: float, frontage: float, facing: int, depth: float, max_storeys: int) -> void:
	# Local frame: u along the street, v away from it (into the lot), up = Y.
	var u_axis := Vector3.RIGHT if along_x else Vector3.BACK
	var v_axis := (Vector3.BACK if along_x else Vector3.RIGHT) * -facing
	var origin := (Vector3(start, GROUND, line) if along_x else Vector3(line, GROUND, start))
	var front_dir := -v_axis  # the house front faces the street
	var at := func(u: float, v: float, y: float) -> Vector3: return origin + u_axis * u + v_axis * v + Vector3.UP * y
	# House frame: local +Z is the front (toward the street), Y up, X = Y x Z.
	var basis := Basis(Vector3.UP.cross(front_dir), Vector3.UP, front_dir)
	var vacant := rng.randf() < .3
	# Yard and walls (a vacant lot keeps its grass and gets a stand of trees instead of a house).
	if not vacant:
		b._box("Yard", at.call(frontage * .5, depth * .5, .015), _sized(basis, Vector3(frontage - .1, .03, depth - .1)), "n yard")
	var wall_key: String = ["n block", "n plaster 0", "n plaster 6", "n concrete"][rng.randi_range(0, 3)]
	var wall_h := rng.randf_range(1.4, 2.0)
	var gate_w := rng.randf_range(2.4, 3.2)
	var gate_u := rng.randf_range(.5, frontage - gate_w - .5)
	var front_v := .25
	_wall_segment(at.call(0, front_v, 0), at.call(gate_u, front_v, 0), wall_h, wall_key)
	_wall_segment(at.call(gate_u + gate_w, front_v, 0), at.call(frontage, front_v, 0), wall_h, wall_key)
	_gate(at.call(gate_u, front_v, 0), at.call(gate_u + gate_w, front_v, 0), wall_h - .1)
	_wall_segment(at.call(frontage - .1, front_v, 0), at.call(frontage - .1, depth - .1, 0), wall_h + .2, "n block")
	_wall_segment(at.call(.1, depth - .1, 0), at.call(frontage - .1, depth - .1, 0), wall_h + .2, "n block")
	if vacant:
		for i in rng.randi_range(3, 5):
			var kind: String = ["island_tree_01", "island_tree_02", "tree_small_02", "palm_coconut_a", "banana_plant", "searsia_lucida"][rng.randi_range(0, 5)]
			_want(at.call(rng.randf_range(1.5, frontage - 1.5), rng.randf_range(1.5, depth - 1.5), 0), kind, rng.randf_range(.9, 1.4), 1.5)
		return
	# House footprint.
	var side := rng.randf_range(.8, 1.6)
	var house_w := frontage - side * 2.0
	var setback := rng.randf_range(2.2, 3.4)
	var house_d := minf(rng.randf_range(6.0, 9.0), depth - setback - .6)
	if house_w < 4.0 or house_d < 3.5:
		return
	var storeys := rng.randi_range(1, max_storeys)
	var centre: Vector3 = at.call(side + house_w * .5, setback + house_d * .5, 0)
	_house(centre, basis, house_w, house_d, storeys)
	# The house and its roof overhang / front balcony keep tree crowns out.
	var a: Vector3 = centre + basis * Vector3(-house_w * .5 - .55, 0, -house_d * .5 - .55)
	var c: Vector3 = centre + basis * Vector3(house_w * .5 + .55, 0, house_d * .5 + 1.3)
	_no_canopy.append(Rect2(minf(a.x, c.x), minf(a.z, c.z), absf(c.x - a.x), absf(c.z - a.z)))
	# Yard planting: small plants out front, a real tree in the back yard when it fits.
	if rng.randf() < .5:
		_want(at.call(rng.randf_range(.9, frontage - .9), rng.randf_range(.9, setback - .5), 0), ["banana_small", "banana_plant", "searsia_lucida"][rng.randi_range(0, 2)], rng.randf_range(.7, 1.0), .6)
	var back := depth - setback - house_d
	if back > 1.5 or rng.randf() < .6:
		var kind: String = ["island_tree_02", "tree_small_02", "palm_coconut_a", "island_tree_01", "banana_plant"][rng.randi_range(0, 4)]
		_want(at.call(rng.randf_range(1.0, frontage - 1.0), setback + house_d + maxf(back * .5, .5), 0), kind, rng.randf_range(.9, 1.3), 1.5)
	if rng.randf() < .3:
		var chair: Vector3 = at.call(side + house_w * rng.randf_range(.2, .8), setback - .8, 0)
		_model("street/plastic_monobloc_chair_01", chair, rad_to_deg(atan2(front_dir.x, front_dir.z)) + rng.randf_range(-30, 30), 1.0, 45.0)

func _sized(basis: Basis, size: Vector3) -> Vector3:
	# Axis-aligned size of a box authored in `basis` (all lot bases are 90-degree turns).
	return (basis * size).abs()

func _wall_segment(a: Vector3, c: Vector3, height: float, key: String) -> void:
	var length := a.distance_to(c)
	if length < .05:
		return
	var mid := (a + c) * .5 + Vector3.UP * height * .5
	var dir := (c - a).normalized()
	var size := Vector3(length, height, .18) if absf(dir.x) > .5 else Vector3(.18, height, length)
	b._box("Fence wall", mid, size, key)
	_no_trunk.append(Rect2(mid.x - size.x * .5, mid.z - size.z * .5, size.x, size.z).grow(.15))
	b._box("Fence cap", mid + Vector3.UP * (height * .5 + .03), size * Vector3(1, 0, 1) + Vector3(.06 if absf(dir.x) < .5 else 0, .06, .06 if absf(dir.x) > .5 else 0), "n concrete")

func _gate(a: Vector3, c: Vector3, height: float) -> void:
	var key: String = ["n gate green", "n gate maroon", "n frame dark", "n frame white"][rng.randi_range(0, 3)]
	var dir := (c - a).normalized()
	var length := a.distance_to(c)
	var bars := int(length / .12)
	for i in bars + 1:
		var p := a + dir * (i * length / bars)
		b._box("Gate bar", p + Vector3.UP * height * .5, Vector3(.025, height, .025), key)
	for y in [.12, height * .5, height - .05]:
		b._box("Gate rail", (a + c) * .5 + Vector3.UP * y, (Vector3(length, .05, .05) if absf(dir.x) > .5 else Vector3(.05, .05, length)), key)
	for p in [a, c]:
		b._box("Gate post", p + Vector3.UP * (height + .2) * .5, Vector3(.24, height + .2, .24), "n concrete")

## A house centred at `centre` (ground level) whose front faces basis.z * -1... built in the lot basis:
## local x = along the street, local z = toward the street (front), y up.
func _house(centre: Vector3, basis: Basis, w: float, d: float, storeys: int) -> void:
	_houses += 1
	var style := rng.randi_range(0, 4)
	var wall: String = "n plaster %d" % rng.randi_range(0, WALL_COLOURS.size() - 1)
	var lower := wall
	if style == 3:
		lower = "n brick"
	elif style == 4 and storeys > 1:
		lower = wall
	var height := storeys * STOREY
	var to_world := func(local: Vector3) -> Vector3: return centre + basis * local
	# Plinth and storey bodies (a slightly wider band marks each floor slab).
	b._box("House plinth", to_world.call(Vector3(0, .15, 0)), _sized(basis, Vector3(w + .1, .3, d + .1)), "n concrete")
	for s in storeys:
		var key := lower if s == 0 else wall
		if style == 4 and s == storeys - 1 and storeys > 1:
			key = "n block"  # unfinished hollow-block top floor
		b._box("House storey", to_world.call(Vector3(0, s * STOREY + STOREY * .5 + .15, 0)), _sized(basis, Vector3(w, STOREY, d)), key)
		if s > 0:
			b._box("Floor band", to_world.call(Vector3(0, s * STOREY + .15, 0)), _sized(basis, Vector3(w + .14, .22, d + .14)), "n concrete")
	# Windows on the front and back, a few on the sides.
	var frame: String = ["n frame white", "n frame dark", "n frame brown"][rng.randi_range(0, 2)]
	for s in storeys:
		var y0 := s * STOREY + .15
		var count := maxi(1, int(w / 2.6))
		for i in count:
			var u := -w * .5 + (i + .5) * w / count
			if s == 0 and i == count / 2:
				_door(to_world, basis, Vector3(u, y0, d * .5), frame, style)
			else:
				_window(to_world, basis, Vector3(u, y0 + .95, d * .5), 1.2, 1.15, frame, 1)
			if rng.randf() < .7:
				_window(to_world, basis, Vector3(u, y0 + .95, -d * .5), 1.0, 1.0, frame, -1)
		for side in [-1.0, 1.0]:
			if rng.randf() < .5:
				_side_window(to_world, basis, Vector3(side * w * .5, y0 + 1.0, rng.randf_range(-d * .25, d * .25)), frame, side)
	# Upper-floor balcony on some houses.
	if storeys > 1 and rng.randf() < .55:
		var bw := minf(w * .55, 3.6)
		var y := STOREY + .15
		b._box("Balcony slab", to_world.call(Vector3(0, y, d * .5 + .55)), _sized(basis, Vector3(bw, .16, 1.1)), "n concrete")
		var bars := int(bw / .14)
		for i in bars + 1:
			b._box("Balcony baluster", to_world.call(Vector3(-bw * .5 + i * bw / bars, y + .52, d * .5 + 1.07)), _sized(basis, Vector3(.025, .9, .025)), "n grille")
		b._box("Balcony rail", to_world.call(Vector3(0, y + 1.0, d * .5 + 1.07)), _sized(basis, Vector3(bw, .05, .06)), "n grille")
	# Roof.
	var top := height + .15
	match style:
		0, 3:
			_gable_roof(to_world, basis, w, d, top, "n roof %d" % rng.randi_range(0, ROOF_COLOURS.size() - 1) if rng.randf() < .8 else "n roof rust", wall)
		1:
			_hip_roof(to_world, basis, w, d, top, "n roof tile" if rng.randf() < .6 else "n roof grey")
		2, 4:
			_flat_roof(to_world, basis, w, d, top, wall, style == 4)
	# AC units and a downpipe.
	if rng.randf() < .6:
		var side := -1.0 if rng.randf() < .5 else 1.0
		var ac_local := Vector3(side * (w * .5 + .13), STOREY * (storeys - 1) + 1.9 + .15, rng.randf_range(-d * .3, d * .3))
		var out := basis * Vector3(side, 0, 0)
		_model("street/exterior_aircon_unit", to_world.call(ac_local), rad_to_deg(atan2(out.x, out.z)), .55, 70.0)
	b._box("Downpipe", to_world.call(Vector3(w * .5 - .1, height * .5, d * .5 + .08)), _sized(basis, Vector3(.08, height, .08)), "n frame white")

func _window(to_world: Callable, basis: Basis, local: Vector3, ww: float, wh: float, frame: String, face: int) -> void:
	var out := Vector3(0, 0, face)
	b._box("Window frame", to_world.call(local + out * .03), _sized(basis, Vector3(ww + .12, wh + .12, .06)), frame)
	var pane: String = "n glass" if rng.randf() < .55 else ["n curtain a", "n curtain b", "n curtain c"][rng.randi_range(0, 2)]
	b._box("Window pane", to_world.call(local + out * .05), _sized(basis, Vector3(ww, wh, .03)), pane)
	b._box("Window mullion", to_world.call(local + out * .075), _sized(basis, Vector3(.04, wh, .03)), frame)
	b._box("Window sill", to_world.call(local + Vector3(0, -wh * .5 - .07, 0) + out * .08), _sized(basis, Vector3(ww + .25, .06, .16)), "n concrete")
	if rng.randf() < .6:
		# Steel security grille in front of the glass.
		for i in 6:
			var u := -ww * .5 + (i + .5) * ww / 6
			b._box("Grille bar", to_world.call(local + Vector3(u, 0, 0) + out * .12), _sized(basis, Vector3(.016, wh, .016)), "n grille")
		for y in [-wh * .25, wh * .25]:
			b._box("Grille rail", to_world.call(local + Vector3(0, y, 0) + out * .12), _sized(basis, Vector3(ww, .016, .016)), "n grille")
	if rng.randf() < .3:
		b._box("Window awning", to_world.call(local + Vector3(0, wh * .5 + .2, 0) + out * .3), _sized(basis, Vector3(ww + .4, .03, .55)), "n roof %d" % rng.randi_range(0, ROOF_COLOURS.size() - 1), false, Basis.IDENTITY)

func _side_window(to_world: Callable, basis: Basis, local: Vector3, frame: String, side: float) -> void:
	var out := Vector3(side, 0, 0)
	b._box("Window frame", to_world.call(local + out * .03), _sized(basis, Vector3(.06, 1.0, 1.0)), frame)
	b._box("Window pane", to_world.call(local + out * .05), _sized(basis, Vector3(.03, .88, .88)), "n glass")

func _door(to_world: Callable, basis: Basis, local: Vector3, frame: String, style: int) -> void:
	if style == 2 and rng.randf() < .6:
		# Sari-sari store front: a roll-up shutter and a painted sign board.
		b._box("Shutter", to_world.call(local + Vector3(0, 1.2, .04)), _sized(basis, Vector3(2.2, 2.4, .05)), "n shutter")
		b._box("Store sign", to_world.call(local + Vector3(0, 2.62, .06)), _sized(basis, Vector3(2.6, .4, .05)), "n sign")
		return
	b._box("Door frame", to_world.call(local + Vector3(0, 1.08, .03)), _sized(basis, Vector3(1.05, 2.16, .06)), frame)
	b._box("Door leaf", to_world.call(local + Vector3(0, 1.04, .05)), _sized(basis, Vector3(.9, 2.05, .04)), "n planks" if rng.randf() < .5 else frame)
	b._box("Door step", to_world.call(local + Vector3(0, .07, .35)), _sized(basis, Vector3(1.4, .14, .6)), "n concrete")
	b._box("Door canopy", to_world.call(local + Vector3(0, 2.45, .45)), _sized(basis, Vector3(1.6, .08, .9)), "n concrete")

func _gable_roof(to_world: Callable, basis: Basis, w: float, d: float, top: float, key: String, gable_key: String) -> void:
	# Ridge runs along local x; slopes fall to the front and back with a 0.5 m overhang.
	var rise := d * .5 * tan(deg_to_rad(rng.randf_range(16, 24)))
	var over := .5
	var half := d * .5 + over
	var drop := over * rise / (d * .5)
	for side in [-1.0, 1.0]:
		var eave: Vector3 = to_world.call(Vector3(0, top - drop, side * half))
		var ridge: Vector3 = to_world.call(Vector3(0, top + rise, 0))
		var along := basis * Vector3((w + over * 2) * .5, 0, 0)
		var pts := [eave - along, eave + along, ridge + along, ridge - along]
		var normal: Vector3 = (pts[1] - pts[0]).cross(pts[3] - pts[0]).normalized()
		if normal.y < 0:
			pts = [pts[1], pts[0], pts[3], pts[2]]
			normal = -normal
		b._quad(pts, normal, key, Vector2((w + over * 2), half / cos(atan(rise / (d * .5)))))
		b._box("Fascia", to_world.call(Vector3(0, top - drop - .08, side * half)), _sized(basis, Vector3(w + over * 2, .16, .04)), "n frame white")
	# Gable triangles in the wall colour.
	for end in [-1.0, 1.0]:
		var a: Vector3 = to_world.call(Vector3(end * w * .5, top, -d * .5))
		var c: Vector3 = to_world.call(Vector3(end * w * .5, top, d * .5))
		var r: Vector3 = to_world.call(Vector3(end * w * .5, top + rise, 0))
		var out := basis * Vector3(end, 0, 0)
		var tool := b._builder(gable_key)
		var tri := [a, c, r]
		if (c - a).cross(r - a).dot(out) < 0:
			tri = [c, a, r]
		for p in [tri[0], tri[2], tri[1]]:
			tool.set_normal(out)
			tool.set_uv(Vector2((p - a).length(), p.y - top))
			tool.add_vertex(p)

func _hip_roof(to_world: Callable, basis: Basis, w: float, d: float, top: float, key: String) -> void:
	var over := .5
	var hw := w * .5 + over
	var hd := d * .5 + over
	var rise := minf(hw, hd) * tan(deg_to_rad(24))
	var ridge := maxf(hw - hd, 0.0)
	var r0: Vector3 = to_world.call(Vector3(-ridge, top + rise, 0))
	var r1: Vector3 = to_world.call(Vector3(ridge, top + rise, 0))
	var c := [to_world.call(Vector3(-hw, top - .15, -hd)), to_world.call(Vector3(hw, top - .15, -hd)), to_world.call(Vector3(hw, top - .15, hd)), to_world.call(Vector3(-hw, top - .15, hd))]
	var faces := [[c[3], c[2], r1, r0], [c[1], c[0], r0, r1], [c[2], c[1], r1, r1], [c[0], c[3], r0, r0]]
	for f: Array in faces:
		var normal: Vector3 = (f[1] - f[0]).cross(f[2] - f[0]).normalized()
		if normal.y < 0:
			f = [f[1], f[0], f[3], f[2]]
			normal = -normal
		b._quad(f, normal, key, Vector2((f[1] - f[0]).length(), (f[2] - f[1]).length()))
	b._box("Eave soffit", to_world.call(Vector3(0, top - .17, 0)), _sized(basis, Vector3(hw * 2, .04, hd * 2)), "n frame white")

func _flat_roof(to_world: Callable, basis: Basis, w: float, d: float, top: float, wall: String, unfinished: bool) -> void:
	b._box("Roof slab", to_world.call(Vector3(0, top + .1, 0)), _sized(basis, Vector3(w + .2, .2, d + .2)), "n concrete")
	if unfinished:
		# Exposed rebar on the columns, waiting for the next storey.
		for x in [-w * .5 + .1, w * .5 - .1]:
			for z in [-d * .5 + .1, d * .5 - .1]:
				for k in 4:
					b._box("Rebar", to_world.call(Vector3(x + (k % 2) * .08 - .04, top + .65, z + (k / 2) * .08 - .04)), Vector3(.016, .9, .016), "n rust")
	else:
		for side: Array in [[Vector3(0, top + .55, d * .5), Vector3(w + .2, .7, .15)], [Vector3(0, top + .55, -d * .5), Vector3(w + .2, .7, .15)],
				[Vector3(w * .5, top + .55, 0), Vector3(.15, .7, d)], [Vector3(-w * .5, top + .55, 0), Vector3(.15, .7, d)]]:
			b._box("Parapet", to_world.call(side[0]), _sized(basis, side[1]), wall)
	# Water tank on a steel stand.
	var tank: Vector3 = to_world.call(Vector3(w * .25, top + .2, -d * .2))
	for k in 4:
		var leg := tank + basis * Vector3((k % 2) * .9 - .45, 0, (k / 2) * .9 - .45)
		b._rod(leg, leg + Vector3.UP * .9, .03, "n grille", 6)
	b._rod(tank + Vector3.UP * .9, tank + Vector3.UP * 2.1, .55, "n tank blue" if rng.randf() < .6 else "n tank black", 14)
	b._rod(tank + Vector3.UP * 2.1, tank + Vector3.UP * 2.22, .55, "n tank blue", 14, .3)

# ---------------------------------------------------------------- our house, trees, poles

## Exterior of the new studio wing (indoors on layer 1) as seen from the courtyard and stair.
func _our_house_shell() -> void:
	# Living room, kitchen, studio wing, balcony, stair and courtyard.
	_no_canopy.append(Rect2(-7.5, -4.5, 21.0, 13.0))
	b._box("Studio wing exterior", Vector3(-3.45, (GROUND + 3.25) * .5, 5.27), Vector3(4.95, 3.25 - GROUND, 4.66), "n plaster 4")
	b._box("Studio wing roof", Vector3(-3.45, 3.32, 5.27), Vector3(5.2, .14, 4.9), "n concrete")
	for x in [-4.8, -2.2]:
		_window(func(local: Vector3) -> Vector3: return local, Basis.IDENTITY, Vector3(x, -1.0, 7.6), 1.3, 1.1, "n frame dark", 1)

func _model(path: String, at: Vector3, yaw: float, scale: float, fade := 0.0) -> Node3D:
	var node := InteriorModelKit.place(models, path, at, yaw, scale, "none")
	node.set_meta("fade", fade)
	return node

## Queues a tree; _plant() places it at `at` or within `search` metres of it, if anywhere fits.
func _want(at: Vector3, kind: String, scale: float, search: float) -> void:
	_wanted.append([at, kind, scale, search])

func _plant() -> void:
	for want: Array in _wanted:
		var base: Vector3 = want[0]
		var kind: String = want[1]
		var scale: float = want[2]
		var search: float = want[3]
		var fade := 90.0 if kind.begins_with("banana") or kind.begins_with("shrub") or kind == "searsia_lucida" else 0.0
		var planted := false
		for attempt in 16:
			var spot := base if attempt == 0 else base + Vector3(rng.randf_range(-search, search), 0, rng.randf_range(-search, search))
			if _hits_point(_no_trunk, spot, .5):
				continue
			var node := _model("nature/" + kind, spot, rng.randf_range(0, 360), scale, fade)
			var box := InteriorModelKit.bounds_in(node, models)
			var crown := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
			crown = crown.grow(-minf(crown.size.x, crown.size.y) * .1)
			if _hits_rect(_no_canopy, crown) or _crowded(crown):
				node.free()
				continue
			node.set_meta("tree", true)
			_crowns.append(crown)
			_trees += 1
			planted = true
			break
		if not planted:
			_dropped += 1

func _hits_point(rects: Array[Rect2], p: Vector3, margin: float) -> bool:
	for r in rects:
		if r.grow(margin).has_point(Vector2(p.x, p.z)):
			return true
	return false

func _hits_rect(rects: Array[Rect2], crown: Rect2) -> bool:
	for r in rects:
		if r.intersects(crown):
			return true
	return false

## Two crowns may touch, but not grow through each other.
func _crowded(crown: Rect2) -> bool:
	for other in _crowns:
		if other.intersects(crown):
			var shared := other.intersection(crown).get_area()
			if shared > .45 * minf(other.get_area(), crown.get_area()):
				return true
	return false

func _hero_trees() -> void:
	# Big trees composed for the balcony and courtyard views; they rise above the roofs.
	for spec: Array in [
			["island_tree_01", Vector3(9.8, GROUND, 12.2), 1.7], ["palm_coconut_a", Vector3(14.6, GROUND, 9.5), 1.15],
			["palm_coconut_b", Vector3(-3.0, GROUND, 25.5), .85], ["jacaranda_tree", Vector3(-9.5, GROUND, 33.0), .62],
			["palm_coconut_a", Vector3(28.5, GROUND, 13.0), 1.25], ["jacaranda_tree", Vector3(31.0, GROUND, 30.0), .55],
			["island_tree_01", Vector3(9.5, GROUND, 24.5), 1.5], ["palm_coconut_b", Vector3(16.5, GROUND, 40.0), 1.0],
			["island_tree_02", Vector3(-12.0, GROUND, 11.5), 1.6], ["tree_small_02", Vector3(0.5, GROUND, 13.0), 1.5],
			["palm_coconut_a", Vector3(-14.0, GROUND, 20.0), 1.1], ["island_tree_01", Vector3(-26.0, GROUND, 8.0), 2.0],
			["jacaranda_tree", Vector3(45.0, GROUND, 22.0), .7], ["palm_coconut_b", Vector3(40.0, GROUND, -6.0), .9],
			["island_tree_01", Vector3(26.5, GROUND, -2.0), 1.4], ["jacaranda_tree", Vector3(5.0, GROUND, 58.0), .6],
			["palm_coconut_a", Vector3(-30.0, GROUND, 40.0), 1.3], ["island_tree_02", Vector3(20.0, GROUND, 4.0), 1.3],
			["banana_plant", Vector3(13.6, GROUND, 6.4), 1.0], ["banana_small", Vector3(8.6, GROUND, 7.8), 1.1],
			["palm_coconut_b", Vector3(55.0, GROUND, 55.0), 1.1],
			# A palm and banana grove on the open lane outside the courtyard gate.
			["palm_coconut_a", Vector3(16.6, GROUND, 3.8), 1.2], ["banana_plant", Vector3(15.2, GROUND, 6.6), 1.0],
			["tree_small_02", Vector3(16.9, GROUND, 6.8), 1.25], ["palm_coconut_b", Vector3(16.2, GROUND, 1.8), .8],
			["banana_small", Vector3(14.6, GROUND, 2.6), 1.0], ["island_tree_02", Vector3(-45.0, GROUND, 25.0), 2.2]]:
		_want(spec[1], spec[0], spec[2], 7.0)
	# A far ring of tree crowns that melts into the haze beyond the last streets.
	for i in 30:
		var angle := deg_to_rad(rng.randf_range(-100.0, 190.0))
		var radius := rng.randf_range(75.0, 150.0)
		var at := Vector3(6.0 + sin(angle) * radius, GROUND, 14.0 + cos(angle) * radius)
		var kind: String = ["jacaranda_tree", "island_tree_01", "palm_coconut_b", "palm_coconut_a", "island_tree_02"][rng.randi_range(0, 4)]
		var scale := rng.randf_range(.55, .8) if kind == "jacaranda_tree" else (rng.randf_range(1.6, 2.4) if kind.begins_with("island") else rng.randf_range(1.0, 1.4))
		_want(at, kind, scale, 10.0)

func _poles() -> void:
	# Concrete utility poles along street A (cross arms along Z) and street B (along X), with sagging wires.
	var lines := [[], []]
	for x in [-14.0, 0.0, 11.4, 24.0, 38.0]:
		lines[0].append(Vector3(x, GROUND, 15.6))
	for z in [-12.0, 2.0, 30.0, 44.0]:
		lines[1].append(Vector3(18.4, GROUND, z))
	for n in 2:
		var line: Array = lines[n]
		var arm_dir := Vector3.BACK if n == 0 else Vector3.RIGHT
		for i in line.size():
			var p: Vector3 = line[i]
			b._rod(p, p + Vector3.UP * 9.0, .14, "n pole", 10, .1)
			_no_trunk.append(Rect2(p.x - 1.0, p.z - 1.0, 2.0, 2.0))
			b._box("Pole cross arm", p + Vector3.UP * 8.5, Vector3(.1, .1, .1) + arm_dir * 1.5, "n pole")
			b._box("Pole transformer", p + Vector3.UP * 7.4 + Vector3(.3, 0, .3), Vector3(.45, .7, .45), "n frame dark")
			if i + 1 < line.size():
				var q: Vector3 = line[i + 1]
				for k in 3:
					var off := arm_dir * (-.6 + k * .6)
					_wire(p + Vector3.UP * 8.6 + off, q + Vector3.UP * 8.6 + off, .5)
	# The courtyard's own service drops from street A's pole.
	_wire(Vector3(11.4, GROUND + 8.0, 15.6), Vector3(6.0, 3.1, 2.92), .6)
	_wire(Vector3(11.4, GROUND + 8.3, 15.6), Vector3(12.6, 1.0, 5.4), .4)

func _wire(a: Vector3, c: Vector3, sag: float) -> void:
	var pts: Array = []
	for i in 11:
		var t := float(i) / 10
		pts.append(a.lerp(c, t) + Vector3.DOWN * sag * 4.0 * t * (1 - t))
	b._tube(pts, .012, "n wire", 4)

# ---------------------------------------------------------------- sky

func _sky(sun_direction: Vector3) -> void:
	var dome := MeshInstance3D.new()
	dome.name = "Sky dome"
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	dome.mesh = sphere
	dome.scale = Vector3.ONE * 450.0
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dome.layers = 2
	dome.extra_cull_margin = 16384.0
	var material := ShaderMaterial.new()
	material.shader = SKY_SHADER
	material.set_shader_parameter("sky_texture", load("res://assets/outdoor/sky/misty_afternoon_sky.png"))
	material.set_shader_parameter("sun_direction", sun_direction)
	# The HDRI's own (painted-out) sun sat at u = 0.4701; turn the panorama so its glow sits under ours.
	var sun_azimuth := atan2(sun_direction.x, -sun_direction.z)
	material.set_shader_parameter("yaw", (0.4701 - .5) * TAU - sun_azimuth)
	dome.material_override = material
	root.add_child(dome)
