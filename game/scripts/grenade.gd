class_name InteriorGrenades
extends Node
## 0.43: frag grenades, solo and co-op.
##
## Hold T: the pin comes out (a click) and the fuse runs while it is held ("cooking"). Let go: it is thrown along the
## view, or lobbed underhand with the sights up (right mouse), and the thrower shouts "Fire in the hole!" in their
## squad voice (assets/audio/voices/*/fire_in_the_hole_*.wav). Held past the fuse it goes off in the hand.
##
## It flies as a real body, bounces off walls and floors and rolls to a stop. When the fuse runs out: a fireball
## and a smoke flipbook (made from code for the owner's Aetherion Project, tools/make_explosion_fx.py there), a
## flash, dirt and sparks, a scorch on the ground, the bang, the lens shaken by distance, nearby glass broken,
## loose props thrown, and every zombie with a clear line to it torn up and thrown (InteriorZombie.blow): within
## KILL_RADIUS most die outright, further out to RADIUS the damage falls off. Anything that hears it comes.
##
## Co-op: the thrower's game simulates its grenade and decides what it does to the infected (through the same
## `shot` path as a round, so the host keeps the count); every other peer is told of the throw (it sees the grenade
## fly) and of the blast (it sees and hears it, and its own player takes the blast if close).

const FUSE := 3.6
const THROW_SPEED := 17.0
const LOB_SPEED := 8.5
const KILL_RADIUS := 4.0
const RADIUS := 10.0
const PLAYER_RADIUS := 8.0
## Room / world geometry and loose objects (the grenade bounces off both; the blast is stopped by the first only).
const MASK := 2 | 4
const WALLS := 2
const START_COUNT := 3
const DIR := "res://assets/grenade/"
## 0.58: a thrown grenade is marked on every survivor's screen within this distance (scripts/world_markers.gd).
const MARK_RANGE := 30.0
const Shine := preload("res://scripts/pickup_shine.gd")
const Markers := preload("res://scripts/world_markers.gd")
var _hot: ShaderMaterial

var main: Node
var player: InteriorPlayer
var count := 0
var cooking := false
var cook_time := 0.0
var _live: Array = []
var _next := 1
var _model: PackedScene
var _fire_material: StandardMaterial3D
var _smoke_material: StandardMaterial3D
var _scorch: ImageTexture
var _bang: AudioStream
var _far: AudioStream
var _effects: Array = []
var _cool := 0.0

func setup(main_node: Node) -> void:
	main = main_node
	player = main.player
	name = "Grenades"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("grenades")
	if "--grenades" in OS.get_cmdline_user_args():
		count = 10
	_model = load(DIR + "frag_grenade.glb")
	_bang = load(DIR + "grenade_explosion1.ogg")
	_far = load(DIR + "bomb_explosion.mp3")
	_fire_material = _flipbook("explosion_albedo.png", "explosion_emit.png")
	_smoke_material = _flipbook("smoke_albedo.png", "")
	_scorch = _make_scorch()

func give(amount: int) -> void:
	count = clampi(count + amount, 0, 20)
	_hud()

# ---------------------------------------------------------------- the throw

func _unhandled_input(event: InputEvent) -> void:
	if player == null or not player.playing or bool(main.get("mobile")):
		return
	if InputMap.has_action("grenade") and event.is_action_pressed("grenade") and not event.is_echo():
		_pull_pin()
		get_viewport().set_input_as_handled()

func _pull_pin() -> void:
	if cooking or count <= 0 or _cool > 0.0 or player.downed:
		if count <= 0 and main.story != null and main.story.has_method("notify"):
			main.story.notify("No grenades")
		return
	cooking = true
	cook_time = 0.0
	count -= 1
	_click(player.camera.global_position, -6.0, 1.4)
	_hud()

