extends "res://scripts/coop/outer_world.gd"
## 0.65: Market Row and the long bridge (owner, 2026-11-25: "expand the Outer streets and make it more epic with
## buildings that have interiors ... at least 6 enterable buildings with full on interior designs with maximum
## creepiness and horror ... A 2-story boutique "Azrin & Azrael", a Pizza parlor "Airah's Pizzahan", a 2-story
## Shopmart called "Nichols Davao Mart" ... drag a table just to reach something then they can vault over to reach
## the upper floor ... The Bridge should also be way longer than that with some broken cars and stuff"; the plan was
## sketched and approved). Street-local metres as in outer_world.gd.
##
## The way, after the long stair comes up at the kiosk: the river road east is buried under a wreck pile ->
## Airah's Pizzahan (in at its smashed door, over the service counter, out by the kitchen's back door) -> the neon
## court (a light well inside the block) -> the flats (through the ground floor's hall) -> the red-stair alley (the
## eatery up its red stair, optional) -> Nichols Davao Mart by its loading door: its front shut, one escalator down,
## the other broken off 2.3 m up: drag a food-court table under it and climb -> the top floor, east through the wall
## that came down into Azrin & Azrael's top floor -> down its stair and out through the smashed display window ->
## the road past the pile (the funeral parlor beside the bridge, optional) -> stage 17: the long bridge (four red
## arches, wrecks, a stretch with the east half of the deck gone) with the horde behind.

const R_ROW := 8
const R_MART := 9
const R_BOUT := 10
const R_BRIDGE := 11
const ROW_NAMES := ["Market row", "Nichols Davao Mart", "Azrin and Azrael", "Long bridge"]
## Ground floors of the row (the pavement's height), the mart's and the boutique's upper floor.
const G0 := .15
const F1 := 4.55
## The mart's broken escalator: its broken end (the step line there), its top on the upper floor.
## The broken escalator's end: a flat landing (its treads) ESC_LAND deep at 2.6 m, then the steps up. Out of reach
## from the floor even off a jump (the hands catch 2.38 m there); off a jump from a table's top, in reach.
const ESC_BREAK := Vector3(50.0, 2.6, 775.1)
const ESC_LAND := .75
const ESC_TOP := Vector3(50.0, 4.55, 779.0)
const ESC_FOOT_Z := 771.38
## Where a table's middle must be for the climb (x0, x1, z0, z1).
## Where a dragged table counts as under the broken escalator (x0, x1, z0, z1, street-local), and where it is then
## set: upright, long side across, its far edge half a metre short of the end (the climb from its top).
const TABLE_ZONE := [48.2, 51.8, 772.0, 775.8]
const TABLE_SPOT := Vector3(50.0, G0, 774.35)
## Doors and openings on the way (street-local).
const PIZZA_DOOR := Vector3(23.0, G0, 786.0)
const PIZZA_BACK := Vector3(22.1, G0, 771.0)
const FLATS_IN := Vector3(31.0, G0, 763.0)
const FLATS_OUT := Vector3(39.0, G0, 755.4)
const LOADING := Vector3(58.25, G0, 760.0)
const STOCK_DOOR := Vector3(53.2, G0, 764.0)
const BREACH := Vector3(67.0, F1, 774.5)
const BOUT_STAIR_TOP := Vector3(78.1, F1, 772.3)
const BOUT_STAIR_FOOT := Vector3(78.1, G0, 779.9)
const BOUT_WINDOW := Vector3(76.3, G0, 786.0)
const FUNERAL_DOOR := Vector3(91.3, G0, 786.0)

const PLASTER := "painted_plaster_wall|#d8d0bc"
const PLASTER_DIRTY := "worn_cracked_plaster|#b8ae98"
const TILE_W := "marble_tiles|#d8d4c8"
const RED := "#a81c16"
const NEON_PINK := Color(1.0, .3, .62)
const NEON_RED := Color(1.0, .18, .12)
const WARM := Color(1.0, .72, .42)
const COLD := Color(.7, .86, 1.0)

## Pieces that move or change with the night (outer_street.gd).
var row_tables: Array[int] = []
var table_step: StaticBody3D
var rocking: Array = []
var thumps: Array = []
var _plastic: StandardMaterial3D

func build_row() -> void:
	row_ground()
	wreck_pile()
	pizzahan()
	court()
	flats()
	alley()
	eatery()
	mart()
	boutique()
	funeral()
	east_road()
	long_bridge()

# ---------------------------------------------------------------- small makers

func _rects(a0: float, a1: float, b0: float, b1: float, holes: Array) -> Array:
	# (0.65: each hole cut out of every piece it overlaps. The pieces were cut left to right, which assumed no two
	# holes share an x: the boutique's band of upper windows filled its whole ground floor in, the smashed display
	# window included, drawn and solid.)
	var out: Array = [[a0, a1, b0, b1]]
	for h: Array in holes:
		var ha: float = h[0]
		var hb: float = h[1]
		var hlo: float = h[2]
		var hhi: float = h[3]
		var next: Array = []
		for p: Array in out:
			var pa: float = p[0]
			var pb: float = p[1]
			var plo: float = p[2]
			var phi: float = p[3]
			if hb <= pa + .005 or ha >= pb - .005 or hhi <= plo + .005 or hlo >= phi - .005:
				next.append(p)
				continue
			var ca := maxf(ha, pa)
			var cb := minf(hb, pb)
			if ca > pa + .005: next.append([pa, ca, plo, phi])
			if cb < pb - .005: next.append([cb, pb, plo, phi])
			if hlo > plo + .005: next.append([ca, cb, plo, hlo])
			if hhi < phi - .005: next.append([ca, cb, hhi, phi])
		out = next
	return out

## A wall in the plane z = `z` (`t` thick, centred) from x0 to x1, y0 to y1, with holes [xa, xb, ya, yb]; `skin` is
## another material laid thin on its `side` (+1 or -1 in z) face. It collides.
func wall_z(r: int, z: float, x0: float, x1: float, y0: float, y1: float, id: String, holes := [], t := .25, skin := "", side := 1.0, collide := true) -> void:
	for p: Array in _rects(x0, x1, y0, y1, holes):
		var a: float = p[0]
		var b: float = p[1]
		var lo: float = p[2]
		var hi: float = p[3]
		span(r, Vector3(a, lo, z - t * .5), Vector3(b, hi, z + t * .5), id, collide)
		if skin != "": span(r, Vector3(a, lo, z + side * (t * .5 + .003)), Vector3(b, hi, z + side * (t * .5 + .011)), skin)

## The same in the plane x = `x` (holes [za, zb, ya, yb]).
func wall_x(r: int, x: float, z0: float, z1: float, y0: float, y1: float, id: String, holes := [], t := .25, skin := "", side := 1.0, collide := true) -> void:
	for p: Array in _rects(z0, z1, y0, y1, holes):
		var a: float = p[0]
		var b: float = p[1]
		var lo: float = p[2]
		var hi: float = p[3]
		span(r, Vector3(x - t * .5, lo, a), Vector3(x + t * .5, hi, b), id, collide)
		if skin != "": span(r, Vector3(x + side * (t * .5 + .003), lo, a), Vector3(x + side * (t * .5 + .011), hi, b), skin)

## A window in a wall: its frame, and glass ("glass"), teeth of it ("smashed"), nothing ("dark"), boards across
## ("boarded") or a warm lit pane ("lit"). `along_x`: the wall runs along x (the window's plane is z = c.z).
func win(r: int, c: Vector3, w: float, h: float, along_x: bool, state := "glass", bars := false) -> void:
	var B := Basis.IDENTITY if along_x else Basis(Vector3.UP, PI * .5)
	var ax := B.x
	for sg: float in [-1.0, 1.0]:
		bx(r, c + ax * (sg * w * .5), Vector3(.06, h + .06, .14), "#2a2a28", false, B)
		bx(r, c + Vector3.UP * (sg * h * .5), Vector3(w + .06, .06, .14), "#2a2a28", false, B)
	match state:
		"glass": bx(r, c, Vector3(w, h, .015), "glass#1c242ad0", false, B)
		"dark": bx(r, c - B.z * .06, Vector3(w, h, .01), DARK, false, B)
		"lit": bx(r, c - B.z * .05, Vector3(w, h, .01), "glow#d8a060*0.6", false, B)
		"boarded":
			bx(r, c - B.z * .06, Vector3(w, h, .01), DARK, false, B)
			for k in 4: bx(r, c + Vector3.UP * (-h * .35 + k * h * .23) + B.z * .08, Vector3(w + .2, .14, .03), "weathered_planks|#7a6a52", false, B * Basis(Vector3.FORWARD, rng.randf_range(-.08, .08)))
		"smashed":
			bx(r, c - B.z * .06, Vector3(w, h, .01), DARK, false, B)
			for k in 7:
				var e := rng.randi() % 4
				var p := c + (ax * (rng.randf_range(-w, w) * .5) + Vector3.UP * (h * .5 if e == 0 else -h * .5)) if e < 2 else c + (ax * (w * .5 if e == 2 else -w * .5) + Vector3.UP * rng.randf_range(-h, h) * .5)
				bx(r, p, Vector3(rng.randf_range(.08, .25), rng.randf_range(.1, .3), .01), "glass#8aa0a8b0", false, B * Basis(Vector3.FORWARD, rng.randf_range(-1.0, 1.0)))
	if bars:
		var n := maxi(2, int(w / .14))
		for k in n: bx(r, c + ax * (-w * .5 + (k + .5) * w / n) + B.z * .1, Vector3(.02, h, .02), "#2a2a2a", false, B)

## Glass shards scattered on the floor round `c`.
func shards(r: int, c: Vector3, spread: Vector2, n: int) -> void:
	for k in n:
		bx(r, c + Vector3(rng.randf_range(-spread.x, spread.x), .008, rng.randf_range(-spread.y, spread.y)), Vector3(rng.randf_range(.04, .16), .006, rng.randf_range(.04, .14)), "glass#8aa0a8c0", false, Basis(Vector3.UP, rng.randf() * TAU))

## A door leaf standing open: hinged at `hinge` (its foot), `w` wide, swung to `yaw` (0: along +x).
func leaf(r: int, hinge: Vector3, w: float, h: float, yaw: float, id := "dark_wooden_planks|#5a4030", tilt := 0.0) -> void:
	var B := Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, tilt)
	bx(r, hinge + B * Vector3(w * .5, h * .5, 0), Vector3(w, h, .05), id, false, B)
	bx(r, hinge + B * Vector3(w * .85, h * .48, .04), Vector3(.04, .1, .05), "#b8a878", false, B)

## A sign on a wall facing `out`: a dark board and, on it, strokes that read as lettering but are not any (the
## owner gave no names for these places), lit in `col`; a light in front of it flickering in `mode`.
func glyph_sign(r: int, at: Vector3, out: Vector3, w: float, h: float, col: Color, mode := 2, light := true, board := "#1a1214") -> void:
	var B := fbasis(out)
	bx(r, at, Vector3(w, h, .08), board, false, B)
	var id := "glow#%s*2.6" % col.to_html(false)
	var n := maxi(2, int(w / (h * .7)))
	for k in n:
		var cx := -w * .5 + (k + .5) * w / n
		var gw := w / n * .7
		for st in rng.randi_range(2, 4):
			var vertical := rng.randf() < .5
			var sz := Vector3(.04, rng.randf_range(.3, .8) * h * .7, .02) if vertical else Vector3(rng.randf_range(.3, 1.0) * gw, .04, .02)
			bx(r, at + B * Vector3(cx + rng.randf_range(-gw, gw) * .3, rng.randf_range(-h, h) * .22, .05), sz, id, false, B)
	var g := glow_piece(r, at + B * Vector3(0, -h * .5 - .04, .07), Vector3(w * .9, .03, .03), col, 2.4, B)
	if light:
		var l := omni(r, at + out * 1.2, col, .9, 7.5)
		lamp_light(l, .9, mode, "", g, 2.4)
	else:
		lamp_light(null, 0.0, mode, "", g, 2.4)

## A name the owner gave, on a sign: `neon` lit (and flickering in `mode`), else painted.
func name_sign(r: int, at: Vector3, yaw: float, words: String, height: float, col: Color, neon := true, mode := 2) -> Label3D:
	var l := label(r, at, words, height, yaw, col, neon, 70.0)
	if neon:
		l.outline_modulate = Color(col.r * .5, col.g * .3, col.b * .3, .9)
		l.outline_size = 10
		lamps.append({"l": null, "e": 0.0, "m": mode, "p": rng.randf() * 10.0, "g": null, "ge": 0.0, "gate": "", "on": -1.0, "lbl": l, "col": col})
	return l

## A shop mannequin: one of the people's bodies cast in white plastic, stood in a pose.
const MANNEQUIN_BODIES := ["dalaga", "kolehiyala", "tindera", "opisina", "nanay"]
func mannequin(r: int, at: Vector3, yaw: float, body := 0, clip := "idle", t := 0.0, tilt := Vector3.ZERO) -> Node3D:
	var path := "res://assets/characters/zombies/z_%s.glb" % MANNEQUIN_BODIES[body % MANNEQUIN_BODIES.size()]
	if not ResourceLoader.exists(path): return null
	var n := (InteriorModelKit.scene(path)).instantiate() as Node3D
	n.name = "Mannequin"
	roots[r].add_child(n)
	n.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis.from_euler(tilt), at)
	if _plastic == null:
		_plastic = StandardMaterial3D.new()
		_plastic.albedo_color = Color("#e4e0d8")
		_plastic.roughness = .24
		_plastic.clearcoat_enabled = true
		_plastic.clearcoat = .6
	for g in n.find_children("*", "MeshInstance3D", true, false):
		var mi := g as MeshInstance3D
		mi.material_override = _plastic
		mi.visibility_range_end = 48.0
	if tilt == Vector3.ZERO: solid(r, at + Vector3.UP * .9, Vector3(.5, 1.8, .4), Basis(Vector3.UP, yaw))
	InteriorZombie._load_shared()
	var ap := AnimationPlayer.new()
	n.add_child(ap)
	ap.add_animation_library("", InteriorZombie._library)
	if ap.has_animation(clip):
		ap.play(clip)
		ap.seek(t, true)
		ap.pause()
	return n

## A plain block of a building (no way in): walls, a roof slab, rows of windows on the faces in `faces`
## ("n" +z, "s" -z, "e" +x, "w" -x).
func block_bld(r: int, lo: Vector3, hi: Vector3, faces := "n", collide := true) -> void:
	var wall: String = WALL_IDS[rng.randi() % WALL_IDS.size()]
	span(r, lo, hi, wall, collide)
	span(r, Vector3(lo.x + .2, hi.y, lo.z + .2), Vector3(hi.x - .2, hi.y + .05, hi.z - .2), "#3a3834")
	for f in faces:
		var along_x: bool = f == "n" or f == "s"
		var a0 := lo.x if along_x else lo.z
		var a1 := hi.x if along_x else hi.z
		var n := maxi(1, int((a1 - a0) / 3.0))
		var y := lo.y + 3.6
		while y < hi.y - 1.2:
			for k in n:
				var a := a0 + (k + .5) * (a1 - a0) / n
				var c := Vector3(a, y + .2, hi.z + .02) if f == "n" else (Vector3(a, y + .2, lo.z - .02) if f == "s" else (Vector3(hi.x + .02, y + .2, a) if f == "e" else Vector3(lo.x - .02, y + .2, a)))
				var roll := rng.randf()
				win(r, c, 1.3, 1.3, along_x, "lit" if roll < .05 else ("smashed" if roll < .2 else "dark"), roll > .6)
			y += 3.2

## The tables of the row (the mart's food court): rigid, dragged like the store's (street.tables), host-simulated.
func row_table(kind: String, at: Vector3, yaw: float) -> void:
	var friction := PhysicsMaterial.new()
	friction.friction = .85
	friction.bounce = .02
	var t := RigidBody3D.new()
	t.name = "Row table %d" % row_tables.size()
	t.collision_layer = 4
	t.collision_mask = 1 | 2 | 4 | 16
	t.physics_material_override = friction
	t.linear_damp = .6
	t.angular_damp = 2.0
	t.can_sleep = true
	t.continuous_cd = true
	t.set_meta("barricade", true)
	t.set_meta("half", Vector3(1.0, .4, .4) if kind == "long" else Vector3(.45, .4, .45))
	if kind == "long":
		t.mass = 24.0
		s.piece(t, Vector3.UP * .74, Vector3(2.0, .04, .8), "#d8d0c0")
		s.piece(t, Vector3(0, .69, .38), Vector3(2.0, .06, .03), "#8a6a4a")
		for x: float in [-.85, .85]:
			for z: float in [-.32, .32]: s.piece(t, Vector3(x, .36, z), Vector3(.035, .72, .035), "#3a3c3a")
		s.shape(t, Vector3.UP * .73, Vector3(2.0, .06, .8))
		s.shape(t, Vector3.UP * .36, Vector3(1.8, .7, .68))
	else:
		t.mass = 14.0
		s.piece(t, Vector3.UP * .72, Vector3(.9, .04, .9), "#c8b89a")
		for x: float in [-.38, .38]:
			for z: float in [-.38, .38]: s.piece(t, Vector3(x, .36, z), Vector3(.05, .72, .05), "#3a3c3a")
		s.shape(t, Vector3.UP * .72, Vector3(.9, .05, .9))
		s.shape(t, Vector3.UP * .36, Vector3(.82, .7, .82))
	t.position = at
	t.rotation.y = yaw
	if not bool(s.get("authority")):
		t.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		t.freeze = true
	s.add_child(t)
	row_tables.append(s.tables.size())
	s.tables.append(t)

# ---------------------------------------------------------------- ground, the pile

