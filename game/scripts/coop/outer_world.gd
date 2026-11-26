extends "res://scripts/coop/outer_kit.gd"
## 0.63: Outer Street's places, laid down once on every peer (scripts/coop/outer_street.gd runs them and the night in
## them). Street-local metres: +z north (away from PILCST), +x east, y 0 the road. The references (work/Reference/
## Outer Street) are for mood only: the elevated highway on rust-streaked piers, a yellow-railed stair up a hillside,
## a glass-roofed footbridge, a crossing with vending machines and carts, a riverside road with its bus and lamps.

const R_SOUTH := 0
const R_PILEUP := 1
const R_PLAZA := 2
const R_HILL := 3
const R_STATION := 4
const R_TUNNEL := 5
const R_RIVER := 6
const R_SKY := 7
const ROOT_NAMES := ["Avenue", "Pile-up", "Plaza", "Hillside", "Station", "Tunnel", "Riverside", "Highway and skyline"]

## The bus at the pile-up: along the west lane, nose north, doors on its east side (rear and front).
const BUS_O := Vector3(36.6, 0, 649.5)
const BUS_W := 2.5
const BUS_L := 12.0
const BUS_FLOOR := .36
const BUS_DOORS := [2.5, 10.8]
## The subway: the entrance's shutter (chained), the concourse floor, the platform, the track bed, the train.
const SHUTTER := Vector3(33.0, .15, 671.5)
const CON_Y := -5.2
const PLAT_Y := -10.2
const BED_Y := -11.3
const PANEL := Vector3(55.0, -5.2, 686.7)
const TRAIN_X0 := 33.15
const TRAIN_X1 := 36.05
const TRAIN_FLOOR := -10.15
const CARS := [[713.0, 731.6], [732.4, 751.0]]
const OPEN_DOOR := 722.3
const EXIT_Z := 782.0
## The hillside terrace and what is on it.
const TERRACE_Y := 5.0
const OVP_Y := 5.6
const CUTTERS := Vector3(1.1, 6.07, 684.4)
const BACK_ROOM := [-5.6, -2.4, 680.6, 689.4]
## The bridge: everyone alive on its deck past GOAL_Z ends the chapter.
const GOAL_Z := 1062.0
const GOAL_X0 := 88.6
const GOAL_X1 := 99.4

const ROAD := "asphalt_02|#7a7872"
const WALK := "concrete_pavement|#a39f95"
const CURB := "concrete_wall_008|#b6b0a0"
const DIRT := "dirty_concrete|#77736a"
const CONC := "concrete_wall_008|#a29b8c"
const ROUGH := "rough_concrete|#8a867c"
const STONE := "mossy_stone_wall|#8e8e80"
const HEAP := "damaged_concrete_floor|#8a8476"
const TILE := "marble_tiles|#dcd9cf"
const TILE_LOW := "marble_tiles|#5d6c6a"
const TILE_FLOOR := "marble_tiles|#9d998f"
const CEIL := "s:ceiling|#a9a59a"
const SHUT := "painted_metal_shutter|#a6aaa4"
const STEEL := "rusty_metal_02|#7e7c78"
const DARK := "#121212"
const GLASS := "glass#2c3a42b4"
const YELLOW := "#d8aa16"
const SODIUM := Color(1.0, .66, .32)
const TUBE := Color(.84, .94, 1.0)
const WALL_IDS := ["painted_plaster_wall|#d9d0b4", "painted_plaster_wall|#b6cdbd", "painted_plaster_wall|#c4cfd8", "painted_plaster_wall|#dcc2b4",
	"painted_plaster_wall|#e3ded1", "peeling_painted_wall|#c8bfa6", "worn_cracked_plaster|#bfb7a2", "painted_plaster_wall|#cbc4dd"]
const BOARD_COLS := ["#b8322a", "#2a5aa0", "#e0b020", "#2a8a4a", "#e8e2d0", "#c85a1a", "#5a2a6a", "#1a6a6a"]

## Pieces that change with the night (outer_street.gd `sync`).
var shutter_body: StaticBody3D
var shutter_curtain: Node3D
var chain: Node3D
var cutters: Node3D
var cutters_glint: Dictionary
var back_door: StaticBody3D
var flaps: Node3D
var flaps_shape: CollisionShape3D
var lever: Node3D
var vista: Array = []
## 0.67: the second car's hum (stopped when its lights die: outer_dread.gd).
var train_hum: AudioStreamPlayer3D

# ---------------------------------------------------------------- small makers

## A point on a facade: `a` along it (from its middle), `y` up, `o` out from it.
func fp(c: Vector3, out: Vector3, a: float, y: float, o: float) -> Vector3:
	return c + Vector3.UP.cross(out).normalized() * a + Vector3.UP * y + out * o

func fbasis(out: Vector3) -> Basis:
	return Basis(Vector3.UP.cross(out).normalized(), Vector3.UP, out)

## Vertical wall slices along a slope from a to b (a stair's side): each slice's top `h` over the slope, its foot
## under it; they collide, so nobody steps off the side of a stair.
func side_wall(r: int, a: Vector3, b: Vector3, h: float, thick: float, id: String, n: int, collide := true) -> void:
	var d := b - a
	var yaw := atan2(d.x, d.z)
	for i in n:
		var p0 := a.lerp(b, float(i) / n)
		var p1 := a.lerp(b, float(i + 1) / n)
		var lo := minf(p0.y, p1.y) - .8
		var hi := maxf(p0.y, p1.y) + h
		var mid := (p0 + p1) * .5
		var flat := Vector2(p1.x - p0.x, p1.z - p0.z).length()
		bx(r, Vector3(mid.x, (lo + hi) * .5, mid.z), Vector3(thick, hi - lo, flat + .02), id, collide, Basis(Vector3.UP, yaw))

## A heap that stops bodies: one mass (drawn, colliding) its silhouette broken by chunks and slabs over it.
func heap(r: int, lo: Vector3, hi: Vector3, chunks := 30, id := HEAP) -> void:
	span(r, lo, hi, id, true)
	var c := (lo + hi) * .5
	var sz := hi - lo
	for i in chunks:
		var at := Vector3(rng.randf_range(lo.x, hi.x), rng.randf_range(lo.y + sz.y * .3, hi.y + .3), rng.randf_range(lo.z, hi.z))
		# On a face or the top: pushed out to the surface.
		match rng.randi() % 5:
			0: at.x = lo.x - .1
			1: at.x = hi.x + .1
			2: at.z = lo.z - .1
			3: at.z = hi.z + .1
			_: at.y = hi.y + .1
		bx(r, at, Vector3(rng.randf_range(.4, 1.6), rng.randf_range(.3, 1.0), rng.randf_range(.4, 1.4)), [CONC, HEAP, ROUGH, "concrete_block_wall|#8a867a"][rng.randi() % 4], false, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-.6, .6)))
	rubble(r, Vector3(c.x, lo.y, c.z), Vector3(sz.x * .6 + 1.0, .5, sz.z * .6 + 1.0), int(chunks * .7))

## A shophouse (or house) facing `out` from the facade's middle at the ground `c`: `w` wide, `depth` deep, `floors`
## storeys; look 0 shutter down, 1 shutter with a gap under it, 2 a shop behind a scissor gate, 3 a house front.
## `volume` false draws only the facade (on a block another call made).
func shophouse(r: int, c: Vector3, out: Vector3, w: float, depth: float, floors: int, look := 0, volume := true) -> void:
	var B := fbasis(out)
	var h := 3.6 + (floors - 1) * 3.2
	var wall: String = WALL_IDS[rng.randi() % WALL_IDS.size()]
	if volume:
		bx(r, c - out * depth * .5 + Vector3.UP * (h * .5), Vector3(w, h, depth), wall, true, B)
		bx(r, fp(c, out, 0, h + .45, -.15), Vector3(w, .9, .3), wall, false, B)
		bx(r, c - out * depth * .5 + Vector3.UP * (h + .02), Vector3(w - .4, .04, depth - .4), "#4a4844", false, B)
		if rng.randf() < .35:
			var tank := fp(c, out, rng.randf_range(-w * .3, w * .3), h + 1.0, -depth * .5)
			for lx in [-.55, .55]:
				for lz in [-.55, .55]: bar(r, tank + Vector3(lx, -1.0, lz), tank + Vector3(lx, 0, lz), .05, STEEL)
			cyl(r, tank + Vector3.UP * .7, .72, 1.4, ["#2a5a9a", "#3a6a4a", "#9a9a92"][rng.randi() % 3], Basis.IDENTITY, 14)
	# The grime: streaks down from the roof's edge, a band along the foot.
	for i in int(w / 2.0):
		bx(r, fp(c, out, rng.randf_range(-w * .45, w * .45), h - rng.randf_range(.8, 2.0), .012), Vector3(rng.randf_range(.15, .5), rng.randf_range(1.2, 3.0), .01), "#3a362f", false, B)
	bx(r, fp(c, out, 0, .3, .012), Vector3(w, .6, .01), "#4a463e", false, B)
	# Ground floor.
	for side in [-1.0, 1.0]: bx(r, fp(c, out, side * (w * .5 - .2), 1.8, .1), Vector3(.4, 3.6, .2), wall, false, B)
	var ow := w - 1.0
	match look:
		0, 1:
			var gap := .35 if look == 1 else 0.0
			bx(r, fp(c, out, 0, 1.5 + gap * .5, .05), Vector3(ow, 3.0 - gap, .05), SHUT, false, B)
			bx(r, fp(c, out, 0, 3.12, .15), Vector3(ow + .2, .3, .3), "#6a6e6a", false, B)
			bx(r, fp(c, out, 0, gap + .04, .08), Vector3(ow, .08, .06), "#4a4e4a", false, B)
			if gap > 0.0: bx(r, fp(c, out, 0, gap * .5, .02), Vector3(ow, gap, .02), DARK, false, B)
			if rng.randf() < .5: bx(r, fp(c, out, rng.randf_range(-ow * .3, ow * .3), 1.4, .08), Vector3(.4, .55, .01), "#e8e4d6", false, B)
		2:
			bx(r, fp(c, out, 0, 1.55, .02), Vector3(ow, 3.0, .02), "#0c0c0c", false, B)
			for row in 3:
				for i in int(ow / .45):
					if rng.randf() < .3: continue
					bx(r, fp(c, out, -ow * .5 + .3 + i * .45, .55 + row * .85, .12), Vector3(.32, rng.randf_range(.2, .45), .2), BOARD_COLS[rng.randi() % BOARD_COLS.size()], false, B)
				bx(r, fp(c, out, 0, .32 + row * .85, .12), Vector3(ow - .2, .04, .26), "#5a5a56", false, B)
			for i in int(ow / .35):
				var a := -ow * .5 + i * .35
				bar(r, fp(c, out, a, .1, .32), fp(c, out, a + .35, 2.9, .32), .02, "#3a3a38")
				bar(r, fp(c, out, a + .35, .1, .32), fp(c, out, a, 2.9, .32), .02, "#3a3a38")
			solid(r, fp(c, out, 0, 1.5, .32), Vector3(ow, 3.0, .06), B)
		3:
			bx(r, fp(c, out, -w * .25, 1.05, .04), Vector3(1.0, 2.1, .06), "dark_wooden_planks|#5a4030", false, B)
			bx(r, fp(c, out, w * .15, 1.5, .04), Vector3(1.6, 1.2, .06), "#202428", false, B)
			for i in 6: bar(r, fp(c, out, w * .15 - .7 + i * .28, .9, .1), fp(c, out, w * .15 - .7 + i * .28, 2.1, .1), .02, "#2a2a2a")
	if look != 3:
		var board := fp(c, out, 0, 3.75, .16)
		var tilt := Basis.IDENTITY if rng.randf() < .8 else Basis(Vector3.FORWARD, rng.randf_range(-.18, .18))
		var col: String = BOARD_COLS[rng.randi() % BOARD_COLS.size()]
		bx(r, board, Vector3(ow, .8, .08), col, false, B * tilt)
		for i in rng.randi_range(3, 6):
			var lx := rng.randf_range(-ow * .38, ow * .38)
			bx(r, board + B.x * lx + B.z * .05 + Vector3.UP * rng.randf_range(-.12, .12), Vector3(rng.randf_range(.3, .9), .16, .01), "#f0ece0" if col != "#e8e2d0" and col != "#e0b020" else "#1a1a1a", false, B * tilt)
		if rng.randf() < .45:
			bx(r, fp(c, out, 0, 3.3, .95), Vector3(w - .3, .04, 1.7), "rusty_corrugated_iron", false, B * Basis(Vector3.RIGHT, .24))
			for side in [-1.0, 1.0]: bar(r, fp(c, out, side * (w * .5 - .5), 3.5, .02), fp(c, out, side * (w * .5 - .5), 3.0, 1.6), .04, STEEL)
	# Upper floors: windows (grilles, sills, a rare one still lit), air-conditioners, a balcony now and then.
	for f in range(1, floors):
		var y0 := 3.6 + (f - 1) * 3.2
		var n := maxi(1, int(w / 2.7))
		if rng.randf() < .28:
			bx(r, fp(c, out, 0, y0 + .05, .55), Vector3(w - .8, .15, 1.1), CONC, false, B)
			for i in int((w - .8) / .5) + 1: bar(r, fp(c, out, -(w - .8) * .5 + i * .5, y0 + .1, 1.08), fp(c, out, -(w - .8) * .5 + i * .5, y0 + 1.1, 1.08), .025, "#2e2e2c")
			bar(r, fp(c, out, -(w - .8) * .5, y0 + 1.1, 1.08), fp(c, out, (w - .8) * .5, y0 + 1.1, 1.08), .04, "#2e2e2c")
			if rng.randf() < .6:
				for i in rng.randi_range(2, 5): bx(r, fp(c, out, rng.randf_range(-w * .35, w * .35), y0 + 1.3, .9), Vector3(.45, .65, .01), BOARD_COLS[rng.randi() % BOARD_COLS.size()], false, B)
		for i in n:
			var a := -w * .5 + (i + .5) * w / n
			var yc := y0 + 1.65
			bx(r, fp(c, out, a, yc, .04), Vector3(1.5, 1.4, .08), "#2a2a28", false, B)
			var roll := rng.randf()
			var pane := "glass#1c242ad8" if roll < .8 else (DARK if roll < .96 else "glow#d8a060*0.7")
			bx(r, fp(c, out, a, yc, .085), Vector3(1.36, 1.26, .02), pane, false, B)
			if pane.begins_with("glow"): bx(r, fp(c, out, a - .3, yc, .1), Vector3(.6, 1.2, .01), "#7a3a2a", false, B)
			for k in 5: bar(r, fp(c, out, a - .6 + k * .3, yc - .65, .13), fp(c, out, a - .6 + k * .3, yc + .65, .13), .018, "#2a2a2a")
			bx(r, fp(c, out, a, y0 + .92, .1), Vector3(1.6, .08, .2), CONC, false, B)
			bx(r, fp(c, out, a, y0 + .45, .006), Vector3(.25, .9, .01), "#3a362f", false, B)
			if rng.randf() < .35:
				bx(r, fp(c, out, a + .2, y0 + .55, .3), Vector3(.8, .55, .5), "#c8c8c0", false, B)
				bx(r, fp(c, out, a + .45, y0 + .55, .56), Vector3(.4, .4, .01), "#3a3a38", false, B)
	# A meter box and its conduit.
	var mx := w * .5 - .7
	bx(r, fp(c, out, mx, 2.3, .1), Vector3(.35, .45, .16), "#8a8e8a", false, B)
	bar(r, fp(c, out, mx, 2.55, .1), fp(c, out, mx, h, .1), .04, "#5a5e5a")

## A vending machine facing `out`, its front at `at` (ground). `mode` -1 dead, else the lamp mode of its panel.
func vending(r: int, at: Vector3, out: Vector3, mode: int, side_col := "#c83228") -> void:
	var B := fbasis(out)
	bx(r, at - out * .43 + Vector3.UP * .93, Vector3(1.0, 1.86, .86), side_col, true, B)
	bx(r, at + out * .005 + Vector3.UP * 1.84, Vector3(1.0, .12, .02), "#e8e8e0", false, B)
	if mode >= 0:
		var g := glow_piece(r, fp(at, out, -.12, 1.2, .006), Vector3(.62, 1.1, .02), Color(.9, .96, 1.0), 1.8, B)
		var l := omni(r, at + out * .6 + Vector3.UP * 1.2, Color(.85, .93, 1.0), .7, 4.0)
		lamp_light(l, .7, mode, "", g, 1.8)
		hum(r, at + Vector3.UP, "res://assets/audio/nichols/fridge_hum.ogg", -26.0, 2.0)
	else:
		bx(r, fp(at, out, -.12, 1.2, .006), Vector3(.62, 1.1, .02), "#1a1e20", false, B)
	for row in 4:
		for i in 5:
			bx(r, fp(at, out, -.38 + i * .13, .78 + row * .27, .02), Vector3(.08, .16, .03), BOARD_COLS[(row * 5 + i * 3) % BOARD_COLS.size()], false, B)
	bx(r, fp(at, out, .33, 1.1, .02), Vector3(.18, .7, .02), "#2a2a2a", false, B)
	bx(r, fp(at, out, -.1, .32, .02), Vector3(.6, .22, .04), "#0e0e0e", false, B)

