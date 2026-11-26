extends "res://scripts/coop/outer_kit.gd"
## 0.68: the hospital past the long bridge, laid down once on every peer at the bridge's chapter board (scripts/coop/
## hospital.gd runs the night in it). Owner's brief (2026-11-26): ambulances outside, mayhem, every way blocked but the
## hospital's entrance; inside, pathways blocked, the stairs to the second floor; Doctor Berido hidden somewhere on it;
## the cafeteria's ladder into the vents, a hidden entrance and stairs to the third floor; a peaceful third floor; the
## electric door to the secret laboratory. Styling from work/Reference/Davao Central Laboratory: white block walls
## over a greige wainscot, royal blue soffit beams and door frames, white terrazzo with blue sweeps and a ring, a blue
## ring in the lobby's ceiling, blue lockers; the laboratory white panels, light strips, hex ceiling lights, glowing
## tanks, a yellow-railed catwalk; the wards a black clinic of curtains, ducts and gurneys. All of it dead, flickering
## and sparking.
##
## Hospital-local metres (`h(x, y, z)` puts them in street-local): +z into the building (its front at z 0), +x east,
## floors at F1 0, F2 4.2, F3 8.4; the main roof 12.6; the laboratory (x 4..24, z 12..36) two storeys from 8.4 to 16.

const HO := Vector3(60.0, 0.0, 1300.0)
const F1 := 0.0
const F2 := 4.2
const F3 := 8.4
const ROOF := 12.6
const LAB_ROOF := 16.2
const C1 := 3.5
const C2 := 6.9
const C3 := 11.6
const LOBBY_TOP := 8.1
const CAT_Y := 12.0

const R_OUT := 0
const R_F1 := 1
const R_F2 := 2
const R_F3 := 3
const R_LAB := 4
const R_SKY := 5
const R_LOBBY := 6
const HROOTS := ["Hospital street", "Hospital ground floor", "Hospital second floor", "Hospital third floor", "The laboratory", "Hospital skyline", "Hospital lobby"]

## Materials.
const WALL := "concrete_block_wall|#e2e5ea"
const WAIN := "concrete_block_wall|#a3947f"
const BLUE := "#1d4ea8"
const BLUE_D := "#163c80"
const TERR := "h:terrazzo"
const LABT := "h:lab_tile"
const HAZ := "h:hazard"
const CEIL := "ceiling_interior|#dcdcd6"
const PANEL := "#e6eaee"
const STEEL := "#8c9298"
const DARK := "#16181b"
const GRATE := "#3a3e42"
const YELLOW := "#d6b21c"
const CURTAIN := "fabric_pattern_07|#4f7a6a"
const SHEET := "#d8d6cc"
const ASPHALT := "asphalt_02"
const PAVE := "concrete_pavement"
const COLD := Color(.82, .9, 1.0)
const TEAL := Color(.25, .95, .9)
const RED_L := Color(1.0, .12, .08)
const BLUE_L := Color(.2, .35, 1.0)

## Places the night uses (hospital-local).
const SPAWN := Vector3(0.0, 0.0, -15.0)
const NPC_AT := [Vector3(-7.4, 0, -9.6), Vector3(-5.6, 0, -10.6), Vector3(-9.2, 0, -11.0), Vector3(5.6, 0, -9.2), Vector3(7.4, 0, -10.4), Vector3(-1.4, 0, -12.6), Vector3(1.6, 0, -12.2)]
const DOOR := Vector3(0.0, 0.0, 0.0)
const STAIR_DOOR2 := Vector3(-16.0, F2, 23.3)
const BERIDO_AT := Vector3(22.6, F2, 34.6)
const CRAWL_HOLE := Vector3(15.0, F2, 32.7)
const LADDER_FOOT := Vector3(-22.5, F2, 20.55)
const DUCT_Y := 6.95
const DUCT_TOP := 8.05
const DUCT_X := -22.5
const DUCT_Z := 31.0
const DROP := Vector3(-7.0, F2, 31.0)
const BOOKCASE := Vector3(-10.1, F2, 33.2)
const HIDDEN_FOOT := Vector3(-10.0, F2, 34.75)
const HIDDEN_TOP := Vector3(-3.2, F3, 34.75)
const BIG_DOOR := Vector3(4.0, F3, 24.0)
const BERIDO_DOOR := Vector3(2.4, F3, 24.0)
const ROOF_LADDER := Vector3(14.0, CAT_Y, 35.4)
const FLARE := Vector3(14.0, LAB_ROOF, 24.0)
const POD_LUCKY := Vector3(14.0, F3, 34.4)
## The five things the laboratory's door needs (flag suffix, what it is called, where it lies).
const ITEMS := [["keycard", "keycard", Vector3(-21.6, F3 + .02, 23.6)], ["logbook", "logbook", Vector3(-15.2, F3 + .78, 33.6)],
	["override", "override key", Vector3(-22.8, F3 + 1.02, 13.6)], ["fuse", "fuse", Vector3(-12.6, F3 + 1.0, 21.2)],
	["battery", "battery pack", Vector3(-4.6, F3 + .02, 13.8)]]

var big_door_n: Node3D
var big_door_s: Node3D
var door_light: StandardMaterial3D
var bookcase: Node3D
var shutter: Node3D
var shutter_shape: CollisionShape3D
var fire_door: Node3D
var item_nodes := {}
var tanks: Array = []
var brains: Array = []
var lucky_pod_glass: Node3D
var sparks_at: Array = []
var _hmats := {}

func h(x: float, y: float, z: float) -> Vector3: return HO + Vector3(x, y, z)
func hv(v: Vector3) -> Vector3: return HO + v

func mat(id: String) -> Material:
	if not id.begins_with("h:"): return super.mat(id)
	if _hmats.has(id): return _hmats[id]
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = load("res://assets/hospital/%s.png" % id.trim_prefix("h:"))
	sm.uv1_triplanar = true
	sm.uv1_world_triplanar = true
	sm.uv1_scale = Vector3.ONE / (3.2 if id == "h:terrazzo" else (2.4 if id == "h:lab_tile" else 1.0))
	sm.roughness = .18 if id != "h:hazard" else .6
	sm.metallic_specular = .7
	sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_hmats[id] = sm
	return sm

# ---------------------------------------------------------------- pieces

## A floor slab, top at y.
func slab(r: int, x0: float, x1: float, z0: float, z1: float, y: float, id: String, thick := .3) -> void:
	span(r, h(x0, y - thick, z0), h(x1, y, z1), id, true)

## A wall along z at x (or along x at z), y0 up h, with openings [centre, width, height] (from y0).
func wall_z(r: int, x: float, z0: float, z1: float, y0: float, hh: float, id: String, gaps: Array = [], wain := true, t := .2) -> void:
	var cuts: Array = gaps.duplicate()
	cuts.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var z := z0
	for g: Array in cuts:
		var a := float(g[0]) - float(g[1]) * .5
		var b := float(g[0]) + float(g[1]) * .5
		if a > z: _wseg(r, true, x, z, a, y0, hh, id, wain, t)
		var gh := float(g[2])
		if gh < hh: span(r, h(x - t * .5, y0 + gh, a), h(x + t * .5, y0 + hh, b), id, true)
		bx(r, h(x, y0 + gh + .05, (a + b) * .5), Vector3(t + .06, .1, b - a + .12), BLUE)
		for e in [a, b]: bx(r, h(x, y0 + gh * .5, e), Vector3(t + .06, gh, .1), BLUE)
		z = b
	if z < z1: _wseg(r, true, x, z, z1, y0, hh, id, wain, t)

func wall_x(r: int, z: float, x0: float, x1: float, y0: float, hh: float, id: String, gaps: Array = [], wain := true, t := .2) -> void:
	var cuts: Array = gaps.duplicate()
	cuts.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var x := x0
	for g: Array in cuts:
		var a := float(g[0]) - float(g[1]) * .5
		var b := float(g[0]) + float(g[1]) * .5
		if a > x: _wseg(r, false, z, x, a, y0, hh, id, wain, t)
		var gh := float(g[2])
		if gh < hh: span(r, h(a, y0 + gh, z - t * .5), h(b, y0 + hh, z + t * .5), id, true)
		bx(r, h((a + b) * .5, y0 + gh + .05, z), Vector3(b - a + .12, .1, t + .06), BLUE)
		for e in [a, b]: bx(r, h(e, y0 + gh * .5, z), Vector3(.1, gh, t + .06), BLUE)
		x = b
	if x < x1: _wseg(r, false, z, x, x1, y0, hh, id, wain, t)

func _wseg(r: int, along_z: bool, at: float, a: float, b: float, y0: float, hh: float, id: String, wain: bool, t: float) -> void:
	if b - a < .02: return
	if along_z:
		span(r, h(at - t * .5, y0, a), h(at + t * .5, y0 + hh, b), id, true)
		if wain and id == WALL:
			bx(r, h(at, y0 + .55, (a + b) * .5), Vector3(t + .03, 1.1, b - a), WAIN)
			bx(r, h(at, y0 + 1.12, (a + b) * .5), Vector3(t + .05, .05, b - a), BLUE)
	else:
		span(r, h(a, y0, at - t * .5), h(b, y0 + hh, at + t * .5), id, true)
		if wain and id == WALL:
			bx(r, h((a + b) * .5, y0 + .55, at), Vector3(b - a, 1.1, t + .03), WAIN)
			bx(r, h((a + b) * .5, y0 + 1.12, at), Vector3(b - a, .05, t + .05), BLUE)

## A dropped ceiling of tiles with its grid; `holes` are [x0, x1, z0, z1] left open (fallen tiles hang there).
func ceiling(r: int, x0: float, x1: float, z0: float, z1: float, y: float, id := CEIL, holes: Array = []) -> void:
	var step := 2.4
	var x := x0
	while x < x1 - .01:
		var xe := minf(x + step, x1)
		var z := z0
		while z < z1 - .01:
			var ze := minf(z + step, z1)
			var open := false
			for hl: Array in holes:
				if x < float(hl[1]) and xe > float(hl[0]) and z < float(hl[3]) and ze > float(hl[2]): open = true
			if not open:
				bx(r, h((x + xe) * .5, y + .02, (z + ze) * .5), Vector3(xe - x, .04, ze - z), id)
			elif rng.randf() < .6:
				var tip := Basis(Vector3.RIGHT, rng.randf_range(.5, 1.2)) * Basis(Vector3.FORWARD, rng.randf_range(-.4, .4))
				bx(r, h((x + xe) * .5, y - .5, (z + ze) * .5), Vector3(.6, .02, .6), id, false, tip)
				cable(r, h((x + xe) * .5, y, (z + ze) * .5), h((x + xe) * .5 + rng.randf_range(-.5, .5), y - rng.randf_range(1.0, 2.2), (z + ze) * .5), .1, "#141414", .02)
			z = ze
		x = xe

## A ceiling light panel: some still light the room (failing), most are dead or dying.
func tube(r: int, at: Vector3, mode: int, light := false, reach := 7.0, energy := 1.1, color := COLD) -> void:
	if mode < 0:
		bx(r, at, Vector3(1.2, .05, .3), "#8a8e90")
		return
	lamp(r, at, color, energy, reach, mode, Vector3(1.2, .05, .3), "", light, false, 2.2)

