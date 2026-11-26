class_name InteriorBlood
extends Node3D
## 0.28: what comes out of the infected when they are shot, and where it ends up.
##
## A round going into a body throws a red mist and drops out of the far side (the reference video's bursts). What
## leaves is followed: several throws out of the back of the wound, each a ray to the first wall, floor or prop it
## meets inside a few metres, where it lands as a splat. Close surfaces take big ones, far ones a scatter of drops;
## on a wall the picture's runs point down, on the ground it lies along the way it was thrown. Some falls straight
## under the wound, and a body that has come to rest spreads a pool. Nothing is cleaned up: decals stay where they
## fell (the oldest go only after MAX_DECALS), with a normal map and a low roughness so they take the moon, a lamp
## or the flashlight like something wet.
## The pictures are the project's own red-liquid graphics, recut by tools/zombie_assets.py.
##
## 0.29: blood is followed drop by drop.
##  - `drop` is one drop in the air: it leaves with a speed, falls under gravity, and where its arc meets a floor,
##    a wall or a prop it leaves a spot: round where it fell straight, drawn out where it struck at a slant. A hit
##    throws a cone of them out of the far side of the wound and a few back toward the gun.
##  - `bleed` is a wound that goes on bleeding: drops fall from it at its own rate, slower as the pressure goes,
##    wherever the wounded part is by then, so one that walks leaves a trail and one that stands leaves a puddle
##    (drops landing on the last spot widen it instead of stacking). A cut artery (`spurt`) pumps: a jet with
##    every beat, shorter each time.
##  - `sever_burst`, and the parts that come off (scripts/zombie_gore.gd), which are kept here.

const DIR := "res://assets/zombies/blood/"
const SOUNDS := "res://assets/audio/zombies/"
const MAX_DECALS := 340
const MAX_SPOTS := 460
const MAX_FLYING := 240
const MAX_BLEEDERS := 48
const MAX_PIECES := 20
const MAX_GIBS := 64
## Drops a second, all wounds together.
const DROP_BUDGET := 110.0
const MASK := 2 | 4
const DEPTH := .42

## Drops whose arcs are worked out in one frame on a phone; the rest wait a frame or two (a shotgun's load into a
## crowd asks for a hundred at once, eight rays each).
const LAUNCH_PER_FRAME := 40

var main: Node
var mobile := false
## 0.64: no Decal on this renderer (a phone's Compatibility): the marks are flat quads (scripts/blood_marks.gd).
var flat := false
var marks: InteriorBloodMarks
var _queued: Array = []
var _decals: Array[Node3D] = []
var _splats: Array = []
var _drops: Array = []
var _pools: Array = []
var _orm: ImageTexture
var _mist_mesh: QuadMesh
var _drop_mesh: QuadMesh
var _fade: Gradient
var _grow: Curve
var _frame := -1
var _bursts := 0
var _streams := {}
var _spots: Array[Node3D] = []
var _blots: Array = []
var _flying: Array = []
var _fly_mesh: MultiMesh
var _fly_node: MultiMeshInstance3D
var _bleeders: Array = []
var _budget := 0.0
var _pieces: Array = []
var _gibs: Array = []

func setup(main_node: Node) -> void:
	main = main_node
	mobile = bool(main.get("mobile")) or RenderingServer.get_current_rendering_method() == "gl_compatibility"
	name = "Blood"
	# 0.64: a phone gets all of it too (before this every splat, spot, pool, wound, drop and torn-off part was
	# skipped on a phone): as flat marks where a decal cannot be drawn.
	flat = RenderingServer.get_current_rendering_method() == "gl_compatibility" or "--flat-blood" in OS.get_cmdline_user_args()
	if flat:
		marks = InteriorBloodMarks.new()
		marks.setup()
		add_child(marks)
	for key: String in ["splat_a", "splat_b", "splat_c", "splat_d", "splat_e"]:
		_splats.append(_kit(key))
	for key: String in ["drops_a", "drops_b"]:
		_drops.append(_kit(key))
	for key: String in ["pool_a", "pool_b"]:
		_pools.append(_kit(key))
	# Occlusion 1, roughness .16, not metal: wet.
	var flat := Image.create(4, 4, false, Image.FORMAT_RGB8)
	flat.fill(Color(1.0, .16, 0.0))
	_orm = ImageTexture.create_from_image(flat)
	_fade = Gradient.new()
	_fade.set_color(0, Color(1, 1, 1, 1))
	_fade.set_color(1, Color(1, 1, 1, 0))
	_grow = Curve.new()
	_grow.add_point(Vector2(0.0, .3))
	_grow.add_point(Vector2(1.0, 1.0))
	# A fine haze, not a cloud: small, thin, gone in under half a second.
	# 0.43: denser and darker than 0.29's pink haze, which hardly read at night.
	_mist_mesh = _particle_mesh("mist.png", Vector2(.36, .36), Color(.34, .0, .008, .62), Color(.06, .0, .0))
	(_mist_mesh.material as StandardMaterial3D).albedo_texture = _haze()
	_drop_mesh = _particle_mesh("droplet.png", Vector2(.065, .065), Color(.32, .0, .006, 1.0), Color(.05, .0, .0))
	_build_drops()

