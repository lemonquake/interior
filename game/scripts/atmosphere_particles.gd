class_name InteriorAtmosphereParticles
extends Node3D
## Air movement composed with ChiprChopr's Particle Scene Compositor and Profesor Shader's
## wind-driven particle simulation. Licenses and pinned sources: licenses/ATMOSPHERE.md.
## Fixed-size emitter pools, capped quality budgets, distance culling, and no per-frame allocation.

const ParticleGroup = preload("res://addons/particle_scene_compositor/sync_node_3d/gpu_particles/gpu_sync_node_3d.gd")
const WIND := preload("res://assets/atmosphere/shaders/wind_drift.gdshader")
const SPRITE := preload("res://assets/atmosphere/shaders/air_particle.gdshader")
const GROUND_Y := -2.9

var _player: InteriorPlayer
var _main: Node
var _groups: Array[Dictionary] = []
var _quality := 2
var _compatibility := false
var _poll := 0.0
var _elapsed := 0.0
var _outside := false
var _field_weight := 0.0
var _initialized := false
var _mist: Node3D
var _air: Node3D
var _hut: Node3D

func setup(main: Node, character: InteriorPlayer) -> void:
	if _initialized:
		return
	_initialized = true
	_main = main
	_player = character
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_compatibility = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	_hut = get_tree().get_first_node_in_group("hut_house") as Node3D
	add_to_group("atmosphere_particles")
	# These boxes stay inside the walls. Local dust never follows the camera through a wall.
	_dust("Living room dust", Vector3(-0.1, 1.45, 0.1), Vector3(5.0, 1.5, 4.2), Color(.82, .78, .64, .40), 88)
	_dust("Kitchen window dust", Vector3(-4.35, 1.55, .1), Vector3(1.45, 1.25, 3.6), Color(.57, .67, .85, .32), 40)
	_dust("Studio dust", Vector3(-3.4, 1.4, 5.15), Vector3(3.4, 1.65, 3.2), Color(.67, .63, .79, .28), 52)
	_build_outdoor_air()
	_build_lamp_moths()
	set_quality(_quality)
	_update_zones()

func set_quality(value: int) -> void:
	_quality = clampi(value, 0, 3)
	var multiplier: float = [0.28, 0.55, 1.0, 1.35][_quality]
	if _compatibility:
		multiplier *= .65
	for entry in _groups:
		for node: GPUParticles3D in entry.particles:
			var amount := maxi(3, roundi(float(node.get_meta("full_amount")) * multiplier))
			if node.amount != amount:
				node.amount = amount
			node.fixed_fps = 20 if _quality == 0 or _compatibility else 30
		if entry.active:
			(entry.hub as Node3D).call("restart", 2.0)

func _group(label: String, mode: String, at: Vector3, radius: float) -> Dictionary:
	var hub := ParticleGroup.new()
	hub.name = label
	hub.autostart = false
	hub.one_shot = false
	hub.free_on_finish = false
	hub.position = at
	hub.visible = false
	# The compositor owns synchronized loops, stop/restart, and child completion signals.
	# It lives for the scene's lifetime; all of its particles are freed with this parent.
	var entry := {"hub": hub, "mode": mode, "radius": radius, "particles": [],
		"materials": [], "presence": 0.0, "target": 0.0, "active": false}
	_groups.append(entry)
	add_child(hub)
	return entry

