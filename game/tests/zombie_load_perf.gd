extends SceneTree
## 0.60 measurement (not a test, changes nothing in the game): what crowds of infected, their dead, torn limbs and
## blood cost, rendered (never headless), uncapped, vsync off, adaptive resolution off. One part per run so the
## parts do not leak into each other. Writes work/v60/perf/raw_<mode>_<part>.json and prints INTERIOR_ZLOAD_ROW lines.
##   godot --path game --script res://tests/zombie_load_perf.gd -- --render-size=1280x720 --mode=solo --part=alive
##   --mode=solo  --part=alive|dead|limbs|decals|massacre
##   --mode=coop  --part=alive|dead|massacre
##   [--quality=2] [--seconds=4]
## The game's caps are stepped round here only to see what they save: solo spawns past MAX_ALIVE (36), corpses past
## MAX_CORPSES (16), limbs past InteriorBlood.MAX_PIECES (20) and decals past MAX_DECALS (340) are kept by this
## script's own lists. Nothing is frozen or put to sleep by hand; the ablation rows (hidden / no script) are measured
## and then undone.

## Kinds that stand up (crawlers and lurkers start as ragdolls and would skew the live rows).
const STANDING := ["shambler", "limper", "fresh", "runner", "rager", "leaper", "dull", "brute", "twitcher", "screamer", "stalker"]

var main
var mode := "solo"
var part := "alive"
var quality := 2
var seconds := 4.0
var pass_tag := ""
var rows: Array = []
var extra := {}
var zombies: InteriorZombies
var blood: InteriorBlood
var spots: Array = []
var spot_index := 0
var mine: Array = []          # solo: every zombie this script made
var dead_list: Array = []     # solo: corpses kept past MAX_CORPSES
var kept_pieces: Array = []
var kept_decals: Array = []
var kind_index := 0
var eye := Vector3.ZERO
var look := Vector3.ZERO
# co-op
var s
var m
var stand := Vector3.ZERO
var stash: Array = []

var _phys_first := 0
var _phys_steps := 0

func _initialize() -> void:
	call_deferred("_run")
	physics_frame.connect(_on_physics_frame)

## The first physics tick of a frame starts here; the frame's process step (process_frame) ends the physics block.
func _on_physics_frame() -> void:
	if _phys_steps == 0:
		_phys_first = Time.get_ticks_usec()
	_phys_steps += 1

# ---------------------------------------------------------------- measuring

func _pct(sorted: Array, q: float) -> float:
	if sorted.is_empty():
		return 0.0
	return float(sorted[clampi(int(sorted.size() * q), 0, sorted.size() - 1)])

func _sorted(a: Array) -> Array:
	var b := a.duplicate()
	b.sort()
	return b

func _bodies_report() -> Dictionary:
	var bones := 0
	var awake := 0
	var rigid := 0
	var rigid_awake := 0
	var decals := 0
	var skinned := 0
	for node in root.find_children("*", "PhysicalBone3D", true, false):
		var b := node as PhysicalBone3D
		if not b.is_inside_tree():
			continue
		bones += 1
		if not PhysicsServer3D.body_get_state(b.get_rid(), PhysicsServer3D.BODY_STATE_SLEEPING):
			awake += 1
	for node in root.find_children("*", "RigidBody3D", true, false):
		var r := node as RigidBody3D
		if r.is_in_group("zombie_parts") or r.name.begins_with("Gib"):
			rigid += 1
			if not r.sleeping:
				rigid_awake += 1
	for node in root.find_children("*", "Decal", true, false):
		if (node as Decal).is_visible_in_tree():
			decals += 1
	for node in root.find_children("*", "Skeleton3D", true, false):
		if (node as Skeleton3D).is_visible_in_tree():
			skinned += 1
	return {"ragdoll_bones": bones, "ragdoll_bones_awake": awake, "limb_and_gib_bodies": rigid, "limb_and_gib_awake": rigid_awake,
		"decals_visible": decals, "skeletons_visible": skinned}