func _kit(key: String) -> Array:
	# (The flat marks draw from one sheet: the separate pictures are not even read.)
	if flat:
		return [null, null, key]
	return [load(DIR + key + "_albedo.png"), load(DIR + key + "_normal.png"), key]

## Where a mark on the world hangs: the flat marks' own node (it batches them), or here.
func _world() -> Node3D:
	return marks if flat else self

## A decal's centre sits `lift` off the surface (its box projects down onto it); a flat mark lies on it.
func _lay(node: Node3D, basis: Basis, point: Vector3, up: Vector3, lift: float) -> void:
	# (A prop struck as it was being freed: the mark goes with it.)
	if not node.is_inside_tree():
		node.queue_free()
		return
	node.global_transform = Transform3D(basis, point + up * (0.0 if flat else lift))

func _particle_mesh(texture: String, size: Vector2, colour: Color, glow: Color) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = load(DIR + texture)
	m.albedo_color = colour
	# A little of its own light, or a burst in the dark between muzzle flashes would be black.
	m.emission_enabled = true
	m.emission = glow
	quad.material = m
	return quad

func count() -> int:
	var live := 0
	for decal in _decals:
		live += 1 if is_instance_valid(decal) else 0
	return live

## 0.63 (owner, for frame rate: once the squad faces Heavy-arm the night's old mess goes): every splat, spot, torn-off
## part and gib farther than `radius` from all of `keep` freed. What lies round the squad stays. Returns how many went.
func clear_away(keep: Array, radius: float) -> int:
	var gone := 0
	var r2 := radius * radius
	for list: Array in [_decals, _spots, _pieces, _gibs]:
		for i in range(list.size() - 1, -1, -1):
			var n: Variant = list[i]
			if not is_instance_valid(n):
				list.remove_at(i)
				continue
			if n is Node3D and (n as Node3D).is_inside_tree():
				var at := (n as Node3D).global_position
				var near := false
				for k: Vector3 in keep:
					if at.distance_squared_to(k) < r2:
						near = true
						break
				if near: continue
			(n as Node).queue_free()
			list.remove_at(i)
			gone += 1
	return gone

func clear() -> void:
	for decal in _decals + _spots:
		if is_instance_valid(decal):
			decal.queue_free()
	_decals.clear()
	_spots.clear()
	for node in _pieces + _gibs:
		if is_instance_valid(node):
			node.queue_free()
	_pieces.clear()
	_gibs.clear()
	_flying.clear()
	_bleeders.clear()
	if _fly_mesh != null:
		_fly_mesh.visible_instance_count = 0

# ---------------------------------------------------------------- a hit

