class_name InteriorNeighborhoodDerelict
extends RefCounted
## Additive dressing for the baked neighbourhood. Every detail is tied to an existing
## window or solid wall; this never removes geometry or changes walking collisions.
## Photograph-based materials, chipped silhouettes and shallow relief hold up at street level.

const GROUND := -2.9
const OUTDOOR_LAYER := 2
const SEED := 612046

var _root: Node3D
var _details: Node3D
var _rng := RandomNumberGenerator.new()
var _batches: Dictionary = {}
var _materials: Dictionary = {}
var _houses: Array[Dictionary] = []
## 0.34: every window pane found on the baked houses (scripts/window_glass.gd breaks them): {at, normal, width,
## height, cover} in the neighbourhood's own frame. cover: 0 bare, 1 boarded, 2 behind a sheet of roofing iron.
var _panes: Array[Dictionary] = []
var _stats := {"windows_found": 0, "boarded_windows": 0, "timber_boards": 0,
	"corrugated_sheets": 0, "exposed_masonry": 0, "wall_fractures": 0,
	"rubble_fragments": 0, "broken_wall_tops": 0, "batches": 0}

static func build(parent: Node3D) -> Dictionary:
	var existing := parent.get_node_or_null("Derelict facades")
	if existing != null:
		return existing.get_meta("derelict_stats", {})
	var dressing = (load("res://scripts/neighborhood_derelict.gd") as GDScript).new()
	dressing._root = parent
	dressing._details = Node3D.new()
	dressing._details.name = "Derelict facades"
	parent.add_child(dressing._details)
	dressing._rng.seed = SEED
	dressing._make_materials()
	dressing._read_houses()
	dressing._break_wall_tops()
	dressing._dress_windows()
	dressing._dress_walls()
	dressing._commit()
	dressing._details.set_meta("derelict_stats", dressing._stats)
	dressing._details.set_meta("window_panes", dressing._panes)
	return dressing._stats.duplicate()

func _make_materials() -> void:
	_pbr("Weathered timber", "dark_wooden_planks", Color(1.08, 1.03, .96), .95)
	_pbr("Rusted sheet", "rusty_corrugated_iron", Color(.79, .77, .72), .86)
	(_materials["Rusted sheet"] as StandardMaterial3D).metallic = .23
	_pbr("Exposed masonry", "concrete_block_wall", Color(.68, .66, .60), .99)
	_pbr("Broken plaster", "concrete_wall_008", Color(.87, .84, .76), .96)
	_pbr("Fallen masonry", "concrete_wall_008", Color(.65, .61, .53), 1.0)
	_pbr("Fracture recess", "concrete_wall_008", Color(.15, .135, .10), 1.0)
	_pbr("Rust fasteners", "rusty_metal_02", Color(.32, .29, .24), .93)
	(_materials["Rust fasteners"] as StandardMaterial3D).metallic = .3

func _pbr(key: String, texture_set: String, tint: Color, roughness: float) -> void:
	var directory := "res://assets/outdoor/textures/" + texture_set + "/"
	var material := StandardMaterial3D.new()
	material.resource_name = "Derelict / " + key
	material.albedo_texture = load(directory + "albedo.jpg") as Texture2D
	material.normal_enabled = true
	material.normal_texture = load(directory + "normal.jpg") as Texture2D
	material.normal_scale = .78
	material.roughness_texture = load(directory + "roughness.jpg") as Texture2D
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	material.roughness = roughness
	material.albedo_color = tint
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_materials[key] = material

func _local_transform(node: Node3D) -> Transform3D:
	# Supports both runtime scenes and an unparented scene during a bake/inspection.
	var transform := node.transform
	var ancestor := node.get_parent()
	while ancestor != _root and ancestor is Node3D:
		transform = (ancestor as Node3D).transform * transform
		ancestor = ancestor.get_parent()
	return transform

