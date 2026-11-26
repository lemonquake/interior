class_name InteriorZombies
extends Node3D
## 0.28: the infected as a whole (each one is scripts/zombie.gd). Nothing spawns them but the debug menu (World tab).
##
## Spawning: `spawn_around` puts them on open ground somewhere in the neighbourhood round the player (a ring of
## 14 to 42 m, outdoors, not in water, with room to stand), wandering; `spawn_ahead` puts one in front of the
## camera. Gunshots are heard to 55 m, a scream to 18 m.
## The player: claws take 11 to 19 of 100; the lens jolts, the picture goes red at the edges and comes back as
## health does (it returns after four seconds without being hit). At nothing, the picture goes black and the player
## wakes at home; the ones near home are gone and the rest lose interest.
## Bodies stay as ragdolls where they fell (the oldest are taken away past MAX_CORPSES), and so does the blood
## (scripts/blood.gd).

const MAX_ALIVE := 36
const MAX_CORPSES := 16
const HEARING := 55.0
const SCREAM := 18.0
const SHADE := "shader_type canvas_item;\nuniform float amount = 0.0;\nuniform float black = 0.0;\nvoid fragment() {\n\tfloat edge = smoothstep(.22, .78, length(UV - vec2(.5)) * 1.3);\n\tvec3 c = mix(vec3(.42, .0, .0), vec3(.0), black);\n\tCOLOR = vec4(c, clamp(edge * amount + black, 0.0, 1.0));\n}\n"

var main: Node
var player: InteriorPlayer
var gun: InteriorGun
var blood: InteriorBlood
## 0.33: light and sound (scripts/senses.gd).
var senses: InteriorSenses
## Debug menu: they neither notice nor hunt the player.
var passive := false
## Debug menu: claws do nothing.
var invulnerable := false
## 0.55 (tests): hurts refused while `invulnerable` (claws, falls, blasts).
var blocked_hits := 0
## Debug menu: everything at a quarter speed, to see what a round does.
var slow_motion := false:
	set(value):
		slow_motion = value
		Engine.time_scale = .25 if value else 1.0
var health := 100.0
var kills := 0
## 0.33: wounds, the limp, breath, the heart (scripts/body.gd); `pulse` is the heartbeat in the red edge.
var body: InteriorBody
## 0.33: ways round walls (scripts/zombie_nav.gd); one search a physics tick.
var nav: InteriorZombieNav
## 0.37: what moves in the fixed world: instance id -> [body, its shapes' box in its own frame, where it was].
var _movers := {}
var _mover_wait := 0.0
## How many times a door or a gate has been seen to have moved (tests).
var mover_changes := 0
var _search_tick := -1
var pulse := 0.0
var _since_hit := 10.0
var _shade: ShaderMaterial
var _overlay: ColorRect
var _hurt_voice: AudioStreamPlayer
var _down := false
var _corpses: Array[InteriorZombie] = []
## 0.33: places waiting for a figure (one is built every other frame: building 36 at once stopped the game for
## 0.4 s), and the living as of this physics tick (every one of them asked for the whole list every tick).
var _queue: Array = []
var _queue_wait := 0
var _crowd: Array[InteriorZombie] = []
var _crowd_tick := -1
var _rank_wait := 0
## How many of the nearest in view are animated every frame, and how many more every second frame; the rest
## every third, and those out of the picture every fourth. Hit boxes follow at the same rate.
const EVERY_FRAME := 10
const EVERY_SECOND := 12

