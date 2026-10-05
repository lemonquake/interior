class_name InteriorRoomSurroundings
extends Node3D
## The owner's three other room sides. All static details batch by material;
## dimensions and collision geometry use metres in the existing room space.

const ObjectScript = preload("res://scripts/physics_object.gd")
const REPLACED_COLLIDERS := ["Left wall", "Right wall", "Rear wall", "Ceiling"]
var _batches: Dictionary = {}
var _materials: Dictionary = {}
var _shell: StaticBody3D
var _room: Node3D
var _stats := {"triangles_removed":0, "triangles_added":0, "static_batches":0, "colliders":0, "dynamic_props":0, "family_photos":0, "features":[], "kitchen_bounds":[-5.65,-3.3,-2.7,2.7], "kitchen_entrance":[-3.3,0,1.95]}

static func apply(room: Node3D, visual: Node3D, _manifest: Dictionary) -> Dictionary:
	if room.has_meta("reference_room_stats"):
		return room.get_meta("reference_room_stats")
	var builder := InteriorRoomSurroundings.new()
	builder.name = "ReferenceRoomSurroundings"
	builder._room = room
	room.add_child(builder)
	builder.add_to_group("room_surroundings")
	builder._strip_old_shell(visual)
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
	for key: String in _batches:
		var tool := _batches[key] as SurfaceTool
		tool.index()
		tool.generate_tangents()
		var mesh := MeshInstance3D.new()
		mesh.name = "Room detail - " + key
		mesh.mesh = tool.commit()
		mesh.material_override = _materials[key]
		add_child(mesh)
		_stats.static_batches += 1
	_batches.clear()

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
	for name: String in ["steel","brass","black steel"]:
		_materials[name].metallic = .65 if name != "black steel" else .34
	_materials["mirror"].metallic = .7
	_materials["glass"].transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materials["glass"].cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials["leaf curtain"].cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials["leaf curtain"].uv1_triplanar = false
	_materials["leaf curtain"].uv1_scale = Vector3(1,2.3,1)
	_materials["blue cloth"].albedo_color = Color(.28,.43,.55)
	_materials["pink cloth"].albedo_color = Color(.75,.48,.56)
	_materials["curtain blue"].albedo_color = Color(.31,.45,.57)
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

