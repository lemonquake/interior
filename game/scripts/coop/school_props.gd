extends Node3D
## 0.57: the college's loose things as real bodies (owner: "the open and half-open classroom doors are still frozen,
## with no collision. They need to become hinged physics doors you can push, close and drag"; "all 1,095 chairs
## still have no collision. They should become pushable physics props"; "both have to stay in sync between host and
## other players").
##
## What is here (indices are the same on every peer: each builds the school from the street's seed, in the same
## order):
## - every armchair (`chair`): a RigidBody3D with no mesh of its own; it is drawn by its floor's MultiMesh, whose
##   instance follows the body when it moves. Collision layer 32 (CHAIR_LAYER): the players, the infected and the
##   other props bump it; rounds go through its open frame (gun.gd's mask has no 32).
## - every classroom door that was left open or ajar (`door`): a leaf on a HingeJoint3D at its frame, swinging
##   into the room only. Layer 4, like the store's tables: it stops rounds and takes the shove.
## - the leaves lying off their hinges (`leaf`) and the shut doors once they come off (`shut`, a slot kept from the
##   build and filled by school.gd `_break`).
##
## The host simulates; everyone else has the same bodies frozen (kinematic), eased toward the host's transforms
## (`state` / `apply`, carried in the session's snapshot). Walking into a prop pushes it: the host's own player and
## each client send what they lean on (`intent`: where, which way, how fast they are trying to go) and the host turns
## it into an impulse against the body's real motion, so a client's push is the same push as the host's. Hold E on a
## prop drags it by the point you hold (`grab` / `release`); a tap of E on a door swings it shut, or open if it is
## shut. The infected shove what they walk into (figure.gd, `light_prop`); the squad AI walk round.

const CHAIR_LAYER := 32
const PROP_LAYER := 4
const MASK := 2 | 4 | 32
const CHAIR_MASS := 6.5
const DOOR_MASS := 16.0
## How far a door opens into its room (rad), and where a tap swings a shut one to.
const DOOR_MAX := 1.75
const DOOR_OPEN := 1.45
## A tap is a press of E shorter than this (s) that moved the leaf less than TAP_MOVE (rad).
const TAP_TIME := .3
const TAP_MOVE := .12
## Pushing (as player.gd `_push_contacts`): the most a shove puts in per second, and how long a client's push lasts
## on the host after it arrives (they come every POSE_RATE).
const PUSH_FORCE := 520.0
const PLAYER_MASS := 78.0
const INTENT_LIFE := .12
## Host: props sent per snapshot at most (moving ones first), and how many of those moved and settled go again each
## time in turn (a lost packet, a late joiner).
const SEND_MAX := 80
const ROUND_ROBIN := 6

var school: Node3D
## The co-op session (scripts/coop/session.gd): who is where, `team`. Set by mission.gd once the school stands.
var session
var host := false
## {body, kind, mm, inst, swing, sign, last}
var props: Array = []
var _active := {}
var _dirty := {}
var _settle := {}
var _moved := {}
var _rr := 0
var _goal := {}
var _intents := {}
## Host: id -> [prop, grip (body-local), msec, opening when grabbed]
var drags := {}
## Host: door -> [goal opening, until msec]
var _swing := {}
var _chair_shapes: Array = []
var _leaf_mesh: BoxMesh
var _glass_mesh: BoxMesh
var _handle_mesh: BoxMesh
var _friction: PhysicsMaterial

