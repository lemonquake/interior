class_name InteriorGun
extends Node
## 0.11: the Glock 17 from the hut's drawer, usable (owned by scripts/story.gd).
##
## Ammo: it comes out of the drawer empty (pulling the trigger dry-clicks: "It's empty."). The hooded man's 60 rounds
## go to the reserve. The magazine holds 17, plus 1 in the chamber; the first reload loads 17 and racks the slide,
## so 17 are loaded (16 + 1) and 43 are left. A later reload pockets what was left in the old magazine.
## Equip: 1 / G draws and holsters (mobile: the Gun button). Drawing drops what is held; Hold (E) on a prop or a
## door leaves the gun where it is (0.30). Left click (mobile: Fire) shoots, R (Reload) reloads, F while drawn opens the inspect screen.
## Shots leave from the weapon's breech (0.37, `BARREL`), not the camera, and fly as projectiles tested tick by tick
## (0.37, `Round`), collision mask 2|4|16; the pistol is semi-automatic (one per click).
## No enemies, and the stranger has no collider: shots never touch him. Pets are never harmed: the hamster and
## fish enclosures' glass stops the round and takes a crack.
## Each shot: a muzzle flash (a card in the view model and a 40 ms light in the world, so walls light up), a short
## camera kick, the round thrown from the slide (the model's own "fire" clip), a 3D gunshot on the "Gun" bus with a
## far echo outdoors, and an impact by surface: a bullet hole (6 cm, at most 40, oldest reused), dust or splinters,
## a ricochet on metal, a splash on water; props are knocked (6 N s along the ray) and a TV stops on static.
## The view model (arms: assets/characters/fp_arms.glb, gun: assets/models/story/glock17.glb) renders in its own
## world in a SubViewport under the HUD, so it never clips into walls; it is lit to roughly match where you are.
##
## 0.27, from the owner's reference video, frame by frame (work/v27/reference):
##  - The hands hold the weapon and the arms reach for it (scripts/arm_ik.gd): the shoulders stay with the body, so
##    aiming, turning and recoil bend the wrists and swing the forearms. The weapon has weight: it hangs back from
##    a swing of the mouse, banks into it, and carries on a little when the swing stops.
##  - Recoil is the hands' spring (muzzle flip, shove back, roll, yaw), the lens' spring (player.punch) and what
##    each shot leaves the muzzle off by (it climbs and wanders). A round goes where the muzzle points at that
##    instant, inside a cone that opens with every shot of a string: fast fire sprays.
##  - The pistol fires as fast as the finger (about nine a second); its muzzle flips some 25 degrees at the wrists
##    while the lens hardly moves. Smoke hangs at the muzzle after each shot.
##  - A second weapon, debug menu only (PROFILES.rifle): an AR-15 pattern carbine (assets/models/story/ar15.glb,
##    tools/blender/story/build_ar15.py), 30 rounds, automatic at 600 a minute while the trigger is held (B: single
##    shots). It is shouldered, so every round shakes the whole picture; brass flies, every third round is a tracer.
##    2 brings it up, 1 / G the pistol.
##
## 0.28: the rifle is automatic for as long as the trigger is held (the owner's video again). A third weapon, debug
## menu only (PROFILES.shotgun): a pump 12 gauge (assets/models/story/shotgun.glb, tools/blender/story/
## build_shotgun.py), seven in the tube and one in the chamber, nine pellets a shell, pumped after every shot, loaded
## one shell at a time (a pull of the trigger stops the loading). 3 brings it up. Rounds are projectiles now (see
## PATH_STEPS): speed, drop, time of flight, energy left at the target, and the infected (scripts/zombie.gd) take
## them by where they are hit.
##
## 0.29: a fourth weapon, debug menu only (PROFILES.sniper): a bolt-action .338 (assets/models/story/sniper.glb,
## tools/blender/story/build_sniper.py), five in the box magazine and one in the chamber, the bolt worked by the
## right hand after every shot. 4 brings it up. From the hip it is a long heavy rifle that hits somewhere near;
## with the right button held the eye goes to its scope (scripts/scope.gdshader): the lens itself narrows to the
## scope's power, 8x to begin with, and the mouse wheel turns the power ring between 2x and 8x. The picture swims
## with the breath (Shift holds it, for a few seconds), loses focus when the rifle moves, fires or the ring is
## turned, and the round still drops on its way: at 200 m, most of a third of a metre. It goes through two bodies.
## Every profile has `sever`: how much of a round's energy goes into breaking the part it hits (scripts/zombie.gd).
##
## 0.48: the named arsenal (scripts/arsenal.gd). `weapon` is still the mechanism in the hands ("pistol", "rifle",
## "shotgun", "sniper"); `models[weapon]` is which weapon of that kind it is (one carried per kind, like a loadout),
## and `_prof()` its figures: the mechanism's PROFILES entry with the weapon's own over it. A weapon with its own
## model shows that model (pistols on the Glock's frame, long guns built with `_build_long` from the model's
## sockets); `cycle: "self"` fires without the pump or the bolt, `burst` fires that many a pull, a sniper rifle has
## its own scope powers and reticle.

signal fired
signal reloaded
signal ammo_changed

const MAG_SIZE := 17
const RANGE := 80.0
## Layers 2 and 3 (the world and its props) and 5: the hit boxes of the infected (scripts/zombie.gd).
const MASK := 2 | 4 | 16 | 64   # 0.49: 64 = InteriorModelKit.SHOT_LAYER, models as drawn
const SHOT_INTERVAL := .11          # the pistol: as fast as the finger, about nine a second
const DRAW_TIME := .45
const HOLSTER_TIME := .35
const RELOAD_TIME := 1.6
## fp_reload timeline (s): the magazine drops out, the new one is seated, the slide is pulled back and let go.
const RELOAD_MAG_OUT := .30
const RELOAD_MAG_IN := .95
const RELOAD_RACK := 1.27
const RELOAD_RELEASE := 1.30
const DRY_TOAST := "It's empty."
const DRY_TOAST_EVERY := 3.0
const IMPULSE := 6.0                # N s along the ray
const DECAL_SIZE := .06
const DECAL_MAX := 120
const KICK_DEG := .55
const VIEW_FOV := 55.0
## 0.27: the hands and the weapon are drawn through a longer lens than the world (this much of its field of view),
## as the reference shows them: large, close under the camera. Aim angles are scaled to match, so the muzzle is
## still drawn pointing where the round goes. 0.31: half the world's field of view (it was .78), and the weapons
## are carried lower, so that what is on screen is the weapon and the hands holding it are under its edge.
const VIEW_SCALE := .37
## 0.32: the camera is an action camera on the forehead, and what it shows of a weapon is the weapon: the frame's
## lower edge cuts across it just ahead of the hands (`_hands_over_edge` pushes the weapon down until the wrists,
## palms and knuckles are under the edge, in every stance and wherever the muzzle is swung), and what is nearest
## the lens is out of its focus and in the wearer's own shadow (gun_near.gdshader on the view).
## How far under the edge the hands are kept (as a share of the half height), and the places on a hand that
## count: in the hand bone's frame (+Y down the hand, the knuckles at .10), each with the hand's thickness there.
const CROP_MARGIN := .05
const HAND_SPOTS := [[Vector3(.0, .0, .0), .032], [Vector3(.0, .05, .0), .032], [Vector3(-.03, .098, .0), .018],
	[Vector3(.0, .102, .0), .018], [Vector3(.03, .098, .0), .018], [Vector3(-.03, .125, -.055), .013], [Vector3(.03, .125, -.055), .013]]
## The hand under a long gun has its thumb up one side of it: where that ends (either hand).
const GUARD_SPOTS := [[Vector3(.055, .05, -.045), .013], [Vector3(-.055, .05, -.045), .013]]
const NEAR_SHADER := preload("res://scripts/gun_near.gdshader")
## 0.26 body-camera handling. The weapon is held in front of the chest camera and is aimed by the hands, not by the
## lens: the mouse swings the muzzle inside a free zone and the view follows (player.gd free aim).
## 0.27: what differs between the two weapons. Angles in radians, lengths in metres, times in seconds.
##   *_at / *_turn   where the rear sight sits in front of the lens (x right, y up, -z ahead) and how the weapon is
##                   turned (pitch, yaw, roll): ready, sights up, running, tucked against a wall
##   pivot           what recoil and the weapon's weight turn it about, from the rear sight (wrists / the butt)
##   shoulders, blade  where the shoulders are from the lens, and how far the body is turned behind the weapon
##   inertia, cant   how far it hangs back from a swing, and how far it banks into one (per rad/s)
##   flip, shove, roll, yaw, omega, damping   the hands' recoil spring: impulses per shot, stiffness
##   punch, punch_bias, kick, jolt            the lens: spring impulse (pitch, yaw, roll), what stays, the knock
##   climb           what a shot leaves the muzzle off by: yaw either way, pitch up
##   spread          the cone: at rest, added per shot, the most, how fast it closes per second
##   kick_aim        how much of the hands' kick the next round inherits
## The hands turn about the wrists: a little below and behind the rear sight.
const WRIST := Vector3(.0, -.1, .035)
const RIFLE_MAG_SIZE := 30
const SHOTGUN_TUBE := 7
const SNIPER_MAG := 5
## The scope's powers, and what the wheel turns it by.
const SCOPE_MIN := 2.0
const SCOPE_MAX := 8.0
## The bolt (s after the shot): the handle is up, the bolt is back (the case leaves), it starts forward, it is home,
## the handle is down; its travel, and how far the handle turns.
const BOLT := [.2, .4, .5, .7, .85]
const BOLT_TIME := .95
const BOLT_TRAVEL := .095
const BOLT_LIFT := 1.05
const PROFILES := {
	"pistol": {
		"label": "Glock 17", "mag": 17, "interval": SHOT_INTERVAL, "automatic": false, "draw": DRAW_TIME, "holster": HOLSTER_TIME,
		"hip_at": Vector3(.045, -.06, -.17), "hip_turn": Vector3(.07, -.1, -.14),
		# The idle clip holds the muzzle about six degrees in toward the middle; the stances square it up.
		"ads_at": Vector3(.0, -.04, -.21), "ads_turn": Vector3(.0, -.102, .0),
		# Running: muzzle down and across the body. Close to a wall: pulled in, muzzle up.
		"run_at": Vector3(.06, -.11, -.22), "run_turn": Vector3(-.36, .42, .28),
		"tuck_at": Vector3(.045, -.13, -.18), "tuck_turn": Vector3(.72, .08, -.2),
		"pivot": WRIST, "shoulders": Vector3(.0, -.27, .09), "blade": .0, "body_shove": .25, "crop": -.02,
		"hip_zone": Vector2(.2, .125), "ads_zone": Vector2(.06, .045), "ads_fov": -10.0, "ads_pace": .62,
		"follow": Vector2(4.6, 9.0), "inertia": .016, "cant": .045,
		"flip": 21.0, "shove": Vector3(.25, .8, 1.1), "roll": 4.5, "yaw": 2.4, "omega": 30.0, "damping": .42,
		"punch": Vector3(.65, .45, 2.4), "punch_bias": .0, "kick": .5, "jolt": .0075,
		"climb": Vector2(.011, .02), "spread": [.005, .006, .035, .1], "kick_aim": .5,
		"impulse": IMPULSE, "flash": 5.0, "flash_range": 6.0, "lens": .75, "pitch": 1.0, "volume": 2.0,
		"round": "9 mm", "pellets": 1, "velocity": 375.0, "drag": 420.0, "damage": 34.0, "knock": 60.0, "bore": 1.0, "pierce": false, "sever": .3,
	},
	"rifle": {
		"label": "AR-15", "mag": RIFLE_MAG_SIZE, "interval": .1, "automatic": true, "draw": .55, "holster": .4,
		"hip_at": Vector3(.045, -.085, -.1), "hip_turn": Vector3(.05, .07, -.08),
		"ads_at": Vector3(.0, -.045, -.1), "ads_turn": Vector3.ZERO,
		"run_at": Vector3(.06, -.16, -.05), "run_turn": Vector3(-.5, .5, .2),
		"tuck_at": Vector3(.04, -.16, -.02), "tuck_turn": Vector3(.9, .1, -.15),
		"pivot": Vector3(.0, -.106, .29), "shoulders": Vector3(.0, -.25, .05), "blade": -.2, "body_shove": .6,
		"hip_zone": Vector2(.16, .1), "ads_zone": Vector2(.045, .035), "ads_fov": -14.0, "ads_pace": .55,
		"follow": Vector2(5.2, 10.0), "inertia": .026, "cant": .06,
		"flip": 3.4, "shove": Vector3(.35, .35, 1.3), "roll": 2.6, "yaw": 1.3, "omega": 34.0, "damping": .4,
		"punch": Vector3(2.7, 1.7, 4.4), "punch_bias": .25, "kick": .3, "jolt": .012,
		"climb": Vector2(.014, .011), "spread": [.0045, .0035, .035, .12], "kick_aim": 1.0,
		"impulse": 9.0, "flash": 7.0, "flash_range": 10.0, "lens": .6, "pitch": .8, "volume": 4.0,
		"round": "5.56 mm", "pellets": 1, "velocity": 940.0, "drag": 600.0, "damage": 46.0, "knock": 95.0, "bore": 2.2, "pierce": true, "sever": .7,
	},
	"shotgun": {
		"label": "12 gauge", "mag": SHOTGUN_TUBE, "interval": .82, "automatic": false, "draw": .6, "holster": .45,
		"hip_at": Vector3(.045, -.08, -.06), "hip_turn": Vector3(.05, .07, -.08),
		"ads_at": Vector3(.0, -.03, -.1), "ads_turn": Vector3(-.035, .0, .0),
		"run_at": Vector3(.06, -.16, -.05), "run_turn": Vector3(-.5, .5, .2),
		"tuck_at": Vector3(.04, -.16, -.02), "tuck_turn": Vector3(.9, .1, -.15),
		"pivot": Vector3(.0, -.08, .34), "shoulders": Vector3(.0, -.25, .05), "blade": -.2, "body_shove": .8,
		"hip_zone": Vector2(.16, .1), "ads_zone": Vector2(.045, .035), "ads_fov": -10.0, "ads_pace": .55,
		"follow": Vector2(5.0, 9.5), "inertia": .03, "cant": .065,
		"flip": 7.0, "shove": Vector3(.4, .5, 1.4), "roll": 4.0, "yaw": 2.2, "omega": 22.0, "damping": .5,
		"punch": Vector3(6.5, 2.4, 6.0), "punch_bias": .2, "kick": 1.4, "jolt": .03,
		"climb": Vector2(.02, .05), "spread": [.006, .012, .03, .08], "kick_aim": .6,
		"impulse": 5.0, "flash": 11.0, "flash_range": 13.0, "lens": 1.0, "pitch": .58, "volume": 6.0,
		# 0.31: 00 buck as it is. Nine 8.4 mm lead balls of 3.5 g leave together at about 400 m/s, each a little faster
		# or slower than the next, in a pattern about an inch wide for every yard (`pattern` is its standard deviation
		# in radians: most of the load in the middle, a flyer or two outside it). A ball that size holds its speed badly
		# next to a bullet but is far from spent at 40 m; it goes through an arm or a shin and on into what is behind,
		# stops in a trunk, and skips off stone or steel that it meets at a shallow angle.
		"round": "12 gauge 00 buck", "pellets": 9, "pattern": .0105, "velocity": 400.0, "velocity_spread": .05, "drag": 130.0,
		"damage": 19.0, "knock": 85.0, "bore": .5, "pierce": false, "limb_pierce": true, "keep": .5, "skip": true, "sever": 1.3,
	},
	"sniper": {
		"label": ".338 bolt action", "mag": SNIPER_MAG, "interval": 1.05, "automatic": false, "draw": .7, "holster": .5,
		"hip_at": Vector3(.045, -.125, -.06), "hip_turn": Vector3(.05, .07, -.08),
		"ads_at": Vector3(.0, .0, -.075), "ads_turn": Vector3.ZERO,
		"run_at": Vector3(.06, -.2, -.02), "run_turn": Vector3(-.5, .5, .2),
		"tuck_at": Vector3(.04, -.2, .0), "tuck_turn": Vector3(.9, .1, -.15),
		"pivot": Vector3(.0, -.1, .27), "shoulders": Vector3(.0, -.25, .05), "blade": -.22, "body_shove": .8,
		"hip_zone": Vector2(.14, .09), "ads_zone": Vector2(.03, .025), "ads_fov": -12.0, "ads_pace": .4,
		"follow": Vector2(4.6, 9.0), "inertia": .036, "cant": .07,
		"flip": 6.0, "shove": Vector3(.4, .5, 1.7), "roll": 3.4, "yaw": 1.8, "omega": 20.0, "damping": .55,
		"punch": Vector3(7.5, 2.2, 4.5), "punch_bias": .2, "kick": 1.8, "jolt": .03,
		"climb": Vector2(.012, .04), "spread": [.0009, .004, .02, .06], "hip_spread": 16.0, "kick_aim": .15,
		"impulse": 14.0, "flash": 13.0, "flash_range": 15.0, "lens": 1.0, "pitch": .5, "volume": 7.0,
		"round": ".338", "pellets": 1, "velocity": 915.0, "drag": 1500.0, "damage": 160.0, "knock": 300.0, "bore": 3.5, "pierce": true,
		"sever": 1.7, "passes": 3, "keep": .65, "range": 320.0, "scope": true,
	},
}
## 0.28 ballistics. Every round is a projectile with its own figures (PROFILES: round, pellets, velocity m/s, drag,
## damage, knock, pierce): it leaves at `velocity`, loses speed over `drag` metres (to 1/e), drops under gravity, and
## arrives after its time of flight with what energy it has left. A 9 mm is slow and heavy, a 5.56 is fast, flat and
## goes through a body into what is behind it, buckshot is nine pellets that spread and are spent by 40 m.
## Where the path is tested, in metres from the muzzle.
const PATH_STEPS: Array[float] = [8.0, 20.0, 40.0, 60.0, 80.0, 115.0, 160.0, 210.0, 265.0, 320.0]
## The pump (s after the shot): starts back, is back (the shell leaves), starts forward, is home; and its travel.
const PUMP := [.16, .32, .4, .58]
const PUMP_TIME := .66
const PUMP_TRAVEL := .085
## One shell into the tube.
const SHELL_TIME := .58
## The rifle's reload (s): the magazine comes out, the new one is seated, the bolt catch is slapped, the bolt is
## home, the hand is back on the handguard.
const RIFLE_RELOAD := [.62, 1.45, 1.85, 1.9, 2.4]
## Where the two shoulder joints' midpoint is in the arms' rig (fp_arms.glb turned to look down -Z).
const SHOULDER_MID := Vector3(.0, -.24, .11)
## The fists' holes in the hand bones' frames (tools/blender/human/build_fp_arms.py), where the pistol's grip passes
## through the right fist in the Glock's own frame, and how much further back the rifle's grip leans.
const HOLE_L := Vector3(.007, .07, -.026)
const PISTOL_GRIP := Vector3(.0, -.0141, -.0507)
## The Glock's sights in its own frame (muzzle along +Z): the top of the slide at its rear and at its front. (The
## model's bounding box is a third taller than the pistol, so it cannot be used for this.)
const PISTOL_REAR_SIGHT := Vector3(.0, .0731, -.0625)
const PISTOL_FRONT_SIGHT := Vector3(.0, .0731, .1014)
const RIFLE_GRIP_TILT := -.227
## Rear-sight position in the rig before the idle pose has been measured (fp_idle, frame 0).
const SIGHT_GUESS := Vector3(.151, -.051, -.36)
const WATER_Y := -3.32
const ARMS := "res://assets/characters/fp_arms.glb"
const HAND_TEXTURES := "res://assets/characters/hands/"
const GLOCK := preload("res://assets/models/story/glock17.glb")
const RIFLE := preload("res://assets/models/story/ar15.glb")
const SHOTGUN := preload("res://assets/models/story/shotgun.glb")
const SNIPER := preload("res://assets/models/story/sniper.glb")
const SCOPE_SHADER := preload("res://scripts/scope.gdshader")
const HOLE_SHADER := preload("res://scripts/bullet_hole.gdshader")
const SFX := "res://assets/audio/sfx/"
const BUS := "Gun"
## 0.31: what the fingers do on each thing they hold (scripts/arm_ik.gd `finger_pose`, degrees). Four fingers:
## [curl at the knuckle, the middle joint, the last joint, spread]; the thumb: [curl, spread, roll, second joint, last].
const HAND_POSES := {
	# Hanging, or on the way to something: the hand model's own relaxed pose.
	"relaxed": {"index": [0, 0, 0, 0], "middle": [2, 2, 0, 0], "ring": [4, 4, 2, 0], "pinky": [6, 6, 2, 0], "thumb": [0, 0, 0, 0, 0]},
	# The holds below are what is used when a weapon has no fit of its own (assets/hand_fits.json).
	"pistol": {"index": [-4, -16, -10, 12], "middle": [58, 62, 22, 0], "ring": [60, 64, 24, 0], "pinky": [62, 66, 28, 0], "thumb": [16, 0, 0, 14, 10]},
	"support": {"index": [50, 56, 22, 0], "middle": [52, 58, 22, 0], "ring": [54, 60, 24, 0], "pinky": [56, 62, 26, 0], "thumb": [4, 0, 0, 2, 2]},
	"grip": {"index": [-4, -16, -10, 12], "middle": [54, 60, 20, 0], "ring": [56, 62, 22, 0], "pinky": [58, 64, 26, 0], "thumb": [14, 0, 0, 12, 8]},
	"guard": {"index": [52, 36, 18, 0], "middle": [54, 38, 18, 0], "ring": [54, 40, 20, 0], "pinky": [56, 42, 22, 0], "thumb": [14, 0, 0, 8, 6]},
	# Round a magazine.
	"mag": {"index": [34, 40, 18, 0], "middle": [38, 44, 20, 0], "ring": [42, 46, 22, 0], "pinky": [46, 48, 24, 0], "thumb": [18, 0, 0, 12, 8]},
	# Over the top of a slide, pinching it.
	"rack": {"index": [40, 50, 20, 0], "middle": [42, 52, 20, 0], "ring": [46, 54, 22, 0], "pinky": [50, 56, 24, 0], "thumb": [20, 0, 0, 14, 10]},
	# 0.32: the bolt catch pressed with the thumb, the fingers closed (it was a flat hand, which stood up into the picture).
	"slap": {"index": [62, 78, 40, 0], "middle": [66, 82, 42, 0], "ring": [68, 84, 44, 0], "pinky": [70, 84, 46, 0], "thumb": [-6, 8, 0, -4, -4]},
	# Two fingers and the thumb on a bolt handle.
	"bolt": {"index": [30, 42, 20, 0], "middle": [34, 46, 22, 0], "ring": [60, 76, 34, 0], "pinky": [64, 78, 36, 0], "thumb": [20, 0, 0, 16, 14]},
	# A shell between the fingers and the thumb.
	"shell": {"index": [32, 38, 18, 0], "middle": [36, 40, 20, 0], "ring": [52, 64, 30, 0], "pinky": [56, 68, 32, 0], "thumb": [22, 0, 0, 16, 10]},
}
## The index finger on the trigger, and through its pull.
const TRIGGER_FINGER := [10, 30, 10, 2]
## What pulling the trigger adds to the finger on it (degrees at each joint).
const TRIGGER_PULL := [3.0, 9.0, 5.0]
## Which way the index finger leans when it lies along the frame, and when it goes into the trigger guard.
const FIT_INDEX_UP := 12.0
const FIT_INDEX_IN := 2.0
## 0.31, measured on the real-size Glock (tests/_glock_dims.gd; +Z the muzzle, +Y up, +X its left). The right hand's
## place on it comes with the arms (tools/blender/human/build_fp_arms.py `right_on_grip`: the web of the hand in the
## hollow under the beavertail). The left hand is the right one mirrored, canted forward and down (thumbs forward),
## with its index knuckle under the trigger guard against the right hand's fingers.
const PISTOL_IN_HAND := Vector3.ZERO
const SUPPORT_CANT := .26
const SUPPORT_KNUCKLE := Vector3(.036, -.010, -.030)
const INDEX_KNUCKLE_L := Vector3(.0226, .1017, -.0064)
## The left hand's middle knuckle, which sits under a handguard or a pump a little left of its middle: the fingers' first
## bones go across under it and the rest of them up its far side.
const GUARD_KNUCKLE := Vector3(.0, .102, .0)
## Where fingers that are not simply wrapped go, on the Glock: the right index finger along the frame and on the
## trigger, the right thumb forward along the left side, the left thumb ahead of it.
const REACH := {"along": Vector3(-.0235, .037, .05), "trigger": Vector3(-.003, .021, .0245), "thumb_r": Vector3(.0225, .039, -.004),
	"thumb_l": Vector3(.0225, .033, .036)}
