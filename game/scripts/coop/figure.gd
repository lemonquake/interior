extends CharacterBody3D
## The host moves infected bodies. Everyone plays the same clips on the shared town skeleton.
##
## 0.40: the infected carry the same hit boxes as the solo zombies (InteriorZombie.build_ragdoll): a round from any
## peer's own gun lands on the body it struck there (`shot`), blood flies on that peer at once and the hit goes to
## the host, which owns health and the push. Every hit shoves the body back and jerks it by where it was struck;
## enough at once (buckshot close up) puts it on the ground for a moment. On death every peer lets the same bodies
## fall as a ragdoll, pushed the way the last round went (`go_limp`).
## Survivors (players and squad AI) get a muzzle flash, their own voice, and a smooth follow of the host's state.
## Every body the solo infected have (hands and feet too): the same ragdoll, nothing left out.
const HIT_BONES := []
const MASS := 68.0
const REELS := {"front": "hit_front", "back": "hit_back", "heavy": "stagger_heavy", "small": "stagger_small"}
const OUTFITS := [
	["default", "Default Outfit"],
	["tactical", "Tactical Vest"],
	["hoodie_dark", "Charcoal Hoodie"],
	["hoodie_crimson", "Crimson Hoodie"],
	["biker", "Leather Biker"],
	["paramedic", "EMS Paramedic"],
	["flannel", "Red Flannel"],
	["police", "Patrol Uniform"],
	["doctor", "Clinic Lab Coat"],
	["athlete", "Street Jersey"],
	["mechanic", "Mechanic Coveralls"],
	["barong", "Barong Tagalog"],
	["raincoat", "Yellow Raincoat"],
	["camo", "Woodland Camo"],
	["office", "Shirt & Necktie"],
]
const HAIRSTYLES := [
	["default", "Default Hair"],
	["buzz_fade", "Buzz Fade"],
	["textured_crop", "Textured Crop"],
	["side_part", "Side Part"],
	["slick_back", "Slick Back"],
	["textured_spiky", "Textured Spiky"],
	["undercut_quiff", "Undercut Quiff"],
	["curtain_part", "Curtain Part"],
	["wavy_shag", "Wavy Shag"],
	["curly_afro", "Curly Afro"],
	["chin_bob", "Chin Bob"],
	["long_straight", "Long Straight"],
	["long_disheveled", "Long Wild"],
	["high_bun", "High Bun"],
	["ponytail", "Ponytail"],
	["twin_pigtails", "Twin Pigtails"],
	["thinning_receding", "Receding"],
	["patchy_rotted", "Wild Patchy"],
	["bald", "Bald / Shaved"],
]
const HAIR_COLORS := [
	["Jet Black", Color(0.11, 0.10, 0.10)],
	["Dark Brown", Color(0.24, 0.16, 0.12)],
	["Chestnut", Color(0.42, 0.24, 0.14)],
	["Auburn Red", Color(0.56, 0.18, 0.12)],
	["Ash Blonde", Color(0.76, 0.65, 0.42)],
	["Silver Grey", Color(0.74, 0.75, 0.78)],
	["Bleached White", Color(0.92, 0.91, 0.88)],
	["Midnight Blue", Color(0.14, 0.22, 0.44)],
]
const DEFAULT_HAIR := {
	"Alex": "textured_crop",
	"Aljay": "undercut_quiff",
	"Louie": "side_part",
	"Anthony": "slick_back",
	"Clyde": "wavy_shag",
}
static var _hair_scenes := {}
var _custom_hair: MeshInstance3D
var hand: BoneAttachment3D
var carried: Node3D
var held_kind := ""
var voice := AudioStreamPlayer3D.new()
var talk: AudioStreamPlayer3D
var clips: AnimationPlayer
var lamp: SpotLight3D
var flash: OmniLight3D
var flash_time := 0.0
var goal := Vector3.ZERO
var goal_yaw := 0.0
## 0.40: the host's figures move between its updates: how fast the last two said it went (dead reckoning).
var goal_velocity := Vector3.ZERO
var goal_age := 0.0
var _last_goal_at := -1.0
var replicated := false
var hp := 90.0
var attack_wait := 0.0
var nav_wait := 0.0
var path := PackedVector3Array()
var vault_time := -1.0
var vault_from := Vector3.ZERO
var vault_to := Vector3.ZERO
var anim_name := "idle"
var caption: Label3D
var speed := 2.3
var asleep := false
var stalled := 0.0
## 0.40: hit boxes, the ragdoll, and what the last rounds did.
var infected := false
var key := -1
var session: Node
var skeleton: Skeleton3D
var sim: PhysicalBoneSimulator3D
var bodies := {}
var dead := false
var shove := Vector3.ZERO
var stun := 0.0
var stun_clip := ""
var hit_frame := -1
var hit_sum := 0.0
var flinch_until := 0.0
## 0.40: animation level of detail. Near figures are posed every frame; farther or out of view ones every 2nd to
## 4th frame (at 200 FPS that is still 50-100 poses a second). (Switching shadows off far away was tried and cost
## four times the draw calls.)
var anim_step := 1
var _manual := false
var _anim_acc := 0.0
var _anim_phase := randi()%4
var _lod_wait := randf()*.3
var _meshes: Array[GeometryInstance3D] = []
var _seen_at := Vector3.ZERO
var _seen_velocity := Vector3.ZERO
var _rested := 0.0
## 0.41: how it gets past things (host): a vault's arc, shoving a loose table, tripping over the dead.
var vault_dur := 1.0
var vault_top := 0.0
var push_body: RigidBody3D
## 0.57: light props (school chairs, doors) it is walking through for a moment: body -> until (msec).
var _wading := {}
var push_time := 0.0
var push_from := Vector3.ZERO
var _lean_grace := 0.0
## 0.56: a stalled figure looks for a top to climb over at most every quarter second (it used to cast six rays and
## three body shapes every tick while it stood pressed against a wall it could not climb).
var _vault_look := 0.0
var bash_wait := 0.0
var trip_wait := 0.0
## Climbers go over sooner; the rest lean into what is in the way until it gives or they lose patience.
var nerve := randf()
var sway := randf_range(.08, .32)
var _sway_phase := randf() * TAU
## 0.41: not yet hunting anyone (`asleep`): sleeping it off, wandering about a spot, or eating.
var idle_mode := "sleep"
var home := Vector3.ZERO
## 0.52: a horde on the move (idle_mode "march"): the points it walks through, how far along, at what pace, and
## what it does when it gets there.
var march: Array[Vector3] = []
var march_i := 0
var march_pace := 1.05
var march_then := "sleep"
var wander_goal := Vector3.INF
var wander_wait := 0.0
var back := false
## 0.41: parts come off (every peer, on the host's word: `cut`); the host keeps what each part has taken.
var severed := {}
var sever_load := {}
var chunked := {}
var arms_lost := 0
var _scene: PackedScene
var _sever_mod: InteriorZombieGore.Sever