## A street lamp: pole, arm toward `arm`, its head; `mode` -1 dead.
func street_lamp(r: int, at: Vector3, arm: Vector3, mode: int, h := 6.4) -> void:
	pipe(r, at, at + Vector3.UP * h, .07, "#4a4e4c", 8)
	solid(r, at + Vector3.UP * 1.2, Vector3(.22, 2.4, .22))
	var tip := at + Vector3.UP * h + arm.normalized() * 1.7
	bar(r, at + Vector3.UP * (h - .1), tip, .07, "#4a4e4c")
	bx(r, tip + Vector3.DOWN * .08, Vector3(.42, .14, .26), "#3a3e3c", false, Basis(Vector3.UP, atan2(arm.x, arm.z)))
	if mode < 0:
		bx(r, tip + Vector3.DOWN * .17, Vector3(.32, .04, .18), "#2a2a26")
		return
	var g := glow_piece(r, tip + Vector3.DOWN * .17, Vector3(.32, .04, .18), SODIUM, 3.2)
	var l := omni(r, tip + Vector3.DOWN * .5, SODIUM, 1.9, 15.0)
	l.distance_fade_begin = 70.0
	lamp_light(l, 1.9, mode, "", g, 3.2)

## A traffic signal on its post; `blink` leaves the amber one blinking (the controller on its battery).
func signal_post(r: int, at: Vector3, out: Vector3, blink: bool) -> void:
	pipe(r, at, at + Vector3.UP * 3.3, .07, "#3a3e3c", 8)
	var head := at + Vector3.UP * 3.0 + out * .2
	bx(r, head, Vector3(.34, 1.0, .3), "#1e2220", false, fbasis(out))
	for k in 3:
		var p := head + Vector3.UP * (.3 - k * .3) + out * .16
		if k == 1 and blink:
			var g := glow_piece(r, p, Vector3(.2, .2, .02), Color(1.0, .62, .1), 3.0, fbasis(out))
			var l := omni(r, p + out * .5, Color(1.0, .6, .15), .8, 7.0)
			lamp_light(l, .8, 5, "", g, 3.0)
		else:
			bx(r, p, Vector3(.2, .2, .02), "#2a2a26", false, fbasis(out))

func power_pole(r: int, at: Vector3) -> Vector3:
	place(r, "fields/power_pole", at, 0.0, 1.0, Vector3.ZERO, 140.0)
	solid(r, at + Vector3.UP * 3.0, Vector3(.3, 6.0, .3))
	return at + Vector3.UP * 5.8

# ---------------------------------------------------------------- the bus

## A city bus in the frame `xf` (local: x 0..BUS_W across, west to east; z 0..BUS_L rear to front; y up). 0.65: drawn by
## the model (tools/blender/vehicles: "bus_walk" with both doors on +x broken open and its east windows smashed,
## "bus_shut" for the stalled ones); here only what collides, what glows and what was left in it. Without an inside:
## one collider round it. `palette` (outer_kit.gd) repaints it (BURNT for a burnt-out one).
func bus(r: int, xf: Transform3D, inside: bool, palette := {}) -> void:
	var W := BUS_W
	var L := BUS_L
	var F := BUS_FLOOR
	var R := xf.basis
	var lp := func(p: Vector3) -> Vector3: return xf * p
	vehicle(r, "bus_walk" if inside else "bus_shut", xf, palette, 150.0)
	if str(palette.get("paint", "")) != "burnt":
		# The destination sign dying; the hazards still blinking on the battery, front and back.
		var dest := glow_piece(r, lp.call(Vector3(W * .5, 2.77, L + .012)), Vector3(1.8, .26, .01), Color(1.0, .55, .1), 1.6, R)
		lamp_light(null, 0.0, 3, "", dest, 1.6)
		for p: Vector3 in [Vector3(.18, 1.35, -.056), Vector3(W - .18, 1.35, -.056), Vector3(.68, .66, L + .056), Vector3(W - .68, .66, L + .056)]:
			var g := glow_piece(r, lp.call(p), Vector3(.18, .16, .012), Color(1.0, .55, .08), 3.0, R)
			lamp_light(null, 0.0, 5, "", g, 3.0)
		var haz := omni(r, lp.call(Vector3(W * .5, 1.3, -.9)), Color(1.0, .55, .12), .9, 6.0)
		lamp_light(haz, .9, 5)
	if not inside:
		solid(r, lp.call(Vector3(W * .5, 1.6, L * .5)), Vector3(W + .1, 3.2, L + .2), R)
		return
	# --- Inside: colliders. Floor, walls (doorways open on +x), ends, roof; the headers over the doorways.
	solid(r, lp.call(Vector3(W * .5, F * .5, L * .5)), Vector3(W, F, L), R)
	solid(r, lp.call(Vector3(.06, 1.7, L * .5)), Vector3(.12, 2.7, L), R)
	for sp: Array in [[0.0, BUS_DOORS[0] - .55], [BUS_DOORS[0] + .55, BUS_DOORS[1] - .55], [BUS_DOORS[1] + .55, L]]:
		solid(r, lp.call(Vector3(W - .06, 1.7, (float(sp[0]) + float(sp[1])) * .5)), Vector3(.12, 2.7, float(sp[1]) - float(sp[0])), R)
	for dz in BUS_DOORS: solid(r, lp.call(Vector3(W - .06, 2.8, dz)), Vector3(.12, .5, 1.1), R)
	solid(r, lp.call(Vector3(W * .5, 1.7, .06)), Vector3(W, 2.7, .12), R)
	solid(r, lp.call(Vector3(W * .5, 1.7, L - .06)), Vector3(W, 2.7, .12), R)
	solid(r, lp.call(Vector3(W * .5, 2.95, L * .5)), Vector3(W, .12, L), R)
	# The step up at each door, outside; its yellow edge.
	for dz in BUS_DOORS:
		ramp(r, lp.call(Vector3(W + .75, 0.0, dz)), lp.call(Vector3(W - .08, F, dz)), 1.05, "#3a3a36", .2)
		bx(r, lp.call(Vector3(W - .2, F + .006, dz)), Vector3(.3, .01, 1.0), YELLOW, false, R)
	# Seats (west doubles, east singles between the doors, the back bench), the driver's place, the dash.
	solid(r, lp.call(Vector3(.57, F + .23, 5.25)), Vector3(.9, .46, 9.3), R)
	solid(r, lp.call(Vector3(W * .5, F + .23, .41)), Vector3(W - .24, .46, .58), R)
	for sp: Array in [[.12, BUS_DOORS[0] - .7], [BUS_DOORS[0] + .7, BUS_DOORS[1] - .7]]:
		solid(r, lp.call(Vector3(2.1, F + .23, (float(sp[0]) + float(sp[1])) * .5)), Vector3(.56, .46, float(sp[1]) - float(sp[0])), R)
	solid(r, lp.call(Vector3(.56, F + .5, 10.65)), Vector3(.88, 1.0, .7), R)
	solid(r, lp.call(Vector3(1.0, F + .45, L - .3)), Vector3(1.8, .9, .36), R)
	# The lights: one tube failing, one dying (the rear one, over the door you come in at, lights the way in);
	# the driver's red one.
	var t1 := lamp(r, lp.call(Vector3(W * .5, 2.53, 3.2)), TUBE, 1.4, 7.0, 2, Vector3.ZERO, "", true, true)
	t1["g"] = glow_piece(r, lp.call(Vector3(W * .5, 2.54, 3.2)), Vector3(.1, .04, 1.6), TUBE, 2.6, R)
	var t2 := lamp(r, lp.call(Vector3(W * .5, 2.53, 7.6)), TUBE, .8, 5.0, 3, Vector3.ZERO)
	t2["g"] = glow_piece(r, lp.call(Vector3(W * .5, 2.54, 7.6)), Vector3(.1, .04, 1.6), TUBE, 2.6, R)
	lamp(r, lp.call(Vector3(.4, 2.45, L - .5)), Color(1.0, .25, .18), .5, 3.5, 1, Vector3(.12, .06, .06))
	hum(r, lp.call(Vector3(W * .5, 2.4, 3.0)), "res://assets/audio/nichols/arc_buzz.ogg", -20.0, 3.0)
	# What was left: bags, papers, a phone still lit on the floor; blood down the aisle and on the west side.
	for i in 6:
		var at: Vector3 = lp.call(Vector3(rng.randf_range(.3, .8), F + .52, rng.randf_range(1.2, 9.4)))
		bx(r, at, Vector3(rng.randf_range(.25, .45), rng.randf_range(.15, .3), rng.randf_range(.2, .35)), ["#3a2a20", "#20304a", "#6a1a1a", "#2a2a2a"][i % 4], false, R * Basis(Vector3.UP, rng.randf() * TAU))
	litter(r, lp.call(Vector3(1.4, F, 6.0)), Vector2(.35, 4.0), 24)
	bx(r, lp.call(Vector3(1.6, F + .012, 6.8)), Vector3(.08, .01, .15), "glow#9ad0ff*1.2", false, R * Basis(Vector3.UP, .4))
	stain(r, "pool_big", lp.call(Vector3(1.4, F, 7.6)), rng.randf() * TAU, 1.4, 1.0, .85)
	drag(r, lp.call(Vector3(1.4, F, 4.0)), lp.call(Vector3(1.4, F, 7.2)), false)
	for i in 3: smear(r, "smear_wall", lp.call(Vector3(.2, 1.6, 2.0 + i * 3.0)), R * Vector3(1, 0, 0), 1.0, .7)
	# Broken glass where the doors were torn out.
	for dz in BUS_DOORS:
		for k in 14:
			bx(r, lp.call(Vector3(W + rng.randf_range(.1, 1.4), .012, dz + rng.randf_range(-.9, .9))), Vector3(rng.randf_range(.04, .12), .006, rng.randf_range(.04, .12)), "glass#8aa0a8c0", false, R * Basis(Vector3.UP, rng.randf() * TAU))

# ---------------------------------------------------------------- the train

## A box between two corners that only collides (nothing drawn).
func block(r: int, lo: Vector3, hi: Vector3) -> void:
	solid(r, (lo + hi) * .5, (hi - lo).abs())

## One car of the stalled train, z0..z1 along the track. 0.65: drawn by the model ("metro_a": shut rear end, the west
## door at OPEN_DOOR forced; "metro_b": the cab at z1, its front door down onto the track); here the colliders, the
## lights and the pictures. `light_mode` -1: only the dim red emergency ones at the ends.
func car(r: int, z0: float, z1: float, cab: bool, rear_end: bool, open_door: float, light_mode: int, gate := "") -> void:
	var x0 := TRAIN_X0
	var x1 := TRAIN_X1
	var xm := (x0 + x1) * .5
	var y0 := TRAIN_FLOOR
	var len := z1 - z0
	vehicle(r, "metro_b" if cab else "metro_a", Transform3D(Basis.IDENTITY, Vector3(x0, y0, z0)), {}, 140.0, METRO_PAINT)
	var doors: Array = [z0 + 3.5, z0 + 9.3, z0 + 15.1]
	block(r, Vector3(x0, y0 - .55, z0), Vector3(x1, y0, z1))
	block(r, Vector3(x0, -7.1, z0), Vector3(x1, -7.0, z1))
	for west in [true, false]:
		var x := x0 if west else x1
		var pieces: Array = [[z0, z1]]
		if west and open_door > 0.0: pieces = [[z0, open_door - .65], [open_door + .65, z1]]
		for p: Array in pieces:
			solid(r, Vector3(x, (y0 + -7.0) * .5, (float(p[0]) + float(p[1])) * .5), Vector3(.12, -7.0 - y0, float(p[1]) - float(p[0])))
		if west and open_door > 0.0: block(r, Vector3(x - .06, y0 + 2.05, open_door - .65), Vector3(x + .06, -7.0, open_door + .65))
	# The ends.
	if rear_end: block(r, Vector3(x0, y0, z0), Vector3(x1, -7.0, z0 + .1))
	else: _gangway_wall(r, z0, z0 + .1)
	if not cab: _gangway_wall(r, z1 - .1, z1)
	# Benches along both sides between the doors.
	var segs: Array = []
	var last := z0 + .3
	for d: float in doors:
		segs.append([last, d - .8])
		last = d + .8
	segs.append([last, (z1 - 2.2) if cab else z1 - .3])
	for sg: Array in segs:
		var a: float = sg[0]
		var b: float = sg[1]
		if b - a < .4: continue
		for west in [true, false]:
			var bxw := x0 + .32 if west else x1 - .32
			block(r, Vector3(bxw - .25, y0, a), Vector3(bxw + .25, y0 + .46, b))
	# Pictures in the ad frames, the line map, the intercom's light.
	for i in int(len / 2.4):
		var az := z0 + 1.2 + i * 2.4
		for west in [true, false]:
			bx(r, Vector3((x0 + .125) if west else (x1 - .125), y0 + 2.3, az), Vector3(.01, .32, 1.6), BOARD_COLS[(i * 3 + (1 if west else 0)) % BOARD_COLS.size()])
	bx(r, Vector3(x1 - .07, -8.0, z0 + 6.4), Vector3(.02, .16, 2.4), "#e8e6de")
	bx(r, Vector3(x1 - .08, -8.0, z0 + 6.4), Vector3(.01, .02, 2.2), "#2a8a4a")
	for k in 7: bx(r, Vector3(x1 - .085, -8.0, z0 + 5.4 + k * .33), Vector3(.01, .05, .05), "#f0f0e8")
	lamp(r, Vector3(x0 + .12, -8.3, z0 + 1.0), Color(1.0, .2, .15), .0, 1.0, 5, Vector3(.02, .05, .05), "", false)
	# The light: tubes along the ceiling's middle (`light_mode` -1: only the dim red emergency ones at the ends).
	if light_mode >= 0:
		var lz := z0 + 2.5
		var k := 0
		while lz < z1 - 1.5:
			var with_light := k % 2 == 0
			lamp(r, Vector3(xm, y0 + 2.565, lz), TUBE, 1.1 if with_light else 0.0, 6.0, light_mode if k % 3 != 2 else 3, Vector3(.12, .03, 1.6), gate, with_light)
			lz += 3.6
			k += 1
		var h := hum(r, Vector3(xm, -8.0, (z0 + z1) * .5), "res://assets/audio/nichols/arc_buzz.ogg", -18.0, 3.5)
		if cab: train_hum = h
	for ez in [z0 + .6, z1 - .6]:
		lamp(r, Vector3(xm, y0 + 2.565, ez), Color(1.0, .3, .2), .45, 4.5, 1, Vector3(.3, .03, .1))
	# Cab: the partition and its open door, the console, the front with its evacuation door folded down to the track.
	if cab:
		var pz := z1 - 2.0
		block(r, Vector3(x0, y0, pz), Vector3(x0 + 1.05, -7.0, pz + .08))
		block(r, Vector3(x1 - 1.05, y0, pz), Vector3(x1, -7.0, pz + .08))
		block(r, Vector3(x0 + 1.05, -8.1, pz), Vector3(x1 - 1.05, -7.0, pz + .08))
		block(r, Vector3(x0 + .12, y0, z1 - 1.2), Vector3(x0 + .95, y0 + .95, z1 - .12))
		var scr := glow_piece(r, Vector3(x0 + .55, y0 + 1.02, z1 - .65), Vector3(.5, .02, .3), Color(1.0, .2, .1), 1.4, Basis(Vector3.RIGHT, -.5))
		lamp_light(null, 0.0, 4, "", scr, 1.4)
		block(r, Vector3(x0, y0, z1 - .1), Vector3(xm - .6, -7.0, z1))
		block(r, Vector3(xm + .6, y0, z1 - .1), Vector3(x1, -7.0, z1))
		block(r, Vector3(xm - .6, -8.2, z1 - .1), Vector3(xm + .6, -7.0, z1))
		ramp(r, Vector3(xm, y0, z1 - .05), Vector3(xm, BED_Y, z1 + 2.5), 1.15, "rusty_metal_02|#8a8a86", .1)
		for side in [-.58, .58]: bar(r, Vector3(xm + side, y0 + .05, z1), Vector3(xm + side, BED_Y + .05, z1 + 2.5), .04, YELLOW)
		# Its headlights, one still glowing, aimed up the tunnel.
		var hl := glow_piece(r, Vector3(x1 - .45, y0 + .6, z1 + .055), Vector3(.3, .18, .01), Color(1.0, .92, .7), 2.2)
		var beam := spot(r, Vector3(x1 - .45, y0 + .6, z1 + .3), Vector3(x1 - .6, -10.4, z1 + 30.0), Color(1.0, .9, .7), 2.2, 34.0, 22.0, true)
		lamp_light(beam, 2.2, 3, "", hl, 2.2)

func _gangway_wall(r: int, za: float, zb: float) -> void:
	var xm := (TRAIN_X0 + TRAIN_X1) * .5
	block(r, Vector3(TRAIN_X0, TRAIN_FLOOR, za), Vector3(xm - .6, -7.0, zb))
	block(r, Vector3(xm + .6, TRAIN_FLOOR, za), Vector3(TRAIN_X1, -7.0, zb))
	block(r, Vector3(xm - .6, -8.05, za), Vector3(xm + .6, -7.0, zb))

# ---------------------------------------------------------------- ground, lane, avenue

func holed(r: int, at: Vector3, size: Vector3, hole: Array, id: String, collide: bool) -> void:
	var ax := at.x - size.x * .5
	var bxx := at.x + size.x * .5
	var az := at.z - size.z * .5
	var bz := at.z + size.z * .5
	var h0: float = hole[0]
	var h1: float = hole[1]
	var hz0: float = hole[2]
	var hz1: float = minf(hole[3], bz)
	for part: Array in [[ax, h0, az, bz], [h1, bxx, az, bz], [h0, h1, az, hz0], [h0, h1, hz1, bz]]:
		var w: float = float(part[1]) - float(part[0])
		var d: float = float(part[3]) - float(part[2])
		if w < .01 or d < .01: continue
		bx(r, Vector3((float(part[0]) + float(part[1])) * .5, at.y, (float(part[2]) + float(part[3])) * .5), Vector3(w, size.y, d), id, collide)

