extends "res://scripts/coop/figure.gd"
## 0.68: Doctor Lucky's body. The fight (what he does, his health, his vital signs on everyone's screen) is
## scripts/coop/lucky.gd.
##
## The model is tools/blender/human/build_lucky.py: the game's downloaded base body (the one every townsperson is
## built on) dressed in a torn lab coat, then grown wrong: the arms 40 % longer from the elbow, the jaw unhinged and
## hanging to the sternum with needle teeth, three bone claws out of each hand, spurs down the spine, all of him 1.12x.
## His bones are the town skeleton's (the arms lengthened along their own line), so he plays every clip the infected
## have and his own (lucky_anims.glb: the hunch, the sprint, the leap's wind-up, the leap, the landing, the swipe, the
## scream, the flinch, the spider crawl and the cling for the walls).
const ASSET := "res://assets/characters/zombies/lucky.glb"
const CLIPS_ASSET := "res://assets/characters/zombies/lucky_anims.glb"
const SIZE := 1.12
const LOOPED := ["lucky_idle", "lucky_run", "lucky_wind", "lucky_leap", "lucky_spider", "lucky_cling"]
static var _added := false

var fight

func setup_lucky(at: Vector3) -> void:
	setup(ASSET, at, "", true)
	speed = 6.0
	hp = 9999.0
	if skeleton != null:
		skeleton.motion_scale = SIZE
	_add_clips()
	for c in get_children():
		if c is CollisionShape3D:
			var capsule := CapsuleShape3D.new()
			capsule.radius = .38
			capsule.height = 1.9
			(c as CollisionShape3D).shape = capsule
			(c as CollisionShape3D).position.y = .95
			break
	floor_snap_length = .4
	for bone: String in bodies:
		var body: PhysicalBone3D = bodies[bone]
		body.mass *= 1.3
		for c in body.get_children():
			if c is CollisionShape3D and (c as CollisionShape3D).shape is CapsuleShape3D:
				var cap := ((c as CollisionShape3D).shape as CapsuleShape3D).duplicate() as CapsuleShape3D
				cap.radius *= SIZE * (1.25 if bone.begins_with("hand") or bone.begins_with("forearm") else 1.0)
				cap.height = maxf(cap.height * SIZE, cap.radius * 2.0 + .02)
				(c as CollisionShape3D).shape = cap
	voice.unit_size = 8.0
	voice.max_distance = 70.0
	voice.volume_db = 3.0
	set_meta("boss", true)

## His clips go into the town library the infected share.
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
		for clip: StringName in lib.get_animation_list():
			if InteriorZombie._library.has_animation(clip): continue
			var a: Animation = lib.get_animation(clip).duplicate()
			if str(clip) in LOOPED: a.loop_mode = Animation.LOOP_LINEAR
			InteriorZombie._library.add_animation(clip, a)
	root.free()