func _builder(key: String) -> SurfaceTool:
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
	_box("Kitchen floor",Vector3(-4.5,-.1,0),Vector3(2.4,.20,5.6),"tile white",true)
	_box("Kitchen far wall",Vector3(-5.75,1.45,0),Vector3(.2,2.9,5.6),"plaster",true)
	_box("Kitchen front wall",Vector3(-4.5,1.45,-2.8),Vector3(2.5,2.9,.2),"plaster",true)
	_box("Kitchen rear wall",Vector3(-4.5,1.45,2.8),Vector3(2.5,2.9,.2),"plaster",true)
	# The opening is deliberately full-height below the blue lintel; the sofa
	# leaves the documented rear entrance route at z=1.95 physically clear.
	_box("Kitchen opening lintel",Vector3(-3.36,2.67,0),Vector3(.20,.46,5.4),"blue ceiling",true)
	for z in [-2.58,2.58]:
		_box("Kitchen doorway post",Vector3(-3.36,1.24,z),Vector3(.18,2.48,.20),"blue ceiling",true)
	_box("Rear wall east",Vector3(2.0,1.45,2.8),Vector3(2.6,2.9,.2),"dark recess",true)
	_box("Rear wall center",Vector3(-.27,1.45,2.8),Vector3(1.94,2.9,.2),"dark recess",true)
	_box("Rear wall studio header",Vector3(-2.25,2.65,2.8),Vector3(2.1,.5,.2),"plaster",true)
	_box("Right wall gallery",Vector3(3.4,1.45,-1.18),Vector3(.2,2.9,3.04),"dark recess",true)
	_box("Right wall storage",Vector3(3.4,1.45,2.08),Vector3(.2,2.9,1.24),"dark recess",true)
	_box("Right doorway header",Vector3(3.4,2.64,.90),Vector3(.2,.52,1.16),"dark recess",true)
	# A shallow real instrument alcove and a closet keep every opening enclosed.
	_box("Studio floor",Vector3(-2.26,-.1,3.26),Vector3(2.12,.2,1.15),"tile white",true)
	_box("Studio rear wall",Vector3(-2.26,1.45,3.91),Vector3(2.12,2.9,.18),"dark recess",true)
	for x in [-1.18,-3.4]: _box("Studio side",Vector3(x,1.45,3.3),Vector3(.15,2.9,1.2),"plaster",true)
	_box("Closet floor",Vector3(3.79,-.1,.90),Vector3(.98,.2,1.16),"tile white",true)
	_box("Closet rear",Vector3(4.32,1.45,.90),Vector3(.15,2.9,1.16),"plaster",true)
	for z in [.27,1.53]: _box("Closet side",Vector3(3.85,1.45,z),Vector3(1.1,2.9,.14),"plaster",true)
	# Blue painted fibreboard ceiling, with shallow joints and an off-white patch.
	_box("Room ceiling",Vector3(-1.15,3.01,0),Vector3(9.1,.22,5.6),"blue ceiling",true)
	_box("Studio ceiling",Vector3(-2.25,3.0,3.31),Vector3(2.2,.2,1.26),"blue ceiling",true)
	_box("Closet ceiling",Vector3(3.83,3.0,.90),Vector3(1.10,.2,1.3),"blue ceiling",true)
	for x in range(-5,4):
		_box("Ceiling panel joint",Vector3(x,2.893,0),Vector3(.010,.009,5.4),"dark recess")
	for z in [-1.8,-.6,.6,1.8]:
		_box("Ceiling panel joint",Vector3(-1.15,2.893,z),Vector3(9.1,.009,.009),"dark recess")
	_box("Ceiling pale repair panel",Vector3(-3.83,2.881,.54),Vector3(.91,.014,1.16),"ivory")
	# Fine dark grout makes the extension meet the existing tiled floor.
	for x in range(5):
		_box("Kitchen floor grout",Vector3(-5.62+x*.6,.006,0),Vector3(.004,.002,5.4),"cream basket")
	for z in range(10):
		_box("Kitchen floor grout",Vector3(-4.47,.006,-2.7+z*.6),Vector3(2.32,.002,.004),"cream basket")

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
			_box("Counter edge checker tile",Vector3(-4.843,.905,-2.35+ix*.60+iz*.30),Vector3(.013,.17,.292),"navy" if (ix+iz)%2 == 0 else "tile white")
	# Blue and cream backsplash, individually grouted and clearly above the worktop.
	for row in 3:
		for col in 16:
			_box("Backsplash checker tile",Vector3(-5.633,1.075+row*.285,-2.39+col*.30),Vector3(.018,.278,.291),"navy" if (row+col)%3 == 0 else "tile white")
	_feature("Kitchen barred window with blue valance")
	_box("Kitchen window recess",Vector3(-5.635,2.12,-.10),Vector3(.025,1.30,4.56),"dark recess")
	var glassmat := _material("sunlit window",Color(.67,.71,.51),.7)
	glassmat.emission_enabled = true
	glassmat.emission = Color(.45,.47,.32)
	glassmat.emission_energy_multiplier = .22
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
	# The blue drawer/drying rack is open at the top, with individually slotted plates.
	_box("Blue dish rack drawers",Vector3(-5.19,1.16,1.60),Vector3(.51,.37,.69),"blue plastic",true)
	for y in [1.045,1.17,1.29]:
		_box("Dish rack drawer groove",Vector3(-4.927,y,1.60),Vector3(.012,.009,.64),"dark recess")
		_box("Dish rack drawer handle",Vector3(-4.914,y+.038,1.60),Vector3(.024,.015,.17),"blue plastic")
	for side in [-1,1]: _box("Drying rack tall side",Vector3(-5.18,1.47,1.60+side*.33),Vector3(.52,.26,.025),"blue plastic")
	for i in 8:
		var z := 1.35+i*.065
		_rod(Vector3(-5.18,1.46,z-.009),Vector3(-5.18,1.46,z+.009),.16,"ivory" if i%3 else "black steel",24)
	# Glass-front dish cupboard at the right of the sink.
	_box("Counter cupboard body",Vector3(-5.29,1.43,-1.17),Vector3(.56,.94,.73),"ivory",true)
	_box("Counter cupboard dark recess",Vector3(-4.992,1.60,-1.17),Vector3(.022,.53,.64),"dark recess")
	for z in [-1.50,-1.17,-.84]: _box("Glass cupboard stile",Vector3(-4.961,1.59,z),Vector3(.029,.58,.021),"ivory")
	for y in [1.32,1.88]: _box("Glass cupboard rail",Vector3(-4.958,y,-1.17),Vector3(.030,.023,.69),"ivory")
	for z in [-1.34,-1.00]: _box("Cupboard glazed door",Vector3(-4.952,1.60,z),Vector3(.01,.51,.30),"glass")
	for y in [1.08,1.20]:
		_box("Cupboard drawer",Vector3(-4.976,y,-1.17),Vector3(.03,.10,.66),"ivory")
		_box("Cupboard drawer pull",Vector3(-4.941,y,-1.17),Vector3(.025,.015,.15),"steel")
	for i in 5:
		_lathe(Vector3(-4.979,1.335,-1.43+i*.12),[Vector2(.04,0),Vector2(.037,.115),Vector2(.03,.117)],"ivory",12)
	# Pot, kettle and rice cooker are shaped with curved profiles.
	_lathe(Vector3(-5.25,1.91,-1.33),[Vector2(.10,0),Vector2(.14,.08),Vector2(.13,.18),Vector2(.06,.21)],"steel")
	_lathe(Vector3(-5.27,1.91,-.94),[Vector2(.075,0),Vector2(.11,.035),Vector2(.10,.21),Vector2(.066,.25)],"steel")
	_tube([Vector3(-5.25,1.96,-.85),Vector3(-5.14,1.98,-.81),Vector3(-5.12,2.10,-.85),Vector3(-5.23,2.14,-.87)],.014,"black steel")
	_box("Cooker stove",Vector3(-4.46,1.00,-2.25),Vector3(.60,.075,.47),"blue plastic",true)
	_rod(Vector3(-4.46,1.041,-2.25),Vector3(-4.46,1.055,-2.25),.20,"black steel",24)
	_lathe(Vector3(-4.46,1.06,-2.25),[Vector2(.11,0),Vector2(.14,.015),Vector2(.24,.14),Vector2(.245,.15),Vector2(.225,.145),Vector2(.125,.035)],"black steel",28)
	_rod(Vector3(-4.26,1.16,-2.25),Vector3(-4.02,1.20,-2.25),.019,"black steel",10)
	_lathe(Vector3(-5.06,.975,-2.15),[Vector2(.12,0),Vector2(.145,.06),Vector2(.135,.25),Vector2(.03,.28)],"ivory")
	for i in 4:
		_counter_bottle(Vector3(-5.39,.978,.58+i*.15),i%3)
	for i in 5:
		_rod(Vector3(-5.39,1.04,.65),Vector3(-5.4+sin(i)*.06,1.29,.66+cos(i)*.05),.006,"steel",6)
	# Fridge near the enclosure, with full family snapshots and magnetic letters.
	_feature("Dark refrigerator with family snapshots and alphabet magnets")
	_box("Refrigerator",Vector3(-3.89,.96,-2.18),Vector3(.66,1.91,.70),"black steel",true)
	_box("Fridge freezer door",Vector3(-3.89,1.56,-1.816),Vector3(.64,.65,.035),"black steel")
	_box("Fridge lower door",Vector3(-3.89,.65,-1.815),Vector3(.64,1.13,.04),"black steel")
	for y in [1.21,1.30]: _box("Fridge silver handle",Vector3(-4.05,y,-1.776),Vector3(.25,.020,.022),"steel")
	_frame(Vector3(-4.01,1.62,-1.784),.18,.25,4,Basis.IDENTITY)
	_frame(Vector3(-3.76,1.66,-1.784),.19,.24,0,Basis.IDENTITY)
	_quad([Vector3(-4.18,.13,-1.786),Vector3(-3.61,.13,-1.786),Vector3(-3.61,1.12,-1.786),Vector3(-4.18,1.12,-1.786)],Vector3.BACK,"alphabet magnets")
	for i in 3:
		_lathe(Vector3(-4.07+i*.17,1.92,-2.16),[Vector2(.048,0),Vector2(.048,.18),Vector2(.031,.20)],"green plastic" if i == 0 else "ivory",12)
	# Small open household rack and pastel drawer tower.
	_rack(Vector3(-3.75,0,-.99),Vector3(.53,1.07,.40),"ivory",3)
	for i in 3: _box("Pastel utility drawer",Vector3(-3.75,.19+i*.30,-.99),Vector3(.47,.24,.36),"pink plastic" if i%2 == 0 else "ivory",true)
	for i in 2:
		_flower_mat(Vector3(-4.55,.013,.37+i*.79),.33)
	# Six actual rigid-body objects are reachable from the kitchen floor.
	for i in 3:
		_loose_kitchen_prop("Kitchen cup %d"%(i+1),Vector3(-5.06,1.025,.64+i*.17),.20,Vector3(.08,.09,.08),"ivory",true)
	_loose_kitchen_prop("Kitchen soap bottle",Vector3(-5.02,1.07,.37),.34,Vector3(.065,.18,.065),"green plastic",false)
	_loose_kitchen_prop("Kitchen small storage tub",Vector3(-5.07,1.05,2.13),.40,Vector3(.23,.15,.18),"pink plastic",false)
	_loose_kitchen_prop("Kitchen sponge",Vector3(-5.04,1.001,-.48),.06,Vector3(.10,.037,.066),"cream basket",false)

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
	_box("Navy entry door",Vector3(-1.91,1.14,2.661),Vector3(1.04,2.28,.055),"navy")
	for x in [-2.46,-1.36]: _box("Door timber jamb",Vector3(x,1.18,2.637),Vector3(.055,2.36,.07),"slat")
	_box("Door timber lintel",Vector3(-1.91,2.355,2.637),Vector3(1.16,.065,.07),"slat")
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
	# Blue circular bag, hanging by its red strap, is a distinctive reference cue.
	_rod(Vector3(-1.96,1.62,2.557),Vector3(-1.96,1.62,2.49),.32,"blue plastic",28)
	_tube([Vector3(-2.09,1.84,2.535),Vector3(-1.95,2.17,2.552),Vector3(-1.84,1.85,2.535)],.014,"red enamel")
	_frame(Vector3(-1.96,1.64,2.476),.23,.15,7,Basis(Vector3.UP,PI))
	_box("Entry light switch",Vector3(-1.21,1.37,2.632),Vector3(.076,.12,.025),"ivory")
	_box("Entry switch rocker",Vector3(-1.21,1.38,2.613),Vector3(.045,.065,.012),"ivory")
	_feature("Tall mirror routers and visible cable runs")
	_box("Rear tall mirror surround",Vector3(-.93,1.27,2.628),Vector3(.40,2.01,.045),"steel")
	_box("Rear tall mirror inset",Vector3(-.93,1.27,2.598),Vector3(.342,1.945,.008),"mirror")
	# Simulated mirror has subtle inset framing, with no fake room-photo plane.
	for x in [-1.10,-.76]: _box("Mirror bevel edge",Vector3(x,1.27,2.584),Vector3(.009,1.94,.008),"ivory")
	for i in 3:
		var p := Vector3(-.37+i*.29,2.22-(i%2)*.28,2.585)
		_box("Wall mounted router",p,Vector3(.25,.15,.077),"ivory")
		for j in 12: _box("Router ventilation slit",p+Vector3(-.102+j*.018,0,-.041),Vector3(.006,.085,.006),"dark recess")
		for j in 3: _sphere(p+Vector3(-.063+j*.03,-.049,-.045),Vector3(.008,.008,.004),"green plastic",8)
		for x in [-.10,.10]: _rod(p+Vector3(x,.08,0),p+Vector3(x,.25,0),.004,"ivory",6)
	for i in 8:
		var x := -.58+i*.105
		var pts: Array = []
		for j in 25:
			var t := float(j)/24
			pts.append(Vector3(x+sin(t*TAU+i)*.07,2.34-t*(1.70 if i%3 == 0 else .74),2.54-sin(t*PI)*.035))
		_tube(pts,.0033,"blue plastic" if i%3 else "black steel",5)
	_tube([Vector3(.25,1.62,2.51),Vector3(.63,1.51,2.48),Vector3(1.1,1.26,2.49),Vector3(1.48,1.16,2.91)],.005,"black steel",6)
	_feature("Open studio niche with guitars keyboard and acoustic panels")
	for row in 6:
		for col in 7:
			var p := Vector3(1.38+col*.286,.84+row*.285,3.80)
			_box("Studio acoustic tile",p,Vector3(.269,.267,.073),"foam red" if row > 3 else "black steel")
			for ridge in 4: _box("Acoustic foam ridge",p+Vector3(-.093+ridge*.060,0,-.044),Vector3(.035,.26,.025),"foam red" if row > 3 else "dark recess")
	_guitar(Vector3(2.79,1.29,3.66),true)
	_guitar(Vector3(2.14,1.42,3.66),false)
	_guitar(Vector3(1.59,1.37,3.66),false)
	# Keyboard leans into the opening with separate ivory keys and black accidentals.
	var keyboard_basis := Basis(Vector3.BACK,-.14)*Basis(Vector3.RIGHT,.20)
	var kp := Vector3(2.00,.68,3.26)
	_box("Studio keyboard body",kp,Vector3(.35,1.12,.095),"black steel",true,keyboard_basis)
	for i in 28:
		_box("Studio piano white key",kp+keyboard_basis*Vector3(-.008,-.52+i*.037,-.062),Vector3(.27,.034,.024),"white key",false,keyboard_basis)
		if i%7 not in [2,6]: _box("Studio piano black key",kp+keyboard_basis*Vector3(.065,-.50+i*.037,-.083),Vector3(.13,.018,.020),"dark recess",false,keyboard_basis)
	_box("Studio amp cabinet",Vector3(2.98,.34,3.47),Vector3(.44,.63,.35),"black steel",true)
	for i in 15: _box("Amplifier grille",Vector3(2.98,.35,3.279+i*.0001),Vector3(.38,.017,.009),"steel",false,Basis(Vector3.FORWARD,i*.16))
	_box("Studio cardboard carton",Vector3(1.47,.38,3.24),Vector3(.31,.76,.31),"cream basket",true)
	for z in [3.10,3.38]: _box("Carton taped seam",Vector3(1.47,.762,z),Vector3(.15,.006,.012),"label paper")
	# Two soft hanging bags to the right of the opening.
	for i in 2:
		var p := Vector3(3.19,1.55+i*.39,2.58)
		_sphere(p,Vector3(.28,.43,.15),"black steel")
		_tube([p+Vector3(-.08,.16,0),p+Vector3(0,.39,.01),p+Vector3(.08,.16,0)],.015,"black steel")