func _read_houses() -> void:
	var colliders := _root.get_node_or_null("NeighbourhoodColliders")
	if colliders == null:
		return
	for child in colliders.get_children():
		if not child is CollisionShape3D or not str(child.name).begins_with("House"):
			continue
		var collider := child as CollisionShape3D
		if not collider.shape is BoxShape3D:
			continue
		var transform := _local_transform(collider)
		var size := (transform.basis * (collider.shape as BoxShape3D).size).abs()
		_houses.append({"center": transform.origin, "size": size,
			"severity": _rng.randf_range(.34, .77)})

func _house_at_window(point: Vector3, normal: Vector3) -> int:
	for i in _houses.size():
		var house: Dictionary = _houses[i]
		var center: Vector3 = house.center
		var size: Vector3 = house.size
		var delta := point - center
		if absf(delta.y) > size.y * .5 or delta.dot(normal) < .0:
			continue
		# Colliders extend 5 cm past the rendered house body; panes project 6.5 cm.
		var plane := size.x * .5 if absf(normal.x) > .8 else size.z * .5
		var across := absf(delta.z) if absf(normal.x) > .8 else absf(delta.x)
		var width := size.z if absf(normal.x) > .8 else size.x
		if absf(delta.dot(normal) - plane) < .1 and across < width * .5:
			return i
	return -1

func _dress_windows() -> void:
	# The builder emits six indices per quad, preserved by SurfaceTool.index().
	# Reading those quads identifies actual openings, including randomly omitted windows.
	var seen: Dictionary = {}
	for child in _root.get_children():
		if not child is MeshInstance3D:
			continue
		var label := str(child.name)
		if label != "Neighbourhood - n glass" and not label.begins_with("Neighbourhood - n curtain"):
			continue
		var instance := child as MeshInstance3D
		if instance.mesh == null:
			continue
		var transform := _local_transform(instance)
		for surface in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for i in vertices.size():
					indices.append(i)
			for first in range(0, indices.size() - 5, 6):
				var normal := (transform.basis * normals[indices[first]]).normalized()
				if absf(normal.y) > .1:
					continue
				var bounds := AABB(transform * vertices[indices[first]], Vector3.ZERO)
				for offset in 6:
					bounds = bounds.expand(transform * vertices[indices[first + offset]])
				var width := maxf(bounds.size.x, bounds.size.z)
				if width < .7 or width > 1.7 or bounds.size.y < .7 or bounds.size.y > 1.6:
					continue
				var point := bounds.get_center()
				var house_index := _house_at_window(point, normal)
				if house_index < 0:
					continue
				var key := "%0.2f,%0.2f,%0.2f" % [point.x, point.y, point.z]
				if seen.has(key):
					continue
				seen[key] = true
				_stats.windows_found += 1
				# The inward face also matches the slab, so admit only the outermost face.
				var center: Vector3 = _houses[house_index].center
				var extent: Vector3 = _houses[house_index].size
				var plane := extent.x * .5 if absf(normal.x) > .8 else extent.z * .5
				if (point - center).dot(normal) < plane + .006:
					continue
				_rng.seed = SEED + int(absf(point.x * 317.0 + point.z * 773.0 + point.y * 1211.0))
				var pane := {"at": point, "normal": normal, "width": width, "height": bounds.size.y, "cover": 0}
				_panes.append(pane)
				if _rng.randf() > float(_houses[house_index].severity):
					continue
				var frame := Basis(Vector3.UP.cross(normal), Vector3.UP, normal)
				point += normal * .091 # outside both the glass and the existing grille
				if _rng.randf() < .13:
					pane.cover = 2
					_sheet(point + Vector3.DOWN * .04, frame, width + .16, bounds.size.y * .87)
				else:
					pane.cover = 1
					_board_window(point, frame, width, bounds.size.y)
				_stats.boarded_windows += 1

