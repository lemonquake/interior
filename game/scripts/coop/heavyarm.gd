extends Node
const Shine := preload("res://scripts/pickup_shine.gd")
## 0.53: Heavy-arm, at PILCST's rear gate (co-op stage 15, the field, after the blast).
##
## Out of 208 and over the field, the rear gate is shut: chained and padlocked. Someone sits against it, head down, as
## if waiting. Closer, the squad sees what it is: one of them, grown wrong, the right arm swollen to twice a man's,
## bone through the skin. Ma'am Teves knows him: Mang Dado, who kept that gate and locked it every night at nine; the
## gate's key still hangs on his lanyard. He gets up.
##
## The fight (host; every peer draws it from `mission.flags.boss`):
##   - he walks at whoever is nearest, and swats or slams anyone who gets close;
##   - every few seconds one of three attacks, each wound up for WIND seconds first, with something to see. 0.54:
##     the tells are his old night round. His guard's flashlight is still clipped to the lanyard (heavyarm_body.gd
##     `_torch`), and every peer drives it from his state (`_torch_render`):
##       charge  crouched, the heavy fist cocked back, the flashlight snaps on and hunts whoever he wants: its light
##               lies long on the ground where he will run (`_lane`, the cheap reflector's rings drawn out down the
##               lane). It lags the target and cuts out on a bad contact; for the last second it holds dead still
##               and steady (a click). Then he runs down his own light: anyone in it is thrown and hurt. A fuel drum
##               in the lane goes up on him (that is what really hurts him); a wall stops him dazed. Looking into the
##               beam whites out the body camera (`_glare`).
##       throw   squatting, tearing a slab out of the ground (the light down in the hole): where it and two chunks
##               will land their shadows are already on the ground (`_marks`, "anino": a slab-shaped blot, a pale
##               moonlit rim at the edge of what it will hit, darkening as the throw comes), and stay under each
##               piece until it lands.
##       roar    chest up, breathing in through the guard's whistle (the pea rattles), the flashlight turned
##               straight up into the sky; then the whistle, the guard calling for help, and the roar: a pack comes
##               running from far behind the squad. The dogs on that side go off; one of the survivors' orange
##               spray-painted arrows at the screen's edge points where from while they are on the way.
##   - his health is the gate's chain (`ChainBar`): links rust and snap off from both ends toward the padlock.
##   - rounds barely mark him (heavyarm_body.gd ARMOUR; more while he is dazed); blasts are what hurt him: the fuel
##     drums (BARRELS, the school's gasolina for the generator and the grass cutters, stood along the far end of the
##     field) go up when shot or run into, and grenades. A boss bar shows his health to everyone.
## Dead, he drops the key, shining. Whoever takes it can unlock the gate; it swings open and the way out is as before
## (escape.gd: everyone at the gate, the board).
const Street := preload("res://scripts/coop/street.gd")
const SCHOOL := preload("res://scripts/coop/school.gd")
const BODY := preload("res://scripts/coop/heavyarm_body.gd")
const KIND := 900
const NAME := "HEAVY-ARM"
const SEAT := Vector3(44.0, 0, 597.85)
## Where the fuel drums stand (street-local): in pairs and alone along the far half of the field.
const BARRELS := [Vector3(31.0, 0, 593.6), Vector3(31.8, 0, 594.4), Vector3(52.6, 0, 592.4), Vector3(60.4, 0, 588.0),
	Vector3(20.6, 0, 589.6), Vector3(21.4, 0, 590.4), Vector3(39.0, 0, 587.6), Vector3(10.5, 0, 594.6),
	Vector3(27.0, 0, 575.0), Vector3(48.5, 0, 577.0), Vector3(14.0, 0, 572.0)]
const BARREL_HP := 34.0
## 0.59: 30 % less health than 0.53-0.58 (1680 alone on Normal, was 2400).
const HEALTH_SCALE := .7
const BARREL_REACH := 4.6
const BARREL_DAMAGE := 560.0
const WIND := 2.5
const CHARGE_SPEED := 10.5
## When the slab leaves his hand in heavy_throw (tools/blender/human/heavyarm_clips.py THROW_RELEASE).
const THROW_RELEASE := .52
const FIELD_LO := Vector3(-5.4, -1, 536.0)
const FIELD_HI := Vector3(61.4, 4, 599.2)
## 0.54: the flashlight's tells (tools/ui/heavyarm_tells.py).
const TORCH_LANE := preload("res://assets/coop/heavyarm/torch_lane.png")
const TORCH_COOKIE := preload("res://assets/coop/heavyarm/torch_cookie.png")
const ANINO := preload("res://assets/coop/heavyarm/anino.png")
const ANINO_RIM := preload("res://assets/coop/heavyarm/anino_rim.png")
const BEAM_DUST := preload("res://assets/coop/heavyarm/beam_dust.png")
const GLARE := preload("res://assets/coop/heavyarm/glare.png")
const SPRAY := preload("res://assets/siege/spray_arrow_albedo.png")
const BEAM_SHADER := preload("res://scripts/coop/torch_beam.gdshader")
const TORCH_CLICK := "res://assets/audio/heavyarm/torch_click.wav"
const WHISTLE := "res://assets/audio/heavyarm/whistle_call.wav"
const WHISTLE_IN := "res://assets/audio/heavyarm/whistle_inhale.wav"
const TORCH_COLOUR := Color(1.0, .8, .55)
const TORCH_ANGLE := 9.0
const TORCH_RANGE := 44.0
const LANE_WIDTH := 3.4
const TALK := [
	["{P}", "Wait. There's someone by the gate. Sitting there.", 4.5],
	["{Q}", "That's no survivor. Look at its arm. Look at the size of that arm.", 5.0],
	["Ma'am Teves", "Diyos ko... Mang Dado? That's Mang Dado. He kept this gate. He locked it every night at nine.", 7.0],
	["{P}", "That's not him any more. The others didn't do this. It's changed into something.", 5.5],
	["Ma'am Teves", "The key... the gate's key is on his lanyard. It's still round his neck.", 6.0],
]

var mission
var session
var school
var boss
var _root: Node3D
## Every peer: the drums as built (StaticBody3D or null once gone).
var barrels: Array = []
var _barrel_hp: Array = []
var _seen_barrels := 0
var _hud: CanvasLayer
var _bar_box: Control
var _chain: ChainBar
var _arrow: Control
var _arrow_label: Label
## The flashlight's light on the ground down the charge's lane (a Decal; a flat quad on the Compatibility renderer).
var _lane: Node3D
var _lane_dir := Vector3.ZERO
var _lane_on := 0.0
## The slabs' shadows where they will land (one per landing; `_falls` while they are in the air).
var _marks: Array = []
var _falls := {}
var _spot: SpotLight3D
var _beam: MeshInstance3D
var _beam_mat: ShaderMaterial
var _torch_aim := Vector3.INF
var _torch_level := 0.0
var _flick_wait := 0.0
var _flick_low := false
var _drift := 0.0
var _glare: TextureRect
var _wash: ColorRect
var _glare_seen := 0.0
var _glare_clear := true
var _glare_check := 0.0
var _horde_seen := Vector3.INF
var _dead_at := -1.0
var _state_clock := 0.0
var _held_seen := false
var _rocks := {}
var _key_node: Node3D
var _seen_state := ""
var _seen_rocks := {}
var _clock_offset := 0.0
var _step_wait := 0.0
var _shown := 0.0
## Host.
var clock := 0.0
var state := "none"
var state_time := 0.0
var hp := 0.0
var max_hp := 0.0
var target := 0
var lane_from := Vector3.ZERO
var lane_dir := Vector3.FORWARD
var lane_len := 0.0
var travelled := 0.0
var _hit := {}
var _crash := false
var last_special := ""
var special_wait := 5.0
var melee_wait := 0.0
var roar_wait := 14.0
var talk_i := -1
var talk_wait := 0.0
var spotter := 1
var rocks: Array = []
var _next_rock := 1
var _marks_host: Array = []
var _throw_aim := Vector3.ZERO
var _side_off: Array = []
var _queue: Array = []
var _melee_kind := "boss_sweep"
var _melee_hit := false
var _path := PackedVector3Array()
var _path_wait := 0.0
var horde_at := Vector3.INF
var horde_boss := Vector3.ZERO
var horde_until := 0.0
var _released := false

func setup(owner_mission) -> void:
	mission = owner_mission
	session = mission.session
	school = mission.school
	name = "Heavy-arm"

func w(at: Vector3) -> Vector3: return Street.ORIGIN + at

# ---------------------------------------------------------------- every peer: the drums

func build() -> void:
	if _root != null or school == null: return
	_root = Node3D.new()
	_root.name = "Fuel drums"
	school.roots[12].add_child(_root)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(.42, .07, .05)
	paint.metallic = .45
	paint.roughness = .55
	var band := StandardMaterial3D.new()
	band.albedo_color = Color(.16, .05, .04)
	band.metallic = .5
	band.roughness = .5
	var lid := StandardMaterial3D.new()
	lid.albedo_color = Color(.3, .29, .27)
	lid.metallic = .6
	lid.roughness = .45
	for i in BARRELS.size():
		var at: Vector3 = BARRELS[i]
		var g: Vector3 = mission.ground(w(at))
		var base: Vector3 = (g - Street.ORIGIN) if g.is_finite() else at
		var body := StaticBody3D.new()
		body.name = "Drum %d" % i
		body.collision_layer = 2
		body.collision_mask = 0
		body.position = base + Vector3.UP * .44
		body.rotation.y = float(i) * 1.7
		body.set_meta("zombie", self)
		body.set_meta("barrel", i)
		body.set_meta("bone", "drum")
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = .3
		cyl.height = .88
		shape.shape = cyl
		body.add_child(shape)
		var drum := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = .29
		mesh.bottom_radius = .29
		mesh.height = .88
		mesh.radial_segments = 20
		drum.mesh = mesh
		drum.material_override = paint
		drum.layers = 1 | 2
		body.add_child(drum)
		for y in [-.3, 0.0, .3]:
			var ring := MeshInstance3D.new()
			var ring_mesh := CylinderMesh.new()
			ring_mesh.top_radius = .3
			ring_mesh.bottom_radius = .3
			ring_mesh.height = .03
			ring_mesh.radial_segments = 20
			ring.mesh = ring_mesh
			ring.material_override = band
			ring.position.y = y
			ring.layers = 1 | 2
			body.add_child(ring)
		var top := MeshInstance3D.new()
		var top_mesh := CylinderMesh.new()
		top_mesh.top_radius = .27
		top_mesh.bottom_radius = .27
		top_mesh.height = .01
		top.mesh = top_mesh
		top.material_override = lid
		top.position.y = .445
		top.layers = 1 | 2
		body.add_child(top)
		var word := Label3D.new()
		word.text = "GASOLINA\nPILCST GENSET"
		word.font_size = 30
		word.pixel_size = .0032
		word.modulate = Color(.86, .82, .7)
		word.outline_size = 0
		word.position = Vector3(0, .1, .296)
		word.visibility_range_end = 18.0
		word.layers = 1 | 2
		body.add_child(word)
		var warn := Label3D.new()
		warn.text = "HUWAG MANIGARILYO"
		warn.font_size = 22
		warn.pixel_size = .0032
		warn.modulate = Color(.9, .78, .2)
		warn.position = Vector3(0, -.13, .296)
		warn.visibility_range_end = 14.0
		warn.layers = 1 | 2
		body.add_child(warn)
		_root.add_child(body)
		barrels.append(body)
		_barrel_hp.append(BARREL_HP)

