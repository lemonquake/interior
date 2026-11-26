extends RefCounted
## 0.44: Olivar Family Mart's back office (it was a dark staff room with its door hanging open), where Jonna, the
## shift supervisor, shut herself in when the front glass went.
##
## Everything in it has a reason. She dragged the two-drawer cabinet against the door and pulled it back to open
## it: the scrape marks run from the door. She came in bleeding: drops from the door to the back wall, the smear
## where she slid down it, the first-aid box emptied round her, the towels, the belt she tied off with. She has
## been in here two nights: water, crackers. The CCTV still shows the shop floor (the UPS under the desk beeps);
## the handheld radio on the desk, its channel light blinking, is how she heard about the school. The rest is the
## office as the family kept it: the permit, the shift board, the calendar, the lockers with a spare uniform, the
## safe (left open when the soldiers asked for the cash for nothing), and the corner shelf with the Santo Niño and
## the lucky cat, its little red bulb on.
##
## The room: x 1.07..8.4, z 69.57..73.4 (street-local), the door in the partition at x 3.85..4.9 (z 69.5).
const DOOR_HINGE := Vector3(3.9, 0, 69.5)
## Jonna: where she stands when she opens the door, and where she sits against the back wall.
const DOORWAY := Vector3(4.4, 0, 70.05)
const SEAT := Vector3(2.35, 0, 72.95)
const OPEN_YAW := -1.75

