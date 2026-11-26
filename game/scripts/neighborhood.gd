class_name InteriorNeighborhood
extends Node3D
## Runtime glue for the neighbourhood (built by scripts/neighborhood_builder.gd inside the baked
## balcony scene). It only matters while the balcony is visible (door open or player outside):
## - model instances (trees, AC units, chairs) go on the outdoor visual layer, foliage gets alpha
##   scissor and small plants fade out with distance;
## - the night sky dome follows the camera and the camera's far plane opens up to it;
## - night (0.7): the room's WorldEnvironment gets a dark blue haze while the balcony shows. Outdoors
##   the ambient light turns moonlit blue and the colour grade cools; out on the dirt road the haze
##   opens up (the fields stretch to the horizon). Everything is restored indoors, so the room renders
##   exactly as before with the door shut.
## - mist (0.8): a faint, slowly drifting ground mist outside the house (scripts/night_mist.gdshader, adapted
##   from alghost's MIT fog shader) in a FogVolume that follows the camera, on desktop High and Ultra
##   (volumetric fog; the Compatibility renderer on Android has none and keeps the plain depth haze). It lies
##   in the streets, the courtyard and over the paddies alike and thins out below the balcony.
## The night sounds live in scripts/night_audio.gd.

const OUTDOOR_LAYER := 2
const FAR := 900.0
const MIST_SHADER := preload("res://scripts/night_mist.gdshader")
const MIST_SIZE := Vector3(180.0, 5.0, 180.0)
const GROUND_Y := -2.9
const WEATHERING := preload("res://scripts/neighborhood_weathering.gd")
const STREET_DECAY := preload("res://scripts/neighborhood_ground.gd")
const DERELICT := preload("res://scripts/neighborhood_derelict.gd")

var _env: Environment
var _saved_far := -1.0
var _active := false
var _tier := -2
var _outdoors := false
var _zone := -1.0
var _mobile := false
var _mist: FogVolume
var _lighting: InteriorLighting
var _outside_blend := 0.0
## 0.30: false while the districts are still being put up behind the loading screen (scripts/boot.gd).
var built := false

func _ready() -> void:
	add_to_group("neighbourhood")
	InteriorLoadClock.mark("neighbourhood: start")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	_mobile = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	for node in find_children("*", "Node3D", true, false):
		if node.has_meta("keep_instance"):
			var fade := float(node.get_meta("fade", 0.0))
			if _mobile and node.has_meta("tree") and fade == 0.0:
				fade = 160.0
			InteriorModelKit.prepare_instance(node, OUTDOOR_LAYER, fade, not _mobile or node.has_meta("tree"), node.has_meta("tree"))
	_shot_proxies()
	InteriorLoadClock.mark("neighbourhood: model instances")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	# Extend the authored/baked neighbourhood without rebaking the owner's room or exterior.
	var decay := {"ground": STREET_DECAY.build(self)}
	decay["facades"] = DERELICT.build(self)
	decay["surfaces"] = WEATHERING.apply(self)
	decay["vehicles"] = InteriorVehicleWeathering.apply(self)
	InteriorLoadClock.mark("neighbourhood: decay and weathering")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	var canal := preload("res://scripts/canal_settlement.gd").new()
	add_child(canal)
	await canal.build(self)
	InteriorLoadClock.mark("neighbourhood: canal settlement")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	# 0.21: the Nichols property beyond the south end of street B.
	var nichols := preload("res://scripts/nichols_property.gd").new()
	add_child(nichols)
	await nichols.build(self)
	InteriorLoadClock.mark("neighbourhood: Nichols property")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	# 0.23: the sheet-iron wall round the town, the survivors' path and what happened in the streets.
	# `-- --no-siege` leaves it out (A/B checks against 0.22).
	if not "--no-siege" in OS.get_cmdline_user_args():
		var siege := preload("res://scripts/town_siege.gd").new()
		add_child(siege)
		await siege.build(self)
	InteriorLoadClock.mark("neighbourhood: town siege")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	# 0.26: slits between walls and the empty ring round the Nichols fence are shut (scripts/map_seals.gd).
	if not "--no-seals" in OS.get_cmdline_user_args():
		InteriorMapSeals.attach(self)
	InteriorLoadClock.mark("neighbourhood: seals")
	if InteriorLoadClock.staged: await InteriorLoadClock.breathe()
	InteriorLoadClock.later(_install_interactions)
	decay["textured_street_litter"] = InteriorHorrorPropMaterials.dress_baked_litter(self)
	set_meta("abandoned_town", decay)
	_darken_windows()
	var dome := get_node_or_null("Sky dome") as MeshInstance3D
	if dome != null and dome.material_override is ShaderMaterial:
		InteriorNight.configure_sky(dome.material_override as ShaderMaterial)
	InteriorLoadClock.mark("neighbourhood: done")
	InteriorBuildCache.save()
	built = true