func setup(asset: String, at: Vector3, title: String, is_infected := false) -> void:
	infected = is_infected
	position = at
	goal = at
	collision_layer = 0
	# 0.41: loose things too (layer 4: the forecourt tables), so they are pushed and climbed, not walked through.
	# (0.57: and the school's chairs, layer 32, which they shove aside: school_props.gd.)
	collision_mask = 2 | 4 | 32 if is_infected else 2
	var capsule := CapsuleShape3D.new()
	capsule.radius = .25
	capsule.height = 1.52
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = .76
	add_child(shape)
	_scene = load(asset) as PackedScene
	var model := _scene.instantiate() as Node3D
	model.rotation.y = PI
	add_child(model)
	InteriorZombie._load_shared()
	clips = AnimationPlayer.new()
	model.add_child(clips)
	clips.add_animation_library("",InteriorZombie._library)
	clips.playback_default_blend_time = .15
	clips.play("idle_hurt" if infected else "idle")
	skeleton = model.find_child("Skeleton3D",true,false) as Skeleton3D
	if title != "":
		caption = Label3D.new()
		caption.text = title
		caption.position.y = 2.06
		caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		caption.pixel_size = .004
		caption.font_size = 38
		caption.visibility_range_end = 24
		caption.outline_size = 8
		add_child(caption)
	if title!="" and not title.begins_with("Dodong"):
		if skeleton!=null:
			hand = BoneAttachment3D.new()
			skeleton.add_child(hand)
			hand.bone_name = "hand.R"
		talk = AudioStreamPlayer3D.new()
		talk.unit_size = 6.0
		talk.max_distance = 45
		talk.volume_db = 2.0
		talk.position.y = 1.6
		add_child(talk)
	if infected and skeleton!=null:
		# The same bodies the solo infected are hit on and fall as: rounds from any gun land on them.
		sim = InteriorZombie.build_ragdoll(skeleton,self,bodies,HIT_BONES)
		_sever_mod = InteriorZombieGore.Sever.new()
		_sever_mod.name = "Severed"
		skeleton.add_child(_sever_mod)
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			(mesh as MeshInstance3D).layers = 1 | 2 | InteriorZombie.RENDER_LAYER
	for mesh in model.find_children("*","GeometryInstance3D",true,false): _meshes.append(mesh)
	if not "--no-figure-lod" in OS.get_cmdline_user_args(): _drive_by_hand(true)
	voice.unit_size = 3.5
	voice.max_distance = 34
	voice.volume_db = -8
	add_child(voice)
	floor_snap_length = .36
	speed = randf_range(1.8,3.15)
	_seen_at = at
	reset_physics_interpolation()

static func valid_outfit(key: String) -> String:
	for entry: Array in OUTFITS:
		if entry[0] == key:
			return key
	return "default"

static func valid_hair(key: String) -> String:
	for entry: Array in HAIRSTYLES:
		if entry[0] == key:
			return key
	return "default"

static func asset_for(who: String, outfit: String) -> String:
	var key := valid_outfit(outfit)
	if key != "default":
		var path := "res://assets/characters/survivors/outfits/outfit_%s.glb" % key
		if ResourceLoader.exists(path):
			return path
	return "res://assets/characters/survivors/%s.glb" % who.to_lower()

func apply_hair(hair_style: String, hair_color_idx: int, who := "Alex") -> void:
	if skeleton == null:
		return
	if is_instance_valid(_custom_hair):
		_meshes.erase(_custom_hair)
		_custom_hair.queue_free()
		_custom_hair = null
	var def_hair := skeleton.find_child("DefaultHair", true, false) as MeshInstance3D
	var style := valid_hair(hair_style)
	var color_idx := clampi(hair_color_idx, 0, HAIR_COLORS.size() - 1)
	var tint: Color = HAIR_COLORS[color_idx][1]
	# If using Default Hair on a Default Outfit and Default Color (0), keep built-in DefaultHair untouched!
	if style == "default" and def_hair != null and color_idx == 0:
		def_hair.visible = true
		return
	if def_hair != null:
		def_hair.visible = false
	var chosen := str(DEFAULT_HAIR.get(who, "textured_crop")) if style == "default" else style
	if chosen == "bald":
		return
	var path := "res://assets/characters/hair/hair_%s.glb" % chosen
	if not ResourceLoader.exists(path):
		if def_hair != null:
			def_hair.visible = true
		return
	if not _hair_scenes.has(chosen):
		_hair_scenes[chosen] = load(path)
	var ps := _hair_scenes[chosen] as PackedScene
	if ps == null:
		return
	var tmp := ps.instantiate() as Node3D
	var hmesh := tmp.find_child("CustomHair", true, false) as MeshInstance3D
	if hmesh == null:
		var found := tmp.find_children("*", "MeshInstance3D", true, false)
		if not found.is_empty():
			hmesh = found[0] as MeshInstance3D
	if hmesh != null:
		hmesh.owner = null
		hmesh.get_parent().remove_child(hmesh)
		skeleton.add_child(hmesh)
		hmesh.transform = Transform3D.IDENTITY
		hmesh.skeleton = NodePath("..")
		if hmesh.mesh != null and hmesh.mesh.get_surface_count() > 0:
			var src_mat := hmesh.get_active_material(0) as BaseMaterial3D
			if src_mat != null:
				var copy := src_mat.duplicate() as BaseMaterial3D
				copy.albedo_color = tint
				hmesh.set_surface_override_material(0, copy)
		_custom_hair = hmesh
		_meshes.append(hmesh)
	tmp.free()

