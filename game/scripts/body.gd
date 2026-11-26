class_name InteriorBody
extends Node
## 0.33: the player's body in danger. There is no health bar: the body says how it is.
##
## - A blow opens a wound. It bleeds (health goes on falling, slower and slower, never to nothing) until it clots
##   by itself (a bad one in about forty seconds) or is bound: stand still and hold H for two and a half seconds. The gun is down while the hands work.
## - Rest brings health back only so far (`ceiling`): every blow takes some of that away too, and it returns slowly.
## - Below 62 the wounded side starts to limp; below 35 (critical, until it is back over 45) the limp is full: the
##   bad leg takes short hard steps, the pace drops by a third, there is no running, a jump is a third lower, climbs
##   are slower and lower. The heart is heard, the picture's red edge beats with it, the lens and the hands shake.
## - Running empties the lungs in about thirteen seconds; winded, the run falls to a jog and the heart is loud.
## - A fall of more than about two and a half metres hurts, and any hard landing costs a moment's pace.
## - V shoves: whatever stands within arm's reach in front reels back. It costs breath and takes a second to do again.
## - 0.36: the breath is heard. A few seconds into a run it starts to pant, faster and louder the emptier the
##   lungs, and goes on, slowing, while they fill again. Badly hurt or bleeding it comes slow and heavy, one breath
##   every two to four seconds. Recordings: licenses/BREATHING_SOUNDS.md, cut by tools/breath_sounds.py.

const CRITICAL := 35.0
const RECOVERED := 45.0
const HURT := 62.0
const BIND_TIME := 2.5
const SHOVE_REACH := 1.3   # 0.49: arm's length
const SHOVE_WAIT := .95
const SPRINT_SECONDS := 13.0
const REST_SECONDS := 7.0
const BREATH_SOUNDS := "res://assets/audio/sfx/"

var main: Node
var player: InteriorPlayer
var director: InteriorZombies
## Health a second running out of open wounds.
var bleeding := 0.0
## What rest alone brings health back to.
var ceiling := 100.0
var stamina := 1.0
var critical := false
## 0..1 while H is held on a wound.
var binding := 0.0
var shoves := 0
var _since_sprint := 10.0
var _since_shove := 10.0
var _beat := 0.0
var _beat_env := 0.0
var _heart: AudioStreamPlayer
var _voice: AudioStreamPlayer
var _cloth: AudioStreamPlayer
var _told_bleeding := false
var _bind_rustle := 0.0
## 0.36: 0..1, how hard the lungs are working: it rises a few seconds into a run and falls as they fill again.
var puff := 0.0
var panting := false
## Slow heavy breaths taken so far (hurt or bleeding).
var breaths := 0
var _pant: AudioStreamPlayer
var _breath: AudioStreamPlayer
var _heavy: Array[AudioStream] = []
var _breath_wait := 1.0
var _last_breath := -1

func setup(main_node: Node) -> void:
	main = main_node
	name = "Body"
	player = main.player
	director = main.zombies
	director.body = self
	_heart = AudioStreamPlayer.new()
	_heart.stream = _heartbeat()
	_heart.volume_db = -60.0
	add_child(_heart)
	_voice = AudioStreamPlayer.new()
	add_child(_voice)
	_cloth = AudioStreamPlayer.new()
	add_child(_cloth)
	_pant = AudioStreamPlayer.new()
	_pant.volume_db = -60.0
	add_child(_pant)
	_breath = AudioStreamPlayer.new()
	add_child(_breath)
	if ResourceLoader.exists(BREATH_SOUNDS + "breath_pant.wav"):
		# Its own copy: the loop is set here, not in the file every other reader of it shares.
		var loop := (load(BREATH_SOUNDS + "breath_pant.wav") as AudioStreamWAV).duplicate() as AudioStreamWAV
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_begin = 0
		loop.loop_end = int(loop.get_length() * loop.mix_rate)
		_pant.stream = loop
	for index in range(1, 20):
		var path := BREATH_SOUNDS + "breath_heavy_%d.wav" % index
		if not ResourceLoader.exists(path):
			break
		_heavy.append(load(path) as AudioStream)
	player.stepped.connect(_on_step)
	player.landed.connect(_on_landed)
	player.mantled.connect(_on_mantled)

func health() -> float:
	return director.health

## 0 well .. 1 at death's door.
func hurt() -> float:
	return clampf(1.0 - director.health / 100.0, 0.0, 1.0)

func reset() -> void:
	bleeding = 0.0
	ceiling = 100.0
	stamina = 1.0
	critical = false
	binding = 0.0
	_apply(1.0)

