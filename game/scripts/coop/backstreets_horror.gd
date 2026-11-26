extends RefCounted
## 0.45: what happened in the backstreets, and what is still happening. Built into Backstreets (backstreets.gd)
## before its meshes are committed; `tick` runs from Backstreets.tick on every peer.
##
## The lanes are darker than 0.44: about half the lamps are out, the rest weaker, so the gaps between the pools
## are where a flashlight earns its keep. What light is left here and there has a reason to be there: a
## flashlight someone dropped, still on, its beam along the wet ground; candles at a door; a phone face up on the
## asphalt; a television left on behind a curtain. Lamps that are failing buzz and stutter, die and come back;
## broken fittings and a torn-down cable spit sparks now and then (with the arc's crackle and a flash on the
## walls). Blood, kept subtle: small pools and spatter in the lanes, drags into doorways and under shutters,
## smears along the walls at hip height where someone leaned and kept going. Nothing written, no hand prints.
## Far off, now and then, something screams, or a dog pack starts, somewhere down a lane you are not in.

const SPARK_SOUND := "res://assets/audio/nichols/arc_buzz.ogg"
const FAR_SOUNDS := ["res://assets/audio/zombies/scream_1.ogg", "res://assets/audio/zombies/scream_2.ogg",
	"res://assets/audio/zombies/scream_3.ogg", "res://assets/audio/siege/groan_b.ogg", "res://assets/audio/siege/groan_c.ogg",
	"res://assets/audio/night/dog_pack.ogg", "res://assets/audio/siege/rattle.ogg"]
## Light behaviours: a fluorescent's stutter, a bulb that is dying (mostly off), a flame, a television.
enum { BUZZ, DYING, FLAME, TV }

var bs
var s
var rng: RandomNumberGenerator
## [light, base energy, mode, seed]
var lights: Array = []
## [particles, flash light, sound player, next time]
var sparks: Array = []
var _far: AudioStreamPlayer3D
var _next_far := 18.0
var _last := 0.0

func build(backstreets) -> void:
	bs = backstreets
	s = bs.s
	rng = bs.rng
	_blood()
	_little_lights()
	for at: Vector3 in _spark_sites(): _spark(at)
	_far = AudioStreamPlayer3D.new()
	_far.unit_size = 9.0
	_far.max_distance = 90.0
	_far.volume_db = -4.0
	_far.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	bs.add_child(_far)

# ---------------------------------------------------------------- blood

func _blood() -> void:
	for spec: Array in bs.CORRIDORS:
		var x0: float = spec[0]
		var x1: float = spec[1]
		var z0: float = spec[2]
		var z1: float = spec[3]
		var along_z := (z1 - z0) >= (x1 - x0)
		var length := maxf(z1 - z0, x1 - x0)
		if length < 10.0: continue
		var t := rng.randf_range(2.0, 5.0)
		while t < length - 2.0:
			var roll := rng.randf()
			var across := rng.randf_range(.25, .75)
			var at := Vector3(lerpf(x0, x1, across), 0, z0 + t) if along_z else Vector3(x0 + t, 0, lerpf(z0, z1, across))
			if roll < .4:
				# A small pool or spatter in the lane, darkened by the rain.
				s.stain(["pool_big", "splat_a", "splat_b", "splat_c", "spatter_floor"][rng.randi() % 5], at, rng.randf() * TAU,
					rng.randf_range(.7, 1.4), rng.randf_range(.6, 1.2), rng.randf_range(.5, .8))
			elif roll < .62:
				# Dragged to the side: into a doorway, under a shutter.
				var left := rng.randf() < .5
				var end := Vector3(x0 + .25 if left else x1 - .25, 0, at.z + rng.randf_range(-1.5, 1.5)) if along_z \
					else Vector3(at.x + rng.randf_range(-1.5, 1.5), 0, z0 + .25 if left else z1 - .25)
				s.drag_trail(at, end, rng.randf() < .45)
			elif roll < .92:
				# Along a wall at hip height: leaned on, walked along, then not.
				var left := rng.randf() < .5
				var normal := (Vector3(1, 0, 0) if left else Vector3(-1, 0, 0)) if along_z else (Vector3(0, 0, 1) if left else Vector3(0, 0, -1))
				var wall := Vector3(x0 if left else x1, rng.randf_range(.75, 1.25), at.z) if along_z else Vector3(at.x, rng.randf_range(.75, 1.25), z0 if left else z1)
				_wall_smear(wall, normal, rng.randf_range(1.2, 2.6), rng.randf_range(.35, .6), rng.randf_range(.55, .85))
				if rng.randf() < .5:
					s.stain("spatter_floor", wall + normal * .5 - Vector3.UP * wall.y, rng.randf() * TAU, .9, .8, .55)
			t += rng.randf_range(3.5, 7.5)

