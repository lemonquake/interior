class_name HamsterEnclosure
extends Node3D

const HamsterScript = preload("res://scripts/hamster.gd")
const FLOORS: Array[float] = [0.65, 1.05, 1.45]
const HALF_WIDTH := 0.385
const HALF_DEPTH := 0.235
const CLEARANCE := 0.045
const GRAPH: Array[Vector2] = [Vector2(-0.28, -0.02), Vector2(0, -0.02), Vector2(0.27, -0.02), Vector2(-0.28, -0.17), Vector2(0, -0.17), Vector2(0.27, -0.17)]
const EDGES: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(0, 3), Vector2i(3, 4), Vector2i(4, 5), Vector2i(2, 5)]
var residents: Array[InteriorHamster] = []
var wheels: Array[Node3D] = []
var body: RigidBody3D
var _materials: Dictionary = {}
var _built := false
var connector_paths: Array = []
var traveller := -1
var activity_owners: Dictionary = {}
const PET_CLEARANCE := 0.12
const PORT_Z := -0.02
const TUBE_RADIUS := 0.052


# Call after the imported body and its original colliders have been assembled.
# This body keeps its room transform, physical identity, mass, grab/push behavior.
static func attach_to(enclosure_body: RigidBody3D) -> HamsterEnclosure:
	var existing := enclosure_body.get_node_or_null("HamsterPlayground") as HamsterEnclosure
	if existing != null:
		return existing
	for child in enclosure_body.get_children():
		if child is MeshInstance3D or child is CollisionShape3D or child is Node3D:
			enclosure_body.remove_child(child)
			child.queue_free()
	var habitat := HamsterEnclosure.new()
	habitat.name = "HamsterPlayground"
	habitat.body = enclosure_body
	# The room is approached from +Z. Face the wheel openings, hide doorway and
	# sliding acrylic doors toward that aisle while retaining local navigation.
	habitat.rotation.y = PI
	enclosure_body.add_child(habitat)
	habitat.build()
	return habitat

func build() -> void:
	if _built:
		return
	_built = true
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_make_materials()
	# A full stand with casters; trays stay separate physical support surfaces.
	for x in [-0.385, 0.385]:
		for z in [-0.235, 0.235]:
			_box(self, Vector3(x, 0.93, z), Vector3(0.028, 1.80, 0.028), "metal", true)
			_cylinder(self, Vector3(x, 0.055, z), 0.031, 0.031, 0.030, "rubber", Vector3(PI / 2, 0, 0))
			_box(self, Vector3(x, 0.027, z), Vector3(0.036, 0.055, 0.049), "metal", true, false)
	_box(self, Vector3(0, 0.12, 0), Vector3(0.80, 0.026, 0.50), "wood", true)
	# Lower shelf holds the aquariums. The thin top is the last enclosure lid.
	_box(self, Vector3(0, 1.845, 0), Vector3(0.80, 0.022, 0.50), "wood", true)
	for y in [0.12, 0.60, 1.00, 1.40, 1.845]:
		for z in [-0.248, 0.248]:
			_box(self, Vector3(0, y, z), Vector3(0.80, 0.021, 0.019), "metal", true)
		for x in [-0.397, 0.397]:
			_box(self, Vector3(x, y, 0), Vector3(0.019, 0.021, 0.50), "metal", true)
	for level in 3:
		_build_compartment(level)
	_build_connectors()
	for index in 3:
		var pet := HamsterScript.new() as InteriorHamster
		pet.name = ["Biscuit", "Nibbles", "Pebble"][index]
		pet.configure(self, index, index, 71391 + index * 101)
		add_child(pet)
		residents.append(pet)
	add_to_group("hamster_habitats")

