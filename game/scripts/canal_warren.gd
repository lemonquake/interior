extends Node3D
## 0.18 canal warren: the hidden back of the squatter settlement, behind the far-bank fence. A narrow, black
## estero (drainage canal) runs between two rows of stilt shanties whose upper storeys lean over it; patched
## roofs of plywood, tin and tarp close the gap, so the boardwalks along it are one long tunnel through the
## houses. It is reached through a pried-open tin sheet in the fence (far bank, z 8) and left through another
## near the road bridge (z 54.7).
##
## The route: alley -> east boardwalk south (a caved-in stretch you crouch under, one failing bulb) -> plank
## bridge -> west boardwalk north, through a family room (dying fluorescent tube, a radio that still plays,
## a light switch), an altar room (one votive candle), an open courtyard with a hand pump (moonlight only)
## and the back of a padlocked sari-sari store (a kerosene lamp) -> second bridge -> alley -> exit.
## Locked doors along the way can be knocked on (the town's knock gesture, neighborhood_encounters.gd).
## Loose pails, basins, bottles, pots, crates and plastic chairs are rigid bodies (loose_props.gd).
##
## Built by canal_settlement.gd with its builder, materials and kit; coordinates are river coordinates (u, z)
## like the settlement's, and d = metres east of the estero's centre line ec(z).

const LooseProps := preload("res://scripts/loose_props.gd")
const Usable := preload("res://scripts/neighborhood_usable.gd")
const WarrenUsable := preload("res://scripts/warren_usable.gd")
const WarrenDoor := preload("res://scripts/warren_door.gd")

const FLOOR := -2.10
const DECK := -2.05          # boardwalk top
const COVER := FLOOR + 2.32  # underside of the tunnel roof
const EW := -3.55            # estero water
const EBED := -4.10
const Z0 := -15.6            # the warren's south and north walls (the estero runs into culverts there)
const Z1 := 58.6
const WEST_U := -53.2
const FENCE_U := -28.5
const ENTRY_Z := 8.0
const EXIT_Z := 54.7
const B1_Z := -11.0
const B2_Z := 52.6
const EAST_SOUTH := Vector2(-11.9, 9.2)  # z span of the east boardwalk's south part
const EAST_NORTH := Vector2(51.6, 55.8)
const WEST_WALK := Vector2(-11.9, 53.5)
const HOUSE_D := 2.45        # house fronts stand this far from the centre line
const WALK_IN := .85         # boardwalks reach this far over the water
const ROOMS := [["family", 1.0, 6.0], ["altar", 18.0, 23.0], ["store", 40.0, 45.0]]
const ROOM_BACK := -6.5
const YARD := Vector2(28.0, 34.0)
const SAG := Vector2(-2.2, -.3)  # the caved-in stretch of the east boardwalk
const SLITS := [Vector2(-6.9, -6.3), Vector2(12.4, 13.1), Vector2(36.2, 36.9), Vector2(47.4, 48.0), Vector2(-14.2, -13.4),
	Vector2(-9.6, -9.1), Vector2(-3.4, -2.9), Vector2(2.3, 2.8), Vector2(6.6, 7.0), Vector2(9.6, 10.1), Vector2(15.3, 15.8),
	Vector2(25.1, 25.6), Vector2(38.3, 38.8), Vector2(50.3, 50.8)]
## Moonlight falls through the holes in the roofs: a faint blue pool under most of them (no lamp, just the moon).
const SPILLS := [-6.6, 12.75, 36.55, 47.7, -9.35, -3.15, 2.55, 6.8, 9.85, 15.55, 25.35, 38.55, 50.55]
const LINES := ["Hello? ...Nobody.", "Padlocked. From the outside.", "Something moved in there. Or I imagined it.",
	"It smells like something died behind this door.", "Locked. A wet rag is stuffed under it.",
	"Someone sprayed a number on it. A census mark... or a warning.", "I can hear dripping inside.", "Locked. Good."]

var s: Node3D
var b
var rng := RandomNumberGenerator.new()
var lights: Array[Dictionary] = []
var elapsed := 0.0
var radio
var light_switch
var pump
var _hinted := false
var _player: Node
var stats := {"houses": 0, "doors": 0, "locked": 0, "props": 0, "lights": 0, "usables": 0, "planks": 0, "decals": 0, "junk": 0}

# ------------------------------------------------------------------------------------------------ geometry

static func rx(z: float) -> float:
	return -66.0 + 2.4 * sin((z - 4.0) * .052)

static func ec(z: float) -> float:
	return -41.0 + 1.1 * sin((z + 10.0) * .09)

## dx/dz of the estero's centre line in world space.
static func slope(z: float) -> float:
	return 2.4 * .052 * cos((z - 4.0) * .052) + 1.1 * .09 * cos((z + 10.0) * .09)

static func at(u: float, y: float, z: float) -> Vector3:
	return Vector3(rx(z) + u, y, z)

static func pos(d: float, y: float, z: float) -> Vector3:
	return at(ec(z) + d, y, z)

## Local X across the estero (east), Z along it (north).
static func along(z: float) -> Basis:
	var t := Vector3(slope(z), 0, 1).normalized()
	return Basis(Vector3(t.z, 0, -t.x), Vector3.UP, t)

## Kit-house frames: local +X toward the water.
static func faces_west(z: float) -> Basis:
	var t := Vector3(slope(z), 0, 1).normalized()
	var x := Vector3(-t.z, 0, t.x)
	return Basis(x, Vector3.UP, x.cross(Vector3.UP))

static func faces_east(z: float) -> Basis:
	return along(z)

## Terrain height inside the warren (canal_settlement.ground() defers to this west of the old fence).
static func ground(u: float, z: float, n: float) -> float:
	if z > Z0 - .2 and z < Z1 + .2:
		var d := absf(u - ec(z))
		if d < 1.3: return EBED + n * .08
		if d < 1.8: return lerpf(EBED, EW - .2, (d - 1.3) / .5) + n * .05
		if d < 2.05: return lerpf(EW - .2, FLOOR - .03, (d - 1.8) / .25)
	return FLOOR + n * .05

static func in_spans(z: float, spans: Array) -> bool:
	for span: Vector2 in spans:
		if z >= span.x and z <= span.y: return true
	return false

# ------------------------------------------------------------------------------------------------ build

func build(settlement: Node3D) -> void:
	name = "Canal warren"
	s = settlement
	b = settlement.b
	rng.seed = 180818
	_materials()
	_water()
	_banks()
	_houses()
	_walks()
	_bridges()
	_covers()
	_rooms()
	_yard()
	_ends()
	_gates()
	_bounds()
	_dressing()
	_props()
	_lights()
	_sounds()
	stats["lights"] = lights.size()
	set_meta("counts", stats)

func _materials() -> void:
	var net := StandardMaterial3D.new()
	net.resource_name = "Warren / mosquito net"
	net.albedo_color = Color(.4, .41, .37, .16)
	net.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	net.cull_mode = BaseMaterial3D.CULL_DISABLED
	net.roughness = 1.0
	b._materials["net"] = net
	var tube := StandardMaterial3D.new()
	tube.albedo_color = Color(.8, .85, .85)
	tube.emission_enabled = true
	tube.emission = Color(.75, .92, 1.0)
	tube.emission_energy_multiplier = 3.0
	b._materials["tube"] = tube
	b._flat("banig", Color(.42, .33, .2), .95)
	b._flat("altar red", Color(.38, .04, .04), .6)
	b._flat("altar gold", Color(.55, .42, .12), .35)
	(b._materials["altar gold"] as StandardMaterial3D).metallic = .8
	b._flat("sachet a", Color(.62, .12, .1), .4)
	b._flat("sachet b", Color(.1, .3, .6), .4)
	b._flat("sachet c", Color(.75, .6, .1), .4)
	b._flat("iron", Color(.08, .085, .08), .55)
	(b._materials["iron"] as StandardMaterial3D).metallic = .7
	b._flat("screen", Color(.03, .04, .045), .15)
	stats["textured_prop_materials"] = InteriorHorrorPropMaterials.dress_palette(b._materials)
	var water: ShaderMaterial = (b._materials["water"] as ShaderMaterial).duplicate()
	water.set_shader_parameter("water_color", Color(.010, .012, .006))
	water.set_shader_parameter("scum_color", Color(.085, .08, .035))
	water.set_shader_parameter("flow_speed", .008)
	water.set_shader_parameter("sky_reflection", .3)
	water.set_shader_parameter("glitter_energy", .15)
	b._materials["estero"] = water

## Box helper oriented along the estero at z.
func _along_box(label: String, d: float, y: float, z: float, size: Vector3, mat: String, solid := false, surface := "wood", tilt := Basis.IDENTITY) -> void:
	s._box(label, pos(d, y, z), size, mat, solid, surface, along(z) * tilt)

## A run of boxes following the estero from z0 to z1 (walls, rails, retaining boards).
func _strip(label: String, d: float, y: float, z0: float, z1: float, across: float, height: float, mat: String, solid := false, surface := "wood", step := 2.0) -> void:
	var z := z0
	while z < z1 - .01:
		var z2 := minf(z + step, z1)
		var zm := (z + z2) * .5
		_along_box(label, d, y, zm, Vector3(across, height, z2 - z + .02), mat, solid, surface)
		z = z2

func _water() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := Z0 - .4
	while z < Z1 + .4:
		var z2 := minf(z + .75, Z1 + .4)
		var q := [pos(-1.9, EW, z), pos(1.9, EW, z), pos(1.9, EW, z2), pos(-1.9, EW, z2)]
		var uv := [Vector2(-1.9, z), Vector2(1.9, z), Vector2(1.9, z2), Vector2(-1.9, z2)]
		for i in [0, 1, 2, 0, 2, 3]:
			tool.set_normal(Vector3.UP)
			tool.set_uv(uv[i])
			tool.add_vertex(q[i])
		z = z2
	var water := MeshInstance3D.new()
	water.name = "Estero water"
	water.mesh = tool.commit()
	water.material_override = b._materials["estero"]
	water.layers = 2
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

