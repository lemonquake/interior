extends Node3D
## 0.63: the building kit Outer Street is laid down with (scripts/coop/outer_street.gd extends this): roots per part of
## the map, each with its boxes merged by material (InteriorBoxKit), its own static body, its lamps. The same habits as
## PILCST's (school.gd): boxes and cylinders by the hundred into one mesh per material, colliders only where a body
## has to stop, real lights few and faded with distance, the flickering ones (`lamps`) run by `_lamps_tick`.

const HorrorLiquid := preload("res://scripts/horror_liquid.gd")
const SCHOOL_TEX := {"checker": 1.2, "corridor": 1.2, "classroom": 1.2, "ceiling": 1.2, "board": 2.0, "cream": 2.6, "green": 2.0}

var s: Node3D
var rng := RandomNumberGenerator.new()
var roots: Array[Node3D] = []
var bodies: Array[StaticBody3D] = []
var _kits: Array = []
var _mats := {}
## Which roots are under the street (no moon on them: lamp-lit layers only).
var under: Array = []
## The lamps that flicker or wait for power: {l: light or null, e: energy, m: mode, p: phase, g: glow material or
## null, ge: glow energy, gate: flag that must be set (or "!flag": must not be), on: last value}.
var lamps: Array = []
var power := false
var _flags_seen := {}
var _now := 0.0
## 0.67: the root each glow material was made in (`glow_piece`), so a lamp knows its root (`_lamp_root`).
var _glow_root := {}

func world(at: Vector3) -> Vector3: return s.position + at if s != null else at
func local(w: Vector3) -> Vector3: return w - s.position if s != null else w

func make_roots(names: Array) -> void:
	for i in names.size():
		var r := Node3D.new()
		r.name = str(names[i])
		add_child(r)
		roots.append(r)
		_kits.append({})
		var b := StaticBody3D.new()
		b.collision_layer = 2
		b.name = str(names[i]) + " body"
		add_child(b)
		bodies.append(b)

func mat(id: String) -> Material:
	if _mats.has(id): return _mats[id]
	var m: Material
	if id.begins_with("s:"):
		var base := id.trim_prefix("s:")
		var tint := Color.WHITE
		if "|" in base:
			tint = Color(base.get_slice("|", 1))
			base = base.get_slice("|", 0)
		var sm := StandardMaterial3D.new()
		sm.albedo_texture = load("res://assets/school/%s.png" % base)
		sm.albedo_color = tint
		sm.uv1_triplanar = true
		sm.uv1_world_triplanar = true
		sm.uv1_scale = Vector3.ONE / float(SCHOOL_TEX.get(base, 2.0))
		sm.roughness = .6
		sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		m = sm
	else:
		m = s.material(id)
	_mats[id] = m
	return m

## A box in root `r`; `collide` gives it a collider in that root's body.
func bx(r: int, at: Vector3, size: Vector3, id: String, collide := false, basis := Basis.IDENTITY) -> CollisionShape3D:
	if not _kits[r].has(id): _kits[r][id] = InteriorBoxKit.new()
	_kits[r][id].box(size, Transform3D(basis, at))
	if not collide: return null
	return solid(r, at, size, basis)

func solid(r: int, at: Vector3, size: Vector3, basis := Basis.IDENTITY) -> CollisionShape3D:
	var c := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	c.shape = b
	c.transform = Transform3D(basis, at)
	bodies[r].add_child(c)
	return c

## A box between two corners (min, max), with or without a collider.
func span(r: int, lo: Vector3, hi: Vector3, id: String, collide := false) -> CollisionShape3D:
	return bx(r, (lo + hi) * .5, (hi - lo).abs(), id, collide)

func cyl(r: int, at: Vector3, radius: float, h: float, id: String, basis := Basis.IDENTITY, sides := 10) -> void:
	if not _kits[r].has(id): _kits[r][id] = InteriorBoxKit.new()
	_kits[r][id].cylinder(radius, h, sides, Transform3D(basis, at))

func bar(r: int, a: Vector3, b: Vector3, thick: float, id: String) -> void:
	var d := b - a
	if d.length() < .001: return
	var up: Vector3 = Vector3.UP if absf(d.normalized().y) < .98 else Vector3.RIGHT
	bx(r, (a + b) * .5, Vector3(thick, thick, d.length()), id, false, Basis.looking_at(d.normalized(), up))