## A smear on a wall: the street's floor decal turned to project into the wall along `-normal`.
func _wall_smear(at: Vector3, normal: Vector3, length: float, height: float, alpha: float) -> void:
	s.stain("smear_wall", at, 0.0, length, height, alpha, .6)
	var d := s.get_child(s.get_child_count() - 1) as Decal
	if d == null: return
	var y := normal.normalized()
	var z := Vector3.UP
	d.basis = Basis(y.cross(z), y, z).rotated(y, rng.randf_range(-.12, .12))
	d.position = at + normal * .05

# ---------------------------------------------------------------- the little lights

func _little_lights() -> void:
	# Hand-placed in the stretches: [kind, where, facing yaw].
	var spots := [
		["flashlight", Vector3(-2.9, 0, 117.6), 2.3], ["candles", Vector3(-4.5, 0, 101.0), 0.0], ["tv", Vector3(.7, 4.6, 89.0), 0.0],
		["phone", Vector3(9.5, 0, 144.4), 0.0], ["candles", Vector3(31.0, 0, 142.4), 0.0], ["tv", Vector3(22.0, 4.6, 148.8), 0.0],
		["flashlight", Vector3(43.6, 0, 206.6), -2.6], ["phone", Vector3(41.4, 0, 183.0), 0.0], ["candles", Vector3(45.5, 0, 226.0), 0.0],
		["tv", Vector3(41.2, 4.4, 258.0), 0.0], ["phone", Vector3(29.0, 0, 291.0), 0.0], ["candles", Vector3(26.5, 0, 302.0), 0.0],
		["flashlight", Vector3(28.6, 0, 369.0), .9], ["tv", Vector3(23.2, 4.6, 335.0), 0.0], ["candles", Vector3(31.3, 0, 392.0), 0.0],
		["phone", Vector3(27.3, 0, 438.0), 0.0], ["tv", Vector3(30.8, 4.6, 470.0), 0.0], ["candles", Vector3(25.6, 0, 486.0), 0.0],
	]
	# The service gate: a caged bulb over it, buzzing, the first light past the mart (and the last for a while).
	var gate := Vector3(-4.75, 3.25, 82.4)
	bs.bx(gate + Vector3(.12, 0, 0), Vector3(.2, .2, .2), "#24251f", false, Basis.IDENTITY, 0)
	bs.bx(gate + Vector3(.14, -.06, 0), Vector3(.1, .1, .1), "glow#ffd08a*4.0", false, Basis.IDENTITY, 0)
	var bulb: SpotLight3D = bs.pool(gate + Vector3(.2, -.15, 0), Vector3(1, 0, 0), Color(1.0, .7, .4), 5.0, true)
	lights.append([bulb, 5.0, BUZZ, 3.0])
	for spec: Array in spots:
		var at: Vector3 = spec[1]
		var stretch: int = bs.stretch_at(Vector3(at.x, 0, at.z))
		if stretch < 0: stretch = bs._nearest_stretch(at)
		match spec[0]:
			"flashlight": _flashlight(at, spec[2], stretch)
			"candles": _candles(at, stretch)
			"phone": _phone(at, stretch)
			"tv": _tv(at, stretch)

