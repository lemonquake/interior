class_name InteriorStranger
extends Node3D
## 0.9: the man in the black hoodie (assets/characters/stranger.glb, built by tools/blender/human/build_human.py
## on the owner's generic_body).
##
## 1. AT_GATE   He stands outside the courtyard gate, both hands on the bars, arms spread, breathing hard,
##              staring up at the house (clip gate_grip).
## 2. SPOTTED   The moment the player has him in view (on screen, not hidden behind a wall, ~0.25 s) he lets
##              go - the gate clanks - turns to the right (north) and runs.
## 3. TO_ROAD   Along the lane and up street B to the foot of utility pole 9, just short of street C and the
##              way out to the rice fields.
## 4. WAITING   He stands there facing you (clip stand_stare).
## 5. FLEEING   Once the player walks past the food cart on the corner of streets A and B (or comes within
##              20 m) he runs through the gap in the barricade and down the middle of the dirt road, then (0.10)
##              turns sharply onto the footpath to the bahay kubo (scripts/hut_house.gd) and runs inside.
## 6. HIDDEN    Past the doorway, out of sight behind the hut's walls, he is gone (hidden, not freed).
## 0.10, driven by scripts/story.gd once the player takes the Glock from the drawer:
## 7. CALLING   He stands in the yard calling the player out (the three dialogue lines).
## 8. AWAITING  He waits for the player to come out of the hut.
## 9. LEADING   He runs along the cleared footpath, road and dike to the scarecrow; if the player falls more
##              than 20 m behind he stops and waits, facing them.
## 10. DIGGING  He crouches and reaches under the scarecrow (clip interact_pickup); at the lowest point the box
##              of rounds (hut_house.gd buried it behind the post) goes into his right hand; he brushes off.
## 11. BRINGING He comes back to the player with the box, walking the last 4 m.
## 12. GIVING   He holds it out (clip hand_over); at the release frame it leaves his hand for the player's
##              (in front of the camera, then down into a pocket): "Received 60 Glock ammo".
## 0.11: the scarecrow stands ~40 m past the hut path on an islet; a dike (scripts/footpath.gd) leads to it.
## 13. LEAVING  After warning the player to go home he follows the dike back to the road and leaves (GONE).
## 0.23 (the walled town, scripts/town_siege.gd) replaces 2-5 with:
## 2. CUTSCENE  The moment the player sees him (or comes within 5 m) the game cuts to a short film
##              (scripts/stranger_cutscene.gd): from behind him at the gate staring up at the house, round to his side
##              as he senses he is watched and turns his head (a LookAtModifier3D on "head"), lets go, backs off a few
##              steps and walks (not runs) away up the lane.
## 3. WALK_AWAY / POSTED  He walks on to the circled spot by pole 9 and stands there.
## 4. AT_HOLE   The instant the courtyard gate is opened he is moved to the broken hole in the sheet-iron wall at
##              the end of street B (the old way to the rice fields), facing the town.
## 5. CRAWLING  Once the player sees him there (or comes close) he turns, crouches (clip crouch_walk) and squeezes out
##              through the hole, stands and runs down the dirt road to the hut (FLEEING, as before): it teaches the
##              player the way out and that crouching (C) gets them through.
## Restart reloads the scene, so the whole sequence plays again. He has no collider: the player can't catch him.
## Without a hut (no fields), FLEEING ends as in 0.9: far out on the road and out of sight he is removed.

enum State { AT_GATE, SPOTTED, TO_ROAD, WAITING, FLEEING, GONE, HIDDEN, CALLING, AWAITING, LEADING, DIGGING, BRINGING, GIVING, LEAVING,
	CUTSCENE, WALK_AWAY, POSTED, AT_HOLE, CRAWLING }

const MODEL := preload("res://assets/characters/stranger.glb")
const CutsceneScript := preload("res://scripts/stranger_cutscene.gd")
const OUTDOOR_LAYER := 2
const GROUND := -2.9
## Outside the gate (the leaves are at x 12.6, meeting at z 4.1); his fists close on the bars 0.4 m ahead.
const GATE_SPOT := Vector3(13.0, GROUND, 4.1)
## The circled spot: by utility pole 9 (x 18.4, z 44) on street B, before street C and the dirt road.
const WAIT_SPOT := Vector3(19.05, GROUND, 45.1)
## food_cart_a on the corner of streets A and B (street_dressing.gd).
const CART := Vector3(19.7, GROUND, 17.0)
## Lane -> street B: south of the gate cart and the oil drum, under the bent sign, round the east side of the
## parked tricycle and the corner cart, west of the second tricycle and drum, past the poles (tests check it).
const ROUTE_TO_ROAD := [Vector3(14.0, GROUND, 4.6), Vector3(16.5, GROUND, 5.5), Vector3(18.9, GROUND, 6.0),
		Vector3(21.5, GROUND, 9.4), Vector3(21.6, GROUND, 14.0), Vector3(21.3, GROUND, 20.5),
		Vector3(19.9, GROUND, 26.0), Vector3(19.9, GROUND, 40.0), Vector3(19.3, GROUND, 43.6), WAIT_SPOT]
