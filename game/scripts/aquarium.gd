class_name InteriorAquarium
extends Node3D

var fish: Array[Node3D] = []
var tails: Array[Node3D] = []
var elapsed := 0.0
var bowl_scale := 1.0
## Inner size of a rectangular tank in metres; zero builds the round bowl.
var tank_size := Vector3.ZERO
# Swim path: ellipse radii (x, z), centre height and vertical bob, in local metres.
var _swim := Vector4(.10, .095, .145, .035)

static func attach_to(body: InteriorObject, scale_value := 1.0, tank := Vector3.ZERO) -> InteriorAquarium:
	for child in body.get_children():
		if child is MeshInstance3D or child is CollisionShape3D:
			body.remove_child(child)
			child.queue_free()
	var bowl := InteriorAquarium.new()
	bowl.name = "Aquarium"
	bowl.bowl_scale = scale_value
	bowl.tank_size = tank
	if tank != Vector3.ZERO:
		body.add_child(bowl)
		bowl._build_tank()
		var box := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = tank + Vector3(.02, .07, .02)
		box.shape = box_shape
		box.position.y = box_shape.size.y * .5
		body.add_child(box)
		body.display_name = "Aquarium"
		body.mass = 1000.0 * tank.x * tank.y * tank.z * .85 + 12.0
		return bowl
	bowl.scale = Vector3.ONE * scale_value
	body.add_child(bowl)
	bowl._build()
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = .176 * scale_value
	collision.shape = shape
	collision.position.y = .172 * scale_value
	body.add_child(collision)
	body.display_name = "Glass aquarium"
	body.mass = 5.4 * pow(scale_value, 3)
	return bowl

func _build() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("aquariums")
	var glass := _material(Color(.66,.85,.89,.12),.13)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.disable_receive_shadows = true
	glass.metallic_specular = .8
	var profile := PackedVector2Array([Vector2(.08,.014),Vector2(.125,.027),Vector2(.17,.085),Vector2(.188,.17),Vector2(.17,.25),Vector2(.131,.29),Vector2(.128,.31),Vector2(.123,.314),Vector2(.118,.31),Vector2(.121,.29),Vector2(.163,.247),Vector2(.180,.17),Vector2(.162,.09),Vector2(.12,.035),Vector2(.08,.022)])
	var shell := _lathe(profile,48)
	_mesh(self,shell,glass,Vector3.ZERO)
	var rim := TorusMesh.new()
	rim.inner_radius = .120
	rim.outer_radius = .130
	rim.rings = 40
	rim.ring_segments = 8
	_mesh(self,rim,glass,Vector3(0,.310,0))
	var water := _material(Color(.22,.48,.40,.12),.19)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.disable_receive_shadows = true
	water.cull_mode = BaseMaterial3D.CULL_DISABLED
	var surface := CylinderMesh.new()
	surface.top_radius = .162
	surface.bottom_radius = .162
	surface.height = .001
	surface.radial_segments = 48
	_mesh(self,surface,water,Vector3(0,.244,0))
	var substrate := _material(Color(.24,.19,.12),.95)
	var bed := SphereMesh.new()
	bed.radius = .12
	bed.height = .07
	bed.radial_segments = 24
	bed.rings = 12
	_mesh(self,bed,substrate,Vector3(0,.046,0))
	var random := RandomNumberGenerator.new()
	random.seed = 9185
	var gravel := MultiMeshInstance3D.new()
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	var pebble := SphereMesh.new()
	pebble.radius = .009
	pebble.height = .012
	pebble.radial_segments = 8
	pebble.rings = 4
	pebble.material = _material(Color.WHITE,.85)
	pebble.material.vertex_color_use_as_albedo = true
	instances.mesh = pebble
	instances.instance_count = 70
	for i in instances.instance_count:
		var r := sqrt(random.randf()) * .105
		var a := random.randf() * TAU
		instances.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(cos(a)*r,.065+random.randf()*.008,sin(a)*r)))
		instances.set_instance_color(i,[Color(.46,.19,.10),Color(.64,.47,.23),Color(.22,.29,.21),Color(.65,.64,.49)][i%4])
	gravel.multimesh = instances
	add_child(gravel)
	var leaf_material := _material(Color(.07,.24,.10),.68)
	for i in 7:
		var stem := Node3D.new()
		add_child(stem)
		stem.position = Vector3(-.05+sin(i*2.4)*.025,.07,-.025+cos(i*2.4)*.025)
		stem.rotation.z = sin(i*1.4)*.35
		var stalk := CylinderMesh.new()
		stalk.top_radius = .0015
		stalk.bottom_radius = .002
		stalk.height = .12 + float(i%3)*.027
		_mesh(stem,stalk,leaf_material,Vector3(0,stalk.height*.5,0))
		for j in 3:
			var leaf := SphereMesh.new()
			leaf.radius = .018
			leaf.height = .065
			leaf.radial_segments = 10
			leaf.rings = 5
			var node := _mesh(stem,leaf,leaf_material,Vector3((1 if j%2==0 else -1)*.014,.05+j*.039,0))
			node.scale.z = .12
			node.rotation.z = (1 if j%2==0 else -1)*.65
	for i in 2:
		var swimmer := Node3D.new()
		swimmer.name = "Goldfish%d" % i
		add_child(swimmer)
		fish.append(swimmer)
		var color := _material(Color(.83,.24,.035) if i==0 else Color(.94,.52,.12),.41)
		var body_mesh := SphereMesh.new()
		body_mesh.radius = .020
		body_mesh.height = .075
		body_mesh.radial_segments = 16
		body_mesh.rings = 8
		var body_node := _mesh(swimmer,body_mesh,color,Vector3.ZERO)
		body_node.rotation.x = PI*.5
		body_node.scale.x = .8
		var tail := Node3D.new()
		swimmer.add_child(tail)
		tail.position.z = -.034
		tails.append(tail)
		var fin := SurfaceTool.new()
		fin.begin(Mesh.PRIMITIVE_TRIANGLES)
		for vertex in [Vector3(0,0,0),Vector3(.003,.023,-.032),Vector3(.003,-.023,-.032),Vector3(0,0,0),Vector3(.003,-.023,-.032),Vector3(.003,.023,-.032)]:
			fin.add_vertex(vertex)
		fin.generate_normals()
		_mesh(tail,fin.commit(),color,Vector3.ZERO)
		for side in [-1,1]:
			var eye := SphereMesh.new()
			eye.radius = .0032
			eye.height = .0064
			eye.radial_segments = 8
			eye.rings = 4
			_mesh(swimmer,eye,_material(Color(.012,.011,.008),.18),Vector3(side*.012,.005,.024))