## A round bar (pipe, rail, pole) from a to b.
func pipe(r: int, a: Vector3, b: Vector3, radius: float, id: String, sides := 8) -> void:
	var d := b - a
	if d.length() < .001: return
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < .9 else Vector3.RIGHT).normalized()
	cyl(r, (a + b) * .5, radius, d.length(), id, Basis(x, y, x.cross(y)), sides)

## A cable sagging between two points (a few straight pieces).
func cable(r: int, a: Vector3, b: Vector3, sag: float, id := "#121212", thick := .025) -> void:
	var n := 6
	var last := a
	for i in range(1, n + 1):
		var t := float(i) / n
		var p := a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
		bar(r, last, p, thick, id)
		last = p

## Stairs from a (bottom or top) to b: drawn steps with nosings, one sloped collider under them (PILCST's `_ramp`).
func stair(r: int, a: Vector3, b: Vector3, width: float, steps: int, id := "concrete_floor_02|#8a867c", nose := "#2b2b28", collide := true) -> void:
	var d := b - a
	var run := Vector2(d.x, d.z).length()
	var dir := Vector3(d.x, 0, d.z).normalized()
	var angle := atan2(d.y, run)
	var yaw := atan2(dir.x, dir.z)
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -angle)
	var mid := (a + b) * .5 - basis.y * .1
	bx(r, mid, Vector3(width, .2, d.length()), id, collide, basis)
	var rise := d.y / steps
	var tread := run / steps
	for i in steps:
		var c := a + dir * (tread * (i + .5)) + Vector3.UP * (rise * (i + .5))
		var step: Vector3 = Vector3(width, absf(rise), tread) if absf(dir.z) > .5 else Vector3(tread, absf(rise), width)
		bx(r, c, step, id)
		var edge := a + dir * (tread * i) + Vector3.UP * (rise * (i + 1)) if rise > 0 else a + dir * (tread * (i + 1)) + Vector3.UP * (rise * (i + 1))
		var strip: Vector3 = Vector3(width, .02, .05) if absf(dir.z) > .5 else Vector3(.05, .02, width)
		if nose != "": bx(r, edge + Vector3.UP * .005, strip, nose)

## A flat sloped walking surface (a ramp) from a to b, `width` across; its top passes through a and b.
func ramp(r: int, a: Vector3, b: Vector3, width: float, id: String, thick := .3) -> void:
	var d := b - a
	var run := Vector2(d.x, d.z).length()
	var dir := Vector3(d.x, 0, d.z).normalized()
	var basis := Basis(Vector3.UP, atan2(dir.x, dir.z)) * Basis(Vector3.RIGHT, -atan2(d.y, run))
	bx(r, (a + b) * .5 - basis.y * thick * .5, Vector3(width, thick, d.length() + .04), id, true, basis)

## A railing from a to b at the height of a: posts, a top rail, two lower rails; its collider `h` tall.
func railing(r: int, a: Vector3, b: Vector3, h := 1.1, id := "#3a3e3c", collide := true, post_every := 1.6) -> void:
	var d := b - a
	var n := maxi(1, ceili(d.length() / post_every))
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		pipe(r, p, p + Vector3.UP * h, .025, id, 6)
	pipe(r, a + Vector3.UP * h, b + Vector3.UP * h, .03, id, 6)
	for f in [.35, .7]: pipe(r, a + Vector3.UP * h * f, b + Vector3.UP * h * f, .015, id, 5)
	if collide:
		var flat := Vector3(d.x, 0, d.z)
		solid(r, (a + b) * .5 + Vector3.UP * (h * .5 + .1), Vector3(.12, h + .2, flat.length()), Basis(Vector3.UP, atan2(flat.x, flat.z)))

func label(r: int, at: Vector3, words: String, height: float, yaw: float, color := Color(.92, .9, .84), glow := false, reach := 30.0) -> Label3D:
	var l := Label3D.new()
	l.text = words
	l.pixel_size = height / 64
	l.font_size = 64
	l.outline_size = 3 if glow else 0
	l.modulate = color
	l.shaded = not glow
	l.double_sided = false
	l.rotation.y = yaw
	l.position = at
	l.visibility_range_end = reach
	roots[r].add_child(l)
	return l