## Across street C and through the gap the barricade leaves at street B's north end (x 19.5..22.5, z 54.1).
const ROUTE_TO_FIELDS := [Vector3(20.4, GROUND, 49.0), Vector3(21.0, GROUND, 54.1), Vector3(21.0, GROUND, 58.0)]
const RUN_SPEED := 5.7          # m/s; the player runs 4.7
## Downloaded animation_run.glb, retargeted to this rig. Stance-foot travel
## measures 5.62 m/s; matching playback to that speed keeps his shoes planted.
const RUN_CLIP_SPEED := 5.62
const RUN_STEPS := [6.0 / 30.0, 16.0 / 30.0] # contacts in the authored 19-frame cycle
const ACCELERATION := 9.0
const TURN_RATE := 9.0
const REACTION := .25           # seconds he must be in view before he bolts
const SEE_DISTANCE := 48.0
const CART_PASS := .6           # metres past the cart (northward) that count as passing it
const NEAR_FLEE := 20.0
const ROAD_RUN := 230.0         # metres down the dirt road before he may vanish
## 0.11: the GLB names its clips interact_talk / interact_pickup (0.10 asked for "talk" / "pickup", so he never
## reached under the scarecrow or gestured while calling). Every clip he plays is listed in CLIPS; tests check them.
const LOOPS := ["gate_grip", "stand_stare", "run", "idle", "idle_look", "walk", "hero_run", "hero_walk", "interact_talk", "walk_back",
	"crouch_walk"]
const CLIPS := ["gate_grip", "stand_stare", "run", "walk", "interact_talk", "interact_pickup", "idle_adjust", "hand_over",
	"walk_back", "crouch_walk"]
const WADE_SPEED := 2.0         # m/s through the flooded paddy
const WADE_DEPTH := .62         # feet below the road level while wading (water at GROUND - 0.42)
const FOLLOW_GAP := 20.0        # he waits when the player is further behind than this
const FOLLOW_RESUME := 12.0
## 0.11: interact_pickup at PICKUP_RATE: the box leaves the ground when hand.R is lowest (PICKUP_LOW s into the
## clip, measured from the GLB), and PICKUP_HAND is where that hand is then, in his frame (right, forward) metres.
const PICKUP_RATE := .8
const PICKUP_LOW := .333        # frame 10 of 30; hand.R is then 0.36 m up (a deep crouch, not the ground)
const PICKUP_HAND := Vector2(.108, .025)
const BOX_LIFT := .22           # s for the box to come up out of the mud into his fist
## hand_over (build_human.py): his right hand is at full reach, palm up, here (s); the player takes the box then.
const HAND_OVER_RELEASE := 1.2
const BOX_POCKET_TIME := .35
const WALK_SPEED := 1.45
const WALK_CLIP_SPEED := 1.6
const BRING_WALK := 4.0         # the last metres back to the player are walked, box in hand
const GIVE_DISTANCE := 1.15     # he stops this far from the player to hold the box out
## 0.23 cutscene beats (s from the cut), matching scripts/stranger_cutscene.gd's shots.
const CUT_LOOK := 2.9           # his head turns toward the player
const CUT_LET_GO := 3.7         # hands off the bars, backing off
const CUT_TURN := 5.1           # turns away and walks
const BACK_SPEED := .5          # m/s backing off (walk_back played slow)
const BACK_CLIP_SPEED := 1.2
## crouch_walk is the walk's cycle with the stride x0.72 (build_human.py): 1.15 m/s at rate 1.
const CRAWL_SPEED := .78
const CRAWL_CLIP_SPEED := 1.15
const HOLE_REACTION := .6       # s in view before he goes through
const HOLE_NEAR := 12.0
## Without a box_grip node in the GLB: the box's place in the right fist (hand.R bone space).
const BOX_IN_HAND := Transform3D(Basis.IDENTITY, Vector3(0, .09, .03))

var state := State.AT_GATE
var speed := 0.0
var path: Array[Vector3] = []
var _model: Node3D
var _anim: AnimationPlayer
var _steps: AudioStreamPlayer3D
var _step_streams := {}
var _player: Node3D
var _seen_time := 0.0
var _wait_time := 0.0
var _yaw := -PI * .5
var _run_phase := 0.0
var _step_clip := ""
var _gate: Node
var _gate_rids: Array[RID] = []
var _road_along := 0.0
var _road_start := 0.0
var _hut: InteriorHutHouse
var _wading := false
var _paused_for_player := false
var _scarecrow: Node3D
var _box: Node3D
var _dig_time := 0.0
var _dig_end := 0.0
var _brushed := false
var _give_time := 0.0
var _released := false
var _return_poll := 0.0
var _cut_time := 0.0
var _cutscene: Node
var _walking := false
var _look: LookAtModifier3D
var _look_target: Node3D
var _crawl_turn := 0.0

func _ready() -> void:
	name = "Stranger"
	add_to_group("stranger")
	# The main scene processes always (menus); he must stop with the game.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_model = MODEL.instantiate() as Node3D
	add_child(_model)
	for node in _model.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).layers = OUTDOOR_LAYER
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	# Movement and animation use one clock, including footsteps and pause.
	_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	_own_loops()
	_setup_audio()
	global_position = GATE_SPOT
	_face(_yaw)
	_play("gate_grip", 0.0)
	# Start part-way through the breath so he isn't in step with anything else.
	_anim.seek(randf() * 3.0, true)

## The GLB's animations are shared resources: loop the ones we need on our own copies.
func _own_loops() -> void:
	if _anim == null:
		return
	var source := _anim.get_animation_library("")
	var own := AnimationLibrary.new()
	for clip in source.get_animation_list():
		var animation := source.get_animation(clip)
		if clip in LOOPS:
			animation = animation.duplicate()
			animation.loop_mode = Animation.LOOP_LINEAR
		own.add_animation(clip, animation)
	_anim.remove_animation_library("")
	_anim.add_animation_library("", own)