## How far from the middle of a long gun's grip the palm lies, compared with the Glock's.
const LONG_GRIP_OUT := .0065
## Without fp_arms.glb: where the gun sits in front of the view camera (right of centre, low).
const GUN_REST := Transform3D(Basis(Vector3.UP, PI), Vector3(.13, -.13, -.36))

var owned := false
## 0.20 debug menu: every shot leaves the magazine full.
var infinite_ammo := false
var drawn := false
var mag := 0
var chambered := false
var reserve := 0
var reloading := false
var main: Node
var player: InteriorPlayer
var story: Node
var mobile := false
var ammo_label: Label
var _time := 0.0
var _busy_until := 0.0
var _last_shot := -10.0
var _last_dry_toast := -10.0
var _reload_t := -1.0
var _reload_steps := 0
var _decals: Array[Node3D] = []
var _holes: Node3D
var _container: SubViewportContainer
var _viewport: SubViewport
var _view_camera: Camera3D
var _rig: Node3D
var _arms: Node3D
var _arms_anim: AnimationPlayer
var _glock: Node3D
var _glock_anim: AnimationPlayer
var _parts := {}                    # magazine / slide nodes -> rest transform relative to the gun's root
var _muzzle: Node3D
var _flash_card: MeshInstance3D
var _flash_light: OmniLight3D
var _key: DirectionalLight3D
var _env: Environment
var _show := 0.0                    # 0 holstered (out of view) .. 1 up
var _show_target := 0.0
var _floor := 0.0
var _rim: DirectionalLight3D
var _studio: PanoramaSkyMaterial
var _near: ShaderMaterial
var _last_view_basis := Basis.IDENTITY
var _lag := Vector2.ZERO
## 0.26: right mouse button held: the sights come up to the lens.
var aiming := false
## Options: Aim "Body camera" (the muzzle leads the view) or "Centred" (the muzzle stays on the crosshair).
var free_aim := true
var _ads := 0.0
var _run := 0.0
var _tuck := 0.0
## 0.33: down out of the way while the hands climb or bind a wound.
var _stow := 0.0
var _keep_up := 0.0
var _sight := SIGHT_GUESS
var _sight_measured := false
## 0.40: the line the sights make (rear notch to front post), in the weapon's sight frame; the same line as drawn
## this frame in the view camera's space; and the view lens' scale against the world lens'. A round goes along
## the drawn line (`_shot_basis`), so the front post sits where it lands, at the hip as on the sights.
var _sight_line := Vector3.FORWARD
var _view_line := Vector3.FORWARD
var _view_ratio := 1.0
var _view_line_valid := false
var _rear_fix := Vector3.ZERO
## Rounds by the 0.39 rule (lens line plus part of the kick) instead: A/B measurements only.
var legacy_aim := "--legacy-aim" in OS.get_cmdline_user_args()
var _kick := Vector3.ZERO           # the hands' recoil: pitch, yaw, roll (rad)
var _kick_velocity := Vector3.ZERO
var _kick_at := Vector3.ZERO        # ...and where it shoves the weapon: right, up, back (m)
var _kick_at_velocity := Vector3.ZERO
## 0.27: which weapon is in the hands ("pistol" / "rifle"); `mag`, `chambered` and `reserve` are that weapon's.
var weapon := "pistol"
## 0.46 (co-op): more beside the ammunition (the healthkits carried).
var extra_hud := ""
## The secret rifle: given by the debug menu only.
var rifle_owned := false
## 0.28: the pump shotgun, debug menu only as well.
var shotgun_owned := false
## 0.29: the sniper rifle, debug menu only too. `scope_zoom` is its scope's power; `scoped` how far the eye is in
## the scope (0 to 1).
var sniper_owned := false
var scope_zoom := SCOPE_MAX
var scoped := 0.0
var _scope_rect: ColorRect
var _scope_shade: ShaderMaterial
var _scope_blur := 0.0
var _scope_eye := Vector2.ZERO
var _scope_time := 0.0
var _breath_held := 0.0
var _breath_out := 0.0
var _scope_hint := false
var _cycle_eject := false
## Tests: rounds arrive at once instead of after their time of flight.
var instant_hits := false
## Every hit of the last trigger pull: [{position, normal, collider, surface, distance, power}].
var last_hits: Array = []
## 0.33: how many times a round has come out the far side of something.
var pierced := 0
var _longs := {}
## 0.48: which weapon of each kind is carried (scripts/arsenal.gd ids), its figures, the pistols' own models.
var models := {"pistol": "glock17", "rifle": "ar15", "shotgun": "pump12", "sniper": "bolt338"}
var _profiles := {}
var _pistol_kits := {}
var _glock_meshes: Array = []
var _glock_muzzle := Vector3.ZERO
var _burst_left := 0
var _pump_t := -1.0
var _pump_step := 0
var _shell_t := -1.0
var _shell_in := false
var _shell_blend := 0.0
var _fx_frame := -1
var _fx_count := 0
## The rifle's selector: automatic while the trigger is held, or one round a pull.
var automatic := true
## The trigger is being held by something other than the mouse (the touch Fire button, a test).
var trigger_held := false
## 0.64: a phone's Aim button (the right mouse button's sights): on until tapped again or the weapon goes away.
var touch_aim := false
## Tests: 0 puts every round exactly on the muzzle line (no cone, no inherited kick).
var spread_scale := 1.0
## Rounds fired without a pause of a third of a second.
var shots_in_burst := 0
## The direction the last round left in (world).
var last_shot_direction := Vector3.FORWARD
var _stock := {"pistol": {"mag": 0, "chambered": false, "reserve": 0}, "rifle": {"mag": 0, "chambered": false, "reserve": 0},
	"shotgun": {"mag": 0, "chambered": false, "reserve": 0}, "sniper": {"mag": 0, "chambered": false, "reserve": 0}}
var _pending := ""
var _next_shot := 0.0
var _bloom := 0.0
var _burst_bias := 0.0
var _sway := Vector3.ZERO           # the weapon's weight against the aim: pitch, yaw, roll (rad)
var _sway_velocity := Vector3.ZERO
var _aim_rate := Vector2.ZERO
var _last_heading := Vector2.ZERO
var _ik: InteriorArmIK
var _skeleton: Skeleton3D
var _skel_to_rig := Transform3D.IDENTITY
var _grip_local := Transform3D.IDENTITY
var _rifle: Node3D
var _rifle_at := {}
var _rifle_parts := {}
var _rifle_rest := {}
var _rifle_hands := {}
var _rifle_muzzle: Node3D
var _pistol_muzzle: Node3D
var _flash_cards := {}
var _casings: Array = []
var _bolt_t := 0.0
var _report := "--gun-report" in OS.get_cmdline_user_args()
var _breath := 0.0
## 0.31: how far the index finger is into the trigger (0 along the frame, 1 on it, 2 pulled), and the outside camera
## the captures look at the hands with.
var _trigger := 0.0
var _trigger_until := 0.0
var _inspect_camera: Camera3D
var _drift := Vector3.ZERO
var _tuck_timer := 0.0
var _near_wall := false
var _shot_voice: AudioStreamPlayer3D
var _tail_voice: AudioStreamPlayer
var _hand_voice: AudioStreamPlayer
var _reverb: AudioEffectReverb
var _streams := {}
## Where the last round went: {position, normal, collider, surface} (empty for a miss).
var last_hit := {}
var _hole_texture: ImageTexture
var _crack_texture: ImageTexture

func setup(main_node: Node, story_node: Node) -> void:
	main = main_node
	story = story_node
	player = main.player
	mobile = main.mobile
	name = "Gun"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("gun")
	_holes = Node3D.new()
	_holes.name = "BulletHoles"
	main.add_child(_holes)
	_build_audio()
	_build_view()
	_build_hud()
	_hole_texture = _make_hole_texture(false)
	_crack_texture = _make_hole_texture(true)
	player.fire_hook = try_fire
	player.use_hook = _before_use
	_update_hud()

# ---------------------------------------------------------------- state

func give() -> void:
	owned = true
	ammo_changed.emit()
	_update_hud()

## Debug menu only: the secret rifle, a full magazine in it and ten spare.
func give_rifle() -> void:
	give_long("rifle", RIFLE_MAG_SIZE * 10)

## Debug menu only: the pump shotgun, loaded, and 64 shells.
func give_shotgun() -> void:
	give_long("shotgun", 64)

## Debug menu only: the sniper rifle, loaded, and 40 rounds.
func give_sniper() -> void:
	give_long("sniper", 40)

## 0.48: a named weapon (scripts/arsenal.gd id), loaded, with `spare` rounds; it takes the place of what was
## carried of its kind. Returns what that was ({} when nothing).
func give_model(id: String, spare: int) -> Dictionary:
	var cls := InteriorArsenal.class_of(id)
	if cls == "":
		return {}
	id = InteriorArsenal.resolve(id)
	var size := int(profile_of(id).mag)
	var out := take_weapon(id, size - 1, true, spare)
	return out

func give_long(which: String, spare: int) -> void:
	if not has_weapon(which):
		if which == "rifle":
			rifle_owned = true
		elif which == "sniper":
			sniper_owned = true
		else:
			shotgun_owned = true
		var size := int(profile_of(which).mag)
		var full := {"mag": size - 1, "chambered": true, "reserve": spare}
		if weapon == which:
			mag = full.mag
			chambered = true
			reserve = full.reserve
		else:
			_stock[which] = full
	ammo_changed.emit()
	_update_hud()

## 0.46 (co-op): G held puts the weapon in the hands down. Returns what it held ({} when there was nothing), and
## brings up whatever else is carried.
func drop_current() -> Dictionary:
	if not has_weapon(weapon):
		return {}
	var out := {"which": str(models[weapon]), "class": weapon, "mag": mag, "chambered": chambered, "reserve": reserve}
	var was_drawn := drawn
	holster(true)
	_pending = ""
	match weapon:
		"pistol":
			owned = false
		"rifle":
			rifle_owned = false
		"shotgun":
			shotgun_owned = false
		"sniper":
			sniper_owned = false
	mag = 0
	chambered = false
	reserve = 0
	_stock[weapon] = {"mag": 0, "chambered": false, "reserve": 0}
	for other in ["rifle", "shotgun", "sniper", "pistol"]:
		if has_weapon(other):
			_switch(other)
			if was_drawn:
				draw()
			break
	ammo_changed.emit()
	_update_hud()
	return out

## 0.46 (co-op): a weapon off the ground. One already carried just takes its rounds.
func take_weapon(id: String, in_mag: int, in_chamber: bool, spare: int) -> Dictionary:
	var cls := InteriorArsenal.class_of(id)
	if not PROFILES.has(cls):
		return {}
	id = InteriorArsenal.resolve(id)
	var which := cls
	var rounds := in_mag + (1 if in_chamber else 0) + spare
	var swapped := {}
	if has_weapon(cls):
		if str(models[cls]) == id:
			add_rounds(rounds, cls)
			return {}
		# 0.48: one of each kind: the one carried goes down for this one.
		var old: Dictionary = {"mag": mag, "chambered": chambered, "reserve": reserve} if weapon == cls else _stock[cls]
		swapped = {"which": str(models[cls]), "class": cls, "mag": int(old.mag), "chambered": bool(old.chambered), "reserve": int(old.reserve)}
	models[cls] = id
	_show_weapon()
	match which:
		"pistol":
			owned = true
		"rifle":
			rifle_owned = true
		"shotgun":
			shotgun_owned = true
		"sniper":
			sniper_owned = true
	var kept := {"mag": clampi(in_mag, 0, int(profile_of(cls).mag)), "chambered": in_chamber, "reserve": spare}
	if weapon == which:
		mag = kept.mag
		chambered = kept.chambered
		reserve = kept.reserve
	else:
		_stock[which] = kept
	ammo_changed.emit()
	_update_hud()
	if not swapped.is_empty() and weapon == cls and drawn:
		draw_flash()
	select(which)
	if story != null and story.has_method("notify"):
		story.notify(InteriorArsenal.display_name(id))
	return swapped

## The weapon in the hands changed under them (a swap): the view model shows it at once.
func draw_flash() -> void:
	_show_weapon()
	_busy_until = _time + float(_prof().draw)

func has_weapon(which: String) -> bool:
	return {"pistol": owned, "rifle": rifle_owned, "shotgun": shotgun_owned, "sniper": sniper_owned}.get(which, false)

## 0.48: the figures of the weapon in the hands.
func _prof() -> Dictionary:
	return profile_of(str(models.get(weapon, weapon)))

## The figures of a weapon id (or a mechanism: its stock weapon's).
func profile_of(id: String) -> Dictionary:
	var key := InteriorArsenal.resolve(id)
	if key == "":
		key = InteriorArsenal.resolve(weapon)
	if _profiles.has(key):
		return _profiles[key]
	var out: Dictionary = (PROFILES[InteriorArsenal.class_of(key)] as Dictionary).duplicate(true)
	var own: Dictionary = InteriorArsenal.stats(key)
	for k: String in own:
		out[k] = own[k]
	out["label"] = InteriorArsenal.display_name(key)
	out["id"] = key
	_profiles[key] = out
	return out

## The name of what is in the hands ("Eruption AD-15").
func weapon_name() -> String:
	return InteriorArsenal.display_name(str(models.get(weapon, weapon)))

func mag_size() -> int:
	return int(_prof().mag)

## Spare rounds: the pistol's (the hooded man's box) unless told otherwise.
func add_rounds(count: int, which := "pistol") -> void:
	if which == weapon:
		reserve += count
	else:
		(_stock[which] as Dictionary)["reserve"] = int((_stock[which] as Dictionary).reserve) + count
	ammo_changed.emit()
	_update_hud()

## Debug menu: a full magazine and a round in the chamber, at once.
func debug_fill() -> void:
	mag = mag_size()
	chambered = true
	reloading = false
	_reload_t = -1.0
	ammo_changed.emit()
	_update_hud()

func loaded() -> int:
	return mag + (1 if chambered else 0)

## Every pistol round the player has (the story counts these), whichever weapon is out.
func total() -> int:
	if weapon == "pistol":
		return loaded() + reserve
	var kept: Dictionary = _stock["pistol"]
	return int(kept.mag) + (1 if bool(kept.chambered) else 0) + int(kept.reserve)

func ready_to_fire() -> bool:
	return drawn and not reloading and _time >= _busy_until

func toggle() -> void:
	if drawn:
		holster()
	else:
		draw()

## Brings a weapon up, putting the other away first.
func select(which: String) -> void:
	if not PROFILES.has(which) or not has_weapon(which):
		return
	if drawn and which == weapon:
		return
	if drawn:
		_pending = which
		holster()
	else:
		_switch(which)
		draw()

## 0.64: a phone's Swap: the next weapon carried comes up (pistol, rifle, shotgun, sniper, round again).
func cycle_weapon() -> void:
	var order := ["pistol", "rifle", "shotgun", "sniper"]
	var at := order.find(_pending if _pending != "" else weapon)
	for step in range(1, order.size() + 1):
		var next: String = order[(at + step) % order.size()]
		if has_weapon(next) and next != weapon:
			touch_aim = false
			select(next)
			return

## 1 / G and 2: the weapon comes up, or goes away if it is the one already out.
func _key_weapon(which: String) -> void:
	if drawn and weapon == which and _pending == "":
		holster()
	else:
		select(which)

func _switch(which: String) -> void:
	if which == weapon:
		return
	_stock[weapon] = {"mag": mag, "chambered": chambered, "reserve": reserve}
	weapon = which
	var kept: Dictionary = _stock[which]
	mag = int(kept.mag)
	chambered = bool(kept.chambered)
	reserve = int(kept.reserve)
	_show_weapon()
	ammo_changed.emit()
	_update_hud()

func _show_weapon() -> void:
	var kit_key := _kit_key()
	if weapon != "pistol" and not _longs.has(kit_key) and _view_camera != null:
		_build_variant(kit_key)
		if not _longs.has(kit_key):
			kit_key = weapon
	if _glock != null:
		_glock.visible = weapon == "pistol"
		_show_pistol_model()
	for key: String in _longs:
		((_longs[key] as Dictionary).node as Node3D).visible = key == kit_key
	if _longs.has(kit_key):
		# The long gun in the hands: the rifle's variables are whichever one that is.
		var kit: Dictionary = _longs[kit_key]
		_rifle = kit.node
		_rifle_at = kit.at
		_rifle_parts = kit.parts
		_rifle_rest = kit.rest
		_rifle_hands = kit.hands
		_rifle_muzzle = kit.muzzle
	_muzzle = _rifle_muzzle if weapon != "pistol" and _rifle_muzzle != null else _pistol_muzzle
	_flash_card = _flash_cards.get(kit_key if weapon != "pistol" else "pistol", _flash_card)
	if scope_zoom < _scope_range().x or scope_zoom > _scope_range().y:
		scope_zoom = _scope_range().y

## 0.48: the key of the view model for the weapon in the hands: the mechanism for a stock weapon, else its id.
func _kit_key() -> String:
	var id := str(models.get(weapon, weapon))
	return weapon if InteriorArsenal.is_stock(id) else id

## A long gun's own model, built like the stock ones from its sockets (tools/blender/story/process_guns.py).
func _build_variant(id: String) -> void:
	var path := InteriorArsenal.model_path(id)
	if path == "" or not ResourceLoader.exists(path):
		return
	var cls := InteriorArsenal.class_of(id)
	var reach: float = {"rifle": -.05, "shotgun": 0.0, "sniper": -.1}.get(cls, 0.0)
	var flash: float = {"rifle": .4, "shotgun": .6, "sniper": .7}.get(cls, .5)
	_build_long(id, load(path) as PackedScene, [], reach, flash * (1.4 if float(profile_of(id).get("flash", 7.0)) > 12.0 else 1.0), Vector3(0, 0, -.06), cls)

## The pistol in the hands: the Glock's own meshes, or another pistol's model on the Glock's frame (its sights where
## the Glock's are), with the muzzle moved to its own.
func _show_pistol_model() -> void:
	var id := str(models.pistol)
	var stock := InteriorArsenal.is_stock(id)
	if not stock and not _pistol_kits.has(id):
		var path := InteriorArsenal.model_path(id)
		if ResourceLoader.exists(path):
			var node := (load(path) as PackedScene).instantiate() as Node3D
			node.name = "Pistol_" + id
			_glock.add_child(node)
			_finish(node)
			var socket := node.find_child("muzzle", true, false) as Node3D
			_pistol_kits[id] = {"node": node, "muzzle": socket.position if socket != null else _glock_muzzle}
		else:
			stock = true
	for mesh: MeshInstance3D in _glock_meshes:
		if is_instance_valid(mesh):
			mesh.visible = stock
	for key: String in _pistol_kits:
		((_pistol_kits[key] as Dictionary).node as Node3D).visible = not stock and key == id
	if _pistol_muzzle != null:
		_pistol_muzzle.position = _glock_muzzle if stock else ((_pistol_kits[id] as Dictionary).muzzle as Vector3)

