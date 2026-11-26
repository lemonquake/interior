extends "res://scripts/coop/figure.gd"
## 0.53: Heavy-arm's body. The fight itself (what he does, his health, the barrels, the key) is scripts/coop/heavyarm.gd.
##
## The model is tools/blender/human/build_heavyarm.py: a downloaded sculpt (shaz13's "Boss Zombie Sculpted", CC BY
## 4.0) skinned to the town skeleton and grown 1.25x, the right arm swollen into the heavy arm, the left gone wrong
## another way. So it plays every clip the infected have (Skeleton3D.motion_scale carries the hips' moves at his
## size) and his own (heavyarm_anims.glb: sat at the gate, getting up, the heavy walk, the three wind-ups, the charge,
## the throw, dazed). His hit boxes are the town ragdoll's at his size, the heavy arm's much fatter. Rounds barely
## mark him (ARMOUR); blasts are reported apart (`shot` with "grenade"), they are what hurts him.
const ASSET := "res://assets/characters/zombies/heavyarm.glb"
const CLIPS_ASSET := "res://assets/characters/zombies/heavyarm_anims.glb"
const SIZE := 1.25
const LOOPED := ["heavy_sit", "heavy_idle", "heavy_walk", "heavy_wind", "heavy_charge", "heavy_dig", "heavy_inhale", "heavy_daze"]
## What is left of a round's damage, by where it lands. The heavy arm is all but armour.
const ARMOUR := {"head": .42, "chest": .2, "spine": .2, "hips": .18, "upper_arm.R": .06, "forearm.R": .04, "hand.R": .04,
	"upper_arm.L": .14, "forearm.L": .14, "hand.L": .1, "thigh.L": .15, "thigh.R": .15, "shin.L": .12, "shin.R": .12,
	"foot.L": .1, "foot.R": .1}
## How much fatter each hit box is than a man's at his size (the heavy arm).
const FAT := {"upper_arm.R": 1.9, "forearm.R": 2.7, "hand.R": 2.8, "chest": 1.25, "upper_arm.L": 1.2, "forearm.L": 1.25}
static var _added := false

var fight
var lanyard: Node3D
## 0.54: his flashlight, still clipped to the lanyard's strap (heavyarm.gd aims its light: his tells are its beam).
var torch: Node3D
## Where the beam leaves the lens (its +Z is the way the flashlight points as it hangs).
var torch_lens: Node3D
var torch_glass: StandardMaterial3D

func setup_heavy(at: Vector3) -> void:
	setup(ASSET, at, "", true)
	speed = 1.6
	hp = 9999.0
	if skeleton != null:
		skeleton.motion_scale = SIZE
	_add_clips()
	# A body his size to move with.
	for c in get_children():
		if c is CollisionShape3D:
			var capsule := CapsuleShape3D.new()
			capsule.radius = .5
			capsule.height = 2.1
			(c as CollisionShape3D).shape = capsule
			(c as CollisionShape3D).position.y = 1.05
			break
	floor_snap_length = .5
	_fatten()
	_lanyard()
	voice.unit_size = 7.0
	voice.max_distance = 80.0
	voice.volume_db = 2.0
	set_meta("boss", true)

## His clips go into the town library the infected share (every figure may have them; none of the others asks).
static func _add_clips() -> void:
	InteriorZombie._load_shared()
	if _added: return
	_added = true
	var scene := load(CLIPS_ASSET) as PackedScene
	if scene == null: return
	var root := scene.instantiate()
	var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null:
		var lib := player.get_animation_library("")
		for name: StringName in lib.get_animation_list():
			if InteriorZombie._library.has_animation(name): continue
			var a: Animation = lib.get_animation(name).duplicate()
			if str(name) in LOOPED: a.loop_mode = Animation.LOOP_LINEAR
			InteriorZombie._library.add_animation(name, a)
	root.free()

func _fatten() -> void:
	for bone: String in bodies:
		var body: PhysicalBone3D = bodies[bone]
		body.mass *= 2.2
		for c in body.get_children():
			if c is CollisionShape3D and (c as CollisionShape3D).shape is CapsuleShape3D:
				var cap := ((c as CollisionShape3D).shape as CapsuleShape3D).duplicate() as CapsuleShape3D
				cap.radius *= SIZE * float(FAT.get(bone, 1.1))
				cap.height = maxf(cap.height, cap.radius * 2.0 + .02)
				(c as CollisionShape3D).shape = cap