## A round has gone into `body` at `point`, travelling along `dir`.
func wound(_zombie: Node3D, _body: Node3D, point: Vector3, dir: Vector3, dealt: float, head: bool) -> void:
	var power := clampf(dealt / 40.0, .35, 2.4) * (1.5 if head else 1.0)
	var frame := Engine.get_physics_frames()
	if frame != _frame:
		_frame = frame
		_bursts = 0
	_bursts += 1
	if _bursts <= 3:
		_burst(point, dir, power)
		_sound(point, "flesh_%d" % (1 + randi() % 6), -2.0)
		if head or dealt > 40.0:
			_sound(point, "sploosh_%d" % (1 + randi() % 3), -1.0)
	elif _bursts == 5:
		# The fifth thing to arrive in one instant: a load of shot going in together.
		_sound(point, "sploosh_%d" % (1 + randi() % 3), 2.0)
		_sound(point, "pellets_%d" % (1 + randi() % 2), 1.0)
	if not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	# Out of the far side, onto whatever is behind.
	var throws := (2 + int(power * 2.5)) if _bursts <= 4 else 1
	for i in throws:
		var way := (dir + Vector3(randf_range(-.45, .45), randf_range(-.5, .28), randf_range(-.45, .45))).normalized()
		var reach := 1.1 + 3.4 * power * randf_range(.45, 1.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point, point + way * reach, MASK))
		if hit.is_empty():
			# It falls short of anything: onto the ground under where it ran out of speed.
			var from := point + way * reach * .6
			hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 3.2, MASK))
			if not hit.is_empty():
				_splat(hit.position, hit.normal, way, randf_range(.16, .34) * sqrt(power), hit.collider)
			continue
		var near := 1.0 - clampf(point.distance_to(hit.position) / reach, 0.0, 1.0)
		_splat(hit.position, hit.normal, way, lerpf(.2, .8, near) * sqrt(power) * randf_range(.75, 1.25), hit.collider)
	# 0.29: and drop by drop. Out of the far side in a cone, fast and fine; a few back toward the gun, slower.
	if _bursts <= 5:
		var side := dir.cross(Vector3.UP if absf(dir.y) < .9 else Vector3.RIGHT).normalized()
		var rise := side.cross(dir)
		for i in 5 + int(power * 7.0):
			var out := (dir + side * randf_range(-.55, .55) + rise * randf_range(-.35, .6)).normalized()
			drop(point + dir * .06, out * randf_range(1.6, 4.2 + 2.6 * power), randf_range(.014, .04) * sqrt(power))
		for i in 2 + int(power * 2.0):
			var back := (-dir + side * randf_range(-.7, .7) + rise * randf_range(-.3, .8)).normalized()
			drop(point - dir * .04, back * randf_range(.7, 2.4), randf_range(.012, .028))
	# And straight down from the wound.
	if _bursts <= 4:
		var under := point + Vector3(randf_range(-.25, .25), 0, randf_range(-.25, .25))
		var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(under, under + Vector3.DOWN * 2.4, MASK))
		if not ground.is_empty():
			_splat(ground.position, ground.normal, dir, randf_range(.2, .42), ground.collider)

## One landing: a splat (a scatter of drops when small) lying on the surface it hit.
func _splat(point: Vector3, normal: Vector3, way: Vector3, size: float, collider: Object) -> void:
	var up := normal.normalized()
	var wall := absf(up.y) < .6
	var kit: Array
	if size < .3 and randf() < .65:
		kit = _drops[randi() % _drops.size()]
		size *= 1.5
	elif not wall and size > .55 and randf() < .35:
		kit = _pools[randi() % _pools.size()]
	else:
		kit = _splats[randi() % _splats.size()]
	# The picture's bottom (the decal's +Z): down a wall, along the throw on a floor.
	var along := Vector3.DOWN if wall else way
	along -= up * along.dot(up)
	if along.length() < .05:
		along = up.cross(Vector3.RIGHT if absf(up.x) < .9 else Vector3.UP)
	along = along.normalized()
	var across := up.cross(along).normalized()
	var graze := 1.0 + .7 * (1.0 - absf(way.dot(up))) * randf()
	var decal := _decal(kit, Vector3(size * randf_range(.85, 1.15), DEPTH, size * graze))
	var parent: Node3D = collider as Node3D if collider is RigidBody3D else _world()
	parent.add_child(decal)
	# Mostly in front of the surface, so a thin wall's other face stays clean.
	_lay(decal, Basis(across, up, along), point, up, DEPTH * .5 - .11)

func _decal(kit: Array, size: Vector3) -> Node3D:
	if flat:
		var mark := marks.mark(str(kit[2]), size, Color(.92, .8, .8), 38.0)
		_keep_decal(mark)
		return mark
	var decal := Decal.new()
	decal.name = "Blood"
	decal.size = size
	decal.texture_albedo = kit[0]
	decal.texture_normal = kit[1]
	decal.texture_orm = _orm
	decal.modulate = Color(.92, .8, .8)
	decal.albedo_mix = 1.0
	decal.normal_fade = .35
	decal.upper_fade = .25
	decal.lower_fade = .25
	decal.cull_mask = 0xFFFFF
	decal.distance_fade_enabled = true
	decal.distance_fade_begin = 38.0
	decal.distance_fade_length = 10.0
	decal.add_to_group("blood_decals")
	_keep_decal(decal)
	return decal

func _keep_decal(decal: Node3D) -> void:
	_decals.append(decal)
	if _decals.size() > MAX_DECALS:
		var old: Node3D = _decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()