## The scope's powers for the weapon in the hands.
func _scope_range() -> Vector2:
	var p := _prof()
	return Vector2(float(p.get("scope_min", SCOPE_MIN)), float(p.get("scope_max", SCOPE_MAX)))

func _bring_up_pending() -> void:
	if _pending == "":
		return
	var which := _pending
	_pending = ""
	_switch(which)
	draw()

func draw() -> void:
	# 0.43: down in co-op, on the belly: no gun.
	if player != null and player.downed:
		return
	if drawn or not player.playing or player.get_meta("knocking", false):
		return
	if not has_weapon(weapon):
		return
	drawn = true
	player.release_object()
	if player.is_pulling():
		player.hold_released()
	_busy_until = _time + float(_prof().draw)
	_show_target = 1.0
	player.free_aim = free_aim
	_set_crosshair(false)
	_show_weapon()
	_play_arms("fp_draw" if weapon == "pistol" else "fp_idle")
	_hand_sound("gun_pickup", -8.0, 1.1 if weapon == "pistol" else .8)
	_set_view(true)
	_update_hud()

func holster(instant := false) -> void:
	if not drawn:
		return
	drawn = false
	reloading = false
	touch_aim = false
	trigger_held = false
	_reload_t = -1.0
	_shell_t = -1.0
	_pump_t = -1.0
	_restore_parts()
	_show_target = 0.0
	aiming = false
	player.free_aim = false
	player.fov_offset = 0.0
	player.pace_scale = 1.0
	_set_crosshair(true)
	_leave_scope()
	if instant:
		_show = 0.0
		_set_view(false)
		_update_hud()
		_bring_up_pending()
		return
	if weapon == "pistol":
		_play_arms("fp_holster")
	_update_hud()

## Hold (E) on a prop or a door (player.gd use_hook). Until 0.30 the gun went away first. The owner's rule now:
## the gun stays in the hands whatever E does; only G / 1 (or the weapon's own key) puts it away.
func _before_use() -> void:
	pass

## Left click / the Fire button while the gun is out: returns true when the click was the gun's (so no throw).
func try_fire() -> bool:
	if not drawn:
		return false
	# A click that moves the hooded man's dialogue on is not a shot.
	if story != null and story.ui != null and story.ui.dialogue_active():
		return true
	if weapon == "shotgun" and reloading and loaded() > 0:
		# A pull of the trigger stops the loading: what is in the tube is enough.
		_end_shell_reload()
		return true
	if not ready_to_fire() or _time < _next_shot:
		return true
	if player.mantling or player.hands_busy:
		return true
	if not chambered:
		_dry_fire()
		return true
	var burst := int(_prof().get("burst", 0))
	if burst > 1 and _burst_left <= 0:
		_burst_left = burst - 1
	_shoot()
	return true

## 0.33 a shove (V, scripts/body.gd): the weapon goes out with the hands and comes back.
func thrust() -> void:
	_kick_at_velocity += Vector3(randf_range(-.3, .3), .7, -3.6)
	_kick_velocity += Vector3(-2.2, randf_range(-.8, .8), randf_range(-1.2, 1.2))
	_keep_up = maxf(_keep_up, .5)

## The rifle's selector is on automatic.
func fires_automatic() -> bool:
	return bool(_prof().automatic) and automatic and int(_prof().get("burst", 0)) <= 1

func reload() -> bool:
	if weapon == "shotgun":
		# Shells go into the tube one at a time, for as long as there is room and there are shells.
		if not drawn or reloading or reserve <= 0 or mag >= mag_size() or _pump_t >= 0.0:
			return false
		reloading = true
		_shell_t = 0.0
		_shell_in = false
		return true
	if not drawn or reloading or reserve <= 0 or (mag >= mag_size() and chambered) or _pump_t >= 0.0:
		return false
	reloading = true
	_reload_t = 0.0
	_reload_steps = 0
	if weapon == "pistol":
		_play_arms("fp_reload")
	return true

func _dry_fire() -> void:
	_last_shot = _time
	_next_shot = _time + .25
	if weapon == "pistol":
		_play_arms("fp_dry")
	_hand_sound("gun_dry", -4.0, 1.0 if weapon == "pistol" else .85)
	if _time - _last_dry_toast >= DRY_TOAST_EVERY or _last_dry_toast < 0.0:
		_last_dry_toast = _time
		if story != null and story.has_method("notify"):
			story.notify(DRY_TOAST)

func _shoot() -> void:
	var p: Dictionary = _prof()
	var interval := float(p.interval)
	# A held trigger keeps the weapon's own rhythm whatever the frame rate.
	_next_shot = _next_shot + interval if _time - _next_shot < interval else _time + interval
	if _time - _last_shot > .3:
		shots_in_burst = 0
		_burst_bias = randf_range(-1.0, 1.0)
	shots_in_burst += 1
	_last_shot = _time
	_trigger_until = _time + 1.6
	chambered = mag > 0
	if mag > 0:
		mag -= 1
	if infinite_ammo:
		mag = mag_size()
		chambered = true
	if weapon == "pistol":
		if _glock_anim != null and _glock_anim.has_animation("fire"):
			_glock_anim.stop()
			_glock_anim.play("fire", -1, 2.4)
	elif weapon == "rifle" or str(p.get("cycle", "hand")) == "self":
		# 0.48: a self-loader (the rifles, the Drakon, the Tempest, the Gausser's second barrel): no hand on a pump.
		_bolt_t = .07
		if weapon != "shotgun" or str(p.id) != "gausser_db":
			_eject_casing()
	else:
		# The pump, or the bolt: worked by hand before the next one.
		_pump_t = 0.0
		_pump_step = 0
		_cycle_eject = true
	if weapon == "sniper":
		_scope_blur = 1.0
		_scope_eye += Vector2(randf_range(-.05, .05), .11)
	# The round leaves before the weapon moves: this shot's kick belongs to the next one.
	_hitscan()
	_muzzle_flash()
	_muzzle_smoke()
	_recoil()
	_shot_sound()
	fired.emit()
	ammo_changed.emit()
	_update_hud()

func _process(delta: float) -> void:
	_time += delta
	if _reload_t >= 0.0:
		_reload_tick(delta)
	if _shell_t >= 0.0:
		_shell_tick(delta)
	if _pump_t >= 0.0:
		_pump_tick(delta)
	var p: Dictionary = _prof()
	var live := drawn and player.playing and not player.cutscene
	var wants_aim := live and not reloading and (touch_aim or (not mobile and InputMap.has_action("aim") and Input.is_action_pressed("aim")))
	if wants_aim != aiming:
		aiming = wants_aim
	# A held trigger: the rifle keeps firing (the first round of a pull comes from the click itself).
	var held := trigger_held or (not mobile and InputMap.has_action("fire") and Input.is_action_pressed("fire"))
	if live and held and fires_automatic() and chambered and not reloading:
		try_fire()
	# 0.48: the rest of a burst, at the weapon's own rate; a short pause after it.
	if _burst_left > 0:
		if not live or reloading or not chambered:
			_burst_left = 0
		elif _time >= _next_shot:
			_burst_left -= 1
			_shoot()
			if _burst_left == 0:
				_next_shot = _time + .2
	_bloom = maxf(0.0, _bloom - float((p.spread as Array)[3]) * delta)
	if drawn:
		var follow: Vector2 = p.follow
		player.free_aim = free_aim and not player.cutscene
		player.aim_limit = (p.hip_zone as Vector2).lerp(p.ads_zone as Vector2, _ads)
		player.aim_follow = lerpf(follow.x, follow.y, _ads)
		player.fov_offset = float(p.ads_fov) * _ads
		player.pace_scale = lerpf(1.0, float(p.ads_pace), _ads)
		_scope_tick(delta, p)
	_update_view(delta)

## The eye in the scope. The lens narrows to the scope's power (and the mouse slows by as much), the picture swims
## with the breath and the stride, and focus comes and goes.
func _scope_tick(delta: float, p: Dictionary) -> void:
	var has_scope := bool(p.get("scope", false))
	var want := smoothstep(.55, .96, _ads) if has_scope and aiming else 0.0
	if not has_scope and scoped <= 0.0:
		return
	scoped = move_toward(scoped, want, delta * 7.0)
	if scoped <= 0.0:
		_leave_scope()
		return
	if _scope_rect == null:
		_build_scope()
	player.free_aim = false
	var base := float(player.get("_base_fov"))
	var half := tan(deg_to_rad(base) * .5)
	var through := rad_to_deg(2.0 * atan(half / scope_zoom))
	player.fov_offset = lerpf(float(p.ads_fov) * _ads, through - base, scoped)
	player.fov_rate = lerpf(5.0, 16.0, scoped)
	player.look_scale = lerpf(1.0, tan(deg_to_rad(player.camera.fov) * .5) / half, scoped)
	player.tremor_scale = lerpf(1.0, .3, scoped)
	# The breath: a slow figure of eight, wider standing than crouched, much wider on the move. Shift holds it.
	_scope_time += delta
	var holding := InputMap.has_action("run") and Input.is_action_pressed("run") and _breath_out <= 0.0
	if holding:
		_breath_held += delta
		if _breath_held > 5.0:
			_breath_out = 3.5
	else:
		_breath_held = maxf(0.0, _breath_held - delta * 1.5)
	_breath_out = maxf(0.0, _breath_out - delta)
	var pace := clampf(Vector2(player.velocity.x, player.velocity.z).length() / InteriorPlayer.WALK_SPEED, 0.0, 1.6)
	var steady := .22 if holding else (1.9 if _breath_out > 0.0 else 1.0)
	var size := .0032 * steady * (.55 if bool(player.get("crouching")) else 1.0) * (1.0 + 3.0 * pace)
	var t := _scope_time
	var swim := Vector2(sin(t * .83) + .35 * sin(t * 2.9 + 1.0), .8 * sin(t * 1.66 + .6) + .3 * sin(t * 3.7)) * size
	player.lens_sway = swim * scoped
	# Focus: gone with a shot, the power ring or a fast swing, back in a third of a second.
	var swing := clampf((_aim_rate.length() - .05) * 2.2, 0.0, .7) + .25 * pace
	_scope_blur = maxf(move_toward(_scope_blur, 0.0, delta * 2.6), swing)
	if _pump_t >= 0.0:
		_scope_blur = maxf(_scope_blur, .45)
		_scope_eye += Vector2(.5, -.3) * delta * sin(_pump_t / BOLT_TIME * PI)
	# The eye is never quite on the axis: it trails the rifle's swing and the recoil, and the shadow comes in.
	var off := Vector2(-_aim_rate.x, _aim_rate.y) * .012 + Vector2(_kick.y, -_kick.x) * .9 + swim * 6.0
	_scope_eye = _scope_eye.lerp(off.limit_length(.3), 1.0 - exp(-9.0 * delta))
	var size_px := main.get_viewport().get_visible_rect().size
	_scope_shade.set_shader_parameter("aspect", size_px.x / maxf(size_px.y, 1.0))
	var dark := 1.0
	var bodycam: Variant = main.get("bodycam")
	if bodycam != null and is_instance_valid(bodycam) and bodycam.get("_night") != null:
		dark = clampf(float(bodycam.get("_night")), 0.0, 1.0)
	_scope_shade.set_shader_parameter("night", dark)
	_scope_shade.set_shader_parameter("gain", lerpf(1.0, 1.9, dark))
	_scope_shade.set_shader_parameter("amount", scoped)
	_scope_shade.set_shader_parameter("style", int(p.get("reticle", 0)))
	_scope_shade.set_shader_parameter("radius", float(p.get("scope_radius", .445)))
	_scope_shade.set_shader_parameter("blur", clampf(_scope_blur + (1.0 - scoped) * .8, 0.0, 1.0))
	_scope_shade.set_shader_parameter("eye", _scope_eye + Vector2(0.0, (1.0 - scoped) * .22))
	_scope_rect.visible = true
	_container.modulate.a = 1.0 - smoothstep(.15, .7, scoped)
	if not _scope_hint and scoped > .9:
		_scope_hint = true
		if story != null and story.has_method("notify"):
			story.notify("Scope %dx. Mouse wheel changes the power, Shift holds your breath." % int(scope_zoom))

func _leave_scope() -> void:
	scoped = 0.0
	_scope_blur = 0.0
	if _scope_rect != null:
		_scope_rect.visible = false
	if _container != null:
		_container.modulate.a = 1.0
	if player != null:
		player.look_scale = 1.0
		player.fov_rate = 5.0
		player.tremor_scale = 1.0
		player.lens_sway = Vector2.ZERO

func _build_scope() -> void:
	_scope_rect = ColorRect.new()
	_scope_rect.name = "Scope"
	_scope_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scope_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope_shade = ShaderMaterial.new()
	_scope_shade.shader = SCOPE_SHADER
	_scope_rect.material = _scope_shade
	_scope_rect.visible = false
	main.hud.add_child(_scope_rect)
	# Over the world and the hands, under the rest of the HUD.
	main.hud.move_child(_scope_rect, _container.get_index() + 1)

## The power ring: one power a click of the wheel.
func turn_scope(clicks: int) -> void:
	var before := scope_zoom
	var span := _scope_range()
	scope_zoom = clampf(round(scope_zoom) + clicks, span.x, span.y)
	if scope_zoom != before:
		_scope_blur = maxf(_scope_blur, .7)
		_hand_sound("gun_dry", -14.0, 1.9)
		_update_hud()

func _input(event: InputEvent) -> void:
	if not drawn or mobile or scoped < .3 or not (event is InputEventMouseButton) or not event.pressed:
		return
	var button := (event as InputEventMouseButton).button_index
	if button == MOUSE_BUTTON_WHEEL_UP or button == MOUSE_BUTTON_WHEEL_DOWN:
		turn_scope(1 if button == MOUSE_BUTTON_WHEEL_UP else -1)
		get_viewport().set_input_as_handled()

## What a shot does. The hands: the muzzle flips up about the wrists (or the butt), the weapon is shoved back, it
## rolls and yaws either way, and comes back on a spring. The muzzle is left a little off where it was, mostly
## higher, so a string climbs and wanders. The lens: a spring of its own (the pistol hardly moves it, the shouldered
## rifle shakes the whole picture) and the frame clips white. All of it grows through a long string.
func _recoil() -> void:
	var p: Dictionary = _prof()
	var soft := lerpf(1.0, .72, _ads)
	var heat := 1.0 + minf(float(shots_in_burst - 1) * .06, .5)
	# A muzzle that is already high has less left to give.
	var room := 1.0 - .6 * clampf(_kick.x / .9, 0.0, 1.0)
	_kick_velocity += Vector3(float(p.flip) * randf_range(.85, 1.15) * room, float(p.yaw) * randf_range(-1.0, 1.0),
		float(p.roll) * randf_range(-1.0, 1.0)) * soft * heat
	var shove: Vector3 = p.shove
	_kick_at_velocity += Vector3(shove.x * randf_range(-1.0, 1.0), shove.y * randf_range(.6, 1.1), shove.z * randf_range(.85, 1.15)) * soft
	_keep_up = .45
	# 0.32: the arms' clip throws the pistol up, and the crop reads the clip a frame late: the near end goes down
	# with the shot, so the fist under it never shows in the flash.
	if weapon == "pistol":
		_floor = minf(_floor + .06, .22)
	var climb: Vector2 = p.climb
	if player.free_aim:
		player.aim_offset += Vector2((randf_range(-1.0, 1.0) + _burst_bias * .45) * climb.x, climb.y * randf_range(.7, 1.3)) * soft * heat
	# Most knocks are alike; now and then one is half as hard again, or twice (the reference's worst frames).
	var punch: Vector3 = p.punch
	var wild := 1.0 + pow(randf(), 3.0)
	player.punch(Vector3(punch.x * randf_range(.8, 1.25) * wild, punch.y * (randf_range(-1.0, 1.0) + float(p.punch_bias)),
		punch.z * randf_range(-1.0, 1.0) * (1.0 + pow(randf(), 3.0))) * soft * heat)
	player.kick(float(p.kick) if player.free_aim else 1.6)
	player.jolt(float(p.jolt))
	var spread: Array = p.spread
	_bloom = minf(_bloom + float(spread[1]), float(spread[2]))
	var bodycam: Variant = main.get("bodycam")
	if bodycam != null and is_instance_valid(bodycam):
		bodycam.call("shot", float(p.lens))

## Where a round goes: where the muzzle points now (the lens, the free aim, and what is left of the last kick and
## of the weapon's swing), somewhere inside the cone.
func _shot_basis() -> Basis:
	var p: Dictionary = _prof()
	var basis := player.aim_basis()
	var line := drawn_aim()
	if line.is_finite():
		# 0.40: where the weapon on the screen points: its sight line, from the view lens into the world lens.
		basis = Basis.looking_at(line, Vector3.UP if absf(line.y) < .98 else Vector3.BACK)
	else:
		var inherited := float(p.kick_aim) * minf(spread_scale, 1.0)
		basis = basis * Basis(Vector3.UP, (_kick.y + _sway.y) * inherited) * Basis(Vector3.RIGHT, (_kick.x + _sway.x) * inherited)
	var pace := clampf(Vector2(player.velocity.x, player.velocity.z).length() / InteriorPlayer.RUN_SPEED, 0.0, 1.0)
	var cone := (float((p.spread as Array)[0]) + _bloom) * lerpf(1.0, .5, _ads) * (1.0 + .6 * pace) * spread_scale
	# A scoped rifle off the shoulder points only roughly where it looks.
	cone *= lerpf(float(p.get("hip_spread", 1.0)), 1.0, _ads)
	if cone > 0.0:
		var around := randf() * TAU
		var out := cone * sqrt(randf())
		basis = basis * Basis(Vector3.UP, cos(around) * out) * Basis(Vector3.RIGHT, sin(around) * out)
	return basis

## 0.40: the sight line of the weapon as it is drawn, in the world: the point it vanishes to on the screen, seen
## through the world's lens. INF while the weapon is not up (holstered, coming up, hands busy) or not drawn at all.
func drawn_aim() -> Vector3:
	if legacy_aim or not _view_line_valid or _container == null or not _container.visible or _view_line.z > -.2 or _view_ratio <= .0:
		return Vector3.INF
	var k := 1.0 / _view_ratio
	var local := Vector3(_view_line.x / -_view_line.z * k, _view_line.y / -_view_line.z * k, -1.0).normalized()
	return (player.camera.global_basis * local).normalized()

## The sight line in the sight frame: the pistol's as measured in the hand, the long guns' from their markers.
func _line_in_frame() -> Vector3:
	if weapon == "pistol":
		return _sight_line if _sight_measured else Vector3.FORWARD
	if _rifle_at.has("front_sight") and _rifle_at.has("rear_sight"):
		var d: Vector3 = (_rifle_at["front_sight"] as Vector3) - (_rifle_at["rear_sight"] as Vector3)
		if d.length() > .05 and d.normalized().dot(Vector3.FORWARD) > .8:
			return d.normalized()
	return Vector3.FORWARD

## The cone a round would leave in right now (radians, half angle).
func spread_now() -> float:
	var p: Dictionary = _prof()
	return (float((p.spread as Array)[0]) + _bloom) * lerpf(1.0, .5, _ads) * spread_scale

func _set_crosshair(on: bool) -> void:
	if main == null or main.get("hud") == null:
		return
	var dot := main.hud.get_node_or_null("Crosshair") as CanvasItem
	if dot != null:
		dot.visible = on

func _unhandled_input(event: InputEvent) -> void:
	if player == null or not player.playing or mobile:
		return
	if event.is_action_pressed("gun"):
		_key_weapon("pistol")
		get_viewport().set_input_as_handled()
	elif rifle_owned and InputMap.has_action("rifle") and event.is_action_pressed("rifle"):
		_key_weapon("rifle")
		get_viewport().set_input_as_handled()
	elif shotgun_owned and InputMap.has_action("shotgun") and event.is_action_pressed("shotgun"):
		_key_weapon("shotgun")
		get_viewport().set_input_as_handled()
	elif sniper_owned and InputMap.has_action("sniper") and event.is_action_pressed("sniper"):
		_key_weapon("sniper")
		get_viewport().set_input_as_handled()
	elif drawn and weapon == "rifle" and bool(_prof().automatic) and InputMap.has_action("fire_mode") and event.is_action_pressed("fire_mode"):
		automatic = not automatic
		_hand_sound("gun_dry", -9.0, 1.5)
		_update_hud()
		if story != null and story.has_method("notify"):
			story.notify("Automatic" if automatic else "Single shots")
	elif drawn and event.is_action_pressed("reload"):
		reload()
	elif drawn and weapon == "pistol" and event.is_action_pressed("inspect") and story != null and story.has_method("inspect_carried_gun"):
		story.inspect_carried_gun()
		get_viewport().set_input_as_handled()