## A round into a drum (from this peer's own gun): the host counts it; enough and it goes up.
func shot(body: Node, _point: Vector3, _dir: Vector3, damage: float, _knock: float, _weapon: String, _tear := -1.0) -> void:
	if not is_instance_valid(body) or not body.has_meta("barrel"): return
	var i := int(body.get_meta("barrel"))
	if multiplayer.is_server(): barrel_hit(1, i, damage)
	else: session.barrel_report.rpc_id(1, i, damage)

func hit_rids() -> Array[RID]: return []

## Host: a drum took `damage` from `id`'s round.
func barrel_hit(id: int, i: int, damage: float) -> void:
	if i < 0 or i >= _barrel_hp.size() or _barrel_gone(i): return
	_barrel_hp[i] = float(_barrel_hp[i]) - clampf(damage, 0.0, 200.0)
	if float(_barrel_hp[i]) <= 0.0: explode(i, id)

func _barrel_gone(i: int) -> bool: return (int(mission.flags.get("drums", 0)) & (1 << i)) != 0

func barrel_at(i: int) -> Vector3:
	var g: Vector3 = mission.ground(w(BARRELS[i]))
	return (g if g.is_finite() else w(BARRELS[i])) + Vector3.UP * .45

## Host: drum `i` goes up (`by` set it off, for the count). Heavy-arm close to it takes the blast, the infected near
## it are thrown, the drums beside it go up a moment later. Every peer sees and hears it (and its own player takes it)
## when the flag reaches it (`render`).
func explode(i: int, by: int) -> void:
	if _barrel_gone(i): return
	mission.flags.drums = int(mission.flags.get("drums", 0)) | (1 << i)
	var at := barrel_at(i)
	mission.threat = 3.0
	mission.nav.forget_box(AABB(at - Vector3(1.0, 1.0, 1.0), Vector3(2.0, 2.4, 2.0)))
	if boss != null and is_instance_valid(boss) and not boss.dead and state != "dead":
		var d: float = boss.chest_at().distance_to(at)
		if d < BARREL_REACH:
			var f := clampf(1.0 - maxf(d - 1.2, 0.0) / (BARREL_REACH - 1.2), .25, 1.0)
			_take(by, BARREL_DAMAGE * f, true)
			if state != "dead":
				_daze(3.2, true)
				mission.say("%s\nIt went up right on him! Again, find another drum!" % _name(by), 5)
	for k in mission.enemies.keys():
		var z = mission.enemies[k]
		if not is_instance_valid(z) or z.dead or z.hp <= 0 or z.has_meta("boss"): continue
		var d: float = z.position.distance_to(at)
		if d > 6.0: continue
		var way: Vector3 = (z.position - at + Vector3.UP * 1.2).normalized()
		var who: int = by if session.team.has(by) else _any_id()
		if who != 0: mission.damage(who, k, "chest", z.position + Vector3.UP, way, lerpf(420.0, 60.0, d / 6.0), lerpf(520.0, 140.0, d / 6.0))
	for j in BARRELS.size():
		if j != i and not _barrel_gone(j) and barrel_at(j).distance_to(at) < 2.6:
			_queue.append([.28 + randf() * .2, j, by])
	print("INTERIOR_COOP_HEAVY drum %d up (by %d)" % [i, by])

## Host: a grenade went off at `at` (mission.boom): the drums close to it go up a moment later.
func near_blast(at: Vector3) -> void:
	for i in BARRELS.size():
		if not _barrel_gone(i) and barrel_at(i).distance_to(at) < 3.0:
			_queue.append([.12 + randf() * .15, i, _any_id()])

func _any_id() -> int:
	for id: int in session.team: return id
	return 0

# ---------------------------------------------------------------- host: him

func _ensure_boss() -> void:
	if boss != null and is_instance_valid(boss): return
	for z in mission.enemies.values():
		if is_instance_valid(z) and z.has_meta("boss"):
			boss = z
			return
	if state != "none": return
	mission.next_id += 1
	boss = mission.make_enemy(mission.next_id, KIND, mission.ground(w(SEAT)))
	if boss == null: return
	boss.rotation.y = 0.0
	boss.asleep = true
	boss.idle_mode = ""
	boss.pose("heavy_sit")
	var humans := 0
	var bots := 0
	for id: int in session.team:
		if session.is_bot(id): bots += 1
		else: humans += 1
	max_hp = clampf(2400.0 + 800.0 * float(maxi(humans - 1, 0)) + 300.0 * float(bots), 2400.0, 5200.0)
	max_hp *= HEALTH_SCALE
	if str(session.mode) == "hard": max_hp *= 1.25
	elif str(session.mode) == "easy": max_hp *= .8
	hp = max_hp
	boss.hp = hp
	state = "sit"
	state_time = 0.0
	print("INTERIOR_COOP_HEAVY sat at the rear gate, hp %.0f" % max_hp)

## Called by escape.gd's tick on the host from the blast on (he is there when the squad looks out of 208).
func tick(delta: float, living: Array) -> void:
	clock += delta
	if _root == null: build()
	_ensure_boss()
	for i in range(_queue.size() - 1, -1, -1):
		_queue[i][0] -= delta
		if _queue[i][0] <= 0.0:
			var q: Array = _queue[i]
			_queue.remove_at(i)
			explode(int(q[1]), int(q[2]))
	_rocks_tick()
	if boss == null or not is_instance_valid(boss) or state == "dead" or living.is_empty():
		_publish()
		return
	state_time += delta
	melee_wait -= delta
	match state:
		"sit": _sit(delta)
		"talk": _talk(delta)
		"rise": _rise(delta)
		"fight": _fight(delta)
		"melee": _melee(delta)
		"wind_charge": _wind_charge(delta)
		"charge": _charge(delta)
		"daze": _dazed(delta)
		"wind_throw": _wind_throw(delta)
		"throw": _throw(delta)
		"wind_roar": _wind_roar(delta)
		"roar": _roar(delta)
	if state != "charge":
		boss.velocity.y = minf(0.0, boss.velocity.y) - 16.0 * delta
		boss.move_and_slide()
	_publish()

func _go(next: String) -> void:
	state = next
	state_time = 0.0
	print("INTERIOR_COOP_HEAVY %s (hp %.0f)" % [next, hp])

func _name(id: int) -> String:
	if not session.team.has(id): return "Ma'am Teves"
	return session.NAMES[int(session.team[id].slot) % session.NAMES.size()]

func _humans() -> Array:
	var out: Array = []
	for id: int in session.team:
		if not session.is_bot(id) and int(session.team[id].hp) > 0: out.append(id)
	return out

func _stand_still() -> void:
	boss.velocity.x = 0.0
	boss.velocity.z = 0.0

func _face(at: Vector3, delta: float, rate := 5.0) -> void:
	var to: Vector3 = at - boss.position
	to.y = 0.0
	if to.length() < .2: return
	boss.rotation.y = lerp_angle(boss.rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-rate * delta))

## Sitting against the gate. Someone near enough to make him out (or a light on him, or a round in him): the talk.
func _sit(_delta: float) -> void:
	boss.pose("heavy_sit")
	_stand_still()
	var space: PhysicsDirectSpaceState3D = mission.get_world_3d().direct_space_state
	var head: Vector3 = boss.position + Vector3.UP * 1.0
	for id in _humans():
		var p: Dictionary = session.team[id]
		var d: float = p.pos.distance_to(boss.position)
		var seen: bool = space.intersect_ray(PhysicsRayQueryParameters3D.create(p.pos + Vector3.UP * 1.5, head, 2)).is_empty()
		if d < 15.0 or (d < 27.0 and seen):
			spotter = id
			talk_i = -1
			talk_wait = .2
			# 0.63 (owner, for frame rate): facing him, the night's old bodies and blood are put away (every peer:
			# mission.gd `clean_before_heavy`).
			mission.flags.heavy_clean = true
			_go("talk")
			print("INTERIOR_COOP_HEAVY spotted by %d at %.1f m" % [id, d])
			return

func _talk(delta: float) -> void:
	boss.pose("heavy_sit")
	_stand_still()
	for id in _humans():
		if session.team[id].pos.distance_to(boss.position) < 8.5:
			_wake_now()
			return
	talk_wait -= delta
	if talk_wait > 0.0: return
	talk_i += 1
	if talk_i >= TALK.size():
		_wake_now()
		return
	var line: Array = TALK[talk_i]
	var who: String = line[0]
	if who == "{P}": who = _name(spotter)
	elif who == "{Q}":
		who = _name(spotter)
		for id: int in session.team:
			if id != spotter and int(session.team[id].hp) > 0:
				who = _name(id)
				break
	mission.say(who + "\n" + str(line[1]), float(line[2]) + .5)
	talk_wait = float(line[2])

func _wake_now() -> void:
	if state != "sit" and state != "talk": return
	boss.asleep = false
	mission.threat = 3.0
	_go("rise")

func _rise(delta: float) -> void:
	_stand_still()
	if state_time < 2.0:
		boss.pose("heavy_rise")
		return
	var id: int = mission.nearest(boss.position)
	if id: _face(session.team[id].pos, delta, 6.0)
	if not _released:
		_released = true
		mission.say("", .1)
	# Up: the first roar (nothing comes to it yet: this one is for them).
	boss.pose("boss_roar")
	if state_time > 3.5:
		special_wait = 3.0
		_go("fight")

