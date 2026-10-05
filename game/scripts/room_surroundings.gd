class_name InteriorRoomSurroundings
extends Node3D
## The owner's three other room sides. All static details batch by material;
## dimensions and collision geometry use metres in the existing room space.

const ObjectScript = preload("res://scripts/physics_object.gd")
const DoorScript = preload("res://scripts/hinged_door.gd")
## Hinge of the (mirrored) navy entry door: the leaf spans x 1.39..2.43 and its
## inner face sits at z 2.6335. It swings inward (toward -Z), away from the cabinet.
const ENTRY_HINGE := Vector3(2.43, 0, 2.6335)
const DOOR_PREFIX := "door|"
const TOY_BALL := Vector3(-1.05, .112, 1.05)
const TOY_TENNIS := Vector3(-.62, .036, 1.28)
const REPLACED_COLLIDERS := ["Left wall", "Right wall", "Rear wall", "Ceiling"]
var _batches: Dictionary = {}
var _materials: Dictionary = {}
var _shell: StaticBody3D
var _room: Node3D
var _door_prefix := ""
var _stats := {"triangles_removed":0, "triangles_added":0, "static_batches":0, "colliders":0, "dynamic_props":0, "family_photos":0, "features":[], "kitchen_bounds":[-5.65,-3.3,-2.7,2.7], "kitchen_entrance":[-3.3,0,1.95], "door_triangles":0}

static func apply(room: Node3D, visual: Node3D, _manifest: Dictionary) -> Dictionary:
	if room.has_meta("reference_room_stats"):
		return room.get_meta("reference_room_stats")
	var builder := InteriorRoomSurroundings.new()
	builder.name = "ReferenceRoomSurroundings"
	builder._room = room
	room.add_child(builder)
	builder.add_to_group("room_surroundings")
	builder._strip_old_shell(visual)
	# Declutter: remove the imported meshes of actors dropped from the manifest.
	for node_name in _manifest.get("declutter", []):
		var node := visual.find_child(str(node_name), true, false)
		if node == null:
			node = visual.find_child(str(node_name).replace(" ", "_"), true, false)
		if node != null:
			node.get_parent().remove_child(node)
			node.free()
			builder._stats.features.append("Removed clutter: " + str(node_name))
	builder._build()
	room.set_meta("reference_room_stats", builder._stats)
	print("INTERIOR_REFERENCE_ROOM ", JSON.stringify(builder._stats))
	return builder._stats

func _strip_old_shell(visual: Node3D) -> void:
	var architecture := visual.find_child("Room architecture", true, false) as MeshInstance3D
	if architecture == null:
		architecture = visual.find_child("Room_architecture", true, false) as MeshInstance3D
	if architecture == null:
		push_error("Reference surroundings: combined room architecture was not found")
		return
	var replacement := ArrayMesh.new()
	for surface in architecture.mesh.get_surface_count():
		var arrays := architecture.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			indices.resize(vertices.size())
			for i in vertices.size(): indices[i] = i
		var output := SurfaceTool.new()
		output.begin(Mesh.PRIMITIVE_TRIANGLES)
		var count := 0
		for index in range(0,indices.size(),3):
			var triangle := [indices[index], indices[index+1], indices[index+2]]
			var minimum := Vector3(INF,INF,INF)
			var maximum := Vector3(-INF,-INF,-INF)
			for vertex in triangle:
				var p := architecture.global_transform * vertices[vertex]
				minimum = minimum.min(p)
				maximum = maximum.max(p)
			# Whole wall triangles sit at the four old shell planes. Keeping
			# floor triangles (and the complete TV face) preserves its baked UVs.
			var remove := minimum.x > 3.285 or maximum.x < -3.285 or minimum.z > 2.685 or minimum.y > 2.884
			if remove:
				_stats.triangles_removed += 1
				continue
			for vertex in triangle:
				if normals.size() == vertices.size(): output.set_normal(normals[vertex])
				if uvs.size() == vertices.size(): output.set_uv(uvs[vertex])
				if colors.size() == vertices.size(): output.set_color(colors[vertex])
				output.add_vertex(vertices[vertex])
			count += 3
		if count > 0:
			output.set_material(architecture.get_active_material(surface))
			output.commit(replacement)
	architecture.mesh = replacement

func _build() -> void:
	_shell = StaticBody3D.new()
	_shell.name = "ReferenceRoomStructure"
	_shell.collision_layer = 2
	_shell.collision_mask = 5
	_shell.physics_material_override = PhysicsMaterial.new()
	_shell.physics_material_override.friction = .73
	add_child(_shell)
	_prepare_materials()
	_build_shell()
	_build_kitchen()
	_build_rear_mirrored()
	_build_right()
	var door_leaf := _build_entry_door()
	for key: String in _batches:
		var tool := _batches[key] as SurfaceTool
		if key.begins_with(DOOR_PREFIX):
			# The entry door leaf is its own hinged body, not part of the static batches.
			var material_key := key.trim_prefix(DOOR_PREFIX)
			var leaf_mesh := tool.commit()
			var triangles := leaf_mesh.surface_get_array_len(0) / 3
			_stats.triangles_added -= triangles
			_stats.door_triangles += triangles
			tool.clear()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tool.append_from(leaf_mesh, 0, Transform3D(Basis.IDENTITY, -ENTRY_HINGE))
			tool.index()
			tool.generate_tangents()
			var leaf := MeshInstance3D.new()
			leaf.name = "Door leaf - " + material_key
			leaf.mesh = tool.commit()
			leaf.material_override = _materials[material_key]
			door_leaf.add_child(leaf)
			continue
		tool.index()
		tool.generate_tangents()
		var mesh := MeshInstance3D.new()
		mesh.name = "Room detail - " + key
		mesh.mesh = tool.commit()
		mesh.material_override = _materials[key]
		add_child(mesh)
		_stats.static_batches += 1
	_batches.clear()