## Sparks out of a broken panel or a torn cable: a spray of hot points, a blue-white flash, the arc's buzz.
func sparks(r: int, at: Vector3, sound_on := true) -> void:
	var p := GPUParticles3D.new()
	p.position = at
	p.amount = 28
	p.lifetime = .7
	p.explosiveness = .85
	p.randomness = .6
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 70.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 4.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = .5
	pm.scale_max = 1.0
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(.035, .035)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.albedo_color = Color(1.0, .86, .55)
	sm.emission_enabled = true
	sm.emission = Color(1.0, .8, .45)
	sm.emission_energy_multiplier = 6.0
	quad.material = sm
	p.draw_pass_1 = quad
	p.visibility_aabb = AABB(Vector3(-2, -4, -2), Vector3(4, 5, 4))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	roots[r].add_child(p)
	var l := omni(r, at, Color(.7, .82, 1.0), 2.2, 4.5)
	l.distance_fade_begin = 24.0
	lamps.append({"l": l, "e": 2.2, "m": 4, "p": rng.randf() * 10.0, "g": null, "ge": 0.0, "gate": "", "on": -1.0})
	sparks_at.append([r, at, p])
	if sound_on: hum(r, at, "res://assets/audio/nichols/arc_buzz.ogg", -14.0, 3.0)

func bed(r: int, at: Vector3, yaw: float, blood := true, tipped := false) -> void:
	var b := Basis(Vector3.UP, yaw)
	if tipped: b = b * Basis(Vector3.FORWARD, 1.45)
	var up := b.y
	bx(r, at + up * .42, Vector3(.95, .08, 2.05), STEEL, false, b)
	bx(r, at + up * .52, Vector3(.88, .14, 1.95), SHEET if not blood else "#9a8a80", false, b)
	bx(r, at + b * Vector3(0, .75, -.98), Vector3(.95, .55, .05), STEEL, false, b)
	for sx in [-.42, .42]:
		for sz in [-.9, .9]: bx(r, at + b * Vector3(sx, .2, sz), Vector3(.05, .4, .05), STEEL, false, b)
		bx(r, at + b * Vector3(sx, .7, .2), Vector3(.03, .2, 1.2), STEEL, false, b)
	solid(r, at + up * .45, Vector3(.95, .9, 2.05), b)
	if blood and not tipped: stain(r, "pool_big", at + up * .6, yaw, 1.0, .7, .8)

func gurney(r: int, at: Vector3, yaw: float, tipped := false) -> void:
	var b := Basis(Vector3.UP, yaw)
	if tipped: b = b * Basis(Vector3.FORWARD, 1.5)
	bx(r, at + b * Vector3(0, .8, 0), Vector3(.62, .06, 1.9), STEEL, false, b)
	bx(r, at + b * Vector3(0, .86, 0), Vector3(.58, .06, 1.8), "#8a7a72", false, b)
	for sz in [-.8, .8]: bx(r, at + b * Vector3(0, .4, sz), Vector3(.5, .8, .04), STEEL, false, b)
	solid(r, at + b * Vector3(0, .45, 0), Vector3(.62, .9, 1.9), b)

func curtain(r: int, a: Vector3, b: Vector3, top: float, open := .0) -> void:
	bar(r, Vector3(a.x, top, a.z), Vector3(b.x, top, b.z), .03, STEEL)
	var d := b - a
	var n := maxi(1, int(d.length() / .45))
	var shut := 1.0 - open
	for i in int(n * shut):
		var t := (i + .5) / n
		var c := a.lerp(b, t)
		var yaw := atan2(d.x, d.z) + (.25 if i % 2 == 0 else -.25)
		bx(r, Vector3(c.x, top - 1.05, c.z), Vector3(.02, 2.0, .5), CURTAIN, false, Basis(Vector3.UP, yaw))

func iv_pole(r: int, at: Vector3) -> void:
	pipe(r, at, at + Vector3.UP * 1.9, .012, STEEL, 5)
	bx(r, at + Vector3.UP * .03, Vector3(.5, .04, .5), STEEL)
	bx(r, at + Vector3(.1, 1.75, 0), Vector3(.1, .2, .04), "glass#c8d0d080")

func monitor(r: int, at: Vector3, yaw: float, mode: int) -> void:
	var b := Basis(Vector3.UP, yaw)
	bx(r, at, Vector3(.5, .4, .3), "#2a2c2e", false, b)
	if mode >= 0:
		var g := glow_piece(r, at + b * Vector3(0, 0, .16), Vector3(.42, .3, .01), Color(.2, 1.0, .5), 1.6, b)
		lamps.append({"l": null, "e": 0.0, "m": mode, "p": rng.randf() * 10.0, "g": g, "ge": 1.6, "gate": "", "on": -1.0})

func lockers(r: int, x0: float, x1: float, z: float, y: float, facing: float) -> void:
	var n := int((x1 - x0) / .46)
	for i in n:
		var x := x0 + (i + .5) * .46
		bx(r, h(x, y + .95, z), Vector3(.44, 1.9, .5), BLUE)
		for k in 2:
			bx(r, h(x, y + .6 + k * .95, z + facing * .255), Vector3(.3, .6, .01), BLUE_D)
			bx(r, h(x + .14, y + .95 + k * .3 - .15, z + facing * .26), Vector3(.04, .08, .02), "#b8bcc0")
	solid(r, h((x0 + x1) * .5, y + .95, z), Vector3(x1 - x0, 1.9, .5))

func chairs(r: int, at: Vector3, n: int, yaw: float, knocked := 0) -> void:
	var b := Basis(Vector3.UP, yaw)
	for i in n:
		var c := at + b * Vector3((i - (n - 1) * .5) * .58, 0, 0)
		if i < knocked:
			bx(r, c + Vector3(0, .25, 0), Vector3(.5, .08, .5), BLUE, false, b * Basis(Vector3.RIGHT, 1.3))
			continue
		bx(r, c + Vector3(0, .45, 0), Vector3(.5, .07, .48), BLUE, false, b)
		bx(r, c + b * Vector3(0, .78, -.23), Vector3(.5, .6, .06), BLUE, false, b)
		bx(r, c + Vector3(0, .22, 0), Vector3(.06, .44, .06), STEEL, false, b)

func duct(r: int, a: Vector3, b: Vector3, w := .7, hh := .5) -> void:
	var d := b - a
	var basis := Basis(Vector3.UP, atan2(d.x, d.z))
	bx(r, (a + b) * .5, Vector3(w, hh, d.length()), "#6a6e70", false, basis)
	var n := int(d.length() / 1.6)
	for i in n:
		var c := a.lerp(b, (i + .5) / n)
		bx(r, c, Vector3(w + .04, hh + .04, .05), "#4a4e50", false, basis)

func shelf(r: int, at: Vector3, yaw: float, w := 1.6, tipped := false) -> void:
	var b := Basis(Vector3.UP, yaw)
	if tipped: b = b * Basis(Vector3.RIGHT, 1.35)
	for k in 5: bx(r, at + b * Vector3(0, .1 + k * .45, 0), Vector3(w, .03, .45), STEEL, false, b)
	for sx in [-1, 1]: bx(r, at + b * Vector3(sx * w * .5, 1.0, 0), Vector3(.04, 2.0, .45), STEEL, false, b)
	for k in 8: bx(r, at + b * Vector3(rng.randf_range(-w * .4, w * .4), .25 + (k % 4) * .45, 0), Vector3(rng.randf_range(.1, .35), rng.randf_range(.12, .3), .3), ["#d8d4c8", "#6a8aa8", "#a8a090", "#e8e8e0"][k % 4], false, b)

func desk(r: int, at: Vector3, size: Vector3, top := "#d8dce0", front := BLUE) -> void:
	bx(r, at + Vector3(0, size.y * .5, 0), size, front)
	bx(r, at + Vector3(0, size.y + .02, 0), size + Vector3(.06, .04, .06), top)
	solid(r, at + Vector3(0, size.y * .5, 0), size)

func body_bag(r: int, at: Vector3, yaw: float) -> void:
	bx(r, at + Vector3(0, .13, 0), Vector3(.62, .26, 1.85), "#101214", false, Basis(Vector3.UP, yaw))
	bx(r, at + Vector3(0, .27, 0), Vector3(.03, .02, 1.6), "#6a6a6a", false, Basis(Vector3.UP, yaw))

## The infected's dead and the night's mess in a room: litter, blood, a few fallen tiles.
func mess(r: int, lo: Vector2, hi: Vector2, y: float, n := 14, blood := 2) -> void:
	litter(r, h((lo.x + hi.x) * .5, y, (lo.y + hi.y) * .5), Vector2((hi.x - lo.x) * .45, (hi.y - lo.y) * .45), n, ["#e4e4dc", "#c8ccd0", "#7a8a98", "#e8e2d0", "#1d4ea8", "#9a2a22"])
	for i in blood:
		stain(r, ["pool_big", "splat_a", "drag_a"][i % 3], h(rng.randf_range(lo.x, hi.x), y, rng.randf_range(lo.y, hi.y)), rng.randf() * TAU, rng.randf_range(1.0, 2.2), rng.randf_range(.8, 1.6))

func blocker(r: int, lo: Vector3, hi: Vector3, kind := "rubble") -> void:
	solid(r, (h(lo.x, lo.y, lo.z) + h(hi.x, hi.y, hi.z)) * .5, (hi - lo).abs())
	var c := (lo + hi) * .5
	var sz := (hi - lo).abs()
	if kind == "rubble":
		heap_h(r, lo, hi)
		rebar(r, h(c.x, hi.y - .3, c.z), Vector3(sz.x * .4, 0, sz.z * .4), 6, Vector3(0, -.4, 0))
	elif kind == "barricade":
		for i in 9:
			var at := h(rng.randf_range(lo.x, hi.x), lo.y + rng.randf_range(.3, sz.y - .4), rng.randf_range(lo.z, hi.z))
			bx(r, at, Vector3(rng.randf_range(.6, 1.9), rng.randf_range(.1, .9), rng.randf_range(.4, 1.0)), [STEEL, "#8a7a72", BLUE, "#c8ccd0", "#5a5e62"][i % 5], false, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-.8, .8)))
		bed(r, h(c.x, lo.y, c.z), rng.randf() * TAU, false, true)
		gurney(r, h(c.x + .4, lo.y + .9, c.z - .3), rng.randf() * TAU)

func heap_h(r: int, lo: Vector3, hi: Vector3) -> void:
	var sz := (hi - lo).abs()
	for i in int(clampf(sz.x * sz.z * 1.2, 12, 40)):
		var u := Vector3(rng.randf(), rng.randf(), rng.randf())
		var at := h(lo.x + u.x * sz.x, lo.y + u.y * u.y * sz.y, lo.z + u.z * sz.z)
		bx(r, at, Vector3(rng.randf_range(.3, 1.3), rng.randf_range(.15, .6), rng.randf_range(.3, 1.1)), ["concrete_wall_008|#b8b0a4", CEIL, WALL, "#6a6e70"][i % 4], false, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-.6, .6)))

## A posed-dead spot list filled by the builder (hospital.gd lays the figures down): [local, kind, yaw, clip, how far].
var dead_spots: Array = []

# ---------------------------------------------------------------- the build

func build_hospital() -> void:
	make_roots(HROOTS)
	under = [R_F1, R_F2, R_F3, R_LAB, R_LOBBY]
	street_outside()
	facade()
	ground_floor()
	second_floor()
	third_floor()
	laboratory()
	roof()
	skyline()