func _measure(label: String, secs: float, tags := {}, settle := 20) -> Dictionary:
	for i in settle:
		await process_frame
	var vp := root.get_viewport_rid()
	var samples: Array = []
	var begin := Time.get_ticks_usec()
	var previous := begin
	var process := 0.0
	var physics := 0.0
	var rcpu := 0.0
	var rgpu := 0.0
	var draws := 0.0
	var prims := 0.0
	var objects := 0.0
	var active := 0.0
	var pairs := 0.0
	var n := 0
	var ticks0 := Engine.get_physics_frames()
	var phys_block := 0.0
	var phys_steps := 0
	var phys_frames: Array = []
	_phys_steps = 0
	while Time.get_ticks_usec() - begin < secs * 1000000.0:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		previous = now
		if _phys_steps > 0:
			var block := (now - _phys_first) / 1000.0
			phys_block += block
			phys_steps += _phys_steps
			phys_frames.append(block / _phys_steps)
		_phys_steps = 0
		process += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		rcpu += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
		rgpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		active += Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
		pairs += Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)
		n += 1
	var elapsed := (Time.get_ticks_usec() - begin) / 1000000.0
	var ticks := Engine.get_physics_frames() - ticks0
	var avg := 0.0
	for x in samples:
		avg += float(x)
	avg /= maxf(samples.size(), 1)
	var sorted := samples.duplicate()
	sorted.sort()
	var row := {"mode": mode, "part": part, "view": label,
		"frames": samples.size(), "fps_avg": snappedf(1000.0 / avg, .1), "fps_median": snappedf(1000.0 / _pct(sorted, .5), .1),
		"ms_avg": snappedf(avg, .01), "ms_p50": snappedf(_pct(sorted, .5), .01), "ms_p95": snappedf(_pct(sorted, .95), .01),
		"ms_p99": snappedf(_pct(sorted, .99), .01), "ms_worst": snappedf(sorted[-1] if not sorted.is_empty() else 0.0, .01),
		"fps_1pct_low": snappedf(1000.0 / maxf(_pct(sorted, .99), .001), .1),
		"process_max_ms_1s": snappedf(process / n, .02), "physics_max_ms_1s": snappedf(physics / n, .02),
		"physics_ms_per_tick": snappedf(phys_block / maxf(phys_steps, 1), .01),
		"physics_ms_per_tick_p95": snappedf(_pct(_sorted(phys_frames), .95), .01),
		"physics_share_pct": snappedf(phys_block / (elapsed * 10.0), .1),
		"non_physics_ms_per_frame": snappedf((elapsed * 1000.0 - phys_block) / maxf(samples.size(), 1), .02),
		"physics_ticks_per_s": snappedf(ticks / elapsed, .1),
		"render_cpu_ms": snappedf(rcpu / n, .02), "render_gpu_ms": snappedf(rgpu / n, .02),
		"draw_calls": int(draws / n), "primitives": int(prims / n), "objects": int(objects / n),
		"physics_active_objects": int(active / n), "collision_pairs": int(pairs / n),
		"physics_islands": int(Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"objects_alloc": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"static_mem_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, .1),
		"video_mem_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, .1),
		"texture_mem_mb": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, .1),
		"buffer_mem_mb": snappedf(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0, .1)}
	row.merge(_bodies_report())
	row.merge(_counts())
	row.merge(tags, true)
	rows.append(row)
	print("INTERIOR_ZLOAD_ROW ", JSON.stringify(row))
	return row

func _counts() -> Dictionary:
	if mode == "solo":
		var live := 0
		var corpses := 0
		for z in mine:
			if is_instance_valid(z) and not z.is_queued_for_deletion():
				if z.alive(): live += 1
				else: corpses += 1
		return {"alive": live, "corpses": corpses, "blood_decals": blood.count() if blood else 0,
			"blood_spots": blood.spots() if blood else 0, "limbs_kept": blood._pieces.size() + kept_pieces.size() if blood else 0}
	var live := 0
	for z in m.enemies.values():
		if is_instance_valid(z) and not z.dead: live += 1
	var corpses := 0
	for c in m.corpses + stash:
		if is_instance_valid(c): corpses += 1
	return {"alive": live, "corpses": corpses, "blood_decals": blood.count() if blood else 0,
		"blood_spots": blood.spots() if blood else 0, "limbs_kept": blood._pieces.size() + kept_pieces.size() if blood else 0}