func omni(r: int, at: Vector3, color: Color, energy: float, reach: float, shadows := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = at
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	l.omni_attenuation = 1.3
	l.shadow_enabled = shadows
	l.distance_fade_enabled = true
	l.distance_fade_begin = 38.0
	l.distance_fade_length = 12.0
	l.light_specular = .3
	roots[r].add_child(l)
	return l

func spot(r: int, at: Vector3, aim: Vector3, color: Color, energy: float, reach: float, angle: float, shadows := false) -> SpotLight3D:
	var l := SpotLight3D.new()
	l.transform = Transform3D(Basis.looking_at((aim - at).normalized(), Vector3.UP if absf((aim - at).normalized().y) < .98 else Vector3.FORWARD), at)
	l.light_color = color
	l.light_energy = energy
	l.spot_range = reach
	l.spot_angle = angle
	l.spot_attenuation = 1.1
	l.shadow_enabled = shadows
	l.distance_fade_enabled = true
	l.distance_fade_begin = 46.0
	l.distance_fade_length = 14.0
	roots[r].add_child(l)
	return l

## A glowing piece (tube, lens, screen) with a material of its own, so it can flicker on its own.
func glow_piece(r: int, at: Vector3, size: Vector3, color: Color, energy: float, basis := Basis.IDENTITY) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color.darkened(.3)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.transform = Transform3D(basis, at)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 120.0
	roots[r].add_child(mi)
	_glow_root[m] = r
	return m

## A light fixture: its glowing tube and its light, registered to flicker (`mode`: 0 steady, 1 slow breathe,
## 2 failing tube, 3 dying, 4 strobing, 5 blink, 6 static) and, with `gate`, only lit while that flag is (or, "!flag",
## is not) set. `light` false: the tube glows with no light of its own.
func lamp(r: int, at: Vector3, color: Color, energy: float, reach: float, mode: int, tube := Vector3(1.2, .05, .1), gate := "", light := true, shadows := false, glow := 2.6) -> Dictionary:
	var g: StandardMaterial3D = glow_piece(r, at, tube, color, glow) if tube != Vector3.ZERO else null
	var l: Light3D = omni(r, at + Vector3.DOWN * .2, color, energy, reach, shadows) if light else null
	var d := {"l": l, "e": energy, "m": mode, "p": rng.randf() * 10.0, "g": g, "ge": glow, "gate": gate, "on": -1.0}
	lamps.append(d)
	return d

func lamp_light(l: Light3D, energy: float, mode: int, gate := "", g: StandardMaterial3D = null, glow := 2.6) -> Dictionary:
	var d := {"l": l, "e": energy, "m": mode, "p": rng.randf() * 10.0, "g": g, "ge": glow, "gate": gate, "on": -1.0}
	lamps.append(d)
	return d

func _lamps_tick(flags: Dictionary) -> void:
	_now = Time.get_ticks_msec() * .001
	var now := _now
	for d: Dictionary in lamps:
		# (0.67: a lamp in a root the viewpoint has hidden (`_view`) or that was put away is not worked out: its light
		# and glow are not drawn. Its root is found once.)
		var ri: int = d.get("r", -2)
		if ri == -2:
			ri = _lamp_root(d)
			d["r"] = ri
		if ri >= 0 and not roots[ri].visible: continue
		var l: Light3D = d.l
		var g: StandardMaterial3D = d.g
		if l != null and not is_instance_valid(l): continue
		if l != null and not l.is_inside_tree(): continue
		var lit := true
		var gate: String = d.gate
		if gate != "":
			if gate.begins_with("!"): lit = not bool(flags.get(gate.trim_prefix("!"), false))
			else: lit = bool(flags.get(gate, false))
		var ph: float = d.p
		var on := 0.0
		if lit:
			match int(d.m):
				0: on = 1.0
				1: on = .85 + .15 * sin(now * 1.3 + ph)
				2:
					var cycle := fmod(now * (.17 + fmod(ph, 1.0) * .06) + ph * 7.0, 1.0)
					if cycle < .18: on = 1.0 if sin(now * (37.0 + ph * 3.0)) > .05 else .04
					else: on = .9 + .1 * sin(now * 2.1 + ph)
				3:
					var cycle := fmod(now * (.21 + fmod(ph, 1.0) * .05) + ph * 3.0, 1.0)
					on = (.8 if sin(now * 43.0 + ph) > -.3 else 0.0) if cycle < .14 else .02
				4: on = 1.0 if sin(now * 23.0 + ph) * sin(now * 5.3 + ph * 2.0) > -.15 else .03
				5: on = 1.0 if fmod(now + ph, 1.1) < .55 else 0.0
				6: on = .55 + .45 * sin(now * 31.0 + ph) * sin(now * 7.3 + ph * 2.0)
		if absf(on - float(d.on)) < .01: continue
		d.on = on
		if l != null:
			l.light_energy = float(d.e) * on
			l.visible = on > .005
		if g != null: g.emission_energy_multiplier = float(d.ge) * maxf(on, .015)
		if d.has("lbl"):
			var lb: Label3D = d.lbl
			if is_instance_valid(lb): lb.modulate = Color(d.col as Color, maxf(on, .12))

## The root a lamp belongs to: its light's or label's ancestor among `roots`, else its glow material's; -1 unknown.
func _lamp_root(d: Dictionary) -> int:
	var n: Node = null
	if d.l != null: n = d.l
	elif d.has("lbl"): n = d.lbl
	if n != null and is_instance_valid(n):
		while n != null and n != self:
			var i := roots.find(n)
			if i >= 0: return i
			n = n.get_parent()
	if d.g != null and _glow_root.has(d.g): return int(_glow_root[d.g])
	return -1

## A model from assets/models (`path` like "street/jeepney"), its meshes drawn out to `reach`.
func place(r: int, path: String, at: Vector3, yaw_deg := 0.0, scale := 1.0, tilt := Vector3.ZERO, reach := 90.0) -> Node3D:
	var n: Node3D = InteriorModelKit.place(roots[r], path, at, yaw_deg, scale, "bottom", tilt)
	if n != null:
		for g in n.find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).visibility_range_end = reach
	return n