func street_outside() -> void:
	var r := R_OUT
	span(r, h(-46, -.4, -36), h(46, 0, 0), ASPHALT, true)
	span(r, h(-30, -.4, -6), h(30, .0, 0), PAVE, false)
	bx(r, h(0, .02, -6.05), Vector3(60, .04, .12), "#8a8a84")
	for x in range(-40, 41, 6): bx(r, h(float(x), .01, -18), Vector3(2.6, .015, .16), "#c8c2a0")
	# Blocked both ways along the street: a jackknifed truck and the cars that hit it west; east the police line went
	# down under a burning pile-up. Behind, the row across the street (its shutters down, one front fallen out).
	blocker(r, Vector3(-36, 0, -34), Vector3(-30, 3.6, 0), "rubble")
	road_car(r, "truck_wreck", h(-27.5, 0, -16), 1.2, false, "", Vector3(0, 0, .05), true)
	road_car(r, "sedan_wreck", h(-25.0, 0, -9.0), 2.6, true)
	road_car(r, "van_wreck", h(-26.5, 0, -24.0), .4, false, "#d8d6d0", Vector3(0, 0, 1.4), true)
	road_car(r, "sedan_wreck", h(-24.2, 1.45, -21.6), 1.9, true, "", Vector3(.1, 0, 2.9), false)
	blocker(r, Vector3(30, 0, -34), Vector3(36, 3.6, 0), "rubble")
	road_car(r, "truck_wreck", h(27.0, 0, -12.0), -1.4, true, "", Vector3.ZERO, true)
	road_car(r, "taxi_wreck", h(24.0, 0, -23.5), 2.2, false)
	road_car(r, "sedan", h(25.2, 0, -4.0), -.6, false, "#1e2a44")
	fire(r, h(27.0, 1.4, -12.0), 1.3, 14.0)
	fire(r, h(-25.0, .9, -9.0), .8, 9.0)
	for i in 6:
		var x := -28.0 + i * 11.2
		bx(r, h(x, 4.5, -31.0), Vector3(10.6, 9.0, 4.0), ["painted_plaster_wall|#b8b0a0", "worn_cracked_plaster|#a8a090", "brick_wall_02|#8a6a5a"][i % 3])
		bx(r, h(x, 1.6, -28.95), Vector3(8.0, 3.2, .1), "painted_metal_shutter|#7a7e80")
		for k in 3: bx(r, h(x - 3.0 + k * 3.0, 6.0, -28.98), Vector3(1.6, 1.4, .05), "#121416" if rng.randf() < .8 else "glow#ffc890*0.6")
	solid(r, h(0, 2.0, -29.4), Vector3(60, 4.0, 1.0))
	heap_h(r, Vector3(-2, 0, -29), Vector3(6, 2.2, -26))
	# The hospital's grounds closed off either side of the building: its fence and gates, chained.
	for side in [-1.0, 1.0]:
		var x0: float = 24.0 * side
		var x1: float = 30.0 * side
		span(r, h(minf(x0, x1), 0, -.3), h(maxf(x0, x1), 3.0, .1), "#3a3e40", true)
		for k in 7: pipe(r, h(lerpf(x0, x1, k / 6.0), 0, -.1), h(lerpf(x0, x1, k / 6.0), 3.0, -.1), .03, "#2a2e30")
	# The ambulances by the door, back doors open; the police car's light bar still turning.
	ambulance(r, h(-7.0, 0, -6.6), PI * .5 + .15)
	ambulance(r, h(7.4, 0, -7.2), -PI * .5 - .1)
	police_car(r, h(-14.0, 0, -12.0), .5)
	police_car(r, h(14.0, 0, -13.6), -.8)
	# The triage they ran out here before they gave up on it: bags, a gurney, a stretcher, the blood.
	for i in 5: body_bag(r, h(-18.0 + i * .9, 0, -3.2 + (i % 2) * .3), rng.randf_range(-.1, .1))
	gurney(r, h(-3.6, 0, -4.2), .3)
	gurney(r, h(12.0, 0, -3.0), 1.9, true)
	for i in 6: stain(r, ["pool_big", "drag_a", "splat_a"][i % 3], h(rng.randf_range(-16, 16), 0, rng.randf_range(-14, -2)), rng.randf() * TAU, 1.6, 1.2)
	litter(r, h(0, 0, -12), Vector2(26, 10), 70)
	# Barricades the police put up across the pavement either side of the ambulances.
	for x in [-11.0, 11.0]:
		for k in 3: bx(r, h(x + (k - 1) * 1.3, .5, -2.2), Vector3(1.2, 1.0, .5), "#c8c8c0")
	# The lamps, one dead, one dying; a pole down across the pavement with its cable sparking.
	for x in [-20.0, -6.0, 20.0]:
		pipe(r, h(x, 0, -6.6), h(x, 6.2, -6.6), .08, "#4a4e50", 6)
		bar(r, h(x, 6.2, -6.6), h(x, 6.2, -5.2), .06, "#4a4e50")
		lamp(r, h(x, 6.1, -5.2), Color(1.0, .78, .5), 2.4 if x != -6.0 else 0.0, 16.0, 2 if x != 20.0 else 3, Vector3(.4, .1, .6), "", x != -6.0)
	pipe(r, h(16.0, .2, -6.0), h(21.0, .5, -1.0), .1, "#3a3a38", 6)
	cable(r, h(21.0, .5, -1.0), h(10.0, .02, -2.0), .2, "#101010", .02)
	sparks(r, h(10.0, .15, -2.0))
	smoke(r, h(-26.0, 3.0, -14.0), 30, 1.6)

