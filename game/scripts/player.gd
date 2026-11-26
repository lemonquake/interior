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
## 0.33 slow walk (hold Ctrl): heel to toe, hardly a sound (scripts/senses.gd).
const SNEAK_SPEED := 1.05
const SNEAK_STEP := .62
## Metres travelled per footstep: an adult stride, about 2.3 steps/s walking and 3 steps/s running.
const WALK_STEP := 1.05
const RUN_STEP := 1.55
const CROUCH_STEP := .7
## Head bob: vertical drop at each heel strike, side-to-side sway over a left/right pair, roll.
## 0.26: 55 % less than before (it was .034 / .022 / .011). Options: Head bob Default / Low (a further 25 % less) / Off.
const BOB_HEIGHT := .0153
const BOB_SWAY := .0099
const BOB_ROLL := .005
## 0.26 body camera: the lens leans into a turn and into a sidestep, and is never perfectly still.
const TURN_ROLL := .022             # rad of lean per rad/s of turning
const TURN_ROLL_MAX := .1
const PUNCH_OMEGA := 34.0           # the lens' recoil spring: about a fifth of a second a swing
const PUNCH_DAMPING := .5
const PUNCH_MAX := .2
const STRAFE_ROLL := .0075          # rad of lean per m/s sideways
const TREMOR := .0015               # rad, standing still
## A little heavier on the feet than before (10.5 / 13.5 / 12.0).
const GROUND_ACCELERATION := 9.4
const SPRINT_ACCELERATION := 11.5
const GROUND_BRAKING := 11.0
const AIR_ACCELERATION := 1.8
const GRAVITY := 14.0
const JUMP_SPEED := 4.8
## Highest edge the feet step over without a jump (m).
const LIP_HEIGHT := .16
const PLAYER_MASS := 78.0
const COYOTE_TIME := 0.11
const JUMP_BUFFER_TIME := 0.14
const STANDING_HEIGHT := 1.70
const CROUCH_HEIGHT := 1.00
const STANDING_EYE := 1.58
const CROUCH_EYE := 0.88
## 0.43: down in co-op (scripts/coop/session.gd sets `downed`): on the belly, the eye this low, crawling.
const DOWNED_EYE := 0.36
const DOWNED_SPEED := 0.55
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
## Hold (E) shorter than this is a tap: pick up / drop, open / close, unlock (as before 0.7).
## Held longer, it pulls: a door or gate leaf follows the view, a prop is dragged and dropped on release.
const TAP_TIME := 0.28
## 0.51: ladders anyone can climb (world): [volume, the wall's normal out toward the climber, where the top steps
## off to]. Set by whatever builds them (scripts/coop/school.gd). Facing it and pushing forward climbs, back climbs down.
static var ladders: Array = []
const LADDER_SPEED := 2.1
var on_ladder := false
## 0.68: the ladder being climbed over the top (its step-off may lie outside its volume: the hospital's duct).
var _carry: Array = []
var _ladder_off := 0.0

var camera: Camera3D
var held: InteriorObject
var target: InteriorObject
## Hinged door under the crosshair (InteriorHingedDoor) when no prop is targeted.
var door_target: Node3D
## Where the view ray met the targeted door or gate leaf (INF when aiming through an open doorway).
var door_hit := Vector3.INF
var door_hit_collider: Object
## The door or gate being pulled while Hold (E) is held down.
var pulling: Node3D
## 0.10: when set and it returns true, Hold (E / the touch button) was used by the story (dialogue) instead.
var hold_hook: Callable
## 0.41: called first whenever Hold (E / the touch button) comes up.
var release_hook: Callable
## 0.57: co-op: walking into a host-simulated prop (body, contact point, flat direction, speed) goes here.
var prop_push_hook: Callable
## 0.61: co-op school chairs (layer 32) that will not give (a heap jammed in a doorway) are waded through, as the
## infected do (figure.gd `_shove_light`): after WADE_AFTER s pressing into them and hardly moving, they stop blocking
## this player until it is clear of them. chair -> msec it may block again (once the player has stepped off it).
const WADE_AFTER := .35
var _wading := {}
var _chair_press := 0.0
var _wade_on := 0
## 0.11 (scripts/gun.gd): called on a left click / Fire before throwing; returns true when the gun took it.
var fire_hook: Callable
## Called when Hold (E) is about to act on a prop or door (the gun stays up since 0.30; the hook is kept for it).
var use_hook: Callable
## Camera kick from a shot (radians of extra pitch), easing back to 0.
var recoil := 0.0
## 0.27: a shot knocks the lens on a spring of its own (pitch, yaw, roll in radians): the pistol hardly moves it,
## the shouldered rifle shakes the whole picture. Like `recoil`, it does not scale with Options: Head bob.
var _punch := Vector3.ZERO
var _punch_velocity := Vector3.ZERO
var _hold_down := false
var _hold_down_time := 0.0
var _grabbed_on_press := false
var _pull_distance := 1.2
var _pull_anchor := Vector3.ZERO
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
var downed := false
var sneaking := false
var touch_sneaking := false
## 0.34: a finger held on the phone's Bind button (scripts/mobile_controls.gd, scripts/body.gd).
var touch_binding := false
## 0.23: a cutscene has the camera (scripts/stranger_cutscene.gd): no moving, looking or using things.
var cutscene := false
## 0.20 debug menu (scripts/debug_menu.gd): a walk/run speed multiplier, and noclip flight (no collision, no gravity;
## WASD along the view, Space up, C down, Shift faster).
var debug_speed := 1.0
var noclip := false:
	set(value):
		noclip = value
		velocity = Vector3.ZERO
		if _collision != null:
			_collision.disabled = value or _teleport_frames > 0
var sensitivity := 0.0022
## Presentation only: 1 = normal, .3 = reduced, 0 = no movement from the camera.
## Crouch height and recoil remain independent so controls and weapon feedback stay consistent.
var camera_motion := 1.0:
	set(value):
		camera_motion = clampf(value, 0.0, 1.0)
		if camera != null and is_zero_approx(camera_motion):
			camera.fov = _base_fov
			camera.rotation.z = 0.0
			_lens_set = camera.rotation
			_sync_camera(global_position)