## 0.49: the baked street's vehicles, carts and stalls have a walking box each ("<model> collider"); rounds go on
## through the box and strike the model as drawn (InteriorModelKit.shot_proxy).
func _shot_proxies() -> void:
	var solids := get_node_or_null("NeighbourhoodColliders")
	if solids == null:
		return
	var models := {}
	for node in find_children("*", "Node3D", true, false):
		if node.has_meta("keep_instance") and not node.has_meta("tree"):
			models[String(node.name)] = node
	for c in solids.get_children():
		if not c is CollisionShape3D or not String(c.name).ends_with(" collider"):
			continue
		var model: Node3D = models.get(String(c.name).trim_suffix(" collider"))
		if model != null:
			InteriorModelKit.shot_proxy(c, model, "wood" if String(model.name).contains("cart") or String(model.name).contains("stall") else "metal")

func _install_interactions() -> void:
	InteriorLoadClock.mark("deferred: before interactions")
	# Runtime only: editor bakes must keep the original batches, not serialize converted gates.
	var scene := get_tree().current_scene
	if scene == null or not "player" in scene or has_node("Neighborhood interactions") or not has_node("NeighbourhoodColliders"):
		return
	var interactions := preload("res://scripts/neighborhood_interactions.gd").new()
	add_child(interactions)
	interactions.build(self)
	# 0.18: the warren's locked doors knock through the same gesture and remarks.
	var encounters := interactions.get_node_or_null("Quiet encounters")
	for door in get_tree().get_nodes_in_group("warren_locked"):
		door.controller = encounters
	# 0.18: every monobloc chair (yards, stalls, canal, warren) becomes a physical, pushable chair.
	var chairs := InteriorLooseProps.convert_chairs(self)
	# The tipped chair by the corner cart lay across street A's clear walking line (z 18.4); solid now, it rests
	# by the far kerb instead.
	for body in get_tree().get_nodes_in_group("movable"):
		if body.get_meta("loose_prop", "") == "chair" and body.has_node("Tipped chair") and absf(body.global_position.z - 18.6) < .6:
			body.global_position = Vector3(19.1, body.global_position.y, 20.15)
			body.home_transform = body.global_transform
			body.reset_physics_interpolation()
	var audio := get_tree().current_scene.get_node_or_null("RoomAudio")
	if audio != null and audio.has_method("_impact") and not audio.voices.is_empty():
		for body in get_tree().get_nodes_in_group("movable"):
			if not body.has_meta("loose_prop"): continue
			var wired := false
			for link: Dictionary in body.body_entered.get_connections():
				wired = wired or (link.callable as Callable).get_method() == "_impact"
			if not wired:
				body.body_entered.connect(audio._impact.bind(body))
	var decay: Dictionary = get_meta("abandoned_town", {})
	decay["chairs"] = chairs
	decay["interactions"] = interactions.get_meta("counts")
	set_meta("abandoned_town", decay)
	InteriorLoadClock.mark("deferred: interactions and chairs")

func _darken_windows() -> void:
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var material := mesh.material_override as StandardMaterial3D
		if material == null:
			continue
		if "curtain" in material.resource_name or "window glass" in material.resource_name:
			material = material.duplicate() as StandardMaterial3D
			material.emission_enabled = false
			material.albedo_color = Color(.045, .052, .055)
			material.roughness = .88
			material.metallic = .05
			mesh.material_override = material

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var shown := is_visible_in_tree()
	if shown != _active:
		_active = shown
		_apply_fog(shown)
		if camera != null:
			if shown:
				_saved_far = camera.far if _saved_far < 0.0 else _saved_far
				camera.far = FAR
			elif _saved_far > 0.0:
				camera.far = _saved_far
	var outdoors := shown and camera != null and (camera.global_position.y < -.4 or camera.global_position.z < -17.0 or camera.global_position.x < -33.0 or (camera.global_position.z > 2.62 and camera.global_position.x > .8))
	if outdoors != _outdoors:
		_outdoors = outdoors
		_apply_outdoors(outdoors)
	# Only the ground mist follows the doorway, fading in and out (the grade is the same on both sides).
	if not get_tree().paused or (camera != null and camera.has_meta("menu_camera")):
		_outside_blend = lerpf(_outside_blend, 1.0 if outdoors else 0.0, 1.0 - exp(-delta * 2.2))
		_blend_grade()
	if not _outdoors and _mist != null and _mist.visible and _outside_blend < .01:
		_set_mist(false)
	if not shown or camera == null:
		return
	if outdoors:
		_update_zone(InteriorFields.zone_weight(camera.global_position))
	if _mist != null and _mist.visible:
		_mist.global_position = Vector3(snappedf(camera.global_position.x, 4.0), GROUND_Y + 1.6, snappedf(camera.global_position.z, 4.0))
	var dome := get_node_or_null("Sky dome") as Node3D
	if dome != null:
		dome.global_position = camera.global_position
	if not is_instance_valid(_lighting):
		_lighting = InteriorLighting.find_in(get_tree().current_scene if get_tree().current_scene != null else get_parent())
	var tier := _lighting.tier if _lighting != null else 2
	if tier != _tier:
		_tier = tier
		_zone = -1.0
		_set_mist(_outdoors)
		var moon := get_parent().get_node_or_null("Moon") as DirectionalLight3D
		if moon != null:
			moon.directional_shadow_max_distance = 64.0 if tier >= 3 else (26.0 if tier >= 2 else 20.0)
			# 0.43: Low draws no moon shadow at all (a second pass over everything within 20 m: hundreds of draw
			# calls a frame on the CPU, which is what holds weaker PCs back).
			if not moon.has_meta("shadow_wanted"):
				moon.set_meta("shadow_wanted", moon.shadow_enabled)
			moon.shadow_enabled = bool(moon.get_meta("shadow_wanted")) and tier >= 1

