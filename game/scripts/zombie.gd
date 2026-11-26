class_name InteriorZombie
extends CharacterBody3D
## 0.28: one of the infected (the debug menu spawns them: scripts/zombies.gd).
##
## People: seven townspeople built on the owner's base body (tools/blender/human/build_zombies.py), men and women,
## each a different build, face, clothes and hair; each one here also differs in size, posture, pace and voice.
## Calm, it stands, wanders slowly (the hurt walk, hunched, head lolling: scripts/zombie_pose.gd) or crouches over
## something on the ground. It notices the player by sight (a cone ahead, further when the flashlight is on, never
## through walls), by a gunshot, by running footsteps close by, or by another one screaming. Then it screams and
## comes: arms up, at a limping sprint or a fast lurch, round obstacles by feel, and claws when it is in reach.
## Losing sight for a while, it goes to where it last saw the player, looks about, and wanders again.
##
## Body: every main bone has a hit box (a PhysicalBone3D on layer 5) that follows the animation, so a round is
## taken by the bone it strikes: the head counts four times a chest hit, limbs less than half. A hit pushes the
## whole figure back by its momentum, kicks the struck limb's spring, and from a hard enough load (a rifle string,
## any shotgun blast, a leg giving way) or on death the animation lets go and the hit boxes become the ragdoll:
## each round's impulse goes into the bone it struck and the rest is shared through the body, so a close load of
## buckshot throws it. Alive, it gets up again. Dead, it lies where physics left it, and bleeds.
##
## 0.29, the owner: "realism, more realism". A round is a few newton seconds: it does not throw anybody. So:
##  - A hit is taken where it lands. The struck part jerks once and settles (zombie_pose.gd, damped springs), the
##    figure steps back by the round's real share of its weight, and it reels by where it was hit: an arm hit
##    hardly slows it, a body hit folds it for a moment, a leg hit makes it stumble. Only a full load of buckshot
##    close up, or a leg that gives way, puts it on the ground.
##  - Wounds stay. A hurt arm stops reaching, a hurt leg limps and slows it, body wounds bend it over; every wound
##    bleeds where it is (scripts/blood.gd: drops fall from it and mark where it walks), and it loses strength with
##    the blood: one that is badly holed goes down on its own after a while.
##  - Death is a body with nothing holding it up: a head shot drops it where it stands; otherwise it reels a
##    moment first. Knees and elbows are hinges and only bend the way they bend; the joints are stiff, so a body
##    folds and settles instead of flailing, and may twitch once or twice after.
##  - Parts come off (scripts/zombie_gore.gd). Each of the head, the upper and lower arms, the thighs and the shins
##    takes what a round has left when it arrives (`shot`'s `sever`: nothing much from a 9 mm, a good deal from a
##    5.56, a load of buckshot close up, all of it from the sniper's .338) and lets go at SEVER: the part falls as
##    its own body, both ends are stumps, the stump pumps blood. Without a head it is dead; a head that takes far
##    more than it holds comes apart instead. Without an arm it keeps coming. Without a leg it cannot stand: it
##    drags itself after the player by its arms (State.CRAWL) and bites at the ankles.

##
## 0.31, the owner: "destroyed bit by bit ... the hands, elbow, arm, foot, ankle, calf ... their bodies can get
## shattered as the player repeatedly shoots", and "at least 10 variations" of behaviour.
##  - The hands and the feet have their own hit boxes and come off at the wrist and the ankle; with the forearm (the
##    elbow), the upper arm (the shoulder), the shin (the knee) and the thigh (the hip) that is six cuts a side.
##    Before a part lets go it is torn: at two fifths and at three quarters of what it holds a piece is blown out of
##    it (`_chunk`: a crater of meat on the part, what came out of it on the ground).
##  - The trunk breaks too. The chest, taking enough (two close loads of buckshot, a rifle magazine's worth, two .338),
##    comes apart: the arms and the head fly and what stands is hips and legs. The belly, taking enough, lets the legs
##    go, and what is left drags itself on.
##  - KINDS: thirteen ways of being one of them. Who it is (the townsperson, VARIANTS) and how it behaves (the kind)
##    are picked separately.

signal died(zombie: InteriorZombie)

enum State { IDLE, ROAM, FEED, ALERT, CHASE, ATTACK, SEARCH, STAGGER, DOWN, GETUP, DEAD, CRAWL, LEAP, LISTEN }

## How each kind differs. walk / chase: ground speed ranges (m/s); the rest are read where they are used.
const KINDS := {
	# The ordinary dead: slow, patient, always coming.
	"shambler": {"label": "Shambler", "weight": 20.0, "walk": [.42, .75], "chase": [1.55, 2.2], "runs": false, "health": 100.0},
	# One leg drags. Stop and go, a lurch for every step; it never runs, and it never stops groaning.
	"limper": {"label": "Limper", "weight": 12.0, "walk": [.28, .46], "chase": [.85, 1.25], "runs": false, "health": 90.0,
		"limp": true, "lean": [.3, .48], "groans": 2.0},
	# Turned an hour ago: upright, clean, fast, looks almost like a neighbour. It stares for a second before it runs.
	"fresh": {"label": "Freshly turned", "weight": 9.0, "walk": [.9, 1.3], "chase": [4.5, 5.3], "runs": true, "health": 85.0,
		"lean": [.0, .06], "upright": true, "stare": [.5, 1.3], "tint": Color(1.16, 1.03, .97), "clean": true},
	# The hurt run of 0.28.
	"runner": {"label": "Runner", "weight": 14.0, "walk": [.5, .8], "chase": [3.3, 4.25], "runs": true, "health": 100.0},
	# All rage: sprints, swings half again as fast, shrugs off what staggers the others, and does not lose you.
	"rager": {"label": "Rager", "weight": 6.0, "walk": [1.0, 1.4], "chase": [5.3, 6.1], "runs": true, "health": 115.0,
		"attack_rate": 1.5, "damage": 1.25, "steady": 2.2, "lose": 16.0, "sight": 30.0, "growls": 2.5,
		"tint": Color(1.1, .86, .84), "clean": true},
	# Low and loping. From three to six metres it gathers itself and jumps at you.
	"leaper": {"label": "Leaper", "weight": 7.0, "walk": [.6, .9], "chase": [3.5, 4.2], "runs": true, "health": 80.0,
		"leap": true, "lean": [.34, .46]},
	# Slow in the head: it looks at you for a long while before it understands, sees little to its sides, hears less.
	"dull": {"label": "Slow-witted", "weight": 9.0, "walk": [.3, .5], "chase": [1.15, 1.6], "runs": false, "health": 125.0,
		"stare": [2.6, 5.0], "cone": .55, "deaf": true, "tint": Color(.86, .9, .88)},
	# Its legs are no use to it. It drags itself along the ground, low, where the torch is not pointing.
	"crawler": {"label": "Crawler", "weight": 6.0, "walk": [.4, .6], "chase": [1.0, 1.4], "runs": false, "health": 75.0, "crawls": true},
	# Lies among the dead until you are close enough.
	"lurker": {"label": "Lurker", "weight": 5.0, "walk": [.5, .8], "chase": [3.4, 4.0], "runs": true, "health": 90.0, "lurks": true},
	# Big, heavy, slow. Takes three times what the others take, and hits like it.
	"brute": {"label": "Brute", "weight": 4.0, "walk": [.45, .6], "chase": [1.7, 2.1], "runs": false, "health": 280.0,
		"damage": 1.8, "steady": 2.4, "tough": 1.7, "size": [1.14, 1.2], "mass": 1.6, "pitch": .72, "heavy": true},
	# Nerves misfiring: a burst of speed, a dead stop, a jerk sideways, another burst.
	"twitcher": {"label": "Twitcher", "weight": 6.0, "walk": [.7, 1.0], "chase": [5.0, 5.8], "runs": true, "health": 70.0,
		"twitch": true, "clean": true},
	# Keeps its distance and screams the others in from three streets away. Cornered or hurt, it comes itself.
	"screamer": {"label": "Screamer", "weight": 4.0, "walk": [.5, .8], "chase": [3.6, 4.2], "runs": true, "health": 70.0,
		"screams": true, "pitch": 1.3},
	# Stands quite still for as long as you look at it. Look away.
	"stalker": {"label": "Stalker", "weight": 5.0, "walk": [.5, .8], "chase": [4.4, 5.0], "runs": true, "health": 90.0,
		"stalks": true, "damage": 1.4, "quiet": true},
}

const VARIANTS := [
	"tambay", "obrero", "tanod", "kuya", "nanay", "dalaga", "estudyante",
	"doktor", "nars", "pasyente", "matadero", "pulis", "pari", "tindera",
	"drayber", "mekaniko", "opisina", "bumbero", "sundalo", "atleta", "lola",
	"lolo", "bata_hoodie", "tulog", "tindero_vest", "biker", "pormal",
	"kusinero", "rider", "nobya", "guro", "mangingisda", "karpintero", "negosyante",
	"jogger", "boxer", "madre", "guwardiya", "turista", "janitor", "panadero",
	"labandera", "kolehiyala", "skater", "barbero", "magsasaka", "pulis_swat", "mayaman",
	"tricycle", "kargador", "pasyente_f", "estudyante_m", "tinderong_isda", "musikero", "mananahi",
	"bombero_f", "biktima_sunog",
]
const FEMALE := [
	"nanay", "dalaga", "estudyante", "nars", "tindera", "lola", "tulog", "pormal",
	"nobya", "guro", "jogger", "madre", "labandera", "kolehiyala", "mayaman",
	"pasyente_f", "mananahi", "bombero_f",
]
const MODEL_DIR := "res://assets/characters/zombies/"
const SOUND_DIR := "res://assets/audio/zombies/"
## 0.44: clips taken from zombie_extra_anims.glb.
const EXTRA_CLIPS := ["sit_hurt"]
const LOOPS := ["idle", "idle_look", "idle_hurt", "walk", "walk_hurt", "run", "run_hurt", "hero_run", "fem_walk",
	"fem_run", "fem_idle", "devour", "crouch_walk", "crawl", "down_idle", "sit_hurt"]
## Clip lengths (s) and the ground speed each moving clip was made for (m/s).
const CLIP_TIME := {"hit_front": .467, "hit_back": .467, "hit_light": .4, "hit_heavy": .6, "stagger_small": .667,
	"stagger_heavy": 1.067, "getup": .933, "war_cry": 1.133, "boss_roar": 1.533, "dual_1": .5, "dual_2": .5,
	"dual_heavy": 1.133, "boss_sweep": 1.2}
const CLIP_SPEED := {"walk_hurt": 1.0, "walk": 1.6, "fem_walk": 1.3, "run_hurt": 3.6, "run": 5.62, "fem_run": 5.0, "hero_run": 6.2}
const LAYER := 8
const HITBOX := 16
const RENDER_LAYER := 1024
const MASS := 68.0
const GRAVITY := 14.0
const ACCELERATION := 7.0
const ATTACK_RANGE := 1.3
const ATTACK_REACH := 1.75
## One blow's knock that takes it off its feet: five pellets or more of a close load.
const KNOCKDOWN := 400.0
## How much of a round's knock reaches the whole figure, and the struck part alone (N s per unit).
const PUSH_BODY := .15
const PUSH_LOCAL := .1
## 0.43: a blow above this much knock (rounds that land in the same instant add up) throws the whole body: buckshot
## up close, the sniper, a grenade. Below it a body only falls the way it was hit.
const BLOW_FROM := 140.0
## What each part holds before it comes off (see `shot`), and what a head must take at once to come apart.
const SEVER := {"head": 80.0, "upper_arm": 85.0, "forearm": 55.0, "hand": 30.0, "thigh": 140.0, "shin": 90.0, "foot": 42.0,
	"chest": 300.0, "spine": 250.0, "hips": 290.0}
