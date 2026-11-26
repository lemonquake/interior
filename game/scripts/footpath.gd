class_name InteriorFootpath
extends RefCounted
## 0.11: a raised earthen path from the dirt road out across the paddy, made at runtime under the baked Fields
## (first the hut's causeway in 0.10, now also the dike out to the scarecrow's islet).
## - Visible: a grassy top and muddy banks sloping down into the water.
## - Solid: a walking slab from the road verge to the far end, low invisible walls along both edges, and a gap cut
##   in the road's invisible edge wall where it leaves the road.
## - With `pad_radius` > 0 the far end is a round islet: a pad to stand on and a ring of low walls around it, open
##   where the path arrives.
## build() returns the route along it: road centre, the verge, the far end (and the islet's centre with a pad).

const GROUND := -2.9
const WATER_Y := GROUND - .42
const WALK_HALF := 3.2       # the dirt road's walkable half width (fields_builder.gd)
const OUTDOOR_LAYER := 2

## `to_point` is the far end (world, y ignored). `end_y` is the walking height there. `top` / `bank` are the
## materials for the grassy top and the muddy banks.
static func build(fields: Node3D, from_road_index: int, to_point: Vector3, half_width: float, end_y: float,
		top: Material, bank: Material, label := "Footpath", pad_radius := 0.0) -> Array[Vector3]:
	var road: PackedVector2Array = fields.get_meta("road_samples") if fields.has_meta("road_samples") else PackedVector2Array()
	var route: Array[Vector3] = []
	if road.is_empty():
		return route
	var i := clampi(from_road_index, 0, road.size() - 1)
	var centre := road[i]
	var far := Vector2(to_point.x, to_point.z)
	var dir := (far - centre).normalized()
	var n := Vector2(-dir.y, dir.x)
	var path := Node3D.new()
	path.name = label
	fields.add_child(path)
	# From the road's edge wall to the far end.
	var start := centre + dir * (WALK_HALF + .12)
	# With an islet the path stops just inside its flat top (the islet itself is part of the fields bake).
	var end := far - dir * (pad_radius - .15) if pad_radius > 0.0 else far
	var start_y := _ground_y(fields, Vector3(start.x - dir.x * .5, GROUND, start.y - dir.y * .5), GROUND - .05)
	var a := start - dir * .6
	var b := end + dir * (.1 if pad_radius > 0.0 else .3)
	var top_y: Array[float] = [start_y - .02, end_y]
	var base := WATER_Y - .15
	var faces := [
		[Vector3(a.x + n.x * half_width, top_y[0], a.y + n.y * half_width), Vector3(b.x + n.x * half_width, top_y[1], b.y + n.y * half_width),
		 Vector3(b.x - n.x * half_width, top_y[1], b.y - n.y * half_width), Vector3(a.x - n.x * half_width, top_y[0], a.y - n.y * half_width)],
	]
	for s in [-1.0, 1.0]:
		var o: Vector2 = n * s
		faces.append([Vector3(a.x + o.x * half_width, top_y[0], a.y + o.y * half_width), Vector3(a.x + o.x * (half_width + .6), base, a.y + o.y * (half_width + .6)),
			Vector3(b.x + o.x * (half_width + .6), base, b.y + o.y * (half_width + .6)), Vector3(b.x + o.x * half_width, top_y[1], b.y + o.y * half_width)])
	for item in [[quads(faces.slice(0, 1)), top, label + " top"], [quads(faces.slice(1)), bank, label + " banks"]]:
		var mi := MeshInstance3D.new()
		mi.name = item[2]
		mi.mesh = item[0]
		mi.material_override = item[1]
		mi.layers = OUTDOOR_LAYER
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		path.add_child(mi)
	# The walking surface (tilted so the far end sits lower), and low walls along it.
	var body := StaticBody3D.new()
	body.name = label.replace(" ", "") + "Colliders"
	body.collision_layer = 2
	body.collision_mask = 5
	path.add_child(body)
	# Exact top vertices shared by render and collision: no lip, tilted slab offset or invisible step.
	var flat := Basis(Vector3(-n.x, 0, -n.y), Vector3.UP, Vector3(dir.x, 0, dir.y))
	var points := PackedVector3Array()
	for p: Vector3 in faces[0]:
		points.append(p)
		points.append(p + Vector3.DOWN * .6)
	var floor_shape := ConvexPolygonShape3D.new()
	floor_shape.points = points
	var floor_collision := CollisionShape3D.new()
	floor_collision.name = label
	floor_collision.shape = floor_shape
	body.add_child(floor_collision)
	var edge_length := start.distance_to(end) + .1
	if pad_radius > 0.0:
		edge_length = start.distance_to(far) - (pad_radius + .14) + .12  # up to the islet's ring of walls
	for s in [-1.0, 1.0]:
		var o: Vector2 = n * s * (half_width + .22)
		var edge_mid := start + dir * edge_length * .5
		_solid(body, label + " edge", Vector3(edge_mid.x + o.x, GROUND + .3, edge_mid.y + o.y), Vector3(.24, 2.4, edge_length), flat)
	if pad_radius > 0.0:
		_islet_pad(body, far, pad_radius, end_y, -dir, half_width, label)
		# Widen the visible island together with its support; banks slope into the existing water.
		var top_faces: Array = []
		var bank_faces: Array = []
		for k in 32:
			var angle := TAU * k / 32.0
			var next_angle := TAU * (k + 1) / 32.0
			var u := Vector2(cos(angle), sin(angle))
			var v := Vector2(cos(next_angle), sin(next_angle))
			var centre3 := Vector3(far.x, end_y + .002, far.y)
			var p0 := centre3 + Vector3(u.x, 0, u.y) * pad_radius
			var p1 := centre3 + Vector3(v.x, 0, v.y) * pad_radius
			# A small inner ring avoids degenerate quads at the centre.
			top_faces.append([centre3 + Vector3(u.x, 0, u.y) * .02, p0, p1, centre3 + Vector3(v.x, 0, v.y) * .02])
			bank_faces.append([p0, Vector3(far.x + u.x * (pad_radius + .9), base, far.y + u.y * (pad_radius + .9)), Vector3(far.x + v.x * (pad_radius + .9), base, far.y + v.y * (pad_radius + .9)), p1])
		for spec in [[top_faces, top, "Cleared island"], [bank_faces, bank, "Island banks"]]:
			var mesh := MeshInstance3D.new()
			mesh.name = spec[2]
			mesh.mesh = quads(spec[0])
			mesh.material_override = spec[1]
			mesh.layers = OUTDOOR_LAYER
			path.add_child(mesh)
	open_road_wall(fields, start, half_width + .35)
	route.append(Vector3(centre.x, GROUND, centre.y))
	route.append(Vector3(start.x, GROUND, start.y))
	route.append(Vector3(end.x, GROUND, end.y))
	if pad_radius > 0.0:
		route.append(Vector3(far.x, GROUND, far.y))
	return route