## Hinged navy entry door: pivot node at the hinge, AnimatableBody3D leaf beneath it.
func _build_entry_door() -> AnimatableBody3D:
	_feature("Hinged navy entry door to the balcony")
	var door := DoorScript.new() as InteriorHingedDoor
	door.name = "EntryDoor"
	door.position = ENTRY_HINGE
	add_child(door)
	var leaf := AnimatableBody3D.new()
	leaf.name = "DoorLeaf"
	leaf.collision_layer = 2
	leaf.collision_mask = 5
	leaf.sync_to_physics = true
	leaf.physics_material_override = PhysicsMaterial.new()
	leaf.physics_material_override.friction = .6
	door.add_child(leaf)
	var collision := CollisionShape3D.new()
	collision.name = "LeafCollider"
	var shape := BoxShape3D.new()
	# Slab plus the inner raised panels (z 2.597..2.689), hinge edge at local x=0.
	shape.size = Vector3(1.04, 2.28, .092)
	shape.margin = .002
	collision.shape = shape
	collision.position = Vector3(-.52, 1.14, .0095)
	leaf.add_child(collision)
	return leaf

func _build_rear_mirrored() -> void:
	# Looking toward +Z reverses screen-left and world-X. Keep the owner's
	# entry at screen-left and studio at screen-right without moving either
	# side wall or the original furniture. Rejoin the reflected geometry into
	# the same material batches, preserving the mobile draw-call count.
	var saved_batches := _batches
	_batches = {}
	var first_collider := _shell.get_child_count()
	_build_rear()
	var rear_batches := _batches
	_batches = saved_batches
	for key: String in rear_batches:
		var source := (rear_batches[key] as SurfaceTool).commit()
		var arrays := source.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		for i in vertices.size():
			vertices[i].x = -vertices[i].x
			normals[i].x = -normals[i].x
			# Geometric reflection must never mirror the supplied family photo.
			if key.begins_with("family "):
				uv[i].x = 1.0-uv[i].x
		# Keep every batch unindexed until the final _build() index() call.
		# SurfaceTool.append_from(indexed_mesh) would switch the destination
		# to indexed mode and discard pre-existing kitchen vertices and later
		# right-wall vertices that share this material but have no indices.
		var destination := _builder(key)
		for i in range(0,vertices.size(),3):
			for vertex in [i,i+2,i+1]:
				destination.set_normal(normals[vertex])
				destination.set_uv(uv[vertex])
				destination.add_vertex(vertices[vertex])
	var reflection := Basis.from_scale(Vector3(-1,1,1))
	for i in range(first_collider,_shell.get_child_count()):
		var collider := _shell.get_child(i) as CollisionShape3D
		# Symmetric box shapes permit a positive-determinant basis after the
		# reflection. This avoids unsupported negative collision-shape scaling.
		collider.transform = Transform3D(reflection*collider.basis*reflection,reflection*collider.position)

func _prepare_materials() -> void:
	_material("plaster", Color(.88,.87,.81), .91, "surfaces/plaster")
	_material("floor", Color.WHITE, .4)
	_material("slat", Color.WHITE, .66, "reference_room/pale_slat")
	_material("navy", Color.WHITE, .44, "reference_room/navy_enamel")
	_material("blue ceiling", Color.WHITE, .73, "reference_room/blue_ceiling")
	_material("dark recess", Color(.032,.037,.039), .92)
	_material("ivory", Color(.78,.78,.71), .51)
	_material("tile white", Color(.88,.86,.77), .38, "surfaces/marble")
	_material("steel", Color(.42,.47,.48), .31)
	_material("black steel", Color(.054,.064,.07), .43)
	_material("oak", Color.WHITE, .58, "surfaces/oak")
	_material("darkwood", Color.WHITE, .46, "surfaces/darkwood")
	_material("brass", Color(.57,.41,.21), .29)
	_material("glass", Color(.54,.66,.68,.15), .18)
	_material("mirror", Color(.29,.38,.43), .12)
	_material("blue plastic", Color(.24,.47,.65), .48)
	_material("pink plastic", Color(.72,.46,.52), .61)
	_material("green plastic", Color(.30,.44,.21), .57)
	_material("red enamel", Color(.43,.08,.075), .4)
	_material("cream basket", Color(.67,.59,.42), .6)
	_material("blue cloth", Color(.21,.36,.46), .96, "surfaces/linen")
	_material("pink cloth", Color(.65,.40,.43), .96, "surfaces/linen")
	_material("leaf curtain", Color.WHITE,.93,"reference_room/leaf_curtain")
	_material("curtain blue",Color(.24,.37,.48),.62,"surfaces/linen")
	_material("foam red",Color(.30,.095,.087),.98)
	_material("white key",Color(.89,.87,.76),.44)
	_material("brown rug",Color(.31,.24,.18),.99,"surfaces/rug")
	_material("label paper",Color(.83,.82,.71),.89)
	_material("ceramic", Color.WHITE, .2)
	_material("bottle glass", Color.WHITE, .1)
	# Shared library finishes (contract section 5) replace the flat reference colours.
	for pair: Array in [["plaster","warm_plaster"],["navy","navy_enamel"],["blue ceiling","ceiling_white"],
			["ivory","white_satin"],["tile white","quartz_counter"],["floor","marble_floor"],["steel","brushed_steel"],
			["black steel","black_metal"],["oak","oak"],["darkwood","walnut"],["brass","brass"],["glass","glass_clear"],
			["mirror","mirror"],["curtain blue","linen_white"],["leaf curtain","sheer_curtain"],["foam red","walnut"],
			["ceramic","ceramic_white"],["bottle glass","glass_frosted"],["blue plastic","black_metal"],["cream basket","grout"]]:
		_materials[pair[0]] = InteriorMaterials.material(pair[1])
	_materials["blue cloth"].albedo_color = Color(.28,.43,.55)
	_materials["pink cloth"].albedo_color = Color(.75,.48,.56)
	var magnets := _material("alphabet magnets",Color.WHITE,.6)
	magnets.albedo_texture = load("res://assets/reference_room/fridge_magnets.png")
	magnets.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	magnets.alpha_scissor_threshold = .3
	magnets.uv1_triplanar = false
	for i in 8:
		var photo := _material("family %d" % i,Color.WHITE,.82)
		photo.albedo_texture = load("res://assets/family/family_%d.jpg" % i)
		photo.uv1_triplanar = false
		photo.metallic_specular = .12