var throw_charge := 0.0
var charging_throw := false
## 0.26 free aim (scripts/gun.gd sets it while the pistol is up): the mouse moves the muzzle first, inside
## `aim_limit` (yaw, pitch, radians either side); the view follows it at `aim_follow` per second, and is dragged
## along at once when the muzzle reaches the edge. `aim_offset` is where the muzzle points relative to the lens.
var free_aim := false
var aim_offset := Vector2.ZERO
var aim_limit := Vector2(.2, .125)
var aim_follow := 4.6
## Degrees added to the lens' field of view (the sights coming up narrow it), and a walking-pace multiplier.
var fov_offset := 0.0
var pace_scale := 1.0
## 0.29 (the sniper's scope, scripts/gun.gd): how fast the field of view follows, how much of the mouse reaches the
## view (a scope slows it by its power), how much of the hand-held tremor is left, and the breath: a turn of the
## lens (yaw, pitch, radians) that the round follows.
var fov_rate := 5.0
var look_scale := 1.0
var tremor_scale := 1.0
var lens_sway := Vector2.ZERO
var _turn_input := 0.0
var _turn_rate := 0.0
var _lean := 0.0
var _bob_roll := 0.0
var _tremor_time := 0.0
var _jolt := 0.0
## 0.60: the shake of being hit (InteriorHurtFeedback): 0..1, dies away in about 0.4 s.
var _shake := 0.0
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
## Landing compression is separate from footsteps so it settles without erasing the next stride.
var _landing_offset := 0.0
## The lens rotation this script last wrote (see _body_camera).
var _lens_set := Vector3.INF
var lip_climb := not "--no-lip" in OS.get_cmdline_user_args()
## Eye lag after a stepped-over lip (m, negative), eased back to zero.
var _lip_offset := 0.0
var _landing_velocity := 0.0
var _breath_phase := 0.0
var _breath_offset := 0.0
## The desired planar velocity this tick (input direction x speed), before collisions.
var wish_velocity := Vector3.ZERO
## 0.33 movement. Z / X lean the head and shoulders round a corner. Space in front of something between knee and
## chest height climbs onto it (a jump first reaches higher); a low wall too thin to stand on is gone over.
const PEEK_REACH := .36             # m the eye goes sideways
const PEEK_ROLL := .15              # rad
const MANTLE_LOW := .42             # below this the feet simply step or jump
const MANTLE_HIGH := 1.3            # from the ground: chest height
const MANTLE_AIR := 1.05            # off a jump: what the hands still catch above the feet
const VAULT_HIGH := 1.05
const VAULT_DROP := 1.0             # never over a wall with a long fall behind it (nor, from a perch, over the town's walls)
signal mantled(height: float, over: bool)
var peek := 0.0
var touch_peek := 0.0
var mantling := false
var mantle_enabled := not "--no-mantle" in OS.get_cmdline_user_args()
## Something else has the hands (binding a wound, scripts/body.gd): the gun is down and does not fire.
var hands_busy := false
var is_sprinting := false
## 0.33 the body in danger (scripts/body.gd sets these). `limp` 0..1: the leg on `limp_side` takes short, hard
## steps and the pace drops; at 1 there is no running. `winded` 0..1: out of breath, the run slows. `strain` 0..1
## shakes the lens and the hands. `stumble` (s): a hard landing or a blow takes the pace for a moment.
var limp := 0.0
var limp_side := 1.0
var can_run := true
var winded := 0.0
var strain := 0.0
var stumble := 0.0
var _thrown := Vector3.ZERO
var _mantle := {}
var _mantle_eye := 0.0
var _mantle_tilt := Vector3.ZERO
var _limp_pitch := 0.0
var _crouch_shape: CapsuleShape3D
var _spawn_position := Vector3(0, 0.15, 2.0)

func _ready() -> void:
	collision_layer = 1
	# (0.57: 32 = the co-op school's chairs, scripts/coop/school_props.gd; nothing else uses it.)
	collision_mask = 6 | 32
	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.24
	_capsule.height = STANDING_HEIGHT
	_collision = CollisionShape3D.new()
	_collision.shape = _capsule
	_collision.position.y = STANDING_HEIGHT * 0.5
	add_child(_collision)
	_standing_shape = _capsule.duplicate() as CapsuleShape3D
	_crouch_shape = _capsule.duplicate() as CapsuleShape3D
	_crouch_shape.height = CROUCH_HEIGHT
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
	InteriorLoadClock.later(_save_spawn)

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
	var eye := _eye_y + (_eye_offset + _landing_offset + _breath_offset) * camera_motion + _lip_offset + _mantle_eye - absf(peek) * .16
	var sway := _sway * camera_motion + peek
	if origin.is_equal_approx(global_position):
		camera.position = Vector3(sway, eye, 0.0)
	else:
		camera.global_position = origin + global_basis.x * sway + Vector3.UP * eye

func _process(delta: float) -> void:
	if playing:
		_sync_camera(get_global_transform_interpolated().origin)
		if recoil != 0.0:
			recoil = move_toward(recoil, 0.0, deg_to_rad(6.4) * delta)
			if _lens_set.is_finite() and camera.rotation.is_equal_approx(_lens_set):
				camera.rotation.x = _look_pitch + recoil
				_lens_set = camera.rotation
		if not cutscene:
			_follow_aim(delta)
			_body_camera(delta)
		else:
			# The film moves the lens itself; the view snaps back to the body when it ends.
			_lens_set = Vector3.INF

## The view catches up with the muzzle (free aim), or takes back what is left of the offset once the gun is away.
func _follow_aim(delta: float) -> void:
	if aim_offset == Vector2.ZERO:
		return
	var step := aim_offset * (1.0 - exp(-(aim_follow if free_aim else 14.0) * delta))
	if aim_offset.length_squared() < 1e-9:
		step = aim_offset
	aim_offset -= step
	_turn(step)
	aim_offset.y = clampf(aim_offset.y, -1.42 - _look_pitch, 1.42 - _look_pitch)

