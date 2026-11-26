extends Node
## 0.68: Doctor Lucky, the Morboid: the laboratory's last thing alive (scripts/coop/hospital.gd brings him out of his
## pod when Doctor Berido has told the squad what he was). Owner's brief (2026-11-26): "a new type, Fast and has big
## claws in each hands and he has uber opened unhinged jaw ... the ability to leap great distances and climb and stick
## to walls, very creepy and scary".
##
## The fight (host; every peer draws it from `mission.flags.lucky`):
##   - out of the pod screaming; then he sprints at whoever is nearest (6 m/s, faster than anyone can run) and rakes
##     anyone within reach with both claws (two hits);
##   - LEAP: down on his haunches for a moment, his claws scraping sparks off the floor (the tell), then he is in the
##     air, twelve, twenty metres, and lands on where his target stood: everyone at the landing is thrown and cut;
##   - WALL: he leaps onto a wall above the catwalk and clings there, spread like a spider, crawling along it above the
##     squad, his jaw hanging; then he drops off it onto someone;
##   - SCREAM: twice in the fight, up on his feet with his arms flung wide: the pods along the north wall break and
##     what was in them comes out.
##   - his health is a heart monitor's trace on everyone's screen (`Vitals`), the beat faster and wilder as it runs out;
##     it flatlines when he dies.
const BODY := preload("res://scripts/coop/lucky_body.gd")
const KIND := 901
const NAME := "Doctor Lucky, the Morboid"
const RUN_SPEED := 6.0
const LEAP_WIND := .75
const SWIPE_REACH := 2.6
## The laboratory (hospital-local): its floor and its four walls (x or z of the wall's face, its normal into the hall).
const LAB_LO := Vector3(4.6, 8.4, 12.6)
const LAB_HI := Vector3(23.4, 8.4, 35.4)
const WALLS := [[4.15, Vector3(1, 0, 0)], [23.85, Vector3(-1, 0, 0)], [12.15, Vector3(0, 0, 1)], [35.85, Vector3(0, 0, -1)]]

var mission
var session
var hosp
var boss
var state := "none"
var state_time := 0.0
var hp := 0.0
var max_hp := 0.0
var target := 0
var clock := 0.0
var melee_wait := 0.0
var special_wait := 3.0
var screams := 0
var _path := PackedVector3Array()
var _path_wait := 0.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _dur := 1.0
var _arc := 3.0
var _wall_n := Vector3.ZERO
var _wall_dir := 1.0
var _wall_for := 2.0
var _after_leap := "land"
var _hits_done := 0
var _recent := 0.0
var _recent_t := 0.0
var _stuck := 0.0
var _last := Vector3.ZERO
## Every peer.
var _hud: CanvasLayer
var _vitals: Vitals
var _box: Control
var _shown := 0.0
var _seen_state := ""
var _scrape: GPUParticles3D

func setup(m, h) -> void:
	mission = m
	session = m.session
	hosp = h
	name = "Doctor Lucky"

func _hl(w: Vector3) -> Vector3: return hosp.local(w) - hosp.HO
func _w(l: Vector3) -> Vector3: return hosp.world(hosp.HO + l)

# ---------------------------------------------------------------- host

func _ensure_boss() -> void:
	if boss != null and is_instance_valid(boss): return
	for z in mission.enemies.values():
		if is_instance_valid(z) and z.has_meta("boss") and int(z.get_meta("kind", 0)) == KIND:
			boss = z
			return
	if state != "none": return
	mission.next_id += 1
	boss = mission.make_enemy(mission.next_id, KIND, _w(hosp.POD_LUCKY + Vector3(0, 0, -1.3)))
	if boss == null: return
	boss.rotation.y = 0.0
	boss.asleep = false
	boss.idle_mode = ""
	var humans := 0
	var bots := 0
	for id: int in session.team:
		if session.is_bot(id): bots += 1
		else: humans += 1
	max_hp = clampf(2200.0 + 700.0 * float(maxi(humans - 1, 0)) + 250.0 * float(bots), 2200.0, 5200.0)
	if str(session.mode) == "hard": max_hp *= 1.25
	elif str(session.mode) == "easy": max_hp *= .8
	hp = max_hp
	boss.hp = hp
	_go("emerge")
	print("INTERIOR_COOP_LUCKY out of his pod, hp %.0f" % max_hp)

