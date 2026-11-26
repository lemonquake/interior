class_name InteriorZombieGore
extends RefCounted
## 0.29: what a round can take off one of the infected (scripts/zombie.gd), and what is left where it was.
##
## A severed part is the same figure again with every bone but the part's own drawn in to the cut, so the arm, leg
## or head that falls is the one that was shot, in the clothes it wore, in the pose it had. It is a body of its own
## from then on: it drops, rolls, and bleeds for a while (scripts/blood.gd). Both sides of the cut get a stump: torn
## flesh round the end of the bone. A head that takes far more than it can hold does not come off whole: it comes
## apart, and `gib` is one of the pieces.

const SHRINK := .001

static var _meat: StandardMaterial3D
static var _bone: StandardMaterial3D
## 0.31: one mesh of each shape for every stump, crater and gib (they were made anew each time: a hitch per cut).
static var _shapes := {}
static var _gib_material: PhysicsMaterial
static var _gib_balls := {}

static func _shape(key: String) -> Mesh:
	if _shapes.has(key):
		return _shapes[key]
	var mesh: PrimitiveMesh
	match key:
		"dome":
			var half := SphereMesh.new()
			half.radius = 1.04
			half.height = .5
			half.is_hemisphere = true
			half.radial_segments = 10
			half.rings = 3
			mesh = half
		"rod":
			var rod := CylinderMesh.new()
			rod.top_radius = .2
			rod.bottom_radius = .27
			rod.height = 1.1
			rod.radial_segments = 7
			rod.rings = 1
			mesh = rod
		"cone":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 1.0
			cone.height = 1.0
			cone.radial_segments = 5
			cone.rings = 1
			mesh = cone
		_:
			var lump := SphereMesh.new()
			lump.radius = 1.0
			lump.height = 2.0
			lump.radial_segments = 6
			lump.rings = 3
			mesh = lump
	mesh.material = bone() if key == "rod" or key == "shard" else meat()
	_shapes[key] = mesh
	return mesh