func carry(rifle: bool) -> void:
	var kind := "rifle" if rifle else "pistol"
	if hand==null or held_kind==kind: return
	held_kind = kind
	if carried!=null: carried.queue_free()
	carried = (InteriorGun.RIFLE if rifle else InteriorGun.GLOCK).instantiate()
	hand.add_child(carried)
	carried.rotation_degrees = Vector3(90,0,90)

func sound(stream: AudioStream, volume := -8.0) -> void:
	voice.stream = stream
	voice.volume_db = volume
	voice.pitch_scale = randf_range(.91,1.07)
	voice.play()

## 0.40: a line of radio chatter, from where this survivor stands.
func say(stream: AudioStream) -> void:
	if talk==null or stream==null: return
	talk.stream = stream
	talk.play()

## 0.40: the shot seen from outside: a short flash at the hand and the report.
func fire_flash(rifle: bool) -> void:
	if flash==null:
		flash = OmniLight3D.new()
		flash.light_color = Color(1.0,.78,.45)
		flash.omni_range = 5.5
		flash.shadow_enabled = false
		add_child(flash)
		flash.position = Vector3(.12,1.35,-.55)
	flash.light_energy = 6.0 if rifle else 4.0
	flash.visible = true
	flash_time = .05
	sound(preload("res://assets/audio/sfx/gun_shot.ogg"),-2.0 if rifle else -5.0)

func flashlight(on: bool, pitch: float) -> void:
	if on and lamp == null:
		lamp = SpotLight3D.new()
		lamp.position = Vector3(.16,1.44,0)
		lamp.spot_range = 18
		lamp.spot_angle = 22
		lamp.light_energy = 3.0
		lamp.distance_fade_enabled = true
		lamp.distance_fade_begin = 30.0
		lamp.distance_fade_length = 10.0
		add_child(lamp)
	if lamp != null:
		lamp.visible = on
		lamp.rotation.x = pitch

func pose(clip: String) -> void:
	if dead: return
	if clip=="dual_1" and anim_name!=clip: sound(preload("res://assets/audio/zombies/attack_1.ogg"))
	if clip=="alert" and anim_name!=clip: sound(InteriorZombie._stream("scream_%d"%(1+randi()%3)),-2.0)
	if clip=="wall_impact" and anim_name!=clip and randf()<.5: sound(InteriorZombie._stream("growl_%d"%(1+randi()%3)),-7.0)
	# A flinch played here a moment ago runs out before the host's own clip takes over.
	if Time.get_ticks_msec()<flinch_until and clip!=stun_clip: return
	anim_name = clip
	if clips.current_animation != clip and clips.has_animation(clip): clips.play(clip)

## 0.40: where the host says it is now. Two updates apart give how fast it goes, carried on between them.
func follow(at: Vector3, yaw: float) -> void:
	var now := Time.get_ticks_msec()/1000.0
	if _last_goal_at>0.0:
		var gap := now-_last_goal_at
		if gap>.02 and gap<.5: goal_velocity = goal_velocity.lerp(((at-goal)/gap).limit_length(7.0),.6)
		if at.distance_to(goal)>3.0: goal_velocity = Vector3.ZERO
	if physics_interpolation_mode!=Node.PHYSICS_INTERPOLATION_MODE_OFF:
		# Drawn every frame from here: the engine's own tick-to-tick blend would hold it to the physics rate.
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_last_goal_at = now
	goal_age = 0.0
	goal = at
	goal_yaw = yaw

## The clips and the skeleton advanced from here (`_animate`), or by themselves (a ragdoll must run by itself:
## the simulator only reaches the drawn mesh then; see docs/v38).
func _drive_by_hand(on: bool) -> void:
	if on==_manual or clips==null: return
	_manual = on
	clips.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL if on else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	if skeleton!=null:
		skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL if on else Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE
	_anim_acc = 0.0

func _animate(delta: float) -> void:
	# 0.51: not drawn (another floor of the school): the pose waits until it is.
	if not visible:
		_anim_acc = minf(_anim_acc+delta,.3)
		return
	_lod_wait -= delta
	if _lod_wait<=0.0:
		_lod_wait = .25
		var camera := get_viewport().get_camera_3d()
		if camera!=null:
			var d := camera.global_position.distance_to(global_position)
			var seen := not camera.is_position_behind(global_position+Vector3.UP) or d<4.0
			anim_step = 1 if d<14.0 and seen else (2 if d<28.0 and seen else (3 if d<50.0 else 4))
	_anim_acc += delta
	if (Engine.get_process_frames()+_anim_phase)%anim_step!=0: return
	clips.advance(_anim_acc)
	if skeleton!=null: skeleton.advance(_anim_acc)
	_anim_acc = 0.0

func _process(delta: float) -> void:
	if flash!=null and flash.visible:
		flash_time -= delta
		if flash_time<=0: flash.visible = false
	if _manual and not dead: _animate(delta)
	if dead or not replicated: return
	if physics_interpolation_mode!=Node.PHYSICS_INTERPOLATION_MODE_OFF:
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	goal_age += delta
	var ahead := goal+goal_velocity*minf(goal_age,.12)
	position = position.lerp(ahead,1.0-exp(-18*delta))
	rotation.y = lerp_angle(rotation.y,goal_yaw,1.0-exp(-14*delta))