const TRUNK := ["hips", "spine", "chest"]
const HEAD_BURST := 120.0
## (Measured, tests/gore_probe.gd: a positive hinge angle here opens a knee forward.)
const HINGE_SIGN := -1.0
## Bone: [next bone down the limb, radius, mass kg, swing, twist (degrees), damage factor]. The forearms and the
## shins hang from hinges (the elbow, the knee): their swing is how far the hinge closes, and it does not open back.
const BODIES := {
	"hips": ["spine", .13, 11.0, 0.0, 0.0, 1.0],
	"spine": ["chest", .125, 9.0, 16.0, 10.0, 1.0],
	"chest": ["neck", .14, 14.0, 18.0, 12.0, 1.1],
	"head": ["", .1, 5.0, 34.0, 28.0, 4.0],
	"upper_arm.L": ["forearm.L", .048, 2.2, 78.0, 35.0, .4],
	"forearm.L": ["hand.L", .04, 1.4, 145.0, 0.0, .3],
	"hand.L": ["", .038, .45, 38.0, 20.0, .2],
	"upper_arm.R": ["forearm.R", .048, 2.2, 78.0, 35.0, .4],
	"forearm.R": ["hand.R", .04, 1.4, 145.0, 0.0, .3],
	"hand.R": ["", .038, .45, 38.0, 20.0, .2],
	"thigh.L": ["shin.L", .075, 7.0, 52.0, 12.0, .55],
	"shin.L": ["foot.L", .052, 3.4, 140.0, 0.0, .45],
	"foot.L": ["toe.L", .046, .9, 30.0, 12.0, .25],
	"thigh.R": ["shin.R", .075, 7.0, 52.0, 12.0, .55],
	"shin.R": ["foot.R", .052, 3.4, 140.0, 0.0, .45],
	"foot.R": ["toe.R", .046, .9, 30.0, 12.0, .25],
}
const VOICES := {"groan": 4, "growl": 3, "scream": 3, "attack": 2, "death": 2, "hurt": 2}

static var _library: AnimationLibrary
static var _scenes := {}
static var _streams := {}
static var _tinted := {}
static var _variant_bag: Array[String] = []

var director: Node
var player: InteriorPlayer
var variant := ""
var female := false
var state := State.IDLE
var health := 100.0
var runner := true
var roam_speed := .6
var chase_speed := 3.8
var sight := 20.0
## 0.33 (scripts/senses.gd). They are blind in the dark and go by ear. `hearing` scales how far a sound reaches it;
## `lit` is the light where it stands (in the dark it goes quiet: it stands and sways, hardly wanders, groans
## low); `_dark` is the player gone into the dark while it hunts; `_dazed` a search by one that lost them so.
var hearing := 1.0
var lit := 1.0
var _dark := false
var _dazed := false
var _docile := 0.0
var _noise_heat := 0.0
var _listen_at := Vector3.ZERO
## 0.37: how sure it is of where the player is, 0..1 (1 while it sees them). Nothing on the screen shows it; the
## way it moves and sounds does (`_search`, `_head_tick`). `awareness()` names it for tests and the debug readout.
var certainty := 0.0
var _head_yaw := 0.0
var _head_pitch := 0.0
## Seconds it stands stock still: a sound stopped it mid-step, it stops to listen, it stands over a place.
var _hold := 0.0
var _pause_wait := 0.0
var _sweep := randf() * TAU
var _examined := false
var _beam_seen := 0.0
var _reach_ok := false
var _reach_at := -1.0
var _tilt_rest := Vector3.ZERO
var _tilt_known := false
var sees := false
var last_seen := Vector3.ZERO
var home := Vector3.ZERO
var model: Node3D
var skeleton: Skeleton3D
## 0.33 (scripts/zombies.gd shares the time out): the clip, the posture and the hit boxes are advanced every
## `animation_step` frames, with the time that has passed. A body the physics is holding runs by itself.
var animation_step := 1
var _anim_time := 0.0
var _anim_by_hand := false
var _anim_phase := randi() % 12
var anim: AnimationPlayer
var pose: InteriorZombiePose
var sim: PhysicalBoneSimulator3D
var voice: AudioStreamPlayer3D
var ragdolled := false
var _bodies := {}
var _state_time := 0.0
var _state_len := 0.0
var _sense_timer := 0.0
var _lost := 0.0
var _goal := Vector3.ZERO
var _walk := Vector3.ZERO
var _shove := Vector3.ZERO
var _bias := 1.0
var _stuck := 0.0
## 0.48: how many times running it has stuck (scripts/waypoints.gd `detour` on the second).
var _stuck_runs := 0
## 0.33: the way round when the straight way is shut (scripts/zombie_nav.gd): points to walk through.
var _path := PackedVector3Array()
var _path_at := 0
var _path_goal := Vector3.INF
var _path_wait := 0.0
## 0.37: the route finder's count of world changes when this way was found, and how long it has pushed along it
## without getting anywhere.
var _path_epoch := 0
var _path_stall := 0.0
var _stall_from := Vector3.ZERO
var _detour := 0.0
var _step_wait := 0.0
var _voice_timer := 3.0
var _attack_hit := 0.0
var _attack_done := false
var _hits: Array = []
var _resolving := false
var _recent_knock := 0.0
var _rest_time := 0.0
var _pooled := false
var _wounds: Array[Node3D] = []
## 0.29: bone -> true for what has come off, and what each part has taken toward that.
var severed := {}
var _sever_load := {}
var _sever_now := {}
var _sever_mod: InteriorZombieGore.Sever
var _scene: PackedScene
var _legless := false
var _arm_gone := {"L": false, "R": false}
var _arm_hurt := {"L": 0.0, "R": 0.0}
var _leg_hurt := 0.0
var _gut_hurt := 0.0
var _bleeding := 0.0
var _doomed := false
var _doom_push := Vector3.ZERO
var _twitch := 0.0
var _twitches := 0
var _crawl_wait := 0.0
var _crawl_side := false
var _bite_wait := 0.0
var _base_lean := 0.0
var _pitch := 1.0
var _calm_reach := 0.0
var _walk_clip := "walk_hurt"
var _run_clip := "run_hurt"
var _idle_clip := "idle_hurt"
## 0.31: which kind it is (KINDS), and what that makes of it.
var kind := "shambler"
var kin: Dictionary = KINDS["shambler"]
var attack_rate := 1.0
var damage_scale := 1.0
var steady := 1.0
var tough := 1.0
var weight := 1.0
var _stare_pending := false
var _stared := false
var _leap_wait := 0.0
## 0.59: attack speed halved: after a swing it gets its breath back for as long as the swing took before the next.
var _swing_rest := 0.0
var _leap_phase := 0
var _spurt := 0.0
var _spurt_go := true
var _strafe := 0.0
var _screams := 0
var _scream_wait := 1.5
var _charging := false
var _playing_dead := false
var _frozen := false
var _gait := randf() * 6.0
var _getup_rate := .8
var _foot_gone := {"L": false, "R": false}
var _fall_now := false
var _chunked := {}
var _sever_at := {}
var _burst_done := {}

static func _pick_variant() -> String:
	if _variant_bag.is_empty():
		_variant_bag.assign(VARIANTS)
		_variant_bag.shuffle()
	return _variant_bag.pop_back()

func setup(director_node: Node, variant_name: String, kind_name := "") -> void:
	director = director_node
	player = director.player
	variant = variant_name if variant_name in VARIANTS else _pick_variant()
	female = variant in FEMALE
	name = "Zombie " + variant
	add_to_group("zombies")
	collision_layer = LAYER
	collision_mask = 2 | 4 | 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .27
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = .85
	add_child(shape)
	floor_snap_length = .28
	floor_max_angle = deg_to_rad(46.0)
	floor_stop_on_slope = true
	safe_margin = .01
	platform_floor_layers = 2
	platform_wall_layers = 0
	_load_shared()
	_scene = _scenes[variant] as PackedScene
	model = _scene.instantiate() as Node3D
	model.name = "Model"
	add_child(model)
	# Built facing +Z after the glTF import; the body's ahead is -Z.
	model.rotation.y = PI
	model.scale = Vector3.ONE * (randf_range(.91, 1.00) if female else randf_range(.95, 1.06))
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).layers = 1 | 2 | RENDER_LAYER
	skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	anim = AnimationPlayer.new()
	anim.name = "Clips"
	model.add_child(anim)
	anim.add_animation_library("", _library)
	anim.playback_default_blend_time = .25
	pose = InteriorZombiePose.new()
	pose.name = "Posture"
	skeleton.add_child(pose)
	pose.setup()
	_build_bodies()
	# Last on the skeleton, after the ragdoll: what has come off is drawn in to its joint.
	_sever_mod = InteriorZombieGore.Sever.new()
	_sever_mod.name = "Severed"
	skeleton.add_child(_sever_mod)
	voice = AudioStreamPlayer3D.new()
	voice.name = "Voice"
	voice.unit_size = 5.0
	voice.max_distance = 60.0
	voice.attenuation_filter_cutoff_hz = 9000.0
	if AudioServer.get_bus_index("Gun") >= 0:
		voice.bus = "Gun"
	add_child(voice)
	voice.position.y = 1.55
	# Who this one is.
	runner = randf() < .62
	roam_speed = randf_range(.42, .8)
	chase_speed = randf_range(3.3, 4.25) if runner else randf_range(1.75, 2.4)
	_pitch = randf_range(1.22, 1.42) if female else randf_range(.82, 1.08)
	_walk_clip = "walk_hurt" if randf() < .75 else ("fem_walk" if female else "walk")
	_run_clip = "run_hurt" if randf() < .7 else ("fem_run" if female else "run")
	_idle_clip = "idle_hurt" if randf() < .6 else ("fem_idle" if female else "idle_look")
	pose.lean = randf_range(.08, .36)
	_base_lean = pose.lean
	pose.head_tilt = Vector3(randf_range(-.12, .3), randf_range(-.25, .25), randf_range(-.4, .4))
	pose.droop = randf_range(-.13, .13)
	pose.reach_angle = Vector2(randf_range(.9, 1.45), randf_range(.9, 1.45))
	_calm_reach = randf_range(0.0, .22) if randf() < .7 else randf_range(.3, .5)
	pose.reach_target = _calm_reach
	_bias = 1.0 if randf() < .5 else -1.0
	_voice_timer = randf_range(1.0, 9.0)
	kind = kind_name if KINDS.has(kind_name) else pick_kind()
	kin = KINDS[kind]
	_apply_kind()

## One of KINDS, by its weight.
static func pick_kind() -> String:
	var total := 0.0
	for key: String in KINDS:
		total += float((KINDS[key] as Dictionary).weight)
	var roll := randf() * total
	for key: String in KINDS:
		roll -= float((KINDS[key] as Dictionary).weight)
		if roll <= 0.0:
			return key
	return "shambler"

func _apply_kind() -> void:
	name = "Zombie %s %s" % [kind, variant]
	runner = bool(kin.runs)
	var walk: Array = kin.walk
	var chase: Array = kin.chase
	roam_speed = randf_range(float(walk[0]), float(walk[1]))
	chase_speed = randf_range(float(chase[0]), float(chase[1]))
	health = float(kin.health)
	attack_rate = float(kin.get("attack_rate", 1.0))
	damage_scale = float(kin.get("damage", 1.0))
	steady = float(kin.get("steady", 1.0))
	tough = float(kin.get("tough", 1.0))
	weight = float(kin.get("mass", 1.0))
	sight = float(kin.get("sight", sight))
	hearing = .35 if bool(kin.get("deaf", false)) else float(kin.get("hearing", 1.0))
	_pitch *= float(kin.get("pitch", 1.0))
	if kin.has("lean"):
		var lean: Array = kin.lean
		pose.lean = randf_range(float(lean[0]), float(lean[1]))
		_base_lean = pose.lean
	if kin.has("size"):
		var size: Array = kin.size
		model.scale = Vector3.ONE * randf_range(float(size[0]), float(size[1]))
	if bool(kin.get("upright", false)):
		pose.head_tilt *= .25
		pose.droop *= .3
		_calm_reach = 0.0
		pose.reach_target = 0.0
	if bool(kin.get("clean", false)):
		_walk_clip = "fem_walk" if female else "walk"
		_run_clip = "fem_run" if female else ("hero_run" if kind != "fresh" and anim.has_animation("hero_run") else "run")
		_idle_clip = "fem_idle" if female else "idle_look"
	if bool(kin.get("limp", false)) or bool(kin.get("heavy", false)):
		_walk_clip = "walk_hurt"
		_run_clip = "walk_hurt"
		_idle_clip = "idle_hurt"
		pose.droop = .2 * _bias
	if bool(kin.get("lurks", false)):
		_getup_rate = 1.45
	if kin.has("tint"):
		_tint(kin.tint)