## 0.65: the vehicle models (tools/blender/vehicles/build_vehicles.py) carry material slot NAMES only; a palette binds
## each name to a material id: "paint:#rrggbb" glossy paint, "metal:#rrggbb" bare metal, "burnt" charred, else any id
## `mat` knows. `palette` overrides `base` slot by slot.
const BUS_PAINT := {"paint": "paint:#e2ded2", "paint2": "paint:#1d7470", "glass": "glass#24303ab0", "dark": "#141414",
	"rubber": "#0e0e0e", "trim": "#3a3c3c", "chrome": "metal:#b8bcbc", "rim": "metal:#7a7e7e", "interior": "#c8c4b6",
	"seat": "fabric_pattern_07|#6a88c0", "floor": "#2c2e2c", "lamp_front": "#d8d4c0", "lamp_rear": "#7a1a14",
	"lamp_amber": "#b8701a", "yellow": "#d8aa16", "strap": "#d8d4c8", "crack": "#d8dcd8", "metal": "metal:#9aa0a0",
	"rust": "rusty_metal_02|#7e7c78"}
const METRO_PAINT := {"paint": "metal:#a6aaa8", "paint2": "paint:#2a7a86", "interior": "#c6c9c5", "floor": "#3a3c3a",
	"seat": "fabric_pattern_07|#7a8aa8", "metal": "metal:#9a9e9c", "glass": "glass#1e262cb0"}
const BURNT := {"paint": "burnt", "paint2": "burnt", "glass": "glass#0a0a0a38", "seat": "#1a1614", "interior": "#2a2622",
	"floor": "#1a1816", "trim": "#161616", "chrome": "#2a2826", "rim": "rusty_metal_03|#6a4a3a", "lamp_front": "#2a2a26",
	"lamp_rear": "#2a1a16", "lamp_amber": "#2a2016", "metal": "burnt", "rubber": "#080808", "strap": "#2a2622",
	"yellow": "#3a3020", "dark": "#0c0c0c"}
const CAR_COLOURS := ["#d8d6d0", "#9a9ea2", "#6a1a1a", "#1e2a44", "#141414", "#b8a888", "#2a4a3a", "#8a8e92"]