func _physics_process(delta: float) -> void:
	# The dead stay ragdolls for good: every body keeps its physics (rounds and feet still move them).
	if dead: return
	# How fast it is going as drawn: a ragdoll carries it on.
	_seen_velocity = _seen_velocity.lerp((global_position-_seen_at)/maxf(delta,.001),.35)
	_seen_at = global_position

# ---------------------------------------------------------------- hits

func hit_rids() -> Array[RID]:
	var out: Array[RID] = []
	for body: PhysicalBone3D in bodies.values(): out.append(body.get_rid())
	return out

func alive() -> bool: return infected and not dead

## The local gun's round landed on `body` (scripts/gun.gd `_land`). Blood and the jerk now, on this peer; the host
## decides what the hit does.
func shot(body: Node, point: Vector3, dir: Vector3, damage: float, knock: float, _weapon: String, _sever := -1.0) -> void:
	if not infected: return
	if not is_instance_valid(body) or not is_inside_tree(): return
	var bone := str(body.get_meta("bone","chest"))
	var way := dir.normalized()
	var dealt := damage*float((InteriorZombie.BODIES.get(bone,[0,0,0,0,0,1.0]) as Array)[5])
	var tear := (_sever if _sever>=0.0 else damage*.5)
	if dead:
		nudge(body as PhysicalBone3D,point,way,knock)
		bleed(body as Node3D,point,way,dealt*.5,false)
		# 0.41: the dead come apart too: the host keeps the count (the decor dead only here).
		if session!=null:
			if key<=-100: session.mission.tear(self,bone,way,knock,tear)
			else: session.report_corpse_hit(key,bone,point,way,knock,tear)
		return
	bleed(body as Node3D,point,way,dealt,bone=="head")
	flinch(way,knock,bone)
	if session!=null: session.report_hit(key,bone,point,way,dealt,knock,tear)

## Blood out of the far side, a spot on the body, a drip from the wound.
func bleed(body: Node3D, point: Vector3, way: Vector3, dealt: float, head: bool) -> void:
	if session==null: return
	var blood = session.blood()
	if blood==null: return
	blood.wound(self,body,point,way,dealt,head)
	if body!=null and is_instance_valid(body): blood.mark_wound(self,body,point,way,InteriorZombie.RENDER_LAYER)
	if body!=null and is_instance_valid(body) and dealt>10:
		blood.bleed(body,body.global_transform.affine_inverse()*point,body.global_basis.inverse()*-way,clampf(dealt/14.0,1.2,4.0),randf_range(4.0,8.0),false)

## Jerked back by a hit, where everyone can see it: the clip for where it came from. The host's own push follows.
func flinch(way: Vector3, knock: float, bone := "chest") -> void:
	if dead: return
	var local := global_basis.inverse()*way
	var clip: String = REELS.front if local.z>0.0 else REELS.back
	if knock>140.0: clip = REELS.heavy
	elif knock<70.0 and bone!="head" and randf()<.4: clip = REELS.small
	if not clips.has_animation(clip): clip = "hit_front"
	stun_clip = clip
	flinch_until = Time.get_ticks_msec()+int(InteriorZombie.CLIP_TIME.get(clip,.5)*700.0)
	anim_name = clip
	clips.play(clip,.06)
	clips.seek(0.0,not _manual)
	if replicated:
		# A step back at once; the host's own push arrives with the next update.
		position += Vector3(way.x,0,way.z).normalized()*clampf(knock/MASS*.05,.02,.16)
	if randf()<.5: sound(InteriorZombie._stream("hurt_%d"%(1+randi()%2)),-6.0)

## Host: what a hit does to how it moves. Rounds arriving in the same physics frame add up.
func knock_back(way: Vector3, knock: float) -> void:
	var frame := Engine.get_physics_frames()
	if frame!=hit_frame:
		hit_frame = frame
		hit_sum = 0.0
	hit_sum += knock
	shove = (shove+Vector3(way.x,0,way.z).normalized()*knock/MASS*.55).limit_length(4.2)
	if hit_sum>=420.0 and stun<1.0:
		# Buckshot close up: off its feet, then up again.
		stun = 2.1
		stun_clip = "knockdown"
		vault_time = -1.0
	elif hit_sum>=140.0 and stun<.6:
		stun = .75
		stun_clip = REELS.heavy
	elif stun<.3:
		stun = .38
		stun_clip = REELS.front if (global_basis.inverse()*way).z>0.0 else REELS.back
	asleep = false

## A round into one already lying there.
func nudge(body: PhysicalBone3D, point: Vector3, way: Vector3, knock: float) -> void:
	if body==null or not is_instance_valid(body): return
	body.apply_impulse(way*minf(knock*.1,body.mass*2.6),point-body.global_position)
	# 0.43: rounds landing in one instant add up; a heavy blow throws the corpse (InteriorZombie.blow).
	var frame := Engine.get_physics_frames()
	if frame!=_dead_frame:
		_dead_frame = frame
		_dead_push = Vector3.ZERO
		_dead_thrown = false
	_dead_push += way*knock
	if not _dead_thrown and _dead_push.length()>=InteriorZombie.BLOW_FROM:
		_dead_thrown = true
		InteriorZombie.blow(bodies.values(),_dead_push,_dead_push.length()*.8,body)

var _dead_frame := -1
var _dead_push := Vector3.ZERO
var _dead_thrown := false

