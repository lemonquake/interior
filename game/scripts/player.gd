class_name InteriorPlayer
extends CharacterBody3D

signal grabbed(body: InteriorObject)
signal target_changed(body: InteriorObject)
signal console_requested
## Emitted at each heel strike (the low point of the head bob): surface key from InteriorSurfaces,
## strength 0..1 (walk ~0.6, run 1.0, crouch ~0.3).
signal stepped(surface: String, strength: float)
signal landed(surface: String, fall_speed: float)

# Distances are metres, velocities m/s, masses kg and impulses N s.
const WALK_SPEED := 2.45
const RUN_SPEED := 4.7
const CROUCH_SPEED := 1.2
## Metres travelled per footstep: an adult stride, about 2.3 steps/s walking and 3 steps/s running.
const WALK_STEP := 1.05
const RUN_STEP := 1.55
const CROUCH_STEP := .7
## Head bob: vertical drop at each heel strike, side-to-side sway over a left/right pair, roll.
const BOB_HEIGHT := .034
const BOB_SWAY := .022
const BOB_ROLL := .011
const GROUND_ACCELERATION := 10.5
const SPRINT_ACCELERATION := 13.5
const GROUND_BRAKING := 12.0
const AIR_ACCELERATION := 1.8
const GRAVITY := 14.0
const JUMP_SPEED := 4.8
const PLAYER_MASS := 78.0
const COYOTE_TIME := 0.11
const JUMP_BUFFER_TIME := 0.14
const STANDING_HEIGHT := 1.70
const CROUCH_HEIGHT := 1.00
const STANDING_EYE := 1.58
const CROUCH_EYE := 0.88
const REACH := 3.0
const HOLD_DISTANCE := 1.55
const HOLD_MIN_DISTANCE := 0.7
const HOLD_MAX_DISTANCE := 2.4
const CARRY_FORCE := 420.0          # N; heavier props lag and sag, ~40 kg cannot be lifted
const DRAG_FORCE := 520.0           # N at the grab point for heavy furniture
const PUSH_FORCE := 520.0           # N sustained shove into props
const THROW_CHARGE_TIME := 0.6
const OBSTRUCT_DISTANCE := 0.55
const OBSTRUCT_TIME := 0.3

var camera: Camera3D
var held: InteriorObject
var target: InteriorObject
## Hinged door under the crosshair (InteriorHingedDoor) when no prop is targeted.
var door_target: Node3D
var touch_move := Vector2.ZERO
var touch_sprinting := false
var touch_crouching := false
var playing := false:
	set(value):
		playing = value
		if not value:
			touch_move = Vector2.ZERO
			touch_sprinting = false
			_jump_buffer = 0.0
var crouching := false
var sensitivity := 0.0022
var throw_charge := 0.0
var charging_throw := false
var _base_fov := 75.0
var _eye_y := STANDING_EYE
var _hold_distance := HOLD_DISTANCE
var _grab_local := Vector3.ZERO
var _hold_relative := Basis.IDENTITY
var _hand_point := Vector3.ZERO
var _hand_velocity := Vector3.ZERO
var _obstructed_time := 0.0
var _rotating := false
var _teleport_frames := 0
var _look_pitch := 0.0
var _previous_damp := Vector2.ZERO
var _capsule: CapsuleShape3D
var _collision: CollisionShape3D
var _standing_shape: CapsuleShape3D
var _coyote_left := 0.0
var _jump_buffer := 0.0
var _bob_phase := 0.0   # 0..1 through the current step; 0 = heel strike
var _step_count := 0
var _bob_weight := 0.0
var _sway := 0.0
var _eye_offset := 0.0
var _air_speed := 0.0
## The desired planar velocity this tick (input direction x speed), before collisions.
var wish_velocity := Vector3.ZERO
var _spawn_position := Vector3(0, 0.15, 2.0)