func vmat(id: String) -> Material:
	if _mats.has("v:" + id): return _mats["v:" + id]
	var m: Material
	if id.begins_with("paint:") or id.begins_with("metal:"):
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(id.substr(6))
		sm.roughness = .4 if id.begins_with("paint:") else .32
		sm.metallic = .2 if id.begins_with("paint:") else .8
		m = sm
	elif id == "burnt":
		var sm := StandardMaterial3D.new()
		sm.albedo_texture = load("res://assets/outdoor/textures/rusty_metal_03/albedo.jpg")
		sm.albedo_color = Color("#4a3a32")
		sm.uv1_triplanar = true
		sm.uv1_world_triplanar = true
		sm.uv1_scale = Vector3.ONE * .7
		sm.roughness = .95
		m = sm
	else:
		m = mat(id)
	_mats["v:" + id] = m
	return m

## A vehicle model in root `r` at `xf` (its own frame: see build_vehicles.py), its slots bound through the palettes.
func vehicle(r: int, model: String, xf: Transform3D, palette := {}, reach := 140.0, base := BUS_PAINT) -> Node3D:
	var n := InteriorModelKit.scene("res://assets/models/vehicles/%s.glb" % model).instantiate() as Node3D
	n.name = model
	n.transform = xf
	roots[r].add_child(n)
	for g in n.find_children("*", "MeshInstance3D", true, false):
		var mi := g as MeshInstance3D
		mi.visibility_range_end = reach
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var key := src.resource_name if src != null else ""
			var id: String = palette.get(key, base.get(key, ""))
			if id != "": mi.set_surface_override_material(i, vmat(id))
	return n

## A road vehicle (sedan, van, pickup, truck ...) standing on the ground at `at`, nose toward `yaw` (radians, 0 = +z),
## tilted by `tilt` (x pitch, z roll); `burnt` chars it; its collider a box round it. `size` its box (w, h, l).
const CAR_BOX := {"sedan": Vector3(1.8, 1.45, 4.6), "sedan_wreck": Vector3(1.8, 1.45, 4.6), "taxi_wreck": Vector3(1.8, 1.45, 4.6),
	"van": Vector3(1.75, 1.95, 4.7), "van_wreck": Vector3(1.75, 1.95, 4.7), "pickup_wreck": Vector3(1.85, 1.8, 5.3),
	"truck": Vector3(2.35, 3.3, 7.5), "truck_wreck": Vector3(2.35, 3.3, 7.5)}
func road_car(r: int, model: String, at: Vector3, yaw: float, burnt := false, colour := "", tilt := Vector3.ZERO, collide := true) -> Node3D:
	var basis := Basis(Vector3.UP, yaw) * Basis.from_euler(tilt)
	var pal := {}
	if burnt: pal = BURNT.duplicate()
	else:
		pal["paint"] = "paint:" + (colour if colour != "" else CAR_COLOURS[rng.randi() % CAR_COLOURS.size()])
		if model == "taxi_wreck": pal["paint"] = "paint:#e8e6e0"
		pal["paint2"] = "paint:#2a6ab0" if model == "taxi_wreck" else "paint:#7a2a24"
		if model.begins_with("truck"): pal["metal"] = "metal:#b8bcbc"
	var n := vehicle(r, model, Transform3D(basis, at), pal, 160.0)
	if collide:
		var sz: Vector3 = CAR_BOX.get(model, Vector3(1.8, 1.5, 4.6))
		solid(r, at + basis * Vector3(0, sz.y * .5, 0), sz, basis)
	return n

func stain(r: int, kind: String, at: Vector3, yaw: float, length: float, width: float, alpha := .92) -> void:
	var t: Array = HorrorLiquid.texture_set(kind)
	var generated: bool = not t.is_empty()
	if not generated:
		var root := "res://assets/siege/"
		if not ResourceLoader.exists(root + kind + "_albedo.png"): return
		t = [load(root + kind + "_albedo.png"), load(root + kind + "_normal.png"), load(root + kind + "_orm.png")]
	var d := Decal.new()
	d.size = Vector3(length, .4, width)
	d.texture_albedo = t[0]
	d.texture_normal = t[1]
	d.texture_orm = t[2]
	d.modulate = Color(1, 1, 1, alpha)
	d.cull_mask = 8
	d.normal_fade = .35
	d.upper_fade = .2
	d.lower_fade = .2
	d.distance_fade_enabled = true
	d.distance_fade_begin = 26.0
	d.distance_fade_length = 6.0
	roots[r].add_child(d)
	d.position = at + Vector3.UP * .06
	d.rotation.y = yaw
	HorrorLiquid.finish(d, generated)