## Lean into turns and sidesteps, a hand-held tremor that grows with speed, and the jolt of a shot or a landing.
## All of it scales with `camera_motion` (Options: Head bob), and none of it moves where the body is.
func _body_camera(delta: float) -> void:
	# Something aimed the lens directly since the last frame (a test, a staged shot): keep where it points.
	if _lens_set.is_finite() and not camera.rotation.is_equal_approx(_lens_set):
		if absf(camera.rotation.x - _lens_set.x) > 1e-5:
			_look_pitch = clampf(camera.rotation.x - recoil, -1.42, 1.42)
		if absf(camera.rotation.y - _lens_set.y) > 1e-4:
			rotate_y(camera.rotation.y)
	_turn_rate = lerpf(_turn_rate, _turn_input / maxf(delta, .0001), 1.0 - exp(-14.0 * delta))
	_turn_input = 0.0
	var sideways := (global_basis.inverse() * velocity).x
	var lean := clampf(_turn_rate * TURN_ROLL, -TURN_ROLL_MAX, TURN_ROLL_MAX) - sideways * STRAFE_ROLL
	_lean = lerpf(_lean, lean, 1.0 - exp(-7.0 * delta))
	_tremor_time += delta
	_jolt *= exp(-9.0 * delta)
	_shake = maxf(_shake - delta * 2.6, 0.0)
	# The recoil spring, in steps short enough to stay true at any frame rate.
	if _punch != Vector3.ZERO or _punch_velocity != Vector3.ZERO:
		var left := minf(delta, .05)
		while left > 0.0:
			var h := minf(left, .004)
			left -= h
			_punch_velocity += (-_punch * PUNCH_OMEGA * PUNCH_OMEGA - _punch_velocity * 2.0 * PUNCH_DAMPING * PUNCH_OMEGA) * h
			_punch += _punch_velocity * h
		_punch = _punch.clamp(Vector3.ONE * -PUNCH_MAX, Vector3.ONE * PUNCH_MAX)
		if _punch.length_squared() < 1e-9 and _punch_velocity.length_squared() < 1e-7:
			_punch = Vector3.ZERO
			_punch_velocity = Vector3.ZERO
	var pace := clampf(Vector2(velocity.x, velocity.z).length() / RUN_SPEED, 0.0, 1.0)
	var amount := (TREMOR * (1.0 + 2.4 * pace) * (1.0 + 2.2 * strain) + _jolt) * .55
	var t := _tremor_time
	var tremor := Vector3(sin(t * 1.93) + .6 * sin(t * 4.37 + 1.2) + .3 * sin(t * 9.1 + .4),
		sin(t * 1.51 + 2.0) + .6 * sin(t * 3.83) + .3 * sin(t * 8.3 + 2.2),
		sin(t * 1.27 + .7) + .5 * sin(t * 5.3 + 1.9)) * amount
	tremor *= tremor_scale
	if _shake > 0.0:
		# A quick, small shudder (at most ~0.6 degrees), fast enough to read as a hit, not a sway.
		var k := _shake * _shake * .011
		tremor += Vector3(sin(t * 61.0) + .5 * sin(t * 97.0), sin(t * 53.0 + 1.3) + .5 * sin(t * 89.0), .6 * sin(t * 47.0 + .7)) * k / maxf(camera_motion, .35)
	# (The lean round a corner, the fold over a ledge and the bad leg's dip are the body's, not the Head bob option's.)
	camera.rotation = Vector3(_look_pitch + recoil + _punch.x + tremor.x * camera_motion + lens_sway.y + _mantle_tilt.x + _limp_pitch * maxf(camera_motion, .5),
		_punch.y + tremor.y * camera_motion + lens_sway.x,
		_punch.z + (_bob_roll + _lean + tremor.z) * camera_motion + _mantle_tilt.z - peek / PEEK_REACH * PEEK_ROLL)
	_lens_set = camera.rotation

## 0.60: being hit (InteriorHurtFeedback.hit): severity 0..1.
func shake(severity: float) -> void:
	_shake = clampf(maxf(_shake, severity), 0.0, 1.0)

## A knock to the lens (radians of tremor that dies away in about a fifth of a second): a shot, a hard landing.
## 0.53: thrown by a blow (Heavy-arm): carried along `push` (m/s), off the ground if it has an upward part, the
## feet unsteady for a moment. It dies away on its own.
func throw_back(push: Vector3) -> void:
	_thrown = Vector3(push.x, 0.0, push.z)
	if push.y > 0.0:
		velocity.y = maxf(velocity.y, push.y)
	stumble = maxf(stumble, .7)

func jolt(amount: float) -> void:
	_jolt = minf(_jolt + amount, .03)

## A shot's knock to the lens: an impulse (rad/s: pitch up, yaw left, roll) on the recoil spring.
func punch(impulse: Vector3) -> void:
	_punch_velocity += impulse

## Where the muzzle points: the lens, turned by the free-aim offset.
func aim_basis() -> Basis:
	return camera.global_basis * Basis(Vector3.UP, aim_offset.x) * Basis(Vector3.RIGHT, aim_offset.y)

func _turn(turn: Vector2) -> void:
	if turn == Vector2.ZERO:
		return
	rotate_y(turn.x)
	_turn_input += turn.x
	_look_pitch = clampf(_look_pitch + turn.y, -1.42, 1.42)
	camera.rotation.x = _look_pitch + recoil
	_lens_set = camera.rotation

## A shot kicks the view up by `degrees`; it comes back down over about 0.25 s.
func kick(degrees: float) -> void:
	recoil = minf(recoil + deg_to_rad(degrees), deg_to_rad(4.0))
	camera.rotation.x = _look_pitch + recoil
	_lens_set = camera.rotation

func look(motion: Vector2) -> void:
	if not playing or cutscene or not motion.is_finite():
		return
	var turn := Vector2(-motion.x, -motion.y) * sensitivity * look_scale
	if free_aim:
		# The muzzle moves first; past the edge of its free zone the body turns with it at once.
		aim_offset += turn
		var over := Vector2(aim_offset.x / aim_limit.x, aim_offset.y / aim_limit.y)
		if over.length_squared() > 1.0:
			var edge := over.normalized()
			turn = Vector2((over.x - edge.x) * aim_limit.x, (over.y - edge.y) * aim_limit.y)
			aim_offset = Vector2(edge.x * aim_limit.x, edge.y * aim_limit.y)
		else:
			turn = Vector2.ZERO
	_turn(turn)