func _build_compartment(level: int) -> void:
	var floor_y := FLOORS[level]
	# Deep litter pan, acrylic viewing panels, lid, sliding door and two latches.
	_box(self, Vector3(0, floor_y - 0.035, 0), Vector3(0.77, 0.048, 0.47), "tray", true)
	_box(self, Vector3(0, floor_y - 0.008, 0), Vector3(0.746, 0.011, 0.44), "bedding")
	for x in [-0.376, 0.376]:
		var has_port: bool = (x > 0 and level < 2) or (x < 0 and level > 0)
		if has_port:
			# Four separate panes leave a real 108 mm aperture: no invisible pane
			# or collider crosses the tube entrance.
			_box(self, Vector3(x, floor_y + 0.223, 0), Vector3(0.012, 0.250, 0.47), "glass", true)
			_box(self, Vector3(x, floor_y + 0.044, -0.158), Vector3(0.012, 0.108, 0.154), "glass", true)
			_box(self, Vector3(x, floor_y + 0.044, 0.135), Vector3(0.012, 0.108, 0.200), "glass", true)
			_ring(self, Vector3(x, floor_y + 0.046, PORT_Z), 0.059, TUBE_RADIUS, 0.026, "blue", Vector3(0, 0, PI / 2))
		else:
			_box(self, Vector3(x, floor_y + 0.172, 0), Vector3(0.012, 0.356, 0.47), "glass", true)
	for z in [-0.23, 0.23]:
		_box(self, Vector3(0, floor_y + 0.172, z), Vector3(0.746, 0.356, 0.008), "glass", true)
	_box(self, Vector3(0, floor_y + 0.346, 0), Vector3(0.76, 0.009, 0.46), "glass", true)
	for x in [-0.33, 0.33]:
		_box(self, Vector3(x, floor_y + 0.27, -0.239), Vector3(0.016, 0.025, 0.014), "metal")
		_cylinder(self, Vector3(x, floor_y + 0.27, -0.249), 0.004, 0.004, 0.006, "brass", Vector3(PI / 2, 0, 0))
	for x in [-0.22, 0.22]:
		_box(self, Vector3(x, floor_y + 0.155, -0.238), Vector3(0.042, 0.009, 0.012), "metal")
	_build_wheel(level)
	_build_hide(level)
	# External clear tubes replace the old log that obscured residents.
	_build_bridge(level)
	# A shallow sand bath and a glazed food dish, both visibly hollow.
	_ring(self, Vector3(0.23, floor_y + 0.014, -0.145), 0.056, 0.046, 0.027, "clay")
	_cylinder(self, Vector3(0.23, floor_y + 0.009, -0.145), 0.046, 0.046, 0.006, "sand")
	_ring(self, Vector3(0.055, floor_y + 0.014, 0.148), 0.032, 0.025, 0.026, "ceramic")
	_cylinder(self, Vector3(0.055, floor_y + 0.004, 0.148), 0.025, 0.025, 0.005, "ceramic")
	for grain in 14:
		var angle := float(grain) * 2.39996
		var r := sqrt(float(grain) / 14.0) * 0.020
		_sphere(self, Vector3(0.055 + cos(angle) * r, floor_y + 0.012, 0.148 + sin(angle) * r), Vector3(0.009, 0.005, 0.004), "food")
	# Clear drinking bottles with alternating pink and blue caps at the front.
	var cap: String = "pink" if level % 2 == 0 else "blue"
	_box(self, Vector3(0.11, floor_y + 0.19, -0.247), Vector3(0.045, 0.012, 0.03), cap)
	_cylinder(self, Vector3(0.11, floor_y + 0.18, -0.249), 0.026, 0.026, 0.15, "bottle")
	_cylinder(self, Vector3(0.11, floor_y + 0.16, -0.249), 0.023, 0.023, 0.09, "water")
	_cylinder(self, Vector3(0.11, floor_y + 0.260, -0.249), 0.028, 0.028, 0.017, cap)
	_cylinder(self, Vector3(0.11, floor_y + 0.102, -0.249), 0.028, 0.028, 0.019, cap)
	_cylinder(self, Vector3(0.11, floor_y + 0.068, -0.221), 0.003, 0.003, 0.075, "steel", Vector3(0.65, 0, 0))
	# Scatter shallow bedding chips as one draw-call per level.
	var chips := MultiMeshInstance3D.new()
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	var chip_mesh := BoxMesh.new()
	chip_mesh.size = Vector3(0.010, 0.0020, 0.005)
	chip_mesh.material = _materials.bedding
	instances.mesh = chip_mesh
	instances.instance_count = 420
	var rng := RandomNumberGenerator.new()
	rng.seed = 72712 + level
	for i in instances.instance_count:
		var at := Vector3(rng.randf_range(-0.35, 0.35), floor_y - 0.001, rng.randf_range(-0.20, 0.20))
		instances.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rng.randf_range(-PI, PI)), at))
		instances.set_instance_color(i, Color(1, rng.randf_range(0.80, 1.0), rng.randf_range(0.65, 0.90)))
	chips.multimesh = instances
	add_child(chips)