func setup(owner_school: Node3D, is_host: bool) -> void:
	school = owner_school
	host = is_host
	name = "Loose props"
	_friction = PhysicsMaterial.new()
	_friction.friction = .75
	_friction.bounce = .05
	# The armchair as three boxes: legs and seat, the back, the writing arm (school.gd `_chair_mesh`).
	for spec: Array in [[Vector3(.44, .47, .42), Vector3(0, .235, 0)], [Vector3(.42, .34, .05), Vector3(0, .74, .2)], [Vector3(.26, .04, .46), Vector3(.31, .7, -.05)]]:
		var bs := BoxShape3D.new()
		bs.size = spec[0]
		_chair_shapes.append([bs, spec[1]])
	_leaf_mesh = BoxMesh.new()
	_leaf_mesh.size = Vector3(.98, 2.1, .05)
	_glass_mesh = BoxMesh.new()
	_glass_mesh.size = Vector3(.3, .42, .07)
	_handle_mesh = BoxMesh.new()
	_handle_mesh.size = Vector3(.05, .12, .1)

func _common(body: RigidBody3D, kind: String) -> int:
	var i := props.size()
	body.set_meta("coop_prop", i)
	body.set_meta("light_prop", true)
	body.physics_material_override = _friction
	body.can_sleep = true
	if host:
		# (Put to sleep once it is in Jolt's world, `_bed`: asleep, the classrooms stay as they were left, piles and
		# all, until something touches them.)
		body.sleeping_state_changed.connect(_woke.bind(i))
	else:
		body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		body.freeze = true
	props.append({"body": body, "kind": kind, "mm": null, "inst": -1, "swing": 0.0, "sign": 1.0, "last": Transform3D()})
	return i

## The chairs of root `r` (school.gd `_commit`), drawn by `mm` (instance n is transforms[n]).
func add_chairs(transforms: Array, mm: MultiMesh) -> void:
	# (`-- --no-chair-bodies`: measuring only, the chairs drawn and nothing else, as before 0.57.)
	if "--no-chair-bodies" in OS.get_cmdline_user_args(): return
	for n in transforms.size():
		var body := RigidBody3D.new()
		body.collision_layer = CHAIR_LAYER
		body.collision_mask = MASK
		body.mass = CHAIR_MASS
		body.linear_damp = .35
		body.angular_damp = 1.6
		for s: Array in _chair_shapes:
			var cs := CollisionShape3D.new()
			cs.shape = s[0]
			cs.position = s[1]
			body.add_child(cs)
		body.transform = transforms[n]
		var i := _common(body, "chair")
		props[i].mm = mm
		props[i].inst = n
		props[i].last = body.transform
		add_child(body)
		_bed.append(body)

## A leaf with its little window and handle (as the shut doors have), under `parent`, the hinge at its origin and
## the leaf along +X from it (`centred`: the leaf's middle at the origin instead).
func _leaf(parent: Node3D, material: Material, centred: bool) -> void:
	var off := Vector3.ZERO if centred else Vector3(.49, 0, 0)
	for part: Array in [[_leaf_mesh, Vector3.ZERO, material], [_glass_mesh, Vector3(.18, .42, 0), school.mat("glass#0a0c0ee8")], [_handle_mesh, Vector3(.36, -.06, 0), school.mat("#b8a878")]]:
		var mi := MeshInstance3D.new()
		mi.mesh = part[0]
		mi.material_override = part[2]
		mi.position = off + part[1]
		mi.layers = 1 | 8
		parent.add_child(mi)