func tick(delta: float, living: Array) -> void:
	clock += delta
	_ensure_boss()
	if boss == null or not is_instance_valid(boss) or state == "dead":
		_publish()
		return
	state_time += delta
	melee_wait -= delta
	special_wait -= delta
	_recent_t -= delta
	if _recent_t <= 0.0: _recent = 0.0
	if living.is_empty():
		_publish()
		return
	match state:
		"emerge": _emerge(delta)
		"fight": _fight(delta)
		"swipe": _swipe(delta)
		"wind": _wind(delta)
		"leap": _leap(delta)
		"land": _land(delta)
		"wall": _wall(delta)
		"scream": _scream(delta)
		"hit": _flinch(delta)
	_publish()

func _go(next: String) -> void:
	state = next
	state_time = 0.0
	if next != "hit": print("INTERIOR_COOP_LUCKY %s (hp %.0f)" % [next, hp])

func _pick() -> int:
	var best := INF
	var found := 0
	for id: int in session.team:
		var p: Dictionary = session.team[id]
		if int(p.hp) <= 0: continue
		var d: float = boss.position.distance_to(p.pos)
		if not session.is_bot(id): d *= .8
		if d < best:
			best = d
			found = id
	return found

func _face(at: Vector3, delta: float, rate := 9.0) -> void:
	var to: Vector3 = at - boss.position
	to.y = 0.0
	if to.length() < .2: return
	boss.rotation.y = lerp_angle(boss.rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-rate * delta))

func _gravity(delta: float) -> void:
	boss.velocity.x = 0.0
	boss.velocity.z = 0.0
	boss.velocity.y = minf(0.0, boss.velocity.y) - 16.0 * delta
	boss.move_and_slide()

func _emerge(delta: float) -> void:
	boss.pose("lucky_scream")
	_gravity(delta)
	if session.team.has(_pick()): _face(session.team[_pick()].pos, delta, 3.0)
	if state_time > 2.3: _go("fight")

func _fight(delta: float) -> void:
	target = _pick()
	if target == 0:
		boss.pose("lucky_idle")
		_gravity(delta)
		return
	var tp: Vector3 = session.team[target].pos
	var d: float = boss.position.distance_to(tp)
	var tl := _hl(tp)
	var in_lab: bool = tl.x > 4.2 and tl.x < 23.8 and tl.z > 12.2 and tl.z < 35.8 and tl.y > 7.5
	if d < SWIPE_REACH and absf(tp.y - boss.position.y) < 1.6 and melee_wait <= 0.0:
		_hits_done = 0
		_go("swipe")
		return
	if special_wait <= 0.0:
		special_wait = randf_range(4.5, 7.5)
		var roll := randf()
		if screams < 2 and hp < max_hp * (.7 if screams == 0 else .35):
			screams += 1
			_go("scream")
			return
		if roll < .45 and in_lab:
			_start_wall()
			return
		if d > 4.0:
			_go("wind")
			return
	# Up on the catwalk or out of reach of his feet: he jumps for it.
	if absf(tp.y - boss.position.y) > 2.5 and special_wait < 2.5:
		_go("wind")
		return
	_run_at(tp, delta)
	if _stuck > 1.6:
		_stuck = 0.0
		_go("wind")