func _build_wheel(level: int) -> void:
	var y := FLOORS[level]
	_box(self, Vector3(-0.21, y + 0.008, 0.15), Vector3(0.16, 0.016, 0.12), "blue")
	for x in [-0.255, -0.165]:
		_cylinder(self, Vector3(x, y + 0.082, 0.178), 0.005, 0.005, 0.17, "steel", Vector3(0, 0, -0.20 if x < -0.21 else 0.20))
	var wheel := Node3D.new()
	wheel.name = "ExerciseWheel%d" % level
	add_child(wheel)
	wheel.position = Vector3(-0.21, y + 0.118, 0.135)
	# The wheel rotates around its Z axle; the hamster runs on its solid bottom.
	_ring(wheel, Vector3.ZERO, 0.112, 0.104, 0.079, "blue", Vector3(PI / 2, 0, 0))
	_cylinder(wheel, Vector3(0, 0, 0.039), 0.112, 0.112, 0.006, "blue", Vector3(PI / 2, 0, 0))
	_cylinder(wheel, Vector3(0, 0, -0.001), 0.012, 0.012, 0.087, "steel", Vector3(PI / 2, 0, 0))
	for spoke in 12:
		var theta := float(spoke) / 12.0 * TAU
		_box(wheel, Vector3(sin(theta) * 0.057, cos(theta) * 0.057, 0.034), Vector3(0.006, 0.10, 0.005), "blue", false, true, Vector3(0, 0, -theta))
	for tread in 24:
		var theta := float(tread) / 24.0 * TAU
		_box(wheel, Vector3(sin(theta) * 0.103, cos(theta) * 0.103, 0), Vector3(0.004, 0.004, 0.071), "blue", false, true, Vector3(0, 0, -theta))
	wheels.append(wheel)

func _build_hide(level: int) -> void:
	var y := FLOORS[level]
	# An open doorway, four side boards and a pitched roof, never a solid cube.
	_box(self, Vector3(0.225, y + 0.059, 0.18), Vector3(0.135, 0.112, 0.009), "wood")
	for x in [0.161, 0.289]:
		_box(self, Vector3(x, y + 0.059, 0.127), Vector3(0.010, 0.112, 0.112), "wood")
	for x in [0.172, 0.278]:
		_box(self, Vector3(x, y + 0.039, 0.073), Vector3(0.030, 0.07, 0.009), "wood")
	_box(self, Vector3(0.225, y + 0.093, 0.073), Vector3(0.083, 0.032, 0.009), "wood")
	for x in [-1.0, 1.0]:
		_box(self, Vector3(0.225 + x * 0.034, y + 0.123, 0.127), Vector3(0.085, 0.009, 0.145), "wood", false, true, Vector3(0, 0, x * 0.25))

func _build_tunnel(level: int) -> void:
	var y := FLOORS[level]
	# Hollow cork log, open at both ends with visible rings and bark ribs.
	_ring(self, Vector3(-0.135, y + 0.039, -0.148), 0.042, 0.034, 0.21, "cork", Vector3(0, 0, PI / 2))
	for i in 10:
		_ring(self, Vector3(-0.231 + float(i) * 0.021, y + 0.039, -0.148), 0.043, 0.040, 0.004, "wood", Vector3(0, 0, PI / 2))

func _build_bridge(level: int) -> void:
	var y := FLOORS[level]
	for plank in 10:
		var z := -0.13 + float(plank) * 0.013
		var height := sin(float(plank) / 9.0 * PI) * 0.028
		_cylinder(self, Vector3(0, y + height + 0.004, z), 0.007, 0.007, 0.105, "wood", Vector3(0, 0, PI / 2))
	for x in [-0.043, 0.043]:
		for plank in 9:
			var z := -0.123 + float(plank) * 0.013
			var height := sin((float(plank) + 0.5) / 9.0 * PI) * 0.028
			_sphere(self, Vector3(x, y + height + 0.005, z), Vector3(0.007, 0.006, 0.020), "rope")

func path_node(level: int, index: int) -> Vector3:
	var point := GRAPH[index]
	return Vector3(point.x, FLOORS[level], point.y)

