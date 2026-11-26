class_name InteriorSenses
extends Node
## 0.33: what the infected can see and hear, and the lamps that can be shot out.
##
## Light. They are blind in the dark. `light_at` is how lit a place is (0 black, 1 under a lamp): every lamp, bulb,
## candle and moonbeam patch that is on, by distance and by whether a wall is between; the moon by itself counts
## for nothing. `visibility` is how plainly the player shows: the light where they stand, or all of it for a moment
## after a shot. 0.37: the torch by where it points (`exposure_to`): eyes in its beam see the player plainly, from
## anywhere else only what the beam throws back off what it lights shows them (more when it lights something near);
## and the lit spot itself (`beam_spot`) is something they can see and come to look at. scripts/zombie.gd sees by
## it and goes quiet where it is dark.
##
## 0.37: what stands between two places (`between`) is one rule for everyone: the player's ears
## (scripts/sound_stage.gd), the infected's ears, eyes and claws, the player's shove (scripts/body.gd) and the light
## on a place. Only the world as it shows counts (the unseen walls are not there). A pane of glass is seen through,
## heard through muffled and not reached through; a door leaf, a gate or a hung cloth hides and muffles less than
## a wall; an open doorway or a broken pane is open air.
##
## Sound. `noise(at, loudness)` is a sound that carries `loudness` metres in the open (what is between takes off
## by `muffle`: a wall about two fifths, a shot as much as anything else). Footsteps make one each (a slow walk a metre and a half, a run fifteen), so do a landing, a thrown thing
## coming down, a breaking bulb and a shot. Each of the infected within reach is told, with how loud it was to it.
##
## Lamps. A round that passes through a bulb (`shot_segment`) puts it out for good: glass, a spark, the dark.
## The scene is rebuilt on Restart, which brings them back.

## Below DARK a place is dark; at LIT a figure there is plain to see.
const DARK := .07
const LIT := .3
## How far a round may pass from a lamp's own point and still break it (m).
const BULB := .17
const STREET_BULB := .34
## Lamps that are not things: bounce and fill lights, glows, the torch, the weapon's own light.
const NOT_FIXTURES := ["moon", "bounce", "glow", "fill", "strip", "daylight", "tvglow", "candlebounce", "power strip", "debug", "flashlight", "refrigerator", "muzzle"]
const MASK := 2

var main: Node
var player: InteriorPlayer
## [Light3D, is spot, shootable]
var _lights: Array = []
var _visibility := 0.0
var _visibility_wait := 0.0
var _flash := 0.0
var _glass: AudioStream
var _spark_mesh: QuadMesh
var shot_out: Array[Light3D] = []
## The last few noises (tests and the debug readout): {at, loudness, kind, heard}.
var noises: Array = []
var _own_light := 0.0
## 0.37: where the torch's beam lands and how much it throws back on the player.
var beam_spot := Vector3.INF
var beam_normal := Vector3.UP
var _spill := 0.0
## How much each kind of thing between two places muffles a sound (a wall is 1).
const THROUGH_GLASS := .45
const THROUGH_LEAF := .6
## Debug menu and the older tests: everywhere counts as lit, so they see as they did before 0.33.
var daylight := false
## Debug menu: a line on the screen with the light on the player, how plainly they show and the last sound.
var readout := false:
	set(value):
		readout = value
		if value and _label == null and main != null:
			_label = Label.new()
			_label.name = "SensesReadout"
			_label.add_theme_font_size_override("font_size", 16)
			_label.add_theme_color_override("font_color", Color(.8, .95, .8))
			_label.add_theme_color_override("font_outline_color", Color.BLACK)
			_label.add_theme_constant_override("outline_size", 4)
			_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_label.position = Vector2(24, 96)
			main.hud.add_child(_label)
		if _label != null:
			_label.visible = value
var _label: Label

func setup(scene: Node) -> void:
	main = scene
	player = main.player
	name = "Senses"
	player.stepped.connect(_on_step)
	player.landed.connect(_on_landed)
	if ResourceLoader.exists("res://assets/audio/sfx/hit_glass.ogg"):
		_glass = load("res://assets/audio/sfx/hit_glass.ogg")
	get_tree().node_added.connect(_on_node_added)
	InteriorLoadClock.later(_collect)

func _collect() -> void:
	_lights.clear()
	for node in main.find_children("*", "Light3D", true, false):
		_add_light(node as Light3D)
	for node in get_tree().get_nodes_in_group("movable"):
		_watch(node)