## He kept the rear gate: a guard's lanyard still round his neck, the ID card and the gate's key on its ring.
func _lanyard() -> void:
	if skeleton == null: return
	var chest := skeleton.find_bone("chest")
	if chest < 0: return
	lanyard = BoneAttachment3D.new()
	lanyard.bone_name = "chest"
	skeleton.add_child(lanyard)
	var rest := skeleton.get_bone_global_rest(chest)
	var holder := Node3D.new()
	lanyard.add_child(holder)
	# (The skeleton's own space: he faces +Z in it, up is +Y.)
	holder.transform = rest.affine_inverse() * Transform3D(Basis.IDENTITY, Vector3(.02, 1.36 * SIZE, .2 * SIZE))
	var cord := StandardMaterial3D.new()
	cord.albedo_color = Color(.08, .14, .32)
	cord.roughness = .9
	for side in [-1.0, 1.0]:
		var strap := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(.018, .3, .006)
		strap.mesh = box
		strap.material_override = cord
		strap.position = Vector3(side * .07, .14, -.03)
		strap.rotation.z = side * .38
		holder.add_child(strap)
	var card := MeshInstance3D.new()
	var card_box := BoxMesh.new()
	card_box.size = Vector3(.075, .1, .004)
	card.mesh = card_box
	var card_mat := StandardMaterial3D.new()
	card_mat.albedo_color = Color(.78, .76, .7)
	card_mat.roughness = .7
	card.material_override = card_mat
	card.position = Vector3(0, -.03, .004)
	holder.add_child(card)
	var stripe := MeshInstance3D.new()
	var stripe_box := BoxMesh.new()
	stripe_box.size = Vector3(.076, .022, .005)
	stripe.mesh = stripe_box
	var stripe_mat := StandardMaterial3D.new()
	stripe_mat.albedo_color = Color(.42, .06, .08)
	stripe.material_override = stripe_mat
	stripe.position = Vector3(0, .008, .005)
	holder.add_child(stripe)
	var key := Node3D.new()
	key.name = "Key"
	key.position = Vector3(.03, -.1, .01)
	holder.add_child(key)
	key_mesh(key, .7)
	_torch(holder)

## 0.54: the night round's flashlight: a cheap right-angle one, clipped high on the left strap, its head toward his
## front. Scuffed black plastic, a strip of electrical tape round the body where the case cracked, a chrome bezel and
## an old yellow bulb behind the glass (heavyarm.gd turns it on and points it: the charge's lane, the roar's beacon).
func _torch(holder: Node3D) -> void:
	torch = Node3D.new()
	torch.name = "Flashlight"
	torch.position = Vector3(-.105, .085, .05)
	torch.rotation = Vector3(-.18, 0, .12)
	holder.add_child(torch)
	var shell := StandardMaterial3D.new()
	shell.albedo_color = Color(.07, .075, .07)
	shell.roughness = .62
	var tape := StandardMaterial3D.new()
	tape.albedo_color = Color(.02, .02, .022)
	tape.roughness = .35
	var chrome := StandardMaterial3D.new()
	chrome.albedo_color = Color(.62, .6, .55)
	chrome.metallic = .9
	chrome.roughness = .3
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(.042, .1, .034)
	body.mesh = box
	body.material_override = shell
	torch.add_child(body)
	var wrap := MeshInstance3D.new()
	var wrap_box := BoxMesh.new()
	wrap_box.size = Vector3(.045, .018, .037)
	wrap.mesh = wrap_box
	wrap.material_override = tape
	wrap.position = Vector3(0, -.018, 0)
	torch.add_child(wrap)
	var clip := MeshInstance3D.new()
	var clip_box := BoxMesh.new()
	clip_box.size = Vector3(.016, .06, .006)
	clip.mesh = clip_box
	clip.material_override = chrome
	clip.position = Vector3(0, .01, -.02)
	torch.add_child(clip)
	var head := MeshInstance3D.new()
	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = .024
	head_mesh.bottom_radius = .019
	head_mesh.height = .036
	head_mesh.radial_segments = 14
	head.mesh = head_mesh
	head.material_override = shell
	head.rotation.x = PI * .5
	head.position = Vector3(0, .03, .033)
	torch.add_child(head)
	var bezel := MeshInstance3D.new()
	var bezel_mesh := TorusMesh.new()
	bezel_mesh.inner_radius = .019
	bezel_mesh.outer_radius = .026
	bezel_mesh.rings = 12
	bezel_mesh.ring_segments = 8
	bezel.mesh = bezel_mesh
	bezel.material_override = chrome
	bezel.rotation.x = PI * .5
	bezel.position = Vector3(0, .03, .052)
	torch.add_child(bezel)
	var glass := MeshInstance3D.new()
	var glass_mesh := CylinderMesh.new()
	glass_mesh.top_radius = .02
	glass_mesh.bottom_radius = .02
	glass_mesh.height = .003
	glass_mesh.radial_segments = 14
	glass.mesh = glass_mesh
	torch_glass = StandardMaterial3D.new()
	torch_glass.albedo_color = Color(.3, .27, .2)
	torch_glass.emission_enabled = true
	torch_glass.emission = Color(1.0, .78, .48)
	torch_glass.emission_energy_multiplier = 0.0
	glass.material_override = torch_glass
	glass.rotation.x = PI * .5
	glass.position = Vector3(0, .03, .053)
	torch.add_child(glass)
	torch_lens = Node3D.new()
	torch_lens.name = "Lens"
	torch_lens.position = Vector3(0, .03, .056)
	torch.add_child(torch_lens)