## Debug menu.
func heal() -> void:
	director.health = 100.0
	reset()

## A blow has landed (scripts/zombies.gd has already taken `amount` off). `side`: -1 from the left .. 1 from the right.
func wounded(amount: float, side: float, kind := "claw") -> void:
	ceiling = maxf(40.0, ceiling - amount * .4)
	if kind != "fall":
		bleeding = minf(1.6, bleeding + amount * .03)
		if absf(side) > .15:
			player.limp_side = signf(side)
	player.stumble = maxf(player.stumble, .25 if kind != "fall" else .5)
	binding = 0.0
	if bleeding > .3 and not _told_bleeding and main.get("story") != null and main.story != null:
		_told_bleeding = true
		main.story.notify("You are bleeding. Stand still and hold H to bind it.")

func _physics_process(delta: float) -> void:
	if player == null or director == null or not player.playing:
		return
	if director.get("_down") == true:
		bleeding = 0.0
		binding = 0.0
		player.hands_busy = false
		return
	var since_hit: float = director.get("_since_hit")
	var moving := Vector2(player.velocity.x, player.velocity.z).length()
	# Wounds.
	if bleeding > 0.0:
		if director.health > 8.0 and not director.invulnerable:
			director.health = maxf(8.0, director.health - bleeding * delta)
		bleeding = maxf(0.0, bleeding - .04 * delta)
	_bind(delta, moving)
	if bleeding <= 0.0 and since_hit > 6.0:
		if director.health < ceiling:
			director.health = minf(ceiling, director.health + 2.5 * delta)
		elif ceiling < 100.0 and moving < InteriorPlayer.WALK_SPEED * 1.1:
			ceiling = minf(100.0, ceiling + .4 * delta)
			director.health = maxf(director.health, minf(ceiling, director.health + .4 * delta))
	# Breath.
	if player.is_sprinting and moving > InteriorPlayer.WALK_SPEED * 1.2:
		_since_sprint = 0.0
		stamina = maxf(0.0, stamina - delta / SPRINT_SECONDS)
	else:
		_since_sprint += delta
		if _since_sprint > .8:
			stamina = minf(1.0, stamina + delta / REST_SECONDS * (1.3 if moving < .3 else 1.0))
	_since_shove += delta
	if InputMap.has_action("shove") and Input.is_action_just_pressed("shove"):
		shove()
	_apply(delta)

func _apply(delta: float) -> void:
	var health := director.health
	if health < CRITICAL:
		critical = true
	elif health > RECOVERED:
		critical = false
	var limp := 1.0 if critical else clampf((HURT - health) / (HURT - CRITICAL), 0.0, 1.0) * .45
	player.limp = lerpf(player.limp, limp, 1.0 - exp(-2.5 * delta))
	if player.limp < .003 and limp == 0.0:
		player.limp = 0.0
	player.can_run = not critical
	player.winded = smoothstep(.3, .02, stamina)
	player.strain = clampf(hurt() * .9 + player.winded * .35 + (.25 if bleeding > .2 else 0.0), 0.0, 1.0)

## H held, standing still, on an open wound.
func _bind(delta: float, moving: float) -> void:
	var held := bleeding > 0.0 and ((InputMap.has_action("heal") and Input.is_action_pressed("heal")) or player.touch_binding) and moving < 1.3 and not player.mantling
	var pad: Variant = main.get("touch")
	if pad != null and pad is InteriorTouchControls:
		(pad as InteriorTouchControls).set_wound_state(bleeding > 0.0)
	if not held:
		binding = 0.0
		player.hands_busy = false
		return
	player.hands_busy = true
	binding += delta / BIND_TIME
	_bind_rustle -= delta
	if _bind_rustle <= 0.0:
		_bind_rustle = .55
		_rustle()
	if binding >= 1.0:
		binding = 0.0
		bleeding = 0.0
		ceiling = minf(100.0, ceiling + 6.0)
		player.hands_busy = false
		if main.get("story") != null and main.story != null:
			main.story.notify("Bound. It holds.")

func _rustle() -> void:
	var path := "res://assets/audio/footsteps/footstep_carpet_00%d.ogg" % (randi() % 5)
	if ResourceLoader.exists(path):
		_cloth.stream = load(path)
		_cloth.pitch_scale = randf_range(1.5, 1.9)
		_cloth.volume_db = -13.0
		_cloth.play()