func _physics_process(delta: float) -> void:
	elapsed += delta
	if tank_size != Vector3.ZERO:
		_swim_tank()
		return
	for i in fish.size():
		var angle := elapsed * (.52 if i==0 else -.38) + i*PI
		fish[i].position = Vector3(cos(angle)*.10,.145+sin(elapsed*.6+i)*.035,sin(angle)*.095)
		fish[i].rotation.y = -angle + (0 if i==0 else PI)
		tails[i].rotation.y = sin(elapsed*12.0+i)*.48

func _swim_tank() -> void:
	var speeds := [.52, -.38, .44, -.61, .33]
	for i in fish.size():
		var speed: float = speeds[i % speeds.size()]
		var angle := elapsed * speed + i * TAU / fish.size()
		var lane := 1.0 - .2 * (i % 3)
		fish[i].position = Vector3(cos(angle)*_swim.x*lane, _swim.z+sin(elapsed*.6+i)*_swim.w+(i%3-1)*_swim.w, sin(angle)*_swim.y*lane)
		fish[i].rotation.y = -angle + (0.0 if speed > 0.0 else PI)
		tails[i].rotation.y = sin(elapsed*12.0+i)*.48

## Rectangular glass tank (balcony): open-top glass with black trims, gravel, plants,
## pink coral, rocks, a toy boat at the surface, a filter box and five fish.
func _build_tank() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("aquariums")
	var t := tank_size
	_swim = Vector4(t.x * .36, t.z * .26, t.y * .52, t.y * .11)
	var glass := _material(Color(.70,.86,.90,.10),.06)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.metallic_specular = .9
	var trim := _material(Color(.03,.03,.035),.4)
	var water := _material(Color(.30,.62,.60,.16),.05)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.cull_mode = BaseMaterial3D.CULL_DISABLED
	for item: Array in [[Vector3(0,t.y*.5,t.z*.5),Vector3(t.x,t.y,.006)],[Vector3(0,t.y*.5,-t.z*.5),Vector3(t.x,t.y,.006)],
			[Vector3(t.x*.5,t.y*.5,0),Vector3(.006,t.y,t.z)],[Vector3(-t.x*.5,t.y*.5,0),Vector3(.006,t.y,t.z)]]:
		_box_mesh(item[1], glass, item[0])
	_box_mesh(Vector3(t.x-.01,t.y*.82,t.z-.01), water, Vector3(0,t.y*.41+.012,0))
	for y in [.008, t.y - .006]:
		for z in [-1, 1]: _box_mesh(Vector3(t.x+.016,.016,.016), trim, Vector3(0,y,z*t.z*.5))
		for x in [-1, 1]: _box_mesh(Vector3(.016,.016,t.z), trim, Vector3(x*t.x*.5,y,0))
	_box_mesh(Vector3(t.x,.006,t.z), trim, Vector3(0,.003,0))
	var random := RandomNumberGenerator.new()
	random.seed = 4417
	var gravel := MultiMeshInstance3D.new()
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	var pebble := SphereMesh.new()
	pebble.radius = .011
	pebble.height = .014
	pebble.radial_segments = 6
	pebble.rings = 3
	pebble.material = _material(Color.WHITE,.85)
	pebble.material.vertex_color_use_as_albedo = true
	instances.mesh = pebble
	instances.instance_count = 260
	for i in instances.instance_count:
		instances.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(random.randf_range(-.48,.48)*t.x,.012+random.randf()*.02,random.randf_range(-.46,.46)*t.z)))
		instances.set_instance_color(i,[Color(.92,.89,.80),Color(.80,.55,.62),Color(.45,.62,.80),Color(.86,.76,.45)][i%4])
	gravel.multimesh = instances
	add_child(gravel)
	var leaf_material := _material(Color(.10,.42,.14),.6)
	for i in 9:
		var stem := Node3D.new()
		add_child(stem)
		stem.position = Vector3(random.randf_range(-.42,.42)*t.x,.03,-t.z*.32+random.randf()*.06)
		stem.rotation.z = random.randf_range(-.25,.25)
		for j in 4:
			var leaf := SphereMesh.new()
			leaf.radius = .02
			leaf.height = .09
			leaf.radial_segments = 8
			leaf.rings = 4
			var node := _mesh(stem,leaf,leaf_material,Vector3((1 if j%2==0 else -1)*.012,.04+j*.055,0))
			node.scale.z = .15
			node.rotation.z = (1 if j%2==0 else -1)*.45
	var coral := _material(Color(.95,.45,.62),.7)
	for i in 6:
		var branch := CylinderMesh.new()
		branch.top_radius = .006
		branch.bottom_radius = .012
		branch.height = .07 + (i%3)*.02
		branch.radial_segments = 6
		var node := _mesh(self,branch,coral,Vector3(-t.x*.32+(i%3)*.025,.06,t.z*.12+(i/3)*.03))
		node.rotation = Vector3(sin(i*1.7)*.5,0,cos(i*2.3)*.5)
	var rock := _material(Color(.55,.50,.44),.9)
	for i in 3:
		var stone := SphereMesh.new()
		stone.radius = .035 + i*.008
		stone.height = .05
		_mesh(self,stone,rock,Vector3(t.x*(.12+i*.1),.03,t.z*(.18-i*.12)))
	var hull := _material(Color(.92,.80,.55),.6)
	var boat := _box_mesh(Vector3(.10,.025,.04),hull,Vector3(-t.x*.05,t.y*.82+.012,t.z*.1))
	boat.rotation.y = .4
	_box_mesh(Vector3(.004,.06,.004),_material(Color(.3,.2,.12),.7),Vector3(-t.x*.05,t.y*.82+.05,t.z*.1))
	_box_mesh(Vector3(.16,.10,.09),trim,Vector3(t.x*.30,t.y+.04,-t.z*.32))
	var palette := [Color(.95,.45,.08),Color(.98,.75,.15),Color(.85,.20,.10),Color(.20,.45,.95),Color(.95,.95,.90)]
	for i in 5:
		_add_fish(palette[i], 1.0 - .12 * (i % 2))

