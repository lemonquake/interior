class_name InteriorHamster
extends Node3D

# A deterministic habitat resident. Steering follows the enclosure's clear
# corridor graph; it never takes a straight shortcut through a playground prop.
const MODEL = preload("res://assets/hamsters/hamster.glb")
const IDLES: Array[String] = ["idle_sniff", "idle_groom", "idle_rear", "idle_rest"]
var habitat: Node3D
var resident_id := 0
var compartment := 0
var seed_value := 71021
var state := "wander"
var active_clip := ""
var elapsed := 0.0
var state_time := 0.0
var duration := 0.0
var speed := 0.0
var animation_player: AnimationPlayer
var skeleton: Skeleton3D
var visited: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _model: Node3D
var _route: Array[Vector3] = []
var _route_index := 0
var _destination := "idle"
var _last_node := 0
var _scheduled_visit := 0
var _animation_names: Dictionary = {}
var visited_levels: Dictionary = {}
var _home_level := 0
var _target_level := 0
var _in_transfer := false
var _blocked_time := 0.0
var _visual_pivot: Node3D
var _yield_index := -1
var _yield_time := 0.0


func configure(owner_habitat: Node3D, index: int, habitat_level: int, deterministic_seed: int) -> void:
	habitat = owner_habitat
	resident_id = index
	compartment = habitat_level
	_home_level = habitat_level
	_target_level = habitat_level
	seed_value = deterministic_seed

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("hamsters")
	_rng.seed = seed_value
	_model = MODEL.instantiate() as Node3D
	_model.name = "AnimatedHamster"
	_model.scale = Vector3.ONE * 0.95
	_visual_pivot = Node3D.new()
	_visual_pivot.position.y = 0.028
	add_child(_visual_pivot)
	_visual_pivot.add_child(_model)
	_model.position.y = -0.028
	animation_player = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if animation_player == null:
		push_error("The hamster asset has no AnimationPlayer.")
		return
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for animation_name in animation_player.get_animation_list():
		var short_name := str(animation_name).get_slice("/", str(animation_name).get_slice_count("/") - 1)
		_animation_names[short_name] = animation_name
		animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
	# Small coat shifts make all three residents distinguishable without textures.
	var coat := _model.find_child("HamsterCoat", true, false) as MeshInstance3D
	if coat != null and coat.mesh != null:
		var material := coat.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
		material.vertex_color_use_as_albedo = true
		material.albedo_color = [Color(1, 0.92, 0.80), Color(0.78, 0.87, 1.0), Color(1, 1, 0.94)][resident_id % 3]
		coat.set_surface_override_material(0, material)
	position = habitat.path_node(compartment, resident_id % 3)
	_last_node = resident_id % 3
	visited_levels[compartment] = true
	_choose_destination()

func _physics_process(delta: float) -> void:
	simulate_step(delta)

func simulate_step(delta: float) -> void:
	if animation_player == null or habitat == null or not is_finite(delta) or delta <= 0:
		return
	elapsed += delta
	state_time += delta
	if state == "wander":
		_follow_route(delta)
	elif state == "wheel":
		habitat.spin_wheel(compartment, delta * 5.0)
		speed = 0.19
		_play("run", 1.0)
	elif state == "sand":
		_play("dig", 1.0)
	elif state == "food" or state == "water":
		_play("eat", 1.0 if state == "food" else 0.62)
	elif state == "hide":
		_play("idle_rest", 1.0)
	if state != "wander":
		_visual_pivot.rotation.x = move_toward(_visual_pivot.rotation.x, 0, delta * 5)
	if state != "wander" and state_time >= duration:
		_choose_destination()
	# Advance manually: a direct fixed-step stress harness and live physics share
	# identical state/pose timing, and pausing the scene freezes both.
	animation_player.advance(delta)

func _follow_route(delta: float) -> void:
	if _yield_time > 0:
		_yield_time -= delta
		_play("idle_sniff", 1.0)
		return
	if _route_index >= _route.size():
		_arrive()
		return
	var target := _route[_route_index]
	var offset := target - position
	var distance := offset.length()
	if distance < 0.003:
		position = target
		_route_index += 1
		if _route_index == _yield_index:
			_yield_time = 1.0
			_yield_index = -1
		return
	var target_speed := 0.18 if _in_transfer else (0.095 if _destination in ["hide", "water"] else 0.14)
	# Approach corners and stop at the interaction rather than sliding across it.
	if _route_index == _route.size() - 1:
		target_speed *= clampf(distance / 0.025, 0.30, 1.0)
	speed = move_toward(speed, target_speed, delta * 0.32)
	var travel := minf(distance, speed * delta)
	var next_position := position + offset / distance * travel
	if not habitat.can_advance(self, next_position):
		_blocked_time += delta
		speed = 0.0
		_play("idle_sniff", 1.0)
		if _blocked_time > 0.35:
			var detour: Dictionary = habitat.avoid_resident(self, target)
			if not detour.is_empty():
				_route_index = int(detour.skip) + 1
				if detour.get("yield", false):
					_yield_index = _route_index + detour.points.size()
				for index in range(detour.points.size() - 1, -1, -1):
					_route.insert(_route_index, detour.points[index])
				_blocked_time = 0.0
		return
	_blocked_time = 0.0
	position = next_position
	for level in 3:
		if absf(position.y - habitat.FLOORS[level]) < 0.022 and absf(position.x) < 0.36:
			visited_levels[level] = true
	var horizontal := Vector2(offset.x, offset.z).length()
	if horizontal > 0.001:
		var heading := atan2(offset.x, offset.z)
		rotation.y = lerp_angle(rotation.y, heading, minf(1.0, delta * 12.0))
	var pitch := -atan2(offset.y, horizontal) if _in_transfer else 0.0
	_visual_pivot.rotation.x = lerp_angle(_visual_pivot.rotation.x, pitch, minf(1.0, delta * 12.0))
	_play("walk", clampf(speed / 0.085, 0.30, 1.65))