## Who he goes for: the nearest on their feet, a person over a squad AI unless the AI is much nearer.
func _pick() -> int:
	var best := 0
	var score := INF
	for id: int in session.team:
		var p: Dictionary = session.team[id]
		if int(p.hp) <= 0: continue
		var d: float = p.pos.distance_to(boss.position) * (1.4 if session.is_bot(id) else 1.0)
		if d < score:
			score = d
			best = id
	return best

func _fight(delta: float) -> void:
	target = _pick()
	if target == 0:
		_stand_still()
		boss.pose("heavy_idle")
		return
	var at: Vector3 = session.team[target].pos
	var d: float = at.distance_to(boss.position)
	special_wait -= delta
	roar_wait -= delta
	if d < 3.0 and melee_wait <= 0.0:
		_melee_kind = "boss_slam" if _melee_kind == "boss_sweep" else "boss_sweep"
		_melee_hit = false
		_go("melee")
		return
	if special_wait <= 0.0 and state_time > .8:
		var choice := _choose(d)
		if choice != "":
			last_special = choice
			_start(choice)
			return
	# On toward them, the heavy walk (faster as he weakens).
	if d < 2.6:
		_stand_still()
		boss.pose("heavy_idle")
		_face(at, delta)
		return
	var pace := 1.75 if hp > max_hp * .4 else 2.3
	var step := _toward(at, delta)
	boss.velocity.x = step.x * pace
	boss.velocity.z = step.z * pace
	boss.pose("heavy_walk")
	_face(boss.position + step, delta, 4.0)

func _toward(at: Vector3, delta: float) -> Vector3:
	var space: PhysicsDirectSpaceState3D = mission.get_world_3d().direct_space_state
	var from: Vector3 = boss.position + Vector3.UP * .6
	if space.intersect_ray(PhysicsRayQueryParameters3D.create(from, at + Vector3.UP * .6, 2)).is_empty():
		_path = PackedVector3Array()
		return Vector3(at.x - boss.position.x, 0, at.z - boss.position.z).normalized()
	_path_wait -= delta
	if _path.is_empty() or _path_wait <= 0.0:
		_path = mission.nav.path(boss.position, at)
		_path_wait = .7
	while not _path.is_empty() and Vector2(_path[0].x - boss.position.x, _path[0].z - boss.position.z).length() < .8:
		_path.remove_at(0)
	var next: Vector3 = _path[0] if not _path.is_empty() else at
	return Vector3(next.x - boss.position.x, 0, next.z - boss.position.z).normalized()

## Which wound-up attack now: a charge across open ground, a throw at range, a roar now and then (not the same
## twice running).
func _choose(d: float) -> String:
	var options: Array = []
	if d > 5.5 and d < 30.0 and _clear_lane(session.team[target].pos): options.append(["charge", 1.3])
	if d > 7.0 and d < 42.0: options.append(["throw", 1.0])
	if roar_wait <= 0.0 and mission._alive_count() < mission.SCHOOL_CEILING - 6: options.append(["roar", 1.1])
	var total := 0.0
	for o: Array in options:
		if o[0] == last_special and options.size() > 1: o[1] = float(o[1]) * .2
		total += float(o[1])
	if total <= 0.0: return ""
	var roll := randf() * total
	for o: Array in options:
		roll -= float(o[1])
		if roll <= 0.0: return o[0]
	return options[-1][0]