func _material(key: String, color: Color, roughness: float, texture := "") -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = "Reference room / " + key
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic_specular = .28
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if not texture.is_empty():
		mat.albedo_texture = load("res://assets/%s_color.jpg" % texture)
		mat.normal_enabled = true
		mat.normal_texture = load("res://assets/%s_normal.png" % texture)
		mat.normal_scale = .2 if key in ["slat","oak","navy"] else .4
		mat.roughness_texture = load("res://assets/%s_roughness.jpg" % texture)
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		mat.roughness = 1
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3.ONE * (3.0 if "cloth" in key else 1.0)
	_materials[key] = mat
	return mat

func _feature(label: String) -> void:
	_stats.features.append(label)

func _builder(base_key: String) -> SurfaceTool:
	var key := _door_prefix + base_key
	if not _batches.has(key):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		_batches[key] = tool
	return _batches[key]

func _quad(points: Array, normal: Vector3, key: String, uv := Vector2.ONE) -> void:
	var tool := _builder(key)
	var coords := [Vector2(0,uv.y),Vector2(uv.x,uv.y),Vector2(uv.x,0),Vector2.ZERO]
	for i in [0,2,1,0,3,2]:
		tool.set_normal(normal)
		tool.set_uv(coords[i])
		tool.add_vertex(points[i])
	_stats.triangles_added += 2

func _box(label: String, center: Vector3, size: Vector3, key: String, collide := false, basis := Basis.IDENTITY) -> void:
	var p: Array[Vector3] = []
	for i in 8:
		p.append(center + basis * (Vector3(1 if i & 1 else -1,1 if i & 2 else -1,1 if i & 4 else -1) * size * .5))
	for face: Array in [[4,5,7,6,Vector3.BACK,Vector2(size.x,size.y)],[1,0,2,3,Vector3.FORWARD,Vector2(size.x,size.y)],[0,4,6,2,Vector3.LEFT,Vector2(size.z,size.y)],[5,1,3,7,Vector3.RIGHT,Vector2(size.z,size.y)],[6,7,3,2,Vector3.UP,Vector2(size.x,size.z)],[0,1,5,4,Vector3.DOWN,Vector2(size.x,size.z)]]:
		_quad([p[face[0]],p[face[1]],p[face[2]],p[face[3]]],basis * face[4],key,face[5])
	if collide:
		_collider(label,center,size,basis)

func _collider(label: String, center: Vector3, size: Vector3, basis := Basis.IDENTITY) -> void:
	var collision := CollisionShape3D.new()
	collision.name = label.validate_node_name()
	var shape := BoxShape3D.new()
	shape.size = size
	shape.margin = .002
	collision.shape = shape
	_shell.add_child(collision)
	collision.transform = Transform3D(basis,center)
	_stats.colliders += 1

func _rod(a: Vector3, b: Vector3, radius: float, key: String, sides := 8, top_radius := -1.0) -> void:
	if a.distance_squared_to(b) < .000001: return
	var normal := (b-a).normalized()
	var u := normal.cross(Vector3.UP if absf(normal.y) < .95 else Vector3.RIGHT).normalized()
	var v := normal.cross(u)
	var r2 := radius if top_radius < 0 else top_radius
	var tool := _builder(key)
	for i in sides:
		var na := u*cos(TAU*i/sides) + v*sin(TAU*i/sides)
		var nb := u*cos(TAU*(i+1)/sides) + v*sin(TAU*(i+1)/sides)
		var points := [a+na*radius,b+na*r2,b+nb*r2,a+nb*radius]
		for index in [0,1,2,0,2,3]:
			tool.set_normal(na if index in [0,1] else nb)
			tool.set_uv(Vector2(float(i+(1 if index in [2,3] else 0))/sides,0 if index in [0,3] else a.distance_to(b)))
			tool.add_vertex(points[index])
		for ring in [[a,-normal,radius],[b,normal,r2]]:
			var rev := -1 if ring[1] == normal else 1
			var ring_points := [ring[0],ring[0]+na*ring[2],ring[0]+nb*ring[2]]
			for index in ([0,1,2] if rev == 1 else [0,2,1]):
				tool.set_normal(ring[1])
				tool.set_uv(Vector2(.5,.5))
				tool.add_vertex(ring_points[index])
		_stats.triangles_added += 4

func _tube(points: Array, radius: float, key: String, sides := 7) -> void:
	for i in points.size()-1:
		_rod(points[i],points[i+1],radius,key,sides)

func _lathe(center: Vector3, profile: Array, key: String, sides := 20, basis := Basis.IDENTITY) -> void:
	for j in profile.size()-1:
		var a: Vector2 = profile[j]
		var b: Vector2 = profile[j+1]
		for i in sides:
			var angle0 := TAU*i/sides
			var angle1 := TAU*(i+1)/sides
			var mid := (angle0+angle1)*.5
			var n := Vector3(cos(mid)*(b.y-a.y),a.x-b.x,sin(mid)*(b.y-a.y)).normalized()
			var points := [Vector3(cos(angle0)*a.x,a.y,sin(angle0)*a.x),Vector3(cos(angle0)*b.x,b.y,sin(angle0)*b.x),Vector3(cos(angle1)*b.x,b.y,sin(angle1)*b.x),Vector3(cos(angle1)*a.x,a.y,sin(angle1)*a.x)]
			for k in 4: points[k] = center+basis*points[k]
			_quad(points,basis*n,key)

