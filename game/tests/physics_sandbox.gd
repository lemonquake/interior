extends SceneTree
## RENDERED physics sandbox (run without --headless, --resolution 1280x720).
## Ball rolling across a platform, down a 10 degree ramp and over the floor; a
## block tower hit by a thrown ball; tall vase tipping vs box sliding and a
## knocked bottle rolling. Saves contact sheets to work/v3/physics/screens/.

const Common = preload("res://tests/physics_common.gd")
const OUT := "A:/3rd Harmonik/interior/work/v3/physics/screens/"
const CELL := Vector2i(533, 300)
var world: Node3D
var camera: Camera3D
var report := {}

func _initialize() -> void:
	call_deferred("_run")

func _material(color: Color, roughness := 0.6) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _visual_box(parent: Node3D, size: Vector3, color: Color, offset := Vector3.ZERO) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color)
	mesh.position = offset
	parent.add_child(mesh)

func _static(center: Vector3, size: Vector3, color: Color, rotation_deg := Vector3.ZERO) -> void:
	var body := Common.static_box(world, center, size, "wood", rotation_deg)
	_visual_box(body, size, color)

func _ball(radius: float, mass: float, position: Vector3, color: Color) -> InteriorObject:
	var ball := Common.ball(world, radius, mass, position)
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh.mesh = sphere
	mesh.material_override = _material(color, 0.45)
	ball.add_child(mesh)
	# White band and dot make the spin readable in stills.
	_visual_box(ball, Vector3(radius * 2.02, radius * 0.35, radius * 0.35), Color(0.95, 0.95, 0.92))
	_visual_box(ball, Vector3(radius * 0.4, radius * 0.4, radius * 2.04), Color(0.1, 0.1, 0.12))
	return ball

func _block(size: Vector3, mass: float, position: Vector3, color: Color, material := "wood") -> InteriorObject:
	var block := Common.block(world, size, mass, position, material)
	_visual_box(block, size, color)
	return block

func _cylinder(radius: float, height: float, mass: float, position: Vector3, color: Color, material: String) -> InteriorObject:
	var body := Common.prop(world, [{"kind": "cylinder", "center": [0, 0, 0], "radius": radius, "height": height}], mass, material, position)
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	mesh.mesh = cylinder
	mesh.material_override = _material(color, 0.3)
	body.add_child(mesh)
	_visual_box(body, Vector3(radius * 2.05, height * 0.12, radius * 0.5), Color(0.95, 0.9, 0.75), Vector3(0, height * 0.3, 0))
	return body

func _setup() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	world = Node3D.new()
	root.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.72, 0.78, 0.84)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.85, 0.88, 0.95)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled = true
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 25.0
	world.add_child(sun)
	var floor_body := Common.floor_slab(world)
	_visual_box(floor_body, Vector3(60, 1, 60), Color(0.56, 0.42, 0.30))
	# Grid lines on the floor show travel distance (1 m spacing).
	for i in range(-8, 9):
		var line := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.012, 0.002, 30)
		line.mesh = box
		line.material_override = _material(Color(0.42, 0.31, 0.22))
		line.position = Vector3(i, 0.001, 0)
		world.add_child(line)
	camera = Camera3D.new()
	camera.fov = 55
	world.add_child(camera)
	camera.current = true

func _look(from: Vector3, at: Vector3) -> void:
	camera.global_position = from
	camera.look_at(at)
	camera.reset_physics_interpolation()

func _grab() -> Image:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	return image

func _sheet(frames: Array[Image], labels: Array, path: String) -> void:
	var columns := 3
	var rows := int(ceil(frames.size() / float(columns)))
	var sheet := Image.create(CELL.x * columns, CELL.y * rows, false, Image.FORMAT_RGB8)
	for i in frames.size():
		var cell := frames[i].duplicate() as Image
		cell.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(cell, Rect2i(Vector2i.ZERO, CELL), Vector2i((i % columns) * CELL.x, (i / columns) * CELL.y))
	sheet.save_png(path)
	report[path.get_file()] = labels

func _capture_sequence(times: Array, watch: Callable = Callable()) -> Array[Image]:
	var frames: Array[Image] = []
	var frame := 0
	for t in times:
		while frame < int(t * 60.0):
			await physics_frame
			frame += 1
			if watch.is_valid():
				watch.call()
		frames.append(await _grab())
	return frames

