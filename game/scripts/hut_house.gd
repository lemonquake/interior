class_name InteriorHutHouse
extends Node3D
const Shine := preload("res://scripts/pickup_shine.gd")
## 0.10: the bahay kubo off the dirt road becomes a house you can walk into (added at runtime by interior.gd
## under the baked Fields, so the fields bake is unchanged).
##
## - The hut turns to face the road, so its doorway (and the lantern, now under the eave beside it) looks back at
##   the road. An earthen footpath leads straight from the road to its door; the road's invisible edge wall
##   opens for it, and low invisible walls keep the player on the path and the yard.
## - Inside: a plank floor and plank-lined walls, a woven sleeping mat and pillow, a low table and stool, a shelf of
##   jars, a water jar and sacks, and against the back wall facing the door a dresser with a lit candle.
## - On the dresser a brass key sparkles. Take it, and it unlocks the dresser's top drawer, which slides open on a
##   Glock 17 lying on a cloth. Taking the gun hands over to the story (scripts/story.gd), which shows it on screen.
## - 0.12: beside the cloth lies a black flashlight (scripts/flashlight.gd); taking it hands it to the story too.
## All of the hut's own geometry is in the hut's local frame: floor at y 0.42, inner wall faces at x -1.734 (back)
## and 1.695 (door wall), z -1.64 / 1.691; the doorway is on the +X wall at z -0.62..0.02.

signal key_taken
signal drawer_opened
signal gun_requested
signal flashlight_picked

const OUTDOOR_LAYER := 2
const GROUND := -2.9
const WATER_Y := GROUND - .42
const FLOOR := .42
const BACK := -1.734
const FRONT := 1.695
const SIDE_POS := 1.691
const SIDE_NEG := -1.64
const DOOR_Z0 := -.62
const DOOR_Z1 := .02
const DOOR_Z := -.3
const DOOR_TOP := 2.3
const WINDOW_Z := Vector2(.62, 1.28)
const WINDOW_Y := Vector2(1.45, 2.18)
const YARD := 6.6
const PATH_HALF := 1.15
const WALK_HALF := 3.2
const GLOCK := preload("res://assets/models/story/glock17.glb")
const AMMO_BOX := "res://assets/models/story/ammo_box.glb"
## 0.11: the scarecrow's islet (fields_builder.gd): flat top radius, and the dike's half width.
const ISLET_TOP := 2.0
const DIKE_HALF := 1.05
const SPARKLE_SHADER := preload("res://scripts/sparkle.gdshader")
const DRAWER_TRAVEL := .3

var kubo: Node3D
var fields: Node3D
var has_key := false
var drawer_open := false
var gun_taken := false
var flashlight_taken := false
var mobile := false
## World-space route for the stranger: from the middle of the road, along the footpath, up the steps, inside.
var route_in: Array[Vector3] = []
## The road sample index where the footpath leaves the road.
var road_index := 0
## 0.11: the dike to the scarecrow: road centre, verge, the islet's edge, the islet's centre (empty without one).
var crow_route: Array[Vector3] = []
var crow_index := -1
## The box of rounds, half-buried behind the scarecrow until the stranger digs it up.
var ammo_box: Node3D
var candle_light: OmniLight3D
var _flame: MeshInstance3D
var _key: Node3D
var _drawer: Node3D
var _gun: Node3D
var _gun_body: StaticBody3D
var _drawer_front: StaticBody3D
var _torch: Node3D
var _torch_body: StaticBody3D
var _colliders: StaticBody3D
var _mats := {}
var _t := 0.0
var _sfx: AudioStreamPlayer3D

static func attach(fields_root: Node3D) -> InteriorHutHouse:
	if fields_root == null:
		return null
	var kubo_node := fields_root.find_child("BahayKubo", true, false) as Node3D
	if kubo_node == null:
		return null
	var hut := InteriorHutHouse.new()
	hut.name = "HutHouse"
	hut.kubo = kubo_node
	hut.fields = fields_root
	fields_root.add_child(hut)
	return hut

func _ready() -> void:
	add_to_group("hut_house")
	mobile = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	# Turn the hut so its doorway (local +X) faces the road (it faced along the road before).
	var road := _road_samples()
	var hut_xz := Vector2(kubo.global_position.x, kubo.global_position.z)
	road_index = _nearest(road, hut_xz)
	var to_road := (road[road_index] - hut_xz).normalized()
	var yaw := atan2(-to_road.y, to_road.x)  # local +X -> to_road
	kubo.global_rotation = Vector3(0, yaw, 0)
	global_transform = kubo.global_transform
	_materials()
	_colliders = StaticBody3D.new()
	_colliders.name = "HutColliders"
	_colliders.collision_layer = 2
	_colliders.collision_mask = 5
	add_child(_colliders)
	_move_lantern()
	_shell()
	_steps()
	_furniture()
	_dresser()
	_candle()
	_key_on_top()
	_footpath(road)
	_scarecrow_dike()
	_clear_approach()
	_hide_ammo_box()
	_sfx = AudioStreamPlayer3D.new()
	_sfx.name = "HutSfx"
	_sfx.unit_size = 3.0
	_sfx.max_distance = 30.0
	_sfx.position = Vector3(BACK + .5, FLOOR + 1.0, DOOR_Z)
	add_child(_sfx)

func _road_samples() -> PackedVector2Array:
	return fields.get_meta("road_samples") if fields.has_meta("road_samples") else PackedVector2Array([Vector2(12, 150)])

static func _nearest(points: PackedVector2Array, p: Vector2) -> int:
	var best := 0
	var best_d := INF
	for i in points.size():
		var d := points[i].distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best

# ---------------------------------------------------------------- materials and helpers

