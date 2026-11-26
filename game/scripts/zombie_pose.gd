class_name InteriorZombiePose
extends SkeletonModifier3D
## 0.28: what makes a townsperson's clip an infected one, on top of whatever the AnimationPlayer plays.
##
## Posture: the back hunched, the head hanging to one side and never quite still, one shoulder dropped, and the arms
## coming up to reach when there is someone to reach for (`reach_target`).
## Flinch: every bone here has a spring. A round that goes in kicks the bone it hit and the ones it hangs from
## (`kick`), so a shoulder is thrown back, a head snaps, a leg buckles, and it all swings back on its own.
## Runs before the PhysicalBoneSimulator3D, which takes the whole skeleton over when the body is a ragdoll.
##
## Skeleton space: +X is the figure's left, +Y up, +Z ahead.

const ORDER := ["spine", "chest", "neck", "head", "upper_arm.L", "forearm.L", "upper_arm.R", "forearm.R", "thigh.L", "thigh.R"]
## 0.29: nearly critically damped. A struck part jerks once and comes back; it does not swing to and fro.
const STIFFNESS := 150.0
const DAMPING := 20.0
const LIMIT := .9

var lean := .22
var head_tilt := Vector3.ZERO       # pitch (forward), yaw, roll
var droop := 0.0
var reach := 0.0
var reach_target := 0.0
var reach_angle := Vector2(1.25, 1.1)   # left, right
## 0.29: how far each arm has given up reaching (a wound, or it is gone): left, right.
var arm_limp := Vector2.ZERO
var _ids := {}
var _offset := {}
var _velocity := {}
var _last := 0
var _phase := randf() * 20.0

func setup() -> void:
	var skeleton := get_skeleton()
	for bone: String in ORDER:
		_ids[bone] = skeleton.find_bone(bone)
		_offset[bone] = Vector3.ZERO
		_velocity[bone] = Vector3.ZERO
	_last = Time.get_ticks_msec()

## An angular velocity (rad/s, skeleton space) for a bone's spring.
func kick(bone: String, turn: Vector3) -> void:
	if _velocity.has(bone):
		_velocity[bone] = (_velocity[bone] as Vector3) + turn

func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _ids.is_empty():
		return
	var now := Time.get_ticks_msec()
	var delta := clampf(float(now - _last) / 1000.0, 0.0, .05) * Engine.time_scale
	_last = now
	_phase += delta
	reach = move_toward(reach, reach_target, delta * 2.2)
	var t := _phase
	for bone: String in ORDER:
		var id: int = _ids[bone]
		if id < 0:
			continue
		var offset: Vector3 = _offset[bone]
		var velocity: Vector3 = _velocity[bone]
		var left := delta
		while left > 0.0:
			var h := minf(left, .008)
			left -= h
			velocity += (-offset * STIFFNESS - velocity * DAMPING) * h
			offset += velocity * h
		offset = offset.limit_length(LIMIT)
		_offset[bone] = offset
		_velocity[bone] = velocity
		var turn := Basis.IDENTITY
		match bone:
			"spine":
				turn = Basis(Vector3.RIGHT, lean * .45)
			"chest":
				turn = Basis(Vector3.RIGHT, lean * .55) * Basis(Vector3.BACK, droop)
			"neck":
				turn = Basis(Vector3.RIGHT, head_tilt.x * .4 - lean * .3) * Basis(Vector3.BACK, head_tilt.z * .4)
			"head":
				turn = Basis(Vector3.UP, head_tilt.y + sin(t * .9) * .09 + sin(t * 2.3 + 1.0) * .04) \
					* Basis(Vector3.RIGHT, head_tilt.x * .6 + sin(t * 1.3 + 2.0) * .05) \
					* Basis(Vector3.BACK, head_tilt.z * .6 + sin(t * 1.7) * .05)
			"upper_arm.L":
				turn = Basis(Vector3.RIGHT, -reach * (1.0 - arm_limp.x * .85) * (reach_angle.x + sin(t * 2.1) * .08))
			"upper_arm.R":
				turn = Basis(Vector3.RIGHT, -reach * (1.0 - arm_limp.y * .85) * (reach_angle.y + sin(t * 1.8 + 1.5) * .08))
			"forearm.L", "forearm.R":
				turn = Basis(Vector3.RIGHT, -reach * .3)
		var angle := offset.length()
		if angle > .0005:
			turn = Basis(offset / angle, angle) * turn
		if turn.is_equal_approx(Basis.IDENTITY):
			continue
		var pose := skeleton.get_bone_global_pose(id)
		pose.basis = turn * pose.basis
		skeleton.set_bone_global_pose(id, pose)