## T (0.48; V before): both hands out. Whatever stands close in front reels back, and loose things are pushed.
func shove() -> int:
	if _since_shove < SHOVE_WAIT or player.mantling or player.hands_busy or not player.playing or player.cutscene:
		return -1
	_since_shove = 0.0
	shoves += 1
	stamina = maxf(0.0, stamina - .11)
	var forward := -player.camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var from := player.global_position
	var struck := 0
	# 0.49: two hands push one body, the nearest in front.
	var target: InteriorZombie = null
	var nearest := INF
	for zombie: InteriorZombie in director.alive():
		var to := zombie.where() - from
		var height := absf(to.y)
		to.y = 0.0
		if to.length() > SHOVE_REACH or height > 1.2 or (to.length() > .3 and to.normalized().dot(forward) < .5):
			continue
		if zombie.state == InteriorZombie.State.DOWN or zombie.state == InteriorZombie.State.DEAD or zombie.state == InteriorZombie.State.CRAWL or zombie.state == InteriorZombie.State.GETUP:
			continue
		# 0.37: not through a wall, a door, a fence or a window (the rule its claws go by).
		if not director.within_reach(zombie):
			continue
		if to.length() < nearest:
			nearest = to.length()
			target = zombie
	if target != null:
		target.shoved(forward, 1.0 - .4 * player.limp)
		struck += 1
		_pass_stumble(target, forward, .3)

	var moved := _shove_things(from, forward)
	var gun: Variant = main.story.gun if main.get("story") != null and main.story != null else null
	if gun != null and (gun as InteriorGun).drawn:
		(gun as InteriorGun).thrust()
	player.punch(Vector3(-1.6, randf_range(-.6, .6), randf_range(-.8, .8)))
	if struck > 0 or moved > 0:
		player.jolt(.012)
		var thud := InteriorZombie._stream("thud_%d" % (1 + randi() % 3))
		if thud != null:
			_voice.stream = thud
			_voice.volume_db = -7.0
			_voice.pitch_scale = randf_range(1.05, 1.25)
			_voice.play()
		var senses: Variant = main.get("senses")
		if senses != null:
			(senses as InteriorSenses).noise(from, 5.0, "shove")
	return struck

## 0.48: one reeling back into others takes them with it, and they the ones behind them, a little less each time.
func _pass_stumble(from_zombie: InteriorZombie, way: Vector3, strength: float, depth := 0) -> void:
	if depth > 0 or strength < .25:
		return
	for other: InteriorZombie in director.alive():
		if other == from_zombie or other.state == InteriorZombie.State.STAGGER or other.state == InteriorZombie.State.DOWN 				or other.state == InteriorZombie.State.CRAWL or other.state == InteriorZombie.State.GETUP:
			continue
		var gap := other.where() - from_zombie.where()
		gap.y = 0.0
		if gap.length() > .75 or (gap.length() > .3 and gap.normalized().dot(way) < .2):
			continue
		other.shoved((way + gap.normalized() * .4).normalized(), strength)
		_pass_stumble(other, way, strength - .3, depth + 1)

## 0.48: T into a table, a chair, a box: it goes, as hard as its weight lets it. Returns how many moved.
func _shove_things(from: Vector3, forward: Vector3) -> int:
	var space := player.get_world_3d().direct_space_state
	var reach := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	ball.radius = .8
	reach.shape = ball
	reach.collision_mask = 4
	reach.exclude = [player.get_rid()]
	reach.transform = Transform3D(Basis.IDENTITY, from + forward * .95 + Vector3.UP * .8)
	var moved := 0
	for found in space.intersect_shape(reach, 8):
		var body := found.collider as RigidBody3D
		if body == null or (body.freeze and not body is InteriorObject):
			continue
		if body is InteriorObject:
			var thing := body as InteriorObject
			if thing.anchored and thing.freeze:
				continue
			thing.activate()
		body.sleeping = false
		var mass := maxf(body.mass, 1.0)
		# 0.49: what two arms put into it (about 45 N s at most): a box skids, a table shifts, a rack barely moves.
		body.apply_impulse(forward * minf(mass * 1.6, 45.0) + Vector3.UP * clampf(mass * .08, 0.0, 3.0), Vector3(0, .3, 0))
		moved += 1
	return moved

func _on_step(_surface: String, _strength: float) -> void:
	# The bad leg, now and then.
	if critical and player._on_bad_leg() and randf() < .3:
		_grunt(-17.0, randf_range(1.05, 1.2))

func _on_mantled(height: float, _over: bool) -> void:
	stamina = maxf(0.0, stamina - .04 - .05 * height)
	if critical:
		_grunt(-12.0, 1.0)