func _tex_mat(key: String, albedo: String, normal: String, rough: String, tile: float, tint: Color, roughness := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = "Hut / " + key
	m.albedo_texture = load(albedo)
	m.albedo_color = tint
	if normal != "" and ResourceLoader.exists(normal):
		m.normal_enabled = true
		m.normal_texture = load(normal)
	if rough != "" and ResourceLoader.exists(rough):
		m.roughness_texture = load(rough)
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.roughness = roughness
	m.uv1_triplanar = true
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE / tile
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats[key] = m
	return m

func _flat(key: String, color: Color, roughness := .8, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = "Hut / " + key
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	_mats[key] = m
	return m

func _materials() -> void:
	var outdoor := "res://assets/outdoor/textures/"
	var mats := "res://assets/materials/"
	_tex_mat("wall planks", outdoor + "dark_wooden_planks/albedo.jpg", outdoor + "dark_wooden_planks/normal.jpg", outdoor + "dark_wooden_planks/roughness.jpg", 1.4, Color(.78, .66, .54))
	_tex_mat("floor planks", mats + "oak_slat_color.jpg", mats + "oak_slat_normal.png", mats + "oak_slat_roughness.jpg", 1.1, Color(.5, .38, .28), .8)
	_tex_mat("walnut", mats + "walnut_color.jpg", mats + "walnut_normal.png", mats + "walnut_roughness.jpg", .6, Color(.62, .5, .4), .85)
	(_mats["walnut"] as StandardMaterial3D).metallic_specular = .12
	_tex_mat("rough wood", mats + "oak_color.jpg", mats + "oak_normal.png", mats + "oak_roughness.jpg", .8, Color(.55, .43, .32), .85)
	_tex_mat("mat weave", "res://assets/surfaces/brown_weave_color.jpg", "res://assets/surfaces/brown_weave_normal.png", "res://assets/surfaces/brown_weave_roughness.jpg", .35, Color(.9, .8, .62))
	_tex_mat("bamboo", mats + "bamboo_color.jpg", mats + "bamboo_normal.png", mats + "bamboo_roughness.jpg", .5, Color(.85, .78, .6))
	_tex_mat("cloth", mats + "fabric_micro_color.jpg", mats + "fabric_micro_normal.png", mats + "fabric_micro_roughness.jpg", .2, Color(.62, .1, .08))
	_tex_mat("pillow", mats + "fabric_micro_color.jpg", mats + "fabric_micro_normal.png", mats + "fabric_micro_roughness.jpg", .2, Color(.78, .74, .66))
	_tex_mat("sack", mats + "fabric_micro_color.jpg", mats + "fabric_micro_normal.png", mats + "fabric_micro_roughness.jpg", .3, Color(.62, .52, .36))
	_tex_mat("clay", mats + "terracotta_color.jpg", mats + "terracotta_normal.png", mats + "terracotta_roughness.jpg", .4, Color(.8, .55, .4))
	_tex_mat("path", outdoor + "brown_mud_02/albedo.jpg", outdoor + "brown_mud_02/normal.jpg", outdoor + "brown_mud_02/roughness.jpg", 1.3, Color(.62, .56, .45))
	_tex_mat("path bank", outdoor + "brown_mud_02/albedo.jpg", outdoor + "brown_mud_02/normal.jpg", outdoor + "brown_mud_02/roughness.jpg", 2.0, Color(.5, .46, .42), .6)
	for key in ["path", "path bank"]:
		(_mats[key] as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
		(_mats[key] as StandardMaterial3D).normal_scale = .45
	_flat("brass", Color(.78, .6, .26), .32, 1.0)
	_flat("dark brass", Color(.45, .34, .16), .45, 1.0)
	_flat("iron", Color(.08, .08, .085), .5, .8)
	_flat("glass", Color(.42, .5, .44), .15)
	_flat("wax", Color(.93, .88, .76), .55)
	_flat("wick", Color(.05, .04, .03), .9)
	_flat("tin", Color(.6, .6, .58), .4, .9)
	var flame := StandardMaterial3D.new()
	flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.albedo_color = Color(1.0, .78, .42)
	flame.emission_enabled = true
	flame.emission = Color(1.0, .62, .25)
	flame.emission_energy_multiplier = 4.0
	_mats["flame"] = flame

## A box in the hut's frame (or under `parent`): min corner `lo`, max corner `hi`.
func _box(parent: Node3D, label: String, lo: Vector3, hi: Vector3, mat: String, collide := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var box := BoxMesh.new()
	box.size = (hi - lo).abs()
	mesh.mesh = box
	mesh.material_override = _mats[mat]
	mesh.layers = OUTDOOR_LAYER
	parent.add_child(mesh, true)
	mesh.position = (lo + hi) * .5
	if collide:
		_solid(label, (lo + hi) * .5, (hi - lo).abs())
	return mesh

func _solid(label: String, center: Vector3, size: Vector3, basis := Basis.IDENTITY, body: CollisionObject3D = null) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = label.validate_node_name()
	collision.shape = shape
	(body if body != null else _colliders).add_child(collision, true)
	collision.transform = Transform3D(basis, center)
	return collision

func _cylinder(parent: Node3D, label: String, at: Vector3, radius: float, height: float, mat: String, top_radius := -1.0, segments := 24) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var c := CylinderMesh.new()
	c.bottom_radius = radius
	c.top_radius = radius if top_radius < 0.0 else top_radius
	c.height = height
	c.radial_segments = segments
	c.rings = 1
	mesh.mesh = c
	mesh.material_override = _mats[mat]
	mesh.layers = OUTDOOR_LAYER
	parent.add_child(mesh, true)
	mesh.position = at + Vector3.UP * height * .5
	return mesh

# ---------------------------------------------------------------- the hut

func _move_lantern() -> void:
	# The lantern hung in the air 3.4 m out from the hut; now it hangs from a hook under the eave, beside the door.
	var at := global_transform * Vector3(2.22, 1.62, DOOR_Z1 + .55)
	var hook := global_transform * Vector3(2.22, 2.36, DOOR_Z1 + .55)
	for item in [["HutLantern", 0.0], ["HutLanternLight", .2], ["HutLanternFlame", .17]]:
		var node := fields.find_child(item[0], true, false) as Node3D
		if node != null:
			node.global_position = at + Vector3.UP * float(item[1])
	var cord := MeshInstance3D.new()
	cord.name = "Lantern cord"
	var c := CylinderMesh.new()
	c.top_radius = .006
	c.bottom_radius = .006
	c.height = hook.y - at.y - .28
	cord.mesh = c
	cord.material_override = _mats["iron"]
	cord.layers = OUTDOOR_LAYER
	add_child(cord)
	cord.global_position = Vector3(at.x, (hook.y + at.y + .28) * .5, at.z)

func _shell() -> void:
	var lining := Node3D.new()
	lining.name = "Lining"
	add_child(lining)
	var t := .018
	# Floor boards over the hut's own slats, and its collider.
	_box(lining, "Floor boards", Vector3(BACK, FLOOR - .01, SIDE_NEG), Vector3(FRONT, FLOOR + .012, SIDE_POS), "floor planks")
	_solid("Floor", Vector3((BACK + FRONT + .12) * .5, FLOOR - .2, (SIDE_NEG + SIDE_POS) * .5), Vector3(FRONT - BACK + .12, .42, SIDE_POS - SIDE_NEG))
	var top := DOOR_TOP - .02
	# Back wall and the two side walls: plank lining just inside the hut's own walls.
	_box(lining, "Back wall", Vector3(BACK, FLOOR, SIDE_NEG), Vector3(BACK + t, top, SIDE_POS), "wall planks")
	_box(lining, "Side wall +z", Vector3(BACK, FLOOR, SIDE_POS - t), Vector3(FRONT, top, SIDE_POS), "wall planks")
	_box(lining, "Side wall -z", Vector3(BACK, FLOOR, SIDE_NEG), Vector3(FRONT, top, SIDE_NEG + t), "wall planks")
	# Door wall, around the doorway and the window.
	var x0 := FRONT - t
	_box(lining, "Door wall a", Vector3(x0, FLOOR, SIDE_NEG), Vector3(FRONT, top, DOOR_Z0 - .02), "wall planks")
	_box(lining, "Door wall b", Vector3(x0, FLOOR, DOOR_Z1 + .02), Vector3(FRONT, top, WINDOW_Z.x), "wall planks")
	_box(lining, "Door wall c", Vector3(x0, FLOOR, WINDOW_Z.y), Vector3(FRONT, top, SIDE_POS), "wall planks")
	_box(lining, "Under window", Vector3(x0, FLOOR, WINDOW_Z.x), Vector3(FRONT, WINDOW_Y.x, WINDOW_Z.y), "wall planks")
	_box(lining, "Over window", Vector3(x0, WINDOW_Y.y, WINDOW_Z.x), Vector3(FRONT, top, WINDOW_Z.y), "wall planks")
	# Skirting, corner posts and a beam along the top of the walls.
	for z in [SIDE_NEG + t, SIDE_POS - t - .07]:
		_box(lining, "Corner post", Vector3(BACK + t, FLOOR, z), Vector3(BACK + t + .07, top, z + .07), "rough wood")
		_box(lining, "Corner post", Vector3(FRONT - t - .07, FLOOR, z), Vector3(FRONT - t, top, z + .07), "rough wood")
	_box(lining, "Wall plate", Vector3(BACK + t, top - .09, SIDE_NEG + t), Vector3(BACK + t + .06, top, SIDE_POS - t), "rough wood")
	_box(lining, "Wall plate", Vector3(BACK, top - .09, SIDE_POS - t - .06), Vector3(FRONT, top, SIDE_POS - t), "rough wood")
	_box(lining, "Wall plate", Vector3(BACK, top - .09, SIDE_NEG + t), Vector3(FRONT, top, SIDE_NEG + t + .06), "rough wood")
	# Door frame: jambs and lintel.
	_box(lining, "Door jamb", Vector3(FRONT - .06, FLOOR, DOOR_Z0 - .05), Vector3(FRONT + .03, DOOR_TOP, DOOR_Z0), "rough wood")
	_box(lining, "Door jamb", Vector3(FRONT - .06, FLOOR, DOOR_Z1), Vector3(FRONT + .03, DOOR_TOP, DOOR_Z1 + .05), "rough wood")
	_box(lining, "Threshold", Vector3(FRONT - .06, FLOOR, DOOR_Z0 - .05), Vector3(FRONT + .1, FLOOR + .03, DOOR_Z1 + .05), "rough wood")
	# Ceiling joists across the room.
	for k in 4:
		var x := lerpf(BACK + .45, FRONT - .45, k / 3.0)
		_box(lining, "Joist", Vector3(x - .04, top + .02, SIDE_NEG), Vector3(x + .04, top + .12, SIDE_POS), "rough wood")
	# Walls (colliders): the hut's walls with the doorway left open.
	var h := DOOR_TOP + .4
	_solid("Back wall", Vector3(BACK - .06, FLOOR + h * .5, (SIDE_NEG + SIDE_POS) * .5), Vector3(.12, h, SIDE_POS - SIDE_NEG + .3))
	_solid("Side wall +z", Vector3((BACK + FRONT) * .5, FLOOR + h * .5, SIDE_POS + .06), Vector3(FRONT - BACK + .3, h, .12))
	_solid("Side wall -z", Vector3((BACK + FRONT) * .5, FLOOR + h * .5, SIDE_NEG - .06), Vector3(FRONT - BACK + .3, h, .12))
	_solid("Door wall a", Vector3(FRONT + .06, FLOOR + h * .5, (SIDE_NEG - .15 + DOOR_Z0) * .5), Vector3(.12, h, DOOR_Z0 - SIDE_NEG + .15))
	_solid("Door wall b", Vector3(FRONT + .06, FLOOR + h * .5, (DOOR_Z1 + SIDE_POS + .15) * .5), Vector3(.12, h, SIDE_POS + .15 - DOOR_Z1))
	_solid("Lintel", Vector3(FRONT + .06, DOOR_TOP + .3, DOOR_Z), Vector3(.12, .6, DOOR_Z1 - DOOR_Z0))
	# The hut's posts and the yard around it.
	_solid("Yard", Vector3(0, -.34, 0), Vector3(YARD * 2.0, .7, YARD * 2.0))

func _steps() -> void:
	var steps := Node3D.new()
	steps.name = "Steps"
	add_child(steps)
	var z0 := DOOR_Z0 - .12
	var z1 := DOOR_Z1 + .12
	_box(steps, "Step 1", Vector3(2.35, .0, z0), Vector3(2.68, .15, z1), "rough wood")
	_box(steps, "Step 2", Vector3(2.0, .0, z0), Vector3(2.36, .29, z1), "rough wood")
	_box(steps, "Landing", Vector3(FRONT, .0, z0), Vector3(2.01, FLOOR - .01, z1), "rough wood")
	for z in [z0 - .04, z1]:
		_box(steps, "Stringer", Vector3(FRONT, .0, z), Vector3(2.7, .1, z + .04), "rough wood")
	# One ramp collider from the yard to the floor: the capsule walks up it like stairs. Its top runs from the
	# floor's top (just inside the doorway, so there is no lip) down to the yard.
	# The floor collider ends at FRONT + 0.12 (under the door wall): the ramp starts exactly on that edge.
	var top_in := Vector2(FRONT + .12, FLOOR + .012)
	var top_out := Vector2(2.9, .01)
	var along := top_out - top_in
	var slope := atan2(-along.y, along.x)
	var basis := Basis(Vector3.BACK, -slope)
	var thick := .12
	var mid := (top_in + top_out) * .5 + Vector2(-sin(slope), -cos(slope)) * thick * .5
	_solid("Steps ramp", Vector3(mid.x, mid.y, DOOR_Z), Vector3(along.length(), thick, z1 - z0), basis)

func _furniture() -> void:
	var room := Node3D.new()
	room.name = "Furniture"
	add_child(room)
	# A woven sleeping mat along the +z wall, a pillow and a folded blanket.
	_box(room, "Sleeping mat", Vector3(-.95, FLOOR + .012, .98), Vector3(.95, FLOOR + .02, 1.62), "mat weave")
	var pillow := MeshInstance3D.new()
	pillow.name = "Pillow"
	var capsule := CapsuleMesh.new()
	capsule.radius = .1
	capsule.height = .5
	pillow.mesh = capsule
	pillow.material_override = _mats["pillow"]
	pillow.layers = OUTDOOR_LAYER
	room.add_child(pillow)
	pillow.transform = Transform3D(Basis(Vector3.RIGHT, PI * .5).scaled(Vector3(1, 1, .45)), Vector3(-.78, FLOOR + .065, 1.3))
	_box(room, "Folded blanket", Vector3(.55, FLOOR + .02, 1.1), Vector3(.88, FLOOR + .09, 1.52), "cloth")
	# A low table with a clay cup and a tin plate, and a stool.
	var tx := .25
	var tz := -1.2
	_box(room, "Table top", Vector3(tx - .32, FLOOR + .36, tz - .23), Vector3(tx + .32, FLOOR + .4, tz + .23), "walnut", true)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_box(room, "Table leg", Vector3(tx + sx * .27 - .025, FLOOR, tz + sz * .18 - .025), Vector3(tx + sx * .27 + .025, FLOOR + .36, tz + sz * .18 + .025), "walnut")
	_cylinder(room, "Clay cup", Vector3(tx + .12, FLOOR + .4, tz - .05), .035, .08, "clay", .04)
	_cylinder(room, "Tin plate", Vector3(tx - .1, FLOOR + .4, tz + .03), .1, .012, "tin", .11)
	_cylinder(room, "Stool seat", Vector3(tx + .62, FLOOR + .32, tz + .05), .16, .04, "rough wood")
	for k in 3:
		var a := TAU * k / 3.0
		_box(room, "Stool leg", Vector3(tx + .62 + cos(a) * .1 - .02, FLOOR, tz + .05 + sin(a) * .1 - .02), Vector3(tx + .62 + cos(a) * .1 + .02, FLOOR + .32, tz + .05 + sin(a) * .1 + .02), "rough wood")
	_solid("Stool", Vector3(tx + .62, FLOOR + .18, tz + .05), Vector3(.32, .36, .32))
	# A shelf on the -z wall with jars and a folded cloth.
	_box(room, "Shelf", Vector3(-.9, FLOOR + 1.22, SIDE_NEG + .02), Vector3(.2, FLOOR + 1.25, SIDE_NEG + .24), "rough wood")
	for sx in [-.8, .1]:
		_box(room, "Shelf bracket", Vector3(sx - .015, FLOOR + 1.08, SIDE_NEG + .02), Vector3(sx + .015, FLOOR + 1.22, SIDE_NEG + .2), "rough wood")
	_cylinder(room, "Jar", Vector3(-.72, FLOOR + 1.25, SIDE_NEG + .13), .05, .16, "glass", .045)
	_cylinder(room, "Jar lid", Vector3(-.72, FLOOR + 1.41, SIDE_NEG + .13), .046, .02, "tin")
	_cylinder(room, "Jar", Vector3(-.56, FLOOR + 1.25, SIDE_NEG + .13), .04, .12, "glass", .036)
	_cylinder(room, "Clay pot", Vector3(-.3, FLOOR + 1.25, SIDE_NEG + .13), .06, .1, "clay", .045)
	_box(room, "Folded cloth", Vector3(-.12, FLOOR + 1.25, SIDE_NEG + .04), Vector3(.12, FLOOR + 1.31, SIDE_NEG + .22), "pillow")
	# A big water jar with a wooden lid by the door, and two sacks in the far corner.
	_cylinder(room, "Water jar", Vector3(1.3, FLOOR, 1.32), .17, .2, "clay", .23)
	_cylinder(room, "Water jar top", Vector3(1.3, FLOOR + .2, 1.32), .23, .2, "clay", .13)
	_cylinder(room, "Water jar lid", Vector3(1.3, FLOOR + .4, 1.32), .15, .025, "rough wood")
	_solid("Water jar", Vector3(1.3, FLOOR + .21, 1.32), Vector3(.44, .42, .44))
	for k in 2:
		var sack := MeshInstance3D.new()
		sack.name = "Sack"
		var s := CapsuleMesh.new()
		s.radius = .2
		s.height = .62
		sack.mesh = s
		sack.material_override = _mats["sack"]
		sack.layers = OUTDOOR_LAYER
		room.add_child(sack)
		# Lying down, slumped: a long squashed capsule.
		var lying := Basis(Vector3.UP, .25 + k * .5) * Basis(Vector3.RIGHT, PI * .5)
		sack.transform = Transform3D(lying.scaled(Vector3(.95, 1.0, .62)), Vector3(-1.4 + k * .06, FLOOR + .13 + k * .22, 1.3 - k * .05))
	_solid("Sacks", Vector3(-1.38, FLOOR + .25, 1.25), Vector3(.5, .5, .8))
	# A bamboo pole for hanging clothes, with a shirt on it.
	_cylinder(room, "Clothes pole", Vector3(.3, FLOOR + 1.75, SIDE_POS - .12), .018, 1.4, "bamboo").rotation = Vector3(0, 0, PI * .5)
	_box(room, "Shirt", Vector3(.05, FLOOR + 1.12, SIDE_POS - .14), Vector3(.5, FLOOR + 1.74, SIDE_POS - .1), "sack").rotation.y = .04

# ---------------------------------------------------------------- the dresser, its drawer and the gun

const DRESSER_W := 1.0
const DRESSER_D := .46
const DRESSER_H := .84
var _dresser_x := 0.0      # front face x
var _drawer_closed := Vector3.ZERO

func _dresser() -> void:
	var d := Node3D.new()
	d.name = "Dresser"
	add_child(d)
	var back := BACK + .02
	var front := back + DRESSER_D
	_dresser_x = front
	var z0 := DOOR_Z - DRESSER_W * .5
	var z1 := DOOR_Z + DRESSER_W * .5
	var f := FLOOR
	var side := .025
	_box(d, "Plinth", Vector3(back, f, z0 + .02), Vector3(front - .02, f + .06, z1 - .02), "walnut")
	_box(d, "Side", Vector3(back, f, z0), Vector3(front, f + DRESSER_H - .03, z0 + side), "walnut")
	_box(d, "Side", Vector3(back, f, z1 - side), Vector3(front, f + DRESSER_H - .03, z1), "walnut")
	_box(d, "Back", Vector3(back, f + .06, z0), Vector3(back + .012, f + DRESSER_H - .03, z1), "walnut")
	_box(d, "Top", Vector3(back - .005, f + DRESSER_H - .03, z0 - .015), Vector3(front + .02, f + DRESSER_H, z1 + .015), "walnut")
	_box(d, "Shelf", Vector3(back, f + .565, z0 + side), Vector3(front - .02, f + .578, z1 - side), "walnut")
	# Body collider (stops short of the front, where the drawers have their own).
	_solid("Dresser", Vector3((back + front - .03) * .5, f + DRESSER_H * .5, DOOR_Z), Vector3(front - .03 - back, DRESSER_H, DRESSER_W + .03))
	# The two lower drawers are fixed fronts.
	for k in 2:
		var y0 := f + .065 + k * .252
		_box(d, "Drawer front", Vector3(front - .02, y0, z0 + side + .003), Vector3(front, y0 + .245, z1 - side - .003), "walnut")
		for kz in [-.28, .28]:
			_knob(d, Vector3(front, y0 + .122, DOOR_Z + kz))
	# The top drawer: a real tray that slides out.
	_drawer = Node3D.new()
	_drawer.name = "TopDrawer"
	d.add_child(_drawer)
	_drawer_closed = Vector3(front, f + .582, DOOR_Z)
	_drawer.position = _drawer_closed
	var w := DRESSER_W * .5 - side - .004
	var depth := DRESSER_D - .05
	_box(_drawer, "Drawer front", Vector3(-.02, 0, -w), Vector3(0, .222, w), "walnut")
	_box(_drawer, "Drawer bottom", Vector3(-depth, .015, -w + .01), Vector3(-.02, .025, w - .01), "rough wood")
	_box(_drawer, "Drawer back", Vector3(-depth, .015, -w + .01), Vector3(-depth + .012, .17, w - .01), "rough wood")
	_box(_drawer, "Drawer side", Vector3(-depth, .015, -w + .01), Vector3(-.02, .17, -w + .022), "rough wood")
	_box(_drawer, "Drawer side", Vector3(-depth, .015, w - .022), Vector3(-.02, .17, w - .01), "rough wood")
	for kz in [-.28, .28]:
		_knob(_drawer, Vector3(0, .111, kz))
	# Brass keyhole escutcheon.
	var plate := _cylinder(_drawer, "Keyhole plate", Vector3(.004, .111, 0), .022, .006, "dark brass")
	plate.rotation = Vector3(0, 0, PI * .5)
	plate.position = Vector3(.003, .111, 0)
	_box(_drawer, "Keyhole", Vector3(.004, .098, -.003), Vector3(.0075, .118, .003), "iron")
	# The drawer front's own collider (it moves with the drawer); its parent is what the player uses.
	var usable_drawer := InteriorHutUsable.new()
	usable_drawer.name = "DrawerUse"
	usable_drawer.hut = self
	usable_drawer.kind = "drawer"
	_drawer.add_child(usable_drawer)
	_drawer_front = StaticBody3D.new()
	_drawer_front.name = "DrawerBody"
	_drawer_front.collision_layer = 2
	_drawer_front.collision_mask = 0
	usable_drawer.add_child(_drawer_front)
	_solid("Drawer front", Vector3(-.012, .111, 0), Vector3(.03, .222, w * 2.0), Basis.IDENTITY, _drawer_front)
	# A red cloth in the tray, the gun on it, lying on its side.
	_box(_drawer, "Cloth", Vector3(-.26, .025, -.2), Vector3(-.04, .033, .2), "cloth")
	_gun = GLOCK.instantiate() as Node3D
	_gun.name = "Glock"
	_drawer.add_child(_gun)
	for node in _gun.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).layers = OUTDOOR_LAYER
	# Model: length along local Z (muzzle +Z), height along Y, thickness X. Lay it on its left side, grip toward
	# the drawer front, muzzle pointing along the drawer.
	_gun.transform = Transform3D(Basis(Vector3.FORWARD, -PI * .5) * Basis(Vector3.UP, .0), Vector3(-.13, .047, .02))
	_gun_body = StaticBody3D.new()
	_gun_body.name = "GunBody"
	_gun_body.collision_layer = 2
	_gun_body.collision_mask = 0
	var usable_gun := InteriorHutUsable.new()
	usable_gun.name = "GunUse"
	usable_gun.hut = self
	usable_gun.kind = "gun"
	_drawer.add_child(usable_gun)
	usable_gun.add_child(_gun_body)
	_solid("Gun", Vector3(-.13, .06, .02), Vector3(.16, .06, .22), Basis.IDENTITY, _gun_body)
	_gun_body.process_mode = Node.PROCESS_MODE_DISABLED  # only once the drawer is open
	# 0.12: the flashlight, on the tray beside the cloth, lens toward the far side, parallel to the gun.
	var torch_at := Vector3(-.17, .025 + .0205, -.335)
	_torch = InteriorFlashlight.make_model(OUTDOOR_LAYER)
	_torch.name = "Flashlight"
	_drawer.add_child(_torch)
	_torch.transform = Transform3D(Basis(Vector3.FORWARD, .35), torch_at)
	var usable_torch := InteriorHutUsable.new()
	usable_torch.name = "FlashlightUse"
	usable_torch.hut = self
	usable_torch.kind = "flashlight"
	_drawer.add_child(usable_torch)
	_torch_body = StaticBody3D.new()
	_torch_body.name = "FlashlightBody"
	_torch_body.collision_layer = 2
	_torch_body.collision_mask = 0
	usable_torch.add_child(_torch_body)
	_solid("Flashlight", torch_at + Vector3(0, .01, 0), Vector3(.075, .06, InteriorFlashlight.LENGTH + .02), Basis.IDENTITY, _torch_body)
	_torch_body.process_mode = Node.PROCESS_MODE_DISABLED

func _knob(parent: Node3D, at: Vector3) -> void:
	var knob := MeshInstance3D.new()
	knob.name = "Knob"
	var s := SphereMesh.new()
	s.radius = .016
	s.height = .026
	knob.mesh = s
	knob.material_override = _mats["walnut"]
	knob.layers = OUTDOOR_LAYER
	parent.add_child(knob)
	knob.position = at + Vector3(.012, 0, 0)

func _candle() -> void:
	var top := FLOOR + DRESSER_H
	var at := Vector3(BACK + .24, top, DOOR_Z + .3)
	var c := Node3D.new()
	c.name = "Candle"
	add_child(c)
	_cylinder(c, "Candle dish", at, .05, .012, "dark brass", .055)
	_cylinder(c, "Candle", at + Vector3(0, .012, 0), .019, .1, "wax", .018, 16)
	_cylinder(c, "Wax drip", at + Vector3(.008, .012, .01), .012, .05, "wax", .006, 8)
	_cylinder(c, "Wick", at + Vector3(0, .112, 0), .0016, .012, "wick", -1.0, 6)
	_flame = MeshInstance3D.new()
	_flame.name = "Candle flame"
	var s := SphereMesh.new()
	s.radius = .007
	s.height = .014
	_flame.mesh = s
	_flame.material_override = _mats["flame"]
	# A soft, shadowless bounce of the candle low in the room, so the open drawer under the dresser top isn't black.
	var bounce := OmniLight3D.new()
	bounce.name = "CandleBounce"
	bounce.light_color = Color(1.0, .66, .42)
	bounce.light_energy = .55
	bounce.light_specular = .15
	bounce.omni_range = 2.6
	bounce.omni_attenuation = 1.0
	bounce.light_cull_mask = OUTDOOR_LAYER
	bounce.shadow_enabled = false
	c.add_child(bounce)
	bounce.position = Vector3(BACK + .95, FLOOR + 1.15, DOOR_Z)
	_flame.layers = OUTDOOR_LAYER
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.add_child(_flame)
	_flame.position = at + Vector3(0, .133, 0)
	_flame.scale = Vector3(1, 2.4, 1)
	candle_light = OmniLight3D.new()
	candle_light.name = "CandleLight"
	candle_light.light_color = Color(1.0, .7, .45)
	candle_light.light_energy = 1.15
	candle_light.light_specular = .3
	candle_light.omni_range = 6.0
	candle_light.omni_attenuation = 1.25
	candle_light.light_cull_mask = OUTDOOR_LAYER
	candle_light.shadow_enabled = not mobile
	candle_light.shadow_bias = .04
	candle_light.distance_fade_enabled = true
	candle_light.distance_fade_begin = 50.0
	candle_light.distance_fade_length = 15.0
	c.add_child(candle_light)
	candle_light.position = at + Vector3(.04, .24, .0)

func _key_on_top() -> void:
	var top := FLOOR + DRESSER_H
	_key = InteriorHutUsable.new()
	_key.name = "Key"
	(_key as InteriorHutUsable).hut = self
	(_key as InteriorHutUsable).kind = "key"
	add_child(_key)
	_key.position = Vector3(BACK + .32, top + .004, DOOR_Z - .2)
	_key.rotation.y = .5
	var ring := MeshInstance3D.new()
	ring.name = "Key ring"
	var torus := TorusMesh.new()
	torus.inner_radius = .009
	torus.outer_radius = .015
	torus.rings = 24
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = _mats["brass"]
	ring.layers = OUTDOOR_LAYER
	_key.add_child(ring)
	ring.scale = Vector3(1, .5, 1)
	ring.position = Vector3(0, .003, 0)
	var shaft := _cylinder(_key, "Key shaft", Vector3.ZERO, .0032, .05, "brass", -1.0, 10)
	shaft.rotation = Vector3(0, 0, PI * .5)
	shaft.position = Vector3(.039, .003, 0)
	_box(_key, "Key bit", Vector3(.052, .0005, .002), Vector3(.064, .0055, .014), "brass")
	# 0.59: the story's pickups shine like co-op's (scripts/pickup_shine.gd); the key keeps its own sparkles (below)
	# instead of the twinkle.
	Shine.apply(_key, false)
	_box(_key, "Key bit", Vector3(.056, .0005, .012), Vector3(.06, .0055, .018), "brass")
	var body := StaticBody3D.new()
	body.name = "KeyBody"
	body.collision_layer = 2
	body.collision_mask = 0
	_key.add_child(body)
	_solid("Key", Vector3(.03, .03, 0), Vector3(.14, .07, .1), Basis.IDENTITY, body)
	# Sparkles: a few twinkling stars over the key.
	for k in 4:
		var star := MeshInstance3D.new()
		star.name = "Sparkle"
		var quad := QuadMesh.new()
		quad.size = Vector2(.11, .11) if k == 0 else Vector2(.06, .06)
		star.mesh = quad
		var mat := ShaderMaterial.new()
		mat.shader = SPARKLE_SHADER
		mat.set_shader_parameter("phase", k * .29)
		mat.set_shader_parameter("speed", 1.0 + k * .23)
		star.material_override = mat
		star.layers = OUTDOOR_LAYER
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_key.add_child(star)
		star.position = Vector3([.035, .0, .06, .02][k], [.03, .05, .02, .07][k], [0.0, .02, -.015, -.02][k])

# ---------------------------------------------------------------- the path from the road

func _footpath(road: PackedVector2Array) -> void:
	# 0.11: the causeway is made by scripts/footpath.gd, which also makes the dike out to the scarecrow.
	var door_out := global_transform * Vector3(2.75, 0, DOOR_Z)
	road_index = _nearest(road, Vector2(door_out.x, door_out.z))
	var yard_edge := global_transform * Vector3(YARD, 0, DOOR_Z)
	var path := InteriorFootpath.build(fields, road_index, yard_edge, PATH_HALF, GROUND - .14, _mats["path"], _mats["path bank"], "Footpath")
	# Yard edges, with the gap where the path arrives (local +X side).
	var h := 2.4
	_solid("Yard edge -x", Vector3(-YARD - .12, h * .5 - .5, 0), Vector3(.24, h, YARD * 2.0 + .5))
	_solid("Yard edge +z", Vector3(0, h * .5 - .5, YARD + .12), Vector3(YARD * 2.0 + .5, h, .24))
	_solid("Yard edge -z", Vector3(0, h * .5 - .5, -YARD - .12), Vector3(YARD * 2.0 + .5, h, .24))
	var gap0 := DOOR_Z - PATH_HALF - .1
	var gap1 := DOOR_Z + PATH_HALF + .1
	_solid("Yard edge +x", Vector3(YARD + .12, h * .5 - .5, (gap1 + YARD + .25) * .5), Vector3(.24, h, YARD + .25 - gap1))
	_solid("Yard edge +x", Vector3(YARD + .12, h * .5 - .5, (gap0 - YARD - .25) * .5), Vector3(.24, h, gap0 + YARD + .25))
	# The stranger's way in: road centre, the path, the steps, the doorway, inside.
	route_in.clear()
	route_in.append_array(path)
	for p in [Vector3(3.3, 0, DOOR_Z), Vector3(2.4, 0, DOOR_Z), Vector3(FRONT - .1, 0, DOOR_Z), Vector3(.7, 0, DOOR_Z)]:
		route_in.append(global_transform * p)

# ---------------------------------------------------------------- 0.11: the scarecrow's dike and the buried box

func _scarecrow_dike() -> void:
	if not fields.has_meta("scarecrow_index") or not fields.has_meta("scarecrow_islet"):
		return
	crow_index = int(fields.get_meta("scarecrow_index"))
	var islet: Vector3 = fields.get_meta("scarecrow_islet")
	crow_route = InteriorFootpath.build(fields, crow_index, islet, DIKE_HALF, GROUND - .16, _mats["path"], _mats["path bank"], "Scarecrow dike", ISLET_TOP)

## Clear the authored route, including foliage with no collider that still hides the ground/man.
func _clear_approach() -> void:
	var corridors: Array = [route_in.slice(0, 4), crow_route]
	var removed: Array[String] = []
	for node: Node in fields.find_children("*", "Node3D", true, false):
		if not node.has_meta("tree"):
			continue
		var bounds := InteriorModelKit.bounds_in(node, fields)
		var footprint := Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z))
		var obstructs := false
		for route: Array in corridors:
			for k in range(1, route.size()):
				var a: Vector3 = route[k - 1]
				var b: Vector3 = route[k]
				var steps := maxi(1, ceili(a.distance_to(b) / .4))
				for j in steps + 1:
					var p := a.lerp(b, float(j) / steps)
					if footprint.grow(1.35).has_point(Vector2(p.x, p.z)):
						obstructs = true
		# Remove the broad tree crowding the hut's turning area as well.
		if String(node.name) == "tree_small_02" and (node as Node3D).global_position.distance_to(global_position) < 12.0:
			obstructs = true
		if obstructs:
			removed.append(str(node.name))
			node.get_parent().remove_child(node)
			node.queue_free()
	# The widened ground must not have old rice/grass blades poking through its walking surface.
	# 0.34: only the patches of rice and grass that reach the routes are looked at, and each of those is read and
	# written as one buffer: asking every blade in the fields for its place one at a time took half a second.
	var segments: Array = []       # [a, b] on the ground
	var reach := Rect2()
	var any := false
	for route: Array in corridors:
		for k in range(1, route.size()):
			var a := Vector2((route[k - 1] as Vector3).x, (route[k - 1] as Vector3).z)
			var b := Vector2((route[k] as Vector3).x, (route[k] as Vector3).z)
			segments.append([a, b])
			for corner: Vector2 in [a, b]:
				reach = reach.expand(corner) if any else Rect2(corner, Vector2.ZERO)
				any = true
	var islet := Vector2(crow_route[-1].x, crow_route[-1].z) if not crow_route.is_empty() else Vector2.INF
	if islet.is_finite():
		reach = reach.expand(islet) if any else Rect2(islet, Vector2.ZERO)
		any = true
	reach = reach.grow(maxf(1.35, ISLET_TOP + .25) + .05)
	for mmi: MultiMeshInstance3D in fields.find_children("*", "MultiMeshInstance3D", true, false):
		var multimesh := mmi.multimesh
		if multimesh == null or not any or multimesh.transform_format != MultiMesh.TRANSFORM_3D:
			continue
		var place := mmi.global_transform
		var box := place * multimesh.get_aabb()
		if not reach.intersects(Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))):
			continue
		var buffer := multimesh.buffer
		var stride := 12 + (4 if multimesh.use_colors else 0) + (4 if multimesh.use_custom_data else 0)
		var changed := false
		for i in multimesh.instance_count:
			var at := i * stride
			var p := place * Vector3(buffer[at + 3], buffer[at + 7], buffer[at + 11])
			var flat := Vector2(p.x, p.z)
			if not reach.has_point(flat):
				continue
			var clear := islet.is_finite() and flat.distance_to(islet) < ISLET_TOP + .25
			if not clear:
				for segment: Array in segments:
					if Geometry2D.get_closest_point_to_segment(flat, segment[0], segment[1]).distance_to(flat) < 1.35:
						clear = true
						break
			if clear:
				buffer[at + 7] -= 12.0
				changed = true
		if changed:
			var own := multimesh.duplicate() as MultiMesh
			own.buffer = buffer
			mmi.multimesh = own
	set_meta("cleared_vegetation", removed)