func _banks() -> void:
	# Both banks are shored up with whatever was at hand: hollow block, cement, old planks, sandbags.
	for side in [-1.0, 1.0]:
		var z := Z0
		while z < Z1:
			var z2 := minf(z + rng.randf_range(1.2, 3.0), Z1)
			var mat: String = ["block", "cement", "wood", "block", "rock"][rng.randi() % 5]
			var top := FLOOR - rng.randf_range(.03, .25)
			_along_box("Shored bank", side * 1.93, (EW - .5 + top) * .5, (z + z2) * .5, Vector3(.14, top - EW + .5, z2 - z + .02), mat)
			if rng.randf() < .35:
				for k in rng.randi_range(2, 4):
					b._sphere(pos(side * 1.8, EW + .05 + k * .14, z + rng.randf_range(.2, z2 - z - .2)), Vector3(.28, .09, .2), "sack", 6)
			z = z2
	# Rubbish rafts, bottles and foam caught in the black water.
	var z := Z0 + 1.0
	while z < Z1 - 1.0:
		var t := Basis(Vector3.UP, rng.randf_range(-.3, .3) + PI * .5).scaled(Vector3(.42, .42, .42))
		s._kit(["floating_a", "floating_b", "floating_c"][rng.randi() % 3], pos(rng.randf_range(-.6, .6), EW + .005, z), along(z) * t, "Estero rubbish")
		stats.junk += 1
		z += rng.randf_range(2.0, 4.5)
	for i in 110:
		var zz := rng.randf_range(Z0, Z1)
		var p := pos(rng.randf_range(-1.6, 1.6), EW + .012, zz)
		match rng.randi() % 3:
			0: b._sphere(p, Vector3(rng.randf_range(.12, .28), .07, rng.randf_range(.1, .22)), ["plastic white", "plastic black", "plastic blue", "foam", "foam stained"][rng.randi() % 5], 6)
			1: b._rod(p, p + Vector3(rng.randf_range(-.22, .22), 0, rng.randf_range(-.22, .22)), .035, ["pet", "glass green", "can"][rng.randi() % 3], 7)
			_: b._quad([p + Vector3(-.2, 0, -.15), p + Vector3(.2, 0, -.15), p + Vector3(.2, 0, .15), p + Vector3(-.2, 0, .15)], Vector3.UP, ["scum", "paper", "cardboard"][rng.randi() % 3])
	# Stilts of old structures stand in the water.
	for i in 40:
		var zz := rng.randf_range(Z0 + 1, Z1 - 1)
		var dd := rng.randf_range(-1.2, 1.2)
		b._rod(pos(dd, EBED - .1, zz), pos(dd + rng.randf_range(-.15, .15), EW + rng.randf_range(.3, 1.4), zz + rng.randf_range(-.1, .1)), rng.randf_range(.04, .07), "wood", 6)

# ------------------------------------------------------------------------------------------------ houses

func _houses() -> void:
	var kit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(s.KIT + "kit.json"))
	var pool: Array = []
	for spec: Dictionary in kit.houses:
		# River houses on stilts would plant their posts in the boardwalk; only flush-fronted ones.
		if spec.row != "river" or (spec.colliders as Array).size() == 1:
			pool.append(spec)
	var order := range(pool.size())
	for i in order.size():
		var j := rng.randi_range(i, order.size() - 1)
		var tmp: int = order[i]
		order[i] = order[j]
		order[j] = tmp
	var next := 0
	for row in ["east", "west"]:
		var gaps: Array = [Vector2(ENTRY_Z - .8, ENTRY_Z + .8), Vector2(EXIT_Z - .8, EXIT_Z + .8)] if row == "east" else \
			[Vector2(1.0 - .15, 6.0 + .15), Vector2(18.0 - .15, 23.0 + .15), Vector2(YARD.x - .15, YARD.y + .15), Vector2(40.0 - .15, 45.0 + .15)]
		var z := Z0 + .25
		while z < Z1 - 2.5:
			var spec: Dictionary = pool[order[next % order.size()]]
			next += 1
			var w: float = spec.width
			var blocked := false
			for gap: Vector2 in gaps:
				if z < gap.y and z + w > gap.x:
					z = gap.y
					blocked = true
			if blocked: continue
			if z + w > Z1 - .2: break
			var zc := z + w * .5
			var walk: bool = row == "west" and zc > WEST_WALK.x and zc < WEST_WALK.y or row == "east" and (in_spans(zc, [EAST_SOUTH, EAST_NORTH]))
			_house(spec, row, zc, walk)
			z += w + rng.randf_range(.04, .2)
	# Back houses close the west row behind the rooms and the courtyard.
	for room: Array in ROOMS:
		var spec: Dictionary = pool[pool.size() - 1 - (int(room[1]) % 6)]
		var zc: float = (room[1] + room[2]) * .5
		var p := pos(ROOM_BACK - .12, FLOOR, zc)
		s._kit((spec.file as String).get_basename(), p, faces_east(zc), "Warren house")
		_colliders(spec, p, faces_east(zc))
		stats.houses += 1
	# Behind the courtyard a low back house closes the gap in the west row.
	for i in 2:
		var spec: Dictionary = pool[order[(next + i) % order.size()]]
		if spec.row == "river": spec = pool[pool.size() - 1 - i]
		var zc := YARD.x + 1.6 + i * 3.0
		var p := pos(-8.6, FLOOR, zc)
		s._kit((spec.file as String).get_basename(), p, faces_east(zc), "Warren house")
		_colliders(spec, p, faces_east(zc))
		stats.houses += 1

func _house(spec: Dictionary, row: String, zc: float, walk: bool) -> void:
	var east := row == "east"
	var basis := faces_west(zc) if east else faces_east(zc)
	var p := pos(HOUSE_D if east else -HOUSE_D, FLOOR, zc)
	s._kit((spec.file as String).get_basename(), p, basis, "Warren house")
	_colliders(spec, p, basis)
	stats.houses += 1
	# The census crew sprayed a number on every front.
	s._decal(p + basis.x * .02 + Vector3.UP * rng.randf_range(1.5, 2.0) + basis.z * rng.randf_range(-.8, .8), basis.x, .6, "census_%02d" % (rng.randi() % 8))
	stats.decals += 1
	if not walk: return
	for door: Dictionary in spec.doors:
		if door.kind == "boarded": continue
		var local_z: float = spec.width * .5 - float(door.s)
		if absf(local_z) > spec.width * .5 - .5: continue
		_locked_door(p + basis.z * local_z, basis.x, "metal" if door.kind == "metal" else "wood")
	if rng.randf() < .7:
		s._decal(p + basis.x * .02 + Vector3.UP * rng.randf_range(.6, 1.4) + basis.z * rng.randf_range(-1.2, 1.2), basis.x, rng.randf_range(.7, 1.3))
		stats.decals += 1

func _colliders(spec: Dictionary, p: Vector3, basis: Basis) -> void:
	for box: Dictionary in spec.colliders:
		var c := Vector3(box.center[0], box.center[1], box.center[2])
		var size := Vector3(box.size[0], box.size[1], box.size[2])
		s._solid("Warren house body", p + basis * c, size, "wood", basis)

## A permanently locked door on a house front: knocking uses the town's knock gesture and remarks.
func _locked_door(front: Vector3, normal: Vector3, style: String, size := Vector2(.9, 2.0), centre_y := FLOOR + 1.0) -> Node3D:
	var door := Usable.new()
	door.kind = "door"
	door.index = 100 + stats.locked
	door.name = "Warren locked door %02d" % stats.locked
	door.set_meta("lines", LINES)
	door.add_to_group("warren_locked")
	var basis := Basis(Vector3.UP.cross(normal), Vector3.UP, normal)
	door.transform = Transform3D(basis, front + normal * .05 + Vector3.UP * (centre_y - front.y))
	add_child(door)
	var w := size.x
	var h := size.y
	var body := _static(door, Vector3.ZERO, Vector3(w, h, .1))
	var main: String = "rust" if style == "metal" else ["wood", "wood grey"][rng.randi() % 2]
	_mesh_box(body, Vector3.ZERO, Vector3(w - .02, h, .07), main)
	if style == "metal":
		for y in [-.3, 0.0, .3]:
			_mesh_box(body, Vector3(0, y * h, .04), Vector3(w - .06, .05, .02), "shutter")
	else:
		for y in [-.31, .31]:
			_mesh_box(body, Vector3(0, y * h, .045), Vector3(w - .08, .07, .025), "wood")
		_mesh_box(body, Vector3(0, 0, .045), Vector3(.07, h * .65, .025), "wood", Basis(Vector3.FORWARD, .62))
	# Hasp, padlock and a chain wound through the handle.
	var lx := w * .5 - .12
	_mesh_box(body, Vector3(lx, -.02, .06), Vector3(.12, .05, .03), "rust")
	_mesh_box(body, Vector3(lx, -.1, .085), Vector3(.06, .07, .03), "iron")
	for k in 4:
		_mesh_box(body, Vector3(lx + .03 - k * .02, .05 + k * .05, .08), Vector3(.05, .03, .015), "rust", Basis(Vector3.FORWARD, .7 * (1 if k % 2 else -1)))
	stats.locked += 1
	stats.usables += 1
	return door