func _guitar(center: Vector3, acoustic: bool) -> void:
	var key := "oak" if acoustic else "red enamel"
	var scale := 1.0 if acoustic else .74
	var outline: Array[Vector2] = []
	# A continuous waisted silhouette, not a stack of spheres.
	for i in 40:
		var angle := TAU*i/40
		var y := sin(angle)*.31
		var width := .155*(1-.38*exp(-pow(y/.09,2)))
		outline.append(Vector2(cos(angle)*width,y)*scale)
	var tool := _builder(key)
	for i in outline.size():
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i+1)%outline.size()]
		for layer in [-1,1]:
			var normal := Vector3(0,0,layer)
			var points := [center+Vector3(0,0,layer*.049),center+Vector3(a.x,a.y,layer*.049),center+Vector3(b.x,b.y,layer*.049)]
			for j in ([0,2,1] if layer == 1 else [0,1,2]):
				tool.set_normal(normal)
				tool.set_uv(Vector2(points[j].x,points[j].y))
				tool.add_vertex(points[j])
			_stats.triangles_added += 1
		_quad([center+Vector3(a.x,a.y,-.049),center+Vector3(b.x,b.y,-.049),center+Vector3(b.x,b.y,.049),center+Vector3(a.x,a.y,.049)],Vector3(a.x,a.y,0).normalized(),key)
	_box("Guitar neck",center+Vector3(0,.53,0),Vector3(.052,.65,.045),"darkwood")
	_box("Guitar headstock",center+Vector3(0,.90,0),Vector3(.079,.16,.043),key)
	if acoustic: _rod(center+Vector3(0,.08,-.052),center+Vector3(0,.08,-.055),.057,"dark recess",20)
	else: _box("Guitar pickguard",center+Vector3(.025,.028,-.054),Vector3(.087,.13,.007),"ivory")
	_box("Guitar bridge",center+Vector3(0,-.15,-.057),Vector3(.13,.024,.012),"darkwood")
	for i in 6:
		var x := -.018+i*.007
		_rod(center+Vector3(x,-.16,-.066),center+Vector3(x,.94,-.031),.0008,"steel",4)
		_sphere(center+Vector3(-.053 if i%2 else .053,.85+(i/2)*.032,0),Vector3(.025,.014,.023),"steel",8)
	for i in 13: _rod(center+Vector3(-.026,.23+i*.043,-.028),center+Vector3(.026,.23+i*.043,-.028),.0015,"steel",4)

