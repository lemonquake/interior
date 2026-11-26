class_name InteriorLooseProps
extends RefCounted
## Loose outdoor props that really collide: the monobloc chairs everywhere in the neighbourhood and the
## buckets, basins, bottles, pots and crates of the canal warren. Every one is an InteriorObject (Jolt rigid
## body): it blocks the player, tips over when shoved, can be grabbed and carried with E and makes impact sounds.
##
## The chairs were plain model instances without collision (the player walked through them). `convert_chairs`
## swaps every placed chair for a body with a compound collider fitted to the model: seat, tilted back, arm rests
## and four legs. Runtime only (neighborhood.gd calls it once the main scene exists), so bakes stay unchanged.

const CHAIR_MODEL := "plastic_monobloc_chair_01"

## Seat, back, arms and legs of the monobloc chair, in the model's own metres (origin at the bottom centre,
## front toward +Z, back toward -Z): [centre, size, tilt about X].
const CHAIR_SHAPES := [
	[Vector3(0, .43, .04), Vector3(.58, .07, .50), 0.0],
	[Vector3(0, .67, -.255), Vector3(.52, .40, .055), -.25],
	[Vector3(-.28, .62, -.03), Vector3(.05, .06, .42), 0.0],
	[Vector3(.28, .62, -.03), Vector3(.05, .06, .42), 0.0],
	[Vector3(-.27, .2, .26), Vector3(.05, .40, .05), 0.0],
	[Vector3(.27, .2, .26), Vector3(.05, .40, .05), 0.0],
	[Vector3(-.27, .2, -.23), Vector3(.05, .40, .05), 0.0],
	[Vector3(.27, .2, -.23), Vector3(.05, .40, .05), 0.0],
]

static func _shape(body: CollisionObject3D, centre: Vector3, size: Vector3, basis := Basis.IDENTITY) -> CollisionShape3D:
	var c := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	box.margin = InteriorPropPhysics.SHAPE_MARGIN
	c.shape = box
	c.transform = Transform3D(basis, centre)
	body.add_child(c)
	return c

static func _cylinder(body: CollisionObject3D, centre: Vector3, radius: float, height: float) -> CollisionShape3D:
	var c := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	shape.margin = InteriorPropPhysics.SHAPE_MARGIN
	c.shape = shape
	c.position = centre
	body.add_child(c)
	return c

static func _body(parent: Node, label: String, material: String, mass: float, xf: Transform3D) -> InteriorObject:
	var body := InteriorObject.new()
	body.name = label.validate_node_name()
	body.display_name = label
	body.physics_material = material
	body.mass = mass
	body.outdoor = true
	parent.add_child(body, true)
	body.global_transform = Transform3D(xf.basis.orthonormalized(), xf.origin)
	body.home_transform = body.global_transform
	return body

## Every monobloc chair instance below `root` becomes a physical chair. Returns how many were converted.
static func convert_chairs(root: Node) -> int:
	var chairs: Array[Node3D] = []
	for node in root.find_children("*", "Node3D", true, false):
		if CHAIR_MODEL in node.scene_file_path and not node.get_parent() is InteriorObject:
			chairs.append(node as Node3D)
	for chair in chairs:
		chair_body(chair)
	return chairs.size()

## Wraps one placed chair model in a rigid body at the same pose (scale stays on the visual).
static func chair_body(visual: Node3D) -> InteriorObject:
	var parent := visual.get_parent()
	var xf := visual.global_transform
	var s := xf.basis.get_scale().x
	var body := _body(parent, "Plastic chair", "plastic", 2.6, xf)
	visual.get_parent().remove_child(visual)
	body.add_child(visual)
	visual.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), Vector3.ZERO)
	for spec: Array in CHAIR_SHAPES:
		_shape(body, (spec[0] as Vector3) * s, (spec[1] as Vector3) * s, Basis(Vector3.RIGHT, spec[2]))
	body.set_meta("loose_prop", "chair")
	return body

# ---------------------------------------------------------------- warren props built from primitives

static func _mesh(body: Node3D, mesh: Mesh, material: Material, at := Vector3.ZERO, basis := Basis.IDENTITY) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.transform = Transform3D(basis, at)
	mi.layers = 2
	mi.visibility_range_end = 45.0
	body.add_child(mi)
	return mi