static func build(s) -> void:
	var rng: RandomNumberGenerator = s.rng
	# Vinyl tiles over the slab, worn grey-green.
	s.box(Vector3(4.75, .052, 71.5), Vector3(7.3, .01, 3.8), "concrete_floor_02|#9ea79a")
	# The door: a painted wooden leaf on its hinge (Street.office_door; mission flag "office" swings it in).
	var door := StaticBody3D.new()
	door.collision_layer = 2
	door.position = DOOR_HINGE
	s.add_child(door)
	s.office_door = door
	s.shape(door, Vector3(.475, 1.25, 0), Vector3(.95, 2.5, .05))
	s.piece(door, Vector3(.475, 1.25, 0), Vector3(.95, 2.5, .05), "wood_peeling_paint_weathered|#c9c2a8")
	s.piece(door, Vector3(.85, 1.05, -.05), Vector3(.12, .05, .04), "#8c8c84")
	s.piece(door, Vector3(.85, 1.05, .05), Vector3(.12, .05, .04), "#8c8c84")
	s.piece(door, Vector3(.475, 1.85, -.03), Vector3(.5, .18, .01), "#e8e1c6")
	var words: Label3D = s.sign_at(DOOR_HINGE + Vector3(.475, 1.85, -.04), "OFFICE", .09, PI, Color(.55, .1, .08), false)
	words.reparent(door)
	# The cabinet she braced it with, pulled back to open it, and its scrape marks.
	cabinet(s, Vector3(3.05, 0, 70.15), Vector2(.47, .62), 2, .35, -1)
	for k in 5:
		s.box(Vector3(3.7 + k * .02, .058, 70.0 + k * .07), Vector3(1.2 - k * .1, .003, .012), "#5b5a52", false, Basis(Vector3.UP, .12))
	# Desk against the back wall: steel, a laminate top. On it: the CCTV monitor, keyboard, the radio, papers, the
	# cash box (empty), a mug, a calculator, the desk lamp.
	var desk := Vector3(6.2, 0, 72.95)
	s.box(desk + Vector3(0, .74, 0), Vector3(1.6, .04, .75), "#b9b2a0", true)
	for x in [-.74, .74]: s.box(desk + Vector3(x, .36, 0), Vector3(.04, .72, .7), "#59605c", true)
	s.box(desk + Vector3(.45, .45, -.02), Vector3(.62, .5, .6), "#59605c")
	s.box(desk + Vector3(.45, .35, -.33), Vector3(.5, .14, .01), "#6b726d")
	s.box(desk + Vector3(.45, .55, -.33), Vector3(.5, .14, .01), "#6b726d")
	var mon := desk + Vector3(.35, .96, .2)
	s.box(mon + Vector3(0, -.17, .04), Vector3(.18, .06, .14), "#1b1c1e")
	s.box(mon, Vector3(.56, .36, .05), "#1b1c1e")
	for q in 4:
		var off := Vector3(-.13 + (q % 2) * .26, .085 - (q / 2) * .17, -.027)
		s.box(mon + off, Vector3(.245, .155, .004), "glow#8fb3c4*%.1f" % [1.1 if q != 3 else .25])
	s.light(mon + Vector3(0, 0, -.35), Color(.6, .78, 1.0), .35, 1.8)
	s.box(desk + Vector3(.25, .765, -.15), Vector3(.44, .02, .14), "#2a2b2d")
	s.box(desk + Vector3(-.15, .763, -.05), Vector3(.3, .004, .38), "#ece8dc", false, Basis(Vector3.UP, .2))
	s.box(desk + Vector3(-.2, .767, -.08), Vector3(.28, .004, .36), "#f2efe6", false, Basis(Vector3.UP, -.1))
	s.box(desk + Vector3(-.55, .8, .05), Vector3(.28, .09, .2), "#4a4f55", false, Basis(Vector3.UP, .4))
	s.box(desk + Vector3(-.62, .9, .14), Vector3(.28, .02, .2), "#4a4f55", false, Basis(Vector3.UP, .4) * Basis(Vector3.RIGHT, -1.2))
	for k in 6: s.can(desk + Vector3(rng.randf_range(-.75, -.3), .762, rng.randf_range(-.3, .2)), .012, .004, "#b6a46a", Basis.IDENTITY, 8)
	s.can(desk + Vector3(-.1, .81, .2), .045, .1, "#e9e4d6", Basis.IDENTITY, 12)
	s.box(desk + Vector3(.0, .77, .1), Vector3(.1, .02, .16), "#303236", false, Basis(Vector3.UP, -.3))
	# The radio: upright in its charger, the channel light blinking (Street.radio_led).
	var radio := desk + Vector3(-.35, .76, .22)
	s.box(radio + Vector3(0, .03, 0), Vector3(.1, .06, .09), "#202122")
	s.box(radio + Vector3(0, .15, 0), Vector3(.06, .2, .04), "#1b1c1b")
	s.can(radio + Vector3(.015, .32, 0), .006, .16, "#111111")
	s.box(radio + Vector3(0, .2, -.021), Vector3(.035, .05, .002), "#3a4a3e")
	s.radio_led = MeshInstance3D.new()
	var led := BoxMesh.new()
	led.size = Vector3(.012, .012, .012)
	s.radio_led.mesh = led
	s.radio_led.material_override = s.material("glow#3dff6a*4.0")
	s.radio_led.position = radio + Vector3(-.018, .255, 0)
	s.add_child(s.radio_led)
	s.sign_at(radio + Vector3(.0, .005, -.13), "CH 7 • BRGY", .025, PI, Color(.85, .85, .8), false).rotation.x = -PI * .5
	# The desk lamp: the warm light in the room.
	s.box(desk + Vector3(.72, .77, .2), Vector3(.14, .03, .14), "#2a2b28")
	_bar(s, desk + Vector3(.72, .78, .2), desk + Vector3(.68, 1.15, .1), .015, "#2a2b28")
	_bar(s, desk + Vector3(.68, 1.15, .1), desk + Vector3(.5, 1.12, -.08), .015, "#2a2b28")
	s.can(desk + Vector3(.47, 1.08, -.1), .07, .1, "#7a1717", Basis(Vector3.RIGHT, .5), 12)
	s.light(desk + Vector3(.45, .98, -.18), Color(1.0, .78, .5), .9, 2.6)
	# Chair pushed back from the desk, a UPS under it.
	s.model("street/plastic_monobloc_chair_01", desk + Vector3(-.2, .05, -.85), 200.0)
	s.box(desk + Vector3(-.4, .14, .12), Vector3(.16, .26, .36), "#1e1f20")
	s.box(desk + Vector3(-.4, .2, -.065), Vector3(.02, .02, .002), "glow#ffb02e*3.0")
	# Back wall: the cork shift board, the calendar, the permit, a clock (stopped).
	var wall := 73.39
	s.box(Vector3(6.1, 1.75, wall), Vector3(1.3, .85, .03), "#a07a4a")
	s.box(Vector3(6.1, 1.75, wall + .005), Vector3(1.36, .91, .02), "#3c3a35")
	for k in 9:
		var p := Vector3(5.6 + (k % 3) * .4 + rng.randf_range(-.05, .05), 1.98 - (k / 3) * .26, wall - .02)
		s.box(p, Vector3(.24, .18, .003), ["#f3f0e6", "#fff4a8", "#e8f0f8"][k % 3], false, Basis(Vector3.FORWARD, rng.randf_range(-.12, .12)))
		s.box(p + Vector3(0, .07, -.004), Vector3(.015, .015, .006), "#c43b2b")
	s.sign_at(Vector3(6.1, 2.27, wall - .03), "SHIFT SCHEDULE", .07, PI, Color(.15, .12, .1), false)
	s.box(Vector3(4.75, 1.7, wall - .01), Vector3(.5, .7, .01), "#f4f2ec")
	s.box(Vector3(4.75, 1.96, wall - .015), Vector3(.5, .14, .006), "#c43b2b")
	s.sign_at(Vector3(4.75, 1.96, wall - .025), "NOBYEMBRE 2026", .045, PI, Color(1, 1, 1), false)
	for r in 5:
		for c in 7:
			if r * 7 + c > 30: continue
			s.box(Vector3(4.58 + c * .055, 1.82 - r * .085, wall - .016), Vector3(.04, .06, .003), "#d9d5c9" if r * 7 + c != 17 else "#c43b2b")
	s.box(Vector3(7.35, 1.85, wall - .01), Vector3(.42, .55, .02), "#5b3a20")
	s.box(Vector3(7.35, 1.85, wall - .022), Vector3(.36, .48, .003), "#efe8d2")
	s.sign_at(Vector3(7.35, 1.98, wall - .026), "BUSINESS PERMIT\nCITY OF DAVAO", .03, PI, Color(.15, .2, .45), false)
	s.can(Vector3(3.2, 2.65, wall - .02), .17, .03, "#efece4", Basis(Vector3.RIGHT, PI * .5), 20)
	s.box(Vector3(3.2, 2.7, wall - .04), Vector3(.012, .12, .004), "#111111")
	s.box(Vector3(3.24, 2.64, wall - .04), Vector3(.09, .012, .004), "#111111", false, Basis(Vector3.FORWARD, .5))
	# The corner shelf: Santo Niño in his red cape and gold crown, the lucky cat, the red bulb.
	var shelf := Vector3(8.15, 2.05, 73.15)
	s.box(shelf, Vector3(.42, .03, .4), "#5b3a20")
	_bar(s, shelf + Vector3(0, -.02, .19), shelf + Vector3(0, -.25, .19), .02, "#5b3a20")
	s.can(shelf + Vector3(-.05, .14, .03), .055, .22, "#a1161b", Basis.IDENTITY, 10)
	s.can(shelf + Vector3(-.05, .27, .03), .035, .05, "#e7c9a6", Basis.IDENTITY, 10)
	s.can(shelf + Vector3(-.05, .31, .03), .04, .03, "#d4a22a", Basis.IDENTITY, 8)
	s.box(shelf + Vector3(.12, .07, -.06), Vector3(.08, .11, .07), "#f4f1ea")
	s.box(shelf + Vector3(.155, .15, -.06), Vector3(.025, .06, .025), "#f4f1ea", false, Basis(Vector3.FORWARD, -.4))
	s.box(shelf + Vector3(.12, .09, -.098), Vector3(.03, .01, .002), "#c43b2b")
	s.can(shelf + Vector3(-.15, .06, -.08), .025, .08, "glow#ff2a1a*3.5", Basis.IDENTITY, 8)
	s.light(shelf + Vector3(-.15, .15, -.18), Color(1.0, .2, .12), .35, 1.4)
	# Lockers on the right wall, one standing open with a spare red polo on the hook.
	for i in 3:
		var l := Vector3(8.15, 0, 70.35 + i * .44)
		s.box(l + Vector3(0, .92, 0), Vector3(.45, 1.84, .42), "#5d6e63", true)
		for k in 3: s.box(l + Vector3(-.226, 1.55 - k * .04, 0), Vector3(.004, .015, .3), "#3c4741")
		if i == 1:
			var swing := Basis(Vector3.UP, 1.2)
			s.box(l + Vector3(-.23, .92, -.2) + swing * Vector3(0, 0, .2), Vector3(.02, 1.8, .4), "#5d6e63", false, swing)
			s.box(l + Vector3(-.21, .92, 0), Vector3(.004, 1.78, .4), "#202423")
			s.box(l + Vector3(-.12, 1.3, 0), Vector3(.04, .55, .34), "#7a1717")
		else:
			s.box(l + Vector3(-.226, .92, 0), Vector3(.004, 1.8, .4), "#62746a")
	# The safe: open, empty.
	var safe := Vector3(8.0, 0, 72.95)
	s.box(safe + Vector3(0, .26, 0), Vector3(.48, .52, .46), "#232526", true)
	s.box(safe + Vector3(-.24, .26, -.06), Vector3(.02, .44, .38), "#1a1b1c")
	var open := Basis(Vector3.UP, -1.1)
	s.box(safe + Vector3(-.24, .26, -.23) + open * Vector3(0, 0, .19), Vector3(.06, .46, .38), "#2c2e30", false, open)
	# A water dispenser, the jug nearly empty; the stand fan, off.
	s.box(Vector3(7.95, .48, 71.95), Vector3(.32, .96, .32), "#e8e6e0", true)
	s.can(Vector3(7.95, 1.12, 71.95), .13, .34, "glass#6aa8d8aa", Basis.IDENTITY, 14)
	s.can(Vector3(7.95, .99, 71.95), .12, .06, "glass#3a78b8cc", Basis.IDENTITY, 14)
	s.can(Vector3(1.6, .02, 71.8), .17, .03, "#d9d6cf", Basis.IDENTITY, 14)
	s.can(Vector3(1.6, .6, 71.8), .015, 1.16, "#d9d6cf", Basis.IDENTITY, 8)
	s.can(Vector3(1.6, 1.25, 71.82), .2, .1, "#cfd3d6", Basis(Vector3.RIGHT, PI * .5), 18)
	# The tall cabinet by the left wall, a drawer hanging open, files on the floor.
	cabinet(s, Vector3(1.38, 0, 70.4), Vector2(.47, .62), 4, 0.0, 2)
	for k in 7:
		s.box(Vector3(rng.randf_range(1.5, 2.6), .06, rng.randf_range(70.2, 71.2)), Vector3(.24, .004, .31), ["#e6d27a", "#f0ede4", "#d9c56a"][k % 3], false, Basis(Vector3.UP, rng.randf() * TAU))
	# Ceiling: a troffer, one tube alive.
	s.box(Vector3(4.8, 3.96, 71.5), Vector3(.6, .07, 1.25), "#d8d9d2")
	s.box(Vector3(4.67, 3.92, 71.5), Vector3(.12, .02, 1.15), "glow#e3f7e6*2.0")
	s.box(Vector3(4.93, 3.92, 71.5), Vector3(.12, .02, 1.15), "#4b4c48")
	s.office_light = s.light(Vector3(4.8, 3.5, 71.5), Color(.82, 1.0, .9), 1.1, 6.5, true)
	# Where Jonna sits: the first-aid box tipped out, gauze, the towels, the water and crackers.
	s.model("nichols/nh_medical_box", SEAT + Vector3(.75, .05, -.2), 30.0)
	for k in 6:
		var p := SEAT + Vector3(rng.randf_range(-.6, 1.2), .058, rng.randf_range(-.9, -.1))
		s.box(p, Vector3(rng.randf_range(.06, .14), .01, rng.randf_range(.05, .12)), "#efe9dc" if k % 2 else "#8a2a22", false, Basis(Vector3.UP, rng.randf() * TAU))
	s.box(SEAT + Vector3(-.5, .08, -.5), Vector3(.5, .06, .36), "#6a1c18", false, Basis(Vector3.UP, .5))
	s.box(SEAT + Vector3(1.1, .07, -.45), Vector3(.42, .05, .3), "#3a6a8a", false, Basis(Vector3.UP, -.3))
	s.put("wilkins_bottle", SEAT + Vector3(-.65, .055, -.15), 0.0)
	s.drop("wilkins_bottle", SEAT + Vector3(.5, .055, -.95))
	s.drop("skyflakes", SEAT + Vector3(-.75, .055, -.6))
	# Her camp lantern on the floor beside her (two nights in here), on its low setting.
	var lantern := SEAT + Vector3(.62, 0, -.55)
	s.can(lantern + Vector3.UP * .03, .07, .06, "#2a2b28", Basis.IDENTITY, 12)
	s.can(lantern + Vector3.UP * .13, .055, .14, "glow#ffe2b0*2.2", Basis.IDENTITY, 12)
	s.can(lantern + Vector3.UP * .22, .06, .04, "#2a2b28", Basis.IDENTITY, 12)
	s.box(lantern + Vector3.UP * .27, Vector3(.1, .015, .015), "#2a2b28")
	s.light(lantern + Vector3.UP * .35, Color(1.0, .82, .58), .9, 3.4)
	# Her blood: the drops from the door, the smear down the wall, the pool.
	var drops := DOORWAY
	for k in 9:
		drops = drops.lerp(SEAT, .18) + Vector3(rng.randf_range(-.12, .12), 0, rng.randf_range(-.1, .1))
		s.stain("spatter_floor", drops, rng.randf() * TAU, .5, .5, .9)
	s.stain("pool_big", SEAT + Vector3(.1, 0, -.25), .4, 1.5, 1.2)
	s.wall_mark("smear_wall", Vector3(SEAT.x, .9, wall - .02), Vector3.FORWARD, .8, 1.2)
	s.hum(desk + Vector3(-.4, .3, 0), "res://assets/audio/nichols/fridge_hum.ogg", -26.0, 1.5)

## A steel filing cabinet with `drawers`; `out` pulls drawer `pulled` open by that much (m).
static func cabinet(s, at: Vector3, size: Vector2, drawers: int, yaw: float, pulled: int) -> void:
	var b := Basis(Vector3.UP, yaw)
	var h := drawers * .33
	s.box(at + Vector3.UP * h * .5, Vector3(size.x, h, size.y), "#7d8580", true, b)
	for d in drawers:
		var y := .17 + d * .33
		var out := .32 if d == pulled else 0.0
		s.box(at + b * Vector3(0, y, -size.y * .5 - .01 - out * .5), Vector3(size.x - .04, .29, .02 + out), "#87908a", false, b)
		s.box(at + b * Vector3(0, y + .07, -size.y * .5 - .03 - out), Vector3(.12, .025, .02), "#3a3d3a", false, b)

static func _bar(s, a: Vector3, b: Vector3, thick: float, id: String) -> void:
	var d := b - a
	if d.length() < .001: return
	var up := Vector3.UP if absf(d.normalized().y) < .98 else Vector3.RIGHT
	s.box((a + b) * .5, Vector3(thick, thick, d.length()), id, false, Basis.looking_at(d.normalized(), up))