func _sphere(center: Vector3, size: Vector3, key: String, segments := 12) -> void:
	var profile: Array = []
	for j in 9:
		var a := -PI*.5 + PI*j/8
		profile.append(Vector2(cos(a)*.5,sin(a)*.5))
	_lathe(center,profile,key,segments,Basis.from_scale(size))

func _frame(center: Vector3, width: float, height: float, photo: int, facing: Basis) -> void:
	for x in [-1,1]: _box("Photo frame upright",center+facing*Vector3(x*(width+.028)*.5,0,0),Vector3(.028,height+.07,.026),"darkwood",false,facing)
	for y in [-1,1]: _box("Photo frame rail",center+facing*Vector3(0,y*(height+.027)*.5,0),Vector3(width,.027,.026),"darkwood",false,facing)
	var z := .004
	_quad([center+facing*Vector3(-width*.5,-height*.5,z),center+facing*Vector3(width*.5,-height*.5,z),center+facing*Vector3(width*.5,height*.5,z),center+facing*Vector3(-width*.5,height*.5,z)],facing*Vector3.BACK,"family %d"%photo)
	_stats.family_photos += 1

func _build_shell() -> void:
	_feature("Walkable left kitchen extension")
	_box("Kitchen floor",Vector3(-4.5,-.1,0),Vector3(2.4,.20,5.6),"floor",true)
	_box("Kitchen far wall",Vector3(-5.75,1.45,0),Vector3(.2,2.9,5.6),"plaster",true)
	_box("Kitchen front wall",Vector3(-4.5,1.45,-2.8),Vector3(2.5,2.9,.2),"plaster",true)
	_box("Kitchen rear wall",Vector3(-4.5,1.45,2.8),Vector3(2.5,2.9,.2),"plaster",true)
	# The opening is deliberately full-height below the blue lintel; the sofa
	# leaves the documented rear entrance route at z=1.95 physically clear.
	_box("Kitchen opening lintel",Vector3(-3.36,2.67,0),Vector3(.20,.46,5.4),"blue ceiling",true)
	for z in [-2.58,2.58]:
		_box("Kitchen doorway post",Vector3(-3.36,1.24,z),Vector3(.18,2.48,.20),"blue ceiling",true)
	# The east rear wall now has a real doorway (x 1.39..2.43, up to y 2.32) to the balcony.
	_box("Rear wall east near",Vector3(1.045,1.45,2.8),Vector3(.69,2.9,.2),"dark recess",true)
	_box("Rear wall east far",Vector3(2.865,1.45,2.8),Vector3(.87,2.9,.2),"dark recess",true)
	_box("Rear doorway header",Vector3(1.91,2.61,2.8),Vector3(1.04,.58,.2),"dark recess",true)
	_box("Rear doorway threshold",Vector3(1.91,-.098,2.82),Vector3(1.04,.204,.26),"floor",true)
	# Navy painted reveal lining the wall thickness, like the balcony-side frame.
	for x in [1.40,2.42]: _box("Rear doorway reveal",Vector3(x,1.16,2.8),Vector3(.02,2.32,.2),"navy")
	_box("Rear doorway reveal head",Vector3(1.91,2.31,2.8),Vector3(1.0,.02,.2),"navy")
	_box("Rear wall center",Vector3(-.27,1.45,2.8),Vector3(1.94,2.9,.2),"dark recess",true)
	_box("Rear wall studio header",Vector3(-2.25,2.65,2.8),Vector3(2.1,.5,.2),"plaster",true)
	_box("Right wall gallery",Vector3(3.4,1.45,-1.18),Vector3(.2,2.9,3.04),"dark recess",true)
	_box("Right wall storage",Vector3(3.4,1.45,2.08),Vector3(.2,2.9,1.24),"dark recess",true)
	_box("Right doorway header",Vector3(3.4,2.64,.90),Vector3(.2,.52,1.16),"dark recess",true)
	# The studio doorway (x -3.25..-1.24) opens into scenes/studio/studio.tscn (studio_builder.gd),
	# which owns its floor, walls, ceiling and glass sliding door. A closet keeps the right opening enclosed.
	_box("Closet floor",Vector3(3.79,-.1,.90),Vector3(.98,.2,1.16),"floor",true)
	_box("Closet rear",Vector3(4.32,1.45,.90),Vector3(.15,2.9,1.16),"plaster",true)
	for z in [.27,1.53]: _box("Closet side",Vector3(3.85,1.45,z),Vector3(1.1,2.9,.14),"plaster",true)
	# Smooth warm-white plastered ceiling (the blue panel grid is gone).
	_box("Room ceiling",Vector3(-1.15,3.01,0),Vector3(9.1,.22,5.6),"blue ceiling",true)
	_box("Closet ceiling",Vector3(3.83,3.0,.90),Vector3(1.10,.2,1.3),"blue ceiling",true)