func row_ground() -> void:
	var r := R_ROW
	# The row's base, its top the pavement's height; the pavement along the fronts, its kerb.
	span(r, Vector3(17.0, -.3, 734.0), Vector3(100.2, G0, 786.0), "concrete_floor_02|#6e6a62", true)
	span(r, Vector3(17.0, 0, 786.0), Vector3(100.2, G0, 788.5), WALK, true)
	bx(r, Vector3(58.6, .08, 788.55), Vector3(83.2, .17, .12), CURB)
	# Between the kiosk and the pizza place: a narrow block, its face on the court and the road.
	span(r, Vector3(14.5, 0, 750.0), Vector3(17.0, 11.2, 786.0), WALL_IDS[6], true)
	uppers(r, Vector3(15.75, 0, 786.0), Vector3(0, 0, 1), 2.4, 3.6, 3)
	# Blocks behind the row (nothing in them; the city seen from the bridge and the roofs).
	block_bld(r, Vector3(14.5, 0, 734.0), Vector3(45.0, 14.0, 750.0), "n")
	block_bld(r, Vector3(61.0, 0, 734.0), Vector3(79.0, 12.0, 748.0), "n")
	block_bld(R_BOUT, Vector3(67.0, 0, 748.0), Vector3(83.0, 11.0, 770.0), "e")
	block_bld(R_BOUT, Vector3(79.0, 0, 770.0), Vector3(83.0, 10.5, 786.0), "n")
	block_bld(R_BOUT, Vector3(83.0, 0, 748.0), Vector3(100.2, 9.0, 770.0), "e")
	block_bld(R_BOUT, Vector3(97.0, 0, 770.0), Vector3(100.2, 8.0, 786.0), "n")
	block_bld(R_ROW, Vector3(79.0, 0, 734.0), Vector3(100.2, 13.0, 748.0), "n")

## Upper floors of a facade facing `out` from `c` (its foot), `w` wide, from `y0`, `floors` of them.
func uppers(r: int, c: Vector3, out: Vector3, w: float, y0: float, floors: int, lit_chance := .06) -> void:
	var B := fbasis(out)
	for f in floors:
		var y := y0 + f * 3.2
		var n := maxi(1, int(w / 2.7))
		for i in n:
			var a := -w * .5 + (i + .5) * w / n
			var roll := rng.randf()
			win(r, fp(c, out, a, y + 1.65, .03), 1.3, 1.25, absf(out.z) > .5, "lit" if roll < lit_chance else ("smashed" if roll < .25 else "glass"), true)
			bx(r, fp(c, out, a, y + .92, .1), Vector3(1.6, .08, .2), CONC, false, B)
			if rng.randf() < .3:
				bx(r, fp(c, out, a + .35, y + .55, .3), Vector3(.8, .55, .5), "#c8c8c0", false, B)
		for i in int(w / 2.0): bx(r, fp(c, out, rng.randf_range(-w * .45, w * .45), y + rng.randf_range(.5, 2.5), .012), Vector3(rng.randf_range(.12, .4), rng.randf_range(.8, 2.2), .01), "#3a362f", false, B)

func wreck_pile() -> void:
	var r := R_ROW
	# The road east buried: wrecks and what fell on them, building to river wall, over the wall's line. Taller than
	# anything the hands reach from the cars in front of it (4.8 m).
	heap(r, Vector3(31.0, 0, 786.0), Vector3(39.5, 4.8, 808.7), 46)
	road_car(r, "sedan_wreck", Vector3(29.4, 0, 791.2), .5, true)
	road_car(r, "van_wreck", Vector3(29.7, 0, 796.6), PI * .5 + .18, true)
	road_car(r, "taxi_wreck", Vector3(29.2, 0, 802.4), -.45, true)
	road_car(r, "sedan_wreck", Vector3(33.4, 4.8, 794.0), 1.3, true, "", Vector3(.0, 0, .25), false)
	place(r, "street/jeepney", Vector3(35.2, 4.6, 800.2), 70.0, 1.0, Vector3(12, 0, -20))
	fire(r, Vector3(32.2, 4.85, 797.4), .9, 14.0)
	fire(r, Vector3(30.4, .2, 799.6), .5, 8.0)
	smoke(r, Vector3(34.0, 6.0, 796.0), 22, 1.6)
	litter(r, Vector3(26.0, 0, 795.0), Vector2(3.0, 8.0), 60, ["#3a3a38", "#1a1a1a", "#5a5650", "#8aa0a8"])
	stain(r, "pool_big", Vector3(27.6, 0, 793.0), .4, 1.8, 1.4)

# ---------------------------------------------------------------- Airah's Pizzahan

func pizzahan() -> void:
	var r := R_ROW
	var y := G0
	var wall := "painted_plaster_wall|#e6dcc4"
	var outer := "painted_plaster_wall|#c8b090"
	# Shell: three storeys (flats over the shop, not reached); the shop's ceiling, the slab over it.
	wall_x(r, 17.125, 771.0, 786.0, y, 10.3, outer, [], .25, wall, 1.0)
	wall_x(r, 30.875, 771.0, 786.0, y, 10.3, outer, [], .25, wall, -1.0)
	wall_z(r, 771.125, 17.0, 31.0, y, 10.3, outer, [[PIZZA_BACK.x - .6, PIZZA_BACK.x + .6, y, y + 2.25]], .25, wall, 1.0)
	span(r, Vector3(17.25, 3.75, 771.25), Vector3(30.75, 4.05, 785.75), CONC, true)
	span(r, Vector3(17.25, 3.73, 771.25), Vector3(30.75, 3.75, 785.75), "s:ceiling|#c8c2b4")
	span(r, Vector3(17.0, 10.3, 771.0), Vector3(31.0, 10.6, 786.0), "#3a3834", true)
	span(r, Vector3(17.25, 4.05, 771.25), Vector3(30.75, 10.3, 785.75), outer, true)
	uppers(r, Vector3(24.0, 0, 771.0), Vector3(0, 0, -1), 14.0, 4.05, 2, .1)
	# The front: a glass shopfront in mullions, its door smashed and hanging out; the name over it, in neon.
	var fz := 785.9
	wall_z(r, fz, 17.0, 31.0, 3.4, 10.3, outer, [], .2)
	span(r, Vector3(17.0, 0, fz - .1), Vector3(17.6, 3.4, fz + .1), outer, true)
	span(r, Vector3(30.4, 0, fz - .1), Vector3(31.0, 3.4, fz + .1), outer, true)
	uppers(r, Vector3(24.0, 0, 786.0), Vector3(0, 0, 1), 14.0, 4.6, 2)
	for pane: Array in [[17.6, 19.8], [19.8, 22.0], [22.0, 24.0], [24.0, 26.2], [26.2, 28.3], [28.3, 30.4]]:
		var x: float = pane[0]
		var nx: float = pane[1]
		var door := absf((x + nx) * .5 - PIZZA_DOOR.x) < .5
		bx(r, Vector3(x, 1.7, fz), Vector3(.08, 3.4, .12), "#2a2422")
		if not door:
			span(r, Vector3(x, y, fz - .1), Vector3(nx, .55, fz + .1), RED, true)
			var smashed := rng.randf() < .35
			if smashed:
				win(r, Vector3((x + nx) * .5, 1.95, fz), nx - x - .08, 2.8, true, "smashed")
				shards(r, Vector3((x + nx) * .5, y, fz - .6), Vector2(.8, .5), 10)
			else:
				bx(r, Vector3((x + nx) * .5, 1.95, fz), Vector3(nx - x - .08, 2.8, .015), "glass#1c242ac0")
			solid(r, Vector3((x + nx) * .5, 1.9, fz), Vector3(nx - x, 2.9, .12))
	bx(r, Vector3(30.4, 1.7, fz), Vector3(.08, 3.4, .12), "#2a2422")
	# The door: an empty frame, its glass leaf pulled out and hanging off one hinge onto the pavement.
	var dx0 := PIZZA_DOOR.x - 1.0
	bx(r, Vector3(PIZZA_DOOR.x, 2.55, fz), Vector3(2.0, .1, .14), "#2a2422")
	span(r, Vector3(PIZZA_DOOR.x - 1.0, 2.6, fz - .1), Vector3(PIZZA_DOOR.x + 1.0, 3.4, fz + .1), RED, true)
	leaf(r, Vector3(dx0, y, fz + .1), 1.0, 2.3, -1.2, "glass#3a4a52a0", .1)
	bx(r, PIZZA_DOOR + Vector3(.5, .03, 1.4), Vector3(.95, .04, 2.2), "#2a2422", false, Basis(Vector3.UP, .5))
	bx(r, Vector3(dx0, y + 1.2, fz + .05), Vector3(.06, 2.3, .08), "#2a2422")
	shards(r, PIZZA_DOOR + Vector3(0, 0, .8), Vector2(1.2, .9), 22)
	shards(r, PIZZA_DOOR + Vector3(0, 0, -.8), Vector2(1.0, .7), 14)
	span(r, Vector3(17.2, 3.4, fz + .1), Vector3(30.8, 4.3, fz + .5), "#5a1410")
	name_sign(r, Vector3(24.0, 3.86, fz + .52), 0.0, "Airah's Pizzahan", .56, Color(1.0, .42, .3), true, 2)
	var neon := omni(r, Vector3(24.0, 3.6, 788.2), Color(1.0, .4, .3), 1.2, 10.0)
	lamp_light(neon, 1.2, 2)
	bx(r, Vector3(24.0, 3.3, fz + 1.0), Vector3(13.4, .04, 1.9), "#8a1c16", false, Basis(Vector3.RIGHT, .22))
	# Inside: a checker floor, a red dado, the booths along the west wall.
	span(r, Vector3(17.25, y, 771.25), Vector3(30.75, y + .008, 785.75), "s:checker|#cfc8b8")
	for zz: float in [771.26, 785.74]: span(r, Vector3(17.25, y + .9, zz - .01), Vector3(30.75, y + 1.0, zz + .01), RED)
	span(r, Vector3(17.26, y + .9, 777.8), Vector3(17.27, y + 1.0, 785.7), RED)
	for bz: float in [779.4, 782.0, 784.6]:
		for side: float in [-1.0, 1.0]:
			var sz := bz + side * .78
			span(r, Vector3(17.3, y, sz - .25), Vector3(19.0, y + .46, sz + .25), "velour_velvet|#8a1a18", true)
			span(r, Vector3(17.3, y + .46, sz + side * .2 - .08), Vector3(19.0, y + 1.25, sz + side * .2 + .08), "velour_velvet|#8a1a18", true)
		span(r, Vector3(17.3, y + .72, bz - .4), Vector3(18.9, y + .76, bz + .4), "#d8cfbe", true)
		bx(r, Vector3(18.6, y + .36, bz), Vector3(.1, .72, .1), "#3a3a38")
		for k in 3: bx(r, Vector3(rng.randf_range(17.6, 18.6), y + .775, bz + rng.randf_range(-.3, .3)), Vector3(.24, .012, .24), ["#c8a050", "#e8e4d8", "#d8501a"][k], false, Basis(Vector3.UP, rng.randf() * TAU))
	# The tables down the middle, their cloths, the chairs knocked about; pizza boxes, paper cups.
	for tp: Vector3 in [Vector3(20.6, y, 780.0), Vector3(26.4, y, 780.2), Vector3(20.8, y, 783.6), Vector3(26.6, y, 783.4), Vector3(28.9, y, 781.8)]:
		span(r, tp + Vector3(-.45, .72, -.45), tp + Vector3(.45, .76, .45), "fabric_pattern_07|#c83228", true)
		bx(r, tp + Vector3(0, .36, 0), Vector3(.1, .72, .1), "#2a2a28")
		for k in 3: place(r, "street/plastic_monobloc_chair_01", tp + Vector3(rng.randf_range(-1.0, 1.0), 0, rng.randf_range(-1.0, 1.0)), rng.randf() * 360.0, 1.0, Vector3(85 if rng.randf() < .4 else 0, 0, 0), 40.0)
		for k in 2: bx(r, tp + Vector3(rng.randf_range(-.3, .3), .78, rng.randf_range(-.3, .3)), Vector3(.42, .04, .42), "#e8e0cc", false, Basis(Vector3.UP, rng.randf() * TAU))
	for k in 10: bx(r, Vector3(rng.randf_range(19.5, 30.0), y + .02, rng.randf_range(778.5, 785.0)), Vector3(.42, .04, .42), ["#e8e0cc", "#c8b89a"][k % 2], false, Basis(Vector3.UP, rng.randf() * TAU))
	litter(r, Vector3(24.0, y, 781.8), Vector2(6.0, 3.6), 80, ["#e8e0cc", "#c83228", "#d8d4c4", "#3a3a38"])
	# A television high on the east wall, static; stools along a ledge under it.
	span(r, Vector3(30.2, y + 1.0, 778.6), Vector3(30.75, y + 1.06, 785.2), "#5a3a28", true)
	bx(r, Vector3(30.62, 2.7, 781.8), Vector3(.12, .7, 1.2), "#141414")
	var tv := glow_piece(r, Vector3(30.55, 2.7, 781.8), Vector3(.01, .6, 1.08), Color(.75, .82, .9), 1.4)
	lamp_light(omni(r, Vector3(29.6, 2.6, 781.8), Color(.7, .8, .95), .45, 5.0), .45, 6, "", tv, 1.4)
	# The partition to the kitchen: the service counter across its hatch (vault it: the kitchen door is jammed), the
	# menu boards over it (no words), the till, the warmer; the kitchen door shut with the fridge fallen behind it.
	var pz := 777.6
	wall_z(r, pz, 17.25, 30.75, y, 3.73, wall, [[19.0, 26.6, y, 2.6], [28.4, 29.6, y, 2.2]], .2, wall, 1.0)
	span(r, Vector3(19.0, y, 777.2), Vector3(26.6, y + 1.0, 778.0), RED, true)
	span(r, Vector3(18.95, y + 1.0, 777.15), Vector3(26.65, y + 1.05, 778.05), "marble_tiles|#e0dcd0")
	bx(r, Vector3(20.0, y + 1.25, 777.6), Vector3(.45, .4, .38), "#2a2c2c")
	bx(r, Vector3(25.7, y + 1.4, 777.6), Vector3(1.4, .7, .7), "glass#8a7a5aa0")
	lamp(r, Vector3(25.7, y + 1.7, 777.6), Color(1.0, .6, .3), .3, 3.0, 1, Vector3(1.2, .04, .5))
	for k in 4:
		bx(r, Vector3(20.2 + k * 1.75, 3.1, 777.48), Vector3(1.55, .9, .04), "#1a1a1a")
		for l in 5: bx(r, Vector3(20.2 + k * 1.75 + rng.randf_range(-.55, .55), 3.3 - l * .14, 777.45), Vector3(rng.randf_range(.3, .7), .04, .01), "#e8e4d0")
	leaf(r, Vector3(28.4, y, pz), 1.2, 2.2, 0.0, "#a8aca8")
	solid(r, Vector3(29.0, y + 1.1, pz), Vector3(1.2, 2.2, .12))
	cyl(r, Vector3(29.0, y + 1.6, pz + .03), .15, .02, "#0e1214", Basis(Vector3.RIGHT, PI * .5), 14)
	bx(r, Vector3(29.0, y + .35, pz - .45), Vector3(1.8, .7, .8), "#d8d8d0", true, Basis(Vector3.UP, .08))
	smear(r, "smear_wall", Vector3(28.9, y + 1.2, pz + .12), Vector3(0, 0, 1), .9, .6)
	# The kitchen: the wood oven (embers still glowing), its brick dome; steel benches, the island, shelves, the sink.
	span(r, Vector3(17.25, y, 771.25), Vector3(30.75, y + .008, 777.5), "s:checker|#9a968a")
	span(r, Vector3(17.25, y, 772.0), Vector3(19.7, y + 1.0, 775.4), "red_brick", true)
	for i in 5:
		cyl(r, Vector3(18.4, y + 1.1 + i * .22, 773.7), 1.15 - i * i * .045, .24, "red_brick|#a86a50", Basis.IDENTITY, 18)
	cyl(r, Vector3(18.4, y + 2.4, 773.7), .2, 1.4, "#3a3634", Basis.IDENTITY, 10)
	bx(r, Vector3(19.55, y + 1.35, 773.7), Vector3(.1, .5, .8), DARK)
	var embers := glow_piece(r, Vector3(19.4, y + 1.12, 773.7), Vector3(.3, .08, .6), Color(1.0, .35, .08), 3.2)
	lamp_light(omni(r, Vector3(20.2, y + 1.3, 773.7), Color(1.0, .45, .15), 1.3, 7.0), 1.3, 6, "", embers, 3.2)
	place(r, "nichols/nh_wooden_crate_01", Vector3(18.0, y, 776.6), 10.0)
	for k in 8: cyl(r, Vector3(17.6 + (k % 4) * .3, y + .1 + int(k / 4) * .2, 776.9), .1, .2, "#6a4a32", Basis(Vector3.FORWARD, PI * .5), 8)
	span(r, Vector3(29.0, y, 774.6), Vector3(30.6, y + .9, 777.3), "#a8acac", true)
	span(r, Vector3(23.2, y, 773.2), Vector3(26.4, y + .9, 775.2), "#a8acac", true)
	for k in 6: bx(r, Vector3(23.6 + k * .5, y + .92, 774.2 + rng.randf_range(-.6, .6)), Vector3(.36, .03, .36), ["#e8d8b0", "#c83228", "#e8e4d8"][k % 3], false, Basis(Vector3.UP, rng.randf() * TAU))
	cyl(r, Vector3(29.8, y + 1.15, 776.6), .25, .5, "#c8ccc8", Basis.IDENTITY, 14)
	for lv in 3: span(r, Vector3(18.0, y + .8 + lv * .55, 771.26), Vector3(21.0, y + .83 + lv * .55, 771.6), "#a8acac")
	for k in 14: cyl(r, Vector3(18.3 + (k % 7) * .38, y + .92 + int(k / 7) * .55, 771.43), .07, .2, ["#c83228", "#e0b020", "#2a8a4a", "#e8e4d8"][k % 4], Basis.IDENTITY, 8)
	for k in 5:
		pipe(r, Vector3(23.4 + k * .6, 3.73, 774.2), Vector3(23.4 + k * .6, 3.0, 774.2), .008, "#5a5a56", 4)
		cyl(r, Vector3(23.4 + k * .6, 2.95, 774.2), .17, .03, "#4a4a48", Basis(Vector3.RIGHT, PI * .5), 12)
	var tube := lamp(r, Vector3(24.8, 3.68, 774.2), TUBE, 1.2, 7.5, 2, Vector3(1.2, .04, .1), "", true, true)
	tube["p"] = 3.0
	litter(r, Vector3(24.0, y, 774.0), Vector2(5.0, 2.5), 50, ["#e8e0cc", "#c8a050", "#3a3a38"])
	stain(r, "pool_big", Vector3(25.0, y, 776.4), .5, 1.6, 1.2)
	drag(r, Vector3(25.0, y, 776.4), Vector3(22.2, y, 771.6), false)
	# The walk-in freezer: its door hung open, the cold still in it; what hangs on its hooks wrapped in plastic.
	var fx0 := 26.9
	wall_x(r, fx0, 771.25, 774.4, y, 3.0, "#c8ccc8", [[772.0, 773.2, y, 2.2]], .15)
	wall_z(r, 774.4, fx0, 30.75, y, 3.0, "#c8ccc8", [], .15)
	span(r, Vector3(fx0, 3.0, 771.25), Vector3(30.75, 3.1, 774.4), "#c8ccc8", true)
	leaf(r, Vector3(fx0 - .05, y, 772.0), 1.2, 2.2, PI * .5 + 1.3, "#c8ccc8")
	span(r, Vector3(fx0 + .08, y, 771.3), Vector3(30.7, y + .01, 774.35), "#8a9a9e")
	var cold := lamp(r, Vector3(28.8, 2.9, 772.8), COLD, .8, 4.5, 3, Vector3(.8, .04, .1))
	cold["p"] = 1.7
	for k in 4:
		var hx := 27.6 + k * .8
		pipe(r, Vector3(hx, 3.0, 773.4), Vector3(hx, 2.55, 773.4), .01, "#8a8a88", 4)
		cyl(r, Vector3(hx, 1.75, 773.4), .2, 1.55, "glass#c8c0b8d0", Basis(Vector3.FORWARD, rng.randf_range(-.08, .08)), 10)
		cyl(r, Vector3(hx, 1.75, 773.4), .16, 1.45, "#6a2a24", Basis.IDENTITY, 8)
	stain(r, "pool", Vector3(28.6, y, 773.0), .2, 1.4, 1.0)
	hum(r, Vector3(28.8, 2.0, 772.8), "res://assets/audio/nichols/fridge_hum.ogg", -18.0, 3.0)
	# The back door: kicked off its hinges, lying in the court; a bulb outside it.
	bx(r, PIZZA_BACK + Vector3(-.62, 1.12, 0), Vector3(.08, 2.25, .3), "#4a3828")
	bx(r, PIZZA_BACK + Vector3(.62, 1.12, 0), Vector3(.08, 2.25, .3), "#4a3828")
	bx(r, PIZZA_BACK + Vector3(.3, .03, -1.6), Vector3(1.15, .05, 2.2), "dark_wooden_planks|#5a4030", false, Basis(Vector3.UP, .4))
	for k in 6: bx(r, PIZZA_BACK + Vector3(rng.randf_range(-.6, .6), .01, rng.randf_range(-1.2, .2)), Vector3(.05, .03, rng.randf_range(.2, .5)), "#5a4030", false, Basis(Vector3.UP, rng.randf() * TAU))
	lamp(r, PIZZA_BACK + Vector3(0, 2.6, -.35), WARM, 1.0, 7.0, 2, Vector3(.1, .14, .1))
	# Lights over the dining room: pendants, one swinging dead, one flickering; the neon through the glass.
	for lp: Vector3 in [Vector3(20.6, 3.0, 780.0), Vector3(26.4, 3.0, 780.2), Vector3(20.8, 3.0, 783.6)]:
		pipe(r, lp + Vector3.UP * .73, lp + Vector3.UP * .1, .008, "#2a2a28", 4)
		cyl(r, lp, .22, .2, "#2a2a28", Basis.IDENTITY, 12)
	lamp(r, Vector3(20.6, 2.88, 780.0), WARM, 1.1, 7.0, 3, Vector3(.24, .04, .24))
	lamp(r, Vector3(26.4, 2.88, 780.2), WARM, .9, 6.0, 2, Vector3(.24, .04, .24), "", true, true)
	stain(r, "pool_big", Vector3(23.2, y, 784.0), 1.0, 1.6, 1.3)
	drag(r, Vector3(23.4, y, 785.2), Vector3(23.0, y, 778.4), false)
	smear(r, "smear_wall", Vector3(19.0, 1.6, fz - .12), Vector3(0, 0, -1), 1.2, .8)
	smear(r, "smear_wall", Vector3(22.0, y + .8, 777.15), Vector3(0, 0, 1), 1.4, .7)