## The whole figure a shade healthier, angrier or greyer (the materials are shared by every one of its kind).
func _tint(colour: Color) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance.mesh == null:
			continue
		for surface in instance.mesh.get_surface_count():
			var source := instance.get_active_material(surface) as BaseMaterial3D
			if source == null:
				continue
			var key := "%s|%d" % [kind, source.get_instance_id()]
			if not _tinted.has(key):
				var copy := source.duplicate() as BaseMaterial3D
				copy.albedo_color = Color(source.albedo_color.r * colour.r, source.albedo_color.g * colour.g, source.albedo_color.b * colour.b, source.albedo_color.a)
				_tinted[key] = copy
			instance.set_surface_override_material(surface, _tinted[key])

static func _load_shared() -> void:
	if _library == null:
		var source := (load(MODEL_DIR + "zombie_anims.glb") as PackedScene).instantiate()
		var source_player := source.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_library = source_player.get_animation_library("")
		# 0.44: clips made after the library (Jonna's `sit_hurt`) come from a second export of the same rig; the
		# library itself is left as it was (a full rebuild changes the existing clips).
		var extra_path := MODEL_DIR + "zombie_extra_anims.glb"
		if ResourceLoader.exists(extra_path):
			var extra := (load(extra_path) as PackedScene).instantiate()
			var extra_player := extra.find_child("AnimationPlayer", true, false) as AnimationPlayer
			var more := extra_player.get_animation_library("")
			for clip: String in EXTRA_CLIPS:
				if more.has_animation(clip) and not _library.has_animation(clip):
					_library.add_animation(clip, more.get_animation(clip))
			extra.free()
		for clip: String in LOOPS:
			if _library.has_animation(clip):
				_library.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		source.free()
	for key: String in VARIANTS:
		if not _scenes.has(key):
			_scenes[key] = load(MODEL_DIR + "z_" + key + ".glb")

static func _stream(key: String) -> AudioStream:
	if not _streams.has(key):
		var path := SOUND_DIR + key + ".ogg"
		_streams[key] = load(path) if ResourceLoader.exists(path) else null
	return _streams[key]

## One hit box per main bone: a capsule down the bone, hung from the one above by a cone joint.
func _build_bodies() -> void:
	sim = build_ragdoll(skeleton, self, _bodies)

## 0.40: the hit boxes and the ragdoll on any figure built on the town skeleton (the co-op infected use it too):
## a simulator on `skeleton` with one PhysicalBone3D per bone of BODIES (or of `only`), each tagged with
## meta "zombie" (who to tell when a round lands) and "bone". `out` gets bone -> body.
static func build_ragdoll(skeleton: Skeleton3D, who: Object, out: Dictionary, only: Array = []) -> PhysicalBoneSimulator3D:
	var sim := PhysicalBoneSimulator3D.new()
	sim.name = "Ragdoll"
	skeleton.add_child(sim)
	for bone: String in BODIES:
		if not only.is_empty() and not bone in only:
			continue
		var spec: Array = BODIES[bone]
		var id := skeleton.find_bone(bone)
		if id < 0:
			continue
		var to := Vector3(0.0, .2, 0.0)
		var next := skeleton.find_bone(str(spec[0])) if str(spec[0]) != "" else -1
		if next >= 0:
			to = skeleton.get_bone_rest(next).origin
			if bone.begins_with("foot"):
				to *= 1.5                                # to the toes
		elif bone.begins_with("hand"):
			to = Vector3(0.0, .11, 0.0)
		var length := maxf(to.length(), .05)
		var radius := float(spec[1])
		var body := PhysicalBone3D.new()
		body.name = "Hit " + bone
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = radius
		capsule.height = maxf(length + radius, radius * 2.0 + .01)
		shape.shape = capsule
		# The capsule lies along the body's Z.
		shape.transform = Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)), Vector3.ZERO)
		body.add_child(shape)
		var up := Vector3.UP
		if up.cross(to).length() < .001:
			up = Vector3.BACK
		var frame := Basis.looking_at(to, up)
		body.body_offset = Transform3D(frame, frame * Vector3(0, 0, -length * .5))
		# The joint is at the bone's head; its X (the cone's axis) runs down the bone.
		body.joint_offset = Transform3D(Basis(Vector3.UP, PI * .5), Vector3(0, 0, length * .5))
		body.bone_name = bone
		body.mass = float(spec[2])
		if bone != "hips":
			if bone.begins_with("forearm") or bone.begins_with("shin"):
				# A hinge: across the body for a knee, and for an elbow the axis that folds the forearm forward.
				var axis := Vector3.RIGHT if bone.begins_with("shin") else (Vector3.DOWN if bone.ends_with(".L") else Vector3.UP)
				var z := (frame.inverse() * (skeleton.get_bone_global_rest(id).basis.orthonormalized().inverse() * axis)).normalized() * HINGE_SIGN
				var x := (Vector3(0, 0, -1) - z * z.dot(Vector3(0, 0, -1))).normalized()
				body.joint_offset = Transform3D(Basis(x, z.cross(x), z), Vector3(0, 0, length * .5))
				body.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
				body.set("joint_constraints/angular_limit_enabled", true)
				body.set("joint_constraints/angular_limit_lower", -3.0)
				body.set("joint_constraints/angular_limit_upper", float(spec[3]))
			else:
				body.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
				body.set("joint_constraints/swing_span", float(spec[3]))
				body.set("joint_constraints/twist_span", float(spec[4]))
		# Stiff joints: a body folds under its weight and settles; it does not swing about.
		body.linear_damp = .04
		body.angular_damp = 3.4 if float(spec[2]) > 6.0 else 2.6
		body.friction = .9
		body.collision_layer = HITBOX
		body.collision_mask = 2
		body.set_meta("zombie", who)
		body.set_meta("bone", bone)
		sim.add_child(body)
		out[bone] = body
	return sim

## The hit boxes' bodies, for a round that has gone through to leave out.
func hit_rids() -> Array[RID]:
	var out: Array[RID] = []
	for body: PhysicalBone3D in _bodies.values():
		out.append(body.get_rid())
	return out

func alive() -> bool:
	return state != State.DEAD and health > 0.0

func animate(delta: float, frame: int) -> void:
	if skeleton == null or anim == null:
		return
	var by_hand := not ragdolled and state != State.GETUP and state != State.DOWN and state != State.DEAD and state != State.CRAWL
	_drive_by_hand(by_hand)
	if not by_hand:
		return
	_anim_time += delta
	if (frame + _anim_phase) % maxi(animation_step, 1) != 0:
		return
	anim.advance(_anim_time)
	skeleton.advance(_anim_time)
	_anim_time = 0.0

## Whether the director advances the clip and the skeleton by hand (`animate`) or they run by themselves.
## 0.38: a body the physics holds must run by itself, or the ragdoll simulator never reaches the mesh and the
## figure stays standing, frozen, while its bodies fall. `_ragdoll` and `_die` hand it back at once: a figure
## that dies leaves the "zombies" group in the same frame, so the director never calls `animate` on it again.
func _drive_by_hand(by_hand: bool) -> void:
	if by_hand == _anim_by_hand or skeleton == null or anim == null:
		return
	_anim_by_hand = by_hand
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL if by_hand else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL if by_hand else Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE
	_anim_time = 0.0

## Where it is: the figure, or the body on the ground.
func where() -> Vector3:
	var hips := _bodies.get("hips") as PhysicalBone3D
	return hips.global_position if ragdolled and hips != null else global_position

func missing(part: String) -> bool:
	return severed.has(part)

func chest_position() -> Vector3:
	var chest := _bodies.get("chest", _bodies.get("spine", _bodies.get("hips"))) as PhysicalBone3D
	return chest.global_position if chest != null else global_position + Vector3.UP * 1.2

# ---------------------------------------------------------------- states

func start(calm_state := State.IDLE) -> void:
	home = global_position
	last_seen = global_position
	_enter(calm_state)
	if bool(kin.get("crawls", false)) or bool(kin.get("lurks", false)):
		# Down from the first moment: one that cannot stand, and one that is pretending.
		_playing_dead = bool(kin.get("lurks", false))
		_go_down.call_deferred()

func _go_down() -> void:
	if is_inside_tree() and not ragdolled and alive():
		_ragdoll([], Vector3.ZERO)

func _enter(next: State) -> void:
	state = next
	_state_time = 0.0
	_path = PackedVector3Array()
	match next:
		State.IDLE:
			_state_len = randf_range(4.0, 11.0) if lit < InteriorSenses.DARK else randf_range(1.5, 6.0)
			pose.reach_target = _calm_reach
		State.LISTEN:
			_state_len = randf_range(1.6, 3.2)
			pose.reach_target = _calm_reach
			# 0.37: it stops where it is, mid-step, before the head comes round.
			_hold = randf_range(.35, .65)
		State.ROAM:
			_state_len = randf_range(7.0, 14.0)
			var angle := randf() * TAU
			var far := randf_range(4.0, 13.0)
			_goal = global_position + Vector3(sin(angle), 0, cos(angle)) * far
			if _goal.distance_to(home) > 38.0:
				_goal = home + Vector3(sin(angle), 0, cos(angle)) * 6.0
			pose.reach_target = _calm_reach
		State.FEED:
			_play("devour", randf_range(.8, 1.1))
			pose.reach_target = 0.0
		State.ALERT:
			if _stare_pending:
				# It has seen you. It has not understood yet.
				_stare_pending = false
				var stare: Array = kin.stare
				_state_len = randf_range(float(stare[0]), float(stare[1]))
				_play(_idle_clip, .7, .3)
				pose.reach_target = 0.0
			else:
				var clip := "boss_roar" if bool(kin.get("heavy", false)) or bool(kin.get("screams", false)) or randf() < .5 else "war_cry"
				_state_len = float(CLIP_TIME[clip]) * .8
				_play(clip, 1.15, .15)
				pose.reach_target = 0.0
				_say("scream", 4.0)
				if bool(kin.get("screams", false)):
					director.alert_others(self, last_seen, 46.0)
				else:
					director.alert_others(self, last_seen)
		State.CHASE:
			_lost = 0.0
			_frozen = false
			pose.reach_target = randf_range(.75, 1.0)
			_voice_timer = minf(_voice_timer, randf_range(.2, 1.2))
			if kind == "fresh" and _stared and randf() < .7:
				_stared = false
				_say("scream", 3.0)
				director.alert_others(self, last_seen)
		State.LEAP:
			_leap_phase = 0
			_state_len = .42
			_attack_done = false
			_play("war_cry", 1.9, .1)
			pose.lean = _base_lean + .32
			pose.reach_target = 1.0
			_say("growl", 3.0)
		State.ATTACK:
			var clips := ["dual_heavy", "boss_sweep"] if bool(kin.get("heavy", false)) else ["dual_1", "dual_2", "dual_1", "dual_heavy", "boss_sweep"]
			var clip: String = clips[randi() % clips.size()]
			var rate := (1.2 if clip.begins_with("dual_") and clip != "dual_heavy" else 1.45) * attack_rate
			_state_len = float(CLIP_TIME[clip]) / rate
			_attack_hit = _state_len * .5
			_attack_done = false
			_play(clip, rate, .1)
			pose.reach_target = .35
			_say("attack", 2.0)
		State.SEARCH:
			_state_len = randf_range(5.0, 8.0) if _dazed else randf_range(9.0, 15.0)
			_goal = last_seen
			pose.reach_target = maxf(_calm_reach, .3)
			_examined = false
			_hold = 0.0
			_pause_wait = randf_range(1.5, 3.0)
		State.GETUP:
			_state_len = float(CLIP_TIME["getup"]) / .8 + .15
		_:
			pass

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or director == null:
		return
	_state_time += delta
	_recent_knock = maxf(0.0, _recent_knock - 170.0 * delta)
	_leap_wait = maxf(0.0, _leap_wait - delta)
	_swing_rest = maxf(0.0, _swing_rest - delta)
	if state == State.DOWN or state == State.DEAD or state == State.CRAWL:
		_ragdoll_tick(delta)
		return
	if state == State.LEAP:
		_leap(delta)
		return
	if global_position.y < -14.0:
		director.remove(self)
		return
	_sense_timer -= delta
	if _sense_timer <= 0.0:
		_sense_timer = .16 + randf() * .08
		_sense()
	_voice_tick(delta)
	_bleed_out(delta)
	_noise_heat = maxf(0.0, _noise_heat - .35 * delta)
	_hold = maxf(0.0, _hold - delta)
	_quiet_in_the_dark(delta)
	_head_tick(delta)
	var wish := Vector3.ZERO
	match state:
		State.IDLE:
			if _state_time > _state_len:
				# In the dark it mostly stays where it is.
				_enter(State.IDLE if lit < InteriorSenses.DARK and randf() < .7 else State.ROAM)
		State.LISTEN:
			# The head first (`_head_tick`), then, slowly, the body.
			if _hold <= 0.0:
				_face(_listen_at - global_position, delta, 1.6)
			if _state_time > _state_len:
				_enter(State.IDLE)
		State.ROAM:
			wish = _toward(_goal, roam_speed * _pace() * lerpf(1.0, .5, _docile))
			if wish == Vector3.ZERO or _state_time > _state_len or _stuck > 2.5:
				_stuck = 0.0
				_enter(State.IDLE)
		State.ALERT:
			_face(last_seen - global_position, delta, 7.0)
			if _state_time > _state_len:
				_enter(State.CHASE)
		State.CHASE:
			wish = _chase(delta)
		State.ATTACK:
			wish = _attack(delta)
		State.SEARCH:
			wish = _search(delta)
		State.STAGGER, State.GETUP:
			if _state_time > _state_len:
				if _doomed:
					# It has reeled as far as it is going to.
					_ragdoll([], _doom_push)
					_die()
					return
				_enter(State.CHASE if director.can_target() else State.ROAM)
	_move(wish, delta)