## A round pad at `centre` (a 16-sided slab) and a ring of walls around it, open toward `opening` (unit, xz).
static func _islet_pad(body: StaticBody3D, centre: Vector2, radius: float, top_y: float, opening: Vector2, gap_half: float, label: String) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = .6
	var collision := CollisionShape3D.new()
	collision.name = (label + " islet").validate_node_name()
	collision.shape = shape
	body.add_child(collision, true)
	collision.position = Vector3(centre.x, top_y - .3, centre.y)
	var sides := 12
	var wall_r := radius + .14
	var chord := 2.0 * wall_r * tan(PI / sides) + .06
	for k in sides:
		var a := TAU * (k + .5) / sides
		var out := Vector2(cos(a), sin(a))
		# Leave the opening where the path arrives (wide enough for the path between its edge walls).
		if out.dot(opening) > cos(asin(clampf((gap_half + .35) / wall_r, 0.0, 1.0)) + PI / sides):
			continue
		var p := centre + out * wall_r
		var basis := Basis(Vector3(out.x, 0, out.y), Vector3.UP, Vector3(-out.y, 0, out.x))
		_solid(body, label + " islet edge", Vector3(p.x, GROUND + .3, p.y), Vector3(.24, 2.4, chord), basis)

static func _solid(body: CollisionObject3D, label: String, center: Vector3, size: Vector3, basis := Basis.IDENTITY) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = label.validate_node_name()
	collision.shape = shape
	body.add_child(collision, true)
	collision.transform = Transform3D(basis, center)
	return collision

static func quads(faces: Array) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for pts: Array in faces:
		var normal: Vector3 = (pts[1] - pts[0]).cross(pts[3] - pts[0]).normalized()
		if normal.y < 0.0:
			pts = [pts[3], pts[2], pts[1], pts[0]]
			normal = -normal
		# Godot's front faces wind clockwise, opposite the cross product used for the normal.
		for k in [0, 2, 1, 0, 3, 2]:
			var p: Vector3 = pts[k]
			tool.set_normal(normal)
			tool.set_uv(Vector2(p.x, p.z) * .5)
			tool.add_vertex(p)
	tool.generate_tangents()
	return tool.commit()

static func _ground_y(fields: Node3D, at: Vector3, fallback: float) -> float:
	if not fields.is_inside_tree():
		return fallback
	var space := fields.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.5, at + Vector3.DOWN * 1.5)
	query.collision_mask = 2
	var hit := space.intersect_ray(query)
	return float(hit.position.y) if not hit.is_empty() else fallback

## Cuts a gap in the road's invisible edge wall where a path leaves the road at `start` (on the wall line).
static func open_road_wall(fields: Node3D, start: Vector2, half_width: float) -> void:
	var walls := fields.find_child("FieldsColliders", true, false)
	if walls == null:
		return
	var half_gap := half_width + .1
	for child in walls.get_children():
		var shape := child as CollisionShape3D
		if shape == null or shape.disabled or not String(shape.name).begins_with("Road edge") or not shape.shape is BoxShape3D:
			continue
		var c := Vector2(shape.position.x, shape.position.z)
		var axis3 := shape.transform.basis.z.normalized()
		var axis := Vector2(axis3.x, axis3.z).normalized()
		var length := (shape.shape as BoxShape3D).size.z
		# Distance of the path's centre line from this wall segment's line, and where it crosses.
		var rel := start - c
		var across := rel.dot(Vector2(-axis.y, axis.x))
		var along := rel.dot(axis)
		if absf(across) > .6 or absf(along) > length * .5 + half_gap:
			continue
		var size := (shape.shape as BoxShape3D).size
		var basis := shape.transform.basis
		var y := shape.position.y
		var lo := -length * .5
		var hi := length * .5
		for piece in [[lo, along - half_gap], [along + half_gap, hi]]:
			var p0: float = piece[0]
			var p1: float = piece[1]
			if p1 - p0 < .05:
				continue
			var centre := c + axis * (p0 + p1) * .5
			var box := BoxShape3D.new()
			box.size = Vector3(size.x, size.y, p1 - p0)
			var cut := CollisionShape3D.new()
			cut.name = "Road edge (path gap)"
			cut.shape = box
			walls.add_child(cut, true)
			cut.transform = Transform3D(basis, Vector3(centre.x, y, centre.y))
		shape.queue_free()
		shape.disabled = true