func ground() -> void:
	# The base under everything above the street (its top just under the surfaces); the subway's well cut through it.
	holed(R_SKY, Vector3(46, -.52, 653), Vector3(64, 1.0, 110), [30.5, 35.5, 671.3, 682.6], DIRT, true)
	span(R_SOUTH, Vector3(40, -.1, 600.2), Vector3(48, 0, 614), DIRT, true)
	for seg: Array in [[R_SOUTH, 614.0, 649.5], [R_PILEUP, 649.5, 662.0], [R_PLAZA, 662.0, 704.0]]:
		var r: int = seg[0]
		var z0: float = seg[1]
		var z1: float = seg[2]
		span(r, Vector3(36, -.1, z0), Vector3(56, 0, z1), ROAD, true)
		# The median: yellow-and-black kerbs, the highway's piers stand in it; open at the crossing.
		var parts: Array = [[z0, z1]] if r != R_PLAZA else [[z0, 672.0], [676.0, z1]]
		for p: Array in parts:
			span(r, Vector3(45, 0, p[0]), Vector3(47, .18, p[1]), CURB, true)
			var zz: float = p[0]
			while zz < float(p[1]) - .6:
				for mx in [44.99, 47.01]: bx(r, Vector3(mx, .09, zz + .3), Vector3(.01, .16, .6), YELLOW if int(zz / .6) % 2 == 0 else "#1a1a1a")
				zz += .6
		# Lane lines: white dashes either side of the median, a solid line along each kerb.
		var dz := z0 + 1.0
		while dz < z1 - 1.0:
			if r != R_PLAZA or dz < 670.0 or dz > 678.0:
				for lx in [40.5, 51.5]: bx(r, Vector3(lx, .005, dz + 1.5), Vector3(.14, .01, 3.0), "#d6d2c4")
			dz += 7.0
		for lx in [36.4, 55.6]: bx(r, Vector3(lx, .005, (z0 + z1) * .5), Vector3(.12, .01, z1 - z0), "#c8c4b4")
		for kx in [35.95, 56.05]: bx(r, Vector3(kx, .08, (z0 + z1) * .5), Vector3(.12, .17, z1 - z0), CURB)
	span(R_SOUTH, Vector3(30, 0, 614), Vector3(36, .15, 649.5), WALK, true)
	span(R_SOUTH, Vector3(56, 0, 614), Vector3(62, .15, 649.5), WALK, true)
	span(R_PILEUP, Vector3(30, 0, 649.5), Vector3(36, .15, 662), WALK, true)
	span(R_PILEUP, Vector3(56, 0, 649.5), Vector3(62, .15, 662), WALK, true)
	holed(R_PLAZA, Vector3(29, .075, 683), Vector3(14, .15, 42), [30.5, 35.5, 671.3, 682.6], WALK, true)
	span(R_PLAZA, Vector3(56, 0, 662), Vector3(67, .15, 704), WALK, true)
	span(R_PLAZA, Vector3(67, -.1, 680), Vector3(80, 0, 694), ROAD, true)
	# The crossing: zebra stripes across both carriageways.
	var sx := 36.6
	while sx < 55.5:
		if sx < 44.6 or sx > 47.4: bx(R_PLAZA, Vector3(sx + .25, .006, 674.0), Vector3(.5, .012, 3.8), "#d8d4c6")
		sx += 1.0
	# Drains along the kerbs, a manhole or two.
	for z in [620.0, 634.0, 648.0, 668.0, 686.0, 700.0]:
		var rr: int = R_SOUTH if z < 649.5 else (R_PILEUP if z < 662.0 else R_PLAZA)
		for kx in [36.35, 55.65]: bx(rr, Vector3(kx, .006, z), Vector3(.5, .012, .9), "#1c1c1a")
	for mh: Vector3 in [Vector3(42.0, 0, 622.0), Vector3(50.0, 0, 690.0), Vector3(43.0, 0, 640.0)]:
		var rr: int = R_SOUTH if mh.z < 649.5 else R_PLAZA
		cyl(rr, mh + Vector3.UP * .006, .42, .012, "#2a2826", Basis.IDENTITY, 16)
	for p: Vector3 in [Vector3(38.5, 0, 619.0), Vector3(53.0, 0, 633.0), Vector3(41.0, 0, 646.0), Vector3(49.5, 0, 668.0), Vector3(38.0, 0, 695.0)]:
		var rr: int = R_SOUTH if p.z < 649.5 else R_PLAZA
		bx(rr, p + Vector3.UP * .008, Vector3(rng.randf_range(1.5, 3.5), .01, rng.randf_range(1.0, 2.5)), "puddle", false, Basis(Vector3.UP, rng.randf() * TAU))

func lane() -> void:
	var r := R_SOUTH
	# The blocks either side of the lane, their backs on PILCST's wall; their fronts close the avenue's south end.
	var hw := 3.6 + 2 * 3.2
	span(r, Vector3(18, 0, 600.3), Vector3(40, hw, 614), WALL_IDS[2], true)
	shophouse(r, Vector3(29, .15, 614), Vector3(0, 0, 1), 22.0, 13.7, 3, 0, false)
	shophouse(r, Vector3(40, 0, 607.15), Vector3(1, 0, 0), 13.7, 22.0, 3, 3, false)
	var he := 3.6 + 1 * 3.2
	span(r, Vector3(48, 0, 600.3), Vector3(74, he, 614), WALL_IDS[0], true)
	shophouse(r, Vector3(61, .15, 614), Vector3(0, 0, 1), 26.0, 13.7, 2, 1, false)
	shophouse(r, Vector3(48, 0, 607.15), Vector3(-1, 0, 0), 13.7, 26.0, 2, 3, false)
	# Wires overhead, a lamp on a bracket (failing), what was left in the lane.
	for i in 6:
		var z := 601.5 + i * 2.2
		cable(r, Vector3(40, rng.randf_range(5.6, 7.4), z), Vector3(48, rng.randf_range(5.6, 7.4), z + rng.randf_range(-1.5, 1.5)), .5)
	bar(r, Vector3(40.0, 4.2, 608.0), Vector3(41.2, 4.2, 608.0), .05, "#3a3a38")
	lamp(r, Vector3(41.2, 4.05, 608.0), Color(1.0, .8, .55), 1.4, 9.0, 2, Vector3(.3, .1, .2))
	place(r, "street/tricycle_a", Vector3(46.4, 0, 604.8), 170.0)
	solid(r, Vector3(46.4, .8, 604.8), Vector3(1.6, 1.6, 2.3), Basis(Vector3.UP, deg_to_rad(170.0)))
	for i in 5: place(r, "nichols/nh_trashbag", Vector3(40.6 + rng.randf() * .8, 0, 610.0 + i * .7), rng.randf() * 360.0)
	place(r, "street/oil_drum", Vector3(47.4, 0, 611.5))
	place(r, "street/plastic_monobloc_chair_01", Vector3(41.0, 0, 603.0), 40.0, 1.0, Vector3(80, 0, 0))
	litter(r, Vector3(44, 0, 607), Vector2(3.6, 6.5), 60)
	drag(r, Vector3(44.2, 0, 602.0), Vector3(42.6, 0, 612.6))
	stain(r, "spatter_floor", Vector3(42.0, 0, 609.0), 1.0, 1.4, 1.2)
	bx(r, Vector3(44.5, .008, 606.0), Vector3(2.4, .01, 1.6), "puddle")

func avenue() -> void:
	var r := R_SOUTH
	var z := 614.0
	var looks := [0, 2, 1, 0]
	var fl := [3, 2, 4, 3]
	var i := 0
	for w: float in [8.5, 9.0, 8.0, 10.0]:
		shophouse(r, Vector3(30, .15, z + w * .5), Vector3(1, 0, 0), w, 10.0, fl[i], looks[i])
		z += w
		i += 1
	z = 614.0
	looks = [1, 0, 3, 2]
	fl = [2, 3, 3, 2]
	i = 0
	for w: float in [9.0, 8.5, 9.0, 9.0]:
		shophouse(r, Vector3(62, .15, z + w * .5), Vector3(-1, 0, 0), w, 10.0, fl[i], looks[i])
		z += w
		i += 1
	street_lamp(r, Vector3(30.7, .15, 622.0), Vector3(1, 0, 0), 0)
	street_lamp(r, Vector3(30.7, .15, 641.0), Vector3(1, 0, 0), -1)
	street_lamp(r, Vector3(61.3, .15, 630.0), Vector3(-1, 0, 0), 2)
	street_lamp(r, Vector3(61.3, .15, 647.0), Vector3(-1, 0, 0), -1)
	var p1 := power_pole(r, Vector3(35.4, .15, 618.0))
	var p2 := power_pole(r, Vector3(35.4, .15, 640.0))
	for k in 3: cable(r, p1 + Vector3(k * .35 - .35, 0, 0), p2 + Vector3(k * .35 - .35, 0, 0), .7)
	for k in 3: cable(r, p1 + Vector3(0, -.3, 0), Vector3(30.1, rng.randf_range(5.5, 7.5), 614.5 + k * 3.0), .4)
	for k in 2: cable(r, p2 + Vector3(0, -.3, 0), Vector3(61.9, rng.randf_range(5.5, 7.0), 636.0 + k * 4.0), 1.1)
	cable(r, p2, Vector3(35.4, 5.8, 664.0), .8)
	# Jeepneys left where they stopped; a tricycle on its side; a cart.
	place(r, "street/jeepney", Vector3(42.4, 0, 627.5), 12.0)
	solid(r, Vector3(42.4, 1.22, 627.5), Vector3(2.4, 2.44, 6.8), Basis(Vector3.UP, deg_to_rad(12.0)))
	place(r, "street/jeepney", Vector3(52.0, 0, 639.5), -168.0)
	solid(r, Vector3(52.0, 1.22, 639.5), Vector3(2.4, 2.44, 6.8), Basis(Vector3.UP, deg_to_rad(-168.0)))
	place(r, "street/tricycle_b", Vector3(33.4, .15, 631.0), 30.0, 1.0, Vector3(0, 0, 78))
	place(r, "street/food_cart_b", Vector3(58.6, .15, 624.0), -90.0)
	solid(r, Vector3(58.6, 1.0, 624.0), Vector3(1.2, 2.0, 2.0))
	for k in 8: place(r, "nichols/nh_trashbag", Vector3(rng.randf_range(30.6, 35.0), .15, rng.randf_range(616.0, 648.0)), rng.randf() * 360.0)
	litter(r, Vector3(46, 0, 632), Vector2(15.0, 17.0), 160)
	drag(r, Vector3(44.6, 0, 615.5), Vector3(39.8, 0, 629.0))
	stain(r, "pool_big", Vector3(49.0, 0, 636.0), 2.0, 2.2, 1.8)
	stain(r, "spatter_floor", Vector3(33.0, .15, 644.0), .4, 1.6, 1.4)
	hum(r, Vector3(46, 4, 630), "res://assets/audio/night/cricket_field.ogg", -24.0, 10.0)

# ---------------------------------------------------------------- the elevated highway

func pier(r: int, pz: float, foot := 0.0) -> void:
	cyl(r, Vector3(46, (foot + 7.4) * .5, pz), .95, 7.4 - foot, CONC, Basis.IDENTITY, 18)
	if foot >= 0.0: solid(r, Vector3(46, 3.7, pz), Vector3(1.8, 7.4, 1.8))
	bx(r, Vector3(46, 7.9, pz), Vector3(13, 1.0, 2.4), CONC)
	bx(r, Vector3(46, 7.15, pz), Vector3(5.0, .5, 2.0), CONC)
	for i in 9:
		var sx := rng.randf_range(39.8, 52.2)
		for sz in [pz - 1.21, pz + 1.21]: bx(r, Vector3(sx, 7.6 - rng.randf_range(0, .3), sz), Vector3(rng.randf_range(.08, .25), rng.randf_range(.6, 1.6), .01), "#7a4a2c")
	for i in 5: bx(r, Vector3(46 + rng.randf_range(-.5, .5), rng.randf_range(2.0, 6.0), pz + (.96 if i % 2 == 0 else -.96)), Vector3(rng.randf_range(.1, .3), rng.randf_range(1.5, 4.0), .01), "#7a4a2c")
	pipe(r, Vector3(46.95, foot, pz + .3), Vector3(46.95, 8.4, pz + .3), .07, "#3a3a38", 6)

func deck(r: int, za: float, zb: float, broken_a: bool, broken_b: bool) -> void:
	span(r, Vector3(39, 9.4, za), Vector3(53, 10.0, zb), CONC)
	for gx in [41.5, 46.0, 50.5]: span(r, Vector3(gx - .3, 8.4, za + .2), Vector3(gx + .3, 9.4, zb - .2), "concrete_wall_008|#968f80")
	for px in [39.15, 52.85]: span(r, Vector3(px - .15, 10.0, za), Vector3(px + .15, 10.95, zb), CONC)
	span(r, Vector3(39.3, 10.0, za), Vector3(52.7, 10.02, zb), ROAD)
	var lz := za + 12.0
	while lz < zb - 4.0:
		pipe(r, Vector3(39.15, 10.95, lz), Vector3(39.15, 15.5, lz), .07, "#4a4e4c", 6)
		bar(r, Vector3(39.15, 15.4, lz), Vector3(40.6, 15.4, lz), .06, "#4a4e4c")
		lz += 32.0
	for e: Array in [[broken_a, za, -1.0], [broken_b, zb, 1.0]]:
		if not bool(e[0]): continue
		var ez: float = e[1]
		var dirz: float = e[2]
		rebar(r, Vector3(46, 9.7, ez), Vector3(6.8, 0, 0), 26, Vector3(0, -.4, dirz))
		for i in 10: bx(r, Vector3(rng.randf_range(39.5, 52.5), rng.randf_range(9.2, 10.1), ez + dirz * rng.randf_range(-.6, .2)), Vector3(rng.randf_range(.5, 1.5), rng.randf_range(.3, .7), rng.randf_range(.4, 1.0)), CONC, false, Basis(Vector3.UP, rng.randf() * TAU))

func viaduct() -> void:
	var r := R_SKY
	for pz in [606.0, 646.0, 686.0]: pier(r, pz)
	for pz in [816.0, 856.0, 896.0, 936.0, 976.0, 1016.0, 1056.0, 1096.0]: pier(r, pz, -3.6)
	# The stump of the one whose span is down across the plaza's north side.
	cyl(r, Vector3(46, 1.8, 726.0), .95, 3.6, CONC, Basis.IDENTITY, 18)
	rebar(r, Vector3(46, 3.6, 726.0), Vector3(.7, 0, .7), 14, Vector3(0, 1, 0))
	deck(r, 601.0, 647.2, true, false)
	deck(r, 684.8, 695.5, false, true)
	deck(r, 805.8, 1110.0, true, false)

# ---------------------------------------------------------------- the pile-up and the bus