func setup(main_node: Node) -> void:
	main = main_node
	player = main.player
	name = "Zombies"
	add_to_group("zombie_director")
	# 0.33: the figures and their clips are in memory before the first one is called for (it cost the first
	# spawn a quarter of a second).
	InteriorLoadClock.later(InteriorZombie._load_shared)
	# 0.37: the doors and gates, once the whole world stands, and any built after.
	InteriorLoadClock.later(watch_movers)
	main.get_tree().node_added.connect(_on_node_added)
	senses = main.get("senses")
	nav = InteriorZombieNav.new()
	blood = InteriorBlood.new()
	add_child(blood)
	blood.setup(main)
	if main.get("story") != null and main.story != null:
		gun = main.story.gun
		gun.fired.connect(_on_fired)
	# They stand in the player's way, and the player in theirs.
	player.collision_mask |= InteriorZombie.LAYER
	_overlay = ColorRect.new()
	_overlay.name = "HurtShade"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADE
	_shade = ShaderMaterial.new()
	_shade.shader = shader
	_overlay.material = _shade
	_overlay.visible = false
	main.hud.add_child(_overlay)
	_hurt_voice = AudioStreamPlayer.new()
	_hurt_voice.name = "PlayerHurt"
	add_child(_hurt_voice)

# ---------------------------------------------------------------- spawning

## 0.37: every door leaf and gate leaf in the scene (an AnimatableBody3D in the fixed world's layer).
func watch_movers() -> void:
	if main == null or not is_instance_valid(main):
		return
	for node in main.find_children("*", "AnimatableBody3D", true, false):
		_add_mover(node)

func _on_node_added(node: Node) -> void:
	if node is AnimatableBody3D:
		_add_mover.call_deferred(node)

func _add_mover(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree() or not node is AnimatableBody3D:
		return
	var body := node as AnimatableBody3D
	if (body.collision_layer & 2) == 0 or _movers.has(body.get_instance_id()):
		return
	var box := AABB()
	var any := false
	for child in body.get_children():
		var shape := child as CollisionShape3D
		if shape == null or shape.shape == null:
			continue
		var part := shape.transform * shape.shape.get_debug_mesh().get_aabb()
		box = part if not any else box.merge(part)
		any = true
	if any:
		_movers[body.get_instance_id()] = [body, box, body.global_transform]

## Doors and gates that have moved since the last look: the ground where each was and is is looked at again.
func _check_movers() -> void:
	for id: int in _movers.keys():
		var entry: Array = _movers[id]
		var body: Variant = entry[0]
		if not is_instance_valid(body) or not (body as Node).is_inside_tree():
			_movers.erase(id)
			continue
		var now: Transform3D = (body as Node3D).global_transform
		var was: Transform3D = entry[2]
		if now.origin.distance_to(was.origin) < .02 and now.basis.get_rotation_quaternion().angle_to(was.basis.get_rotation_quaternion()) < .02:
			continue
		var box: AABB = entry[1]
		if nav != null:
			nav.forget_box((was * box).merge(now * box))
		entry[2] = now
		mover_changes += 1

func _physics_process(delta: float) -> void:
	_mover_wait -= delta
	if _mover_wait <= 0.0 and not _movers.is_empty():
		_mover_wait = .2
		_check_movers()
	_waypoints_tick(delta)

## 0.48: the waypoint graph (scripts/waypoints.gd) grows round the player while there are infected about.
var _way_wait := 0.0
func _waypoints_tick(delta: float) -> void:
	if nav == null or player == null:
		return
	_way_wait -= delta
	if _way_wait <= 0.0:
		_way_wait = 1.0
		if get_tree().get_nodes_in_group("zombies").is_empty():
			return
		if nav.space == null:
			nav.space = get_world_3d().direct_space_state
		if nav.waypoints == null:
			nav.waypoints = InteriorWaypoints.new(nav)
		nav.waypoints.seed_around([player.global_position])
	if nav.waypoints != null and nav.waypoints.pending() > 0:
		nav.waypoints.grow(1200)

func take_search() -> bool:
	var tick := Engine.get_physics_frames()
	if tick == _search_tick or nav == null:
		return false
	_search_tick = tick
	if nav.space == null:
		nav.space = get_world_3d().direct_space_state
	return true

func alive() -> Array[InteriorZombie]:
	var out: Array[InteriorZombie] = []
	for node in get_tree().get_nodes_in_group("zombies"):
		if node is InteriorZombie and (node as InteriorZombie).alive():
			out.append(node as InteriorZombie)
	return out

func spawn(at: Vector3, variant := "", facing := NAN, feeding := false, kind := "") -> InteriorZombie:
	if alive().size() >= MAX_ALIVE or not at.is_finite():
		return null
	_crowd_tick = -1
	var zombie := InteriorZombie.new()
	add_child(zombie)
	zombie.setup(self, variant, kind)
	zombie.global_position = at
	zombie.rotation.y = facing if not is_nan(facing) else randf() * TAU
	zombie.died.connect(_on_died)
	zombie.start(InteriorZombie.State.FEED if feeding else InteriorZombie.State.IDLE)
	return zombie

## Open ground under `at`: the point to stand on, or INF.
func ground(at: Vector3, outdoors := true) -> Vector3:
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.5, at + Vector3.DOWN * 9.0, 2))
	if hit.is_empty() or (hit.normal as Vector3).y < .75:
		return Vector3.INF
	var point: Vector3 = hit.position
	if outdoors and (point.y > -1.0 or InteriorFieldsBuilder.in_water(Vector2(point.x, point.z))):
		return Vector3.INF
	var room := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .34
	capsule.height = 1.6
	room.shape = capsule
	room.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * 1.0)
	room.collision_mask = 2 | 4 | 1 | InteriorZombie.LAYER
	if not space.intersect_shape(room, 1).is_empty():
		return Vector3.INF
	return point + Vector3.UP * .03