func _setup_audio() -> void:
	_steps = AudioStreamPlayer3D.new()
	_steps.name = "Footsteps"
	_steps.max_polyphony = 2
	_steps.unit_size = 4.0
	_steps.max_distance = 70.0
	_steps.volume_db = -3.0
	_steps.position.y = .05
	if AudioServer.get_bus_index("Night") >= 0:
		_steps.bus = "Night"
	add_child(_steps)
	for set_name in ["concrete", "grass"]:
		var randomizer := AudioStreamRandomizer.new()
		randomizer.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
		randomizer.random_pitch = 1.08
		randomizer.random_volume_offset_db = 2.0
		for i in 5:
			var stream_path := "res://assets/audio/footsteps/footstep_%s_%03d.ogg" % [set_name, i]
			if ResourceLoader.exists(stream_path):
				randomizer.add_stream(-1, load(stream_path))
		_step_streams[set_name] = randomizer

## A clip he needs is missing from stranger.glb: say so loudly (0.10 fell back silently and nobody noticed).
func _require_clip(clip: String) -> bool:
	if _anim != null and _anim.has_animation(clip):
		return true
	push_error("Stranger: clip '%s' is missing from stranger.glb" % clip)
	return false

func _play(clip: String, blend: float, rate := 1.0) -> void:
	if not _require_clip(clip):
		return
	if _anim.current_animation != clip:
		_anim.play(clip, blend)
	_anim.speed_scale = rate

func _face(yaw: float) -> void:
	_yaw = yaw
	rotation = Vector3(0, yaw, 0)

## The model faces +Z: the yaw that turns it toward `direction`.
static func yaw_toward(direction: Vector3) -> float:
	return atan2(direction.x, direction.z)

func _find_player() -> Node3D:
	if _player == null or not is_instance_valid(_player):
		var scene := get_tree().current_scene
		if scene != null and "player" in scene:
			_player = scene.player
	return _player

func _find_gate() -> void:
	if _gate != null:
		return
	for door in get_tree().get_nodes_in_group("interior_doors"):
		if door is InteriorPushGate and not door.neighborhood_gate:
			_gate = door
			for leaf in door.find_children("*", "CollisionObject3D", true, false):
				_gate_rids.append((leaf as CollisionObject3D).get_rid())
			for leaf in door.get_children():
				if leaf is CollisionObject3D:
					_gate_rids.append((leaf as CollisionObject3D).get_rid())
			break

func _physics_process(delta: float) -> void:
	var player := _find_player()
	if player == null:
		return
	_find_gate()
	match state:
		State.AT_GATE:
			if _sees_me(delta) or player.global_position.distance_to(global_position) < 5.0:
				_start_cutscene()
		State.CUTSCENE:
			_act(delta)
		State.WALK_AWAY:
			if not _gate_opened() and _run_along(delta):
				state = State.POSTED
				speed = 0.0
				_walking = false
				_play("stand_stare", .45)
		State.POSTED:
			_face_player(player, delta, 1.4)
			_gate_opened()
		State.AT_HOLE:
			_face_player(player, delta, 1.2)
			var near := player.global_position.distance_to(global_position) < HOLE_NEAR
			if (_sees_me(delta) and _seen_time >= HOLE_REACTION) or near:
				_start_crawl()
		State.CRAWLING:
			_crawl(delta)
		State.SPOTTED:
			_wait_time -= delta
			if _wait_time <= 0.0:
				state = State.TO_ROAD
		State.TO_ROAD:
			if _run_along(delta):
				state = State.WAITING
				speed = 0.0
				_play("stand_stare", .45)
				_wait_time = 0.0
		State.WAITING:
			_wait_time += delta
			var to_player := player.global_position - global_position
			to_player.y = 0.0
			if to_player.length() > .5:
				_face(lerp_angle(_yaw, yaw_toward(to_player), minf(1.0, delta * 1.6)))
			if _wait_time > .8 and (passed_cart(player.global_position) or to_player.length() < NEAR_FLEE):
				_flee()
		State.FLEEING:
			var arrived := _run_along(delta)
			var far := player.global_position.distance_to(global_position)
			if _hut != null:
				# Into the hut: gone the moment he is through the doorway (or if the player is nowhere near).
				if arrived or (far > 120.0 and not _in_view(false)):
					# Left far behind: he is already inside, where the story expects him.
					global_position = _hut.route_in[-1]
					_hide_in_hut()
				return
			if arrived:
				_road_along = ROAD_RUN + 1.0
			if far > 120.0 or (_road_along - _road_start > ROAD_RUN and not _in_view(false)):
				state = State.GONE
				queue_free()
		State.HIDDEN:
			pass
		State.CALLING:
			_face_player(player, delta, 3.0)
		State.AWAITING:
			_face_player(player, delta, 3.0)
			if _hut != null and not _hut.is_inside(player.global_position) and player.global_position.distance_to(global_position) < 18.0:
				_start_leading()
		State.LEADING:
			var gap := player.global_position.distance_to(global_position)
			if _paused_for_player:
				_face_player(player, delta, 2.0)
				if gap < FOLLOW_RESUME:
					_paused_for_player = false
			elif gap > FOLLOW_GAP and not _wading:
				_paused_for_player = true
				speed = 0.0
				_play("stand_stare", .35)
			elif _run_along(delta):
				_start_digging()
		State.DIGGING:
			_dig(delta)
		State.BRINGING:
			var to_player := player.global_position - global_position
			to_player.y = 0.0
			if to_player.length() < GIVE_DISTANCE + .3 and _handover_clear(player.global_position):
				_start_giving()
			else:
				_return_poll -= delta
				if _return_poll <= 0.0:
					_return_poll = .75
					path = _safe_path_to(player.global_position)
				if _run_along(delta):
					speed = 0.0
					_play("stand_stare", .2)
		State.GIVING:
			_give(player, delta)
		State.LEAVING:
			var done := _run_along(delta)
			var away := player.global_position.distance_to(global_position)
			if (away > 45.0 or done) and not _in_view(false):
				state = State.GONE
				queue_free()