func pileup() -> void:
	var r := R_PILEUP
	shophouse(r, Vector3(30, .15, 655.75), Vector3(1, 0, 0), 12.5, 10.0, 3, 0)
	shophouse(r, Vector3(62, .15, 655.75), Vector3(-1, 0, 0), 12.5, 10.0, 2, 1)
	# West: the balcony came down off the shophouse with what was under it, and a jeepney ran into it.
	heap(r, Vector3(30.0, 0, 649.2), Vector3(36.55, 3.3, 662.0), 36)
	bx(r, Vector3(33.2, 4.85, 655.6), Vector3(5.6, .2, 9.0), CONC, false, Basis(Vector3.BACK, -.5))
	for i in 12: bar(r, Vector3(35.4, 3.6, 651.4 + i * .75), Vector3(35.4 + rng.randf_range(-.4, .4), 4.4 + rng.randf_range(-.3, .3), 651.4 + i * .75 + rng.randf_range(-.2, .2)), .03, "#2e2e2c")
	place(r, "street/jeepney", Vector3(33.3, .15, 646.4), -6.0, 1.0, Vector3(4, 0, 0))
	solid(r, Vector3(33.3, 1.3, 646.4), Vector3(2.45, 2.45, 6.8), Basis(Vector3.UP, deg_to_rad(-6.0)))
	# The span of the highway between the piers came down on the road: its south half lies here, propped on what
	# it fell on, rising north; under it all crushed. (Its mass is a heap no one climbs.)
	heap(r, Vector3(41.2, 0, 649.0), Vector3(55.8, 3.0, 664.0), 26)
	var sb := Basis(Vector3.RIGHT, -.172)
	var sc := Vector3(48.5, 4.35, 656.5)
	bx(r, sc, Vector3(14.8, .6, 15.6), CONC, true, sb)
	bx(r, sc + sb.y * .31, Vector3(13.6, .02, 15.6), ROAD, false, sb)
	for lx in [-3.6, 3.6]: bx(r, sc + sb.y * .325 + sb.x * lx, Vector3(.14, .01, 14.0), "#d6d2c4", false, sb)
	for gx in [-4.6, 0.0, 4.6]: bx(r, sc - sb.y * .8 + sb.x * gx, Vector3(.6, 1.0, 15.2), "concrete_wall_008|#968f80", false, sb)
	bx(r, sc + sb.y * .78 + sb.x * 7.25, Vector3(.3, .95, 15.6), CONC, false, sb)
	pipe(r, sc + sb.y * .8 + sb.x * 7.0 + sb.z * 3.0, sc + sb.y * 2.4 + sb.x * 9.5 + sb.z * 4.0, .07, "#4a4e4c", 6)
	rebar(r, sc + sb.z * 7.8, sb.x * 7.0, 22, sb.z * 1.0)
	rebar(r, sc - sb.z * 7.8, sb.x * 7.0, 18, -sb.z * 1.0)
	rebar(r, sc - sb.x * 7.4, sb.z * 7.0, 12, Vector3(-1, -.2, 0))
	place(r, "street/jeepney", Vector3(44.6, 0, 647.9), 90.0, 1.0, Vector3(0, 0, -5))
	solid(r, Vector3(44.6, 1.22, 647.9), Vector3(6.8, 2.44, 2.45))
	place(r, "street/jeepney", Vector3(52.2, 0, 647.4), 76.0, 1.0, Vector3(0, 0, 6))
	solid(r, Vector3(52.2, 1.22, 647.4), Vector3(2.45, 2.44, 6.8), Basis(Vector3.UP, deg_to_rad(76.0)))
	# Between the bus's two doors the slab's corner and a crushed car are hard against its side.
	heap(r, Vector3(39.15, 0, 653.6), Vector3(41.2, 3.3, 658.6), 0)
	for i in 10:
		var at := Vector3(rng.randf_range(39.6, 41.0), rng.randf_range(3.3, 3.8), rng.randf_range(653.8, 658.4))
		bx(r, at, Vector3(rng.randf_range(.3, .8), rng.randf_range(.2, .5), rng.randf_range(.3, .8)), CONC, false, Basis(Vector3.UP, rng.randf() * TAU))
	bx(r, Vector3(40.0, 1.0, 656.1), Vector3(1.6, 1.3, 4.0), "#3e4e5e", false, Basis(Vector3.FORWARD, .25))
	for i in 6: bx(r, Vector3(39.07, rng.randf_range(1.3, 2.3), rng.randf_range(654.0, 658.2)), Vector3(.12, rng.randf_range(.15, .3), rng.randf_range(.2, .4)), CONC)
	# East: the pier's capital fallen along the walk, an awning and its shop's front down over it.
	heap(r, Vector3(55.8, 0, 649.0), Vector3(62.0, 3.4, 664.0), 30)
	cyl(r, Vector3(57.0, 1.0, 655.0), .95, 11.0, CONC, Basis(Vector3.RIGHT, PI * .5) * Basis(Vector3.BACK, .12), 16)
	bx(r, Vector3(59.6, 3.9, 656.0), Vector3(5.4, .05, 12.0), "rusty_corrugated_iron", false, Basis(Vector3.BACK, .42))
	# Dust still settling; a wreck burning on the far side, seen over it all.
	smoke(r, Vector3(48.0, 5.0, 660.0), 14, 1.4, false)
	fire(r, Vector3(47.5, .1, 665.6), .7)
	place(r, "street/oil_drum", Vector3(44.0, 0, 665.0), 0.0, 1.0, Vector3(0, 0, 85))
	# The way: the bus, its hazards blinking at the back; its rear door is the only way through.
	bus(r, Transform3D(Basis.IDENTITY, BUS_O), true)
	litter(r, Vector3(40.2, 0, 650.0), Vector2(.8, 2.0), 20, ["#5a6a70", "#8aa0a8", "#d8d4c4"])
	litter(r, Vector3(40.2, 0, 661.0), Vector2(.8, 2.0), 16, ["#5a6a70", "#8aa0a8", "#d8d4c4"])
	stain(r, "pool", Vector3(40.0, 0, 652.6), .3, 1.2, 1.0)
	smear(r, "smear_wall", Vector3(39.12, 1.4, 653.3), Vector3(1, 0, 0), 1.0, .6)
	drag(r, Vector3(40.0, 0, 661.5), Vector3(38.6, 0, 667.0), false)

# ---------------------------------------------------------------- the plaza

func plaza() -> void:
	var r := R_PLAZA
	# Vending machines along the foot of the retaining wall, one still lit, one failing, one dead; one on its face.
	vending(r, Vector3(23.0, .15, 676.8), Vector3(1, 0, 0), 2, "#c83228")
	vending(r, Vector3(23.0, .15, 678.0), Vector3(1, 0, 0), 0, "#2a5aa0")
	vending(r, Vector3(23.0, .15, 679.2), Vector3(1, 0, 0), -1, "#e6e2d8")
	bx(r, Vector3(25.4, .6, 681.6), Vector3(1.86, .86, 1.0), "#2a8a4a", true, Basis(Vector3.UP, .2))
	bx(r, Vector3(25.4, 1.04, 681.6), Vector3(1.1, .02, .62), "#0e1214", false, Basis(Vector3.UP, .2))
	litter(r, Vector3(25.6, .15, 680.0), Vector2(1.6, 1.4), 30, ["#c83228", "#2a5aa0", "#e0b020", "#d8d4c4"])
	# The carts, their umbrellas, the stools kicked over.
	place(r, "street/food_cart_a", Vector3(27.0, .15, 688.0), 90.0)
	solid(r, Vector3(27.0, 1.0, 688.0), Vector3(1.4, 2.0, 2.3))
	place(r, "street/food_cart_b", Vector3(24.8, .15, 692.6), 0.0)
	solid(r, Vector3(24.8, 1.0, 692.6), Vector3(2.0, 2.0, 1.2))
	place(r, "street/food_stall_c", Vector3(60.6, .15, 668.6), -90.0)
	solid(r, Vector3(60.6, 1.0, 668.6), Vector3(1.7, 2.0, 2.6))
	umbrella(r, Vector3(27.0, .15, 690.4), ["#c83228", "#e8e4d8"])
	umbrella(r, Vector3(60.4, .15, 671.6), ["#2a5aa0", "#e0b020"])
	for k in 7: place(r, "street/plastic_monobloc_chair_01", Vector3(rng.randf_range(23.5, 29.0), .15, rng.randf_range(684.0, 694.0)), rng.randf() * 360.0, 1.0, Vector3(85 if k % 2 == 0 else 0, 0, 0))
	# The waiting shed: its ad still flickering.
	for p: Vector3 in [Vector3(23.4, .15, 694.3), Vector3(27.6, .15, 694.3), Vector3(23.4, .15, 697.7), Vector3(27.6, .15, 697.7)]:
		pipe(r, p, p + Vector3.UP * 2.65, .05, "#5a5e5c", 8)
	bx(r, Vector3(25.5, 2.85, 696.0), Vector3(5.0, .06, 4.2), "rusty_corrugated_iron", false, Basis(Vector3.RIGHT, .07))
	span(r, Vector3(23.7, .15, 697.0), Vector3(27.3, .58, 697.5), "#6a6e6a", true)
	var ad := glow_piece(r, Vector3(25.5, 1.55, 697.86), Vector3(1.8, 1.1, .04), Color(.95, .9, .8), 1.6, Basis.IDENTITY)
	lamp_light(omni(r, Vector3(25.5, 1.5, 697.2), Color(.95, .9, .8), .5, 4.0), .5, 4, "", ad, 1.6)
	bx(r, Vector3(25.5, 1.55, 697.84), Vector3(1.4, .7, .01), "#6a2a3a")
	# Signals: one dead, one blinking amber on its battery.
	signal_post(r, Vector3(35.5, .15, 670.4), Vector3(0, 0, -1), true)
	signal_post(r, Vector3(56.5, .15, 677.6), Vector3(0, 0, 1), false)
	street_lamp(r, Vector3(30.6, .15, 664.6), Vector3(1, 0, 0), 0)
	street_lamp(r, Vector3(61.5, .15, 686.0), Vector3(-1, 0, 0), 2)
	street_lamp(r, Vector3(30.6, .15, 701.0), Vector3(1, 0, 0), -1)
	var p1 := power_pole(r, Vector3(35.6, .15, 666.5))
	var p2 := power_pole(r, Vector3(35.6, .15, 699.0))
	for k in 3: cable(r, p1 + Vector3(k * .35 - .35, 0, 0), p2 + Vector3(k * .35 - .35, 0, 0), .8)
	cable(r, p1, Vector3(35.4, 5.8, 640.0), .9)
	for k in 3: cable(r, p2 + Vector3(0, -.3, 0), Vector3(67.0, rng.randf_range(6.0, 8.0), 696.0 + k * 2.5), 1.4)
	# A fire in a drum by the median, the night's one warm light out here.
	place(r, "street/oil_drum", Vector3(48.6, 0, 695.0))
	solid(r, Vector3(48.6, .45, 695.0), Vector3(.6, .9, .6))
	fire(r, Vector3(48.6, .9, 695.0), .45, 9.0)
	# The road north is gone: the next span down across it, its ends on what it crushed, burning.
	heap(r, Vector3(20.0, 0, 703.6), Vector3(76.0, 4.6, 728.0), 56)
	bx(r, Vector3(46.0, 5.5, 710.0), Vector3(14.6, .6, 13.0), CONC, false, Basis(Vector3.RIGHT, .26) * Basis(Vector3.BACK, .05))
	bx(r, Vector3(47.5, 5.9, 721.0), Vector3(14.2, .6, 12.0), CONC, false, Basis(Vector3.RIGHT, -.3) * Basis(Vector3.BACK, -.08))
	for gx in [41.5, 46.0, 50.5]: bx(r, Vector3(gx, 4.9, 709.0), Vector3(.6, 1.0, 12.0), "concrete_wall_008|#968f80", false, Basis(Vector3.RIGHT, .26))
	rebar(r, Vector3(46.0, 4.6, 703.8), Vector3(7.0, 0, 0), 26, Vector3(0, .1, -1))
	place(r, "street/jeepney", Vector3(39.4, 0, 702.1), 82.0, 1.0, Vector3(0, 0, 9))
	solid(r, Vector3(39.4, 1.22, 702.1), Vector3(2.45, 2.44, 6.8), Basis(Vector3.UP, deg_to_rad(82.0)))
	bx(r, Vector3(59.5, .7, 702.6), Vector3(4.2, 1.4, 1.9), "#7a2a24", true, Basis(Vector3.UP, .15) * Basis(Vector3.FORWARD, .1))
	fire(r, Vector3(53.0, 4.7, 706.0), 1.2, 16.0)
	fire(r, Vector3(29.0, 4.7, 711.0), .8, 12.0)
	smoke(r, Vector3(44.0, 6.0, 714.0), 30, 1.8)
	# East: the cross street, shut by a container and a truck pushed across it.
	shophouse(r, Vector3(67, .15, 671.0), Vector3(-1, 0, 0), 18.0, 12.0, 3, 2)
	shophouse(r, Vector3(67, .15, 699.0), Vector3(-1, 0, 0), 10.0, 12.0, 2, 1)
	span(r, Vector3(67, 0, 680.0), Vector3(80, 7.0, 680.3), WALL_IDS[3], true)
	span(r, Vector3(67, 0, 693.7), Vector3(80, 7.0, 694.0), WALL_IDS[4], true)
	span(r, Vector3(73.6, 0, 680.3), Vector3(76.2, 2.7, 692.2), "rusty_metal_03|#7a3a28", true)
	var rib := 680.6
	while rib < 692.0:
		bx(r, Vector3(73.58, 1.35, rib), Vector3(.03, 2.6, .08), "#5a2a1c")
		rib += .45
	span(r, Vector3(72.6, 0, 692.2), Vector3(75.6, 3.0, 693.7), "#d8d4c8", true)
	bx(r, Vector3(72.58, 2.1, 692.95), Vector3(.02, .8, 1.2), "glass#24303ab0")
	for k in 10: bx(r, Vector3(72.9 + (k % 2) * .1, .15 + int(k / 5) * .3, 681.0 + (k % 5) * 2.2), Vector3(.5, .28, .9), "#7a6a4a", false, Basis(Vector3.UP, rng.randf_range(-.2, .2)))
	span(r, Vector3(79.6, 0, 680.3), Vector3(80.0, 7.0, 693.7), WALL_IDS[1], true)
	# The night here: blood dragged from the bus to the station's shutter (they ran for the subway), bags, papers.
	drag(r, Vector3(38.8, 0, 666.5), Vector3(33.4, .15, 670.6))
	stain(r, "pool_big", Vector3(33.0, .15, 670.4), .2, 1.6, 1.4)
	stain(r, "spatter_floor", Vector3(41.0, 0, 683.0), 1.2, 1.6, 1.4)
	stain(r, "pool", Vector3(52.0, 0, 676.0), 2.2, 1.2, 1.0)
	litter(r, Vector3(44.0, 0, 684.0), Vector2(18.0, 18.0), 200)
	for k in 9: place(r, "nichols/nh_trashbag", Vector3(rng.randf_range(23.0, 35.0), .15, rng.randf_range(664.0, 703.0)), rng.randf() * 360.0)
	hum(r, Vector3(44, 5, 690), "res://assets/audio/night/cricket_gryllus.ogg", -26.0, 12.0)

func umbrella(r: int, at: Vector3, cols: Array) -> void:
	pipe(r, at, at + Vector3.UP * 2.3, .025, "#cfcfc8", 6)
	for i in 8:
		var a := i * TAU / 8.0
		var dir := Vector3(cos(a), 0, sin(a))
		bx(r, at + Vector3.UP * 2.18 + dir * .55, Vector3(.7, .02, 1.05), cols[i % cols.size()], false, Basis(Vector3.UP, -a + PI * .5) * Basis(Vector3.RIGHT, .32))

# ---------------------------------------------------------------- the hillside: the yellow stair, the terrace

func yellow_stair() -> void:
	var r := R_HILL
	var a := Vector3(27.6, .15, 667.0)
	var b := Vector3(15.0, TERRACE_Y, 667.0)
	stair(r, a, b, 3.6, 30, "concrete_floor_02|#aca797", "#3a3a36")
	var y_at := func(x: float) -> float: return lerpf(a.y, b.y, (a.x - x) / (a.x - b.x))
	# In front of the retaining wall its sides are walls; inside the cut, the cut's own faces.
	for sz in [665.05, 668.95]:
		side_wall(r, Vector3(27.6, a.y, sz), Vector3(22.0, y_at.call(22.0), sz), .9, .3, CONC, 6)
	# The rails: yellow, either side and down the middle; posts every metre and a half.
	for rz in [665.35, 667.0, 668.65]:
		pipe(r, a + Vector3(.3, .95, rz - 667.0), b + Vector3(-.2, .95, rz - 667.0), .03, YELLOW, 8)
		var x := 27.3
		while x > 15.2:
			var yy: float = y_at.call(x)
			pipe(r, Vector3(x, yy, rz), Vector3(x, yy + .95, rz), .025, YELLOW, 6)
			x -= 1.5
	# Vines down the cut; weeds at the steps' ends; a lamp over its head, failing.
	for i in 14:
		var vz := 665.21 if i % 2 == 0 else 668.79
		bx(r, Vector3(rng.randf_range(15.5, 21.5), rng.randf_range(3.0, 4.8), vz), Vector3(rng.randf_range(.3, .8), rng.randf_range(.8, 2.2), .02), "forest_leaves_02|#3a5a2a")
	bar(r, Vector3(15.6, TERRACE_Y + 2.9, 665.3), Vector3(15.6, TERRACE_Y + 2.9, 666.4), .05, "#3a3a38")
	lamp(r, Vector3(15.6, TERRACE_Y + 2.75, 666.4), TUBE, 1.2, 9.0, 2, Vector3(.12, .06, .7))