## A brass key on a ring (also the one he drops).
static func key_mesh(parent: Node3D, size := 1.0) -> void:
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(.78, .6, .26)
	brass.metallic = .85
	brass.roughness = .32
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = .012 * size
	torus.outer_radius = .017 * size
	ring.mesh = torus
	ring.material_override = brass
	ring.rotation.x = PI * .5
	parent.add_child(ring)
	var bow := MeshInstance3D.new()
	var bow_mesh := CylinderMesh.new()
	bow_mesh.top_radius = .016 * size
	bow_mesh.bottom_radius = .016 * size
	bow_mesh.height = .006 * size
	bow.mesh = bow_mesh
	bow.material_override = brass
	bow.rotation.x = PI * .5
	bow.position = Vector3(0, -.03 * size, 0)
	parent.add_child(bow)
	var blade := MeshInstance3D.new()
	var blade_box := BoxMesh.new()
	blade_box.size = Vector3(.008 * size, .055 * size, .004 * size)
	blade.mesh = blade_box
	blade.material_override = brass
	blade.position = Vector3(0, -.07 * size, 0)
	parent.add_child(blade)
	for i in 3:
		var tooth := MeshInstance3D.new()
		var tooth_box := BoxMesh.new()
		tooth_box.size = Vector3(.008 * size, .007 * size, .004 * size)
		tooth.mesh = tooth_box
		tooth.material_override = brass
		tooth.position = Vector3(.008 * size, (-.075 - i * .012) * size, 0)
		parent.add_child(tooth)

## A round (or a grenade) on him, from this peer's own gun: blood here; the host weighs it (`mission.damage` ->
## heavyarm.gd `hurt`), a blast apart (`report_boss_blast`).
func shot(body: Node, point: Vector3, dir: Vector3, damage: float, knock: float, weapon: String, sever := -1.0) -> void:
	if dead:
		super.shot(body, point, dir, damage, knock, weapon, sever)
		return
	if not is_instance_valid(body) or not is_inside_tree(): return
	var bone := str(body.get_meta("bone", "chest"))
	var way := dir.normalized()
	if weapon == "grenade":
		if bone == "chest" and session != null: session.report_boss_blast(damage, point)
		return
	var dealt := damage * float((InteriorZombie.BODIES.get(bone, [0, 0, 0, 0, 0, 1.0]) as Array)[5])
	bleed(body as Node3D, point, way, dealt * .6, bone == "head")
	if session != null: session.report_hit(key, bone, point, way, dealt, knock * .1, 0.0)

## Rounds do not stagger him.
func flinch(_way: Vector3, _knock: float, _bone := "chest") -> void:
	if randf() < .35: sound(InteriorZombie._stream("hurt_%d" % (1 + randi() % 2)), -10.0)

func knock_back(_way: Vector3, _knock: float) -> void:
	pass

## Seen from far: his chest (where the bar's name points, where the barrels' blasts are measured from).
func chest_at() -> Vector3:
	var c := bodies.get("chest") as Node3D
	return c.global_position if c != null and is_instance_valid(c) else global_position + Vector3.UP * 1.6