## True once the player is north of the corner cart on street B (or anywhere north of it in town).
static func passed_cart(at: Vector3) -> bool:
	return at.y < -1.0 and at.z > CART.z + CART_PASS and at.x > 9.0

func _bolt() -> void:
	state = State.SPOTTED
	_wait_time = .18
	if _gate != null and _gate.has_method("rattle_from_outside"):
		_gate.rattle_from_outside()
	path.assign(ROUTE_TO_ROAD)
	_play("run", .22, RUN_SPEED / RUN_CLIP_SPEED)
	_run_phase = 0.0

func _flee() -> void:
	state = State.FLEEING
	path.assign(ROUTE_TO_FIELDS.slice(0, 2))
	_hut = get_tree().get_first_node_in_group("hut_house") as InteriorHutHouse
	if _hut != null and not _hut.route_in.is_empty():
		# Down the road to just short of the footpath, then a sharp turn off the road and into the hut.
		path.append_array(road_range(57.0, _hut.road_index - 3))
		path.append_array(_hut.route_in)
	else:
		_hut = null
		path.append_array(road_path())
	if path.size() <= 2:
		path.assign(ROUTE_TO_FIELDS)
	_play("run", .2, RUN_SPEED / RUN_CLIP_SPEED)
	_run_phase = 0.0
	_road_start = 0.0
	_road_along = 0.0

## The middle of the dirt road (the Fields root's "road_samples", about 1 m apart from z 54.5), as
## waypoints every 2 m for the first ROAD_RUN + 60 m.
func road_path() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var fields := get_tree().get_first_node_in_group("fields")
	if fields == null or not fields.has_meta("road_samples"):
		return out
	var samples: PackedVector2Array = fields.get_meta("road_samples")
	var run := 0.0
	for i in range(0, samples.size(), 2):
		if samples[i].y < 57.0:
			continue
		if not out.is_empty():
			run += Vector2(out[-1].x, out[-1].z).distance_to(samples[i])
		out.append(Vector3(samples[i].x, GROUND, samples[i].y))
		if run > ROAD_RUN + 60.0:
			break
	return out

## Road centre waypoints (every 2 samples) from the first sample north of `from_z` (or from `start_index`) to
## sample `to_index`, walking backwards when `to_index` is the smaller.
func road_range(from_z: float, to_index: int, start_index := -1) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var samples := _road_samples()
	if samples.is_empty():
		return out
	var first := start_index
	if first < 0:
		first = 0
		while first < samples.size() - 1 and samples[first].y < from_z:
			first += 1
	first = clampi(first, 0, samples.size() - 1)
	to_index = clampi(to_index, 0, samples.size() - 1)
	var step := 2 if to_index >= first else -2
	var i := first
	while (step > 0 and i <= to_index) or (step < 0 and i >= to_index):
		out.append(Vector3(samples[i].x, GROUND, samples[i].y))
		i += step
	return out

static func nearest_road_index(samples: PackedVector2Array, at: Vector3) -> int:
	var best := 0
	var best_d := INF
	for i in samples.size():
		var d := samples[i].distance_squared_to(Vector2(at.x, at.z))
		if d < best_d:
			best_d = d
			best = i
	return best

func _road_samples() -> PackedVector2Array:
	var fields := get_tree().get_first_node_in_group("fields")
	return fields.get_meta("road_samples") if fields != null and fields.has_meta("road_samples") else PackedVector2Array()

func _face_player(player: Node3D, delta: float, rate: float) -> void:
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() > .3:
		_face(lerp_angle(_yaw, yaw_toward(to_player), minf(1.0, delta * rate)))

# ---------------------------------------------------------------- 0.23: the cutscene, the walk away, the hole

func _start_cutscene() -> void:
	state = State.CUTSCENE
	_cut_time = 0.0
	_seen_time = 0.0
	_setup_look()
	_cutscene = CutsceneScript.new()
	var scene := get_tree().current_scene
	(scene if scene != null else get_parent()).add_child(_cutscene)
	_cutscene.play(self)

## His part of the film, by the clock (see stranger_cutscene.gd for the shots).
func _act(delta: float) -> void:
	var before := _cut_time
	_cut_time += delta
	if before < CUT_LOOK and _cut_time >= CUT_LOOK:
		_set_look(1.0, .6)
	if before < CUT_LET_GO and _cut_time >= CUT_LET_GO:
		if _gate != null and _gate.has_method("rattle_from_outside"):
			_gate.rattle_from_outside()
		_play("walk_back", .3, BACK_SPEED / BACK_CLIP_SPEED)
	if _cut_time >= CUT_LET_GO and _cut_time < CUT_TURN:
		# Backing away from the gate, still facing the house.
		var back := -Vector3(sin(_yaw), 0, cos(_yaw))
		var next := global_position + back * BACK_SPEED * delta
		next.y = _ground_at(next)
		global_position = next
	if before < CUT_TURN and _cut_time >= CUT_TURN:
		_set_look(0.0, .5)
		_walking = true
		path.assign(ROUTE_TO_ROAD)
		speed = .4
	if _cut_time >= CUT_TURN and _run_along(delta):
		speed = 0.0
		_play("stand_stare", .45)