func _process(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)
	if cooking:
		cook_time += delta
		if not player.playing or player.downed:
			# Paused or down with the pin out: it falls at the feet, still live.
			_release(Vector3.ZERO, false)
		elif cook_time >= FUSE:
			cooking = false
			_explode(player.camera.global_position + _forward() * .3 + Vector3.DOWN * .25, true)
			_send_boom(player.camera.global_position)
		elif not Input.is_action_pressed("grenade"):
			var lob := InputMap.has_action("aim") and Input.is_action_pressed("aim")
			var speed := LOB_SPEED if lob else THROW_SPEED
			_release(_forward() * speed + Vector3.UP * (3.2 if lob else 2.4) + player.velocity * .5, true)
	_tick_effects(delta)
	_mark_live()

## 0.58: the shared highlight on live grenades: the pickup shine's shader, warm and quick.
func _hot_material() -> ShaderMaterial:
	if _hot == null:
		_hot = Shine.material().duplicate() as ShaderMaterial
		_hot.set_shader_parameter("tint", Color(1.0, .72, .36))
		_hot.set_shader_parameter("fill", .3)
		_hot.set_shader_parameter("rim_strength", .9)
		_hot.set_shader_parameter("glint_strength", 1.2)
		_hot.set_shader_parameter("period", .7)
	return _hot

## 0.58: every live grenade near enough is marked on the screen with its fuse and distance.
func _mark_live() -> void:
	if _live.is_empty() or player == null: return
	var marks: Node = Markers.of(main)
	if marks == null: return
	var me := player.global_position
	for g: Dictionary in _live:
		var body := g.body as RigidBody3D
		if not is_instance_valid(body) or float(g.fuse) <= 0.0: continue
		var at := body.global_position
		var metres := me.distance_to(at)
		if metres > MARK_RANGE: continue
		marks.mark("nade:" + str(g.id), at + Vector3.UP * .12, "grenade",
			{"fuse": float(g.fuse), "total": FUSE, "metres": int(round(metres)), "danger": metres <= PLAYER_RADIUS})

func _forward() -> Vector3:
	return -player.camera.global_basis.z

func _release(velocity: Vector3, shout: bool) -> void:
	cooking = false
	_cool = .6
	var from := player.camera.global_position + _forward() * .45 + player.camera.global_basis.x * .12 + Vector3.DOWN * .12
	if velocity == Vector3.ZERO:
		from = player.global_position + Vector3.UP * .3
	var left := maxf(.05, FUSE - cook_time)
	var id := "%d:%d" % [_peer(), _next]
	_next += 1
	_spawn(id, from, velocity, left, true)
	if shout:
		_shout()
	var coop: Node = main.get("coop")
	if coop != null and bool(coop.get("active")):
		coop.grenade_out.rpc(id, from, velocity, left)

