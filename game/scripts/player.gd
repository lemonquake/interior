class_name InteriorPlayer
extends CharacterBody3D

signal grabbed(body: InteriorObject)
signal target_changed(body: InteriorObject)
signal console_requested

const WALK_SPEED := 2.8
const RUN_SPEED := 4.2
const REACH := 3.0
const HOLD_DISTANCE := 1.55
var camera: Camera3D
var held: InteriorObject
var target: InteriorObject
var touch_move := Vector2.ZERO
var playing := false
var sensitivity := 0.0022
var _look_pitch := 0.0
var _previous_damp := Vector2.ZERO

func _ready() -> void:
	collision_layer = 1
	collision_mask = 6
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.24
	capsule.height = 1.70
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 0.85
	add_child(collision)
	camera = Camera3D.new()
	camera.position.y = 1.58
	camera.fov = 75.0
	camera.near = 0.06
	camera.far = 35.0
	add_child(camera)
	camera.current = true
	floor_snap_length = 0.2

func look(motion: Vector2) -> void:
	if not playing:
		return
	rotate_y(-motion.x * sensitivity)
	_look_pitch = clampf(_look_pitch - motion.y * sensitivity, -1.42, 1.42)
	camera.rotation.x = _look_pitch

func _unhandled_input(event: InputEvent) -> void:
	if not playing:
		return
	if get_parent().mobile and (event is InputEventMouseMotion or event is InputEventMouseButton):
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.relative)
	if event.is_action_pressed("hold"):
		toggle_hold()
	if event.is_action_pressed("throw"):
		throw_object()
	if event.is_action_pressed("jump") and is_on_floor():
		velocity.y = 4.0
	if event.is_action_pressed("inspect"):
		inspect_object()

func inspect_object() -> void:
	var hit := ray_hit(REACH, 6)
	if hit and hit.collider.is_in_group("mystery_console"):
		console_requested.emit()

func _physics_process(delta: float) -> void:
	if not playing:
		return
	var axis := Input.get_vector("left", "right", "forward", "back") + touch_move
	axis = axis.limit_length(1.0)
	var direction := global_basis * Vector3(axis.x, 0, axis.y)
	var speed := RUN_SPEED if Input.is_action_pressed("run") else WALK_SPEED
	velocity.x = move_toward(velocity.x, direction.x * speed, 16.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 16.0 * delta)
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	move_and_slide()
	# Furniture can also be moved by pushing; impulse remains bounded.
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var body := hit.get_collider() as InteriorObject
		if body != null and body != held:
			body.activate()
			body.apply_central_impulse(-hit.get_normal() * minf(body.mass, 12.0) * delta * 3.0)
	if global_position.y < -3.0:
		global_position = Vector3(0, 0.15, 2.0)
		velocity = Vector3.ZERO
	update_target()
	update_hold(delta)

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
	# Ray checks BOTH room and other furniture. Held bodies keep world collision.
	var hit := ray_hit(HOLD_DISTANCE, 6, [held.get_rid()])
	var distance := HOLD_DISTANCE
	if hit:
		distance = maxf(0.48, camera.global_position.distance_to(hit.position) - 0.35)
	var destination := camera.global_position - camera.global_basis.z * distance
	var error := destination - held.global_position
	if error.length() > 3.8:
		release_object()
		return
	# Velocity servo avoids teleporting rigid bodies through walls.
	var desired_velocity := (error * 9.0).limit_length(7.0)
	var acceleration := ((desired_velocity - held.linear_velocity) * 12.0).limit_length(65.0)
	held.apply_central_force(acceleration * held.mass)
	var max_spin := held.angular_velocity.limit_length(3.0)
	held.angular_velocity = max_spin

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
	# Same throw speed at any mass; heavy furniture still behaves as heavy furniture.
	body.apply_central_impulse(-camera.global_basis.z * body.mass * 7.5)
