extends SceneTree
## 0.33: what happens to the frame time when the view is whipped side to side, the way a player does with the mouse.
## Rendered, with the game's own frame cap and adaptive resolution left ON (that is what the owner plays).
##   godot --path game --script res://tests/fast_look_probe.gd -- --render-size=1920x1080 [--seconds=6] [--quality=2]

var main: Node
var player: InteriorPlayer
var rows: Array = []
var events: Array = []
## Set by whatever the probe is timing; attached to the next spike.
var mark := ""

func _initialize() -> void:
	call_deferred("_run")

func _state() -> Dictionary:
	return {"scale": snappedf(root.scaling_3d_scale, .01), "tier": int(main.quality),
		"vram_mb": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0),
		"tex_mb": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0),
		"static_mb": int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}

## `rate` is the swing in degrees a second (0 = still); the direction flips every `flip` seconds.
func _swing(label: String, seconds: float, rate: float, flip := .16) -> void:
	for i in 20:
		await process_frame
	var samples: Array[float] = []
	var spikes: Array = []
	var begin := Time.get_ticks_usec()
	var previous := begin
	var last_scale := root.scaling_3d_scale
	var last_tier := int(main.quality)
	var draws := 0.0
	var prims := 0.0
	var before := _state()
	while Time.get_ticks_usec() - begin < seconds * 1000000.0:
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - previous) / 1000.0
		previous = now
		samples.append(ms)
		var t := (now - begin) / 1000000.0
		if ms > 25.0 and spikes.size() < 40:
			spikes.append([snappedf(t, .01), snappedf(ms, .1), snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, .1),
				snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, .1), mark])
			mark = ""
		if not is_equal_approx(root.scaling_3d_scale, last_scale):
			events.append([label, snappedf(t, .01), "scale %.2f -> %.2f" % [last_scale, root.scaling_3d_scale]])
			last_scale = root.scaling_3d_scale
		if int(main.quality) != last_tier:
			events.append([label, snappedf(t, .01), "tier %d -> %d" % [last_tier, int(main.quality)]])
			last_tier = int(main.quality)
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		if rate > 0.0:
			var way := 1.0 if int(t / flip) % 2 == 0 else -1.0
			var pixels := deg_to_rad(rate) * minf(ms, 50.0) / 1000.0 / player.sensitivity
			player.look(Vector2(way * pixels, sin(t * 5.0) * pixels * .12))
	var worst := 0.0
	for ms in samples:
		worst = maxf(worst, ms)
	var over25 := 0
	var over100 := 0
	for ms in samples:
		if ms > 25.0:
			over25 += 1
		if ms > 100.0:
			over100 += 1
	samples.sort()
	var row := {"view": label, "rate": rate, "fps_median": snappedf(1000.0 / samples[samples.size() / 2], .1),
		"fps_1pct_low": snappedf(1000.0 / samples[int(samples.size() * .99)], .1), "worst_ms": snappedf(worst, .1),
		"over_25ms": over25, "over_100ms": over100, "frames": samples.size(), "draw_calls": int(draws / samples.size()),
		"primitives_k": int(prims / samples.size() / 1000.0), "before": before, "after": _state()}
	rows.append(row)
	print("FAST_LOOK_ROW ", JSON.stringify(row))
	print("FAST_LOOK_SPIKES ", label, " ", JSON.stringify(spikes))

## Many infected at once, the automatic rifle held down, the view whipped about: what the owner said brings it down.
func _horde(count: int, rounds: int, seconds: float, spot: Array) -> void:
	await _place(spot[1], spot[2])
	var zombies: InteriorZombies = main.zombies
	zombies.invulnerable = true
	var gun: InteriorGun = main.story.gun
	main.story.debug_give_gun()
	gun.give_rifle()
	gun._key_weapon("rifle")
	for i in 60:
		await process_frame
	await _swing("horde: before", 2.5, 0.0)
	for round in rounds:
		var before := zombies.alive().size()
		var begin := Time.get_ticks_usec()
		zombies.spawn_around(count - before, 5.0, 24.0)
		var spawn_ms := (Time.get_ticks_usec() - begin) / 1000.0
		var worst_spawn := 0.0
		while zombies.pending() > 0:
			var frame_begin := Time.get_ticks_usec()
			await process_frame
			worst_spawn = maxf(worst_spawn, (Time.get_ticks_usec() - frame_begin) / 1000.0)
		print("FAST_LOOK_SPAWN_FRAMES worst_ms ", snappedf(worst_spawn, .1))
		print("FAST_LOOK_SPAWN ", JSON.stringify({"round": round, "made": zombies.alive().size() - before, "alive": zombies.alive().size(), "ms": snappedf(spawn_ms, .1)}))
		gun.reserve = 300
		gun.trigger_held = round % 2 == 1
		await _swing("horde %d: %d alive%s" % [round, zombies.alive().size(), ", firing" if gun.trigger_held else ""], seconds, 900.0, .22)
		gun.trigger_held = false
		if round % 2 == 1:
			zombies.kill_all()
	await _swing("horde: bodies and blood", 3.0, 720.0)