## 0.43: a wound that stays on the struck part and runs (the co-op infected had none). `holder` keeps its last six.
func mark_wound(holder: Node, body: Node3D, point: Vector3, dir: Vector3, layer: int) -> void:
	if not is_instance_valid(body) or not is_instance_valid(holder):
		return
	var list: Array = holder.get_meta("wounds", [])
	while list.size() >= 6:
		var old: Variant = list.pop_front()
		if is_instance_valid(old):
			(old as Node).queue_free()
	var decal := wound_decal()
	decal.set("cull_mask", layer)
	body.add_child(decal)
	var y := -dir.normalized()
	var down := Vector3.DOWN - y * Vector3.DOWN.dot(y)
	if down.length() < .1:
		down = y.cross(Vector3.RIGHT)
	var z := down.normalized()
	decal.global_transform = Transform3D(Basis(y.cross(z), y, z), point)
	var run := randf_range(.08, .2)
	var tween := decal.create_tween().set_parallel(true)
	var start_size: Vector3 = decal.get("size")
	tween.tween_property(decal, "size", start_size + Vector3(.03, 0, run), randf_range(3.0, 6.0)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(decal, "position", decal.position + decal.basis.z * run * .5, 4.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	list.append(decal)
	holder.set_meta("wounds", list)

## A small one for the body itself (scripts/zombie.gd parents it to the struck part).
func wound_decal() -> Node3D:
	if flat:
		return marks.wound()
	var decal := Decal.new()
	decal.name = "Wound"
	decal.size = Vector3(.17, .26, .17)
	var kit: Array = _splats[2 + randi() % 3]
	decal.texture_albedo = kit[0]
	decal.texture_normal = kit[1]
	decal.texture_orm = _orm
	decal.modulate = Color(.75, .55, .55)
	decal.albedo_mix = 1.0
	decal.normal_fade = .2
	return decal

## A body has come to rest: it bleeds into a pool that spreads for a while.
func pool(at: Vector3) -> void:
	if not is_inside_tree():
		return
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * .3, at + Vector3.DOWN * 2.5, MASK))
	if hit.is_empty():
		return
	var up: Vector3 = (hit.normal as Vector3).normalized()
	var along := up.cross(Vector3.RIGHT if absf(up.x) < .9 else Vector3.UP).normalized().rotated(up, randf() * TAU)
	var full := randf_range(1.0, 1.6)
	var decal := _decal(_pools[randi() % _pools.size()], Vector3(.25, DEPTH, .25))
	_world().add_child(decal)
	_lay(decal, Basis(up.cross(along).normalized(), up, along), hit.position as Vector3, up, DEPTH * .5 - .11)
	var tween := decal.create_tween()
	tween.tween_property(decal, "size", Vector3(full, DEPTH, full), randf_range(7.0, 11.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sound(hit.position, "splat_%d" % (1 + randi() % 2), -10.0)

# ---------------------------------------------------------------- the burst

func _burst(point: Vector3, dir: Vector3, power: float) -> void:
	var basis := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < .95 else Vector3.RIGHT)
	var mist := CPUParticles3D.new()
	mist.name = "BloodMist"
	mist.one_shot = true
	var puff := minf(power, 2.4)
	mist.amount = 10 + int(power * 7.0)
	mist.explosiveness = .92
	mist.lifetime = .42
	mist.mesh = _mist_mesh
	mist.direction = Vector3(0, 0, -1)
	mist.spread = 32.0
	mist.initial_velocity_min = .8
	mist.initial_velocity_max = 3.2 + 1.6 * puff
	mist.damping_min = 4.0
	mist.damping_max = 7.5
	mist.gravity = Vector3(0, -1.6, 0)
	mist.scale_amount_min = .3 * sqrt(puff)
	mist.scale_amount_max = .85 * sqrt(puff)
	mist.scale_amount_curve = _grow
	mist.angle_max = 360.0
	mist.color_ramp = _fade
	_emit(mist, Transform3D(basis, point + dir * .05), 1.0)
	var drops := CPUParticles3D.new()
	drops.name = "BloodDrops"
	drops.one_shot = true
	drops.amount = 22 + int(power * 18.0)
	drops.explosiveness = 1.0
	drops.lifetime = .85
	drops.mesh = _drop_mesh
	drops.direction = Vector3(0, .25, -1)
	drops.spread = 40.0
	drops.initial_velocity_min = 1.4
	drops.initial_velocity_max = 5.5 + 2.5 * power
	drops.gravity = Vector3(0, -9.8, 0)
	drops.scale_amount_min = .5
	drops.scale_amount_max = 1.5
	drops.color_ramp = _fade
	_emit(drops, Transform3D(basis, point), 1.3)

func _emit(particles: CPUParticles3D, at: Transform3D, life: float) -> void:
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.layers = 3
	add_child(particles)
	particles.global_transform = at
	particles.emitting = true
	get_tree().create_timer(life, false).timeout.connect(particles.queue_free)

func _sound(at: Vector3, key: String, volume: float) -> void:
	if not _streams.has(key):
		var path := SOUNDS + key + ".ogg"
		_streams[key] = load(path) if ResourceLoader.exists(path) else null
	var stream: AudioStream = _streams[key]
	if stream == null:
		return
	var voice := AudioStreamPlayer3D.new()
	voice.stream = stream
	voice.unit_size = 4.0
	voice.max_distance = 50.0
	voice.volume_db = volume
	voice.pitch_scale = randf_range(.88, 1.12)
	if AudioServer.get_bus_index("Gun") >= 0:
		voice.bus = "Gun"
	add_child(voice)
	voice.global_position = at
	voice.play()
	get_tree().create_timer(1.2, false).timeout.connect(voice.queue_free)

# ---------------------------------------------------------------- drop by drop

func spots() -> int:
	var live := 0
	for decal in _spots:
		live += 1 if is_instance_valid(decal) else 0
	return live

func flying() -> int:
	return _flying.size()

func bleeders() -> int:
	return _bleeders.size()

func parts() -> int:
	var live := 0
	for node in _pieces + _gibs:
		live += 1 if is_instance_valid(node) else 0
	return live

## The drops in the air: one mesh, drawn as many times as there are drops. And the stains they leave.
func _build_drops() -> void:
	for seed_value in 4:
		_blots.append(_blot(seed_value))
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = load(DIR + "droplet.png")
	m.albedo_color = Color(.3, .008, .01, 1.0)
	m.emission_enabled = true
	m.emission = Color(.03, .0, .0)
	quad.material = m
	_fly_mesh = MultiMesh.new()
	_fly_mesh.transform_format = MultiMesh.TRANSFORM_3D
	_fly_mesh.mesh = quad
	_fly_mesh.instance_count = MAX_FLYING
	_fly_mesh.visible_instance_count = 0
	_fly_node = MultiMeshInstance3D.new()
	_fly_node.name = "Drops"
	_fly_node.multimesh = _fly_mesh
	_fly_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fly_node.layers = 3
	_fly_node.custom_aabb = AABB(Vector3(-600, -60, -600), Vector3(1200, 160, 1200))
	_fly_node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_fly_node)