## Blood on a wall: `normal` points out of the wall.
func smear(r: int, kind: String, at: Vector3, normal: Vector3, length: float, width: float, alpha := .85) -> void:
	var t: Array = HorrorLiquid.texture_set(kind)
	var generated: bool = not t.is_empty()
	if not generated:
		var root := "res://assets/siege/"
		if not ResourceLoader.exists(root + kind + "_albedo.png"): return
		t = [load(root + kind + "_albedo.png"), load(root + kind + "_normal.png"), load(root + kind + "_orm.png")]
	var d := Decal.new()
	d.texture_albedo = t[0]
	d.texture_normal = t[1]
	d.texture_orm = t[2]
	d.modulate = Color(1, 1, 1, alpha)
	d.size = Vector3(length, .3, width)
	d.cull_mask = 8
	d.normal_fade = .4
	d.distance_fade_enabled = true
	d.distance_fade_begin = 24.0
	d.distance_fade_length = 6.0
	roots[r].add_child(d)
	var up := normal.normalized()
	var side := up.cross(Vector3.UP if absf(up.y) < .95 else Vector3.RIGHT).normalized()
	d.transform = Transform3D(Basis(up, rng.randf_range(-.4, .4)) * Basis(side, up, side.cross(up)), at)
	HorrorLiquid.finish(d, generated)

func drag(r: int, a: Vector3, b: Vector3, pool := true) -> void:
	if pool: stain(r, "pool_big", a, rng.randf() * TAU, 1.5, 1.2)
	var d := b - a
	var n := maxi(1, ceili(Vector2(d.x, d.z).length() / 1.3))
	for i in n:
		var at := a.lerp(b, (i + .5) / n)
		stain(r, ["drag_body_a", "drag_body_b", "drag_a"][i % 3], at, atan2(d.x, d.z) - PI * .5 + rng.randf_range(-.15, .15), 1.5, .6)

func hum(r: int, at: Vector3, path: String, volume: float, unit: float) -> AudioStreamPlayer3D:
	if not ResourceLoader.exists(path): return null
	var a := AudioStreamPlayer3D.new()
	var st: AudioStream = load(path)
	if st is AudioStreamOggVorbis:
		st = (st as AudioStreamOggVorbis).duplicate()
		(st as AudioStreamOggVorbis).loop = true
	a.stream = st
	a.volume_db = volume
	a.unit_size = unit
	a.max_distance = unit * 5.0
	a.autoplay = true
	a.position = at
	roots[r].add_child(a)
	return a

## A one-off sound where something happened (every peer).
func sound(at: Vector3, path: String, volume := 0.0, unit := 12.0) -> void:
	if not ResourceLoader.exists(path): return
	var a := AudioStreamPlayer3D.new()
	a.stream = load(path)
	a.volume_db = volume
	a.unit_size = unit
	a.max_distance = unit * 8.0
	a.position = at
	add_child(a)
	a.play()
	a.finished.connect(a.queue_free)

## Paper, trash, leaves scattered flat (no colliders), `n` pieces round `c` in `spread` (x, z).
func litter(r: int, c: Vector3, spread: Vector2, n: int, kinds := ["#d8d4c4", "#b8b0a0", "#6a6458", "#e8e4d8", "#3a5a8a", "#8a3a2a"]) -> void:
	for i in n:
		var at := c + Vector3(rng.randf_range(-spread.x, spread.x), .012, rng.randf_range(-spread.y, spread.y))
		bx(r, at, Vector3(rng.randf_range(.08, .32), .01, rng.randf_range(.06, .24)), kinds[rng.randi() % kinds.size()], false, Basis(Vector3.UP, rng.randf() * TAU))