func _run() -> void:
	_setup()
	DirAccess.make_dir_recursive_absolute(OUT)
	for i in 10:
		await process_frame
	# 1. Ball: platform -> 10 degree ramp -> floor.
	var height := 0.4
	var ramp_length := height / sin(deg_to_rad(10.0))
	var ramp_run := height / tan(deg_to_rad(10.0))
	_static(Vector3(-4.0, height * 0.5 - 0.05, 0), Vector3(2.0, height + 0.1 - 0.0, 1.2), Color(0.35, 0.45, 0.55))
	_static(Vector3(-3.0 + ramp_run * 0.5, height * 0.5 - 0.1 * cos(deg_to_rad(10.0)) * 0.5, 0), Vector3(ramp_length + 0.02, 0.1, 1.2), Color(0.35, 0.45, 0.55), Vector3(0, 0, -10))
	var ball := _ball(0.11, 0.43, Vector3(-4.6, height + 0.11, 0), Color(0.85, 0.2, 0.15))
	await _frames(5)
	_look(Vector3(-1.2, 1.25, 3.4), Vector3(-1.6, 0.15, 0))
	ball.linear_velocity = Vector3(2.2, 0, 0)
	var max_slip := [0.0]
	var watch_ball := func():
		if ball.is_supported() and ball.linear_velocity.length() > 0.3:
			var n := Vector3.UP if ball.global_position.x > -3.0 + ramp_run + 0.15 or ball.global_position.x < -3.0 else Vector3(sin(deg_to_rad(10.0)), cos(deg_to_rad(10.0)), 0)
			max_slip[0] = maxf(max_slip[0], (ball.linear_velocity + ball.angular_velocity.cross(-n * 0.11)).length() / ball.linear_velocity.length())
	var frames := await _capture_sequence([0.3, 0.9, 1.5, 2.3, 3.5, 6.0], watch_ball)
	report["ball_max_slip_ratio_while_rolling"] = max_slip[0]
	report["ball_final_x"] = ball.global_position.x
	report["ball_speed_at_8s"] = ball.linear_velocity.length()
	_sheet(frames, ["0.3 s", "0.9 s", "1.5 s", "2.3 s", "3.5 s", "6.0 s"], OUT + "01-ball-roll-sequence.png")
	frames[3].save_png(OUT + "04-ball-roll-frame.png")
	# 2. Tower hit by a thrown ball.
	var tower: Array[InteriorObject] = []
	var colors := [Color(0.9, 0.75, 0.35), Color(0.35, 0.6, 0.85), Color(0.85, 0.45, 0.35), Color(0.45, 0.75, 0.45), Color(0.8, 0.8, 0.78)]
	for i in 5:
		tower.append(_block(Vector3(0.3, 0.15, 0.3), 1.0, Vector3(0, 0.075 + 0.15 * i, -8), colors[i]))
	await _frames(120)
	report["tower_asleep_before_hit"] = tower.all(func(b): return b.sleeping)
	_look(Vector3(1.6, 1.3, -5.6), Vector3(-0.3, 0.4, -8))
	var thrown := _ball(0.08, 0.6, Vector3(-2.6, 0.55, -8), Color(0.2, 0.25, 0.8))
	await _frames(1)
	thrown.linear_velocity = Vector3(7.5, 0.9, 0)
	frames = await _capture_sequence([0.05, 0.3, 0.45, 0.65, 1.0, 2.5])
	var min_y := 99.0
	for block in tower:
		min_y = minf(min_y, block.global_position.y)
	report["tower_lowest_block_y"] = min_y
	_sheet(frames, ["0.05 s", "0.3 s", "0.45 s", "0.65 s", "1.0 s", "2.5 s"], OUT + "02-tower-topple-sequence.png")
	# 3. Tip vs slide, plus a knocked bottle.
	var vase := _cylinder(0.08, 0.6, 1.4, Vector3(-0.7, 0.3, 8), Color(0.25, 0.5, 0.55), "ceramic")
	var crate := _block(Vector3(0.3, 0.3, 0.3), 1.4, Vector3(0.7, 0.15, 8), Color(0.75, 0.6, 0.4), "wood")
	var bottle := _cylinder(0.035, 0.26, 0.4, Vector3(1.9, 0.13, 7.7), Color(0.2, 0.55, 0.3), "glass")
	await _frames(60)
	_look(Vector3(0.6, 1.05, 10.3), Vector3(0.7, 0.2, 8))
	var crate_start := crate.global_position
	vase.apply_impulse(Vector3(1.6, 0, 0), Vector3(0, 0.26, 0))
	crate.apply_impulse(Vector3(2.4, 0, 0), Vector3(0, -0.08, 0))
	bottle.apply_impulse(Vector3(0, 0, 0.3), Vector3(0, 0.12, 0))
	frames = await _capture_sequence([0.05, 0.35, 0.7, 1.1, 1.8, 3.5])
	report["vase_tilt_deg"] = Common.tilt_deg(vase)
	report["crate_tilt_deg"] = Common.tilt_deg(crate)
	report["crate_slide_m"] = crate.global_position.distance_to(crate_start)
	report["bottle_tilt_deg"] = Common.tilt_deg(bottle)
	_sheet(frames, ["0.05 s", "0.35 s", "0.7 s", "1.1 s", "1.8 s", "3.5 s"], OUT + "03-tip-vs-slide.png")
	print("INTERIOR_PHYSICS_SANDBOX ", JSON.stringify({"passed": report.get("vase_tilt_deg", 0.0) > 60.0 and report.get("crate_tilt_deg", 90.0) < 5.0, "report": report}))
	quit()

func _frames(count: int) -> void:
	for i in count:
		await physics_frame