## Dropped where its owner went down, still on: a short black torch on its side, the beam along the ground.
func _flashlight(at: Vector3, yaw: float, stretch: int) -> void:
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * .5)
	bs.cyl(at + Vector3.UP * .03, .022, .2, "#151515", b, 8, stretch)
	var head := at + Vector3.UP * .03 + Basis(Vector3.UP, yaw) * Vector3(0, 0, -.11)
	bs.cyl(head, .03, .03, "glow#fff6dc*4.0", b, 8, stretch)
	var sp := SpotLight3D.new()
	# In front of the lens: the torch's own head would shadow the whole beam.
	sp.position = head + Basis(Vector3.UP, yaw) * Vector3(0, 0, -.06) + Vector3.UP * .02
	sp.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -.05)
	sp.light_color = Color(1.0, .95, .84)
	sp.light_energy = 3.0
	sp.spot_range = 10.0
	sp.spot_angle = 16.0
	sp.spot_angle_attenuation = 1.2
	sp.shadow_enabled = true
	sp.distance_fade_enabled = true
	sp.distance_fade_begin = 40.0
	sp.distance_fade_length = 10.0
	sp.set_meta("outdoor", true)
	bs.add_child(sp)
	s.stain("splat_b", at + Basis(Vector3.UP, yaw) * Vector3(0, 0, .5), rng.randf() * TAU, .8, .7, .7)

## A row of white candles on a saucer at a door, as for a wake: some burnt out.
func _candles(at: Vector3, stretch: int) -> void:
	for k in 5:
		var off := Vector3(rng.randf_range(-.18, .18), 0, rng.randf_range(-.18, .18))
		var h := rng.randf_range(.05, .16)
		bs.cyl(at + off + Vector3.UP * h * .5, .018, h, "#ece6d4", Basis.IDENTITY, 6, stretch)
		if k < 3: bs.cyl(at + off + Vector3.UP * (h + .015), .006, .03, "glow#ffc566*5.0", Basis.IDENTITY, 4, stretch)
	bs.cyl(at + Vector3.UP * .005, .26, .01, "#8f8a80", Basis.IDENTITY, 12, stretch)
	var l: OmniLight3D = bs.lamp(at + Vector3.UP * .3, Color(1.0, .62, .3), .55, 3.2)
	lights.append([l, .55, FLAME, rng.randf() * 100.0])

## A phone face up on the asphalt, its screen still lit (a call nobody answers).
func _phone(at: Vector3, stretch: int) -> void:
	var yaw := rng.randf() * TAU
	bs.bx(at + Vector3.UP * .006, Vector3(.075, .01, .155), "#0d0d0f", false, Basis(Vector3.UP, yaw), stretch)
	bs.bx(at + Vector3.UP * .012, Vector3(.066, .002, .14), "glow#cfe4ff*1.6", false, Basis(Vector3.UP, yaw), stretch)
	var l: OmniLight3D = bs.lamp(at + Vector3.UP * .12, Color(.7, .82, 1.0), .22, 1.4)
	lights.append([l, .22, DYING, rng.randf() * 100.0])
	s.stain("spatter_floor", at + Vector3(rng.randf_range(-.6, .6), 0, rng.randf_range(-.6, .6)), rng.randf() * TAU, 1.0, .9, .6)

## A television on behind a first-floor window: a cold, jumping light on the ceiling and the curtain.
func _tv(at: Vector3, _stretch: int) -> void:
	var l: OmniLight3D = bs.lamp(at, Color(.55, .7, 1.0), .9, 4.5)
	lights.append([l, .9, TV, rng.randf() * 100.0])

# ---------------------------------------------------------------- sparks

func _spark_sites() -> Array:
	var out: Array = []
	# Dead lamp fittings (Backstreets records them), a few of them still shorting.
	for at: Vector3 in bs.dead_lamps:
		if rng.randf() < .35: out.append(at)
	# A cable torn down from the poles, its end on the ground in the pole street and the brick alley.
	for spec in [[Vector3(24.2, 7.6, 342.0), Vector3(26.4, .05, 344.5)], [Vector3(30.6, 7.4, 446.0), Vector3(28.9, .05, 443.0)]]:
		var a: Vector3 = spec[0]
		var b: Vector3 = spec[1]
		bs.wire(a, b, .4, .02)
		out.append(b + Vector3.UP * .05)
	return out