func _build_kitchen() -> void:
	_feature("Navy louvered kitchen cabinets and tiled L counter")
	# Lower cabinetry follows the far-left wall and turns behind the refrigerator.
	_box("Kitchen base",Vector3(-5.31,.45,-.05),Vector3(.66,.9,4.96),"navy",true)
	_box("Kitchen plinth",Vector3(-5.34,.065,-.05),Vector3(.59,.13,4.97),"dark recess")
	# Countertop is split around the sink aperture, so tossed cups can settle
	# in the inset basin instead of floating over an invisible slab.
	_box("Kitchen countertop outer strip",Vector3(-5.565,.936,-.05),Vector3(.16,.065,5.05),"tile white",true)
	_box("Kitchen countertop front strip",Vector3(-4.925,.936,-.05),Vector3(.14,.065,5.05),"tile white",true)
	_box("Kitchen countertop north",Vector3(-5.24,.936,-1.445),Vector3(.49,.065,2.26),"tile white",true)
	_box("Kitchen countertop south",Vector3(-5.24,.936,1.395),Vector3(.49,.065,2.16),"tile white",true)
	_box("Kitchen L base",Vector3(-4.38,.45,-2.31),Vector3(1.20,.9,.64),"navy",true)
	_box("Kitchen L counter",Vector3(-4.36,.936,-2.28),Vector3(1.25,.065,.73),"tile white",true)
	for bay in 8:
		var z := -2.20+bay*.60
		_box("Cabinet recessed front",Vector3(-4.972,.48,z),Vector3(.024,.71,.52),"dark recess")
		for side in [-1,1]: _box("Cabinet door stile",Vector3(-4.946,.48,z+side*.252),Vector3(.042,.74,.046),"navy")
		for y in [.14,.82]: _box("Cabinet door rail",Vector3(-4.941,y,z),Vector3(.045,.06,.55),"navy")
		for slat in 9: _box("Cabinet louver",Vector3(-4.944,.22+slat*.06,z),Vector3(.047,.038,.47),"navy",false,Basis(Vector3.FORWARD,.12))
		_rod(Vector3(-4.902,.63,z+.20),Vector3(-4.902,.69,z+.20),.008,"steel")
	for ix in 8:
		for iz in 2:
			_box("Counter edge checker tile",Vector3(-4.843,.905,-2.35+ix*.60+iz*.30),Vector3(.013,.17,.292),"navy")
	# Blue and cream backsplash, individually grouted and clearly above the worktop.
	for row in 3:
		for col in 16:
			_box("Backsplash checker tile",Vector3(-5.633,1.075+row*.285,-2.39+col*.30),Vector3(.018,.278,.291),"navy" if row == 0 else "tile white")
	_feature("Kitchen barred window with blue valance")
	_box("Kitchen window recess",Vector3(-5.635,2.12,-.10),Vector3(.025,1.30,4.56),"dark recess")
	var glassmat := _material("sunlit window",Color(.86,.9,.96),.7)
	glassmat.emission_enabled = true
	glassmat.emission = Color(.82,.89,1.0)
	glassmat.emission_energy_multiplier = 1.6
	_box("Kitchen window daylight",Vector3(-5.606,2.12,-.10),Vector3(.018,1.20,4.43),"sunlit window")
	for z in [-2.37,2.17]: _box("Window frame upright",Vector3(-5.56,2.12,z),Vector3(.085,1.34,.042),"black steel")
	for y in [1.48,2.10,2.76]: _box("Window frame horizontal",Vector3(-5.558,y,-.1),Vector3(.088,.032,4.60),"black steel")
	for i in 15: _rod(Vector3(-5.53,1.48,-2.20+i*.29),Vector3(-5.53,2.76,-2.20+i*.29),.009,"black steel",6)
	_curtain(Vector3(-5.45,2.24,-2.39),4.58,.50,"curtain blue",true)
	_rod(Vector3(-5.40,2.80,-2.43),Vector3(-5.40,2.80,2.21),.016,"steel")
	# Shallow inset basin and the curved black mixer tap.
	_feature("Sink dish rack cookware and everyday counter items")
	_box("Sink dark basin",Vector3(-5.24,.904,.01),Vector3(.49,.010,.63),"dark recess")
	for z in [-.31,.31]: _box("Sink metal rim",Vector3(-5.24,.983,z),Vector3(.52,.019,.019),"steel")
	for x in [-5.49,-4.99]: _box("Sink metal rim",Vector3(x,.983,0),Vector3(.021,.019,.62),"steel")
	_box("Sink basin bottom",Vector3(-5.24,.912,0),Vector3(.47,.009,.60),"steel",true)
	for z in [-.304,.304]: _box("Sink basin end",Vector3(-5.24,.940,z),Vector3(.48,.056,.012),"steel",true)
	for x in [-5.479,-5.001]: _box("Sink basin side",Vector3(x,.940,0),Vector3(.012,.056,.61),"steel",true)
	_rod(Vector3(-5.24,.917,0),Vector3(-5.24,.919,0),.027,"dark recess",16)
	_tube([Vector3(-5.47,.99,.34),Vector3(-5.47,1.22,.34),Vector3(-5.42,1.28,.28),Vector3(-5.29,1.28,.24),Vector3(-5.22,1.21,.21)],.022,"black steel",10)
	_rod(Vector3(-5.47,1.03,.39),Vector3(-5.36,1.09,.39),.014,"black steel")
	# Glass-front dish cupboard at the right of the sink.
	_box("Counter cupboard body",Vector3(-5.29,1.43,-1.17),Vector3(.56,.94,.73),"ivory",true)
	_box("Counter cupboard dark recess",Vector3(-4.992,1.60,-1.17),Vector3(.022,.53,.64),"dark recess")
	for z in [-1.50,-1.17,-.84]: _box("Glass cupboard stile",Vector3(-4.961,1.59,z),Vector3(.029,.58,.021),"ivory")
	for y in [1.32,1.88]: _box("Glass cupboard rail",Vector3(-4.958,y,-1.17),Vector3(.030,.023,.69),"ivory")
	for z in [-1.34,-1.00]: _box("Cupboard glazed door",Vector3(-4.952,1.60,z),Vector3(.01,.51,.30),"glass")
	for y in [1.08,1.20]:
		_box("Cupboard drawer",Vector3(-4.976,y,-1.17),Vector3(.03,.10,.66),"ivory")
		_box("Cupboard drawer pull",Vector3(-4.941,y,-1.17),Vector3(.025,.015,.15),"steel")
	_box("Cooker stove",Vector3(-4.46,1.00,-2.25),Vector3(.60,.075,.47),"blue plastic",true)
	_rod(Vector3(-4.46,1.041,-2.25),Vector3(-4.46,1.055,-2.25),.20,"black steel",24)
	_lathe(Vector3(-4.46,1.06,-2.25),[Vector2(.11,0),Vector2(.14,.015),Vector2(.24,.14),Vector2(.245,.15),Vector2(.225,.145),Vector2(.125,.035)],"black steel",28)
	_rod(Vector3(-4.26,1.16,-2.25),Vector3(-4.02,1.20,-2.25),.019,"black steel",10)
	# Fridge near the enclosure, with full family snapshots and magnetic letters.
	_feature("Dark refrigerator with clean doors")
	_box("Refrigerator",Vector3(-3.89,.96,-2.18),Vector3(.66,1.91,.70),"black steel",true)
	_box("Fridge freezer door",Vector3(-3.89,1.56,-1.816),Vector3(.64,.65,.035),"black steel")
	_box("Fridge lower door",Vector3(-3.89,.65,-1.815),Vector3(.64,1.13,.04),"black steel")
	for y in [1.21,1.30]: _box("Fridge silver handle",Vector3(-4.05,y,-1.776),Vector3(.25,.020,.022),"steel")
	# Styled, reachable rigid bodies: three cups, a wooden bowl of oranges, two bottles.
	for i in 3:
		_loose_kitchen_prop("Kitchen cup %d"%(i+1),Vector3(-5.10,1.0135,.60+i*.15),.20,Vector3(.08,.09,.08),"ceramic",true)
	_build_toys()