func _on_node_added(node: Node) -> void:
	if node is Light3D:
		_add_light.call_deferred(node)
	elif node is InteriorObject:
		_watch.call_deferred(node)

func _watch(node: Node) -> void:
	if is_instance_valid(node) and node is InteriorObject and not (node as InteriorObject).impact.is_connected(_on_impact):
		(node as InteriorObject).impact.connect(_on_impact.bind(node))

func _add_light(light: Light3D) -> void:
	if not is_instance_valid(light) or light is DirectionalLight3D or not light.is_inside_tree():
		return
	if not (light is OmniLight3D or light is SpotLight3D) or light.get_viewport() != main.get_viewport():
		return
	# Not the flash of a shot or a spark: lamps that are here to stay.
	if light.has_meta("no_shoot") or String(light.name).to_lower().contains("muzzle") or String(light.name).to_lower().contains("flash "):
		return
	for entry: Array in _lights:
		if is_instance_valid(entry[0]) and entry[0] == light:
			return
	_lights.append([light, light is SpotLight3D, _is_fixture(light)])

## A lamp that is a thing a round can break: a named fixture, or an unnamed bulb that throws a shadow.
static func _is_fixture(light: Light3D) -> bool:
	if light.has_meta("no_shoot"):
		return false
	var label := String(light.name).to_lower()
	for word: String in NOT_FIXTURES:
		if label.contains(word):
			return false
	var parent := light.get_parent()
	if parent != null and (String(parent.name).to_lower().contains("flashlight") or String(parent.name).to_lower().contains("gunview")):
		return false
	if label.begins_with("@") and not light.shadow_enabled and not (parent != null and String(parent.name).to_lower().contains("bulb")):
		return false
	return true

# ---------------------------------------------------------------- light

## How lit `point` is, 0..1. With `walls` a wall between a lamp and the point shades it (the three strongest lamps
## are checked).
func light_at(point: Vector3, walls := true) -> float:
	if daylight:
		return 1.0
	var found: Array = []
	var dead := false
	for entry: Array in _lights:
		# (A lamp that has been freed must be passed over before it is given a type.)
		if not is_instance_valid(entry[0]):
			dead = true
			continue
		var light: Light3D = entry[0]
		if not light.visible or light.light_energy < .03 or not light.is_visible_in_tree():
			continue
		var at := light.global_position
		var to := point - at
		var reach: float = (light as SpotLight3D).spot_range if entry[1] else (light as OmniLight3D).omni_range
		var far2 := to.length_squared()
		if far2 > reach * reach:
			continue
		var far := sqrt(far2)
		var fall := pow(1.0 - far / reach, 1.25)
		if entry[1] and far > .05:
			var off := rad_to_deg((-light.global_basis.z).angle_to(to / far))
			var cone := (light as SpotLight3D).spot_angle
			if off > cone:
				continue
			fall *= clampf((cone - off) / maxf(cone * .25, 1.0), 0.0, 1.0)
		var amount := minf(light.light_energy, 3.0) * fall
		if amount > .015:
			found.append([amount, at])
	if dead:
		_lights = _lights.filter(func(entry: Array) -> bool: return is_instance_valid(entry[0]))
	if found.is_empty():
		return 0.0
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var total := 0.0
	var space := main.get_viewport().world_3d.direct_space_state if walls else null
	for index in found.size():
		var amount: float = found[index][0]
		if walls and index < 3 and space != null:
			var at: Vector3 = found[index][1]
			var way := point - at
			var far := way.length()
			if far > .6:
				if not sight_clear(point, at + way / far * .45):
					continue
		elif walls and index >= 3:
			amount *= .5
		total += amount
	return clampf(total, 0.0, 1.0)

func torch_on() -> bool:
	var story: Variant = main.get("story")
	if story == null or not is_instance_valid(story):
		return false
	var torch: Variant = story.get("flashlight")
	return torch != null and is_instance_valid(torch) and bool(torch.get("on"))

## How plainly the player shows, 0..1, to eyes that are not in the torch's beam.
func visibility() -> float:
	return 1.0 if daylight else _visibility