func _clear_lane(at: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = mission.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(boss.position + Vector3.UP * 1.0, at + Vector3.UP * 1.0, 2)
	var hit := space.intersect_ray(q)
	return hit.is_empty() or (hit.collider as Node).has_meta("barrel")

func _start(kind: String) -> void:
	match kind:
		"charge":
			lane_from = boss.position
			_aim_lane()
			_go("wind_charge")
		"throw":
			_throw_aim = session.team[target].pos
			_side_off = [Vector3(randf_range(2.5, 4.5), 0, randf_range(-2.0, 2.0)).rotated(Vector3.UP, randf() * TAU),
				Vector3(randf_range(2.5, 4.5), 0, randf_range(-2.0, 2.0)).rotated(Vector3.UP, randf() * TAU)]
			_go("wind_throw")
		"roar":
			_go("wind_roar")

func _aim_lane() -> void:
	if not session.team.has(target): return
	var to: Vector3 = session.team[target].pos - boss.position
	to.y = 0.0
	if to.length() < .5: to = -boss.global_basis.z
	lane_dir = to.normalized()
	lane_len = clampf(to.length() + 7.0, 11.0, 30.0)
	lane_from = boss.position

## The charge wound up: the lane follows the target for the first part, then holds.
func _wind_charge(delta: float) -> void:
	_stand_still()
	boss.pose("heavy_wind")
	if state_time < WIND - 1.0:
		if session.team.has(target) and int(session.team[target].hp) > 0: _aim_lane()
	_face(boss.position + lane_dir, delta, 8.0)
	if state_time >= WIND:
		travelled = 0.0
		_hit.clear()
		_crash = false
		boss.rotation.y = atan2(-lane_dir.x, -lane_dir.z)
		_go("charge")

func _charge(delta: float) -> void:
	boss.pose("heavy_charge")
	var before: Vector3 = boss.position
	boss.velocity = Vector3(lane_dir.x * CHARGE_SPEED, minf(0.0, boss.velocity.y) - 16.0 * delta, lane_dir.z * CHARGE_SPEED)
	boss.move_and_slide()
	var moved := Vector2(boss.position.x - before.x, boss.position.z - before.z).length()
	travelled += moved
	var front: Vector3 = boss.position + lane_dir * .6
	# Anyone in the way: thrown, hurt.
	for id: int in session.team:
		var p: Dictionary = session.team[id]
		if int(p.hp) <= 0 or _hit.has(id): continue
		var off: Vector3 = p.pos - front
		off.y = 0.0
		if off.length() < 1.65:
			_hit[id] = true
			var side := lane_dir.cross(Vector3.UP) * signf(off.dot(lane_dir.cross(Vector3.UP)) + .001)
			_hurt_player(id, 42, lane_dir * 10.0 + side * 5.0 + Vector3.UP * 4.5)
			mission.say("", .1)
	# The infected in the way are thrown aside, dead.
	for k in mission.enemies.keys():
		var z = mission.enemies[k]
		if not is_instance_valid(z) or z.dead or z.hp <= 0 or z.has_meta("boss"): continue
		if Vector2(z.position.x - front.x, z.position.z - front.z).length() < 1.4:
			var who := _any_id()
			if who != 0: mission.damage(who, k, "chest", z.position + Vector3.UP, (lane_dir + Vector3.UP * .6).normalized(), 500.0, 600.0)
	# A drum in the way goes up on him.
	for i in BARRELS.size():
		if _barrel_gone(i): continue
		var b := barrel_at(i)
		if Vector2(b.x - front.x, b.z - front.z).length() < 1.25:
			explode(i, target)
			return
	var out: Vector3 = boss.position - Street.ORIGIN
	var walled: bool = state_time > .3 and moved < CHARGE_SPEED * delta * .35
	if walled or out.x < FIELD_LO.x or out.x > FIELD_HI.x or out.z < FIELD_LO.z or out.z > FIELD_HI.z:
		_crash = true
		_daze(2.6, false)
		print("INTERIOR_COOP_HEAVY crashed")
		return
	if travelled >= lane_len or state_time > 3.2:
		_stand_still()
		special_wait = randf_range(3.0, 5.0)
		melee_wait = .8
		_go("fight")

func _daze(seconds: float, blasted: bool) -> void:
	_stand_still()
	boss.velocity = Vector3.ZERO
	_crash = not blasted
	special_wait = seconds + randf_range(2.0, 3.5)
	_go("daze")
	boss.set_meta("daze_for", seconds)

func _dazed(delta: float) -> void:
	_stand_still()
	boss.pose("stagger_heavy" if state_time < 1.0 else "heavy_daze")
	if state_time >= float(boss.get_meta("daze_for", 2.5)):
		_go("fight")

func _melee(delta: float) -> void:
	_stand_still()
	boss.pose(_melee_kind)
	if state_time < .45 and session.team.has(target): _face(session.team[target].pos, delta, 8.0)
	var at := .55 if _melee_kind == "boss_sweep" else .8
	if not _melee_hit and state_time >= at:
		_melee_hit = true
		var fwd: Vector3 = -boss.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var centre: Vector3 = boss.position + fwd * (1.3 if _melee_kind == "boss_slam" else .9)
		for id: int in session.team:
			var p: Dictionary = session.team[id]
			if int(p.hp) <= 0: continue
			var off: Vector3 = p.pos - centre
			off.y = 0.0
			var reach := 3.2 if _melee_kind == "boss_slam" else 2.9
			if off.length() > reach: continue
			if _melee_kind == "boss_sweep" and fwd.dot((p.pos - boss.position).normalized()) < -.1: continue
			var away := off.normalized() if off.length() > .1 else fwd
			_hurt_player(id, 34 if _melee_kind == "boss_slam" else 28, away * 7.0 + Vector3.UP * 3.0)
		mission.flags.thud = int(mission.flags.get("thud", 0)) + 1
	if state_time >= (1.4 if _melee_kind == "boss_slam" else 1.2):
		melee_wait = randf_range(1.6, 2.4)
		_go("fight")

## The throw wound up: the rings follow the target, then hold for the last half second.
func _wind_throw(delta: float) -> void:
	_stand_still()
	boss.pose("heavy_dig")
	if state_time < WIND - .5 and session.team.has(target) and int(session.team[target].hp) > 0:
		_throw_aim = session.team[target].pos
	_face(_throw_aim, delta, 6.0)
	_marks_host = [[_throw_aim, 3.0], [_throw_aim + _side_off[0], 1.9], [_throw_aim + _side_off[1], 1.9]]
	if state_time >= WIND:
		_go("throw")

func _throw(delta: float) -> void:
	_stand_still()
	boss.pose("heavy_throw")
	_face(_throw_aim, delta, 6.0)
	if not boss.has_meta("thrown") and state_time >= THROW_RELEASE:
		boss.set_meta("thrown", true)
		var hand: Vector3 = boss.position + Vector3.UP * 2.7 - boss.global_basis.z * .4
		for i in _marks_host.size():
			var to: Vector3 = mission.ground(_marks_host[i][0])
			if not to.is_finite(): to = _marks_host[i][0]
			var dur := clampf(hand.distance_to(to) / 17.0, .75, 1.8) + i * .12
			rocks.append([_next_rock, hand, to, clock, dur, 1.0 if i == 0 else .55, float(_marks_host[i][1])])
			_next_rock += 1
		_marks_host.clear()
	if state_time >= 1.2:
		boss.remove_meta("thrown")
		special_wait = randf_range(3.5, 5.5)
		_go("fight")

## Host: the slabs in the air; each lands when its time is up (hurting whoever is under it).
func _rocks_tick() -> void:
	for i in range(rocks.size() - 1, -1, -1):
		var r: Array = rocks[i]
		if clock - float(r[3]) < float(r[4]): continue
		rocks.remove_at(i)
		var at: Vector3 = r[2]
		var reach: float = r[6]
		for id: int in session.team:
			var p: Dictionary = session.team[id]
			if int(p.hp) <= 0: continue
			var off: Vector3 = p.pos - at
			off.y = 0.0
			if off.length() > reach: continue
			var f := 1.0 - off.length() / reach
			_hurt_player(id, int(lerpf(12.0, 46.0 if r[5] > .9 else 26.0, f)), (off.normalized() if off.length() > .1 else Vector3.FORWARD) * (4.0 + 5.0 * f) + Vector3.UP * 3.0)
		for k in mission.enemies.keys():
			var z = mission.enemies[k]
			if not is_instance_valid(z) or z.dead or z.hp <= 0 or z.has_meta("boss"): continue
			if z.position.distance_to(at) < reach:
				var who := _any_id()
				if who != 0: mission.damage(who, k, "chest", z.position + Vector3.UP, (z.position - at + Vector3.UP).normalized(), 300.0, 400.0)
		for j in BARRELS.size():
			if not _barrel_gone(j) and barrel_at(j).distance_to(at) < 1.6: explode(j, target)

func _wind_roar(delta: float) -> void:
	_stand_still()
	boss.pose("heavy_inhale")
	var id: int = mission.nearest(boss.position)
	if id: _face(session.team[id].pos, delta, 3.0)
	if state_time >= WIND - .1: _go("roar")

## The roar: a pack comes from far behind the squad (whichever side of them is away from him), running.
func _roar(_delta: float) -> void:
	_stand_still()
	boss.pose("boss_roar")
	if not boss.has_meta("summoned") and state_time > .35:
		boss.set_meta("summoned", true)
		_summon()
	if state_time >= 1.6:
		boss.remove_meta("summoned")
		roar_wait = randf_range(24.0, 32.0)
		special_wait = randf_range(3.0, 4.5)
		_go("fight")

func _summon() -> void:
	var centre := Vector3.ZERO
	var n := 0
	for id: int in session.team:
		if int(session.team[id].hp) > 0:
			centre += session.team[id].pos
			n += 1
	if n == 0: return
	centre /= float(n)
	var away: Vector3 = centre - boss.position
	away.y = 0.0
	away = away.normalized() if away.length() > .5 else Vector3.BACK
	var from: Vector3 = centre + away * 30.0
	var l: Vector3 = from - Street.ORIGIN
	l.x = clampf(l.x, FIELD_LO.x + 1.0, FIELD_HI.x - 1.0)
	l.z = clampf(l.z, 541.0, FIELD_HI.z - 1.0)
	from = Street.ORIGIN + Vector3(l.x, 0, l.z)
	var count := clampi(4 + 2 * session.team.size(), 5, 11)
	count = mini(count, maxi(mission.SCHOOL_CEILING - mission._alive_count(), 3))
	# (0.66: a few a tick, mission `later`; each tries three spots.)
	for i in count:
		mission.later(func() -> void:
			for t in 3:
				var spot: Vector3 = mission.ground(from + Vector3(randf_range(-5, 5), 0, randf_range(-3, 3)))
				var z = mission.spawn(spot, false, true)
				if z != null:
					z.speed = randf_range(3.0, 3.8)
					return)
	horde_at = from
	horde_boss = boss.position
	horde_until = clock + 10.0
	mission.threat = 3.0
	# 0.54: someone hears them first.
	var who := 0
	for id: int in session.team:
		if int(session.team[id].hp) > 0 and (who == 0 or randf() < .5): who = id
	if who != 0: mission.say("%s\nBehind us! They're coming up behind us!" % _name(who), 4.5)
	print("INTERIOR_COOP_HEAVY roar: %d coming from %s" % [count, str((from - Street.ORIGIN).snapped(Vector3.ONE * .1))])

## Host: `id` struck by him for `amount`, thrown along `push` (their own game moves them).
func _hurt_player(id: int, amount: int, push: Vector3) -> void:
	if not session.team.has(id): return
	if session.harmless or mission.harmless:
		mission.blocked_hits += 1
		return
	var p: Dictionary = session.team[id]
	var hurt := mini(amount, int(p.hp))
	p.hp -= hurt
	p.hurt += hurt
	session.hurt(id, hurt)
	if not session.is_bot(id): session.knocked.rpc(id, push)

## Host: a round from `id` landed on him (mission.damage). Armour by where; more gets through while he is dazed.
func hurt(id: int, bone: String, dealt: float) -> void:
	if state == "dead" or state == "none": return
	var m := float(BODY.ARMOUR.get(bone, .15))
	if state == "daze": m *= 1.8
	_take(id, dealt * m, false)
	if state == "sit" or state == "talk": _wake_now()

## Host: a grenade's blast on him (`amount` as it would be on one of the infected).
func blast(id: int, amount: float) -> void:
	if state == "dead" or state == "none": return
	_take(id, amount * 1.35, true)
	if state == "sit" or state == "talk": _wake_now()
	elif amount > 250.0 and state != "dead" and state != "daze" and state != "charge": _daze(1.3, true)

func _take(id: int, amount: float, _blasted: bool) -> void:
	hp = maxf(0.0, hp - amount)
	boss.hp = maxf(hp, .01)
	if session.team.has(id): session.team[id].hits += 1
	if hp <= 0.0: _die(id)

func _die(id: int) -> void:
	_go("dead")
	boss.hp = 0.0
	if session.team.has(id): session.team[id].kills += 1
	var at: Vector3 = boss.position
	var fwd: Vector3 = -boss.global_basis.z
	var g: Vector3 = mission.ground(at + Vector3(fwd.x, 0, fwd.z).normalized() * .9)
	mission.flags.heavy_key = (g if g.is_finite() else at) + Vector3.UP * .05
	session.fallen.rpc(boss.key, at, KIND, boss.rotation.y, (-fwd + Vector3.UP * .3) * 260.0, "chest")
	mission.say("Ma'am Teves\nIt's down... it's over. The key, there, on the ground. Take it, open the gate!", 8)
	mission.threat = 0.0
	print("INTERIOR_COOP_HEAVY dead (by %d)" % id)

## What every peer draws, in the flags the snapshot carries.
func _publish() -> void:
	var b := {"s": state, "hp": hp, "max": max_hp, "now": clock}
	if state.begins_with("wind_"): b.wk = clampf(state_time / WIND, 0.0, 1.0)
	if state == "wind_charge": b.lane = [lane_from, lane_dir, lane_len, clampf(state_time / WIND, 0.0, 1.0)]
	# 0.54: the run too, so every peer's flashlight pool goes down the lane ahead of him.
	if state == "charge": b.run = [lane_from, lane_dir, lane_len, 1.0]
	if state == "wind_throw": b.marks = _marks_host.duplicate(true)
	if not rocks.is_empty():
		var list: Array = []
		for r: Array in rocks: list.append([r[0], r[1], r[2], r[3], r[4], r[5]])
		b.rocks = list
	if horde_at.is_finite() and clock < horde_until: b.horde = horde_at
	mission.flags.boss = b

# ---------------------------------------------------------------- the key and the gate (host)

func key_here(at: Vector3) -> bool:
	var k = mission.flags.get("heavy_key")
	return k is Vector3 and not bool(mission.flags.get("heavy_key_taken", false)) and at.distance_to(k) < 2.0

func take_key(id: int) -> void:
	mission.flags.heavy_key_taken = true
	mission.flags.key_holder = id
	mission.say("%s\nGot it. The rear gate's key, still on the guard's ring." % _name(id), 5)

func at_gate(at: Vector3) -> bool:
	var g := w(SCHOOL.REAR_GATE)
	return at.distance_to(g) < 3.4 and not bool(mission.flags.get("reargate", false))

func unlock() -> void:
	mission.flags.reargate = true
	var g := w(SCHOOL.REAR_GATE)
	mission.nav.forget_box(AABB(g - Vector3(3.0, .5, 3.0), Vector3(6.0, 3.0, 6.0)))
	mission.say("The padlock opens; the chain rattles down. The gate swings out onto the street.", 6)
	print("INTERIOR_COOP_HEAVY the rear gate open")

## What the HUD's objective says now (mission.objective).
func objective() -> String:
	if bool(mission.flags.get("reargate", false)): return "Through the rear gate. Bring the students."
	var b: Dictionary = mission.flags.get("boss", {})
	var s := str(b.get("s", "none"))
	if s == "dead":
		if bool(mission.flags.get("heavy_key_taken", false)): return "Unlock the rear gate."
		return "Take the rear gate's key from Heavy-arm."
	if s == "none" or s == "sit" or s == "talk": return ""
	return "Heavy-arm. Rounds barely hurt him; blasts do. Bait his charge into the fuel drums."

# ---------------------------------------------------------------- every peer

func render(delta: float) -> void:
	if school == null: return
	if _root == null: build()
	var b: Dictionary = mission.flags.get("boss", {})
	if not multiplayer.is_server() and b.has("now"):
		var off := float(b.now) - Time.get_ticks_msec() * .001
		_clock_offset = off if absf(off - _clock_offset) > 1.0 else lerpf(_clock_offset, off, .1)
	var now := clock if multiplayer.is_server() else Time.get_ticks_msec() * .001 + _clock_offset
	if boss == null or not is_instance_valid(boss):
		boss = null
		for z in mission.enemies.values():
			if is_instance_valid(z) and z.has_meta("boss"): boss = z
		if boss == null:
			for z in mission.corpses:
				if is_instance_valid(z) and z.has_meta("boss"): boss = z
	_drums_render()
	_state_render(str(b.get("s", "none")), delta)
	_lane_render(b, delta)
	_marks_render(b, delta)
	_rocks_render(b, now)
	_torch_render(b, str(b.get("s", "none")), delta)
	_key_render(delta)
	_hud_render(b, delta)

func _drums_render() -> void:
	var gone := int(mission.flags.get("drums", 0))
	if gone == _seen_barrels: return
	for i in BARRELS.size():
		var bit := 1 << i
		if (gone & bit) == 0 or (_seen_barrels & bit) != 0: continue
		var at := barrel_at(i)
		if i < barrels.size() and is_instance_valid(barrels[i]):
			(barrels[i] as Node).queue_free()
		barrels[i] = null
		var nades = session.main.get("grenades")
		if nades != null and is_instance_valid(nades) and nades.has_method("detonate"): nades.detonate(at)
		_burning(at)
	_seen_barrels = gone

## What is left of a drum: a burning puddle for a while.
func _burning(at: Vector3) -> void:
	var fire := OmniLight3D.new()
	fire.light_color = Color(1.0, .5, .2)
	fire.light_energy = 2.4
	fire.omni_range = 7.0
	fire.set_meta("outdoor", true)
	add_child(fire)
	fire.global_position = at + Vector3.UP * .4
	var flames := GPUParticles3D.new()
	flames.amount = 28
	flames.lifetime = .9
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = .45
	pm.direction = Vector3.UP
	pm.spread = 18.0
	pm.initial_velocity_min = .8
	pm.initial_velocity_max = 1.8
	pm.gravity = Vector3(0, .6, 0)
	pm.scale_min = .5
	pm.scale_max = 1.1
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, .75, .35, .9))
	ramp.set_color(1, Color(.5, .12, .03, 0.0))
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	pm.color_ramp = tex
	flames.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(.5, .7)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft()
	quad.material = m
	flames.draw_pass_1 = quad
	add_child(flames)
	flames.global_position = at - Vector3.UP * .35
	var fade := create_tween()
	fade.tween_interval(14.0)
	fade.tween_property(fire, "light_energy", 0.0, 4.0)
	fade.tween_callback(func(): flames.emitting = false)
	fade.tween_interval(1.5)
	fade.tween_callback(fire.queue_free)
	fade.tween_callback(flames.queue_free)