## The islet's centre and the unit direction from it back to the road (xz).
func crow_frame() -> Array:
	if crow_route.size() < 4:
		return []
	var centre := crow_route[3]
	var to_road := crow_route[0] - centre
	to_road.y = 0.0
	return [centre, to_road.normalized()]

## Where the box lies: behind the scarecrow's post (on the side away from the road, so it can't be seen from there),
## half sunk into the mud and tilted.
func box_spot() -> Vector3:
	var frame := crow_frame()
	if frame.is_empty():
		return Vector3.INF
	var p: Vector3 = frame[0] - frame[1] * .55
	p.y = GROUND - .16 + .006
	return p

func _hide_ammo_box() -> void:
	var at := box_spot()
	if not at.is_finite():
		return
	ammo_box = make_ammo_box()
	ammo_box.name = "AmmoBox"
	fields.add_child(ammo_box)
	var frame := crow_frame()
	var to_road: Vector3 = frame[1]
	# Long side along the scarecrow's back, one end dug in.
	var yaw := atan2(to_road.x, to_road.z) + PI * .5 + .35
	ammo_box.global_transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, .22) * Basis(Vector3.RIGHT, -.12), at)
	ammo_box.add_to_group("ammo_box")

## The 9x19 mm box (assets/models/story/ammo_box.glb; a plain card box until that exists).
static func make_ammo_box() -> Node3D:
	var box: Node3D
	if ResourceLoader.exists(AMMO_BOX):
		box = (load(AMMO_BOX) as PackedScene).instantiate() as Node3D
	else:
		box = Node3D.new()
		var mesh := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(.12, .04, .075)
		mesh.mesh = b
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(.55, .52, .4)
		m.roughness = .9
		mesh.material_override = m
		box.add_child(mesh)
	for node in box.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).layers = OUTDOOR_LAYER
	return box