func _static(parent: Node3D, centre: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 5
	parent.add_child(body)
	var c := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	c.shape = box
	c.position = centre
	c.set_meta("surface", "wood")
	body.add_child(c)
	return body

func _mesh_box(parent: Node3D, centre: Vector3, size: Vector3, mat: String, basis := Basis.IDENTITY) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = b._materials[mat]
	mi.transform = Transform3D(basis, centre)
	mi.layers = 2
	parent.add_child(mi)
	return mi

func _mesh_tube(parent: Node3D, centre: Vector3, radius: float, height: float, mat: String, basis := Basis.IDENTITY, top := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top < 0 else top
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mi.mesh = mesh
	mi.material_override = b._materials[mat]
	mi.transform = Transform3D(basis, centre)
	mi.layers = 2
	parent.add_child(mi)
	return mi

# ------------------------------------------------------------------------------------------------ boardwalks

func _walks() -> void:
	_deck(WALK_IN, HOUSE_D, EAST_SOUTH.x, EAST_SOUTH.y)
	_deck(WALK_IN, HOUSE_D, EAST_NORTH.x, EAST_NORTH.y)
	_deck(-HOUSE_D, -WALK_IN, WEST_WALK.x, WEST_WALK.y)
	var bridges := [Vector2(B1_Z - .55, B1_Z + .55), Vector2(B2_Z - .55, B2_Z + .55)]
	_rail(WALK_IN - .05, EAST_SOUTH.x, EAST_SOUTH.y, bridges)
	_rail(WALK_IN - .05, EAST_NORTH.x, EAST_NORTH.y, bridges)
	var west_gaps: Array = bridges.duplicate()
	for room: Array in ROOMS: west_gaps.append(Vector2(room[1], room[2]))
	_rail(-WALK_IN + .05, WEST_WALK.x, WEST_WALK.y, west_gaps)
	# The courtyard is on the bank top beside the walk; the same rail keeps everyone out of the water.

func _deck(d0: float, d1: float, z0: float, z1: float) -> void:
	var mid := (d0 + d1) * .5
	var w := d1 - d0
	var z := z0
	while z < z1 - .01:
		var z2 := minf(z + 2.0, z1)
		var zm := (z + z2) * .5
		var c: CollisionShape3D = s._solid("Warren boardwalk", pos(mid, DECK - .1, zm), Vector3(w, .2, z2 - z + .02), "wood", along(zm))
		c.set_meta("surface", "wood")
		z = z2
	# Planks laid across, warped, some grey, a few missing over the bank (never over the water side).
	z = z0 + .1
	while z < z1:
		var zz := z
		var skip := rng.randf() < .05
		if d0 < 0:
			for room: Array in ROOMS:
				if zz > room[1] - .05 and zz < room[2] + .05: skip = true
		if not skip:
			var tilt := Basis(Vector3.FORWARD, rng.randf_range(-.025, .025)) * Basis(Vector3.UP, rng.randf_range(-.04, .04))
			_along_box("Boardwalk plank", mid, DECK - .025 - rng.randf_range(0, .012), zz, Vector3(w + rng.randf_range(-.08, .1), .045, .19), ["wood", "wood", "wood grey"][rng.randi() % 3], false, "wood", tilt)
			stats.planks += 1
		z += .21
	# Bearers and stilts down into the muck on the water side.
	_strip("Boardwalk bearer", d0 + .06 if d0 < 0 else d1 - .06, DECK - .12, z0, z1, .09, .1, "wood")
	_strip("Boardwalk bearer", d1 - .06 if d0 < 0 else d0 + .06, DECK - .12, z0, z1, .09, .1, "wood")
	z = z0 + .3
	while z < z1:
		var edge := d0 if absf(d0) < absf(d1) else d1
		b._rod(pos(edge, EBED - .2, z), pos(edge, DECK - .1, z + rng.randf_range(-.08, .08)), .05, "wood", 6)
		z += rng.randf_range(1.2, 1.8)

func _rail(d: float, z0: float, z1: float, gaps: Array) -> void:
	# Posts with a top rail and a mid rail of salvaged lumber; pipe and rope where the wood ran out.
	var z := z0
	while z < z1 - .05:
		var z2 := minf(z + 1.6, z1)
		var open := false
		for gap: Vector2 in gaps:
			if z2 > gap.x and z < gap.y:
				if z < gap.x - .1:
					z2 = gap.x
				else:
					open = true
					z2 = gap.y
		if not open and z2 - z > .05:
			var zm := (z + z2) * .5
			_along_box("Rail post", d, DECK + .48, z, Vector3(.07, .96, .07), "wood")
			var mat: String = ["wood", "wood grey", "rust", "wood"][rng.randi() % 4]
			_along_box("Rail", d, DECK + .93, zm, Vector3(.05, .07, z2 - z + .04), mat, false, "wood", Basis(Vector3.RIGHT, rng.randf_range(-.04, .04)))
			if rng.randf() < .7:
				_along_box("Mid rail", d, DECK + .5, zm, Vector3(.04, .06, z2 - z), "wood grey")
			s._solid("Warren rail", pos(d, DECK + .6, zm), Vector3(.1, 1.2, z2 - z + .02), "wood", along(zm))
		z = z2

func _bridges() -> void:
	for zb in [B1_Z, B2_Z]:
		var z0: float = zb - .5
		var z1: float = zb + .5
		var zz: float = z0 + .08
		while zz < z1:
			s._beam("Bridge plank", pos(-HOUSE_D + .05, DECK - .03, zz), pos(HOUSE_D - .05, DECK - .03 + rng.randf_range(-.02, .02), zz + rng.randf_range(-.04, .04)), .17, .045, ["wood", "wood grey"][rng.randi() % 2])
			zz += .19
		for z in [z0 + .05, z1 - .05]:
			s._beam("Bridge stringer", pos(-HOUSE_D, DECK - .12, z), pos(HOUSE_D, DECK - .16, z), .09, .12, "wood")
		b._rod(pos(0, EBED - .2, zb), pos(0, DECK - .2, zb), .07, "wood", 6)
		s._solid("Warren bridge", pos(0, DECK - .1, zb), Vector3(HOUSE_D * 2, .2, 1.0), "wood", along(zb))
		for side in [-1.0, 1.0]:
			var z: float = zb + side * .5
			for d in [-WALK_IN, 0.0, WALK_IN]:
				_along_box("Bridge post", d, DECK + .48, z, Vector3(.07, .96, .07), "wood")
			s._beam("Bridge rail", pos(-WALK_IN, DECK + .93, z), pos(WALK_IN, DECK + .9, z), .06, .06, "wood grey" if side < 0 else "rust")
			s._solid("Warren bridge rail", pos(0, DECK + .6, z), Vector3(WALK_IN * 2 + .1, 1.2, .1), "wood", along(z))

# ------------------------------------------------------------------------------------------------ the tunnel roof

func _covers() -> void:
	var room_spans: Array = []
	for room: Array in ROOMS: room_spans.append(Vector2(room[1], room[2]))
	var open: Array = SLITS.duplicate()
	open.append(YARD)
	_cover(-WALK_IN, HOUSE_D, Z0 + .2, Z1 - .2, open)
	_cover(-HOUSE_D, -WALK_IN, Z0 + .2, Z1 - .2, open + room_spans)
	# The caved-in stretch: the roof hangs down to waist height; you have to crouch to pass.
	var low := FLOOR + 1.27
	s._solid("Collapsed roof", pos((WALK_IN + HOUSE_D) * .5, low + (COVER - low) * .5 + .02, (SAG.x + SAG.y) * .5), Vector3(HOUSE_D - WALK_IN + .2, COVER - low, SAG.y - SAG.x), "wood", along(SAG.x))
	for i in 7:
		var z := lerpf(SAG.x, SAG.y, i / 6.0)
		var drop := low + rng.randf_range(0, .18)
		s._beam("Fallen joist", pos(WALK_IN - .2, drop + rng.randf_range(.05, .2), z), pos(HOUSE_D + .1, COVER - .05, z + rng.randf_range(-.3, .3)), .08, .1, "wood")
	s._beam("Fallen roof sheet", pos(WALK_IN - .1, low + .05, SAG.x - .2), pos(HOUSE_D, COVER - .1, SAG.y + .3), 1.6, .02, "roof")
	s._beam("Sagging plywood", pos(WALK_IN, low + .12, SAG.y + .1), pos(HOUSE_D - .1, COVER - .2, SAG.x - .3), 1.3, .03, "wood grey")
	for k in 3:
		s._kit("rubble_a" if k % 2 else "heap_small_b", pos(HOUSE_D - .2, DECK, SAG.x + .5 + k * .6), along(SAG.x) * Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * .45), "Fallen debris")

func _cover(d0: float, d1: float, z0: float, z1: float, open: Array) -> void:
	var w := d1 - d0
	var mid := (d0 + d1) * .5
	var z := z0
	while z < z1:
		if not in_spans(z, open) and not (d0 > 0 and z > SAG.x and z < SAG.y):
			s._beam("Roof joist", pos(d0 - .05, COVER + .06, z), pos(d1 + .05, COVER + .06 + rng.randf_range(-.06, .03), z + rng.randf_range(-.05, .05)), .07, .11, "wood")
		z += rng.randf_range(.5, .75)
	z = z0
	while z < z1 - .01:
		var z2 := minf(z + rng.randf_range(.9, 1.4), z1)
		var zm := (z + z2) * .5
		if not in_spans(zm, open) and not (d0 > 0 and zm > SAG.x - .2 and zm < SAG.y + .2):
			var mat: String = ["roof", "tin", "wood grey", "roof", "tarp blue", "wood", "tarp orange"][rng.randi() % 7]
			var sag := rng.randf_range(0, .08)
			_along_box("Tunnel roof", mid, COVER + .14 - sag, zm, Vector3(w + .1, .03, z2 - z + .08), mat, false, "wood", Basis(Vector3.RIGHT, rng.randf_range(-.04, .04)))
			if rng.randf() < .2:
				# Tyres and rocks hold the sheets down.
				b._ring(pos(mid + rng.randf_range(-.4, .4), COVER + .26, zm), .3, "rubber", Basis(Vector3.RIGHT, PI * .5), .09, 12)
			s._solid("Tunnel roof", pos(mid, COVER + .3, zm), Vector3(w, .3, z2 - z + .02), "wood", along(zm))
			# Things hang from the joists: a cut cable, a plastic bag, a rag on a nail.
			if rng.randf() < .35:
				var p := pos(mid + rng.randf_range(-w * .4, w * .4), COVER, zm)
				match rng.randi() % 3:
					0: b._tube([p, p + Vector3(.05, -.5, .02), p + Vector3(.02, -rng.randf_range(.7, 1.0), .08)], .008, "wire", 4)
					1: b._sphere(p + Vector3.DOWN * .18, Vector3(.13, .2, .1), ["plastic white", "plastic black", "plastic red"][rng.randi() % 3], 6)
					_: _rag(p, p + Vector3(.25, 0, .05))
		z = z2
	# Old wiring along the underside.
	for k in 2:
		var a := pos(mid + rng.randf_range(-w * .3, w * .3), COVER - .02, z0)
		var zz := z0
		while zz < z1 - 3:
			var c := pos(mid + rng.randf_range(-w * .3, w * .3), COVER - .03, zz + 3.0)
			s._wire(a, c, rng.randf_range(.05, .25), .007)
			a = c
			zz += 3.0

func _rag(a: Vector3, c: Vector3) -> void:
	var drop := rng.randf_range(.35, .7)
	var mat := "cloth %d" % (rng.randi() % 4)
	b._quad([a, c, c + Vector3(.02, -drop, .03), a + Vector3(-.02, -drop * rng.randf_range(.8, 1.1), .02)], Vector3.FORWARD, mat)

# ------------------------------------------------------------------------------------------------ rooms

func _rooms() -> void:
	for room: Array in ROOMS:
		_room_shell(room[0], room[1], room[2])
	_family_room(ROOMS[0][1], ROOMS[0][2])
	_altar_room(ROOMS[1][1], ROOMS[1][2])
	_store(ROOMS[2][1], ROOMS[2][2])

func _room_shell(kind: String, z0: float, z1: float) -> void:
	var zm := (z0 + z1) * .5
	var wall: String = ["paint %d" % (rng.randi() % 6), "wood", "wood grey", "paint %d" % (rng.randi() % 6)][rng.randi() % 4]
	var h := COVER - FLOOR
	# Floor over the bank and the walk, one plank floor.
	s._solid("Room floor", pos((ROOM_BACK - WALK_IN) * .5, DECK - .1, zm), Vector3(-WALK_IN - ROOM_BACK, .2, z1 - z0), "wood", along(zm))
	var z := z0 + .1
	while z < z1:
		_along_box("Floor board", (ROOM_BACK - WALK_IN) * .5, DECK - .025, z, Vector3(-WALK_IN - ROOM_BACK, .04, .2), ["wood", "wood grey"][rng.randi() % 2])
		z += .205
	# West (back) wall.
	_strip("Room wall", ROOM_BACK - .05, FLOOR + h * .5, z0, z1, .08, h, wall, true, "wood", 1.3)
	# East wall over the water, with a barred window.
	var win := Vector2(zm - .6, zm + .6)
	_strip("Room wall", -WALK_IN + .04, FLOOR + h * .5, z0, win.x, .07, h, wall, true)
	_strip("Room wall", -WALK_IN + .04, FLOOR + h * .5, win.y, z1, .07, h, wall, true)
	_along_box("Window sill", -WALK_IN + .04, FLOOR + .5, zm, Vector3(.08, 1.0, 1.2), wall, true)
	_along_box("Window head", -WALK_IN + .04, (FLOOR + 1.95 + COVER) * .5, zm, Vector3(.08, COVER - FLOOR - 1.95, 1.2), wall, true)
	for k in 6:
		_along_box("Window bar", -WALK_IN + .04, FLOOR + 1.47, win.x + .1 + k * .2, Vector3(.025, .95, .025), "rust")
	s._solid("Window bars", pos(-WALK_IN + .04, FLOOR + 1.47, zm), Vector3(.06, .95, 1.2), "metal", along(zm))
	# Ceiling.
	_along_box("Room ceiling", (ROOM_BACK - WALK_IN) * .5, COVER + .02, zm, Vector3(-WALK_IN - ROOM_BACK + .1, .04, z1 - z0 + .1), ["wood grey", "wood", "paint 4"][rng.randi() % 3])
	z = z0 + .3
	while z < z1:
		_along_box("Ceiling joist", (ROOM_BACK - WALK_IN) * .5, COVER - .04, z, Vector3(-WALK_IN - ROOM_BACK, .08, .07), "wood")
		z += .8
	# End walls across the walk with a plank door in each; the door swings north, away from you going north.
	for end in [z0, z1]:
		var doorway := Vector2(-2.15, -1.25)
		var left := ROOM_BACK - .05
		_along_box("Room end wall", (left + doorway.x) * .5, FLOOR + h * .5, end, Vector3(doorway.x - left, h, .08), wall, true)
		_along_box("Room end wall", (doorway.y - WALK_IN + .04) * .5, FLOOR + h * .5, end, Vector3(-WALK_IN + .04 - doorway.y, h, .08), wall, true)
		_along_box("Door head", (doorway.x + doorway.y) * .5, (FLOOR + 2.0 + COVER) * .5, end, Vector3(doorway.y - doorway.x, COVER - FLOOR - 2.0, .08), wall, true)
		_along_box("Door jamb", doorway.x - .03, FLOOR + 1.0, end, Vector3(.06, 2.0, .12), "wood")
		_along_box("Door jamb", doorway.y + .03, FLOOR + 1.0, end, Vector3(.06, 2.0, .12), "wood")
		_hinged_door(pos(doorway.y - .01, DECK + .01, end), along(end), doorway.y - doorway.x - .04, 1.94, "wood" if rng.randf() < .6 else "wood grey", "door", 92.0)
		var outer := -1.0 if end == z0 else 1.0
		s._decal(pos(-3.6, FLOOR + rng.randf_range(1.0, 1.6), end + outer * .06), along(end).z * outer, rng.randf_range(.9, 1.4))
		stats.decals += 1
	# Inside, the walls are papered with calendars, newspaper and a faded poster.
	for k in 3:
		var zz := rng.randf_range(z0 + .5, z1 - .5)
		var p := pos(ROOM_BACK + .02, FLOOR + rng.randf_range(1.1, 1.7), zz)
		var a := along(zz)
		var hw := rng.randf_range(.18, .32)
		var hh := rng.randf_range(.25, .42)
		b._quad([p - a.z * hw - Vector3.UP * hh, p + a.z * hw - Vector3.UP * hh, p + a.z * hw + Vector3.UP * hh, p - a.z * hw + Vector3.UP * hh], a.x, "paper")

func _hinged_door(hinge: Vector3, basis: Basis, width: float, height: float, mat: String, label: String, angle: float) -> Node3D:
	var door := WarrenDoor.new()
	door.name = "Warren door %02d" % stats.doors
	door.label = label
	door.open_angle_deg = angle
	door.swing_seconds = .9
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
	if mat == "roof" or mat == "tin":
		# A corrugated sheet nailed to two battens.
		_mesh_box(leaf, Vector3(-width * .5, height * .5, 0), Vector3(width, height, .02), mat)
		for y in [.35, height - .35]:
			_mesh_box(leaf, Vector3(-width * .5, y, .03), Vector3(width - .05, .07, .04), "wood")
	else:
		var x := 0.0
		while x < width - .02:
			var pw := minf(rng.randf_range(.12, .2), width - x)
			_mesh_box(leaf, Vector3(-x - pw * .5, height * .5 - rng.randf_range(0, .03), 0), Vector3(pw - .01, height - rng.randf_range(0, .05), .035), mat)
			x += pw
		for y in [.3, height * .5, height - .3]:
			_mesh_box(leaf, Vector3(-width * .5, y, .03), Vector3(width - .06, .08, .025), "wood")
		_mesh_box(leaf, Vector3(-width + .1, height * .48, .055), Vector3(.03, .12, .04), "rust")
	door.transform = Transform3D(basis, hinge)
	add_child(door)
	stats.doors += 1
	return door

func _family_room(z0: float, z1: float) -> void:
	var a := along((z0 + z1) * .5)
	# A floor mat (banig) with a pillow and a sagging mosquito net over it.
	var mat_c := pos(-4.6, DECK + .006, z0 + 1.6)
	_along_box("Banig", -4.6, DECK + .006, z0 + 1.6, Vector3(1.6, .012, 1.1), "banig")
	_along_box("Pillow", -5.2, DECK + .06, z0 + 1.6, Vector3(.3, .1, .5), "cloth 2")
	_along_box("Blanket", -4.3, DECK + .03, z0 + 1.7, Vector3(.9, .05, 1.0), "cloth 0", false, "wood", Basis(Vector3.UP, .2))
	var net_top := mat_c + Vector3.UP * 1.35
	var corners: Array[Vector3] = []
	for c in [Vector2(-.85, -.6), Vector2(.85, -.6), Vector2(.85, .6), Vector2(-.85, .6)]:
		corners.append(net_top + a.x * c.x + a.z * c.y)
	for i in 4:
		var p: Vector3 = corners[i]
		var q: Vector3 = corners[(i + 1) % 4]
		b._quad([p, q, q + Vector3.DOWN * 1.22, p + Vector3.DOWN * 1.27], (p + q - net_top * 2.0).normalized(), "net")
	b._quad([corners[0], corners[1], corners[2], corners[3]], Vector3.DOWN, "net")
	for c in corners: s._wire(c, c + Vector3.UP * (COVER - c.y), 0.0, .004)
	# A low table, an old TV on a cabinet, clothes on a line, a calendar.
	_along_box("Low table", -3.4, DECK + .36, z1 - 1.4, Vector3(.7, .04, .9), "wood grey", true)
	for c in [Vector2(-.3, -.4), Vector2(.3, -.4), Vector2(.3, .4), Vector2(-.3, .4)]:
		_along_box("Table leg", -3.4 + c.x, DECK + .17, z1 - 1.4 + c.y, Vector3(.04, .34, .04), "wood")
	s._kit("cabinet", pos(-6.0, DECK, z1 - 1.0), a * Basis(Vector3.UP, PI * .5).scaled(Vector3.ONE * .8), "Cabinet")
	s._solid("Cabinet", pos(-6.0, DECK + .45, z1 - 1.0), Vector3(.5, .9, .8), "wood", a)
	_along_box("Old TV", -6.0, DECK + 1.12, z1 - 1.0, Vector3(.45, .42, .5), "plastic black")
	_along_box("TV screen", -5.77, DECK + 1.12, z1 - 1.0, Vector3(.01, .32, .38), "screen")
	s._decal(pos(-5.76, DECK + 1.12, z1 - 1.0), a.x, .25, "throw_02")
	b._tube([pos(ROOM_BACK + .1, FLOOR + 1.9, z0 + .3), pos(-3.6, FLOOR + 1.75, (z0 + z1) * .5), pos(ROOM_BACK + .1, FLOOR + 1.9, z1 - .3)], .006, "wire", 4)
	for k in 5:
		var t := (k + .5) / 5.0
		var p: Vector3 = pos(lerpf(ROOM_BACK + .1, -3.6, 1.0 - absf(t - .5) * 2.0), FLOOR + 1.82, lerpf(z0 + .3, z1 - .3, t))
		_rag(p, p + a.z * .3)
	# The radio on the table still finds a station.
	radio = _usable("radio", pos(-3.4, DECK + .38, z1 - 1.3), a * Basis(Vector3.UP, PI * .5), Vector3(.32, .2, .12))
	var radio_body: Node3D = radio.get_child(0)
	_mesh_box(radio_body, Vector3(0, .1, 0), Vector3(.32, .2, .12), "plastic black")
	_mesh_box(radio_body, Vector3(-.07, .1, .062), Vector3(.14, .14, .01), "iron")
	_mesh_box(radio_body, Vector3(.09, .14, .062), Vector3(.1, .03, .01), "altar gold")
	_mesh_tube(radio_body, Vector3(.1, .4, 0), .004, .55, "can", Basis(Vector3.FORWARD, -.5))
	# The switch for the tube light, by the south door.
	light_switch = _usable("switch", pos(-2.35, FLOOR + 1.35, z0 + .07), a, Vector3(.08, .12, .04))
	_mesh_box(light_switch.get_child(0), Vector3(0, .06, 0), Vector3(.08, .12, .03), "plastic white")
	_mesh_box(light_switch.get_child(0), Vector3(0, .07, .02), Vector3(.02, .04, .02), "plastic black")
	light_switch.on = true
	_tube_light(pos(-3.4, COVER - .06, (z0 + z1) * .5), a)
	# A sack of clothes, a broken electric fan, a child's slipper.
	s._kit("heap_small_a", pos(-6.0, DECK, z0 + .7), a.scaled(Vector3.ONE * .6), "Room junk")
	b._sphere(pos(-2.9, DECK + .02, z0 + 2.8), Vector3(.1, .03, .22), "plastic blue", 6)

func _altar_room(z0: float, z1: float) -> void:
	var a := along((z0 + z1) * .5)
	var zm := (z0 + z1) * .5
	# A wall altar: a red-draped shelf, a framed Santo Nino picture, plastic flowers, rosaries and one candle.
	_along_box("Altar shelf", ROOM_BACK + .3, FLOOR + 1.05, zm, Vector3(.45, .05, 1.3), "wood", true)
	_along_box("Altar cloth", ROOM_BACK + .3, FLOOR + 1.0, zm, Vector3(.47, .14, 1.32), "altar red")
	for k in 2:
		_along_box("Altar bracket", ROOM_BACK + .2, FLOOR + .9, zm + (k - .5) * 1.0, Vector3(.25, .2, .04), "wood")
	_along_box("Picture frame", ROOM_BACK + .05, FLOOR + 1.55, zm, Vector3(.04, .62, .46), "altar gold")
	_along_box("Picture", ROOM_BACK + .075, FLOOR + 1.55, zm, Vector3(.01, .52, .36), "altar red")
	s._decal(pos(ROOM_BACK + .08, FLOOR + 1.55, zm), a.x, .3, "sign_04")
	# A small robed figure (the Santo Nino) under a glass dome, a crown of gold paint.
	_along_box("Figure robe", ROOM_BACK + .3, FLOOR + 1.2, zm - .35, Vector3(.1, .22, .09), "altar red")
	b._sphere(pos(ROOM_BACK + .3, FLOOR + 1.35, zm - .35), Vector3(.04, .045, .04), "foam stained", 8)
	b._rod(pos(ROOM_BACK + .3, FLOOR + 1.39, zm - .35), pos(ROOM_BACK + .3, FLOOR + 1.43, zm - .35), .032, "altar gold", 8, .045)
	for k in 6:
		b._sphere(pos(ROOM_BACK + .3 + rng.randf_range(-.1, .1), FLOOR + 1.12 + rng.randf_range(0, .12), zm + .2 + k * .07), Vector3(.035, .035, .035), ["plastic red", "plastic yellow", "plastic white"][k % 3], 6)
	for k in 3:
		var p := pos(ROOM_BACK + .06, FLOOR + 1.85, zm - .25 + k * .25)
		b._tube([p, p + Vector3(.04, -.15, 0), p + Vector3(.02, -.3, .03), p + Vector3(-.01, -.15, .04), p], .004, "altar gold", 3)
	var candle := Node3D.new()
	candle.name = "Altar candle"
	candle.position = pos(ROOM_BACK + .32, FLOOR + 1.08, zm + .05)
	add_child(candle)
	_mesh_tube(candle, Vector3(0, .05, 0), .035, .1, "candle glass", Basis.IDENTITY, .04)
	_light(candle, Vector3(0, .12, 0), Color(1, .32, .14), 3.2, .6, "candle", false)
	# Someone slept here: a stripped bed frame, a rotten mattress, a locked door to the back room.
	s._kit("mattress", pos(-4.2, DECK + .02, z1 - 1.3), a * Basis(Vector3.UP, rng.randf_range(-.2, .2)).scaled(Vector3.ONE * .8), "Mattress")
	_locked_door(pos(ROOM_BACK + .02, FLOOR, z0 + .8), a.x, "wood")
	for k in 4:
		s._decal(pos(rng.randf_range(-5.5, -3.0), FLOOR + rng.randf_range(1.2, 1.9), z0 + .06), a.z, rng.randf_range(.6, 1.0))
		stats.decals += 1

func _store(z0: float, z1: float) -> void:
	var a := along((z0 + z1) * .5)
	var zm := (z0 + z1) * .5
	# The walk passes the back of a sari-sari store: a counter and a wire grille from counter to ceiling, the
	# little window to buy through, and the shelves inside behind it.
	var grille_d := -2.6
	_along_box("Store counter", grille_d - .2, FLOOR + .5, zm, Vector3(.45, 1.0, z1 - z0 - .1), "wood grey", true)
	_along_box("Counter top", grille_d - .2, FLOOR + 1.02, zm, Vector3(.5, .04, z1 - z0 - .1), "wood")
	var z := z0 + .1
	while z < z1 - .05:
		_along_box("Grille bar", grille_d, (FLOOR + 1.04 + COVER) * .5, z, Vector3(.02, COVER - FLOOR - 1.04, .02), "rust")
		z += .12
	_along_box("Grille mesh", grille_d + .01, (FLOOR + 1.04 + COVER) * .5, zm, Vector3(.01, COVER - FLOOR - 1.04, z1 - z0 - .1), "chain")
	s._solid("Store grille", pos(grille_d, (FLOOR + 1.04 + COVER) * .5, zm), Vector3(.08, COVER - FLOOR - 1.04, z1 - z0), "metal", a)
	# The window: a hinged flap of grille, padlocked; "Pabili po!" gets no answer.
	var window := _locked_door(pos(grille_d + .02, FLOOR, zm), a.x, "metal", Vector2(.55, .45), FLOOR + 1.36)
	window.name = "Store window"
	window.set_meta("lines", ["Pabili po! ...No one.", "Closed. The padlock's rusted shut.", "Pabili po? ...Something knocked back. No. Just the wind."])
	# The sign over the window.
	_along_box("Store sign", grille_d + .05, COVER - .2, zm, Vector3(.03, .3, 1.6), "paint 0")
	s._decal(pos(grille_d + .07, COVER - .2, zm), a.x, 1.5, "sign_06")
	# Shelves inside: sachets in strips, bottles, cans, a sack of rice, an empty ice cooler.
	for k in 4:
		var y := FLOOR + .5 + k * .45
		_along_box("Store shelf", ROOM_BACK + .3, y, zm, Vector3(.45, .03, z1 - z0 - .6), "wood")
		for j in 9:
			var p := pos(ROOM_BACK + .3 + rng.randf_range(-.1, .1), y + .1, z0 + .5 + j * .45)
			if rng.randf() < .55:
				b._rod(p - Vector3.UP * .08, p + Vector3.UP * .08, .035, ["glass green", "can", "pet", "plastic red"][rng.randi() % 4], 7)
			elif rng.randf() < .5:
				b._sphere(p, Vector3(.08, .07, .08), "cardboard", 5)
	for j in 7:
		var top := pos(rng.randf_range(-5.0, -3.2), COVER - .05, z0 + .5 + j * .6)
		var strip := rng.randf_range(.5, .9)
		b._quad([top, top + a.z * .09, top + a.z * .09 + Vector3.DOWN * strip, top + Vector3.DOWN * strip], a.x, ["sachet a", "sachet b", "sachet c"][j % 3])
	b._sphere(pos(-4.6, DECK + .3, z0 + .6), Vector3(.35, .3, .3), "sack", 8)
	_along_box("Ice cooler", -4.0, DECK + .3, z1 - .6, Vector3(.7, .6, .5), "plastic red")
	# The kerosene lamp (gasera) still burns on the counter, inside the grille.
	var lamp := Node3D.new()
	lamp.name = "Gasera"
	lamp.position = pos(grille_d - .25, FLOOR + 1.04, zm - 1.4)
	add_child(lamp)
	_mesh_tube(lamp, Vector3(0, .06, 0), .045, .12, "can")
	_mesh_tube(lamp, Vector3(0, .14, 0), .006, .05, "wire")
	_light(lamp, Vector3(0, .2, 0), Color(1, .55, .22), 4.6, .75, "gasera", false)

## A usable object: Node3D with a StaticBody3D child the player's ray can target.
func _usable(kind: String, p: Vector3, basis: Basis, size: Vector3) -> Node3D:
	var node := WarrenUsable.new()
	node.kind = kind
	node.warren = self
	node.name = "Warren " + kind
	node.transform = Transform3D(basis, p)
	var body := _static(node, Vector3(0, size.y * .5, 0), size + Vector3(.04, .04, .04))
	body.name = "Body"
	add_child(node)
	stats.usables += 1
	return node

# ------------------------------------------------------------------------------------------------ courtyard

func _yard() -> void:
	var zm := (YARD.x + YARD.y) * .5
	var a := along(zm)
	# The courtyard (looban): open to the moon, a hand pump on a cracked pad, laundry, rooster cages, a gutted tricycle.
	_along_box("Pump pad", -4.2, FLOOR + .04, zm, Vector3(1.6, .1, 1.6), "cement", true, "concrete")
	_along_box("Pump drain", -4.2, FLOOR + .025, zm + 1.2, Vector3(.3, .03, .9), "muck")
	pump = _usable("pump", pos(-4.2, FLOOR + .08, zm), a * Basis(Vector3.UP, PI * .5), Vector3(.25, 1.1, .25))
	var pb: Node3D = pump.get_child(0)
	_mesh_tube(pb, Vector3(0, .45, 0), .07, .9, "iron")
	_mesh_tube(pb, Vector3(0, .95, 0), .09, .14, "iron")
	_mesh_tube(pb, Vector3(0, .7, .16), .03, .3, "iron", Basis(Vector3.RIGHT, PI * .5))
	var handle := Node3D.new()
	handle.name = "Handle"
	handle.position = Vector3(0, 1.0, 0)
	pump.add_child(handle)
	_mesh_box(handle, Vector3(-.4, .05, 0), Vector3(.8, .04, .04), "iron", Basis(Vector3.FORWARD, .25))
	pump._handle = handle
	s._decal(pos(-4.2, FLOOR + .1, zm), Vector3.UP, .8, "throw_01")
	# Laundry lines across the yard and over the water.
	for k in 3:
		var p0 := pos(-8.3, FLOOR + 2.3 + k * .15, YARD.x + 1.0 + k * 1.8)
		var p1 := pos(-1.2, FLOOR + 2.2 + k * .1, YARD.x + 1.4 + k * 1.7)
		b._tube([p0, p0.lerp(p1, .5) + Vector3.DOWN * .3, p1], .005, "wire", 3)
		for j in 6:
			var t := (j + .5) / 6.0
			var p := p0.lerp(p1, t) + Vector3.DOWN * sin(t * PI) * .3
			_rag(p, p + (p1 - p0).normalized() * rng.randf_range(.25, .45))
	b._tube([pos(-1.0, FLOOR + 2.6, YARD.x + 2.0), pos(0, FLOOR + 2.2, YARD.x + 2.2), pos(1.9, FLOOR + 2.7, YARD.x + 2.4)], .005, "wire", 3)
	for j in 4:
		var p := pos(-.6 + j * .6, FLOOR + 2.35 - sin(j / 3.0 * PI) * .3, YARD.x + 2.1 + j * .1)
		_rag(p, p + a.x * .35)
	# Rooster cages (for the sabong) of slats, empty.
	for k in 3:
		var c := pos(-7.4 + k * .9, FLOOR, YARD.y - .8)
		_cage(c, a)
	s._solid("Cages", pos(-6.5, FLOOR + .35, YARD.y - .8), Vector3(2.7, .7, .8), "wood", a)
	s._model("street/tricycle_b", pos(-6.6, FLOOR, YARD.x + 1.2), .95, rad_to_deg(atan2(a.x.x, a.x.z)) + 70.0, "Gutted tricycle", true, Vector3(0, 0, 6))
	s._model("street/oil_drum", pos(-2.4, FLOOR, YARD.y - .5), .85, rng.randf() * 360, "Water drum", true)
	s._model("street/oil_drum", pos(-8.0, FLOOR, zm), .85, rng.randf() * 360, "Water drum", true)
	for k in 5:
		s._kit(["heap_medium_a", "heap_small_a", "heap_small_b", "litter_a", "litter_b"][k], pos(rng.randf_range(-8.0, -5.5), FLOOR, rng.randf_range(YARD.x + .5, YARD.y - 1.5)), Basis(Vector3.UP, rng.randf() * TAU), "Yard rubbish")
		stats.junk += 1
	# A basketball ring nailed to the back house.
	var ring := pos(-8.5, FLOOR + 2.7, zm)
	_along_box("Backboard", -8.45, FLOOR + 2.95, zm, Vector3(.03, .6, .9), "wood grey")
	b._ring(ring + a.x * .3, .2, "rust", Basis(Vector3.RIGHT, PI * .5), .01, 14)
	for k in 3:
		s._decal(pos(-8.42, FLOOR + rng.randf_range(.8, 1.8), YARD.x + 1.0 + k * 1.8), a.x, rng.randf_range(.9, 1.5))
		stats.decals += 1

func _cage(c: Vector3, a: Basis) -> void:
	for k in 5:
		var t := k / 4.0 - .5
		b._rod(c + a.x * t * .7 + a.z * -.3, c + a.x * t * .5 + a.z * -.2 + Vector3.UP * .65, .012, "wood", 4)
		b._rod(c + a.x * t * .7 + a.z * .3, c + a.x * t * .5 + a.z * .2 + Vector3.UP * .65, .012, "wood", 4)
	b._ring(c + Vector3.UP * .65, .3, "wood", Basis(Vector3.RIGHT, PI * .5), .012, 10)
	b._ring(c + Vector3.UP * .05, .38, "wood", Basis(Vector3.RIGHT, PI * .5), .014, 10)

# ------------------------------------------------------------------------------------------------ ends, gates, bounds

func _ends() -> void:
	# Junk barricades close the ends of every boardwalk.
	_barricade(WALK_IN - .05, HOUSE_D, EAST_SOUTH.y + .15)
	_barricade(WALK_IN - .05, HOUSE_D, EAST_SOUTH.x - .15)
	_barricade(-HOUSE_D, -WALK_IN + .05, WEST_WALK.x - .15)
	_barricade(-HOUSE_D, -WALK_IN + .05, WEST_WALK.y + .15)
	_barricade(WALK_IN - .05, HOUSE_D, EAST_NORTH.x - .15)
	_barricade(WALK_IN - .05, HOUSE_D, EAST_NORTH.y + .15)
	# Concrete headwalls and culverts where the estero leaves the warren.
	for z in [Z0, Z1]:
		var inward := 1.0 if z == Z0 else -1.0
		_along_box("Culvert headwall", 0, (EBED - .3 + FLOOR + 1.0) * .5, z, Vector3(4.6, FLOOR + 1.0 - EBED + .3, .4), "concrete", true, "concrete")
		_along_box("Culvert mouth", 0, EW + .2, z + inward * .21, Vector3(1.4, 1.0, .02), "inside")
		for k in 7:
			_along_box("Culvert grate", -.6 + k * .2, EW + .2, z + inward * .24, Vector3(.03, 1.0, .03), "rust", false, "metal", Basis(Vector3.FORWARD, rng.randf_range(-.12, .12)))
		s._kit("floating_b", pos(0, EW + .01, z + inward * .9), along(z).scaled(Vector3.ONE * .5), "Culvert rubbish")

func _barricade(d0: float, d1: float, z: float) -> void:
	var mid := (d0 + d1) * .5
	var w := absf(d1 - d0)
	s._solid("Warren barricade", pos(mid, FLOOR + 1.0, z), Vector3(w, 2.0, .35), "wood", along(z))
	for k in 6:
		var y := FLOOR + .2 + k * .3
		s._beam("Barricade board", pos(mid - w * .55, y + rng.randf_range(-.1, .1), z + rng.randf_range(-.1, .1)), pos(mid + w * .55, y + rng.randf_range(-.15, .15), z + rng.randf_range(-.1, .1)), .18, .03, ["wood", "wood grey", "roof", "tin"][rng.randi() % 4])
	s._kit("heap_small_a" if rng.randf() < .5 else "heap_small_b", pos(mid, DECK, z), along(z) * Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * .7), "Barricade junk")
	s._decal(pos(mid, FLOOR + 1.2, z - .2), -along(z).z, .9, "sign_0%d" % (rng.randi() % 8))
	stats.junk += 1