func _board_window(point: Vector3, frame: Basis, width: float, height: float) -> void:
	var count := _rng.randi_range(2, 4)
	for i in count:
		var fraction := (float(i) + .5) / float(count)
		var y := lerpf(-height * .41, height * .41, fraction) + _rng.randf_range(-.065, .065)
		var tilt := _rng.randf_range(-.11, .11)
		var plank_frame := frame * Basis(Vector3.BACK, tilt)
		var length := width + _rng.randf_range(.13, .36)
		var timber_center := point + Vector3.UP * y + frame.z * float(i % 2) * .013
		_plank(timber_center, plank_frame, length, _rng.randf_range(.16, .225))
		for side in [-1.0, 1.0]:
			_fastener(timber_center + plank_frame.x * (length * .5 - .09) + frame.z * .041, frame)
	# A diagonal repair brace is used sparingly; neighboring windows have different repairs.
	if _rng.randf() < .24:
		var tilt := _rng.randf_range(.4, .68) * (-1.0 if _rng.randf() < .5 else 1.0)
		_plank(point + frame.z * .06, frame * Basis(Vector3.BACK, tilt), width * 1.12, .115)

func _plank(center: Vector3, frame: Basis, length: float, width: float) -> void:
	var half := length * .5
	var w := width * .5
	# Asymmetric broken ends and one missing splinter are actual geometry, not a decal.
	var outline: Array[Vector2] = [Vector2(-half, -w * .85), Vector2(-half + .042, -w * .15),
		Vector2(-half + .015, w), Vector2(half - .04, w * .91),
		Vector2(half, w * .37), Vector2(half - .021, -w * .8),
		Vector2(half - .12, -w), Vector2(-half + .1, -w)]
	var tint := Color.from_hsv(.075, _rng.randf_range(.04, .15), _rng.randf_range(.72, 1.0))
	var v_offset := _rng.randf_range(.05, .84)
	_polygon_prism(center, frame, outline, .033, "Weathered timber", tint, Vector2(.7, .72), Vector2(_rng.randf(), v_offset))
	_stats.timber_boards += 1

func _fastener(point: Vector3, frame: Basis) -> void:
	var points: Array[Vector3] = []
	for i in 6:
		var angle := TAU * float(i) / 6.0
		points.append(point + (frame.x * cos(angle) + frame.y * sin(angle)) * .009)
	for i in range(1, 5):
		_triangle("Rust fasteners", points[0], points[i], points[i + 1], frame.z,
			Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Color(.6, .55, .48))

func _sheet(center: Vector3, frame: Basis, width: float, height: float) -> void:
	var columns := maxi(18, int(width / .026))
	var rows := 6
	var points: Array[Vector3] = []
	var tint := Color(_rng.randf_range(.73, .94), _rng.randf_range(.70, .91), _rng.randf_range(.64, .85))
	var phase := _rng.randf_range(0.0, TAU)
	for row in rows + 1:
		var fy := float(row) / float(rows)
		for column in columns + 1:
			var fx := float(column) / float(columns)
			var x := (fx - .5) * width
			var y := (fy - .5) * height
			if row == 0:
				y += sin(float(column) * 2.19 + phase) * .019
			# Visible corrugation plus a wind-bent free lower corner.
			var ripple := sin(x * TAU / .085) * .011
			var bend := pow(1.0 - fy, 3.0) * (.035 + .13 * fx * fx)
			points.append(center + frame * Vector3(x, y, ripple + bend))
	for row in rows:
		for column in columns:
			if row == 0 and ((column < 2 and phase < 2.0) or (column == columns - 1 and phase > 4.0)):
				continue
			var a := row * (columns + 1) + column
			var b := a + 1
			var c := b + columns + 1
			var d := a + columns + 1
			var normal := (points[b] - points[a]).cross(points[d] - points[a]).normalized()
			var uv_a := Vector2(float(column) / columns, 1.0 - float(row) / rows)
			var uv_b := Vector2(float(column + 1) / columns, uv_a.y)
			var uv_c := Vector2(uv_b.x, 1.0 - float(row + 1) / rows)
			var uv_d := Vector2(uv_a.x, uv_c.y)
			_triangle("Rusted sheet", points[a], points[b], points[c], normal, uv_a, uv_b, uv_c, tint)
			_triangle("Rusted sheet", points[a], points[c], points[d], normal, uv_a, uv_c, uv_d, tint)
	for side in [-1.0, 1.0]:
		_fastener(center + frame.x * side * (width * .5 - .09) + Vector3.UP * height * .37 + frame.z * .025, frame)
	_stats.corrugated_sheets += 1