## Every half second for `secs`: how many ragdoll bodies are still awake (how long a fall stays "active").
func _settle_curve(label: String, secs: float) -> void:
	var curve: Array = []
	var begin := Time.get_ticks_msec()
	var frames := 0
	var t0 := Time.get_ticks_usec()
	var worst := 0.0
	var prev := t0
	var next_mark := 0
	while Time.get_ticks_msec() - begin < secs * 1000:
		await process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - prev) / 1000.0)
		prev = now
		frames += 1
		var t := Time.get_ticks_msec() - begin
		if t >= next_mark:
			next_mark += 500
			var r := _bodies_report()
			curve.append([snappedf(t / 1000.0, .1), r.ragdoll_bones, r.ragdoll_bones_awake, r.limb_and_gib_awake,
				int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)), frames, snappedf(worst, .1)])
			frames = 0
			worst = 0.0
	extra[label] = {"columns": ["t_s", "ragdoll_bones", "awake_bones", "limbs_awake", "physics_active", "frames_in_window", "worst_ms_in_window"], "rows": curve}
	print("INTERIOR_ZLOAD_SETTLE ", label, " ", JSON.stringify(curve))

## A picture of what was measured (proof the bodies, limbs and decals were in the frame).
func _shot(file: String) -> void:
	await process_frame
	var img := root.get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://").path_join("../work/v60/perf/shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join("%s_%s%s.png" % [mode, file, pass_tag]))

func _save() -> void:
	var dir := ProjectSettings.globalize_path("res://").path_join("../work/v60/perf").simplify_path()
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("raw_%s_%s%s.json" % [mode, part, pass_tag])
	var info := {"mode": mode, "part": part, "quality": quality, "window": str(root.size),
		"render_scale": root.scaling_3d_scale, "msaa": root.msaa_3d, "adapter": RenderingServer.get_video_adapter_name(),
		"adapter_vendor": RenderingServer.get_video_adapter_vendor(), "api": RenderingServer.get_video_adapter_api_version(),
		"cpu": OS.get_processor_name(), "cores": OS.get_processor_count(), "godot": Engine.get_version_info().string,
		"physics_engine": ProjectSettings.get_setting("physics/3d/physics_engine"),
		"physics_tps": Engine.physics_ticks_per_second, "rows": rows, "extra": extra}
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(info, "  "))
	f.close()
	print("INTERIOR_ZLOAD_SAVED ", path)

# ---------------------------------------------------------------- solo helpers

func _find_spots() -> void:
	# The street ahead of the camera (play_perf's lane, x 18.4..22.4), only where the camera can see the ground:
	# in the frustum and with a clear line from the eye. (0.60 first pass spread them over the yards behind the
	# walls, out of the picture.)
	spots.clear()
	var camera: Camera3D = main.player.camera
	var space := root.get_world_3d().direct_space_state
	for zi in range(0, 40):
		for xi in range(0, 5):
			var at := Vector3(18.4 + xi * .95 + (zi % 2) * .45, -1.3, 10.0 + zi * .95)
			var g := zombies.ground(at)
			if not g.is_finite() or not camera.is_position_in_frustum(g + Vector3.UP * .3):
				continue
			var ray := PhysicsRayQueryParameters3D.create(camera.global_position, g + Vector3.UP * .4, 2)
			if not space.intersect_ray(ray).is_empty():
				continue
			spots.append(g)
	spots.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(eye) < b.distance_squared_to(eye))
	var fwd := -camera.global_basis.z
	if fwd.z < .8:
		push_error("zombie_load_perf: camera faces %s, not up the street" % fwd)
	print("INTERIOR_ZLOAD spots ", spots.size(), " camera ", camera.global_position, " forward ", fwd,
		" first ", spots.slice(0, 3), " last ", spots.slice(-2))
	extra["spots"] = spots.size()
	extra["camera"] = [str(camera.global_position), str(fwd)]

func _next_spot() -> Vector3:
	if spots.is_empty():
		return Vector3.INF
	var at: Vector3 = spots[spot_index % spots.size()]
	spot_index += 1
	return at + Vector3(randf_range(-.12, .12), 0, randf_range(-.12, .12))

