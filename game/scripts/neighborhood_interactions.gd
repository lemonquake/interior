extends Node3D
## Replace static gate bars with hinged rusty steel and attach usable entrances to the baked town.
const Usable := preload("res://scripts/neighborhood_usable.gd")
const Encounters := preload("res://scripts/neighborhood_encounters.gd")
var gates: Array[Node3D] = []
var doors: Array[Node3D] = []
var _bounds: Array[AABB] = []
var _leaves: Array[Array] = []
var _town: Node3D
var _rust: StandardMaterial3D
var _wood: StandardMaterial3D

func build(town: Node3D) -> void:
	_town = town
	name = "Neighborhood interactions"
	_rust = _material("rusty_metal_02", Color(.65, .60, .52), .3)
	_wood = _material("dark_wooden_planks", Color(.75, .72, .64), 0.0)
	var encounters := Encounters.new()
	encounters.name = "Quiet encounters"
	add_child(encounters)
	var colliders := town.get_node("NeighbourhoodColliders")
	var houses: Array[AABB] = []
	for shape in colliders.get_children():
		if not shape is CollisionShape3D or not shape.shape is BoxShape3D:
			continue
		var bounds := AABB(shape.position - shape.shape.size * .5, shape.shape.size)
		if str(shape.name).begins_with("House"):
			houses.append(bounds)
		if str(shape.name).begins_with("Lot gate"):
			_make_gate(bounds)
			shape.disabled = true
	# Remove the old fixed bars; all other faces and UVs remain in their shared batches.
	for child in town.get_children():
		if not child is MeshInstance3D:
			continue
		var label := str(child.name)
		if "n gate" in label or "n frame" in label:
			_extract_gates(child)
		if "n frame" in label or "n planks" in label or "n shutter" in label:
			_find_doors(child, houses, encounters)
	set_meta("counts", {"gates": gates.size(), "doors": doors.size(), "objects": doors.size()})

