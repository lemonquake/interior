class_name InteriorAquarium
extends Node3D

var fish: Array[Node3D] = []
var tails: Array[Node3D] = []
var elapsed := 0.0
var bowl_scale := 1.0

static func attach_to(body: InteriorObject, scale_value := 1.0) -> InteriorAquarium:
	for child in body.get_children():
		if child is MeshInstance3D or child is CollisionShape3D:
			body.remove_child(child)
			child.queue_free()
	var bowl := InteriorAquarium.new()
	bowl.name = "Aquarium"
	bowl.bowl_scale = scale_value
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
	for i in fish.size():
		var angle := elapsed * (.52 if i==0 else -.38) + i*PI
		fish[i].position = Vector3(cos(angle)*.10,.145+sin(elapsed*.6+i)*.035,sin(angle)*.095)
		fish[i].rotation.y = -angle + (0 if i==0 else PI)
		tails[i].rotation.y = sin(elapsed*12.0+i)*.48

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