func _counter_bottle(p: Vector3, variant: int) -> void:
	var key: String = ["green plastic","ivory","pink plastic"][variant]
	_lathe(p,[Vector2(.025,0),Vector2(.038,.02),Vector2(.036,.16),Vector2(.02,.19),Vector2(.018,.23)],key,12)
	_rod(p+Vector3(0,.225,0),p+Vector3(0,.245,0),.02,"black steel")
	_box("Bottle paper label",p+Vector3(.037,.10,0),Vector3(.006,.075,.041),"label paper")

func _loose_kitchen_prop(label: String, p: Vector3, mass: float, size: Vector3, key: String, cup: bool) -> void:
	var body := ObjectScript.new() as InteriorObject
	body.name = label.validate_node_name()
	body.display_name = label
	body.mass = mass
	body.position = p
	body.set_meta("reference_room_prop",true)
	body.add_to_group("room_surroundings")
	_room.add_child(body)
	var mesh := MeshInstance3D.new()
	if cup:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = size.x*.5
		cylinder.bottom_radius = size.x*.43
		cylinder.height = size.y
		cylinder.radial_segments = 20
		mesh.mesh = cylinder
		var handle := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = .017
		torus.outer_radius = .023
		torus.rings = 12
		torus.ring_segments = 6
		handle.mesh = torus
		handle.material_override = _materials[key]
		handle.position.x = size.x*.47
		handle.rotation.x = PI*.5
		body.add_child(handle)
	else:
		var box := BoxMesh.new()
		box.size = size
		mesh.mesh = box
	mesh.material_override = _materials[key]
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var boxshape := BoxShape3D.new()
	boxshape.size = size
	boxshape.margin = .001
	shape.shape = boxshape
	body.add_child(shape)
	body.home_transform = body.global_transform
	body.dormant = true
	body.freeze = true
	body.sleeping = true
	_stats.dynamic_props += 1

func _build_rear() -> void:
	_feature("Rear navy paneled entrance and vertical pale slats")
	# Pale vertical wood strips sit proud of the black recess, like the photo.
	for i in 77:
		var x := -3.29+i*.059
		if x < -2.43 or x > -1.38:
			_box("Rear wall pale slat",Vector3(x,1.45,2.677),Vector3(.034,2.9,.041),"slat")
	# Everything on the door leaf goes to separate batches that become the hinged body.
	_door_prefix = DOOR_PREFIX
	_box("Navy entry door",Vector3(-1.91,1.14,2.661),Vector3(1.04,2.28,.055),"navy")
	_door_prefix = ""
	for x in [-2.46,-1.36]: _box("Door timber jamb",Vector3(x,1.18,2.637),Vector3(.055,2.36,.07),"slat")
	_box("Door timber lintel",Vector3(-1.91,2.355,2.637),Vector3(1.16,.065,.07),"slat")
	_door_prefix = DOOR_PREFIX
	for row in 3:
		for col in 2:
			var p := Vector3(-2.155+col*.49,.42+row*.69,2.623)
			_box("Recessed door panel",p,Vector3(.38,.51,.018),"dark recess")
			_box("Door raised panel",p+Vector3(0,0,-.006),Vector3(.326,.453,.017),"navy")
			for side in [-1,1]:
				_box("Door panel molding",p+Vector3(side*.186,0,-.017),Vector3(.018,.515,.019),"navy")
				_box("Door panel molding",p+Vector3(0,side*.249,-.017),Vector3(.384,.018,.019),"navy")
	_sphere(Vector3(-1.50,1.015,2.582),Vector3(.069,.069,.055),"brass")
	_box("Door latch plate",Vector3(-1.50,1.015,2.61),Vector3(.070,.135,.012),"steel")
	_box("Door latch bolt",Vector3(-1.44,1.38,2.607),Vector3(.15,.041,.02),"steel")
	# Balcony-side knob and rose on the plain outer face.
	_sphere(Vector3(-1.50,1.015,2.716),Vector3(.069,.069,.055),"brass")
	_box("Door outer rose",Vector3(-1.50,1.015,2.692),Vector3(.060,.11,.008),"steel")
	_door_prefix = ""
	_box("Entry light switch",Vector3(-1.21,1.37,2.632),Vector3(.076,.12,.025),"ivory")
	_box("Entry switch rocker",Vector3(-1.21,1.38,2.613),Vector3(.045,.065,.012),"ivory")
	_feature("Tall mirror beside the entrance")
	_box("Rear tall mirror surround",Vector3(-.93,1.27,2.628),Vector3(.40,2.01,.045),"steel")
	_box("Rear tall mirror inset",Vector3(-.93,1.27,2.598),Vector3(.342,1.945,.008),"mirror")
	# Simulated mirror has subtle inset framing, with no fake room-photo plane.
	for x in [-1.10,-.76]: _box("Mirror bevel edge",Vector3(x,1.27,2.584),Vector3(.009,1.94,.008),"ivory")