func route_to(level: int, from_node: int, activity: String) -> Dictionary:
	var destination_node := {"wheel":0, "hide":2, "sand":5, "food":1, "water":4, "tunnel":3, "bridge":4, "idle":4}[activity] as int
	var route: Array[Vector3] = _graph_route(level, from_node, destination_node)
	for point in _activity_points(level, activity):
		route.append(point)
	if activity == "tunnel":
		destination_node = 4
	elif activity == "bridge":
		destination_node = 1
	return {"points":route, "node":destination_node}

func _activity_points(level: int, activity: String) -> Array[Vector3]:
	var y := FLOORS[level]
	match activity:
		"wheel": return [Vector3(-0.21, y, -0.02), Vector3(-0.21, y + 0.012, 0.12)]
		"hide": return [Vector3(0.225, y, -0.02), Vector3(0.225, y, 0.118)]
		"sand": return [Vector3(0.23, y + 0.013, -0.145)]
		"food": return [Vector3(0.055, y, -0.02), Vector3(0.055, y, 0.097)]
		"water": return [Vector3(0.11, y, -0.17)]
		"tunnel": return [Vector3(-0.28, y, -0.148), Vector3(0, y, -0.17)]
		"bridge": return [Vector3(0, y, -0.15), Vector3(0, y + 0.019, -0.10), Vector3(0, y + 0.032, -0.065), Vector3(0, y + 0.018, -0.03), path_node(level, 1)]
	return []

func retreat_from(level: int, activity: String) -> Array[Vector3]:
	if activity in ["tunnel", "bridge", "idle"]:
		return []
	var points := _activity_points(level, activity)
	points.reverse()
	return points

func spin_wheel(level: int, amount: float) -> void:
	wheels[level].rotate_z(-amount)

func reset_residents() -> void:
	traveller = -1
	activity_owners.clear()
	for wheel in wheels:
		wheel.rotation = Vector3.ZERO
	for pet in residents:
		pet.reset_resident()

func contains_resident(pet: InteriorHamster) -> bool:
	var p := pet.position
	for floor_y in FLOORS:
		if absf(p.x) < HALF_WIDTH - 0.025 and absf(p.z) < HALF_DEPTH - 0.023 and p.y >= floor_y - 0.004 and p.y <= floor_y + 0.038:
			return true
	# Tube traversal follows its center minus the feet/body offset. Check the
	# entire centerline, including the curved elbows outside the acrylic walls.
	for path in connector_paths:
		for i in range(path.size() - 1):
			var a: Vector3 = path[i] - Vector3(0, 0.028, 0)
			var b: Vector3 = path[i + 1] - Vector3(0, 0.028, 0)
			var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
			if p.distance_to(a.lerp(b, t)) < 0.018:
				return true
	return false

func _build_connectors() -> void:
	for pair in 2:
		var side := 1.0 if pair == 0 else -1.0
		var bottom := FLOORS[pair] + 0.046
		var top := FLOORS[pair + 1] + 0.046
		var path: Array[Vector3] = [Vector3(side * 0.34, bottom, PORT_Z), Vector3(side * 0.405, bottom, PORT_Z)]
		for i in range(1, 9):
			var a := float(i) / 8.0 * PI / 2.0
			path.append(Vector3(side * (0.405 + sin(a) * 0.095), bottom + 0.095 * (1.0 - cos(a)), PORT_Z))
		path.append(Vector3(side * 0.50, top - 0.095, PORT_Z))
		for i in range(1, 9):
			var a := float(i) / 8.0 * PI / 2.0
			path.append(Vector3(side * (0.405 + cos(a) * 0.095), top - 0.095 + sin(a) * 0.095, PORT_Z))
		path.append(Vector3(side * 0.34, top, PORT_Z))
		connector_paths.append(path)
		_tube_surface(path)
		_tube_colliders(path)
		# Corrugated transparent ribs make the external U-shaped connector legible.
		for i in range(path.size() - 1):
			var a: Vector3 = path[i]
			var b: Vector3 = path[i + 1]
			var count := maxi(1, int(a.distance_to(b) / 0.021))
			for j in count:
				var rib := Node3D.new()
				add_child(rib)
				rib.position = a.lerp(b, float(j) / count)
				rib.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
				_ring(rib, Vector3.ZERO, TUBE_RADIUS + 0.003, TUBE_RADIUS, 0.003, "ridge")
		for point in [path[1], path[9], path[10], path[path.size() - 2]]:
			var collar := Node3D.new()
			add_child(collar)
			collar.position = point
			collar.rotation.z = PI / 2 if absf(point.x) < 0.45 else 0.0
			_ring(collar, Vector3.ZERO, TUBE_RADIUS + 0.006, TUBE_RADIUS + 0.001, 0.012, "blue")