func _on_landed(_surface: String, fall_speed: float) -> void:
	var speed := -fall_speed
	if speed > 6.0:
		player.stumble = maxf(player.stumble, clampf((speed - 6.0) * .16, .15, .7))
	# (0.55: not in a co-op game: the squad's health is the session's, and this body's director is switched off there.
	# Its health still fell on every hard landing, with the blow's sound, shove and stumble, invulnerable or not.)
	var coop: Node = main.get("coop")
	if coop != null and bool(coop.get("active")):
		return
	if speed > 8.4 and not director.invulnerable:
		director.hurt_player((speed - 7.6) * 8.0, player.global_position, "fall")
	elif critical and speed > 3.0:
		_grunt(-12.0, 1.1)

func _grunt(volume: float, pitch: float) -> void:
	if _voice.playing:
		return
	var stream := InteriorZombie._stream("player_hurt_%d" % (1 + randi() % 2))
	if stream != null:
		_voice.stream = stream
		_voice.volume_db = volume
		_voice.pitch_scale = pitch
		_voice.play()

func _process(delta: float) -> void:
	if player == null or director == null:
		return
	# The heart: faster and louder the worse it is; heard only when hurt or out of breath.
	var bad := hurt()
	var loud := clampf(maxf((bad - .3) * 1.7, (.5 - stamina) * 1.6), 0.0, 1.0)
	if not player.playing:
		loud = 0.0
	var rate := (62.0 + 58.0 * (1.0 - stamina) + 48.0 * bad) / 60.0
	_beat += delta * rate
	_beat_env = maxf(0.0, _beat_env - delta * 4.5)
	if _beat >= 1.0:
		_beat = fmod(_beat, 1.0)
		if loud > .02:
			_heart.volume_db = lerpf(-30.0, -7.0, loud)
			_heart.pitch_scale = lerpf(.94, 1.1, clampf(rate - 1.0, 0.0, 1.0))
			_heart.play()
			_beat_env = 1.0
	director.pulse = _beat_env * .14 * smoothstep(.4, .75, bad)
	_breathe(delta, bad)

## 0.36: the breath. Running: one fast loop whose loudness and speed follow the lungs. Hurt: single slow breaths.
func _breathe(delta: float, bad: float) -> void:
	var alive: bool = player.playing and director.get("_down") != true
	# Panting starts about four seconds into a run (two thirds of the breath left) and is full near the end of it.
	var want := clampf((.66 - stamina) / .5, 0.0, 1.0) if alive else 0.0
	puff = move_toward(puff, want, delta * (.9 if want > puff else .45))
	if _pant.stream != null:
		if puff > .04:
			_pant.volume_db = lerpf(-34.0, -12.0, pow(puff, .7)) + 2.0 * bad
			_pant.pitch_scale = lerpf(.84, 1.06, puff)
			if not panting:
				panting = true
				_pant.play()
		elif panting:
			panting = false
			_pant.stop()
	# Hurt (under about 58, worst under 28) or bleeding: slow, heavy, and under the panting it is not heard.
	var ache := smoothstep(.42, .72, bad)
	if bleeding > .2:
		ache = maxf(ache, .35)
	if not alive:
		ache = 0.0
	_breath_wait -= delta
	if ache <= .05:
		_breath_wait = minf(_breath_wait, .8)
	elif puff < .3 and _breath_wait <= 0.0 and not _heavy.is_empty() and not _breath.playing:
		var pick := randi() % _heavy.size()
		if pick == _last_breath:
			pick = (pick + 1) % _heavy.size()
		_last_breath = pick
		_breath.stream = _heavy[pick]
		_breath.volume_db = lerpf(-25.0, -10.0, ache)
		_breath.pitch_scale = randf_range(.95, 1.04) * lerpf(.96, 1.05, ache)
		_breath.play()
		breaths += 1
		_breath_wait = lerpf(3.8, 2.2, ache) * randf_range(.9, 1.12)

## Two soft thumps, made here: the first low and long, the second shorter and a little higher.
static func _heartbeat() -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * .46)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / rate
		var v := 0.0
		for thump: Array in [[0.0, 46.0, 30.0, 1.0], [.17, 58.0, 44.0, .6]]:
			var u := t - float(thump[0])
			if u >= 0.0:
				var attack := minf(1.0, u / .008)
				var freq := float(thump[1]) * (1.0 + .5 * exp(-u * 40.0))
				v += sin(TAU * freq * u) * exp(-u * float(thump[2])) * attack * float(thump[3])
				v += sin(TAU * freq * 2.0 * u) * exp(-u * float(thump[2]) * 1.8) * attack * float(thump[3]) * .22
		data.encode_s16(i * 2, int(clampf(v * .8, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