func _ready() -> void:
	collision_layer = 1
	collision_mask = 6
	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.24
	_capsule.height = STANDING_HEIGHT
	_collision = CollisionShape3D.new()
	_collision.shape = _capsule
	_collision.position.y = STANDING_HEIGHT * 0.5
	add_child(_collision)
	_standing_shape = _capsule.duplicate() as CapsuleShape3D
	camera = Camera3D.new()
	camera.fov = _base_fov
	camera.near = 0.04
	camera.far = 35.0
	# Not interpolated itself: each rendered frame the camera is placed on the
	# interpolated body position and mouse look applies immediately, so 120/144 Hz
	# displays stay smooth with 60 Hz physics.
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.position.y = STANDING_EYE
	add_child(camera)
	camera.current = true
	_register_actions()
	floor_snap_length = 0.22
	floor_max_angle = deg_to_rad(44.0)
	floor_stop_on_slope = true
	floor_constant_speed = true
	safe_margin = 0.004
	max_slides = 6
	# Props never carry or launch the player; only the room counts as a platform.
	platform_floor_layers = 2
	platform_wall_layers = 0
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
	# The scene places the player immediately after add_child().
	_save_spawn.call_deferred()

func _register_actions() -> void:
	if not InputMap.has_action("rotate_held"):
		InputMap.add_action("rotate_held")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_R
		InputMap.action_add_event("rotate_held", key)

func _save_spawn() -> void:
	_spawn_position = global_position
	_sync_camera(global_position)

func set_fov(deg: float) -> void:
	_base_fov = clampf(deg, 50.0, 110.0)
	camera.fov = _base_fov

func _view_basis() -> Basis:
	return Basis(Vector3.UP, global_rotation.y) * Basis(Vector3.RIGHT, _look_pitch)

## Physics ticks use the exact eye; rendered frames use the interpolated body.
func _sync_camera(origin: Vector3) -> void:
	if camera == null:
		return
	var eye := _eye_y + _eye_offset
	if origin.is_equal_approx(global_position):
		camera.position = Vector3(_sway, eye, 0.0)
	else:
		camera.global_position = origin + global_basis.x * _sway + Vector3.UP * eye

func _process(_delta: float) -> void:
	if playing:
		_sync_camera(get_global_transform_interpolated().origin)

func look(motion: Vector2) -> void:
	if not playing or not motion.is_finite():
		return
	rotate_y(-motion.x * sensitivity)
	_look_pitch = clampf(_look_pitch - motion.y * sensitivity, -1.42, 1.42)
	camera.rotation.x = _look_pitch

## Turns the held object relative to the view (R + mouse, or touch drag).
func rotate_held(delta: Vector2) -> void:
	if not is_instance_valid(held) or not delta.is_finite():
		return
	var turn := Basis(Vector3.UP, delta.x * 0.008) * Basis(Vector3.RIGHT, delta.y * 0.008)
	_hold_relative = (turn * _hold_relative).orthonormalized()
	held.sleeping = false