## Dead: the bodies take it from the clips, pushed the way the last round went.
func go_limp(push: Vector3, bone := "chest") -> void:
	if dead: return
	dead = true
	_drive_by_hand(false)
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	if caption!=null: caption.hide()
	if sim==null:
		clips.play("death_fwd")
		return
	clips.pause()
	sim.influence = 1.0
	sim.physical_bones_start_simulation()
	var carry_on := Vector3(_seen_velocity.x,0,_seen_velocity.z).limit_length(4.0)
	# 0.41: a head shot takes the legs out from under it where it stands; anything else goes the way the rounds went.
	var head := bone=="head"
	var share := (push*(.12 if head else .28)).limit_length(MASS*3.0)
	for body: PhysicalBone3D in bodies.values():
		body.linear_velocity = carry_on
		body.apply_central_impulse(share*body.mass/MASS)
		# The dead lie on tables and sandbags (layer 4), not through them.
		body.collision_mask = 2 | 4
	var struck := bodies.get(bone) as PhysicalBone3D
	if struck!=null: struck.apply_central_impulse(push.normalized()*minf(push.length()*.1,struck.mass*2.6))
	var chest := bodies.get("chest") as PhysicalBone3D
	if chest!=null: chest.apply_central_impulse(Vector3(randf_range(-1,1),-.6 if head else 0.0,randf_range(-1,1))*chest.mass*.35)
	# 0.43: buckshot up close, the sniper, a grenade: thrown (the host sends the hit sum x 1.9).
	InteriorZombie.blow(bodies.values(),push,push.length()/1.9,struck)
	if head:
		for leg in ["shin.L","shin.R"]:
			var shin := bodies.get(leg) as PhysicalBone3D
			if shin!=null: shin.apply_central_impulse(-global_basis.z*shin.mass*.9)
	get_tree().create_timer(randf_range(.42,.6),false).timeout.connect(_thud)
	# A hand or a foot may still jerk once or twice.
	if randf()<.55 and not severed.has("head"):
		for k in 1+randi()%3:
			get_tree().create_timer(randf_range(.9,3.4),false).timeout.connect(_twitch)

func _twitch() -> void:
	if not is_inside_tree(): return
	var names := ["forearm.L","forearm.R","shin.L","shin.R","hand.L","hand.R","head"]
	var body := bodies.get(names[randi()%names.size()]) as PhysicalBone3D
	if body!=null and is_instance_valid(body):
		body.apply_central_impulse(Vector3(randf_range(-1,1),randf_range(.2,1.0),randf_range(-1,1))*body.mass*randf_range(.5,1.1))

func _thud() -> void:
	if not is_inside_tree(): return
	var blood = session.blood() if session!=null else null
	var hips := bodies.get("hips") as PhysicalBone3D
	var at := hips.global_position if hips!=null else global_position
	if blood!=null:
		blood.thud(at)
		get_tree().create_timer(1.4,false).timeout.connect(func():
			if is_inside_tree() and blood!=null: blood.pool(hips.global_position if is_instance_valid(hips) else at))

## Where it lies.
func where() -> Vector3:
	var hips := bodies.get("hips") as PhysicalBone3D
	return hips.global_position if dead and hips!=null else global_position

# ---------------------------------------------------------------- the host moves it

