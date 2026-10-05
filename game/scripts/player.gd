class_name InteriorPlayer
extends CharacterBody3D

signal grabbed(body: InteriorObject)
signal target_changed(body: InteriorObject)
signal console_requested

# Distances are metres, velocities m/s, masses kg and impulses N s.
const WALK_SPEED := 3.2
const RUN_SPEED := 5.6
const CROUCH_SPEED := 1.45
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

var camera: Camera3D
var held: InteriorObject
var target: InteriorObject
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
var _look_pitch := 0.0
var _previous_damp := Vector2.ZERO
var _capsule: CapsuleShape3D
var _collision: CollisionShape3D
var _standing_shape: CapsuleShape3D
var _coyote_left := 0.0
var _jump_buffer := 0.0
var _bob_phase := 0.0
var _eye_offset := 0.0
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
	camera.position.y = STANDING_EYE
	camera.fov = 75.0
	camera.near = 0.04
	camera.far = 35.0
	add_child(camera)
	camera.current = true
	floor_snap_length = 0.22
	floor_max_angle = deg_to_rad(44.0)
	floor_stop_on_slope = true
	floor_constant_speed = true
	safe_margin = 0.004
	max_slides = 6
	# The scene places the player immediately after add_child().
	_save_spawn.call_deferred()

func _save_spawn() -> void:
	_spawn_position = global_position

func look(motion: Vector2) -> void:
	if not playing or not motion.is_finite():
		return
	rotate_y(-motion.x * sensitivity)
	_look_pitch = clampf(_look_pitch - motion.y * sensitivity, -1.42, 1.42)
	camera.rotation.x = _look_pitch

func _unhandled_input(event: InputEvent) -> void:
	if not playing:
		return
	if get_parent().get("mobile") == true and (event is InputEventMouseMotion or event is InputEventMouseButton):
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.relative)
	if event.is_action_pressed("hold"):
		toggle_hold()
	if event.is_action_pressed("throw"):
		throw_object()
	if event.is_action_pressed("jump"):
		request_jump()
	if event.is_action_pressed("inspect"):
		inspect_object()

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
	if not global_position.is_finite() or not velocity.is_finite() or global_position.y < -3.0:
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
	# move_and_slide removes blocked velocity, so retain the actual approach speed.
	var approach_velocity := velocity
	move_and_slide()
	_push_contacts(approach_velocity)
	_update_camera(delta, sprinting)
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

func _push_contacts(approach_velocity: Vector3) -> void:
	var pushed: Array[InteriorObject] = []
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var body := hit.get_collider() as InteriorObject
		if body == null or body == held or pushed.has(body) or (body.anchored and body.freeze):
			continue
		var normal := hit.get_normal()
		if absf(normal.y) > 0.65:
			continue
		var toward := -normal
		var contact_offset := hit.get_position() - body.global_position
		var center_offset := hit.get_position() - body.to_global(body.center_of_mass)
		var contact_velocity := body.linear_velocity + body.angular_velocity.cross(center_offset)
		var closing_speed := maxf(0.0, (approach_velocity - contact_velocity).dot(toward))
		if closing_speed < 0.035:
			continue
		# Reduced mass transfers a finite share of player momentum. A chair responds
		# readily; a sofa needs a sustained push or a faster approach.
		var reduced_mass := PLAYER_MASS * body.mass / (PLAYER_MASS + body.mass)
		var impulse_size := minf(closing_speed * reduced_mass * 0.92, 115.0)
		body.activate()
		if body.freeze:
			continue
		body.apply_impulse(toward * impulse_size, contact_offset)
		pushed.append(body)

func _update_camera(delta: float, sprinting: bool) -> void:
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	var target_bob := 0.0
	if is_on_floor() and planar_speed > 0.2:
		_bob_phase += planar_speed * delta * 5.0
		target_bob = sin(_bob_phase * 2.0) * (0.007 if crouching else 0.012) * minf(planar_speed / WALK_SPEED, 1.2)
	_eye_offset = lerpf(_eye_offset, target_bob, 1.0 - exp(-12.0 * delta))
	var eye_height := CROUCH_EYE if crouching else STANDING_EYE
	camera.position.y = lerpf(camera.position.y, eye_height + _eye_offset, 1.0 - exp(-13.0 * delta))
	var desired_fov := 79.0 if sprinting and planar_speed > WALK_SPEED else 75.0
	camera.fov = lerpf(camera.fov, desired_fov, 1.0 - exp(-5.0 * delta))

func reset_motion(spawn_position: Vector3, restore_stance := true) -> void:
	release_object()
	global_position = spawn_position
	velocity = Vector3.ZERO
	touch_move = Vector2.ZERO
	touch_sprinting = false
	touch_crouching = false
	_jump_buffer = 0.0
	_coyote_left = 0.0
	_bob_phase = 0.0
	_eye_offset = 0.0
	if restore_stance and _capsule != null:
		crouching = false
		_capsule.height = STANDING_HEIGHT
		_collision.position.y = STANDING_HEIGHT * 0.5
		camera.position.y = STANDING_EYE
		camera.fov = 75.0

func ray_hit(distance: float, mask: int, exclude: Array[RID] = []) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(camera.global_position,
		camera.global_position - camera.global_basis.z * distance, mask)
	query.exclude = [get_rid()] + exclude
	return get_world_3d().direct_space_state.intersect_ray(query)

func update_target() -> void:
	var hit := ray_hit(REACH, 6)
	var next := hit.get("collider") as InteriorObject
	if next != target:
		target = next
		target_changed.emit(target)

func toggle_hold() -> void:
	if held != null:
		release_object()
		return
	update_target()
	if target == null:
		var hit := ray_hit(REACH, 6)
		if hit and hit.collider.is_in_group("mystery_console"):
			console_requested.emit()
		return
	grab_object(target)

func grab_object(body: InteriorObject) -> void:
	if not is_instance_valid(body) or held != null:
		return
	held = body
	held.held = true
	held.activate(true)
	held.sleeping = false
	_previous_damp = Vector2(held.linear_damp, held.angular_damp)
	held.linear_damp = 3.0
	held.angular_damp = 8.0
	add_collision_exception_with(held)
	held.add_collision_exception_with(self)
	grabbed.emit(held)

func update_hold(_delta: float) -> void:
	if not is_instance_valid(held):
		held = null
		return
	# Check structure and furniture; the held rigid body keeps world collisions.
	var hit := ray_hit(HOLD_DISTANCE, 6, [held.get_rid()])
	var distance := HOLD_DISTANCE
	if hit:
		distance = maxf(0.48, camera.global_position.distance_to(hit.position) - 0.35)
	var destination := camera.global_position - camera.global_basis.z * distance
	var error := destination - held.global_position
	if not error.is_finite() or error.length() > 3.8:
		release_object()
		return
	var desired_velocity := (error * 9.0).limit_length(7.0)
	var acceleration := ((desired_velocity - held.linear_velocity) * 12.0).limit_length(65.0)
	# Bounded force makes heavy furniture slower to lift and position.
	held.apply_central_force((acceleration * held.mass).limit_length(950.0))
	held.angular_velocity = held.angular_velocity.limit_length(3.0)

func release_object() -> InteriorObject:
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
	return body

func throw_object() -> void:
	var body := release_object()
	if body == null:
		return
	body.sleeping = false
	var throw_speed := clampf(7.5 * sqrt(2.5 / maxf(body.mass, 0.1)), 1.5, 7.5)
	body.apply_central_impulse(-camera.global_basis.z * body.mass * throw_speed)