func _tube_colliders(path: Array[Vector3]) -> void:
	# Six thin convex strips surround each tube span. They collide with loose
	# room objects while leaving the interior and both end openings hollow.
	for i in range(0, path.size() - 1, 2):
		var a := path[i]
		var b := path[mini(i + 2, path.size() - 1)]
		var axis := (b - a).normalized()
		var align := Quaternion(Vector3.UP, axis)
		for face in 6:
			var angle := float(face) * TAU / 6.0
			var radial := align * Vector3(cos(angle), 0, sin(angle))
			var collider := CollisionShape3D.new()
			collider.name = "HollowTubeCollider"
			var shape := BoxShape3D.new()
			shape.size = Vector3(0.052, a.distance_to(b) + 0.005, 0.005)
			shape.margin = 0.001
			collider.shape = shape
			body.add_child(collider)
			collider.transform = transform * Transform3D(Basis(axis.cross(radial).normalized(), axis, radial), (a + b) * 0.5 + radial * 0.048)

func _tube_surface(path: Array[Vector3]) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(path.size() - 1):
		var tangent_a := (path[min(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		var tangent_b := (path[min(i + 2, path.size() - 1)] - path[i]).normalized()
		var normal_a := tangent_a.cross(Vector3.FORWARD).normalized()
		var normal_b := tangent_b.cross(Vector3.FORWARD).normalized()
		for ring in 24:
			var a := float(ring) / 24.0 * TAU
			var b := float(ring + 1) / 24.0 * TAU
			var vertices := [path[i] + (normal_a * cos(a) + Vector3.FORWARD * sin(a)) * TUBE_RADIUS, path[i] + (normal_a * cos(b) + Vector3.FORWARD * sin(b)) * TUBE_RADIUS, path[i + 1] + (normal_b * cos(b) + Vector3.FORWARD * sin(b)) * TUBE_RADIUS, path[i + 1] + (normal_b * cos(a) + Vector3.FORWARD * sin(a)) * TUBE_RADIUS]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_uv(Vector2(float(ring) / 24.0, float(i) / path.size()))
				st.add_vertex(vertices[idx])
	st.generate_normals()
	_mesh(self, Vector3.ZERO, st.commit(), "tube")

func request_transfer(pet: InteriorHamster, target_level: int, from_node: int) -> Dictionary:
	if traveller != -1 and traveller != pet.resident_id:
		return {}
	traveller = pet.resident_id
	var points: Array[Vector3] = []
	var current := pet.compartment
	var node := from_node
	while current != target_level:
		var next_level := current + (1 if target_level > current else -1)
		var pair := mini(current, next_level)
		var entry := 2 if pair == 0 else 0
		var graph_route := _graph_route(current, node, entry)
		points.append_array(graph_route)
		var tube: Array = connector_paths[pair].duplicate()
		if next_level < current:
			tube.reverse()
		for point: Vector3 in tube:
			points.append(point - Vector3(0, 0.028, 0))
		points.append(path_node(next_level, entry))
		current = next_level
		node = entry
	return {"points":points, "node":node, "level":target_level}

func _graph_route(level: int, from_node: int, destination: int) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var order: Array[int] = [0, 1, 2, 5, 4, 3]
	var index := order.find(from_node)
	points.append(path_node(level, from_node))
	while order[index] != destination:
		index = (index + 1) % order.size()
		points.append(path_node(level, order[index]))
	return points

func can_advance(pet: InteriorHamster, next_position: Vector3) -> bool:
	for other in residents:
		if other == pet:
			continue
		if other.position.distance_to(next_position) < PET_CLEARANCE:
			return false
	return true

func avoid_resident(pet: InteriorHamster, _target: Vector3) -> Dictionary:
	# Replan on a small real floor grid. Occupied cells include the other pets'
	# body clearance, so opposing traffic walks around rather than overlapping.
	if absf(pet.position.x) > 0.34:
		return {}
	var floor_y := pet.position.y
	for value in FLOORS:
		if absf(value - floor_y) < 0.04:
			floor_y = value
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(-16, -9, 33, 19)
	grid.cell_size = Vector2(0.02, 0.02)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for x in range(-16, 17):
		for z in range(-9, 10):
			var point := Vector3(x * 0.02, floor_y, z * 0.02)
			var solid := not _floor_walkable(point)
			for other in residents:
				if other != pet and point.distance_to(other.position) < PET_CLEARANCE + 0.002:
					solid = true
			grid.set_point_solid(Vector2i(x, z), solid)
	var start := Vector2i(roundi(pet.position.x / 0.02), roundi(pet.position.z / 0.02))
	if not grid.is_in_boundsv(start):
		return {}
	grid.set_point_solid(start, false)
	for index in range(pet._route_index, mini(pet._route_index + 32, pet._route.size())):
		var goal: Vector3 = pet._route[index]
		if absf(goal.y - floor_y) > 0.04:
			break
		var end := Vector2i(roundi(goal.x / 0.02), roundi(goal.z / 0.02))
		if not grid.is_in_boundsv(end) or grid.is_point_solid(end):
			continue
		var path := grid.get_point_path(start, end)
		if path.size() < 2:
			continue
		var points: Array[Vector3] = []
		for i in range(1, path.size()):
			points.append(Vector3(path[i].x, floor_y, path[i].y))
		points.append(goal)
		return {"points":points, "skip":index}
	# If another pet occupies the final activity point, the higher ID yields
	# into a nearby free patch for a moment so the first pet can finish passing.
	var must_yield := false
	for other in residents:
		if other != pet and other.position.distance_to(pet.position) < 0.16:
			must_yield = other._in_transfer or pet.resident_id > other.resident_id
			if must_yield:
				break
	if must_yield:
		for offset in [Vector2i(0, 5), Vector2i(0, -5), Vector2i(5, 0), Vector2i(-5, 0)]:
			var end: Vector2i = start + offset
			if not grid.is_in_boundsv(end) or grid.is_point_solid(end):
				continue
			var path := grid.get_point_path(start, end)
			if path.size() < 2:
				continue
			var points: Array[Vector3] = []
			for i in range(1, path.size()):
				points.append(Vector3(path[i].x, floor_y, path[i].y))
			return {"points":points, "skip":pet._route_index - 1, "yield":true}
	return {}

func _floor_walkable(point: Vector3) -> bool:
	if absf(point.x) > 0.325 or point.z < -0.185 or point.z > 0.18:
		return false
	if point.z > 0.047:
		# The open wheel and hide entries remain usable; their walls do not.
		if point.x < -0.095 and absf(point.x + 0.21) > 0.027:
			return false
		if point.x > 0.12 and absf(point.x - 0.225) > 0.021:
			return false
	return true

func release_activity(pet: InteriorHamster) -> void:
	for key in activity_owners.keys():
		if activity_owners[key] == pet.resident_id:
			activity_owners.erase(key)

func claim_activity(pet: InteriorHamster, activity: String) -> bool:
	var key := str(pet.compartment) + ":" + activity
	if activity_owners.has(key) and activity_owners[key] != pet.resident_id:
		return false
	activity_owners[key] = pet.resident_id
	return true

func _make_materials() -> void:
	var palette := {"metal":Color(0.07,0.075,0.08), "steel":Color(0.55,0.57,0.59), "brass":Color(0.52,0.36,0.16), "rubber":Color(0.035,0.036,0.039), "wood":Color(0.57,0.38,0.20), "cork":Color(0.34,0.23,0.12), "rope":Color(0.58,0.45,0.28), "tray":Color(0.22,0.29,0.25), "bedding":Color(0.72,0.59,0.40), "sand":Color(0.75,0.67,0.51), "clay":Color(0.45,0.28,0.19), "ceramic":Color(0.48,0.63,0.60), "food":Color(0.48,0.30,0.12), "blue":Color(0.22,0.30,0.59), "pink":Color(0.83,0.36,0.49), "tube":Color(0.85,0.91,0.93,0.13), "ridge":Color(0.86,0.94,1.0,0.31), "glass":Color(0.80,0.89,0.93,0.035), "bottle":Color(0.81,0.94,1,0.15), "water":Color(0.24,0.64,0.78,0.15)}
	for key in palette:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = palette[key]
		mat.roughness = 0.80
		if key in ["metal", "steel", "brass"]:
			mat.metallic = 0.75
			mat.roughness = 0.38
		elif key in ["glass", "bottle", "water", "tube", "ridge"]:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.roughness = 0.22
			mat.disable_receive_shadows = true
		elif key in ["wood", "bedding", "sand", "cork"]:
			var noise := FastNoiseLite.new()
			noise.seed = 11991
			noise.frequency = 0.10 if key == "wood" else 0.25
			var texture := NoiseTexture2D.new()
			texture.width = 128
			texture.height = 128
			texture.noise = noise
			texture.as_normal_map = true
			texture.bump_strength = 0.45
			mat.normal_enabled = true
			mat.normal_texture = texture
			mat.normal_scale = 0.22
			mat.uv1_scale = Vector3(3, 14 if key == "wood" else 3, 1)
			if key == "wood" and ResourceLoader.exists("res://assets/surfaces/oak_color.jpg"):
				mat.albedo_color = Color(0.93, 0.84, 0.71)
				mat.albedo_texture = load("res://assets/surfaces/oak_color.jpg")
				mat.normal_texture = load("res://assets/surfaces/oak_normal.png")
				mat.roughness_texture = load("res://assets/surfaces/oak_roughness.jpg")
				mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
				mat.roughness = 1.0
				mat.uv1_triplanar = true
				mat.uv1_scale = Vector3(3, 3, 3)
		_materials[key] = mat

func _mesh(parent: Node3D, at: Vector3, mesh: Mesh, material: String, rotation_value := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _materials[material]
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if material in ["glass", "bottle", "water", "tube", "ridge"] else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	instance.position = at
	instance.rotation = rotation_value
	return instance

func _box(parent: Node3D, at: Vector3, size: Vector3, material: String, collision := false, visible_mesh := true, rotation_value := Vector3.ZERO) -> void:
	if visible_mesh:
		var box := BoxMesh.new()
		box.size = size
		_mesh(parent, at, box, material, rotation_value)
	if collision and body != null:
		var shape := CollisionShape3D.new()
		shape.name = "HabitatCollider"
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		box_shape.margin = 0.001
		shape.shape = box_shape
		body.add_child(shape)
		shape.position = transform * at
		shape.rotation = rotation + rotation_value

func _cylinder(parent: Node3D, at: Vector3, top: float, bottom: float, height: float, material: String, rotation_value := Vector3.ZERO) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = top
	cylinder.bottom_radius = bottom
	cylinder.height = height
	cylinder.radial_segments = 20
	cylinder.rings = 1
	_mesh(parent, at, cylinder, material, rotation_value)

func _sphere(parent: Node3D, at: Vector3, dimensions: Vector3, material: String) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1
	sphere.radial_segments = 12
	sphere.rings = 6
	var instance := _mesh(parent, at, sphere, material)
	instance.scale = dimensions

func _ring(parent: Node3D, at: Vector3, outer: float, inner: float, height: float, material: String, rotation_value := Vector3.ZERO) -> void:
	# An annular prism with real open interior, including inner walls and end rims.
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in 32:
		var a := float(segment) / 32.0 * TAU
		var b := float(segment + 1) / 32.0 * TAU
		for radii in [[outer, outer], [inner, inner], [inner, outer], [outer, inner]]:
			var rim := float(radii[0]) != float(radii[1])
			var sign_value := -1.0 if radii == [outer, inner] else 1.0
			var y0 := sign_value * height * 0.5 if rim else -height * 0.5
			var y1 := y0 if rim else height * 0.5
			var points := [Vector3(sin(a) * radii[0], y0, cos(a) * radii[0]), Vector3(sin(b) * radii[0], y0, cos(b) * radii[0]), Vector3(sin(b) * radii[1], y1, cos(b) * radii[1]), Vector3(sin(a) * radii[1], y1, cos(a) * radii[1])]
			# Godot's visible face uses clockwise winding. For this
			# sin/cos ordering only the outer cylindrical wall needs reversal;
			# both rim faces already face the expected side.
			var reverse_winding: bool = radii == [outer, outer]
			var order := [0, 2, 1, 0, 3, 2] if reverse_winding else [0, 1, 2, 0, 2, 3]
			for vertex_index in order:
				builder.set_uv(Vector2(float(segment) / 32.0, float(vertex_index) / 3.0))
				builder.add_vertex(points[vertex_index])
	builder.generate_normals()
	_mesh(parent, at, builder.commit(), material, rotation_value)