# ---------------------------------------------------------------- the neon court

func court() -> void:
	var r := R_ROW
	var y := G0
	# The light well: tall walls all round (the pizza place's back, the narrow block, the south block, the flats);
	# a skylight's frame high over it, most of its glass gone; laundry, wires, units, plants, the wet.
	span(r, Vector3(17.25, y, 757.25), Vector3(30.75, y + .01, 770.95), "dirty_concrete|#5e5a54")
	span(r, Vector3(17.0, 0, 750.0), Vector3(31.0, 13.6, 757.0), "painted_plaster_wall|#9aa49a", true)
	uppers(r, Vector3(24.0, 0, 757.0), Vector3(0, 0, 1), 14.0, 3.6, 3, .12)
	win(r, Vector3(20.0, 1.7, 757.03), 1.2, 1.2, true, "boarded")
	win(r, Vector3(27.5, 1.7, 757.03), 1.2, 1.2, true, "lit", true)
	for k in 12:
		var wx := 17.02 if k % 2 == 0 else 30.98
		var wy := rng.randf_range(3.5, 12.0)
		var wz := rng.randf_range(758.0, 770.0)
		if k % 2 == 0: bx(r, Vector3(wx + .3, wy, wz), Vector3(.5, .45, .8), "#c8c8c0")
		else: bx(r, Vector3(wx - .3, wy, wz), Vector3(.5, .45, .8), "#bcbcb4")
	for k in 6:
		var wz := 758.4 + k * 2.2
		win(r, Vector3(17.01, 5.4 + (k % 3) * 3.2, wz), 1.0, 1.2, false, ["dark", "lit", "dark", "smashed", "dark", "glass"][k], true)
	var top := 13.6
	for i in 8:
		var tx := 17.0 + i * 2.0
		bar(r, Vector3(tx, top, 757.0), Vector3(tx, top, 771.0), .12, "#2a2c2a")
	for i in 5: bar(r, Vector3(17.0, top + .05, 757.0 + i * 3.5), Vector3(31.0, top + .05, 757.0 + i * 3.5), .08, "#2a2c2a")
	for i in 7:
		for k in 4:
			if rng.randf() < .45: continue
			bx(r, Vector3(18.0 + i * 2.0, top + .1, 758.75 + k * 3.5), Vector3(1.9, .02, 3.4), "glass#7a9098a0")
	for k in 4:
		var cy := 4.6 + k * 1.9
		cable(r, Vector3(17.2, cy, 759.0 + k * 3.0), Vector3(30.8, cy - .3, 760.5 + k * 2.6), .5, "#d8d8d0", .012)
		for i in 7: bx(r, Vector3(18.6 + i * 1.8, cy - .55 - sin(i / 6.0 * PI) * .35, 759.0 + k * 3.0 + i * .21), Vector3(rng.randf_range(.4, .7), rng.randf_range(.5, .9), .015), BOARD_COLS[rng.randi() % BOARD_COLS.size()], false, Basis(Vector3.UP, .1))
	for k in 6: cable(r, Vector3(17.1, rng.randf_range(3.0, 9.0), rng.randf_range(758, 770)), Vector3(30.9, rng.randf_range(3.0, 9.0), rng.randf_range(758, 770)), .6)
	# The stair up the west wall to a landing and a boarded door (something behind it knocks).
	stair(r, Vector3(17.9, y, 769.2), Vector3(17.9, 2.75, 763.6), 1.3, 14, "concrete_floor_02|#7a6a5a", "#3a2a1a")
	span(r, Vector3(17.25, 2.55, 761.0), Vector3(18.75, 2.75, 763.6), "concrete_floor_02|#7a6a5a", true)
	for p: Vector3 in [Vector3(18.7, 0, 761.05), Vector3(18.7, 0, 763.55)]: pipe(r, p, p + Vector3.UP * 2.55, .06, "#5a1a14", 8)
	solid(r, Vector3(18.7, 1.3, 762.3), Vector3(.12, 2.55, .12))
	side_wall(r, Vector3(18.6, y, 769.2), Vector3(18.6, 2.75, 763.6), .95, .06, "#5a1a14", 7)
	railing(r, Vector3(18.75, 2.75, 763.55), Vector3(18.75, 2.75, 761.05), 1.0, "#5a1a14")
	railing(r, Vector3(18.75, 2.75, 761.05), Vector3(17.3, 2.75, 761.05), 1.0, "#5a1a14")
	span(r, Vector3(17.15, 2.75, 761.7), Vector3(17.25, 4.95, 762.9), "dark_wooden_planks|#4a3428")
	for k in 4: bx(r, Vector3(17.3, 3.2 + k * .45, 762.3), Vector3(.04, .14, 1.5), "weathered_planks|#7a6a52", false, Basis(Vector3.RIGHT, rng.randf_range(-.1, .1)))
	lamp(r, Vector3(17.45, 5.2, 762.3), WARM, .7, 5.0, 3, Vector3(.1, .14, .1))
	thumps.append([Vector3(17.3, 3.6, 762.3), 14.0, 3.0])
	# The way on: the flats' door under the pink sign; the vending machine humming beside it.
	glyph_sign(r, Vector3(30.82, 3.1, FLATS_IN.z), Vector3(-1, 0, 0), 2.2, .62, NEON_PINK, 2)
	var pink := omni(r, Vector3(28.6, 2.4, 763.0), NEON_PINK, 1.6, 12.0)
	lamp_light(pink, 1.6, 1)
	vending(r, Vector3(30.1, y, 767.2), Vector3(-1, 0, 0), 2, "#c83228")
	vending(r, Vector3(30.1, y, 766.0), Vector3(-1, 0, 0), -1, "#e6e2d8")
	lamp(r, Vector3(30.5, 3.6, 768.6), TUBE, .8, 6.0, 2, Vector3(.1, .05, 1.0))
	# Plants, drums, a chair, the drain, puddles (the neon in them), graffiti strokes on the walls.
	for k in 7: place(r, ["decor/potted_plant_01", "decor/potted_plant_02", "decor/potted_plant_04"][k % 3], Vector3(rng.randf_range(19.5, 29.5), y, 757.6 + rng.randf_range(0, .4)), rng.randf() * 360.0, 1.0, Vector3.ZERO, 40.0)
	for k in 3: cyl(r, Vector3(29.9, y + .45, 758.2 + k * .75), .3, .9, "#2a5a9a", Basis.IDENTITY, 14)
	place(r, "street/plastic_monobloc_chair_01", Vector3(26.0, y, 765.0), 210.0, 1.0, Vector3(85, 0, 0), 40.0)
	span(r, Vector3(17.25, y + .002, 763.85), Vector3(30.75, y + .012, 764.15), "#1a1a18")
	for k in 6: bx(r, Vector3(rng.randf_range(19.0, 29.0), y + .014, rng.randf_range(758.5, 770.0)), Vector3(rng.randf_range(1.0, 2.6), .01, rng.randf_range(.8, 2.0)), "puddle", false, Basis(Vector3.UP, rng.randf() * TAU))
	for k in 16:
		var on_east := k % 2 == 0
		var gx := 30.86 if on_east else 17.27
		bx(r, Vector3(gx, rng.randf_range(.4, 2.2), rng.randf_range(757.6, 770.4)), Vector3(.01, rng.randf_range(.06, .5), rng.randf_range(.1, .9)), ["#1a1a1a", "#3a1a2a", "#2a3a2a"][k % 3], false, Basis(Vector3.RIGHT, rng.randf_range(-.8, .8)))
	litter(r, Vector3(24.0, y, 764.0), Vector2(6.0, 6.0), 70, ["#d8d4c4", "#6a5a3a", "#3a3a38", "#e8e0cc"])
	for k in 5: place(r, "nichols/nh_trashbag", Vector3(rng.randf_range(27.0, 30.4), y, rng.randf_range(769.0, 770.6)), rng.randf() * 360.0)
	drag(r, Vector3(PIZZA_BACK.x, y, 769.6), Vector3(29.6, y, 763.4), false)
	hum(r, Vector3(24.0, 6.0, 764.0), "res://assets/audio/nichols/drip.ogg", -14.0, 5.0)

# ---------------------------------------------------------------- the flats

func flats() -> void:
	var r := R_ROW
	var y := G0
	var outer := "painted_plaster_wall|#c4cfd8"
	var green := "peeling_painted_wall|#9cae98"
	var paper := "decrepit_wallpaper|#c8b898"
	# Shell, four storeys (the floors over the ground floor are not reached: the stair is buried at its top).
	wall_x(r, 31.125, 748.0, 786.0, y, 13.6, outer, [[FLATS_IN.z - .6, FLATS_IN.z + .6, y, y + 2.2]], .25, green, 1.0)
	wall_x(r, 38.875, 748.0, 760.0, y, 13.6, outer, [[FLATS_OUT.z - .6, FLATS_OUT.z + .6, y, y + 2.2]], .25, green, -1.0)
	wall_x(r, 38.875, 760.0, 786.0, y, 13.6, outer, [], .25, paper, -1.0)
	wall_z(r, 748.125, 31.0, 39.0, y, 13.6, outer, [], .25, green, 1.0)
	wall_z(r, 785.875, 31.0, 39.0, y, 13.6, outer, [], .25, paper, -1.0)
	span(r, Vector3(31.25, 3.4, 748.25), Vector3(38.75, 3.7, 785.75), CONC, true)
	span(r, Vector3(31.25, 3.38, 748.25), Vector3(38.75, 3.4, 785.75), "s:ceiling|#b8b4a6")
	span(r, Vector3(31.25, 3.7, 748.25), Vector3(38.75, 13.6, 785.75), outer, true)
	span(r, Vector3(31.0, 13.6, 748.0), Vector3(39.0, 13.9, 786.0), "#3a3834", true)
	uppers(r, Vector3(31.0, 0, 765.0), Vector3(-1, 0, 0), 14.0, 3.7, 3, .1)
	uppers(r, Vector3(39.0, 0, 754.0), Vector3(1, 0, 0), 11.0, 3.7, 3, .05)
	# The door from the court: gone off its hinges, leaning in the hall. The door out to the alley, left open.
	bx(r, FLATS_IN + Vector3(1.4, 1.0, -1.6), Vector3(.05, 2.05, .9), "dark_wooden_planks|#4a3a2c", false, Basis(Vector3.UP, .2) * Basis(Vector3.FORWARD, .15))
	leaf(r, FLATS_OUT + Vector3(-.1, 0, -.6), 1.1, 2.15, -PI * .5 - .25, "#5a6a5a")
	lamp(r, FLATS_OUT + Vector3(.35, 2.55, 0), WARM, .8, 6.0, 2, Vector3(.1, .14, .1))
	# The hall and its corridor: tiles, mailboxes, shoes, a shrine niche with a candle, a pram, the stair up (the
	# floor above came down on it), the door to the flat at the back (shut; something in there), a dying bulb.
	span(r, Vector3(31.25, y, 752.0), Vector3(38.75, y + .008, 766.0), "marble_tiles|#8a8478")
	wall_z(r, 752.0, 31.25, 38.75, y, 3.38, green, [], .15)
	span(r, Vector3(34.0, y, 752.08), Vector3(35.2, y + 2.15, 752.12), "dark_wooden_planks|#4a3a2c")
	smear(r, "smear_wall", Vector3(34.6, 1.0, 752.14), Vector3(0, 0, 1), .9, .7)
	thumps.append([Vector3(34.6, 1.2, 751.0), 10.0, 2.0])
	wall_z(r, 766.0, 31.25, 38.75, y, 3.38, paper, [[33.2, 34.4, y, y + 2.15]], .15, paper, 1.0)
	leaf(r, Vector3(34.4, y, 766.05), 1.2, 2.15, PI + 1.1)
	for k in 12: bx(r, Vector3(31.3, 1.3 + (k % 3) * .32, 753.2 + int(k / 3) * .42), Vector3(.12, .28, .38), "#8a8e8a")
	for k in 8: bx(r, Vector3(rng.randf_range(31.4, 32.2), y + .05, rng.randf_range(757.6, 761.4)), Vector3(.12, .09, .28), ["#2a2a2a", "#c83228", "#e8e4d8", "#2a5aa0"][k % 4], false, Basis(Vector3.UP, rng.randf() * TAU))
	bx(r, Vector3(36.0, 1.5, 765.88), Vector3(.6, .7, .2), "#5a3a28")
	cyl(r, Vector3(36.0, 1.3, 765.8), .04, .12, "#e8e0c8", Basis.IDENTITY, 8)
	var candle := glow_piece(r, Vector3(36.0, 1.38, 765.8), Vector3(.03, .05, .03), Color(1.0, .7, .3), 3.0)
	lamp_light(omni(r, Vector3(36.0, 1.6, 765.4), Color(1.0, .7, .35), .35, 3.0), .35, 6, "", candle, 3.0)
	bx(r, Vector3(37.4, y + .5, 754.0), Vector3(.6, .55, .9), "#2a3a4a", false, Basis(Vector3.UP, .4))
	stair(r, Vector3(38.1, y, 757.6), Vector3(38.1, 3.38, 764.6), 1.2, 18, "marble_tiles|#7a746a", "#3a3a36")
	side_wall(r, Vector3(37.45, y, 757.6), Vector3(37.45, 3.38, 764.6), .9, .06, "#4a4a44", 6)
	heap(r, Vector3(37.5, 1.6, 761.2), Vector3(38.7, 3.38, 764.6), 10, ROUGH)
	lamp(r, Vector3(35.0, 3.3, 759.0), WARM, .9, 7.0, 3, Vector3(.1, .14, .1))
	litter(r, Vector3(35.0, y, 758.0), Vector2(3.4, 5.0), 40)
	stain(r, "drag_a", Vector3(35.6, y, 757.4), .9, 1.6, .6)
	# The family's flat: a living room (the television's static, a shrine of candles and photographs, the sofa, the
	# rocking chair facing the wall), a kitchen corner; through to the children's room (dolls on the bunk, all
	# looking at the door).
	span(r, Vector3(31.25, y, 766.08), Vector3(38.75, y + .008, 785.75), "wood_floor_worn|#7a5a3a")
	place(r, "decor/sofa_02", Vector3(33.6, y, 772.6), 90.0, 1.0, Vector3.ZERO, 40.0)
	solid(r, Vector3(33.4, y + .4, 772.6), Vector3(.9, .8, 2.0))
	place(r, "nichols/nh_coffeetable_01", Vector3(35.0, y, 772.6), 90.0, 1.0, Vector3.ZERO, 40.0)
	bx(r, Vector3(38.4, y + .45, 772.6), Vector3(.5, .9, 1.4), "#4a3a2a", true)
	bx(r, Vector3(38.3, y + 1.25, 772.6), Vector3(.4, .6, .8), "#1a1a1a")
	var tv := glow_piece(r, Vector3(38.09, y + 1.25, 772.6), Vector3(.01, .5, .7), Color(.75, .8, .9), 1.6)
	lamp_light(omni(r, Vector3(37.4, y + 1.3, 772.6), Color(.7, .8, .95), .6, 5.0), .6, 6, "", tv, 1.6)
	hum(r, Vector3(38.0, y + 1.2, 772.6), "res://assets/audio/nichols/arc_buzz.ogg", -24.0, 2.5)
	place(r, "nichols/nh_vintage_cabinet_01", Vector3(31.6, y, 769.0), 90.0, 1.0, Vector3.ZERO, 40.0)
	solid(r, Vector3(31.6, y + .5, 769.0), Vector3(.5, 1.0, 1.0))
	for k in 5:
		var cp := Vector3(31.65, y + 1.05, 768.6 + k * .2)
		cyl(r, cp, .025, .1 + k * .02, "#e8e0c8", Basis.IDENTITY, 6)
		var fl := glow_piece(r, cp + Vector3.UP * (.07 + k * .01), Vector3(.02, .04, .02), Color(1.0, .7, .3), 3.0)
		lamp_light(null, 0.0, 6, "", fl, 3.0)
	lamp_light(omni(r, Vector3(32.2, y + 1.3, 769.0), Color(1.0, .66, .32), .5, 4.0), .5, 6)
	place(r, "nichols/nh_standing_picture_frame_01", Vector3(31.65, y + 1.0, 769.4), 90.0, 1.0, Vector3.ZERO, 30.0)
	place(r, "nichols/nh_fancy_picture_frame_02", Vector3(31.65, y + 1.0, 768.4), 90.0, .8, Vector3.ZERO, 30.0)
	var rc := place(r, "nichols/nh_rockingchair_01", Vector3(32.2, y, 775.0), -90.0, 1.0, Vector3.ZERO, 30.0)
	if rc != null: rocking.append([rc, rc.rotation])
	place(r, "nichols/nh_dining_table", Vector3(36.4, y, 768.6), 0.0, 1.0, Vector3.ZERO, 40.0)
	solid(r, Vector3(36.4, y + .4, 768.6), Vector3(1.6, .8, .9))
	for k in 3: place(r, "nichols/nh_dining_chair_02", Vector3(35.6 + k * .8, y, 767.8 + (k % 2) * 1.7), 180.0 * (k % 2) + rng.randf_range(-20, 20), 1.0, Vector3(80 if k == 2 else 0, 0, 0), 30.0)
	span(r, Vector3(37.9, y, 774.4), Vector3(38.75, y + .9, 776.0), "#c8c4b6", true)
	bx(r, Vector3(38.3, y + .98, 775.0), Vector3(.5, .12, .5), "#3a3a38")
	cyl(r, Vector3(38.3, y + 1.1, 775.0), .14, .16, "#5a5a56", Basis.IDENTITY, 12)
	lamp(r, Vector3(35.0, 3.3, 771.0), WARM, .5, 5.0, 3, Vector3(.1, .14, .1))
	wall_z(r, 776.0, 31.25, 38.75, y, 3.38, paper, [[35.0, 36.2, y, y + 2.15]], .15, "decrepit_wallpaper|#b8a8c0", 1.0)
	span(r, Vector3(31.4, y, 781.0), Vector3(32.4, y + .4, 785.6), "#6a4a3a", true)
	span(r, Vector3(31.4, y + 1.55, 781.0), Vector3(32.4, y + 1.65, 785.6), "#6a4a3a", true)
	for p: Vector3 in [Vector3(32.4, 0, 781.0), Vector3(32.4, 0, 785.6)]: pipe(r, p + Vector3.UP * y, p + Vector3.UP * (y + 1.9), .04, "#6a4a3a", 6)
	span(r, Vector3(31.45, y + .4, 781.1), Vector3(32.35, y + .5, 785.5), "fabric_pattern_07|#c87a9a")
	span(r, Vector3(31.45, y + 1.65, 781.1), Vector3(32.35, y + 1.75, 785.5), "fabric_pattern_07|#7a9ac8")
	place(r, "nichols/nh_porcelain_doll", Vector3(32.0, y + .5, 782.0), 90.0, 1.0, Vector3.ZERO, 25.0)
	place(r, "nichols/nh_antique_doll", Vector3(32.0, y + .5, 783.4), 80.0, 1.0, Vector3.ZERO, 25.0)
	place(r, "nichols/nh_porcelain_doll", Vector3(32.0, y + 1.75, 784.6), 100.0, 1.0, Vector3.ZERO, 25.0)
	place(r, "nichols/nh_antique_doll", Vector3(37.8, y, 777.2), 210.0, 1.0, Vector3.ZERO, 25.0)
	place(r, "nichols/nh_rocking_horse", Vector3(36.6, y, 783.6), 160.0, 1.0, Vector3.ZERO, 30.0)
	span(r, Vector3(37.4, y, 779.0), Vector3(38.75, y + 2.0, 781.6), "wood_cabinet_worn_long|#6a5a4a", true)
	bx(r, Vector3(37.35, y + 1.0, 780.6), Vector3(.03, 1.9, .9), "wood_cabinet_worn_long|#6a5a4a", false, Basis(Vector3.UP, .6))
	smear(r, "smear_wall", Vector3(37.36, y + 1.2, 780.0), Vector3(-1, 0, 0), .8, .5)
	for k in 9: bx(r, Vector3(38.73, rng.randf_range(.8, 1.6), rng.randf_range(782.0, 785.4)), Vector3(.01, .26, .34), BOARD_COLS[rng.randi() % BOARD_COLS.size()], false, Basis(Vector3.RIGHT, rng.randf_range(-.2, .2)))
	litter(r, Vector3(35.0, y, 781.0), Vector2(3.0, 4.0), 30, ["#c83228", "#2a5aa0", "#e0b020", "#2a8a4a", "#e8e4d8"])
	var night := glow_piece(r, Vector3(38.7, y + .35, 778.0), Vector3(.02, .08, .12), Color(1.0, .8, .5), 2.0)
	lamp_light(omni(r, Vector3(38.3, y + .5, 778.0), Color(1.0, .78, .5), .35, 3.0), .35, 1, "", night, 2.0)