func _build_right() -> void:
	_feature("Right slatted wall and family-photo gallery")
	for i in 89:
		var z := -2.66+i*.06
		if z < .36 or z > 1.44:
			_box("Right wall pale slat",Vector3(3.275,1.45,z),Vector3(.042,2.9,.036),"slat")
		else: _box("Right wall slat above doorway",Vector3(3.275,2.65,z),Vector3(.042,.50,.036),"slat")
	var facing := Basis(Vector3.UP,-PI*.5)
	for item: Array in [[-2.15,2.18,.31,.41,4],[-1.63,2.09,.29,.39,3],[-1.04,2.15,.35,.46,6],[-.49,2.08,.29,.39,2],[-1.95,1.54,.42,.31,0],[-.97,1.52,.36,.39,5],[-.41,1.49,.31,.39,7],[-1.1,2.67,.30,.22,1]]:
		_frame(Vector3(3.239,item[1],item[0]),item[2],item[3],item[4],facing)
	_feature("Leaf-pattern curtain doorway and shallow closet")
	for z in [.34,1.46]: _box("Curtain doorway frame",Vector3(3.245,1.18,z),Vector3(.085,2.36,.062),"darkwood")
	_box("Curtain doorway lintel",Vector3(3.245,2.37,.90),Vector3(.085,.060,1.20),"darkwood")
	_curtain(Vector3(3.237,.07,.375),.51,2.23,"leaf curtain",true)
	_curtain(Vector3(3.237,.07,.932),.49,2.23,"leaf curtain",true)
	_rod(Vector3(3.215,2.30,.91),Vector3(3.215,1.40,.91),.011,"black steel")
	_sphere(Vector3(3.204,1.44,.91),Vector3(.026,.14,.11),"pink plastic")
	_sphere(Vector3(3.203,1.33,.91),Vector3(.051,.052,.052),"cream basket")
	_box("Closet shelf",Vector3(3.90,1.89,.90),Vector3(.53,.028,.95),"ivory",true)
	_box("Closet back storage",Vector3(4.12,.42,.89),Vector3(.22,.83,.73),"ivory",true)
	_flower_mat(Vector3(2.91,.013,.90),.33)
	_feature("Tall cupboard household shelf and laundry baskets")
	# Tall white display cupboard with inset doors and translucent shelves.
	_box("Tall storage cabinet",Vector3(3.06,1.02,2.12),Vector3(.44,2.03,.67),"ivory",true)
	_box("Tall cupboard glass opening",Vector3(2.824,1.59,2.12),Vector3(.020,.66,.58),"dark recess")
	_box("Tall cupboard glass",Vector3(2.806,1.59,2.12),Vector3(.011,.61,.53),"glass")
	for y in [.27,.71,1.12]:
		_box("Tall cupboard raised door",Vector3(2.817,y,2.12),Vector3(.026,.37,.58),"ivory")
		for z in [1.862,2.378]: _box("Cupboard molded door edge",Vector3(2.798,y,z),Vector3(.016,.34,.014),"ivory")
		for yp in [-.163,.163]: _box("Cupboard molded door edge",Vector3(2.798,y+yp,2.12),Vector3(.016,.014,.52),"ivory")
		_box("Cupboard door handle",Vector3(2.770,y,1.93),Vector3(.028,.072,.014),"steel")
	for i in 4: _box("Storage tins in glass cabinet",Vector3(2.824,1.42+i*.12,2.12),Vector3(.029,.075,.38),"pink plastic" if i%2 else "ivory")
	_rack(Vector3(3.07,1.33,1.70),Vector3(.20,.79,.36),"ivory",4)
	for i in 6: _counter_bottle(Vector3(2.997,1.54+(i/3)*.19,1.60+(i%3)*.07),i%3)
	_basket(Vector3(2.65,0,1.94),Vector3(.42,.60,.41),"cream basket")
	_basket(Vector3(3.03,0,1.55),Vector3(.32,.52,.33),"ivory")
	for i in 6:
		var p := Vector3(2.66+sin(i*2.4)*.12,.59+(i%2)*.021,1.95+cos(i*2.4)*.11)
		_sphere(p,Vector3(.24,.105,.18),"blue cloth" if i%2 else "pink cloth")
	# Woven shopping bag and soft folded bags on top of the cabinet.
	_box("Blue woven shopping bag",Vector3(3.05,2.20,2.12),Vector3(.31,.34,.38),"blue plastic")
	for i in 9: _box("Bag woven horizontal strips",Vector3(2.884,2.07+i*.033,2.12),Vector3(.009,.012,.37),"black steel")
	for i in 9: _box("Bag woven vertical strips",Vector3(2.880,2.20,1.95+i*.041),Vector3(.011,.31,.012),"black steel")
	for z in [2.03,2.20]: _tube([Vector3(2.95,2.36,z),Vector3(2.96,2.55,z),Vector3(3.13,2.55,z),Vector3(3.14,2.36,z)],.009,"black steel")
	_sphere(Vector3(3.05,2.31,2.54),Vector3(.30,.23,.29),"green plastic")

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