## `count` of them somewhere in the neighbourhood round the player. Returns how many found a place.
func spawn_around(count: int, near := 14.0, far := 42.0) -> int:
	var made := 0
	var tries := count * 40
	var centre := player.global_position
	var room := MAX_ALIVE - alive().size() - _queue.size()
	while made < count and made < room and tries > 0:
		tries -= 1
		var angle := randf() * TAU
		var at := ground(centre + Vector3(sin(angle), 0, cos(angle)) * randf_range(near, far))
		if not at.is_finite() or absf(at.y - centre.y) > 6.0:
			continue
		# Not on top of one already waiting for its figure.
		var taken := false
		for waiting: Array in _queue:
			if (waiting[0] as Vector3).distance_squared_to(at) < .6:
				taken = true
				break
		if taken:
			continue
		_queue.append([at, randf() < .15])
		made += 1
	return made

## Places found by spawn_around whose figures are not built yet.
func pending() -> int:
	return _queue.size()

## One in front of the camera, facing the player.
func spawn_ahead(distance := 7.0, kind := "", turn := 0.0) -> InteriorZombie:
	var ahead := -player.camera.global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized().rotated(Vector3.UP, turn)
	for k: float in [1.0, .75, 1.3, .5]:
		var at := ground(player.global_position + ahead * distance * k, false)
		if at.is_finite():
			return spawn(at, "", atan2(ahead.x, ahead.z), false, kind)
	return null

## Debug: one of every kind, in an arc ahead. Returns how many found a place.
func spawn_every_kind(distance := 11.0) -> int:
	var kinds := InteriorZombie.KINDS.keys()
	var made := 0
	for index in kinds.size():
		var turn := (float(index) / maxf(kinds.size() - 1, 1) - .5) * 1.9
		if spawn_ahead(distance + (index % 3) * 1.6, kinds[index], turn) != null:
			made += 1
	return made

func remove(zombie: InteriorZombie) -> void:
	_corpses.erase(zombie)
	if is_instance_valid(zombie):
		zombie.queue_free()

## Debug: every one of them drops where it stands.
func kill_all() -> void:
	for zombie in alive():
		zombie.health = 0.0
		zombie._ragdoll([], -zombie.global_basis.z * 30.0)
		zombie._die()
	# (One already reeling to its death is not in that list: it falls on its own.)