## 0.41: what it does about everything between it and `target`. `underfoot` is where the dead lie (hips). Returns
## true when it lands a blow.
## 0.50: `strike` false when `target` is only a point on the way (a stair in the school): no stopping to attack it.
func chase(delta: float, target: Vector3, nav: InteriorZombieNav, can_search: bool, underfoot: Array, strike := true) -> bool:
	attack_wait = maxf(0,attack_wait-delta)
	nav_wait -= delta
	trip_wait -= delta
	bash_wait -= delta
	# Pushed by rounds: it goes where they drive it before it goes anywhere itself.
	shove = shove.lerp(Vector3.ZERO,1.0-exp(-5.5*delta))
	if stun>0.0:
		stun -= delta
		var down := stun_clip=="knockdown"
		pose("getup" if down and stun<.95 else stun_clip)
		velocity.x = shove.x
		velocity.z = shove.z
		velocity.y = minf(0,velocity.y)-16*delta
		move_and_slide()
		stalled = 0.0
		return false
	if vault_time >= 0:
		# Over the top: hands down, a leg up, and the drop on the far side; it does not always land well.
		vault_time += delta
		var t := clampf(vault_time/vault_dur,0,1)
		var lift := maxf(vault_top-vault_from.y+.18,.3)
		position = vault_from.lerp(vault_to,smoothstep(0.0,1.0,t))+Vector3.UP*sin(t*PI)*lift
		pose("launch" if t<.6 else "stagger_small")
		stalled = 0.0
		if t>=1.0:
			vault_time = -1
			velocity = Vector3.ZERO
			var roll := randf()
			if roll<.3+(.15 if speed>2.6 else 0.0):
				stun = 2.1
				stun_clip = "knockdown"
			elif roll<.65:
				stun = .62
				stun_clip = "stagger_small"
		return false
	var forward := Vector3(target.x-global_position.x,0,target.z-global_position.z).normalized()
	# The dead underfoot: a foot catches and it goes down, or nearly.
	if trip_wait<=0.0 and Vector2(velocity.x,velocity.z).length()>.8:
		for at: Vector3 in underfoot:
			if Vector2(at.x-global_position.x,at.z-global_position.z).length()<.55 and absf(at.y-global_position.y)<.8:
				trip_wait = 3.0
				if randf()<.4 or speed>2.7:
					stun = 2.1
					stun_clip = "knockdown"
				else:
					stun = .62
					stun_clip = "stagger_small"
				return false
	var space := get_world_3d().direct_space_state
	if strike and global_position.distance_to(target)<1.32:
		var reach := PhysicsRayQueryParameters3D.create(position+Vector3.UP*.62,target+Vector3.UP*.62,2|4)
		var high := PhysicsRayQueryParameters3D.create(position+Vector3.UP*1.2,target+Vector3.UP*1.2,2)
		if space.intersect_ray(reach).is_empty() and space.intersect_ray(high).is_empty():
			velocity = Vector3.ZERO
			rotation.y = lerp_angle(rotation.y,atan2(-forward.x,-forward.z),1.0-exp(-10*delta))
			pose("dual_1")
			if attack_wait<=0:
				attack_wait = 3.3   # 0.59: half the attack speed (was 1.65 s)
				return true
			return false
	if not path.is_empty() and position.distance_to(path[0])<.55: path.remove_at(0)
	var aim := target if path.is_empty() else path[0]
	var direction := Vector3(aim.x-position.x,0,aim.z-position.z).normalized()
	# Nobody walks a straight line in this state: a lurch from side to side, worse the faster it goes.
	var now := Time.get_ticks_msec()*.001
	var side := direction.cross(Vector3.UP)
	direction = (direction+side*sin(now*(1.6+speed*.5)+_sway_phase)*sway).normalized()
	rotation.y = lerp_angle(rotation.y,atan2(-direction.x,-direction.z),1.0-exp(-9*delta))
	var pace := speed*(.55 if push_body!=null else 1.0)
	velocity.x = direction.x*pace+shove.x
	velocity.z = direction.z*pace+shove.z
	velocity.y = minf(0,velocity.y)-16*delta
	var before := position
	move_and_slide()
	if not _wading.is_empty(): _unwade()
	# Loose things in the way get leaned on: one alone moves a table slowly, a crowd moves it fast.
	var leaning: RigidBody3D = null
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var other := hit.get_collider() as RigidBody3D
		# 0.57: a school chair or a classroom door (school_props.gd) is walked through, not leaned on (one lying on
		# the floor is met from above, the round foot of the capsule on its edge: kicked along all the same).
		if other!=null and other.has_meta("light_prop"):
			if -hit.get_normal().dot(direction)>=.25 or hit.get_position().y-global_position.y<.5: _shove_light(other,hit,direction,pace,delta)
			continue
		if other==null or -hit.get_normal().dot(direction)<.25: continue
		leaning = other
		other.sleeping = false
		var at := hit.get_position()
		other.apply_impulse(direction*210.0*delta,Vector3(at.x,other.global_position.y+.55,at.z)-other.global_position)
	if leaning!=null:
		_lean_grace = .45
		if leaning!=push_body:
			push_body = leaning
			push_time = 0.0
			push_from = leaning.global_position
		push_time += delta
		stalled = 0.0
		if bash_wait<=0.0:
			# Throws itself at it now and then.
			bash_wait = randf_range(1.1,2.3)
			stun = .5
			stun_clip = "wall_impact"
			leaning.apply_impulse(direction*randf_range(26.0,48.0),Vector3(0,.6,0))
			return false
		var patience := lerpf(3.6,.7,nerve)
		if push_time>patience:
			# Braced (it has hardly moved): over the top if there is somewhere to land.
			if leaning.global_position.distance_to(push_from)<.6 and try_vault(direction): return false
			push_time = 0.0
			push_from = leaning.global_position
		pose("walk_hurt")
		return false
	# Contact with what it leans on comes and goes frame to frame: it only lets go after a moment without it.
	if push_body!=null and is_instance_valid(push_body) and global_position.distance_to(push_body.global_position)<1.9:
		_lean_grace -= delta
		if _lean_grace>0.0:
			push_time += delta
			stalled = 0.0
			pose("walk_hurt")
			return false
	push_body = null
	push_time = 0.0
	if position.distance_to(before)<speed*delta*.35:
		stalled += delta
		_vault_look -= delta
		if stalled>.45 and _vault_look<=0.0:
			_vault_look = .25
			if try_vault(direction): return false
	else:
		stalled = maxf(0,stalled-delta*.4)
	# 0.48: pressed against something too long (no way over it): back off to a waypoint a few links away from
	# where it is pushing, then look again from there (scripts/waypoints.gd).
	if stalled>2.0 and nav.waypoints!=null:
		var off := nav.waypoints.detour(position,position+direction*3.0)
		if off.is_finite():
			path = PackedVector3Array([off])
			nav_wait = 2.2
			stalled = 0.0
	if can_search and nav_wait<=0 and (stalled>.12 or not path.is_empty()):
		path = nav.path(position,target)
		nav_wait = 1.1
	pose("run_hurt" if speed>2.5 else "walk_hurt")
	return false

## Something low in front (a table, sandbags, a counter): is there a top to get a hand on and ground beyond to drop
## to? Starts the vault if so. Two tables deep leave nowhere to land, and it has to push instead.
func try_vault(dir: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var base := global_position
	var knee := space.intersect_ray(PhysicsRayQueryParameters3D.create(base+Vector3.UP*.42,base+Vector3.UP*.42+dir*.95,2|4))
	if knee.is_empty(): return false
	if not space.intersect_ray(PhysicsRayQueryParameters3D.create(base+Vector3.UP*1.4,base+Vector3.UP*1.4+dir*1.4,2|4)).is_empty(): return false
	var probe: Vector3 = knee.position+dir*.14
	var top_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(probe+Vector3.UP*1.5,probe+Vector3.DOWN*.1,2|4))
	var top: float = top_hit.position.y if not top_hit.is_empty() else base.y+.8
	if top-base.y>1.15: return false
	var fit := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .24
	capsule.height = 1.4
	fit.shape = capsule
	fit.collision_mask = 2|4
	for reach in [1.2,1.55,1.9]:
		var land: Vector3 = base+dir*reach
		var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(land+Vector3.UP*1.6,land+Vector3.DOWN*.6,2|4))
		if down.is_empty() or (down.normal as Vector3).y<.7 or down.collider is RigidBody3D: continue
		if absf((down.position as Vector3).y-base.y)>.45: continue
		fit.transform = Transform3D(Basis.IDENTITY,(down.position as Vector3)+Vector3.UP*.93)
		if not space.intersect_shape(fit,1).is_empty(): continue
		vault_from = position
		vault_to = (down.position as Vector3)+Vector3.UP*.02
		vault_top = top
		vault_dur = randf_range(.8,1.15)+(top-base.y)*.35
		vault_time = 0.0
		push_body = null
		return true
	return false