# ---------------------------------------------------------------- the red-stair alley

func alley() -> void:
	var r := R_ROW
	var y := G0
	span(r, Vector3(39.0, y, 748.0), Vector3(67.0, y + .01, 760.0), "dirty_concrete|#55514a")
	span(r, Vector3(39.0, y + .002, 753.85), Vector3(67.0, y + .012, 754.15), "#1a1a18")
	for k in 7: bx(r, Vector3(rng.randf_range(41.0, 65.0), y + .014, rng.randf_range(750.0, 759.0)), Vector3(rng.randf_range(1.0, 2.8), .01, rng.randf_range(.8, 2.0)), "puddle", false, Basis(Vector3.UP, rng.randf() * TAU))
	# Its ends: the flats (the door you came out of), and east a wall with what was piled against it.
	span(r, Vector3(66.75, 0, 748.0), Vector3(67.0, 4.6, 760.0), "concrete_block_wall|#8a867a", true)
	for k in 6: place(r, "nichols/nh_wooden_crate_0%d" % (1 + k % 2), Vector3(66.0 - (k % 2) * .7, y + int(k / 3) * .6, 749.0 + (k % 3) * 1.1), rng.randf() * 30.0, 1.0, Vector3.ZERO, 40.0)
	for k in 6: place(r, "nichols/nh_trashbag", Vector3(rng.randf_range(62.0, 66.2), y, rng.randf_range(752.0, 759.0)), rng.randf() * 360.0)
	# The south side: the eatery's back wall, the red stair up it to the eatery's door, its landing; under the stair,
	# sacks and crates. Red sheet sides, a red rail; signs in red on the walls.
	stair(r, Vector3(46.2, y, 749.0), Vector3(53.6, 4.15, 749.0), 1.4, 24, "concrete_floor_02|#8a2a22", "#3a1410")
	span(r, Vector3(53.6, 3.95, 748.0), Vector3(57.2, 4.15, 750.0), "concrete_floor_02|#8a2a22", true)
	for p: Vector3 in [Vector3(57.1, 0, 749.9), Vector3(53.7, 0, 749.9), Vector3(50.0, 0, 749.9)]: pipe(r, p, p + Vector3.UP * (3.95 if p.x > 53 else 2.0), .07, "#7a1a14", 8)
	solid(r, Vector3(57.1, 2.0, 749.9), Vector3(.14, 3.95, .14))
	side_wall(r, Vector3(46.2, y, 749.72), Vector3(53.6, 4.15, 749.72), .95, .05, "#b8221a", 9)
	pipe(r, Vector3(46.2, 1.1, 749.75), Vector3(53.6, 5.1, 749.75), .03, "#d8301e", 6)
	railing(r, Vector3(53.6, 4.15, 750.0), Vector3(57.2, 4.15, 750.0), 1.05, "#b8221a")
	railing(r, Vector3(57.2, 4.15, 750.0), Vector3(57.2, 4.15, 748.05), 1.05, "#b8221a")
	for k in 5: bx(r, Vector3(50.6 + k * .5, y + .25, 748.6), Vector3(.45, .5, .5), "#7a6a4a", false, Basis(Vector3.UP, rng.randf_range(-.2, .2)))
	lamp(r, Vector3(55.6, 6.6, 748.3), WARM, 1.0, 7.0, 2, Vector3(.1, .14, .1))
	glyph_sign(r, Vector3(49.6, 5.4, 747.98), Vector3(0, 0, 1), 1.8, .6, NEON_RED, 2)
	glyph_sign(r, Vector3(59.0, 3.0, 747.98), Vector3(0, 0, 1), 2.4, .5, NEON_RED, 5, false)
	glyph_sign(r, Vector3(42.0, 3.4, 759.98), Vector3(0, 0, -1), 1.6, .55, NEON_RED, 1)
	for k in 3:
		var hz := 751.6 + k * 2.4
		var hx := 43.0 + k * 7.0
		pipe(r, Vector3(hx, 5.6, 748.0), Vector3(hx, 5.6, hz), .03, "#2a2a28", 6)
		bx(r, Vector3(hx, 5.1, hz), Vector3(.2, .9, .5), "#5a0a08")
		bx(r, Vector3(hx + .11, 5.1, hz), Vector3(.01, .7, .36), "glow#ff3020*1.4")
	span(r, Vector3(39.0, 3.2, 748.0), Vector3(45.0, 3.25, 751.8), "rusty_corrugated_iron", false)
	for k in 8: cable(r, Vector3(39.1, rng.randf_range(4.0, 8.0), rng.randf_range(749, 759)), Vector3(66.9, rng.randf_range(4.0, 8.0), rng.randf_range(749, 759)), .8)
	for k in 4: place(r, "street/exterior_aircon_unit", Vector3(rng.randf_range(41.0, 64.0), rng.randf_range(4.0, 6.5), 759.6), 180.0, 1.0, Vector3.ZERO, 60.0)
	# The north side: the mart's back (outer_row.gd `mart` draws the wall and the loading door), the dumpster, the
	# pallets, the pallet truck, crates; a caged lamp over the loading door.
	span(r, Vector3(44.2, y, 758.8), Vector3(46.6, y + 1.3, 759.95), "#2a5a3a", true)
	bx(r, Vector3(45.4, y + 1.36, 759.2), Vector3(2.5, .06, 1.4), "#22482e", false, Basis(Vector3.RIGHT, -.25))
	for k in 3: bx(r, Vector3(61.4 + k * 1.3, y + .08 + (k % 2) * .16, 759.2), Vector3(1.2, .14, 1.0), "weathered_planks|#8a7a5a")
	bx(r, Vector3(55.4, y + .15, 758.4), Vector3(.7, .2, 1.4), "#c8a020", false, Basis(Vector3.UP, .3))
	pipe(r, Vector3(55.3, y + .2, 759.2), Vector3(55.1, y + 1.2, 759.6), .025, "#2a2a28", 6)
	for k in 4: place(r, "nichols/nh_cardboard_box_01", Vector3(rng.randf_range(60.0, 64.0), y, rng.randf_range(757.5, 759.0)), rng.randf() * 360.0, 1.0, Vector3.ZERO, 40.0)
	lamp(r, LOADING + Vector3(0, 3.05, -.35), Color(1.0, .86, .6), 1.4, 9.0, 2, Vector3(.2, .14, .14), "", true, true)
	litter(r, Vector3(53.0, y, 754.0), Vector2(13.0, 5.0), 140)
	drag(r, Vector3(40.6, y, 755.4), Vector3(LOADING.x, y, 758.8), false)
	stain(r, "spatter_floor", Vector3(48.0, y, 756.0), .8, 1.4, 1.2)
	hum(r, Vector3(53.0, 3.0, 754.0), "res://assets/audio/nichols/bulb_hum.ogg", -24.0, 6.0)

# ---------------------------------------------------------------- the eatery up the red stair

func eatery() -> void:
	var r := R_ROW
	var y1 := 4.15
	var outer := "painted_plaster_wall|#d8c8b0"
	var red := "floral_jacquard|#8a2a24"
	# Shell: a shop below (shuttered: not reached), the eatery over it.
	span(r, Vector3(45.0, 0, 734.0), Vector3(61.0, 3.85, 747.75), outer, true)
	span(r, Vector3(57.5, G0, 747.75), Vector3(60.6, 3.0, 747.85), SHUT)
	span(r, Vector3(45.0, 3.85, 734.25), Vector3(61.0, y1, 747.75), CONC, true)
	wall_z(r, 747.875, 45.0, 61.0, y1 - .3, 7.6, outer, [[55.0, 56.2, y1, y1 + 2.2], [47.0, 49.0, 5.0, 6.4], [50.2, 52.2, 5.0, 6.4], [58.0, 60.0, 5.0, 6.4]], .25, red, -1.0)
	wall_z(r, 734.125, 45.0, 61.0, 0, 7.6, outer, [[47.0, 49.0, 5.0, 6.4], [52.0, 54.0, 5.0, 6.4], [57.0, 59.0, 5.0, 6.4]], .25, red, 1.0)
	wall_x(r, 45.125, 734.0, 748.0, y1 - .3, 7.6, outer, [], .25, red, 1.0)
	wall_x(r, 60.875, 734.0, 748.0, y1 - .3, 7.6, outer, [], .25, red, -1.0)
	span(r, Vector3(45.0, 7.3, 734.0), Vector3(61.0, 7.6, 748.0), "#3a3834", true)
	span(r, Vector3(45.25, 7.28, 734.25), Vector3(60.75, 7.3, 747.75), "#3a1a16")
	for wx: float in [48.0, 51.2, 59.0]: win(r, Vector3(wx, 5.7, 748.02), 2.0, 1.4, true, "lit" if wx < 50 else "glass")
	for wx: float in [48.0, 53.0, 58.0]: win(r, Vector3(wx, 5.7, 733.98), 2.0, 1.4, true, "smashed" if wx > 55 else "dark")
	leaf(r, Vector3(56.2, y1, 747.8), 1.2, 2.2, PI * .5 + .3, "#7a1a14")
	# Inside: red carpet, the banquet tables (the party left as it was), lanterns, the karaoke screen still on.
	span(r, Vector3(45.25, y1, 734.25), Vector3(60.75, y1 + .008, 747.75), "dirty_carpet|#6a2a24")
	var tables: Array[Vector3] = [Vector3(48.6, y1, 744.0), Vector3(53.0, y1, 740.6), Vector3(57.6, y1, 743.6), Vector3(48.8, y1, 737.6)]
	for i in tables.size():
		var tp: Vector3 = tables[i]
		cyl(r, tp + Vector3.UP * .74, .95, .06, "#e8e4d8", Basis.IDENTITY, 20)
		cyl(r, tp + Vector3.UP * .45, .9, .55, "#d8d0c4", Basis.IDENTITY, 20)
		cyl(r, tp + Vector3.UP * .79, .45, .03, "glass#a8b8b8b0", Basis.IDENTITY, 16)
		solid(r, tp + Vector3.UP * .38, Vector3(1.5, .76, 1.5))
		for k in 8:
			var a := k * TAU / 8.0
			cyl(r, tp + Vector3(cos(a) * .7, .785, sin(a) * .7), .1, .015, "#f0ece4", Basis.IDENTITY, 10)
			if rng.randf() < .7: place(r, "nichols/nh_dining_chair_02", tp + Vector3(cos(a) * 1.35, 0, sin(a) * 1.35), rad_to_deg(-a) - 90.0 + rng.randf_range(-20, 20), 1.0, Vector3(80 if rng.randf() < .2 else 0, 0, 0), 30.0)
	# The cake on the big table, its candles still lit; balloons up under the ceiling on their strings.
	var cake: Vector3 = tables[1] + Vector3.UP * .8
	cyl(r, cake + Vector3.UP * .1, .3, .2, "#e8d8d0", Basis.IDENTITY, 16)
	cyl(r, cake + Vector3.UP * .27, .22, .14, "#d8a0b0", Basis.IDENTITY, 16)
	for k in 5:
		var cp := cake + Vector3(cos(k * 1.26) * .12, .38, sin(k * 1.26) * .12)
		cyl(r, cp, .008, .08, "#e8e4d0", Basis.IDENTITY, 4)
		var fl := glow_piece(r, cp + Vector3.UP * .06, Vector3(.012, .025, .012), Color(1.0, .75, .35), 3.0)
		lamp_light(null, 0.0, 6, "", fl, 3.0)
	lamp_light(omni(r, cake + Vector3.UP * .6, Color(1.0, .7, .35), .5, 4.0), .5, 6)
	for k in 14:
		var bp := Vector3(rng.randf_range(46.0, 60.0), rng.randf_range(6.6, 7.1), rng.randf_range(735.0, 747.0))
		cyl(r, bp, .16, .3, ["#c83228", "#e0b020", "#2a5aa0", "#e8e4d8", "#c85aa0"][k % 5], Basis.IDENTITY, 10)
		pipe(r, bp + Vector3.DOWN * .15, bp + Vector3(rng.randf_range(-.1, .1), -rng.randf_range(.8, 2.0), rng.randf_range(-.1, .1)), .003, "#e8e4d8", 3)
	for k in 6:
		var lp := Vector3(47.0 + (k % 3) * 5.6, 6.7, 736.5 + int(k / 3) * 7.0)
		pipe(r, lp + Vector3.UP * .6, lp + Vector3.UP * .25, .006, "#2a2a28", 4)
		cyl(r, lp, .28, .5, "#b8201a", Basis.IDENTITY, 12)
		var gl := glow_piece(r, lp, Vector3(.3, .3, .3), Color(1.0, .25, .15), 1.2)
		lamp_light(null, 0.0, 1 if k != 4 else 3, "", gl, 1.2)
	lamp_light(omni(r, Vector3(52.6, 6.4, 740.0), Color(1.0, .3, .2), 1.1, 11.0), 1.1, 1)
	span(r, Vector3(60.0, y1, 740.0), Vector3(60.7, y1 + .9, 742.6), "#2a2422", true)
	bx(r, Vector3(60.55, y1 + 1.55, 741.3), Vector3(.1, .9, 1.5), "#141414")
	var screen := glow_piece(r, Vector3(60.48, y1 + 1.55, 741.3), Vector3(.01, .78, 1.36), Color(.3, .45, 1.0), 1.8)
	lamp_light(omni(r, Vector3(59.4, y1 + 1.5, 741.3), Color(.35, .5, 1.0), .8, 7.0), .8, 6, "", screen, 1.8)
	for sz: float in [739.6, 743.0]: bx(r, Vector3(60.3, y1 + .5, sz), Vector3(.5, 1.0, .45), "#1a1a1a", true)
	place(r, "studio/mic_boom_stand", Vector3(58.6, y1, 741.4), -90.0, 1.0, Vector3(0, 0, 70), 30.0)
	hum(r, Vector3(60.0, y1 + 1.4, 741.3), "res://assets/audio/nichols/arc_buzz.ogg", -22.0, 3.0)
	# A kitchen pass at the west end; plates, bottles; a mahjong table in the corner, its tiles over the floor.
	span(r, Vector3(45.25, y1, 738.0), Vector3(46.4, y1 + 1.0, 745.0), "#6a4a32", true)
	for k in 10: cyl(r, Vector3(45.6 + (k % 2) * .5, y1 + 1.1, 738.6 + k * .6), .04, .26, ["#2a6a3a", "#6a3a1a", "#e8e4d8"][k % 3], Basis.IDENTITY, 6)
	var mt := Vector3(58.0, y1, 736.4)
	span(r, mt + Vector3(-.5, 0, -.5), mt + Vector3(.5, .72, .5), "#2f6a3e", true)
	for k in 30: bx(r, mt + Vector3(rng.randf_range(-1.8, 1.8), .025, rng.randf_range(-1.6, 1.6)), Vector3(.07, .05, .09), "#e8e2cc", false, Basis(Vector3.UP, rng.randf() * TAU))
	litter(r, Vector3(53.0, y1, 741.0), Vector2(7.0, 6.0), 90, ["#e8e4d8", "#c83228", "#e0b020", "#d8a0b0"])
	stain(r, "pool_big", Vector3(53.4, y1, 742.0), .6, 2.0, 1.6)
	stain(r, "spatter_floor", Vector3(49.0, y1, 741.0), 1.6, 1.6, 1.4)
	drag(r, Vector3(55.6, y1, 747.0), Vector3(53.6, y1, 742.4), false)
	smear(r, "smear_wall", Vector3(60.6, y1 + 1.2, 744.6), Vector3(-1, 0, 0), 1.2, .8)