## A zombie through the director's own steps (InteriorZombies.spawn), past its MAX_ALIVE; its death is not handed to
## the director, so MAX_CORPSES does not take bodies away.
func _solo_spawn(at: Vector3) -> InteriorZombie:
	var z := InteriorZombie.new()
	zombies.add_child(z)
	z.setup(zombies, "", STANDING[kind_index % STANDING.size()])
	kind_index += 1
	z.global_position = at
	z.rotation.y = PI + randf_range(-.6, .6)
	z.start(InteriorZombie.State.IDLE)
	mine.append(z)
	return z

func _solo_spawn_many(count: int) -> int:
	var made := 0
	for i in count:
		var at := _next_spot()
		if not at.is_finite():
			break
		_solo_spawn(at)
		made += 1
		if i % 6 == 5:
			await process_frame
	return made

func _solo_alive() -> Array:
	var out: Array = []
	for z in mine:
		if is_instance_valid(z) and z.alive():
			out.append(z)
	return out

## As the debug menu's "Kill all": the figure drops where it stands, a ragdoll, dead.
func _clean_kill(z: InteriorZombie) -> void:
	z.health = 0.0
	z._ragdoll([], -z.global_basis.z * 30.0)
	z._die()

## Rifle rounds, as play_perf does: `bones` each take one, with `sever` the round's tearing load.
func _shoot(z: InteriorZombie, bone: String, sever: float) -> void:
	if not is_instance_valid(z):
		return
	var body := z._bodies.get(bone) as PhysicalBone3D
	if body == null:
		return
	var way := (body.global_position - (eye + Vector3(0, .1, 0))).normalized()
	var p: Dictionary = InteriorGun.PROFILES["rifle"]
	z.shot(body, body.global_position - way * .1, way, float(p.damage), float(p.knock), "rifle", sever)

func _set_corpse_visible(on: bool) -> void:
	for z in mine:
		if is_instance_valid(z) and not z.alive():
			z.visible = on

func _set_corpse_script(on: bool) -> void:
	for z in mine:
		if is_instance_valid(z) and not z.alive():
			z.set_physics_process(on)
			z.set_process(on)

func _keep_overflow() -> void:
	# What the caps would have freed, held here instead (only for the rows past a cap).
	while blood._pieces.size() > 0 and blood._pieces.size() >= InteriorBlood.MAX_PIECES - 4:
		kept_pieces.append(blood._pieces.pop_front())

# ---------------------------------------------------------------- solo parts

func _solo_setup() -> void:
	main._play()
	main._apply_quality(quality)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var stranger = main.get_node_or_null("Stranger")
	if stranger != null:
		stranger.process_mode = Node.PROCESS_MODE_DISABLED
	var player: InteriorPlayer = main.player
	eye = Vector3(20.2, -1.32, 6.0)
	look = Vector3(20.5, -1.65, 31.0)
	# Facing up the street (+z). The body carries the yaw (player.gd takes a camera yaw into the body and resets the
	# camera itself), so turn the body; play_perf's camera.look_at alone ends up facing -z.
	player.reset_motion(eye - Vector3.UP * 1.58)
	var way := look - eye
	player.rotation = Vector3(0, atan2(-way.x, -way.z), 0)
	player.reset_physics_interpolation()
	zombies = main.zombies
	blood = zombies.blood
	zombies.invulnerable = true
	for i in 30:
		await process_frame
	_find_spots()

func _solo_part_alive() -> void:
	zombies.passive = false
	await _measure("street, 0 alive", seconds, {"n": 0})
	var have := 0
	for target in [10, 25, 50, 75, 100]:
		await _solo_spawn_many(target - have)
		have = target
		for z in _solo_alive():
			z.hear(main.player.global_position)
		# Give them time to come on (the chase, the crowding, the attack).
		for i in 120:
			await process_frame
		await _measure("street, %d alive chasing" % target, seconds, {"n": target})
		if target == 25 or target == 100:
			await _shot("alive_%d" % target)
		if target == 50 or target == 25:
			await _alive_ablations(target)