func _toward(goal: Vector3, speed: float) -> Vector3:
	var to := goal - global_position
	to.y = 0.0
	if to.length() < .7:
		return Vector3.ZERO
	if state == State.SEARCH:
		var via := _route(goal, get_physics_process_delta_time()) - global_position
		via.y = 0.0
		if via.length() > .05:
			to = via
	return to.normalized() * speed

## Something fixed between here and there, at shin or at chest height (no further than a dozen metres off)?
func _shut(goal: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var to := goal - global_position
	to.y = 0.0
	var reach := minf(to.length(), 12.0)
	if reach < .8:
		return false
	var dir := to.normalized()
	for h: float in [.38, 1.05]:
		var from := global_position + Vector3.UP * h
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * reach, InteriorZombieNav.MASK)).is_empty():
			return true
	return false

## Where to head for now on the way to `goal`: the goal itself while the straight way is open, else the next
## point of a way round. It looks again about once a second, and at once when it has stopped getting anywhere.
func _route(goal: Vector3, delta: float) -> Vector3:
	var nav: InteriorZombieNav = director.nav
	if nav == null:
		return goal
	_path_wait -= delta
	# 0.37: a door or a gate has moved somewhere along the way: look again.
	if nav.epoch != _path_epoch:
		if not _path.is_empty() and nav.touched(_path_epoch, _path, _path_at):
			_path_goal = Vector3.INF
			_path_wait = 0.0
		_path_epoch = nav.epoch
	# 0.37: two seconds of trying and not half a metre further on (a shoved wardrobe, a crate in a gap: loose things
	# are not in the route finder's map): the cell it was making for is shut for a while, and it goes by a found
	# way, not straight, until that has passed.
	_detour = maxf(0.0, _detour - delta)
	_path_stall += delta
	if _path_stall > 2.0:
		if global_position.distance_to(_stall_from) < .45 and not _frozen:
			var toward := goal - global_position
			toward.y = 0.0
			var blocked: Vector3 = _path[_path_at] if _path_at < _path.size() else global_position + toward.normalized() * .7
			if toward.length() > 1.0:
				nav.shut_for(InteriorZombieNav.cell_of(blocked), 8.0)
				_detour = 8.0
				_path_goal = Vector3.INF
				_path_wait = 0.0
		_path_stall = 0.0
		_stall_from = global_position
	if _path_wait <= 0.0 or (_stuck > .5 and _path.is_empty() and _path_wait < .5):
		if not _shut(goal) and _stuck < .5 and _detour <= 0.0:
			_path = PackedVector3Array()
			_path_wait = randf_range(.3, .45)
		elif (_path.is_empty() or goal.distance_to(_path_goal) > 2.0 or _stuck > .5) and director.take_search():
			_path = nav.path(global_position, goal)
			_path_at = 0
			_path_goal = goal
			_path_epoch = nav.epoch
			_path_wait = randf_range(.9, 1.4)
		else:
			_path_wait = .12
	if _path.is_empty():
		return goal
	while _path_at < _path.size():
		var leg := _path[_path_at] - global_position
		leg.y = 0.0
		if leg.length() > .42:
			break
		_path_at += 1
	if _path_at >= _path.size():
		_path = PackedVector3Array()
		return goal
	return _path[_path_at]

func _chase(delta: float) -> Vector3:
	if not director.can_target():
		_enter(State.ROAM)
		return Vector3.ZERO
	var goal := last_seen
	if sees:
		_lost = 0.0
	else:
		# What it hunted went into the dark: it has lost them in a couple of seconds, and gropes on dazed.
		_lost += delta * (3.2 if _dark else 1.0)
		if _lost > float(kin.get("lose", 7.0)):
			_dazed = _dark
			certainty = .5 if _dazed else .9
			_enter(State.SEARCH)
			return Vector3.ZERO
	var to := goal - global_position
	var height := absf(to.y)
	to.y = 0.0
	var dist := to.length()
	# 0.37: only where its arms can get at them: not through a window it sees them through, a door or a fence.
	if sees and dist < ATTACK_RANGE and height < 1.6 and _can_reach():
		if _swing_rest <= 0.0:
			_enter(State.ATTACK)
			return Vector3.ZERO
		# Between swings: up close, facing them, not walking through them.
		_face(to, delta, 6.0)
		return Vector3.ZERO
	if not sees and dist < 1.0:
		certainty = .7
		_enter(State.SEARCH)
		return Vector3.ZERO
	if dist < .2:
		return Vector3.ZERO
	var dir := to / dist
	# 0.33: round what is in the way, not into it.
	var via := _route(goal, delta) - global_position
	via.y = 0.0
	if via.length() > .05:
		dir = via.normalized()
	var speed := chase_speed * _pace()
	_frozen = false
	if bool(kin.get("leap", false)) and sees and _leap_wait <= 0.0 and dist > 3.0 and dist < 6.6 and height < 1.3 and is_on_floor() \
			and not _legless and _leg_hurt < .6 and _can_reach():
		_enter(State.LEAP)
		return Vector3.ZERO
	if bool(kin.get("twitch", false)):
		# A burst, a dead stop, a jerk to one side.
		_spurt -= delta
		if _spurt <= 0.0:
			_spurt_go = not _spurt_go
			_spurt = randf_range(.45, 1.0) if _spurt_go else randf_range(.22, .6)
			_strafe = randf_range(-1.0, 1.0)
			if not _spurt_go:
				pose.kick("head", Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9)))
				pose.kick("chest", Vector3(randf_range(-4, 4), randf_range(-3, 3), randf_range(-4, 4)))
		if not _spurt_go and dist > 2.4:
			return Vector3.ZERO
		if dist > 3.0:
			dir = (dir + dir.cross(Vector3.UP) * _strafe * .85).normalized()
	elif bool(kin.get("screams", false)) and not _charging:
		# It stays back and calls the others; close in on it, or hurt it, and it comes.
		if dist < 6.0 or _screams >= 3:
			_charging = true
		else:
			_scream_wait -= delta
			if sees and _scream_wait <= 0.0:
				_screams += 1
				_scream_wait = randf_range(4.5, 7.0)
				_enter(State.ALERT)
				return Vector3.ZERO
			if dist < 9.0:
				return -dir * roam_speed * 1.6
			if dist < 14.0:
				_face(to, delta, 6.0)
				return Vector3.ZERO
			speed = lerpf(roam_speed, chase_speed, .4)
	elif bool(kin.get("stalks", false)) and sees and dist > 2.3 and _watched():
		# Looked at, it does not move at all.
		_frozen = true
		return Vector3.ZERO
	elif bool(kin.get("limp", false)):
		# A lurch for every step.
		_gait += delta * 2.5
		speed *= .25 + .9 * pow(absf(sin(_gait)), 1.6)
	return dir * speed

## The player's lens is turned toward it (the stalker's rule).
func _watched() -> bool:
	var camera := player.camera
	var to := (global_position + Vector3.UP * 1.1) - camera.global_position
	return to.length() > .01 and (-camera.global_basis.z).dot(to.normalized()) > .7

## The leaper's jump: it gathers itself, then goes through the air at where the player is.
func _leap(delta: float) -> void:
	var to := player.global_position - global_position
	var flat := Vector3(to.x, 0, to.z)
	if _leap_phase == 0:
		_face(flat, delta, 12.0)
		velocity = Vector3(0, velocity.y - GRAVITY * delta if not is_on_floor() else -.6, 0)
		move_and_slide()
		if _state_time >= _state_len:
			_leap_phase = 1
			_state_time = 0.0
			var dist := flat.length()
			var time := clampf(dist / 8.5, .38, .7)
			var aim := flat.normalized() * maxf(dist - .55, .5) / time
			velocity = Vector3(aim.x, GRAVITY * time * .5 + clampf(to.y, -1.0, 1.2) / time + .5, aim.z)
			floor_snap_length = 0.0
			_play("dual_heavy", 1.3, .08)
			pose.lean = _base_lean
			_say("attack", 3.0)
		return
	velocity.y -= GRAVITY * delta
	move_and_slide()
	var reach := flat.length()
	if not _attack_done and reach < 1.25 and absf(to.y) < 1.6 and _can_reach(true):
		_attack_done = true
		director.hurt_player(randf_range(16.0, 24.0) * damage_scale, global_position)
		velocity.x *= .2
		velocity.z *= .2
	if (is_on_floor() and _state_time > .12) or _state_time > 1.4:
		floor_snap_length = .28
		_leap_wait = randf_range(2.6, 4.2)
		_walk = Vector3(velocity.x, 0, velocity.z) * .4
		_enter(State.CHASE)

func _attack(delta: float) -> Vector3:
	var to := player.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	_face(to, delta, 9.0)
	if not _attack_done and _state_time >= _attack_hit:
		_attack_done = true
		if dist < ATTACK_REACH and (-global_basis.z).dot(to.normalized()) > .25 and absf(player.global_position.y - global_position.y) < 1.7 \
				and _can_reach(true):
			director.hurt_player(randf_range(11.0, 19.0) * damage_scale * (.6 if _arm_gone["L"] and _arm_gone["R"] else 1.0), global_position)
	if _state_time > _state_len:
		_swing_rest = _state_len
		_enter(State.CHASE)
	# A step into the swing.
	return to.normalized() * 1.3 if dist > .85 and _state_time < _attack_hit else Vector3.ZERO