## The haze a round knocks out of a body: soft all the way to its edge, a little uneven, no shape of its own.
func _haze() -> ImageTexture:
	var size := 48
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x - size * .5 + .5, y - size * .5 + .5) / (size * .5)
			var a := atan2(d.y, d.x)
			var edge := .86 + .08 * sin(a * 3.0 + .7) + .05 * sin(a * 5.0 + 2.0)
			var v := clampf(1.0 - d.length() / edge, 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, v * v * (3.0 - 2.0 * v) * v))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

## A blot: a round stain with an uneven edge and a few small ones thrown off it.
func _blot(seed_value: int) -> ImageTexture:
	var size := 64
	var rng := RandomNumberGenerator.new()
	rng.seed = 40 + seed_value
	var lobes: Array[Vector3] = []
	for k in 5:
		lobes.append(Vector3(rng.randf_range(2.0, 9.0), rng.randf_range(0.0, TAU), rng.randf_range(.02, .09)))
	var satellites: Array[Vector3] = []
	for k in 2 + seed_value:
		var angle := rng.randf_range(0.0, TAU)
		var far := rng.randf_range(.72, .92)
		satellites.append(Vector3(cos(angle) * far, sin(angle) * far, rng.randf_range(.04, .09)))
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x - size * .5 + .5, y - size * .5 + .5) / (size * .5)
			var r := d.length()
			var a := atan2(d.y, d.x)
			var edge := .58
			for lobe in lobes:
				edge += sin(a * round(lobe.x) + lobe.y) * lobe.z
			var alpha := 1.0 - smoothstep(edge - .07, edge, r)
			for satellite in satellites:
				alpha = maxf(alpha, 1.0 - smoothstep(satellite.z - .03, satellite.z, d.distance_to(Vector2(satellite.x, satellite.y))))
			# Thinner toward the rim, where it has soaked in.
			var body := lerpf(1.0, .75, smoothstep(edge * .4, edge, r))
			image.set_pixel(x, y, Color(.3 * body, .012, .014, alpha * .96))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