func _gates() -> void:
	# Pried tin sheets in the far-bank fence: the only ways in and out.
	for spec in [[ENTRY_Z, 1.0], [EXIT_Z, -1.0]]:
		var zc: float = spec[0]
		var seg0: float = -16.0 + floor((zc + 16.0) / 2.5) * 2.5
		var seg1: float = seg0 + 2.5
		var t := Vector3(2.4 * .052 * cos((zc - 4.0) * .052), 0, 1).normalized()
		var wall_basis := Basis(t, Vector3.UP, t.cross(Vector3.UP))
		for piece in [Vector2(seg0, zc - .5), Vector2(zc + .5, seg1)]:
			var a := at(FENCE_U, FLOOR, piece.x)
			var c := at(FENCE_U, FLOOR, piece.y)
			if c.z - a.z < .05: continue
			s._box("Boundary fence", (a + c) * .5 + Vector3.UP * 1.2, Vector3(.08, 2.4, a.distance_to(c) + .05), "roof", true, "metal", Basis(Vector3.UP, -atan(2.4 * .052 * cos((zc - 4.0) * .052))))
		var hinge := at(FENCE_U, FLOOR + .02, zc + .48)
		_hinged_door(hinge, wall_basis, .94, 2.3, "roof", "tin sheet", 78.0 * spec[1])
		s._box("Door post", at(FENCE_U, FLOOR + 1.2, zc + .52), Vector3(.08, 2.4, .08), "wood", true)
		s._box("Door post", at(FENCE_U, FLOOR + 1.2, zc - .52), Vector3(.08, 2.4, .08), "wood", true)
		# Warnings sprayed on the outside, and a tag on the inside.
		s._decal(at(FENCE_U + .1, FLOOR + 1.5, zc - 1.0), Vector3(1, 0, 0), 1.0, "sign_02")
		s._decal(at(FENCE_U - .1, FLOOR + 1.3, zc + 1.0), Vector3(-1, 0, 0), 1.1)
		# The alley from the gate to the water: a tarp over it, junk along the walls.
		var span := (FENCE_U - (ec(zc) + HOUSE_D))
		for k in 3:
			var u0 := FENCE_U - .5 - k * span / 3.0
			b._quad([at(u0, FLOOR + 2.45, zc - .75), at(u0 - span / 3.0, FLOOR + 2.3, zc - .75), at(u0 - span / 3.0, FLOOR + 2.15, zc + .75), at(u0, FLOOR + 2.4, zc + .75)], Vector3.UP, ["tarp blue", "tarp orange", "roof"][k])
		for k in 4:
			var u := FENCE_U - 1.0 - k * span / 4.0
			s._kit(["litter_a", "litter_b", "heap_small_a", "litter_a"][k], at(u, FLOOR, zc + (.55 if k % 2 else -.55)), Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * .7), "Alley rubbish")
			stats.junk += 1

	# Makeshift steps up the far bank from the path: boards staked into the mud, old tyres as risers.
	var low := at(-7.3, s.path_y(ENTRY_Z), ENTRY_Z)
	var high := at(-13.6, FLOOR, ENTRY_Z)
	s._ramp("Bank steps", low + Vector3.UP * .02, high + Vector3.UP * .02, 1.3, "dirt")
	var steps := 11
	for k in steps + 1:
		var t := float(k) / steps
		var p := low.lerp(high, t)
		p.y = lerpf(low.y, high.y, t)
		s._beam("Bank step board", p + Vector3(0, -.03, -.6), p + Vector3(rng.randf_range(-.05, .05), -.03 + rng.randf_range(-.03, .03), .6), .22, .05, ["wood", "wood grey"][rng.randi() % 2])
		if k % 3 == 1:
			b._ring(p + Vector3(.12, -.14, -.75), .28, "rubber", Basis(Vector3.FORWARD, .3), .09, 12)
		b._rod(p + Vector3(.1, -.4, .62), p + Vector3(.1, .05, .62), .025, "wood", 5)
	# A trodden trail of litter climbs from the far-bank path to the entry sheet: the only hint it is used.
	var u := -8.6
	while u > FENCE_U + 1.2:
		var zz := ENTRY_Z + rng.randf_range(-.6, .6) + sin(u * .4) * .4
		s._kit("litter_a" if rng.randf() < .5 else "litter_b", at(u, s.ground(u, zz) - .01, zz), Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(.4, .65)), "Trail litter")
		stats.junk += 1
		u -= rng.randf_range(1.4, 2.6)
	b._sphere(at(-21.5, s.ground(-21.5, ENTRY_Z + .3) + .015, ENTRY_Z + .3), Vector3(.1, .025, .24), "plastic red", 6)