# ---------------------------------------------------------------- Nichols Davao Mart

func mart() -> void:
	var r := R_MART
	var y := G0
	var outer := "painted_plaster_wall|#e2ddd0"
	var inner := "painted_plaster_wall|#e8e4da"
	var roof := 9.2
	# Shell. The back: the loading door (its shutter jammed up short of the top), a staff door; the front shut by
	# its shutters; east, on the upper floor, the wall broken through into Azrin & Azrael.
	wall_x(r, 39.125, 760.0, 786.0, 0, 10.4, outer, [], .25, inner, 1.0)
	wall_x(r, 66.875, 760.0, 786.0, 0, 10.4, outer, [[BREACH.z - 1.5, BREACH.z + 1.5, F1, F1 + 2.5]], .25, inner, -1.0)
	wall_z(r, 760.125, 39.0, 67.0, 0, 10.4, "concrete_block_wall|#9a968a", [[56.5, 60.0, y, y + 2.35]], .25, inner, 1.0)
	span(r, Vector3(56.45, y + 2.35, 759.9), Vector3(60.05, y + 3.0, 760.0), SHUT)
	for k in 3: bx(r, Vector3(56.5 + k * 1.75, y + 2.32, 759.92), Vector3(1.4, .06, .04), "#4a4e4a", false, Basis(Vector3.FORWARD, rng.randf_range(-.05, .05)))
	span(r, Vector3(56.3, y + 3.0, 759.7), Vector3(60.2, y + 3.5, 760.0), "#5a5e5a")
	span(r, Vector3(44.0, y, 759.96), Vector3(45.1, y + 2.1, 760.0), "#5a6a6a")
	for wx: float in [42.0, 48.0, 54.0, 63.0]: win(r, Vector3(wx, 6.4, 759.98), 2.0, 1.4, true, "smashed" if wx == 48.0 else "dark", true)
	# The front: glass and its roll-down shutters, all down; the upper floor's ribbon of windows; the name.
	var fz := 785.875
	wall_z(r, fz, 39.0, 67.0, 3.9, 10.4, outer, [[40.0, 66.0, 5.2, 8.1]], .25, inner, -1.0)
	span(r, Vector3(39.0, 0, fz - .125), Vector3(40.0, 3.9, fz + .125), outer, true)
	span(r, Vector3(66.0, 0, fz - .125), Vector3(67.0, 3.9, fz + .125), outer, true)
	span(r, Vector3(40.0, y, 785.9), Vector3(66.0, 3.4, 785.95), "glass#2a3a44b0")
	for k in 14: bx(r, Vector3(40.0 + k * 2.0, 1.8, 785.92), Vector3(.08, 3.5, .1), "#3a3e3c")
	span(r, Vector3(40.0, y, 786.05), Vector3(66.0, 3.4, 786.12), SHUT, true)
	span(r, Vector3(39.8, 3.4, 785.8), Vector3(66.2, 3.9, 786.3), "#5a5e5a")
	for k in 26:
		var sx := 40.5 + k
		if rng.randf() < .3: smear(r, "smear_wall", Vector3(sx, rng.randf_range(.6, 1.8), 786.14), Vector3(0, 0, 1), .8, .6)
	var wx := 40.0
	while wx < 65.99:
		var nx := minf(wx + 2.6, 66.0)
		bx(r, Vector3(wx, 6.65, fz), Vector3(.12, 2.9, .3), "#3a3e3c")
		var roll := rng.randf()
		if roll < .3: win(r, Vector3((wx + nx) * .5, 6.65, fz), nx - wx - .1, 2.8, true, "smashed")
		else: bx(r, Vector3((wx + nx) * .5, 6.65, fz), Vector3(nx - wx - .1, 2.8, .015), "glass#2a3a44b0")
		wx = nx
	solid(r, Vector3(53.0, 6.6, fz), Vector3(26.0, 4.1, .2))
	span(r, Vector3(40.0, 8.5, 786.0), Vector3(66.0, 10.0, 786.35), "#a81c16")
	name_sign(r, Vector3(53.0, 9.25, 786.37), 0.0, "Nichols Davao Mart", .95, Color(.96, .94, .88), false)
	# Floors: the ground floor's tiles, the stockroom's concrete; the upper floor's slab round the well, its tiles;
	# ceilings under it; the roof round the skylight.
	span(r, Vector3(39.25, y, 764.1), Vector3(66.75, y + .008, 785.75), "marble_tiles|#cfcabd")
	span(r, Vector3(39.25, y, 760.25), Vector3(66.75, y + .008, 763.9), "concrete_floor_02|#6a6660")
	holed(r, Vector3(53.0, F1 - .2, 773.0), Vector3(27.5, .4, 25.5), [46.0, 60.0, 768.0, 779.0], CONC, true)
	holed(r, Vector3(53.0, F1 + .004, 773.0), Vector3(27.5, .01, 25.5), [46.0, 60.0, 768.0, 779.0], TILE_W, false)
	holed(r, Vector3(53.0, F1 - .42, 773.0), Vector3(27.5, .02, 25.5), [46.0, 60.0, 768.0, 779.0], "s:ceiling|#c4c0b4", false)
	holed(r, Vector3(53.0, roof + .15, 773.0), Vector3(28.0, .3, 26.0), [46.0, 60.0, 768.0, 779.0], "#3a3834", true)
	holed(r, Vector3(53.0, roof - .02, 773.0), Vector3(27.5, .02, 25.5), [46.0, 60.0, 768.0, 779.0], "s:ceiling|#c4c0b4", false)
	for e: Array in [[46.0, 60.0, 767.8, 768.0], [46.0, 60.0, 779.0, 779.2], [45.8, 46.0, 768.0, 779.0], [60.0, 60.2, 768.0, 779.0]]:
		span(r, Vector3(e[0], F1 - .45, e[2]), Vector3(e[1], F1 + .02, e[3]), "#c8c4b8")
		span(r, Vector3(e[0], roof - .2, e[2]), Vector3(e[1], roof + .3, e[3]), "#c8c4b8")
	# The columns round the well and through the floors.
	for c: Vector3 in [Vector3(46.0, 0, 768.0), Vector3(60.0, 0, 768.0), Vector3(46.0, 0, 779.0), Vector3(60.0, 0, 779.0), Vector3(45.6, 0, 763.2), Vector3(63.4, 0, 772.0), Vector3(45.6, 0, 782.6), Vector3(63.4, 0, 780.0)]:
		cyl(r, c + Vector3.UP * (roof * .5), .34, roof, "#d8d4c8", Basis.IDENTITY, 16)
		solid(r, c + Vector3.UP * (roof * .5), Vector3(.6, roof, .6))
	# The skylight: an arched glass roof over the well (ribs, purlins, panes; some gone).
	var z := 768.0
	while z <= 779.01:
		var last := Vector3(46.0, roof + .3, z)
		for i in range(1, 9):
			var a := PI * i / 8.0
			var p := Vector3(53.0 - cos(a) * 7.0, roof + .3 + sin(a) * 2.2, z)
			bar(r, last, p, .12, "#3a3e3c")
			last = p
		z += 1.375
	for i in range(9):
		var a := PI * i / 8.0
		var p := Vector3(53.0 - cos(a) * 7.0, roof + .3 + sin(a) * 2.2, 768.0)
		bar(r, p, p + Vector3(0, 0, 11.0), .07, "#3a3e3c")
	for i in range(8):
		var a0 := PI * i / 8.0
		var a1 := PI * (i + 1) / 8.0
		var p0 := Vector3(53.0 - cos(a0) * 7.0, roof + .3 + sin(a0) * 2.2, 0)
		var p1 := Vector3(53.0 - cos(a1) * 7.0, roof + .3 + sin(a1) * 2.2, 0)
		var mid := (p0 + p1) * .5
		var d := p1 - p0
		for k in 8:
			if rng.randf() < .3: continue
			var pz := 768.0 + (k + .5) * 1.375
			bx(r, Vector3(mid.x, mid.y, pz), Vector3(d.length(), .02, 1.3), "glass#8aa0a890", false, Basis(Vector3.FORWARD, atan2(d.y, d.x)))
	# The gallery's railings round the well (glass between posts), open where the escalator lands.
	for e: Array in [[Vector3(46.0, F1, 767.95), Vector3(60.0, F1, 767.95)], [Vector3(45.95, F1, 768.0), Vector3(45.95, F1, 779.0)], [Vector3(60.05, F1, 768.0), Vector3(60.05, F1, 779.0)], [Vector3(46.0, F1, 779.05), Vector3(ESC_TOP.x - .7, F1, 779.05)], [Vector3(ESC_TOP.x + .7, F1, 779.05), Vector3(60.0, F1, 779.05)]]:
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		railing(r, a, b, 1.1, "#8a8e8e", true, 1.4)
		bx(r, (a + b) * .5 + Vector3.UP * .6, Vector3(maxf(absf(b.x - a.x), .02), .9, maxf(absf(b.z - a.z), .02)), "glass#6a8088a0")
	# Banners hanging into the well from the gallery (blank: no words).
	for k in 4:
		var bxp := 47.5 + k * 3.6
		bx(r, Vector3(bxp, F1 - 1.6, 767.85), Vector3(1.1, 3.0, .02), ["#c83228", "#2a5aa0", "#e0b020", "#2a8a4a"][k], false, Basis(Vector3.FORWARD, rng.randf_range(-.05, .05)))
	mart_escalators()
	mart_ground()
	mart_upper()
	# The light: the moon through the skylight; the power out but for the emergency lights and the odd tube.
	for e: Vector3 in [Vector3(39.6, 3.6, 766.0), Vector3(66.4, 3.6, 784.0), Vector3(53.0, 3.6, 764.4), Vector3(39.6, 7.6, 776.0), Vector3(66.4, 7.6, 770.0)]:
		lamp(r, e, Color(1.0, .3, .2), .9, 10.0, 2, Vector3(.3, .1, .1), "", true)
	exit_sign(r, Vector3(STOCK_DOOR.x, 2.75, 764.25), 0.0)
	exit_sign(r, Vector3(64.0, F1 + 2.6, 760.3), 0.0)
	hum(r, Vector3(53.0, 3.0, 773.0), "res://assets/audio/nichols/cellar_tone.ogg", -16.0, 14.0)
	hum(r, Vector3(53.0, 6.0, 773.0), "res://assets/audio/nichols/drip.ogg", -18.0, 6.0)

## The two escalators in the well. The east one came down whole; the west one broke off 2.3 m up (the climb: drag
## a table under its end, climb onto the table, jump for the end, up to the gallery).
func mart_escalators() -> void:
	var r := R_MART
	var y := G0
	var half := .6
	var ex := ESC_TOP.x
	var b0 := ESC_BREAK + Vector3(0, 0, ESC_LAND)
	var slope := Basis(Vector3.RIGHT, -atan2(ESC_TOP.y - b0.y, ESC_TOP.z - b0.z))
	# What is left of it: its broken-off landing (flat treads), then the steps (one sloped walking slab, its treads
	# drawn), the truss under it, its sides (glass and handrails over silver skirts), rebar and cables out of the end.
	bx(r, ESC_BREAK + Vector3(0, -.15, ESC_LAND * .5), Vector3(half * 2.0, .3, ESC_LAND), "#3a3c3c", true)
	bx(r, ESC_BREAK + Vector3(0, -.65, ESC_LAND * .5), Vector3(half * 2.0 + .2, .7, ESC_LAND), "#a8acac", true)
	for k in 2:
		bx(r, ESC_BREAK + Vector3(0, .012, .2 + k * .36), Vector3(half * 2.0 - .08, .02, .3), "#5a5e5e")
		bx(r, ESC_BREAK + Vector3(0, .02, .05 + k * .36), Vector3(half * 2.0 - .1, .025, .03), YELLOW)
	ramp(r, b0, ESC_TOP, half * 2.0, "#3a3c3c", .3)
	var d := ESC_TOP - b0
	var n := 12
	for i in n:
		var p := b0.lerp(ESC_TOP, (i + .5) / n)
		bx(r, p + Vector3.UP * .012, Vector3(half * 2.0 - .08, .02, d.length() / n * .82), "#5a5e5e", false, slope)
		bx(r, p + Vector3.UP * .02 + slope.z * (d.length() / n * .42), Vector3(half * 2.0 - .1, .025, .03), YELLOW, false, slope)
	var mid := (b0 + ESC_TOP) * .5
	bx(r, mid + slope.y * -.65, Vector3(half * 2.0 + .2, 1.0, d.length()), "#a8acac", true, slope)
	for sx: float in [-1.0, 1.0]:
		side_wall(r, Vector3(ex + sx * (half + .05), ESC_BREAK.y, ESC_BREAK.z), Vector3(ex + sx * (half + .05), b0.y, b0.z), .95, .03, "glass#6a8088a0", 2)
		side_wall(r, Vector3(ex + sx * (half + .05), b0.y, b0.z), Vector3(ex + sx * (half + .05), ESC_TOP.y, ESC_TOP.z), .95, .03, "glass#6a8088a0", 6)
		pipe(r, Vector3(ex + sx * (half + .05), ESC_BREAK.y + .98, ESC_BREAK.z), Vector3(ex + sx * (half + .05), b0.y + .98, b0.z), .045, "#141414", 3)
		pipe(r, Vector3(ex + sx * (half + .05), b0.y + .98, b0.z), Vector3(ex + sx * (half + .05), ESC_TOP.y + .98, ESC_TOP.z + .5), .045, "#141414", 8)
		bx(r, mid + slope.x * (sx * (half + .12)) + slope.y * -.3, Vector3(.06, .5, d.length()), "#c8ccc8", false, slope)
		bx(r, ESC_BREAK + Vector3(sx * (half + .12), -.3, ESC_LAND * .5), Vector3(.06, .5, ESC_LAND), "#c8ccc8")
	rebar(r, ESC_BREAK + Vector3.DOWN * .5, Vector3(half, 0, 0), 14, Vector3(0, -.3, -1))
	for k in 5: bar(r, ESC_BREAK + Vector3(rng.randf_range(-.5, .5), -.4, 0), ESC_BREAK + Vector3(rng.randf_range(-.6, .6), -rng.randf_range(.6, 1.0), rng.randf_range(-.3, .1)), .015, "#1a1a1a")
	for k in 4: bx(r, ESC_BREAK + Vector3(rng.randf_range(-.5, .5), rng.randf_range(-.9, -.2), .02), Vector3(rng.randf_range(.2, .5), rng.randf_range(.1, .3), .04), CONC, false, Basis(Vector3.FORWARD, rng.randf_range(-.6, .6)))
	# Its lower half on the floor beside it, in pieces (nothing in reach of the broken end to climb on).
	for k in 6:
		var pz := ESC_FOOT_Z + .4 + k * .6
		bx(r, Vector3(ex + 1.6 + rng.randf_range(-.2, .3), y + .06, pz), Vector3(1.1, .1, .5), ["#5a5e5e", "#a8acac"][k % 2], false, Basis(Vector3.UP, rng.randf_range(-.4, .4)) * Basis(Vector3.RIGHT, rng.randf_range(-.08, .08)))
	bx(r, Vector3(ex + 1.9, y + .14, ESC_FOOT_Z + 1.6), Vector3(.2, .28, 3.4), "#a8acac", false, Basis(Vector3.UP, .25))
	span(r, Vector3(ex - .75, y, ESC_FOOT_Z - .4), Vector3(ex + .75, y + .02, ESC_FOOT_Z + .5), "#6a6e6e")
	shards(r, Vector3(ex + .9, y, 773.5), Vector2(1.4, 2.4), 18)
	# Its light: a tube still hanging over the break from the gallery's underside, failing.
	var t := lamp(r, Vector3(ex - 1.1, 4.4, ESC_BREAK.z - .8), TUBE, 1.5, 8.0, 2, Vector3(.1, .05, 1.2), "", true, true)
	t["p"] = 5.5
	for dz: float in [-.5, .5]: pipe(r, Vector3(ex - 1.1, 9.5, ESC_BREAK.z - .8 + dz), Vector3(ex - 1.1, 4.45, ESC_BREAK.z - .8 + dz), .006, "#1a1a1a", 4)
	# The east one: torn off the gallery, its upper half hanging steep from the edge, the rest crumpled on the floor.
	var e2 := 54.0
	var hang_top := Vector3(e2, F1 - .15, 779.0)
	var hang_foot := Vector3(e2, y + .9, 777.2)
	var hb := Basis(Vector3.RIGHT, -atan2(hang_top.y - hang_foot.y, hang_top.z - hang_foot.z))
	bx(r, (hang_top + hang_foot) * .5, Vector3(1.3, .7, hang_top.distance_to(hang_foot)), "#a8acac", true, hb)
	bx(r, (hang_top + hang_foot) * .5 + hb.y * .36, Vector3(1.1, .02, hang_top.distance_to(hang_foot)), "#3a3c3c", false, hb)
	for k in 3:
		var lz := 770.0 + k * 2.4
		bx(r, Vector3(e2 + rng.randf_range(-.3, .6), y + .28, lz), Vector3(1.3, .55, 2.2), ["#a8acac", "#5a5e5e"][k % 2], k < 2, Basis(Vector3.UP, rng.randf_range(-.3, .3)) * Basis(Vector3.FORWARD, rng.randf_range(-.25, .25)))
	rebar(r, Vector3(e2, F1 - .2, 779.05), Vector3(.6, 0, 0), 12, Vector3(0, -.6, -.4))
	for k in 6: bar(r, Vector3(e2 + rng.randf_range(-.5, .5), F1 - .3, 779.0), Vector3(e2 + rng.randf_range(-.8, .8), rng.randf_range(1.5, 3.5), 778.0 + rng.randf_range(-.5, .5)), .012, "#1a1a1a")
	railing(r, Vector3(e2 - .7, F1, 779.1), Vector3(e2 + .7, F1, 779.1), 1.1, "#8a8e8e")
	for k in 4: bx(r, Vector3(e2 - .6 + k * .4, F1 + .9, 779.12), Vector3(.4, .08, .01), [YELLOW, "#1a1a1a"][k % 2])
	smoke(r, Vector3(e2, 1.0, 772.0), 6, .8, false)