func _move(wish: Vector3, delta: float) -> void:
	floor_snap_length = .28
	var steer := wish
	if wish.length() > .05:
		steer = _avoid(wish.normalized()) * wish.length()
		_face(steer, delta, 5.5 if state == State.CHASE else 3.0)
	_walk = _walk.move_toward(steer + director.separation(self), ACCELERATION * delta)
	_shove = _shove.move_toward(Vector3.ZERO, 6.0 * delta)
	var before := global_position
	velocity = Vector3(_walk.x + _shove.x, velocity.y - GRAVITY * delta if not is_on_floor() else -.6, _walk.z + _shove.z)
	move_and_slide()
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length() / maxf(delta, .0001)
	_step_wait -= delta
	if _hold > 0.0 and (state == State.LISTEN or state == State.SEARCH):
		# Stock still, caught mid-step.
		anim.speed_scale = .05
		_stuck = 0.0
		return
	if wish.length() > .3:
		if moved < wish.length() * .25:
			_stuck += delta
			if _stuck > .25 and _step_wait <= 0.0 and is_on_floor():
				_try_step(steer.normalized())
			if _stuck > 1.1:
				_bias = -_bias
				_stuck = .3
				# 0.48: the second time running it backs off to a waypoint a few links away and looks again from there.
				_stuck_runs += 1
				if _stuck_runs >= 2 and director != null and director.nav != null and director.nav.waypoints != null:
					var off: Vector3 = director.nav.waypoints.detour(global_position, global_position + steer.normalized() * 3.0)
					if off.is_finite():
						_path = PackedVector3Array([off])
						_path_wait = 2.2
						_stuck_runs = 0
		else:
			_stuck = maxf(0.0, _stuck - delta * 2.0)
			if _stuck <= 0.0:
				_stuck_runs = 0
	_animate(moved)

## A kerb or a step in the way: up onto it if there is room above it.
func _try_step(dir: Vector3) -> void:
	_step_wait = .35
	var lifted := global_transform.translated(Vector3.UP * .34)
	if not test_move(global_transform, Vector3.UP * .34) and not test_move(lifted, dir * .35):
		global_position += Vector3.UP * .34 + dir * .12
		_stuck = 0.0

## The way round what is ahead: the wish if it is clear, else the nearest clear heading to one side.
func _avoid(wish: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3.UP * .75
	var reach := 1.15
	var query := PhysicsRayQueryParameters3D.create(origin, origin + wish * reach, 2 | 4)
	if space.intersect_ray(query).is_empty():
		return wish
	for angle: float in [.7, -.7, 1.3, -1.3, 1.9, -1.9]:
		var dir := wish.rotated(Vector3.UP, angle * _bias)
		query.to = origin + dir * reach
		if space.intersect_ray(query).is_empty():
			return dir
	return wish

func _face(dir: Vector3, delta: float, rate: float) -> void:
	var flat := Vector3(dir.x, 0, dir.z)
	if flat.length() < .05:
		return
	var want := atan2(-flat.x, -flat.z)
	rotation.y = lerp_angle(rotation.y, want, 1.0 - exp(-rate * delta))

func _animate(speed: float) -> void:
	match state:
		State.IDLE, State.LISTEN:
			_play(_idle_clip, 1.0 - .35 * _docile, .4)
		State.ROAM, State.SEARCH, State.CHASE:
			if speed < .15 and not _frozen:
				_play(_idle_clip, 1.0, .35)
			elif state == State.CHASE and _frozen:
				# Mid-step, and not a hair of it moving.
				anim.speed_scale = 0.0
			elif state == State.CHASE and runner and _leg_hurt < .8:
				_play(_run_clip, clampf(speed / float(CLIP_SPEED[_run_clip]), .5, 1.6), .2)
			else:
				_play(_walk_clip, clampf(speed / float(CLIP_SPEED[_walk_clip]), .35, 2.6), .3)
		_:
			pass

func _play(clip: String, rate := 1.0, blend := .25) -> void:
	if not anim.has_animation(clip):
		return
	if anim.current_animation != clip:
		anim.play(clip, blend)
	anim.speed_scale = rate

# ---------------------------------------------------------------- senses

func _sense() -> void:
	sees = false
	if director.senses != null:
		lit = director.senses.light_at(global_position + Vector3.UP * 1.2, false)
	if not director.can_target():
		return
	var eye := global_position + Vector3.UP * 1.5
	var target := player.camera.global_position
	var to := target - eye
	var dist := to.length()
	var hunting := state == State.CHASE or state == State.ATTACK or state == State.ALERT or state == State.SEARCH
	# 0.33: sight goes by how plainly the player shows. In the dark that is arm's length; under a lamp, in the
	# torch's own light or in a muzzle flash it is as far as ever.
	var senses: InteriorSenses = director.senses
	# 0.37: the torch by where it points: looking into its beam shows the player from as far as ever; from the
	# side, only what it throws back off what it lights.
	var bright := smoothstep(InteriorSenses.DARK, InteriorSenses.LIT, senses.exposure_to(eye)) if senses != null else 1.0
	_dark = bright < .15
	var reach := lerpf(2.4 if hunting else 1.6, sight * (1.25 if hunting else 1.0), bright)
	if dist < reach:
		var flat := Vector3(to.x, 0, to.z).normalized()
		# Within arm's length it knows someone is there whichever way it faces; never through a wall or a shut door.
		if dist < 1.25 or hunting or (-global_basis.z).dot(flat) > float(kin.get("cone", .2)):
			sees = _line_to(eye, target) or _line_to(eye, player.global_position + Vector3.UP * .9)
	if not sees and not hunting and senses != null:
		_notice_beam(eye, senses)
	if sees:
		certainty = 1.0
		last_seen = player.global_position
		if state == State.IDLE or state == State.ROAM or state == State.FEED or state == State.SEARCH or state == State.LISTEN:
			_dazed = false
			if kin.has("stare") and not _stared:
				_stared = true
				_stare_pending = true
				_enter(State.ALERT)
			elif dist < 5.0 or state == State.SEARCH or bool(kin.get("quiet", false)):
				_enter(State.CHASE)
			else:
				_enter(State.ALERT)

## 0.37: the head, or failing that the body: a pole or a wire in the way of one does not hide a person. Glass
## does not hide anyone (scripts/senses.gd `sight_clear`); the unseen walls are not there.
func _line_to(eye: Vector3, target: Vector3) -> bool:
	var senses: InteriorSenses = director.senses
	if senses != null:
		return senses.sight_clear(eye, target)
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye, target, 2)).is_empty()

## 0.37: claws can get at the player (scripts/zombies.gd `within_reach`), looked at no more than every 0.15 s.
func _can_reach(fresh := false) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if fresh or now - _reach_at > .15:
		_reach_at = now
		_reach_ok = director.within_reach(self)
	return _reach_ok

## 0.37: the torch's spot of light, seen from where it stands. A glance across it turns its head; held on
## something near it, it goes to look (at the spot, not at whoever holds the torch).
func _notice_beam(eye: Vector3, senses: InteriorSenses) -> void:
	var spot := senses.beam_spot
	var seen := false
	if spot.is_finite() and state != State.FEED:
		var to := spot - eye
		var far := to.length()
		var flat := Vector3(to.x, 0, to.z)
		var facing := flat.length() < .05 or (-global_basis.z).dot(flat.normalized()) > float(kin.get("cone", .2)) - .25
		seen = far > 1.0 and far < sight * 1.2 and facing and senses.sight_clear(eye, spot + senses.beam_normal * .12)
	if not seen:
		_beam_seen = maxf(0.0, _beam_seen - .15)
		return
	_beam_seen = minf(_beam_seen + .22, 2.0)
	if _beam_seen > .4:
		heard(spot, clampf(_beam_seen * .25, .1, .5), "light")

## 0.37: what it is doing about the player, as a word: calm, suspicious (it heard or glimpsed something and has
## stopped to listen), searching (going to look, or looking about where it lost them) or hunting (it knows).
func awareness() -> String:
	match state:
		State.LISTEN:
			return "suspicious"
		State.SEARCH:
			return "searching"
		State.ALERT, State.CHASE, State.ATTACK, State.LEAP:
			return "hunting"
		_:
			return "calm"

## 0.37: going to see. How sure it is shows. Sure (it lost sight of them a moment ago) it goes quickly and
## straight. Unsure (a sound, the torch's spot) it goes slowly and stops dead now and then to listen. At the place it
## stands over it and looks down at it, then looks about, slower and wider the less sure it is, and gives up with
## a long breath out.
func _search(delta: float) -> Vector3:
	certainty = move_toward(certainty, 0.0, delta * (.11 if _examined else .045))
	var wish := Vector3.ZERO
	if _hold <= 0.0:
		if not _examined:
			var fast := lerpf(roam_speed, chase_speed, .55)
			var speed := roam_speed * 1.15 if _dazed else lerpf(roam_speed * 1.05, fast, smoothstep(.25, .9, certainty))
			wish = _toward(_goal, speed)
			if wish == Vector3.ZERO:
				# There, and nothing.
				_examined = true
				_stuck = 0.0
				_hold = randf_range(1.0, 1.7)
				_say("groan", -10.0, .85)
				_state_len = _state_time + _hold + randf_range(2.5, 4.5)
				wish = Vector3.ZERO
			elif certainty < .6:
				_pause_wait -= delta
				if _pause_wait <= 0.0:
					# It stops dead to listen.
					_pause_wait = randf_range(2.2, 4.0) * (.6 + certainty)
					_hold = randf_range(.6, 1.2)
					wish = Vector3.ZERO
		elif absf(_head_yaw) > .55:
			# Looking about: the body comes round after the head.
			_face((-global_basis.z).rotated(Vector3.UP, _head_yaw), delta, 1.4)
	if _state_time > _state_len:
		# It has given up: a long breath out, and it wanders off.
		_say("groan", -7.0, .78)
		certainty = 0.0
		_dazed = false
		_enter(State.ROAM)
		return Vector3.ZERO
	return wish

## The way to `at`, as a turn of the head from where the body faces (radians, + to its left).
func _yaw_to(at: Vector3) -> float:
	var to := at - global_position
	to.y = 0.0
	var ahead := -global_basis.z
	ahead.y = 0.0
	if to.length() < .3 or ahead.length() < .01:
		return 0.0
	return ahead.normalized().signed_angle_to(to.normalized(), Vector3.UP)

## 0.37: where the head is turned. Listening it snaps round to the sound, chin up; at a place it searched it looks
## down at it, then about; hunting it looks where it goes.
func _head_tick(delta: float) -> void:
	var yaw := 0.0
	var pitch := 0.0
	var rate := 4.0
	match state:
		State.LISTEN:
			yaw = _yaw_to(_listen_at)
			pitch = -.14
			rate = 9.0
		State.ALERT:
			yaw = _yaw_to(last_seen)
			rate = 9.0
		State.SEARCH:
			if _examined and _hold > 0.0:
				yaw = _yaw_to(_goal) * .5
				pitch = .42
			elif _examined or _hold > 0.0:
				_sweep += delta * lerpf(.9, 1.6, certainty)
				yaw = sin(_sweep) * lerpf(.85, .5, certainty)
				pitch = -.06
				rate = 3.0
			else:
				_sweep += delta * .8
				yaw = sin(_sweep) * .3 * (1.0 - certainty)
		_:
			pass
	var k := 1.0 - exp(-rate * delta)
	_head_yaw = lerpf(_head_yaw, clampf(yaw, -.9, .9), k)
	_head_pitch = lerpf(_head_pitch, pitch, k)
	pose.head_tilt.y = _tilt_rest.y + _head_yaw