func terrace() -> void:
	var r := R_HILL
	var y := TERRACE_Y
	# The hill: a mass with retaining walls for faces, the stair's cut through its east edge.
	span(r, Vector3(-8, 0, 662), Vector3(15, y, 706), STONE, true)
	span(r, Vector3(15, 0, 662), Vector3(22, y, 665.2), STONE, true)
	span(r, Vector3(15, 0, 668.8), Vector3(22, y, 706), STONE, true)
	for p: Array in [[-8.0, 15.0, 662.0, 706.0], [15.0, 22.0, 662.0, 665.2], [15.0, 22.0, 668.8, 706.0]]:
		span(r, Vector3(p[0], y - .01, p[2]), Vector3(p[1], y + .02, p[3]), "concrete_floor_02|#8e8a80")
	for i in 22: bx(r, Vector3(21.99, rng.randf_range(.5, 4.6), rng.randf_range(662.5, 705.5)), Vector3(.02, rng.randf_range(.4, 1.6), rng.randf_range(.3, 1.2)), "forest_leaves_02|#3a5a2a")
	# Its edge: a rail over the plaza, gaps for the stair's head and the overpass; the cut's edges railed too.
	railing(r, Vector3(21.85, y, 662.2), Vector3(21.85, y, 665.05))
	railing(r, Vector3(21.85, y, 668.95), Vector3(21.85, y, 688.3))
	railing(r, Vector3(21.85, y, 691.7), Vector3(21.85, y, 705.8))
	railing(r, Vector3(15.0, y, 665.1), Vector3(21.85, y, 665.1))
	railing(r, Vector3(15.0, y, 668.9), Vector3(21.85, y, 668.9))
	# Its ends: a wall and a shut gate south; north, the house that came down.
	span(r, Vector3(-8, y, 661.8), Vector3(22, y + 2.4, 662.1), "concrete_block_wall|#9a968c", true)
	bx(r, Vector3(13.5, y + 1.1, 662.15), Vector3(2.6, 2.0, .05), "rusty_metal_02|#6a6a62")
	heap(r, Vector3(-8, y, 704.6), Vector3(22, y + 3.2, 706.4), 26)
	# The houses up here, fronts east over the plaza; the sari-sari store; the hardware store (`hardware`).
	shophouse(r, Vector3(6, y, 664.6), Vector3(1, 0, 0), 5.0, 14.0, 2, 3)
	shophouse(r, Vector3(6, y, 671.5), Vector3(1, 0, 0), 8.2, 14.0, 2, 2)
	shophouse(r, Vector3(6, y, 677.8), Vector3(1, 0, 0), 4.4, 14.0, 3, 3)
	shophouse(r, Vector3(6, y, 693.8), Vector3(1, 0, 0), 7.6, 14.0, 2, 1)
	shophouse(r, Vector3(6, y, 701.1), Vector3(1, 0, 0), 7.0, 14.0, 3, 3)
	hardware()
	# The sari-sari store: a glow behind its grille (a lamp someone left), candy jars on the ledge.
	lamp(r, Vector3(6.25, y + 1.6, 671.2), Color(1.0, .7, .4), .7, 5.0, 1, Vector3(.2, .25, .2))
	for k in 6: cyl(r, Vector3(6.25, y + 1.12, 669.0 + k * .8), .1, .22, "glass#c8d8d0a0", Basis.IDENTITY, 8)
	# The mahjong table, its game left as it was, the battery lantern still on: the one warm light up here.
	var mt := Vector3(10.2, y, 671.6)
	span(r, mt + Vector3(-.5, 0, -.5), mt + Vector3(.5, .72, .5), "#2f6a3e", true)
	for i in 4:
		for k in 8:
			var e := Vector3(-.36 + k * .1, .755, -.4) if i == 0 else (Vector3(-.36 + k * .1, .755, .4) if i == 1 else (Vector3(-.4, .755, -.36 + k * .1) if i == 2 else Vector3(.4, .755, -.36 + k * .1)))
			bx(r, mt + e, Vector3(.07 if i < 2 else .09, .05, .09 if i < 2 else .07), "#e8e2cc")
	for k in 9: bx(r, mt + Vector3(rng.randf_range(-1.6, 1.6), .025, rng.randf_range(-1.6, 1.6)), Vector3(.07, .05, .09), "#e8e2cc", false, Basis(Vector3.UP, rng.randf() * TAU))
	for k in 4:
		var a := k * PI * .5
		place(r, "street/plastic_monobloc_chair_01", mt + Vector3(cos(a), 0, sin(a)) * .95, rad_to_deg(-a) - 90.0, 1.0, Vector3(80 if k == 2 else 0, 0, 0))
	lamp(r, mt + Vector3(.15, .95, .1), Color(1.0, .74, .42), 1.3, 10.0, 1, Vector3(.12, .2, .12), "", true, true, 3.0)
	bx(r, mt + Vector3(-.2, .78, -.15), Vector3(.2, .1, .1), "#2a2a2a")
	# The tarp over it on bamboo poles; string lights, dead.
	for pz in [668.6, 674.6]: pipe(r, Vector3(13.4, y, pz), Vector3(13.4, y + 2.7, pz), .045, "#a89060", 6)
	bx(r, Vector3(9.7, y + 2.95, 671.6), Vector3(7.6, .03, 6.4), "#2a4a86", false, Basis(Vector3.BACK, -.08))
	for i in 12: cyl(r, Vector3(6.4 + i * .6, y + 2.75 - sin(i / 11.0 * PI) * .25, 668.8), .04, .07, "#4a4030", Basis.IDENTITY, 6)
	# Washing on the lines; pots, a banana plant, a tree, a hoop, a parked tricycle, a water tank on its stand.
	for lz in [676.4, 696.8]:
		cable(r, Vector3(6.05, y + 2.6, lz), Vector3(17.5, y + 2.4, lz), .35, "#d8d8d0", .012)
		pipe(r, Vector3(17.5, y, lz), Vector3(17.5, y + 2.4, lz), .04, "#6a6e6a", 6)
		for k in 9: bx(r, Vector3(7.0 + k * 1.15, y + 2.1 - sin(k / 8.0 * PI) * .3, lz), Vector3(rng.randf_range(.4, .7), rng.randf_range(.5, .8), .015), BOARD_COLS[rng.randi() % BOARD_COLS.size()])
	for k in 6: place(r, ["decor/potted_plant_01", "decor/potted_plant_02", "decor/potted_plant_04"][k % 3], Vector3(6.6, y, 663.0 + k * 7.0 + rng.randf_range(-.5, .5)), rng.randf() * 360.0)
	place(r, "nature/banana_plant", Vector3(19.4, y, 700.6), 30.0)
	place(r, "nature/island_tree_01", Vector3(16.6, y, 682.6), 0.0, 1.1)
	solid(r, Vector3(16.6, y + 1.5, 682.6), Vector3(.5, 3.0, .5))
	pipe(r, Vector3(20.4, y, 694.0), Vector3(20.4, y + 3.3, 694.0), .07, "#5a5e5c", 8)
	solid(r, Vector3(20.4, y + 1.2, 694.0), Vector3(.2, 2.4, .2))
	bx(r, Vector3(20.2, y + 3.3, 694.0), Vector3(.05, 1.05, 1.6), "#e6e4dc")
	for i in 10:
		var a := i * TAU / 10.0
		bar(r, Vector3(19.85 + cos(a) * .23, y + 3.0, 694.0 + sin(a) * .23), Vector3(19.85 + cos(a + TAU / 10.0) * .23, y + 3.0, 694.0 + sin(a + TAU / 10.0) * .23), .02, "#c84a1a")
	place(r, "street/tricycle_b", Vector3(13.6, y, 698.4), 20.0)
	solid(r, Vector3(13.6, y + .8, 698.4), Vector3(1.6, 1.6, 2.3), Basis(Vector3.UP, deg_to_rad(20.0)))
	var tank := Vector3(9.0, y, 676.6)
	for lx in [-.55, .55]:
		for lz in [-.55, .55]: bar(r, tank + Vector3(lx, 0, lz), tank + Vector3(lx, 2.2, lz), .05, STEEL)
	cyl(r, tank + Vector3.UP * 2.9, .75, 1.4, "#2a5a9a", Basis.IDENTITY, 14)
	solid(r, tank + Vector3.UP * 1.1, Vector3(1.2, 2.2, 1.2))
	litter(r, Vector3(14, y, 684), Vector2(7.0, 20.0), 110, ["#6a5a3a", "#4a3a2a", "#d8d4c4", "#3a5a2a"])
	stain(r, "drag_a", Vector3(12.0, y, 683.6), 1.2, 1.4, .6)
	hum(r, Vector3(10, y + 2, 684), "res://assets/audio/night/gecko_tokay.ogg", -22.0, 8.0)
	hum(r, Vector3(-4, y + 3, 690), "res://assets/audio/night/dog_bark_c.ogg", -30.0, 20.0)

## The hardware store on the terrace (x -6..6, z 680..690): shutter up most of the way, the counter, shelves of tools,
## a flashlight dropped on the floor still shining at the counter where the bolt cutters are; the back room's door
## shut, and something behind it.
func hardware() -> void:
	var r := R_HILL
	var y := TERRACE_Y
	var wall := "painted_plaster_wall|#d6d0b8"
	var inner := "painted_plaster_wall|#c8c2ae"
	span(r, Vector3(-6.25, y, 680.0), Vector3(6.0, y + 3.4, 680.25), wall, true)
	span(r, Vector3(-6.25, y, 689.75), Vector3(6.0, y + 3.4, 690.0), wall, true)
	span(r, Vector3(-6.25, y, 680.0), Vector3(-6.0, y + 3.4, 690.0), wall, true)
	span(r, Vector3(5.75, y, 680.0), Vector3(6.0, y + 3.4, 681.5), wall, true)
	span(r, Vector3(5.75, y, 688.5), Vector3(6.0, y + 3.4, 690.0), wall, true)
	span(r, Vector3(5.75, y + 2.25, 681.5), Vector3(6.0, y + 3.4, 688.5), wall, true)
	span(r, Vector3(5.92, y + 2.25, 681.6), Vector3(6.08, y + 2.7, 688.4), SHUT)
	span(r, Vector3(5.8, y + 2.7, 681.5), Vector3(6.2, y + 3.05, 688.5), "#5a5e5a")
	span(r, Vector3(-6.25, y + 3.4, 680.0), Vector3(6.0, y + 3.6, 690.0), "#cfcac0", true)
	span(r, Vector3(-6.25, y + 3.6, 680.0), Vector3(6.0, y + 6.8, 690.0), wall, true)
	span(r, Vector3(-6.0, y + 6.8, 680.2), Vector3(5.8, y + 6.84, 689.8), "#4a4844")
	for i in 3:
		var wz := 682.0 + i * 3.0
		bx(r, Vector3(6.04, y + 5.2, wz), Vector3(.08, 1.4, 1.5), "#2a2a28")
		bx(r, Vector3(6.085, y + 5.2, wz), Vector3(.02, 1.26, 1.36), "glass#1c242ad8")
		for k in 5: bar(r, Vector3(6.13, y + 4.55, wz - .6 + k * .3), Vector3(6.13, y + 5.85, wz - .6 + k * .3), .018, "#2a2a2a")
	bx(r, Vector3(6.16, y + 3.05, 685.0), Vector3(.08, .62, 6.6), "#2a5aa0")
	for i in 5: bx(r, Vector3(6.21, y + 3.05 + rng.randf_range(-.1, .1), 682.6 + i * 1.15), Vector3(.01, .2, rng.randf_range(.5, .9)), "#f0ece0")
	span(r, Vector3(-6.0, y - .01, 680.25), Vector3(5.75, y + .02, 689.75), "concrete_floor_02|#7a766c")
	# The back room's wall, its door (a body of its own: burst when the cutters come off the counter).
	span(r, Vector3(-2.15, y, 680.25), Vector3(-1.95, y + 3.4, 684.2), inner, true)
	span(r, Vector3(-2.15, y, 685.4), Vector3(-1.95, y + 3.4, 689.75), inner, true)
	span(r, Vector3(-2.15, y + 2.1, 684.2), Vector3(-1.95, y + 3.4, 685.4), inner, true)
	back_door = StaticBody3D.new()
	back_door.collision_layer = 2
	back_door.name = "Hardware back door"
	back_door.position = Vector3(-1.98, y + 1.05, 684.2)
	roots[r].add_child(back_door)
	var dc := CollisionShape3D.new()
	var ds := BoxShape3D.new()
	ds.size = Vector3(.06, 2.1, 1.2)
	dc.shape = ds
	dc.position = Vector3(0, 0, .6)
	back_door.add_child(dc)
	s.piece(back_door, Vector3(0, 0, .6), Vector3(.05, 2.08, 1.18), "dark_wooden_planks|#5a4030")
	s.piece(back_door, Vector3(.04, 0, 1.05), Vector3(.04, .1, .06), "#b8a878")
	for k in 6:
		var sc: MeshInstance3D = s.piece(back_door, Vector3(.035, rng.randf_range(-.8, .4), rng.randf_range(.2, 1.0)), Vector3(.005, rng.randf_range(.25, .6), .015), "#e8dcc8")
		sc.rotation.x = rng.randf_range(-.3, .3)
	stain(r, "pool", Vector3(-1.6, y, 684.8), .4, .9, .7, .8)
	# The counter, its glass case, the bolt cutters on it; a pegboard of tools behind.
	span(r, Vector3(.6, y, 681.2), Vector3(1.6, y + 1.05, 687.2), "dark_wooden_planks|#6a4a32", true)
	span(r, Vector3(.5, y + 1.05, 681.1), Vector3(1.7, y + 1.09, 687.3), "#8a6a4a")
	bx(r, Vector3(1.64, y + .6, 684.2), Vector3(.03, .76, 5.6), "glass#5a6a70a0")
	for k in 9: bx(r, Vector3(1.2, y + .3 + int(k / 3) * .25, 682.0 + (k % 3) * 1.6), Vector3(.5, .1, .9), BOARD_COLS[k % BOARD_COLS.size()])
	cutters = place(r, "nichols/nh_bolt_cutters_01", CUTTERS + Vector3.UP * .02, 20.0, 1.0, Vector3(90, 0, 0))
	cutters_glint = lamp(r, CUTTERS + Vector3(.1, .35, 0), Color(.85, .95, 1.0), .45, 2.2, 1, Vector3(.03, .03, .03))
	span(r, Vector3(-1.9, y + .9, 681.0), Vector3(-1.85, y + 2.4, 688.8), "#a89a78")
	for k in 14:
		var tz := 681.4 + k * .52
		bar(r, Vector3(-1.82, y + rng.randf_range(1.2, 2.2), tz), Vector3(-1.82, y + rng.randf_range(1.0, 1.6), tz + rng.randf_range(-.1, .1)), .03, ["#8a8a88", "#c84a1a", "#3a3a38", "#d8aa16"][k % 4])
	# Shelves along both side walls, stocked; sacks of cement; pipes leaning; a tool chest; a gas tank.
	for wz in [680.55, 689.45]:
		for lv in 4:
			span(r, Vector3(-1.6, y + .25 + lv * .55, wz - .3), Vector3(5.4, y + .29 + lv * .55, wz + .3), "#6a6e6a", false)
			for k in 14:
				if rng.randf() < .3: continue
				var px := -1.3 + k * .48
				if rng.randf() < .5: cyl(r, Vector3(px, y + .44 + lv * .55, wz), .1, .26, ["#c84a1a", "#2a5aa0", "#e8e4d8", "#d8aa16"][rng.randi() % 4], Basis.IDENTITY, 8)
				else: bx(r, Vector3(px, y + .4 + lv * .55, wz), Vector3(.34, rng.randf_range(.15, .32), .4), ["#8a6a4a", "#5a5a56", "#2a5aa0", "#7a3a2a"][rng.randi() % 4])
		for px in [-1.6, 1.9, 5.4]: bar(r, Vector3(px, y, wz - .3), Vector3(px, y + 2.1, wz - .3), .04, "#4a4e4a")
		solid(r, Vector3(1.9, y + 1.05, wz), Vector3(7.0, 2.1, .6))
	for k in 6: bx(r, Vector3(-1.2 + (k % 3) * .55, y + .14 + int(k / 3) * .26, 688.4), Vector3(.5, .25, .32), "#9a968a", false, Basis(Vector3.UP, rng.randf_range(-.2, .2)))
	for k in 7: pipe(r, Vector3(5.4, y, 681.0 + k * .12), Vector3(5.6, y + 2.0, 681.1 + k * .12), .04, "#e8e8e0", 6)
	place(r, "nichols/nh_metal_tool_chest", Vector3(3.6, y, 688.6), 180.0)
	place(r, "nichols/nh_propane_tank", Vector3(4.8, y, 681.0), 0.0)
	place(r, "nichols/nh_sledgehammer_01", Vector3(1.8, y, 686.6), 0.0, 1.0, Vector3(0, 0, 18))
	place(r, "nichols/nh_pipe_wrench", Vector3(1.1, y + 1.09, 686.2), 70.0, 1.0, Vector3(90, 0, 0))
	place(r, "nichols/nh_rusted_hacksaw", Vector3(1.0, y + 1.09, 682.2), 30.0, 1.0, Vector3(90, 0, 0))
	# The flashlight someone dropped: still on, lying on the floor, its beam across the counter.
	bx(r, Vector3(3.25, y + .05, 683.0), Vector3(.26, .07, .07), "#1a1a1a", false, Basis(Vector3.UP, .6))
	var lens := glow_piece(r, Vector3(3.12, y + .05, 683.08), Vector3(.02, .06, .06), Color(.9, .96, 1.0), 3.0, Basis(Vector3.UP, .6))
	var beam := spot(r, Vector3(3.05, y + .1, 683.12), CUTTERS + Vector3(0, .1, 0), Color(.88, .94, 1.0), 2.0, 8.0, 26.0, true)
	lamp_light(beam, 2.0, 0, "", lens, 3.0)
	cable(r, Vector3(2.0, y + 3.4, 685.0), Vector3(2.0, y + 2.6, 685.0), 0.0, "#111111", .01)
	omni(r, Vector3(4.6, y + 2.4, 685.0), Color(.6, .68, .85), .3, 8.0)
	cyl(r, Vector3(2.0, y + 2.55, 685.0), .06, .1, "#3a3830", Basis.IDENTITY, 8)
	litter(r, Vector3(2.0, y, 685.0), Vector2(3.4, 4.0), 40, ["#d8d4c4", "#8a8a88", "#6a5a3a"])
	# The back room: dark, boxes, a cot.
	span(r, Vector3(-6.0, y - .01, 680.25), Vector3(-2.15, y + .03, 689.75), "concrete_floor_02|#5a5650")
	for k in 6: bx(r, Vector3(-5.4 + (k % 2) * .7, y + .25 + int(k / 2) * .5, 681.0), Vector3(.6, .48, .5), "#8a6a4a")
	span(r, Vector3(-5.8, y, 688.0), Vector3(-4.0, y + .45, 689.5), "#4a5a4a", false)

# ---------------------------------------------------------------- the covered overpass