func mart_ground() -> void:
	var r := R_MART
	var y := G0
	var inner := "painted_plaster_wall|#e8e4da"
	# The stockroom across the back: racks of cartons, pallets, a staff clock; double doors through to the floor
	# (one hanging, one gone), a curtain of plastic strips in the doorway.
	wall_z(r, 764.0, 39.25, 66.75, y, F1 - .42, inner, [[STOCK_DOOR.x - 1.2, STOCK_DOOR.x + 1.2, y, y + 2.4]], .2)
	for k in 32: bx(r, Vector3(STOCK_DOOR.x - 1.1 + k * .07, y + 1.25, 764.05), Vector3(.06, 2.3, .005), "glass#c8d8d080", false, Basis(Vector3.UP, rng.randf_range(-.15, .15)))
	leaf(r, Vector3(STOCK_DOOR.x - 1.2, y, 764.1), 1.15, 2.3, -1.4, "#9a9e9c", .06)
	bx(r, Vector3(STOCK_DOOR.x + 1.6, y + .04, 765.4), Vector3(1.15, .05, 2.2), "#9a9e9c", false, Basis(Vector3.UP, .3))
	for rk in 4:
		var rx := 40.2 + rk * 3.2
		for lv in 4:
			span(r, Vector3(rx, y + .2 + lv * .85, 760.4), Vector3(rx + 2.6, y + .25 + lv * .85, 761.6), "#6a6e6a")
			for k in 5:
				if rng.randf() < .3: continue
				bx(r, Vector3(rx + .3 + k * .5, y + .5 + lv * .85, 761.0), Vector3(.45, .5, .9), ["#a8885a", "#8a6a4a", "#c8a870"][k % 3], false, Basis(Vector3.UP, rng.randf_range(-.1, .1)))
		for px: float in [rx, rx + 2.6]: bar(r, Vector3(px, y, 760.4), Vector3(px, y + 3.4, 760.4), .05, "#3a5a8a")
		solid(r, Vector3(rx + 1.3, y + 1.7, 761.0), Vector3(2.6, 3.4, 1.2))
	for k in 4: bx(r, Vector3(61.0 + (k % 2) * 1.3, y + .08 + int(k / 2) * .16, 762.6), Vector3(1.2, .14, 1.0), "weathered_planks|#8a7a5a")
	bx(r, Vector3(63.8, y + .6, 762.6), Vector3(.9, 1.2, .9), "#a8885a", true)
	bx(r, Vector3(66.6, 1.6, 762.0), Vector3(.1, .35, .3), "#3a3a38")
	stain(r, "pool_big", Vector3(58.6, y, 762.4), .3, 1.8, 1.4)
	drag(r, Vector3(58.4, y, 761.4), Vector3(STOCK_DOOR.x, y, 765.6), false)
	lamp(r, Vector3(50.0, F1 - .5, 762.0), TUBE, 1.0, 7.0, 3, Vector3(1.2, .05, .1))
	# The supermarket: gondolas of stock (the real brands), one fallen against the next, stock over the floor;
	# trolleys; the checkouts across the front.
	var goods = preload("res://scripts/coop/store_goods.gd").new()
	var names: Array = goods.names()
	for gi in 3:
		var gx := 40.3 + gi * 1.7
		var fallen := gi == 1
		var gb := Basis.IDENTITY if not fallen else Basis(Vector3.FORWARD, -.32)
		var gc := Vector3(gx, y, 772.6)
		bx(r, gc + gb * Vector3(0, .9, 0), Vector3(.12, 1.8, 14.0), "#c8ccc8", false, gb)
		solid(r, gc + gb * Vector3(0, .9, 0), Vector3(.95, 1.8, 14.0), gb)
		for side: float in [-1.0, 1.0]:
			for lv in 4:
				var sy := .25 + lv * .45
				bx(r, gc + gb * Vector3(side * .25, sy, 0), Vector3(.45, .03, 14.0), "#d8dcd8", false, gb)
				if fallen and side > 0: continue
				var sz := 765.9
				while sz < 779.3:
					var item: String = names[rng.randi() % names.size()]
					var ext: Vector3 = goods.extent(item)
					if rng.randf() < .62:
						var at: Vector3 = gc + gb * Vector3(side * .25, sy + .015, sz - gc.z)
						goods.add(item, Transform3D(gb * Basis(Vector3.UP, side * PI * .5), at))
					sz += ext.x + .02
		if fallen:
			for k in 60:
				var item: String = names[rng.randi() % names.size()]
				goods.add(item, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, PI * .5), Vector3(gx + rng.randf_range(.3, 1.4), y + .04, rng.randf_range(766.0, 779.0))))
	for k in 70:
		var item: String = names[rng.randi() % names.size()]
		goods.add(item, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * (Basis(Vector3.RIGHT, PI * .5) if rng.randf() < .7 else Basis.IDENTITY), Vector3(rng.randf_range(39.6, 46.0), y + .03, rng.randf_range(765.0, 781.0))))
	goods.build(roots[r])
	for k in 5:
		var cp := Vector3(rng.randf_range(44.0, 58.0), y, rng.randf_range(779.6, 781.6))
		var cb := Basis(Vector3.UP, rng.randf() * TAU) * (Basis(Vector3.FORWARD, PI * .5) if k == 2 else Basis.IDENTITY)
		bx(r, cp + cb * Vector3(0, .6, 0), Vector3(.55, .5, .9), "#9aa0a0", false, cb)
		bx(r, cp + cb * Vector3(0, .95, -.48), Vector3(.5, .04, .04), "#c83228", false, cb)
		for wz: float in [-.35, .35]: cyl(r, cp + cb * Vector3(0, .07, wz), .07, .5, "#1a1a1a", cb * Basis(Vector3.FORWARD, PI * .5), 8)
	for ci in 5:
		var cx := 47.0 + ci * 3.0
		span(r, Vector3(cx - .35, y, 781.6), Vector3(cx + .35, y + .9, 784.0), "#c8c4b8", true)
		span(r, Vector3(cx - .3, y + .9, 781.7), Vector3(cx + .3, y + .92, 783.9), "#1a1a1a")
		bx(r, Vector3(cx + .2, y + 1.1, 783.6), Vector3(.35, .3, .35), "#2a2c2c")
		bx(r, Vector3(cx + .2, y + 1.35, 783.5), Vector3(.3, .2, .02), "#0e1214")
		pipe(r, Vector3(cx + .35, y, 781.7), Vector3(cx + .35, y + 1.9, 781.7), .025, "#8a8e8e", 6)
		if ci == 2:
			var g := glow_piece(r, Vector3(cx + .35, y + 1.95, 781.7), Vector3(.12, .12, .02), Color(1.0, .3, .2), 2.0)
			lamp_light(null, 0.0, 5, "", g, 2.0)
	# The food court in the well: the tables (loose: drag one under the broken escalator), stools fallen, the
	# counter of a stall at the side; blood under the escalator's end.
	for k in 8: place(r, "street/plastic_monobloc_chair_01", Vector3(rng.randf_range(46.5, 59.5), y, rng.randf_range(768.6, 778.4)), rng.randf() * 360.0, 1.0, Vector3(85 if k % 3 == 0 else 0, 0, 0), 40.0)
	span(r, Vector3(57.0, y, 778.2), Vector3(59.8, y + 1.05, 779.0), "#c83228", true)
	bx(r, Vector3(58.4, y + 1.08, 778.6), Vector3(2.9, .05, .9), "#e8e4d8")
	for k in 4: bx(r, Vector3(57.4 + k * .7, 2.9, 778.95), Vector3(.6, .5, .03), ["#e0b020", "#c83228"][k % 2])
	stain(r, "pool_big", Vector3(ESC_BREAK.x, y, 774.0), .4, 2.0, 1.6)
	stain(r, "spatter_floor", Vector3(ESC_BREAK.x + .6, y, 776.0), 1.2, 1.6, 1.4)
	drag(r, Vector3(ESC_BREAK.x, y, 774.0), Vector3(STOCK_DOOR.x, y, 766.0), false)
	litter(r, Vector3(53.0, y, 774.0), Vector2(12.0, 9.0), 200)
	# The shops on the ground floor's east side: the pharmacy (its shutter half down), the phone shop (smashed).
	wall_x(r, 60.9, 764.1, 785.75, y, F1 - .42, "#3a3e3c", [[765.0, 771.0, y, 3.2], [772.8, 780.4, y, 3.2]], .12)
	span(r, Vector3(60.84, 1.25, 765.0), Vector3(60.96, 3.2, 771.0), SHUT)
	bx(r, Vector3(60.9, 1.2, 768.0), Vector3(.14, .1, 6.0), "#4a4e4a")
	solid(r, Vector3(60.9, 2.2, 768.0), Vector3(.2, 1.9, 6.0))
	wall_z(r, 771.9, 60.9, 66.75, y, F1 - .42, inner, [], .15)
	for lv in 4:
		span(r, Vector3(65.9, y + .3 + lv * .5, 765.0), Vector3(66.7, y + .33 + lv * .5, 771.4), "#e8e8e0")
		for k in 10: bx(r, Vector3(66.3, y + .45 + lv * .5, 765.4 + k * .6), Vector3(.3, .22, .25), ["#e8e8e0", "#2a8ad0", "#d83a3a"][rng.randi() % 3])
	span(r, Vector3(62.4, y, 766.4), Vector3(63.2, y + 1.0, 770.4), "#e8e8e0", true)
	for z: float in [774.0, 777.4]:
		span(r, Vector3(62.6, y, z), Vector3(64.6, y + .9, z + 1.2), "#1a1a1a", true)
		for k in 4:
			var ph := glow_piece(r, Vector3(63.0 + k * .4, y + .93, z + .6), Vector3(.12, .01, .22), Color(.5, .7, 1.0), .8)
			lamp_light(null, 0.0, [0, 3, 6, 2][k], "", ph, .8)
	shards(r, Vector3(60.4, y, 776.6), Vector2(.6, 3.4), 30)
	# The info desk at the doors, a fallen directory board (blank), a mop bucket; the dead (outer_street.gd).
	span(r, Vector3(51.2, y, 779.6), Vector3(54.8, y + 1.05, 780.4), "#d8d4c8", true)
	bx(r, Vector3(52.0, y + .1, 784.6), Vector3(1.6, .08, 1.0), "#2a5aa0", false, Basis(Vector3.UP, .3))
	cyl(r, Vector3(56.2, y + .2, 784.8), .2, .4, YELLOW, Basis.IDENTITY, 12)

func mart_upper() -> void:
	var r := R_MART
	var y := F1
	var inner := "painted_plaster_wall|#e8e4da"
	# Shopfronts round the gallery: west (televisions, washers), south (toys: dolls on every shelf), east (clothes:
	# mannequins; its back wall the one broken through to the boutique); north, a cafe under the front windows.
	wall_x(r, 43.4, 760.25, 781.6, y, 9.18, inner, [[766.4, 768.6, y, 7.6], [769.0, 777.6, y, 7.6]], .15)
	wall_x(r, 62.6, 765.4, 781.6, y, 9.18, inner, [[772.2, 777.4, y, 7.6]], .15)
	wall_z(r, 765.4, 43.4, 62.6, y, 9.18, inner, [[46.0, 51.0, y, 7.6], [54.6, 60.0, y, 7.6]], .15)
	for e: Array in [[43.4, 769.0, 777.6], [62.6, 772.2, 777.4]]:
		var ex: float = e[0]
		bx(r, Vector3(ex, 7.6, (float(e[1]) + float(e[2])) * .5), Vector3(.2, .2, float(e[2]) - float(e[1])), "#3a3e3c")
		shards(r, Vector3(ex, y, (float(e[1]) + float(e[2])) * .5), Vector2(.5, 2.4), 16)
	# West: the appliance shop.
	for k in 9:
		var tz := 769.4 + k * .9
		bx(r, Vector3(39.5, y + 1.6 + (k % 2) * .8, tz), Vector3(.12, .55, .85), "#141414")
		if k % 3 == 0:
			var g := glow_piece(r, Vector3(39.58, y + 1.6 + (k % 2) * .8, tz), Vector3(.01, .48, .78), Color(.7, .78, .9), 1.2)
			lamp_light(null, 0.0, 6, "", g, 1.2)
	lamp_light(omni(r, Vector3(40.6, y + 1.8, 772.0), Color(.7, .8, .95), .5, 6.0), .5, 6)
	for k in 6: bx(r, Vector3(40.4 + (k % 3) * 1.0, y + .45, 771.0 + int(k / 3) * 3.0), Vector3(.8, .9, .7), "#e8e8e0", true, Basis(Vector3.UP, rng.randf_range(-.2, .2)))
	# South: the toy shop (dolls on every shelf, facing the door).
	for lv in 4:
		span(r, Vector3(46.0, y + .4 + lv * .5, 760.4), Vector3(60.0, y + .43 + lv * .5, 760.9), "#e8d8c8")
		for k in 18:
			if rng.randf() < .35: continue
			place(r, "nichols/nh_porcelain_doll" if (k + lv) % 3 else "nichols/nh_antique_doll", Vector3(46.5 + k * .75, y + .43 + lv * .5, 760.65), 0.0, .7, Vector3.ZERO, 22.0)
	place(r, "nichols/nh_rocking_horse", Vector3(53.0, y, 764.0), 20.0, 1.2, Vector3.ZERO, 30.0)
	for k in 10: bx(r, Vector3(rng.randf_range(46.5, 59.5), y + .12, rng.randf_range(762.0, 767.0)), Vector3(rng.randf_range(.2, .4), .25, rng.randf_range(.2, .4)), ["#c85aa0", "#e0b020", "#2a8ad0", "#d83a3a"][k % 4], false, Basis(Vector3.UP, rng.randf() * TAU))
	lamp(r, Vector3(53.0, 8.5, 764.0), WARM, .6, 6.0, 3, Vector3(.1, .14, .1))
	# East: the clothes shop; mannequins about it, all turned toward the gallery; its back wall broken through.
	for k in 4:
		var rz := 769.0 + k * 3.4
		pipe(r, Vector3(64.2, y + 1.5, rz), Vector3(64.2, y + 1.5, rz + 2.0), .02, "#8a8e8e", 6)
		for p: float in [rz, rz + 2.0]: pipe(r, Vector3(64.2, y, p), Vector3(64.2, y + 1.5, p), .02, "#8a8e8e", 6)
		for g in 8: bx(r, Vector3(64.2, y + 1.0, rz + .15 + g * .24), Vector3(.5, .9, .05), BOARD_COLS[rng.randi() % BOARD_COLS.size()], false, Basis(Vector3.UP, rng.randf_range(-.2, .2)))
	mannequin(r, Vector3(65.8, y, 767.4), -PI * .5, 0)
	mannequin(r, Vector3(65.6, y, 778.8), -PI * .5 + .3, 3)
	mannequin(r, Vector3(63.6, y, 771.0), -PI * .5 - .4, 1)
	# (Low enough to walk over: the feet step up .16 m by themselves, player.gd LIP_HEIGHT; the squad and the infected
	# go through here too.)
	heap(r, Vector3(65.0, y, BREACH.z - 1.6), Vector3(66.75, y + .14, BREACH.z + 1.6), 10, PLASTER_DIRTY)
	rubble(r, Vector3(66.0, y + .1, BREACH.z), Vector3(1.4, .2, 1.6), 20, PLASTER_DIRTY)
	rebar(r, Vector3(66.9, F1 + 2.5, BREACH.z), Vector3(0, 0, 1.4), 10, Vector3(0, -.4, 0))
	smear(r, "smear_wall", Vector3(66.7, y + 1.4, BREACH.z + 2.0), Vector3(-1, 0, 0), 1.1, .8)
	# North: the cafe under the front windows.
	for k in 4:
		var tp := Vector3(48.0 + k * 3.4, y, 783.4)
		cyl(r, tp + Vector3.UP * .73, .4, .04, "#e8e4d8", Basis.IDENTITY, 14)
		pipe(r, tp, tp + Vector3.UP * .72, .04, "#2a2a28", 6)
		for c in 2: place(r, "street/plastic_monobloc_chair_01", tp + Vector3(rng.randf_range(-.8, .8), 0, rng.randf_range(-.8, .8)), rng.randf() * 360.0, 1.0, Vector3(85 if rng.randf() < .3 else 0, 0, 0), 30.0)
	span(r, Vector3(56.4, y, 784.4), Vector3(60.2, y + 1.05, 785.4), "#5a3a28", true)
	litter(r, Vector3(53.0, y, 773.0), Vector2(13.0, 12.0), 160)
	stain(r, "pool_big", Vector3(ESC_TOP.x, y, 780.6), .2, 1.6, 1.3)
	drag(r, Vector3(ESC_TOP.x, y, 780.0), Vector3(61.6, y, 779.0), false)
	drag(r, Vector3(61.6, y, 776.0), Vector3(66.0, y, BREACH.z), false)
	# Lights up here: tubes along the gallery (some flickering, some dead).
	var modes := [2, -1, 0, 3, -1, 2, 4, -1]
	var spots: Array[Vector3] = [Vector3(43.0, 8.8, 766.0), Vector3(43.0, 8.8, 776.0), Vector3(43.0, 8.8, 783.0), Vector3(53.0, 8.8, 782.4), Vector3(63.0, 8.8, 783.0), Vector3(63.0, 8.8, 774.0), Vector3(63.0, 8.8, 765.0), Vector3(53.0, 8.8, 762.4)]
	for i in spots.size():
		if int(modes[i]) < 0: bx(r, spots[i], Vector3(1.2, .05, .14), "#6a6e70")
		else: lamp(r, spots[i], TUBE, 1.1, 9.0, int(modes[i]), Vector3(1.2, .05, .14))