## One drop leaves `from` at `velocity`. Its arc is followed to the first thing it meets; it is drawn falling, and
## leaves a spot there. `bleeder` is the wound it came from, if it dripped from one.
func drop(from: Vector3, velocity: Vector3, size: float, bleeder: Variant = null) -> void:
	if not is_inside_tree() or _flying.size() + _queued.size() >= MAX_FLYING:
		return
	if flat:
		# 0.64: on a phone its arc is worked out in `_process`, at most LAUNCH_PER_FRAME a frame.
		_queued.append([from, velocity, size, bleeder])
		return
	_launch(from, velocity, size, bleeder)

func _launch(from: Vector3, velocity: Vector3, size: float, bleeder: Variant) -> void:
	var space := get_world_3d().direct_space_state
	var p := from
	var v := velocity
	var t := 0.0
	var hit := {}
	for i in 8:
		var h := .05 + .04 * i
		var q := p + v * h + Vector3.DOWN * (4.9 * h * h)
		hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(p, q, MASK))
		if not hit.is_empty():
			t += h * p.distance_to(hit.position) / maxf(p.distance_to(q), .0001)
			v.y -= 9.8 * h
			break
		t += h
		v.y -= 9.8 * h
		p = q
	_flying.append({"p": from, "v": velocity, "t": 0.0, "life": t if not hit.is_empty() else 1.5, "size": size, "hit": hit,
		"way": v.normalized() if v.length() > .01 else Vector3.DOWN, "bleeder": bleeder})

func _process(delta: float) -> void:
	if not _queued.is_empty():
		var now := _queued.slice(0, LAUNCH_PER_FRAME)
		_queued = _queued.slice(LAUNCH_PER_FRAME)
		for q: Array in now:
			if is_inside_tree():
				_launch(q[0], q[1], q[2], q[3])
	if _fly_mesh == null or (_flying.is_empty() and _fly_mesh.visible_instance_count == 0):
		return
	for i in range(_flying.size() - 1, -1, -1):
		var d: Dictionary = _flying[i]
		d.t = float(d.t) + delta
		if float(d.t) >= float(d.life):
			_flying.remove_at(i)
			_drop_lands(d)
			continue
		var v: Vector3 = d.v
		d.p = (d.p as Vector3) + v * delta
		v.y -= 9.8 * delta
		d.v = v
	var shown := 0
	for d: Dictionary in _flying:
		if shown >= MAX_FLYING:
			break
		_fly_mesh.set_instance_transform(shown, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * maxf(float(d.size) * .8, .012)), d.p))
		shown += 1
	_fly_mesh.visible_instance_count = shown

func _drop_lands(d: Dictionary) -> void:
	var hit: Dictionary = d.hit
	# (0.55: a freed body compares equal to null in Godot 4, so `!= null` let a drop through onto one that had just
	# been freed, and _spot raised a type error. Whatever it struck must still be there.)
	if hit.is_empty() or not is_instance_valid(hit.get("collider")):
		return
	var bleeder: Variant = d.bleeder
	if bleeder is Dictionary:
		# A drip onto the spot the last drip made: the spot widens.
		var last: Variant = (bleeder as Dictionary).get("spot")
		if last != null and is_instance_valid(last):
			var puddle := last as Node3D
			var wide: Vector3 = puddle.get("size")
			if puddle.global_position.distance_to(hit.position) < .07 + wide.x * .35:
				if wide.x < .42:
					puddle.set("size", wide + Vector3(.014, 0, .014))
				return
	var spot := _spot(hit.position, hit.normal, d.way, float(d.size), hit.collider)
	if bleeder is Dictionary:
		(bleeder as Dictionary)["spot"] = spot