## A sound reached it (scripts/senses.gd): `strength` is 1 right beside it and 0 at the edge of its earshot.
## A faint one turns its head; a loud one, or the third in a row, brings it over. One that is hunting blind
## goes by them.
func heard(at: Vector3, strength: float, kind: String) -> void:
	if not alive() or ragdolled:
		return
	_noise_heat = minf(_noise_heat + strength, 3.0)
	# A thing coming down or glass breaking is a sound to go and see about, from further off than a footstep.
	# (0.37: a shot muffled by walls to almost nothing turns a head like any other sound; scripts/senses.gd has
	# already taken what was between off `strength`.)
	var loud := (kind == "shot" and strength > .12) or strength > (.3 if kind == "thing" or kind == "glass" or kind == "light" else .55) or _noise_heat > 1.3
	match state:
		State.IDLE, State.ROAM, State.FEED, State.LISTEN:
			_listen_at = at
			if loud:
				last_seen = at
				_dazed = false
				certainty = maxf(certainty, clampf(.3 + strength * .45, .3, .75))
				_enter(State.SEARCH)
				# The head comes round to it before it sets off.
				_hold = randf_range(.25, .45)
			elif state != State.FEED or strength > .3:
				if state != State.LISTEN:
					_enter(State.LISTEN)
					# A short questioning sound, not the hunting growl.
					_say("groan", -6.0, 1.18)
				else:
					_state_len = maxf(_state_len, _state_time + 1.2)
		State.SEARCH:
			last_seen = at
			_listen_at = at
			if _goal.distance_to(at) > 1.5:
				_examined = false
			_goal = at
			certainty = maxf(certainty, .4 + .35 * strength)
			_state_len = maxf(_state_len, _state_time + 6.0)
			if loud:
				_dazed = false
		State.CHASE:
			if not sees:
				last_seen = at
				_lost = maxf(0.0, _lost - 2.5 * strength)
		_:
			pass

## Where it is dark it goes quiet: the head sinks, it leans, it hardly moves.
func _quiet_in_the_dark(delta: float) -> void:
	if not _tilt_known:
		_tilt_known = true
		_tilt_rest = pose.head_tilt
	var calm := state == State.IDLE or state == State.ROAM or state == State.LISTEN
	_docile = move_toward(_docile, 1.0 if calm and lit < InteriorSenses.DARK else 0.0, delta * (.5 if calm else 3.0))
	pose.head_tilt.x = _tilt_rest.x + .34 * _docile + _head_pitch

## A noise worth going to: a shot, a scream, running feet.
func hear(at: Vector3) -> void:
	if bool(kin.get("deaf", false)) and randf() < .75:
		return
	if state == State.IDLE or state == State.ROAM or state == State.FEED or state == State.LISTEN:
		last_seen = at
		_listen_at = at
		_dazed = false
		certainty = maxf(certainty, .6)
		_enter(State.SEARCH)
	elif state == State.SEARCH:
		last_seen = at
		_listen_at = at
		_goal = at
		_examined = false
		certainty = maxf(certainty, .6)
		_state_len = _state_time + 10.0

## Back to wandering (the player died, or the debug menu made them harmless).
func forget() -> void:
	certainty = 0.0
	if state == State.CHASE or state == State.ATTACK or state == State.ALERT or state == State.SEARCH:
		_enter(State.ROAM)

func _voice_tick(delta: float) -> void:
	_voice_timer -= delta
	if _voice_timer > 0.0 or voice.playing:
		return
	if state == State.CHASE:
		if bool(kin.get("quiet", false)):
			_voice_timer = 2.0
			return
		_say("growl", 2.0)
		_voice_timer = randf_range(.9, 2.4) / float(kin.get("growls", 1.0))
	elif state == State.IDLE or state == State.ROAM or state == State.SEARCH or state == State.FEED or state == State.LISTEN:
		_say("groan", -3.0 - 7.0 * _docile)
		_voice_timer = randf_range(4.0, 13.0) / float(kin.get("groans", 1.0)) * (1.0 + 1.2 * _docile)

func _say(kind: String, volume := 0.0, pitch := 1.0) -> void:
	var stream := _stream("%s_%d" % [kind, 1 + randi() % int(VOICES[kind])])
	if stream == null:
		return
	voice.stream = stream
	voice.volume_db = volume
	voice.pitch_scale = _pitch * pitch * randf_range(.94, 1.06)
	voice.play()

# ---------------------------------------------------------------- being shot

## A round (or one pellet) arrives: scripts/gun.gd calls this with the hit box it struck. `sever` is what the round
## has to break the part with (its damage by the weapon's own factor); without one, half the damage.
func shot(body: Node, point: Vector3, dir: Vector3, damage: float, knock: float, _weapon: String, sever := -1.0) -> void:
	if not is_instance_valid(body) or not is_inside_tree():
		return
	var bone := str(body.get_meta("bone", "chest"))
	if not BODIES.has(bone):
		return
	var dealt := damage * float((BODIES[bone] as Array)[5])
	var was_alive := health > 0.0
	_playing_dead = false
	_charging = true
	var limb := bone != "head" and not bone in TRUNK
	# A limb is not where it lives: a round there cripples and bleeds, and the bleeding does the rest.
	health = maxf(health - dealt, minf(health, 25.0)) if limb else health - dealt
	var way := dir.normalized()
	_hits.append({"body": body, "point": point, "dir": way, "knock": knock, "bone": bone, "dealt": dealt})
	director.blood.wound(self, body as Node3D, point, way, dealt, bone == "head")
	_add_wound(body as Node3D, point, way)
	# The wound goes on bleeding where it is: drops fall from it for as long as there is pressure behind it.
	if was_alive or randf() < .5:
		var part := body as Node3D
		director.blood.bleed(part, part.global_transform.affine_inverse() * point, part.global_basis.inverse() * -way,
			clampf(dealt / 14.0, 1.2, 5.0) * (1.0 if was_alive else .4), randf_range(7.0, 12.0) if was_alive else 3.0, false)
	_bleeding += dealt * .004
	_hurt_part(bone, dealt)
	var key := bone.get_slice(".", 0)
	if SEVER.has(key):
		var load := (sever if sever >= 0.0 else damage * .5) / tough
		_sever_load[bone] = float(_sever_load.get(bone, 0.0)) + load
		_sever_now[bone] = float(_sever_now.get(bone, 0.0)) + load
		var struck := body as Node3D
		_sever_at[bone] = [struck.global_transform.affine_inverse() * point, struck.global_basis.inverse() * way]
	if not _resolving:
		_resolving = true
		_resolve_hits.call_deferred()

## What a wound does to how it moves from then on.
func _hurt_part(bone: String, dealt: float) -> void:
	var k := clampf(dealt / 45.0, .15, 1.0)
	if bone.begins_with("upper_arm") or bone.begins_with("forearm") or bone.begins_with("hand"):
		var side := bone.right(1)
		_arm_hurt[side] = minf(1.0, float(_arm_hurt[side]) + k * (.35 if bone.begins_with("hand") else .7))
	elif bone.begins_with("thigh") or bone.begins_with("shin") or bone.begins_with("foot"):
		_leg_hurt = minf(1.0, _leg_hurt + k * .5)
	elif bone != "head":
		_gut_hurt = minf(1.0, _gut_hurt + k * .3)
	_apply_hurt()

func _apply_hurt() -> void:
	pose.arm_limp = Vector2(1.0 if _arm_gone["L"] else float(_arm_hurt["L"]), 1.0 if _arm_gone["R"] else float(_arm_hurt["R"]))
	pose.lean = _base_lean + _gut_hurt * .34
	if _leg_hurt > .3:
		_walk_clip = "walk_hurt"
		_run_clip = "run_hurt"

## How fast it can still go.
func _pace() -> float:
	var feet := .55 if _foot_gone["L"] or _foot_gone["R"] else 1.0
	return (1.0 - .5 * _leg_hurt) * (1.0 - .2 * _gut_hurt) * clampf(.55 + health / 220.0, .55, 1.0) * feet

## Everything that arrived this frame, taken together: a load of buckshot is one blow.
func _resolve_hits() -> void:
	_resolving = false
	if not is_inside_tree():
		return
	var total := 0.0
	var push := Vector3.ZERO
	var legs := false
	var arms_only := true
	var head := false
	for hit: Dictionary in _hits:
		total += float(hit.knock)
		push += (hit.dir as Vector3) * float(hit.knock)
		var bone := str(hit.bone)
		var leg := bone.begins_with("thigh") or bone.begins_with("shin") or bone.begins_with("foot")
		legs = legs or leg
		head = head or bone == "head"
		arms_only = arms_only and (bone.begins_with("upper_arm") or bone.begins_with("forearm") or bone.begins_with("hand"))
	_recent_knock += total
	var hits := _hits.duplicate()
	_hits.clear()
	# What comes off with this blow.
	var cuts: Array = []
	var chunks: Array = []
	var trunk := ""
	for bone: String in _sever_load:
		if severed.has(bone) or not _bodies.has(bone) or _burst_done.has(bone):
			continue
		var need := float(SEVER[bone.get_slice(".", 0)])
		var load := float(_sever_load[bone])
		if load >= need:
			if bone in TRUNK:
				trunk = bone
			else:
				cuts.append(bone)
		else:
			# Not off yet, but not whole either: a piece is torn out of it.
			var stage := int(_chunked.get(bone, 0))
			if (stage == 0 and load >= need * .4) or (stage == 1 and load >= need * .74):
				_chunked[bone] = stage + 1
				chunks.append(bone)
	for bone: String in cuts:
		if bone == "head":
			health = minf(health, 0.0)
		elif bone.begins_with("thigh") or bone.begins_with("shin"):
			_legless = true
		elif bone.begins_with("foot"):
			_foot_gone[bone.right(1)] = true
			_leg_hurt = maxf(_leg_hurt, .85)
			_fall_now = true
		elif bone.begins_with("hand"):
			_arm_hurt[bone.right(1)] = maxf(float(_arm_hurt[bone.right(1)]), .55)
		else:
			_arm_gone[bone.right(1)] = true
	if trunk == "chest":
		health = minf(health, 0.0)
	elif trunk != "":
		_legless = true
	var now := _sever_now.duplicate()
	_sever_now.clear()
	_react(hits, total, push, legs, arms_only, head)
	_fall_now = false
	var way := push.normalized() if push.length() > .01 else -global_basis.z
	for bone: String in chunks:
		_chunk(bone)
	for bone: String in cuts:
		_sever(bone, way, total, bone == "head" and float(now.get(bone, 0.0)) >= HEAD_BURST)
	if trunk == "chest":
		_burst_chest(way, total)
	elif trunk != "":
		_burst_belly(trunk, way, total)

func _react(hits: Array, total: float, push: Vector3, legs: bool, arms_only: bool, head: bool) -> void:
	if state == State.DOWN or state == State.DEAD or state == State.CRAWL:
		# Already on the ground: the rounds shove what they strike; a heavy blow throws the whole body.
		for hit: Dictionary in hits:
			_nudge(hit, 1.0)
		if ragdolled:
			blow(_bodies.values(), push, push.length() * .8)
		_rest_time = 0.0
		if health <= 0.0 and state != State.DEAD:
			_die()
		return
	if health <= 0.0:
		if head or total >= KNOCKDOWN * steady or _doomed or total >= BLOW_FROM * 1.5:
			# Nothing holds it up any more.
			_ragdoll(hits, push)
			_die()
		else:
			# It is finished but has not fallen yet: a step or two, folding, and then it goes.
			_doom(push)
			for hit: Dictionary in hits:
				_flinch(hit)
		return
	if total >= KNOCKDOWN * steady or _legless or _fall_now or (legs and randf() < (.22 + _leg_hurt * .4) / steady):
		_ragdoll(hits, push)
		return
	# Still up: a step back by what hit it, the struck part jerked, and by where it was hit a reel.
	_shove = (_shove + Vector3(push.x, 0, push.z) / (MASS * weight) * .5).limit_length(2.4)
	for hit: Dictionary in hits:
		_flinch(hit)
	last_seen = player.global_position
	if state == State.FEED or state == State.IDLE or state == State.ROAM or state == State.SEARCH or state == State.ALERT:
		director.alert_others(self, last_seen)
	var reels := total > 150.0 * steady or (legs and steady < 2.0) or head or (not arms_only and total > 45.0 * steady and randf() < .65)
	if reels and state != State.STAGGER:
		_reel(total, push)
	elif state != State.STAGGER and state != State.CHASE and state != State.ATTACK:
		_enter(State.CHASE)

