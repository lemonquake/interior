extends SceneTree
## Contract 8.1 / 8.2 / 8.4: balls roll (not slide), slow by rolling resistance,
## stop and sleep; a ball rolls down a 10 degree ramp while a wooden box stays;
## a knocked-over bottle lies on its side and rolls.

const Common = preload("res://tests/physics_common.gd")
var checks := 0
var failures: Array[String] = []
var metrics := {}

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition and not failures.has(message):
		failures.append(message)
		push_error(message)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	Common.floor_slab(world)
	metrics["max_angular_velocity_setting"] = ProjectSettings.get_setting("physics/jolt_physics_3d/limits/max_angular_velocity", -1)
	# 1. Ball rolled at 2 m/s across a wooden floor.
	var radius := 0.11
	var ball := Common.ball(world, radius, 0.43, Vector3(0, radius, 0))
	await _frames(2)
	ball.linear_velocity = Vector3(2, 0, 0)
	var start := ball.global_position
	await _frames(30)
	var slip := Common.slip(ball, radius)
	var speed := ball.linear_velocity.length()
	metrics["slip_ratio_at_0_5s"] = slip / maxf(speed, 0.001)
	metrics["speed_at_0_5s"] = speed
	check(metrics.slip_ratio_at_0_5s < 0.10, "Ball must roll, not slide, after 0.5 s (|w r - v| < 10 %)")
	var stop_time := -1.0
	var sleep_time := -1.0
	var max_slip_late := 0.0
	for frame in 60 * 24:
		await physics_frame
		var t := 0.5 + frame / 60.0
		if stop_time < 0.0 and ball.linear_velocity.length() < 0.02:
			stop_time = t
		if ball.sleeping and sleep_time < 0.0:
			sleep_time = t
			break
		if ball.linear_velocity.length() > 0.2:
			max_slip_late = maxf(max_slip_late, Common.slip(ball, radius) / ball.linear_velocity.length())
	var travel := Vector2(ball.global_position.x - start.x, ball.global_position.z - start.z).length()
	metrics["travel_m"] = travel
	metrics["stop_time_s"] = stop_time
	metrics["sleep_time_s"] = sleep_time
	metrics["final_v"] = ball.linear_velocity.length()
	metrics["final_w"] = ball.angular_velocity
	metrics["final_y"] = ball.global_position.y
	metrics["max_slip_ratio_while_rolling"] = max_slip_late
	check(travel > 2.0, "Ball must travel more than 2 m")
	check(stop_time >= 4.0 and stop_time <= 20.0, "Ball must come to rest within 4-20 s via rolling resistance")
	check(sleep_time > 0.0 and sleep_time <= stop_time + 3.0, "Ball must fall asleep once stopped")
	check(absf(ball.global_position.y - radius) < 0.01, "Ball must stay on the floor")
	ball.queue_free()
	# 2. Ten-degree ramp: ball rolls down, wooden box stays.
	var ramp_angle := 10.0
	var ramp := Common.static_box(world, Vector3(0, 1.0, 10), Vector3(6, 0.2, 2), "wood", Vector3(0, 0, ramp_angle))
	var surface_normal := ramp.global_basis.y.normalized()
	var on_ramp := func(local_x: float, height: float) -> Vector3:
		return ramp.global_transform * Vector3(local_x, 0.1, 0) + surface_normal * height
	var ramp_ball := Common.ball(world, 0.08, 0.3, on_ramp.call(1.5, 0.08))
	var crate := Common.block(world, Vector3(0.2, 0.2, 0.2), 1.0, on_ramp.call(1.0, 0.1) + Vector3(0, 0, 0.5), "wood", Vector3(0, 0, ramp_angle))
	await _frames(2)
	var ball_start := ramp_ball.global_position
	var crate_start := crate.global_position
	await _frames(120)
	metrics["ramp_ball_travel_m"] = ramp_ball.global_position.distance_to(ball_start)
	metrics["ramp_crate_travel_m"] = crate.global_position.distance_to(crate_start)
	metrics["ramp_ball_slip_ratio"] = (ramp_ball.linear_velocity + ramp_ball.angular_velocity.cross(-surface_normal * 0.08)).length() / maxf(ramp_ball.linear_velocity.length(), 0.001)
	check(metrics.ramp_ball_travel_m > 0.8, "Ball must roll down a 10 degree ramp")
	check(metrics.ramp_ball_slip_ratio < 0.15, "Ball must roll down the ramp, not slide")
	check(metrics.ramp_crate_travel_m < 0.01, "Wooden box must stay on a 10 degree ramp (static friction)")
	ramp_ball.queue_free()
	crate.queue_free()
	# 3. Bottle knocked over lies on its side and rolls.
	var bottle := Common.prop(world, [{"kind": "cylinder", "center": [0, 0, 0], "radius": 0.035, "height": 0.26}], 0.4, "glass", Vector3(0, 0.13, -6))
	await _frames(20)
	bottle.apply_impulse(Vector3(0.35, 0, 0), Vector3(0, 0.12, 0))
	var bottle_start := bottle.global_position
	var bottle_max_speed := 0.0
	var lying_frames := 0
	for frame in 300:
		await physics_frame
		if Common.tilt_deg(bottle) > 80.0:
			lying_frames += 1
			bottle_max_speed = maxf(bottle_max_speed, bottle.rolling_speed())
	metrics["bottle_tilt_deg"] = Common.tilt_deg(bottle)
	metrics["bottle_travel_m"] = bottle.global_position.distance_to(bottle_start)
	metrics["bottle_max_rolling_speed"] = bottle_max_speed
	check(metrics.bottle_tilt_deg > 80.0, "Knocked bottle must lie on its side")
	check(bottle_max_speed > 0.05, "Knocked bottle must roll on its side")
	check(bottle.is_supported(), "Lying bottle must report support")
	print("INTERIOR_PHYSICS_ROLLING ", JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "metrics": metrics}))
	quit(0 if failures.is_empty() else 1)
