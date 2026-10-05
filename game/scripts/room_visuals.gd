class_name InteriorRoomVisuals
extends RefCounted
## Surface and attached detail pass for the imported room.
## Decorative meshes live beneath their own prop, so physics ownership stays intact.

static var _materials: Dictionary = {}
static var _leaf_mesh: ArrayMesh

static func apply(room: Node3D, _visual: Node3D, manifest: Dictionary, lights: Array) -> Dictionary:
	if room.has_meta("room_visuals_stats"):
		return room.get_meta("room_visuals_stats")
	_materials.clear()
	var stats := {"meshes": 0, "surface_materials": 0, "family_photos": 0, "detail_meshes": 0}
	_replace_surfaces(room, stats)
	for actor: Dictionary in manifest.get("actors", []):
		var body := room.get_node_or_null(NodePath(str(actor.nodeName))) as Node3D
		if body == null:
			continue
		var mesh := _first_mesh(body)
		if mesh == null:
			continue
		_pale_furniture_finish(mesh)
		var asset := str(actor.assetId)
		if asset in ["fabric_sofa", "leather_sofa"]:
			_sofa_seams(mesh, asset == "leather_sofa")
			stats.detail_meshes += 1
		elif asset == "potted_plant":
			_plant(mesh)
			stats.detail_meshes += 2
		elif asset == "marble_table":
			_table_lip(mesh)
			stats.detail_meshes += 1
		elif asset == "photo_frame":
			_frame_inlay(mesh)
			stats.detail_meshes += 1
		elif asset == "storage_bin":
			_bin_stitches(mesh)
			stats.detail_meshes += 1
		elif asset == "loose_component" and str(actor.nodeName).begins_with("Keyboard"):
			_keyboard(mesh)
			stats.detail_meshes += 1
		elif asset == "computer_tower":
			_hard_surface_parts(mesh)
			_tower_vents(mesh)
			stats.detail_meshes += 1
		elif asset == "standing_fan":
			_hard_surface_parts(mesh)
		elif asset in ["television", "monitor"]:
			_screen_glass(mesh, asset == "television")
			stats.detail_meshes += 1
		elif asset == "loose_component" and str(actor.nodeName).begins_with("Loose cushion"):
			_cushion_seams(mesh)
			stats.detail_meshes += 1
	configure_lighting(room, lights)
	# Recessed downlight trims are built by InteriorLighting.
	room.set_meta("room_visuals_stats", stats)
	print("INTERIOR_VISUALS ", JSON.stringify(stats))
	return stats

static func _first_mesh(node: Node) -> MeshInstance3D:
	for child in node.get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D
		var found := _first_mesh(child)
		if found != null:
			return found
	return null

static func _replace_surfaces(node: Node, stats: Dictionary) -> void:
	# The authored live habitat owns its own materials and resident coat variants.
	if node.is_in_group("hamster_habitats") or node.is_in_group("aquariums") or node.is_in_group("room_surroundings") or node is InteriorLighting:
		return
	if node is MeshInstance3D and (node as MeshInstance3D).material_override == null:
		var mesh := node as MeshInstance3D
		stats.meshes += 1
		var architectural := _is_architecture(mesh)
		for i in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(i) as StandardMaterial3D
			if original == null:
				continue
			var name := original.resource_name
			var cache_key := name + ("|arch" if architectural else "")
			if not _materials.has(cache_key):
				_materials[cache_key] = _surface(original, name, architectural)
			mesh.set_surface_override_material(i, _materials[cache_key])
			stats.surface_materials += 1
			if name.begins_with("Owner photo insert"):
				stats.family_photos += 1
	for child in node.get_children():
		_replace_surfaces(child, stats)

static func _is_architecture(node: Node) -> bool:
	var parent := node.get_parent()
	while parent != null:
		if parent is RigidBody3D:
			return false
		parent = parent.get_parent()
	return true

## Original glb material name -> shared library key (contract section 5).
static func _library_key(name: String, architectural: bool) -> String:
	match name:
		"Brown woven upholstery": return "fabric_brown"
		"Beige cushion": return "linen_beige"
		"Chocolate leather": return "leather_brown"
		"Gray crib fabric": return "canvas_gray"
		"Beige patterned rug": return "rug_wool"
		"Warm oak": return "oak_slat" if architectural else "oak"
		"Dark stained table wood": return "walnut"
		"Warm white paint": return "warm_plaster" if architectural else "white_satin"
		"Table gold marble", "Cream gold marble": return "marble_gold"
		"Cream floor tiles": return "marble_floor"
		"Ivory plastic": return "plastic_white"
		"Black plastic and steel": return "black_metal"
		"Plant foliage": return "foliage"
		"Red petals": return "petal_red"
		"Yellow petals": return "petal_yellow"
		"Purple petals": return "petal_purple"
		"Pink soft toy": return "toy_pink"
	return ""