func _bounds() -> void:
	# A tall wall of tin and block around the back of the warren.
	var z := Z0
	while z < Z1:
		var z2 := minf(z + 2.5, Z1)
		var a := at(WEST_U, FLOOR, z)
		var c := at(WEST_U, FLOOR, z2)
		s._box("Warren back wall", (a + c) * .5 + Vector3.UP * 1.6, Vector3(.1, 3.2, a.distance_to(c) + .05), "roof" if rng.randf() < .6 else "block", true, "metal", Basis(Vector3.UP, -atan(2.4 * .052 * cos((z - 4.0) * .052))))
		z = z2
	for zz in [Z0 - .25, Z1 + .25]:
		var a := at(WEST_U, FLOOR, zz)
		var c := at(FENCE_U, FLOOR, zz)
		s._box("Warren end wall", (a + c) * .5 + Vector3.UP * 1.6, Vector3(c.x - a.x, 3.2, .25), "block", true, "concrete")
		for i in 3: s._decal(a.lerp(c, rng.randf_range(.1, .9)) + Vector3(0, rng.randf_range(.8, 1.8), .14 * (1.0 if zz < 0 else -1.0)), Vector3(0, 0, 1.0 if zz < 0 else -1.0), rng.randf_range(1.0, 1.6))

# ------------------------------------------------------------------------------------------------ dressing

