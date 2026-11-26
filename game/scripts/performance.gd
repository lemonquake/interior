class_name InteriorPerformance
extends Node
## 0.26: one place that keeps the frame rate up on desktop (the Android budget stays in mobile_performance.gd).
##
## The whole world lives in one scene tree. Before this, fifty trees of 120-240 thousand triangles each were drawn
## (and drawn again into the moon's shadow cascades) from anywhere in town, no prop, light or decal had a distance
## limit, and 260 sleeping props ticked every physics frame. What this does:
## - range: every geometry instance without its own visibility range gets one from its size (a cup stops being
##   drawn at ~20 m, a cart at ~65 m, a house never). Trees get a range and a coarser level of detail, and only
##   cast moon shadows on High and Ultra, near the camera.
## - lights and decals fade out with distance, so a street never pays for the lamps of the next district.
## - zones: the furnished home is hidden once the camera is well away from it, the town once the camera is far up
##   the field road, and everything above ground while the camera is down in the Nichols cellar.
## - resolution: the 3D render scale (never the HUD) follows the graphics card's own time for the 3D view, a step a
##   second, between MIN_SCALE and full. The graphics level is never changed during play (0.33).
## - frame cap: 200 FPS with V-Sync off by default (Options: Frame rate).
## `-- --no-perf` switches all of it off (A/B measurements); `--perf-report` prints what was changed.
##
## 0.64: phones run it too (it was PC only): the zones, the trees, the light fades. Their distance limits for small
## things stay mobile_performance.gd's (measured on the phone renderer in 0.25), the frame cap stays the phone's own
## 60, and the render scale follows the frame time (a phone's renderer reports no GPU time): `_phone_scale`.

const TARGET_FPS := 132.0
const MIN_FPS := 100.0
## Longest side of the instance (m) -> distance (m) beyond which it is not drawn, on High.
const RANGE_STEPS := [[.4, 22.0], [1.0, 38.0], [2.5, 65.0], [6.0, 110.0]]
const RANGE_SCALE := [.5, .8, 1.0, 1.5]
const TREE_RANGE := [70.0, 115.0, 150.0, 230.0]
const TREE_SHADOW_RANGE := [0.0, 0.0, 18.0, 60.0]
const LOD_THRESHOLD := [5.0, 3.0, 1.6, 1.0]
const LIGHT_FADE := [26.0, 34.0, 44.0, 70.0]
const DECAL_FADE := [14.0, 20.0, 28.0, 45.0]
const MIN_SCALE := [.7, .75, .8, .85]
const TREE_HINTS := ["island_tree", "tree_small", "jacaranda", "palm_coconut", "banana", "searsia", "gianttree", "bank tree", "back tree"]
const HOME_MIN := Vector3(-7.2, -.6, -4.2)
const HOME_MAX := Vector3(4.2, 4.2, 10.5)
## Metres from the home's envelope within which its rooms are still drawn (the courtyard and the lane see in).
const HOME_REACH := 26.0
const FRAME_CAPS := [200, 144, 120, 60, 0]
const FRAME_LABELS := ["Frame rate: 200", "Frame rate: 144", "Frame rate: 120", "Frame rate: 60", "Frame rate: V-Sync"]

var main: Node
var enabled := true
var tier := 2
## Options "Keep the frame rate": the render scale follows the graphics card's load.
var adaptive := true
var frame_cap := 0
var scale := 1.0
var _max_scale := 1.0
var _tuned := false
var _ranged: Array = []          # [GeometryInstance3D, base range]
var _own_ranged: Array = []      # [GeometryInstance3D, its own range]
var _trees: Array[GeometryInstance3D] = []
var _lights: Array = []          # [Light3D, base fade]
var _decals: Array[Decal] = []
var _zone_timer := 0.0
var _sample_time := 0.0
var _gpu_ms := 0.0
var _measuring := false
var _home: Array[Node3D] = []
var _town: Array[Node3D] = []
var _surface: Array[Node3D] = []
var _tree_shadow_timer := 0.0
var _movers: Array[GeometryInstance3D] = []
var report := {}
## Set before `setup` on a phone.
var mobile := false
## A phone's render scale never drops below this share of the graphics level's own ceiling.
const PHONE_FLOOR := .72
var _frame_ms := 0.0
var _phone_log := 0

