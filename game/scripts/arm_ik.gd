class_name InteriorArmIK
extends SkeletonModifier3D
## 0.27: the first-person arms reach for the weapon instead of being carried with it (scripts/gun.gd).
##
## The body camera is on the chest: the shoulders stay with the body while the hands go where the weapon goes, so
## aiming, turning and recoil bend the wrists and swing the forearms about the elbows, as an arm does. Runs after
## the arms' clips each frame:
##   - `delta_pose` moves the clip's hand poses rigidly (the pistol: the clips already hold it in both hands);
##   - a socket replaces a hand's pose outright, by `socket_weight` (the rifle: grip and handguard);
## and then each upper arm and forearm is solved to put the wrist there (two-bone IK, elbows toward `pole`).
## All transforms are in the skeleton's space.

const SIDES := ["R", "L"]

var delta_pose := Transform3D.IDENTITY
var socket := {"R": Transform3D.IDENTITY, "L": Transform3D.IDENTITY}
var socket_weight := {"R": 0.0, "L": 0.0}
## Where each elbow hangs: a direction from the shoulder, in skeleton space.
var pole := {"R": Vector3(-.5, -1.0, -.2), "L": Vector3(.5, -1.0, -.2)}
## How much of the clip's own elbow direction is kept (the rest follows `pole`).
var clip_elbow := .35
## How much of the hand's twist the forearm takes up.
var forearm_twist := .6
## The clip's hand poses before anything was changed, and where the hands ended up.
var clip_hand := {"R": Transform3D.IDENTITY, "L": Transform3D.IDENTITY}
var solved_hand := {"R": Transform3D.IDENTITY, "L": Transform3D.IDENTITY}
## How straight each arm had to be (0 folded .. 1 fully stretched): the weapon is held out of reach at 1.
var stretch := {"R": 0.0, "L": 0.0}

## 0.31: the hands have fingers (tools/blender/human/fp_hands.py). What each hand's fingers are asked to do, in
## degrees: "index" / "middle" / "ring" / "pinky": [curl at the knuckle, at the middle joint, at the last joint,
## spread]; "thumb": [curl, spread, roll, curl at its second joint, at its last]. A missing finger stays as it was.
## Every finger bone has +Y down the finger and +Z out of its back, so a curl is a turn about -X on both hands and a
## spread or a roll changes sign on the left.
const DIGITS := ["index", "middle", "ring", "pinky", "thumb"]
var finger_pose := {"R": {}, "L": {}}
## How fast the fingers go to a new pose (1/s).
var finger_rate := 16.0

## A pistol in both hands: the left hand bone's pose in the right hand bone's frame, and how much of it is used.
var left_on_right := Transform3D.IDENTITY
var left_on_right_weight := 0.0

var _bones := {}
var _fingers := {}
var _finger_now := {"R": {}, "L": {}}

func _bone_ids(skeleton: Skeleton3D) -> bool:
	if not _bones.is_empty():
		return true
	for side: String in SIDES:
		var ids := [skeleton.find_bone("upper_arm." + side), skeleton.find_bone("forearm." + side), skeleton.find_bone("hand." + side)]
		if ids.has(-1):
			return false
		_bones[side] = ids
	return true

func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or not _bone_ids(skeleton):
		return
	for side: String in SIDES:
		var ids: Array = _bones[side]
		var upper := skeleton.get_bone_global_pose(ids[0])
		var fore := skeleton.get_bone_global_pose(ids[1])
		var hand := skeleton.get_bone_global_pose(ids[2])
		clip_hand[side] = hand
		var target: Transform3D = delta_pose * hand
		var weight := float(socket_weight[side])
		if weight > 0.0:
			target = target.interpolate_with(socket[side], clampf(weight, 0.0, 1.0))
		if side == "L" and left_on_right_weight > 0.0:
			target = target.interpolate_with((solved_hand["R"] as Transform3D) * left_on_right, clampf(left_on_right_weight, 0.0, 1.0))
		var shoulder := upper.origin
		var upper_length := (fore.origin - upper.origin).length()
		var fore_length := (hand.origin - fore.origin).length()
		var reach := target.origin - shoulder
		var far := upper_length + fore_length
		var distance := clampf(reach.length(), absf(upper_length - fore_length) + .002, far - .002)
		stretch[side] = clampf(reach.length() / far, 0.0, 1.0)
		var toward := reach.normalized() if reach.length() > .0001 else Vector3.FORWARD
		# The elbow sits on the circle where the two bone lengths meet, on the side the pole points to.
		var along := (upper_length * upper_length - fore_length * fore_length + distance * distance) / (2.0 * distance)
		var out := sqrt(maxf(upper_length * upper_length - along * along, 0.0))
		var clip_bend := (fore.origin - shoulder).slide(toward)
		var pole_bend := (pole[side] as Vector3).slide(toward)
		var bend := pole_bend.normalized()
		if clip_bend.length() > .001:
			bend = (bend * (1.0 - clip_elbow) + clip_bend.normalized() * clip_elbow)
		if bend.length() < .001:
			bend = Vector3.DOWN.slide(toward)
		bend = bend.normalized()
		var elbow := shoulder + toward * along + bend * out
		var wrist := shoulder + toward * distance
		var upper_swing := _swing((fore.origin - shoulder).normalized(), (elbow - shoulder).normalized())
		var fore_swing := _swing((hand.origin - fore.origin).normalized(), (wrist - elbow).normalized())
		var fore_basis := fore_swing * fore.basis
		# The forearm turns part of the way with the hand, so the wrist does not wring like a cloth.
		var carried := (fore_swing * hand.basis).orthonormalized()
		var relative := (target.basis.orthonormalized() * carried.inverse()).get_rotation_quaternion()
		var axis := (wrist - elbow).normalized()
		var twist := 2.0 * atan2(Vector3(relative.x, relative.y, relative.z).dot(axis), relative.w)
		twist = wrapf(twist, -PI, PI) * forearm_twist
		fore_basis = Basis(axis, twist) * fore_basis
		skeleton.set_bone_global_pose(ids[0], Transform3D(upper_swing * upper.basis, shoulder))
		skeleton.set_bone_global_pose(ids[1], Transform3D(fore_basis, elbow))
		var placed := Transform3D(target.basis, wrist)
		skeleton.set_bone_global_pose(ids[2], placed)
		solved_hand[side] = placed
	_pose_fingers(skeleton, _delta)

