class_name InteriorObject
extends RigidBody3D
## Movable room prop (contract section 6). Bake-safe: everything below works on a
## body reloaded from a saved scene whose CollisionShape3D children already exist.

## strength = contact impulse in N s (estimated from contact impulses and the
## velocity change of this body), emitted at most every IMPACT_COOLDOWN seconds.
signal impact(strength: float, at: Vector3, material: String)

const PropPhysics = preload("res://scripts/prop_physics.gd")
const IMPACT_THRESHOLD := 0.05
const IMPACT_COOLDOWN := 0.12
const MAX_LINEAR_SPEED := 30.0
const MAX_ANGULAR_SPEED := 90.0
const SUPPORT_COS := 0.5

@export var prop_id := ""
@export var display_name := "Object"
@export var clue_digit := ""
@export_multiline var clue_text := ""
## Wall-attached: frozen until grabbed (activate(true)).
@export var anchored := false
@export_enum("carry", "drag", "none") var grab_mode := "carry"
## Key into InteriorPropPhysics.MATERIALS.
@export var physics_material := "wood":
	set(value):
		physics_material = value
		if is_inside_tree():
			_apply_material()
## Round body (ball, can, pot on its side...): rolling resistance replaces angular damping.
@export var rolls := false
## Begin asleep (not frozen) at the authored pose; Jolt wakes it on contact.
@export var start_asleep := false

var discovered := false
var held := false
## Compatibility only: legacy builders set dormant + freeze for "untouched"
## props. Such bodies are converted to sleeping (unfrozen) bodies on _ready.
var dormant := false
var home_transform := Transform3D.IDENTITY

var _round_radius := 0.0
var _rolling_coefficient := 0.012
var _spin_coefficient := 0.05
var _supported := false
var _support_normal := Vector3.UP
var _previous_velocity := Vector3.ZERO
var _impact_clock := 0.0
var _last_impact := -1.0

func _ready() -> void:
	collision_layer = PropPhysics.LAYER_OBJECTS
	collision_mask = 7
	can_sleep = true
	contact_monitor = true
	max_contacts_reported = 8
	home_transform = global_transform
	add_to_group("movable", true)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	_apply_material()
	# Builders append shapes and set exports right after add_child(); a baked
	# scene already has them. Either way finish once the current frame settles.
	_finish_setup.call_deferred()

func _apply_material() -> void:
	var values := PropPhysics.params(physics_material)
	physics_material_override = PropPhysics.physics_material(physics_material)
	linear_damp_mode = RigidBody3D.DAMP_MODE_COMBINE
	angular_damp_mode = RigidBody3D.DAMP_MODE_COMBINE
	linear_damp = float(values.linear_damp)
	angular_damp = float(values.angular_damp)
	_rolling_coefficient = float(values.rolling)
	_spin_coefficient = float(values.spin)

func _finish_setup() -> void:
	if not is_inside_tree():
		return
	home_transform = global_transform
	_round_radius = PropPhysics.smallest_round_radius(self)
	if _round_radius > 0.0 and _shape_count() == 1:
		rolls = true
	var bounds := PropPhysics.shape_bounds(self)
	# Small or light props get CCD so throws never tunnel through thin walls.
	continuous_cd = mass < 6.0 or bounds.size.length() < 0.6
	_configure_mass_distribution(bounds)
	if anchored:
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		freeze = true
	elif dormant and freeze:
		freeze = false
		dormant = false
		sleeping = true
	elif start_asleep and not held:
		sleeping = true

func _shape_count() -> int:
	var count := 0
	for child in get_children():
		if child is CollisionShape3D:
			count += 1
	return count

func _configure_mass_distribution(bounds: AABB) -> void:
	var weighted_center := Vector3.ZERO
	var volume := 0.0
	for child in get_children():
		var collision := child as CollisionShape3D
		if collision == null or collision.shape == null:
			continue
		var shape := collision.shape
		var weight := 0.001
		if shape is BoxShape3D:
			var dimensions: Vector3 = shape.size
			weight = dimensions.x * dimensions.y * dimensions.z
		elif shape is CylinderShape3D:
			weight = PI * shape.radius * shape.radius * shape.height
		elif shape is SphereShape3D:
			weight = 4.0 / 3.0 * PI * pow(shape.radius, 3)
		elif shape is CapsuleShape3D:
			weight = PI * shape.radius * shape.radius * shape.height
		weighted_center += collision.position * weight
		volume += weight
	if volume <= 0.0:
		return
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = weighted_center / volume
	var minimum_y := bounds.position.y
	var height := bounds.size.y
	# Dense frames (tables, chairs, racks) carry their weight low on their feet.
	if mass >= 4.0 and height > 0.3:
		center_of_mass.y = maxf(minimum_y + 0.04, center_of_mass.y - height * 0.08)
	var label := (display_name + " " + str(name) + " " + str(get_meta("asset_id", ""))).to_lower()
	if "fan" in label:
		# Motor and cast base dominate a standing fan; the rotor guard is light.
		center_of_mass.y = minimum_y + height * 0.22
	elif "plant" in label or "flower" in label:
		# Soil fills the bottom of the pot.
		center_of_mass.y = minimum_y + height * 0.36