## 0.33: shoved by the player's hands (scripts/body.gd): back on its heels, whatever it was doing.
func shoved(way: Vector3, strength := 1.0) -> void:
	if not alive():
		return
	# 0.49: a step back on its heels and a short reel, not a throw.
	_shove = (_shove + way * 1.3 * strength).limit_length(1.6)
	last_seen = player.global_position
	_reel(60.0 * strength, way)

## A reel on its feet: the clip for the side the round came from.
func _reel(total: float, push: Vector3) -> void:
	var local := global_basis.inverse() * (push.normalized() if push.length() > .01 else Vector3.BACK)
	var clip := "hit_front" if local.z > 0.0 else "hit_back"
	if absf(local.x) > absf(local.z):
		clip = "hit_right" if local.x > 0.0 else "hit_left"
	if total > 150.0:
		clip = "stagger_heavy"
	elif total <= 80.0 and randf() < .35:
		clip = "stagger_small"
	if not anim.has_animation(clip):
		clip = "hit_front"
	state = State.STAGGER
	_state_time = 0.0
	_state_len = _clip_time(clip) * (.7 if total > 150.0 else .8)
	_play(clip, 1.1, .1)
	pose.reach_target = .15
	_say("hurt", 1.0)

func _clip_time(clip: String) -> float:
	if CLIP_TIME.has(clip):
		return float(CLIP_TIME[clip])
	return anim.get_animation(clip).length if anim.has_animation(clip) else .5

## Dead on its feet: it reels for a moment and then the ragdoll takes it.
func _doom(push: Vector3) -> void:
	_doomed = true
	_doom_push = push
	_shove = (_shove + Vector3(push.x, 0, push.z) / MASS * .5).limit_length(2.0)
	state = State.STAGGER
	_state_time = 0.0
	_state_len = randf_range(.2, .5)
	_play("stagger_heavy" if randf() < .6 else "hit_front", 1.25, .08)
	pose.reach_target = 0.0

## A round into a body that is already lying there.
func _nudge(hit: Dictionary, scale: float) -> void:
	var body := hit.body as PhysicalBone3D
	if not is_instance_valid(body) or body.is_queued_for_deletion():
		return
	var impulse := minf(float(hit.knock) * PUSH_LOCAL * scale, body.mass * 2.6)
	body.apply_impulse((hit.dir as Vector3) * impulse, (hit.point as Vector3) - body.global_position)

func _flinch(hit: Dictionary) -> void:
	var local := (skeleton.global_basis.orthonormalized().inverse() * (hit.dir as Vector3)).normalized()
	var axis := Vector3.UP.cross(local)
	if axis.length() < .05:
		axis = Vector3.RIGHT
	axis = axis.normalized()
	var k := clampf(float(hit.knock) / 60.0, .3, 2.2)
	var bone := str(hit.bone)
	if bone == "head":
		pose.kick("head", axis * 8.0 * k)
		pose.kick("neck", axis * 4.5 * k)
		pose.kick("chest", axis * 1.6 * k)
	elif bone.begins_with("upper_arm") or bone.begins_with("forearm") or bone.begins_with("hand"):
		var side := 1.0 if bone.ends_with(".L") else -1.0
		pose.kick("upper_arm" + bone.right(2), axis * 9.0 * k)
		pose.kick("forearm" + bone.right(2), axis * 6.0 * k)
		# The shoulder goes back with the arm.
		pose.kick("chest", Vector3(0, -side * local.z, 0) * 3.2 * k + axis * 1.0 * k)
	elif bone.begins_with("thigh") or bone.begins_with("shin") or bone.begins_with("foot"):
		pose.kick("thigh" + bone.right(2), axis * 6.5 * k)
		pose.kick("spine", axis * -2.0 * k)
	else:
		# The body folds round where it was hit, and the head comes forward.
		pose.kick("spine", axis * 3.2 * k)
		pose.kick("chest", axis * 4.2 * k)
		pose.kick("head", axis * -3.0 * k)

## The animation lets go: every hit box is a body now, carrying on at the speed the figure had. A round gives the
## whole figure its real share of a push and the part it struck a jerk; nothing lifts it. It falls because nothing
## holds it up.
func _ragdoll(hits: Array, push: Vector3) -> void:
	if ragdolled:
		for hit: Dictionary in hits:
			_nudge(hit, 1.0)
		return
	state = State.DOWN
	_state_time = 0.0
	_rest_time = 0.0
	ragdolled = true
	_drive_by_hand(false)
	collision_layer = 0
	collision_mask = 0
	pose.active = false
	anim.pause()
	sim.influence = 1.0
	sim.physical_bones_start_simulation()
	var carry := Vector3(_walk.x + _shove.x, 0, _walk.z + _shove.z)
	var share := (push * PUSH_BODY).limit_length(MASS * 2.2)
	for body: PhysicalBone3D in _bodies.values():
		body.linear_velocity = carry
		body.apply_central_impulse(share * body.mass / MASS)
	for hit: Dictionary in hits:
		_nudge(hit, 1.0)
	blow(_bodies.values(), push, push.length(), (hits[0] as Dictionary).body as PhysicalBone3D if not hits.is_empty() else null)
	# Which way it goes over is never quite the same twice.
	var chest := _bodies.get("chest") as PhysicalBone3D
	if chest != null:
		chest.apply_central_impulse(Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * chest.mass * .35)
	_walk = Vector3.ZERO
	_shove = Vector3.ZERO
	velocity = Vector3.ZERO
	if not _playing_dead:
		get_tree().create_timer(randf_range(.42, .6), false).timeout.connect(_thud)

## 0.43: thrown by a heavy blow. `strength` is in knock units (a 9 mm round is 60, the sniper 300, buckshot up
## close 500 or more, a grenade close by 900 and up). The whole body leaves the ground along the blow, the struck part a
## little faster.
static func blow(bodies: Array, push: Vector3, strength: float, struck: PhysicalBone3D = null) -> void:
	if strength < BLOW_FROM or push.length() < .001:
		return
	var way := push.normalized()
	var flat := Vector3(way.x, 0, way.z)
	flat = flat.normalized() if flat.length() > .05 else Vector3.ZERO
	# Buckshot point blank (~680) leaves at ~7 m/s, the sniper (300) at ~3.5, a grenade close by at the 8.5 cap.
	var speed := clampf(1.8 + (strength - BLOW_FROM) / 95.0, 0.0, 8.5)
	var lift := clampf(speed * .28 + maxf(way.y, 0.0) * speed * .5, .4, 5.0)
	for body: Variant in bodies:
		if not is_instance_valid(body) or not body is PhysicalBone3D:
			continue
		(body as PhysicalBone3D).linear_velocity += flat * speed * randf_range(.85, 1.08) + Vector3.UP * lift * randf_range(.8, 1.1)
	if is_instance_valid(struck):
		struck.linear_velocity += way * speed * .45
		struck.angular_velocity += way.cross(Vector3.UP) * speed * .8

func _thud() -> void:
	if is_inside_tree() and ragdolled:
		director.blood.thud(where())

func _ragdoll_tick(delta: float) -> void:
	var hips := _bodies.get("hips") as PhysicalBone3D
	if hips == null:
		return
	if hips.global_position.y < -14.0:
		director.remove(self)
		return
	_rest_time = _rest_time + delta if hips.linear_velocity.length() < .45 else 0.0
	if state == State.DOWN and _playing_dead:
		# Quite still among the dead, until someone is close enough.
		if director.can_target() and hips.global_position.distance_to(player.global_position) < 4.4 and _state_time > 1.2:
			_playing_dead = false
			_state_time = 10.0
		return
	if state == State.DOWN:
		_bleed_out(delta)
		if state == State.DOWN and ((_state_time > 1.7 and _rest_time > .8) or _state_time > 6.0):
			if _legless or bool(kin.get("crawls", false)):
				_enter_crawl()
			else:
				_getup()
	elif state == State.CRAWL:
		_bleed_out(delta)
		if state == State.CRAWL:
			_crawl_tick(delta)
	else:
		if not _pooled and (_rest_time > 1.0 or _state_time > 4.0):
			_pooled = true
			director.blood.pool(chest_position())
		_twitch_tick(delta)

## Blood lost is strength lost; with enough of it gone, it stops.
func _bleed_out(delta: float) -> void:
	if _bleeding <= 0.0 or health <= 0.0:
		return
	health -= _bleeding * delta
	_bleeding = maxf(0.0, _bleeding - _bleeding * .04 * delta)
	if health <= 0.0:
		if ragdolled:
			_die()
		elif state != State.STAGGER or not _doomed:
			_doom(Vector3.ZERO)

## For a few seconds after, a hand or a foot may still jerk.
func _twitch_tick(delta: float) -> void:
	if _twitches <= 0 or _state_time > 5.0:
		return
	_twitch -= delta
	if _twitch > 0.0:
		return
	_twitch = randf_range(.25, 1.1)
	_twitches -= 1
	var names := ["forearm.L", "forearm.R", "shin.L", "shin.R", "head"]
	var body := _bodies.get(names[randi() % names.size()]) as PhysicalBone3D
	if body != null:
		body.apply_central_impulse(Vector3(randf_range(-1, 1), randf_range(.2, 1.0), randf_range(-1, 1)) * body.mass * randf_range(.5, 1.1))

func _die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	_state_time = 0.0
	health = minf(health, 0.0)
	_twitches = (1 + randi() % 3) if randf() < .55 and not severed.has("head") else 0
	_twitch = randf_range(.3, .9)
	if not severed.has("head"):
		_say("death", 2.0)
	else:
		voice.stop()
	_drive_by_hand(false)
	remove_from_group("zombies")
	add_to_group("zombie_corpses")
	died.emit(self)

## Up off the ground: the figure goes to where the ragdoll lies, feet where its feet are, and the get-up clip
## takes the bones back from the bodies over half a second.
func _getup() -> void:
	var hips_at := (_bodies["hips"] as PhysicalBone3D).global_position
	var head_body := _bodies.get("head", _bodies.get("chest", _bodies.get("spine"))) as PhysicalBone3D
	var head_at := head_body.global_position if head_body != null else hips_at + Vector3.FORWARD * .3
	var space := get_world_3d().direct_space_state
	var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(hips_at + Vector3.UP * .6, hips_at + Vector3.DOWN * 3.0, 2))
	var at := hips_at
	if not floor_hit.is_empty():
		at = floor_hit.position
	global_position = at
	var along := Vector3(hips_at.x - head_at.x, 0, hips_at.z - head_at.z)
	if along.length() > .15:
		rotation.y = atan2(-along.x, -along.z)
	collision_layer = LAYER
	collision_mask = 2 | 4 | 1
	velocity = Vector3.ZERO
	ragdolled = false
	state = State.GETUP
	_state_time = 0.0
	_state_len = float(CLIP_TIME["getup"]) / _getup_rate + .2
	anim.play("getup", 0.0)
	anim.speed_scale = _getup_rate
	last_seen = player.global_position
	var tween := create_tween()
	tween.tween_property(sim, "influence", 0.0, .55)
	tween.tween_callback(_end_ragdoll)

func _end_ragdoll() -> void:
	if ragdolled:
		sim.influence = 1.0
		return
	sim.physical_bones_stop_simulation()
	sim.influence = 1.0
	pose.active = true

# ---------------------------------------------------------------- without a leg

func _enter_crawl() -> void:
	state = State.CRAWL
	_state_time = 0.0
	_crawl_wait = randf_range(.4, 1.0)
	_bite_wait = 1.0
	_voice_timer = randf_range(.5, 2.0)