# ---------------------------------------------------------------- interaction

func is_inside(world: Vector3) -> bool:
	# (0.64: a phone's squad game lets go of the fields, hut and all; for its last frame it is out of the tree.)
	if not is_inside_tree():
		return false
	var p := global_transform.affine_inverse() * world
	return p.x > BACK - .1 and p.x < FRONT + .05 and p.z > SIDE_NEG - .1 and p.z < SIDE_POS + .1 and p.y > -.5 and p.y < 3.0

## Where the stranger stands to call the player out: in the yard, a few metres in front of the steps.
func call_spot() -> Vector3:
	return global_transform * Vector3(4.6, 0, DOOR_Z + .6)

func door_point() -> Vector3:
	return global_transform * Vector3(2.9, 0, DOOR_Z)

## The route from the call spot back to the road (reverse of the way in, without the inside points).
func route_out() -> Array[Vector3]:
	var out: Array[Vector3] = []
	out.append(global_transform * Vector3(YARD - .4, 0, DOOR_Z))
	for k in [2, 1, 0]:
		out.append(route_in[k])
	return out

func usable_prompt(kind: String) -> String:
	match kind:
		"key":
			return "Take the key"
		"drawer":
			if drawer_open:
				# The open drawer: aiming anywhere at it reaches the gun, then the flashlight.
				return usable_prompt("gun") if not gun_taken else usable_prompt("flashlight")
			return "Unlock the drawer" if has_key else "Locked drawer"
		"gun":
			return "Pick up the Glock" if drawer_open and not gun_taken else ""
		"flashlight":
			return "Pick up the flashlight" if drawer_open and not flashlight_taken else ""
	return ""