var _dot: Texture2D
func _soft() -> Texture2D:
	if _dot != null: return _dot
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) * clampf(1.0 - d, 0.0, 1.0)))
	_dot = ImageTexture.create_from_image(img)
	return _dot

## Sounds and the lens for what he does, once per change (each peer).
func _state_render(s: String, delta: float) -> void:
	if boss == null: return
	var viewer: Vector3 = session.main.player.global_position if session.main.get("player") != null else boss.global_position
	var d: float = viewer.distance_to(boss.global_position)
	_state_clock += delta
	if s != _seen_state:
		var was := _seen_state
		_seen_state = s
		_state_clock = 0.0
		_held_seen = false
		var chest: Vector3 = boss.chest_at() if boss.has_method("chest_at") else boss.global_position
		match s:
			"rise":
				_voice("growl_%d" % (1 + randi() % 3), .55, 6.0)
				_one(TORCH_CLICK, chest, -2.0, 6.0, .9)
			"fight":
				if was == "rise": _jolt(d, .25)
			"wind_charge":
				_voice("growl_%d" % (1 + randi() % 3), .5, 8.0)
				_one("res://assets/audio/siege/scrape.ogg", boss.global_position, 2.0, 10.0, .7)
				_one(TORCH_CLICK, chest, 2.0, 8.0, 1.0)
			"charge":
				_voice("scream_%d" % (1 + randi() % 3), .62, 10.0)
			"daze":
				_one(TORCH_CLICK, chest, 0.0, 6.0, .8)
				if _crash or was == "charge":
					_one("res://assets/audio/sfx/impactMetal_heavy_001.ogg", boss.global_position, 6.0, 14.0, .6)
					_one("res://assets/audio/siege/bang_c.ogg", boss.global_position, 4.0, 16.0, .8)
					_jolt(d, .35)
				_voice("hurt_%d" % (1 + randi() % 2), .5, 6.0)
			"wind_throw":
				_one("res://assets/audio/siege/rattle.ogg", boss.global_position, 4.0, 12.0, .55)
				_one("res://assets/audio/sfx/hit_stone.ogg", boss.global_position, 6.0, 12.0, .5)
			"throw":
				_voice("attack_%d" % (1 + randi() % 2), .55, 8.0)
			"wind_roar":
				_one("res://assets/audio/sfx/breath_heavy_3.wav", boss.global_position, 4.0, 12.0, .45)
				# 0.54: breathing in through the guard's whistle: the pea rattles.
				_one(WHISTLE_IN, chest, 6.0, 16.0, 1.0)
			"roar":
				# 0.54: the whistle first (a guard calling for help), then the roar under it. Deep: a scream and a
				# growl taken down an octave, with the wall of it under them.
				_one(WHISTLE, chest, 14.0, 40.0, 1.0)
				_voice("scream_%d" % (1 + randi() % 3), .48, 12.0)
				_one("res://assets/audio/siege/groan_b.ogg", boss.global_position, 8.0, 40.0, .55)
				_jolt(d, .5)
			"melee":
				_voice("attack_%d" % (1 + randi() % 2), .6, 6.0)
			"dead":
				_voice("death_%d" % (1 + randi() % 2), .5, 10.0)
	# The heavy walk: his feet heard.
	if s == "fight" and boss.anim_name == "heavy_walk":
		_step_wait -= delta
		if _step_wait <= 0.0:
			_step_wait = .62
			_one("res://assets/audio/sfx/hit_dirt.ogg", boss.global_position, 0.0, 9.0, randf_range(.45, .55))
	elif s == "charge":
		_step_wait -= delta
		if _step_wait <= 0.0:
			_step_wait = .3
			_one("res://assets/audio/sfx/hit_dirt.ogg", boss.global_position, 6.0, 12.0, randf_range(.4, .5))
			_jolt(d, .06)
	var thud := int(mission.flags.get("thud", 0))
	if thud != int(get_meta("thud", 0)):
		set_meta("thud", thud)
		_one("res://assets/audio/siege/bang_d.ogg", boss.global_position, 4.0, 14.0, .6)
		_jolt(d, .18)

func _voice(key: String, pitch: float, volume: float) -> void:
	var s: AudioStream = InteriorZombie._stream(key)
	if s == null or boss == null: return
	var a := AudioStreamPlayer3D.new()
	a.stream = s
	a.pitch_scale = pitch
	a.volume_db = volume
	a.unit_size = 12.0
	a.max_distance = 110.0
	a.bus = "Zombies" if AudioServer.get_bus_index("Zombies") >= 0 else "Master"
	boss.add_child(a)
	a.position = Vector3.UP * 2.0
	a.play()
	a.finished.connect(a.queue_free)

func _one(path: String, at: Vector3, volume: float, unit: float, pitch := 1.0) -> void:
	if not ResourceLoader.exists(path): return
	var a := AudioStreamPlayer3D.new()
	a.stream = load(path)
	a.unit_size = unit
	a.max_distance = unit * 9.0
	a.volume_db = volume
	a.pitch_scale = pitch
	add_child(a)
	a.global_position = at
	a.play()
	a.finished.connect(a.queue_free)

func _jolt(distance: float, amount: float) -> void:
	if session.main.get("player") == null: return
	var k := clampf(1.0 - distance / 35.0, 0.0, 1.0)
	if k > 0.0: session.main.player.jolt(amount * k * .12)

## 0.54: is this renderer able to draw decals (Forward+ / Mobile)? Compatibility gets flat quads instead.
func _decals() -> bool:
	return RenderingServer.get_current_rendering_method() != "gl_compatibility"

## The charge's lane: his flashlight's light lying long down the ground where he will run. It sweeps after the
## target (lagging them, cutting out on the flashlight's bad contact); once he holds (the last second) it is dead
## still and brighter. While he runs it goes with him, what is left of the lane ahead of him.
func _lane_render(b: Dictionary, delta: float) -> void:
	var l = b.get("lane", b.get("run"))
	var want: bool = l != null
	if _lane == null:
		_lane = _make_lane()
	_lane.visible = want
	if not want:
		_lane_on = 0.0
		return
	var from: Vector3 = l[0]
	var dir: Vector3 = l[1]
	var length: float = l[2]
	var k: float = l[3]
	var running: bool = b.has("run")
	if running and boss != null and is_instance_valid(boss):
		var done := clampf((boss.global_position - from).dot(dir), 0.0, length - 1.0)
		from += dir * done
		length -= done
	var held := running or k >= (WIND - 1.0) / WIND
	if _lane_on <= 0.0 or _lane_dir == Vector3.ZERO: _lane_dir = dir
	_lane_dir = _lane_dir.slerp(dir, 1.0 - exp(-(40.0 if held else 4.0) * delta)).normalized()
	_lane_on = move_toward(_lane_on, 1.0, delta * 5.0)
	var face := Basis.looking_at(_lane_dir, Vector3.UP)
	var mid: Vector3 = from + _lane_dir * length * .5
	var power := _torch_power()
	if _lane is Decal:
		var d := _lane as Decal
		d.size = Vector3(LANE_WIDTH, 5.0, length)
		d.global_transform = Transform3D(face, mid + Vector3.UP * 1.2)
		d.emission_energy = (.95 if held else .75) * power * _lane_on
	else:
		_lane.global_transform = Transform3D(Basis(face.x * LANE_WIDTH, face.y, face.z * length), mid + Vector3.UP * .08)
		((_lane as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = Color(1, 1, 1, clampf(power * _lane_on, 0.0, 1.0))

func _make_lane() -> Node3D:
	if _decals():
		var d := Decal.new()
		d.name = "Flashlight on the lane"
		d.texture_emission = TORCH_LANE
		d.emission_energy = 0.0
		d.albedo_mix = 0.0
		d.normal_fade = .4
		d.upper_fade = .2
		d.lower_fade = .35
		add_child(d)
		return d
	var quad := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1, 1)
	quad.mesh = plane
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = TORCH_LANE
	quad.material_override = m
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(quad)
	return quad

## Where the slabs will land: their shadows on the ground before they are even thrown ("anino"): a blot the slab's
## shape turning slowly, a soft penumbra, and a pale moonlit rim at the edge of what each will hit, darker and
## brighter-rimmed as the throw comes, steady for the last half second.
func _marks_render(b: Dictionary, _delta: float) -> void:
	var list: Array = b.get("marks", [])
	var k := float(b.get("wk", 0.0))
	while _marks.size() < list.size():
		_marks.append(_make_shadow())
	for i in _marks.size():
		var m: Node3D = _marks[i]
		m.visible = i < list.size()
		if not m.visible: continue
		var at: Vector3 = list[i][0]
		var g: Vector3 = mission.ground(at)
		_shadow_at(m, g if g.is_finite() else at, float(list[i][1]), lerpf(.5, .95, k), lerpf(.6, 1.5, k), i, k >= (WIND - .5) / WIND)

func _make_shadow() -> Node3D:
	if _decals():
		var d := Decal.new()
		d.name = "Slab's shadow"
		d.texture_albedo = ANINO
		d.texture_emission = ANINO_RIM
		d.albedo_mix = 1.0
		d.emission_energy = 0.0
		d.normal_fade = .3
		d.upper_fade = .2
		d.lower_fade = .35
		add_child(d)
		return d
	var quad := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1, 1)
	quad.mesh = plane
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = ANINO_RIM
	quad.material_override = m
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(quad)
	return quad