func overpass() -> void:
	var r := R_PLAZA
	var y := OVP_Y
	var z0 := 688.3
	var z1 := 691.7
	ramp(r, Vector3(17.6, TERRACE_Y, 690.0), Vector3(22.0, y, 690.0), z1 - z0, "concrete_floor_02|#8e8a80", .35)
	railing(r, Vector3(17.6, TERRACE_Y, z0 + .05), Vector3(22.0, TERRACE_Y, z0 + .05), 1.15)
	railing(r, Vector3(17.6, TERRACE_Y, z1 - .05), Vector3(22.0, TERRACE_Y, z1 - .05), 1.15)
	span(r, Vector3(22.0, y - .35, z0), Vector3(63.0, y, z1), "concrete_floor_02|#8e8a80", true)
	span(r, Vector3(22.0, y - .005, z0 + .1), Vector3(63.0, y + .01, z1 - .1), "s:corridor|#9c988e")
	for gz in [z0, z1 - .35]: span(r, Vector3(22.0, y - 1.0, gz), Vector3(63.0, y - .35, gz + .35), CONC)
	for zs in [z0 + .08, z1 - .08]:
		span(r, Vector3(22.0, y, zs - .08), Vector3(63.0, y + .3, zs + .08), CONC)
		bx(r, Vector3(42.5, y + .78, zs), Vector3(41.0, .66, .02), "glass#5a7078a0")
		pipe(r, Vector3(22.0, y + 1.15, zs), Vector3(63.0, y + 1.15, zs), .03, "#6a6e6a", 6)
		solid(r, Vector3(42.5, y + .7, zs), Vector3(41.0, 1.4, .16))
	# Its roof: arched frames every three metres, glass between them, panes gone here and there; a ridge.
	var x := 22.0
	while x <= 63.01:
		for zs in [z0 + .1, z1 - .1]: pipe(r, Vector3(x, y, zs), Vector3(x, y + 2.4, zs), .04, "#5a5e5c", 6)
		var arc: Array[Vector3] = [Vector3(x, y + 2.4, z0 + .1), Vector3(x, y + 3.0, z0 + .6), Vector3(x, y + 3.25, 690.0), Vector3(x, y + 3.0, z1 - .6), Vector3(x, y + 2.4, z1 - .1)]
		for i in arc.size() - 1: bar(r, arc[i], arc[i + 1], .07, "#5a5e5c")
		if x < 62.9:
			for side in [-1.0, 1.0]:
				if rng.randf() < .22:
					for k in 3: bx(r, Vector3(x + rng.randf_range(.3, 2.7), y + .01, 690.0 + side * rng.randf_range(.2, 1.4)), Vector3(rng.randf_range(.1, .3), .01, rng.randf_range(.1, .25)), "glass#8aa0a8c0", false, Basis(Vector3.UP, rng.randf() * TAU))
					continue
				bx(r, Vector3(x + 1.5, y + 2.86, 690.0 + side * .95), Vector3(3.0, .02, 1.45), "glass#7a9098a0", false, Basis(Vector3.RIGHT, side * .55))
		x += 3.0
	pipe(r, Vector3(22.0, y + 3.25, 690.0), Vector3(63.0, y + 3.25, 690.0), .05, "#5a5e5c", 6)
	var modes := [2, 0, 3, -1, 2, 4, 0]
	for i in 7:
		var lx := 24.5 + i * 6.0
		bar(r, Vector3(lx, y + 3.2, 690.0), Vector3(lx, y + 2.95, 690.0), .02, "#2a2a2a")
		if modes[i] < 0: bx(r, Vector3(lx, y + 2.9, 690.0), Vector3(1.2, .05, .1), "#5a5e60")
		else: lamp(r, Vector3(lx, y + 2.9, 690.0), TUBE, 1.1, 7.0, modes[i], Vector3(1.2, .05, .1))
	for cx in [30.0, 46.0, 58.0]:
		cyl(r, Vector3(cx, (y - 1.0) * .5, 690.0), .32, y - 1.0, "#8a8e8a", Basis.IDENTITY, 14)
		solid(r, Vector3(cx, (y - 1.0) * .5, 690.0), Vector3(.6, y - 1.0, .6))
	# The east landing, and the stair down to the plaza's east side.
	span(r, Vector3(63.0, y - .35, 684.0), Vector3(67.0, y, 692.0), "concrete_floor_02|#8e8a80", true)
	railing(r, Vector3(63.05, y, 684.0), Vector3(63.05, y, z0))
	railing(r, Vector3(63.0, y, 691.95), Vector3(67.0, y, 691.95))
	railing(r, Vector3(66.95, y, 692.0), Vector3(66.95, y, 684.0))
	for p: Vector3 in [Vector3(63.4, 0, 691.6), Vector3(66.6, 0, 691.6), Vector3(63.4, 0, 684.4), Vector3(66.6, 0, 684.4)]:
		pipe(r, p, p + Vector3.UP * (y - .35), .18, "#8a8e8a", 10)
		solid(r, p + Vector3.UP * (y - .35) * .5, Vector3(.36, y - .35, .36))
	bx(r, Vector3(65.0, y + 2.6, 688.0), Vector3(4.2, .06, 8.2), "glass#7a9098a0")
	stair(r, Vector3(65.0, .15, 672.5), Vector3(65.0, y, 684.0), 3.2, 32, "concrete_floor_02|#9a968c", YELLOW)
	for sx in [63.25, 66.75]:
		side_wall(r, Vector3(sx, .15, 672.5), Vector3(sx, y, 684.0), 1.05, .2, CONC, 8)
		pipe(r, Vector3(sx, 1.2, 672.5), Vector3(sx, y + 1.05, 684.0), .03, YELLOW, 6)
	# What was dropped up here: a wheelchair on its side, bags, a shoe; a smear down the glass.
	place(r, "nichols/nh_wheelchair_01", Vector3(40.0, y, 689.3), 70.0, 1.0, Vector3(0, 0, 85))
	litter(r, Vector3(42.0, y, 690.0), Vector2(18.0, 1.3), 70)
	stain(r, "pool_big", Vector3(51.0, y, 690.2), .4, 1.4, 1.2)
	smear(r, "smear_wall", Vector3(52.4, y + .9, z1 - .12), Vector3(0, 0, -1), 1.2, .8)

# ---------------------------------------------------------------- the station: entrance, concourse, power room