# ---------------------------------------------------------------- Azrin & Azrael

func boutique() -> void:
	var r := R_BOUT
	var y := G0
	var outer := "painted_plaster_wall|#2a2a2c"
	var inner := "white_plaster_02|#e8e4dc"
	var paper := "floral_jacquard|#bcae9e"
	# Shell: two storeys; the west wall is the mart's (broken through upstairs).
	wall_x(r, 78.875, 770.0, 786.0, 0, 9.0, outer, [], .25, inner, -1.0)
	wall_z(r, 770.125, 67.0, 79.0, 0, 9.0, outer, [], .25, inner, 1.0)
	span(r, Vector3(67.0, 8.1, 770.0), Vector3(79.0, 8.4, 786.0), "#2a2826", true)
	span(r, Vector3(67.25, 8.08, 770.25), Vector3(78.75, 8.1, 785.75), "#d8d4cc")
	holed(r, Vector3(72.9, 4.35, 778.0), Vector3(11.5, .4, 15.5), [BOUT_STAIR_TOP.x - .75, 78.75, BOUT_STAIR_TOP.z, BOUT_STAIR_FOOT.z], CONC, true)
	holed(r, Vector3(72.9, F1 + .004, 778.0), Vector3(11.5, .01, 15.5), [BOUT_STAIR_TOP.x - .75, 78.75, BOUT_STAIR_TOP.z, BOUT_STAIR_FOOT.z], "dirty_carpet|#5a4a4c", false)
	holed(r, Vector3(72.9, 4.13, 778.0), Vector3(11.5, .02, 15.5), [BOUT_STAIR_TOP.x - .75, 78.75, BOUT_STAIR_TOP.z, BOUT_STAIR_FOOT.z], "#dcd8d0", false)
	# The front: two display windows (the east one smashed out to the pavement: the way out), the door between
	# (locked), the upper floor's windows; the name, painted on the black band.
	var fz := 785.875
	wall_z(r, fz, 67.0, 79.0, 0, 9.0, outer, [[67.6, 71.4, .55, 3.4], [71.8, 73.6, y, 2.6], [74.2, 78.4, y, 3.4], [68.0, 78.0, 5.2, 7.6]], .25)
	win(r, Vector3(69.5, 1.97, fz + .06), 3.8, 2.85, true, "glass")
	solid(r, Vector3(69.5, 1.97, fz), Vector3(3.8, 2.85, .12))
	span(r, Vector3(71.8, y, fz - .05), Vector3(73.6, 2.6, fz + .05), "glass#2a3a44b0", true)
	bx(r, Vector3(72.7, 1.3, fz + .07), Vector3(1.8, .06, .04), "#c8b878")
	for k in 10: bx(r, Vector3(74.2 + (k % 2) * 4.2 + (-.04 if k % 2 else .04), rng.randf_range(.3, 3.2), fz + .02), Vector3(.05, rng.randf_range(.1, .4), .01), "glass#8aa0a8b0", false, Basis(Vector3.FORWARD, rng.randf_range(-.8, .8)))
	for k in 6: bx(r, Vector3(rng.randf_range(74.4, 78.2), 3.35, fz + .02), Vector3(rng.randf_range(.1, .3), rng.randf_range(.1, .4), .01), "glass#8aa0a8b0", false, Basis(Vector3.FORWARD, rng.randf_range(-.8, .8)))
	shards(r, BOUT_WINDOW + Vector3(0, 0, 1.2), Vector2(2.2, 1.0), 40)
	shards(r, BOUT_WINDOW + Vector3(0, 0, -.8), Vector2(2.0, .6), 20)
	win(r, Vector3(73.0, 6.4, fz + .06), 10.0, 2.4, true, "glass")
	for k in 4: bx(r, Vector3(69.5 + k * 2.4, 6.4, fz + .02), Vector3(.08, 2.4, .1), "#141414")
	solid(r, Vector3(73.0, 6.4, fz), Vector3(10.0, 2.4, .12))
	span(r, Vector3(67.0, 7.9, fz + .12), Vector3(79.0, 8.9, fz + .3), "#121212")
	name_sign(r, Vector3(73.0, 8.4, fz + .31), 0.0, "Azrin & Azrael", .62, Color(.9, .86, .78), false)
	# The display windows: a step, mannequins posed in them; one fallen out through the broken glass.
	span(r, Vector3(67.6, y, 784.6), Vector3(71.4, y + .35, 785.7), "#141414", true)
	mannequin(r, Vector3(68.6, y + .35, 785.1), 0.0, 1)
	mannequin(r, Vector3(70.4, y + .35, 785.1), .2, 0)
	span(r, Vector3(74.2, y, 785.0), Vector3(78.4, y + .06, 785.7), "#141414")
	mannequin(r, Vector3(76.2, y + .1, 787.4), PI * .5, 2, "idle", 0.0, Vector3(PI * .5, 0, 0))
	mannequin(r, Vector3(74.8, y + .06, 784.9), -.3, 4)
	# Inside, ground floor: worn boards, racks of clothes, tables of folded things, the till, fitting rooms
	# (curtains, one half open), a tall mirror; mannequins standing about, facing the stair you come down.
	span(r, Vector3(67.25, y, 770.25), Vector3(78.75, y + .008, 785.75), "wood_floor_worn|#7a5a3e")
	for k in 4:
		var rz := 776.2 + k * 2.1
		pipe(r, Vector3(70.2, y + 1.45, rz), Vector3(73.4, y + 1.45, rz), .02, "#c8b878", 6)
		for p: float in [70.2, 73.4]: pipe(r, Vector3(p, y, rz), Vector3(p, y + 1.45, rz), .02, "#c8b878", 6)
		for g in 10: bx(r, Vector3(70.4 + g * .3, y + .95, rz), Vector3(.04, .95, .5), ["#2a2a2c", "#7a2a2a", "#e8e4dc", "#5a6a7a", "#c8b89a"][rng.randi() % 5], false, Basis(Vector3.UP, rng.randf_range(-.25, .25)))
	for tp: Vector3 in [Vector3(75.0, y, 777.0), Vector3(75.0, y, 781.6)]:
		span(r, tp + Vector3(-.8, 0, -.5), tp + Vector3(.8, .8, .5), "#2a2422", true)
		for k in 6: bx(r, tp + Vector3(rng.randf_range(-.6, .6), .84 + (k % 3) * .05, rng.randf_range(-.35, .35)), Vector3(.4, .05, .3), BOARD_COLS[rng.randi() % BOARD_COLS.size()])
	span(r, Vector3(67.4, y, 774.2), Vector3(68.8, y + 1.0, 777.6), "#141414", true)
	bx(r, Vector3(68.1, y + 1.2, 776.8), Vector3(.4, .35, .4), "#2a2c2c")
	for k in 3:
		var fx := 67.4 + k * 1.25
		span(r, Vector3(fx + 1.2, y, 770.3), Vector3(fx + 1.25, y + 2.3, 772.0), "#141414", true)
		var open := k == 1
		bx(r, Vector3(fx + (.25 if open else .62), y + 1.2, 772.05), Vector3(.5 if open else 1.2, 2.1, .04), "velour_velvet|#6a1a2a", false, Basis(Vector3.UP, rng.randf_range(-.05, .05)))
		pipe(r, Vector3(fx, y + 2.3, 772.05), Vector3(fx + 1.25, y + 2.3, 772.05), .015, "#c8b878", 6)
	stain(r, "pool", Vector3(69.2, y, 771.2), .3, 1.0, .8)
	smear(r, "smear_wall", Vector3(69.2, y + 1.2, 770.27), Vector3(0, 0, 1), .9, .6)
	bx(r, Vector3(71.8, y + 1.2, 770.28), Vector3(1.0, 2.2, .03), "glass#9aa8b0e8")
	bx(r, Vector3(71.8, y + 1.2, 770.27), Vector3(1.1, 2.3, .02), "#c8b878")
	for p: Array in [[Vector3(71.0, y, 779.4), 2.4, 0], [Vector3(74.0, y, 784.0), 2.8, 3], [Vector3(76.6, y, 775.0), -2.4, 1], [Vector3(72.4, y, 772.8), 2.8, 2], [Vector3(68.4, y, 783.0), -2.8, 4]]:
		mannequin(r, p[0], float(p[1]), int(p[2]))
	# The stair down from the floor above, along the east wall: its glass side, the opening's rail upstairs.
	stair(r, BOUT_STAIR_FOOT, BOUT_STAIR_TOP, 1.2, 26, "dark_wooden_planks|#4a3428", "#c8b878")
	side_wall(r, Vector3(BOUT_STAIR_TOP.x - .66, y, BOUT_STAIR_FOOT.z), Vector3(BOUT_STAIR_TOP.x - .66, F1, BOUT_STAIR_TOP.z), .95, .03, "glass#6a8088a0", 8)
	pipe(r, Vector3(BOUT_STAIR_TOP.x - .66, y + .98, BOUT_STAIR_FOOT.z), Vector3(BOUT_STAIR_TOP.x - .66, F1 + .98, BOUT_STAIR_TOP.z), .03, "#c8b878", 6)
	railing(r, Vector3(BOUT_STAIR_TOP.x - .72, F1, BOUT_STAIR_TOP.z + .05), Vector3(BOUT_STAIR_TOP.x - .72, F1, BOUT_STAIR_FOOT.z), 1.05, "#c8b878")
	railing(r, Vector3(BOUT_STAIR_TOP.x - .72, F1, BOUT_STAIR_FOOT.z + .02), Vector3(78.7, F1, BOUT_STAIR_FOOT.z + .02), 1.05, "#c8b878")
	# Track lights, almost all dead; two on, failing, on the mannequins; the red exit sign over the door.
	for k in 3: bar(r, Vector3(68.0, 4.1, 773.0 + k * 4.0), Vector3(77.0, 4.1, 773.0 + k * 4.0), .04, "#141414")
	var sp1 := spot(r, Vector3(71.0, 4.05, 777.0), Vector3(71.0, y, 779.4), WARM, 2.4, 7.0, 22.0, true)
	lamp_light(sp1, 2.4, 2)
	var sp2 := spot(r, Vector3(74.0, 4.05, 781.0), Vector3(74.0, y + 1.0, 784.0), WARM, 1.8, 7.0, 24.0)
	lamp_light(sp2, 1.8, 3)
	exit_sign(r, Vector3(72.7, 3.0, 785.6), PI)
	# Upstairs: the formal room. Gowns on mannequins in a half ring facing the hole in the wall you come through, a
	# long mirror, the seamstress's table, bolts of cloth; the chandelier dying.
	wall_z(r, 785.6, 67.25, 78.75, F1, 8.08, paper, [[68.0, 78.0, 5.2, 7.6]], .02, "", 1.0, false)
	span(r, Vector3(78.72, F1, 779.9), Vector3(78.74, 8.08, 785.6), paper)
	span(r, Vector3(67.26, F1, 776.2), Vector3(67.28, 8.08, 785.6), paper)
	for k in 5:
		var a := -.9 + k * .45
		var mp := BREACH + Vector3(5.0, 0, 0) + Vector3(cos(a) * 2.6, 0, sin(a) * 2.6)
		mannequin(r, mp, atan2(BREACH.x - mp.x, BREACH.z - mp.z) + PI, k % 5)
		cyl(r, mp + Vector3(0, .55, 0), .55, 1.1, ["#e8e4dc", "#d8d0c8", "#e8e0e0"][k % 3], Basis.IDENTITY, 14)
	bx(r, Vector3(74.0, F1 + 1.5, 785.55), Vector3(4.0, 2.6, .03), "glass#9aa8b0e8")
	span(r, Vector3(68.0, F1, 783.2), Vector3(70.0, F1 + .8, 784.4), "#6a4a32", true)
	bx(r, Vector3(68.6, F1 + .95, 783.8), Vector3(.5, .3, .25), "#e8e4dc")
	for k in 6: cyl(r, Vector3(70.6 + k * .45, F1 + .2, 784.8), .18, 1.4, ["floral_jacquard|#c8a8a8", "velour_velvet|#5a1a2a", "fabric_pattern_07|#d8c8a8"][k % 3], Basis(Vector3.FORWARD, PI * .5), 10)
	place(r, "nichols/nh_sofa_01", Vector3(70.2, F1, 784.8), 180.0, 1.0, Vector3.ZERO, 30.0)
	solid(r, Vector3(70.2, F1 + .4, 784.8), Vector3(2.0, .8, .9))
	place(r, "nichols/nh_chandelier_01", Vector3(73.0, 7.0, 777.0), 0.0, 1.0, Vector3.ZERO, 40.0)
	lamp(r, Vector3(73.0, 6.8, 777.0), WARM, 1.3, 9.0, 3, Vector3(.4, .1, .4), "", true, true)
	lamp(r, Vector3(67.6, 7.6, 778.0), Color(1.0, .3, .2), .8, 8.0, 2, Vector3(.1, .1, .3))
	for k in 3: mannequin(r, Vector3(rng.randf_range(70.0, 76.0), F1 + .12, rng.randf_range(780.0, 784.0)), rng.randf() * TAU, k + 1, "idle", 0.0, Vector3(PI * .5, 0, rng.randf_range(-.3, .3)))
	litter(r, Vector3(73.0, F1, 777.0), Vector2(5.0, 6.0), 60, ["#e8e4dc", "#c8b89a", "#7a2a2a"])
	stain(r, "drag_a", Vector3(70.0, F1, BREACH.z), PI * .5, 1.6, .6)
	litter(r, Vector3(73.0, y, 779.0), Vector2(5.0, 6.0), 60, ["#e8e4dc", "#c8b89a", "#7a2a2a", "#2a2a2c"])
	hum(r, Vector3(73.0, 6.0, 777.0), "res://assets/audio/nichols/bulb_hum.ogg", -24.0, 5.0)

# ---------------------------------------------------------------- the funeral parlor