func _dressing() -> void:
	# Graffiti along both walks: tags, throw-ups, warnings; litter on the boards.
	for span: Vector2 in [EAST_SOUTH, WEST_WALK]:
		var east := span == EAST_SOUTH
		var z := span.x + .5
		while z < span.y:
			var d := HOUSE_D + .03 if east else -HOUSE_D - .03
			var n: Vector3 = (-1.0 if east else 1.0) * along(z).x
			if rng.randf() < .55:
				s._decal(pos(d, FLOOR + rng.randf_range(.5, 1.7), z), n, rng.randf_range(.6, 1.4))
				stats.decals += 1
			if rng.randf() < .5:
				var dd := rng.randf_range(WALK_IN + .2, HOUSE_D - .2) * (1.0 if east else -1.0)
				s._kit("litter_a" if rng.randf() < .5 else "litter_b", pos(dd, DECK - .01, z + rng.randf_range(-.3, .3)), Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(.45, .7)), "Boardwalk litter")
				stats.junk += 1
			if rng.randf() < .3:
				# A sack or a heap against the house wall.
				var dd := (HOUSE_D - .3) * (1.0 if east else -1.0)
				if not _room_or_yard(z):
					s._kit(["heap_small_a", "heap_small_b"][rng.randi() % 2], pos(dd, DECK, z), along(z) * Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * .5), "Wall junk")
					stats.junk += 1
			z += rng.randf_range(1.2, 2.6)
	# Hanging laundry and wires crossing the open slits.
	for slit: Vector2 in SLITS:
		var zz := (slit.x + slit.y) * .5
		var p0 := pos(-HOUSE_D, COVER + 1.4, zz)
		var p1 := pos(HOUSE_D, COVER + 1.5, zz + .2)
		b._tube([p0, p0.lerp(p1, .5) + Vector3.DOWN * .35, p1], .005, "wire", 3)
		for j in 4:
			var t := (j + .5) / 4.0
			var p := p0.lerp(p1, t) + Vector3.DOWN * sin(t * PI) * .35
			_rag(p, p + (p1 - p0).normalized() * .35)
	# Water dripping off the roofs into the estero, in the dark.

