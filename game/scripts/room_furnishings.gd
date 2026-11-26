extends RefCounted
## Shared by the room builder and the targeted saved-scene update.
const LockedDoor = preload("res://scripts/locked_room_door.gd")

static func apply(room: Node3D) -> void:
	for path in ["InteriorLighting/Light_accent_lamp", "ReferenceRoomSurroundings/Room detail - leaf curtain"]:
		var old := room.get_node_or_null(path)
		if old != null:
			if old is MeshInstance3D and room.has_meta("reference_room_stats"):
				var stats: Dictionary = room.get_meta("reference_room_stats")
				for s in old.mesh.get_surface_count():
					var indices: int = old.mesh.surface_get_array_index_len(s)
					stats.triangles_added -= (indices if indices > 0 else old.mesh.surface_get_array_len(s))/3
				stats.static_batches -= 1
				room.set_meta("reference_room_stats",stats)
			old.get_parent().remove_child(old)
			old.free()
	for child in room.get_children():
		if child is InteriorObject and String(child.name).begins_with("Loose cushion"):
			_pillow(child)
	if not room.has_node("LockedClosetDoor"):
		_door(room)

static func _pillow(body: InteriorObject) -> void:
	if body.has_meta("white_pillow"):
		return
	var mesh := InteriorRoomVisuals._first_mesh(body)
	if mesh == null:
		return
	for detail in mesh.get_children():
		mesh.remove_child(detail)
		detail.free()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Two puffed cloth faces meet at a pinched, softly rounded sewn edge.
	const STEPS := 32
	for side in [-1.0, 1.0]:
		for row in STEPS:
			for column in STEPS:
				var corners: Array[Vector2] = [Vector2(column, row), Vector2(column + 1, row), Vector2(column + 1, row + 1), Vector2(column, row + 1)]
				var order := [0, 1, 2, 0, 2, 3] if side < 0 else [0, 2, 1, 0, 3, 2]
				for index in order:
					var uv := corners[index] / float(STEPS)
					surface.set_uv(uv)
					surface.add_vertex(_pillow_point(uv * 2.0 - Vector2.ONE, side))
	surface.index()
	surface.generate_normals()
	surface.generate_tangents()
	mesh.mesh = surface.commit()
	var fabric := StandardMaterial3D.new()
	fabric.resource_name = "Soft white pillow cotton"
	fabric.albedo_color = Color(.96, .96, .945)
	fabric.roughness = .98
	fabric.metallic_specular = .18
	fabric.normal_enabled = true
	fabric.normal_texture = load("res://assets/surfaces/linen_normal.png")
	fabric.normal_scale = .18
	fabric.uv1_scale = Vector3(3, 3, 3)
	mesh.material_override = fabric
	mesh.set_surface_override_material(0, null)
	var edge := PackedVector3Array()
	for segment in 4:
		for step in STEPS:
			var t := float(step) / STEPS * 2.0 - 1.0
			var uv: Vector2 = [Vector2(t, -1), Vector2(1, t), Vector2(-t, 1), Vector2(-1, -t)][segment]
			edge.append(_pillow_point(uv, 1))
	edge.append(edge[0])
	InteriorRoomVisuals._detail(mesh, "White pillow stitched edge", InteriorRoomVisuals._tubes([edge], .0015), fabric)
	for child in body.get_children():
		if child is CollisionShape3D:
			var shape := ConvexPolygonShape3D.new()
			shape.points = mesh.mesh.get_faces()
			child.shape = shape
			child.transform = mesh.transform
	body.display_name = "White pillow"
	body.set_meta("white_pillow", true)

static func _pillow_point(uv: Vector2, side: float) -> Vector3:
	var u := uv.x
	var v := uv.y
	var puff := sqrt(maxf(0, (1 - u * u) * (1 - v * v)))
	var crease := .006 * sin(u * 24 + v * 5) * pow(absf(v), 8) * puff
	var p := Vector3(.285 * u * (1 - .10 * pow(v, 6)), .24 * v * (1 - .10 * pow(u, 6)), side * (.105 * puff + crease))
	return Basis(Vector3.RIGHT, deg_to_rad(12)) * p

static func _box(parent: Node3D, label: String, center: Vector3, size: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	node.position = center
	parent.add_child(node)

static func _door(room: Node3D) -> void:
	var door := Node3D.new()
	door.set_script(LockedDoor)
	door.name = "LockedClosetDoor"
	door.position = Vector3(3.25, 0, .90)
	room.add_child(door)
	var body := StaticBody3D.new()
	body.name = "ClosedDoor"
	body.collision_layer = 2
	body.collision_mask = 5
	door.add_child(body)
	var wood := InteriorMaterials.material("walnut").duplicate() as StandardMaterial3D
	wood.resource_name = "Closet door dark wood"
	wood.roughness = .65
	var metal := InteriorMaterials.material("black_metal")
	_box(body, "Solid wood door", Vector3(0, 1.175, 0), Vector3(.065, 2.31, 1.045), wood)
	# Two inset panels and narrow rails match the existing dark timber frame.
	for y in [.62, 1.73]:
		_box(body, "Inset panel", Vector3(-.040, y, 0), Vector3(.018, .93, .81), wood)
		for z in [-.42, .42]:
			_box(body, "Panel stile", Vector3(-.055, y, z), Vector3(.027, .98, .025), wood)
		for offset in [-.48, .48]:
			_box(body, "Panel rail", Vector3(-.055, y + offset, 0), Vector3(.027, .025, .865), wood)
	_box(body, "Handle plate", Vector3(-.064, 1.05, .39), Vector3(.018, .16, .06), metal)
	_box(body, "Handle stem", Vector3(-.098, 1.08, .39), Vector3(.055, .026, .026), metal)
	_box(body, "Lever handle", Vector3(-.123, 1.08, .335), Vector3(.025, .028, .14), metal)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(.10, 2.33, 1.07)
	collider.shape = shape
	collider.position = Vector3(0, 1.17, 0)
	body.add_child(collider)