func _environment() -> Environment:
	if _env != null:
		return _env
	for node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		_env = (node as WorldEnvironment).environment
		break
	return _env

func _apply_fog(on: bool) -> void:
	var env := _environment()
	if env == null:
		return
	env.fog_enabled = on
	if not on:
		return
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = InteriorNight.FOG_TOWN
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = .04
	env.fog_depth_begin = 8.0
	env.fog_depth_end = 150.0
	env.fog_depth_curve = 1.7
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.0
	env.fog_height = -2.2
	env.fog_height_density = 0.0

## Outdoors only adds the ground mist. The grade, ambient and exposure are the same inside the house and out
## (0.39, InteriorNight.apply_grade): until 0.38 they were swapped here as the camera crossed the navy door.
func _apply_outdoors(on: bool) -> void:
	var env := _environment()
	if env == null:
		return
	if on:
		_set_mist(true)
	else:
		# The mist is switched off by _process once it has faded out behind the player.
		_apply_fog(_active)

## Only the ambient colour moves, and only with the distance out into the rice fields, never at a doorway.
func _blend_grade() -> void:
	var env := _environment()
	if env == null:
		return
	var zone := maxf(_zone, 0.0)
	env.set_meta("night_zone", zone)
	env.ambient_light_color = InteriorNight.ambient_color(zone)
	# The mist fades in as the camera steps out instead of switching on at the door line.
	if _mist != null and _mist.visible:
		(_mist.material as ShaderMaterial).set_shader_parameter("base_density",
			lerpf(.009, .012, zone) * smoothstep(0.0, 1.0, _outside_blend))

## Called immediately after the lighting rig applies a quality preset, including while paused.
func refresh_quality() -> void:
	_blend_grade()
	_tier = -2

## Blends the haze from the close town fog to the open fields (weight 0..1). Both are kept light: just
## enough depth to the dark, never a grey wall.
func _update_zone(weight: float) -> void:
	if absf(weight - _zone) < .01:
		return
	_zone = weight
	var env := _environment()
	if env == null:
		return
	env.fog_light_color = InteriorNight.FOG_TOWN.lerp(InteriorNight.FOG_FIELDS, weight)
	env.fog_depth_begin = lerpf(8.0, 24.0, weight)
	env.fog_depth_end = lerpf(138.0, 315.0, weight)
	env.fog_depth_curve = lerpf(1.7, 1.5, weight)
	_set_mist(_outdoors)

## The ground mist: desktop High / Ultra only, outdoors only. No global volumetric density, so palms,
## roofs and poles stay dark against the sky; only the low layer in the FogVolume scatters the moon and
## the street lamps.
func _set_mist(on: bool) -> void:
	var env := _environment()
	var volumetric := on and not _mobile and _tier >= 2 and env != null and RenderingServer.get_current_rendering_method() != "gl_compatibility"
	if env != null:
		env.volumetric_fog_enabled = volumetric
	if volumetric:
		RenderingServer.environment_set_volumetric_fog_volume_size(128 if _tier >= 3 else 96, 96 if _tier >= 3 else 64)
		env.volumetric_fog_density = 0.0
		env.volumetric_fog_albedo = Color(.5, .56, .72)
		env.volumetric_fog_emission_energy = 0.0
		env.volumetric_fog_anisotropy = .45
		env.volumetric_fog_length = 96.0 if _tier >= 3 else 72.0
		env.volumetric_fog_detail_spread = 1.4
		env.volumetric_fog_ambient_inject = .2
		env.volumetric_fog_sky_affect = 0.0
		env.volumetric_fog_temporal_reprojection_enabled = true
		env.volumetric_fog_temporal_reprojection_amount = .85
		if _mist == null:
			_mist = FogVolume.new()
			_mist.name = "Ground mist"
			_mist.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
			_mist.size = MIST_SIZE
			var material := ShaderMaterial.new()
			material.shader = MIST_SHADER
			material.set_shader_parameter("ground_y", GROUND_Y)
			_mist.material = material
			add_child(_mist)
	if _mist != null:
		_mist.visible = volumetric
		if volumetric:
			# A touch thicker over the open paddies than between the houses.
			(_mist.material as ShaderMaterial).set_shader_parameter("base_density", lerpf(.009, .012, maxf(_zone, 0.0)) * smoothstep(0.0, 1.0, _outside_blend))