## Rubble: concrete chunks heaped round `c` (no colliders: whatever stops a body there is laid down on its own).
func rubble(r: int, c: Vector3, spread: Vector3, n: int, id := "concrete_wall_008|#9a9282") -> void:
	for i in n:
		var u := Vector3(rng.randf_range(-1, 1), rng.randf(), rng.randf_range(-1, 1))
		var at := c + Vector3(u.x * spread.x, u.y * spread.y * (1.0 - absf(u.x) * .6), u.z * spread.z)
		var sz := Vector3(rng.randf_range(.2, .9), rng.randf_range(.15, .6), rng.randf_range(.2, .8))
		bx(r, at, sz, id, false, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-.5, .5)))

## Rebar sticking out of a broken concrete edge.
func rebar(r: int, c: Vector3, along: Vector3, n: int, out: Vector3) -> void:
	for i in n:
		var a := c + along * rng.randf_range(-1, 1)
		bar(r, a, a + out * rng.randf_range(.3, 1.2) + Vector3(rng.randf_range(-.3, .3), rng.randf_range(-.4, .2), rng.randf_range(-.3, .3)), .025, "#4a3a2c")

func smoke(r: int, at: Vector3, amount := 30, scale_k := 1.0, dark := true) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.position = at
	p.amount = amount
	p.lifetime = 8.0
	p.preprocess = 5.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(.1, 1, .2)
	pm.spread = 16.0
	pm.initial_velocity_min = .6
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(.1, .3, .1)
	pm.scale_min = 1.2 * scale_k
	pm.scale_max = 3.0 * scale_k
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = .7
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, .15, 1.0])
	var c := Color(.08, .075, .07) if dark else Color(.32, .31, .3)
	fade.colors = PackedColorArray([Color(c, 0.0), Color(c, .45), Color(c, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = fade
	pm.color_ramp = gt
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(2.4, 2.4)
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.vertex_color_use_as_albedo = true
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.albedo_texture = _soft_dot()
	quad.material = sm
	p.draw_pass_1 = quad
	p.visibility_aabb = AABB(Vector3(-8, -1, -8), Vector3(16, 34, 20))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	roots[r].add_child(p)
	return p

## A fire: flames (glowing blobs that breathe), its light (flickering), its smoke.
func fire(r: int, at: Vector3, size := 1.0, light_reach := 11.0) -> void:
	for i in 3:
		var g := glow_piece(r, at + Vector3(rng.randf_range(-.3, .3) * size, .25 * size + i * .12 * size, rng.randf_range(-.3, .3) * size), Vector3(.5, .7, .5) * size * (1.0 - i * .2), Color(1.0, .45 + i * .1, .15), 4.0, Basis(Vector3.UP, rng.randf() * TAU))
		lamps.append({"l": null, "e": 0.0, "m": 6, "p": rng.randf() * 10.0, "g": g, "ge": 4.0, "gate": "", "on": -1.0})
	var l := omni(r, at + Vector3.UP * (.8 * size), Color(1.0, .55, .25), 2.4 * size, light_reach)
	l.distance_fade_begin = 70.0
	lamps.append({"l": l, "e": 2.4 * size, "m": 6, "p": rng.randf() * 10.0, "g": null, "ge": 0.0, "gate": "", "on": -1.0})
	smoke(r, at + Vector3.UP * size, int(26 * size), size)

var _dot: ImageTexture
func _soft_dot() -> ImageTexture:
	if _dot != null: return _dot
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) * clampf(1.0 - d, 0.0, 1.0)))
	_dot = ImageTexture.create_from_image(img)
	return _dot

## The kits made into meshes, one per material per root; the moon (render layer 2) only on the roots above ground.
func commit(reach_up := 300.0, reach_down := 140.0, far_roots: Array = [], far := 1800.0) -> void:
	for i in _kits.size():
		var down := i in under
		var reach: float = reach_down if down else (far if i in far_roots else reach_up)
		# (0.65: materials alike but for their colour share one mesh: InteriorColourBatch.)
		var dress := func(mesh: MeshInstance3D, id: String) -> void:
			mesh.layers = (1 | 8) if down else (1 | 2 | 8)
			mesh.visibility_range_end = reach
			if id.begins_with("glass") or id.begins_with("glow") or id.begins_with("#12") or id == "puddle":
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		InteriorColourBatch.commit_kits(roots[i], _kits[i], mat, dress)
		if not down:
			for g in roots[i].find_children("*", "GeometryInstance3D", true, false):
				(g as GeometryInstance3D).layers |= 2
	_kits.clear()