func _dress_walls() -> void:
	var colliders := _root.get_node_or_null("NeighbourhoodColliders")
	if colliders == null:
		return
	var serial := 0
	for child in colliders.get_children():
		if not child is CollisionShape3D:
			continue
		var label := str(child.name)
		var is_house := label.begins_with("House")
		if not is_house and not label.begins_with("Fence wall"):
			continue
		var collider := child as CollisionShape3D
		if not collider.shape is BoxShape3D:
			continue
		var transform := _local_transform(collider)
		var size := (transform.basis * (collider.shape as BoxShape3D).size).abs()
		var center := transform.origin
		serial += 1
		_rng.seed = SEED + serial * 179
		if _rng.randf() > (.84 if is_house else .88):
			continue
		var normals: Array = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD] if is_house else ([Vector3.BACK, Vector3.FORWARD] if size.x > size.z else [Vector3.RIGHT, Vector3.LEFT])
		for normal: Vector3 in normals:
			var street_facing := _faces_street(center, normal)
			if _rng.randf() > (.92 if street_facing else .54):
				continue
			var along_x := absf(normal.z) > .5
			var length := size.x if along_x else size.z
			if length < 1.0:
				continue
			var wall_plane := (size.z if along_x else size.x) * .5
			# Rendered house walls sit 5 cm inside their collision. Fence colliders are exact.
			wall_plane += -.05 if is_house else .0
			var frame := Basis(Vector3.UP.cross(normal), Vector3.UP, normal)
			var patch_width := minf(_rng.randf_range(1.05, 2.7) if street_facing else _rng.randf_range(.74, 2.05), length - .35)
			var offset := _rng.randf_range(-length * .5 + patch_width * .5 + .12, length * .5 - patch_width * .5 - .12)
			var point := Vector3(center.x, GROUND + (.31 if is_house else .05), center.z) + normal * (wall_plane + .009) + frame.x * offset
			var patch_height := _rng.randf_range(.38, .94) if street_facing else _rng.randf_range(.29, .68)
			var intact_height := float(collider.get_meta("broken_top_clearance", size.y - .17))
			patch_height = minf(patch_height, intact_height - .10)
			_masonry_patch(point, frame, patch_width, patch_height)
			if _rng.randf() < (.86 if street_facing else .48):
				var fracture_top := minf(intact_height, _rng.randf_range(1.25, 2.35))
				_wall_fracture(point + frame.z * .007, frame, Vector2(_rng.randf_range(-patch_width * .22, patch_width * .22), fracture_top), Vector2(_rng.randf_range(-patch_width * .15, patch_width * .15), patch_height * .52), .008)
			# Debris remains within a narrow strip beside an already-solid wall.
			for fragment in _rng.randi_range(5, 12):
				var p := Vector3(point.x, GROUND + .045, point.z) + frame.x * _rng.randf_range(-patch_width * .65, patch_width * .65) + normal * _rng.randf_range(.04, .3)
				p.y = _debris_ground(p)
				_rubble(p, _rng.randf_range(.035, .115))

func _debris_ground(point: Vector3) -> float:
	for x: float in [21.0, -19.0]:
		var edge := absf(point.x - x)
		if edge >= 2.0 and edge <= 3.0:
			return GROUND + .125
	for z: float in [18.0, 49.0]:
		var edge := absf(point.z - z)
		if edge >= 2.0 and edge <= 3.0:
			return GROUND + .125
	return GROUND + .032

