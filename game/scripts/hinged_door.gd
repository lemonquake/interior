class_name InteriorHingedDoor
extends Node3D
## A door leaf that swings about this node's origin (the hinge axis, +Y).
## The leaf is a child AnimatableBody3D so it blocks the player and props and
## shoves loose props aside while it moves. Aim at it and press Hold (E) to toggle.
## Hold E (0.7) instead to grab the leaf where you aim and pull or push it by hand: it follows the
## view, keeps a little momentum when let go and rests wherever it stops.

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
## Pulling by hand: fastest swing (eased units per second) and how quickly a let-go door slows.
const PULL_SPEED := 2.4
const COAST_DAMPING := 2.8

var _manual := false   # moved by hand: rests at _t instead of animating to open / closed
var _held := false
var _t := 0.0          # eased opening, 0 closed .. 1 open, while manual
var _speed := 0.0
var _grab_angle := 0.0
var _grab_start := 0.0

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
	return _t > .02 if _manual else _open

## True while the leaf is still swinging (or held).
func is_moving() -> bool:
	if _manual:
		return _held or absf(_speed) > .01
	return not is_equal_approx(_progress, 1.0 if _open else 0.0)

static func _ease(p: float) -> float:
	return p * p * (3.0 - 2.0 * p)

static func _uneased(t: float) -> float:
	return .5 - sin(asin(clampf(1.0 - 2.0 * t, -1.0, 1.0)) / 3.0)

## Hold E on the leaf: `point` is where the view ray met it.
func grab(point: Vector3, _collider: Object = null) -> void:
	if _body == null:
		return
	if not _manual:
		_t = _ease(_progress)
		_manual = true
	_held = true
	_speed = 0.0
	_grab_start = _t
	_grab_frame(to_local(point))

## While held: `hand` is the point in front of the camera the grab point should follow.
func drag_to(hand: Vector3, delta: float) -> void:
	if not _held:
		return
	var want := _hand_target(to_local(hand))
	var speed := clampf((want - _t) * 9.0, -PULL_SPEED, PULL_SPEED)
	_speed = lerpf(_speed, speed, 1.0 - exp(-14.0 * delta))

## Lets go; the leaf coasts on. Returns how far (eased units) it moved while held.
func release() -> float:
	_held = false
	return absf(_t - _grab_start)

func _grab_frame(local: Vector3) -> void:
	var leaf_angle := deg_to_rad(open_angle_deg) * _t
	_grab_angle = wrapf(atan2(local.x, local.z) - leaf_angle, -PI, PI)

func _hand_target(local: Vector3) -> float:
	var angle := deg_to_rad(open_angle_deg)
	if absf(angle) < .001:
		return _t
	var want := wrapf(atan2(local.x, local.z) - _grab_angle, -PI, PI)
	return clampf(want / angle, 0.0, 1.0)

func open() -> void:
	if not _open:
		_open = true
		toggled.emit(true)

func close() -> void:
	if _open:
		_open = false
		toggled.emit(false)

func toggle() -> void:
	if _manual:
		# Left ajar by hand: a tap finishes the swing toward whichever side is nearer to done.
		_manual = false
		_held = false
		_progress = _uneased(_t)
		_open = _t < .5
		toggled.emit(_open)
		return
	if _open:
		close()
	else:
		open()

## Snaps to the closed/open pose without animating (tests, restart).
func snap(open_state: bool) -> void:
	_manual = false
	_held = false
	_speed = 0.0
	_open = open_state
	_progress = 1.0 if open_state else 0.0
	_blocked = 0.0
	_apply()
	if _body != null:
		_body.reset_physics_interpolation()

## True when the segment from..to passes through the (open) doorway, so an open door can be
## closed by aiming at the opening from either side, not only at the swung-back leaf.
func aims_through(from: Vector3, to: Vector3) -> bool:
	if _shape == null or not (is_open() or is_moving()):
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
	if _manual:
		_swing_by_hand(delta)
		return
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

func _swing_by_hand(delta: float) -> void:
	if not _held:
		_speed *= exp(-COAST_DAMPING * delta)
		if absf(_speed) < .01:
			_speed = 0.0
			return
	var next := clampf(_t + _speed * delta, 0.0, 1.0)
	if is_equal_approx(next, _t):
		if next <= 0.0 or next >= 1.0:
			_speed = -_speed * .15 if not _held else 0.0
		return
	var hits := _overlaps_t(next)
	if hits & PLAYER_MASK:
		# Never shove the player through the doorway; the leaf stops against them.
		_speed = 0.0
		return
	if hits & PROP_MASK:
		next = lerpf(_t, next, PROP_SPEED)
	_t = next
	_progress = _uneased(_t)
	_open = _t > .5
	_apply_t(_t)

## Which of the player / prop layers the leaf would overlap at swing progress `p`.
func _overlaps(p: float) -> int:
	return _overlaps_t(_ease(p))

## The same at eased opening `t`.
func _overlaps_t(t: float) -> int:
	if _shape == null or _body == null or not is_inside_tree():
		return 0
	if _query == null:
		_query = PhysicsShapeQueryParameters3D.new()
		_query.shape = _shape.shape
		_query.collision_mask = PLAYER_MASK | PROP_MASK
		_query.exclude = [_body.get_rid()]
	var pose := global_transform * Transform3D(Basis(Vector3.UP, deg_to_rad(open_angle_deg) * t), Vector3.ZERO) * _shape.transform
	_query.transform = pose
	var mask := 0
	for hit in get_world_3d().direct_space_state.intersect_shape(_query, 8):
		var collider := hit.get("collider") as CollisionObject3D
		if collider != null:
			mask |= collider.collision_layer & (PLAYER_MASK | PROP_MASK)
	return mask

func _apply() -> void:
	# Smoothstep ease: the leaf starts and stops gently.
	_apply_t(_t if _manual else _ease(_progress))

func _apply_t(t: float) -> void:
	if _body == null:
		return
	_body.rotation = Vector3(0.0, deg_to_rad(open_angle_deg) * t, 0.0)
