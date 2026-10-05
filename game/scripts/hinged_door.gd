class_name InteriorHingedDoor
extends Node3D
## A door leaf that swings about this node's origin (the hinge axis, +Y).
## The leaf is a child AnimatableBody3D so it blocks the player and props and
## shoves loose props aside while it moves. Aim at it and press Hold (E) to toggle.

signal toggled(open: bool)

## Negative swings the free edge toward -Z (inward for the rear entry door).
@export var open_angle_deg := -88.0
@export var swing_seconds := 0.6
@export var start_open := false
@export var label := "door"

var _body: AnimatableBody3D
var _open := false
var _progress := 0.0  # 0 closed .. 1 open
var _blocked := 0.0  # seconds the swing has been held up by the player
var _shape: CollisionShape3D
var _query: PhysicsShapeQueryParameters3D

## Player layer: the leaf stops for the player instead of shoving them through the doorway.
const PLAYER_MASK := 1
## Loose props: the leaf slows right down while it is pushing one so it nudges, not launches.
const PROP_MASK := 4
const PROP_SPEED := .3
const GIVE_UP_SECONDS := .35

func _ready() -> void:
	add_to_group("interior_doors")
	for child in get_children():
		if child is AnimatableBody3D:
			_body = child
			break
	if _body != null:
		for child in _body.get_children():
			if child is CollisionShape3D:
				_shape = child
				break
	_open = start_open
	_progress = 1.0 if _open else 0.0
	_apply()
	if _body != null:
		_body.reset_physics_interpolation()

func is_open() -> bool:
	return _open

## True while the leaf is still swinging.
func is_moving() -> bool:
	return not is_equal_approx(_progress, 1.0 if _open else 0.0)

func open() -> void:
	if not _open:
		_open = true
		toggled.emit(true)

func close() -> void:
	if _open:
		_open = false
		toggled.emit(false)

func toggle() -> void:
	if _open:
		close()
	else:
		open()

## Snaps to the closed/open pose without animating (tests, restart).
func snap(open_state: bool) -> void:
	_open = open_state
	_progress = 1.0 if open_state else 0.0
	_blocked = 0.0
	_apply()
	if _body != null:
		_body.reset_physics_interpolation()

## True when the segment from..to passes through the (open) doorway, so an open door can be
## closed by aiming at the opening from either side, not only at the swung-back leaf.
func aims_through(from: Vector3, to: Vector3) -> bool:
	if _shape == null or not (_open or is_moving()):
		return false
	var inv := (global_transform * _shape.transform).affine_inverse()
	var a := inv * from
	var b := inv * to
	if is_equal_approx(a.z, b.z) or signf(a.z) == signf(b.z):
		return false
	var p := a.lerp(b, a.z / (a.z - b.z))
	var half := (_shape.shape as BoxShape3D).size * .5
	return absf(p.x) <= half.x and absf(p.y) <= half.y

func prompt_text() -> String:
	return ("Close " if _open else "Open ") + label

func _physics_process(delta: float) -> void:
	var goal := 1.0 if _open else 0.0
	if is_equal_approx(_progress, goal):
		return
	var step := move_toward(_progress, goal, delta / maxf(swing_seconds, 0.05))
	var hits := _overlaps(step)
	if hits & PLAYER_MASK:
		# Someone is standing in the swing: hold, then give way back to where it came from.
		_blocked += delta
		if _blocked >= GIVE_UP_SECONDS:
			_blocked = 0.0
			_open = not _open
			toggled.emit(_open)
		return
	_blocked = 0.0
	if hits & PROP_MASK:
		step = move_toward(_progress, goal, PROP_SPEED * delta / maxf(swing_seconds, 0.05))
	_progress = step
	_apply()

## Which of the player / prop layers the leaf would overlap at swing progress `p`.
func _overlaps(p: float) -> int:
	if _shape == null or _body == null or not is_inside_tree():
		return 0
	if _query == null:
		_query = PhysicsShapeQueryParameters3D.new()
		_query.shape = _shape.shape
		_query.collision_mask = PLAYER_MASK | PROP_MASK
		_query.exclude = [_body.get_rid()]
	var t := p * p * (3.0 - 2.0 * p)
	var pose := global_transform * Transform3D(Basis(Vector3.UP, deg_to_rad(open_angle_deg) * t), Vector3.ZERO) * _shape.transform
	_query.transform = pose
	var mask := 0
	for hit in get_world_3d().direct_space_state.intersect_shape(_query, 8):
		var collider := hit.get("collider") as CollisionObject3D
		if collider != null:
			mask |= collider.collision_layer & (PLAYER_MASK | PROP_MASK)
	return mask

func _apply() -> void:
	if _body == null:
		return
	# Smoothstep ease: the leaf starts and stops gently.
	var t := _progress * _progress * (3.0 - 2.0 * _progress)
	_body.rotation = Vector3(0.0, deg_to_rad(open_angle_deg) * t, 0.0)