func _reload_tick(delta: float) -> void:
	_reload_t += delta
	var t := _reload_t
	var rifle := weapon != "pistol"
	var times: Array = RIFLE_RELOAD if rifle else [RELOAD_MAG_OUT, RELOAD_MAG_IN, RELOAD_RACK, RELOAD_RELEASE, RELOAD_TIME]
	if _reload_steps == 0 and t >= float(times[0]):
		_reload_steps = 1
		_hand_sound("gun_mag_out", -3.0, 1.0 if not rifle else .85)
	if _reload_steps == 1 and t >= float(times[1]):
		_reload_steps = 2
		# What was left in the old magazine goes back in the pocket; a full one goes in.
		reserve += mag
		mag = mini(mag_size(), reserve)
		reserve -= mag
		_hand_sound("gun_mag_in", -2.0, 1.0 if not rifle else .85)
		ammo_changed.emit()
		_update_hud()
	if _reload_steps == 2 and t >= float(times[2]):
		_reload_steps = 3
		_hand_sound("gun_rack", -3.0, 1.0 if not rifle else .8)
	if _reload_steps == 3 and t >= float(times[3]):
		_reload_steps = 4
		if not chambered and mag > 0:
			chambered = true
			mag -= 1
			if weapon == "sniper":
				# The bolt is worked to chamber the first one.
				_pump_t = 0.0
				_pump_step = 0
				_cycle_eject = false
				_next_shot = _time + BOLT_TIME
		ammo_changed.emit()
		_update_hud()
	if not rifle:
		_pose_parts(t)
	if t >= float(times[4]):
		_reload_t = -1.0
		reloading = false
		_restore_parts()
		_play_arms("fp_idle")
		reloaded.emit()

# ---------------------------------------------------------------- the shot

func _hitscan() -> void:
	var p: Dictionary = _prof()
	var eye := player.camera.global_position
	var space := player.get_world_3d().direct_space_state
	# 0.26: the round goes where the muzzle points, which is not always the middle of the picture.
	var aim := _shot_basis()
	var look := -aim.z
	# 0.37: the round leaves from the weapon, not from the lens. The lens is on the forehead and the weapon is
	# lower and ahead of it (`BARREL`), so the two lines are not the same: the bore is laid from the breech to the
	# first thing the lens' line meets (where both agree), and a round only goes where the barrel itself has room.
	# A wall the lens peers over, or a post the muzzle is pressed against, takes the round.
	var reach := float(p.get("range", RANGE))
	var sight := InteriorSurfaces.seen_ray(space, eye, eye + look * reach, MASK, [player.get_rid()])
	var aim_at: Vector3 = sight.position if sight else eye + look * reach
	var breech := breech_world(eye)
	var bore := aim_at - breech
	var dir := look if bore.length() < .25 else bore.normalized()
	last_shot_origin = breech
	last_shot_direction = dir
	last_hit = {}
	last_hits.clear()
	var bore_basis := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < .98 else Vector3.BACK)
	var pellets := int(p.pellets)
	var seen_far := eye.distance_to(aim_at)
	for index in pellets:
		var each := dir
		var speed := 1.0
		if pellets > 1:
			# Buckshot: every ball has its own place in the pattern (most of them near the middle) and its own speed.
			var around := randf() * TAU
			var out := minf(float(p.pattern) * sqrt(-2.0 * log(maxf(randf(), .000001))), float(p.pattern) * 3.4)
			each = -(bore_basis * Basis(Vector3.UP, cos(around) * out) * Basis(Vector3.RIGHT, sin(around) * out)).z
			speed = 1.0 + randf_range(-1.0, 1.0) * float(p.get("velocity_spread", 0.0))
		if index == 0:
			if weapon == "rifle" and shots_in_burst % 3 == 1:
				_tracer(each, minf(seen_far, reach))
			elif pellets > 1:
				_shot_streak(each, minf(seen_far, reach))
		_fire_round(breech, each, p, index, speed)

## 0.37: where the weapon really is, in the lens' frame (x right, y up, -z ahead): the breech (the back of the
## barrel, at the firing hand or the shoulder) at the hip, on the sights and tucked against a wall, and how long
## the barrel is in front of it. The view model is drawn larger and nearer than this (that is the framing); the
## round goes by this.
const BARREL := {
	"pistol": {"hip": Vector3(.12, -.27, -.3), "ads": Vector3(.0, -.12, -.36), "tuck": Vector3(.12, -.32, -.12), "length": .19},
	"rifle": {"hip": Vector3(.15, -.25, -.06), "ads": Vector3(.0, -.14, -.1), "tuck": Vector3(.15, -.32, .0), "length": .58},
	"shotgun": {"hip": Vector3(.15, -.25, -.06), "ads": Vector3(.0, -.13, -.1), "tuck": Vector3(.15, -.32, .0), "length": .66},
	"sniper": {"hip": Vector3(.15, -.26, -.04), "ads": Vector3(.0, -.16, -.08), "tuck": Vector3(.15, -.33, .02), "length": .74},
}

## The breech in the world, in the stance the hands are in now. Never on the far side of something from the lens:
## pressed against a wall, it is this side of it.
func breech_world(eye := Vector3.INF) -> Vector3:
	if not eye.is_finite():
		eye = player.camera.global_position
	var b: Dictionary = BARREL.get(weapon, BARREL.pistol)
	var at: Vector3 = (b.hip as Vector3).lerp(b.ads as Vector3, _ads).lerp(b.tuck as Vector3, _tuck * (1.0 - _ads))
	var breech := eye + player.aim_basis() * at
	var query := PhysicsRayQueryParameters3D.create(eye, breech, 2)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		breech = (hit.position as Vector3) + (eye - breech).normalized() * .03
	return breech

## The muzzle in the world: the barrel's length on from the breech, along the bore.
func muzzle_physical() -> Vector3:
	var b: Dictionary = BARREL.get(weapon, BARREL.pistol)
	return breech_world() - player.aim_basis().z * float(b.length)

## Where a projectile is after `s` metres of its path: along the bore, less what gravity has taken in the time it
## needed to get there (it slows as it goes).
static func path_point(from: Vector3, dir: Vector3, s: float, v0: float, drag: float) -> Vector3:
	var t := drag / v0 * (exp(s / drag) - 1.0)
	return from + dir * s + Vector3.DOWN * (4.9 * t * t)

## How far along its path a projectile is after `t` seconds (the inverse of the time in `path_point`).
static func path_reach(t: float, v0: float, drag: float) -> float:
	return drag * log(1.0 + t * v0 / drag)

## 0.37: a projectile in flight. It is moved on every physics tick by as far as it goes in that time, and each
## step is tested against the world as it is at that moment: a figure that has walked out of its way is missed,
## one that steps into it is struck. (Before 0.37 the whole path was tested the instant the trigger broke and
## what it met was struck after the time of flight, wherever it had gone since.)
class Round:
	var from: Vector3
	var dir: Vector3
	var v0: float
	var drag: float
	var p: Dictionary
	var index: int
	var energy := 1.0
	var s := 0.0             # metres along the path so far
	var t := 0.0             # seconds in flight
	var reach := 80.0
	var passes := 1
	var covers_left := 2
	var limbs_only := false
	var first := true
	var skip := false        # a ball skipped off stone or steel: it lands, nothing more
	var exclude: Array[RID] = []

## Segments of a path are tested this long at most (the path curves under gravity).
const SEGMENT := 24.0
var _rounds: Array[Round] = []
## Where the last trigger pull's rounds left from (the breech) and along what.
var last_shot_origin := Vector3.ZERO

## One projectile down its path. It stops at the first thing it meets, except a rifle round in a body: that goes
## through, with under half its energy, into whoever or whatever is behind.
func _fire_round(from: Vector3, dir: Vector3, p: Dictionary, index: int, speed_scale := 1.0) -> void:
	var r := Round.new()
	r.from = from
	r.dir = dir
	r.v0 = float(p.velocity) * speed_scale
	r.drag = float(p.drag)
	r.p = p
	r.index = index
	r.reach = float(p.get("range", RANGE))
	r.limbs_only = bool(p.get("limb_pierce", false)) and not bool(p.pierce)
	r.passes = int(p.get("passes", 2)) if bool(p.pierce) or r.limbs_only else 1
	r.exclude = [player.get_rid()]
	_launch(r)

func _launch(r: Round) -> void:
	if instant_hits:
		_fly(r, r.reach)
		return
	# The tick it leaves in: as far as it goes in one physics step (a shot at arm's length lands at once).
	r.t = 1.0 / float(Engine.physics_ticks_per_second)
	if not _fly(r, minf(path_reach(r.t, r.v0, r.drag), r.reach)):
		_rounds.append(r)

func _physics_process(delta: float) -> void:
	if _rounds.is_empty():
		return
	# (A ball that skips off something is launched while this runs: it joins the new list.)
	var flying := _rounds
	_rounds = []
	for r in flying:
		r.t += delta
		var to := minf(path_reach(r.t, r.v0, r.drag), r.reach)
		if not _fly(r, to) and r.s < r.reach - .01:
			_rounds.append(r)

## Rounds still in the air.
func rounds_in_flight() -> int:
	return _rounds.size()

## Moves `r` on to `until` metres along its path. True when it has stopped.
func _fly(r: Round, until: float) -> bool:
	var space := player.get_world_3d().direct_space_state
	var lamps: InteriorSenses = main.get("senses") if main != null else null
	while r.s < until - .0001:
		var to_s := minf(until, r.s + SEGMENT)
		var a := path_point(r.from, r.dir, r.s, r.v0, r.drag)
		var b := path_point(r.from, r.dir, to_s, r.v0, r.drag)
		# (0.33: not stopped by the world's unseen walls: the fields' road edges, the play area's bounds.)
		var hit := InteriorSurfaces.seen_ray(space, a, b, MASK, r.exclude)
		var end: Vector3 = hit.position if hit else b
		# 0.33: a lamp in the round's way goes out (scripts/senses.gd).
		if lamps != null:
			lamps.shot_segment(a, end)
		# The paddies, the pond and the canal have no colliders: a round going into the water splashes.
		if not r.skip and a.y > WATER_Y and end.y <= WATER_Y and r.from.y < -.4:
			var at := a.lerp(end, (a.y - WATER_Y) / maxf(a.y - end.y, .0001))
			if InteriorFieldsBuilder.in_water(Vector2(at.x, at.z)):
				_impact_fx(at, Vector3.UP, "water", null, r.index > 1)
				return true
		if not hit:
			r.s = to_s
			continue
		if _strike(r, hit, r.s + a.distance_to(hit.position), space):
			return true
	return false

## What `r` does to what it met `hit_s` metres along its path. True when the round has stopped.
func _strike(r: Round, hit: Dictionary, hit_s: float, space: PhysicsDirectSpaceState3D) -> bool:
	var p := r.p
	var dir := r.dir
	r.passes -= 1
	var collider := hit.collider as Node
	var body_hit := collider != null and collider.has_meta("zombie")
	var speed := r.v0 * exp(-hit_s / r.drag)
	var power := r.energy * speed * speed / (r.v0 * r.v0)
	var point: Vector3 = hit.position
	var normal: Vector3 = hit.normal
	var shape := int(hit.get("shape", 0))
	var pet := collider != null and not body_hit and is_pet_home(collider)
	if r.skip:
		_land(collider, shape, point, normal, dir, p, power, r.index, pet)
		return true
	var windows: InteriorWindowGlass = main.get("glass") if main != null else null
	# 0.34: a window pane (scripts/window_glass.gd). It breaks. A pane of the town's houses has the house
	# behind it and keeps the round; through one of the Nichols house's the round goes on, into the room or
	# out of it, and through a pane already out it goes as through air.
	var pane := windows.pane_at(collider, shape, point, dir) if windows != null and not body_hit and not pet else -1
	if pane >= 0:
		var fresh := windows.strike(pane, point, dir, 0.0)
		if fresh:
			var broke := {"position": point, "normal": normal, "collider": collider, "distance": hit_s, "power": power, "surface": "glass", "pane": pane}
			last_hits.append(broke)
			if r.index == 0 and r.first:
				last_hit = broke
		if windows.is_solid(pane):
			return true
		var beyond := windows.way_out(pane, point, dir)
		if beyond < 0.0:
			return true
		if fresh:
			r.energy *= .88
		r.s = hit_s + beyond + .03
		r.passes = maxi(r.passes, 1)
		r.first = false
		return false
	if not pet:
		var record := {"position": point, "normal": normal, "collider": collider, "distance": hit_s, "power": power,
			"surface": "flesh" if body_hit else surface_of(collider, shape, point, normal)}
		last_hits.append(record)
		if r.index == 0 and r.first:
			last_hit = record
	_land(collider, shape, point, normal, dir, p, power, r.index, pet)
	if not body_hit:
		if r.first and bool(p.get("skip", false)) and not pet:
			_skip_off(point, normal, dir, p, power, r.index, str((last_hits[-1] as Dictionary).surface) if not last_hits.is_empty() else "stone")
		# 0.33: thin cover does not stop it. A board, a sheet of roofing iron, a pane, a hung cloth: out the far
		# side with what is left, and on into whatever is behind. Stone, concrete and earth keep every round.
		var cover := str((last_hits[-1] as Dictionary).surface) if not pet and not last_hits.is_empty() else ""
		var through := _thickness(space, point, dir, cover, p) if r.covers_left > 0 else -1.0
		if through < 0.0:
			return true
		r.covers_left -= 1
		r.energy *= clampf(1.0 - through / _bore(cover, p), .2, 1.0) * .75
		_exit_hole(collider, point + dir * through, dir, cover)
		r.s = hit_s + through + .03
		r.passes = maxi(r.passes, 1)
		r.first = false
		return false
	if r.limbs_only:
		# A lead ball goes through an arm or a shin; a trunk or a skull keeps it.
		var struck := str(collider.get_meta("bone", "chest"))
		if struck == "head" or struck in InteriorZombie.TRUNK or struck.begins_with("thigh"):
			return true
	if r.passes <= 0:
		return true
	# Through the body: on down the same path, with what is left.
	var owner_node: Object = collider.get_meta("zombie")
	if is_instance_valid(owner_node) and owner_node.has_method("hit_rids"):
		r.exclude.append_array(owner_node.call("hit_rids"))
	r.energy *= float(p.get("keep", .45))
	r.s = hit_s + .05
	r.first = false
	return false

## Metres of each kind of cover a pistol round gets through (a weapon's "bore" multiplies it: the rifle 2.2, a ball
## of buckshot .5, the .338 3.5). The world's sheet iron is built fatter than iron is, so the figure for metal is too.
const COVER := {"wood": .1, "metal": .11, "glass": .05, "fabric": .35}

func _bore(surface: String, p: Dictionary) -> float:
	return float(COVER.get(surface, 0.0)) * float(p.get("bore", 1.0))

## How thick the cover struck at `point` is along the round's way, or -1 when it is more than the round gets
## through. Measured from the far side: a ray back from as deep as the round could go meets the face it would leave by.
func _thickness(space: PhysicsDirectSpaceState3D, point: Vector3, dir: Vector3, surface: String, p: Dictionary) -> float:
	var limit := _bore(surface, p)
	if limit <= 0.0:
		return -1.0
	var query := PhysicsRayQueryParameters3D.create(point + dir * (limit + .02), point + dir * .002, 2 | 4)
	query.hit_back_faces = false
	query.hit_from_inside = true
	query.exclude = [player.get_rid()]
	var back := space.intersect_ray(query)
	if back.is_empty():
		return -1.0
	var through := ((back.position as Vector3) - point).dot(dir)
	return through if through > .0005 and through <= limit else -1.0

## Where it comes out: a hole torn outward and what it carried with it.
func _exit_hole(collider: Node, point: Vector3, dir: Vector3, surface: String) -> void:
	if collider != null and not is_instance_valid(collider):
		return
	pierced += 1
	_decal(point, dir, surface, collider as Node3D if collider is RigidBody3D else null)
	_impact_fx(point, dir, surface, collider, true)

## A ball of shot that meets stone or steel at a shallow angle skips off it and carries on, flattened and slower.
## (0.37: a projectile of its own, in flight like the rest. It is not counted among `last_hits`: those are where
## each ball first struck.)
func _skip_off(point: Vector3, normal: Vector3, dir: Vector3, p: Dictionary, power: float, index: int, surface: String) -> void:
	if surface != "stone" and surface != "metal":
		return
	if -dir.dot(normal) > .36 or randf() > .75:
		return
	var away := dir.bounce(normal)
	away = (away + normal * randf_range(.02, .12) + Vector3(randf_range(-.06, .06), randf_range(-.04, .06), randf_range(-.06, .06))).normalized()
	var r := Round.new()
	r.from = point + normal * .02
	r.dir = away
	r.v0 = maxf(float(p.velocity) * .55, 1.0)
	r.drag = float(p.drag)
	r.p = p
	r.index = maxi(index, 2)
	r.reach = 16.0
	r.skip = true
	r.energy = power * .3
	r.exclude = [player.get_rid()]
	_launch(r)

## A projectile arrives.
func _land(collider: Node, shape: int, point: Vector3, normal: Vector3, dir: Vector3, p: Dictionary, power: float, index: int, pet: bool) -> void:
	if collider != null and not is_instance_valid(collider):
		return
	if collider != null and collider.has_meta("zombie"):
		var body_owner: Object = collider.get_meta("zombie")
		if is_instance_valid(body_owner):
			var tear := float(p.damage) * power * float(p.get("sever", .5))
			if str(collider.get_meta("bone", "")) == "head":
				tear *= float(p.get("head_pop", 1.0))
			body_owner.call("shot", collider, point, dir, float(p.damage) * power, float(p.knock) * sqrt(power), weapon, tear)
		return
	if pet:
		# The glass stops it; the animals behind it are never touched.
		_decal(point, normal, "glass", collider as Node3D)
		_impact_fx(point, normal, "glass", null, index > 1)
		return
	var surface := surface_of(collider, shape, point, normal)
	if collider is InteriorObject:
		var body := collider as InteriorObject
		if not (body.anchored and body.freeze):
			body.activate()
			body.sleeping = false
			body.apply_impulse(dir * float(p.impulse) * sqrt(power), point - body.global_position)
		if body.has_meta("interactor"):
			var interactor: Object = body.get_meta("interactor")
			if is_instance_valid(interactor) and interactor.has_method("shoot"):
				interactor.call("shoot")
	_decal(point, normal, surface, collider as Node3D if collider is RigidBody3D else null)
	_impact_fx(point, normal, surface, collider, index > 1)

## The hamster enclosure and the aquariums (their glass is the body itself).
static func is_pet_home(collider: Node) -> bool:
	for child in collider.get_children():
		if child is HamsterEnclosure or child is InteriorAquarium:
			return true
	return false

## wood, stone, metal, dirt, fabric or glass.
static func surface_of(collider: Object, shape_index: int, point: Vector3, normal: Vector3) -> String:
	var key := ""
	if collider != null and collider.has_meta("surface"):
		key = str(collider.get_meta("surface"))
	elif collider is InteriorObject:
		key = str((collider as InteriorObject).physics_material)
	if key == "" and collider is CollisionObject3D:
		var body := collider as CollisionObject3D
		var owner_id := body.shape_find_owner(shape_index)
		if owner_id >= 0:
			var node := body.shape_owner_get_owner(owner_id) as Node
			if node != null and node.has_meta("surface"):
				key = str(node.get_meta("surface"))
	if key == "":
		if point.y > -.6:
			key = "wood" if normal.y > .7 else "plaster"     # the house: wooden floor, plastered walls
		elif absf(normal.y) < .6:
			key = "concrete"                                  # walls and fences in town, the hut's planks below
			if collider is Node and (collider as Node).name.begins_with("Hut"):
				key = "wood"
		else:
			key = InteriorSurfaces.at(point)
	match key:
		"wood", "cardboard", "paper", "bamboo":
			return "wood"
		"metal", "steel", "iron", "tin":
			return "metal"
		"glass":
			return "glass"
		"fabric", "foam", "carpet", "rubber", "plastic":
			return "fabric"
		"grass", "dirt", "mud", "snow":
			return "dirt"
	return "stone"

func _decal(point: Vector3, normal: Vector3, surface: String, body: Node3D) -> void:
	if surface == "water":
		return
	var hole: Node3D
	var texture := _crack_texture if surface == "glass" else _hole_texture
	var tint: Color = {"wood": Color(.82, .72, .6), "metal": Color(.75, .75, .78), "dirt": Color(.7, .65, .6),
		"fabric": Color(.7, .7, .7), "glass": Color(1, 1, 1, .85)}.get(surface, Color(.88, .86, .82))
	# Reuse the oldest hole once there are DECAL_MAX.
	if _decals.size() >= DECAL_MAX:
		hole = _decals.pop_front()
		if is_instance_valid(hole):
			hole.queue_free()
	var up := normal.normalized()
	var side := up.cross(Vector3.UP if absf(up.y) < .95 else Vector3.RIGHT).normalized()
	var spin := Basis(up, randf() * TAU)
	if not mobile:
		var decal := Decal.new()
		# Deep enough to reach the visible surface when it stands a few cm off its collider (the room's walls).
		decal.size = Vector3(DECAL_SIZE, .5, DECAL_SIZE)
		decal.texture_albedo = texture
		decal.modulate = tint
		decal.upper_fade = .3
		decal.lower_fade = .3
		decal.cull_mask = 0xFFFFF
		hole = decal
		var parent: Node3D = body if body != null else _holes
		parent.add_child(decal)
		# A decal projects along its -Y: its Y axis is the surface normal.
		decal.global_transform = Transform3D(spin * Basis(side, up, side.cross(up)), point)
	else:
		# The Compatibility renderer (Android) has no decals: a small card just off the surface.
		var card := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(DECAL_SIZE, DECAL_SIZE)
		card.mesh = quad
		var m := ShaderMaterial.new()
		m.shader = HOLE_SHADER
		m.set_shader_parameter("hole", texture)
		m.set_shader_parameter("tint", tint)
		card.material_override = m
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		card.layers = 3
		hole = card
		var parent: Node3D = body if body != null else _holes
		parent.add_child(card)
		# The quad faces its +Z: turn +Z onto the normal.
		card.global_transform = Transform3D(spin * Basis.looking_at(-up, side), point + up * .005)
	hole.name = "BulletHole"
	hole.add_to_group("bullet_holes")
	_decals.append(hole)