## Not hunting yet (host): asleep where it lay, eating, or wandering about one spot.
func idle(delta: float) -> void:
	shove = shove.lerp(Vector3.ZERO,1.0-exp(-5.5*delta))
	if stun>0.0:
		stun -= delta
		pose(stun_clip)
		return
	velocity.y = minf(0,velocity.y)-16*delta
	match idle_mode:
		"feed":
			velocity.x = shove.x
			velocity.z = shove.z
			pose("devour")
		"wander":
			wander_wait -= delta
			if wander_wait>0.0 or not wander_goal.is_finite():
				velocity.x = shove.x
				velocity.z = shove.z
				pose("idle_look" if int(wander_wait*.5)%2==0 else "idle_hurt")
				if wander_wait<=0.0:
					var angle := randf()*TAU
					wander_goal = home+Vector3(cos(angle),0,sin(angle))*randf_range(1.0,3.6)
			else:
				var d := Vector3(wander_goal.x-position.x,0,wander_goal.z-position.z)
				if d.length()<.3 or stalled>1.5:
					wander_goal = Vector3.INF
					wander_wait = randf_range(2.0,6.0)
					stalled = 0.0
				else:
					var dir := d.normalized()
					rotation.y = lerp_angle(rotation.y,atan2(-dir.x,-dir.z),1.0-exp(-4*delta))
					velocity.x = dir.x*.75+shove.x
					velocity.z = dir.z*.75+shove.z
					pose("walk_hurt")
		"march":
			# 0.52: one of a horde going through: point to point at a shuffle, not hunting anyone, then it stops
			# where the last point is and stands there (`march_then`) until something wakes it.
			if march_i>=march.size():
				idle_mode = march_then
				home = position
				wander_wait = randf_range(1.0,5.0)
				velocity.x = shove.x
				velocity.z = shove.z
				pose("idle_hurt")
			else:
				var d := Vector3(march[march_i].x-position.x,0,march[march_i].z-position.z)
				if d.length()<.45 or stalled>2.5:
					march_i += 1
					stalled = 0.0
				var dir := d.normalized()
				rotation.y = lerp_angle(rotation.y,atan2(-dir.x,-dir.z),1.0-exp(-4*delta))
				velocity.x = dir.x*march_pace+shove.x
				velocity.z = dir.z*march_pace+shove.z
				pose("walk_hurt")
		_:
			velocity.x = shove.x
			velocity.z = shove.z
			pose("idle_hurt")
	var before := position
	# (What it means to walk, before the slide takes off what is blocked.)
	var going := Vector3(velocity.x,0,velocity.z)
	move_and_slide()
	if not _wading.is_empty(): _unwade()
	# 0.57: a horde on the march (or one wandering) shoves the school's chairs and doors aside as well.
	if going.length()>.2:
		for i in get_slide_collision_count():
			var hit := get_slide_collision(i)
			var other := hit.get_collider() as RigidBody3D
			if other!=null and other.has_meta("light_prop") and (-hit.get_normal().dot(going.normalized())>.25 or hit.get_position().y-global_position.y<.5):
				_shove_light(other,hit,going.normalized(),going.length(),delta)
	if idle_mode=="wander" and wander_goal.is_finite() and position.distance_to(before)<delta*.2: stalled += delta
	if idle_mode=="march" and position.distance_to(before)<delta*march_pace*.3: stalled += delta

func _unwade() -> void:
	var now := Time.get_ticks_msec()
	for b in _wading.keys():
		if now<int(_wading[b]): continue
		_wading.erase(b)
		if is_instance_valid(b): remove_collision_exception_with(b)

## 0.57: shoved at the pace it walks, through the prop's middle, never thrown (the host simulates it; everyone else
## sees where it went). One that will not go (a heap of chairs crowds shoved against a wall) is waded through: after
## half a second stuck on it, it does not stop this one for a second and a half (`_wading`), as a crowd tramples it.
func _shove_light(other: RigidBody3D, hit: KinematicCollision3D, direction: Vector3, pace: float, delta: float) -> void:
	if other.freeze: return
	if stalled>.5 and not _wading.has(other):
		_wading[other] = Time.get_ticks_msec()+1500
		add_collision_exception_with(other)
	var touch := hit.get_position()
	touch.y = other.to_global(other.center_of_mass).y
	var arm := touch-other.global_position
	var closing := pace*.8-(other.linear_velocity+other.angular_velocity.cross(arm)).dot(direction)
	if closing>.05:
		other.sleeping = false
		other.apply_impulse(direction*minf(closing*other.mass*.5,260.0*delta),arm)

# ---------------------------------------------------------------- 0.41: parts come off

func _chain(id: int) -> PackedInt32Array:
	var out := PackedInt32Array([id])
	for other in range(id+1,skeleton.get_bone_count()):
		if skeleton.get_bone_parent(other) in out and not severed.has(skeleton.get_bone_name(other)):
			out.append(other)
	return out

func _names(chain: PackedInt32Array) -> Array:
	var out := []
	for bone_id in chain: out.append(skeleton.get_bone_name(bone_id))
	return out

## Every peer, on the host's word: `bone` comes off (`burst`: a head that comes apart), or with `chunk_only` a piece is
## torn out of it.
func cut(bone: String, way: Vector3, knock: float, burst: bool, chunk_only := false) -> void:
	if skeleton==null or not is_inside_tree() or session==null: return
	var blood = session.blood()
	if blood==null: return
	if chunk_only:
		var part := bodies.get(bone) as PhysicalBone3D
		if part==null or not is_instance_valid(part): return
		var r := float((InteriorZombie.BODIES.get(bone,[0,.06]) as Array)[1])
		var out := part.global_basis.inverse()*(-way.normalized())
		blood.chunk(part,out*r*.8,out,r*(.62 if bone in InteriorZombie.TRUNK else .8),part.linear_velocity if dead else _seen_velocity,bone in InteriorZombie.TRUNK)
		return
	if bone=="chest":
		_burst_chest(blood,way,knock)
		return
	if bone in ["hips","spine"]:
		_burst_belly(blood,bone,way,knock)
		return
	_sever(blood,bone,way,knock,burst)