func setup(scene: Node) -> void:
	main = scene
	name = "Performance"
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = not "--no-perf" in OS.get_cmdline_user_args()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--frame-cap="):
			frame_cap = clampi(FRAME_CAPS.find(int(argument.trim_prefix("--frame-cap="))), 0, FRAME_CAPS.size() - 1)
	if not enabled:
		return
	if not mobile:
		apply_frame_cap(frame_cap)
	_tune_later()

func _tune_later() -> void:
	# The neighbourhood's interactions, chairs and the siege dressing are built a few frames after start
	# (and, behind the loading screen, the world itself is still going up).
	while InteriorLoadClock.staged:
		if not is_inside_tree(): return
		await get_tree().process_frame
	for i in 24:
		# (A restart can free the world while this waits.)
		if not is_inside_tree(): return
		await get_tree().process_frame
	tune()

func set_adaptive(on: bool) -> void:
	adaptive = on
	if not on and main != null:
		scale = _max_scale
		main.get_viewport().scaling_3d_scale = scale

func apply_frame_cap(index: int) -> void:
	frame_cap = clampi(index, 0, FRAME_CAPS.size() - 1)
	if not enabled or mobile or main.get("benchmarking") == true or main.has_meta("performance_audit"):
		return
	var cap: int = FRAME_CAPS[frame_cap]
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if cap == 0 else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = cap

## The frame rate the adaptive scale aims at: a little under the cap, or the display's own rate with V-Sync.
func target_fps() -> float:
	var cap: int = FRAME_CAPS[frame_cap]
	if cap == 0:
		return maxf(50.0, DisplayServer.screen_get_refresh_rate() - 3.0) if DisplayServer.screen_get_refresh_rate() > 1.0 else 57.0
	return minf(TARGET_FPS, cap * .92)

static func _is_tree(node: Node) -> bool:
	var walker := node
	for i in 4:
		if walker == null:
			return false
		if walker.has_meta("tree"):
			return true
		var label := String(walker.name).to_lower()
		for hint: String in TREE_HINTS:
			if label.contains(hint):
				return true
		walker = walker.get_parent()
	return false

## Walks the finished world once and records what can be limited by distance.
func tune() -> void:
	if not enabled or main == null:
		return
	_tuned = true
	_ranged.clear()
	_own_ranged.clear()
	_trees.clear()
	_lights.clear()
	_decals.clear()
	var counts := {"ranged": 0, "trees": 0, "lights": 0, "decals": 0, "kept": 0}
	for node in main.find_children("*", "GeometryInstance3D", true, false):
		var gi := node as GeometryInstance3D
		if gi.has_meta("perf_seen"):
			continue
		gi.set_meta("perf_seen", true)
		if gi is CPUParticles3D or gi is GPUParticles3D or gi is Label3D or gi.has_meta("no_range"):
			continue
		if String(gi.name).contains("Sky dome") or String(gi.name).contains("Moon"):
			continue
		if _is_tree(gi):
			_trees.append(gi)
			counts.trees += 1
			continue
		if mobile:
			continue
		if gi.visibility_range_end > 0.0:
			# Rice, grass and weeds already end somewhere: Low and Medium bring that in as well.
			_own_ranged.append([gi, gi.visibility_range_end])
			counts.kept += 1
			continue
		# Grass and weeds in one big multimesh never need a moon shadow.
		if gi is MultiMeshInstance3D and (String(gi.name).to_lower().contains("weed") or String(gi.name).to_lower().contains("grass")):
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var size := (gi.global_transform * gi.get_aabb()).size
		var longest := maxf(size.x, maxf(size.y, size.z))
		var base := 0.0
		for step: Array in RANGE_STEPS:
			if longest < float(step[0]):
				base = float(step[1])
				break
		if base > 0.0:
			_ranged.append([gi, base])
			counts.ranged += 1
	for node in main.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light is DirectionalLight3D or light.has_meta("perf_seen") or light.distance_fade_enabled:
			continue
		light.set_meta("perf_seen", true)
		# The room's own rig is hidden with the home; it never needs a fade inside its 10 m.
		if light.get_meta("light_type", "") != "":
			continue
		var reach := (light as OmniLight3D).omni_range if light is OmniLight3D else (light as SpotLight3D).spot_range
		_lights.append([light, reach])
		counts.lights += 1
	for node in main.find_children("*", "Decal", true, false):
		var decal := node as Decal
		if decal.distance_fade_enabled:
			continue
		_decals.append(decal)
		counts.decals += 1
	_home.clear()
	_town.clear()
	_surface.clear()
	for label in ["LivingRoom", "Studio"]:
		var node := main.get_node_or_null(label) as Node3D
		if node != null:
			_home.append(node)
	var neighbourhood := main.get_node_or_null("Balcony/Neighbourhood") as Node3D
	if neighbourhood != null:
		for child in neighbourhood.get_children():
			if not child is Node3D:
				continue
			var label := String(child.name)
			if label == "Sky dome" or label == "Ground mist":
				continue
			if label != "Nichols property":
				_surface.append(child)
			if label in ["Canal settlement", "Nichols property", "Town siege", "Models", "Neighborhood interactions"]:
				_town.append(child)
	report = counts
	apply_quality(tier)
	_still_shadows()
	if "--perf-report" in OS.get_cmdline_user_args():
		print("INTERIOR_PERFORMANCE ", JSON.stringify(counts))