func bullet_holes() -> int:
	var live := 0
	for hole in _decals:
		live += 1 if is_instance_valid(hole) else 0
	return live

func _impact_fx(point: Vector3, normal: Vector3, surface: String, collider: Object, quiet := false) -> void:
	var colour: Color = {"wood": Color(.62, .48, .32), "metal": Color(1.0, .78, .4), "dirt": Color(.36, .3, .22),
		"water": Color(.7, .78, .85, .8), "glass": Color(.85, .9, .95), "fabric": Color(.5, .5, .5)}.get(surface, Color(.6, .58, .55))
	var burst := CPUParticles3D.new() if mobile else null
	var count := 14 if surface != "water" else 22
	if mobile:
		count /= 2
	var particles: GeometryInstance3D
	var draw := QuadMesh.new()
	draw.size = Vector2(.025, .025) if surface != "metal" else Vector2(.012, .012)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if surface == "metal" else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = colour
	if surface == "metal":
		m.emission_enabled = true
		m.emission = colour
		m.emission_energy_multiplier = 3.0
	draw.material = m
	var spread := 35.0 if surface != "water" else 20.0
	var speed := Vector2(1.2, 3.2) if surface != "water" else Vector2(1.5, 3.8)
	if burst != null:
		burst.one_shot = true
		burst.amount = count
		burst.explosiveness = 1.0
		burst.lifetime = .6
		burst.mesh = draw
		burst.direction = Vector3(0, 0, -1)
		burst.spread = spread
		burst.initial_velocity_min = speed.x
		burst.initial_velocity_max = speed.y
		burst.gravity = Vector3(0, -9.8, 0)
		burst.scale_amount_min = .6
		burst.scale_amount_max = 1.4
		particles = burst
	else:
		var gpu := GPUParticles3D.new()
		gpu.one_shot = true
		gpu.amount = count
		gpu.explosiveness = 1.0
		gpu.lifetime = .6
		gpu.draw_pass_1 = draw
		var process := ParticleProcessMaterial.new()
		process.direction = Vector3(0, 0, -1)
		process.spread = spread
		process.initial_velocity_min = speed.x
		process.initial_velocity_max = speed.y
		process.gravity = Vector3(0, -9.8, 0)
		process.scale_min = .6
		process.scale_max = 1.4
		process.damping_min = 1.0
		process.damping_max = 3.0
		gpu.process_material = process
		particles = gpu
	particles.name = "Impact"
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.layers = 3
	main.add_child(particles)
	# The burst leaves along -Z: point -Z out of the surface.
	var out := normal.normalized()
	particles.global_transform = Transform3D(Basis.looking_at(out, Vector3.UP if absf(out.y) < .95 else Vector3.RIGHT), point + out * .02)
	if particles is GPUParticles3D:
		(particles as GPUParticles3D).emitting = true
	else:
		(particles as CPUParticles3D).emitting = true
	get_tree().create_timer(1.2, false).timeout.connect(particles.queue_free)
	# The later pellets of a load land without their own dust and sound.
	if quiet:
		return
	if not mobile and surface != "water" and surface != "glass":
		_impact_dust(point, out, surface)
	# Sound at the hit.
	var voice := AudioStreamPlayer3D.new()
	voice.name = "ImpactSound"
	voice.bus = BUS
	voice.unit_size = 4.0
	voice.max_distance = 90.0
	main.add_child(voice)
	voice.global_position = point
	var key: String = {"wood": "hit_wood", "metal": "hit_metal", "dirt": "hit_dirt", "water": "hit_water", "glass": "hit_glass", "fabric": "hit_dirt"}.get(surface, "hit_stone")
	voice.stream = _stream(key)
	voice.pitch_scale = randf_range(.9, 1.1)
	voice.volume_db = -4.0
	voice.play()
	if surface == "metal":
		var whine := AudioStreamPlayer3D.new()
		whine.bus = BUS
		whine.unit_size = 5.0
		whine.stream = _stream("gun_ricochet")
		whine.pitch_scale = randf_range(.85, 1.2)
		whine.volume_db = -8.0
		main.add_child(whine)
		whine.global_position = point
		whine.play()
		get_tree().create_timer(1.5, false).timeout.connect(whine.queue_free)
	get_tree().create_timer(1.5, false).timeout.connect(voice.queue_free)

## What a round knocks out of a wall: a puff of dust that hangs and drifts, and off anything hard a handful of
## sparks that fall and skip (the reference's corridor is full of both).
func _impact_dust(point: Vector3, out: Vector3, surface: String) -> void:
	var frame := Engine.get_process_frames()
	if frame != _fx_frame:
		_fx_frame = frame
		_fx_count = 0
	_fx_count += 1
	if _fx_count > 3:
		return
	var basis := Basis.looking_at(out, Vector3.UP if absf(out.y) < .95 else Vector3.RIGHT)
	var dust := CPUParticles3D.new()
	dust.name = "ImpactDust"
	dust.one_shot = true
	dust.amount = 4
	dust.explosiveness = .95
	dust.lifetime = .9
	var quad := QuadMesh.new()
	quad.size = Vector2(.3, .3)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _smoke_texture()
	var tint: Color = {"wood": Color(.6, .5, .4), "dirt": Color(.45, .38, .3), "metal": Color(.6, .6, .62), "fabric": Color(.6, .6, .6)}.get(surface, Color(.74, .72, .68))
	m.albedo_color = Color(tint.r, tint.g, tint.b, .34)
	m.emission_enabled = true
	m.emission = Color(.04, .04, .04)
	quad.material = m
	dust.mesh = quad
	dust.direction = Vector3(0, 0, -1)
	dust.spread = 30.0
	dust.initial_velocity_min = .4
	dust.initial_velocity_max = 1.6
	dust.damping_min = 2.0
	dust.damping_max = 3.5
	dust.gravity = Vector3(0, .15, 0)
	dust.scale_amount_min = .5
	dust.scale_amount_max = 1.2
	dust.angle_max = 360.0
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, .3))
	grow.add_point(Vector2(1.0, 1.0))
	dust.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	dust.color_ramp = fade
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.layers = 3
	main.add_child(dust)
	dust.global_transform = Transform3D(basis, point + out * .05)
	dust.emitting = true
	get_tree().create_timer(1.4, false).timeout.connect(dust.queue_free)
	if surface != "stone" and surface != "metal":
		return
	var sparks := CPUParticles3D.new()
	sparks.name = "ImpactSparks"
	sparks.one_shot = true
	sparks.amount = 9
	sparks.explosiveness = 1.0
	sparks.lifetime = .55
	var dot := QuadMesh.new()
	dot.size = Vector2(.014, .014)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	glow.albedo_color = Color(1.0, .72, .32)
	glow.emission_enabled = true
	glow.emission = Color(1.0, .6, .2)
	glow.emission_energy_multiplier = 4.0
	dot.material = glow
	sparks.mesh = dot
	sparks.direction = Vector3(0, 0, -1)
	sparks.spread = 55.0
	sparks.initial_velocity_min = 2.0
	sparks.initial_velocity_max = 6.5
	sparks.gravity = Vector3(0, -9.8, 0)
	sparks.scale_amount_min = .5
	sparks.scale_amount_max = 1.5
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sparks.layers = 3
	main.add_child(sparks)
	sparks.global_transform = Transform3D(basis, point + out * .03)
	sparks.emitting = true
	get_tree().create_timer(1.0, false).timeout.connect(sparks.queue_free)

## A 40 ms flash: a card on the view model's muzzle, and a warm light in the world where the muzzle would be.
func _muzzle_flash() -> void:
	var p: Dictionary = _prof()
	var card := _flash_card
	if card != null:
		card.visible = true
		card.rotation.z = randf() * TAU
		card.scale = Vector3.ONE * randf_range(.85, 1.2)
	if _flash_light != null:
		_flash_light.visible = true
	var light := OmniLight3D.new()
	light.name = "MuzzleFlash"
	# 0.37: never a lamp to scripts/senses.gd (a second flash before the first is gone gets a generated name).
	light.set_meta("no_shoot", true)
	light.light_color = Color(1.0, .74, .42)
	# In a lit room the flash is one more light; in the dark it is the only one.
	var dark := 1.0
	var bodycam: Variant = main.get("bodycam")
	if bodycam != null and is_instance_valid(bodycam) and bodycam.get("_night") != null:
		dark = lerpf(.45, 1.0, clampf(float(bodycam.get("_night")), 0.0, 1.0))
	light.light_energy = float(p.flash) * randf_range(.8, 1.15) * dark
	light.omni_range = float(p.flash_range)
	light.omni_attenuation = 1.6
	light.shadow_enabled = false
	light.light_cull_mask = 0xFFFFF
	main.add_child(light)
	light.global_position = muzzle_world()
	# One frame of the reference's thirty a second: 33 ms, and never less than one drawn frame.
	var lit := _time
	await RenderingServer.frame_post_draw
	while is_inside_tree() and _time - lit < .03:
		await RenderingServer.frame_post_draw
	light.queue_free()
	if card != null and _time - _last_shot > .03:
		card.visible = false
	if _flash_light != null and _time - _last_shot > .03:
		_flash_light.visible = false

## Powder smoke: a few grey puffs that roll out of the muzzle and hang for half a second. They take the light
## that is there (the flash, the torch), so in the dark they are only seen while something lights them.
func _muzzle_smoke() -> void:
	if mobile:
		return
	var smoke := CPUParticles3D.new()
	smoke.name = "MuzzleSmoke"
	smoke.one_shot = true
	smoke.amount = int({"rifle": 4, "shotgun": 10, "sniper": 9}.get(weapon, 5))
	smoke.explosiveness = .9
	smoke.lifetime = .55
	var quad := QuadMesh.new()
	quad.size = Vector2(.16, .16)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _smoke_texture()
	m.albedo_color = Color(.8, .8, .84, .26 if weapon == "pistol" else .3)
	m.emission_enabled = true
	m.emission = Color(.05, .05, .055)
	quad.material = m
	smoke.mesh = quad
	smoke.direction = Vector3(0, 0, -1)
	smoke.spread = 24.0
	smoke.initial_velocity_min = .5
	smoke.initial_velocity_max = 1.9
	smoke.damping_min = 2.5
	smoke.damping_max = 4.5
	smoke.gravity = Vector3(0, .25, 0)
	smoke.scale_amount_min = .5
	smoke.scale_amount_max = 1.3
	smoke.angle_min = 0.0
	smoke.angle_max = 360.0
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, .35))
	grow.add_point(Vector2(1.0, 1.0))
	smoke.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	smoke.color_ramp = fade
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smoke.layers = 3
	main.add_child(smoke)
	var forward := last_shot_direction.normalized()
	smoke.global_transform = Transform3D(Basis.looking_at(forward, Vector3.UP if absf(forward.y) < .95 else Vector3.RIGHT), muzzle_world() + forward * .06)
	smoke.emitting = true
	get_tree().create_timer(1.0, false).timeout.connect(smoke.queue_free)

## Every third round of the rifle is a tracer: a red streak along the round's path for two frames.
func _tracer(dir: Vector3, distance: float) -> void:
	var from := muzzle_world() + dir * .8
	var length := minf(distance - 1.0, 26.0)
	if length < 1.5:
		return
	var streak := MeshInstance3D.new()
	streak.name = "Tracer"
	var box := BoxMesh.new()
	box.size = Vector3(.012, .012, length)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, .3, .16, .8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	box.material = m
	streak.mesh = box
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.add_child(streak)
	streak.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP if absf(dir.y) < .95 else Vector3.RIGHT), from + dir * length * .5)
	await get_tree().create_timer(.03, false).timeout
	await RenderingServer.frame_post_draw
	streak.queue_free()

## One ball of a load of shot on its way: a short grey streak in the air for a frame or two.
static var _streak_mesh: BoxMesh
func _shot_streak(dir: Vector3, distance: float) -> void:
	var length := minf(distance - .9, randf_range(5.0, 9.0))
	if length < .6:
		return
	if _streak_mesh == null:
		_streak_mesh = BoxMesh.new()
		_streak_mesh.size = Vector3(.006, .006, 1.0)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = Color(1.0, .86, .62, .34)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_streak_mesh.material = m
	var streak := MeshInstance3D.new()
	streak.name = "Shot"
	streak.mesh = _streak_mesh
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.add_child(streak)
	var from := muzzle_world() + dir * .7
	streak.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP if absf(dir.y) < .95 else Vector3.RIGHT).scaled_local(Vector3(1.0, 1.0, length)), from + dir * length * .5)
	await get_tree().create_timer(.035, false).timeout
	await RenderingServer.frame_post_draw
	if is_instance_valid(streak):
		streak.queue_free()

## The rifle throws its brass out to the right: a small case in the view model's world, on a short arc.
func _eject_casing() -> void:
	if _rifle == null or mobile:
		return
	var brass := MeshInstance3D.new()
	brass.name = "Casing"
	var shell := weapon == "shotgun"
	var shape := CylinderMesh.new()
	var long_case := weapon == "sniper"
	shape.top_radius = .006 if shell else (.0042 if long_case else .0028)
	shape.bottom_radius = .006 if shell else (.0048 if long_case else .0028)
	shape.height = .034 if shell else (.03 if long_case else .015)
	shape.radial_segments = 8
	shape.rings = 1
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(.55, .06, .04) if shell else Color(.78, .6, .28)
	m.metallic = 0.0 if shell else 1.0
	m.roughness = .32
	shape.material = m
	brass.mesh = shape
	_view_camera.add_child(brass)
	brass.transform = _rifle.transform * Transform3D(Basis.from_euler(Vector3(PI * .5, 0, 0)), _rifle_at.get("eject", Vector3.ZERO))
	var velocity := _rifle.transform.basis * Vector3(randf_range(1.5, 2.6), randf_range(.7, 1.5), randf_range(.2, .9))
	_casings.append({"node": brass, "velocity": velocity, "spin": Vector3(randf_range(-30, 30), randf_range(-30, 30), randf_range(-30, 30)), "life": .5})

func _move_casings(delta: float) -> void:
	for i in range(_casings.size() - 1, -1, -1):
		var case: Dictionary = _casings[i]
		var node: Node3D = case.node
		case.life = float(case.life) - delta
		if case.life <= 0.0 or not is_instance_valid(node):
			if is_instance_valid(node):
				node.queue_free()
			_casings.remove_at(i)
			continue
		var velocity: Vector3 = case.velocity
		velocity.y -= 9.8 * delta
		case.velocity = velocity
		node.position += velocity * delta
		var spin: Vector3 = case.spin
		node.rotate_object_local(Vector3.RIGHT, spin.x * delta)
		node.rotate_object_local(Vector3.UP, spin.y * delta)

## The muzzle's place in the main world: the view model's muzzle, carried from its camera to the player's.
func muzzle_world() -> Vector3:
	var camera := player.camera
	if _muzzle != null and _view_camera != null and _muzzle.is_inside_tree():
		var local := _view_camera.global_transform.affine_inverse() * _muzzle.global_position
		# The view model's lens is longer than the world's: put the point where it is seen.
		var wider := tan(deg_to_rad(camera.fov) * .5) / maxf(tan(deg_to_rad(_view_camera.fov) * .5), .01)
		return camera.global_transform * Vector3(local.x * wider, local.y * wider, local.z)
	return camera.global_transform * Vector3(.12, -.1, -.5)

# ---------------------------------------------------------------- sound

func _build_audio() -> void:
	if AudioServer.get_bus_index(BUS) < 0:
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, BUS)
		AudioServer.set_bus_send(index, "Master")
		_reverb = AudioEffectReverb.new()
		_reverb.room_size = .6
		_reverb.damping = .5
		_reverb.spread = .9
		_reverb.dry = 1.0
		_reverb.wet = .15
		_reverb.hipass = .2
		_reverb.predelay_msec = 30.0
		AudioServer.add_bus_effect(index, _reverb)
	else:
		_reverb = AudioServer.get_bus_effect(AudioServer.get_bus_index(BUS), 0) as AudioEffectReverb
	_shot_voice = AudioStreamPlayer3D.new()
	_shot_voice.name = "Gunshot"
	_shot_voice.bus = BUS
	_shot_voice.unit_size = 10.0
	_shot_voice.max_polyphony = 6
	player.camera.add_child(_shot_voice)
	_shot_voice.position = Vector3(.15, -.1, -.4)
	_tail_voice = AudioStreamPlayer.new()
	_tail_voice.name = "GunshotTail"
	_tail_voice.bus = BUS
	_tail_voice.max_polyphony = 4
	add_child(_tail_voice)
	_hand_voice = AudioStreamPlayer.new()
	_hand_voice.name = "GunHands"
	_hand_voice.max_polyphony = 3
	add_child(_hand_voice)

func _stream(key: String) -> AudioStream:
	if not _streams.has(key):
		var path := SFX + key + ".ogg"
		_streams[key] = load(path) if ResourceLoader.exists(path) else null
	return _streams[key]

func _hand_sound(key: String, volume := 0.0, pitch := 1.0) -> void:
	var stream := _stream(key)
	if stream == null:
		return
	_hand_voice.stream = stream
	_hand_voice.volume_db = volume
	_hand_voice.pitch_scale = pitch
	_hand_voice.play()

func _shot_sound() -> void:
	var profile: Dictionary = _prof()
	var p := player.camera.global_position
	var outdoors := p.y < -.4 or p.z < -17.0 or (p.z > 2.62 and p.x > .8)
	var zone := InteriorFields.zone_weight(p) if outdoors else 0.0
	var in_hut: bool = story != null and story.get("hut") != null and story.hut.is_inside(player.global_position)
	if _reverb != null:
		_reverb.room_size = .35 if in_hut else (.5 if not outdoors else lerpf(.75, .95, zone))
		_reverb.wet = .28 if not outdoors or in_hut else lerpf(.22, .12, zone)
		_reverb.damping = .5
	# 0.33: the room it is really fired in (scripts/sound_stage.gd).
	var stage: InteriorSoundStage = main.get("sound_stage") if main != null else null
	if stage != null:
		if _reverb != null:
			stage.shape_gun(_reverb)
		outdoors = outdoors and stage.open_sky()
	_shot_voice.stream = _stream("gun_shot")
	_shot_voice.pitch_scale = randf_range(.96, 1.04) * float(profile.pitch)
	_shot_voice.volume_db = float(profile.volume)
	_shot_voice.play()
	if outdoors and not in_hut:
		# Far outside, the shot comes back off the tree lines and the town.
		_tail_voice.stream = _stream("gun_tail")
		_tail_voice.volume_db = lerpf(-12.0, -5.0, zone)
		_tail_voice.pitch_scale = randf_range(.95, 1.03) * float(profile.pitch)
		_tail_voice.play()

# ---------------------------------------------------------------- view model

func _build_view() -> void:
	_container = SubViewportContainer.new()
	_container.name = "GunView"
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.visible = false
	_near = ShaderMaterial.new()
	_near.shader = NEAR_SHADER
	_container.material = _near
	main.hud.add_child(_container)
	# Under everything else on the HUD (the crosshair, the toasts and the dialogue draw over it).
	main.hud.move_child(_container, 0)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.positional_shadow_atlas_size = 0
	_container.add_child(_viewport)
	var world := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_CLEAR_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(.4, .45, .6)
	_env.ambient_light_energy = .2
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# 0.32: steel and anodised aluminium show what is round them, and round these there was nothing. A soft box
	# low ahead and all round, a dimmer ceiling, a dark floor: the tops of the slide and the rail take a sheen,
	# the sides stay dark, a barrel gets its line of light. `_light_like_the_scene` keeps it as dim as the place.
	_env.sky = _studio_sky()
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	world.environment = _env
	_viewport.add_child(world)
	_view_camera = Camera3D.new()
	_view_camera.fov = VIEW_FOV
	_view_camera.near = .01
	_view_camera.far = 5.0
	_viewport.add_child(_view_camera)
	_key = DirectionalLight3D.new()
	_key.name = "Key"
	_key.shadow_enabled = false
	_viewport.add_child(_key)
	_key.look_at_from_position(Vector3.ZERO, Vector3(.35, -.7, -.6), Vector3.UP)
	# 0.32: a second light from ahead and above, low over the weapon's top: it runs along the slide, the rail and the
	# barrel as a line of light, which is what shows their shape from behind.
	_rim = DirectionalLight3D.new()
	_rim.name = "Rim"
	_rim.shadow_enabled = false
	_rim.light_specular = .7
	_viewport.add_child(_rim)
	_rim.look_at_from_position(Vector3.ZERO, Vector3(-.75, -.4, .5), Vector3.UP)
	_rig = Node3D.new()
	_rig.name = "Rig"
	_view_camera.add_child(_rig)
	var grip: Node3D = null
	if ResourceLoader.exists(ARMS):
		_arms = (load(ARMS) as PackedScene).instantiate() as Node3D
		_arms.name = "Arms"
		_rig.add_child(_arms)
		# Built facing -Y in Blender (+Z after the glTF import): turn it to look down the camera's -Z.
		_arms.rotation.y = PI
		_arms_anim = _arms.find_child("AnimationPlayer", true, false) as AnimationPlayer
		grip = _arms.find_child("gun_grip", true, false) as Node3D
		_own_arm_loops()
		_skin_hands()
	_glock = GLOCK.instantiate() as Node3D
	_glock.name = "Glock"
	if grip != null:
		grip.add_child(_glock)
		_glock.position = PISTOL_IN_HAND
	else:
		_rig.add_child(_glock)
		_glock.transform = GUN_REST
	_glock_anim = _glock.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_glock_meshes = _glock.find_children("*", "MeshInstance3D", true, false)
	for part in ["magazine_7", "magazine_001_8", "slide rig _18"]:
		var node := _glock.find_child(part, true, false) as Node3D
		if node != null:
			_parts[node] = Transform3D.IDENTITY
	# Muzzle: the front of the gun (its local +Z end), a little above the bore line.
	_pistol_muzzle = Node3D.new()
	_pistol_muzzle.name = "Muzzle"
	_glock.add_child(_pistol_muzzle)
	var bounds := InteriorModelKit.local_bounds(_glock)
	_pistol_muzzle.position = Vector3(bounds.get_center().x, bounds.position.y + bounds.size.y * .82, bounds.end.z + .01)
	_glock_muzzle = _pistol_muzzle.position
	_muzzle = _pistol_muzzle
	_flash_cards["pistol"] = _make_flash(_pistol_muzzle, .24, Vector3(0, 0, .04))
	_flash_card = _flash_cards["pistol"]
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, .72, .4)
	_flash_light.light_energy = 2.5
	_flash_light.omni_range = .8
	_flash_light.visible = false
	_view_camera.add_child(_flash_light)
	_flash_light.position = Vector3(.0, -.08, -.6)
	_rig.position = Vector3(0, -.45, 0)
	# 0.27: the arms reach for the weapon (scripts/arm_ik.gd).
	if _arms != null and grip != null:
		_skeleton = _arms.find_child("Skeleton3D", true, false) as Skeleton3D
		if _skeleton != null:
			_ik = InteriorArmIK.new()
			_ik.name = "ArmIK"
			_skeleton.add_child(_ik)
			_skel_to_rig = _relative(_skeleton, _rig)
			_grip_local = grip.transform * _glock.transform
			# The left hand on the pistol, from where the right hand is: its mirror image, canted.
			var right_hand := _grip_local.affine_inverse().orthonormalized()
			var mirrored := Basis(-right_hand.basis.x * Vector3(-1, 1, 1), right_hand.basis.y * Vector3(-1, 1, 1), right_hand.basis.z * Vector3(-1, 1, 1))
			var support := Basis(Vector3.RIGHT, SUPPORT_CANT) * mirrored
			_ik.left_on_right = _grip_local * Transform3D(support, SUPPORT_KNUCKLE - support * INDEX_KNUCKLE_L)
	_build_rifle()
	_load_fits()