func _room_or_yard(z: float) -> bool:
	for room: Array in ROOMS:
		if z > room[1] - .6 and z < room[2] + .6: return true
	return z > YARD.x - .6 and z < YARD.y + .6

func _props() -> void:
	var plastic := ["plastic blue", "plastic red", "plastic green", "plastic yellow", "plastic white"]
	var spots: Array = []
	# Along the walks (kept to the house side so the way stays open) and in the rooms and the yard.
	for z in [-9.0, -4.5, 3.0, 7.5, -8.0, 11.0, 14.5, 26.0, 37.0, 47.0, 50.5, 53.0]:
		var east: bool = z < 9.0 and z > -9.5 and rng.randf() < .5
		if z > 51.9: east = true
		if not east and _room_or_yard(z): continue
		spots.append([east, z])
	for i in spots.size():
		# Snug against the house wall, so the walk stays open.
		var half: float = [.17, .34, .27, .17][i % 4]
		var p := pos((HOUSE_D - half - .03) * (1.0 if spots[i][0] else -1.0), DECK + .03, spots[i][1])
		var xf := Transform3D(along(spots[i][1]), p)
		match i % 4:
			0: LooseProps.bucket(self, xf, b._materials[plastic[rng.randi() % plastic.size()]], b._materials["inside"], b._materials["wire"])
			1: LooseProps.basin(self, xf, b._materials[plastic[rng.randi() % plastic.size()]], b._materials["inside"])
			2: LooseProps.crate(self, xf, b._materials["wood grey"])
			_: LooseProps.bucket(self, xf, b._materials["plastic blue"], b._materials["inside"], b._materials["wire"])
		stats.props += 1
	# Bottles and pots everywhere someone sat and drank.
	for i in 16:
		var z := rng.randf_range(WEST_WALK.x + .5, WEST_WALK.y - .5)
		var east := z < EAST_SOUTH.y - .5 and rng.randf() < .4
		var dd := rng.randf_range(HOUSE_D - .35, HOUSE_D - .1) * (1.0 if east else -1.0)
		var tip := Basis(Vector3.RIGHT, PI * .5) if rng.randf() < .5 else Basis.IDENTITY
		LooseProps.bottle(self, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * tip, pos(dd, DECK + (.05 if tip != Basis.IDENTITY else .01), z)), b._materials["glass green"])
		stats.props += 1
	var room_z: float = ROOMS[0][1]
	LooseProps.pot(self, Transform3D(Basis(Vector3.UP, 1.0), pos(-3.3, DECK + .4, room_z + 3.3)), b._materials["can"], b._materials["iron"])
	LooseProps.pot(self, Transform3D(Basis.IDENTITY, pos(-4.8, FLOOR + .1, YARD.x + 2.5)), b._materials["can"], b._materials["iron"])
	LooseProps.basin(self, Transform3D(Basis.IDENTITY, pos(-4.2, FLOOR + .1, (YARD.x + YARD.y) * .5 + .45)), b._materials["plastic blue"], b._materials["inside"])
	LooseProps.bucket(self, Transform3D(Basis.IDENTITY, pos(-3.6, FLOOR + .1, (YARD.x + YARD.y) * .5 - .2)), b._materials["plastic red"], b._materials["inside"], b._materials["wire"])
	LooseProps.crate(self, Transform3D(Basis(Vector3.UP, .4), pos(-3.0, DECK + .02, ROOMS[1][1] + 1.0)), b._materials["wood"])
	stats.props += 5
	# Monobloc chairs: placed as models; neighborhood.gd turns every one into a physical chair at runtime.
	for spec in [[-4.6, YARD.x + 4.0, 20.0, 0.0], [-3.2, YARD.x + 4.6, 160.0, 0.0], [-2.6, room_z + 3.6, 90.0, 0.0],
			[-5.0, ROOMS[1][2] - 2.6, 200.0, 0.0], [-7.3, YARD.x + 3.5, 0.0, 88.0], [2.12, -8.3, 90.0, 0.0], [-3.0, 21.5, 0.0, 0.0]]:
		var z: float = spec[1]
		s._model("street/plastic_monobloc_chair_01", pos(spec[0], DECK + .01, z), .95,
			rad_to_deg(atan2(along(z).x.x, along(z).x.z)) + spec[2], "Warren chair", false, Vector3(spec[3], 0, 0))
		stats.props += 1