## 0.37: how plainly the player shows to eyes at `eye`, 0..1: in the torch's beam (it dazzles), all of it; anywhere
## else `visibility`, which counts what the beam throws back.
func exposure_to(eye: Vector3) -> float:
	if daylight:
		return 1.0
	var beam := torch_light()
	if beam != null and torch_on():
		var from := beam.global_position
		var to := eye - from
		var far := to.length()
		if far > .05 and far < beam.spot_range and rad_to_deg((-beam.global_basis.z).angle_to(to / far)) < beam.spot_angle \
				and sight_clear(from, eye):
			return 1.0
	return _visibility

## The torch's beam, when the player has the torch.
func torch_light() -> SpotLight3D:
	var story: Variant = main.get("story")
	if story == null or not is_instance_valid(story):
		return null
	var torch: Variant = story.get("flashlight")
	if torch == null or not is_instance_valid(torch):
		return null
	var light: Variant = torch.get("light")
	return light as SpotLight3D if light != null and is_instance_valid(light) else null

## Where the beam lands, and the light it throws back on whoever holds it: a wall a step away lights them up, the
## far end of a road hardly at all.
func _aim_torch() -> void:
	beam_spot = Vector3.INF
	_spill = 0.0
	var beam := torch_light()
	if beam == null or not torch_on() or not beam.is_inside_tree():
		return
	var from := beam.global_position
	var space := main.get_viewport().world_3d.direct_space_state
	var hit := InteriorSurfaces.seen_ray(space, from, from - beam.global_basis.z * beam.spot_range, MASK | 4, [player.get_rid()])
	if hit.is_empty():
		_spill = .1
		return
	beam_spot = hit.position
	beam_normal = hit.normal
	_spill = .1 + .22 * clampf(1.0 - from.distance_to(beam_spot) / 5.0, 0.0, 1.0)

# ---------------------------------------------------------------- 0.37: what is between

## What stands between `a` and `b`: {"walls", "glass", "leaves"} counts (up to six things along the line) and
## "first", where the first of them is (INF when nothing is). A pane already broken out, an open door and the
## unseen walls are not counted. Things within `slack` metres of `b` are not counted (a voice's own speaker box).
func between(a: Vector3, b: Vector3, mask := MASK, slack := 0.0) -> Dictionary:
	var out := {"walls": 0, "glass": 0, "leaves": 0, "first": Vector3.INF}
	var way := b - a
	var far := way.length()
	if far < .05 or main == null:
		return out
	var dir := way / far
	var space := main.get_viewport().world_3d.direct_space_state
	var windows: Variant = main.get("glass")
	var query := PhysicsRayQueryParameters3D.create(a, b, mask)
	var start := a
	var last_body: Object = null
	var last_at := Vector3.INF
	for i in 6:
		query.from = start
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		var on: Vector3 = hit.position
		if on.distance_to(b) < slack:
			break
		var shape := int(hit.get("shape", 0))
		# A wall built as two faces is met twice, going in and coming out: it is one wall.
		var same: bool = hit.collider == last_body and last_at.is_finite() and on.distance_to(last_at) < .6
		last_body = hit.collider
		last_at = on
		if not same and not InteriorSurfaces.unseen(hit.collider, shape):
			var kind := _barrier(hit.collider, shape, on, dir, hit.normal, windows)
			if kind != "":
				out[kind] = int(out[kind]) + 1
				if not (out.first as Vector3).is_finite():
					out.first = on
		if on.distance_to(b) < .06:
			break
		start = on + dir * .05
	return out

## "walls", "glass", "leaves", or "" for an opening (a pane already out).
func _barrier(collider: Object, shape: int, at: Vector3, dir: Vector3, normal: Vector3, windows: Variant) -> String:
	if windows != null and is_instance_valid(windows) and windows is InteriorWindowGlass:
		var glass := windows as InteriorWindowGlass
		var pane := glass.pane_at(collider, shape, at, dir)
		if pane >= 0:
			return "" if glass.is_broken(pane) else "glass"
	if collider is AnimatableBody3D:
		return "leaves"
	if collider != null and InteriorGun.surface_of(collider, shape, at, normal) == "fabric":
		return "leaves"
	return "walls"

## A clear line to see along: nothing but glass between (and only so much of that).
func sight_clear(a: Vector3, b: Vector3) -> bool:
	var d := between(a, b)
	return int(d.walls) == 0 and int(d.leaves) == 0

## Hands, claws, a shove: nothing at all between.
func reach_clear(a: Vector3, b: Vector3) -> bool:
	return not (between(a, b).first as Vector3).is_finite()