## Turns the held object relative to the view (R + mouse, or touch drag).
func rotate_held(delta: Vector2) -> void:
	if not is_instance_valid(held) or not delta.is_finite():
		return
	var turn := Basis(Vector3.UP, delta.x * 0.008) * Basis(Vector3.RIGHT, delta.y * 0.008)
	_hold_relative = (turn * _hold_relative).orthonormalized()
	held.sleeping = false

func _unhandled_input(event: InputEvent) -> void:
	if not playing or cutscene:
		return
	if get_parent().get("mobile") == true and (event is InputEventMouseMotion or event is InputEventMouseButton):
		return
	if get_parent().get("capturing") == true and event is InputEventMouse:
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
		hold_pressed()
	elif event.is_action_released("hold"):
		hold_released()
	if (event.is_action_pressed("fire") or event.is_action_pressed("throw")) and fire_hook.is_valid() and fire_hook.call():
		pass  # the drawn gun took the click (scripts/gun.gd)
	elif event.is_action_pressed("throw") and is_instance_valid(held):
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
	if fire_hook.is_valid() and fire_hook.call():
		return
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
	# The courtyard below the balcony is at y=-2.9 and the canal riverbed at -6.6 (0.17); only a real
	# fall out of the world resets.
	if not global_position.is_finite() or not velocity.is_finite() or global_position.y < -12.0:
		reset_motion(_spawn_position)
		return
	if noclip:
		_fly(delta)
		return
	if cutscene:
		# Held where they stand while the film plays; gravity still applies.
		velocity = Vector3(0.0, velocity.y - GRAVITY * delta if not is_on_floor() else 0.0, 0.0)
		move_and_slide()
		return
	if mantling:
		_mantle_tick(delta)
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
	if not ladders.is_empty() and _ladder(axis, direction, delta):
		return
	sneaking = touch_sneaking or (InputMap.has_action("sneak") and Input.is_action_pressed("sneak"))
	var sprinting := (Input.is_action_pressed("run") or touch_sprinting) and not crouching and pace_scale > .99 and not sneaking \
		and can_run and not hands_busy and absf(peek) < .06
	is_sprinting = sprinting and axis.length_squared() > .01
	_update_peek(delta, grounded)
	# Out of breath the run slows to a jog; a bad leg takes a fifth off it, and more off the walk.
	var run_speed := lerpf(RUN_SPEED, 3.5, winded) * (1.0 - .2 * limp)
	var speed := (CROUCH_SPEED if crouching else (run_speed if sprinting else WALK_SPEED * (1.0 - .3 * limp))) * debug_speed * pace_scale
	if sneaking:
		speed = (CROUCH_SPEED * .7 if crouching else SNEAK_SPEED) * debug_speed * pace_scale
	if downed:
		speed = DOWNED_SPEED * debug_speed
	speed *= 1.0 - .45 * absf(peek) / PEEK_REACH
	if stumble > 0.0:
		stumble = maxf(0.0, stumble - delta)
		speed *= lerpf(1.0, .3, clampf(stumble / .3, 0.0, 1.0))
	if limp > 0.0 and _on_bad_leg():
		# The weight comes off the bad leg as fast as it can: the pace sags while that foot carries it.
		speed *= 1.0 - .5 * limp * sin(_bob_phase * PI)
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
	if _thrown.length_squared() > .01:
		velocity.x += _thrown.x
		velocity.z += _thrown.z
		_thrown = _thrown.move_toward(Vector3.ZERO, (9.0 if grounded else 3.0) * delta)
	if not crouching and (_jump_buffer > 0.0 or (not grounded and velocity.y < 2.2 and axis.y < -.3 and InputMap.has_action("jump") and Input.is_action_pressed("jump"))) \
			and _try_mantle(grounded):
		_jump_buffer = 0.0
		return
	if _jump_buffer > 0.0 and _coyote_left > 0.0 and not crouching:
		velocity.y = JUMP_SPEED * (1.0 - .32 * limp)
		# The legs push off: the eye dips a little before it rises.
		_landing_velocity = minf(_landing_velocity, -.22)
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
	var before := global_position
	move_and_slide()
	if grounded and axis.length_squared() > 0.001:
		_climb_lip(before, direction.normalized() * speed * axis.length(), delta)
	if is_on_floor() and not grounded and falling_speed < -1.2:
		landed.emit(InteriorSurfaces.under(self), falling_speed)
		# A landing plants a foot: restart the stride from a heel strike.
		_bob_phase = 0.0
		_landing_velocity = -clampf((-falling_speed - 1.2) * .13, 0.0, .85)
		jolt(clampf((-falling_speed - 1.2) * .0022, 0.0, .012))
	_push_contacts(approach_velocity, delta)
	_update_camera(delta, sprinting)
	if charging_throw:
		throw_charge = minf(1.0, throw_charge + delta / THROW_CHARGE_TIME)
	update_target()
	update_hold(delta)
	_update_pull(delta)

## 0.51: on a ladder (`ladders`): forward climbs, back goes down, no gravity while on it; at the top the body is
## carried over the edge to the ladder's step-off spot. Off at the bottom by walking back onto the floor.
func _ladder(axis: Vector2, direction: Vector3, delta: float) -> bool:
	_ladder_off = maxf(0.0, _ladder_off - delta)
	var found: Array = []
	if not _carry.is_empty(): found = _carry
	elif not downed and _ladder_off <= 0.0:
		for l: Array in ladders:
			if (l[0] as AABB).has_point(global_position + Vector3.UP * .3):
				found = l
				break
	if found.is_empty():
		on_ladder = false
		return false
	var into: Vector3 = -(found[1] as Vector3)
	var box: AABB = found[0]
	var top: float = box.end.y - 1.2
	if not on_ladder:
		var toward := direction.normalized().dot(into) if direction.length_squared() > .0001 else 0.0
		if toward < .45 or axis.length() < .2:
			return false
		on_ladder = true
	# Looking down the hatch, forward goes down.
	var climb := -axis.y
	if camera != null and -camera.global_basis.z.y < -.45:
		climb = -climb
	if not _carry.is_empty() or (global_position.y >= top - .05 and climb > .1):
		_carry = found
		# Over the top: up and onto the floor beside the hatch.
		var off: Vector3 = found[2]
		# 0.68: into a space too low to stand in (the hospital's duct): crouched, as a body has to be to fit there.
		if not crouching and not _fits(off + Vector3.UP * .05, _standing_shape) and _fits(off + Vector3.UP * .05, _crouch_shape):
			crouching = true
			_capsule.height = CROUCH_HEIGHT
			_collision.position.y = CROUCH_HEIGHT * .5
		global_position = global_position.move_toward(off + Vector3.UP * .05, 2.4 * delta)
		velocity = Vector3.ZERO
		if Vector2(global_position.x - off.x, global_position.z - off.z).length() < .12:
			on_ladder = false
			_ladder_off = .6
			_carry = []
		_update_camera(delta, false)
		update_target()
		update_hold(delta)
		return true
	if is_on_floor() and climb < -.1:
		on_ladder = false
		_ladder_off = .5
		return false
	# Held to the rungs: up and down only, drawn onto the ladder's line (through the hatch without catching its edge).
	var line := Vector3(box.get_center().x, global_position.y, box.end.z - .45)
	global_position = global_position.lerp(line, 1.0 - exp(-10.0 * delta))
	velocity = Vector3.UP * climb * LADDER_SPEED
	move_and_slide()
	_update_camera(delta, false)
	update_target()
	update_hold(delta)
	return true