func _choose_destination() -> void:
	# First visit every activity once, then choose independently from the seeded
	# random stream. This also makes first-load behavior useful and varied.
	var activities: Array[String] = ["wheel", "tunnel", "bridge", "tunnel", "sand", "food", "water", "hide", "idle"]
	if _scheduled_visit < activities.size():
		_destination = activities[(_scheduled_visit + resident_id * 2) % activities.size()]
	elif _scheduled_visit < activities.size() + IDLES.size():
		_destination = "idle"
	elif visited_levels.size() < 3:
		_destination = "tunnel"
	else:
		_destination = activities[_rng.randi_range(0, activities.size() - 1)]
		for activity in activities:
			if not visited.has(activity):
				_destination = activity
				break
	_scheduled_visit += 1
	habitat.release_activity(self)
	var plan: Dictionary = {}
	if _destination == "tunnel":
		_target_level = (compartment + 1) % 3
		plan = habitat.request_transfer(self, _target_level, _last_node)
		_in_transfer = not plan.is_empty()
		if not _in_transfer:
			_destination = "idle"
	if not _in_transfer:
		if not habitat.claim_activity(self, _destination):
			_destination = "idle"
		plan = habitat.route_to(compartment, _last_node, _destination)
	_route.clear()
	# Return from an interaction along its same unobstructed entry before taking
	# the graph to a new activity. Nearest-node shortcuts can cross a hide wall.
	if state != "wander":
		var retreat: Array = habitat.retreat_from(compartment, state)
		for point in retreat:
			_route.append(point)
	for point in plan.points:
		_route.append(point)
	_last_node = int(plan.node)
	_route_index = 0
	state = "wander"
	state_time = 0.0
	_play("walk", 0.8)

func _arrive() -> void:
	state = _destination
	if _in_transfer:
		compartment = _target_level
		visited_levels[compartment] = true
		habitat.traveller = -1
		_in_transfer = false
	state_time = 0.0
	speed = 0.0
	visited[state] = int(visited.get(state, 0)) + 1
	duration = _rng.randf_range(1.6, 3.2)
	if state == "wheel":
		rotation.y = PI * 0.5
		duration = _rng.randf_range(4.0, 7.0)
	elif state == "idle":
		var idle_name := IDLES[(int(visited.idle) + resident_id) % IDLES.size()]
		_play(idle_name, 1.0)
		visited[idle_name] = int(visited.get(idle_name, 0)) + 1
	elif state == "tunnel" or state == "bridge":
		# The interaction route already went through the open tunnel / over the
		# bridge. Pause at its exit to look around before returning to the corridor.
		_play("idle_sniff", 1.0)
	elif state == "hide":
		duration = _rng.randf_range(4.0, 8.0)
		_play("idle_rest", 1.0)
	elif state == "food":
		rotation.y = 0.0
	elif state == "water":
		rotation.y = PI * 0.5

func _play(clip: String, playback_speed: float) -> void:
	if not _animation_names.has(clip):
		return
	animation_player.speed_scale = playback_speed
	if clip != active_clip:
		active_clip = clip
		animation_player.play(_animation_names[clip], 0.14, 1.0)

func reset_resident() -> void:
	_rng.seed = seed_value
	compartment = _home_level
	_target_level = _home_level
	_in_transfer = false
	_yield_index = -1
	_yield_time = 0.0
	_blocked_time = 0.0
	visited_levels.clear()
	_visual_pivot.rotation = Vector3.ZERO
	animation_player.stop()
	active_clip = ""
	visited.clear()
	elapsed = 0.0
	state_time = 0.0
	speed = 0.0
	_scheduled_visit = 0
	state = "wander"
	rotation = Vector3.ZERO
	position = habitat.path_node(compartment, resident_id % 3)
	_last_node = resident_id % 3
	visited_levels[compartment] = true
	_choose_destination()
	animation_player.advance(0.0)

func snapshot() -> Dictionary:
	return {"resident": resident_id, "level": compartment, "position": [position.x, position.y, position.z], "state": state, "clip": active_clip, "elapsed": elapsed, "visited": visited.duplicate(), "visited_levels":visited_levels.duplicate(), "blocked_seconds":_blocked_time, "transfer":_in_transfer}