## Where the live cost goes: each zombie's own tick (AI, senses, paths, move_and_slide) off; the director's
## per-frame animation (clips and skeletons advanced by hand) off; the figures hidden. Each undone after.
func _alive_ablations(target: int) -> void:
	var live := _solo_alive()
	for z in live:
		z.set_physics_process(false)
	await _measure("%d alive, zombie _physics_process off (ablation)" % target, 3.0, {"n": target, "ablation": "ai_tick"})
	for z in live:
		z.set_physics_process(true)
	zombies.set_process(false)
	await _measure("%d alive, director animation off (ablation)" % target, 3.0, {"n": target, "ablation": "animation"})
	zombies.set_process(true)
	for z in live:
		z.visible = false
	await _measure("%d alive, figures hidden (ablation)" % target, 3.0, {"n": target, "ablation": "hidden"})
	for z in live:
		z.visible = true
	await _measure("%d alive, back" % target, 3.0, {"n": target})

func _solo_part_dead() -> void:
	zombies.passive = true
	await _measure("street, 0 dead", seconds, {"n": 0})
	var have := 0
	for target in [10, 20, 40, 60, 100]:
		await _solo_spawn_many(target - have)
		for i in 30:
			await process_frame
		var batch := _solo_alive()
		var start_frame := Engine.get_process_frames()
		for z in batch:
			_clean_kill(z)
		have = target
		# (a) the fall: the batch's ragdolls are all moving.
		await _measure("%d dead, just killed %d (0-2.5 s)" % [target, batch.size()], 2.5, {"n": target, "batch": batch.size(), "phase": "falling"}, 0)
		await _settle_curve("settle_after_%d" % target, 9.0)
		# (b) settled.
		await _measure("%d dead, settled" % target, seconds, {"n": target, "phase": "settled"})
		if target in [20, 100]:
			await _shot("dead_%d" % target)
		if target in [20, 60, 100]:
			_set_corpse_visible(false)
			await _measure("%d dead, corpses hidden (ablation)" % target, 3.0, {"n": target, "phase": "settled", "ablation": "hidden"})
			_set_corpse_visible(true)
			_set_corpse_script(false)
			await _measure("%d dead, corpse scripts off (ablation)" % target, 3.0, {"n": target, "phase": "settled", "ablation": "scripts"})
			_set_corpse_script(true)
	# What taking bodies away costs in the frame it happens: one (a rolling cap) against twenty (a batch).
	var corpses: Array = []
	for z in mine:
		if is_instance_valid(z) and not z.alive():
			corpses.append(z)
	for batch in [1, 1, 1, 5, 20]:
		var gone: Array = []
		for i in batch:
			gone.append(corpses.pop_front())
		await _free_spike("free %d corpse(s) at once" % batch, gone)
	for i in range(0, corpses.size() - InteriorZombies.MAX_CORPSES):
		corpses[i].queue_free()
	await _measure("after freeing all but 16 (MAX_CORPSES)", seconds, {"n": 16, "phase": "settled"})
	for z in corpses:
		if is_instance_valid(z):
			z.queue_free()
	await _measure("after freeing every corpse", seconds, {"n": 0, "phase": "settled"})

## The worst frame among the next 12 after `nodes` are queue_free()d, against the 60 frames before.
func _free_spike(label: String, nodes: Array) -> void:
	var before: Array = []
	var prev := Time.get_ticks_usec()
	for i in 60:
		await process_frame
		var now := Time.get_ticks_usec()
		before.append((now - prev) / 1000.0)
		prev = now
	for nd in nodes:
		if is_instance_valid(nd):
			nd.queue_free()
	var after: Array = []
	for i in 12:
		await process_frame
		var now := Time.get_ticks_usec()
		after.append((now - prev) / 1000.0)
		prev = now
	before.sort()
	var row := {"mode": mode, "part": part, "view": label, "kind": "free_spike", "count": nodes.size(),
		"before_p50_ms": snappedf(_pct(before, .5), .01), "before_worst_ms": snappedf(before[-1], .01),
		"after_worst_ms": snappedf(after.max(), .01), "after_frames_ms": after.map(func(x): return snappedf(x, .1))}
	rows.append(row)
	print("INTERIOR_ZLOAD_ROW ", JSON.stringify(row))