func apply_quality(index: int) -> void:
	tier = clampi(index, 0, 3)
	if not enabled:
		return
	var viewport := main.get_viewport()
	_max_scale = viewport.scaling_3d_scale
	scale = _max_scale
	_frame_ms = 0.0
	viewport.mesh_lod_threshold = LOD_THRESHOLD[tier]
	if not _tuned:
		return
	var k: float = RANGE_SCALE[tier]
	for entry: Array in _ranged:
		# A prop freed during play (a spent magazine, a debug spawn) must be skipped before the cast: casting a
		# freed object is itself an error.
		if not is_instance_valid(entry[0]):
			continue
		var gi := entry[0] as GeometryInstance3D
		var reach := float(entry[1]) * k
		gi.visibility_range_end = reach
		gi.visibility_range_end_margin = reach * .12
		gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		# 0.33: out of doors, nothing under a metre throws a shadow below Ultra (a tin, a slipper, a clump of litter
		# under the moon: 750 draw calls a frame for shadows nobody can make out). Indoors they keep theirs.
		if float(entry[1]) <= 38.0:
			if not gi.has_meta("perf_cast"):
				gi.set_meta("perf_cast", gi.cast_shadow)
				gi.set_meta("perf_indoor", _indoors(gi))
			gi.cast_shadow = (gi.get_meta("perf_cast") as int) if tier >= 3 or gi.get_meta("perf_indoor") else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for entry: Array in _own_ranged:
		if is_instance_valid(entry[0]):
			var gi := entry[0] as GeometryInstance3D
			gi.visibility_range_end = float(entry[1]) * minf(1.0, k + .1)
	for tree in _trees:
		if not is_instance_valid(tree):
			continue
		if not tree.has_meta("perf_own_range"):
			tree.set_meta("perf_own_range", tree.visibility_range_end > 0.0)
		if not tree.get_meta("perf_own_range"):
			tree.visibility_range_end = TREE_RANGE[tier]
			tree.visibility_range_end_margin = 14.0
			tree.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		tree.lod_bias = [.35, .5, .75, 1.0][tier]
		if not tree.has_meta("perf_shadow"):
			tree.set_meta("perf_shadow", tree.cast_shadow)
	_tree_shadows(true)
	_mover_shadows()
	for entry: Array in _lights:
		if not is_instance_valid(entry[0]):
			continue
		var light := entry[0] as Light3D
		var fade: float = maxf(LIGHT_FADE[tier], float(entry[1]) * 2.5)
		light.distance_fade_enabled = true
		light.distance_fade_begin = fade
		light.distance_fade_length = fade * .25
		light.distance_fade_shadow = fade * .55
	for decal in _decals:
		if not is_instance_valid(decal):
			continue
		decal.distance_fade_enabled = true
		decal.distance_fade_begin = DECAL_FADE[tier]
		decal.distance_fade_length = DECAL_FADE[tier] * .3

const INDOOR_HINTS := ["livingroom", "studio", "nichols house", "basement", "cellar", "hut", "warren", "tunnel"]