## How much is between for a sound: 0 open air, a pane .45, a door or a gate .6, a wall 1; more add up (to 2.5).
func muffle(a: Vector3, b: Vector3, slack := 0.0) -> float:
	var d := between(a, b, MASK, slack)
	return minf(float(d.walls) + THROUGH_GLASS * float(d.glass) + THROUGH_LEAF * float(d.leaves), 2.5)

## What is between takes this share of a sound's reach off (a wall about two fifths).
static func carry(muffled: float) -> float:
	return 1.0 / (1.0 + .7 * muffled)

## The light on the player alone (the debug readout).
func own_light() -> float:
	return _own_light

## A shot lights whoever fired it for a moment.
func flash(seconds := .35) -> void:
	_flash = maxf(_flash, seconds)
	_visibility = 1.0

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_flash = maxf(0.0, _flash - delta)
	_visibility_wait -= delta
	if _visibility_wait > 0.0:
		return
	_visibility_wait = .12
	_own_light = light_at(player.global_position + Vector3.UP * (.6 if player.crouching else 1.1))
	var now := _own_light
	_aim_torch()
	if torch_on():
		now = maxf(now, _spill)
	if _flash > 0.0:
		now = 1.0
	# Stepping into the light shows at once; stepping out of it takes a moment to be lost.
	_visibility = now if now > _visibility else move_toward(_visibility, now, .12 / .45)
	if readout and _label != null:
		var text := "light on me %.2f   shown %d%%%s" % [_own_light, int(_visibility * 100.0), "   (dark)" if _visibility < DARK else ""]
		if not noises.is_empty():
			var last: Dictionary = noises[-1]
			if Time.get_ticks_msec() - int(last.time) < 2500:
				text += "\nsound: %s, carries %.1f m, heard by %d" % [last.kind, last.loudness, last.heard]
		_label.text = text

# ---------------------------------------------------------------- sound

## A sound at `at` that carries `loudness` metres in the open.
func noise(at: Vector3, loudness: float, kind := "") -> int:
	var heard := 0
	var zombies: Variant = main.get("zombies")
	if zombies != null and is_instance_valid(zombies) and loudness > 0.0 and (zombies as InteriorZombies).can_target():
		for zombie: InteriorZombie in (zombies as InteriorZombies).alive():
			var where := zombie.where()
			var reach := loudness * zombie.hearing
			var far := where.distance_to(at)
			if far > reach:
				continue
			# 0.37: the same rule the player's ears go by (scripts/sound_stage.gd), shots included.
			if far > .8:
				reach *= carry(muffle(at + Vector3.UP * .9, where + Vector3.UP * 1.3))
				if far > reach:
					continue
			zombie.heard(at, 1.0 - far / reach, kind)
			heard += 1
	noises.append({"at": at, "loudness": loudness, "kind": kind, "heard": heard, "time": Time.get_ticks_msec()})
	if noises.size() > 12:
		noises.pop_front()
	return heard

## Metres a footstep of this strength carries (the strength scripts/player.gd gives each step: .12 slow, .3
## crouched, about .55 walking, 1 running), by what is underfoot.
static func step_loudness(strength: float, surface: String) -> float:
	var reach := 1.1 + 14.0 * pow(clampf(strength, 0.0, 1.0), 1.7)
	match surface:
		"metal", "tin", "gravel", "water", "wood_hollow":
			reach *= 1.3
		"grass", "dirt", "carpet", "mud", "sand":
			reach *= .75
	return reach

func _on_step(surface: String, strength: float) -> void:
	noise(player.global_position, step_loudness(strength, surface), "step")

func _on_landed(_surface: String, fall_speed: float) -> void:
	noise(player.global_position, clampf(3.0 - fall_speed * 1.5, 4.0, 13.0), "landing")

func _on_impact(strength: float, at: Vector3, _material: String, body: Node = null) -> void:
	# A thing thrown or knocked over: a blow that changed its speed by two metres a second or more. What merely
	# settles, or is leaned on, makes no sound worth turning for.
	if strength < 1.0 or player == null or not player.playing:
		return
	var mass := (body as RigidBody3D).mass if body is RigidBody3D else 1.0
	# 0.34: thrown hard enough at a window, it breaks the pane.
	var windows: Variant = main.get("glass")
	if windows != null and windows is InteriorWindowGlass:
		(windows as InteriorWindowGlass).thing_hit(at, strength, mass)
	if strength / maxf(mass, .05) >= 2.0:
		noise(at, clampf(3.0 + sqrt(strength) * 2.4, 0.0, 14.0), "thing")