## 0.26: a low lip the feet should simply step over (the 7 cm edge where the balcony stair meets its landing, the
## end of a ramp, a kerb, a door sill). move_and_slide only rides over one with momentum: arriving slowly, or
## turning into it, left the body pressed against it for good. When a step forward was blocked, try it again from
## LIP_HEIGHT higher and settle onto whatever fixed floor is there. Never onto loose props, never off an edge.
func _climb_lip(before: Vector3, wish: Vector3, delta: float) -> void:
	if not is_on_floor() or wish.length_squared() < .04 or not lip_climb:
		return
	var forward := wish.normalized()
	var moved := global_position - before
	if Vector3(moved.x, 0.0, moved.z).dot(forward) > wish.length() * delta * .4:
		return
	var here := global_transform
	if test_move(here, Vector3.UP * LIP_HEIGHT):
		return
	var raised := here.translated(Vector3.UP * LIP_HEIGHT)
	var reach := forward * maxf(.1, wish.length() * delta * 2.0)
	if test_move(raised, reach):
		return
	var landing := KinematicCollision3D.new()
	if not test_move(raised.translated(reach), Vector3.DOWN * (LIP_HEIGHT + .04), landing):
		return
	if landing.get_normal().y < cos(floor_max_angle) or not landing.get_collider() is StaticBody3D:
		return
	var rise := LIP_HEIGHT + landing.get_travel().y
	if rise < .004:
		return
	global_position = raised.origin + reach + landing.get_travel()
	# The eye catches up over a few frames instead of popping.
	_lip_offset -= rise
	velocity.x = wish.x
	velocity.z = wish.z

## Hold (E) went down: drop what is held, use the TV, take hold of a door or gate leaf, or pick up.
func hold_pressed() -> void:
	if hold_hook.is_valid() and hold_hook.call():
		return
	if use_hook.is_valid():
		use_hook.call()
	_hold_down = true
	_hold_down_time = Time.get_ticks_msec() / 1000.0
	_grabbed_on_press = false
	if held != null:
		release_object()
		return
	update_target()
	if target == null and door_target != null and door_hit.is_finite() and door_target.has_method("grab"):
		pulling = door_target
		pulling.call("grab", door_hit, door_hit_collider)
		_pull_anchor = door_hit
		_pull_distance = clampf(camera.global_position.distance_to(door_hit), HOLD_MIN_DISTANCE, REACH)
		return
	toggle_hold()
	_grabbed_on_press = held != null

## Hold (E) came up: a short press was a tap (toggle the door, unlock the gate, keep carrying);
## after a long press, a pulled leaf swings on by itself and a dragged prop is let go.
func hold_released() -> void:
	# 0.41: co-op lets go of a dragged table here (the hold itself went to `hold_hook`).
	if release_hook.is_valid():
		release_hook.call()
	if not _hold_down:
		return
	_hold_down = false
	var duration := Time.get_ticks_msec() / 1000.0 - _hold_down_time
	if pulling != null:
		var door := pulling
		pulling = null
		if not is_instance_valid(door):
			return
		var moved := float(door.call("release"))
		if duration < TAP_TIME and moved < .05:
			door.call("toggle")
		return
	if _grabbed_on_press and duration >= TAP_TIME and is_instance_valid(held):
		release_object()
	_grabbed_on_press = false

func is_pulling() -> bool:
	return pulling != null and is_instance_valid(pulling)

func _update_pull(delta: float) -> void:
	if pulling == null:
		return
	# Walked off (or the leaf swung away): let go once the hand is far from where it took hold.
	if not is_instance_valid(pulling) or camera.global_position.distance_to(_pull_anchor) > REACH + 1.8:
		if is_instance_valid(pulling):
			pulling.call("release")
		pulling = null
		return
	pulling.call("drag_to", camera.global_position - camera.global_basis.z * _pull_distance, delta)

## Z / X: the head and shoulders go sideways, never through what is beside them.
func _update_peek(delta: float, grounded: bool) -> void:
	var wish := touch_peek
	if InputMap.has_action("lean_left"):
		wish += Input.get_action_strength("lean_right") - Input.get_action_strength("lean_left")
	if not grounded or is_sprinting or is_instance_valid(held):
		wish = 0.0
	var goal := clampf(wish, -1.0, 1.0) * PEEK_REACH
	if absf(goal) > .001:
		var eye := global_position + Vector3.UP * _eye_y
		var side := global_basis.x * signf(goal)
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + side * (absf(goal) + .2), collision_mask, [get_rid()]))
		if hit:
			goal = signf(goal) * maxf(0.0, eye.distance_to(hit.position) - .2)
	peek = lerpf(peek, goal, 1.0 - exp(-(9.0 if absf(goal) > absf(peek) else 12.0) * delta))
	if absf(goal) < .001 and absf(peek) < .0008:
		peek = 0.0

func _on_bad_leg() -> bool:
	return (1.0 if _step_count % 2 == 0 else -1.0) == limp_side