## One shadow: `reach` is how far the piece's landing hurts (the rim), `dark` the blot, `rim` the rim's light.
func _shadow_at(node: Node3D, at: Vector3, reach: float, dark: float, rim: float, i: int, held: bool) -> void:
	var t := _now_s()
	var span := reach * 2.0 / .93
	var turn := Basis(Vector3.UP, t * (.12 if held else .45) + float(i) * 2.1)
	if node is Decal:
		var d := node as Decal
		d.size = Vector3(span, 5.0, span)
		d.global_transform = Transform3D(turn, at + Vector3.UP * 1.2)
		d.modulate = Color(1, 1, 1, dark)
		d.emission_energy = rim * (1.7 if held else .82 + .18 * sin(t * 6.5 + float(i)))
	else:
		node.global_transform = Transform3D(turn.scaled(Vector3(span, 1, span)), at + Vector3.UP * .07)
		((node as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = Color(1, 1, 1, clampf(rim, 0.0, 1.0))

func _now_s() -> float: return Time.get_ticks_msec() * .001

## 0.54: his flashlight, on every peer, from his state: where it points, how bright, how steady.
##   sit, talk    on, weak, at the ground before him (a small light by the gate is what makes the squad look);
##   fight        on, low, swinging ahead of his walk;
##   wind_charge  bright, hunting the one he wants: it lags them and cuts out now and then (a bad contact); for the
##                last second it holds dead still and steady (a click), on the lane he will run;
##   charge       full, shaking with his run;   daze  sputtering;
##   wind_throw   down into the hole he tears the slab from;   throw  up after the slab;
##   wind_roar    turned up into the sky, brighter as he breathes in (a beacon); roar  the same, full;
##   dead         wherever his chest fell, fading out after a few last flickers.
func _torch_render(b: Dictionary, s: String, delta: float) -> void:
	if _spot == null: _build_torch()
	var ok: bool = boss != null and is_instance_valid(boss) and boss.is_inside_tree() and boss.get("torch_lens") != null
	if not ok or s == "none":
		_spot.visible = false
		_beam.visible = false
		_glare_render(Vector3.ZERO, Vector3.FORWARD, 0.0, delta)
		return
	var lens: Vector3 = (boss.torch_lens as Node3D).global_position
	var fwd: Vector3 = -boss.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > .01 else Vector3.FORWARD
	var ground: Vector3 = boss.global_position
	var wk := float(b.get("wk", 0.0))
	var level := .3
	var aim: Vector3 = ground + fwd * 7.0
	var rate := 6.0
	var steady := false
	var shake := 0.0
	var beacon := false
	match s:
		"sit", "talk":
			level = .28
			aim = ground + fwd * 2.4
		"rise":
			level = .32
			aim = ground + fwd * 4.0
		"fight", "melee":
			level = .34
			aim = ground + fwd * 8.0 + boss.global_basis.x * sin(_state_clock * 2.1) * 1.3
		"wind_charge", "charge":
			var l = b.get("lane", b.get("run"))
			if l != null:
				var from: Vector3 = l[0]
				aim = from + (_lane_dir if _lane_dir != Vector3.ZERO else (l[1] as Vector3)) * float(l[2]) * .78
			steady = s == "charge" or wk >= (WIND - 1.0) / WIND
			level = 1.0 if steady else lerpf(.6, .82, wk)
			rate = 40.0 if steady else 4.0
			shake = .35 if s == "charge" else 0.0
			if steady and s == "wind_charge" and not _held_seen:
				_held_seen = true
				_one(TORCH_CLICK, lens, 4.0, 10.0, 1.15)
		"daze":
			level = .5
			aim = ground + fwd * 3.0
		"wind_throw":
			level = .6
			aim = ground + fwd * .9
		"throw":
			# After the slab: toward where it is coming down.
			level = .6
			var flying: Array = b.get("rocks", [])
			aim = (flying[0][2] as Vector3) if not flying.is_empty() else ground + fwd * 12.0
		"wind_roar", "roar":
			beacon = true
			steady = true
			level = lerpf(.45, 1.0, wk) if s == "wind_roar" else 1.0
			aim = lens + (Vector3.UP * 3.0 + fwd * .4).normalized() * 40.0
			rate = 2.4 if s == "wind_roar" else 8.0
		"dead":
			if _dead_at < 0.0: _dead_at = _now_s()
			var since := _now_s() - _dead_at
			level = .45 * clampf(1.0 - (since - 6.0) / 2.5, 0.0, 1.0)
			aim = lens + (boss.torch_lens as Node3D).global_basis.z * 8.0
			rate = 30.0
	if s != "dead": _dead_at = -1.0
	# The flicker: steady when he means it; otherwise a bad contact now and then (often while he hunts or reels).
	_flick_wait -= delta
	if _flick_wait <= 0.0:
		var shaky: bool = s in ["wind_charge", "daze", "dead"]
		_flick_low = not steady and randf() < (.45 if s == "daze" else (.24 if shaky else .05))
		_flick_wait = randf_range(.04, .1) if _flick_low else randf_range(.12, .45)
	var flick := .97 + .03 * sin(_now_s() * 37.0) if steady else (.05 if _flick_low else 1.0 - .06 * randf())
	_torch_level = move_toward(_torch_level, level, delta * 3.0)
	var power := _torch_level * flick
	_power = power
	if not _torch_aim.is_finite(): _torch_aim = aim
	_torch_aim = _torch_aim.lerp(aim, 1.0 - exp(-rate * delta))
	var to: Vector3 = _torch_aim - lens
	if shake > 0.0: to += Vector3(randf_range(-1, 1), randf_range(-.3, .3), randf_range(-1, 1)) * shake
	if to.length() < .3: to = fwd
	var dir := to.normalized()
	var up := Vector3.UP if absf(dir.y) < .97 else Vector3.FORWARD
	var face := Basis.looking_at(dir, up)
	var angle := TORCH_ANGLE * (.75 if beacon else 1.0)
	_spot.global_transform = Transform3D(face, lens)
	_spot.spot_angle = angle
	_spot.visible = power > .01
	_spot.light_energy = 15.0 * power
	_spot.shadow_enabled = power > .6 and s in ["wind_charge", "charge"]
	var reach := minf(to.length() + .6, TORCH_RANGE) if dir.y < -.03 else 40.0
	var radius := tan(deg_to_rad(angle)) * reach
	_beam.visible = power > .01
	_beam.global_transform = Transform3D(Basis(face.x * radius, face.z * reach, -face.y * radius), lens + dir * reach * .5)
	_drift += delta * (.35 if beacon else .18)
	_beam_mat.set_shader_parameter("energy", power * (1.0 if beacon else .6))
	_beam_mat.set_shader_parameter("drift", _drift)
	var glass = boss.get("torch_glass")
	if glass is StandardMaterial3D: (glass as StandardMaterial3D).emission_energy_multiplier = power * 7.0
	_glare_render(lens, dir, power, delta)

var _power := 0.0
func _torch_power() -> float: return clampf(_power, 0.0, 1.0)

func _build_torch() -> void:
	_spot = SpotLight3D.new()
	_spot.name = "Heavy-arm's flashlight"
	_spot.light_color = TORCH_COLOUR
	_spot.spot_range = TORCH_RANGE
	_spot.spot_angle = TORCH_ANGLE
	_spot.spot_attenuation = .55
	_spot.spot_angle_attenuation = 1.6
	_spot.light_projector = TORCH_COOKIE
	_spot.light_volumetric_fog_energy = .6
	_spot.light_specular = .3
	_spot.set_meta("outdoor", true)
	_spot.visible = false
	add_child(_spot)
	_beam = MeshInstance3D.new()
	_beam.name = "Beam"
	var cone := CylinderMesh.new()
	cone.top_radius = .02
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 24
	cone.rings = 6
	cone.cap_top = false
	cone.cap_bottom = false
	_beam.mesh = cone
	_beam_mat = ShaderMaterial.new()
	_beam_mat.shader = BEAM_SHADER
	_beam_mat.set_shader_parameter("dust", BEAM_DUST)
	_beam_mat.set_shader_parameter("tint", TORCH_COLOUR)
	_beam.material_override = _beam_mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.extra_cull_margin = 4.0
	_beam.visible = false
	add_child(_beam)

## Looking into his beam: the body camera's lens flares (a hot core and a flat streak where the flashlight is on the
## screen) and the whole frame washes warm, by how squarely it points at the lens.
func _glare_render(lens: Vector3, dir: Vector3, power: float, delta: float) -> void:
	if _glare == null: return
	var cam := get_viewport().get_camera_3d()
	var want := 0.0
	if cam != null and power > .05 and not session.local_menu:
		var to_cam: Vector3 = cam.global_position - lens
		var d := to_cam.length()
		var c := dir.dot(to_cam / maxf(d, .01))
		var edge := cos(deg_to_rad(_spot.spot_angle * 1.9))
		if c > edge and d < TORCH_RANGE and not cam.is_position_behind(lens):
			_glare_check -= delta
			if _glare_check <= 0.0:
				_glare_check = .12
				var q := PhysicsRayQueryParameters3D.create(lens + to_cam / maxf(d, .01) * .5, cam.global_position, 2)
				if boss != null and is_instance_valid(boss) and boss.has_method("hit_rids"): q.exclude = boss.hit_rids()
				_glare_clear = get_viewport().get_world_3d().direct_space_state.intersect_ray(q).is_empty()
			if _glare_clear:
				want = smoothstep(edge, cos(deg_to_rad(_spot.spot_angle * .45)), c) * power * clampf(1.35 - d / TORCH_RANGE, 0.0, 1.0)
			_glare.position = cam.unproject_position(lens) - _glare.size * .5
	_glare_seen = move_toward(_glare_seen, want, delta * 7.0)
	_glare.visible = _glare_seen > .01
	_glare.modulate.a = clampf(_glare_seen * 1.3, 0.0, 1.0)
	_glare.scale = Vector2.ONE * (.5 + .9 * _glare_seen)
	_wash.color.a = .2 * _glare_seen

## The slabs in flight (each peer from the host's list: where from, where to, when, how long), and where they land.
func _rocks_render(b: Dictionary, now: float) -> void:
	var list: Array = b.get("rocks", [])
	var live := {}
	for r: Array in list:
		var id := int(r[0])
		live[id] = true
		if _seen_rocks.has(id): continue
		_seen_rocks[id] = true
		var node := MeshInstance3D.new()
		var box := BoxMesh.new()
		var size: float = r[5]
		box.size = Vector3(.95, .32, .7) * size
		node.mesh = box
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(.5, .49, .45)
		m.roughness = .95
		node.material_override = m
		node.layers = 1 | 2
		add_child(node)
		# 0.54: its shadow stays on the ground where it will come down, blacker the nearer it is.
		var shade := _make_shadow()
		_rocks[id] = [node, r[1], r[2], float(r[3]), float(r[4]), Vector3(randf_range(-6, 6), randf_range(-4, 4), randf_range(-6, 6)), shade, 3.0 if size > .9 else 1.9]
	for id: int in _rocks.keys():
		var e: Array = _rocks[id]
		var node: MeshInstance3D = e[0]
		var from: Vector3 = e[1]
		var to: Vector3 = e[2]
		var t := clampf((now - float(e[3])) / float(e[4]), 0.0, 1.0)
		if t >= 1.0 or (not live.has(id) and t > .5):
			_rocks.erase(id)
			if is_instance_valid(e[6]): (e[6] as Node).queue_free()
			if is_instance_valid(node):
				_land(to)
				node.queue_free()
			continue
		var arc := 3.5 + from.distance_to(to) * .14
		node.global_position = from.lerp(to, t) + Vector3.UP * (4.0 * arc * t * (1.0 - t))
		node.rotation = (e[5] as Vector3) * t
		if is_instance_valid(e[6]): _shadow_at(e[6], to, float(e[7]), lerpf(.82, 1.0, t), 1.6 + t, id, true)

func _land(at: Vector3) -> void:
	_one("res://assets/audio/siege/bang_a.ogg", at, 4.0, 14.0, .7)
	_one("res://assets/audio/sfx/hit_stone.ogg", at, 6.0, 10.0, .6)
	var viewer: Vector3 = session.main.player.global_position if session.main.get("player") != null else at
	_jolt(viewer.distance_to(at), .3)
	var dust := CPUParticles3D.new()
	dust.one_shot = true
	dust.amount = 26
	dust.lifetime = 1.4
	dust.explosiveness = .95
	dust.direction = Vector3.UP
	dust.spread = 70.0
	dust.initial_velocity_min = 2.0
	dust.initial_velocity_max = 6.0
	dust.gravity = Vector3(0, -6, 0)
	dust.scale_amount_min = .3
	dust.scale_amount_max = .8
	dust.color = Color(.42, .39, .34, .8)
	var quad := QuadMesh.new()
	quad.size = Vector2(.4, .4)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft()
	quad.material = m
	dust.mesh = quad
	add_child(dust)
	dust.global_position = at + Vector3.UP * .2
	dust.emitting = true
	get_tree().create_timer(2.0, false).timeout.connect(dust.queue_free)

## The key where he fell: turning slowly, shining, sparkling, until someone takes it.
func _key_render(delta: float) -> void:
	var k = mission.flags.get("heavy_key")
	var want: bool = k is Vector3 and not bool(mission.flags.get("heavy_key_taken", false))
	if want and _key_node == null:
		_key_node = Node3D.new()
		_key_node.name = "Rear gate key"
		add_child(_key_node)
		var spin := Node3D.new()
		spin.name = "Spin"
		_key_node.add_child(spin)
		BODY.key_mesh(spin, 3.2)
		for c in spin.get_children():
			if c is MeshInstance3D:
				var m := ((c as MeshInstance3D).material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
				m.emission_enabled = true
				m.emission = Color(1.0, .78, .35)
				m.emission_energy_multiplier = 1.6
				(c as MeshInstance3D).material_override = m
				(c as MeshInstance3D).layers = 1 | 2
		Shine.apply(spin)
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, .8, .45)
		glow.light_energy = 1.6
		glow.omni_range = 3.2
		glow.set_meta("outdoor", true)
		glow.position = Vector3.UP * .35
		_key_node.add_child(glow)
		var sparks := CPUParticles3D.new()
		sparks.amount = 22
		sparks.lifetime = 1.3
		sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		sparks.emission_sphere_radius = .3
		sparks.direction = Vector3.UP
		sparks.spread = 180.0
		sparks.initial_velocity_min = .05
		sparks.initial_velocity_max = .3
		sparks.gravity = Vector3(0, .15, 0)
		sparks.scale_amount_min = .4
		sparks.scale_amount_max = 1.0
		var curve := Curve.new()
		curve.add_point(Vector2(0, 0))
		curve.add_point(Vector2(.25, 1))
		curve.add_point(Vector2(1, 0))
		sparks.scale_amount_curve = curve
		sparks.color = Color(1.0, .88, .55)
		var quad := QuadMesh.new()
		quad.size = Vector2(.07, .07)
		var m2 := StandardMaterial3D.new()
		m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m2.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m2.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m2.vertex_color_use_as_albedo = true
		m2.albedo_texture = _star()
		quad.material = m2
		sparks.mesh = quad
		sparks.position = Vector3.UP * .35
		_key_node.add_child(sparks)
		_key_node.global_position = k
		_one("res://assets/audio/sfx/key_pickup.ogg", k, -2.0, 5.0, 1.2)
	if not want and _key_node != null:
		_key_node.queue_free()
		_key_node = null
		if bool(mission.flags.get("heavy_key_taken", false)):
			_one("res://assets/audio/sfx/key_pickup.ogg", k if k is Vector3 else Vector3.ZERO, 0.0, 5.0, 1.0)
	if _key_node != null:
		var spin := _key_node.get_node("Spin") as Node3D
		spin.rotation.y += delta * 1.6
		spin.position.y = .35 + .06 * sin(Time.get_ticks_msec() * .003)

var _star_tex: Texture2D
func _star() -> Texture2D:
	if _star_tex != null: return _star_tex
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var dx := absf(x - 15.5) / 15.5
			var dy := absf(y - 15.5) / 15.5
			var cross := maxf(clampf(1.0 - dx * 6.0, 0, 1) * clampf(1.0 - dy, 0, 1), clampf(1.0 - dy * 6.0, 0, 1) * clampf(1.0 - dx, 0, 1))
			var core := clampf(1.0 - Vector2(dx, dy).length() * 2.2, 0, 1)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(cross + core, 0, 1)))
	_star_tex = ImageTexture.create_from_image(img)
	return _star_tex