func activate(detach := false) -> void:
	if anchored and freeze and not detach:
		return
	dormant = false
	freeze = false
	sleeping = false

func _on_body_entered(other: Node) -> void:
	# Jolt wakes sleeping bodies itself; only legacy frozen props need help.
	if other is InteriorObject and other.freeze and not other.anchored and not freeze:
		other.activate()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not state.transform.origin.is_finite() or not state.linear_velocity.is_finite() or not state.angular_velocity.is_finite():
		state.transform = home_transform
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		return
	var dt := state.step
	_impact_clock += dt
	var gravity_length := state.total_gravity.length()
	var up := -state.total_gravity / gravity_length if gravity_length > 0.001 else Vector3.UP
	var support := Vector3.ZERO
	var support_count := 0
	var impulse_total := 0.0
	var impact_point := global_position
	var surface_rolling := 0.0
	for i in state.get_contact_count():
		var normal := state.get_contact_local_normal(i)
		var impulse := state.get_contact_impulse(i).length()
		if impulse > impulse_total * 0.5:
			impact_point = state.get_contact_collider_position(i)
		impulse_total += impulse
		if normal.dot(up) > SUPPORT_COS:
			support += normal
			support_count += 1
			var other := state.get_contact_collider_object(i)
			if other != null and other.has_meta("rolling_resistance"):
				surface_rolling = maxf(surface_rolling, float(other.get_meta("rolling_resistance")))
			elif other is InteriorObject:
				surface_rolling = maxf(surface_rolling, (other as InteriorObject)._rolling_coefficient)
			else:
				surface_rolling = maxf(surface_rolling, PropPhysics.DEFAULT_SURFACE_ROLLING)
	_supported = support_count > 0
	if _supported:
		_support_normal = support.normalized()
	# Impacts: contact impulse, or this body's own velocity change in a contact.
	var velocity_change := (state.linear_velocity - _previous_velocity - state.total_gravity * dt).length() * mass
	_previous_velocity = state.linear_velocity
	if state.get_contact_count() > 0:
		var strength := maxf(impulse_total, velocity_change)
		if strength >= IMPACT_THRESHOLD and _impact_clock - _last_impact >= IMPACT_COOLDOWN and not held:
			_last_impact = _impact_clock
			call_deferred("emit_signal", "impact", strength, impact_point, physics_material)
	# Rolling resistance: a torque C_rr * N * r against the rolling direction,
	# only while touching a support. No angular damping does this job.
	# Below the sleep threshold leave the body alone: writing velocities would
	# keep Jolt from putting it to sleep.
	var resting := state.linear_velocity.length_squared() < 0.0001 and (state.angular_velocity * _round_radius).length_squared() < 0.0001
	if _supported and _round_radius > 0.0 and not resting:
		var normal_force := mass * gravity_length * clampf(_support_normal.dot(up), 0.0, 1.0)
		var omega := state.angular_velocity
		var spin := _support_normal * omega.dot(_support_normal)
		var roll := omega - spin
		var coefficient := _rolling_coefficient + surface_rolling
		var inverse_inertia := state.inverse_inertia_tensor
		if roll.length_squared() > 1e-8:
			var torque_impulse := -roll.normalized() * coefficient * normal_force * _round_radius * dt
			var change := inverse_inertia * torque_impulse
			if change.length_squared() >= roll.length_squared():
				change = -roll
			state.angular_velocity += change
		if spin.length_squared() > 1e-8:
			var spin_impulse := -spin.normalized() * _spin_coefficient * normal_force * _round_radius * 0.5 * dt
			var spin_change := inverse_inertia * spin_impulse
			if spin_change.length_squared() >= spin.length_squared():
				spin_change = -spin
			state.angular_velocity += spin_change
	# Safety net only; real throws stay well below these.
	if state.linear_velocity.length_squared() > MAX_LINEAR_SPEED * MAX_LINEAR_SPEED:
		state.linear_velocity = state.linear_velocity.limit_length(MAX_LINEAR_SPEED)
	if state.angular_velocity.length_squared() > MAX_ANGULAR_SPEED * MAX_ANGULAR_SPEED:
		state.angular_velocity = state.angular_velocity.limit_length(MAX_ANGULAR_SPEED)

func _physics_process(_delta: float) -> void:
	var position_now := global_position
	if not position_now.is_finite() or position_now.y < -4.0 or absf(position_now.x) > 40.0 or absf(position_now.z) > 40.0:
		recover()

## Rolling contact speed in m/s for audio; 0 while airborne or not round.
func rolling_speed() -> float:
	if sleeping or freeze or not _supported or _round_radius <= 0.0:
		return 0.0
	var roll := angular_velocity - _support_normal * angular_velocity.dot(_support_normal)
	return minf(roll.length() * _round_radius, linear_velocity.length())

## True while a contact holds the body up (kept through sleep).
func is_supported() -> bool:
	return _supported

func recover() -> void:
	held = false
	dormant = false
	freeze = anchored
	global_transform = home_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_previous_velocity = Vector3.ZERO
	reset_physics_interpolation()
	if not anchored:
		sleeping = true