# ---------------------------------------------------------------- lamps

## The lamp a round going from `a` to `b` passes through, if any (the first along the way).
func lamp_on_path(a: Vector3, b: Vector3) -> Light3D:
	var way := b - a
	var length := way.length()
	if length < .001:
		return null
	way /= length
	var best: Light3D = null
	var best_along := INF
	for entry: Array in _lights:
		if not entry[2] or not is_instance_valid(entry[0]):
			continue
		var light: Light3D = entry[0]
		if not light.visible or light.has_meta("shot_out") or not light.is_visible_in_tree():
			continue
		var to := light.global_position - a
		var along := to.dot(way)
		if along < 0.0 or along > length or along >= best_along:
			continue
		var miss := (to - way * along).length()
		if miss <= (STREET_BULB if String(light.name).begins_with("Street lamp") else BULB):
			best = light
			best_along = along
	return best

## Called for each straight piece of a round's flight. Returns the lamp it broke.
func shot_segment(a: Vector3, b: Vector3) -> Light3D:
	var lamp := lamp_on_path(a, b)
	if lamp != null:
		put_out(lamp)
	return lamp

func put_out(light: Light3D) -> void:
	if not is_instance_valid(light) or light.has_meta("shot_out"):
		return
	var at := light.global_position
	light.set_meta("shot_out", true)
	light.visible = false
	shot_out.append(light)
	# The glass that glowed: the bulb or lens hung beside the lamp.
	var beside: Array = light.get_children()
	if light.get_parent() != null:
		beside += light.get_parent().get_children()
	for node in beside:
		var mesh := node as MeshInstance3D
		if mesh == null or not mesh.visible or mesh.global_position.distance_to(at) > .2:
			continue
		var material := mesh.material_override as BaseMaterial3D
		if material != null and material.emission_enabled and mesh.get_aabb().get_longest_axis_size() < .5:
			mesh.visible = false
	_break_fx(at, light.light_color)
	noise(at, 10.0, "glass")

func _break_fx(at: Vector3, colour: Color) -> void:
	if _spark_mesh == null:
		_spark_mesh = QuadMesh.new()
		_spark_mesh.size = Vector2(.012, .05)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.albedo_color = Color(1.0, .82, .5)
		m.emission_enabled = true
		m.emission = Color(1.0, .7, .3)
		m.emission_energy_multiplier = 4.0
		_spark_mesh.material = m
	var sparks := CPUParticles3D.new()
	sparks.mesh = _spark_mesh
	sparks.one_shot = true
	sparks.explosiveness = .95
	sparks.amount = 26
	sparks.lifetime = .7
	sparks.direction = Vector3.DOWN
	sparks.spread = 75.0
	sparks.initial_velocity_min = 1.2
	sparks.initial_velocity_max = 4.5
	sparks.gravity = Vector3(0, -9.8, 0)
	sparks.scale_amount_min = .5
	sparks.scale_amount_max = 1.2
	sparks.particle_flag_align_y = true
	main.add_child(sparks)
	sparks.global_position = at
	sparks.emitting = true
	get_tree().create_timer(1.6, false).timeout.connect(sparks.queue_free)
	# The filament's last flash.
	var pop := OmniLight3D.new()
	pop.set_meta("no_shoot", true)
	pop.name = "Bulb glow dying"
	pop.light_color = colour.lerp(Color(.7, .85, 1.0), .5)
	pop.light_energy = 3.2
	pop.omni_range = 6.0
	pop.shadow_enabled = false
	main.add_child(pop)
	pop.global_position = at
	var tween := pop.create_tween()
	tween.tween_property(pop, "light_energy", 0.0, .16)
	tween.tween_callback(pop.queue_free)
	if _glass != null:
		var voice := AudioStreamPlayer3D.new()
		voice.stream = _glass
		voice.unit_size = 9.0
		voice.max_distance = 70.0
		voice.volume_db = 2.0
		voice.pitch_scale = randf_range(1.05, 1.3)
		if AudioServer.get_bus_index("Gun") >= 0:
			voice.bus = "Gun"
		main.add_child(voice)
		voice.global_position = at
		voice.play()
		voice.finished.connect(voice.queue_free)