## A classroom door left open `swing` (rad) into its room: the hinge at `hinge` (street-local), `sign` +1 where the
## room is to -Z (south side), -1 to +Z. Drawn and hidden with floor root `root`.
func add_door(root: Node3D, hinge: Vector3, sign: float, swing: float, material: Material) -> void:
	var body := RigidBody3D.new()
	body.name = "Classroom door"
	body.collision_layer = PROP_LAYER
	body.collision_mask = MASK
	body.mass = DOOR_MASS
	body.angular_damp = 2.2
	body.linear_damp = .5
	body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = Vector3(.49, 0, 0)
	# (No weight on the hinge: Jolt's joint would let it sag a hair a tick and wake it for nothing.)
	body.gravity_scale = 0.0
	# (The collider is a little narrower and shorter than the leaf drawn: clear of both posts and the floor at
	# every angle, so only the hinge holds it.)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(.9, 2.02, .045)
	cs.shape = bs
	cs.position = Vector3(.5, .02, 0)
	body.add_child(cs)
	_leaf(body, material, false)
	# Built where it was left: Jolt's hinge counts its angle from the pose the leaf has when the joint is made.
	body.transform = Transform3D(Basis(Vector3.UP, sign * swing), hinge)
	var i := _common(body, "door")
	props[i].swing = swing
	props[i].sign = sign
	props[i].last = body.transform
	root.add_child(body)
	if not host: return
	_bed.append(body)
	var joint := HingeJoint3D.new()
	joint.name = "Hinge"
	joint.transform = Transform3D(Basis(Vector3.RIGHT, -PI * .5), hinge)
	root.add_child(joint)
	joint.node_a = joint.get_path_to(body)
	# (work/v57/hinge_sign.gd: the joint's angle grows as the leaf turns the other way about +Y from where it was
	# made. Opening `o` turns it by sign * o.)
	joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
	if sign > 0.0:
		joint.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, swing - DOOR_MAX)
		joint.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, swing)
	else:
		joint.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, -swing)
		joint.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, DOOR_MAX - swing)
	# (0.59: no limit bias / relaxation: Jolt ignores both and warned twice per door, 40-odd lines a load.)

## A leaf off its hinges lying on the floor (centre `at`, flat, turned `yaw`).
func add_leaf(root: Node3D, at: Vector3, yaw: float, material: Material) -> void:
	var body := RigidBody3D.new()
	body.name = "Door leaf (off)"
	body.collision_layer = PROP_LAYER
	body.collision_mask = MASK
	body.mass = DOOR_MASS
	body.linear_damp = .4
	body.angular_damp = 1.2
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(.98, 2.1, .05)
	cs.shape = bs
	body.add_child(cs)
	_leaf(body, material, true)
	body.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * .5), at)
	var i := _common(body, "leaf")
	props[i].last = body.transform
	root.add_child(body)
	_bed.append(body)

## A shut door's slot: empty until it comes off (school.gd `_break` fills it).
func reserve() -> int:
	props.append({"body": null, "kind": "shut", "mm": null, "inst": -1, "swing": 0.0, "sign": 1.0, "last": Transform3D()})
	return props.size() - 1

## The shut door `i` came off: `body` is the leaf now lying loose (already in the tree, the host's impulses given).
func fill(i: int, body: RigidBody3D) -> void:
	if i < 0 or i >= props.size(): return
	body.set_meta("coop_prop", i)
	body.set_meta("light_prop", true)
	body.collision_mask = MASK
	props[i].body = body
	props[i].last = _local(body)
	if host:
		body.sleeping_state_changed.connect(_woke.bind(i))
		_active[i] = true
		_moved[i] = true
	else:
		body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		body.freeze = true

## School-local (street-local) transform of a prop's body, whatever it hangs under.
func _local(body: Node3D) -> Transform3D:
	return school.global_transform.affine_inverse() * body.global_transform

func _set_local(body: Node3D, t: Transform3D) -> void:
	body.global_transform = school.global_transform * t

func _woke(i: int) -> void:
	var body: RigidBody3D = props[i].body
	if body == null: return
	if not body.sleeping: _active[i] = true

# ---------------------------------------------------------------- doors

## How far door `i` stands open (rad, 0 shut).
func opening(i: int) -> float:
	var e: Dictionary = props[i]
	var x: Vector3 = (e.body as Node3D).global_basis.x
	return atan2(-x.z, x.x) * float(e.sign)

## Host: door `i` swings to `goal` by itself (a tap of E).
func swing_to(i: int, goal: float) -> void:
	_swing[i] = [clampf(goal, 0.0, DOOR_MAX), Time.get_ticks_msec() + 3000]
	_wake(i)