func _box_mesh(size: Vector3, material: Material, at: Vector3) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _mesh(self, box, material, at)

func _add_fish(tint: Color, size: float) -> void:
	var swimmer := Node3D.new()
	swimmer.name = "Fish%d" % fish.size()
	swimmer.scale = Vector3.ONE * size
	add_child(swimmer)
	fish.append(swimmer)
	var color := _material(tint,.41)
	var body_mesh := SphereMesh.new()
	body_mesh.radius = .016
	body_mesh.height = .06
	body_mesh.radial_segments = 12
	body_mesh.rings = 6
	var body_node := _mesh(swimmer,body_mesh,color,Vector3.ZERO)
	body_node.rotation.x = PI*.5
	body_node.scale.x = .75
	var tail := Node3D.new()
	swimmer.add_child(tail)
	tail.position.z = -.028
	tails.append(tail)
	var fin := SurfaceTool.new()
	fin.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in [Vector3(0,0,0),Vector3(.003,.018,-.026),Vector3(.003,-.018,-.026),Vector3(0,0,0),Vector3(.003,-.018,-.026),Vector3(.003,.018,-.026)]:
		fin.add_vertex(vertex)
	fin.generate_normals()
	_mesh(tail,fin.commit(),color,Vector3.ZERO)

func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _mesh(parent: Node3D, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	if material is StandardMaterial3D and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	node.position = at
	return node

func _lathe(profile: PackedVector2Array, sides: int) -> ArrayMesh:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in profile.size()-1:
		for j in sides:
			var a := float(j)/sides*TAU
			var b := float(j+1)/sides*TAU
			var vertices := [Vector3(cos(a)*profile[i].x,profile[i].y,sin(a)*profile[i].x),Vector3(cos(b)*profile[i].x,profile[i].y,sin(b)*profile[i].x),Vector3(cos(b)*profile[i+1].x,profile[i+1].y,sin(b)*profile[i+1].x),Vector3(cos(a)*profile[i+1].x,profile[i+1].y,sin(a)*profile[i+1].x)]
			for index in [0,1,2,0,2,3]:
				builder.add_vertex(vertices[index])
	builder.generate_normals()
	return builder.commit()