func _emitter(entry: Dictionary, label: String, amount: int, size: Vector2,
		box: Vector3, lifetime: float, tint: Color, shape: int, drift: float) -> GPUParticles3D:
	var particle := GPUParticles3D.new()
	particle.name = label
	particle.emitting = false
	particle.amount = amount
	particle.set_meta("full_amount", amount)
	particle.lifetime = lifetime
	particle.randomness = .65
	particle.local_coords = false
	particle.fixed_fps = 30
	particle.interpolate = true
	particle.layers = 1 if entry.mode == "indoor" else 2
	particle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particle.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	particle.visibility_aabb = AABB(-box * .5 - Vector3.ONE * 6.0, box + Vector3.ONE * 12.0)
	var process := ShaderMaterial.new()
	process.shader = WIND
	process.set_shader_parameter("box_emit_size", box)
	process.set_shader_parameter("grav", Vector3(0.0, -.006 if shape == 0 else 0.0, 0.0))
	process.set_shader_parameter("forward_speed_min", drift * .1)
	process.set_shader_parameter("forward_speed_max", drift * .5)
	process.set_shader_parameter("wind_direction", Vector3(.8, .04, .6).normalized())
	process.set_shader_parameter("wind_speed_min", drift * .25)
	process.set_shader_parameter("wind_speed_max", drift)
	process.set_shader_parameter("initial_rotation_xz", 1.2)
	process.set_shader_parameter("rot_speed_x", Vector2(.1, .4))
	process.set_shader_parameter("rot_speed_y", Vector2(.1, .6))
	process.set_shader_parameter("rot_speed_z", Vector2(.1, .5))
	process.set_shader_parameter("gust_response", 0.0 if entry.mode == "indoor" else 1.6)
	particle.process_material = process
	var mesh := QuadMesh.new()
	mesh.size = size
	var material := ShaderMaterial.new()
	material.shader = SPRITE
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("presence", 0.0)
	material.set_shader_parameter("shape", shape)
	material.set_shader_parameter("glow", .28 if shape == 2 else (.035 if shape == 0 else .015))
	material.set_shader_parameter("softness", .5 if shape == 1 else .08)
	if is_instance_valid(_hut) and entry.mode in ["mist", "air"]:
		material.set_shader_parameter("exclude_hut", true)
		material.set_shader_parameter("hut_inverse", _hut.global_transform.affine_inverse())
	mesh.material = material
	particle.draw_pass_1 = mesh
	(entry.hub as Node3D).add_child(particle)
	entry.particles.append(particle)
	entry.materials.append(material)
	return particle

func _dust(label: String, at: Vector3, box: Vector3, tint: Color, amount: int) -> void:
	var entry := _group(label, "indoor", at, 11.0)
	_emitter(entry, "Fine drifting dust", amount, Vector2(.012, .012), box, 13.0, tint, 0, .014)
	# A few larger flecks make the air readable when it crosses a lamp or window.
	_emitter(entry, "Near light flecks", maxi(6, amount / 5), Vector2(.024, .015), box * .8, 10.0,
		Color(tint.r, tint.g, tint.b, tint.a * .65), 0, .02)

func _build_outdoor_air() -> void:
	var entry := _group("Ground wisps", "mist", Vector3(0, GROUND_Y + .65, 0), 1000.0)
	_mist = entry.hub
	_emitter(entry, "Low broad wisps", 30, Vector2(5.5, 1.4), Vector3(34, .45, 34), 15.0,
		Color(.43, .5, .61, .13), 1, .2)
	_emitter(entry, "Thin moving strands", 18, Vector2(3.7, .65), Vector3(27, .35, 27), 11.0,
		Color(.54, .6, .68, .09), 1, .32)
	entry = _group("Outdoor drifting seeds", "air", Vector3.ZERO, 1000.0)
	_air = entry.hub
	_emitter(entry, "Airborne seed husks", 100, Vector2(.032, .013), Vector3(25, 2.0, 25), 10.0,
		Color(.55, .57, .6, .37), 0, .16)