## The film is over (stranger_cutscene.gd calls this): he keeps walking to his spot.
func end_cutscene() -> void:
	_cutscene = null
	_set_look(0.0, .2)
	if state != State.CUTSCENE:
		return
	if _cut_time < CUT_TURN:
		_walking = true
		path.assign(ROUTE_TO_ROAD)
	state = State.WALK_AWAY if not path.is_empty() else State.POSTED
	if state == State.POSTED:
		_play("stand_stare", .45)
	_gate_opened()

func in_cutscene() -> bool:
	return state == State.CUTSCENE

## The courtyard gate has been opened: he is taken straight to the hole in the north wall.
func _gate_opened() -> bool:
	if _gate == null or not _gate.has_method("is_open") or not _gate.is_open():
		return false
	if state in [State.WALK_AWAY, State.POSTED, State.CUTSCENE]:
		to_hole()
		return true
	return false

func to_hole() -> void:
	if is_instance_valid(_cutscene):
		_cutscene.finish()
	state = State.AT_HOLE
	_walking = false
	speed = 0.0
	path.clear()
	_seen_time = 0.0
	global_position = InteriorTownSiege.STRANGER_WAIT
	_face(PI)  # facing the town (-z)
	_play("stand_stare", 0.0)
	_steps.stop()
	reset_physics_interpolation()

func _start_crawl() -> void:
	state = State.CRAWLING
	_crawl_turn = 0.0
	speed = 0.0
	_play("stand_stare", .2)

## Turn to the hole, crouch through it, stand up on the dirt road and run for the hut.
func _crawl(delta: float) -> void:
	if _crawl_turn < .55:
		_crawl_turn += delta
		_face(lerp_angle(_yaw, 0.0, minf(1.0, delta * 7.0)))
		if _crawl_turn >= .55:
			_face(0.0)
			_play("crouch_walk", .3, CRAWL_SPEED / CRAWL_CLIP_SPEED)
		return
	var out := InteriorTownSiege.STRANGER_OUT
	var to := out - global_position
	to.y = 0.0
	if to.length() < .08:
		_flee_from_hole()
		return
	var next := global_position + to.normalized() * minf(to.length(), CRAWL_SPEED * delta)
	next.y = _ground_at(next)
	global_position = next

func _flee_from_hole() -> void:
	state = State.FLEEING
	path.clear()
	_hut = get_tree().get_first_node_in_group("hut_house") as InteriorHutHouse
	if _hut != null and not _hut.route_in.is_empty():
		path.append_array(road_range(57.0, _hut.road_index - 3))
		path.append_array(_hut.route_in)
	else:
		_hut = null
		path.append_array(road_path())
	if path.is_empty():
		path.assign(ROUTE_TO_FIELDS.slice(2))
	speed = 1.5
	_play("run", .35, RUN_SPEED / RUN_CLIP_SPEED)
	_run_phase = 0.0
	_road_start = 0.0
	_road_along = 0.0

## His head can turn toward the player (LookAtModifier3D on the "head" bone); off until the cutscene asks for it.
func _setup_look() -> void:
	if _look != null:
		return
	var found := _model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return
	var skeleton := found[0] as Skeleton3D
	var bone := skeleton.find_bone("head")
	if bone < 0:
		return
	_look_target = Node3D.new()
	_look_target.name = "Look target"
	add_child(_look_target)
	var look := LookAtModifier3D.new()
	look.name = "Head look"
	look.bone_name = "head"
	# Which of the head bone's axes points the way he faces (the rig's rolls are not known here).
	var rest := skeleton.global_basis * skeleton.get_bone_global_rest(bone).basis
	var forward := (_model.global_basis * Vector3.BACK).normalized()
	var axes := [[rest.x, SkeletonModifier3D.BONE_AXIS_PLUS_X], [-rest.x, SkeletonModifier3D.BONE_AXIS_MINUS_X],
		[rest.z, SkeletonModifier3D.BONE_AXIS_PLUS_Z], [-rest.z, SkeletonModifier3D.BONE_AXIS_MINUS_Z]]
	var best := -2.0
	for axis: Array in axes:
		var d := (axis[0] as Vector3).normalized().dot(forward)
		if d > best:
			best = d
			look.forward_axis = axis[1]
	look.primary_rotation_axis = Vector3.AXIS_Y
	look.use_angle_limitation = true
	look.primary_limit_angle = deg_to_rad(140.0)
	look.secondary_limit_angle = deg_to_rad(70.0)
	look.duration = .35
	look.influence = 0.0
	skeleton.add_child(look)
	look.target_node = look.get_path_to(_look_target)
	_look = look

func _set_look(weight: float, seconds: float) -> void:
	if _look == null:
		return
	var tween := create_tween()
	tween.tween_property(_look, "influence", weight, seconds).set_trans(Tween.TRANS_SINE)

func _process(_delta: float) -> void:
	if _look_target != null and _player != null and is_instance_valid(_player):
		var eye: Vector3 = _player.global_position + Vector3.UP * 1.55
		var camera: Variant = _player.get("camera")
		if camera is Camera3D:
			eye = (camera as Camera3D).global_position
		_look_target.global_position = eye

# ---------------------------------------------------------------- 0.10: the hut, the scarecrow

func _hide_in_hut() -> void:
	state = State.HIDDEN
	speed = 0.0
	path.clear()
	visible = false
	_steps.stop()

## The player took the gun: he is in the yard, calling them out.
func call_out(hut: InteriorHutHouse) -> void:
	_hut = hut
	state = State.CALLING
	visible = true
	speed = 0.0
	var spot := hut.call_spot()
	global_position = spot
	spot.y = _ground_at(spot)
	global_position = spot
	_face(yaw_toward(hut.door_point() - spot))
	_play("interact_talk", .2)