func _sever(blood, bone: String, way: Vector3, knock: float, burst: bool) -> void:
	if severed.has(bone) or not bodies.has(bone): return
	var id := skeleton.find_bone(bone)
	var body := bodies[bone] as PhysicalBone3D
	if id<0 or not is_instance_valid(body): return
	var chain := _chain(id)
	var spec: Array = InteriorZombie.BODIES[bone]
	var at := body.global_transform*body.joint_offset.origin
	var along := body.global_position-at
	along = along.normalized() if along.length()>.001 else Vector3.UP
	var speed: Vector3 = body.linear_velocity if dead else _seen_velocity
	var mass := 0.0
	for bone_id in chain:
		var part := bodies.get(skeleton.get_bone_name(bone_id)) as PhysicalBone3D
		mass += part.mass if part!=null else 0.0
	var radius := .085 if bone=="head" else float(spec[1])
	var thrown := clampf(knock/120.0,.5,3.2)
	if burst:
		for k in 9:
			var out := (way*randf_range(.6,1.6)+Vector3(randf_range(-1,1),randf_range(.1,1.3),randf_range(-1,1))).normalized()
			blood.keep_gib(InteriorZombieGore.gib(blood,body.global_position+out*.05,speed+out*randf_range(1.5,5.5)))
	else:
		var piece := InteriorZombieGore.piece(self,_scene,skeleton,bodies,id,chain,radius,maxf(mass,.5),blood)
		piece.collision_mask = 2|4
		piece.linear_velocity = speed+way*randf_range(.6,1.4)*thrown+along*randf_range(.3,1.0)+Vector3.UP*randf_range(.4,1.3)
		piece.angular_velocity = Vector3(randf_range(-5,5),randf_range(-3,3),randf_range(-5,5))
		blood.keep_piece(piece)
		blood.bleed(piece,piece.get_meta("cut"),Vector3.DOWN,6.0,randf_range(5.0,8.0),false)
	var parent_id := skeleton.get_bone_parent(id)
	var rest := skeleton.get_bone_rest(id)
	var attach := BoneAttachment3D.new()
	attach.name = "Stump "+bone
	attach.bone_name = skeleton.get_bone_name(parent_id)
	skeleton.add_child(attach)
	var cap := InteriorZombieGore.stump(.06 if bone=="head" else radius*1.12)
	attach.add_child(cap)
	cap.transform = Transform3D(InteriorZombieGore.facing(rest.basis.y),rest.origin)
	var above := ""
	var walk := parent_id
	var gone := _names(chain)
	while walk>=0 and above=="":
		var candidate := skeleton.get_bone_name(walk)
		if bodies.has(candidate) and not candidate in gone: above = candidate
		walk = skeleton.get_bone_parent(walk)
	for part_name: String in gone:
		if bodies.has(part_name):
			var part := bodies[part_name] as PhysicalBone3D
			bodies.erase(part_name)
			part.collision_layer = 0
			part.queue_free()
	severed[bone] = true
	_sever_mod.bones.append(id)
	var small := bone.begins_with("hand") or bone.begins_with("foot")
	blood.sever_burst(at,along,2.2 if bone=="head" or bone.begins_with("thigh") else (.8 if small else 1.4),burst)
	var host := bodies.get(above) as PhysicalBone3D
	if host!=null:
		blood.bleed(host,host.global_transform.affine_inverse()*at,host.global_basis.inverse()*along,
			9.0 if bone=="head" or bone.begins_with("thigh") else (4.0 if small else 6.5),randf_range(11.0,16.0),true)
	if bone.begins_with("upper_arm") or bone.begins_with("forearm"): arms_lost = mini(2,arms_lost+1)

func _burst_chest(blood, way: Vector3, knock: float) -> void:
	if severed.has("chest") or not bodies.has("chest"): return
	var chest := bodies["chest"] as PhysicalBone3D
	var at := chest.global_position
	var speed: Vector3 = chest.linear_velocity if dead else _seen_velocity
	var side := way.cross(Vector3.UP)
	side = side.normalized() if side.length()>.05 else Vector3.RIGHT
	for bone: String in ["upper_arm.L","upper_arm.R","head"]:
		if not severed.has(bone) and bodies.has(bone):
			var out := Vector3.UP if bone=="head" else side*(1.0 if bone.ends_with(".L") else -1.0)
			_sever(blood,bone,(way*.6+out).normalized(),knock*1.3,false)
	var id := skeleton.find_bone("chest")
	var rest := skeleton.get_bone_rest(id)
	var attach := BoneAttachment3D.new()
	attach.name = "Stump chest"
	attach.bone_name = skeleton.get_bone_name(skeleton.get_bone_parent(id))
	skeleton.add_child(attach)
	var cap := InteriorZombieGore.stump(.15)
	attach.add_child(cap)
	cap.transform = Transform3D(InteriorZombieGore.facing(rest.basis.y),rest.origin)
	bodies.erase("chest")
	chest.collision_layer = 0
	chest.queue_free()
	severed["chest"] = true
	_sever_mod.bones.append(id)
	blood.sever_burst(at,Vector3.UP,3.2,true)
	blood.shatter(at,speed,way,16,true)
	var host := bodies.get("spine",bodies.get("hips")) as PhysicalBone3D
	if host!=null: blood.bleed(host,host.global_transform.affine_inverse()*at,Vector3.UP,9.0,randf_range(8.0,12.0),true)

func _burst_belly(blood, bone: String, way: Vector3, knock: float) -> void:
	if severed.has("belly"): return
	severed["belly"] = true
	var body := bodies.get(bone,bodies.get("hips")) as PhysicalBone3D
	if body==null: return
	var at := body.global_position
	var speed: Vector3 = body.linear_velocity if dead else _seen_velocity
	var side := way.cross(Vector3.UP)
	side = side.normalized() if side.length()>.05 else Vector3.RIGHT
	for leg: String in ["thigh.L","thigh.R"]:
		if not severed.has(leg) and bodies.has(leg):
			_sever(blood,leg,(way*.5+side*(1.0 if leg.ends_with(".L") else -1.0)+Vector3.DOWN*.3).normalized(),knock,false)
	blood.sever_burst(at,Vector3.DOWN,2.6,true)
	blood.shatter(at,speed,way,11,false)