func ambulance(r: int, at: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	bx(r, at + b * Vector3(0, 1.5, -1.0), Vector3(2.1, 2.3, 3.8), "#e8e8e4", false, b)
	bx(r, at + b * Vector3(0, 1.15, 1.9), Vector3(2.0, 1.5, 1.9), "#e8e8e4", false, b)
	bx(r, at + b * Vector3(0, 1.55, 2.5), Vector3(1.86, .7, .9), "glass#1a2228c0", false, b * Basis(Vector3.RIGHT, -.35))
	for side in [-1.0, 1.0]:
		bx(r, at + b * Vector3(side * 1.06, 1.25, -.6), Vector3(.02, .28, 4.6), "#c01a1a", false, b)
		for wz in [-2.0, 1.9]: cyl(r, at + b * Vector3(side * .92, .38, wz), .38, .3, "#0e0e0e", b * Basis(Vector3.FORWARD, PI * .5), 10)
	bx(r, at + b * Vector3(.55, 2.2, .1), Vector3(.5, .5, .05), "#c01a1a", false, b)
	bx(r, at + b * Vector3(.55, 2.2, .1), Vector3(.16, .5, .06), "#e8e8e4", false, b)
	# Light bar on the cab, red and blue turning.
	for k in 2:
		var g := glow_piece(r, at + b * Vector3(-.45 + k * .9, 2.0, 2.4), Vector3(.7, .14, .22), RED_L if k == 0 else BLUE_L, 4.0, b)
		lamps.append({"l": null, "e": 0.0, "m": 5, "p": float(k) * .55, "g": g, "ge": 4.0, "gate": "", "on": -1.0})
	var l := omni(r, at + b * Vector3(0, 2.4, 2.4), RED_L, 2.6, 13.0)
	lamps.append({"l": l, "e": 2.6, "m": 5, "p": 0.0, "g": null, "ge": 0.0, "gate": "", "on": -1.0})
	var l2 := omni(r, at + b * Vector3(0, 2.4, 2.2), BLUE_L, 2.6, 13.0)
	lamps.append({"l": l2, "e": 2.6, "m": 5, "p": .55, "g": null, "ge": 0.0, "gate": "", "on": -1.0})
	# The back open: two leaves swung out, the inside lit (a stretcher, a monitor, the oxygen).
	for side in [-1.0, 1.0]:
		bx(r, at + b * Vector3(side * 1.55, 1.45, -2.95), Vector3(1.0, 2.0, .05), "#e8e8e4", false, b * Basis(Vector3.UP, side * 1.3))
	bx(r, at + b * Vector3(0, .7, -1.0), Vector3(.6, .1, 2.6), "#c8c8c0", false, b)
	var inside := omni(r, at + b * Vector3(0, 2.3, -1.2), Color(.9, .95, 1.0), 1.4, 5.0)
	inside.distance_fade_begin = 30.0
	solid(r, at + b * Vector3(0, 1.3, -.2), Vector3(2.2, 2.6, 5.8), b)

func police_car(r: int, at: Vector3, yaw: float) -> void:
	road_car(r, "sedan", at, yaw, false, "#1c2436")
	var b := Basis(Vector3.UP, yaw)
	for k in 2:
		var g := glow_piece(r, at + b * Vector3(-.3 + k * .6, 1.52, .1), Vector3(.5, .1, .2), RED_L if k == 0 else BLUE_L, 4.0, b)
		lamps.append({"l": null, "e": 0.0, "m": 5, "p": float(k) * .55 + .2, "g": g, "ge": 4.0, "gate": "", "on": -1.0})

func facade() -> void:
	var r := R_OUT
	# The front: white panels and royal blue bands, the lobby's glass curtain wall, the canopy over the entrance.
	span(r, h(-24, 0, -.2), h(-10, ROOF + .9, .2), "white_plaster_02|#e6e8ec", true)
	span(r, h(10, 0, -.2), h(24, ROOF + .9, .2), "white_plaster_02|#e6e8ec", true)
	span(r, h(-10, LOBBY_TOP, -.2), h(10, ROOF + .9, .2), "white_plaster_02|#e6e8ec", true)
	for y in [F2 - .2, F3 - .2, ROOF + .4]:
		bx(r, h(0, y, -.26), Vector3(48.4, .5, .12), BLUE)
	for side in [-1.0, 1.0]:
		for k in 4:
			var x: float = side * (12.0 + k * 3.0)
			for y in [F2 + 1.6, F3 + 1.6]: bx(r, h(x, y, -.24), Vector3(1.8, 1.5, .06), "#121820" if rng.randf() < .85 else "glow#d8e8ff*0.5")
	r = R_LOBBY
	# The glass curtain wall: mullions in blue, panes broken out here and there (behind them the lobby).
	for k in range(-10, 11, 2):
		bx(r, h(float(k), LOBBY_TOP * .5, -.05), Vector3(.12, LOBBY_TOP, .16), BLUE_D)
	for y in [2.8, 5.6, LOBBY_TOP - .05]: bx(r, h(0, y, -.05), Vector3(20, .12, .16), BLUE_D)
	for k in range(-10, 10, 2):
		for row in 3:
			var x0 := float(k)
			if x0 >= -3 and x0 < 3 and row == 0: continue
			if rng.randf() < .3: continue
			bx(r, h(x0 + 1.0, 1.4 + row * 2.8, -.04), Vector3(1.88, 2.68, .02), "glass#26343cb0")
	solid(r, h(-6.25, LOBBY_TOP * .5, 0), Vector3(7.5, LOBBY_TOP, .3))
	solid(r, h(6.25, LOBBY_TOP * .5, 0), Vector3(7.5, LOBBY_TOP, .3))
	solid(r, h(0, (3.0 + LOBBY_TOP) * .5, 0), Vector3(5.0, LOBBY_TOP - 3.0, .3))
	r = R_OUT
	# The canopy and its sign.
	bx(r, h(0, 3.5, -3.2), Vector3(9.0, .35, 6.6), "white_plaster_02|#e0e2e6")
	bx(r, h(0, 3.5, -6.5), Vector3(9.1, .5, .12), BLUE)
	for x in [-4.2, 4.2]: pipe(r, h(x, 0, -6.2), h(x, 3.4, -6.2), .14, "#d0d2d6", 10)
	var em_sign := label(r, h(0, 3.52, -6.6), "EMERGENCY", .5, PI, Color(1.0, .2, .16), true, 70.0)
	var sl := lamp_light(null, 0.0, 2, "", null, 0.0)
	sl["lbl"] = em_sign
	sl["col"] = Color(1.0, .2, .16)
	var under_l := omni(r, h(0, 3.1, -3.0), COLD, 1.6, 9.0)
	lamps.append({"l": under_l, "e": 1.6, "m": 2, "p": 3.0, "g": null, "ge": 0.0, "gate": "", "on": -1.0})
	# The lockdown shutter inside the whole glass front (rolled up in its box under the lobby's ceiling; hospital.gd
	# brings it down behind the squad).
	r = R_LOBBY
	bx(r, h(0, LOBBY_TOP - .3, .45), Vector3(20.2, .5, .5), "#5a5e62")
	shutter = Node3D.new()
	shutter.name = "Lockdown shutter"
	shutter.position = h(0, LOBBY_TOP - .5, .45)
	roots[r].add_child(shutter)
	var sm := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(20.0, LOBBY_TOP - .5, .06)
	sm.mesh = box
	sm.position = Vector3(0, -(LOBBY_TOP - .5) * .5, 0)
	sm.material_override = mat("painted_metal_shutter|#8a8e90")
	shutter.add_child(sm)
	shutter.scale.y = .02
	var sb := StaticBody3D.new()
	sb.collision_layer = 2
	shutter_shape = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(20.0, LOBBY_TOP - .5, .3)
	shutter_shape.shape = bs
	shutter_shape.disabled = true
	sb.position = h(0, (LOBBY_TOP - .5) * .5, .45)
	sb.add_child(shutter_shape)
	roots[r].add_child(sb)

func ground_floor() -> void:
	var r := R_F1
	slab(r, -24, -10, 0, 36, F1, TERR)
	slab(r, 10, 24, 0, 36, F1, TERR)
	slab(r, -10, 10, 16, 36, F1, TERR)
	# Outer walls (the front belongs to the street's root, which draws it).
	wall_z(r, -24, 0, 36, 0, F2 - .3, WALL, [], false, .3)
	wall_z(r, 24, 0, 36, 0, F2 - .3, WALL, [], false, .3)
	wall_x(r, 36, -24, 24, 0, F2 - .3, WALL, [], false, .3)
	# --- The lobby (x -10..10, z 0..16), two storeys: the blue ring in the ceiling, the ring in the floor. (Its own root:
	# the second floor's balcony looks down into it after the rest of the ground floor is put away.)
	r = R_LOBBY
	slab(r, -10, 10, 0, 16, F1, TERR)
	for x in [-10.0, 10.0]: span(r, h(x - .1, F2 - .3, 0), h(x + .1, LOBBY_TOP, 12), WALL, true)
	span(r, h(-10, C2, 11.9), h(10, LOBBY_TOP, 12.1), "white_plaster_02|#e8eaec")
	wall_z(r, -10, 0, 16, 0, F2 - .3, WALL, [[8.0, 4.0, 3.2]])
	wall_z(r, 10, 0, 16, 0, F2 - .3, WALL, [[8.0, 4.0, 3.2]])
	wall_x(r, 16, -10, 10, 0, F2 - .3, WALL, [[0.0, 3.6, 3.2]])
	span(r, h(-10, LOBBY_TOP, 0), h(10, LOBBY_TOP + .3, 16), "white_plaster_02|#e8eaec")
	for k in 32:
		var a := k / 32.0 * TAU
		var c := Vector3(0, LOBBY_TOP - .25, 6.5) + Vector3(cos(a), 0, sin(a)) * 4.4
		bx(r, h(c.x, c.y, c.z), Vector3(.9, .5, .5), BLUE, false, Basis(Vector3.UP, -a))
		bx(r, h(c.x * .93, c.y - .26, 6.5 + (c.z - 6.5) * .93), Vector3(.86, .04, .12), "#9ac0ff", false, Basis(Vector3.UP, -a))
	var ring := lamp(r, h(0, LOBBY_TOP - .6, 6.5), Color(.45, .65, 1.0), 2.4, 16.0, 2, Vector3.ZERO, "", true)
	ring["e"] = 2.4
	for k in 40:
		var a := k / 40.0 * TAU
		for rad in [3.0, 3.5]:
			bx(r, h(cos(a) * rad, .006, 6.5 + sin(a) * rad), Vector3(.5, .012, .14 if rad == 3.0 else .08), BLUE, false, Basis(Vector3.UP, -a + PI * .5))
	for k in 18:
		var t := k / 17.0
		var p := Vector3(lerpf(-8.0, 8.0, t), .007, 1.5 + sin(t * PI) * 2.6)
		bx(r, h(p.x, p.y, p.z), Vector3(1.0, .012, .26), "#7a8088", false, Basis(Vector3.UP, cos(t * PI) * .7))
	# Reception, the waiting rows, what was left.
	desk(r, h(-4.0, 0, 10.6), Vector3(5.0, 1.1, .8))
	bx(r, h(-4.0, .55, 10.19), Vector3(5.02, .18, .02), "#9ac0ff")
	monitor(r, h(-5.2, 1.35, 10.6), PI, 3)
	monitor(r, h(-2.8, 1.35, 10.6), PI, -1)
	for row in 3: chairs(r, h(5.0, 0, 3.0 + row * 1.6), 6, PI, row)
	chairs(r, h(-6.0, 0, 3.2), 4, PI * .5, 1)
	gurney(r, h(2.0, 0, 9.0), .7, true)
	iv_pole(r, h(-1.0, 0, 5.0))
	mess(r, Vector2(-9, 1), Vector2(9, 15), F1, 30, 5)
	drag(r, h(-1.0, 0, 2.0), h(-6.0, 0, 13.6))
	# The grand stair up to the balcony: its middle flight came down; the top hangs from the balcony.
	stair(r, h(-8.2, 0, 2.4), h(-8.2, 1.7, 6.2), 2.2, 10, TERR, BLUE)
	railing(r, h(-9.35, 0, 2.4), h(-9.35, 1.7, 6.2), 1.0, BLUE_D)
	span(r, h(-9.3, 3.1, 10.0), h(-7.1, 3.5, 12.0), TERR, true)
	bx(r, h(-8.2, 2.5, 9.2), Vector3(2.2, .3, 2.4), TERR, false, Basis(Vector3.RIGHT, .7))
	blocker(r, Vector3(-9.6, 0, 6.2), Vector3(-6.8, 2.4, 9.8), "rubble")
	sparks(r, h(-8.2, 3.0, 10.0))
	# The west corridor (beds and cabinets to the ceiling) and the way north (the ceiling came down).
	blocker(r, Vector3(-11.2, 0, 6.0), Vector3(-10.1, 3.4, 10.0), "barricade")
	blocker(r, Vector3(-2.0, 0, 16.2), Vector3(2.0, 3.4, 19.0), "rubble")
	r = R_F1
	wall_z(r, -16, 6, 10, 0, C1, WALL)
	slab(r, -16, -10, 6, 10, C1 + .3, CEIL, .3)
	span(r, h(-16, 0, 5.8), h(-10, C1, 6.0), WALL, true)
	span(r, h(-16, 0, 10.0), h(-10, C1, 10.2), WALL, true)
	tube(r, h(-13.0, C1 - .05, 8.0), 3, true, 6.0, .9)
	stain(r, "drag_a", h(-13.5, 0, 8.0), 1.4, 2.0, .8)
	span(r, h(-2, 0, 16), h(-1.8, C1, 30), WALL, true)
	span(r, h(1.8, 0, 16), h(2, C1, 30), WALL, true)
	ceiling(r, -1.8, 1.8, 16, 30, C1, CEIL, [[-2.0, 2.0, 16.0, 20.0]])
	sparks(r, h(.4, 3.0, 18.4))
	tube(r, h(0, C1 - .05, 24.0), 4, true, 6.0, .8)
	# --- East hall (x 10..24, z 6..10): blue lockers, blue soffit arches, the high windows; the far end down.
	wall_x(r, 6, 10, 24, 0, C1, WALL, [], true)
	wall_x(r, 10, 10, 24, 0, C1, WALL, [[14.0, 1.8, 2.4]])
	lockers(r, 10.6, 18.0, 6.35, 0, 1.0)
	ceiling(r, 10, 24, 6, 10, C1, CEIL, [[16.0, 18.4, 6.0, 10.0]])
	for k in 5:
		var x := 11.0 + k * 2.9
		bx(r, h(x, C1 - .3, 8.0), Vector3(.5, .6, 4.0), BLUE, false, Basis(Vector3.FORWARD, .25))
		tube(r, h(x + 1.2, C1 - .05, 8.0), [2, -1, 3, -1, 4][k], k == 0 or k == 2, 7.0, 1.0)
	blocker(r, Vector3(19.0, 0, 6.2), Vector3(24, 3.4, 9.8), "rubble")
	bx(r, h(18.4, .9, 8.6), Vector3(1.0, 1.8, .8), "#b81e1e", false, Basis(Vector3.FORWARD, 1.2))
	bx(r, h(18.0, .5, 7.2), Vector3(.9, 1.8, .8), "#2a5aa8", false, Basis(Vector3.RIGHT, 1.45))
	sparks(r, h(17.2, 3.2, 8.0))
	mess(r, Vector2(10.5, 6.5), Vector2(18.5, 9.5), F1, 14, 2)
	# --- The ER (x 10..24, z 10..21): curtained bays along its north wall, the counter, the blood.
	wall_x(r, 21, 10, 24, 0, C1, WALL, [[22.0, 1.8, 2.4]])
	ceiling(r, 10, 24, 10, 21, C1, CEIL, [[12.0, 14.4, 15.0, 17.4]])
	for k in 4:
		var x := 11.8 + k * 3.2
		bed(r, h(x, 0, 19.4), PI * .5 * 0.0, true, k == 2)
		curtain(r, h(x - 1.5, 0, 17.6), h(x + 1.5, 0, 17.6), 3.2, .4 if k % 2 == 0 else .0)
		curtain(r, h(x + 1.55, 0, 17.6), h(x + 1.55, 0, 20.8), 3.2)
		monitor(r, h(x + .9, 1.4, 20.6), PI, [3, -1, 2, 6][k])
		iv_pole(r, h(x - .9, 0, 20.3))
	desk(r, h(17.0, 0, 13.6), Vector3(4.0, 1.05, .9), "#e0e4e8")
	gurney(r, h(13.0, 0, 12.6), 1.2)
	gurney(r, h(21.5, 0, 14.0), 2.6, true)
	tube(r, h(13.0, C1 - .05, 13.0), 2, true, 7.0, 1.0)
	tube(r, h(19.0, C1 - .05, 16.0), 3, true, 7.0, 1.0)
	tube(r, h(16.0, C1 - .05, 19.0), -1)
	mess(r, Vector2(10.5, 10.5), Vector2(23.5, 20.5), F1, 24, 4)
	drag(r, h(14.0, 0, 11.0), h(22.0, 0, 20.6))
	sparks(r, h(13.2, 3.2, 16.2))
	dead_spots.append([Vector3(15.2, 0, 15.6), 81, 1.2, "death_back", .95])
	dead_spots.append([Vector3(20.8, 0, 11.6), 8, -2.0, "death_fwd", .9])
	# --- The way round: E2 (x 20..24, z 21..30) and the back corridor (x -16..24, z 30..33).
	wall_z(r, 20, 21, 30, 0, C1, WALL)
	ceiling(r, 20, 24, 21, 33, C1)
	tube(r, h(22.0, C1 - .05, 25.5), 3, true, 6.0, .9)
	wall_x(r, 30, -16, 20, 0, C1, WALL)
	wall_x(r, 33, -16, 24, 0, C1, WALL, [[9.0, 1.8, 2.4]])
	wall_z(r, 4, 33, 36, 0, C1, WALL)
	wall_z(r, 14, 33, 36, 0, C1, WALL)
	ceiling(r, -16, 20, 30, 33, C1, CEIL, [[3.0, 5.4, 30.0, 33.0]])
	for k in 6: tube(r, h(-13.0 + k * 6.0, C1 - .05, 31.5), [3, -1, 4, 2, -1, 3][k], k % 2 == 0, 6.5, .9)
	sparks(r, h(4.2, 3.1, 31.5))
	duct(r, h(-16, C1 - .4, 32.4), h(24, C1 - .4, 32.4), .6, .4)
	mess(r, Vector2(-15, 30.4), Vector2(23, 32.6), F1, 26, 4)
	dead_spots.append([Vector3(-4.0, 0, 31.2), 86, PI * .5, "death_crumple", .9])
	# Jammed doors along it (decor) and the morgue's open door: its drawers, one pulled out.
	for x in [6.0, -8.0, -4.0, 16.0]: bx(r, h(x, 1.1, 30.05 if x in [6.0, -8.0] else 32.95), Vector3(1.1, 2.15, .06), "#c8ccd2")
	slab(r, 4, 14, 33, 36, C1 + .3, CEIL, .3)
	for k in 6:
		bx(r, h(5.2 + k * 1.5, 1.4, 35.6), Vector3(1.3, 2.6, .5), "#9aa0a6")
		for j in 3: bx(r, h(5.2 + k * 1.5, .6 + j * .85, 35.34), Vector3(1.1, .7, .02), "#b8bcc2")
	bx(r, h(9.6, 1.0, 34.6), Vector3(.7, .3, 1.8), "#b8bcc2")
	tube(r, h(9.0, C1 - .05, 34.6), 6, true, 5.0, .7, Color(.7, 1.0, .9))
	# The rest of the ground floor's rooms, shut (solid behind their walls).
	solid(r, h(-6.0, C1 * .5, 23.0), Vector3(8.0, C1, 14.0))
	solid(r, h(11.0, C1 * .5, 25.5), Vector3(18.0, C1, 9.0))
	solid(r, h(-13.0, C1 * .5, 20.0), Vector3(6.0, C1, 20.0))
	# --- The stairwell (x -24..-16, z 22..36): one long flight up the west wall to the landing at z 22..24.5.
	wall_z(r, -16, 22, 36, 0, F2 - .3, WALL, [[31.5, 1.8, 2.4]])
	wall_x(r, 22, -24, -16, 0, C2, WALL, [], false)
	wall_z(r, -24, 22, 36, F2 - .3, C2 - F2 + .3, WALL, [], false, .3)
	wall_x(r, 36, -24, -16, F2 - .3, C2 - F2 + .3, WALL, [], false, .3)
	stair(r, h(-22.4, 0, 34.2), h(-22.4, F2, 24.5), 2.0, 22, "concrete_floor_02|#b8b4ac", BLUE)
	railing(r, h(-21.35, 0, 34.2), h(-21.35, F2, 24.5), 1.0, BLUE_D)
	slab(r, -24, -16, 22, 24.5, F2, "concrete_floor_02|#b8b4ac")
	railing(r, h(-21.3, F2, 24.5), h(-16.2, F2, 24.5), 1.0, BLUE_D)
	span(r, h(-24, C2, 22), h(-16, C2 + .1, 36), CEIL)
	tube(r, h(-19.0, C2 - .05, 30.0), 3, true, 9.0, 1.2)
	tube(r, h(-20.0, F2 - .35, 23.2), 2, true, 5.0, .7)
	stain(r, "drag_a", h(-22.4, 1.2, 30.0), 0.0, 2.4, .7)
	dead_spots.append([Vector3(-19.0, 0, 34.6), 82, .4, "death_back", .9])

func second_floor() -> void:
	var r := R_F2
	# Floors: over everything but the lobby's void (x -10..10, z 0..12) and the stairwell's well.
	slab(r, -24, -10, 0, 22, F2, TERR)
	slab(r, 10, 24, 0, 22, F2, TERR)
	slab(r, -10, 10, 12, 22, F2, TERR)
	slab(r, -16, 24, 21, 36, F2, TERR)
	# The balcony over the lobby: a glass rail with the blue band, curved at its ends.
	for k in 20:
		var x := -9.5 + k
		bx(r, h(x, F2 + .55, 12.05), Vector3(.98, 1.0, .02), "glass#9ab0c070")
	bx(r, h(0, F2 + 1.08, 12.05), Vector3(20, .08, .1), BLUE)
	bx(r, h(0, F2 - .15, 12.0), Vector3(20.2, .3, .16), "#9ac0ff")
	solid(r, h(0, F2 + .55, 12.05), Vector3(20, 1.1, .12))
	# Walls.
	wall_x(r, 21, -24, -10, F2, C2 - F2, WALL, [[-13.0, 2.4, 2.4]])
	wall_x(r, 21, 10, 24, F2, C2 - F2, WALL, [[14.0, 1.8, 2.4]])
	wall_z(r, -10, 12, 21, F2, C2 - F2, WALL)
	wall_z(r, 10, 10, 21, F2, C2 - F2, WALL)
	wall_x(r, 10, 10, 24, F2, C2 - F2, WALL)
	wall_x(r, 25, -16, 24, F2, C2 - F2, WALL, [[-13.5, 1.4, 2.3], [1.5, 1.6, 2.3], [10.5, 1.8, 2.4], [18.0, 1.4, 2.3]])
	wall_z(r, -16, 21, 25, F2, C2 - F2, WALL, [[23.3, 1.6, 2.4]])
	wall_z(r, -16, 25, 36, F2, C2 - F2, WALL)
	wall_z(r, -10, 0, 12, F2, C2 - F2, WALL)
	wall_z(r, -11, 25, 36, F2, C2 - F2, WALL)
	wall_z(r, -3, 25, 36, F2, C2 - F2, WALL)
	wall_z(r, 6, 25, 36, F2, C2 - F2, WALL)
	wall_z(r, 15, 25, 32.0, F2, C2 - F2, WALL)
	wall_z(r, 15, 33.4, 36, F2, C2 - F2, WALL)
	span(r, h(14.9, F2 + 1.05, 32.0), h(15.1, C2, 33.4), WALL, true)
	wall_x(r, 30, 15, 24, F2, C2 - F2, WALL, [[21.0, 1.4, 2.3]])
	wall_z(r, -24, 0, 36, F2, C2 - F2, WALL, [], false, .3)
	wall_z(r, 24, 0, 36, F2, C2 - F2, WALL, [], false, .3)
	wall_x(r, 36, -24, 24, F2, C2 - F2, WALL, [], false, .3)
	wall_x(r, 0, -24, -10, F2, C2 - F2, WALL, [], false, .3)
	wall_x(r, 0, 10, 24, F2, C2 - F2, WALL, [], false, .3)
	# Ceilings (the plenum above them: the duct runs there).
	ceiling(r, -24, -10, 0, 21, C2, CEIL, [[-23.0, -22.0, 19.6, 20.9]])
	ceiling(r, -10, 10, 12, 21, C2, CEIL, [[3.0, 6.0, 14.0, 18.0]])
	ceiling(r, 10, 24, 0, 21, C2)
	ceiling(r, -16, 24, 21, 25, C2, CEIL, [[4.0, 8.0, 21.0, 25.0]])
	ceiling(r, -16, 24, 25, 36, C2, CEIL, [[-7.5, -6.5, 30.5, 31.5], [-11.0, -3.0, 33.5, 36.0]])
	# --- The corridor (x -16..24, z 21..25): the black clinic's ducts overhead, curtains torn down, gurneys.
	duct(r, h(-16, C2 - .35, 22.0), h(24, C2 - .35, 22.0), .8, .45)
	for k in 7: tube(r, h(-13.0 + k * 6.0, C2 - .05, 23.6), [3, 2, -1, 4, -1, 3, 2][k], k in [0, 1, 3, 5], 7.0, 1.0)
	gurney(r, h(-4.0, F2, 22.4), 1.6)
	gurney(r, h(7.0, F2, 24.0), .2, true)
	blocker(r, Vector3(2.5, F2, 21.0), Vector3(4.5, F2 + 2.6, 22.3), "barricade")
	sparks(r, h(6.0, C2 - .2, 23.0))
	mess(r, Vector2(-15.5, 21.4), Vector2(23.5, 24.6), F2, 30, 5)
	dead_spots.append([Vector3(-9.0, F2, 23.0), 85, 2.2, "death_fwd", .9])
	# --- The balcony and the nurses' station.
	tube(r, h(-4.0, C2 - .05, 16.0), 2, true, 8.0, 1.0)
	tube(r, h(5.0, C2 - .05, 19.0), -1)
	chairs(r, h(-3.0, F2, 17.6), 5, 0.0, 2)
	sparks(r, h(4.5, C2 - .1, 16.0))
	desk(r, h(16.0, F2, 15.0), Vector3(5.0, 1.05, 1.0), "#e0e4e8")
	monitor(r, h(15.0, F2 + 1.3, 15.0), PI, 2)
	monitor(r, h(17.4, F2 + 1.3, 15.0), PI, -1)
	shelf(r, h(22.6, F2, 17.0), PI * .5)
	tube(r, h(16.0, C2 - .05, 15.5), 3, true, 8.0, 1.0)
	mess(r, Vector2(10.5, 10.5), Vector2(23.5, 20.5), F2, 22, 3)
	solid(r, h(17.0, (F2 + C2) * .5, 5.0), Vector3(14.0, C2 - F2, 10.0))
	# --- The cafeteria (x -24..-10, z 0..21): tables, the serving line, the kitchen behind; its ladder to the vents.
	for row in 3:
		for col in 3:
			var c := h(-17.0 + col * 2.6, F2, 3.5 + row * 3.2)
			var tip := rng.randf() < .3
			bx(r, c + Vector3(0, .74, 0), Vector3(1.6, .05, .9), "#d8dce0", false, Basis(Vector3.RIGHT, 1.3) if tip else Basis.IDENTITY)
			if not tip:
				pipe(r, c, c + Vector3.UP * .72, .05, STEEL, 6)
				solid(r, c + Vector3(0, .4, 0), Vector3(1.5, .8, .8))
			chairs(r, c + Vector3(0, 0, .8), 2, PI, rng.randi() % 2)
			chairs(r, c - Vector3(0, 0, .8), 2, 0.0, rng.randi() % 2)
	desk(r, h(-19.4, F2, 11.3), Vector3(.8, 1.0, 6.6), "#b8bcc0", "#c8ccd0")
	bx(r, h(-19.4, F2 + 1.4, 11.3), Vector3(.6, .04, 6.6), "glass#c0d0d860")
	wall_z(r, -19.4, 16.2, 21, F2, C2 - F2, WALL)
	span(r, h(-24, F2, 12.6), h(-19.6, F2 + .9, 13.4), STEEL, true)
	for k in 3: bx(r, h(-23.3, F2 + .45, 14.4 + k * 1.6), Vector3(1.2, .9, 1.4), STEEL)
	solid(r, h(-23.3, F2 + .45, 16.0), Vector3(1.2, .9, 4.8))
	for k in 2: lamp(r, h(-21.5 + k * 2.0, C2 - .05, 17.0), COLD, .9, 6.0, [3, 2][k], Vector3(1.2, .05, .3), "", true)
	tube(r, h(-17.0, C2 - .05, 6.0), 2, true, 8.0, 1.0)
	tube(r, h(-13.0, C2 - .05, 10.0), -1)
	tube(r, h(-15.0, C2 - .05, 14.0), 4, true, 7.0, .9)
	mess(r, Vector2(-23.5, .5), Vector2(-10.5, 20.5), F2, 34, 5)
	drag(r, h(-14.0, F2, 6.0), h(-21.0, F2, 18.0))
	dead_spots.append([Vector3(-16.0, F2, 9.4), 27, .5, "devour", .55])
	# The ladder up the kitchen's north wall to the hatch into the duct.
	for k in 10: bx(r, h(LADDER_FOOT.x, F2 + .3 + k * .28, 20.85), Vector3(.5, .04, .04), "#8a8e90")
	for sx in [-.27, .27]: bx(r, h(LADDER_FOOT.x + sx, F2 + 1.4, 20.85), Vector3(.05, 2.8, .05), "#8a8e90")
	bx(r, h(LADDER_FOOT.x, C2 + .02, 20.2), Vector3(1.0, .02, 1.0), "#2a2c2e")
	InteriorPlayer.ladders.append([AABB(world(hv(LADDER_FOOT)) + Vector3(-.4, -.2, -.75), Vector3(.8, 3.4, 1.2)), Vector3(0, 0, -1), world(h(DUCT_X, DUCT_Y, 21.7))])
	# --- The duct: up from the kitchen's hatch, north over the stairwell, east to the records room's grille.
	_ducts(r)
	# --- Ward A (x -16..-11): two beds, the curtains.
	for k in 2:
		bed(r, h(-13.5, F2, 28.0 + k * 4.0), PI * .5, true)
		curtain(r, h(-15.8, F2, 26.4 + k * 4.0), h(-11.2, F2, 26.4 + k * 4.0), C2 - .3, .3)
	tube(r, h(-13.5, C2 - .05, 30.0), 3, true, 7.0, .9)
	mess(r, Vector2(-15.6, 25.4), Vector2(-11.4, 35.6), F2, 12, 2)
	# --- The records room (x -11..-3, z 25..36): its door to the corridor welded shut; the false wall at z 33.5 with
	# the bookcase in front of the stair's foot; the grille the duct drops through.
	bx(r, h(-7.0, F2 + 1.1, 25.12), Vector3(1.3, 2.2, .06), "#7a7e82")
	for k in 4: bx(r, h(-7.0, F2 + .4 + k * .55, 25.18), Vector3(1.4, .05, .04), "#3a3a3a")
	wall_x(r, 33.5, -11, -3, F2, C2 - F2, WALL, [[-10.1, 1.4, 2.3]], false)
	for k in 5: shelf(r, h(-4.0 - k * 1.7, F2, 26.0), 0.0, 1.5, k == 3)
	for k in 3: bx(r, h(-4.2, F2 + .7, 28.5 + k * 1.2), Vector3(.6, 1.4, .9), "#8a8e8a")
	desk(r, h(-8.0, F2, 29.6), Vector3(1.6, .76, .8), "#8a6a4a", "#6a5040")
	tube(r, h(-7.0, C2 - .05, 28.0), 2, true, 6.5, .8)
	bx(r, h(DROP.x, C2 - .02, DROP.z + .9), Vector3(.9, .03, .9), "#4a4e50", false, Basis(Vector3.RIGHT, .9))
	litter(r, h(-7.0, F2, 30.0), Vector2(3.0, 3.0), 40, ["#e8e4d8", "#d8d0b8", "#c8c0a8", "#ffffff"])
	bookcase = Node3D.new()
	bookcase.name = "Bookcase"
	bookcase.position = hv(BOOKCASE)
	roots[r].add_child(bookcase)
	var bmesh := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(1.5, 2.3, .42)
	bmesh.mesh = bb
	bmesh.position = Vector3(0, 1.15, 0)
	bmesh.material_override = mat("wood_cabinet_worn_long|#8a6a4a")
	bookcase.add_child(bmesh)
	for k in 4:
		for j in 6:
			var book := MeshInstance3D.new()
			var bk := BoxMesh.new()
			bk.size = Vector3(.16, .32, .3)
			book.mesh = bk
			book.position = Vector3(-.55 + j * .2, .35 + k * .5, -.08)
			book.material_override = mat(["#5a2a22", "#22344a", "#3a4a2a", "#6a5a3a"][(j + k) % 4])
			bookcase.add_child(book)
	var bcb := StaticBody3D.new()
	bcb.collision_layer = 2
	var bcs := CollisionShape3D.new()
	var bcshape := BoxShape3D.new()
	bcshape.size = Vector3(1.5, 2.3, .42)
	bcs.shape = bcshape
	bcs.position = Vector3(0, 1.15, 0)
	bcb.add_child(bcs)
	bookcase.add_child(bcb)
	# The hidden stair behind the false wall, up to the third floor's records annex.
	stair(r, hv(HIDDEN_FOOT), hv(HIDDEN_TOP), 1.9, 24, "concrete_floor_02|#9a968e", "#2a2a28")
	tube(r, h(-7.0, C2 + .3, 34.8), 3, true, 4.0, .5)
	# --- Ward B (x -3..6): the black clinic: beds behind curtains on rails, ducts, the drip stands.
	for k in 3:
		bed(r, h(-1.5 + k * 3.0, F2, 33.4), 0.0, true, k == 1)
		curtain(r, h(-2.8 + k * 3.0, F2, 31.6), h(.2 + k * 3.0, F2, 31.6), C2 - .3, [.0, .6, .3][k])
		iv_pole(r, h(-.6 + k * 3.0, F2, 34.6))
	duct(r, h(-3, C2 - .3, 28.0), h(6, C2 - .3, 28.0), .7, .4)
	tube(r, h(1.5, C2 - .05, 29.0), 6, true, 7.0, .8, Color(.7, 1.0, .9))
	monitor(r, h(4.8, F2 + 1.3, 35.4), PI, 4)
	mess(r, Vector2(-2.6, 25.5), Vector2(5.6, 35.5), F2, 18, 3)
	# --- The operating theatre (x 6..15): the table under its lamp, the trays, the gore.
	desk(r, h(10.5, F2, 31.0), Vector3(.8, .9, 2.1), "#c8ccd0", STEEL)
	var surgical := spot(r, h(10.5, C2 - .2, 31.0), h(10.5, F2, 31.0), Color(.9, .97, 1.0), 3.0, 4.0, 34.0)
	lamps.append({"l": surgical, "e": 3.0, "m": 3, "p": 1.0, "g": null, "ge": 0.0, "gate": "", "on": -1.0})
	cyl(r, h(10.5, C2 - .25, 31.0), .5, .12, "#c8ccd0", Basis.IDENTITY, 14)
	for k in 3: bx(r, h(8.0 + k * .7, F2 + .95, 28.4), Vector3(.5, .03, .35), STEEL)
	monitor(r, h(13.6, F2 + 1.4, 28.0), -PI * .5, 2)
	stain(r, "pool_big", h(10.5, F2, 31.6), .3, 2.6, 2.0)
	drag(r, h(10.5, F2, 33.0), h(14.6, F2, 32.7), false)
	mess(r, Vector2(6.5, 25.5), Vector2(14.5, 35.5), F2, 16, 3)
	sparks(r, h(7.2, C2 - .3, 34.0))
	dead_spots.append([Vector3(8.4, F2, 34.0), 75, 1.0, "death_back", .9])
	# --- The scrub room (x 15..24, z 25..30) and the sterile supply (z 30..36): its door blocked by the shelving
	# that fell against it; the only way in is low, through the broken partition from the theatre.
	for k in 2: bx(r, h(17.0 + k * 1.4, F2 + .5, 29.2), Vector3(1.2, 1.0, .6), STEEL)
	shelf(r, h(21.0, F2, 29.4), 0.0, 1.8, true)
	solid(r, h(21.0, F2 + 1.1, 29.4), Vector3(2.0, 2.2, 1.2))
	tube(r, h(19.5, C2 - .05, 27.5), 2, true, 6.0, .8)
	for k in 4: shelf(r, h(16.6 + k * 2.0, F2, 35.4), 0.0, 1.7)
	shelf(r, h(23.4, F2, 32.6), PI * .5, 1.6)
	rubble(r, h(15.6, F2, 32.7), Vector3(.5, .3, .6), 6, WALL)
	tube(r, h(20.0, C2 - .05, 33.0), -1)
	stain(r, "drag_a", h(19.0, F2, 33.0), 1.6, 2.4, .6)

## The duct: up through the kitchen's hatch (a hole in its floor at the ladder), north over the stairwell, then east
## to the grille over the records room (a hole in its floor). 1.1 m inside: crouched, or on hands and knees.
func _ducts(r: int) -> void:
	var w := "#5a5e60"
	var t := .05
	var y0 := DUCT_Y
	var y1 := DUCT_TOP
	var ax0 := DUCT_X - .55
	var ax1 := DUCT_X + .55
	var bz0 := DUCT_Z - .55
	var bz1 := DUCT_Z + .55
	# Run A, along z.
	span(r, h(ax0, y0 - t, 19.4), h(ax1, y0, 19.7), w, true)
	span(r, h(ax0, y0 - t, 21.0), h(ax1, y0, bz1), w, true)
	span(r, h(ax0 - t, y0, 19.35), h(ax0, y1, bz1 + t), w, true)
	span(r, h(ax1, y0, 19.35), h(ax1 + t, y1, bz0), w, true)
	span(r, h(ax0 - t, y0, 19.35), h(ax1 + t, y1, 19.4), w, true)
	span(r, h(ax0 - t, y0, bz1), h(ax1, y1, bz1 + t), w, true)
	span(r, h(ax0 - t, y1, 19.35), h(ax1 + t, y1 + t, bz1 + t), w, true)
	# Run B, along x.
	span(r, h(ax1, y0 - t, bz0), h(DROP.x - .5, y0, bz1), w, true)
	span(r, h(DROP.x + .5, y0 - t, bz0), h(-6.4, y0, bz1), w, true)
	span(r, h(ax1, y0, bz0 - t), h(-6.35, y1, bz0), w, true)
	span(r, h(ax1, y0, bz1), h(-6.35, y1, bz1 + t), w, true)
	span(r, h(-6.4, y0, bz0 - t), h(-6.35, y1, bz1 + t), w, true)
	span(r, h(ax1, y1, bz0 - t), h(-6.35, y1 + t, bz1 + t), w, true)
	for c: Vector3 in [Vector3(DUCT_X, 0, 23.0), Vector3(DUCT_X, 0, 27.5), Vector3(-19.0, 0, DUCT_Z), Vector3(-14.0, 0, DUCT_Z), Vector3(-10.0, 0, DUCT_Z)]:
		var g := glow_piece(r, h(c.x, y1 - .03, c.z), Vector3(.1, .02, .1), Color(1.0, .55, .3), .6)
		lamps.append({"l": null, "e": 0.0, "m": 2, "p": rng.randf() * 10.0, "g": g, "ge": .6, "gate": "", "on": -1.0})
	for c: Vector3 in [Vector3(DUCT_X, 0, 25.0), Vector3(-15.0, 0, DUCT_Z)]:
		var dim := omni(r, h(c.x, y0 + .6, c.z), Color(1.0, .6, .35), .35, 7.0)
		dim.distance_fade_begin = 20.0
	stain(r, "drag_a", h(DUCT_X, y0, 26.0), 0.0, 4.0, .5, .6)
	stain(r, "drag_a", h(-14.0, y0, DUCT_Z), PI * .5, 5.0, .5, .6)

func third_floor() -> void:
	var r := R_F3
	# (Round the hidden stair's well, x -10.65..-3.25, z 33.6..36.)
	slab(r, -24, 4, 0, 33.6, F3, LABT)
	slab(r, -24, -10.65, 33.6, 36, F3, LABT)
	slab(r, -3.25, 4, 33.6, 36, F3, LABT)
	slab(r, 4, 24, 0, 12, F3, LABT)
	# Walls: the white corridor's glass and panels (refs: white panels, light strips, glass-fronted rooms).
	wall_z(r, -24, 0, 36, F3, C3 - F3, PANEL, [], false, .3)
	wall_x(r, 36, -24, 4, F3, C3 - F3, PANEL, [], false, .3)
	wall_x(r, 0, -24, 4, F3, C3 - F3, PANEL, [], false, .3)
	wall_x(r, 12, -24, 4, F3, C3 - F3, PANEL, [], false)
	wall_x(r, 22, -24, 4, F3, C3 - F3, PANEL, [[-19.0, 1.6, 2.4], [-10.0, 1.6, 2.4], [-1.0, 1.6, 2.4]], false)
	wall_x(r, 26, -24, 4, F3, C3 - F3, PANEL, [[-18.0, 1.6, 2.4], [-7.0, 1.6, 2.4]], false)
	wall_z(r, -14, 12, 22, F3, C3 - F3, PANEL, [], false)
	wall_z(r, -6, 12, 22, F3, C3 - F3, PANEL, [], false)
	wall_z(r, -12, 26, 36, F3, C3 - F3, PANEL, [], false)
	wall_z(r, -2, 26, 36, F3, C3 - F3, PANEL, [], false)
	span(r, h(-24, C3, 0), h(4, C3 + .1, 36), PANEL)
	span(r, h(-24, ROOF - .3, 0), h(24, ROOF, 12), "concrete_floor_02|#8a8680", true)
	span(r, h(-24, ROOF - .3, 12), h(4, ROOF, 36), "concrete_floor_02|#8a8680", true)
	# The corridor: light strips along both edges of its ceiling, glass panels into the rooms, quiet. Peaceful.
	for side in [22.3, 25.7]:
		for k in 7:
			lamp(r, h(-21.0 + k * 3.8, C3 - .03, side), Color(.9, .96, 1.0), .7 if k % 2 == 0 else 0.0, 6.0, [0, 1, 0, 2, 0, 1, 0][k], Vector3(3.0, .03, .12), "", k % 2 == 0)
	for k in 6:
		bx(r, h(-21.5 + k * 4.4, F3 + 1.6, 22.12), Vector3(2.0, 1.6, .03), "glass#b8d0e070")
		bx(r, h(-21.5 + k * 4.4, F3 + 1.6, 25.88), Vector3(2.0, 1.6, .03), "glass#b8d0e070")
	for k in 8: bx(r, h(-22.0 + k * 3.4, F3 + .06, 24.0), Vector3(2.4, .01, .08), "#9ab8d8")
	# The records annex (x -12..-2, z 26..36): where the hidden stair comes up, a rail round its well.
	railing(r, h(-10.6, F3, 33.55), h(-3.8, F3, 33.55), 1.05, STEEL)
	railing(r, h(-10.7, F3, 33.6), h(-10.7, F3, 35.9), 1.05, STEEL)
	for k in 4: shelf(r, h(-10.5 + k * 2.2, F3, 27.0), 0.0, 1.8)
	lamp(r, h(-7.0, C3 - .03, 30.0), Color(.9, .96, 1.0), .8, 7.0, 1, Vector3(2.4, .03, .3), "", true)
	# The director's office (x -24..-12, z 26..36): the desk, the logbook on it, the window wall.
	desk(r, h(-15.6, F3, 33.6), Vector3(2.4, .76, 1.1), "#3a3028", "#2a2420")
	bx(r, h(-15.6, F3 + 1.1, 34.4), Vector3(.6, .4, .05), "#1a1c1e")
	chairs(r, h(-15.6, F3, 32.5), 1, 0.0)
	shelf(r, h(-23.4, F3, 31.0), PI * .5, 2.4)
	lamp(r, h(-18.0, C3 - .03, 31.0), Color(1.0, .92, .8), .9, 8.0, 1, Vector3(2.4, .03, .3), "", true)
	# The security office (x -24..-14, z 12..22): monitors (dead), the key cabinet hanging open.
	desk(r, h(-19.0, F3, 15.0), Vector3(4.0, .76, .9), "#d8dce0", "#2a2c2e")
	for k in 4: monitor(r, h(-20.5 + k * 1.0, F3 + 1.05, 15.3), PI, [6, -1, 6, -1][k])
	bx(r, h(-23.0, F3 + 1.0, 13.4), Vector3(.8, 1.0, .2), "#5a5e62")
	lamp(r, h(-19.0, C3 - .03, 17.0), COLD, .8, 7.0, 2, Vector3(2.4, .03, .3), "", true)
	# The electrical room (x -14..-6): panels, the fuse box open, sparking.
	for k in 4: bx(r, h(-13.6, F3 + 1.1, 13.5 + k * 2.0), Vector3(.4, 2.0, 1.6), "#7a7e80")
	bx(r, h(-12.6, F3 + 1.0, 21.6), Vector3(1.0, 1.2, .3), "#5a5e60")
	sparks(r, h(-13.3, F3 + 1.8, 16.0))
	lamp(r, h(-10.0, C3 - .03, 17.0), Color(1.0, .7, .4), .7, 6.0, 3, Vector3(1.2, .03, .3), "", true)
	# The server room (x -6..4): racks, blue LEDs, the battery pack on the floor.
	for k in 4:
		for j in 2:
			bx(r, h(-4.5 + k * 2.2, F3 + 1.0, 15.0 + j * 3.4), Vector3(.7, 2.0, 1.1), "#1a1c20")
			var led := glow_piece(r, h(-4.5 + k * 2.2, F3 + 1.4, 15.0 + j * 3.4 - .56), Vector3(.5, 1.2, .01), Color(.3, .55, 1.0), .8)
			lamps.append({"l": null, "e": 0.0, "m": 1, "p": rng.randf() * 10.0, "g": led, "ge": .8, "gate": "", "on": -1.0})
	lamp(r, h(-1.0, C3 - .03, 17.0), Color(.6, .75, 1.0), .7, 7.0, 1, Vector3(1.2, .03, .3), "", true)
	# The corpse at the corridor's west end (the keycard by his hand).
	dead_spots.append([Vector3(-22.2, F3, 24.2), 77, PI * .5, "death_back", .95])
	# The big electric door at the corridor's end: two leaves, a hazard frame, its panel (red: no power).
	for z in [21.8, 26.2]: span(r, h(3.7, F3, z - .3), h(4.3, F3 + 4.6, z + .3), HAZ, true)
	span(r, h(3.7, F3 + 4.4, 21.5), h(4.3, F3 + 5.0, 26.5), HAZ, true)
	span(r, h(3.85, F3 + 5.0, 12), h(4.15, LAB_ROOF, 36), PANEL, true)
	span(r, h(3.85, F3, 12), h(4.15, F3 + 5.0, 21.5), PANEL, true)
	span(r, h(3.85, F3, 26.5), h(4.15, F3 + 5.0, 36), PANEL, true)
	big_door_n = _door_leaf(r, h(4.0, F3, 25.0))
	big_door_s = _door_leaf(r, h(4.0, F3, 23.0))
	bx(r, h(3.6, F3 + 1.3, 27.0), Vector3(.1, .5, .35), "#2a2c2e")
	door_light = glow_piece(r, h(3.54, F3 + 1.4, 27.0), Vector3(.02, .1, .1), Color(1.0, .1, .05), 3.0)

func _door_leaf(r: int, at: Vector3) -> Node3D:
	var n := AnimatableBody3D.new()
	n.sync_to_physics = false
	n.collision_layer = 2
	n.position = at
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(.4, 4.4, 2.0)
	mi.mesh = bm
	mi.position = Vector3(0, 2.2, 0)
	mi.material_override = mat("#9aa0a6")
	n.add_child(mi)
	for k in 6:
		var rib := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(.44, .12, 1.9)
		rib.mesh = rb
		rib.position = Vector3(0, .4 + k * .7, 0)
		rib.material_override = mat("#6a7076")
		n.add_child(rib)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(.4, 4.4, 2.0)
	cs.shape = bs
	cs.position = Vector3(0, 2.2, 0)
	n.add_child(cs)
	roots[r].add_child(n)
	return n

func laboratory() -> void:
	var r := R_LAB
	slab(r, 4, 24, 12, 36, F3, LABT)
	wall_z(r, 24, 12, 36, F3, LAB_ROOF - F3, PANEL, [], false, .3)
	wall_x(r, 36, 4, 24, F3, LAB_ROOF - F3, PANEL, [], false, .3)
	wall_x(r, 12, 4, 24, F3, LAB_ROOF - F3, PANEL, [], false, .3)
	span(r, h(4, LAB_ROOF - .3, 12), h(24, LAB_ROOF, 34.6), "concrete_floor_02|#7a7670", true)
	span(r, h(4, LAB_ROOF - .3, 34.6), h(13.5, LAB_ROOF, 36), "concrete_floor_02|#7a7670", true)
	span(r, h(14.5, LAB_ROOF - .3, 34.6), h(24, LAB_ROOF, 36), "concrete_floor_02|#7a7670", true)
	# The hex lights in the ceiling (most of them dead now).
	for row in 6:
		for col in 7:
			var x := 6.0 + col * 2.6 + (1.3 if row % 2 == 1 else 0.0)
			var z := 14.5 + row * 3.6
			if x > 22.5: continue
			var lit := (row + col) % 3 == 0
			if lit:
				var g := glow_piece(r, h(x, LAB_ROOF - .45, z), Vector3(1.9, .06, 1.9), Color(.85, .95, 1.0), 2.0)
				lamps.append({"l": null, "e": 0.0, "m": [2, 3, 1][(row + col) % 3], "p": rng.randf() * 10.0, "g": g, "ge": 2.0, "gate": "lab_open", "on": -1.0})
			else:
				cyl(r, h(x, LAB_ROOF - .45, z), 1.1, .06, "#2a2e32", Basis.IDENTITY, 6)
	for k in 4:
		var l := omni(r, h(8.0 + (k % 2) * 12.0, LAB_ROOF - 1.2, 18.0 + int(k / 2) * 12.0), Color(.82, .92, 1.0), 2.4, 14.0)
		lamps.append({"l": l, "e": 2.4, "m": [2, 3, 1, 2][k], "p": rng.randf() * 10.0, "g": null, "ge": 0.0, "gate": "lab_open", "on": -1.0})
	# The tanks: a ring of glass columns on a plinth in the middle, teal and lit from below, a brain in each.
	var tc := Vector3(14.0, F3, 24.0)
	cyl(r, h(tc.x, F3 + .2, tc.z), 3.6, .4, "#2a2e32", Basis.IDENTITY, 20)
	solid(r, h(tc.x, F3 + .2, tc.z), Vector3(6.6, .4, 6.6))
	for k in 6:
		var a := k / 6.0 * TAU
		var c := tc + Vector3(cos(a), 0, sin(a)) * 2.5
		cyl(r, h(c.x, F3 + .55, c.z), .62, .3, "#3a3e42", Basis.IDENTITY, 14)
		var liquid := glow_piece(r, h(c.x, F3 + 2.2, c.z), Vector3(.9, 3.0, .9), TEAL, .9)
		lamps.append({"l": null, "e": 0.0, "m": 1, "p": rng.randf() * 10.0, "g": liquid, "ge": .9, "gate": "", "on": -1.0})
		cyl(r, h(c.x, F3 + 2.2, c.z), .6, 3.2, "glass#a0f0f040", Basis.IDENTITY, 16)
		cyl(r, h(c.x, F3 + 3.9, c.z), .64, .3, "#3a3e42", Basis.IDENTITY, 14)
		pipe(r, h(c.x, F3 + 4.0, c.z), h(c.x, LAB_ROOF - .3, c.z), .08, "#5a5e62", 6)
		solid(r, h(c.x, F3 + 2.0, c.z), Vector3(1.2, 4.0, 1.2))
		var brain := place(r, "hospital/brain", h(c.x, F3 + 1.9, c.z), rng.randf() * 360.0, 1.0)
		if brain != null: brains.append([brain, brain.position, rng.randf() * TAU])
		tanks.append(c)
	var tl := omni(r, h(tc.x, F3 + 1.0, tc.z), TEAL, 2.6, 12.0)
	lamps.append({"l": tl, "e": 2.6, "m": 1, "p": 0.0, "g": null, "ge": 0.0, "gate": "", "on": -1.0})
	for k in 12:
		var a := k / 12.0 * TAU
		bx(r, h(tc.x + cos(a) * 4.1, F3 + .005, tc.z + sin(a) * 4.1), Vector3(1.0, .01, .3), HAZ, false, Basis(Vector3.UP, -a + PI * .5))
	# The pods along the north wall: frosted fronts, teal inside; the one at the middle is his.
	for k in 7:
		var x := 6.0 + k * 2.6
		var at := h(x, F3, 34.4)
		cyl(r, at + Vector3(0, 1.3, 0), .7, 2.6, "#c8ccd0", Basis.IDENTITY, 14)
		var inner := glow_piece(r, at + Vector3(0, 1.3, -.4), Vector3(.9, 2.0, .05), TEAL if k != 3 else Color(.9, .25, .2), .8)
		lamps.append({"l": null, "e": 0.0, "m": 1 if k != 3 else 3, "p": rng.randf() * 10.0, "g": inner, "ge": .8, "gate": "", "on": -1.0})
		if k == 3:
			lucky_pod_glass = MeshInstance3D.new()
			var gm := BoxMesh.new()
			gm.size = Vector3(1.0, 2.1, .04)
			(lucky_pod_glass as MeshInstance3D).mesh = gm
			(lucky_pod_glass as MeshInstance3D).material_override = mat("glass#a0e0e0a0")
			lucky_pod_glass.position = at + Vector3(0, 1.3, -.72)
			roots[r].add_child(lucky_pod_glass)
		else:
			bx(r, at + Vector3(0, 1.3, -.72), Vector3(1.0, 2.1, .04), "glass#d8f0f0a0" if k % 3 != 1 else "glass#20303040")
		solid(r, at + Vector3(0, 1.3, 0), Vector3(1.4, 2.6, 1.4))
	# The benches (white, blue tops), the screens, the instruments; overturned in the fighting.
	for k in 4:
		var c := h(7.0 + (k % 2) * 13.0, F3, 16.0 + int(k / 2) * 5.0)
		desk(r, c, Vector3(3.0, .9, .9), "#2a5aa8", "#e8ecf0")
		monitor(r, c + Vector3(-.8, 1.2, 0), PI * .5, [2, 4, 6, -1][k])
		for j in 4: bx(r, c + Vector3(rng.randf_range(-1.2, 1.2), 1.02, rng.randf_range(-.3, .3)), Vector3(.08, .2, .08), "glass#90e0c080")
	desk(r, h(20.5, F3, 30.0), Vector3(.9, .9, 3.0), "#2a5aa8", "#e8ecf0")
	mess(r, Vector2(5, 13), Vector2(23, 33), F3, 40, 6)
	drag(r, h(9.0, F3, 22.0), h(12.0, F3, 33.0))
	sparks(r, h(22.6, F3 + 3.0, 20.0))
	sparks(r, h(6.0, LAB_ROOF - .8, 30.0))
	# The catwalk at 12 m round the walls, yellow rails; its stair up from the floor; the ladder to the roof hatch.
	for seg: Array in [[4.0, 24.0, 12.0, 13.6], [4.0, 24.0, 34.4, 36.0], [4.0, 5.6, 13.6, 34.4], [22.4, 24.0, 13.6, 34.4]]:
		span(r, h(float(seg[0]), CAT_Y - .1, float(seg[2])), h(float(seg[1]), CAT_Y, float(seg[3])), GRATE, true)
	railing(r, h(5.6, CAT_Y, 13.6), h(14.0, CAT_Y, 13.6), 1.1, YELLOW)
	railing(r, h(15.0, CAT_Y, 13.6), h(22.4, CAT_Y, 13.6), 1.1, YELLOW)
	railing(r, h(5.6, CAT_Y, 34.4), h(13.2, CAT_Y, 34.4), 1.1, YELLOW)
	railing(r, h(14.8, CAT_Y, 34.4), h(22.4, CAT_Y, 34.4), 1.1, YELLOW)
	railing(r, h(5.6, CAT_Y, 13.6), h(5.6, CAT_Y, 34.4), 1.1, YELLOW)
	railing(r, h(22.4, CAT_Y, 13.6), h(22.4, CAT_Y, 34.4), 1.1, YELLOW)
	stair(r, h(8.0, F3, 14.6), h(14.0, CAT_Y, 14.6), 1.6, 20, GRATE, YELLOW)
	railing(r, h(8.0, F3, 15.45), h(14.0, CAT_Y, 15.45), 1.1, YELLOW)
	span(r, h(14.0, CAT_Y - .1, 13.6), h(15.0, CAT_Y, 15.4), GRATE, true)
	for k in 9: bx(r, h(ROOF_LADDER.x, CAT_Y + .3 + k * .45, 35.82), Vector3(.5, .04, .04), "#8a8e90")
	for sx in [-.27, .27]: bx(r, h(ROOF_LADDER.x + sx, CAT_Y + 2.1, 35.82), Vector3(.05, 4.2, .05), "#8a8e90")
	InteriorPlayer.ladders.append([AABB(world(hv(ROOF_LADDER)) + Vector3(-.4, -.2, -.75), Vector3(.8, (LAB_ROOF - CAT_Y) + 1.4, 1.2)), Vector3(0, 0, -1), world(h(ROOF_LADDER.x, LAB_ROOF, 33.6))])
	hum(r, h(14.0, F3 + 2.0, 24.0), "res://assets/audio/nichols/fridge_hum.ogg", -12.0, 8.0)

func roof() -> void:
	var r := R_SKY
	for seg: Array in [[-24, 24, -.1, .3], [-24, 24, 35.7, 36.1], [-24.1, -23.7, 0, 36], [23.7, 24.1, 0, 36]]:
		span(r, h(float(seg[0]), ROOF, float(seg[2])), h(float(seg[1]), ROOF + .9, float(seg[3])), "white_plaster_02|#d8dade", true)
	for seg: Array in [[4, 24, 11.9, 12.2], [4, 24, 35.8, 36.1], [3.9, 4.2, 12, 36], [23.8, 24.1, 12, 36]]:
		span(r, h(float(seg[0]), LAB_ROOF, float(seg[2])), h(float(seg[1]), LAB_ROOF + 1.0, float(seg[3])), "white_plaster_02|#d0d2d6", true)
	# The pad on the laboratory's roof, its H, the flare's stand, the beacon dead on its mast.
	cyl(r, h(14.0, LAB_ROOF + .02, 24.0), 7.0, .04, "#3a3c3e", Basis.IDENTITY, 28)
	for k in 28:
		var a := k / 28.0 * TAU
		bx(r, h(14.0 + cos(a) * 6.6, LAB_ROOF + .05, 24.0 + sin(a) * 6.6), Vector3(1.5, .01, .2), "#d8d0a0", false, Basis(Vector3.UP, -a + PI * .5))
	for x in [12.4, 15.6]: bx(r, h(x, LAB_ROOF + .05, 24.0), Vector3(.5, .01, 4.0), "#e8e8e0")
	bx(r, h(14.0, LAB_ROOF + .05, 24.0), Vector3(2.7, .01, .5), "#e8e8e0")
	bx(r, h(14.0, LAB_ROOF + .5, 31.0), Vector3(.8, 1.0, .6), "#b81e1e")
	pipe(r, h(20.0, LAB_ROOF, 30.0), h(20.0, LAB_ROOF + 5.0, 30.0), .08, "#5a5e62", 6)
	var bea := glow_piece(r, h(20.0, LAB_ROOF + 5.1, 30.0), Vector3(.3, .3, .3), Color(1.0, .15, .1), 3.0)
	lamps.append({"l": null, "e": 0.0, "m": 5, "p": 0.0, "g": bea, "ge": 3.0, "gate": "", "on": -1.0})
	# The roof's machinery.
	for k in 5: bx(r, h(-18.0 + k * 4.4, ROOF + .9, 6.0 + (k % 2) * 18.0), Vector3(2.4, 1.8, 2.0), "#7a7e80")
	bx(r, h(-20.0, ROOF + 1.6, 30.0), Vector3(3.0, 3.2, 3.0), "#8a8e90")
	bx(r, h(ROOF_LADDER.x, LAB_ROOF + .05, 35.2), Vector3(1.0, .1, 1.0), "#2a2c2e")

func skyline() -> void:
	var r := R_SKY
	for i in 30:
		var a := i / 30.0 * TAU
		var d := rng.randf_range(90.0, 160.0)
		var c := Vector3(cos(a) * d, 0, 18.0 + sin(a) * d)
		var th := rng.randf_range(14.0, 70.0)
		var tw := rng.randf_range(14.0, 26.0)
		bx(r, h(c.x, th * .5 - 2.0, c.z), Vector3(tw, th, tw * .8), "#14161a", false, Basis(Vector3.UP, -a))
		for k in rng.randi_range(2, 10):
			bx(r, h(c.x + rng.randf_range(-tw * .4, tw * .4), rng.randf_range(3.0, th - 3.0), c.z) - Vector3(cos(a), 0, sin(a)) * (tw * .42), Vector3(1.6, 1.1, .1), "glow#ffd49a*1.0" if rng.randf() < .7 else "#202428", false, Basis(Vector3.UP, -a + PI * .5))
	fire(r, h(-60.0, 24.0, 70.0), 2.0, 30.0)
	smoke(r, h(-60.0, 30.0, 70.0), 30, 3.0)
	smoke(r, h(70.0, 20.0, -40.0), 24, 3.0)
	span(r, h(-200, -2.4, -200), h(200, -2.0, 240), "#101214", false)