func _run_at(tp: Vector3, delta: float) -> void:
	_path_wait -= delta
	if _path_wait <= 0.0 or _path.is_empty():
		_path_wait = .45
		mission.nav.space = mission.get_world_3d().direct_space_state
		_path = mission.nav.path(boss.position, tp)
	var goal := tp
	while not _path.is_empty() and Vector2(_path[0].x - boss.position.x, _path[0].z - boss.position.z).length() < .5:
		_path.remove_at(0)
	if not _path.is_empty(): goal = _path[0]
	var dir: Vector3 = goal - boss.position
	dir.y = 0.0
	if dir.length() < .05:
		_gravity(delta)
		return
	dir = dir.normalized()
	boss.velocity.x = dir.x * RUN_SPEED
	boss.velocity.z = dir.z * RUN_SPEED
	boss.velocity.y = minf(0.0, boss.velocity.y) - 16.0 * delta
	boss.move_and_slide()
	boss.rotation.y = lerp_angle(boss.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-10.0 * delta))
	boss.pose("lucky_run")
	var moved: float = boss.position.distance_to(_last)
	_last = boss.position
	_stuck = _stuck + delta if moved < RUN_SPEED * delta * .25 else 0.0

func _swipe(delta: float) -> void:
	boss.pose("lucky_swipe")
	_gravity(delta)
	if session.team.has(target): _face(session.team[target].pos, delta, 6.0)
	for k in 2:
		var at: float = [.32, .56][k]
		if _hits_done == k and state_time >= at:
			_hits_done += 1
			var fwd: Vector3 = -boss.global_basis.z
			for id: int in session.team:
				var p: Dictionary = session.team[id]
				if int(p.hp) <= 0: continue
				var to: Vector3 = p.pos - boss.position
				if to.length() > SWIPE_REACH + .2 or absf(to.y) > 1.6: continue
				if Vector3(to.x, 0, to.z).normalized().dot(fwd) < .1: continue
				_hurt_player(id, 18, fwd * 2.5 + Vector3.UP)
			boss.sound(load("res://assets/audio/zombies/claw_hit.ogg"), 2.0)
	if state_time > .9:
		melee_wait = .5
		_go("fight")

func _wind(delta: float) -> void:
	boss.pose("lucky_wind")
	_gravity(delta)
	target = _pick() if not session.team.has(target) else target
	if not session.team.has(target):
		_go("fight")
		return
	_face(session.team[target].pos, delta, 12.0)
	if state_time >= LEAP_WIND:
		var tp: Vector3 = session.team[target].pos
		var land: Vector3 = mission.ground(tp + Vector3.UP * .6)
		_begin_leap(land if land.is_finite() else tp, "land")

func _begin_leap(to: Vector3, after: String) -> void:
	_from = boss.position
	_to = to
	var d := _from.distance_to(_to)
	_dur = clampf(d / 14.0, .45, 1.2)
	_arc = 2.0 + d * .14
	_after_leap = after
	boss.velocity = Vector3.ZERO
	boss.sound(load("res://assets/audio/zombies/scream_%d.ogg" % (1 + randi() % 3)), 2.0)
	_go("leap")

func _leap(_delta: float) -> void:
	boss.pose("lucky_leap")
	var k := clampf(state_time / _dur, 0.0, 1.0)
	var p := _from.lerp(_to, k) + Vector3.UP * (_arc * 4.0 * k * (1.0 - k))
	var dir := _to - _from
	dir.y = 0.0
	if dir.length() > .2: boss.rotation.y = atan2(-dir.x, -dir.z)
	boss.position = p
	if k >= 1.0:
		if _after_leap == "wall":
			_wall_for = randf_range(1.8, 3.2)
			_go("wall")
		else:
			_go("land")
			_impact()

func _impact() -> void:
	for id: int in session.team:
		var p: Dictionary = session.team[id]
		if int(p.hp) <= 0: continue
		var to: Vector3 = p.pos - boss.position
		if to.length() < 2.4 and absf(to.y) < 1.6:
			_hurt_player(id, 30, Vector3(to.x, 0, to.z).normalized() * 4.0 + Vector3.UP * 2.0)
	boss.sound(load("res://assets/audio/zombies/thud_%d.ogg" % (1 + randi() % 3)), 6.0)