func _solo_part_limbs() -> void:
	zombies.passive = true
	await _measure("street, 0 limbs", seconds, {"n": 0})
	# Each one loses both forearms and both shins (four pieces), then is shot dead; the corpses are freed so only
	# the pieces (and the blood) are left.
	var have_pieces := 0
	for target in [10, 20, 40, 80]:
		var need := ceili((target - have_pieces) / 4.0)
		await _solo_spawn_many(need)
		for i in 30:
			await process_frame
		var batch := _solo_alive()
		for z in batch:
			for bone in ["forearm.L", "forearm.R", "shin.L", "shin.R"]:
				_shoot(z, bone, 400.0)
			await process_frame
			await process_frame
			_keep_overflow()
		for i in 6:
			await physics_frame
		_keep_overflow()
		for z in batch:
			if is_instance_valid(z):
				_clean_kill(z)
		await _settle_curve("limbs_settle_%d" % target, 6.0)
		for z in batch:
			if is_instance_valid(z):
				mine.erase(z)
				z.queue_free()
		_keep_overflow()
		have_pieces = blood._pieces.size() + kept_pieces.size()
		# The blood the shots left is measured in its own part: take the decals away so this row is the pieces.
		for d in blood._decals + blood._spots:
			if is_instance_valid(d):
				d.queue_free()
		blood._decals.clear()
		blood._spots.clear()
		await _measure("%d torn limbs lying (no corpses, no decals)" % have_pieces, seconds, {"n": have_pieces, "phase": "settled"})
		if have_pieces >= 80:
			await _shot("limbs_80")
		if have_pieces >= 40:
			for p in blood._pieces + kept_pieces:
				if is_instance_valid(p):
					p.visible = false
			await _measure("%d torn limbs, hidden (ablation)" % have_pieces, 3.0, {"n": have_pieces, "ablation": "hidden"})
			for p in blood._pieces + kept_pieces:
				if is_instance_valid(p):
					p.visible = true

func _decal_spot() -> Vector3:
	for k in 20:
		var at := _next_spot()
		if at.is_finite():
			return at
	return Vector3.INF

func _solo_part_decals() -> void:
	zombies.passive = true
	await _measure("street, 0 decals", seconds, {"n": 0})
	var have := 0
	for target in [100, 200, 340, 500, 800, 1200]:
		while have < target:
			var at := _decal_spot()
			blood.pool(at + Vector3(randf_range(-.4, .4), .2, randf_range(-.4, .4)))
			have += 1
			if blood._decals.size() >= InteriorBlood.MAX_DECALS:
				kept_decals.append(blood._decals.pop_front())
			if have % 40 == 0:
				await process_frame
		# Pools grow over 7-11 s; let them reach full size.
		for i in 60:
			await process_frame
		var wait := Time.get_ticks_msec()
		while Time.get_ticks_msec() - wait < 11000:
			await process_frame
		await _measure("%d blood pools (decals) in view" % target, seconds, {"n": target})
		if target == 340 or target == 1200:
			await _shot("decals_%d" % target)

func _solo_part_massacre() -> void:
	# The real thing: 36 (the solo MAX_ALIVE) coming, shot down with rifle rounds (head, chest, limbs: torn parts,
	# bursts, drops, decals) at the game's own caps (MAX_CORPSES 16 kept by the director, MAX_PIECES, MAX_DECALS).
	zombies.passive = false
	await _measure("street, empty", seconds, {"n": 0})
	var made := 0
	for i in 36:
		var z := zombies.spawn(_next_spot())
		if z != null:
			made += 1
			mine.append(z)
	for z in zombies.alive():
		z.hear(main.player.global_position)
	for i in 90:
		await process_frame
	await _measure("36 alive chasing (game spawn, caps on)", seconds, {"n": made})
	var bones := ["head", "chest", "forearm.L", "shin.R", "upper_arm.R", "thigh.L", "chest", "head"]
	var samples: Array = []
	var prev := Time.get_ticks_usec()
	var begin := Time.get_ticks_msec()
	var k := 0
	while Time.get_ticks_msec() - begin < 8000:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now - prev) / 1000.0)
		prev = now
		if samples.size() % 3 == 0:
			var live := zombies.alive()
			if not live.is_empty():
				var z: InteriorZombie = live[k % live.size()]
				_shoot(z, bones[k % bones.size()], 160.0)
				k += 1
	samples.sort()
	rows.append({"mode": mode, "part": part, "view": "shooting 36 down (rifle, gore on)", "frames": samples.size(),
		"ms_p50": snappedf(_pct(samples, .5), .01), "ms_p95": snappedf(_pct(samples, .95), .01), "ms_p99": snappedf(_pct(samples, .99), .01),
		"ms_worst": snappedf(samples[-1], .01), "fps_median": snappedf(1000.0 / _pct(samples, .5), .1), "rounds": k})
	print("INTERIOR_ZLOAD_ROW ", JSON.stringify(rows[-1]))
	zombies.kill_all()
	await _settle_curve("massacre_settle", 6.0)
	await _measure("after: game caps (16 bodies, limbs, blood)", seconds, {"phase": "settled"})
	# Round two: another 36, to fill the decal and piece caps.
	for i in 36:
		var z := zombies.spawn(_next_spot())
		if z != null: mine.append(z)
	for i in 60:
		await process_frame
	k = 0
	begin = Time.get_ticks_msec()
	while Time.get_ticks_msec() - begin < 8000 and not zombies.alive().is_empty():
		await process_frame
		if Engine.get_process_frames() % 3 == 0:
			var live := zombies.alive()
			var z: InteriorZombie = live[k % live.size()]
			_shoot(z, bones[k % bones.size()], 160.0)
			k += 1
	zombies.kill_all()
	for i in 360:
		await process_frame
	await _measure("after round two: caps full", seconds, {"phase": "settled"})