func _studio_sky() -> Sky:
	var image := Image.create(128, 64, false, Image.FORMAT_RGBF)
	for y in 64:
		var elevation := (.5 - (float(y) + .5) / 64.0) * 180.0
		var light := .02 + .03 * smoothstep(-60.0, -5.0, elevation)
		if elevation > 0.0:
			light = .08 + 1.0 * exp(-pow((elevation - 22.0) / 13.0, 2.0)) + .3 * smoothstep(50.0, 80.0, elevation)
		for x in 128:
			# Broken up a little round the horizon, so a turning weapon's sheen moves.
			var round := .8 + .2 * sin(float(x) / 128.0 * TAU * 3.0) * sin(float(x) / 128.0 * TAU + 1.0)
			image.set_pixel(x, y, Color(1.0, .97, .93) * light * round)
	var panorama := PanoramaSkyMaterial.new()
	panorama.panorama = ImageTexture.create_from_image(image)
	panorama.energy_multiplier = .5
	_studio = panorama
	var sky := Sky.new()
	sky.sky_material = panorama
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	return sky

## 0.32: the long guns were built with flat colours (tools/blender/story): a rifle in one light grey. What they
## are made of, here: black anodising, parkerised steel, polymer, each with the fine unevenness of a used surface
## (a noise in the roughness, laid on without texture coordinates).
const FINISHES := {
	"ar_anodised": [Color(.05, .052, .056), .7, .44], "ar_steel": [Color(.085, .087, .092), .9, .36], "ar_polymer": [Color(.035, .035, .037), .0, .62],
	"ar_magazine": [Color(.045, .045, .048), .0, .5], "sg_steel": [Color(.06, .062, .068), .85, .36], "sn_steel": [Color(.055, .058, .064), .85, .36],
}

func _finish(node: Node3D) -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = .035
	noise.fractal_octaves = 4
	var wear := NoiseTexture2D.new()
	wear.width = 256
	wear.height = 256
	wear.seamless = true
	wear.noise = noise
	var ramp := Gradient.new()
	ramp.set_color(0, Color(.62, .62, .62))
	ramp.set_color(1, Color(1.0, 1.0, 1.0))
	wear.color_ramp = ramp
	var done := {}
	for found in node.find_children("*", "MeshInstance3D", true, false):
		var instance := found as MeshInstance3D
		if instance.mesh == null:
			continue
		for surface in instance.mesh.get_surface_count():
			var material := instance.mesh.surface_get_material(surface) as StandardMaterial3D
			if material == null or material.albedo_texture != null or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue
			if not done.has(material):
				var own := material.duplicate() as StandardMaterial3D
				var finish: Array = FINISHES.get(material.resource_name, [])
				if not finish.is_empty():
					own.albedo_color = finish[0]
					own.metallic = finish[1]
					own.roughness = finish[2]
				own.roughness_texture = wear
				own.uv1_triplanar = true
				own.uv1_scale = Vector3.ONE * 9.0
				done[material] = own
			instance.set_surface_override_material(surface, done[material])

## The hands' own material: the downloaded hands' skin, normal and occlusion / roughness maps
## (tools/assets/prepare_hands.py; the Godot XR Tools hands, CC0).
func _skin_hands() -> void:
	var skin := ORMMaterial3D.new()
	skin.resource_name = "FP hand skin"
	skin.albedo_texture = load(HAND_TEXTURES + "hand_skin.png") as Texture2D
	skin.orm_texture = load(HAND_TEXTURES + "hand_orm.png") as Texture2D
	skin.normal_enabled = true
	skin.normal_texture = load(HAND_TEXTURES + "hand_normal.png") as Texture2D
	skin.normal_scale = .35
	skin.metallic_specular = .35
	for node in _arms.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance.mesh == null:
			continue
		for surface in instance.mesh.get_surface_count():
			var material := instance.mesh.surface_get_material(surface)
			if material != null and material.resource_name == "FP hand skin":
				instance.set_surface_override_material(surface, skin)

## Captures and checks: look at the hands from outside (positions in the view camera's space: -Z ahead, +Y up).
## Without arguments the picture goes back to the body camera's.
func inspect_view(from := Vector3.INF, at := Vector3.ZERO, fov := 34.0) -> void:
	if not from.is_finite():
		if _inspect_camera != null:
			_inspect_camera.current = false
		_view_camera.current = true
		return
	if _inspect_camera == null:
		_inspect_camera = Camera3D.new()
		_inspect_camera.name = "Inspect"
		_inspect_camera.near = .01
		_inspect_camera.far = 5.0
		_viewport.add_child(_inspect_camera)
	_inspect_camera.fov = fov
	_inspect_camera.look_at_from_position(from, at, Vector3.UP)
	_inspect_camera.current = true

## Which pose each hand's fingers take now: by the weapon, and by what the hand is doing to it.
func _finger_poses(delta: float) -> void:
	if _ik == null:
		return
	var right := "pistol"
	var left := "support"
	var both := 0.0
	if weapon == "pistol":
		both = smoothstep(.5, .9, _show)
		if reloading and _reload_t >= 0.0:
			both *= 1.0 - smoothstep(0.0, .1, _reload_t) * (1.0 - smoothstep(1.45, 1.6, _reload_t))
		if _show < .55:
			left = "relaxed"
		if reloading and _reload_t >= 0.0:
			if _reload_t >= .12 and _reload_t < 1.04:
				left = "mag"
			elif _reload_t >= 1.04 and _reload_t < 1.36:
				left = "rack"
	else:
		right = "grip"
		left = "guard"
		if weapon == "shotgun":
			if _shell_blend > .25:
				left = "shell"
		elif reloading and _reload_t >= 0.0:
			if _reload_t >= .3 and _reload_t < 1.56:
				left = "mag"
			elif _reload_t >= 1.56 and _reload_t < float(RIFLE_RELOAD[3]) + .08:
				left = "slap" if weapon == "rifle" else "mag"
		if weapon == "sniper" and _pump_t >= .06 and _pump_t < float(BOLT[4]):
			right = "bolt"
	# The trigger finger: along the frame until there is something to shoot at or the trigger is being pulled.
	var held := trigger_held or (not mobile and InputMap.has_action("fire") and Input.is_action_pressed("fire"))
	var want := 0.0
	_ik.left_on_right_weight = both
	if (right == "pistol" or right == "grip") and not reloading:
		if aiming or held or _time < _trigger_until:
			want = 1.0
		if _time - _last_shot < .07:
			want = 2.0
	_trigger = lerpf(_trigger, want, 1.0 - exp(-26.0 * delta))
	var right_pose: Dictionary = _hand_pose("R", right).duplicate()
	if (right == "pistol" or right == "grip") and _trigger > .01:
		var along: Array = right_pose["index"]
		var touching: Array = (_fits.get(weapon + ":R:trigger", {}) as Dictionary).get("index", TRIGGER_FINGER)
		var pulled := [float(touching[0]) + TRIGGER_PULL[0], float(touching[1]) + TRIGGER_PULL[1], float(touching[2]) + TRIGGER_PULL[2], touching[3]]
		var on := _blend(along, touching, clampf(_trigger, 0.0, 1.0))
		right_pose["index"] = _blend(on, pulled, clampf(_trigger - 1.0, 0.0, 1.0))
	_ik.finger_pose["R"] = right_pose
	_ik.finger_pose["L"] = _hand_pose("L", left)

## ---------------------------------------------------------------------------------------------------------------
## 0.31: fingers closed by contact. The hands are real hand models (tools/assets/fetch_hands.py); how far each finger
## closes on each weapon is not guessed: with the hand placed on the weapon, every finger is closed joint by joint
## until it touches the weapon's own surface (or the other hand). That is done once, off line
## (`-- --capture-review --capture-views=fit`), and kept in assets/hand_fits.json: "<weapon>:<side>:<pose>" ->
## {finger: degrees}, in the same form as HAND_POSES.
const FIT_FILE := "res://assets/hand_fits.json"
## Each finger's last bone's length and the finger's radius (m), measured on the hand model at the player's size.
const FIT_TIP := {"index": .0267, "middle": .0221, "ring": .0254, "pinky": .0194, "thumb": .0298}
const FIT_RADIUS := {"index": .0080, "middle": .0084, "ring": .0078, "pinky": .0068, "thumb": .0098}
## How much of a finger's radius is solid: the rest is skin that gives.
const FIT_FIRM := .66
const FIT_STEP := 1.5
## Beyond this a finger is simply not on anything (m).
const FIT_FAR := .03
## Where a finger starts from and how far each of its joints may close (degrees past the relaxed hand).
const FIT_WRAP := {"start": [-14.0, -14.0, -6.0, 0.0], "limit": [98.0, 108.0, 78.0]}
const FIT_THUMB := {"start": [-12.0, 0.0, 0.0, -6.0, -4.0], "limit": [62.0, 52.0, 56.0]}
var _fits := {}
var _fit_shape: SphereShape3D
var _fit_query: PhysicsShapeQueryParameters3D

func _load_fits() -> void:
	if not FileAccess.file_exists(FIT_FILE):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIT_FILE))
	if parsed is Dictionary:
		_fits = parsed

## What a hand's fingers do in a pose: as fitted to this weapon, or the general pose.
func _hand_pose(side: String, key: String) -> Dictionary:
	return _fits.get("%s:%s:%s" % [weapon, side, key], HAND_POSES[key])

## The weapon's surface as one static body at the origin of the hands' own world, in the weapon's own frame.
func _fit_body(node: Node3D) -> StaticBody3D:
	var faces := PackedVector3Array()
	for found in node.find_children("*", "MeshInstance3D", true, false):
		var instance := found as MeshInstance3D
		if instance.mesh == null or instance.mesh is PrimitiveMesh or not instance.is_visible_in_tree() and not node.is_ancestor_of(instance):
			continue
		var relative := _relative(instance, node)
		for vertex in instance.mesh.get_faces():
			faces.append(relative * vertex)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var body := StaticBody3D.new()
	body.name = "FitBody"
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	_viewport.add_child(body)
	return body

## One finger's sample points from joint `from` on, [point, radius], with the hand bone at `hand`.
func _fit_points(side: String, hand: Transform3D, digit: String, pose: Array, from: int) -> Array:
	var sign := 1.0 if side == "R" else -1.0
	var at := hand
	var out := []
	var radius := float(FIT_RADIUS[digit]) * FIT_FIRM
	for k in 3:
		var id := _skeleton.find_bone("%s.%02d.%s" % [digit, k + 1, side])
		var rest := _skeleton.get_bone_rest(id)
		var turn: Quaternion
		if digit == "thumb":
			if k == 0:
				turn = Quaternion(Vector3.BACK, deg_to_rad(float(pose[1])) * sign) * Quaternion(Vector3.UP, deg_to_rad(float(pose[2])) * sign) \
					* Quaternion(Vector3.RIGHT, -deg_to_rad(float(pose[0])))
			else:
				turn = Quaternion(Vector3.RIGHT, -deg_to_rad(float(pose[k + 2])))
		elif k == 0:
			turn = Quaternion(Vector3.BACK, deg_to_rad(float(pose[3])) * sign) * Quaternion(Vector3.RIGHT, -deg_to_rad(float(pose[0])))
		else:
			turn = Quaternion(Vector3.RIGHT, -deg_to_rad(float(pose[k])))
		at = at * Transform3D(rest.basis.orthonormalized() * Basis(turn), rest.origin)
		if k < from:
			continue
		var length := float(FIT_TIP[digit])
		if k < 2:
			var next := _skeleton.find_bone("%s.%02d.%s" % [digit, k + 2, side])
			length = _skeleton.get_bone_rest(next).origin.length()
		var taper := 1.0 - .07 * k
		for part: float in ([.3, .68] if k == 2 else [.38, .8]):
			out.append([at * Vector3(0, length * part, 0), radius * taper])
	return out

func _fit_hit(space: PhysicsDirectSpaceState3D, points: Array, others: Array) -> bool:
	for point: Array in points:
		var at: Vector3 = point[0]
		var radius := float(point[1])
		for other: Array in others:
			if at.distance_to(other[0]) < radius + float(other[1]):
				return true
		_fit_shape.radius = radius
		_fit_query.transform = Transform3D(Basis.IDENTITY, at)
		if not space.intersect_shape(_fit_query, 1).is_empty():
			return true
	return false

## How far a finger's skin at one point is from the nearest thing (m, 0 when touching, up to `FIT_FAR`).
func _fit_gap(space: PhysicsDirectSpaceState3D, at: Vector3, skin: float, others: Array) -> float:
	var gap := FIT_FAR
	for other: Array in others:
		gap = minf(gap, at.distance_to(other[0]) - skin - float(other[1]) / FIT_FIRM)
	if gap <= 0.0:
		return 0.0
	# The smallest sphere here that reaches the weapon.
	var low := skin
	var high := skin + gap
	_fit_query.transform = Transform3D(Basis.IDENTITY, at)
	_fit_shape.radius = high
	if space.intersect_shape(_fit_query, 1).is_empty():
		return gap
	for step in 5:
		var mid := (low + high) * .5
		_fit_shape.radius = mid
		if space.intersect_shape(_fit_query, 1).is_empty():
			low = mid
		else:
			high = mid
	return maxf(high - skin, 0.0)

## How badly a pose holds: the gaps under the finger, the far end counting for more. INF if it goes into anything.
func _fit_cost(space: PhysicsDirectSpaceState3D, points: Array, others: Array) -> float:
	if _fit_hit(space, points, others):
		return INF
	var cost := 0.0
	for index in points.size():
		var skin := float(points[index][1]) / FIT_FIRM
		cost += _fit_gap(space, points[index][0], skin, others) * (1.0 + .3 * index)
	return cost

## Wrap one finger round what the hand holds: of every way it can bend without going into anything, the one that
## lies closest against the surface along its whole length; between equals, the more closed.
func _fit_digit(space: PhysicsDirectSpaceState3D, side: String, hand: Transform3D, digit: String, spec: Dictionary, others: Array) -> Array:
	var start: Array = spec.start
	var limit: Array = spec.limit
	var thumb := digit == "thumb"
	var joints := [0, 3, 4] if thumb else [0, 1, 2]
	var best: Array = start.duplicate()
	var best_score := INF
	# Coarsely over everything it can do, then finely round the best of that.
	for pass_index in 2:
		var step := 12.0 if pass_index == 0 else 4.0
		var lows := []
		var highs := []
		for k in 3:
			if pass_index == 0:
				lows.append(float(start[joints[k]]))
				highs.append(float(limit[k]))
			else:
				lows.append(maxf(float(start[joints[k]]), float(best[joints[k]]) - 8.0))
				highs.append(minf(float(limit[k]), float(best[joints[k]]) + 8.0))
		var a: float = lows[0]
		while a <= float(highs[0]) + .01:
			var b: float = lows[1]
			while b <= float(highs[1]) + .01:
				var c: float = lows[2]
				while c <= float(highs[2]) + .01:
					var pose: Array = best.duplicate()
					pose[joints[0]] = a
					pose[joints[1]] = b
					pose[joints[2]] = c
					var cost := _fit_cost(space, _fit_points(side, hand, digit, pose, 0), others)
					if cost < INF:
						# A finger closes most at its middle joint: an end joint bent much further than that is a claw.
						var claw := maxf(0.0, c - b - 10.0) * .0004
						var score := cost - (a + b + c) * .00002 + claw
						if score < best_score:
							best_score = score
							best = pose
					c += step
				b += step
			a += step
	for i in best.size():
		best[i] = snappedf(float(best[i]), .1)
	print("INTERIOR_HAND_WRAP ", digit, " ", side, " ", best, " gaps ", snappedf(best_score * 1000.0, .1))
	return best

## A finger put where it belongs rather than wrapped: of every pose it can take without going into anything, the
## one that brings its pad nearest `target` (bending as little as it can).
func _fit_reach(space: PhysicsDirectSpaceState3D, side: String, hand: Transform3D, digit: String, target: Vector3, others: Array) -> Array:
	var best: Array = []
	var best_score := INF
	var thumb := digit == "thumb"
	var curls := range(-30, 71, 10) if thumb else range(-24, 61, 6)
	var spreads := range(-50, 51, 10) if thumb else range(-12, 37, 6)
	var rolls := range(-30, 31, 15) if thumb else [0]
	var seconds := range(-10, 41, 10) if thumb else range(-24, 91, 6)
	var thirds := range(-6, 31, 12) if thumb else range(-14, 51, 8)
	for curl: int in curls:
		for spread: int in spreads:
			for roll: int in rolls:
				for second: int in seconds:
					for third: int in thirds:
						var pose: Array = [curl, spread, roll, second, third] if thumb else [curl, second, third, spread]
						var points := _fit_points(side, hand, digit, pose, 0)
						var pad: Vector3 = points[5][0]
						var bend := absf(curl) + absf(second) + absf(third) + absf(spread) * .5 + absf(roll) * .5
						var score := pad.distance_to(target) + bend * .00004
						if score >= best_score:
							continue
						if _fit_hit(space, points.slice(2) if thumb else points, []) or _fit_hit(space, points.slice(2), others):
							continue
						best_score = score
						best = pose
	if best.is_empty():
		return (FIT_THUMB.start as Array).duplicate() if thumb else (FIT_WRAP.start as Array).duplicate()
	for i in best.size():
		best[i] = float(best[i])
	print("INTERIOR_HAND_REACH ", digit, " ", side, " ", best, " off by ", snappedf((best_score) * 1000.0, .1), " mm")
	return best

## A whole hand: {finger: pose}. `specs` may give a finger its own start and limits; `others` are spheres in the way.
func _fit_hand(space: PhysicsDirectSpaceState3D, side: String, hand: Transform3D, specs: Dictionary, others: Array) -> Dictionary:
	var out := {}
	for digit: String in ["index", "middle", "ring", "pinky", "thumb"]:
		var spec: Dictionary = specs.get(digit, FIT_THUMB if digit == "thumb" else FIT_WRAP)
		out[digit] = _fit_digit(space, side, hand, digit, spec, others)
	return out

## A fitted hand as spheres, for the other hand to close on.
func _fit_spheres(side: String, hand: Transform3D, pose: Dictionary) -> Array:
	var out := []
	for digit: String in pose:
		out.append_array(_fit_points(side, hand, digit, pose[digit], 0))
	var mirror := 1.0 if side == "R" else -1.0
	for palm: Vector3 in [Vector3(-.014, .075, -.002), Vector3(.016, .068, -.002), Vector3(.0, .04, -.002)]:
		out.append([hand * Vector3(palm.x * mirror, palm.y, palm.z), .015])
	return out