func _land(delta: float) -> void:
	boss.pose("lucky_land")
	_gravity(delta)
	if state_time > .55:
		melee_wait = .2
		_go("fight")

## Onto the wall nearest him above the catwalk, at the height of the hall's upper storey.
func _start_wall() -> void:
	var l := _hl(boss.position)
	var best := INF
	var pick: Array = WALLS[0]
	for wspec: Array in WALLS:
		var n: Vector3 = wspec[1]
		var d: float = absf((l.x if absf(n.x) > .5 else l.z) - float(wspec[0]))
		if d < best:
			best = d
			pick = wspec
	_wall_n = pick[1]
	var on := l
	if absf(_wall_n.x) > .5:
		on.x = float(pick[0]) + _wall_n.x * .4
		on.z = clampf(l.z, 14.0, 33.0)
	else:
		on.z = float(pick[0]) + _wall_n.z * .4
		on.x = clampf(l.x, 7.0, 21.0)
	on.y = hosp.CAT_Y + randf_range(1.6, 2.8)
	_wall_dir = 1.0 if randf() < .5 else -1.0
	_begin_leap(_w(on), "wall")

func _wall(delta: float) -> void:
	boss.pose("lucky_spider" if state_time < _wall_for - .5 else "lucky_cling")
	if session.team.has(target):
		# Along the wall toward where his target is below him.
		var tl := _hl(session.team[target].pos)
		var l := _hl(boss.position)
		var along := Vector3(_wall_n.z, 0, -_wall_n.x).abs()
		var want := (tl - l).dot(along)
		var step := clampf(want, -1.0, 1.0) * 2.6 * delta
		var next := l + along * step
		next.x = clampf(next.x, 4.5, 23.5)
		next.z = clampf(next.z, 12.5, 35.5)
		boss.position = _w(next)
	if state_time >= _wall_for:
		target = _pick()
		if session.team.has(target):
			var tp: Vector3 = session.team[target].pos
			var land: Vector3 = mission.ground(tp + Vector3.UP * .6)
			_begin_leap(land if land.is_finite() else tp, "land")
		else:
			_begin_leap(mission.ground(boss.position + _wall_n * 3.0), "land")

func _scream(delta: float) -> void:
	boss.pose("lucky_scream")
	_gravity(delta)
	if state_time < .05:
		boss.sound(load("res://assets/audio/zombies/scream_3.ogg"), 8.0)
		var n := clampi(2 + session.team.size(), 3, 5)
		for i in n:
			var at := Vector3(6.0 + randi_range(0, 6) * 2.6, hosp.F3, 33.0)
			mission.later(func() -> void: hosp._spawn(mission, at, "awake", hosp.POOL_LAB[randi() % hosp.POOL_LAB.size()]))
	if state_time > 2.2: _go("fight")

func _flinch(delta: float) -> void:
	boss.pose("lucky_hit")
	_gravity(delta)
	if state_time > .45: _go("fight")

func _hurt_player(id: int, amount: int, push: Vector3) -> void:
	if not session.team.has(id): return
	if session.harmless or mission.harmless:
		mission.blocked_hits += 1
		return
	var p: Dictionary = session.team[id]
	var hurt_by := mini(amount, int(p.hp))
	p.hp -= hurt_by
	p.hurt += hurt_by
	session.hurt(id, hurt_by)
	if not session.is_bot(id): session.knocked.rpc(id, push)

## Host: a round from `id` landed on him (mission.damage): the head (the open jaw) takes more.
func hurt(id: int, bone: String, dealt: float) -> void:
	if state == "dead" or state == "none": return
	_take(id, dealt * (1.6 if bone == "head" or bone == "neck" else 1.0))