## Host: prop `i` was struck from outside (mission.gd `shove`): drawn and sent as it moves.
func woke(i: int) -> void:
	if i >= 0 and i < props.size(): _wake(i)

func _wake(i: int) -> void:
	var body: RigidBody3D = props[i].body
	if body == null or not host: return
	body.sleeping = false
	_active[i] = true

# ---------------------------------------------------------------- pushing and dragging (host)

## Someone (`id`) leans on prop `i` at `point` (world), walking `toward` (flat, unit) at `speed` m/s.
func intent(id: int, i: int, point: Vector3, toward: Vector3, speed: float) -> void:
	if i < 0 or i >= props.size() or props[i].body == null: return
	if not point.is_finite() or not toward.is_finite(): return
	toward.y = 0.0
	if toward.length_squared() < .01: return
	_intents["%d:%d" % [id, i]] = [i, point, toward.normalized(), clampf(speed, 0.0, 7.0), Time.get_ticks_msec()]

## `id` took hold of prop `i` at `grip` (body-local). False if out of reach or already held.
func grab(id: int, i: int, grip: Vector3, from: Vector3) -> bool:
	if i < 0 or i >= props.size() or props[i].body == null or not grip.is_finite(): return false
	for other: int in drags:
		if int(drags[other][0]) == i: return false
	var body: RigidBody3D = props[i].body
	if body.to_global(grip).distance_to(from + Vector3.UP * 1.0) > 3.2: return false
	var half := Vector3(.6, 1.1, .6)
	grip = grip.clamp(-half * 2.0, half * 2.0)
	drags[id] = [i, grip, Time.get_ticks_msec(), opening(i) if props[i].kind == "door" else 0.0]
	_wake(i)
	return true

## `id` let go. A short press on a door that hardly moved it swings it shut (or open, if shut).
func release(id: int) -> int:
	if not drags.has(id): return -1
	var d: Array = drags[id]
	drags.erase(id)
	var i := int(d[0])
	if props[i].kind == "door" and Time.get_ticks_msec() - int(d[2]) < TAP_TIME * 1000.0 and absf(opening(i) - float(d[3])) < TAP_MOVE:
		swing_to(i, 0.0 if opening(i) > .2 else DOOR_OPEN)
	return i

func dragging(id: int) -> int:
	return int(drags[id][0]) if drags.has(id) else -1

## Host: bodies just built, put to sleep over the first physics ticks (Jolt takes a new body in on its next step,
## awake whatever it was told before).
var _bed: Array[RigidBody3D] = []
var _bed_ticks := 0

func _physics_process(delta: float) -> void:
	if not _bed.is_empty():
		_bed_ticks += 1
		if _bed_ticks >= 2:
			for body in _bed:
				if is_instance_valid(body):
					body.sleeping = true
			if _bed_ticks >= 4:
				_bed.clear()
				_active.clear()
				_dirty.clear()
				_settle.clear()
	if host: _host_tick(delta)
	else: _follow(delta)