func _fits(at: Vector3, shape: CapsuleShape3D) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * (shape.height * .5 + .03))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

## Space with something solid in front: is there a top the hands can reach, and room for the body on it (a climb)
## or ground just beyond it (a vault)? Only the fixed world counts; nothing loose is climbed.
func _try_mantle(grounded: bool) -> bool:
	if mantling or noclip or not mantle_enabled or is_instance_valid(held) or is_pulling() or hands_busy:
		return false
	var forward := -global_basis.z
	forward.y = 0.0
	if forward.length_squared() < .01:
		return false
	forward = forward.normalized()
	var feet := global_position
	var space := get_world_3d().direct_space_state
	var mask := 2
	var reach_up := (MANTLE_HIGH if grounded else MANTLE_AIR) * (1.0 - .35 * limp)
	var wall := INF
	for h: float in [.22, .45, .7, .95, 1.2]:
		if h > reach_up:
			break
		var from := feet + Vector3.UP * h
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + forward * .72, mask))
		if hit and absf((hit.normal as Vector3).y) < .6:
			wall = minf(wall, from.distance_to(hit.position))
	if wall == INF:
		return false
	var d := wall + .1
	var above := feet + Vector3.UP * (reach_up + .3)
	# Taller than the hands reach, or no room over the head to go up?
	if space.intersect_ray(PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 1.0, above, mask)):
		return false
	if space.intersect_ray(PhysicsRayQueryParameters3D.create(above, above + forward * d, mask)):
		return false
	var top := space.intersect_ray(PhysicsRayQueryParameters3D.create(above + forward * d, feet + forward * d + Vector3.UP * .15, mask))
	if top.is_empty() or (top.normal as Vector3).y < .7 or not top.collider is StaticBody3D:
		return false
	# Never onto one of the world's unseen walls.
	if InteriorSurfaces.unseen(top.collider, int(top.get("shape", 0))):
		return false
	var top_at: Vector3 = top.position
	var height := top_at.y - feet.y
	if height < (MANTLE_LOW if grounded else .25) or height > reach_up:
		return false
	var deep := space.intersect_ray(PhysicsRayQueryParameters3D.create(above + forward * (d + .36), feet + forward * (d + .36) + Vector3.UP * (height - .2), mask))
	var over := false
	var to := Vector3.ZERO
	if deep and (deep.normal as Vector3).y > .7 and absf((deep.position as Vector3).y - top_at.y) < .16:
		to = Vector3(feet.x, top_at.y, feet.z) + forward * (d + .24)
		var under := space.intersect_ray(PhysicsRayQueryParameters3D.create(to + Vector3.UP * .3, to + Vector3.DOWN * .2, mask))
		if under.is_empty():
			return false
		to.y = (under.position as Vector3).y
		# 0.34: wide enough to stand on, a foot's breadth either side of where the body will be. The top of a wall
		# is not: taken end-on (or off a jump, corner-wise) the lot walls and the canal's boundary walls were
		# walked along like pavements, and the far side of each is a yard, a slit or nothing at all with no way
		# back (tests/climb_integration.gd).
		var across := forward.cross(Vector3.UP).normalized()
		for side: float in [-1.0, 1.0]:
			var beside := to + across * (.24 * side)
			var foot := space.intersect_ray(PhysicsRayQueryParameters3D.create(beside + Vector3.UP * .3, beside + Vector3.DOWN * .25, mask))
			if foot.is_empty() or (foot.normal as Vector3).y < .7:
				return false
	else:
		# Only from the ground: off a jump the hands catch ledges, they do not carry the body over a wall.
		if not grounded or height > VAULT_HIGH * (1.0 - .3 * limp):
			return false
		# The far side: nothing in the way over the top, and ground not far below.
		var beyond := d + .9
		var clear := feet + Vector3.UP * (height + .4)
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(clear, clear + forward * (beyond + .3), mask)):
			return false
		var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(clear + forward * beyond, feet + forward * beyond + Vector3.DOWN * VAULT_DROP, mask))
		if ground.is_empty() or (ground.normal as Vector3).y < .7:
			return false
		to = ground.position
		over = true
		if not _fits(top_at + forward * .05, _crouch_shape):
			return false
	# 0.34: over a rail, never up onto one (InteriorSurfaces.rail).
	if not over and InteriorSurfaces.rail(top.collider, int(top.get("shape", 0))):
		return false
	var stands := _fits(to, _standing_shape)
	if not stands and (over or not _fits(to, _crouch_shape)):
		return false
	# 0.34: not onto the roofs and boundary walls that lead out of the world (InteriorSurfaces.NO_PERCH).
	if InteriorSurfaces.no_perch(to):
		return false
	if height > .6 and test_move(global_transform, Vector3.UP * (height - .5)):
		return false
	mantling = true
	velocity = Vector3.ZERO
	var time := (.5 + .22 * height) if over else (.3 + .5 * height)
	_mantle = {"from": feet, "to": to, "top": top_at.y, "height": height, "over": over, "t": 0.0, "time": time * (1.0 + .55 * limp),
		"side": 1.0 if randf() < .5 else -1.0, "planted": false, "surface": InteriorSurfaces.at(top_at + Vector3.UP * .05, get_tree())}
	if not stands:
		crouching = true
		_capsule.height = CROUCH_HEIGHT
		_collision.position.y = CROUCH_HEIGHT * .5
	return true