func _build_right() -> void:
	_feature("Right slatted wall and family-photo gallery")
	for i in 89:
		var z := -2.66+i*.06
		if z < .36 or z > 1.44:
			_box("Right wall pale slat",Vector3(3.275,1.45,z),Vector3(.042,2.9,.036),"slat")
		else: _box("Right wall slat above doorway",Vector3(3.275,2.65,z),Vector3(.042,.50,.036),"slat")
	var facing := Basis(Vector3.UP,-PI*.5)
	# A calm, aligned gallery of five family photos (was eight scattered frames).
	for item: Array in [[-2.05,1.72,.36,.46,4],[-1.55,1.72,.36,.46,3],[-1.05,1.72,.36,.46,6],[-.55,1.72,.36,.46,2],[-1.30,2.30,.60,.40,0]]:
		_frame(Vector3(3.239,item[1],item[0]),item[2],item[3],item[4],facing)
	_feature("Sheer linen curtain doorway and shallow closet")
	for z in [.34,1.46]: _box("Curtain doorway frame",Vector3(3.245,1.18,z),Vector3(.085,2.36,.062),"darkwood")
	_box("Curtain doorway lintel",Vector3(3.245,2.37,.90),Vector3(.085,.060,1.20),"darkwood")
	_curtain(Vector3(3.237,.07,.375),.51,2.23,"leaf curtain",true)
	_curtain(Vector3(3.237,.07,.932),.49,2.23,"leaf curtain",true)
	_box("Closet shelf",Vector3(3.90,1.89,.90),Vector3(.53,.028,.95),"ivory",true)
	_box("Closet back storage",Vector3(4.12,.42,.89),Vector3(.22,.83,.73),"ivory",true)
	_feature("Tall white storage cupboard")
	# Tall white display cupboard with inset doors and translucent shelves.
	_box("Tall storage cabinet",Vector3(3.06,1.02,2.12),Vector3(.44,2.03,.67),"ivory",true)
	_box("Tall cupboard glass opening",Vector3(2.824,1.59,2.12),Vector3(.020,.66,.58),"dark recess")
	_box("Tall cupboard glass",Vector3(2.806,1.59,2.12),Vector3(.011,.61,.53),"glass")
	for y in [.27,.71,1.12]:
		_box("Tall cupboard raised door",Vector3(2.817,y,2.12),Vector3(.026,.37,.58),"ivory")
		for z in [1.862,2.378]: _box("Cupboard molded door edge",Vector3(2.798,y,z),Vector3(.016,.34,.014),"ivory")
		for yp in [-.163,.163]: _box("Cupboard molded door edge",Vector3(2.798,y+yp,2.12),Vector3(.016,.014,.52),"ivory")
		_box("Cupboard door handle",Vector3(2.770,y,1.93),Vector3(.028,.072,.014),"steel")

func _curtain(origin: Vector3, width: float, height: float, key: String, along_z: bool) -> void:
	for i in 72:
		for j in 4:
			var points: Array = []
			for item: Vector2 in [Vector2(i,j),Vector2(i+1,j),Vector2(i+1,j+1),Vector2(i,j+1)]:
				var u := item.x/72
				var v := item.y/4
				var fold := sin(u*TAU*maxf(3,width*8))*.019 + sin(u*TAU*maxf(6,width*16))*.004
				var hem := sin(u*TAU*maxf(3,width*8))*.010*(1-v)
				points.append(origin+Vector3(fold, v*height+hem,u*width) if along_z else origin+Vector3(u*width,v*height+hem,fold))
			var normal := (Vector3.RIGHT if origin.x < 0 else Vector3.LEFT) if along_z else Vector3.BACK
			var tool := _builder(key)
			for k in ([0,2,1,0,3,2] if normal == Vector3.LEFT else [0,1,2,0,2,3]):
				tool.set_normal(normal)
				tool.set_uv(Vector2(float(i+(1 if k in [1,2] else 0))/72,1-float(j+(1 if k in [2,3] else 0))/4))
				tool.add_vertex(points[k])
			_stats.triangles_added += 2

func _rack(p: Vector3, size: Vector3, key: String, shelves: int) -> void:
	for x in [-1,1]:
		for z in [-1,1]: _box("Household shelf upright",p+Vector3(x*(size.x-.035)*.5,size.y*.5,z*(size.z-.035)*.5),Vector3(.025,size.y,.025),key,true)
	for i in shelves:
		_box("Household shelf",p+Vector3(0,.05+i*(size.y-.08)/(shelves-1),0),Vector3(size.x,.024,size.z),key,true)

func _basket(p: Vector3, size: Vector3, key: String) -> void:
	_collider("Laundry basket",p+Vector3(0,size.y*.5,0),size)
	_box("Basket solid base",p+Vector3(0,.024,0),Vector3(size.x*.86,.045,size.z*.86),key)
	for row in 8:
		var t := float(row)/7
		var width := size.x*(.86+t*.14)
		var depth := size.z*(.86+t*.14)
		for z in [-1,1]: _box("Basket perforated horizontal",p+Vector3(0,.05+t*(size.y-.06),z*depth*.5),Vector3(width,.016,.018),key)
		for x in [-1,1]: _box("Basket perforated horizontal",p+Vector3(x*width*.5,.05+t*(size.y-.06),0),Vector3(.018,.016,depth),key)
	for i in 9:
		for z in [-1,1]: _rod(p+Vector3((float(i)/8-.5)*size.x*.86,.035,z*size.z*.43),p+Vector3((float(i)/8-.5)*size.x,size.y,z*size.z*.5),.008,key,5)
		for x in [-1,1]: _rod(p+Vector3(x*size.x*.43,.035,(float(i)/8-.5)*size.z*.86),p+Vector3(x*size.x*.5,size.y,(float(i)/8-.5)*size.z),.008,key,5)