func use(kind: String) -> void:
	var story := get_tree().get_first_node_in_group("story")
	match kind:
		"key":
			if has_key:
				return
			has_key = true
			_play_sfx("res://assets/audio/sfx/key_pickup.ogg", _key.global_position)
			_key.queue_free()
			key_taken.emit()
		"drawer":
			if drawer_open:
				use("gun" if not gun_taken else "flashlight")
				return
			if not has_key:
				if story != null:
					story.notify("It's locked. There must be a key somewhere.")
				_play_sfx("res://assets/audio/sfx/impactMetal_light_000.ogg", _drawer.global_position, 1.6, -10.0)
				return
			_unlock_and_open()
		"gun":
			if drawer_open and not gun_taken:
				gun_requested.emit()
		"flashlight":
			if drawer_open and not flashlight_taken:
				flashlight_taken = true
				_play_sfx("res://assets/audio/sfx/key_pickup.ogg", _torch.global_position, .8)
				_torch.queue_free()
				_torch_body.get_parent().queue_free()
				flashlight_picked.emit()

func _unlock_and_open() -> void:
	drawer_open = true
	_play_sfx("res://assets/audio/sfx/lock_turn.ogg", _drawer.global_position)
	var tween := create_tween()
	tween.tween_interval(.65)
	tween.tween_callback(func(): _play_sfx("res://assets/audio/sfx/drawer_open.ogg", _drawer.global_position))
	tween.tween_property(_drawer, "position", _drawer_closed + Vector3(DRAWER_TRAVEL, 0, 0), 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		# (The debug menu can take either before the drawer opens.)
		if is_instance_valid(_gun_body):
			_gun_body.process_mode = Node.PROCESS_MODE_INHERIT
		if is_instance_valid(_torch_body):
			_torch_body.process_mode = Node.PROCESS_MODE_INHERIT
		# 0.59: what is in the drawer shines once it is open (shut, the twinkle would show through the front).
		if is_instance_valid(_gun) and not gun_taken:
			Shine.apply(_gun, true, Vector3(0, .06, 0), .16)
		if is_instance_valid(_torch) and not flashlight_taken:
			Shine.apply(_torch, true, Vector3(0, .05, 0), .14)
		drawer_opened.emit())

## Debug menu: the flashlight leaves the drawer without the pickup.
func remove_flashlight() -> void:
	flashlight_taken = true
	if is_instance_valid(_torch):
		_torch.queue_free()
	if is_instance_valid(_torch_body):
		_torch_body.get_parent().queue_free()

## The gun leaves the drawer (taken), or stays (put back).
func take_gun() -> void:
	gun_taken = true
	if is_instance_valid(_gun):
		_gun.queue_free()
	if is_instance_valid(_gun_body):
		_gun_body.get_parent().queue_free()

func _play_sfx(path: String, at: Vector3, pitch := 1.0, volume := 0.0) -> void:
	if not ResourceLoader.exists(path):
		return
	_sfx.stream = load(path)
	_sfx.global_position = at
	_sfx.pitch_scale = pitch
	_sfx.volume_db = volume
	_sfx.play()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	var n := sin(_t * 11.0) * .45 + sin(_t * 6.7 + 1.3) * .35 + sin(_t * 23.0 + .4) * .2
	if candle_light != null:
		candle_light.light_energy = 1.15 + n * .14
	if _flame != null:
		_flame.scale = Vector3(1.0 + n * .06, 2.4 + n * .3, 1.0 + n * .06)