# ---------------------------------------------------------------- co-op

func _coop_setup() -> bool:
	main.set_meta("performance_audit", true)
	s = main.coop
	s.host()
	s.fill_bots()
	s.start_game()
	for i in 20:
		await process_frame
	main._apply_quality(quality)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	m = s.mission
	for i in 4:
		m.debug_skip()
	m.harmless = true
	m.wave_left = 0
	stand = m.ground(m.Street.ORIGIN + Vector3(0, 0, 20))
	main.player.reset_motion(stand)
	main.player.rotation = Vector3(0, PI, 0)
	s.team[1].pos = stand
	for id in s.bots.bots:
		s.bots.bots[id].body.global_position = stand + Vector3(randf_range(-1.5, 1.5), .1, -1.5)
	for k in m.enemies.keys():
		m.enemies[k].queue_free()
		m.enemies.erase(k)
	_bots_hold(true)
	blood = s.blood()
	eye = stand + Vector3.UP * 1.6
	for i in 30:
		await process_frame
	return true

func _bots_hold(hold: bool) -> void:
	for id in s.bots.bots:
		s.bots.bots[id].reserve = 0 if hold else 300
		s.bots.bots[id].mag = 0 if hold else 17

func _coop_spawn_many(count: int) -> int:
	var made := 0
	var tries := 0
	while made < count and tries < count * 6:
		tries += 1
		var at: Vector3 = m.ground(stand + Vector3(randf_range(-4.5, 4.5), 0, 10 + (tries % 40) * .9 + randf_range(-.3, .3)))
		if not at.is_finite():
			continue
		if m.spawn(at) != null:
			made += 1
		if made % 6 == 5:
			await process_frame
	return made

func _coop_alive() -> Array:
	var out: Array = []
	for k in m.enemies.keys():
		var z = m.enemies[k]
		if is_instance_valid(z) and not z.dead and z.hp > 0:
			out.append(k)
	return out

## The host's own kill path (Mission.damage -> Session.fallen rpc -> Figure.go_limp); `tear` 0 keeps it whole.
## Corpses past the session's cap of 16 are moved to this script's list first, so they stay.
func _coop_kill(k: int, bone := "chest", tear := 0.0, keep_all := true) -> void:
	if keep_all and m.corpses.size() >= InteriorZombies.MAX_CORPSES:
		stash.append(m.corpses.pop_front())
	var z = m.enemies.get(k)
	if z == null:
		return
	m.damage(1, k, bone, z.global_position + Vector3.UP, Vector3(0, 0, 1), 999.0, 60.0, tear)

func _coop_restore_stash() -> void:
	# Back into the mission's list, so every infected's `underfoot` scan sees them as in the game.
	for c in stash:
		m.corpses.append(c)
	stash.clear()

func _coop_part_alive() -> void:
	await _measure("store road, squad of 5, 0 infected", seconds, {"n": 0})
	var have := 0
	for target in [10, 25, 50, 75, 100]:
		await _coop_spawn_many(target - have)
		have = target
		for i in 120:
			await process_frame
		await _measure("store road, %d infected chasing" % target, seconds, {"n": _coop_alive().size()})
		if target == 50:
			await _shot("alive_50")