## "Follow me": once the player is out of the hut, run to the scarecrow.
func lead_to_scarecrow(hut: InteriorHutHouse) -> void:
	_hut = hut
	state = State.AWAITING
	_play("stand_stare", .35)

func _start_leading() -> void:
	state = State.LEADING
	_paused_for_player = false
	path.assign(_hut.route_out())
	_scarecrow = get_tree().get_first_node_in_group("scarecrow") as Node3D
	var samples := _road_samples()
	var frame := _hut.crow_frame()
	if not frame.is_empty() and not samples.is_empty():
		# 0.11: down the road to the dike, along it onto the islet, round the scarecrow's post to the box behind it.
		path.append_array(road_range(0.0, _hut.crow_index, _hut.road_index))
		for k in 3:
			path.append(_hut.crow_route[k])
		var centre: Vector3 = frame[0]
		var to_road: Vector3 = frame[1]
		var across := Vector3(-to_road.z, 0, to_road.x)
		path.append(centre + across * .72 + to_road * .1)
		path.append(dig_spot())
	elif _scarecrow != null and not samples.is_empty():
		# No dike (an old fields bake): off the road where it is nearest the scarecrow, through the water.
		var crow_index := nearest_road_index(samples, _scarecrow.global_position)
		path.append_array(road_range(0.0, crow_index, _hut.road_index))
		var crow := _scarecrow.global_position
		var road_point := Vector3(samples[crow_index].x, GROUND, samples[crow_index].y)
		var to_road := road_point - crow
		to_road.y = 0.0
		to_road = to_road.normalized()
		var off := Vector3(crow.x, GROUND, crow.z) - road_point
		path.append(road_point + off.normalized() * 2.8)
		path.append(Vector3(crow.x, GROUND, crow.z) + to_road * .7)
	_play("run", .2, RUN_SPEED / RUN_CLIP_SPEED)

## Where he crouches: facing the road over the box, so his right hand comes down on it.
func dig_spot() -> Vector3:
	var frame := _hut.crow_frame() if _hut != null else []
	var box := _hut.box_spot() if _hut != null else Vector3.INF
	if frame.is_empty() or not box.is_finite():
		return global_position
	var forward: Vector3 = frame[1]
	var right := forward.cross(Vector3.UP)
	var at := box - forward * PICKUP_HAND.y - right * PICKUP_HAND.x
	at.y = GROUND
	return at

func _start_digging() -> void:
	state = State.DIGGING
	speed = 0.0
	_dig_time = 0.0
	_brushed = false
	var frame := _hut.crow_frame() if _hut != null else []
	if not frame.is_empty():
		_face(yaw_toward(frame[1]))
	elif _scarecrow != null:
		_face(yaw_toward(_scarecrow.global_position - global_position))
	_freeze_scarecrow(true)
	var length := 2.0
	if _require_clip("interact_pickup"):
		length = _anim.get_animation("interact_pickup").length
		_play("interact_pickup", .25, PICKUP_RATE)
		_anim.seek(0.0, true)
	_dig_end = length / PICKUP_RATE + .2
	_steps.stop()

func _dig(delta: float) -> void:
	_dig_time += delta
	if _box == null and _dig_time >= PICKUP_LOW / PICKUP_RATE:
		_take_box()
	if _dig_time < _dig_end:
		return
	if not _brushed:
		# Up again; he brushes the mud off (one idle_adjust beat).
		_brushed = true
		var beat := 1.6
		if _require_clip("idle_adjust"):
			beat = minf(_anim.get_animation("idle_adjust").length, 2.2)
			_play("idle_adjust", .3)
			_anim.seek(0.0, true)
		_dig_end = _dig_time + beat
		return
	state = State.BRINGING
	_return_poll = 0.0

## Project both people onto the dry route, then follow its bends instead of crossing paddy/edge walls.
func _safe_path_to(target: Vector3) -> Array[Vector3]:
	if _hut == null or _hut.crow_route.is_empty():
		return [target]
	var frame := _hut.crow_frame()
	var centre: Vector3 = frame[0]
	var to_road: Vector3 = frame[1]
	var across := Vector3(-to_road.z, 0, to_road.x)
	var route: Array[Vector3] = [dig_spot(), centre + across * .9 + to_road * .1]
	for k in [2, 1, 0]:
		route.append(_hut.crow_route[k])
	route.append_array(road_range(0.0, _hut.road_index, _hut.crow_index))
	route.append_array(_hut.route_in.slice(0, 3))
	route.append(_hut.call_spot())
	var start := _project_route(route, global_position)
	var goal := _project_route(route, target)
	var result: Array[Vector3] = []
	var first: int = start.index
	var last: int = goal.index
	if first < last:
		for k in range(first + 1, last + 1):
			result.append(route[k])
	elif first > last:
		for k in range(first, last, -1):
			result.append(route[k])
	result.append(goal.point)
	# A player can stand beside the centre line or on either side of the island. Finish the
	# approach on supported ground, going round the post rather than waiting out of reach.
	var finish: Vector3 = goal.point
	var close_to_island := Vector2(target.x-centre.x,target.z-centre.z).length() < InteriorHutHouse.ISLET_TOP
	if close_to_island and Vector2(finish.x-centre.x,finish.z-centre.z).length() < InteriorHutHouse.ISLET_TOP + .2:
		var a := Vector2(finish.x-centre.x,finish.z-centre.z)
		var b := Vector2(target.x-centre.x,target.z-centre.z)
		var near_post := Geometry2D.get_closest_point_to_segment(Vector2.ZERO,a,b).length() < .48
		if near_post and b.length() > .5:
			var angle := a.angle()
			var turn := wrapf(b.angle()-angle,-PI,PI)
			var steps := maxi(1,ceili(absf(turn)/.35))
			for i in steps + 1:
				var at := angle + turn * float(i)/steps
				result.append(centre + Vector3(cos(at),0,sin(at)) * .92)
			finish = result[-1]
	if _supported_link(finish, target):
		result.append(target)
	return result