## Fit every hold of every weapon and write assets/hand_fits.json.
func fit_hands() -> Dictionary:
	if _skeleton == null:
		return {}
	_fit_shape = SphereShape3D.new()
	_fit_query = PhysicsShapeQueryParameters3D.new()
	_fit_query.shape = _fit_shape
	_fit_query.collide_with_bodies = true
	var out := {}
	for which: String in ["pistol", "rifle", "shotgun", "sniper"]:
		var node: Node3D = _glock if which == "pistol" else (_longs[which] as Dictionary).node
		var body := _fit_body(node)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var space := _viewport.find_world_3d().direct_space_state
		var hands: Dictionary = {} if which == "pistol" else (_longs[which] as Dictionary).hands
		var on_glock := _grip_local.affine_inverse().orthonormalized()
		var right: Transform3D = on_glock if which == "pistol" else (hands["right"] as Transform3D).orthonormalized()
		# A long gun's grip is held as the Glock's is: what the fingers reach for is carried over with the hand.
		var carry := right * on_glock.affine_inverse()
		var key := "pistol" if which == "pistol" else "grip"
		var held := _fit_hand(space, "R", right, {}, [])
		held["index"] = _fit_reach(space, "R", right, "index", carry * (REACH.along as Vector3), [])
		held["thumb"] = _fit_reach(space, "R", right, "thumb", carry * (REACH.thumb_r as Vector3), [])
		out["%s:R:%s" % [which, key]] = held
		out["%s:R:trigger" % which] = {"index": _fit_reach(space, "R", right, "index", carry * (REACH.trigger as Vector3), [])}
		if which == "pistol":
			var left := (right * _ik.left_on_right).orthonormalized()
			# The left hand's fingers close over the right hand's three that hold the grip.
			var over := []
			for under: String in ["middle", "ring", "pinky"]:
				over.append_array(_fit_points("R", right, under, held[under], 0))
			var support := _fit_hand(space, "L", left, {}, over)
			support["thumb"] = _fit_reach(space, "L", left, "thumb", REACH.thumb_l, over)
			out["pistol:L:support"] = support
		else:
			out["%s:L:guard" % which] = _fit_hand(space, "L", hands["guard"], {}, [])
			if hands.has("mag"):
				out["%s:L:mag" % which] = _fit_hand(space, "L", hands["mag"], {}, [])
		body.free()
		await get_tree().physics_frame
	var file := FileAccess.open(FIT_FILE, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(out, "\t"))
		file.close()
	_fits = out
	print("INTERIOR_HAND_FITS ", JSON.stringify(out))
	return out

static func _blend(a: Array, b: Array, k: float) -> Array:
	var out := []
	for i in a.size():
		out.append(lerpf(float(a[i]), float(b[i]), k))
	return out

func _make_flash(muzzle: Node3D, size: float, at: Vector3) -> MeshInstance3D:
	var card := MeshInstance3D.new()
	card.name = "Flash"
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	card.mesh = quad
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = _flash_texture()
	m.albedo_color = Color(1.0, .78, .45)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	card.material_override = m
	card.visible = false
	muzzle.add_child(card)
	card.position = at
	return card

## A node's transform in an ancestor's space (neither needs to be in the tree).
static func _relative(node: Node3D, ancestor: Node) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result

## A hand bone's pose from where its fist's hole is and how the hand lies: `across` is the axis through the fist
## (the thing held), `along` runs from the wrist to the knuckles.
static func _hand(across: Vector3, along: Vector3, hole_at: Vector3, hole: Vector3) -> Transform3D:
	var y := along.normalized()
	var z := across.cross(y).normalized()
	var basis := Basis(y.cross(z), y, z)
	return Transform3D(basis, hole_at - basis * hole)

## The long guns: each its own node under the view camera (muzzle along -Z); the hands go to it.
func _build_rifle() -> void:
	_build_long("rifle", RIFLE, ["ar15_magazine", "ar15_bolt", "ar15_charging_handle"], -.05, .4, Vector3(0, 0, -.07))
	_build_long("shotgun", SHOTGUN, ["sg_forend", "sg_bolt"], 0.0, .6, Vector3(0, 0, -.05))
	_build_long("sniper", SNIPER, ["sn_bolt", "sn_magazine"], -.1, .7, Vector3(0, 0, -.06))
	_show_weapon()

func _build_long(which: String, scene: PackedScene, part_names: Array, reach: float, flash_size: float, flash_at: Vector3, cls := "") -> void:
	if cls == "":
		cls = which
	var node := scene.instantiate() as Node3D
	node.name = which.capitalize()
	node.visible = false
	_view_camera.add_child(node)
	_finish(node)
	var at := {}
	var parts := {}
	var rest := {}
	var hands := {}
	for key: String in ["grip_r", "grip_l", "muzzle", "eject", "rear_sight", "front_sight", "butt", "bolt_handle", "mag"]:
		var socket := node.find_child(key, true, false) as Node3D
		at[key] = _relative(socket, node).origin if socket != null else Vector3.ZERO
	for key: String in part_names:
		var part := node.find_child(key, true, false) as Node3D
		if part != null:
			parts[key] = part
			rest[key] = part.transform
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	node.add_child(muzzle)
	muzzle.position = at["muzzle"]
	_flash_cards[which] = _make_flash(muzzle, flash_size, flash_at)
	# The right fist round the pistol grip, as it holds the Glock's; the left under the handguard (or the pump).
	var grip_r: Vector3 = at["grip_r"]
	var grip_l: Vector3 = at["grip_l"]
	hands["right"] = (Transform3D(Basis(Vector3.RIGHT, RIFLE_GRIP_TILT) * Basis(Vector3.UP, PI), grip_r) * Transform3D(Basis.IDENTITY, -PISTOL_GRIP) * _grip_local.affine_inverse()) \
		.translated_local(Vector3(.0, .0, LONG_GRIP_OUT))
	# 0.31: the palm cups the handguard (or the pump) from below, the wrist to its left; the fingers go up its right
	# side and the thumb up its left.
	var guard_low: float = {"rifle": .0165, "shotgun": .0125, "sniper": .0165}.get(cls, .0165)
	hands["guard"] = _hand(Vector3(.0, .0, -1.0), Vector3(.96, .28, .0), Vector3(-.010, grip_l.y - .013, grip_l.z - reach), GUARD_KNUCKLE)
	if cls == "rifle":
		# Round the magazine, low out of sight (fetching the next one) and on the bolt catch.
		var mag_hole := Vector3(.0, -.186, -.1335)
		hands["mag"] = _hand(Vector3(.0, 1.0, -.2), Vector3(1.0, .0, .1), mag_hole, HOLE_L)
		hands["low"] = _hand(Vector3(.3, 1.0, -.2), Vector3(1.0, -.2, .1), mag_hole + Vector3(-.1, -.42, .14), HOLE_L)
		hands["catch"] = _hand(Vector3(.0, .85, .5), Vector3(.0, .5, -.85), Vector3(-.045, -.02, -.085), HOLE_L)
	elif cls == "sniper":
		# Round the box magazine, low out of sight for the next one, and back toward the forend.
		var box_hole: Vector3 = at["mag"]
		hands["mag"] = _hand(Vector3(.0, 1.0, -.2), Vector3(1.0, .0, .1), box_hole, HOLE_L)
		hands["low"] = _hand(Vector3(.3, 1.0, -.2), Vector3(1.0, -.2, .1), box_hole + Vector3(-.1, -.4, .14), HOLE_L)
		hands["catch"] = (hands["mag"] as Transform3D).interpolate_with(hands["guard"], .5)
	else:
		# Under the receiver, pushing a shell into the loading port; and down at the belt for the next one.
		var port := Vector3(-.01, -.078, -.13)
		hands["port"] = _hand(Vector3(.0, .0, -1.0), Vector3(1.0, -.4, .0), port, HOLE_L)
		hands["low"] = _hand(Vector3(.3, 1.0, -.2), Vector3(1.0, -.2, .1), port + Vector3(-.1, -.36, .2), HOLE_L)
	_longs[which] = {"node": node, "at": at, "parts": parts, "rest": rest, "hands": hands, "muzzle": muzzle}
	if _report:
		print("INTERIOR_GUN_SOCKETS ", which, " ", at, " guard ", (hands["guard"] as Transform3D).origin, " right ", (hands["right"] as Transform3D).origin)

## The bolt now: how far its handle is turned up (0 to 1) and how far back it is (0 to 1).
func _bolt_now() -> Vector2:
	if _pump_t < 0.0 or weapon != "sniper":
		return Vector2.ZERO
	var t := _pump_t
	return Vector2(smoothstep(.05, float(BOLT[0]), t) - smoothstep(float(BOLT[3]), float(BOLT[4]), t),
		smoothstep(float(BOLT[0]), float(BOLT[1]), t) - smoothstep(float(BOLT[2]), float(BOLT[3]), t))

func _bolt_transform(rest: Transform3D) -> Transform3D:
	var now := _bolt_now()
	return Transform3D(Basis(Vector3.BACK, now.x * BOLT_LIFT) * rest.basis, rest.origin + Vector3(0, 0, now.y * BOLT_TRAVEL))

## Where the right hand is on the long gun: on the grip, or (the sniper rifle) working the bolt.
func _rifle_right_hand() -> Transform3D:
	var grip: Transform3D = _rifle_hands["right"]
	if weapon != "sniper" or _pump_t < 0.0:
		return grip
	var handle: Vector3 = _rifle_at.get("bolt_handle", Vector3.ZERO)
	var moved := _bolt_transform(Transform3D.IDENTITY) * handle
	var on_bolt := Transform3D(Basis(Vector3.BACK, .5), moved - (_rifle_at["grip_r"] as Vector3) + Vector3(.02, -.035, .03)) * grip
	var k := smoothstep(0.0, .14, _pump_t) * (1.0 - smoothstep(float(BOLT[4]) - .03, BOLT_TIME, _pump_t))
	return grip.interpolate_with(on_bolt, k)

## How far back the pump is now (m).
func _pump_back() -> float:
	if _pump_t < 0.0 or weapon != "shotgun":
		return 0.0
	return PUMP_TRAVEL * (smoothstep(float(PUMP[0]), float(PUMP[1]), _pump_t) - smoothstep(float(PUMP[2]), float(PUMP[3]), _pump_t))

## The pump's stroke after a shot (or to chamber the first shell): back, the empty flies out, forward.
func _pump_tick(delta: float) -> void:
	_pump_t += delta
	if weapon == "sniper":
		# The bolt: up, back (the case flies), forward, down.
		if _pump_step == 0 and _pump_t >= .05:
			_pump_step = 1
			_hand_sound("gun_rack", -5.0, 1.25)
		if _pump_step == 1 and _pump_t >= float(BOLT[1]):
			_pump_step = 2
			if _cycle_eject:
				_eject_casing()
			_cycle_eject = false
		if _pump_step == 2 and _pump_t >= float(BOLT[3]):
			_pump_step = 3
			_hand_sound("gun_mag_in", -3.0, .95)
		if _pump_t >= BOLT_TIME:
			_pump_t = -1.0
			_pump_step = 0
		return
	if _pump_step == 0 and _pump_t >= float(PUMP[0]):
		_pump_step = 1
		_hand_sound("gun_rack", -2.0, .72)
	if _pump_step == 1 and _pump_t >= float(PUMP[1]):
		_pump_step = 2
		_eject_casing()
	if _pump_step == 2 and _pump_t >= float(PUMP[2]):
		_pump_step = 3
		_hand_sound("gun_mag_in", -3.0, .8)
	if _pump_t >= PUMP_TIME:
		_pump_t = -1.0
		_pump_step = 0

func _shell_tick(delta: float) -> void:
	_shell_t += delta
	if not _shell_in and _shell_t >= SHELL_TIME * .55:
		_shell_in = true
		mag += 1
		reserve -= 1
		_hand_sound("gun_mag_in", -3.0, 1.35)
		ammo_changed.emit()
		_update_hud()
	if _shell_t >= SHELL_TIME:
		if mag < mag_size() and reserve > 0:
			_shell_t = 0.0
			_shell_in = false
		else:
			_end_shell_reload()

func _end_shell_reload() -> void:
	reloading = false
	_shell_t = -1.0
	if not chambered and mag > 0:
		chambered = true
		mag -= 1
		_pump_t = 0.0
		_pump_step = 0
		_next_shot = _time + PUMP_TIME
	ammo_changed.emit()
	_update_hud()
	reloaded.emit()

## Where the left hand is on the long gun now (in its frame): on the handguard or the pump, or about a reload.
func _rifle_left_hand() -> Transform3D:
	var guard: Transform3D = _rifle_hands["guard"]
	if weapon == "shotgun":
		var on_pump := Transform3D(Basis.IDENTITY, Vector3(0, 0, _pump_back())) * guard
		if _shell_blend <= 0.0:
			return on_pump
		# Down for a shell, up to the loading port, and down again.
		var k := clampf(_shell_t / SHELL_TIME, 0.0, 1.0) if _shell_t >= 0.0 else 1.0
		var up := smoothstep(.12, .5, k) * (1.0 - smoothstep(.68, 1.0, k))
		var loading := (_rifle_hands["low"] as Transform3D).interpolate_with(_rifle_hands["port"], up)
		return on_pump.interpolate_with(loading, _shell_blend)
	if not reloading or not _rifle_hands.has("mag") or _reload_t < 0.0:
		return guard
	var keys := [[.22, "guard"], [.5, "mag"], [RIFLE_RELOAD[0], "mag"], [.92, "low"], [1.14, "low"], [RIFLE_RELOAD[1], "mag"],
		[1.52, "mag"], [1.8, "catch"], [RIFLE_RELOAD[3], "catch"], [2.3, "guard"]]
	var t := _reload_t
	var before: Array = keys[0]
	for key: Array in keys:
		if t < float(key[0]):
			var span := float(key[0]) - float(before[0])
			var k := smoothstep(0.0, 1.0, (t - float(before[0])) / span) if span > 0.0 else 1.0
			return (_rifle_hands[before[1]] as Transform3D).interpolate_with(_rifle_hands[key[1]], clampf(k, 0.0, 1.0))
		before = key
	return guard

## The rifle's moving parts: the bolt snaps back on a shot, the magazine goes with the hand during a reload.
func _pose_rifle(delta: float) -> void:
	if weapon == "shotgun":
		_shell_blend = move_toward(_shell_blend, 1.0 if reloading else 0.0, delta * 5.0)
		var forend := _rifle_parts.get("sg_forend") as Node3D
		if forend != null:
			forend.transform = (_rifle_rest["sg_forend"] as Transform3D).translated(Vector3(0, 0, _pump_back()))
		return
	if weapon == "sniper":
		var handle := _rifle_parts.get("sn_bolt") as Node3D
		if handle != null:
			handle.transform = _bolt_transform(_rifle_rest["sn_bolt"])
		var box := _rifle_parts.get("sn_magazine") as Node3D
		if box != null:
			var box_rest: Transform3D = _rifle_rest["sn_magazine"]
			var out := reloading and _reload_t >= float(RIFLE_RELOAD[0]) and _reload_t < float(RIFLE_RELOAD[1])
			box.transform = _rifle_left_hand() * (_rifle_hands["mag"] as Transform3D).affine_inverse() * box_rest if out else box_rest
		return
	_bolt_t = maxf(0.0, _bolt_t - delta)
	var bolt := _rifle_parts.get("ar15_bolt") as Node3D
	if bolt != null:
		var back := sin(clampf(_bolt_t / .07, 0.0, 1.0) * PI) * .032
		if reloading and _reload_t >= 0.0 and not chambered and _reload_t < float(RIFLE_RELOAD[3]):
			back = .032
		bolt.transform = (_rifle_rest["ar15_bolt"] as Transform3D).translated(Vector3(0, 0, back))
	var magazine := _rifle_parts.get("ar15_magazine") as Node3D
	if magazine != null:
		var rest: Transform3D = _rifle_rest["ar15_magazine"]
		var carried := reloading and weapon == "rifle" and _reload_t >= float(RIFLE_RELOAD[0]) and _reload_t < float(RIFLE_RELOAD[1])
		magazine.transform = _rifle_left_hand() * (_rifle_hands["mag"] as Transform3D).affine_inverse() * rest if carried else rest

func _own_arm_loops() -> void:
	if _arms_anim == null:
		return
	var source := _arms_anim.get_animation_library("")
	var own := AnimationLibrary.new()
	for clip in source.get_animation_list():
		var animation := source.get_animation(clip)
		if clip == "fp_idle":
			animation = animation.duplicate()
			animation.loop_mode = Animation.LOOP_LINEAR
		own.add_animation(clip, animation)
	_arms_anim.remove_animation_library("")
	_arms_anim.add_animation_library("", own)

func _play_arms(clip: String) -> void:
	if _arms_anim == null or not _arms_anim.has_animation(clip):
		return
	_arms_anim.stop()
	_arms_anim.play(clip, .04)
	if clip in ["fp_fire", "fp_dry", "fp_draw"]:
		_arms_anim.queue("fp_idle")

func _set_view(on: bool) -> void:
	_container.visible = on
	if on and player != null:
		_last_heading = Vector2(player.global_rotation.y + player.aim_offset.x, float(player.get("_look_pitch")) + player.aim_offset.y)
		_aim_rate = Vector2.ZERO
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if on:
		_last_view_basis = player.camera.global_basis
		_viewport.scaling_3d_scale = main.get_viewport().scaling_3d_scale