func _flower_mat(p: Vector3, radius: float) -> void:
	# Petal silhouette recreates the brown flower mats without a flat screenshot.
	for i in 6:
		var a := TAU*i/6
		_sphere(p+Vector3(cos(a)*radius*.48,0,sin(a)*radius*.48),Vector3(radius*.88,.014,radius*.88),"brown rug")
	_sphere(p+Vector3(0,.008,0),Vector3(radius*.53,.012,radius*.53),"cream basket")

## Lathe profile (radius, height) as an ArrayMesh for small rigid props.
func _lathe_mesh(profile: Array, sides := 24) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		for j in profile.size() - 1:
			var p0: Vector2 = profile[j]
			var p1: Vector2 = profile[j + 1]
			var quad := [Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x), Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x),
				Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x), Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x)]
			for k in [0, 2, 1, 0, 3, 2]:
				var v: Vector3 = quad[k]
				tool.set_uv(Vector2(float(i + (1 if k in [1, 2] else 0)) / sides, v.y * 4.0))
				tool.add_vertex(v)
	tool.generate_normals()
	tool.generate_tangents()
	return tool.commit()

## A small rigid prop (InteriorObject) with explicit physics hints for the physics builder.
func _toy_body(label: String, p: Vector3, mass: float, mesh: Mesh, key: String, shapes: Array, material_hint: String, rolls: bool) -> InteriorObject:
	var body := ObjectScript.new() as InteriorObject
	body.name = label.validate_node_name()
	body.display_name = label
	body.mass = mass
	body.position = p
	body.set_meta("reference_room_prop", true)
	body.set_meta("styled_prop", true)
	body.set("physics_material", material_hint)
	body.set("rolls", rolls)
	body.add_to_group("room_surroundings", true)
	_room.add_child(body)
	var visual := MeshInstance3D.new()
	visual.name = "Visual"
	visual.mesh = mesh
	visual.material_override = InteriorMaterials.material(key)
	body.add_child(visual)
	for item: Array in shapes:
		var collision := CollisionShape3D.new()
		collision.shape = item[0]
		(item[0] as Shape3D).margin = .001
		collision.transform = item[1]
		body.add_child(collision)
	body.home_transform = body.global_transform
	body.dormant = true
	body.freeze = true
	body.sleeping = true
	_stats.dynamic_props += 1
	return body

func _sphere_toy(label: String, p: Vector3, radius: float, mass: float, key: String, hint: String) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 32
	mesh.rings = 16
	var shape := SphereShape3D.new()
	shape.radius = radius
	_toy_body(label, p, mass, mesh, key, [[shape, Transform3D.IDENTITY]], hint, true)

func _build_toys() -> void:
	_feature("Styled physics toys: balls on the rug, bowl of oranges, bottles")
	# Two balls resting on the rug, inviting play.
	_sphere_toy("Rubber ball", TOY_BALL, .11, .35, "toy_red", "rubber")
	_sphere_toy("Tennis ball", TOY_TENNIS, .0335, .058, "tennis_felt", "rubber")
	# Turned wooden bowl on the kitchen counter with three oranges.
	var top := .969
	var bowl_profile := [Vector2(0, 0), Vector2(.065, 0), Vector2(.10, .025), Vector2(.13, .07), Vector2(.122, .072),
		Vector2(.094, .03), Vector2(.06, .012), Vector2(0, .012)]
	var shapes: Array = []
	var base := CylinderShape3D.new()
	base.radius = .07
	base.height = .012
	shapes.append([base, Transform3D(Basis.IDENTITY, Vector3(0, .006, 0))])
	for i in 8:
		var wall := BoxShape3D.new()
		wall.size = Vector3(.012, .07, .1)
		var a := TAU * i / 8
		var wall_basis := Basis(Vector3.UP, -a) * Basis(Vector3.BACK, .5)
		shapes.append([wall, Transform3D(wall_basis, Vector3(cos(a) * .105, .04, sin(a) * .105))])
	var bowl_pos := Vector3(-5.18, top, 1.55)
	_toy_body("Wooden fruit bowl", bowl_pos, .45, _lathe_mesh(bowl_profile, 32), "walnut", shapes, "wood", false)
	for i in 3:
		var a := TAU * i / 3 + .4
		_sphere_toy("Orange %d" % (i + 1), bowl_pos + Vector3(cos(a) * .045, .053, sin(a) * .045), .04, .15, "orange_peel", "fruit")
	# Frosted glass oil bottle and a sage ceramic vase beside the cupboard.
	var bottle_profile := [Vector2(0, 0), Vector2(.034, 0), Vector2(.036, .006), Vector2(.036, .17), Vector2(.03, .2),
		Vector2(.014, .23), Vector2(.013, .27), Vector2(0, .27)]
	var vase_profile := [Vector2(0, 0), Vector2(.04, 0), Vector2(.05, .05), Vector2(.048, .14), Vector2(.03, .2), Vector2(.032, .22), Vector2(0, .22)]
	for i in 2:
		var cylinder := CylinderShape3D.new()
		cylinder.radius = .036 if i == 0 else .05
		cylinder.height = .27 if i == 0 else .22
		_toy_body("Glass bottle" if i == 0 else "Ceramic vase", Vector3(-5.40, top, -.62 + i * .14), .5 if i == 0 else .7,
			_lathe_mesh(bottle_profile if i == 0 else vase_profile, 24), "glass_frosted" if i == 0 else "ceramic_sage",
			[[cylinder, Transform3D(Basis.IDENTITY, Vector3(0, cylinder.height * .5, 0))]], "glass" if i == 0 else "ceramic", false)