func _coop_part_dead() -> void:
	await _measure("store road, 0 dead", seconds, {"n": 0})
	var have := 0
	for target in [10, 20, 40, 60, 100]:
		await _coop_spawn_many(target - have)
		for i in 30:
			await process_frame
		var batch := _coop_alive()
		for k in batch:
			_coop_kill(k)
			if m.corpses.size() >= InteriorZombies.MAX_CORPSES:
				pass
		have = target
		await _measure("%d dead, just killed %d (0-2.5 s)" % [target, batch.size()], 2.5, {"n": target, "batch": batch.size(), "phase": "falling"}, 0)
		await _settle_curve("coop_settle_after_%d" % target, 9.0)
		_coop_restore_stash()
		await _measure("%d dead, settled" % target, seconds, {"n": target, "phase": "settled"})
		if target == 100:
			await _shot("dead_100")
		if target in [20, 60, 100]:
			for c in m.corpses:
				if is_instance_valid(c): c.visible = false
			await _measure("%d dead, corpses hidden (ablation)" % target, 3.0, {"n": target, "ablation": "hidden"})
			for c in m.corpses:
				if is_instance_valid(c): c.visible = true
		# Hand the excess back to the stash before the next kills.
		while m.corpses.size() > InteriorZombies.MAX_CORPSES:
			stash.append(m.corpses.pop_front())
	_coop_restore_stash()
	# Every infected scans the dead underfoot: 30 alive with 100 dead vs 30 alive with 16.
	await _coop_spawn_many(30)
	for i in 120:
		await process_frame
	await _measure("30 infected chasing over 100 dead", seconds, {"n": 30, "corpses_present": m.corpses.size()})
	while m.corpses.size() > InteriorZombies.MAX_CORPSES:
		var c = m.corpses.pop_front()
		if is_instance_valid(c): c.queue_free()
	await _measure("30 infected chasing over 16 dead (session cap)", seconds, {"n": 30, "corpses_present": m.corpses.size()})

func _coop_part_massacre() -> void:
	await _measure("store road, 0 infected", seconds, {"n": 0})
	await _coop_spawn_many(40)
	for i in 120:
		await process_frame
	await _measure("40 infected coming, squad holding", seconds, {"n": 40})
	_bots_hold(false)
	await _measure("squad shooting them down (0-6 s)", 6.0, {"phase": "shooting"})
	await _measure("squad shooting (6-12 s)", 6.0, {"phase": "shooting"})
	# Host kills the rest with limb tears so the piece and decal caps fill.
	for k in _coop_alive():
		var z = m.enemies.get(k)
		if z == null: continue
		m.damage(1, k, "forearm.L", z.global_position + Vector3.UP, Vector3(0, 0, 1), 10.0, 60.0, 400.0)
		if m.enemies.has(k):
			_coop_kill(k, "chest", 0.0, false)
	await _settle_curve("coop_massacre_settle", 6.0)
	await _measure("after: bodies, limbs, blood (session caps)", seconds, {"phase": "settled"})

# ---------------------------------------------------------------- run

func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quality="): quality = int(a.trim_prefix("--quality="))
		if a.begins_with("--mode="): mode = a.trim_prefix("--mode=")
		if a.begins_with("--part="): part = a.trim_prefix("--part=")
		if a.begins_with("--seconds="): seconds = float(a.trim_prefix("--seconds="))
		if a.begins_with("--pass="): pass_tag = "_p" + a.trim_prefix("--pass=")
	seed(60060)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	for i in 40:
		await process_frame
	main.set_meta("performance_audit", true)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	if mode == "solo":
		await _solo_setup()
		match part:
			"alive": await _solo_part_alive()
			"dead": await _solo_part_dead()
			"limbs": await _solo_part_limbs()
			"decals": await _solo_part_decals()
			"massacre": await _solo_part_massacre()
	else:
		await _coop_setup()
		zombies = main.zombies
		match part:
			"alive": await _coop_part_alive()
			"dead": await _coop_part_dead()
			"massacre": await _coop_part_massacre()
	_save()
	print("INTERIOR_ZLOAD_DONE ", rows.size())
	if mode == "coop" and s != null:
		s.end_session()
	quit()