## Debug: the living, the bodies and the blood, gone.
func clear() -> void:
	for node in get_tree().get_nodes_in_group("zombies") + get_tree().get_nodes_in_group("zombie_corpses"):
		node.queue_free()
	Engine.time_scale = 1.0 if not slow_motion else Engine.time_scale
	_corpses.clear()
	_queue.clear()
	_crowd_tick = -1
	blood.clear()

func _on_died(zombie: InteriorZombie) -> void:
	kills += 1
	_corpses.append(zombie)
	while _corpses.size() > MAX_CORPSES:
		var old: InteriorZombie = _corpses.pop_front()
		if is_instance_valid(old):
			old.queue_free()

# ---------------------------------------------------------------- what they know

func can_target() -> bool:
	return not passive and not _down and player.playing and not player.noclip

## The flashlight is on: the player is seen from further off.
func player_lit() -> bool:
	if main.get("story") == null or main.story == null:
		return false
	var torch: Variant = main.story.get("flashlight")
	return torch != null and bool(torch.get("on"))

## 0.37: claws and hands get between the player and `zombie` only where nothing stands between them, the same both
## ways (scripts/body.gd's shove asks this too): over a waist-high rail, yes; through a wall, a shut door, a fence
## or a window, no. Shoulder or chest to chest or head; the unseen walls are not there.
func within_reach(zombie: InteriorZombie) -> bool:
	if senses == null:
		return true
	var z := zombie.where()
	var head := player.camera.global_position + Vector3.DOWN * .2
	var chest := player.global_position + Vector3.UP * (.55 if player.crouching else .95)
	for high: float in [1.35, 1.05]:
		for at: Vector3 in [head, chest]:
			if senses.reach_clear(z + Vector3.UP * high, at):
				return true
	return false

func alert_others(source: InteriorZombie, at: Vector3, reach := SCREAM) -> void:
	for zombie in alive():
		if zombie != source and zombie.where().distance_to(source.where()) < reach:
			zombie.hear(at)

func _on_fired() -> void:
	if not can_target():
		return
	var at := player.global_position
	if senses != null:
		# The flash shows whoever fired; the report carries.
		senses.flash()
		senses.noise(at, HEARING, "shot")
		return
	for zombie in alive():
		if zombie.where().distance_to(at) < HEARING:
			zombie.hear(at)

## A push away from the others close by, so a crowd spreads instead of standing in one spot.
func separation(zombie: InteriorZombie) -> Vector3:
	var push := Vector3.ZERO
	var tick := Engine.get_physics_frames()
	if tick != _crowd_tick:
		_crowd_tick = tick
		_crowd.clear()
		for node in get_tree().get_nodes_in_group("zombies"):
			if node is InteriorZombie and not (node as InteriorZombie).ragdolled and not node.is_queued_for_deletion():
				_crowd.append(node as InteriorZombie)
	var here := zombie.global_position
	for other in _crowd:
		if other == zombie:
			continue
		var away := here - other.global_position
		if absf(away.x) > .75 or absf(away.z) > .75:
			continue
		away.y = 0.0
		var dist := away.length()
		if dist < .75 and dist > .001:
			push += away / dist * (.75 - dist) * 3.0
	return push.limit_length(1.5)

# ---------------------------------------------------------------- the player

func hurt_player(amount: float, from: Vector3, kind := "claw") -> void:
	if _down or not player.playing:
		return
	if invulnerable:
		# (0.55, tests: what the debug menu's Invulnerable refused.)
		blocked_hits += 1
		return
	health -= amount
	_since_hit = 0.0
	var away := player.global_position - from
	away.y = 0.0
	var side := (player.global_basis.inverse() * away.normalized()).x if away.length() > .01 else 0.0
	player.punch(Vector3(randf_range(2.5, 4.5), side * 5.0 + randf_range(-1.5, 1.5), side * 7.0 + randf_range(-2.0, 2.0)))
	player.jolt(.03)
	# 0.60: a small shake and a faint red flash (scripts/hurt_feedback.gd).
	InteriorHurtFeedback.hit(player, clampf(amount / 22.0, .35, 1.0))
	if body != null:
		# (The blow came from the side it pushed away from.)
		body.wounded(amount, -side, kind)
	var stream := InteriorZombie._stream("claw_hit" if kind != "fall" else "thud_%d" % (1 + randi() % 3))
	if stream != null:
		_hurt_voice.stream = stream
		_hurt_voice.volume_db = -2.0
		_hurt_voice.pitch_scale = randf_range(.9, 1.1)
		_hurt_voice.play()
	var grunt := AudioStreamPlayer.new()
	grunt.stream = InteriorZombie._stream("player_hurt_%d" % (1 + randi() % 2))
	grunt.volume_db = -5.0
	add_child(grunt)
	grunt.play()
	grunt.finished.connect(grunt.queue_free)
	if health <= 0.0:
		_player_down()