func blast(id: int, amount: float) -> void:
	if state == "dead" or state == "none": return
	_take(id, amount * 1.2)
	if state == "wall": _begin_leap(mission.ground(boss.position + _wall_n * 2.0), "land")

func _take(id: int, amount: float) -> void:
	hp = maxf(0.0, hp - amount)
	boss.hp = maxf(hp, .01)
	if session.team.has(id): session.team[id].hits += 1
	_recent += amount
	_recent_t = 1.2
	if hp <= 0.0:
		_die(id)
		return
	if _recent > 260.0 and state in ["fight", "swipe"]:
		_recent = 0.0
		_go("hit")

func _die(id: int) -> void:
	_go("dead")
	boss.hp = 0.0
	if session.team.has(id): session.team[id].kills += 1
	var at: Vector3 = boss.position
	if at.y > _w(Vector3(0, hosp.F3 + .5, 0)).y + 1.0:
		var g: Vector3 = mission.ground(at)
		if g.is_finite(): at = g
	var fwd: Vector3 = -boss.global_basis.z
	session.fallen.rpc(boss.key, at, KIND, boss.rotation.y, (-fwd + Vector3.UP * .3) * 220.0, "chest")
	mission.threat = 0.0
	print("INTERIOR_COOP_LUCKY dead (by %d)" % id)

func _publish() -> void:
	var b := {"s": state, "hp": hp, "max": max_hp, "t": state_time}
	if state == "wall" or (state == "leap" and _after_leap == "wall"): b.n = _wall_n
	mission.flags.lucky = b

func debug_kill() -> void:
	_ensure_boss()
	if state != "dead" and boss != null and is_instance_valid(boss): _take(_pick(), hp + 1.0)

# ---------------------------------------------------------------- every peer

func render(delta: float) -> void:
	var b: Dictionary = mission.flags.get("lucky", {})
	var s := str(b.get("s", "none"))
	if boss == null or not is_instance_valid(boss):
		boss = null
		for z in mission.enemies.values():
			if is_instance_valid(z) and int(z.get_meta("kind", 0)) == KIND: boss = z
	if boss != null and is_instance_valid(boss) and not boss.dead:
		var n = b.get("n")
		if (s == "wall" or (s == "leap" and n is Vector3 and float(b.get("t", 0.0)) > .3)) and n is Vector3:
			var up: Vector3 = (n as Vector3).normalized()
			var z := Vector3.DOWN
			boss.global_basis = Basis(up.cross(z).normalized(), up, z)
		elif absf(boss.rotation.x) > .001 or absf(boss.rotation.z) > .001:
			var yaw: float = boss.rotation.y
			boss.rotation = Vector3(0, yaw, 0)
		# The tell before a leap: his claws dragged over the floor, sparking.
		if s == "wind" and _seen_state != "wind": _sparks(boss.global_position + Vector3.UP * .1)
		if s == "scream" and _seen_state != "scream": _jolt()
	if s != _seen_state: _seen_state = s
	_hud_render(b, delta)

func _sparks(at: Vector3) -> void:
	if _scrape == null:
		_scrape = GPUParticles3D.new()
		_scrape.amount = 40
		_scrape.lifetime = .5
		_scrape.one_shot = true
		_scrape.explosiveness = .7
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 80.0
		pm.initial_velocity_min = 2.0
		pm.initial_velocity_max = 5.0
		pm.gravity = Vector3(0, -9.8, 0)
		_scrape.process_material = pm
		var quad := QuadMesh.new()
		quad.size = Vector2(.04, .04)
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		sm.emission_enabled = true
		sm.emission = Color(1.0, .8, .45)
		sm.emission_energy_multiplier = 6.0
		quad.material = sm
		_scrape.draw_pass_1 = quad
		add_child(_scrape)
	_scrape.global_position = at
	_scrape.restart()
	_scrape.emitting = true
	var a := AudioStreamPlayer3D.new()
	a.stream = load("res://assets/audio/siege/scrape.ogg")
	a.volume_db = 4.0
	a.unit_size = 8.0
	add_child(a)
	a.global_position = at
	a.play()
	a.finished.connect(a.queue_free)