## Every peer: a grenade in flight. Only `mine` ones do anything when they go off.
func _spawn(id: String, from: Vector3, velocity: Vector3, fuse: float, mine: bool) -> void:
	var body := RigidBody3D.new()
	body.name = "Grenade"
	body.mass = .4
	body.collision_layer = 0
	body.collision_mask = MASK
	body.continuous_cd = true
	body.contact_monitor = true
	body.max_contacts_reported = 2
	body.angular_damp = 1.6
	body.linear_damp = .08
	var surface := PhysicsMaterial.new()
	surface.bounce = .35
	surface.friction = .7
	surface.rough = true
	body.physics_material_override = surface
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = .036
	shape.shape = sphere
	body.add_child(shape)
	if _model != null:
		var model := _model.instantiate() as Node3D
		model.position = Vector3(0, -.035, 0)
		body.add_child(model)
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			(mesh as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# 0.58: lit up warm in flight and where it lands, quickening as the fuse runs (_mark_live).
			(mesh as GeometryInstance3D).material_overlay = _hot_material()
	main.add_child(body)
	body.global_position = from
	body.linear_velocity = velocity
	body.angular_velocity = Vector3(randf_range(-9, 9), randf_range(-4, 4), randf_range(-9, 9))
	body.body_entered.connect(_bounced.bind(body))
	_live.append({"id": id, "body": body, "fuse": fuse, "mine": mine})

func _bounced(_other: Node, body: RigidBody3D) -> void:
	if is_instance_valid(body) and body.linear_velocity.length() > 1.2:
		_click(body.global_position, -10.0 + minf(body.linear_velocity.length(), 8.0), randf_range(1.6, 2.1))

func _physics_process(delta: float) -> void:
	for g: Dictionary in _live.duplicate():
		g.fuse = float(g.fuse) - delta
		var body := g.body as RigidBody3D
		if not is_instance_valid(body):
			_live.erase(g)
			continue
		if body.global_position.y < -200.0:
			body.queue_free()
			_live.erase(g)
			continue
		if float(g.fuse) <= 0.0 and bool(g.mine):
			var at := body.global_position
			_live.erase(g)
			body.queue_free()
			_explode(at, true)
			_send_boom(at, str(g.id))
		elif float(g.fuse) <= -3.0:
			# Someone else's that we never heard go off: gone.
			_live.erase(g)
			body.queue_free()

func _send_boom(at: Vector3, id := "") -> void:
	var coop: Node = main.get("coop")
	if coop != null and bool(coop.get("active")):
		coop.grenade_boom.rpc(id, at)

## Co-op, every other peer: another player's grenade went off where `at` is.
func remote_boom(id: String, at: Vector3) -> void:
	for g: Dictionary in _live.duplicate():
		if str(g.id) == id:
			if is_instance_valid(g.body):
				(g.body as Node).queue_free()
			_live.erase(g)
	_explode(at, false)

func remote_throw(id: String, from: Vector3, velocity: Vector3, fuse: float) -> void:
	_spawn(id, from, velocity, fuse, false)

func _peer() -> int:
	var coop: Node = main.get("coop")
	if coop != null and bool(coop.get("active")):
		return multiplayer.get_unique_id()
	return 1

func _shout() -> void:
	var coop: Node = main.get("coop")
	if coop != null and bool(coop.get("active")):
		coop.player_line("fire_in_the_hole")
		return
	# Solo: the player's own voice, the same placeholder squad voice as the co-op Aljay.
	var take := 1 + randi() % 3
	var path := "res://assets/audio/voices/aljay/fire_in_the_hole_%d.wav" % take
	for ext in [".mp3", ".ogg"]:
		if ResourceLoader.exists(path.get_basename() + ext):
			path = path.get_basename() + ext
	if not ResourceLoader.exists(path):
		return
	var voice := AudioStreamPlayer.new()
	voice.stream = load(path)
	voice.bus = "Voices"
	voice.volume_db = 2.0
	add_child(voice)
	voice.play()
	voice.finished.connect(voice.queue_free)

# ---------------------------------------------------------------- the blast

## `mine`: this game threw it, so this game decides what it does to the infected (and tells the host in co-op).
func _explode(at: Vector3, mine: bool) -> void:
	_visuals(at)
	_sound(at)
	_shake(at)
	_hurt_player(at, mine)
	_glass(at)
	_props(at)
	var senses: Variant = main.get("senses")
	if senses != null and is_instance_valid(senses):
		(senses as InteriorSenses).noise(at, 140.0, "explosion")
	if mine:
		_hurt_zombies(at)
	# 0.53: on the host, whoever threw it: fuel drums close to it go up (scripts/coop/heavyarm.gd).
	var coop: Node = main.get("coop")
	if coop != null and bool(coop.get("active")) and multiplayer.is_server() and coop.get("mission") != null:
		coop.mission.boom(at)

## 0.53: something else went up (a drum of fuel at PILCST's rear gate): the same fire, smoke, bang and shake, glass
## and loose things, and this game's own player takes the blast. Nothing is done to the infected here (the host does).
func detonate(at: Vector3) -> void:
	_visuals(at)
	_sound(at)
	_shake(at)
	_hurt_player(at, false)
	_glass(at)
	_props(at)

func _clear_line(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, WALLS)
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	return space.intersect_ray(query).is_empty()

## How hard the blast is at `distance`: 1 inside KILL_RADIUS, down to 0 at `reach`.
static func falloff(distance: float, reach := RADIUS) -> float:
	if distance <= KILL_RADIUS:
		return 1.0
	return clampf(1.0 - (distance - KILL_RADIUS) / (reach - KILL_RADIUS), 0.0, 1.0)

func _hurt_zombies(at: Vector3) -> void:
	var origin := at + Vector3.UP * .25
	var targets: Array = []
	for node in get_tree().get_nodes_in_group("zombies") + get_tree().get_nodes_in_group("zombie_corpses"):
		if node is InteriorZombie:
			targets.append([node, (node as InteriorZombie).get("_bodies")])
	var coop: Node = main.get("coop")
	if coop != null and bool(coop.get("active")) and coop.get("mission") != null:
		var mission: Node = coop.mission
		for fig in (mission.get("enemies") as Dictionary).values():
			targets.append([fig, fig.get("bodies")])
		for fig in mission.get("corpses"):
			targets.append([fig, fig.get("bodies")])
	for pair: Array in targets:
		var who: Node = pair[0]
		var bodies: Variant = pair[1]
		if not is_instance_valid(who) or not bodies is Dictionary or (bodies as Dictionary).is_empty():
			continue
		var chest := (bodies as Dictionary).get("chest") as Node3D
		if chest == null or not is_instance_valid(chest):
			chest = (bodies as Dictionary).values()[0] as Node3D
		var distance := chest.global_position.distance_to(at)
		if distance > RADIUS or not _clear_line(origin, chest.global_position):
			continue
		var f := falloff(distance)
		# Up and away from the blast: rounds arriving in one instant add up into one throw.
		var way := (chest.global_position - at + Vector3.UP * (.9 + .6 * f)).normalized()
		var damage := lerpf(25.0, 420.0, f * f)
		var knock := lerpf(120.0, 520.0, f)
		who.call("shot", chest, chest.global_position, way, damage, knock, "grenade", 160.0 * f * f)
		# Fragments and the blast take parts of it with them close up.
		var parts := (bodies as Dictionary).keys()
		parts.shuffle()
		for bone: String in parts.slice(0, 2 + int(f * 3.0)):
			# (An earlier fragment may have taken this part off already.)
			var part := (bodies as Dictionary).get(bone) as Node3D
			if not is_instance_valid(part) or bone == "chest":
				continue
			var near := clampf(1.0 - part.global_position.distance_to(at) / RADIUS, 0.0, 1.0)
			who.call("shot", part, part.global_position, (part.global_position - at + Vector3.UP * .8).normalized(),
				lerpf(8.0, 90.0, near), lerpf(60.0, 260.0, near), "grenade", (220.0 if near > .55 else 40.0) * near)

func _hurt_player(at: Vector3, mine := true) -> void:
	if player == null or not is_instance_valid(player):
		return
	var chest := player.global_position + Vector3.UP * 1.1
	var distance := chest.distance_to(at)
	if distance > PLAYER_RADIUS or not _clear_line(at + Vector3.UP * .25, chest):
		return
	var f := falloff(distance, PLAYER_RADIUS)
	var amount := lerpf(8.0, 130.0, f * f) if distance > 1.6 else 160.0
	var coop: Node = main.get("coop")
	if coop != null and bool(coop.get("active")):
		coop.blast_hurt(int(amount), mine)
		return
	var zombies: Variant = main.get("zombies")
	if zombies != null and is_instance_valid(zombies) and not bool(zombies.get("invulnerable")):
		zombies.call("hurt_player", amount, at, "blast")

func _shake(at: Vector3) -> void:
	if player == null:
		return
	var distance := player.global_position.distance_to(at)
	var k := clampf(1.0 - distance / 40.0, 0.0, 1.0)
	if k <= 0.0:
		return
	player.jolt(.03 * k)
	player.punch(Vector3(randf_range(.6, 1.2), randf_range(-.8, .8), randf_range(-.9, .9)) * 2.4 * k * k)

func _glass(at: Vector3) -> void:
	var glass: Variant = main.get("glass")
	if glass == null or not is_instance_valid(glass) or not bool(glass.get("built")):
		return
	var panes: Array = glass.get("panes")
	for i in panes.size():
		var pane: Dictionary = panes[i]
		if bool(pane.broken):
			continue
		var spot: Vector3 = pane.at
		var distance := spot.distance_to(at)
		if distance < 7.5 and _clear_line(at + Vector3.UP * .25, spot + (at - spot).normalized() * .15):
			glass.call("strike", i, spot, (spot - at).normalized(), distance / 340.0)

func _props(at: Vector3) -> void:
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 7.0
	query.shape = sphere
	query.transform = Transform3D(Basis(), at)
	# (0.57: and 32, the co-op school's chairs: a blast in a classroom throws them. A client's are frozen and
	# follow the host's, so only the host's blast moves them.)
	query.collision_mask = 4 | 1 | 32
	query.collide_with_areas = false
	for hit: Dictionary in main.get_world_3d().direct_space_state.intersect_shape(query, 96):
		var body := hit.collider as RigidBody3D
		if body == null or body.freeze:
			continue
		var off := body.global_position - at
		var f := falloff(off.length(), 7.0)
		body.sleeping = false
		body.apply_central_impulse((off.normalized() + Vector3.UP * .5).normalized() * body.mass * lerpf(1.0, 9.0, f))

func _sound(at: Vector3) -> void:
	var near := AudioStreamPlayer3D.new()
	near.stream = _bang
	near.bus = "Guns"
	near.unit_size = 18.0
	near.max_distance = 600.0
	near.volume_db = 6.0
	near.pitch_scale = randf_range(.94, 1.06)
	near.attenuation_filter_cutoff_hz = 20500.0
	main.add_child(near)
	near.global_position = at
	near.play()
	near.finished.connect(near.queue_free)
	if player != null and player.global_position.distance_to(at) > 35.0 and _far != null:
		var tail := AudioStreamPlayer3D.new()
		tail.stream = _far
		tail.bus = "Guns"
		tail.unit_size = 60.0
		tail.max_distance = 650.0
		main.add_child(tail)
		tail.global_position = at
		tail.play()
		tail.finished.connect(tail.queue_free)

func _click(at: Vector3, volume: float, pitch: float) -> void:
	var gun: Variant = main.story.get("gun") if main.get("story") != null else null
	if gun != null and gun.has_method("_hand_sound") and at.distance_to(player.camera.global_position) < .5:
		gun.call("_hand_sound", "gun_dry", volume, pitch)

# ---------------------------------------------------------------- what it looks like

func _flipbook(albedo: String, emit: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	# Lit, like Aetherion's: the soot takes the flash and the night; the fire is its own light (emission x frame).
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.albedo_texture = load(DIR + albedo)
	m.uv1_scale = Vector3(.125, .125, 1)
	m.disable_receive_shadows = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emit == "":
		# Smoke and dust, not cloud: darker than the flipbook's own grey, so a torch beam does not turn it white.
		m.albedo_color = Color(.42, .4, .37, .9)
	if emit != "":
		m.emission_enabled = true
		m.emission = Color(1, 1, 1)
		m.emission_texture = load(DIR + emit)
		m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		m.emission_energy_multiplier = 4.0
	return m

func _card(material: StandardMaterial3D, at: Vector3, size: float, life: float, rise: float) -> void:
	var card := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	card.mesh = quad
	card.material_override = material.duplicate()
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.add_child(card)
	card.global_position = at
	_effects.append({"node": card, "t": 0.0, "life": life, "rise": rise})

func _tick_effects(delta: float) -> void:
	for e: Dictionary in _effects.duplicate():
		var node := e.node as MeshInstance3D
		if not is_instance_valid(node):
			_effects.erase(e)
			continue
		e.t = float(e.t) + delta
		var k := float(e.t) / float(e.life)
		if k >= 1.0:
			node.queue_free()
			_effects.erase(e)
			continue
		var frame := mini(int(k * 64.0), 63)
		var m := node.material_override as StandardMaterial3D
		# (0.55: a card the run put away behind it (mission `free_unloaded` drops its material) is done with.)
		if m == null:
			node.queue_free()
			_effects.erase(e)
			continue
		m.uv1_offset = Vector3(float(frame % 8) * .125, float(frame / 8) * .125, 0)
		node.position.y += float(e.rise) * delta

func _visuals(at: Vector3) -> void:
	_card(_fire_material, at + Vector3.UP * .9, 4.2, .9, .6)
	_card(_smoke_material, at + Vector3.UP * 1.3, 5.5, 4.0, .45)
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, .62, .3)
	flash.omni_range = 16.0
	flash.light_energy = 14.0
	flash.shadow_enabled = false
	main.add_child(flash)
	flash.global_position = at + Vector3.UP * .8
	var fade := flash.create_tween()
	fade.tween_property(flash, "light_energy", 0.0, .35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	fade.tween_callback(flash.queue_free)
	_burst(at, 34, Color(.12, .09, .07), Vector2(.04, .09), 3.0, 11.0, 1.4, false)
	_burst(at, 28, Color(1.0, .7, .3), Vector2(.02, .03), 9.0, 22.0, .5, true)
	var ground: Dictionary = main.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * .4, at + Vector3.DOWN * 2.0, WALLS | 4))
	if not ground.is_empty():
		var scorch := Decal.new()
		scorch.name = "Scorch"
		scorch.texture_albedo = _scorch
		scorch.size = Vector3(3.4, .9, 3.4)
		scorch.modulate = Color(.06, .05, .045)
		scorch.upper_fade = .3
		scorch.lower_fade = .3
		scorch.distance_fade_enabled = true
		scorch.distance_fade_begin = 45.0
		scorch.distance_fade_length = 10.0
		main.add_child(scorch)
		var up: Vector3 = (ground.normal as Vector3).normalized()
		var along := up.cross(Vector3.RIGHT if absf(up.x) < .9 else Vector3.UP).normalized().rotated(up, randf() * TAU)
		scorch.global_transform = Transform3D(Basis(up.cross(along).normalized(), up, along), ground.position)
		# Not for ever: the oldest scorch goes when there are a dozen.
		var scorches := get_tree().get_nodes_in_group("grenade_scorch")
		scorch.add_to_group("grenade_scorch")
		if scorches.size() >= 12 and is_instance_valid(scorches[0]):
			(scorches[0] as Node).queue_free()