func _faces_street(center: Vector3, normal: Vector3) -> bool:
	var toward := Vector3.ZERO
	var distance := INF
	for x in [21.0, -19.0]:
		if absf(center.x - x) < distance:
			distance = absf(center.x - x)
			toward = Vector3(x - center.x, .0, .0)
	for z in [18.0, 49.0]:
		if absf(center.z - z) < distance:
			distance = absf(center.z - z)
			toward = Vector3(.0, .0, z - center.z)
	return toward.dot(normal) > .0

func _break_wall_tops() -> void:
	# Replace a few complete fence boxes and their caps with profiled geometry. This creates
	# real broken silhouettes; collision remains a closed boundary of the same footprint.
	var targets: Array[Dictionary] = []
	var colliders := _root.get_node_or_null("NeighbourhoodColliders")
	if colliders == null:
		return
	for child in colliders.get_children():
		if not child is CollisionShape3D or not str(child.name).begins_with("Fence wall"):
			continue
		var collision := child as CollisionShape3D
		if not collision.shape is BoxShape3D:
			continue
		var size := (collision.shape as BoxShape3D).size - Vector3(0, .1, 0)
		var p := collision.position
		var length := maxf(size.x, size.z)
		if length < 2.6 or not Rect2(-24, -15, 53, 70).has_point(Vector2(p.x, p.z)):
			continue
		var edge_distance := minf(minf(absf(p.x - 21), absf(p.x + 19)), minf(absf(p.z - 18), absf(p.z - 49)))
		if edge_distance > 3.5:
			continue
		_rng.seed = SEED + int(absf(p.x * 491 + p.z * 977))
		if _rng.randf() > .62:
			continue
		var bounds := AABB(p - size * .5, size).grow(.004)
		var cap_size := Vector3(size.x, .06, size.z) + (Vector3(0, 0, .06) if size.x > size.z else Vector3(.06, 0, 0))
		var cap_bounds := AABB(p + Vector3.UP * (size.y * .5 + .03) - cap_size * .5, cap_size).grow(.004)
		var dip := _rng.randf_range(.18, .46)
		collision.set_meta("broken_top_clearance", size.y - dip * 1.18 - .17)
		targets.append({"position": p, "size": size, "bounds": bounds, "cap_bounds": cap_bounds,
			"material": null, "dip": dip, "offset": _rng.randf_range(.28, .72)})
	for child in _root.get_children():
		if not child is MeshInstance3D or not str(child.name).begins_with("Neighbourhood - n "):
			continue
		var instance := child as MeshInstance3D
		var original := instance.material_override as StandardMaterial3D
		if original == null or instance.mesh == null:
			continue
		var key := original.resource_name.get_slice(" / ", 1)
		if key not in ["n block", "n concrete", "n plaster 0", "n plaster 6"]:
			continue
		var replacement := ArrayMesh.new()
		var removed := 0
		for surface in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			var retained := 0
			for i in range(0, indices.size(), 3):
				var triangle := [vertices[indices[i]], vertices[indices[i + 1]], vertices[indices[i + 2]]]
				var drop := false
				for target: Dictionary in targets:
					var wall: AABB = target.bounds
					var cap: AABB = target.cap_bounds
					if wall.has_point(triangle[0]) and wall.has_point(triangle[1]) and wall.has_point(triangle[2]):
						target.material = original
						drop = true
						break
					if cap.has_point(triangle[0]) and cap.has_point(triangle[1]) and cap.has_point(triangle[2]):
						drop = true
						break
				if drop:
					removed += 1
					continue
				for index in 3:
					var vertex_index := indices[i + index]
					tool.set_normal(normals[vertex_index])
					tool.set_uv(uvs[vertex_index])
					tool.add_vertex(vertices[vertex_index])
				retained += 1
			if retained > 0:
				tool.index()
				tool.generate_tangents()
				tool.commit(replacement)
		if removed > 0:
			instance.mesh = replacement
	for target: Dictionary in targets:
		if target.material == null:
			continue
		var p: Vector3 = target.position
		var size: Vector3 = target.size
		var along := Vector3.RIGHT if size.x > size.z else Vector3.BACK
		var front := along.cross(Vector3.UP)
		var length := maxf(size.x, size.z)
		var bottom := p.y - size.y * .5
		var top := p.y + size.y * .5
		var key := "Broken wall / " + str(target.material.resource_name)
		_materials[key] = target.material
		var count := maxi(12, int(length / .15))
		var points: Array[Vector2] = []
		var center: float = length * target.offset - length * .5
		var half_width := minf(length * .25, 1.1)
		_rng.seed = SEED + int(absf(p.x * 61 + p.z * 113))
		for i in count + 1:
			var x := -length * .5 + length * float(i) / count
			var notch := maxf(0.0, 1.0 - absf(x - center) / half_width)
			var y: float = top - target.dip * pow(notch, .55) * _rng.randf_range(.64, 1.18)
			points.append(Vector2(x, y))
		for i in count:
			var a := points[i]
			var c := points[i + 1]
			for side: float in [-1.0, 1.0]:
				var base := Vector3(p.x, 0, p.z) + front * .09 * side
				var v0 := base + along * a.x + Vector3.UP * bottom
				var v1 := base + along * c.x + Vector3.UP * bottom
				var v2 := base + along * c.x + Vector3.UP * c.y
				var v3 := base + along * a.x + Vector3.UP * a.y
				_triangle(key, v0, v1, v2, front * side, Vector2(a.x, 0), Vector2(c.x, 0), Vector2(c.x, c.y - bottom), Color.WHITE)
				_triangle(key, v0, v2, v3, front * side, Vector2(a.x, 0), Vector2(c.x, c.y - bottom), Vector2(a.x, a.y - bottom), Color.WHITE)
			var v0 := Vector3(p.x, a.y, p.z) + along * a.x - front * .09
			var v1 := Vector3(p.x, c.y, p.z) + along * c.x - front * .09
			var v2 := v1 + front * .18
			var v3 := v0 + front * .18
			var cap_normal := (v1 - v0).cross(v3 - v0).normalized()
			if cap_normal.y < 0:
				cap_normal = -cap_normal
			_triangle("Fallen masonry", v0, v1, v2, cap_normal, Vector2(a.x, 0), Vector2(c.x, 0), Vector2(c.x, .18), Color(.48, .47, .41))
			_triangle("Fallen masonry", v0, v2, v3, cap_normal, Vector2(a.x, 0), Vector2(c.x, .18), Vector2(a.x, .18), Color(.48, .47, .41))
		for edge: Vector2 in [points[0], points[-1]]:
			var outside: Vector3 = -along if edge.x < 0 else along
			var base := Vector3(p.x, bottom, p.z) + along * edge.x
			var v0 := base - front * .09
			var v1 := base + front * .09
			var v2: Vector3 = v1 + Vector3.UP * (edge.y - bottom)
			var v3: Vector3 = v0 + Vector3.UP * (edge.y - bottom)
			_triangle(key, v0, v1, v2, outside, Vector2.ZERO, Vector2(.18, 0), Vector2(.18, size.y), Color.WHITE)
			_triangle(key, v0, v2, v3, outside, Vector2.ZERO, Vector2(.18, size.y), Vector2(0, size.y), Color.WHITE)
		_stats.broken_wall_tops += 1