## Host, every tick: the swings, the drags, the pushes; then what moved is drawn there and marked to be sent.
func _host_tick(delta: float) -> void:
	var now := Time.get_ticks_msec()
	var team := _team()
	for i: int in _swing.keys():
		var e: Dictionary = props[i]
		var body: RigidBody3D = e.body
		var goal: float = _swing[i][0]
		var err := goal - opening(i)
		var spin := body.angular_velocity.y * float(e.sign)
		if now > int(_swing[i][1]) or (absf(err) < .03 and absf(spin) < .15) or drags.values().any(func(d): return int(d[0]) == i):
			_swing.erase(i)
			continue
		body.sleeping = false
		# About its hinge a leaf of 16 kg and 0.98 m has I = m w^2 / 3, about 5 kg m^2. (Up to about 120 N m: enough to
		# shove a chair standing in its way.)
		body.apply_torque(Vector3.UP * float(e.sign) * clampf(err * 38.0 - spin * 9.0, -24.0, 24.0) * 5.1)
	for id: int in drags.keys():
		var d: Array = drags[id]
		if not team.has(id) or int(team[id].hp) <= 0:
			drags.erase(id)
			continue
		var p: Dictionary = team[id]
		var e: Dictionary = props[int(d[0])]
		var body: RigidBody3D = e.body
		if body == null:
			drags.erase(id)
			continue
		var grip := body.to_global(d[1])
		var forward := Vector3(-sin(float(p.yaw)), 0, -cos(float(p.yaw)))
		var hand: Vector3 = p.pos + forward * .9 + Vector3.UP * (grip.y - float(p.pos.y))
		if Vector2(grip.x - p.pos.x, grip.z - p.pos.z).length() > 2.6 or absf(grip.y - float(p.pos.y) - .8) > 1.6:
			drags.erase(id)
			continue
		var error := hand - grip
		# Along the floor: a chair is slid, not lifted (a little lift so it does not snag on every tile).
		error.y = clampf(error.y, -.04, .06)
		var at := grip - body.global_position
		var point_velocity := body.linear_velocity + body.angular_velocity.cross(at)
		# A chair is pulled through its middle's height, so it slides on its feet instead of going over.
		if e.kind == "chair": at.y = body.to_global(body.center_of_mass).y - body.global_position.y
		# (As the store's tables, mission.gd `drag_tick`, but a chair is light: a firmer hand, so it keeps up.)
		var pull := (error * 55.0 - point_velocity * 14.0) * body.mass * (.3 if e.kind == "door" else 1.0)
		body.sleeping = false
		_active[int(d[0])] = true
		body.apply_force(pull.limit_length(body.mass * (32.0 if e.kind == "door" else 60.0)), at)
	for key: String in _intents.keys():
		var it: Array = _intents[key]
		if now - int(it[4]) > INTENT_LIFE * 1000.0:
			_intents.erase(key)
			continue
		_push(int(it[0]), it[1], it[2], float(it[3]), delta)
	for i: int in _active.keys():
		var e: Dictionary = props[i]
		var body: RigidBody3D = e.body
		if body == null:
			_active.erase(i)
			continue
		var t := _local(body)
		var last: Transform3D = e.last
		if t.origin.distance_squared_to(last.origin) > 1e-6 or not t.basis.is_equal_approx(last.basis):
			e.last = t
			_dirty[i] = true
			_moved[i] = true
			if e.mm != null: (e.mm as MultiMesh).set_instance_transform(int(e.inst), t)
		if body.sleeping:
			_active.erase(i)
			_settle[i] = 4

## As player.gd `_push_contacts`: momentum goes in where the body meets the prop, never past the walking speed.
func _push(i: int, point: Vector3, toward: Vector3, speed: float, delta: float) -> void:
	var body: RigidBody3D = props[i].body
	if body == null: return
	# A chair is shoved through its middle's height (legs and knees slide it; only a real blow tips it over).
	if props[i].kind == "chair": point.y = body.to_global(body.center_of_mass).y
	var arm := point - body.to_global(body.center_of_mass)
	var contact_velocity := body.linear_velocity + body.angular_velocity.cross(arm)
	var wanted := speed * clampf(20.0 / (body.mass + 20.0), .15, 1.0)
	var closing := wanted - contact_velocity.dot(toward)
	if closing < .03: return
	body.sleeping = false
	_active[i] = true
	var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
	var inverse_inertia: Basis = state.inverse_inertia_tensor if state else Basis.IDENTITY / maxf(body.mass, .1)
	var arm_cross := arm.cross(toward)
	var inverse_mass := 1.0 / maxf(body.mass, .05) + arm_cross.dot(inverse_inertia * arm_cross)
	var reduced := 1.0 / (inverse_mass + 1.0 / PLAYER_MASS)
	body.apply_impulse(toward * minf(closing * reduced, PUSH_FORCE * delta), point - body.global_position)