func _build_lamp_moths() -> void:
	var count := 0
	for node in _main.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light is DirectionalLight3D or light.light_cull_mask != 2:
			continue
		if not (String(light.name).begins_with("Street lamp") or light.name in ["PorchLight", "CourtyardLight", "HutLanternLight"]):
			continue
		if count >= 7:
			break
		count += 1
		var entry := _group("Moths %d" % count, "lamp", light.global_position + Vector3.DOWN * .18, 32.0)
		entry["light"] = light
		var moths := _emitter(entry, "Moths near bulb", 9, Vector2(.042, .024), Vector3(.7, .55, .7), 3.6,
			Color(.74, .66, .48, .75), 2, .16)
		# Short-lived random flights stay near the bulb; no bright firefly trails around house lamps.
		(moths.process_material as ShaderMaterial).set_shader_parameter("forward_speed_max", .55)
		(moths.process_material as ShaderMaterial).set_shader_parameter("wind_speed_max", .04)

func _process(delta: float) -> void:
	if not _initialized or not is_instance_valid(_player):
		return
	_elapsed += delta
	_poll -= delta
	if _poll <= 0.0:
		_poll = .2
		_update_zones()
	for entry in _groups:
		if entry.active:
			for material: ShaderMaterial in entry.materials:
				material.set_shader_parameter("elapsed", _elapsed)
		var previous: float = entry.presence
		entry.presence = move_toward(previous, float(entry.target), delta * .7)
		if not is_equal_approx(previous, float(entry.presence)):
			for material: ShaderMaterial in entry.materials:
				material.set_shader_parameter("presence", entry.presence)
		if entry.active and entry.presence <= .001 and entry.target <= .001:
			var hub := entry.hub as Node3D
			hub.call("stop")
			hub.set_process(false)
			hub.visible = false
			for particle: GPUParticles3D in entry.particles:
				particle.speed_scale = 0.0
			entry.active = false

func _update_zones() -> void:
	if not is_instance_valid(_player) or _player.camera == null:
		return
	var camera := get_viewport().get_camera_3d()
	var eye := camera.global_position if camera != null else _player.camera.global_position
	_outside = eye.y < -.4 or eye.z < -17.0 or (eye.z > 2.62 and eye.x > .8)
	if is_instance_valid(_hut) and _hut.call("is_inside", eye):
		_outside = false
	_field_weight = InteriorFields.zone_weight(eye)
	if _mist != null:
		_mist.global_position = Vector3(eye.x, GROUND_Y + .65, eye.z)
	if _air != null:
		_air.global_position = Vector3(eye.x, GROUND_Y + 1.25, eye.z)
	for entry in _groups:
		# (0.64: a place a phone's squad game let go of took its lamps and their motes with it.)
		if not is_instance_valid(entry.hub):
			continue
		if String(entry.mode) == "lamp" and not is_instance_valid(entry.get("light")):
			entry.target = 0.0
			continue
		var hub := entry.hub as Node3D
		var near := hub.global_position.distance_to(eye) < float(entry.radius)
		var target := 0.0
		match String(entry.mode):
			"indoor":
				target = 1.0 if near and eye.y > -.4 else 0.0
			"mist":
				target = lerpf(.68, 1.0, _field_weight) if _outside and eye.y < -.4 else 0.0
			"air":
				target = lerpf(.48, .9, _field_weight) if _outside and eye.y < -.4 else 0.0
			"lamp":
				var light := entry.light as Light3D
				target = 1.0 if near and light.is_visible_in_tree() else 0.0
		entry.target = target
		if target > .001 and not entry.active:
			for particle: GPUParticles3D in entry.particles:
				particle.speed_scale = 1.0
			hub.visible = true
			hub.set_process(true)
			# restart() safely reuses the compositor's completion connections on zone re-entry.
			hub.call("restart", 2.0)
			entry.active = true

func debug_state() -> Dictionary:
	var particles := 0
	var active_groups := 0
	for entry in _groups:
		for particle: GPUParticles3D in entry.particles:
			particles += particle.amount
		if entry.active:
			active_groups += 1
	return {"quality": _quality, "groups": _groups.size(), "particles": particles,
		"active_groups": active_groups, "outside": _outside, "fields": _field_weight,
		"compositor": "Particle Scene Compositor", "compatibility": _compatibility}