## It cannot stand. It pulls itself along by its arms: a heave of the chest and one arm, the rest dragged behind,
## toward the player; and what comes within its reach it bites.
func _crawl_tick(delta: float) -> void:
	var chest := _bodies.get("chest") as PhysicalBone3D
	var hips := _bodies.get("hips") as PhysicalBone3D
	if chest == null or hips == null:
		return
	_voice_timer -= delta
	if _voice_timer <= 0.0 and not voice.playing:
		_say("growl" if randf() < .6 else "groan", -1.0)
		_voice_timer = randf_range(2.0, 5.0)
	if not director.can_target():
		return
	var to := player.global_position - chest.global_position
	var height := to.y
	to.y = 0.0
	var dist := to.length()
	if dist > 34.0 or dist < .01:
		return
	_bite_wait -= delta
	_crawl_wait -= delta
	if dist < 1.15 and absf(height) < 1.3:
		if _bite_wait <= 0.0:
			_bite_wait = randf_range(2.4, 3.4)   # 0.59: half the attack speed (was 1.2-1.7 s)
			_say("attack", 1.0)
			director.hurt_player(randf_range(6.0, 11.0), chest.global_position)
		return
	if _crawl_wait > 0.0:
		return
	var arms := 0
	for side: String in ["L", "R"]:
		arms += 0 if _arm_gone[side] or severed.has("forearm." + side) else 1
	# With no arm left it can only writhe.
	_crawl_wait = randf_range(.8, 1.15) if arms > 0 else randf_range(1.4, 2.2)
	var dir := to / dist
	var pull := ((1.0 if arms == 2 else .7) if arms > 0 else .3) * (1.3 if bool(kin.get("crawls", false)) and not _legless else 1.0)
	chest.apply_central_impulse((dir * 3.8 * pull + Vector3.UP * 1.2) * chest.mass)
	hips.apply_central_impulse((dir * 2.7 * pull + Vector3.UP * .6) * hips.mass)
	for trunk: String in ["spine", "thigh.L", "thigh.R"]:
		var dragged := _bodies.get(trunk) as PhysicalBone3D
		if dragged != null:
			dragged.apply_central_impulse((dir * 2.0 * pull + Vector3.UP * .5) * dragged.mass)
	_crawl_side = not _crawl_side
	var side := ".L" if _crawl_side else ".R"
	if _arm_gone[side.right(1)]:
		side = ".R" if _crawl_side else ".L"
	for part: String in ["upper_arm", "forearm"]:
		var arm := _bodies.get(part + side) as PhysicalBone3D
		if arm != null:
			arm.apply_central_impulse((dir * 3.4 + Vector3.UP * 1.8) * arm.mass)
	_rest_time = 0.0

# ---------------------------------------------------------------- parts coming off

## Bone `id` and every bone below it, parents first.
func _chain(id: int) -> PackedInt32Array:
	var out := PackedInt32Array([id])
	for other in range(id + 1, skeleton.get_bone_count()):
		if skeleton.get_bone_parent(other) in out and not severed.has(skeleton.get_bone_name(other)):
			out.append(other)
	return out

## The part hanging from `bone` lets go. `way` is how the blow was travelling, `knock` how hard it was; a head with
## `burst` does not come off whole.
func _sever(bone: String, way: Vector3, knock: float, burst: bool) -> void:
	if severed.has(bone) or not _bodies.has(bone) or not is_inside_tree():
		return
	var id := skeleton.find_bone(bone)
	var body := _bodies[bone] as PhysicalBone3D
	if id < 0 or not is_instance_valid(body):
		return
	var chain := _chain(id)
	var spec: Array = BODIES[bone]
	var cut := body.global_transform * body.joint_offset.origin
	var along := body.global_position - cut
	along = along.normalized() if along.length() > .001 else Vector3.UP
	var speed := body.linear_velocity if ragdolled else velocity
	var blood: InteriorBlood = director.blood
	var mass := 0.0
	for bone_id in chain:
		var part := _bodies.get(skeleton.get_bone_name(bone_id)) as PhysicalBone3D
		mass += part.mass if part != null else 0.0
	var radius := .085 if bone == "head" else float(spec[1])
	var thrown := clampf(knock / 120.0, .5, 3.2)
	if burst:
		# It comes apart: pieces of it, and a great deal of blood. (0.64: on a phone too; it used to just vanish.)
		for k in 9:
			var out := (way * randf_range(.6, 1.6) + Vector3(randf_range(-1, 1), randf_range(.1, 1.3), randf_range(-1, 1))).normalized()
			blood.keep_gib(InteriorZombieGore.gib(blood, body.global_position + out * .05, speed + out * randf_range(1.5, 5.5)))
	else:
		var piece := InteriorZombieGore.piece(self, _scene, skeleton, _bodies, id, chain, radius, maxf(mass, .5), blood)
		piece.linear_velocity = speed + way * randf_range(.6, 1.4) * thrown + along * randf_range(.3, 1.0) + Vector3.UP * randf_range(.4, 1.3)
		piece.angular_velocity = Vector3(randf_range(-5, 5), randf_range(-3, 3), randf_range(-5, 5))
		blood.keep_piece(piece)
		blood.bleed(piece, piece.get_meta("cut"), Vector3.DOWN, 6.0, randf_range(5.0, 8.0), false)
	# The stump: on the bone above, where this one began.
	var parent_id := skeleton.get_bone_parent(id)
	var rest := skeleton.get_bone_rest(id)
	var attach := BoneAttachment3D.new()
	attach.name = "Stump " + bone
	attach.bone_name = skeleton.get_bone_name(parent_id)
	skeleton.add_child(attach)
	var cap := InteriorZombieGore.stump(.06 if bone == "head" else radius * 1.12)
	attach.add_child(cap)
	cap.transform = Transform3D(InteriorZombieGore.facing(rest.basis.y), rest.origin)
	# What it hung from pumps blood out of the cut.
	var above := ""
	var walk := parent_id
	while walk >= 0 and above == "":
		var candidate := skeleton.get_bone_name(walk)
		if _bodies.has(candidate) and not candidate in _names(chain):
			above = candidate
		walk = skeleton.get_bone_parent(walk)
	for bone_id in chain:
		var part_name := skeleton.get_bone_name(bone_id)
		if _bodies.has(part_name):
			var part := _bodies[part_name] as PhysicalBone3D
			_bodies.erase(part_name)
			part.collision_layer = 0
			part.queue_free()
	severed[bone] = true
	_sever_mod.bones.append(id)
	var small := bone.begins_with("hand") or bone.begins_with("foot")
	blood.sever_burst(cut, along, 2.2 if bone == "head" or bone.begins_with("thigh") else (.8 if small else 1.4), burst)
	var host := _bodies.get(above) as PhysicalBone3D
	if host != null:
		blood.bleed(host, host.global_transform.affine_inverse() * cut, host.global_basis.inverse() * along,
			9.0 if bone == "head" or bone.begins_with("thigh") else (4.0 if small else 6.5), randf_range(11.0, 16.0), true)
	_bleeding += .9 if bone.begins_with("thigh") else (.3 if small else .6)
	if bone.begins_with("upper_arm") or bone.begins_with("forearm"):
		_arm_gone[bone.right(1)] = true
	_apply_hurt()

## A piece torn out of a part that is still on: where the last round went in.
func _chunk(bone: String) -> void:
	var body := _bodies.get(bone) as PhysicalBone3D
	if body == null or not is_instance_valid(body) or not _sever_at.has(bone):
		return
	var spot: Array = _sever_at[bone]
	var radius := float((BODIES[bone] as Array)[1])
	director.blood.chunk(body, spot[0], -(spot[1] as Vector3), radius * (.62 if bone in TRUNK else .8),
		body.linear_velocity if ragdolled else velocity, bone in TRUNK)
	_bleeding += .25

## The chest has taken all it can hold. The arms and the head go their own ways, the ribs and what was behind them
## go everywhere, and what is left standing is hips and legs.
func _burst_chest(way: Vector3, knock: float) -> void:
	if severed.has("chest") or not _bodies.has("chest") or not is_inside_tree():
		return
	var chest := _bodies["chest"] as PhysicalBone3D
	var at := chest.global_position
	var speed := chest.linear_velocity if ragdolled else velocity
	var blood: InteriorBlood = director.blood
	var side := way.cross(Vector3.UP)
	side = side.normalized() if side.length() > .05 else Vector3.RIGHT
	for bone: String in ["upper_arm.L", "upper_arm.R", "head"]:
		if not severed.has(bone) and _bodies.has(bone):
			var out := Vector3.UP if bone == "head" else side * (1.0 if bone.ends_with(".L") else -1.0)
			_sever(bone, (way * .6 + out).normalized(), knock * 1.3, false)
	var id := skeleton.find_bone("chest")
	var rest := skeleton.get_bone_rest(id)
	var attach := BoneAttachment3D.new()
	attach.name = "Stump chest"
	attach.bone_name = skeleton.get_bone_name(skeleton.get_bone_parent(id))
	skeleton.add_child(attach)
	var cap := InteriorZombieGore.stump(.15)
	attach.add_child(cap)
	cap.transform = Transform3D(InteriorZombieGore.facing(rest.basis.y), rest.origin)
	_bodies.erase("chest")
	chest.collision_layer = 0
	chest.queue_free()
	severed["chest"] = true
	_sever_mod.bones.append(id)
	_burst_done["chest"] = true
	blood.sever_burst(at, Vector3.UP, 3.2, true)
	blood.shatter(at, speed, way, 16, true)
	var host := _bodies.get("spine", _bodies.get("hips")) as PhysicalBone3D
	if host != null:
		blood.bleed(host, host.global_transform.affine_inverse() * at, Vector3.UP, 9.0, randf_range(8.0, 12.0), true)
	health = minf(health, 0.0)
	if not ragdolled:
		_ragdoll([], way * knock)
	_die()

## The belly gives way: the legs let go at the hips, and what was inside comes out with them.
func _burst_belly(bone: String, way: Vector3, knock: float) -> void:
	if _burst_done.has("belly") or not is_inside_tree():
		return
	_burst_done["belly"] = true
	_burst_done["hips"] = true
	_burst_done["spine"] = true
	var body := _bodies.get(bone, _bodies.get("hips")) as PhysicalBone3D
	if body == null:
		return
	var at := body.global_position
	var speed := body.linear_velocity if ragdolled else velocity
	var blood: InteriorBlood = director.blood
	var side := way.cross(Vector3.UP)
	side = side.normalized() if side.length() > .05 else Vector3.RIGHT
	for leg: String in ["thigh.L", "thigh.R"]:
		if not severed.has(leg) and _bodies.has(leg):
			_sever(leg, (way * .5 + side * (1.0 if leg.ends_with(".L") else -1.0) + Vector3.DOWN * .3).normalized(), knock, false)
	_legless = true
	blood.sever_burst(at, Vector3.DOWN, 2.6, true)
	blood.shatter(at, speed, way, 11, false)
	_bleeding += 2.2
	_gut_hurt = 1.0
	_apply_hurt()
	if not ragdolled and alive():
		_ragdoll([], way * knock)

func _names(chain: PackedInt32Array) -> Array:
	var out := []
	for bone_id in chain:
		out.append(skeleton.get_bone_name(bone_id))
	return out

## The hole a round leaves: a small decal on the struck part, moving with it (only the infected's own layer). The
## blood runs down from it for a few seconds.
func _add_wound(body: Node3D, point: Vector3, dir: Vector3) -> void:
	if not is_instance_valid(body):
		return
	if _wounds.size() >= 6:
		var old: Variant = _wounds.pop_front()
		if is_instance_valid(old):
			(old as Node).queue_free()
	var decal := director.blood.wound_decal() as Node3D
	decal.set("cull_mask", RENDER_LAYER)
	body.add_child(decal)
	var y := -dir
	var down := Vector3.DOWN - y * Vector3.DOWN.dot(y)
	if down.length() < .1:
		down = y.cross(Vector3.RIGHT)
	var z := down.normalized()
	decal.global_transform = Transform3D(Basis(y.cross(z), y, z), point)
	var run := randf_range(.05, .16)
	var tween := decal.create_tween().set_parallel(true)
	var start_size: Vector3 = decal.get("size")
	tween.tween_property(decal, "size", start_size + Vector3(.02, 0, run), randf_range(3.0, 6.0)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(decal, "position", decal.position + decal.basis.z * run * .5, 4.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_wounds.append(decal)
