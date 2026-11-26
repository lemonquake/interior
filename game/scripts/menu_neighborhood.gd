extends Node3D
## A live camera in the playable town. Dressing remains there when Play is pressed.
const EYE := Vector3(22.0, -2.19, 43.0)
const AIM := Vector3(-.65, .12, 1.0)
const SLIPPER := Vector3(19.98, -2.867, 44.70)
var camera: Camera3D
var active := false
var elapsed := 0.0
var _main: Node
var _animated: Array[Node] = []
var _paper: Array[MeshInstance3D] = []
var _lamp: OmniLight3D
var rng := RandomNumberGenerator.new()

func setup(main: Node) -> void:
	_main = main
	name = "Menu neighborhood camera"
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.seed = 151015
	camera = Camera3D.new()
	camera.name = "Live street camera"
	camera.set_meta("menu_camera", true)
	camera.fov = 65.0
	camera.near = .035
	camera.far = 900
	add_child(camera)
	camera.position = EYE
	camera.look_at(EYE + AIM * 20)
	var town := get_tree().get_first_node_in_group("neighbourhood") as Node3D
	if town != null:
		_build_details(town)
	for node in [main.get_node_or_null("NightAudio"), main.atmosphere, main.atmosphere_particles]:
		if is_instance_valid(node): _animated.append(node)

func set_active(value: bool) -> void:
	if active == value: return
	active = value
	for node in _animated:
		node.process_mode = Node.PROCESS_MODE_ALWAYS if value else Node.PROCESS_MODE_PAUSABLE
	if value:
		camera.make_current()
		# Adapt immediately before the first visible frame; subsequent changes remain gradual.
		var town := get_tree().get_first_node_in_group("neighbourhood")
		if town != null:
			town.get_parent().show()
			town._process(0.0)
			town._outside_blend = 1.0
			town._blend_grade()
	else:
		_main.player.camera.make_current()
		# Restore the room's grade without making the player wait through an outdoor fade.
		var town := get_tree().get_first_node_in_group("neighbourhood")
		if town != null:
			town._outside_blend = 0.0
			town._outdoors = false
			town._blend_grade()

func _process(delta: float) -> void:
	if not active: return
	elapsed += delta
	var motion: float = [1.0, .75, 0.0][_main.camera_motion]
	camera.position = EYE + Vector3(sin(elapsed * .13) * .012, sin(elapsed * .19) * .004, 0) * motion
	camera.look_at(EYE + AIM * 20)
	for i in _paper.size():
		_paper[i].rotation.z = sin(elapsed * .75 + i) * .025
	if is_instance_valid(_lamp):
		_lamp.light_energy = 2.1 * (1.0 - .65 * pow(maxf(sin(elapsed * .47), 0.0), 32.0))