func _finger_ids(skeleton: Skeleton3D) -> void:
	if not _fingers.is_empty():
		return
	for side: String in SIDES:
		var found := {}
		for digit: String in DIGITS:
			var ids := []
			for k in 3:
				var id := skeleton.find_bone("%s.%02d.%s" % [digit, k + 1, side])
				if id >= 0:
					ids.append([id, skeleton.get_bone_rest(id).basis.get_rotation_quaternion()])
			if ids.size() == 3:
				found[digit] = ids
		_fingers[side] = found

func has_fingers() -> bool:
	return not _fingers.is_empty() and not (_fingers.get("R", {}) as Dictionary).is_empty()

## The fingers go to what `finger_pose` asks, each joint easing there.
func _pose_fingers(skeleton: Skeleton3D, delta: float) -> void:
	_finger_ids(skeleton)
	var k := 1.0 - exp(-finger_rate * maxf(delta, 0.0)) if delta > 0.0 else 1.0
	for side: String in SIDES:
		var sign := 1.0 if side == "R" else -1.0
		var bones: Dictionary = _fingers[side]
		var want: Dictionary = finger_pose[side]
		var now: Dictionary = _finger_now[side]
		for digit: String in bones:
			var size := 5 if digit == "thumb" else 4
			var value: Array = now.get(digit, [])
			if value.size() != size:
				value = []
				value.resize(size)
				value.fill(0.0)
			var target: Array = want.get(digit, value)
			for i in size:
				value[i] = lerpf(float(value[i]), float(target[i]) if i < target.size() else 0.0, k)
			now[digit] = value
			var ids: Array = bones[digit]
			if digit == "thumb":
				var first := Quaternion(Vector3.BACK, deg_to_rad(float(value[1])) * sign) * Quaternion(Vector3.UP, deg_to_rad(float(value[2])) * sign) \
					* Quaternion(Vector3.RIGHT, -deg_to_rad(float(value[0])))
				skeleton.set_bone_pose_rotation(ids[0][0], (ids[0][1] as Quaternion) * first)
				skeleton.set_bone_pose_rotation(ids[1][0], (ids[1][1] as Quaternion) * Quaternion(Vector3.RIGHT, -deg_to_rad(float(value[3]))))
				skeleton.set_bone_pose_rotation(ids[2][0], (ids[2][1] as Quaternion) * Quaternion(Vector3.RIGHT, -deg_to_rad(float(value[4]))))
			else:
				var first := Quaternion(Vector3.BACK, deg_to_rad(float(value[3])) * sign) * Quaternion(Vector3.RIGHT, -deg_to_rad(float(value[0])))
				skeleton.set_bone_pose_rotation(ids[0][0], (ids[0][1] as Quaternion) * first)
				skeleton.set_bone_pose_rotation(ids[1][0], (ids[1][1] as Quaternion) * Quaternion(Vector3.RIGHT, -deg_to_rad(float(value[1]))))
				skeleton.set_bone_pose_rotation(ids[2][0], (ids[2][1] as Quaternion) * Quaternion(Vector3.RIGHT, -deg_to_rad(float(value[2]))))

## The fingers are where they are asked to be at once (a weapon coming up, a capture).
func snap_fingers() -> void:
	for side: String in SIDES:
		_finger_now[side] = (finger_pose[side] as Dictionary).duplicate(true)

## The smallest turn that takes one direction to another.
static func _swing(from: Vector3, to: Vector3) -> Basis:
	var d := from.dot(to)
	if d > .999999:
		return Basis.IDENTITY
	if d < -.999999:
		var side := from.cross(Vector3.UP)
		if side.length() < .001:
			side = from.cross(Vector3.RIGHT)
		return Basis(side.normalized(), PI)
	return Basis(Quaternion(from, to))