func _wall_fracture(point: Vector3, frame: Basis, from: Vector2, to: Vector2, width: float, branch := false) -> void:
	var steps := 9 if not branch else 5
	var points: Array[Vector2] = [from]
	for i in range(1, steps + 1):
		var progress := float(i) / float(steps)
		var p := from.lerp(to, progress)
		p.x += _rng.randf_range(-.083, .083) * sin(progress * PI)
		p.y += _rng.randf_range(-.025, .025)
		points.append(p)
	for i in steps:
		var a := points[i]
		var b := points[i + 1]
		var across := (b - a).normalized()
		var edge := Vector2(-across.y, across.x) * width * _rng.randf_range(.52, 1.16)
		var p0 := point + frame * Vector3(a.x - edge.x, a.y - edge.y, .0)
		var p1 := point + frame * Vector3(b.x - edge.x, b.y - edge.y, .0)
		var p2 := point + frame * Vector3(b.x + edge.x, b.y + edge.y, .0)
		var p3 := point + frame * Vector3(a.x + edge.x, a.y + edge.y, .0)
		_triangle("Fracture recess", p0, p1, p2, frame.z, a, b, b + edge, Color(.82, .81, .78))
		_triangle("Fracture recess", p0, p2, p3, frame.z, a, b + edge, a + edge, Color(.82, .81, .78))
		# One pale spalled lip catches the grazing moonlight next to the darker crevice.
		if i % 3 != 1:
			var lip_a := p3 + frame * Vector3(edge.x * .42, edge.y * .42, .0015)
			var lip_b := p2 + frame * Vector3(edge.x * .42, edge.y * .42, .0015)
			_triangle("Broken plaster", p3, p2, lip_b, frame.z, a, b, b + edge, Color(.73, .72, .66))
			_triangle("Broken plaster", p3, lip_b, lip_a, frame.z, a, b + edge, a + edge, Color(.73, .72, .66))
	if not branch:
		var junction := points[4]
		var side := -1.0 if _rng.randf() < .5 else 1.0
		_wall_fracture(point, frame, junction, junction + Vector2(_rng.randf_range(.19, .46) * side, _rng.randf_range(-.29, .11)), width * .5, true)
		_stats.wall_fractures += 1