## The climb itself: up the face, then forward over the edge; a vault carries on down the far side. The body
## folds over the edge and unfolds: the eye sinks, the lens tips down and rolls toward the arm that took the weight.
func _mantle_tick(delta: float) -> void:
	var m := _mantle
	var t := minf(1.0, float(m.t) + delta / float(m.time))
	m.t = t
	var from: Vector3 = m.from
	var to: Vector3 = m.to
	var up := smoothstep(0.0, .62, t)
	var flat := from.lerp(to, smoothstep(.42, 1.0, t))
	var y := lerpf(from.y, to.y, up)
	if m.over:
		var crest := float(m.top) + .1
		y = lerpf(from.y, crest, up) if t < .62 else lerpf(crest, to.y, smoothstep(.62, 1.0, t))
	global_position = Vector3(flat.x, y, flat.z)
	velocity = Vector3.ZERO
	var fold := sin(t * PI)
	_mantle_eye = -fold * minf(.42, .14 + .24 * float(m.height))
	_mantle_tilt = Vector3(-fold * (.12 + .09 * float(m.height)) + sin(t * TAU) * .025, 0.0, fold * .075 * float(m.side))
	_eye_y = lerpf(_eye_y, (DOWNED_EYE if downed else CROUCH_EYE) if crouching else STANDING_EYE, 1.0 - exp(-13.0 * delta))
	_bob_weight = lerpf(_bob_weight, 0.0, 1.0 - exp(-8.0 * delta))
	_sway = lerpf(_sway, 0.0, 1.0 - exp(-8.0 * delta))
	peek = lerpf(peek, 0.0, 1.0 - exp(-12.0 * delta))
	if not m.planted and t > .13:
		m.planted = true
		# The hands come down on it.
		stepped.emit(String(m.surface), .3)
		jolt(.004)
	_sync_camera(global_position)
	if t >= 1.0:
		mantling = false
		_mantle_eye = 0.0
		_mantle_tilt = Vector3.ZERO
		_bob_phase = 0.0
		_landing_velocity = -.4 if m.over else -.28
		var axis := Input.get_vector("left", "right", "forward", "back") + touch_move
		if axis.is_finite() and axis.y < -.2:
			var forward := (to - from)
			forward.y = 0.0
			velocity = forward.normalized() * WALK_SPEED * .7
		stepped.emit(InteriorSurfaces.under(self), .62 if m.over else .5)
		mantled.emit(float(m.height), bool(m.over))

func _update_stance() -> void:
	var wants_crouch := downed or touch_crouching or (InputMap.has_action("crouch") and Input.is_action_pressed("crouch"))
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
	var leaned: Array[RigidBody3D] = []
	var pressed_chairs: Array[RigidBody3D] = []
	_unwade()
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		# 0.57: a co-op prop (the school's chairs and doors) is the host's to move: say what it is leant on with.
		var loose := hit.get_collider() as RigidBody3D
		if loose != null and loose.has_meta("coop_prop") and prop_push_hook.is_valid() and not leaned.has(loose):
			# (0.61: underfoot as well: climbed onto a heap in a doorway, the head meets the frame's top.)
			if loose.collision_layer & 32 and not pressed_chairs.has(loose): pressed_chairs.append(loose)
			var side := -hit.get_normal()
			side.y = 0.0
			var walking := Vector3(approach_velocity.x, 0.0, approach_velocity.z)
			# A chair lying on the floor is met from above (the capsule's round foot on its edge): below the knee it
			# is kicked along the way the player walks instead of being taken for something to stand on.
			if hit.get_position().y - global_position.y < .5 and walking.length_squared() > .01 and (absf(hit.get_normal().y) > .65 or side.length_squared() < .01):
				side = walking
			if (absf(hit.get_normal().y) <= .65 or side == walking) and side.length_squared() > .01:
				var speed := approach_velocity.dot(side.normalized())
				if speed > .05:
					leaned.append(loose)
					prop_push_hook.call(loose, hit.get_position(), side.normalized(), speed)
			continue
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
	# 0.61: pressing into (or standing on) school chairs and getting nowhere: walk through them.
	var walking := Vector2(approach_velocity.x, approach_velocity.z).length()
	var moving := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	if pressed_chairs.is_empty() or walking < .5 or moving > walking * .45:
		_chair_press = maxf(_chair_press - delta * 2.0, 0.0)
		return
	_chair_press += delta
	# (Once wading, the next chair of the heap does not hold the player up for another WADE_AFTER.)
	if _chair_press < WADE_AFTER and Time.get_ticks_msec() > _wade_on: return
	_wade_on = Time.get_ticks_msec() + 1200
	for chair in pressed_chairs: _wade(chair)
	# The rest of the heap round the player goes with it (a jammed doorway is many chairs on each other).
	var query := PhysicsShapeQueryParameters3D.new()
	var reach := SphereShape3D.new()
	reach.radius = 1.0
	query.shape = reach
	query.collision_mask = 32
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * .8 + Vector3(approach_velocity.x, 0, approach_velocity.z).normalized() * .5)
	for found in get_world_3d().direct_space_state.intersect_shape(query, 32):
		var chair := found.collider as RigidBody3D
		if chair != null and chair.has_meta("coop_prop"): _wade(chair)

func _wade(chair: RigidBody3D) -> void:
	if not _wading.has(chair):
		# (One already let through, the chair being dragged (session.gd `_prop_feel`), is not ours to put back.)
		if chair in get_collision_exceptions(): return
		add_collision_exception_with(chair)
	_wading[chair] = Time.get_ticks_msec() + 1500

## Chairs waded through block again once their time is up and the player is off them (never inside one).
func _unwade() -> void:
	if _wading.is_empty(): return
	var now := Time.get_ticks_msec()
	for chair: RigidBody3D in _wading.keys():
		if not is_instance_valid(chair):
			_wading.erase(chair)
			continue
		if now < int(_wading[chair]): continue
		var gap := chair.global_position - global_position
		if Vector2(gap.x, gap.z).length() < 1.1 and absf(gap.y) < 2.0:
			_wading[chair] = now + 250
			continue
		_wading.erase(chair)
		remove_collision_exception_with(chair)