## What each part of a place costs: one thing switched off at a time, uncapped, at a fixed resolution, standing still
## and looking eight ways in turn (the same eight every time, each counted equally).
func _ring(label: String) -> void:
	var rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var ms := 0.0
	var gpu := 0.0
	var cpu := 0.0
	var draws := 0.0
	var prims := 0.0
	var worst := 0.0
	var count := 0
	var process := 0.0
	var physics := 0.0
	var ways: Array = []
	for way in 8:
		var way_ms := 0.0
		var way_worst := 0.0
		var way_prims := 0.0
		var way_draws := 0.0
		player.rotation.y = way * TAU / 8.0
		player.camera.rotation = Vector3(-.05, 0, 0)
		for i in 10:
			await process_frame
		var previous := Time.get_ticks_usec()
		for i in 36:
			await process_frame
			var now := Time.get_ticks_usec()
			ms += (now - previous) / 1000.0
			worst = maxf(worst, (now - previous) / 1000.0)
			way_ms += (now - previous) / 1000.0
			way_worst = maxf(way_worst, (now - previous) / 1000.0)
			way_prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			way_draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			previous = now
			process += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
			draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			count += 1
		ways.append([snappedf(way_ms / 36.0, .1), snappedf(way_worst, .1), int(way_draws / 36.0), int(way_prims / 36000.0)])
	print("FAST_LOOK_WAYS ", label, " [ms, worst, draws, k tris] ", JSON.stringify(ways))
	print("FAST_LOOK_RING ", JSON.stringify({"view": label, "frame_ms": snappedf(ms / count, .01), "fps": snappedf(1000.0 * count / ms, .1),
		"process_ms": snappedf(process / count, .01), "physics_ms": snappedf(physics / count, .01), "gpu_ms": snappedf(gpu / count, .01), "render_cpu_ms": snappedf(cpu / count, .01), "worst_ms": snappedf(worst, .1),
		"draw_calls": int(draws / count), "primitives_k": int(prims / count / 1000.0)}))

func _split(spot: Array) -> void:
	main.performance.set_adaptive(false)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _place(spot[1], spot[2])
	await _ring("warm-up")
	await _ring("all on")
	if "--ring-only" in OS.get_cmdline_user_args():
		return
	var trees: Array = main.performance._trees
	for tree in trees:
		if is_instance_valid(tree):
			tree.visible = false
	await _ring("no trees")
	for tree in trees:
		if is_instance_valid(tree):
			tree.visible = true
	var suns: Array = []
	var lamps: Array = []
	for node in main.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light.shadow_enabled and light.is_visible_in_tree():
			if light is DirectionalLight3D:
				suns.append(light)
			else:
				lamps.append(light)
	print("FAST_LOOK_LIGHTS ", JSON.stringify({"moon_shadows": suns.size(), "lamp_shadows": lamps.size()}))
	for light: Light3D in suns:
		light.shadow_enabled = false
	await _ring("no moon shadow")
	for light: Light3D in suns:
		light.shadow_enabled = true
	for light: Light3D in lamps:
		light.shadow_enabled = false
	await _ring("no lamp shadows")
	for light: Light3D in lamps:
		light.shadow_enabled = true
	main.bodycam.rect.visible = false
	main.bodycam._copy.visible = false
	await _ring("no lens pass (same field of view)")
	main.bodycam.rect.visible = true
	main.bodycam._copy.visible = true
	var small: Array = []
	for node in main.find_children("*", "MultiMeshInstance3D", true, false):
		if (node as Node3D).visible:
			small.append(node)
			(node as Node3D).visible = false
	await _ring("no multimeshes")
	for node: Node3D in small:
		node.visible = true
	var fog: Array = []
	for node in main.find_children("*", "FogVolume", true, false):
		if (node as Node3D).visible:
			fog.append(node)
			(node as Node3D).visible = false
	var env: Environment = root.world_3d.environment
	var camera_env := player.camera.environment
	print("FAST_LOOK_ENV ", JSON.stringify({"fog_volumes": fog.size(), "world_env": env != null, "camera_env": camera_env != null}))
	for e: Environment in [env, camera_env]:
		if e != null:
			print("FAST_LOOK_ENV_SET ", JSON.stringify({"volumetric": e.volumetric_fog_enabled, "ssao": e.ssao_enabled, "ssil": e.ssil_enabled, "ssr": e.ssr_enabled, "sdfgi": e.sdfgi_enabled, "glow": e.glow_enabled}))
	await _ring("no fog volumes")
	for node: Node3D in fog:
		node.visible = true
	for tree in trees:
		if is_instance_valid(tree):
			tree.visible = false
	for light: Light3D in suns + lamps:
		light.shadow_enabled = false
	await _ring("no trees, no shadows")