func material(color: Color, roughness := .9, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metal
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var noise := FastNoiseLite.new()
	noise.seed = 1510
	noise.frequency = .15
	var texture := NoiseTexture2D.new()
	texture.width = 128
	texture.height = 128
	texture.noise = noise
	texture.as_normal_map = true
	texture.bump_strength = 1.3
	m.normal_enabled = true
	m.normal_texture = texture
	m.normal_scale = .55
	return m

func mesh(parent: Node3D, label: String, geometry: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = geometry
	node.material_override = mat
	node.layers = 2
	parent.add_child(node)
	node.position = at
	return node

func box(parent: Node3D, label: String, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var geometry := BoxMesh.new()
	geometry.size = size
	return mesh(parent, label, geometry, at, mat)

func rod(parent: Node3D, label: String, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var geometry := CylinderMesh.new()
	geometry.top_radius = radius
	geometry.bottom_radius = radius * 1.1
	geometry.height = a.distance_to(b)
	geometry.radial_segments = 8
	var node := mesh(parent, label, geometry, (a + b) * .5, mat)
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD).normalized()
	if side.length_squared() < .1: side = Vector3.RIGHT
	node.basis = Basis(side, up, side.cross(up))
	return node

func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for p in [a, b, c]:
		st.set_uv(Vector2(p.x, p.z) * 8)
		st.add_vertex(p)

func _sole(parent: Node3D, at_y: float, depth: float, size: float, mat: Material) -> void:
	var contour: Array[Vector3] = []
	for i in 64:
		var angle := TAU * float(i) / 64.0
		var z := cos(angle) * .153
		var width := .051 + .012 * smoothstep(-.12, .07, z) - .012 * exp(-pow((z + .018) / .04, 2))
		var nick := .004 if i in [5, 6, 22, 23, 37, 49, 50] else 0.0
		contour.append(Vector3(sin(angle) * (width - nick), at_y + .003 * sin(angle * 3), z) * size)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in contour.size():
		var a := contour[i]
		var b := contour[(i + 1) % contour.size()]
		triangle(st, Vector3(0, at_y * size, 0), a, b)
		triangle(st, a, a - Vector3.UP * depth, b)
		triangle(st, b, a - Vector3.UP * depth, b - Vector3.UP * depth)
	st.generate_normals()
	mesh(parent, "Chipped rubber sole", st.commit(), Vector3.ZERO, mat)

func _strap(parent: Node3D, points: Array[Vector3], width: float, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var side := (b - a).cross(Vector3.UP).normalized() * width * .5
		triangle(st, a - side, a + side, b + side)
		triangle(st, a - side, b + side, b - side)
	st.generate_normals()
	mesh(parent, "Split rubber strap", st.commit(), Vector3.ZERO, mat)

func _build_details(town: Node3D) -> void:
	var details := Node3D.new()
	details.name = "Tattered slipper and street litter"
	town.add_child(details)
	var rubber := InteriorHorrorPropMaterials.make(Color(.095, .23, .26), "plastic", .25)
	var edge := material(Color(.043, .06, .064))
	var red := InteriorHorrorPropMaterials.make(Color(.30, .065, .045), "plastic", .25)
	var dirt := material(Color(.19, .15, .09))
	var slipper := Node3D.new()
	slipper.name = "Single worn tsinelas"
	details.add_child(slipper)
	slipper.position = SLIPPER
	slipper.rotation.y = -.75
	slipper.scale = Vector3.ONE * 1.15
	_sole(slipper, .018, .018, 1.0, edge)
	_sole(slipper, .024, .008, .98, rubber)
	rod(slipper, "Toe plug", Vector3(.004, .022, .079), Vector3(.004, .055, .079), .006, red)
	_strap(slipper, [Vector3(.004,.055,.079), Vector3(-.013,.069,.058), Vector3(-.038,.061,.024), Vector3(-.052,.028,-.025)], .018, red)
	# The other Y arm has torn off the side plug and folds outward onto the ground.
	_strap(slipper, [Vector3(.004,.055,.079), Vector3(.025,.061,.053), Vector3(.040,.042,.030), Vector3(.063,.026,.018), Vector3(.084,.009,.029)], .019, red)
	for i in 9:
		var at := Vector3(.078 + rng.randf_range(-.006,.006), .010, .02 + i * .002)
		rod(slipper, "Torn strap fibres", at, at + Vector3(rng.randf_range(.004,.017), .002, -.007), .0007, red)
	for i in 30:
		var z := rng.randf_range(-.13,.12)
		var x := rng.randf_range(-.036,.036)
		var mark := box(slipper, "Worn tread and mud", Vector3(x,.025,z), Vector3(rng.randf_range(.008,.03),.001,.0015), dirt if i % 3 == 0 else edge)
		mark.rotation.y = rng.randf_range(-.5,.5)
	var paper := InteriorHorrorPropMaterials.make(Color(.75, .71, .6), "paper", .25)
	var foil := InteriorHorrorPropMaterials.make(Color(.62, .64, .6), "metal", .3)
	var blue := InteriorHorrorPropMaterials.make(Color(.07, .18, .25), "plastic", .25)
	var plastic := InteriorHorrorPropMaterials.make(Color(.024, .031, .027), "bag", .5)
	var rust := InteriorHorrorPropMaterials.make(Color(.25, .10, .046), "metal", .35)
	var glass := material(Color(.065,.15,.095), .19, .15)
	# Gutter grate, caught rubbish, spalled masonry, and loose overhead service wires.
	var drain := Vector3(19.1,-2.878,45.1)
	box(details,"Blocked drain opening",drain,Vector3(.46,.004,.26),edge)
	for i in 9:
		box(details,"Rusted drain bars",drain+Vector3(-.20+i*.05,.006,0),Vector3(.014,.012,.28),rust)
	for z in [-.14,.14]: box(details,"Drain frame",drain+Vector3(0,.007,z),Vector3(.48,.018,.018),rust)
	var cement := material(Color(.31,.30,.26))
	for i in 22:
		var chip := box(details,"Broken concrete fragment",Vector3(18.4+rng.randf_range(0,1.4),-2.855,45+rng.randf_range(-.2,1.7)),Vector3(rng.randf_range(.014,.05),.022,rng.randf_range(.018,.065)),cement)
		chip.rotation = Vector3(rng.randf_range(-.2,.2),rng.randf_range(-PI,PI),rng.randf_range(-.2,.2))
	for wire in 3:
		var start := Vector3(24.5,3.3+wire*.12,44.0)
		var end := Vector3(13.9,.75,52.0+wire*.15)
		for segment in 28:
			var a := float(segment)/28
			var b := float(segment+1)/28
			rod(details,"Sagging service wire",start.lerp(end,a)-Vector3.UP*sin(a*PI)*.55,start.lerp(end,b)-Vector3.UP*sin(b*PI)*.55,.007,edge)
	# Curled wrappers and folded sachets, with seams and creases in the geometry.
	for i in 46:
		var at := SLIPPER + Vector3(rng.randf_range(-2.0,1.4), .002, rng.randf_range(-.1,4.0))
		if at.distance_to(SLIPPER) < .24: continue
		var w := rng.randf_range(.035,.12)
		var h := rng.randf_range(.05,.18)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var a := Vector3(-w,.002,-h)
		var b := Vector3(w,.008,-h * .8)
		var c := Vector3(w * .7,.004,h)
		var d := Vector3(-w,.025,h * .8)
		var fold := Vector3(.01,.022,0)
		for pair in [[a,b],[b,c],[c,d],[d,a]]: triangle(st, pair[0], pair[1], fold)
		st.generate_normals()
		var node := mesh(details, "Creased discarded sachet", st.commit(), at, [paper,foil,blue][i % 3])
		node.rotation.y = rng.randf_range(-PI,PI)
		if i < 6: _paper.append(node)
	for i in 8:
		var at := SLIPPER + Vector3(rng.randf_range(-1.8,.8), .045, rng.randf_range(.3,3.5))
		var can := rod(details, "Crushed rusty can", at, at + Vector3(.11,.015,.07), .036, rust if i % 2 == 0 else foil)
		can.scale.x = .65
		rod(details, "Can rolled rim", at, at + Vector3(.006,.001,.004), .038, foil)
	for i in 4:
		var at := SLIPPER + Vector3(-.6 - i * .35, .036, .6 + i * .4)
		var end := at + Vector3(.13,0,.04)
		rod(details, "Empty glass bottle", at, end, .028, glass)
		rod(details, "Bottle neck", end, end + Vector3(.055,0,.017), .012, glass)
	for i in 3:
		var sphere := SphereMesh.new()
		sphere.radius = .19 + i * .035
		sphere.height = .41 + i * .03
		sphere.radial_segments = 13
		sphere.rings = 8
		var at := Vector3(18.3 + i * .34,-2.58,46.4 + i * .11)
		var arrays := sphere.get_mesh_arrays()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v in vertices.size():
			var p := vertices[v]
			var angle := atan2(p.z,p.x)
			var crumple := 1.0 + .10 * sin(angle * 7.0 + p.y * 25.0) + .065 * sin(angle * 13.0 - p.y * 47.0)
			vertices[v] = Vector3(p.x * crumple, p.y, p.z * crumple)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var crumpled := ArrayMesh.new()
		crumpled.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var bag := mesh(details, "Tied rubbish sack", crumpled, at, plastic)
		bag.scale = Vector3(1,.92,.76)
		rod(details, "Twisted bag tie", at + Vector3.UP*.17, at + Vector3(.035,.26,0), .025, plastic)
	# A damaged wood fruit crate, with individual splinters and rusty nails.
	var wood := InteriorHorrorPropMaterials.worn_wood()
	var crate := Vector3(18.65,-2.80,45.9)
	for i in 5:
		box(details, "Crate bottom slat", crate + Vector3(i*.105,0,0), Vector3(.085,.018,.34), wood)
	for i in 3:
		for side in [-1,1]:
			box(details, "Broken crate rail", crate + Vector3(.2,.04+i*.075,side*.17), Vector3(.51 if i != 2 else .33,.055,.015), wood)
	for x in [0,.43]:
		for z in [-.17,.17]:
			box(details, "Crate corner", crate + Vector3(x,.11,z),Vector3(.023,.27,.024),wood)
			rod(details,"Rusty nail",crate+Vector3(x,.19,z-.012),crate+Vector3(x,.19,z+.012),.003,rust)
	# A low, warm practical light grazes the litter and cracks without lighting the whole town.
	_lamp = OmniLight3D.new()
	_lamp.name = "Faltering wall light"
	_lamp.position = Vector3(18.65,.1,44.6)
	_lamp.light_color = Color(.78,.55,.30)
	_lamp.light_energy = 2.1
	_lamp.omni_range = 7
	_lamp.omni_attenuation = 1.6
	_lamp.light_cull_mask = 2
	_lamp.shadow_enabled = true
	details.add_child(_lamp)
	rod(details, "Rusted lamp post", Vector3(18.30,-2.78,44.6), Vector3(18.30,.32,44.6), .034, rust)
	rod(details, "Bent lamp arm", Vector3(18.30,.32,44.6), Vector3(18.65,.21,44.6), .025, rust)
	box(details, "Rusty light bracket", _lamp.position + Vector3(0,0,-.12), Vector3(.10,.20,.12), rust)
	var lens := material(Color(.7,.52,.27),.3)
	lens.emission_enabled = true
	lens.emission = Color(.7,.45,.18)
	lens.emission_energy_multiplier = 1.2
	var lamp_lens := box(details, "Old light lens", _lamp.position, Vector3(.13,.13,.05),lens)
	lamp_lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 5:
		rod(details,"Lamp cage",_lamp.position+Vector3(-.07+i*.035,-.09,.032),_lamp.position+Vector3(-.07+i*.035,.09,.032),.004,rust)
	details.set_meta("slipper_position", SLIPPER)