## Inside a building (by the names of what it hangs under): small things there stand next to lamps.
static func _indoors(node: Node) -> bool:
	var walker := node.get_parent()
	for i in 6:
		if walker == null:
			return false
		var label := String(walker.name).to_lower()
		for hint: String in INDOOR_HINTS:
			if label.contains(hint):
				return true
		walker = walker.get_parent()
	return false

## A shadow map is only redrawn when something inside the light's reach moves. The hamsters, the fish and a few
## swaying things moved every frame, so all seven of the living room's shadow lights redrew ~380 draw calls each,
## every frame. Whatever moves continuously stops casting a shadow (below Ultra); doors, gates and props that
## move when used keep theirs.
func _still_shadows() -> void:
	var movers: Array[GeometryInstance3D] = []
	for node in main.find_children("*", "", true, false):
		if node is HamsterEnclosure or node is InteriorAquarium:
			for child in node.find_children("*", "GeometryInstance3D", true, false):
				movers.append(child as GeometryInstance3D)
	var before := {}
	var all := main.find_children("*", "GeometryInstance3D", true, false)
	for gi: GeometryInstance3D in all:
		if gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and not gi is GPUParticles3D:
			before[gi] = gi.global_transform
	for i in 9:
		await get_tree().process_frame
	for key in before:
		# (0.50: untyped: something freed during the nine frames, a jump clearing the infected, is skipped.)
		if not is_instance_valid(key): continue
		var gi := key as GeometryInstance3D
		if not gi.global_transform.is_equal_approx(before[key]) and not _is_tree(gi):
			var owner_body := gi.get_parent()
			# A prop still settling after the start is not a permanent mover.
			if owner_body is RigidBody3D or (owner_body != null and owner_body.get_parent() is RigidBody3D):
				continue
			movers.append(gi)
	for gi in movers:
		if is_instance_valid(gi) and not gi.has_meta("perf_mover"):
			gi.set_meta("perf_mover", gi.cast_shadow)
			_movers.append(gi)
	report["movers"] = _movers.size()
	_mover_shadows()
	if "--perf-report" in OS.get_cmdline_user_args():
		print("INTERIOR_PERFORMANCE_MOVERS ", _movers.size())

func _mover_shadows() -> void:
	for gi in _movers:
		if is_instance_valid(gi):
			gi.cast_shadow = (gi.get_meta("perf_mover") as int) if tier >= 3 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Trees only throw a moon shadow close to the camera: their shadow pass was most of the town's triangles.
func _tree_shadows(force := false) -> void:
	var camera := main.get_viewport().get_camera_3d()
	if camera == null:
		return
	var eye := camera.global_position
	var reach: float = TREE_SHADOW_RANGE[tier]
	for tree in _trees:
		if not is_instance_valid(tree) or not tree.has_meta("perf_shadow"):
			continue
		var wanted: int = tree.get_meta("perf_shadow")
		var near := reach > 0.0 and Vector2(tree.global_position.x - eye.x, tree.global_position.z - eye.z).length_squared() < reach * reach
		var cast: int = wanted if near else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if force or tree.cast_shadow != cast:
			tree.cast_shadow = cast

func _want(node: Variant, show: bool) -> void:
	# (Untyped: 0.64's phone squad game frees the Nichols property, which these lists still hold.)
	if not is_instance_valid(node):
		return
	# Only undo what this script hid: other scripts own these nodes' visibility otherwise.
	if not show and node.visible:
		node.visible = false
		node.set_meta("perf_hidden", true)
	elif show and not node.visible and node.has_meta("perf_hidden"):
		node.visible = true
		node.remove_meta("perf_hidden")

func _zones(camera: Camera3D) -> void:
	# (0.64: a phone's squad game frees the Nichols property: what is gone leaves these lists.)
	for list: Array in [_home, _surface, _town]:
		for i in range(list.size() - 1, -1, -1):
			if not is_instance_valid(list[i]):
				list.remove_at(i)
	var eye := camera.global_position
	# Home: hidden once the camera is well clear of it.
	var gap := (eye.clamp(HOME_MIN, HOME_MAX) - eye).length()
	for node in _home:
		_want(node, gap < HOME_REACH)
	# Down in the Nichols cellar and the wartime tunnel nothing above ground can be seen.
	var underground := eye.y < -2.3 and eye.x > -25.5 and eye.x < 1.2 and eye.z > -102.0 and eye.z < -91.0
	# The town's districts: gone once the camera is far up the field road (the haze ends at 315 m there).
	var far_north := eye.z > 400.0
	for node in _surface:
		_want(node, not underground and not (far_north and node in _town))
	for node in _town:
		if not node in _surface:
			_want(node, not far_north)