func _unhandled_input(event: InputEvent) -> void:
	if not playing:
		return
	if get_parent().get("mobile") == true and (event is InputEventMouseMotion or event is InputEventMouseButton):
		return
	if event.is_action("rotate_held"):
		_rotating = event.is_pressed() and is_instance_valid(held)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if _rotating and is_instance_valid(held):
			rotate_held(event.relative)
		else:
			look(event.relative)
	if event is InputEventMouseButton and event.pressed and is_instance_valid(held):
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_hold_distance = minf(_hold_distance + 0.1, HOLD_MAX_DISTANCE)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_hold_distance = maxf(_hold_distance - 0.1, HOLD_MIN_DISTANCE)
	if event.is_action_pressed("hold"):
		toggle_hold()
	if event.is_action_pressed("throw") and is_instance_valid(held):
		charging_throw = true
		throw_charge = 0.0
	elif event.is_action_released("throw") and charging_throw:
		throw_object()
	if event.is_action_pressed("jump"):
		request_jump()
	if event.is_action_pressed("channel"):
		change_channel(1)
	if event is InputEventMouseButton and event.pressed and not is_instance_valid(held) and _interactor_with("change_channel") != null:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			change_channel(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			change_channel(-1)
	if event.is_action_pressed("inspect"):
		inspect_object()

## The interactor (TV, gate...) of the targeted prop, if it has `method`.
func _interactor_with(method: String) -> Object:
	if target == null or not target.has_meta("interactor"):
		return null
	var interactor: Object = target.get_meta("interactor")
	return interactor if is_instance_valid(interactor) and interactor.has_method(method) else null

func change_channel(step: int) -> void:
	var tv := _interactor_with("change_channel")
	if tv != null:
		tv.call("change_channel", step)

## Touch "Throw": throws a held prop, or changes the channel of a TV under the crosshair.
func touch_throw() -> void:
	if not is_instance_valid(held) and _interactor_with("change_channel") != null:
		change_channel(1)
		return
	throw_object()

func request_jump() -> void:
	if playing:
		_jump_buffer = JUMP_BUFFER_TIME

func inspect_object() -> void:
	var hit := ray_hit(REACH, 6)
	if hit and hit.collider.is_in_group("mystery_console"):
		console_requested.emit()

func _physics_process(delta: float) -> void:
	if not playing:
		return
	if not is_finite(delta) or delta <= 0.0:
		return
	# The courtyard below the balcony is at y=-2.9; only a real fall out of the world resets.
	if not global_position.is_finite() or not velocity.is_finite() or global_position.y < -6.0:
		reset_motion(_spawn_position)
		return
	var grounded := is_on_floor()
	_coyote_left = COYOTE_TIME if grounded else maxf(0.0, _coyote_left - delta)
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_update_stance()
	var axis := Input.get_vector("left", "right", "forward", "back") + touch_move
	if not axis.is_finite():
		axis = Vector2.ZERO
	axis = axis.limit_length(1.0)
	var direction := global_basis * Vector3(axis.x, 0, axis.y)
	direction.y = 0.0
	var sprinting := (Input.is_action_pressed("run") or touch_sprinting) and not crouching
	var speed := CROUCH_SPEED if crouching else (RUN_SPEED if sprinting else WALK_SPEED)
	wish_velocity = direction.normalized() * speed * axis.length() if axis.length_squared() > 0.001 else Vector3.ZERO
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	var acceleration := SPRINT_ACCELERATION if sprinting else GROUND_ACCELERATION
	if grounded:
		if axis.length_squared() < 0.001 or planar.dot(direction) < 0.0:
			acceleration = GROUND_BRAKING
		planar = planar.move_toward(direction * speed, acceleration * delta)
	else:
		# No automatic midair braking; the takeoff momentum carries through a jump.
		if axis.length_squared() > 0.001:
			planar = planar.move_toward(direction * speed, AIR_ACCELERATION * delta)
	velocity.x = planar.x
	velocity.z = planar.z
	if _jump_buffer > 0.0 and _coyote_left > 0.0 and not crouching:
		velocity.y = JUMP_SPEED
		_jump_buffer = 0.0
		_coyote_left = 0.0
		grounded = false
	elif grounded and velocity.y < 0.0:
		velocity.y = 0.0
	if not grounded:
		velocity.y -= GRAVITY * delta
	# move_and_slide removes blocked velocity; pushing uses the larger of the real
	# approach and the walking intent so a sustained shove keeps a steady force.
	var approach_velocity := velocity
	if grounded and axis.length_squared() > 0.001:
		var intent := direction.normalized() * speed * axis.length()
		if intent.length_squared() > Vector3(approach_velocity.x, 0, approach_velocity.z).length_squared():
			approach_velocity = Vector3(intent.x, approach_velocity.y, intent.z)
	var falling_speed := velocity.y
	move_and_slide()
	if is_on_floor() and not grounded and falling_speed < -1.2:
		landed.emit(InteriorSurfaces.under(self), falling_speed)
		# A landing plants a foot: restart the stride from a heel strike.
		_bob_phase = 0.0
		_eye_offset -= clampf(-falling_speed * .012, 0.0, .07)
	_push_contacts(approach_velocity, delta)
	_update_camera(delta, sprinting)
	if charging_throw:
		throw_charge = minf(1.0, throw_charge + delta / THROW_CHARGE_TIME)
	update_target()
	update_hold(delta)

func _update_stance() -> void:
	var wants_crouch := touch_crouching or (InputMap.has_action("crouch") and Input.is_action_pressed("crouch"))
	if wants_crouch and not crouching:
		crouching = true
		_capsule.height = CROUCH_HEIGHT
		_collision.position.y = CROUCH_HEIGHT * 0.5
	elif not wants_crouch and crouching and can_stand():
		crouching = false
		_capsule.height = STANDING_HEIGHT
		_collision.position.y = STANDING_HEIGHT * 0.5

func can_stand() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _standing_shape
	query.transform = global_transform * Transform3D(Basis.IDENTITY, Vector3(0, STANDING_HEIGHT * 0.5 + 0.008, 0))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	if is_instance_valid(held):
		query.exclude.append(held.get_rid())
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _push_contacts(approach_velocity: Vector3, delta: float) -> void:
	var pushed: Array[InteriorObject] = []
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var body := hit.get_collider() as InteriorObject
		if body == null or body == held or pushed.has(body) or (body.anchored and body.freeze):
			continue
		var normal := hit.get_normal()
		# Standing on (or brushing the top of) a prop never shoves it.
		if absf(normal.y) > 0.65:
			continue
		var toward := -normal
		toward.y = 0.0
		if toward.length_squared() < 0.01:
			continue
		toward = toward.normalized()
		var point := hit.get_position()
		var arm := point - body.to_global(body.center_of_mass)
		var contact_velocity := body.linear_velocity + body.angular_velocity.cross(arm)
		# Heavy furniture is shoved slower than the player walks.
		var wanted_speed := approach_velocity.dot(toward) * clampf(20.0 / (body.mass + 20.0), 0.15, 1.0)
		var closing_speed := wanted_speed - contact_velocity.dot(toward)
		if closing_speed < 0.03:
			continue
		# Effective mass at the contact point (rotation included) in series with
		# the player: momentum goes in where the capsule touches, so light tall
		# props tip and low wide ones slide.
		body.activate()
		if body.freeze:
			continue
		var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
		var inverse_inertia: Basis = state.inverse_inertia_tensor if state else Basis.IDENTITY / maxf(body.mass, 0.1)
		var arm_cross := arm.cross(toward)
		var inverse_mass := 1.0 / maxf(body.mass, 0.05) + arm_cross.dot(inverse_inertia * arm_cross)
		var reduced_mass := 1.0 / (inverse_mass + 1.0 / PLAYER_MASS)
		var impulse_size := minf(closing_speed * reduced_mass, PUSH_FORCE * delta)
		body.apply_impulse(toward * impulse_size, point - body.global_position)
		pushed.append(body)

func _update_camera(delta: float, sprinting: bool) -> void:
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	var grounded := is_on_floor()
	var moving := grounded and planar_speed > 0.25
	# The bob fades in and out with speed instead of snapping when walking starts or stops.
	var target_weight := clampf(planar_speed / WALK_SPEED, 0.0, 1.35) if moving else 0.0
	_bob_weight = lerpf(_bob_weight, target_weight, 1.0 - exp(-(6.0 if moving else 4.0) * delta))
	if moving:
		var stride := CROUCH_STEP if crouching else (RUN_STEP if planar_speed > (WALK_SPEED + RUN_SPEED) * .5 else WALK_STEP)
		_bob_phase += planar_speed * delta / stride
		if _bob_phase >= 1.0:
			_bob_phase = fmod(_bob_phase, 1.0)
			_step_count += 1
			var strength := 0.3 if crouching else clampf(planar_speed / RUN_SPEED, 0.45, 1.0)
			stepped.emit(InteriorSurfaces.under(self), strength)
	elif _bob_weight < .05:
		# Standing still: settle back to mid-stride so the next step starts cleanly.
		_bob_phase = lerpf(_bob_phase, 0.5 if _bob_phase > 0.25 else 0.0, 1.0 - exp(-3.0 * delta))
	var bob_scale := (0.45 if crouching else 1.0) * _bob_weight
	# Lowest at the heel strike (phase 0), highest at mid-stance (phase 0.5).
	var bob := -cos(_bob_phase * TAU) * BOB_HEIGHT * .5 - BOB_HEIGHT * .5
	# Weight shifts over the planted foot: one full sway per left/right pair of steps.
	var side := 1.0 if _step_count % 2 == 0 else -1.0
	var sway := sin(_bob_phase * PI) * side * BOB_SWAY
	_sway = sway * bob_scale
	_eye_offset = lerpf(_eye_offset, bob * bob_scale, 1.0 - exp(-18.0 * delta))
	var eye_height := CROUCH_EYE if crouching else STANDING_EYE
	_eye_y = lerpf(_eye_y, eye_height, 1.0 - exp(-13.0 * delta))
	if camera != null:
		camera.rotation.z = -sway * bob_scale / BOB_SWAY * BOB_ROLL
	var desired_fov := _base_fov + (4.0 if sprinting and planar_speed > WALK_SPEED else 0.0)
	camera.fov = lerpf(camera.fov, desired_fov, 1.0 - exp(-5.0 * delta))
	# Physics queries this tick use the exact (non-interpolated) eye.
	_sync_camera(global_position)

func _end_teleport() -> void:
	_teleport_frames -= 1
	if _teleport_frames <= 0 and _collision != null:
		_teleport_frames = 0
		_collision.disabled = false

func reset_motion(spawn_position: Vector3, restore_stance := true) -> void:
	release_object()
	# Jolt moves the kinematic character to a teleport target as a sweep; with
	# the capsule briefly disabled nothing on the way gets launched.
	if _collision != null and is_inside_tree():
		_collision.disabled = true
		_teleport_frames += 1
		get_tree().create_timer(0.04, true, true).timeout.connect(_end_teleport)
	global_position = spawn_position
	velocity = Vector3.ZERO
	touch_move = Vector2.ZERO
	touch_sprinting = false
	touch_crouching = false
	_jump_buffer = 0.0
	_coyote_left = 0.0
	_bob_phase = 0.0
	_bob_weight = 0.0
	_sway = 0.0
	_eye_offset = 0.0
	if restore_stance and _capsule != null:
		crouching = false
		_capsule.height = STANDING_HEIGHT
		_collision.position.y = STANDING_HEIGHT * 0.5
		_eye_y = STANDING_EYE
		camera.fov = _base_fov
	reset_physics_interpolation()
	_sync_camera(global_position)

func ray_hit(distance: float, mask: int, exclude: Array[RID] = []) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(camera.global_position,
		camera.global_position - camera.global_basis.z * distance, mask)
	query.exclude = [get_rid()] + exclude
	return get_world_3d().direct_space_state.intersect_ray(query)

func update_target() -> void:
	var hit := ray_hit(REACH, 6)
	var next := hit.get("collider") as InteriorObject
	door_target = null
	if next == null and hit and hit.collider is Node:
		var door := (hit.collider as Node).get_parent()
		if door != null and door.is_in_group("interior_doors"):
			door_target = door as Node3D
	if next == null and door_target == null:
		# An open door: aiming through its doorway (within reach, nothing nearer) targets it too.
		var from := camera.global_position
		var to: Vector3 = hit.position if hit else from - camera.global_basis.z * REACH
		for door in get_tree().get_nodes_in_group("interior_doors"):
			if door.has_method("aims_through") and door.aims_through(from, to.lerp(from, -.05)):
				door_target = door as Node3D
				break
	if next != target:
		target = next
		target_changed.emit(target)

func toggle_hold() -> void:
	if held != null:
		release_object()
		return
	update_target()
	if target != null and target.has_meta("interactor"):
		var interactor: Object = target.get_meta("interactor")
		if is_instance_valid(interactor) and interactor.has_method("interact"):
			interactor.call("interact")
		return
	if target == null and door_target != null:
		door_target.call("toggle")
		return
	if target == null:
		var hit := ray_hit(REACH, 6)
		if hit and hit.collider.is_in_group("mystery_console"):
			console_requested.emit()
		return
	grab_object(target)

func grab_object(body: InteriorObject) -> void:
	if not is_instance_valid(body) or held != null or body.grab_mode == "none":
		return
	held = body
	held.held = true
	held.activate(true)
	held.sleeping = false
	# Grab where the view ray meets the body; fall back to its centre of mass.
	var hit := ray_hit(REACH + 0.5, 6)
	var grab_point: Vector3 = hit.position if hit and hit.collider == body else body.to_global(body.center_of_mass)
	_grab_local = body.to_local(grab_point)
	_hold_distance = clampf(camera.global_position.distance_to(grab_point), HOLD_MIN_DISTANCE, HOLD_DISTANCE)
	var yaw := Basis(Vector3.UP, global_rotation.y)
	_hold_relative = (yaw.inverse() * body.global_basis.orthonormalized()).orthonormalized()
	_hand_point = camera.global_position - camera.global_basis.z * _hold_distance
	_hand_velocity = Vector3.ZERO
	_obstructed_time = 0.0
	charging_throw = false
	throw_charge = 0.0
	_previous_damp = Vector2(held.linear_damp, held.angular_damp)
	add_collision_exception_with(held)
	held.add_collision_exception_with(self)
	grabbed.emit(held)

func update_hold(delta: float) -> void:
	if not is_instance_valid(held):
		held = null
		return
	if delta <= 0.0 or not is_finite(delta):
		return
	var hand := camera.global_position - camera.global_basis.z * _hold_distance
	var hand_velocity := (hand - _hand_point) / delta
	_hand_point = hand
	_hand_velocity = _hand_velocity.lerp(hand_velocity.limit_length(12.0), 0.5)
	var grab_world := held.to_global(_grab_local)
	var error := hand - grab_world
	if not error.is_finite():
		release_object()
		return
	# A wall or furniture between hand and prop: let go after a moment.
	_obstructed_time = _obstructed_time + delta if error.length() > OBSTRUCT_DISTANCE else 0.0
	if _obstructed_time > OBSTRUCT_TIME or error.length() > 1.6:
		release_object()
		return
	held.sleeping = false
	var gravity := Vector3.DOWN * float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var com_world := held.to_global(held.center_of_mass)
	if held.grab_mode == "drag" or held.mass >= 15.0:
		# Heavy furniture: a stiff hand pulls at the grab point, horizontally.
		error.y = clampf(error.y, -0.05, 0.05)
		var point_velocity := held.linear_velocity + held.angular_velocity.cross(grab_world - com_world)
		var pull := (error * 60.0 - (point_velocity - _hand_velocity) * 18.0) * held.mass * 0.25
		held.apply_force(pull.limit_length(DRAG_FORCE), grab_world - held.global_position)
		return
	# Carry: critically damped spring on the grab point; softer for heavier props.
	var weight := clampf(held.mass / 12.0, 0.0, 1.0)
	var omega := lerpf(15.0, 6.0, weight)
	var accel := error * omega * omega - (held.linear_velocity - _hand_velocity) * 2.0 * omega - gravity
	held.apply_central_force((accel * held.mass).limit_length(CARRY_FORCE))
	# Angular servo keeps the prop's orientation relative to the view yaw.
	var target_basis := Basis(Vector3.UP, global_rotation.y) * _hold_relative
	var turn := (target_basis * held.global_basis.orthonormalized().inverse()).get_rotation_quaternion()
	var angle := turn.get_angle()
	var axis := turn.get_axis() if angle > 0.0001 else Vector3.UP
	if angle > PI:
		angle -= TAU
	var desired_spin := (axis * angle * lerpf(14.0, 5.0, weight)).limit_length(10.0)
	held.angular_velocity = held.angular_velocity.lerp(desired_spin, clampf(delta * lerpf(18.0, 6.0, weight), 0.0, 1.0))

func release_object() -> InteriorObject:
	charging_throw = false
	_rotating = false
	if not is_instance_valid(held):
		held = null
		return null
	var body := held
	held = null
	body.held = false
	body.linear_damp = _previous_damp.x
	body.angular_damp = _previous_damp.y
	remove_collision_exception_with(body)
	body.remove_collision_exception_with(self)
	# Drop keeps the hand's motion: the spring already carries it, nothing is zeroed.
	return body

## Throws the held prop. Desktop: hold LMB to charge (throw_charge 0..1 over
## THROW_CHARGE_TIME) and release. Touch calls this directly (medium throw).
func throw_object() -> void:
	var charge := throw_charge if charging_throw else 0.65
	throw_charge = 0.0
	var body := release_object()
	if body == null:
		return
	body.sleeping = false
	var direction := (-camera.global_basis.z + Vector3.UP * 0.06).normalized()
	# Mass-scaled: a 0.5 kg prop leaves at up to ~11 m/s, 6 kg at ~3 m/s.
	var speed := lerpf(2.5, 11.0, clampf(charge, 0.0, 1.0)) * clampf(sqrt(0.5 / maxf(body.mass, 0.05)), 0.12, 1.0)
	body.apply_central_impulse(direction * body.mass * speed)
	var spin_axis := camera.global_basis.x * randf_range(0.5, 1.0) + Vector3(randf_range(-.3, .3), randf_range(-.3, .3), randf_range(-.3, .3))
	body.angular_velocity += spin_axis * (1.5 + 3.0 * charge) * clampf(1.0 / maxf(body.mass, 0.2), 0.1, 1.0)