func funeral() -> void:
	var r := R_BOUT
	var y := G0
	var outer := "painted_plaster_wall|#d8d4c8"
	var wood := "dark_paneled_wood|#6a4a32"
	wall_x(r, 83.125, 770.0, 786.0, 0, 5.2, outer, [], .25, wood, 1.0)
	wall_x(r, 96.875, 770.0, 786.0, 0, 5.2, outer, [], .25, wood, -1.0)
	wall_z(r, 770.125, 83.0, 97.0, 0, 5.2, outer, [], .25, wood, 1.0)
	span(r, Vector3(83.0, 4.0, 770.0), Vector3(97.0, 4.3, 786.0), "#3a3834", true)
	span(r, Vector3(83.25, 3.98, 770.25), Vector3(96.75, 4.0, 785.75), "#d8d0c0")
	var fz := 785.875
	wall_z(r, fz, 83.0, 97.0, 0, 5.2, outer, [[84.0, 88.0, 1.0, 3.0], [88.9, 92.1, y, 2.8], [92.6, 96.4, 1.0, 3.0]], .25, wood, -1.0)
	for wx: float in [86.0, 94.5]:
		win(r, Vector3(wx, 2.0, fz + .06), 4.0, 2.0, true, "glass")
		solid(r, Vector3(wx, 2.0, fz), Vector3(4.0, 2.0, .12))
		bx(r, Vector3(wx, 2.0, fz - .14), Vector3(4.0, 2.0, .04), "velour_velvet|#4a0e14")
	span(r, Vector3(88.9, y, fz - .05), Vector3(90.5, 2.8, fz + .05), "glass#2a3a44b0", true)
	leaf(r, Vector3(92.1, y, fz + .08), 1.55, 2.6, PI - 1.2, "glass#3a4a52a0")
	bx(r, Vector3(90.5, 1.4, fz), Vector3(.06, 2.8, .14), "#2a2a28")
	span(r, Vector3(85.0, 4.4, fz + .15), Vector3(95.0, 5.1, fz + .3), "#1a3a2a")
	glyph_sign(r, Vector3(90.0, 4.75, fz + .35), Vector3(0, 0, 1), 8.0, .5, Color(.95, .92, .84), 0, false, "#1a3a2a")
	for lx: float in [84.4, 95.6]:
		pipe(r, Vector3(lx, y, 787.4), Vector3(lx, 2.6, 787.4), .05, "#2a2a28", 8)
		lamp(r, Vector3(lx, 2.75, 787.4), WARM, .5, 5.0, 3, Vector3(.24, .3, .24))
	# The chapel: carpet, chairs in rows facing the two caskets, wreaths on their stands, candles, the portrait
	# between; one casket open (the lining, someone under a sheet in it), the other shut, scratched from inside.
	span(r, Vector3(83.25, y, 770.25), Vector3(96.75, y + .008, 785.75), "dirty_carpet|#4a1e22")
	for row in 4:
		for k in 8:
			if k == 5 or k == 6: continue
			place(r, "street/plastic_monobloc_chair_01", Vector3(84.8 + k * 1.15, y, 780.0 + row * 1.2), 0.0 + rng.randf_range(-15, 15), 1.0, Vector3(85 if rng.randf() < .12 else 0, 0, 0), 30.0)
	for ck in 2:
		var cx := 87.0 + ck * 6.0
		span(r, Vector3(cx - 1.2, y, 777.0), Vector3(cx + 1.2, y + .55, 777.9), "#2a2422", true)
		span(r, Vector3(cx - 1.1, y + .55, 776.95), Vector3(cx + 1.1, y + 1.15, 777.95), "dark_wooden_planks|#3a2216", true)
		if ck == 0:
			span(r, Vector3(cx - 1.0, y + 1.0, 777.05), Vector3(cx + 1.0, y + 1.16, 777.85), "velour_velvet|#e8e0d8")
			bx(r, Vector3(cx, y + 1.5, 776.9), Vector3(2.2, .06, .9), "dark_wooden_planks|#3a2216", false, Basis(Vector3.RIGHT, -1.1))
			cyl(r, Vector3(cx + .1, y + 1.22, 777.45), .2, 1.6, "#e8e4dc", Basis(Vector3.FORWARD, PI * .5), 10)
			cyl(r, Vector3(cx - .85, y + 1.24, 777.45), .13, .2, "#e8e4dc", Basis(Vector3.FORWARD, PI * .5), 10)
			stain(r, "pool", Vector3(cx, y, 778.2), .3, 1.0, .8)
		else:
			for k in 5: bx(r, Vector3(cx + rng.randf_range(-.9, .9), y + 1.16, 777.45 + rng.randf_range(-.3, .3)), Vector3(.02, .005, rng.randf_range(.2, .5)), "#c8a888", false, Basis(Vector3.UP, rng.randf() * TAU))
			smear(r, "smear_wall", Vector3(cx, y + .9, 777.97), Vector3(0, 0, 1), .8, .5)
			thumps.append([Vector3(cx, y + 1.0, 777.4), 8.0, 4.0])
		for side: float in [-1.0, 1.0]:
			var wp := Vector3(cx + side * 1.6, y, 777.2)
			pipe(r, wp, wp + Vector3.UP * 1.4, .02, "#2a2a28", 4)
			for k in 12:
				var a := k * TAU / 12.0
				bx(r, wp + Vector3(cos(a) * .35, 1.6 + sin(a) * .35, 0), Vector3(.14, .14, .1), ["#e8e4dc", "#c8a8d8", "#e0d080"][k % 3])
			cyl(r, wp + Vector3(side * .3, .7, -.3), .03, 1.4, "#e8e0c8", Basis.IDENTITY, 6)
			var fl := glow_piece(r, wp + Vector3(side * .3, 1.45, -.3), Vector3(.03, .05, .03), Color(1.0, .7, .3), 3.0)
			lamp_light(null, 0.0, 6, "", fl, 3.0)
	place(r, "nichols/nh_standing_picture_frame_01", Vector3(90.0, y + 1.1, 776.8), 0.0, 1.6, Vector3.ZERO, 30.0)
	span(r, Vector3(89.4, y, 776.5), Vector3(90.6, y + 1.1, 777.1), "#2a2422", true)
	lamp_light(omni(r, Vector3(90.0, 2.0, 778.4), Color(1.0, .66, .32), .9, 8.0), .9, 6)
	wall_z(r, 776.0, 83.25, 96.75, y, 3.98, wood, [[93.5, 94.7, y, y + 2.15]], .15)
	for k in 10: bx(r, Vector3(84.0 + k * 1.3, 2.2, 776.1), Vector3(.9, 3.6, .04), "velour_velvet|#3a0a10", false, Basis(Vector3.UP, rng.randf_range(-.1, .1)))
	leaf(r, Vector3(93.5, y, 775.95), 1.2, 2.15, -1.3, wood)
	# The back room: the steel table (someone on it under a sheet), the cabinet, the sink, the coffins stacked.
	span(r, Vector3(83.25, y, 770.25), Vector3(96.75, y + .008, 775.9), "marble_tiles|#b8bcb8")
	span(r, Vector3(88.0, y, 772.4), Vector3(90.2, y + .85, 773.3), "#a8acac", true)
	bx(r, Vector3(89.1, y + .95, 772.85), Vector3(1.9, .18, .6), "#e8e4dc")
	bx(r, Vector3(88.3, y + 1.0, 772.85), Vector3(.3, .2, .3), "#e8e4dc")
	stain(r, "pool_big", Vector3(89.1, y, 772.0), .2, 1.4, 1.2)
	span(r, Vector3(83.3, y, 770.4), Vector3(84.0, y + 2.0, 772.4), "#c8ccc8", true)
	for k in 8: cyl(r, Vector3(83.65, y + .9 + (k % 4) * .3, 770.6 + int(k / 4) * .8), .05, .2, ["#a8c8a8", "#c8a888", "glass#c8d8d0a0"][k % 3], Basis.IDENTITY, 6)
	span(r, Vector3(95.6, y, 770.4), Vector3(96.7, y + .9, 772.0), "#c8ccc8", true)
	for k in 3: span(r, Vector3(84.4, y + k * .62, 774.2), Vector3(86.6, y + .6 + k * .62, 775.8), "dark_wooden_planks|#4a2a1a", true)
	var cold := lamp(r, Vector3(89.0, 3.9, 773.0), COLD, 1.0, 7.0, 3, Vector3(1.2, .04, .1), "", true, true)
	cold["p"] = 2.2
	hum(r, Vector3(89.0, 2.0, 773.0), "res://assets/audio/nichols/fridge_hum.ogg", -20.0, 3.0)
	litter(r, Vector3(90.0, y, 780.0), Vector2(6.0, 5.0), 60, ["#e8e4dc", "#c8a8d8", "#e0d080", "#3a3a38"])
	drag(r, Vector3(94.1, y, 775.0), Vector3(94.0, y, 780.6), false)

# ---------------------------------------------------------------- the road past the pile

func east_road() -> void:
	var r := R_BOUT
	# Past the pile the road runs on to the bridge: the stalled bus (riverside), a car on the pavement, glass.
	road_car(r, "sedan_wreck", Vector3(81.4, G0, 789.4), 1.7)
	road_car(r, "van", Vector3(61.8, 0, 798.8), PI * .5 - .1, false, "#d8d6d0")
	shards(r, Vector3(76.0, G0, 788.0), Vector2(2.6, 1.0), 20)
	stain(r, "pool_big", Vector3(70.6, 0, 792.0), 1.0, 1.8, 1.4)
	drag(r, Vector3(76.3, G0, 787.6), Vector3(71.0, 0, 793.0), false)

# ---------------------------------------------------------------- the long bridge

## The bridge across the river (stage 17): ramp up from the road, then 270 m of deck to the far bank. Four red arches
## over it, wrecks across both lanes, one stretch (z 930..946) where the east half of the deck went into the river
## (barriers round the hole: the west lane only), a barricade across the far end with a gap in it.
const GAP := [930.0, 946.0]
const BRIDGE_END := 1086.0
func long_bridge() -> void:
	var r := R_BRIDGE
	ramp(r, Vector3(94.0, 0.0, 800.0), Vector3(94.0, 2.0, 814.0), 11.0, ROAD, .5)
	for sx: float in [88.4, 99.6]: side_wall(r, Vector3(sx, 2.0 * 6.5 / 14.0, 806.5), Vector3(sx, 2.0, 814.0), 1.15, .2, "#8a2a24", 4)
	span(r, Vector3(87.6, -3.6, 806.9), Vector3(100.4, 0, 812.0), CONC)
	span(r, Vector3(100.2, 0, 786.0), Vector3(106.0, 4.0, 807.0), "concrete_block_wall|#8a867a", true)
	span(r, Vector3(88.0, 0, 806.5), Vector3(88.5, 1.2, 814.0), CONC, true)
	# The deck (a hole in its east half), walkways, the yellow line, its girders and the parapets with red rails.
	var g0: float = GAP[0]
	var g1: float = GAP[1]
	span(r, Vector3(88.5, 1.4, 814.0), Vector3(99.5, 2.0, g0), ROAD, true)
	span(r, Vector3(88.5, 1.4, g0), Vector3(94.0, 2.0, g1), ROAD, true)
	span(r, Vector3(88.5, 1.4, g1), Vector3(99.5, 2.0, BRIDGE_END), ROAD, true)
	span(r, Vector3(88.5, 2.0, 814.0), Vector3(90.0, 2.15, BRIDGE_END), WALK, true)
	span(r, Vector3(98.0, 2.0, 814.0), Vector3(99.5, 2.15, g0), WALK, true)
	span(r, Vector3(98.0, 2.0, g1), Vector3(99.5, 2.15, BRIDGE_END), WALK, true)
	var lz := 815.0
	while lz < BRIDGE_END - 2.0:
		if lz < g0 - 2.0 or lz > g1: bx(r, Vector3(94.0, 2.006, lz + 1.5), Vector3(.14, .01, 3.0), YELLOW)
		lz += 6.0
	for gx: float in [89.5, 94.0, 98.5]:
		for seg: Array in [[814.0, g0], [g1, BRIDGE_END]]:
			span(r, Vector3(gx - .3, .2, seg[0]), Vector3(gx + .3, 1.4, seg[1]), "concrete_wall_008|#968f80")
	span(r, Vector3(89.5 - .3, .2, g0), Vector3(89.5 + .3, 1.4, g1), "concrete_wall_008|#968f80")
	railing(r, Vector3(88.4, 2.15, 814.0), Vector3(88.4, 2.15, BRIDGE_END), 1.1, "#8a2a24")
	railing(r, Vector3(99.6, 2.15, 814.0), Vector3(99.6, 2.15, g0), 1.1, "#8a2a24")
	railing(r, Vector3(99.6, 2.15, g1), Vector3(99.6, 2.15, BRIDGE_END), 1.1, "#8a2a24")
	# The hole: its broken edges (rebar, slabs hanging), concrete barriers round it, a bent rail.
	for e: Array in [[Vector3(94.0, 1.7, (g0 + g1) * .5), Vector3(0, 0, 8.0), Vector3(1, -.4, 0)], [Vector3(96.75, 1.7, g0), Vector3(2.7, 0, 0), Vector3(0, -.5, 1)], [Vector3(96.75, 1.7, g1), Vector3(2.7, 0, 0), Vector3(0, -.5, -1)]]:
		rebar(r, e[0], e[1], 22, e[2])
	bx(r, Vector3(96.6, .6, g0 + 2.4), Vector3(5.0, .5, 4.6), ROAD, false, Basis(Vector3.RIGHT, .7) * Basis(Vector3.FORWARD, .2))
	bx(r, Vector3(97.0, .2, g1 - 3.0), Vector3(4.4, .5, 4.0), ROAD, false, Basis(Vector3.RIGHT, -.9))
	for e: Array in [[Vector3(94.3, 2.0, g0), Vector3(94.3, 2.0, g1)], [Vector3(94.3, 2.0, g0 - .35), Vector3(99.5, 2.0, g0 - .35)], [Vector3(94.3, 2.0, g1 + .35), Vector3(99.5, 2.0, g1 + .35)]]:
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		var d := b - a
		var n := maxi(1, int(d.length() / 2.0))
		for k in n:
			var c := a.lerp(b, (k + .5) / n) + Vector3.UP * .45
			bx(r, c, Vector3(.5, .9, d.length() / n - .06) if absf(d.z) > absf(d.x) else Vector3(d.length() / n - .06, .9, .5), "concrete_wall_008|#c8c4b8" if k % 2 == 0 else "concrete_wall_008|#b83a2a", true)
	# Lamps along it, some dead.
	var li := 0
	var lzz := 820.0
	while lzz < BRIDGE_END - 6.0:
		if lzz < g0 - 3.0 or lzz > g1 + 3.0:
			var west := li % 2 == 0
			street_lamp(r, Vector3(89.2 if west else 98.8, 2.15, lzz), Vector3(1 if west else -1, 0, 0), [0, 2, 0, -1, 0, 3, -1, 0][li % 8])
			li += 1
		lzz += 22.0
	# The wrecks: two buses, a jack-knifed truck, cars, vans, taxis, a pickup on the edge of the hole, a jeepney.
	bus(r, Transform3D(Basis(Vector3.UP, .04), Vector3(96.3, 2.0, 822.0)), false, BURNT)
	road_car(r, "sedan_wreck", Vector3(91.0, 2.0, 845.0), .3)
	road_car(r, "taxi_wreck", Vector3(97.0, 2.0, 861.0), -2.8)
	road_car(r, "van_wreck", Vector3(90.8, 2.0, 879.0), .6, true)
	road_car(r, "truck_wreck", Vector3(94.0, 2.0, 900.0), 1.1, true)
	road_car(r, "sedan", Vector3(91.2, 2.0, 919.0), -.2, true)
	road_car(r, "pickup_wreck", Vector3(96.4, 2.0, 926.0), .9, false, "#6a1a1a", Vector3(-.08, 0, 0))
	road_car(r, "sedan_wreck", Vector3(91.0, 2.0, 958.0), 2.9)
	place(r, "street/jeepney", Vector3(96.6, 2.0, 974.0), 170.0, 1.0, Vector3.ZERO, 160.0)
	solid(r, Vector3(96.6, 3.22, 974.0), Vector3(2.45, 2.44, 6.8), Basis(Vector3.UP, deg_to_rad(170.0)))
	bus(r, Transform3D(Basis(Vector3.UP, -.1), Vector3(96.6, 2.0, 990.0)), false)
	road_car(r, "van", Vector3(91.4, 2.0, 1018.0), .4)
	road_car(r, "sedan_wreck", Vector3(97.0, 2.0, 1034.0), -.3, true)
	road_car(r, "taxi_wreck", Vector3(90.8, 2.0, 1048.0), 1.2)
	# The far end: sandbags and barriers across with a gap; an army truck left there; the bank beyond.
	for k in 7:
		var bxp := 88.8 + k * 1.6
		if bxp > 92.6 and bxp < 95.6: continue
		bx(r, Vector3(bxp, 2.45, 1078.0), Vector3(1.5, .9, .6), "concrete_wall_008|#c8c4b8", true)
		for sb in 2: bx(r, Vector3(bxp, 3.05 + sb * .2, 1078.0), Vector3(1.4, .2, .5), "#8a7a5a")
	road_car(r, "truck", Vector3(97.2, 2.0, 1082.0), PI + .2, false, "#4a5a3a")
	for k in 6: place(r, "nichols/nh_trashbag", Vector3(rng.randf_range(89.0, 99.0), 2.0, rng.randf_range(1070.0, 1080.0)), rng.randf() * 360.0)
	ramp(r, Vector3(94.0, 2.0, BRIDGE_END), Vector3(94.0, 0.0, BRIDGE_END + 12.0), 11.0, ROAD, .5)
	span(r, Vector3(70.0, -1.0, BRIDGE_END + 12.0), Vector3(120.0, 0, BRIDGE_END + 60.0), DIRT, true)
	span(r, Vector3(70.0, 0, BRIDGE_END + 12.0), Vector3(88.0, 4.0, BRIDGE_END + 60.0), "concrete_block_wall|#8a867a", true)
	span(r, Vector3(100.0, 0, BRIDGE_END + 12.0), Vector3(120.0, 4.0, BRIDGE_END + 60.0), "concrete_block_wall|#8a867a", true)
	span(r, Vector3(88.0, 0, BRIDGE_END + 40.0), Vector3(100.0, 4.0, BRIDGE_END + 42.0), "rusty_metal_03|#7a3a28", true)
	litter(r, Vector3(94.0, 2.0, 950.0), Vector2(5.0, 120.0), 260)
	for k in 8: stain(r, ["pool_big", "spatter_floor", "drag_a"][k % 3], Vector3(rng.randf_range(90.0, 98.0), 2.0, rng.randf_range(830.0, 1060.0)), rng.randf() * TAU, 1.6, 1.2)
	# Under it, in the river: the piers; over it, the red arches with lamps along their ribs.
	for pz: float in [835.0, 889.0, 925.0, 997.0, 1051.0]:
		for px: float in [91.0, 97.0]: cyl(R_SKY, Vector3(px, -1.5, pz), .8, 4.0, CONC, Basis.IDENTITY, 14)
	var rs := R_SKY
	for arch: Array in [[816.0, 870.0], [878.0, 928.0], [948.0, 1004.0], [1018.0, 1072.0]]:
		var a0: float = arch[0]
		var a1: float = arch[1]
		for rx: float in [88.9, 99.1]:
			var last := Vector3(rx, 2.2, a0)
			for i in range(1, 15):
				var t := i / 14.0
				var p := Vector3(rx, 2.2 + sin(t * PI) * 16.5, lerpf(a0, a1, t))
				bar(rs, last, p, .7, "#9a2a22")
				if i < 14:
					pipe(rs, p, Vector3(rx, 2.0, p.z), .03, "#7a2a22", 6)
					var gp := glow_piece(rs, p + Vector3.UP * .45, Vector3(.18, .12, .18), Color(1.0, .86, .6), 2.6)
					lamp_light(null, 0.0, 0 if i % 4 != 2 else 3, "", gp, 2.6)
				last = p
		for i in range(3, 12, 2):
			var t := i / 14.0
			bar(rs, Vector3(88.9, 2.2 + sin(t * PI) * 16.5, lerpf(a0, a1, t)), Vector3(99.1, 2.2 + sin(t * PI) * 16.5, lerpf(a0, a1, t)), .4, "#9a2a22")
	hum(r, Vector3(94.0, 2.0, 950.0), "res://assets/audio/night/frog_chorus.ogg", -22.0, 30.0)