## Where a drop landed: round if it fell straight onto the surface, drawn out along its way if it struck at a slant
## (the flatter the longer), with the tail pointing the way it was going.
func _spot(point: Vector3, normal: Vector3, way: Vector3, size: float, collider: Object) -> Node3D:
	var up := normal.normalized()
	var steep := clampf(absf(way.dot(up)), .28, 1.0)
	var along := way - up * way.dot(up)
	if along.length() < .08:
		along = up.cross(Vector3.RIGHT if absf(up.x) < .9 else Vector3.UP).rotated(up, randf() * TAU)
	along = along.normalized()
	var across := up.cross(along).normalized()
	var width := clampf(size * randf_range(1.6, 2.6), .02, .2)
	var depth := .16
	if flat:
		var mark := marks.mark("blot_%d" % (randi() % 4), Vector3(width, depth, width / steep), Color(.95, .85, .85), clampf(width * 120.0, 6.0, 24.0))
		mark.name = "BloodSpot"
		var on: Node3D = collider as Node3D if collider is RigidBody3D else _world()
		on.add_child(mark)
		_lay(mark, Basis(across, up, along), point, up, 0.0)
		_keep_spot(mark)
		return mark
	var decal := Decal.new()
	decal.name = "BloodSpot"
	decal.size = Vector3(width, depth, width / steep)
	decal.texture_albedo = _blots[randi() % _blots.size()]
	decal.texture_orm = _orm
	decal.modulate = Color(.95, .85, .85)
	decal.albedo_mix = 1.0
	decal.normal_fade = .3
	decal.upper_fade = .2
	decal.lower_fade = .2
	decal.cull_mask = 0xFFFFF
	decal.distance_fade_enabled = true
	# 0.56: a spot fades with distance by its size (a 4 cm drop from 6 m, the biggest from 24 m): past that it is a pixel
	# or less, and hundreds of them in the cluster were most of what the blood cost to draw.
	decal.distance_fade_begin = clampf(width * 120.0, 6.0, 24.0)
	decal.distance_fade_length = decal.distance_fade_begin * .35
	decal.add_to_group("blood_decals")
	var parent: Node3D = collider as Node3D if collider is RigidBody3D else self
	parent.add_child(decal)
	decal.global_transform = Transform3D(Basis(across, up, along), point + up * (depth * .5 - .055))
	_keep_spot(decal)
	return decal

func _keep_spot(spot: Node3D) -> void:
	_spots.append(spot)
	if _spots.size() > MAX_SPOTS:
		var old: Node3D = _spots.pop_front()
		if is_instance_valid(old):
			old.queue_free()

## A wound on `body` (at `local`, facing `out`, both in the body's own frame) goes on bleeding: `rate` drops a
## second at first, less as its `life` (s) runs out. With `spurt` it is an artery: it pumps.
func bleed(body: Node3D, local: Vector3, out: Vector3, rate: float, life: float, spurt: bool) -> void:
	if not is_instance_valid(body):
		return
	if _bleeders.size() >= MAX_BLEEDERS:
		_bleeders.pop_front()
	_bleeders.append({"body": body, "local": local, "out": out.normalized(), "rate": rate, "life": life, "age": 0.0, "acc": randf(),
		"spurt": spurt, "spot": null, "was": body.global_transform * local})

func _physics_process(delta: float) -> void:
	if _bleeders.is_empty():
		return
	_budget = minf(_budget + DROP_BUDGET * delta, 24.0)
	for i in range(_bleeders.size() - 1, -1, -1):
		var b: Dictionary = _bleeders[i]
		var body: Variant = b.body
		b.age = float(b.age) + delta
		if not is_instance_valid(body) or not (body as Node3D).is_inside_tree() or float(b.age) >= float(b.life):
			_bleeders.remove_at(i)
			continue
		var part := body as Node3D
		var left := 1.0 - float(b.age) / float(b.life)
		var at := part.global_transform * (b.local as Vector3)
		var speed := ((at - (b.was as Vector3)) / maxf(delta, .0001)).limit_length(8.0)
		b.was = at
		var flow := float(b.rate) * left
		var out := part.global_basis.orthonormalized() * (b.out as Vector3)
		var beat := 0.0
		if bool(b.spurt):
			# A heart still going, faster and weaker as it empties: a jet on each beat, a dribble between.
			var phase := fmod(float(b.age) * (1.5 + (1.0 - left) * .9), 1.0)
			beat = (1.0 - phase / .26) if phase < .26 else 0.0
			flow = flow * (.35 + 5.0 * beat)
		b.acc = float(b.acc) + flow * delta
		while float(b.acc) >= 1.0 and _budget >= 1.0:
			b.acc = float(b.acc) - 1.0
			_budget -= 1.0
			var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
			if beat > 0.0:
				drop(at + out * .03, speed + (out + jitter * .16).normalized() * (.5 + 3.2 * beat * left) * randf_range(.75, 1.15), randf_range(.016, .034))
			else:
				drop(at + out * .02, speed * .9 + jitter * .08 + out * .12, randf_range(.018, .036), b)
		if float(b.acc) >= 1.0:
			b.acc = 1.0