func _update_camera(delta: float, sprinting: bool) -> void:
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	var grounded := is_on_floor()
	var moving := grounded and planar_speed > 0.25
	# The bob fades in and out with speed instead of snapping when walking starts or stops.
	var target_weight := clampf(planar_speed / WALK_SPEED, 0.0, 1.35) if moving else 0.0
	_bob_weight = lerpf(_bob_weight, target_weight, 1.0 - exp(-(6.0 if moving else 4.0) * delta))
	if moving:
		var stride := CROUCH_STEP if crouching else (RUN_STEP if planar_speed > (WALK_SPEED + RUN_SPEED) * .5 else WALK_STEP)
		if sneaking and not crouching:
			stride = SNEAK_STEP
		# A limp: the bad leg's step is short and quick, the good one reaches to make up for it.
		if limp > 0.0:
			stride *= lerpf(1.0, .6, limp) if _on_bad_leg() else lerpf(1.0, 1.1, limp)
		_bob_phase += planar_speed * delta / stride
		if _bob_phase >= 1.0:
			_bob_phase = fmod(_bob_phase, 1.0)
			_step_count += 1
			var strength := 0.3 if crouching else clampf(planar_speed / RUN_SPEED, 0.45, 1.0)
			if sneaking:
				strength = .08 if crouching else .12
			stepped.emit(InteriorSurfaces.under(self), strength)
	elif _bob_weight < .05:
		# Standing still: settle back to mid-stride so the next step starts cleanly.
		_bob_phase = lerpf(_bob_phase, 0.5 if _bob_phase > 0.25 else 0.0, 1.0 - exp(-3.0 * delta))
	var bob_scale := (0.45 if crouching else 1.0) * _bob_weight
	# Lowest at the heel strike (phase 0), highest at mid-stance (phase 0.5).
	var bob := -cos(_bob_phase * TAU) * BOB_HEIGHT * .5 - BOB_HEIGHT * .5
	# ...and the body drops onto the bad leg and tips over it.
	var bad := limp * sin(_bob_phase * PI) * clampf(_bob_weight, 0.0, 1.0) if limp > 0.0 and _on_bad_leg() else 0.0
	bob -= bad * .045
	_limp_pitch = lerpf(_limp_pitch, -bad * .05, 1.0 - exp(-16.0 * delta))
	# Weight shifts over the planted foot: one full sway per left/right pair of steps.
	var side := 1.0 if _step_count % 2 == 0 else -1.0
	var sway := sin(_bob_phase * PI) * side * BOB_SWAY
	_sway = sway * bob_scale
	_eye_offset = lerpf(_eye_offset, bob * bob_scale, 1.0 - exp(-18.0 * delta))
	_lip_offset = clampf(_lip_offset * exp(-16.0 * delta), -.3, 0.0)
	# Critically damped compression: no camera shake or repeated bounce after a landing.
	var spring_rate := 15.0
	var spring_term := (_landing_velocity + spring_rate * _landing_offset) * delta
	var spring_decay := exp(-spring_rate * delta)
	_landing_velocity = (_landing_velocity - spring_rate * spring_term) * spring_decay
	_landing_offset = clampf((_landing_offset + spring_term) * spring_decay, -.045, 0.0)
	# At rest, only a few millimetres of slow breathing remain. It fades while airborne.
	_breath_phase = fmod(_breath_phase + delta * TAU * .21, TAU)
	var breath := sin(_breath_phase) * .0025 * (1.0 - clampf(_bob_weight, 0.0, 1.0)) if grounded else 0.0
	_breath_offset = lerpf(_breath_offset, breath, 1.0 - exp(-4.0 * delta))
	var eye_height := (DOWNED_EYE if downed else CROUCH_EYE) if crouching else STANDING_EYE
	_eye_y = lerpf(_eye_y, eye_height, 1.0 - exp(-13.0 * delta))
	_bob_roll = -sway * bob_scale / BOB_SWAY * BOB_ROLL - bad * limp_side * .03
	if camera != null and not playing:
		camera.rotation.z = _bob_roll * camera_motion
		_lens_set = camera.rotation
	# Actual movement drives the lens: holding Run against a wall or just crossing the
	# walk-speed threshold no longer causes a four-degree jump in the target FOV.
	var run_weight := smoothstep(WALK_SPEED, RUN_SPEED, planar_speed) if sprinting and not crouching else 0.0
	var desired_fov := minf(_base_fov + 3.5 * run_weight * camera_motion, 113.5) + fov_offset
	camera.fov = lerpf(camera.fov, desired_fov, 1.0 - exp(-fov_rate * delta))
	# Physics queries this tick use the exact (non-interpolated) eye.
	_sync_camera(global_position)

## Noclip: fly where the camera looks, straight through walls.
func _fly(delta: float) -> void:
	var axis := Input.get_vector("left", "right", "forward", "back") + touch_move
	axis = axis.limit_length(1.0) if axis.is_finite() else Vector2.ZERO
	var look := camera.global_basis
	var direction := look * Vector3(axis.x, 0, axis.y)
	if Input.is_action_pressed("jump"):
		direction += Vector3.UP
	if InputMap.has_action("crouch") and Input.is_action_pressed("crouch"):
		direction += Vector3.DOWN
	var speed := (RUN_SPEED * 3.0 if Input.is_action_pressed("run") else RUN_SPEED) * debug_speed
	velocity = velocity.lerp(direction.limit_length(1.0) * speed, 1.0 - exp(-10.0 * delta))
	global_position += velocity * delta
	_update_camera(delta, false)
	update_target()
	update_hold(delta)

func _end_teleport() -> void:
	_teleport_frames -= 1
	if _teleport_frames <= 0 and _collision != null:
		_teleport_frames = 0
		_collision.disabled = noclip

func reset_motion(spawn_position: Vector3, restore_stance := true) -> void:
	release_object()
	if is_pulling():
		pulling.call("release")
	pulling = null
	_hold_down = false
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
	_landing_offset = 0.0
	_landing_velocity = 0.0
	_lip_offset = 0.0
	_breath_phase = 0.0
	_breath_offset = 0.0
	recoil = 0.0
	_punch = Vector3.ZERO
	_punch_velocity = Vector3.ZERO
	aim_offset = Vector2.ZERO
	_turn_input = 0.0
	_turn_rate = 0.0
	_lean = 0.0
	_bob_roll = 0.0
	_jolt = 0.0
	mantling = false
	_mantle_eye = 0.0
	_mantle_tilt = Vector3.ZERO
	_limp_pitch = 0.0
	peek = 0.0
	stumble = 0.0
	if camera != null:
		camera.rotation = Vector3(_look_pitch, 0.0, 0.0)
		_lens_set = camera.rotation
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
	door_hit = Vector3.INF
	door_hit_collider = null
	if next == null and hit and hit.collider is Node:
		var door := (hit.collider as Node).get_parent()
		# Doors and gates, and (0.10) the hut's key, drawer and gun ("usables": prompt_text() / toggle()).
		if door != null and (door.is_in_group("interior_doors") or door.is_in_group("usables")):
			door_target = door as Node3D
			door_hit = hit.position
			door_hit_collider = hit.collider
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