## Candidate savings, tried one at a time: what the picture costs per pixel.
func _hide(kind: String, filter := "") -> Array:
	var out: Array = []
	for node in main.find_children("*", kind, true, false):
		if node is Node3D and (node as Node3D).visible and (filter == "" or String(node.name).contains(filter)):
			if node is DirectionalLight3D:
				continue
			out.append(node)
			(node as Node3D).visible = false
	return out

func _show(nodes: Array) -> void:
	for node: Node3D in nodes:
		if is_instance_valid(node):
			node.visible = true

func _tune(spot: Array) -> void:
	main.performance.set_adaptive(false)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _place(spot[1], spot[2])
	await _ring("warm-up")
	await _ring("all on")
	root.scaling_3d_scale = .7
	await _ring("render scale 0.7")
	root.scaling_3d_scale = 1.0
	var hidden := _hide("Light3D")
	await _ring("no lamps (%d)" % hidden.size())
	_show(hidden)
	hidden = _hide("Decal")
	await _ring("no decals (%d)" % hidden.size())
	_show(hidden)
	hidden = _hide("GPUParticles3D") + _hide("CPUParticles3D")
	await _ring("no particles (%d)" % hidden.size())
	_show(hidden)
	hidden = _hide("Node3D", "Sky dome") + _hide("Node3D", "Ground mist") + _hide("Node3D", "Moon")
	await _ring("no sky dome, mist, moon (%d)" % hidden.size())
	_show(hidden)
	hidden = _hide("ReflectionProbe")
	await _ring("no reflection probes (%d)" % hidden.size())
	_show(hidden)
	await _ring("all on again")
	hidden = _hide("Light3D") + _hide("Decal") + _hide("GPUParticles3D") + _hide("CPUParticles3D")
	await _ring("no lamps, decals, particles")
	_show(hidden)
	# The weapon's own view, with the lens on top.
	main.story.debug_give_gun()
	main.story.gun.draw()
	for i in 90:
		await process_frame
	await _ring("pistol up")

func _place(at: Vector3, toward: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.camera.look_at(toward)
	player.reset_physics_interpolation()
	for i in 30:
		await process_frame

func _run() -> void:
	var seconds := 6.0
	var quality := -1
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seconds="):
			seconds = float(argument.trim_prefix("--seconds="))
		if argument.begins_with("--quality="):
			quality = int(argument.trim_prefix("--quality="))
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	for i in 60:
		await process_frame
	main.set("capturing", true)
	main._play()
	if quality >= 0:
		main._apply_quality(quality)
	if "--no-adaptive" in OS.get_cmdline_user_args():
		main.performance.set_adaptive(false)
	player = main.player
	var stranger := main.get_node_or_null("Stranger")
	if stranger != null:
		stranger.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 90:
		await process_frame
	print("FAST_LOOK_START ", JSON.stringify({"window": str(root.size), "max_fps": Engine.max_fps, "state": _state()}))
	var spots := [
		["room", player.global_position, player.global_position + Vector3(0, 1.5, -3.0)],
		["street", Vector3(18.9, -2.9, 6.0), Vector3(20.5, -1.6, 31.0)],
		["field road", Vector3(21.0, -2.9, 58.0), Vector3(21.0, -1.6, 90.0)],
		["nichols gate", Vector3(-12.0, -2.9, -55.0), Vector3(-12.0, -1.6, -80.0)],
	]
	var horde := 0
	var rounds := 6
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--zombies="):
			horde = int(argument.trim_prefix("--zombies="))
		if argument.begins_with("--rounds="):
			rounds = int(argument.trim_prefix("--rounds="))
	if "--tune" in OS.get_cmdline_user_args():
		await _tune(spots[1])
		quit()
		return
	if "--split" in OS.get_cmdline_user_args():
		await _split(spots[1])
		quit()
		return
	if horde > 0:
		await _horde(horde, rounds, seconds, spots[1])
		print("FAST_LOOK_EVENTS ", JSON.stringify(events))
		print("FAST_LOOK ", JSON.stringify({"rows": rows.size(), "state": _state()}))
		quit()
		return
	for spot: Array in spots:
		await _place(spot[1], spot[2])
		await _swing("%s still" % spot[0], 2.5, 0.0)
		await _swing("%s fast" % spot[0], seconds, 720.0)
	# With a weapon up: the muzzle leads, the weapon's own view is drawn as well.
	var story: Node = main.story
	if story != null and story.has_method("debug_give_gun"):
		story.debug_give_gun()
		var gun: Node = story.get("gun")
		if gun != null and gun.has_method("draw"):
			gun.draw()
		await _place(spots[1][1], spots[1][2])
		await _swing("street, pistol, fast", seconds, 720.0)
		await _swing("street, pistol, violent", seconds, 2400.0, .09)
	print("FAST_LOOK_EVENTS ", JSON.stringify(events))
	print("FAST_LOOK ", JSON.stringify({"rows": rows.size(), "state": _state()}))
	quit()