func _jolt() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or boss == null: return
	if cam.global_position.distance_to(boss.global_position) < 24.0 and session.main.get("player") != null:
		var pl = session.main.player
		if pl.has_method("shake"): pl.shake(.6)

func _hud_render(b: Dictionary, delta: float) -> void:
	var s := str(b.get("s", "none"))
	if s == "none" and _hud == null: return
	if _hud == null: _build_hud()
	_shown = move_toward(_shown, 1.0 if s != "none" and s != "dead" else 0.0, delta * (2.0 if s != "dead" else .25))
	_box.visible = _shown > .01 and not session.local_menu
	_box.modulate.a = _shown
	_vitals.k = clampf(float(b.get("hp", 0.0)) / maxf(float(b.get("max", 1.0)), 1.0), 0.0, 1.0)
	_vitals.dead = s == "dead"

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 6
	add_child(_hud)
	_box = Control.new()
	_box.anchor_left = .5
	_box.anchor_right = .5
	_box.offset_left = -260
	_box.offset_right = 260
	_box.offset_top = 52
	_box.offset_bottom = 136
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_box)
	var title := SleepType.label(NAME, SleepType.serif(true), 29, SleepType.BONE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, .55))
	title.size = Vector2(520, 36)
	_box.add_child(title)
	_vitals = Vitals.new()
	_vitals.position = Vector2(0, 40)
	_vitals.size = Vector2(520, 44)
	_vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_vitals)
	_box.visible = false

## His health as the laboratory's own monitors would show it: a heart trace across a dark screen. The trace runs as
## far as his life does and then lies flat; the less there is, the faster and less regular the beat. Dead, it is flat.
class Vitals extends Control:
	var k := 1.0
	var dead := false
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta * (1.0 + (1.0 - k) * 2.2)
		queue_redraw()

	func _wave(u: float) -> float:
		if u < .1: return 0.0
		if u < .2: return sin((u - .1) / .1 * PI) * .12
		if u < .3: return 0.0
		if u < .33: return -(u - .3) / .03 * .18
		if u < .37: return -.18 + (u - .33) / .04 * 1.18
		if u < .41: return 1.0 - (u - .37) / .04 * 1.38
		if u < .45: return -.38 + (u - .41) / .04 * .38
		if u < .6: return 0.0
		if u < .78: return sin((u - .6) / .18 * PI) * .22
		return 0.0

	func _draw() -> void:
		var w := size.x
		var hh := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color(.02, .05, .04, .62))
		draw_rect(Rect2(Vector2.ZERO, size), Color(.25, .9, .55, .25), false, 1.0)
		for gx in range(0, int(w), 26): draw_line(Vector2(gx, 0), Vector2(gx, hh), Color(.25, .9, .55, .06), 1.0)
		var col := Color(.35, 1.0, .6) if not dead else Color(.6, .7, .65, .8)
		var pts := PackedVector2Array()
		var period := 130.0 * (.55 + .45 * k)
		var end := w * (0.0 if dead else k)
		var x := 0.0
		while x <= w:
			var y := hh * .55
			if x < end:
				var u := fposmod(x + _t * 160.0, period) / period
				var jitter := (1.0 - k) * .25 * sin(x * .31 + _t * 9.0)
				y -= (_wave(u) + jitter * float(u > .3 and u < .45)) * hh * .42
			pts.append(Vector2(x, y))
			x += 3.0
		if pts.size() > 1: draw_polyline(pts, col, 2.0, true)
		if not dead and end > 4.0: draw_circle(Vector2(end, pts[clampi(int(end / 3.0), 0, pts.size() - 1)].y), 3.0, col)