func entrance() -> void:
	var r := R_STATION
	stair(r, Vector3(33.0, CON_Y, 682.6), Vector3(33.0, .15, 671.3), 4.0, 31, TILE_FLOOR, YELLOW)
	for x in [30.8, 35.2]:
		span(r, Vector3(x - .2, CON_Y - .4, 671.1), Vector3(x + .2, -.02, 682.6), TILE, true)
	span(r, Vector3(30.6, -1.6, 682.6), Vector3(35.4, -.02, 682.9), CONC)
	# Above the street: parapets with glass on them (nobody climbs in over the side), the canopy, its lightbox.
	var p := R_PLAZA
	for x in [30.8, 35.2]:
		span(p, Vector3(x - .2, 0, 671.1), Vector3(x + .2, 1.2, 683.0), "concrete_wall_008|#c4c0b4", true)
		bx(p, Vector3(x, 1.75, 677.05), Vector3(.06, 1.1, 11.9), "glass#5a7078a0")
		solid(p, Vector3(x, 1.75, 677.05), Vector3(.12, 1.1, 11.9))
		pipe(p, Vector3(x, 2.32, 671.1), Vector3(x, 2.32, 683.0), .03, "#6a6e6a", 6)
	span(p, Vector3(30.6, 0, 682.6), Vector3(35.4, 1.2, 683.0), "concrete_wall_008|#c4c0b4", true)
	bx(p, Vector3(33.0, 1.75, 682.8), Vector3(4.8, 1.1, .06), "glass#5a7078a0")
	solid(p, Vector3(33.0, 1.75, 682.8), Vector3(4.8, 1.1, .12))
	for c: Vector3 in [Vector3(30.6, .15, 671.15), Vector3(35.4, .15, 671.15)]: pipe(p, c, c + Vector3.UP * 3.15, .06, "#4a4e4c", 8)
	for c: Vector3 in [Vector3(30.8, 1.2, 682.8), Vector3(35.2, 1.2, 682.8)]: pipe(p, c, c + Vector3.UP * 2.1, .06, "#4a4e4c", 8)
	bx(p, Vector3(33.0, 3.36, 677.0), Vector3(5.4, .06, 12.2), "glass#6a8088a0", false, Basis(Vector3.RIGHT, -.03))
	for k in 7: bar(p, Vector3(30.4, 3.4, 671.0 + k * 2.0), Vector3(35.6, 3.4, 671.0 + k * 2.0), .06, "#4a4e4c")
	bx(p, Vector3(33.0, 3.15, 671.0), Vector3(5.2, .5, .2), "#2a2e30")
	var box := glow_piece(p, Vector3(33.0, 3.15, 670.88), Vector3(1.5, .38, .02), Color(.25, .5, 1.0), 2.4)
	lamp_light(omni(p, Vector3(33.0, 2.9, 670.2), Color(.3, .5, 1.0), .6, 6.0), .6, 3, "", box, 2.4)
	# The shutter, down and chained: its curtain rolls up into the box when the chain is cut.
	span(p, Vector3(30.9, 2.8, 671.0), Vector3(35.1, 3.2, 671.55), "#5a5e5a")
	for gx in [31.0, 35.0]: span(p, Vector3(gx - .06, .15, 671.25), Vector3(gx + .06, 2.8, 671.55), "#4a4e4a")
	shutter_body = StaticBody3D.new()
	shutter_body.collision_layer = 2
	shutter_body.name = "Subway shutter"
	roots[p].add_child(shutter_body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(4.0, 2.65, .14)
	cs.shape = bs
	cs.position = Vector3(33.0, .15 + 1.325, 671.42)
	shutter_body.add_child(cs)
	shutter_curtain = Node3D.new()
	shutter_curtain.name = "Shutter curtain"
	shutter_curtain.position = Vector3(33.0, 2.8, 671.42)
	roots[p].add_child(shutter_curtain)
	s.piece(shutter_curtain, Vector3(0, -1.325, 0), Vector3(3.9, 2.65, .05), SHUT)
	s.piece(shutter_curtain, Vector3(0, -2.6, -.03), Vector3(3.9, .1, .08), "#4a4e4a")
	for k in 4: s.piece(shutter_curtain, Vector3(rng.randf_range(-1.4, 1.4), -1.4 + rng.randf_range(-.4, .4), -.04), Vector3(.32, .42, .005), "#e8e4d6")
	chain = Node3D.new()
	chain.name = "Shutter chain"
	roots[p].add_child(chain)
	var links: Array[Vector3] = [Vector3(31.12, .45, 671.32), Vector3(31.6, .3, 671.28), Vector3(32.2, .24, 671.27), Vector3(32.8, .26, 671.27), Vector3(33.4, .26, 671.27), Vector3(34.0, .24, 671.27), Vector3(34.5, .3, 671.28), Vector3(34.88, .45, 671.32)]
	for i in links.size() - 1:
		var a := links[i]
		var b := links[i + 1]
		var lk: MeshInstance3D = s.piece(chain, (a + b) * .5, Vector3(.04, .04, (b - a).length()), "#6a6a66")
		lk.basis = Basis.looking_at((b - a).normalized(), Vector3.UP)
	s.piece(chain, Vector3(33.1, .16, 671.24), Vector3(.09, .12, .05), "#b8962a")
	smear(p, "smear_wall", Vector3(32.4, 1.3, 671.36), Vector3(0, 0, -1), 1.2, .9)
	smear(p, "smear_wall", Vector3(34.0, .8, 671.36), Vector3(0, 0, -1), .9, .6)
	# The well below the shutter: dark; at its foot, the green EXIT over the way in.
	exit_sign(r, Vector3(33.0, -1.9, 682.45), PI)

func exit_sign(r: int, at: Vector3, yaw: float) -> void:
	bx(r, at, Vector3(.9, .3, .08), "#e8e8e0", false, Basis(Vector3.UP, yaw))
	var g := glow_piece(r, at + Basis(Vector3.UP, yaw) * Vector3(0, 0, .045), Vector3(.82, .24, .01), Color(.15, .95, .4), 2.4, Basis(Vector3.UP, yaw))
	lamp_light(null, 0.0, 0, "", g, 2.4)
	label(r, at + Basis(Vector3.UP, yaw) * Vector3(0, 0, .06), "EXIT", .16, yaw, Color(.92, 1.0, .94), true, 30.0)
	var l := omni(r, at + Basis(Vector3.UP, yaw) * Vector3(0, -.2, .5), Color(.2, 1.0, .45), .35, 4.0)
	lamp_light(l, .35, 0)

func concourse() -> void:
	var r := R_STATION
	var y := CON_Y
	holed(r, Vector3(34, y - .3, 697.3), Vector3(28, .6, 29.4), [27.5, 31.5, 700.0, 711.0], TILE_FLOOR, true)
	span(r, Vector3(20, -1.45, 682.6), Vector3(48, -1.4, 712), CEIL)
	span(r, Vector3(19.7, y, 682.6), Vector3(20, -1.4, 712), TILE, true)
	span(r, Vector3(48, y, 682.6), Vector3(48.3, -1.4, 686.4), TILE, true)
	span(r, Vector3(48, y, 687.6), Vector3(48.3, -1.4, 712), TILE, true)
	span(r, Vector3(48, -3.0, 686.4), Vector3(48.3, -1.4, 687.6), TILE, true)
	# (0.67: the doorway's own floor: the concourse's stopped at x 48, the power room's starts at 48.3, nothing under.)
	span(r, Vector3(47.9, y - .3, 686.3), Vector3(48.4, y, 687.7), TILE_FLOOR, true)
	span(r, Vector3(20, y, 682.3), Vector3(30.6, -1.4, 682.6), TILE, true)
	span(r, Vector3(35.4, y, 682.3), Vector3(48, -1.4, 682.6), TILE, true)
	span(r, Vector3(20, y, 712), Vector3(48, -1.4, 712.3), TILE, true)
	# The lower band of dark tile round the walls.
	span(r, Vector3(20.01, y, 682.6), Vector3(20.05, y + 1.2, 712), TILE_LOW)
	span(r, Vector3(47.95, y, 687.6), Vector3(47.99, y + 1.2, 712), TILE_LOW)
	span(r, Vector3(20, y, 711.95), Vector3(48, y + 1.2, 711.99), TILE_LOW)
	for cx in [27.0, 41.0]:
		for cz in [688.0, 694.0, 703.0, 709.0]: span(r, Vector3(cx - .4, y, cz - .4), Vector3(cx + .4, -1.4, cz + .4), TILE, true)
	# The ticket office: a glass booth, its desk, its dead screen.
	span(r, Vector3(25.9, y, 684.0), Vector3(26.5, y + 1.0, 693.0), TILE_LOW, true)
	bx(r, Vector3(26.2, y + 1.8, 688.5), Vector3(.04, 1.6, 9.0), "glass#4a5a62a0")
	solid(r, Vector3(26.2, y + 1.8, 688.5), Vector3(.12, 1.6, 9.0))
	span(r, Vector3(20, y + 2.6, 684.0), Vector3(26.5, y + 2.7, 693.0), "#cfcbc0")
	span(r, Vector3(20, y, 683.8), Vector3(26.5, y + 2.6, 684.0), TILE, true)
	span(r, Vector3(20, y, 693.0), Vector3(26.5, y + 2.6, 693.2), TILE, true)
	span(r, Vector3(23.8, y, 685.0), Vector3(25.6, y + .78, 692.0), "#6a6e6a")
	for k in 3: bx(r, Vector3(24.6, y + .95, 686.0 + k * 2.8), Vector3(.1, .32, .5), "#1a1c1e")
	place(r, "street/plastic_monobloc_chair_01", Vector3(23.0, y, 688.0), 70.0, 1.0, Vector3(0, 0, 85))
	# The faregates: steel cabinets, their glass flaps shut (power off); glass walls either side, full height.
	for k in 17:
		var gx := 24.0 + k
		span(r, Vector3(gx - .12, y, 696.3), Vector3(gx + .12, y + 1.0, 697.7), "#8a8e8e", true)
		bx(r, Vector3(gx, y + 1.01, 697.0), Vector3(.24, .02, 1.4), "#2a2e30")
		lamp(r, Vector3(gx, y + 1.03, 696.5), Color(1.0, .2, .15), 0.0, 1.0, 0, Vector3(.08, .02, .08), "!outer_power", false)
		lamp(r, Vector3(gx, y + 1.03, 697.5), Color(.2, 1.0, .4), 0.0, 1.0, 0, Vector3(.08, .02, .08), "outer_power", false)
	flaps = Node3D.new()
	flaps.name = "Faregate flaps"
	roots[r].add_child(flaps)
	for k in 16:
		s.piece(flaps, Vector3(24.5 + k, y + 1.0, 697.0), Vector3(.72, 1.6, .03), "glass#7a98a0a8")
	var fb := StaticBody3D.new()
	fb.collision_layer = 2
	fb.name = "Faregate flaps body"
	roots[r].add_child(fb)
	flaps_shape = CollisionShape3D.new()
	var fs := BoxShape3D.new()
	fs.size = Vector3(16.0, 2.0, .2)
	flaps_shape.shape = fs
	flaps_shape.position = Vector3(32.0, y + 1.0, 697.0)
	fb.add_child(flaps_shape)
	for seg: Array in [[20.0, 23.88], [40.12, 48.0]]:
		var a: float = seg[0]
		var b: float = seg[1]
		bx(r, Vector3((a + b) * .5, y + 1.1, 697.0), Vector3(b - a, 2.2, .04), "glass#5a7078a0")
		solid(r, Vector3((a + b) * .5, y + 1.1, 697.0), Vector3(b - a, 2.2, .12))
		var px := a
		while px <= b + .01:
			pipe(r, Vector3(px, y, 697.0), Vector3(px, y + 2.2, 697.0), .03, "#6a6e6a", 6)
			px += 1.3
	# The stair down to the platform, its hole railed with glass.
	stair(r, Vector3(29.5, PLAT_Y, 711.0), Vector3(29.5, y, 700.0), 4.0, 29, TILE_FLOOR, YELLOW)
	for e: Array in [[Vector3(27.42, y, 700.0), Vector3(27.42, y, 711.0)], [Vector3(31.58, y, 700.0), Vector3(31.58, y, 711.0)], [Vector3(27.5, y, 711.05), Vector3(31.5, y, 711.05)]]:
		railing(r, e[0], e[1], 1.15, "#6a6e6a")
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		bx(r, (a + b) * .5 + Vector3.UP * .6, Vector3(maxf(absf(b.x - a.x), .03), .9, maxf(absf(b.z - a.z), .03)), "glass#5a7078a0")
	exit_sign(r, Vector3(29.5, -2.0, 699.9), PI)
	# The lights: rows of tubes, dark until the power is back (then most of them flicker on); now only the
	# emergency lights, dim and failing.
	var row := 0
	for lz in [686.0, 691.5, 699.0, 705.0, 710.0]:
		for lx in [24.0, 30.0, 36.0, 42.0]:
			var mode: int = [0, 2, 0, 3, 0, 2, 4, 0][(row * 3 + int(lx)) % 8]
			if (row + int(lx)) % 7 == 3:
				bx(r, Vector3(lx, -1.5, lz), Vector3(1.2, .06, .14), "#6a6e70")
				continue
			lamp(r, Vector3(lx, -1.5, lz), TUBE, 1.5 if int(lx) % 12 == 0 else 0.0, 10.0, mode, Vector3(1.2, .06, .14), "outer_power", int(lx) % 12 == 0)
		row += 1
	for e: Vector3 in [Vector3(21.0, -2.0, 684.0), Vector3(46.5, -2.0, 695.0), Vector3(22.0, -2.0, 708.0)]:
		lamp(r, e, Color(1.0, .38, .25), .9, 11.0, 2, Vector3(.3, .1, .1), "!outer_power")
	# Ads and the line map on the walls (lit with the power), benches, bins, an ATM, cameras.
	for k in 4:
		var az := 699.0 + k * 3.2
		var g := glow_piece(r, Vector3(47.93, y + 2.0, az), Vector3(.02, 1.6, 1.1), Color(.95, .92, .85), 1.6)
		lamp_light(null, 0.0, [2, 0, 3, 0][k], "outer_power", g, 1.6)
		bx(r, Vector3(47.91, y + 2.0, az), Vector3(.01, 1.2, .8), BOARD_COLS[(k * 3 + 2) % BOARD_COLS.size()])
	bx(r, Vector3(20.06, y + 2.2, 700.0), Vector3(.02, 1.8, 4.2), "#e8e6de")
	for li in 3:
		var lc: String = ["#2a8a4a", "#c83228", "#2a5aa0"][li]
		bx(r, Vector3(20.08, y + 1.7 + li * .45, 700.0), Vector3(.01, .05, 3.6), lc)
		for k in 8: bx(r, Vector3(20.085, y + 1.7 + li * .45, 698.4 + k * .45), Vector3(.01, .09, .09), "#f0f0e8")
	for bz in [702.0, 706.0]: span(r, Vector3(46.9, y, bz - 1.0), Vector3(47.6, y + .45, bz + 1.0), "#6a6e6a", true)
	span(r, Vector3(46.8, y, 690.4), Vector3(47.8, y + 1.6, 691.4), "#5a5e60", true)
	bx(r, Vector3(46.79, y + 1.15, 690.9), Vector3(.02, .3, .4), "#0e1214")
	for c: Vector3 in [Vector3(22.0, -1.6, 696.0), Vector3(46.0, -1.6, 696.0), Vector3(34.0, -1.6, 710.0)]: cyl(r, c, .12, .14, "#1a1a1a", Basis.IDENTITY, 10)
	# What happened here: bags and a suitcase dropped at the gates, a pool at them, drag marks to the stair down.
	place(r, "nichols/nh_vintage_suitcase", Vector3(36.0, y, 694.6), 30.0)
	for k in 5: bx(r, Vector3(rng.randf_range(28.0, 40.0), y + .12, rng.randf_range(690.0, 696.0)), Vector3(.4, .24, .3), ["#3a2a20", "#20304a", "#6a1a1a"][k % 3], false, Basis(Vector3.UP, rng.randf() * TAU))
	stain(r, "pool_big", Vector3(31.0, y, 695.4), .8, 2.0, 1.6)
	drag(r, Vector3(30.0, y, 698.0), Vector3(29.6, y, 701.0), false)
	smear(r, "smear_wall", Vector3(22.0, y + 1.2, 697.07), Vector3(0, 0, 1), 1.2, .9)
	litter(r, Vector3(34, y, 696), Vector2(13.0, 13.0), 140)
	hum(r, Vector3(34, -3.0, 696), "res://assets/audio/nichols/cellar_tone.ogg", -14.0, 12.0)
	hum(r, Vector3(24, -3.0, 706), "res://assets/audio/nichols/drip.ogg", -16.0, 5.0)

func power_room() -> void:
	var r := R_STATION
	var y := CON_Y
	span(r, Vector3(48.3, y - .6, 682.9), Vector3(56.3, y, 692.3), "concrete_floor_02|#6a6660", true)
	span(r, Vector3(48.3, y, 682.7), Vector3(56.3, -2.0, 683.0), ROUGH, true)
	span(r, Vector3(48.3, y, 692.0), Vector3(56.3, -2.0, 692.3), ROUGH, true)
	span(r, Vector3(56.0, y, 683.0), Vector3(56.3, -2.0, 692.0), ROUGH, true)
	span(r, Vector3(48.3, -2.0, 682.7), Vector3(56.3, -1.8, 692.3), ROUGH, true)
	bx(r, Vector3(48.9, y + 1.05, 685.9), Vector3(.05, 2.1, 1.15), "#5a6a6a", false, Basis(Vector3.UP, 1.2))
	# The breakers on the east wall: four cabinets, the main switch with its lever, indicators.
	for i in 4:
		var cz := 684.9 + i * .95
		span(r, Vector3(55.55, y + .2, cz), Vector3(56.0, y + 2.2, cz + .85), "#7e8482", true)
		bx(r, Vector3(55.54, y + 1.2, cz + .42), Vector3(.01, 1.9, .02), "#3a3e3c")
		lamp(r, Vector3(55.53, y + 2.0, cz + .2), Color(1.0, .2, .1), 0.0, 1.0, 5, Vector3(.01, .05, .05), "!outer_power", false)
		lamp(r, Vector3(55.53, y + 2.0, cz + .2), Color(.2, 1.0, .35), 0.0, 1.0, 0, Vector3(.01, .05, .05), "outer_power", false)
	lever = Node3D.new()
	lever.name = "Main breaker lever"
	lever.position = Vector3(55.45, y + 1.3, PANEL.z)
	roots[r].add_child(lever)
	s.piece(lever, Vector3(0, .25, 0), Vector3(.05, .5, .05), "#c8c8c0")
	s.piece(lever, Vector3(-.05, .5, 0), Vector3(.1, .08, .3), "#c83228")
	lever.rotation.z = -.5
	# The night shift's desk, his chair over, his cot; his hard hat, his flashlight where he dropped them.
	span(r, Vector3(49.0, y, 689.8), Vector3(51.6, y + .76, 691.6), "#6a6e6a", true)
	bx(r, Vector3(50.0, y + .9, 690.6), Vector3(.5, .3, .05), "#1a1c1e")
	bx(r, Vector3(51.0, y + .78, 690.9), Vector3(.3, .03, .22), "#e8e4d6")
	place(r, "street/plastic_monobloc_chair_01", Vector3(50.5, y, 688.8), 200.0, 1.0, Vector3(85, 0, 0))
	span(r, Vector3(52.5, y, 690.6), Vector3(55.2, y + .42, 691.7), "#4a5a4a", true)
	cyl(r, Vector3(53.0, y + .1, 686.4), .16, .12, YELLOW, Basis(Vector3.RIGHT, .4), 12)
	place(r, "nichols/nh_metal_tool_chest", Vector3(49.6, y, 683.8), 0.0)
	lamp(r, Vector3(52.2, y + .25, 684.2), Color(1.0, .78, .5), .8, 7.0, 1, Vector3(.15, .25, .15))
	stain(r, "pool_big", Vector3(53.4, y, 687.6), .3, 1.8, 1.4)
	drag(r, Vector3(53.4, y, 687.6), Vector3(55.0, y, 683.6), false)
	for k in 5: bar(r, Vector3(55.5, y + .02, 685.0 + k * .7), Vector3(rng.randf_range(49.0, 54.0), y + .02, rng.randf_range(683.5, 691.0)), .03, "#1a1a1a")
	hum(r, Vector3(55.0, y + 1.5, 686.7), "res://assets/audio/nichols/bulb_hum.ogg", -26.0, 3.0)

# ---------------------------------------------------------------- the platform, the train, the tunnel, the way out

func platform() -> void:
	var r := R_STATION
	var y := PLAT_Y
	span(r, Vector3(25, y - .6, 688), Vector3(33.1, y, 733.2), TILE_FLOOR, true)
	span(r, Vector3(32.6, BED_Y, 688), Vector3(33.1, y - .6, 733.2), ROUGH, true)
	span(r, Vector3(32.3, y, 688), Vector3(32.9, y + .01, 733.2), YELLOW)
	span(r, Vector3(32.95, y, 688), Vector3(33.08, y + .011, 733.2), "#e8e6de")
	span(r, Vector3(24.7, y, 687.7), Vector3(25, -5.8, 733.5), TILE, true)
	span(r, Vector3(24.71, y, 688), Vector3(24.75, y + 1.2, 733.2), TILE_LOW)
	span(r, Vector3(25, BED_Y, 687.7), Vector3(36.6, -5.8, 688), TILE, true)
	span(r, Vector3(25, y, 733.2), Vector3(33.1, -5.8, 733.5), TILE, true)
	holed(r, Vector3(30.8, -5.83, 700.0), Vector3(11.6, .06, 24.0), [27.5, 31.5, 700.0, 711.0], CEIL, false)
	span(r, Vector3(25, -5.95, 712), Vector3(36.6, -5.8, 733.5), CEIL)
	for pz in [694.0, 717.0, 725.0, 731.0]: span(r, Vector3(25.9, y, pz - .3), Vector3(26.5, -5.8, pz + .3), TILE, true)
	for bz in [698.0, 704.0, 720.0]: span(r, Vector3(25.1, y, bz - 1.0), Vector3(25.6, y + .45, bz + 1.0), "#6a6e6a", true)
	cyl(r, Vector3(24.95, -7.2, 708.0), .35, .06, "#e8e6de", Basis(Vector3.FORWARD, PI * .5), 20)
	bar(r, Vector3(24.9, -7.2, 708.0), Vector3(24.9, -7.05, 708.1), .02, "#1a1a1a")
	bar(r, Vector3(24.9, -7.2, 708.0), Vector3(24.9, -7.35, 707.95), .02, "#1a1a1a")
	bx(r, Vector3(29.2, -6.4, 716.0), Vector3(.2, .4, 2.2), "#1a1a1a")
	var led := glow_piece(r, Vector3(29.31, -6.4, 716.0), Vector3(.01, .3, 2.0), Color(1.0, .25, .1), 1.8)
	lamp_light(null, 0.0, 4, "outer_power", led, 1.8)
	for k in 4:
		var az: float = [700.0, 712.0, 722.0, 728.0][k]
		var g := glow_piece(r, Vector3(24.77, y + 2.0, az), Vector3(.02, 1.7, 1.2), Color(.95, .92, .85), 1.5)
		lamp_light(null, 0.0, [2, 0, 3, 4][k], "outer_power", g, 1.5)
		bx(r, Vector3(24.79, y + 2.0, az), Vector3(.01, 1.3, .85), BOARD_COLS[(k * 5 + 1) % BOARD_COLS.size()])
	var modes := [0, 2, 0, 3, 0, 4, 2, 0]
	var zs := [692.0, 697.0, 703.0, 709.0, 715.0, 721.0, 727.0, 731.0]
	for i in 8:
		var lit := i % 2 == 0
		lamp(r, Vector3(29.2, -6.0, zs[i]), TUBE, 1.4 if lit else 0.0, 10.0, modes[i], Vector3(.14, .06, 1.2), "outer_power", lit)
	lamp(r, Vector3(29.2, -6.1, 700.0), Color(1.0, .3, .2), .8, 10.0, 2, Vector3(.3, .1, .1), "!outer_power")
	lamp(r, Vector3(29.2, -6.1, 724.0), Color(1.0, .3, .2), .5, 9.0, 1, Vector3(.3, .1, .1), "!outer_power")
	exit_sign(r, Vector3(29.5, -6.3, 712.4), 0.0)
	# They went into the train: pools at the edge, drags to its one open door; luggage left on the platform.
	place(r, "nichols/nh_vintage_suitcase", Vector3(30.0, y, 718.0), 80.0)
	place(r, "nichols/nh_vintage_suitcase", Vector3(27.2, y, 726.4), 10.0, 1.0, Vector3(0, 0, 80))
	stain(r, "pool_big", Vector3(31.4, y, 721.2), .5, 1.8, 1.4)
	drag(r, Vector3(28.6, y, 714.0), Vector3(32.4, y, 721.8), false)
	drag(r, Vector3(27.0, y, 730.0), Vector3(32.6, y, 723.0), false)
	litter(r, Vector3(29, y, 712), Vector2(3.6, 20.0), 120)
	hum(r, Vector3(29, -7.0, 712), "res://assets/audio/nichols/cellar_tone.ogg", -16.0, 12.0)
	hum(r, Vector3(29, -7.0, 726), "res://assets/audio/nichols/drip.ogg", -18.0, 5.0)

func train() -> void:
	var r := R_TUNNEL
	car(r, CARS[0][0], CARS[0][1], false, true, OPEN_DOOR, -1)
	# (0.67: its tubes die as the squad reaches the gangway: outer_dread.gd `outer_train_dark`.)
	car(r, CARS[1][0], CARS[1][1], true, false, -1.0, 4, "!outer_train_dark")
	# The bellows between the cars.
	var xm := (TRAIN_X0 + TRAIN_X1) * .5
	span(r, Vector3(xm - .6, TRAIN_FLOOR - .05, CARS[0][1]), Vector3(xm + .6, TRAIN_FLOOR, CARS[1][0]), "#2a2a28", true)
	for sx in [xm - .66, xm + .6]: block(r, Vector3(sx, TRAIN_FLOOR, CARS[0][1]), Vector3(sx + .06, -8.05, CARS[1][0]))
	# Inside: luggage against the benches, newspapers, a shoe; blood from the door to the bench and on its glass.
	place(r, "nichols/nh_vintage_suitcase", Vector3(TRAIN_X0 + .45, TRAIN_FLOOR + .46, 726.0), 90.0)
	place(r, "nichols/nh_vintage_suitcase", Vector3(TRAIN_X1 - .5, TRAIN_FLOOR, 739.0), 0.0, 1.0, Vector3(0, 0, 90))
	litter(r, Vector3(xm, TRAIN_FLOOR, 722.0), Vector2(.6, 8.0), 50)
	litter(r, Vector3(xm, TRAIN_FLOOR, 742.0), Vector2(.6, 8.0), 50)
	stain(r, "pool_big", Vector3(xm, TRAIN_FLOOR, 723.6), .2, 1.4, 1.0)
	drag(r, Vector3(TRAIN_X0 + .3, TRAIN_FLOOR, 722.3), Vector3(TRAIN_X1 - .4, TRAIN_FLOOR, 727.5), false)
	stain(r, "spatter_floor", Vector3(xm, TRAIN_FLOOR, 744.5), 1.0, 1.4, 1.2)
	smear(r, "smear_wall", Vector3(TRAIN_X1 - .1, -8.7, 741.7), Vector3(-1, 0, 0), 1.0, .7)

func tunnel() -> void:
	var r := R_TUNNEL
	span(r, Vector3(33.1, BED_Y - .5, 688), Vector3(36.5, BED_Y, 796), "gravel_road|#4c4a46", true)
	span(r, Vector3(36.5, BED_Y, 688), Vector3(37.0, -5.4, 796), ROUGH, true)
	span(r, Vector3(32.6, BED_Y, 733.2), Vector3(33.1, -6.6, 780.5), ROUGH, true)
	span(r, Vector3(32.6, BED_Y, 783.5), Vector3(33.1, -6.6, 796), ROUGH, true)
	span(r, Vector3(32.6, -8.6, 780.5), Vector3(33.1, -6.6, 783.5), ROUGH, true)
	span(r, Vector3(32.6, -6.9, 733.2), Vector3(37.0, -6.6, 796), ROUGH, true)
	var rz := 736.0
	while rz < 795.0:
		bx(r, Vector3(34.8, -6.95, rz), Vector3(4.4, .2, .3), CONC)
		for wx in [33.12, 36.48]: bx(r, Vector3(wx, -8.9, rz), Vector3(.06, 4.0, .3), CONC)
		rz += 4.0
	for rx in [34.0, 35.2]: span(r, Vector3(rx - .035, BED_Y, 688), Vector3(rx + .035, BED_Y + .15, 795), "#5a5856")
	var sz := 688.4
	while sz < 795.0:
		bx(r, Vector3(34.6, BED_Y + .04, sz), Vector3(2.0, .1, .22), "#6a6660")
		sz += .7
	span(r, Vector3(35.95, BED_Y, 688), Vector3(36.2, BED_Y + .35, 795), "#7a6a3a")
	for cy in [-8.2, -8.6]: span(r, Vector3(36.32, cy, 688), Vector3(36.5, cy + .05, 795), "#5a5e5a")
	for k in 3: span(r, Vector3(36.38, -8.15 - k * .05, 688), Vector3(36.46, -8.1 - k * .05, 795), "#121212")
	# Emergency lights, caged amber, on their own batteries: some steady, some failing, some gone.
	var modes := [0, 3, 2, 0, 3, 1, 0]
	for i in 7:
		var lz := 740.0 + i * 8.0
		bx(r, Vector3(36.4, -8.7, lz), Vector3.ONE * .16, "#2a2a28")
		lamp(r, Vector3(36.3, -8.75, lz), Color(1.0, .68, .32), .9, 8.0, modes[i], Vector3(.1, .14, .1))
	lamp(r, Vector3(33.25, -8.3, 779.6), Color(1.0, .25, .2), .4, 4.0, 1, Vector3(.08, .1, .1))
	for k in 4: bx(r, Vector3(33.12, -9.6, 745.0 + k * 13.0), Vector3(.02, .25, .35), "#e8e6de")
	for k in 8: bx(r, Vector3(rng.randf_range(33.5, 35.8), BED_Y + .17, rng.randf_range(752.0, 792.0)), Vector3(rng.randf_range(.8, 2.0), .01, rng.randf_range(.6, 1.6)), "puddle", false, Basis(Vector3.UP, rng.randf() * TAU))
	place(r, "nichols/nh_street_rat", Vector3(33.5, BED_Y, 761.0), 40.0)
	place(r, "nichols/nh_street_rat", Vector3(36.0, BED_Y + .35, 771.0), 200.0)
	# Its far end: the roof down, earth and water coming through.
	heap(r, Vector3(32.6, BED_Y, 792.4), Vector3(37.0, -6.6, 796.0), 26)
	bx(r, Vector3(34.8, -8.0, 791.6), Vector3(4.6, .4, 3.0), ROUGH, false, Basis(Vector3.RIGHT, .7))
	hum(r, Vector3(34.8, -8.0, 790.0), "res://assets/audio/nichols/drip.ogg", -10.0, 6.0)
	hum(r, Vector3(34.8, -8.0, 765.0), "res://assets/audio/nichols/cellar_tone.ogg", -18.0, 10.0)
	# The cross passage to the emergency exit, its steel door open, EXIT over it.
	span(r, Vector3(30.4, BED_Y - .3, 780.5), Vector3(33.1, BED_Y, 783.5), "concrete_floor_02|#6e6a62", true)
	span(r, Vector3(30.4, BED_Y, 780.2), Vector3(33.1, -8.6, 780.5), ROUGH, true)
	span(r, Vector3(30.4, BED_Y, 783.5), Vector3(33.1, -8.6, 783.8), ROUGH, true)
	span(r, Vector3(30.4, -8.8, 780.2), Vector3(33.1, -8.6, 783.8), ROUGH, true)
	bx(r, Vector3(33.55, BED_Y + 1.05, 780.0), Vector3(.05, 2.1, 1.1), "#5a6a6a", false, Basis(Vector3.UP, -1.3))
	exit_sign(r, Vector3(33.2, -8.25, EXIT_Z), PI * .5)

func long_stair() -> void:
	var r := R_TUNNEL
	var a := Vector3(30.4, BED_Y, EXIT_Z)
	var b := Vector3(9.5, 0.0, EXIT_Z)
	stair(r, a, b, 2.4, 66, "concrete_floor_02|#7c786f", YELLOW)
	side_wall(r, Vector3(30.4, BED_Y, EXIT_Z - 1.3), Vector3(9.5, 0.0, EXIT_Z - 1.3), 3.0, .2, "rough_concrete|#9a968c", 14)
	side_wall(r, Vector3(30.4, BED_Y, EXIT_Z + 1.3), Vector3(9.5, 0.0, EXIT_Z + 1.3), 3.0, .2, "rough_concrete|#9a968c", 14)
	var d := b - a
	var run := Vector2(d.x, d.z).length()
	var dir := Vector3(d.x, 0, d.z).normalized()
	var basis := Basis(Vector3.UP, atan2(dir.x, dir.z)) * Basis(Vector3.RIGHT, -atan2(d.y, run))
	bx(r, (a + b) * .5 + Vector3.UP * 2.95, Vector3(2.8, .2, d.length() + .4), "rough_concrete|#8a867c", false, basis)
	for side in [-1.12, 1.12]: pipe(r, a + Vector3(0, .95, side), b + Vector3(0, .95, side), .03, YELLOW, 6)
	var modes := [3, 2, -1, 4, 2, 3]
	for i in 6:
		var p := a.lerp(b, (i + .5) / 6.0) + Vector3.UP * 2.8
		if modes[i] < 0: bx(r, p, Vector3(.9, .05, .1), "#5a5e60", false, Basis(Vector3.UP, PI * .5))
		else: lamp(r, p, TUBE, 1.0, 6.5, modes[i], Vector3(.9, .05, .1), "!outer_stair_dark")
	stain(r, "drag_a", a.lerp(b, .4) + Vector3.UP * .1, PI * .5, 1.6, .6, .8)
	stain(r, "spatter_floor", a.lerp(b, .7) + Vector3.UP * .1, 1.0, 1.2, 1.0, .8)
	# The exit kiosk at the top (riverside): a concrete box with a door out onto the river road.
	var k := R_RIVER
	span(k, Vector3(4.25, -.3, 778.85), Vector3(9.5, 0, 785.15), "concrete_floor_02|#8a867c", true)
	span(k, Vector3(9.5, -.3, 778.85), Vector3(14.25, 0, EXIT_Z - 1.2), "concrete_floor_02|#8a867c", true)
	span(k, Vector3(9.5, -.3, EXIT_Z + 1.2), Vector3(14.25, 0, 785.15), "concrete_floor_02|#8a867c", true)
	railing(k, Vector3(9.6, 0, EXIT_Z - 1.25), Vector3(14.2, 0, EXIT_Z - 1.25), 1.1)
	railing(k, Vector3(9.6, 0, EXIT_Z + 1.25), Vector3(14.2, 0, EXIT_Z + 1.25), 1.1)
	var kw := "concrete_wall_008|#b4ae9e"
	span(k, Vector3(4.0, 0, 778.6), Vector3(4.25, 3.1, 785.4), kw, true)
	span(k, Vector3(4.0, 0, 778.6), Vector3(14.5, 3.1, 778.85), kw, true)
	span(k, Vector3(4.0, 0, 785.15), Vector3(5.6, 3.1, 785.4), kw, true)
	span(k, Vector3(7.4, 0, 785.15), Vector3(14.5, 3.1, 785.4), kw, true)
	span(k, Vector3(5.6, 2.2, 785.15), Vector3(7.4, 3.1, 785.4), kw, true)
	span(k, Vector3(14.25, .5, 778.85), Vector3(14.5, 3.1, 785.15), kw, true)
	span(k, Vector3(14.25, -3.0, 778.85), Vector3(14.5, .5, EXIT_Z - 1.2), kw, true)
	span(k, Vector3(14.25, -3.0, EXIT_Z + 1.2), Vector3(14.5, .5, 785.15), kw, true)
	span(k, Vector3(4.0, 3.1, 778.6), Vector3(14.5, 3.4, 785.4), CONC, true)
	# (0.67: its door is a node of its own, open against the wall outside until the seal: outer_dread.gd. Under the
	# doorway a floor: the kiosk's stopped at z 785.15, the road's dirt starts at 785.5, nothing under the gap.)
	span(k, Vector3(5.4, -.3, 785.1), Vector3(7.6, 0, 785.6), "concrete_floor_02|#8a867c", true)
	span(k, Vector3(4.4, 0, 779.0), Vector3(5.6, .8, 780.3), "#6a6e6a", true)
	cyl(k, Vector3(4.5, .3, 784.6), .1, .6, "#c83228", Basis.IDENTITY, 10)
	lamp(k, Vector3(7.0, 2.95, 782.0), TUBE, .9, 6.0, 2, Vector3(1.0, .05, .1))
	exit_sign(k, Vector3(6.5, 2.55, 785.05), PI)
	exit_sign(k, Vector3(6.5, 2.55, 785.45), 0.0)

# ---------------------------------------------------------------- the river road and the bridge

func riverside() -> void:
	var r := R_RIVER
	# (Not south of the road: the long stair comes up under there; the kiosk and the hill have floors of their own.)
	span(r, Vector3(-16, -1.0, 785.5), Vector3(106, -.02, 807.0), DIRT, true)
	span(r, Vector3(-14, -.1, 786.0), Vector3(100.2, 0, 803.0), ROAD, true)
	span(r, Vector3(-14, 0, 803.0), Vector3(88, .15, 806.5), WALK, true)
	bx(r, Vector3(37.0, .08, 802.98), Vector3(102.0, .17, .12), CURB)
	var dx := -12.0
	while dx < 98.0:
		bx(r, Vector3(dx + 1.5, .005, 794.5), Vector3(3.0, .01, .14), "#d6d2c4")
		dx += 7.0
	# The river wall: a balustrade, planters along it.
	span(r, Vector3(-14, 0, 806.5), Vector3(88, .5, 806.95), "concrete_wall_008|#cfcbbe", true)
	span(r, Vector3(-14, .95, 806.45), Vector3(88, 1.1, 807.0), "concrete_wall_008|#cfcbbe")
	solid(r, Vector3(37.0, .9, 806.72), Vector3(102.0, 1.6, .5))
	var bxp := -13.8
	while bxp < 88.0:
		bx(r, Vector3(bxp, .72, 806.72), Vector3(.12, .45, .12), "concrete_wall_008|#d8d4c8")
		bxp += .4
	for k in 8:
		var px := -8.0 + k * 12.5
		bx(r, Vector3(px, .4, 805.9), Vector3(1.6, .5, .6), "concrete_wall_008|#b8b2a2")
		for f in 10: bx(r, Vector3(px + rng.randf_range(-.7, .7), .7 + rng.randf_range(0, .2), 805.9 + rng.randf_range(-.2, .2)), Vector3(.12, .1, .12), ["#e0609a", "#d84a7a", "#3a6a2a"][f % 3])
	# The hillside's foot along the south side, houses stacked up it, a few windows still lit.
	span(r, Vector3(-14, 0, 785.6), Vector3(4.0, 3.4, 786.0), STONE, true)
	span(r, Vector3(-14, 0, 770.0), Vector3(4.0, 3.4, 785.6), STONE, true)
	span(r, Vector3(4.0, 0, 770.0), Vector3(14.5, 3.4, 778.6), STONE, true)
	var hx := -12.0
	var i := 0
	while hx < 2.0:
		var w := rng.randf_range(7.0, 10.5)
		shophouse(r, Vector3(hx + w * .5, 3.4, 784.2), Vector3(0, 0, 1), w, 10.0, rng.randi_range(2, 3), 3)
		hx += w + rng.randf_range(.3, 1.5)
		i += 1
	# Lamps along the river wall, most of them lit.
	var lm := [0, 2, 0, -1, 0, 3, 0, 2]
	for k in 8: street_lamp(r, Vector3(-6.0 + k * 13.5, .15, 805.9), Vector3(0, 0, -1), lm[k])
	# A bus stalled along the road (its hazards still going), jeepneys left, a tricycle.
	bus(r, Transform3D(Basis(Vector3.UP, PI * .5), Vector3(45.0, 0, 794.5)), false)
	place(r, "street/jeepney", Vector3(66.5, 0, 791.0), 96.0)
	solid(r, Vector3(66.5, 1.22, 791.0), Vector3(2.45, 2.44, 6.8), Basis(Vector3.UP, deg_to_rad(96.0)))
	place(r, "street/jeepney", Vector3(20.5, 0, 797.8), 84.0)
	solid(r, Vector3(20.5, 1.22, 797.8), Vector3(2.45, 2.44, 6.8), Basis(Vector3.UP, deg_to_rad(84.0)))
	place(r, "street/tricycle_a", Vector3(79.0, .15, 804.6), 15.0)
	# West, the road is shut by a building come down across it: they come round it.
	heap(r, Vector3(-16.0, 0, 785.5), Vector3(-9.5, 4.2, 807.0), 30)
	bx(r, Vector3(-11.0, 4.8, 796.0), Vector3(.4, 6.0, 12.0), WALL_IDS[5], false, Basis(Vector3.BACK, .4))
	litter(r, Vector3(10, 0, 795), Vector2(19.0, 7.0), 110)
	litter(r, Vector3(68, 0, 795), Vector2(27.0, 7.0), 150)
	stain(r, "pool_big", Vector3(24.0, 0, 792.0), 1.0, 2.0, 1.6)
	drag(r, Vector3(12.0, 0, 789.0), Vector3(22.0, 0, 799.0))
	hum(r, Vector3(40, 1, 808), "res://assets/audio/night/frog_chorus.ogg", -20.0, 20.0)
	# The water below the wall (sky root: seen from far).
	bx(R_SKY, Vector3(37.0, -1.7, 809.4), Vector3(102.0, .5, 5.6), STONE, false, Basis(Vector3.RIGHT, .55))
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(900, 640)
	water.mesh = plane
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(.02, .028, .034)
	wm.roughness = .05
	wm.metallic = .25
	wm.metallic_specular = 1.0
	water.material_override = wm
	water.position = Vector3(60, -3.25, 1130)
	water.layers = 1 | 2
	water.visibility_range_end = 2000.0
	roots[R_SKY].add_child(water)

func backdrop() -> void:
	var r := R_SKY
	# The hillside west of the terrace: a high wall, houses stacked up the slope.
	span(r, Vector3(-9.5, 5.0, 660.0), Vector3(-8.0, 12.0, 708.0), STONE, true)
	for i in 14:
		var hx := -14.0 - (i % 3) * 7.5
		var hz := 658.0 + int(i / 3) * 11.0 + rng.randf_range(-1.5, 1.5)
		var hh := rng.randf_range(5.0, 9.0)
		var y0 := 12.0 + (i % 3) * 3.5
		bx(r, Vector3(hx, y0 + hh * .5, hz), Vector3(6.8, hh, rng.randf_range(6.0, 9.0)), WALL_IDS[rng.randi() % WALL_IDS.size()])
		bx(r, Vector3(hx, y0 + hh + .3, hz), Vector3(7.4, .1, 9.4), "rusty_corrugated_iron", false, Basis(Vector3.BACK, .25))
		for k in 3:
			var lit := rng.randf() < .12
			bx(r, Vector3(hx + 3.42, y0 + 1.6 + k % 2 * 3.0, hz + rng.randf_range(-2.0, 2.0)), Vector3(.02, 1.1, .9), "glow#ffc890*0.8" if lit else "#1a1e22")
	# The city between the plaza and the river: blocks gutted, one still burning high up.
	for bxi in 5:
		for bzi in 2:
			var cx := 18.0 + bxi * 14.0 + rng.randf_range(-2.0, 2.0)
			var cz := 712.0 + bzi * 11.0 + rng.randf_range(-1.0, 1.0)
			if absf(cx - 46.0) < 6.0: continue
			var h := rng.randf_range(9.0, 22.0)
			bx(r, Vector3(cx, h * .5, cz), Vector3(rng.randf_range(9.0, 12.0), h, rng.randf_range(8.0, 10.0)), WALL_IDS[rng.randi() % WALL_IDS.size()])
			for k in 6: bx(r, Vector3(cx + rng.randf_range(-4, 4), h + rng.randf_range(0, 1.2), cz + rng.randf_range(-5, 5)), Vector3(rng.randf_range(1.0, 3.0), rng.randf_range(.6, 2.0), rng.randf_range(1.0, 3.0)), CONC, false, Basis(Vector3.UP, rng.randf() * TAU))
			for row in int(h / 3.2):
				for col in 3: bx(r, Vector3(cx + (col - 1) * 3.2, 2.0 + row * 3.2, cz - rng.randf_range(5.0, 7.0) - .05), Vector3(1.4, 1.3, .1), "#121416")
	fire(r, Vector3(60.0, 14.0, 738.0), 1.4, 22.0)
	smoke(r, Vector3(30.0, 18.0, 754.0), 26, 2.0)
	# The far bank: towers, a few windows lit, red lights on the tallest.
	for i in 24:
		var tx := -170.0 + i * 22.0 + rng.randf_range(-6.0, 6.0)
		var th := rng.randf_range(22.0, 96.0)
		var tw := rng.randf_range(14.0, 28.0)
		var td := rng.randf_range(14.0, 24.0)
		var tz := 1170.0 + rng.randf_range(0.0, 70.0)
		bx(r, Vector3(tx, th * .5 - 3.0, tz), Vector3(tw, th, td), "#15171c")
		for k in rng.randi_range(4, 16):
			bx(r, Vector3(tx + rng.randf_range(-tw * .45, tw * .45), rng.randf_range(2.0, th - 4.0), tz - td * .5 - .06), Vector3(1.6, 1.1, .05), "glow#ffd49a*1.1" if rng.randf() < .8 else "glow#cfe0ff*1.0")
		if th > 70.0:
			var g := glow_piece(r, Vector3(tx, th - 2.6, tz), Vector3(.5, .5, .5), Color(1.0, .1, .08), 3.0)
			lamp_light(null, 0.0, 5, "", g, 3.0)
	bx(r, Vector3(60.0, -3.2, 1215.0), Vector3(760.0, .6, 130.0), "#111316")