func _burst(at: Vector3, amount: int, colour: Color, size: Vector2, speed_min: float, speed_max: float, life: float, glow: bool) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	var quad := QuadMesh.new()
	quad.size = Vector2(size.y, size.y)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if glow else BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.albedo_color = colour
	m.vertex_color_use_as_albedo = true
	if glow:
		m.emission_enabled = true
		m.emission = colour
		m.emission_energy_multiplier = 6.0
	quad.material = m
	p.mesh = quad
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = speed_min
	p.initial_velocity_max = speed_max
	p.gravity = Vector3(0, -9.8, 0)
	p.damping_min = .5
	p.damping_max = 2.0
	p.scale_amount_min = size.x / size.y
	p.scale_amount_max = 1.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.add_child(p)
	p.global_position = at + Vector3.UP * .15
	p.emitting = true
	get_tree().create_timer(life + .2, false).timeout.connect(p.queue_free)

static func _make_scorch() -> ImageTexture:
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 43
	noise.frequency = .06
	for y in size:
		for x in size:
			var d := Vector2(x - size * .5, y - size * .5) / (size * .5)
			var r := d.length() + noise.get_noise_2d(x, y) * .35
			var a := clampf(1.0 - r, 0.0, 1.0)
			a = pow(a, .7) * .92
			image.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(image)

func _hud() -> void:
	var gun: Variant = main.story.get("gun") if main.get("story") != null else null
	if gun != null and gun.has_method("_update_hud"):
		gun.call("_update_hud")