static func _tube(radius_top: float, radius_bottom: float, height: float, segments := 14) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius_top
	m.bottom_radius = radius_bottom
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	return m

## A plastic pail (timba) with a darker inside and a wire handle.
static func bucket(parent: Node, xf: Transform3D, plastic: Material, inside: Material, wire: Material) -> InteriorObject:
	var body := _body(parent, "Plastic pail", "plastic", .9, xf)
	_mesh(body, _tube(.15, .12, .3), plastic, Vector3(0, .15, 0))
	_mesh(body, _tube(.135, .135, .01), inside, Vector3(0, .296, 0))
	var ring := TorusMesh.new()
	ring.inner_radius = .145
	ring.outer_radius = .16
	ring.rings = 16
	ring.ring_segments = 4
	_mesh(body, ring, plastic, Vector3(0, .3, 0))
	var arc := TorusMesh.new()
	arc.inner_radius = .145
	arc.outer_radius = .152
	arc.rings = 14
	arc.ring_segments = 3
	_mesh(body, arc, wire, Vector3(0, .3, 0), Basis(Vector3.RIGHT, PI * .5).scaled(Vector3(1, 1, .9)))
	_cylinder(body, Vector3(0, .15, 0), .14, .3)
	body.set_meta("loose_prop", "bucket")
	return body

## A wide, shallow laundry basin (batya).
static func basin(parent: Node, xf: Transform3D, plastic: Material, inside: Material) -> InteriorObject:
	var body := _body(parent, "Plastic basin", "plastic", 1.2, xf)
	_mesh(body, _tube(.32, .25, .17, 18), plastic, Vector3(0, .085, 0))
	_mesh(body, _tube(.3, .3, .01, 18), inside, Vector3(0, .168, 0))
	_cylinder(body, Vector3(0, .085, 0), .29, .17)
	body.set_meta("loose_prop", "basin")
	return body

## An empty gin / soy-sauce bottle.
static func bottle(parent: Node, xf: Transform3D, glass: Material) -> InteriorObject:
	var body := _body(parent, "Empty bottle", "glass", .35, xf)
	_mesh(body, _tube(.035, .035, .2, 10), glass, Vector3(0, .1, 0))
	_mesh(body, _tube(.012, .03, .07, 8), glass, Vector3(0, .235, 0))
	_cylinder(body, Vector3(0, .13, 0), .035, .26)
	body.set_meta("loose_prop", "bottle")
	return body

## A dented aluminium cooking pot (kaldero) with its lid.
static func pot(parent: Node, xf: Transform3D, metal: Material, inside: Material) -> InteriorObject:
	var body := _body(parent, "Dented pot", "metal", 1.1, xf)
	_mesh(body, _tube(.16, .15, .17, 16), metal, Vector3(0, .085, 0))
	_mesh(body, _tube(.15, .165, .025, 16), inside, Vector3(0, .18, 0))
	_mesh(body, _tube(.025, .025, .03, 8), inside, Vector3(0, .205, 0))
	for side in [-1.0, 1.0]:
		_mesh(body, _tube(.012, .012, .07, 6), metal, Vector3(side * .19, .14, 0), Basis(Vector3.FORWARD, PI * .5))
	_cylinder(body, Vector3(0, .1, 0), .16, .2)
	body.set_meta("loose_prop", "pot")
	return body

## A slatted fruit crate (kaing).
static func crate(parent: Node, xf: Transform3D, wood: Material) -> InteriorObject:
	var body := _body(parent, "Wooden crate", "wood", 3.0, xf)
	var size := Vector3(.5, .32, .38)
	for y in [.04, .16, .28]:
		for z in [-1.0, 1.0]:
			var slat := BoxMesh.new()
			slat.size = Vector3(size.x, .07, .015)
			_mesh(body, slat, wood, Vector3(0, y, z * (size.z * .5 - .008)))
		for x in [-1.0, 1.0]:
			var slat := BoxMesh.new()
			slat.size = Vector3(.015, .07, size.z)
			_mesh(body, slat, wood, Vector3(x * (size.x * .5 - .008), y, 0))
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(size.x, .015, size.z)
	_mesh(body, floor_mesh, wood, Vector3(0, .008, 0))
	_shape(body, Vector3(0, size.y * .5, 0), size)
	body.set_meta("loose_prop", "crate")
	return body