static func _surface(source: StandardMaterial3D, name: String, architectural := false) -> Material:
	var key := _library_key(name, architectural)
	if not key.is_empty():
		var shared := InteriorMaterials.material(key)
		if name == "Cream gold marble":
			# The wall slab is honed: softer highlights than the polished table top.
			var honed := shared.duplicate() as BaseMaterial3D
			honed.resource_name = "M_marble_gold_honed"
			honed.roughness = 0.5
			honed.metallic_specular = 0.35
			return honed
		return shared
	return _legacy_surface(source, name)

static func _legacy_surface(source: StandardMaterial3D, name: String) -> StandardMaterial3D:
	var mat := source.duplicate() as StandardMaterial3D
	mat.resource_name = name + " / tactile room finish"
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mat.metallic_specular = 0.32
	# The imported vertex lighting belongs only to static architecture.
	# It remains on that receiver, while movable objects receive actual lights.
	var map_name := ""
	var uv_scale := 1.0
	if name == "Brown woven upholstery":
		map_name = "brown_weave"
		uv_scale = 4.0
	elif name == "Beige cushion":
		map_name = "linen"
		uv_scale = 4.0
	elif name == "Chocolate leather":
		map_name = "leather"
		uv_scale = 3.0
	elif name == "Gray crib fabric":
		map_name = "crib_canvas"
		uv_scale = 4.0
	elif name == "Beige patterned rug":
		map_name = "rug"
		uv_scale = 3.5
	elif name == "Warm oak":
		map_name = "oak"
		uv_scale = 1.2
	elif name == "Dark stained table wood":
		map_name = "darkwood"
		uv_scale = 1.2
	elif name == "Warm white paint":
		map_name = "plaster"
		uv_scale = 1.7
	elif name in ["Table gold marble", "Cream gold marble"]:
		map_name = "marble"
		uv_scale = 0.7
	elif name == "Cream floor tiles":
		# Preserve the licensed stone base; add restrained pore roughness.
		mat.albedo_color = Color(0.90, 0.90, 0.90)
		mat.roughness = 0.49
		mat.normal_enabled = true
		mat.normal_texture = load("res://assets/surfaces/marble_normal.png")
		mat.normal_scale = 0.35
		mat.roughness_texture = load("res://assets/surfaces/marble_roughness.jpg")
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		mat.roughness = 1.0
	elif name == "Ivory plastic":
		mat.albedo_color = Color(0.72, 0.68, 0.59)
		mat.roughness = .52
		mat.metallic_specular = .26
	elif name == "Black plastic and steel":
		mat.albedo_color = Color(.068, .077, .083)
		mat.roughness = .39
		mat.metallic = .18
		mat.metallic_specular = .42
	elif name == "Clear acrylic":
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(.69, .80, .85, .13)
		mat.roughness = .12
		mat.metallic_specular = .56
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.disable_receive_shadows = true
	elif name == "Aquarium water":
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(.25, .40, .34, .20)
		mat.roughness = .19
		mat.metallic_specular = .52
	elif name == "Plant foliage":
		mat.albedo_color = Color(.095, .22, .055)
		mat.roughness = .68
	elif name.ends_with("petals"):
		mat.roughness = .80
		mat.metallic_specular = .15
		# Keep flower hues; avoid bright flat primary colors.
		mat.albedo_color = mat.albedo_color.darkened(.13)
	elif name == "Pink soft toy":
		map_name = "linen"
		uv_scale = 5.0
		mat.albedo_color = Color(.83, .42, .50)
	elif name.begins_with("Owner photo insert"):
		var photo_index := int(name.get_slice(" ", 3))
		mat.albedo_texture = load("res://assets/family/family_%d.jpg" % photo_index)
		mat.albedo_color = Color.WHITE
		mat.uv1_scale = Vector3.ONE
		mat.uv1_offset = Vector3.ZERO
		mat.uv1_triplanar = false
		mat.roughness = .74
		mat.metallic_specular = .16
		mat.vertex_color_use_as_albedo = false
	if not map_name.is_empty():
		mat.albedo_texture = load("res://assets/surfaces/%s_color.jpg" % map_name)
		mat.normal_texture = load("res://assets/surfaces/%s_normal.png" % map_name)
		mat.roughness_texture = load("res://assets/surfaces/%s_roughness.jpg" % map_name)
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		mat.roughness = 1.0
		mat.normal_enabled = true
		mat.normal_scale = .63
		if map_name in ["oak", "darkwood"]:
			mat.normal_scale = .18
		elif map_name == "plaster":
			mat.normal_scale = .26
		if name != "Pink soft toy":
			mat.albedo_color = Color.WHITE
		mat.uv1_triplanar = true
		mat.uv1_triplanar_sharpness = 8.0
		mat.uv1_scale = Vector3.ONE * uv_scale
		mat.uv1_offset = Vector3.ZERO
	if name == "Cream gold marble":
		# The vertical stone panel is a honed finish. A polished table can reflect
		# a fixture, but a wall-sized honed slab must not produce white light discs.
		mat.roughness_texture = load("res://assets/surfaces/plaster_roughness.jpg")
		mat.roughness = .64
		mat.metallic_specular = .18
		mat.normal_scale = .35
	elif name == "Table gold marble":
		mat.metallic_specular = .24
	return mat