static func _part(key: String, at: Vector3, size: Vector3, turn := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = _shape(key)
	instance.transform = Transform3D(Basis.from_euler(turn).scaled_local(size), at)
	instance.layers = 3
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance

## The collapsing modifier: every bone listed (and with it all that hangs from it) is drawn in to its own joint.
class Sever extends SkeletonModifier3D:
	var bones: PackedInt32Array = PackedInt32Array()

	func _process_modification() -> void:
		var skeleton := get_skeleton()
		if skeleton == null:
			return
		for id in bones:
			var pose := skeleton.get_bone_global_pose(id)
			pose.basis = Basis.IDENTITY.scaled(Vector3.ONE * SHRINK)
			skeleton.set_bone_global_pose(id, pose)

static func meat() -> StandardMaterial3D:
	if _meat == null:
		_meat = StandardMaterial3D.new()
		_meat.albedo_color = Color(.3, .018, .02)
		_meat.roughness = .2
		_meat.metallic_specular = .7
		var bumps := "res://assets/zombies/blood/splat_a_normal.png"
		if ResourceLoader.exists(bumps):
			_meat.normal_enabled = true
			_meat.normal_texture = load(bumps)
			_meat.normal_scale = 1.4
			_meat.uv1_triplanar = true
			_meat.uv1_scale = Vector3.ONE * 9.0
	return _meat

static func bone() -> StandardMaterial3D:
	if _bone == null:
		_bone = StandardMaterial3D.new()
		_bone.albedo_color = Color(.74, .66, .54)
		_bone.roughness = .45
	return _bone

## A basis whose Y is `y`.
static func facing(y: Vector3) -> Basis:
	var up := y.normalized()
	var x := up.cross(Vector3.FORWARD if absf(up.z) < .9 else Vector3.RIGHT).normalized()
	return Basis(x, up, x.cross(up))

## The end of a cut limb, +Y out of the wound: a dome of torn flesh, tatters round its edge, the bone standing out.
static func stump(radius: float) -> Node3D:
	var node := Node3D.new()
	node.name = "Stump"
	node.add_child(_part("dome", Vector3.ZERO, Vector3.ONE * radius))
	# Behind the cut too, so the drawn-in skin never shows an open end.
	node.add_child(_part("dome", Vector3.ZERO, Vector3(radius, radius * 1.8, radius), Vector3(PI, 0, 0)))
	node.add_child(_part("rod", Vector3(randf_range(-.1, .1) * radius, radius * .32, randf_range(-.1, .1) * radius), Vector3.ONE * radius,
		Vector3(randf_range(-.25, .25), 0, randf_range(-.25, .25))))
	for k in 5:
		var angle := TAU * (k + randf() * .7) / 5.0
		var wide := radius * randf_range(.2, .36)
		node.add_child(_part("cone", Vector3(cos(angle), .22, sin(angle)) * radius * Vector3(.72, 1.0, .72),
			Vector3(wide, radius * randf_range(.5, 1.1), wide), Vector3(sin(angle) * .7, 0, -cos(angle) * .7)))
	return node

## Where a piece was torn out of a part that is still on, +Y out of the wound: a hollow's worth of raw meat standing
## a little proud of the skin, ragged at the edge; in the trunk, the ends of ribs.
static func crater(radius: float, ribs: bool) -> Node3D:
	var node := Node3D.new()
	node.name = "Crater"
	node.add_child(_part("dome", Vector3.ZERO, Vector3(radius, radius * .55, radius * randf_range(.75, 1.0))))
	for k in 4:
		var angle := TAU * (k + randf() * .8) / 4.0
		var wide := radius * randf_range(.16, .3)
		node.add_child(_part("cone", Vector3(cos(angle), .12, sin(angle)) * radius * .8, Vector3(wide, radius * randf_range(.3, .7), wide),
			Vector3(sin(angle) * 1.0, 0, -cos(angle) * 1.0)))
	if ribs:
		for k in 2:
			node.add_child(_part("rod", Vector3(randf_range(-.3, .3), .16, (k - .5) * .7) * radius, Vector3(radius * .42, radius * 1.2, radius * .42),
				Vector3(0, randf_range(-.3, .3), PI * .5 + randf_range(-.2, .2))))
	return node

## The part of `zombie` that hangs from bone `id`, as a body of its own lying exactly where the part is now.
## `chain` is that bone and all below it; `radius` and `mass` are the part's.
static func piece(zombie: Node3D, scene: PackedScene, skeleton: Skeleton3D, bodies: Dictionary, id: int, chain: PackedInt32Array,
		radius: float, mass: float, holder: Node3D) -> RigidBody3D:
	# Where the part's bones are, in the figure's skeleton space: from the hit boxes (they are the ragdoll when it
	# is one, and follow the animation when it is not), and for the hand or the foot from the bone above.
	var to_skeleton := skeleton.global_transform.affine_inverse()
	var globals := {}
	for bone_id in chain:
		var body := bodies.get(skeleton.get_bone_name(bone_id)) as PhysicalBone3D
		var pose: Transform3D
		if body != null and is_instance_valid(body):
			pose = to_skeleton * body.global_transform * body.body_offset.affine_inverse()
		else:
			var parent := skeleton.get_bone_parent(bone_id)
			pose = (globals[parent] as Transform3D if globals.has(parent) else skeleton.get_bone_global_pose(parent)) * skeleton.get_bone_pose(bone_id)
		pose.basis = pose.basis.orthonormalized()
		globals[bone_id] = pose
	var root: Transform3D = globals[id]
	var world := skeleton.global_transform
	var cut := world * root.origin
	# The far end: the bone furthest from the cut, and a hand's or a head's length beyond it.
	var tip := cut
	for bone_id in chain:
		var pose: Transform3D = globals[bone_id]
		var end := world * (pose.origin + pose.basis.y * .1)
		if end.distance_to(cut) > tip.distance_to(cut):
			tip = end
	var along := tip - cut
	var length := maxf(along.length(), radius * 2.0)
	along = along.normalized() if along.length() > .01 else Vector3.UP
	var part := RigidBody3D.new()
	part.name = "Severed " + skeleton.get_bone_name(id)
	part.mass = mass
	part.collision_layer = 0
	part.collision_mask = 2 | 4
	part.linear_damp = .05
	part.angular_damp = 1.6
	part.continuous_cd = true
	var material := PhysicsMaterial.new()
	material.friction = .95
	material.bounce = .05
	part.physics_material_override = material
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = maxf(length, radius * 2.0 + .01)
	shape.shape = capsule
	part.add_child(shape)
	holder.add_child(part)
	part.global_transform = Transform3D(facing(along), cut + along * length * .5)
	part.add_to_group("zombie_parts")
	# The figure again, standing where the first one stands.
	var model := scene.instantiate() as Node3D
	model.name = "Model"
	part.add_child(model)
	var source := skeleton.get_parent() as Node3D
	var path: Array[Node3D] = []
	while source != null and source != zombie:
		path.push_front(source)
		source = source.get_parent() as Node3D
	# (The model node itself is the first of them: its transform, then the armature's, are the skeleton's parents'.)
	model.global_transform = path[0].global_transform if not path.is_empty() else skeleton.global_transform
	for player in model.find_children("*", "AnimationPlayer", true, false):
		player.free()
	var copy := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if copy != null:
		# Everything that is not the part is drawn in: to the cut, or (what had already come off below the part) to
		# the joint it came off at.
		var gone_at := {}
		for bone_id in copy.get_bone_count():
			if globals.has(bone_id):
				copy.set_bone_global_pose(bone_id, globals[bone_id])
				continue
			var parent := copy.get_bone_parent(bone_id)
			var at := root.origin
			if globals.has(parent):
				at = (globals[parent] as Transform3D * skeleton.get_bone_rest(bone_id)).origin
			elif gone_at.has(parent) and parent > id:
				at = gone_at[parent]
			gone_at[bone_id] = at
			copy.set_bone_global_pose(bone_id, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * SHRINK), at))
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).layers = 3
		# The skin's own bounds are the whole figure's: cull by the part instead.
		(mesh as MeshInstance3D).custom_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 4, 4))
	var cap := stump(radius * 1.1)
	part.add_child(cap)
	cap.transform = Transform3D(facing(Vector3.DOWN), Vector3(0, -length * .5, 0))
	part.set_meta("cut", Vector3(0, -length * .5, 0))
	return part