# ------------------------------------------------------------------------------------------------ light and sound

func _lights() -> void:
	for z: float in SPILLS:
		var spill := OmniLight3D.new()
		spill.name = "Moonlight through the roof"
		spill.position = pos(0, COVER - .15, z)
		spill.light_color = Color(.5, .6, .9)
		spill.light_energy = .32
		spill.omni_range = 5.2
		spill.omni_attenuation = 1.3
		spill.light_cull_mask = 2
		spill.light_specular = .2
		spill.shadow_enabled = false
		add_child(spill)
	# Damp haze hangs in the tunnels; the moon spills and the few lamps glow in it (desktop volumetric fog).
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		var fog := FogVolume.new()
		fog.name = "Warren haze"
		fog.size = Vector3(8, 3.2, Z1 - Z0)
		fog.position = Vector3(rx(21.5) + ec(21.5), FLOOR + .6, (Z0 + Z1) * .5)
		var fm := FogMaterial.new()
		fm.density = .035
		fm.albedo = Color(.5, .55, .6)
		fm.height_falloff = .8
		fm.edge_fade = .4
		fog.material = fm
		add_child(fog)
	# One failing bulb in the south tunnel.
	var hook := pos((WALK_IN + HOUSE_D) * .5, COVER - .02, -5.2)
	b._rod(hook, hook + Vector3.DOWN * .35, .006, "wire", 4)
	var holder := Node3D.new()
	holder.name = "Tunnel bulb"
	holder.position = hook + Vector3.DOWN * .4
	add_child(holder)
	_mesh_tube(holder, Vector3(0, .03, 0), .022, .05, "rust")
	_light(holder, Vector3(0, -.03, 0), Color(1, .6, .3), 4.4, .65, "bulb", false)

func _tube_light(p: Vector3, a: Basis) -> void:
	var holder := Node3D.new()
	holder.name = "Fluorescent tube"
	holder.position = p
	add_child(holder)
	_mesh_box(holder, Vector3(0, .03, 0), Vector3(.1, .03, 1.25), "iron", a)
	var tube := _mesh_tube(holder, Vector3.ZERO, .016, 1.2, "tube", a * Basis(Vector3.RIGHT, PI * .5))
	tube.material_override = (b._materials["tube"] as StandardMaterial3D).duplicate()
	var light := OmniLight3D.new()
	light.position = Vector3(0, -.12, 0)
	light.light_color = Color(.78, .92, 1.0)
	light.light_energy = .9
	light.omni_range = 6.0
	light.omni_attenuation = 1.4
	light.light_cull_mask = 2
	light.shadow_enabled = true
	holder.add_child(light)
	lights.append({"light": light, "material": tube.material_override, "energy": .9, "kind": "tube", "phase": 0.0})
	var hum := AudioStreamPlayer3D.new()
	hum.name = "Tube hum"
	hum.max_distance = 9.0
	hum.unit_size = 1.5
	hum.volume_db = -24.0
	hum.stream = _hum()
	hum.autoplay = true
	holder.add_child(hum)
	lights[-1]["hum"] = hum

func _light(parent: Node3D, offset: Vector3, color: Color, reach: float, energy: float, kind: String, shadows: bool) -> void:
	var glow := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = .02 if kind != "bulb" else .035
	sphere.height = sphere.radius * (2.6 if kind != "bulb" else 2.2)
	sphere.radial_segments = 8
	sphere.rings = 4
	glow.mesh = sphere
	glow.position = offset
	glow.layers = 2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(.8, .7, .5)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	glow.material_override = mat
	parent.add_child(glow)
	var light := OmniLight3D.new()
	light.position = offset + Vector3.UP * .03
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.8
	light.light_cull_mask = 2
	light.shadow_enabled = shadows
	parent.add_child(light)
	lights.append({"light": light, "material": mat, "energy": energy, "kind": kind, "phase": lights.size() * 2.3})

func _sounds() -> void:
	# Water dripping through the roofs, here and there in the dark.
	for z in [-7.5, 9.5, 15.0, 37.5, 49.0]:
		var drip := AudioStreamPlayer3D.new()
		drip.name = "Drip"
		drip.position = pos(rng.randf_range(-.8, .8), EW + .3, z)
		drip.max_distance = 12.0
		drip.unit_size = 1.6
		drip.volume_db = -16.0
		drip.stream = _drips(int(z * 10.0))
		drip.autoplay = true
		add_child(drip)

static func _hum() -> AudioStreamWAV:
	var rate := 22050
	var n := rate * 2
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / rate
		out[i] = (sin(t * TAU * 120.0) * .5 + sin(t * TAU * 240.0) * .25 + sin(t * TAU * 360.0) * .1) * .5
	return WarrenUsable._wav(out, rate, true)

static func _drips(seed_value: int) -> AudioStreamWAV:
	var rate := 22050
	var n := rate * 7
	var out := PackedFloat32Array()
	out.resize(n)
	var rng_ := RandomNumberGenerator.new()
	rng_.seed = seed_value
	for k in 4:
		var start := int(rng_.randf_range(.2, 6.5) * rate)
		var f := rng_.randf_range(900, 1600)
		for i in int(rate * .12):
			if start + i >= n: break
			var t := float(i) / rate
			out[start + i] += sin(t * TAU * (f + t * 4000.0)) * exp(-t * 45.0) * .8
	return WarrenUsable._wav(out, rate, true)

func usable_changed(_node: Node) -> void:
	pass

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	elapsed += delta
	for item in lights:
		var base: float = item.energy
		var energy := base
		var phase: float = item.phase
		match item.kind:
			"tube":
				if is_instance_valid(light_switch) and not light_switch.on:
					energy = 0.0
				else:
					# A dying starter: long steady stretches, then stutter, then dark for a moment.
					var cycle := fmod(elapsed, 13.0)
					if cycle > 9.5 and cycle < 11.0:
						energy = base * (1.0 if sin(elapsed * 57.0) * sin(elapsed * 13.0) > .1 else .04)
					elif cycle >= 11.0 and cycle < 11.8:
						energy = 0.0
					else:
						energy = base * (.94 + .06 * sin(elapsed * 120.0))
				if item.has("hum"):
					(item.hum as AudioStreamPlayer3D).volume_db = -24.0 if energy > .05 else -60.0
			"bulb":
				var cycle := fmod(elapsed + 4.0, 19.0)
				if cycle < 1.6: energy = base * (.05 if sin(elapsed * 41.0) > -.1 else .8)
				elif cycle < 7.0: energy = 0.0
			"candle":
				energy = base * (.8 + .12 * sin(elapsed * 9.3 + phase) + .08 * sin(elapsed * 23.1))
			"gasera":
				energy = base * (.84 + .1 * sin(elapsed * 6.1 + phase) + .06 * sin(elapsed * 17.3))
		(item.light as OmniLight3D).light_energy = energy
		(item.material as StandardMaterial3D).emission_energy_multiplier = energy * 4.0
	_crouch_hint()

func _crouch_hint() -> void:
	if _hinted: return
	var scene := get_tree().current_scene
	if scene == null or not "player" in scene: return
	var player: InteriorPlayer = scene.player
	if player == null or player.crouching: return
	var p := player.global_position
	var near := pos((WALK_IN + HOUSE_D) * .5, DECK, SAG.y + 1.0)
	var far := pos((WALK_IN + HOUSE_D) * .5, DECK, SAG.x - 1.0)
	if Vector2(p.x, p.z).distance_to(Vector2(near.x, near.z)) < 1.0 or Vector2(p.x, p.z).distance_to(Vector2(far.x, far.z)) < 1.0:
		var story := get_tree().get_first_node_in_group("story")
		if story != null and not story.ui.dialogue_active():
			story.ui.say("You", ["The roof's caved in. I'll have to crouch to get under."], 3.5)
			_hinted = true