func _material(texture: String, tint: Color, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var directory := "res://assets/outdoor/textures/" + texture + "/"
	m.resource_name = "Neighborhood interaction / " + texture
	m.albedo_texture = load(directory + "albedo.jpg")
	m.normal_enabled = true
	m.normal_texture = load(directory + "normal.jpg")
	m.roughness_texture = load(directory + "roughness.jpg")
	m.albedo_color = tint
	m.roughness = .94
	m.metallic = metal
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * 1.8
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

func _box(parent: Node3D, label: String, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	mesh.position = at
	mesh.layers = 2
	parent.add_child(mesh)
	return mesh

func _collision(parent: Node3D, at: Vector3, size: Vector3, movable := false) -> PhysicsBody3D:
	var body: PhysicsBody3D = AnimatableBody3D.new() if movable else StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 5
	parent.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)
	return body

func _make_gate(bounds: AABB) -> void:
	var gate := InteriorPushGate.new()
	gate.name = "House gate %02d" % gates.size()
	gate.neighborhood_gate = true
	gate.position = bounds.get_center() - Vector3.UP * bounds.size.y * .5
	var along := Vector3.RIGHT if bounds.size.x > bounds.size.z else Vector3.BACK
	var width := maxf(bounds.size.x, bounds.size.z) * .5
	var leaves: Array = []
	for side in [-1.0, 1.0]:
		var leaf := _collision(gate, Vector3(0, bounds.size.y * .5, width * .5), Vector3(.12, bounds.size.y, width - .025), true) as AnimatableBody3D
		leaf.position = along * width * side
		var direction: Vector3 = along * -side
		leaf.rotation.y = atan2(direction.x, direction.z)
		leaf.set_meta("width", width)
		leaf.set_meta("open_sign", side)
		leaf.name = "Left leaf" if side < 0 else "Right leaf"
		leaves.append(leaf)
		# 0.34: the sheet, stile, hinges, handle, bars and rails straight into one mesh (scripts/box_kit.gd): a box
		# node each, merged afterwards, took a third of a second for the town's gates.
		var kit := InteriorBoxKit.new()
		kit.box(Vector3(.025, .5, width - .12), Transform3D(Basis.IDENTITY, Vector3(0, .34, width * .5)))
		kit.box(Vector3(.045, bounds.size.y, .045), Transform3D(Basis.IDENTITY, Vector3(0, bounds.size.y * .5, width - .045)))
		for height in [.23, bounds.size.y - .20]:
			kit.box(Vector3(.095, .15, .10), Transform3D(Basis.IDENTITY, Vector3(0, height, .035)))
		kit.box(Vector3(.055, .20, .055), Transform3D(Basis.IDENTITY, Vector3(.08, 1.03, width - .16)))
		for bar in range(1, int(width / .12)):
			kit.box(Vector3(.025, bounds.size.y, .025), Transform3D(Basis.IDENTITY, Vector3(0, bounds.size.y * .5, float(bar) * .12)))
		for height in [.12, bounds.size.y * .5, bounds.size.y - .05]:
			kit.box(Vector3(.05, .05, width - .04), Transform3D(Basis.IDENTITY, Vector3(0, height, width * .5)))
		var visual := MeshInstance3D.new()
		visual.name = "Weathered steel leaf"
		visual.mesh = kit.commit()
		visual.material_override = _rust
		visual.layers = 2
		leaf.add_child(visual)
		if side < 0:
			_box(leaf, "Latch bolt", Vector3(.09, .92, width - .03), Vector3(.05, .055, .28), _rust)
	add_child(gate)
	gates.append(gate)
	_bounds.append(bounds.grow(.035))
	_leaves.append(leaves)

func _extract_gates(instance: MeshInstance3D) -> void:
	var replacement := ArrayMesh.new()
	for surface in instance.mesh.get_surface_count():
		var arrays := instance.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var kept := PackedInt32Array()
		for first in range(0, indices.size(), 3):
			var center := instance.transform * ((vertices[indices[first]] + vertices[indices[first + 1]] + vertices[indices[first + 2]]) / 3.0)
			var destination: Node3D = null
			for i in _bounds.size():
				if _bounds[i].has_point(center):
					var split := center.x < _bounds[i].get_center().x if _bounds[i].size.x > _bounds[i].size.z else center.z < _bounds[i].get_center().z
					destination = _leaves[i][0 if split else 1]
					break
			for k in 3:
				if destination == null:
					kept.append(indices[first + k])
		if not kept.is_empty():
			arrays[Mesh.ARRAY_INDEX] = kept
			replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			replacement.surface_set_material(replacement.get_surface_count() - 1, instance.get_active_material(surface))
	instance.mesh = replacement if replacement.get_surface_count() > 0 else null

func _find_doors(instance: MeshInstance3D, houses: Array[AABB], controller: Node) -> void:
	if instance.mesh == null: return
	for surface in instance.mesh.get_surface_count():
		var arrays := instance.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		# Removed gate triangles no longer align in quads; door faces still share coplanar triangles.
		for first in range(0, indices.size() - 5, 3):
			var bounds := AABB(vertices[indices[first]], Vector3.ZERO)
			for k in 6: bounds = bounds.expand(vertices[indices[first + k]])
			if absf(bounds.size.y - 2.05) > .005 or absf(maxf(bounds.size.x, bounds.size.z) - .9) > .005: continue
			if minf(bounds.size.x, bounds.size.z) > .001: continue
			var point := instance.transform * bounds.get_center()
			var normal := (instance.basis * normals[indices[first]]).normalized()
			var valid := false
			for house in houses:
				if house.has_point(point - normal * .10) and not house.has_point(point): valid = true
			if not valid: continue
			var duplicate := false
			for door in doors:
				if door.position.distance_to(point) < .5: duplicate = true
			if duplicate: continue
			_make_door(point, normal, controller)

func _make_door(point: Vector3, normal: Vector3, controller: Node) -> void:
	var door := Usable.new()
	door.name = "Locked house door %02d" % doors.size()
	door.controller = controller
	door.index = doors.size()
	door.position = point + normal * .045
	door.basis = Basis(Vector3.UP.cross(normal), Vector3.UP, normal)
	var body := _collision(door, Vector3.ZERO, Vector3(.92, 2.05, .10))
	_box(body, "Weathered timber door", Vector3.ZERO, Vector3(.90, 2.05, .08), _wood)
	for y in [-.65, .65]:
		_box(body, "Rusted brace", Vector3(0, y, .048), Vector3(.84, .065, .025), _rust)
	_box(body, "Latch plate", Vector3(.32, -.03, .065), Vector3(.10, .26, .03), _rust)
	_box(body, "Locked handle", Vector3(.27, .01, .095), Vector3(.17, .04, .065), _rust)
	add_child(door)
	doors.append(door)
	var object := Usable.new()
	object.kind = "bell" if door.index % 2 == 0 else "mailbox"
	object.index = door.index
	object.controller = controller
	object.name = ("Old doorbell " if object.kind == "bell" else "Rusted mailbox ") + str(door.index)
	object.transform = door.transform
	object.position += door.basis.x * .70 + Vector3.UP * (.25 if object.kind == "bell" else -.25)
	var size := Vector3(.10, .18, .10) if object.kind == "bell" else Vector3(.38, .30, .18)
	var object_body := _collision(object, Vector3.ZERO, size)
	_box(object_body, "Rusted casing", Vector3.ZERO, size, _rust)
	_box(object_body, "Button" if object.kind == "bell" else "Mail slot", Vector3(0, .02, size.z * .5 + .008), Vector3(.035, .04, .02) if object.kind == "bell" else Vector3(.28, .025, .02), _wood)
	add_child(object)
