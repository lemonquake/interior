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

func _ready() -> void:
	add_to_group("interior_doors")
	for child in get_children():
		if child is AnimatableBody3D:
			_body = child
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
	_apply()
	if _body != null:
		_body.reset_physics_interpolation()

func prompt_text() -> String:
	return ("Close " if _open else "Open ") + label

func _physics_process(delta: float) -> void:
	var goal := 1.0 if _open else 0.0
	if is_equal_approx(_progress, goal):
		return
	_progress = move_toward(_progress, goal, delta / maxf(swing_seconds, 0.05))
	_apply()

func _apply() -> void:
	if _body == null:
		return
	# Smoothstep ease: the leaf starts and stops gently.
	var t := _progress * _progress * (3.0 - 2.0 * _progress)
	_body.rotation = Vector3(0.0, deg_to_rad(open_angle_deg) * t, 0.0)