func _process(delta: float) -> void:
	if not enabled or main == null or not _tuned:
		return
	var camera := main.get_viewport().get_camera_3d()
	if camera == null:
		return
	_zone_timer -= delta
	if _zone_timer <= 0.0:
		_zone_timer = .2
		_zones(camera)
	_tree_shadow_timer -= delta
	if _tree_shadow_timer <= 0.0:
		_tree_shadow_timer = .5
		_tree_shadows()
	if not adaptive or main.get("benchmarking") == true or main.has_meta("performance_audit") or get_tree().paused:
		_sample_time = 0.0
		_gpu_ms = 0.0
		_frame_ms = 0.0
		return
	if mobile:
		_phone_scale(delta)
		return
	# 0.33 adaptive render scale, by what the graphics card itself reports for the 3D view. Before this it followed
	# the frame rate: a crowd of infected (a processor load no resolution helps) or one fast turn took the picture
	# down to half resolution in half-second steps, and then the graphics level itself was lowered in the middle
	# of play, which froze the game for up to seven seconds and never came back up. Now: the level is only ever
	# changed in Options, and the resolution moves a step a second, only while the card is the thing that is late.
	var viewport := main.get_viewport()
	if not _measuring:
		_measuring = true
		RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
		return
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid())
	if gpu <= 0.0:
		return
	_gpu_ms = gpu if _gpu_ms <= 0.0 else lerpf(_gpu_ms, gpu, 1.0 - exp(-delta / .5))
	_sample_time += delta
	if _sample_time < 1.0:
		return
	_sample_time = 0.0
	var budget := 1000.0 / target_fps()
	var floor_scale: float = minf(MIN_SCALE[tier], _max_scale)
	if _gpu_ms > budget and scale > floor_scale:
		scale = maxf(floor_scale, scale - .05)
		viewport.scaling_3d_scale = scale
	elif _gpu_ms < budget * .7 and scale < _max_scale:
		scale = minf(_max_scale, scale + .05)
		viewport.scaling_3d_scale = scale

## 0.64: a phone's render scale, by the frame time (its renderer has no GPU timer). A step a second: down while
## frames run long, up again while they are short, between PHONE_FLOOR of the level's ceiling and the ceiling (the
## level's pixel budget, mobile_performance.gd). A crowd that is a processor load can only take it down to the floor.
func _phone_scale(delta: float) -> void:
	var viewport := main.get_viewport()
	var ceiling := _max_scale
	var budgets: Node = main.get("mobile_performance")
	if is_instance_valid(budgets):
		ceiling = float(budgets.get("ceiling"))
	var ms := delta * 1000.0
	_frame_ms = ms if _frame_ms <= 0.0 else lerpf(_frame_ms, ms, 1.0 - exp(-delta / .6))
	_sample_time += delta
	if _sample_time < 1.0:
		return
	_sample_time = 0.0
	var budget := 1000.0 / maxf(float(Engine.max_fps), 30.0)
	var lowest := ceiling * PHONE_FLOOR
	scale = clampf(viewport.scaling_3d_scale, lowest, ceiling)
	if _frame_ms > budget * 1.12 and scale > lowest + .001:
		scale = maxf(lowest, scale - ceiling * .06)
	elif _frame_ms < budget * .82 and scale < ceiling - .001:
		scale = minf(ceiling, scale + ceiling * .04)
	viewport.scaling_3d_scale = scale
	report["phone_scale"] = scale
	# (Every 5 s on an Android phone: the frame rate and the scale in the log, for reports from real phones.)
	_phone_log += 1
	if OS.has_feature("android") and _phone_log % 5 == 0:
		print("INTERIOR_PHONE fps %.0f frame %.1f ms scale %.2f of %.2f" % [Engine.get_frames_per_second(), _frame_ms, scale, ceiling])