func _player_down() -> void:
	_down = true
	health = 0.0
	for zombie in alive():
		zombie.forget()
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: _shade.set_shader_parameter("black", v), 0.0, 1.0, .9)
	tween.tween_interval(1.4)
	tween.tween_callback(_wake_at_home)
	tween.tween_method(func(v: float) -> void: _shade.set_shader_parameter("black", v), 1.0, 0.0, 1.6)
	tween.tween_callback(func() -> void: _down = false)

func _wake_at_home() -> void:
	var spawn: Vector3 = player.get("_spawn_position")
	for zombie in alive():
		if zombie.where().distance_to(spawn) < 22.0:
			remove(zombie)
	if gun != null and gun.drawn:
		gun.holster(true)
	player.reset_motion(spawn)
	health = 100.0
	_since_hit = 10.0
	if body != null:
		body.reset()
	if main.get("story") != null and main.story != null:
		main.story.notify("They got you. You wake up at home.")

## Builds the figures that are waiting, and shares the animation time out: the nearest in view every frame.
func _crowd_tick_frame(delta: float) -> void:
	if not _queue.is_empty():
		_queue_wait -= 1
		if _queue_wait <= 0:
			_queue_wait = 2
			var next: Array = _queue.pop_front()
			spawn(next[0], "", NAN, next[1])
	var living := get_tree().get_nodes_in_group("zombies")
	if living.is_empty():
		return
	_rank_wait -= 1
	if _rank_wait <= 0:
		_rank_wait = 6
		var camera := get_viewport().get_camera_3d()
		var eye := camera.global_position if camera != null else player.global_position
		var ranked: Array = []
		for node in living:
			var zombie := node as InteriorZombie
			if zombie == null or zombie.is_queued_for_deletion():
				continue
			var at := zombie.global_position + Vector3.UP
			var far := at.distance_squared_to(eye)
			var seen := far < 36.0 or camera == null or camera.is_position_in_frustum(at)
			ranked.append([far if seen else far + 1.0e6, zombie, seen])
		ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		for index in ranked.size():
			var step := 1 if index < EVERY_FRAME else (2 if index < EVERY_FRAME + EVERY_SECOND else 3)
			(ranked[index][1] as InteriorZombie).animation_step = step if ranked[index][2] else 4
	var frame := Engine.get_process_frames()
	for node in living:
		if node is InteriorZombie and not node.is_queued_for_deletion():
			(node as InteriorZombie).animate(delta, frame)

func _process(delta: float) -> void:
	_crowd_tick_frame(delta)
	_since_hit += delta
	if body == null and not _down and _since_hit > 4.0 and health < 100.0:
		health = minf(100.0, health + 9.0 * delta)
	var hurt := clampf(1.0 - health / 100.0, 0.0, 1.0)
	var flash := clampf(1.0 - _since_hit / .5, 0.0, 1.0) * .25
	# 0.33: being hurt lasts now, so what stays is only a red edge (the flash of a blow is as it was).
	var amount := clampf((hurt * hurt * .62 if body != null else hurt * 1.15) + flash + pulse, 0.0, 1.0)
	_overlay.visible = amount > .005 or _down
	_shade.set_shader_parameter("amount", amount)