func _masonry_patch(point: Vector3, frame: Basis, width: float, height: float) -> void:
	var outline: Array[Vector2] = [Vector2(-width * .5, .02), Vector2(width * .5, .01)]
	# Uneven lath/plaster failure: irregular shoulder and chipped aggregate rim.
	for i in range(9, -1, -1):
		var x := lerpf(-width * .5, width * .5, float(i) / 9.0)
		var hump := pow(maxf(0.0, 1.0 - absf(x) / (width * .54)), .45)
		outline.append(Vector2(x, height * hump * _rng.randf_range(.69, 1.0)))
	_polygon_prism(point, frame, outline, .007, "Exposed masonry", Color(.91, .91, .86), Vector2(.48, .48), Vector2(_rng.randf(), .0))
	for i in range(2, outline.size() - 1):
		var a := outline[i]
		var b := outline[i + 1]
		var across := (b - a).normalized()
		var edge := Vector2(across.y, -across.x) * _rng.randf_range(.014, .029)
		var p0 := point + frame * Vector3(a.x, a.y, .014)
		var p1 := point + frame * Vector3(b.x, b.y, .014)
		var p2 := point + frame * Vector3(b.x + edge.x, b.y + edge.y, .002)
		var p3 := point + frame * Vector3(a.x + edge.x, a.y + edge.y, .002)
		var tint := Color(_rng.randf_range(.77, .95), .83, .72)
		_triangle("Broken plaster", p0, p1, p2, frame.z, a, b, b + edge, tint)
		_triangle("Broken plaster", p0, p2, p3, frame.z, a, b + edge, a + edge, tint)
	_stats.exposed_masonry += 1