## Where the hands hold the weapon this frame: the stance (ready, sights up, running, tucked against a wall),
## turned to where the muzzle points, plus breathing, the stride, the drag of moving, the weapon's own weight
## against a swing, and the recoil springs. The shoulders stay with the body; the arms reach (arm_ik.gd).
func _update_view(delta: float) -> void:
	if not _container.visible:
		return
	var p: Dictionary = _prof()
	var rifle := weapon != "pistol"
	var speed := delta / (float(p.draw) if _show_target > _show else float(p.holster))
	_show = move_toward(_show, _show_target, speed)
	if _show <= 0.0 and _show_target <= 0.0:
		_set_view(false)
		_bring_up_pending()
		return
	var camera := player.camera
	_view_camera.fov = camera.fov * VIEW_SCALE
	var lens_ratio := tan(deg_to_rad(_view_camera.fov) * .5) / tan(deg_to_rad(camera.fov) * .5)
	if not rifle and not _sight_measured and _show >= 1.0 and not reloading and _glock != null and _arms_anim != null and _arms_anim.current_animation == "fp_idle":
		_measure_sight()
	# Stances.
	var planar := Vector2(player.velocity.x, player.velocity.z).length()
	_keep_up = maxf(0.0, _keep_up - delta)
	var running := planar > InteriorPlayer.WALK_SPEED * 1.25 and not aiming and not reloading and _keep_up <= 0.0
	_tuck_timer -= delta
	if _tuck_timer <= 0.0:
		_tuck_timer = .08
		_near_wall = _wall_ahead()
	var stowed := player.mantling or player.hands_busy
	_stow = lerpf(_stow, 1.0 if stowed else 0.0, 1.0 - exp(-(13.0 if stowed else 6.5) * delta))
	_ads = lerpf(_ads, 1.0 if aiming and not stowed else 0.0, 1.0 - exp(-11.0 * delta))
	_run = lerpf(_run, 1.0 if running else 0.0, 1.0 - exp(-6.5 * delta))
	_tuck = lerpf(_tuck, 1.0 if _near_wall and not aiming else 0.0, 1.0 - exp(-8.0 * delta))
	var at: Vector3 = (p.hip_at as Vector3).lerp(p.ads_at as Vector3, _ads)
	var turn: Vector3 = (p.hip_turn as Vector3).lerp(p.ads_turn as Vector3, _ads)
	# 0.40: the sights on the lens' axis when aiming (the notch and the post one over the other in the middle of the
	# picture), and at the hip the sight line parallel to it: what the weapon points at is where its rounds go.
	var line := _line_in_frame()
	var square := Quaternion(Basis.from_euler(turn) * line, Vector3.FORWARD) if (Basis.from_euler(turn) * line).dot(Vector3.FORWARD) > .5 else Quaternion.IDENTITY
	at.x = lerpf(at.x, .0, _ads)
	at.y = lerpf(at.y, .0, _ads)
	at = at.lerp(p.run_at as Vector3, _run)
	turn = turn.lerp(p.run_turn as Vector3, _run)
	at = at.lerp(p.tuck_at as Vector3, _tuck * (1.0 - _run))
	turn = turn.lerp(p.tuck_turn as Vector3, _tuck * (1.0 - _run))
	# Coming up from the holster / going back down.
	var eased := 1.0 - pow(1.0 - _show, 3.0)
	at += Vector3(.05, -.34, .08) * (1.0 - eased)
	turn += Vector3(-.95, .25, .2) * (1.0 - eased)
	at += Vector3(.04, -.3, .07) * _stow
	turn += Vector3(-.85, .22, .18) * _stow
	# The rifle is rolled over and pulled in while its magazine is changed.
	if rifle and reloading and _reload_t >= 0.0:
		var over := smoothstep(0.0, .3, _reload_t) * (1.0 - smoothstep(2.05, float(RIFLE_RELOAD[4]), _reload_t))
		at += Vector3(.02, .03, -.12) * over
		turn += Vector3(.45, .1, -.65) * over
	if weapon == "shotgun":
		# Rolled over while shells go in; and the pump's stroke drags the muzzle down and round.
		at += Vector3(.015, .02, -.05) * _shell_blend
		turn += Vector3(.3, .08, -.5) * _shell_blend
		var stroke := _pump_back() / PUMP_TRAVEL
		at += Vector3(.0, -.012, .02) * stroke
		turn += Vector3(-.07, .0, .09) * stroke
	if weapon == "sniper" and _pump_t >= 0.0:
		# Working the bolt rocks the rifle on the shoulder.
		var working := _bolt_now()
		at += Vector3(.004, -.006, .012) * working.x + Vector3(.0, .0, .01) * working.y
		turn += Vector3(-.03, .02, .1) * working.x
	# Breathing: slow, never still; steadier with the sights up.
	var motion := player.camera_motion
	# (A hurt or winded body does not hold it still: scripts/body.gd.)
	var steady := lerpf(1.0, .4, _ads) * (1.0 + 1.6 * player.strain)
	_breath += delta
	var t := _breath
	# 0.40: on the sights the eye stays behind the notch: the weapon breathes and walks by turning, not by sliding
	# across the lens (a millimetre beside a notch ten centimetres off the lens is a notch well off the post).
	var slide := 1.0 - .85 * _ads
	at += Vector3(sin(t * 1.07) * .0026, sin(t * 2.14 + .5) * .0034, 0.0) * steady * slide
	# (0.40: the rounds follow this turn now, magnified by the zoomed gun lens: pitch and yaw breathe half as far,
	# the roll, which moves no round, as before.)
	turn += Vector3(sin(t * 1.31) * .0035, sin(t * .93 + 1.1) * .004, sin(t * 1.73) * .009) * steady
	# The stride: the hands carry more of it than the lens does.
	var sway := float(player.get("_sway"))
	var bob := float(player.get("_eye_offset"))
	at += Vector3(-sway * 2.4, bob * 2.1, 0.0) * steady * maxf(motion, .35) * slide
	turn.z += -sway * 5.0 * steady
	# Moving drags the hands a little behind the body.
	var local := player.global_basis.inverse() * player.velocity
	var drift := Vector3(clampf(-local.x * .0055, -.03, .03), clampf(-local.y * .006, -.035, .035), clampf(-local.z * .0045, -.025, .025))
	_drift = _drift.lerp(drift, 1.0 - exp(-6.0 * delta))
	at += _drift * steady * slide
	turn.z += _drift.x * 2.2
	# With "Centred" aim the muzzle still trails a fast turn a little.
	var aim := player.aim_offset
	if not player.free_aim:
		var basis := camera.global_basis
		var swing := (_last_view_basis.inverse() * basis).get_euler()
		_last_view_basis = basis
		_lag = _lag.lerp(Vector2(clampf(swing.y * 2.5, -.06, .06), clampf(swing.x * 2.5, -.05, .05)), 1.0 - exp(-10.0 * delta))
		_lag = _lag.lerp(Vector2.ZERO, 1.0 - exp(-6.0 * delta))
		aim = -_lag
	aim *= lens_ratio
	# The weapon has weight. How fast the muzzle is being swung (the body's turn and the free aim together):
	var heading := Vector2(player.global_rotation.y + player.aim_offset.x, float(player.get("_look_pitch")) + player.aim_offset.y)
	var rate := Vector2(wrapf(heading.x - _last_heading.x, -PI, PI), heading.y - _last_heading.y) / maxf(delta, .0001)
	_last_heading = heading
	_aim_rate = _aim_rate.lerp(rate.limit_length(9.0), 1.0 - exp(-18.0 * delta))
	# ...it hangs back from the swing, banks into it, and carries on a little when the swing stops.
	var inertia := float(p.inertia) * steady
	var want := Vector3(clampf(-_aim_rate.y * inertia, -.1, .1), clampf(-_aim_rate.x * inertia, -.14, .14),
		clampf(_aim_rate.x * float(p.cant), -.28, .28))
	# The springs (recoil in the hands, the shove, the weight), in steps short enough to stay true at any frame rate.
	var omega := float(p.omega)
	var damping := float(p.damping)
	var left := minf(delta, .05)
	while left > 0.0:
		var h := minf(left, .004)
		left -= h
		_kick_velocity += (-_kick * omega * omega - _kick_velocity * 2.0 * damping * omega) * h
		_kick += _kick_velocity * h
		_kick_at_velocity += (-_kick_at * 900.0 - _kick_at_velocity * 30.0) * h
		_kick_at += _kick_at_velocity * h
		_sway_velocity += ((want - _sway) * 169.0 - _sway_velocity * 9.9) * h
		_sway += _sway_velocity * h
	# The lens rolls with the body; the hands only take part of that.
	var counter_roll := -camera.rotation.z * .45
	var dynamic := Basis.from_euler(Vector3(_kick.x + _sway.x, _kick.y + _sway.y, _kick.z + _sway.z + counter_roll))
	var pivot: Vector3 = p.pivot
	# The rear sight's frame in front of the lens: the stance, then recoil and weight about the wrists / the butt,
	# then all of it swung to where the muzzle points.
	var squared := Basis(Quaternion.IDENTITY.slerp(square, (1.0 - _run) * (1.0 - _tuck) * (1.0 - _stow)))
	var sight_frame := Transform3D(squared * Basis.from_euler(turn), at + _kick_at) * Transform3D(dynamic, pivot - dynamic * pivot)
	sight_frame = Transform3D(Basis(Vector3.UP, aim.x) * Basis(Vector3.RIGHT, aim.y), Vector3.ZERO) * sight_frame
	# 0.32: down until the hands are under the frame's edge: at once (a shot's kick is faster than any easing), and slowly back.
	var over_edge := _hands_over_edge(sight_frame, rifle)
	_floor = over_edge if over_edge > _floor else lerpf(_floor, over_edge, 1.0 - exp(-6.0 * delta))
	sight_frame.origin.y -= _floor * (1.0 - _ads)
	# 0.40: the sight line as drawn now (kick, weight, free aim and all), for the next round.
	_view_line = (sight_frame.basis * line).normalized()
	if not rifle and _glock != null and _glock.is_inside_tree():
		# The pistol rides in the arms' clip (it jumps with each shot): its own sights as they are drawn.
		var held := _view_camera.global_transform.affine_inverse() * _glock.global_transform
		var real := (held.basis * (PISTOL_FRONT_SIGHT - PISTOL_REAR_SIGHT)).normalized()
		if real.z < -.5:
			_view_line = real
			# The line the clip really holds it on, in the stance's frame, kept current while it is at rest (not
			# while a shot or a reload moves it): the stance squares that line, not the one measured once.
			if not reloading and _time - _last_shot > .35 and _show >= 1.0 and _sight_measured:
				_sight_line = _sight_line.slerp((sight_frame.basis.inverse() * real).normalized(), .2).normalized()
		# Where its notch is drawn against where the stance put it (a frame late, so a little at a time).
		var miss := held * PISTOL_REAR_SIGHT - (sight_frame.origin - _rear_fix * _ads)
		if miss.length() < .05 and not reloading:
			_rear_fix = _rear_fix.lerp(Vector3(miss.x, miss.y, 0.0), .35).limit_length(.04)
	_view_ratio = lens_ratio
	_view_line_valid = _show >= .9 and _stow < .2
	# The body: the shoulders follow the aim a little and take some of the shove.
	var shoulders: Vector3 = p.shoulders
	var body := Transform3D(Basis.from_euler(Vector3(aim.y * .2, aim.x * .3 + float(p.blade), -camera.rotation.z * .2)),
		shoulders + Vector3(.0, _ads * (.015 - float(p.get("ads_drop", 0.0))), _kick_at.z * float(p.body_shove)) + _drift * .3) * Transform3D(Basis.IDENTITY, -SHOULDER_MID)
	if rifle and _rifle != null:
		_rifle.transform = sight_frame * Transform3D(Basis.IDENTITY, -(_rifle_at["rear_sight"] as Vector3))
		_pose_rifle(delta)
	_finger_poses(delta)
	if _ik != null:
		_rig.transform = body
		var to_skeleton := (body * _skel_to_rig).affine_inverse()
		_ik.pole["R"] = to_skeleton.basis * Vector3(.6, -1.0, .15)
		_ik.pole["L"] = to_skeleton.basis * Vector3(-.6, -1.0, .15)
		if rifle and _rifle != null:
			_ik.delta_pose = Transform3D.IDENTITY
			_ik.socket["R"] = to_skeleton * _rifle.transform * _rifle_right_hand()
			_ik.socket["L"] = to_skeleton * _rifle.transform * _rifle_left_hand()
			_ik.socket_weight["R"] = 1.0
			_ik.socket_weight["L"] = 1.0
		else:
			# The clips hold the pistol in both hands: carry their hand poses to where the pistol is now.
			sight_frame.origin -= _rear_fix * _ads
			_ik.delta_pose = to_skeleton * sight_frame * Transform3D(Basis.IDENTITY, -_sight) * _skel_to_rig
			_ik.socket_weight["R"] = 0.0
			_ik.socket_weight["L"] = 0.0
	else:
		_rig.transform = sight_frame * Transform3D(Basis.IDENTITY, -_sight)
	_move_casings(delta)
	_light_like_the_scene(delta)
	if _report and Engine.get_process_frames() % 30 == 0:
		# Diagnostic (`-- --gun-report`): where the rear sight was asked to be, and where the model's really is.
		var real := Vector3.ZERO
		if rifle and _rifle != null:
			real = _rifle.transform * (_rifle_at["rear_sight"] as Vector3)
		elif _glock != null:
			real = _view_camera.global_transform.affine_inverse() * (_glock.global_transform * PISTOL_REAR_SIGHT)
		print("INTERIOR_GUN_POSE ", weapon, " asked ", sight_frame.origin.snapped(Vector3.ONE * .001), " real ", real.snapped(Vector3.ONE * .001),
			" stretch ", _ik.stretch if _ik != null else {}, " ads ", snappedf(_ads, .01), " tuck ", snappedf(_tuck, .01), " run ", snappedf(_run, .01))
		print("   on screen ", _view_camera.unproject_position(_view_camera.global_transform * real).snapped(Vector2.ONE), " of ", _viewport.size, " fov ", snappedf(_view_camera.fov, .1), " world fov ", snappedf(camera.fov, .1), " cam ", _view_camera.global_transform.origin.snapped(Vector3.ONE * .001), " rig ", _rig.transform.origin.snapped(Vector3.ONE * .001), " keep ", _view_camera.keep_aspect)

## 0.32: how far (m) the weapon has to go down for both hands to be under the lower edge of the picture: the
## highest of the hands' places (HAND_SPOTS), measured against the edge where the lens puts it (the body camera's
## barrel distortion shows less of the bottom in the middle than at the sides).
func _hands_over_edge(sight_frame: Transform3D, long: bool) -> float:
	if _ik == null:
		return 0.0
	var hands: Array[Transform3D] = []
	if long and _rifle != null:
		var gun := sight_frame * Transform3D(Basis.IDENTITY, -(_rifle_at["rear_sight"] as Vector3))
		hands = [gun * _rifle_right_hand(), gun * _rifle_left_hand()]
	else:
		var right_clip: Transform3D = _ik.clip_hand["R"]
		if right_clip == Transform3D.IDENTITY:
			return 0.0
		var carried := sight_frame * Transform3D(Basis.IDENTITY, -_sight) * _skel_to_rig
		var right := carried * right_clip
		hands = [right, right * _ik.left_on_right if _ik.left_on_right_weight > .5 else carried * (_ik.clip_hand["L"] as Transform3D)]
	var tangent := tan(deg_to_rad(_view_camera.fov) * .5)
	var size := Vector2(_viewport.size)
	var aspect := size.x / maxf(size.y, 1.0)
	var bodycam: Variant = main.get("bodycam")
	var k := .34 if bodycam != null and is_instance_valid(bodycam) and bool(bodycam.get("enabled")) else 0.0
	var rim := 1.0 + k * pow(.5 * aspect * .97, 2.0)
	var worst := 0.0
	for index in hands.size():
		var hand := hands[index]
		for spot: Array in (HAND_SPOTS + GUARD_SPOTS if long and index == 1 else HAND_SPOTS):
			var at: Vector3 = hand * (spot[0] as Vector3)
			var depth := maxf(-at.z, .05)
			var across := clampf(at.x / (depth * tangent * aspect), -1.0, 1.0) * .5 * aspect
			var edge := (1.0 + k * (.25 + across * across)) / rim
			worst = maxf(worst, at.y + float(spot[1]) + (edge + CROP_MARGIN) * tangent * depth)
	return maxf(worst + float((_prof() as Dictionary).get("crop", 0.0)), 0.0)

## Something solid within arm's length of the muzzle: the weapon cannot be held out through it.
## (0.37: tested along the real barrel as well as the lens' line: a wall top the lens sees over but the barrel
## would go into tucks it too.)
func _wall_ahead() -> bool:
	var camera := player.camera
	var from := camera.global_position
	var reach := .62 if weapon == "pistol" else .95
	var space := player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from - player.aim_basis().z * reach, 2)
	query.exclude = [player.get_rid()]
	if not space.intersect_ray(query).is_empty():
		return true
	# The barrel at the hip, from the hand to a hand's width past the muzzle.
	var b: Dictionary = BARREL.get(weapon, BARREL.pistol)
	var hip := from + player.aim_basis() * (b.hip as Vector3)
	query = PhysicsRayQueryParameters3D.create(from, hip, 2)
	query.exclude = [player.get_rid()]
	if not space.intersect_ray(query).is_empty():
		return true
	query = PhysicsRayQueryParameters3D.create(hip, hip - player.aim_basis().z * (float(b.length) + .08), 2)
	query.exclude = [player.get_rid()]
	return not space.intersect_ray(query).is_empty()

## The rear sight's place in the rig while the hands hold the idle pose (the stances are built around it).
func _measure_sight() -> void:
	var rear := PISTOL_REAR_SIGHT
	var gun_in_rig := _rig.global_transform.affine_inverse() * _glock.global_transform
	if _ik != null:
		# With the arms reaching, the clip's own pose is what the modifier saw before it moved the hands.
		gun_in_rig = _skel_to_rig * (_ik.clip_hand["R"] as Transform3D) * _grip_local
	_sight = gun_in_rig * rear
	_sight_line = (gun_in_rig.basis * (PISTOL_FRONT_SIGHT - PISTOL_REAR_SIGHT)).normalized()
	_sight_measured = true
	if "--gun-report" in OS.get_cmdline_user_args():
		print("INTERIOR_GUN_SIGHT rear=", _sight, " front=", gun_in_rig * PISTOL_FRONT_SIGHT)

## Dim moon blue outside, warm candlelight in the hut, the room's lamps indoors; never brighter than the scene.
func _light_like_the_scene(delta: float) -> void:
	var p := player.global_position
	var colour := Color(.55, .64, .9)
	var energy := .12
	var ambient := Color(.22, .27, .4)
	var ambient_energy := .1
	var in_hut: bool = story != null and story.get("hut") != null and story.hut.is_inside(p)
	# 0.39: how far inside the room's lamplight the player stands. It falls off over the last metre to the navy door
	# and the first step onto the balcony instead of switching at the door line.
	var indoors := 0.0
	if p.y > -.6:
		indoors = 1.0 if p.x <= .8 else 1.0 - smoothstep(2.1, 3.3, p.z)
	if in_hut:
		colour = Color(1.0, .68, .42)
		energy = .4
		ambient = Color(.36, .24, .15)
		ambient_energy = .16
	else:
		var zone := InteriorFields.zone_weight(p)
		var lamps := not (story != null and bool(story.get("lights_out")))
		if lamps:
			colour = Color(1.0, .74, .48).lerp(colour, zone)
			energy = lerpf(.2, .12, zone)
		if indoors > 0.0:
			colour = colour.lerp(Color(1.0, .88, .72), indoors)
			energy = lerpf(energy, .62, indoors)
			ambient = ambient.lerp(Color(.42, .37, .3), indoors)
			ambient_energy = lerpf(ambient_energy, .22, indoors)
	# 0.12: the flashlight's spill lights the hands and the gun too.
	if story != null and story.get("flashlight") != null and story.flashlight.on:
		colour = colour.lerp(InteriorFlashlight.COLOUR, .6)
		energy += .35
		ambient_energy += .05
	var k := 1.0 - exp(-4.0 * delta)
	_key.light_color = _key.light_color.lerp(colour, k)
	_key.light_energy = lerpf(_key.light_energy, energy * (.7 if mobile else 1.0), k)
	_env.ambient_light_energy = lerpf(_env.ambient_light_energy, ambient_energy, k)
	_env.ambient_light_color = _env.ambient_light_color.lerp(ambient, k)
	# What the weapon reflects is as dim as the place: next to nothing under the moon. The sky's radiance is drawn
	# again when its energy changes, so it changes in steps, not every frame.
	var sheen := clampf(energy * energy * 1.6, .012, .7)
	if _studio != null and absf(sheen - _studio.energy_multiplier) > .18 * maxf(_studio.energy_multiplier, .02):
		_studio.energy_multiplier = lerpf(_studio.energy_multiplier, sheen, .5)
	if _rim != null:
		_rim.light_color = _key.light_color.lerp(Color(.72, .82, 1.0), .35)
		# From the side and ahead, and gone in the dark: under the moon a weapon is a dark shape with an edge to it.
		_rim.light_energy = _key.light_energy * .5 * smoothstep(.1, .5, _key.light_energy)

func _pose_parts(t: float) -> void:
	if _glock == null:
		return
	var root := _glock.global_transform
	for node: Node3D in _parts:
		if _parts[node] == Transform3D.IDENTITY:
			_parts[node] = root.affine_inverse() * node.global_transform
		var rest: Transform3D = _parts[node]
		var offset := Vector3.ZERO
		var shown := true
		if String(node.name).begins_with("magazine"):
			# Down and out of the grip, gone; the new one rises back in.
			var down := Vector3(0, -.95, -.3).normalized()
			if t < RELOAD_MAG_OUT:
				offset = Vector3.ZERO
			elif t < RELOAD_MAG_OUT + .18:
				offset = down * .3 * pow((t - RELOAD_MAG_OUT) / .18, 2.0)
			elif t < RELOAD_MAG_IN - .3:
				shown = false
			elif t < RELOAD_MAG_IN:
				offset = down * .14 * (1.0 - (t - (RELOAD_MAG_IN - .3)) / .3)
		else:
			if t >= RELOAD_RACK and t < RELOAD_RELEASE:
				offset = Vector3(0, 0, -.033) * clampf((t - RELOAD_RACK) / .08, 0.0, 1.0)
		node.visible = shown
		node.global_transform = root * Transform3D(Basis.IDENTITY, offset) * rest

func _restore_parts() -> void:
	if _glock == null:
		return
	var root := _glock.global_transform
	for node: Node3D in _parts:
		node.visible = true
		if _parts[node] != Transform3D.IDENTITY:
			node.global_transform = root * (_parts[node] as Transform3D)

# ---------------------------------------------------------------- HUD

func _build_hud() -> void:
	ammo_label = Label.new()
	ammo_label.name = "AmmoReadout"
	ammo_label.add_theme_font_size_override("font_size", 26)
	ammo_label.add_theme_color_override("font_color", Color(.95, .9, .8))
	ammo_label.add_theme_color_override("font_outline_color", Color(.06, .04, .025, .95))
	ammo_label.add_theme_constant_override("outline_size", 4)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	# Desktop: the bottom-right corner. Mobile: above the right-hand button columns.
	ammo_label.position = Vector2(-190, -62) if not mobile else Vector2(-190, -450)
	ammo_label.size = Vector2(160, 36)
	# 0.46: longer lines (rifle mode, frags, healthkits) grow to the left, not off the right edge of the screen.
	ammo_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ammo_label.visible = false
	main.hud.add_child(ammo_label)

func ammo_text() -> String:
	return "%d / %d" % [loaded(), reserve]

func _update_hud() -> void:
	if ammo_label != null:
		var text := ammo_text()
		if weapon == "rifle" and int(_prof().get("burst", 0)) > 1:
			text += "  BURST"
		elif weapon == "rifle" and bool(_prof().automatic):
			text += "  AUTO" if automatic else "  SEMI"
		elif weapon == "sniper":
			text += "  %dx" % int(scope_zoom)
		var frags: Variant = main.get("grenades") if main != null else null
		if frags != null and is_instance_valid(frags) and int(frags.count) > 0:
			text += "   %d frag" % int(frags.count)
		text += extra_hud
		ammo_label.text = text
		ammo_label.visible = drawn
	if main != null and main.touch != null and main.touch.has_method("set_gun_state"):
		main.touch.set_gun_state(owned or rifle_owned or shotgun_owned or sniper_owned, drawn)

# ---------------------------------------------------------------- textures

## A bullet hole: a dark core with a ragged, lighter chipped rim (or a star of cracks for glass).
func _make_hole_texture(crack: bool) -> ImageTexture:
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 if crack else 7
	var rays: Array[float] = []
	for k in 9:
		rays.append(rng.randf_range(0, TAU))
	for y in size:
		for x in size:
			var d := Vector2(x - size * .5 + .5, y - size * .5 + .5) / (size * .5)
			var r := d.length()
			var a := atan2(d.y, d.x)
			var c := Color(0, 0, 0, 0)
			if crack:
				if r < .1:
					c = Color(.05, .05, .05, .9)
				else:
					for ray in rays:
						var off := absf(wrapf(a - ray, -PI, PI)) * r * size * .5
						if off < 1.1 and r < .95:
							c = Color(.9, .95, 1.0, .75 * (1.0 - r))
					if r > .22 and r < .26:
						c = Color(.9, .95, 1.0, .5)
			else:
				var ragged := .3 + .07 * sin(a * 7.0 + 1.3) + .05 * sin(a * 13.0)
				if r < .16:
					c = Color(.02, .015, .01, 1.0)
				elif r < ragged:
					c = Color(.12, .1, .08, .95)
				elif r < ragged + .32:
					var t := (r - ragged) / .32
					c = Color(.55, .52, .48, (1.0 - t) * .55)
			image.set_pixel(x, y, c)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _flash_texture() -> ImageTexture:
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x - size * .5 + .5, y - size * .5 + .5) / (size * .5)
			var r := d.length()
			var a := atan2(d.y, d.x)
			var star := pow(absf(cos(a * 2.5)), 6.0) * .6
			var v := clampf(1.0 - r / (.35 + star), 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, v * v))
	return ImageTexture.create_from_image(image)

var _smoke_image: ImageTexture

## A soft, uneven puff.
func _smoke_texture() -> ImageTexture:
	if _smoke_image != null:
		return _smoke_image
	var size := 48
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x - size * .5 + .5, y - size * .5 + .5) / (size * .5)
			var r := d.length()
			var a := atan2(d.y, d.x)
			var edge := .78 + .12 * sin(a * 3.0 + 1.0) + .08 * sin(a * 7.0)
			var v := clampf(1.0 - r / edge, 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, v * v * (3.0 - 2.0 * v)))
	image.generate_mipmaps()
	_smoke_image = ImageTexture.create_from_image(image)
	return _smoke_image