## A part has come off at `point`; `out` points down what left. More of everything: mist, drops, splats. With
## `burst` it did not come off whole (a head), and the cloud is twice the size.
func sever_burst(point: Vector3, out: Vector3, power: float, burst: bool) -> void:
	_burst(point, out, power * (1.9 if burst else 1.2))
	if burst:
		_burst(point, Vector3.UP, power * 1.4)
	_sound(point, "tear_%d" % (1 + randi() % 3), 2.0)
	_sound(point, "bone_%d" % (1 + randi() % 3), -1.0)
	_sound(point, "splat_%d" % (1 + randi() % 2), -2.0)
	if not is_inside_tree():
		return
	for i in (34 if burst else 18):
		var way := (out * randf_range(.2, 1.0) + Vector3(randf_range(-1, 1), randf_range(-.2, 1.2), randf_range(-1, 1))).normalized()
		drop(point, way * randf_range(1.0, 5.5 if burst else 3.8), randf_range(.018, .05))
	var space := get_world_3d().direct_space_state
	for i in (5 if burst else 3):
		var way := (out + Vector3(randf_range(-.8, .8), randf_range(-.7, .5), randf_range(-.8, .8))).normalized()
		var reach := randf_range(1.2, 3.6)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point, point + way * reach, MASK))
		if hit.is_empty():
			var from := point + way * reach * .6
			hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 3.0, MASK))
		if not hit.is_empty():
			_splat(hit.position, hit.normal, way, randf_range(.3, .7) * sqrt(power), hit.collider)

## A piece is torn out of a part that stays on (scripts/zombie.gd `_chunk`): a crater of meat where it was, what came
## out of it, and the sound. `local` and `local_out` are in the part's own frame.
func chunk(body: Node3D, local: Vector3, local_out: Vector3, radius: float, speed: Vector3, trunk: bool) -> void:
	if not is_instance_valid(body) or not body.is_inside_tree():
		return
	var point := body.global_transform * local
	var away := local_out.normalized()
	var out := (body.global_basis * away).normalized()
	_burst(point, out, 1.5 if trunk else 1.0)
	_sound(point, "tear_%d" % (1 + randi() % 3), 0.0)
	_sound(point, "sploosh_%d" % (1 + randi() % 3), -3.0)
	if not is_inside_tree():
		return
	var crater := InteriorZombieGore.crater(radius, trunk)
	body.add_child(crater)
	crater.transform = Transform3D(InteriorZombieGore.facing(away), local - away * radius * .3)
	for i in (3 if trunk else 2):
		var way := (out + Vector3(randf_range(-.8, .8), randf_range(0.0, .9), randf_range(-.8, .8))).normalized()
		keep_gib(InteriorZombieGore.gib(self, point + out * .05, speed + way * randf_range(1.2, 4.0)))
	for i in 9:
		var way := (out + Vector3(randf_range(-.9, .9), randf_range(-.3, .9), randf_range(-.9, .9))).normalized()
		drop(point, speed + way * randf_range(.8, 3.6), randf_range(.016, .04))

## A chest or a belly comes apart at `at`: handfuls of it, lengths of rib, and a rain of the rest.
func shatter(at: Vector3, speed: Vector3, way: Vector3, count: int, ribs: bool) -> void:
	_sound(at, "gib_%d" % (1 + randi() % 2), 3.0)
	_sound(at, "bone_%d" % (1 + randi() % 3), 0.0)
	if not is_inside_tree():
		return
	for i in mini(count, 10):
		var out := (way * randf_range(.3, 1.4) + Vector3(randf_range(-1, 1), randf_range(.1, 1.4), randf_range(-1, 1))).normalized()
		keep_gib(InteriorZombieGore.gib(self, at + out * .08, speed + out * randf_range(1.8, 6.5), i < 4, ribs and i % 3 == 2))
	for i in count * 2:
		var out := (way * randf_range(0.0, 1.2) + Vector3(randf_range(-1, 1), randf_range(-.1, 1.5), randf_range(-1, 1))).normalized()
		drop(at + out * .1, speed + out * randf_range(1.5, 6.5), randf_range(.02, .06))

## A body meets the ground.
func thud(at: Vector3) -> void:
	_sound(at, "thud_%d" % (1 + randi() % 3), -1.0)

func keep_piece(piece: Node) -> void:
	_pieces.append(piece)
	while _pieces.size() > MAX_PIECES:
		var old: Node = _pieces.pop_front()
		if is_instance_valid(old):
			old.queue_free()

func keep_gib(gib: Node) -> void:
	_gibs.append(gib)
	while _gibs.size() > MAX_GIBS:
		var old: Node = _gibs.pop_front()
		if is_instance_valid(old):
			old.queue_free()