## The boss bar and the pack's arrow, on every peer. 0.54: his health is the rear gate's chain (`ChainBar`), his name
## over it in the story's serif and who he was under it; the arrow toward a pack he has called is one of the
## survivors' orange spray-painted arrows from the town; the dogs on that side go off as the pack comes through.
func _hud_render(b: Dictionary, delta: float) -> void:
	if _hud == null: _build_hud()
	var s := str(b.get("s", "none"))
	var fighting := s != "none" and s != "sit" and s != "talk"
	_shown = move_toward(_shown, 1.0 if fighting and s != "dead" else 0.0, delta * (2.0 if s != "dead" else .35))
	_bar_box.visible = _shown > .01 and not session.local_menu
	_bar_box.modulate.a = _shown
	_chain.k = clampf(float(b.get("hp", 0.0)) / maxf(float(b.get("max", 1.0)), 1.0), 0.0, 1.0)
	_chain.dead = s == "dead"
	# The pack: an arrow round the middle of the screen toward where it comes from.
	var at = b.get("horde")
	if at is Vector3 and not (at as Vector3).is_equal_approx(_horde_seen):
		_horde_seen = at
		for i in 4:
			var spot: Vector3 = (at as Vector3) + Vector3(randf_range(-9, 9), 0, randf_range(-6, 6))
			var bark := "res://assets/audio/night/dog_bark_%s.ogg" % ["a", "b", "c", "d", "e"][randi() % 5]
			get_tree().create_timer(.25 + i * .55 + randf() * .3, false).timeout.connect(_one.bind(bark, spot, 8.0, 18.0, randf_range(.92, 1.06)))
	var cam := get_viewport().get_camera_3d()
	_arrow.visible = at is Vector3 and cam != null and not session.local_menu
	if not _arrow.visible:
		_arrow.set_meta("in", 0.0)
		return
	var to: Vector3 = (at as Vector3) - cam.global_position
	var local := cam.global_basis.inverse() * to
	var angle := atan2(local.x, -local.z)
	var vp := get_viewport().get_visible_rect().size
	_arrow.position = vp * .5 + Vector2(sin(angle) * vp.x * .36, -cos(angle) * vp.y * .31)
	_arrow.rotation = angle
	# Sprayed on: it comes in quickly, then breathes.
	var grow := minf(float(_arrow.get_meta("in", 0.0)) + delta * 5.0, 1.0)
	_arrow.set_meta("in", grow)
	_arrow.scale = Vector2.ONE * lerpf(.7, 1.0, grow)
	_arrow.modulate.a = grow * (.72 + .28 * sin(_now_s() * 7.0))
	_arrow_label.text = "Behind you" if absf(angle) > 1.9 else "They're coming"
	_arrow_label.rotation = -angle

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 6
	add_child(_hud)
	var top := Control.new()
	top.set_anchors_preset(Control.PRESET_FULL_RECT)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(top)
	# Under everything else here: the lens' flare and wash when his flashlight points into it.
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_wash = ColorRect.new()
	_wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wash.color = Color(1.0, .86, .64, 0.0)
	_wash.material = add
	_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_wash)
	_glare = TextureRect.new()
	_glare.texture = GLARE
	_glare.size = Vector2(560, 280)
	_glare.pivot_offset = _glare.size * .5
	_glare.material = add
	_glare.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glare.visible = false
	top.add_child(_glare)
	# The bar: his name, the chain, who he was.
	_bar_box = Control.new()
	_bar_box.anchor_left = .5
	_bar_box.anchor_right = .5
	_bar_box.offset_left = -260
	_bar_box.offset_right = 260
	# (Below the objective line, which may run to two lines at the top left.)
	_bar_box.offset_top = 52
	_bar_box.offset_bottom = 124
	_bar_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_bar_box)
	var title := SleepType.label("Heavy-arm", SleepType.serif(true), 31, SleepType.BONE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, .55))
	title.position = Vector2(0, 0)
	title.size = Vector2(520, 36)
	_bar_box.add_child(title)
	_chain = ChainBar.new()
	_chain.position = Vector2(0, 38)
	_chain.size = Vector2(520, 34)
	_bar_box.add_child(_chain)
	# (0.59: the caption under the bar is gone: the owner's call.)
	_bar_box.visible = false
	# The pack's arrow: the survivors' own mark.
	_arrow = Control.new()
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_arrow)
	var paint := TextureRect.new()
	paint.texture = SPRAY
	paint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paint.stretch_mode = TextureRect.STRETCH_SCALE
	paint.size = Vector2(176, 176)
	paint.position = Vector2(-88, -88)
	paint.pivot_offset = Vector2(88, 88)
	# (The painted arrow points along +X; the arrow node's rotation 0 is up.)
	paint.rotation = -PI * .5
	paint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.add_child(paint)
	_arrow_label = SleepType.label("", SleepType.street(2), 19, Color(1.0, .55, .22))
	_arrow_label.add_theme_constant_override("outline_size", 5)
	_arrow_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, .8))
	_arrow_label.position = Vector2(-110, 46)
	_arrow_label.size = Vector2(220, 24)
	_arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arrow_label.pivot_offset = Vector2(110, -46)
	_arrow.add_child(_arrow_label)
	_arrow.visible = false