func _supported_link(from: Vector3, to: Vector3) -> bool:
	var steps := maxi(1,ceili(from.distance_to(to)/.35))
	var space := get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = .25
	capsule.height = 1.65
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 2
	for i in steps + 1:
		var at := from.lerp(to,float(i)/steps)
		var ray := PhysicsRayQueryParameters3D.create(at+Vector3.UP*.8,at+Vector3.DOWN*.5,2)
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or hit.normal.y < .7:
			return false
		query.transform = Transform3D(Basis.IDENTITY,hit.position+Vector3.UP*.86)
		if not space.intersect_shape(query,1).is_empty():
			return false
	return true

func _handover_clear(target: Vector3) -> bool:
	if not is_instance_valid(_scarecrow):
		return true
	var centre := _scarecrow.global_position
	var closest := Geometry2D.get_closest_point_to_segment(Vector2(centre.x, centre.z),
		Vector2(global_position.x, global_position.z), Vector2(target.x, target.z))
	return closest.distance_to(Vector2(centre.x, centre.z)) > .38

func _project_route(route: Array[Vector3], at: Vector3) -> Dictionary:
	var best := INF
	var result := {"index": 0, "point": route[0]}
	for i in route.size() - 1:
		var p := Geometry2D.get_closest_point_to_segment(Vector2(at.x, at.z),
			Vector2(route[i].x, route[i].z), Vector2(route[i + 1].x, route[i + 1].z))
		var distance := p.distance_squared_to(Vector2(at.x, at.z))
		if distance < best:
			best = distance
			result = {"index": i, "point": Vector3(p.x, GROUND, p.y)}
	return result