func _team() -> Dictionary:
	return session.team if session != null else {}

# ---------------------------------------------------------------- the host's word, everywhere else

## Host: the props that moved since the last snapshot, then some that came to rest and some that ever moved, as
## [index, x, y, z, qx, qy, qz, qw] per prop (school-local).
func state() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var sent := {}
	for i: int in _dirty.keys():
		if sent.size() >= SEND_MAX: break
		sent[i] = true
		_dirty.erase(i)
	for i: int in _settle.keys():
		sent[i] = true
		_settle[i] = int(_settle[i]) - 1
		if int(_settle[i]) <= 0: _settle.erase(i)
	if not _moved.is_empty():
		var keys := _moved.keys()
		for j in mini(ROUND_ROBIN, keys.size()):
			sent[keys[(_rr + j) % keys.size()]] = true
		_rr = (_rr + ROUND_ROBIN) % maxi(keys.size(), 1)
	for i: int in sent:
		var t: Transform3D = props[i].last
		var q := t.basis.get_rotation_quaternion()
		out.append_array([float(i), t.origin.x, t.origin.y, t.origin.z, q.x, q.y, q.z, q.w])
	return out

## Everyone else: where the host has them; eased toward (`_follow`), or put there at once from far off.
func apply(data: PackedFloat32Array) -> void:
	for o in range(0, data.size() - 7, 8):
		var i := int(data[o])
		if i < 0 or i >= props.size(): continue
		var t := Transform3D(Basis(Quaternion(data[o + 4], data[o + 5], data[o + 6], data[o + 7]).normalized()), Vector3(data[o + 1], data[o + 2], data[o + 3]))
		if not t.origin.is_finite(): continue
		var body: RigidBody3D = props[i].body
		if body != null and not _goal.has(i) and _local(body).origin.distance_to(t.origin) > 4.0:
			_place(i, t)
			continue
		_goal[i] = t

func _place(i: int, t: Transform3D) -> void:
	var e: Dictionary = props[i]
	var body: RigidBody3D = e.body
	if body == null: return
	_set_local(body, t)
	e.last = t
	if e.mm != null: (e.mm as MultiMesh).set_instance_transform(int(e.inst), t)

func _follow(delta: float) -> void:
	var w := 1.0 - exp(-14.0 * delta)
	for i: int in _goal.keys():
		var e: Dictionary = props[i]
		if e.body == null: continue
		var goal: Transform3D = _goal[i]
		var now: Transform3D = e.last
		var next := Transform3D(Basis(now.basis.get_rotation_quaternion().slerp(goal.basis.get_rotation_quaternion(), w)), now.origin.lerp(goal.origin, w))
		if next.origin.distance_squared_to(goal.origin) < 1e-6 and next.basis.is_equal_approx(goal.basis):
			next = goal
			_goal.erase(i)
		_place(i, next)

# ---------------------------------------------------------------- what the local player aims at

## The prop in reach under the view (`player`: InteriorPlayer): [index, grip (body-local)], or [].
func aimed(player: Node) -> Array:
	var camera: Camera3D = player.camera
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * 2.6, MASK)
	query.exclude = [player.get_rid()]
	var hit: Dictionary = (player as Node3D).get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not (hit.collider is RigidBody3D) or not (hit.collider as Node).has_meta("coop_prop"): return []
	var body: RigidBody3D = hit.collider
	return [int(body.get_meta("coop_prop")), body.to_local(hit.position)]

func prompt(player: Node) -> String:
	var a := aimed(player)
	if a.is_empty(): return ""
	match str(props[int(a[0])].kind):
		"door": return "E  •  %s door   Hold E  •  pull it" % ("Close" if opening(int(a[0])) > .2 else "Open")
		"chair": return "Hold E  •  drag chair"
	return "Hold E  •  drag door"

func body_of(i: int) -> RigidBody3D:
	return props[i].body if i >= 0 and i < props.size() else null