## One piece of what a head, a chest or a belly becomes. `big`: a handful, not a scrap. `shard`: a length of bone.
static func gib(holder: Node3D, at: Vector3, velocity: Vector3, big := false, shard := false) -> RigidBody3D:
	var chunk := RigidBody3D.new()
	chunk.name = "Gib"
	var size := randf_range(.04, .07) if big else randf_range(.018, .045)
	chunk.mass = .3 if big else .08
	chunk.collision_layer = 0
	chunk.collision_mask = 2
	chunk.angular_damp = 2.5
	if _gib_material == null:
		_gib_material = PhysicsMaterial.new()
		_gib_material.friction = 1.0
		_gib_material.bounce = .08
	chunk.physics_material_override = _gib_material
	var shape := CollisionShape3D.new()
	var step := int(round(size * 100.0))
	if not _gib_balls.has(step):
		var ball := SphereShape3D.new()
		ball.radius = maxf(step * .008, .012)
		_gib_balls[step] = ball
	shape.shape = _gib_balls[step]
	chunk.add_child(shape)
	var bony := shard or randf() < .25
	var form := Vector3(randf_range(.25, .4), randf_range(.2, .3), randf_range(1.6, 2.6)) if shard \
		else Vector3(randf_range(.6, 1.3), randf_range(.35, .8), randf_range(.7, 1.4))
	chunk.add_child(_part("shard" if bony else "lump", Vector3.ZERO, form * size, Vector3(randf() * TAU, randf() * TAU, 0)))
	holder.add_child(chunk)
	chunk.global_position = at
	chunk.linear_velocity = velocity
	chunk.angular_velocity = Vector3(randf_range(-14, 14), randf_range(-14, 14), randf_range(-14, 14))
	chunk.add_to_group("zombie_parts")
	return chunk