static func _pale_furniture_finish(mesh: MeshInstance3D) -> void:
	# Painted furniture uses satin enamel; the room walls retain matte plaster.
	for i in mesh.mesh.get_surface_count():
		var source := mesh.get_active_material(i)
		if source != null and source.resource_name.begins_with("M_warm_plaster"):
			mesh.set_surface_override_material(i, InteriorMaterials.material("white_satin"))

static func configure_lighting(_room: Node3D, _lights: Array) -> void:
	# Lighting is owned by InteriorLighting (room_lighting.gd).
	pass

static func apply_quality(_room: Node3D, _index: int, _mobile: bool) -> void:
	# Quality tiers are applied by InteriorLighting.apply_quality().
	pass

static func _detail(parent: Node3D, name: String, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.material_override = mat
	parent.add_child(node)
	return node

static func _finish(color: Color, rough := .77) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.metallic_specular = .23
	return mat

static func _rounded_outline(center: Vector3, width: float, depth: float, radius: float, vertical := false) -> PackedVector3Array:
	var points := PackedVector3Array()
	for i in 4:
		var corner := Vector2(1 if i in [0, 3] else -1, 1 if i in [0, 1] else -1)
		var origin := corner * Vector2(width * .5 - radius, depth * .5 - radius)
		for j in 7:
			var angle := (i * 90.0 + j * 15.0) * PI / 180.0
			var p := origin + Vector2(cos(angle), sin(angle)) * radius
			points.append(center + (Vector3(p.x, p.y, 0) if vertical else Vector3(p.x, 0, p.y)))
	points.append(points[0])
	return points

static func _tubes(paths: Array, radius: float, sides := 6) -> ArrayMesh:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for path: PackedVector3Array in paths:
		for i in path.size() - 1:
			var a := path[i]
			var b := path[i + 1]
			if a.distance_to(b) < .00001:
				continue
			var tangent := (b - a).normalized()
			var u := tangent.cross(Vector3.UP if absf(tangent.y) < .95 else Vector3.RIGHT).normalized()
			var v := tangent.cross(u).normalized()
			for s in sides:
				var n0 := u * cos(TAU * s / sides) + v * sin(TAU * s / sides)
				var n1 := u * cos(TAU * (s + 1) / sides) + v * sin(TAU * (s + 1) / sides)
				for vertex: Array in [[a + n0 * radius, n0], [b + n0 * radius, n0], [b + n1 * radius, n1], [a + n0 * radius, n0], [b + n1 * radius, n1], [a + n1 * radius, n1]]:
					builder.set_normal(vertex[1])
					builder.add_vertex(vertex[0])
	return builder.commit()

static func _sofa_seams(mesh: MeshInstance3D, leather: bool) -> void:
	var paths: Array = []
	for x in [-.57, 0.0, .57]:
		paths.append(_rounded_outline(Vector3(x, .538, .075), .543, .625, .063))
	# Welt follows the outward front rim of the back cushion.
	paths.append(_rounded_outline(Vector3(0, .742, -.246), 1.79, .56, .072, true))
	var color := Color(.19, .108, .065) if leather else Color(.28, .19, .12)
	_detail(mesh, "Sofa sewn cushion welts", _tubes(paths, .0034), _finish(color))

static func _cushion_seams(mesh: MeshInstance3D) -> void:
	var path := _rounded_outline(Vector3(0, 0, .072), .525, .417, .065, true)
	_detail(mesh, "Linen pillow seam", _tubes([path], .0027), _finish(Color(.48, .40, .29)))

static func _table_lip(mesh: MeshInstance3D) -> void:
	var paths := [_rounded_outline(Vector3(0, .782, 0), 1.616, 1.286, .019)]
	var bronze := _finish(Color(.31, .23, .13), .35)
	bronze.metallic = .5
	_detail(mesh, "Stone edge lower bead", _tubes(paths, .0026), bronze)

static func _fixture_diffusers(room: Node3D, manifest: Dictionary) -> void:
	var fixture_root := Node3D.new()
	fixture_root.name = "Ceiling fixture details"
	room.add_child(fixture_root)
	for fixture: Dictionary in manifest.get("fixtures", []):
		var values: Array = fixture.location
		var location := Vector3(values[0], values[1], values[2])
		var diffuser := PlaneMesh.new()
		diffuser.size = Vector2(.51, .35) if str(fixture.id) == "ceiling-center" else Vector2(.33, .24)
		var mat := _finish(Color(.86, .84, .74), .74)
		mat.emission_enabled = true
		mat.emission = Color(1, .90, .72)
		mat.emission_energy_multiplier = .78
		var panel := _detail(fixture_root, str(fixture.id) + " frosted diffuser", diffuser, mat)
		panel.position = location + Vector3(0, -.005, 0)
		panel.rotation.x = PI
		panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var frame := _rounded_outline(location + Vector3(0, -.007, 0), diffuser.size.x + .025, diffuser.size.y + .025, .009)
		_detail(fixture_root, str(fixture.id) + " brushed fixture trim", _tubes([frame], .006), _finish(Color(.39, .39, .36), .48))

static func _hard_surface_parts(mesh: MeshInstance3D) -> void:
	for i in mesh.mesh.get_surface_count():
		var source := mesh.get_active_material(i)
		if source != null and source.resource_name.begins_with("Gray crib fabric"):
			var silver := _finish(Color(.30, .33, .35), .34)
			silver.metallic = .46
			silver.metallic_specular = .48
			mesh.set_surface_override_material(i, silver)

static func _screen_glass(mesh: MeshInstance3D, television: bool) -> void:
	var surface := QuadMesh.new()
	surface.size = Vector2(1.43, .804) if television else Vector2(.578, .318)
	var mat := _finish(Color(.80, .86, .89), .36)
	mat.albedo_texture = load("res://assets/surfaces/screen_color.jpg")
	mat.metallic = 0.0
	mat.metallic_specular = .16
	var screen := _detail(mesh, "Screen glass surface", surface, mat)
	screen.position = Vector3(0, 0, .047) if television else Vector3(0, .25, .019)

static func _frame_inlay(mesh: MeshInstance3D) -> void:
	var path := _rounded_outline(Vector3(0, 0, .019), .255, .325, .004, true)
	var inlay := _finish(Color(.43, .30, .17), .42)
	inlay.metallic = .35
	_detail(mesh, "Frame recessed brass inlay", _tubes([path], .0018), inlay)

static func _bin_stitches(mesh: MeshInstance3D) -> void:
	var paths: Array = [_rounded_outline(Vector3(0, .198, 0), .355, .285, .013)]
	for x in [-.17, .17]:
		paths.append(PackedVector3Array([Vector3(x, .035, .151), Vector3(x, .18, .151)]))
	_detail(mesh, "Canvas basket stitched rim", _tubes(paths, .0021), _finish(Color(.23, .26, .27)))

static func _keyboard(mesh: MeshInstance3D) -> void:
	# One joined key mesh keeps this detail to a single draw call.
	var keys := SurfaceTool.new()
	keys.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 4:
		for col in 13:
			_append_box(keys, Vector3(-.194 + col * .030, .012, -.050 + row * .030), Vector3(.025, .005, .022))
	_append_box(keys, Vector3(0, .012, .056), Vector3(.16, .005, .015))
	keys.generate_normals()
	_detail(mesh, "Keyboard individual keycaps", keys.commit(), _finish(Color(.078, .087, .095), .62))

static func _append_box(builder: SurfaceTool, center: Vector3, size: Vector3) -> void:
	var vertices: Array[Vector3] = []
	for i in 8:
		vertices.append(center + Vector3(1 if i & 1 else -1, 1 if i & 2 else -1, 1 if i & 4 else -1) * size * .5)
	for i in [0, 2, 3, 0, 3, 1, 4, 5, 7, 4, 7, 6, 0, 4, 6, 0, 6, 2, 1, 3, 7, 1, 7, 5, 2, 6, 7, 2, 7, 3, 0, 1, 5, 0, 5, 4]:
		builder.add_vertex(vertices[i])

static func _tower_vents(mesh: MeshInstance3D) -> void:
	var paths: Array = []
	for i in 14:
		paths.append(PackedVector3Array([Vector3(-.060, .12 + i * .011, .197), Vector3(.060, .12 + i * .011, .197)]))
	_detail(mesh, "Computer front vent slots", _tubes(paths, .0014, 4), _finish(Color(.12, .14, .15), .58))

static func _plant(mesh: MeshInstance3D) -> void:
	# Replace the capsule-like imported foliage with folded, tapered leaves.
	for i in mesh.mesh.get_surface_count():
		var source := mesh.get_active_material(i)
		if source != null and source.resource_name.begins_with("Plant foliage"):
			var hidden := StandardMaterial3D.new()
			hidden.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			hidden.albedo_color = Color(0, 0, 0, 0)
			mesh.set_surface_override_material(i, hidden)
	if _leaf_mesh == null:
		_leaf_mesh = _leaves()
	var leaves := StandardMaterial3D.new()
	leaves.albedo_texture = load("res://assets/surfaces/leaf_color.jpg")
	leaves.normal_enabled = true
	leaves.normal_texture = load("res://assets/surfaces/leaf_normal.png")
	leaves.normal_scale = .58
	leaves.roughness_texture = load("res://assets/surfaces/leaf_roughness.jpg")
	leaves.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	leaves.cull_mode = BaseMaterial3D.CULL_DISABLED
	leaves.metallic_specular = .20
	_detail(mesh, "Plant folded leaves", _leaf_mesh, leaves)
	var stem_paths: Array = []
	for i in 12:
		var angle := i * 2.399
		var h := .25 + (i % 4) * .05
		var p := Vector3(.075 * cos(angle), h - .026, .075 * sin(angle))
		stem_paths.append(PackedVector3Array([Vector3(0, .158, 0), p * Vector3(.4, .8, .4) + Vector3(0, .038, 0), p]))
	var lip := PackedVector3Array()
	for i in 33:
		lip.append(Vector3(cos(i * TAU / 32) * .099, .159, sin(i * TAU / 32) * .099))
	stem_paths.append(lip)
	_detail(mesh, "Plant stems and pot rim", _tubes(stem_paths, .0026), _finish(Color(.19, .29, .12)))

static func _leaves() -> ArrayMesh:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for leaf in 12:
		var angle := leaf * 2.399
		var h := .25 + (leaf % 4) * .05
		var origin := Vector3(.075 * cos(angle), h - .026, .075 * sin(angle))
		var forward := Vector3(cos(angle), .65 if leaf % 3 == 0 else .26, sin(angle)).normalized()
		var across := Vector3(-sin(angle), 0, cos(angle))
		var length := .10 + (leaf % 3) * .014
		for segment in 8:
			for side in 2:
				var ring: Array[Vector3] = []
				var uv: Array[Vector2] = []
				for k in 4:
					var t := float(segment + (1 if k in [2, 3] else 0)) / 8.0
					var edge := float(side + (1 if k in [1, 2] else 0)) - 1.0
					var width := sin(PI * t) * .029
					var p := origin + forward * t * length + across * width * edge
					p.y += sin(PI * t) * .008 * (1 - absf(edge)) - t * t * .018
					ring.append(p)
					uv.append(Vector2(edge * .5 + .5, t))
				for index in [0, 1, 2, 0, 2, 3]:
					builder.set_uv(uv[index])
					builder.add_vertex(ring[index])
	builder.generate_normals()
	builder.generate_tangents()
	return builder.commit()