func _spark(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.position = at
	p.emitting = false
	p.one_shot = true
	p.explosiveness = .85
	p.amount = 22
	p.lifetime = .75
	p.direction = Vector3.DOWN
	p.spread = 75.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 3.6
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = .5
	p.scale_amount_max = 1.0
	var quad := QuadMesh.new()
	quad.size = Vector2(.035, .035)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color(1.0, .78, .4)
	mat.emission_enabled = true
	mat.emission = Color(1.0, .7, .3)
	mat.emission_energy_multiplier = 6.0
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	p.mesh = quad
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, .95, .8, 1.0))
	fade.set_color(1, Color(1.0, .35, .08, 0.0))
	p.color_ramp = fade
	p.visibility_range_end = 60.0
	bs.add_child(p)
	var flash := OmniLight3D.new()
	flash.position = at
	flash.light_color = Color(.85, .9, 1.0)
	flash.light_energy = 0.0
	flash.omni_range = 7.0
	flash.distance_fade_enabled = true
	flash.distance_fade_begin = 40.0
	flash.distance_fade_length = 10.0
	flash.set_meta("outdoor", true)
	bs.add_child(flash)
	var sound := AudioStreamPlayer3D.new()
	sound.stream = load(SPARK_SOUND)
	sound.position = at
	sound.unit_size = 3.0
	sound.max_distance = 26.0
	sound.volume_db = -6.0
	bs.add_child(sound)
	sparks.append([p, flash, sound, rng.randf_range(1.0, 8.0), 0.0])

# ---------------------------------------------------------------- running

func tick(now: float) -> void:
	var delta := clampf(now - _last, 0.0, .1)
	_last = now
	for f: Array in lights:
		var l: Light3D = f[0]
		var base: float = f[1]
		var seed_value: float = f[3]
		match int(f[2]):
			FLAME: l.light_energy = base * (.82 + .12 * sin(now * 9.1 + seed_value) + .07 * sin(now * 23.7 + seed_value * 2.0))
			DYING:
				var cycle := fmod(now + seed_value, 6.0)
				l.light_energy = base * (1.0 if cycle < 3.4 else (.0 if cycle < 5.2 else (1.0 if sin(now * 40.0) > 0 else .1)))
			TV:
				var cut := floorf((now + seed_value) * 2.3)
				var shade := fposmod(sin(cut * 12.9898) * 43758.5453, 1.0)
				l.light_energy = base * (.35 + shade * .9)
				l.light_color = Color(.5 + shade * .3, .62 + shade * .2, 1.0)
			BUZZ:
				var burst := fmod(now * .37 + seed_value, 4.0) < .6
				l.light_energy = base * ((.05 if sin(now * 63.0 + seed_value) > .2 else 1.0) if burst else 1.0)
	for sp: Array in sparks:
		var flash: OmniLight3D = sp[1]
		if flash.light_energy > 0.0: flash.light_energy = maxf(0.0, flash.light_energy - delta * 22.0)
		if now >= float(sp[3]):
			var p: CPUParticles3D = sp[0]
			p.restart()
			p.emitting = true
			flash.light_energy = rng.randf_range(2.0, 3.4)
			var sound: AudioStreamPlayer3D = sp[2]
			if sound.stream != null:
				sound.pitch_scale = rng.randf_range(.85, 1.2)
				sound.play(rng.randf_range(0.0, .4))
				sp[4] = now + rng.randf_range(.25, .6)
			# Shorts come in twos and threes, then quiet for a while.
			sp[3] = now + (rng.randf_range(.15, .5) if rng.randf() < .4 else rng.randf_range(3.0, 11.0))
		if float(sp[4]) > 0.0 and now >= float(sp[4]):
			(sp[2] as AudioStreamPlayer3D).stop()
			sp[4] = 0.0
	_far_sound(now)

## Now and then, something far down another lane: only while someone here is in the backstreets.
func _far_sound(now: float) -> void:
	if now < _next_far or _far == null or not _far.is_inside_tree(): return
	_next_far = now + rng.randf_range(22.0, 48.0)
	var camera: Camera3D = bs.get_viewport().get_camera_3d()
	if camera == null: return
	var here: Vector3 = camera.global_position - s.global_position
	if here.z < 78.0 or here.z > 505.0: return
	var dir := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
	_far.position = here + dir * rng.randf_range(22.0, 40.0) + Vector3.UP * 2.0
	# A copy: the road glimpses loop the same groans, and a far sound plays once.
	var stream := (load(FAR_SOUNDS[rng.randi() % FAR_SOUNDS.size()]) as AudioStream).duplicate()
	if stream is AudioStreamOggVorbis: (stream as AudioStreamOggVorbis).loop = false
	_far.stream = stream
	_far.pitch_scale = rng.randf_range(.8, 1.05)
	_far.play()