## The box leaves the mud for his right hand (box_grip: a node on the hand.R bone in stranger.glb).
func _take_box() -> void:
	_box = _hut.ammo_box if _hut != null and is_instance_valid(_hut.ammo_box) else null
	if _box == null:
		_box = InteriorHutHouse.make_ammo_box()
		add_child(_box)
	var grip := _model.find_child("box_grip", true, false) as Node3D
	var offset := Transform3D.IDENTITY
	if grip == null:
		var skeleton := _model.find_child("Skeleton3D", true, false) as Skeleton3D
		var attach := BoneAttachment3D.new()
		attach.name = "BoxHand"
		skeleton.add_child(attach)
		attach.bone_name = "hand.R"
		grip = attach
		offset = BOX_IN_HAND
	# From the mud up into the fist (the clip's hand stops ~0.3 m above the ground).
	_box.reparent(grip, true)
	# 0.59: out of the mud it shines like any pickup: this is the ammunition coming to the player.
	InteriorHutHouse.Shine.apply(_box, true, Vector3(0, .07, 0), .16)
	var tween := create_tween()
	tween.tween_property(_box, "transform", offset, BOX_LIFT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func has_box() -> bool:
	return _box != null and is_instance_valid(_box) and _model.is_ancestor_of(_box)

func _freeze_scarecrow(frozen: bool) -> void:
	var fields := get_tree().get_first_node_in_group("fields")
	if fields != null and "crow_frozen" in fields:
		fields.crow_frozen = frozen

func _start_giving() -> void:
	state = State.GIVING
	speed = 0.0
	path.clear()
	_give_time = 0.0
	_released = false
	if _require_clip("hand_over"):
		_play("hand_over", .25)
		_anim.seek(0.0, true)
	_steps.stop()

func _give(player: Node3D, delta: float) -> void:
	_face_player(player, delta, 4.0)
	_give_time += delta
	var at := _give_time
	if _anim != null and _anim.current_animation == "hand_over":
		at = _anim.current_animation_position
	if not _released and (at >= HAND_OVER_RELEASE or _give_time > HAND_OVER_RELEASE + 1.5):
		_released = true
		_hand_over_box()
	if _released and _give_time > 2.7 and _anim != null and _anim.current_animation != "stand_stare":
		_play("stand_stare", .4)

## His hand is out: the box goes from it into the player's hands (in front of the camera) and down into a pocket;
## then the story counts the rounds ("Received 60 Glock ammo").
func _hand_over_box() -> void:
	var camera := get_viewport().get_camera_3d()
	var story := get_tree().get_first_node_in_group("story")
	if _box != null and is_instance_valid(_box) and camera != null:
		var box := _box
		_box = null
		box.reparent(camera, false)
		box.transform = Transform3D(Basis(Vector3.UP, .4) * Basis(Vector3.RIGHT, .25), Vector3(.03, -.2, -.42))
		var tween := create_tween()
		tween.tween_property(box, "position", Vector3(.12, -.62, -.36), BOX_POCKET_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(box, "rotation:x", .9, BOX_POCKET_TIME)
		tween.tween_callback(func():
			box.queue_free()
			if story != null:
				story.receive_ammo())
		return
	if _box != null and is_instance_valid(_box):
		_box.queue_free()
	_box = null
	if story != null:
		story.receive_ammo()

## After the return-home warning: he uses the dike before running up the road and leaving sight.
func leave() -> void:
	if state == State.GONE:
		return
	state = State.LEAVING
	_freeze_scarecrow(false)
	if _box != null and is_instance_valid(_box):
		_box.queue_free()
	_box = null
	var samples := _road_samples()
	path.clear()
	if not samples.is_empty():
		var here := nearest_road_index(samples, global_position)
		if _hut != null and not _hut.crow_route.is_empty():
			path.append_array(_safe_path_to(_hut.crow_route[0]))
			here = _hut.crow_index
		path.append(Vector3(samples[here].x, GROUND, samples[here].y))
		path.append_array(road_range(0.0, here + 160, here + 2))
	_play("run", .2, RUN_SPEED / RUN_CLIP_SPEED)

## Runs toward the next waypoint; returns true when the last one is reached.
func _run_along(delta: float) -> bool:
	if path.is_empty():
		return true
	var target := path[0]
	var to := target - global_position
	to.y = 0.0
	var arrive := path.size() == 1 and state in [State.TO_ROAD, State.FLEEING, State.LEADING, State.BRINGING, State.WALK_AWAY, State.CUTSCENE]
	# Onto the islet and round the post he slows down.
	if state == State.LEADING and path.size() <= 2 and _hut != null and not _hut.crow_route.is_empty():
		arrive = true
	# Road waypoints are 2 m apart: reach each closely so he keeps to the middle of the road.
	if to.length() < (.25 if arrive else .6 if state in [State.FLEEING, State.LEADING, State.LEAVING] else 1.1):
		path.remove_at(0)
		if path.is_empty():
			return true
		return false
	var want := WADE_SPEED if _wading else (WALK_SPEED if _walking else RUN_SPEED)
	if state == State.BRINGING and _player != null and global_position.distance_to(_player.global_position) < BRING_WALK + GIVE_DISTANCE:
		want = WALK_SPEED
	if arrive:
		want = clampf(to.length() * 2.2, minf(1.2, want), want)
	speed = move_toward(speed, want, ACCELERATION * delta)
	_face(lerp_angle(_yaw, yaw_toward(to), minf(1.0, delta * TURN_RATE)))
	var forward := Vector3(sin(_yaw), 0, cos(_yaw))
	var step := forward * speed * delta
	_road_along += step.length() if state == State.FLEEING else 0.0
	var next := global_position + step
	next.y = _ground_at(next)
	global_position = next
	var walk_clip := "carry_box" if has_box() and _anim != null and _anim.has_animation("carry_box") else "walk"
	_play("run" if speed > 2.4 else walk_clip, .25, maxf(.05, speed / (RUN_CLIP_SPEED if speed > 2.4 else WALK_CLIP_SPEED)))
	_footsteps(delta)
	return false

func _ground_at(at: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * .9, at + Vector3.DOWN * 1.5)
	if _player != null and _player is CollisionObject3D:
		query.exclude = [(_player as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		# Off the road and the yards: wading in the flooded paddy.
		_wading = state in [State.LEADING, State.BRINGING, State.DIGGING]
		return lerpf(global_position.y, GROUND - WADE_DEPTH if _wading else GROUND, .2)
	_wading = false
	var y: float = hit.position.y
	# Kerbs and ruts: ease rather than snap.
	return lerpf(global_position.y, y, .35) if absf(y - global_position.y) < .5 else y

func _footsteps(_delta: float) -> void:
	if _anim == null:
		return
	var clip := String(_anim.current_animation)
	var at := _anim.current_animation_position
	if clip != _step_clip:
		_step_clip = clip
		_run_phase = at
		return
	var before := _run_phase
	_run_phase = at
	if speed < 1.0 or _wading or clip not in ["run", "walk", "carry_box"]:
		return
	var length := _anim.current_animation_length
	var contacts := RUN_STEPS if clip == "run" else [0.0, length * .5]
	for strike in contacts:
		var crossed: bool = (before < strike and at >= strike) if at >= before else (strike > before or strike <= at)
		if crossed:
			var surface := "grass" if global_position.z > 55.0 else "concrete"
			_steps.stream = _step_streams.get(surface)
			_steps.pitch_scale = 1.0 if surface == "concrete" else .9
			_steps.play()

# ---------------------------------------------------------------- being seen

func _sees_me(delta: float) -> bool:
	if _in_view(true):
		_seen_time += delta
	else:
		_seen_time = maxf(0.0, _seen_time - delta * .5)
	return _seen_time >= REACTION

## On screen (well inside the frame when `strict`), close enough, and not behind a wall.
func _in_view(strict: bool) -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var chest := global_position + Vector3.UP * 1.25
	var head := global_position + Vector3.UP * 1.62
	var eye := camera.global_position
	if eye.distance_to(chest) > SEE_DISTANCE or camera.is_position_behind(chest):
		return false
	if not camera.is_position_in_frustum(chest) and not camera.is_position_in_frustum(head):
		return false
	if strict:
		var size := get_viewport().get_visible_rect().size
		var on_screen := camera.unproject_position(chest) / size
		if absf(on_screen.x - .5) > .4 or absf(on_screen.y - .5) > .46:
			return false
	var space := get_world_3d().direct_space_state
	for point in [head, chest, global_position + Vector3.UP * .7]:
		var to: Vector3 = point - eye
		# Stop short of him, so the gate he is holding (and its bars) never counts as a wall.
		var reach := maxf(0.0, to.length() - .75)
		var query := PhysicsRayQueryParameters3D.create(eye, eye + to.normalized() * reach)
		var exclude: Array[RID] = _gate_rids.duplicate()
		if _player is CollisionObject3D:
			exclude.append((_player as CollisionObject3D).get_rid())
		query.exclude = exclude
		if space.intersect_ray(query).is_empty():
			return true
	return false