func _rubble(point: Vector3, radius: float) -> void:
	var frame := Basis(Vector3.UP, _rng.randf_range(-PI, PI))
	var points: Array[Vector3] = []
	var count := _rng.randi_range(4, 6)
	for i in count:
		var angle := TAU * float(i) / float(count)
		var r := radius * _rng.randf_range(.65, 1.15)
		points.append(point + frame * Vector3(cos(angle) * r, .0, sin(angle) * r * .7))
	var top := point + Vector3(_rng.randf_range(-.2, .2) * radius, radius * _rng.randf_range(.24, .65), _rng.randf_range(-.2, .2) * radius)
	var tint := Color(_rng.randf_range(.68, 1.0), _rng.randf_range(.68, .92), _rng.randf_range(.65, .83))
	for i in count:
		var next := (i + 1) % count
		var normal := (top - points[i]).cross(points[next] - points[i]).normalized()
		_triangle("Fallen masonry", points[i], top, points[next], normal, Vector2(points[i].x, points[i].z), Vector2(top.x, top.z), Vector2(points[next].x, points[next].z), tint)
	_stats.rubble_fragments += 1

func _polygon_prism(center: Vector3, frame: Basis, outline: Array[Vector2], thickness: float,
		material: String, tint: Color, uv_scale: Vector2, uv_offset: Vector2) -> void:
	var packed := PackedVector2Array(outline)
	var indices := Geometry2D.triangulate_polygon(packed)
	for i in range(0, indices.size(), 3):
		var a := outline[indices[i]]
		var b := outline[indices[i + 1]]
		var c := outline[indices[i + 2]]
		_triangle(material, center + frame * Vector3(a.x, a.y, thickness), center + frame * Vector3(b.x, b.y, thickness), center + frame * Vector3(c.x, c.y, thickness), frame.z,
			a * uv_scale + uv_offset, b * uv_scale + uv_offset, c * uv_scale + uv_offset, tint)
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var p0 := center + frame * Vector3(a.x, a.y, .0)
		var p1 := center + frame * Vector3(b.x, b.y, .0)
		var p2 := center + frame * Vector3(b.x, b.y, thickness)
		var p3 := center + frame * Vector3(a.x, a.y, thickness)
		var normal := (p1 - p0).cross(p3 - p0).normalized()
		_triangle(material, p0, p1, p2, normal, a * uv_scale + uv_offset, b * uv_scale + uv_offset, b * uv_scale + uv_offset + Vector2(.0, .01), tint.darkened(.11))
		_triangle(material, p0, p2, p3, normal, a * uv_scale + uv_offset, b * uv_scale + uv_offset + Vector2(.0, .01), a * uv_scale + uv_offset + Vector2(.0, .01), tint.darkened(.11))

func _triangle(material: String, a: Vector3, b: Vector3, c: Vector3, normal: Vector3,
		uv_a: Vector2, uv_b: Vector2, uv_c: Vector2, color: Color) -> void:
	if not _batches.has(material):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		_batches[material] = tool
	var tool: SurfaceTool = _batches[material]
	# Godot's front faces use clockwise winding; input geometry uses outward normals.
	var points: Array = [a, c, b] if (b - a).cross(c - a).dot(normal) >= .0 else [a, b, c]
	var coordinates: Array = [uv_a, uv_c, uv_b] if (b - a).cross(c - a).dot(normal) >= .0 else [uv_a, uv_b, uv_c]
	for i in 3:
		tool.set_normal(normal)
		tool.set_uv(coordinates[i])
		tool.set_color(color)
		tool.add_vertex(points[i])

func _commit() -> void:
	var _t := Time.get_ticks_usec()
	_commit__timed()
	InteriorLoadClock.tally("derelict commit", _t)

func _commit__timed() -> void:
	for key: String in _batches:
		var tool: SurfaceTool = _batches[key]
		tool.index()
		tool.generate_tangents()
		var instance := MeshInstance3D.new()
		instance.name = key
		instance.mesh = tool.commit()
		instance.material_override = _materials[key]
		instance.layers = OUTDOOR_LAYER
		instance.visibility_range_end = 110.0
		instance.visibility_range_end_margin = 15.0
		instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		_details.add_child(instance)
		_stats.batches += 1