# ---------------------------------------------------------------- debug

## 0.55: debug: him dead where he sat, his key on the ground beside him (not taken yet).
func debug_down() -> void:
	_ensure_boss()
	if state != "dead" and boss != null and is_instance_valid(boss): _take(_any_id(), hp + 1.0, true)

## Forward, as play would leave it: him dead and the key in hand, the gate open.
func debug_finish() -> void:
	debug_down()
	mission.flags.heavy_key_taken = true
	if not bool(mission.flags.get("reargate", false)): unlock()

## Debug: straight to one of his moves (`charge`, `throw`, `roar`), at whoever is nearest.
func debug_force(kind: String) -> String:
	_ensure_boss()
	if boss == null or state == "dead": return "Heavy-arm is not there."
	if state == "sit" or state == "talk":
		boss.asleep = false
		_go("fight")
	target = _pick()
	if target == 0: return "Nobody to go for."
	_start(kind)
	return "Heavy-arm: %s at %s." % [kind, _name(target)]

# ---------------------------------------------------------------- the boss bar

## 0.54: Heavy-arm's health as the rear gate's chain, the gate's padlock in the middle. Links stand out to both
## sides of the lock; as he is hurt they go from the far ends inward: the next to go rusts red and shivers, then
## snaps and drops off the bar, turning. A thin line under the chain is his health exactly (with a pale trail of
## what was just taken). Dead, the shackle springs open. A glint runs along the steel now and then.
class ChainBar extends Control:
	const SIDE := 11
	const LOCK := 30.0
	const STEEL := Color(.6, .59, .55)
	const STEEL_HI := Color(.93, .92, .87, .8)
	const DARK := Color(.02, .015, .015, .9)
	const RUST := Color(.58, .19, .09)
	const BRASS := Color(.72, .55, .25)
	var k := 1.0
	var dead := false
	var _trail := 1.0
	var _standing := SIDE
	var _falling: Array = []
	var _open := 0.0
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _step() -> float:
		return (size.x * .5 - LOCK * .5 - 14.0) / float(SIDE)

	func _link_at(i: int, side: float) -> Vector2:
		return Vector2(size.x * .5 + side * (LOCK * .5 + 4.0 + _step() * (float(i) + .5)), size.y * .5 - 2.0)

	func _process(delta: float) -> void:
		_t += delta
		_trail = move_toward(_trail, k, delta * .5) if _trail > k else k
		var standing := ceili(k * SIDE - .001)
		if standing < _standing:
			# (Only the last few that went: a death drops the lot at once, and a shower of them is noise.)
			for i in range(maxi(standing, _standing - 2), _standing):
				for side in [-1.0, 1.0]:
					_falling.append({"p": _link_at(i, side), "v": Vector2(side * randf_range(25.0, 70.0), randf_range(-70.0, -20.0)),
						"a": 0.0, "w": randf_range(-8.0, 8.0), "life": .8, "face": i % 2 == 0})
		_standing = standing
		for f: Dictionary in _falling:
			var v: Vector2 = f.v
			v.y += 760.0 * delta
			f.v = v
			f.p = (f.p as Vector2) + v * delta
			f.a = float(f.a) + float(f.w) * delta
			f.life = float(f.life) - delta
		_falling = _falling.filter(func(f: Dictionary) -> bool: return float(f.life) > 0.0)
		_open = move_toward(_open, 1.0 if dead else 0.0, delta * 2.2)
		queue_redraw()

	func _draw() -> void:
		var step := _step()
		var cx := size.x * .5
		var cy := size.y * .5 - 2.0
		var span := step * SIDE
		# His health exactly, under the chain: a rust line out from the lock, a pale trail of what was just taken.
		var line_y := cy + 13.0
		for side in [-1.0, 1.0]:
			var x0: float = cx + side * (LOCK * .5 + 4.0)
			draw_line(Vector2(x0, line_y), Vector2(x0 + side * span, line_y), Color(0, 0, 0, .45), 4.0)
			draw_line(Vector2(x0, line_y), Vector2(x0 + side * span * _trail, line_y), Color(.92, .86, .78, .4), 2.0)
			draw_line(Vector2(x0, line_y), Vector2(x0 + side * span * k, line_y), Color(.78, .14, .08, .95), 2.0)
		var glint := fmod(_t * .35, 2.2) - .6
		var frac := k * SIDE - float(_standing - 1)
		for pass_face in [false, true]:
			for i in _standing:
				var face := i % 2 == 0
				if face != pass_face: continue
				for side in [-1.0, 1.0]:
					var at := _link_at(i, side)
					var tint := STEEL.lerp(RUST, .12 + .1 * sin(float(i) * 2.3 + side))
					if i == _standing - 1 and frac < 1.0:
						tint = tint.lerp(RUST, clampf(1.0 - frac, 0.0, 1.0) * .9)
						at += Vector2(sin(_t * 47.0 + side) * (1.0 - frac) * 1.6, 0)
					var shine := exp(-pow((absf(at.x - cx) / maxf(span, 1.0) - glint) / .08, 2.0))
					_link(at, step, face, tint, shine, 0.0)
		for f: Dictionary in _falling:
			var a := clampf(float(f.life) / .8, 0.0, 1.0)
			_link(f.p, step, bool(f.face), Color(RUST, a), 0.0, float(f.a), a)
		_padlock(Vector2(cx, cy + 3.0))

	## One link: `face` is seen side-on as a ring, otherwise end-on as a bar.
	func _link(at: Vector2, step: float, face: bool, tint: Color, shine: float, turn: float, alpha := 1.0) -> void:
		draw_set_transform(at, turn, Vector2.ONE)
		var length := step * 1.42
		var hi := STEEL_HI.lerp(Color(1, .97, .9), shine)
		hi.a *= alpha * (1.0 + shine)
		var dark := Color(DARK, DARK.a * alpha)
		if face:
			var h := 12.0
			var r := h * .5
			var lc := Vector2(-length * .5 + r, 0)
			var rc := Vector2(length * .5 - r, 0)
			for layer in [[dark, 6.2], [tint, 3.4]]:
				var c: Color = layer[0]
				var w: float = layer[1]
				draw_arc(lc, r, PI * .5, PI * 1.5, 12, c, w, true)
				draw_arc(rc, r, -PI * .5, PI * .5, 12, c, w, true)
				draw_line(lc + Vector2(0, -r), rc + Vector2(0, -r), c, w, true)
				draw_line(lc + Vector2(0, r), rc + Vector2(0, r), c, w, true)
			draw_line(lc + Vector2(1, -r - .8), rc + Vector2(-1, -r - .8), hi, 1.1, true)
		else:
			draw_line(Vector2(-length * .5, 0), Vector2(length * .5, 0), dark, 7.0, true)
			draw_line(Vector2(-length * .5 + 1.5, 0), Vector2(length * .5 - 1.5, 0), tint, 4.2, true)
			draw_line(Vector2(-length * .5 + 3.0, -1.2), Vector2(length * .5 - 3.0, -1.2), hi, 1.1, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	## The gate's padlock: a brass body, a steel shackle (springing open once he is dead), a keyhole.
	func _padlock(at: Vector2) -> void:
		var lift := 6.0 * _open
		var swing := -.75 * _open
		var sc := at + Vector2(2.0 * _open, -6.0 - lift)
		for layer in [[DARK, 6.0], [STEEL, 3.2]]:
			draw_arc(sc, 7.0, PI + swing, TAU + swing, 16, layer[0], layer[1], true)
		var body := Rect2(at + Vector2(-11, -4), Vector2(22, 18))
		var box := StyleBoxFlat.new()
		box.bg_color = BRASS.darkened(.18)
		box.border_color = DARK
		box.set_border_width_all(2)
		box.set_corner_radius_all(4)
		draw_style_box(box, body)
		draw_line(body.position + Vector2(4, 3), body.position + Vector2(18, 3), Color(1, .9, .6, .5), 1.2, true)
		draw_circle(at + Vector2(0, 4.0), 2.4, DARK)
		draw_line(at + Vector2(0, 5.0), at + Vector2(0, 9.5), DARK, 1.8)
