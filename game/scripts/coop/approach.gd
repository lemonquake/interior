extends RefCounted
## 0.44: the way up to Old Salmonan's gate, rebuilt (it was a plank ramp standing alone in the yard between two loose
## sheets of tin).
##
## Old Salmonan sits on the old floodwall above the settlement. The barangay's concrete ramp climbs the wall's face to a
## landing, and the night gate (curfew 10 PM, the tanod keep the keys: Dodong's) shuts the purok off at the top.
## When the town fell, a squad held the foot of the ramp: they ran razor wire across the yard to funnel anyone from
## the settlement past their sandbags, lit it with a floodlight off a generator, and kept a log. The infected came
## out of the warren's back fence and through the wire where it was thinnest. The story is left where it happened:
## the trampled wire and the blood beyond it; the casings and the overturned table behind the sandbags; the soldier
## who crawled up the ramp toward a gate that was locked; the guard who went over the bent railing; the tanod
## who died against the bars because Dodong had the keys. The floodlight lies where its tripod was knocked over,
## still burning, throwing its beam sideways across the wall.
##
## Street-local coordinates (Street.ORIGIN added): the yard is at y G, the street at 0; the wall's face at z -0.6.
## The settlement's far-bank fence runs north from the warren's exit to the wall at x -8: everything here is east
## of it, in the yard the exit opens on. The ramp rises westward, from the yard's east end (the ravine's edge is
## at x 12) to the landing in front of the gate.
const G := -3.15
const FOOT_X := 11.2
const TOP_X := 2.6
const OUT_Z := -2.9
const WALL_Z := -0.6
## The dead of the ramp (street-local, like Street.STORE_DEAD): [where, infected index, yaw, clip, part, push].
const DEAD := [
	[Vector3(9.5, G, -7.9), 18, -PI * .9, "death_crumple", .92, Vector3.ZERO],
	[Vector3(6.3, -1.36, -1.85), 18, PI * .5, "death_fwd", .95, Vector3(30, 0, 0)],
	[Vector3(6.1, G, -4.25), 37, -.4, "death_back", .95, Vector3(0, 0, -160)],
	[Vector3(-.9, 0, .2), 2, PI, "death_crumple", .62, Vector3(0, 0, 90)],
	[Vector3(2.6, G, -10.6), 0, -2.4, "death_fwd", .9, Vector3.ZERO]]

static func ramp_y(x: float) -> float:
	return lerpf(G, 0.0, clampf((FOOT_X - x) / (FOOT_X - TOP_X), 0.0, 1.0))

## A block whose top slopes along x from y `t0` (at x0) to `t1` (at x1), bottom flat at `bot`: the ramp's
## concrete body. Drawn as six quads and collided as one convex hull.
static func slope_block(s, x0: float, x1: float, z0: float, z1: float, bot: float, t0: float, t1: float, id: String) -> void:
	var c := [Vector3(x0, bot, z0), Vector3(x1, bot, z0), Vector3(x1, t1, z0), Vector3(x0, t0, z0),
		Vector3(x0, bot, z1), Vector3(x1, bot, z1), Vector3(x1, t1, z1), Vector3(x0, t0, z1)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre := Vector3((x0 + x1) * .5, (bot + (t0 + t1) * .5) * .5, (z0 + z1) * .5)
	for q in [[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]]:
		var p: Array = [c[q[0]], c[q[1]], c[q[2]], c[q[3]]]
		var n: Vector3 = (p[1] - p[0]).cross(p[2] - p[0]).normalized()
		if n.dot(p[0] - centre) < 0.0:
			n = -n
			p.reverse()
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.add_vertex(p[i])
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = s.material(id)
	mesh.layers = 1 | 8
	s.add_child(mesh)
	var hull := ConvexPolygonShape3D.new()
	hull.points = PackedVector3Array(c)
	var col := CollisionShape3D.new()
	col.shape = hull
	s.solid.add_child(col)

## A straight bar from a to b (rails, posts, pipes) in the street's merged meshes.
static func bar(s, a: Vector3, b: Vector3, thick: float, id: String) -> void:
	var d := b - a
	if d.length() < .001: return
	var up := Vector3.UP if absf(d.normalized().y) < .98 else Vector3.RIGHT
	s.box((a + b) * .5, Vector3(thick, thick, d.length()), id, false, Basis.looking_at(d.normalized(), up))

static func build(s) -> void:
	floodwall(s)
	ramp(s)
	gate(s)
	checkpoint(s)
	floodlight(s)
	blood(s)

# ---------------------------------------------------------------- the floodwall

static func floodwall(s) -> void:
	var rng: RandomNumberGenerator = s.rng
	# The wall itself, a footing, and a parapet on top (the street's edge), broken only at the landing.
	s.box(Vector3(0, -1.875, -.1), Vector3(34, 3.75, 1.0), "concrete_wall_008|#b9b5a8", true)
	s.box(Vector3(0, G + .14, WALL_Z - .17), Vector3(34, .3, .36), "dirty_concrete", true)
	for side in [-1, 1]:
		var cx: float = side * 9.75
		s.box(Vector3(cx, .45, -.3), Vector3(14.7, .9, .3), "concrete_wall_008|#aaa69a", true)
		s.box(Vector3(cx, .93, -.3), Vector3(14.8, .07, .4), "rough_concrete")
		# Barbed wire on bent-iron arms along the parapet.
		var x: float = side * 2.8
		while absf(x) < 16.9:
			bar(s, Vector3(x, .9, -.3), Vector3(x, 1.38, -.52), .035, "rusty_metal_04")
			x += side * 2.4
		for k in 3:
			var y := 1.05 + k * .14
			var zz := -.36 - k * .07
			s.wire(Vector3(side * 2.8, y, zz), Vector3(side * 16.8, y, zz), .12 + k * .03, "#3b352f", .012)
	# Expansion joints, moss and the wet line along the foot, weep holes with their stains.
	for k in 9:
		var x := -16.0 + k * 4.0
		s.box(Vector3(x, -1.6, WALL_Z - .005), Vector3(.035, 3.1, .02), "#26251f")
	s.box(Vector3(0, G + .45, WALL_Z - .012), Vector3(34, .6, .02), "worn_mossy_plasterwall|#6f7660")
	for k in 11:
		var x := -15.0 + k * 3.0 + rng.randf_range(-.3, .3)
		if x > TOP_X - .4 and x < FOOT_X + .6: continue
		s.can(Vector3(x, G + 1.0, WALL_Z - .07), .05, .16, "#c9c2b0", Basis(Vector3.RIGHT, PI * .5), 8)
		s.box(Vector3(x, G + .55, WALL_Z - .008), Vector3(.2, .9, .01), "glass#1c1d1455")
	# The barangay's tarpaulin: the curfew, hung on cord from two nails, one corner torn loose.
	var tarp := Vector3(-4.4, -1.35, WALL_Z - .04)
	s.box(tarp, Vector3(3.4, 1.5, .012), "#ece8de", false, Basis(Vector3.FORWARD, .025))
	s.box(tarp + Vector3(0, .58, -.004), Vector3(3.4, .3, .012), "#1d3f73", false, Basis(Vector3.FORWARD, .025))
	s.box(tarp + Vector3(1.55, -.68, -.06), Vector3(.34, .3, .012), "#ece8de", false, Basis(Vector3.RIGHT, .7) * Basis(Vector3.FORWARD, .5))
	s.sign_at(tarp + Vector3(0, .58, -.012), "BARANGAY 23-C  •  OLD SALMONAN", .17, PI, Color(1, .96, .88), false)
	s.sign_at(tarp + Vector3(0, .05, -.012), "CURFEW\n10:00 PM – 4:00 AM", .26, PI, Color(.62, .08, .07), false)
	s.sign_at(tarp + Vector3(0, -.5, -.012), "STRICTLY IMPLEMENTED  •  BY ORDER OF THE PUNONG BARANGAY", .07, PI, Color(.12, .12, .14), false)
	for x in [-1.7, 1.7]: s.box(tarp + Vector3(x, .72, -.02), Vector3(.03, .03, .05), "#3b352f")
	# Stencil from the clean-up drive, half gone.
	s.sign_at(Vector3(-1.2, G + 1.1, WALL_Z - .02), "BAWAL MAGTAPON\nNG BASURA DITO", .19, PI, Color(.58, .12, .09, .85), false)

# ---------------------------------------------------------------- the ramp and the landing

static func ramp(s) -> void:
	var rng: RandomNumberGenerator = s.rng
	var run := FOOT_X - TOP_X
	var angle := atan2(-G, run)
	var tilt := Basis(Vector3.BACK, -angle)
	var length := sqrt(run * run + G * G)
	var mid := Vector3((FOOT_X + TOP_X) * .5, G * .5, (OUT_Z + WALL_Z) * .5)
	# The concrete body (sloped prism), its walking slab, a kerb on the open side.
	slope_block(s, TOP_X, FOOT_X + .3, OUT_Z, WALL_Z, G - .4, -.12, G - .1, "rough_concrete|#9d998d")
	s.box(mid + tilt * Vector3(0, -.06, 0), Vector3(length + .02, .14, WALL_Z - OUT_Z), "concrete_pavement|#a9a597", true, tilt)
	s.box(mid + Vector3(0, 0, OUT_Z - mid.z + .09) + tilt * Vector3(0, .07, 0), Vector3(length, .16, .18), "dirty_concrete", true, tilt)
	# Anti-slip grooves troweled across the slab.
	var k := 0.4
	while k < run - .2:
		var x := FOOT_X - k
		s.box(Vector3(x, ramp_y(x) + .006, mid.z), Vector3(.035, .01, WALL_Z - OUT_Z - .3), "#4d4b44", false, tilt)
		k += .32
	# The landing: a solid block flush with the street.
	s.box(Vector3(.1, (G - .3) * .5, -1.75), Vector3(5.0, -G + .3, 2.3), "rough_concrete|#9d998d", true)
	s.box(Vector3(.1, -.03, -1.75), Vector3(5.0, .06, 2.3), "concrete_pavement|#a9a597", true)
	s.sign_at(Vector3(.4, G + 1.45, OUT_Z - .02), "BRGY. EMERGENCY HOTLINE  •  911", .17, PI, Color(.86, .82, .7, .9), false)
	s.box(Vector3(.4, G + 1.45, OUT_Z - .012), Vector3(3.3, .34, .01), "#7a1717")
	# Galvanised pipe railing on the open side: posts every 1.4 m, two rails; one bay bent out where the guard went
	# over (DEAD[2] lies below it).
	var bent := Vector2(5.4, 6.8)
	var x := TOP_X
	var posts: Array[float] = []
	while x < FOOT_X - .1:
		posts.append(x)
		x += 1.4
	posts.append(FOOT_X - .1)
	for i in posts.size():
		var px: float = posts[i]
		var lean := Vector3(0, 0, -.32) if px > bent.x and px < bent.y + .1 else Vector3.ZERO
		bar(s, Vector3(px, ramp_y(px), OUT_Z + .07), Vector3(px, ramp_y(px) + 1.0, OUT_Z + .07) + lean, .05, "#8b8d86")
		if i == posts.size() - 1: continue
		var nx: float = posts[i + 1]
		var bay_bent := px >= bent.x - .1 and nx <= bent.y + .3
		for h in [.5, 1.0]:
			var a := Vector3(px, ramp_y(px) + h, OUT_Z + .07)
			var b := Vector3(nx, ramp_y(nx) + h, OUT_Z + .07)
			if bay_bent:
				var sag := Vector3(0, -.15 * h, -.55 * h)
				bar(s, a, (a + b) * .5 + sag, .045, "#7f7a6e")
				bar(s, (a + b) * .5 + sag, b, .045, "#7f7a6e")
			else: bar(s, a, b, .045, "#8b8d86" if (i + int(h * 2)) % 3 else "rusty_metal_02")
	# Collision for the railing (the bent bay is open: that is where he went over).
	for i in posts.size() - 1:
		var px: float = posts[i]
		var nx: float = posts[i + 1]
		if px >= bent.x - .1 and nx <= bent.y + .3: continue
		var c := Vector3((px + nx) * .5, (ramp_y(px) + ramp_y(nx)) * .5 + .55, OUT_Z + .07)
		s.shape(s.solid, c, Vector3(nx - px + .05, 1.1, .1), tilt)
	# Railing round the landing's open sides.
	for spec in [[Vector3(-2.4, 0, OUT_Z + .07), Vector3(TOP_X, 0, OUT_Z + .07)], [Vector3(-2.4, 0, OUT_Z + .07), Vector3(-2.4, 0, WALL_Z)]]:
		var a: Vector3 = spec[0]
		var b: Vector3 = spec[1]
		for h in [.5, 1.0]: bar(s, a + Vector3.UP * h, b + Vector3.UP * h, .045, "#8b8d86")
		var n := int(a.distance_to(b) / 1.3) + 1
		for j in n + 1: bar(s, a.lerp(b, float(j) / n), a.lerp(b, float(j) / n) + Vector3.UP * 1.0, .05, "#8b8d86")
		s.shape(s.solid, (a + b) * .5 + Vector3.UP * .55, Vector3(maxf(absf(b.x - a.x), .1) + .05, 1.1, maxf(absf(b.z - a.z), .1) + .05))
	# A handrail on the wall's face, on brackets.
	bar(s, Vector3(FOOT_X - .3, ramp_y(FOOT_X - .3) + .9, WALL_Z - .09), Vector3(TOP_X, .9, WALL_Z - .09), .04, "#6d6f69")
	var bx := TOP_X + 1.0
	while bx < FOOT_X - .3:
		bar(s, Vector3(bx, ramp_y(bx) + .9, WALL_Z - .09), Vector3(bx, ramp_y(bx) + .9, WALL_Z), .03, "#6d6f69")
		bx += 2.2
	# What was dropped going up: casings, a magazine, a boot.
	for j in 40:
		var cx := rng.randf_range(TOP_X + .5, FOOT_X - 1.0)
		s.can(Vector3(cx, ramp_y(cx) + .015, rng.randf_range(OUT_Z + .3, WALL_Z - .2)), .006, .045, "#b38b3a", Basis(Vector3.FORWARD, PI * .5) * Basis(Vector3.UP, rng.randf() * TAU), 5)
	s.box(Vector3(4.4, ramp_y(4.4) + .03, -1.2), Vector3(.07, .03, .19), "#232421", false, tilt * Basis(Vector3.UP, .8))

# ---------------------------------------------------------------- the night gate

static func gate(s) -> void:
	var rng: RandomNumberGenerator = s.rng
	for side in [-1, 1]:
		var p := Vector3(side * 2.38, 0, .75)
		s.box(p + Vector3.UP * 1.8, Vector3(.5, 3.6, .5), "white_plaster_02|#ddd6c4", true)
		s.box(p + Vector3.UP * .5, Vector3(.52, 1.0, .52), "#1d3f73")
		s.box(p + Vector3.UP * 3.64, Vector3(.6, .1, .6), "rough_concrete")
		# Lamp boxes on the pillars: the right one burning (sodium), the left one smashed.
		s.box(p + Vector3.UP * 3.86, Vector3(.34, .34, .34), "#2a2b28")
		if side > 0:
			s.box(p + Vector3(0, 3.86, -.175), Vector3(.28, .26, .02), "glow#ffb35c*3.2")
			var lamp: OmniLight3D = s.light(p + Vector3(0, 3.75, -.6), Color(1.0, .66, .32), 2.4, 14.0, true)
			s.flickers.append([lamp, 2.4, .7, null])
		else:
			s.box(p + Vector3(0, 3.86, -.175), Vector3(.28, .26, .02), "#141513")
			for j in 9: s.box(p + Vector3(rng.randf_range(-.5, .5), .012, rng.randf_range(-1.2, -.3)), Vector3(.05, .004, .04), "glass#e8d7a088", false, Basis(Vector3.UP, rng.randf() * TAU))
	# The barangay's bracket lamps on the wall's face light the climb: sodium, one of them failing.
	for spec in [[5.8, true], [10.2, false]]:
		var x: float = spec[0]
		var at := Vector3(x, ramp_y(x) + 2.9, WALL_Z)
		bar(s, at, at + Vector3(0, .15, -.9), .05, "#3a3b37")
		s.box(at + Vector3(0, .1, -.95), Vector3(.28, .12, .42), "#2a2b28", false, Basis(Vector3.RIGHT, -.25))
		s.box(at + Vector3(0, .03, -.97), Vector3(.22, .02, .34), "glow#ffb35c*3.4", false, Basis(Vector3.RIGHT, -.25))
		var wall_lamp: OmniLight3D = s.light(at + Vector3(0, -.15, -1.0), Color(1.0, .64, .3), 2.2, 11.0, true)
		if not spec[1]: s.flickers.append([wall_lamp, 2.2, 3.1, null])
		s.wire(at + Vector3(0, .1, 0), at + Vector3(-4.0, .3, 0), .3, "#141414", .014)
	# The arch: a steel beam, the purok's name cut from a painted sheet.
	s.box(Vector3(0, 3.55, .75), Vector3(5.3, .14, .14), "rusty_metal_02")
	s.box(Vector3(0, 3.2, .73), Vector3(3.9, .5, .05), "#1d3f73")
	s.box(Vector3(0, 2.92, .72), Vector3(3.9, .04, .05), "#e3b23c")
	s.sign_at(Vector3(0, 3.2, .69), "OLD SALMONAN", .3, PI, Color(.97, .95, .88), false)
	# The sliding leaf (Street.gate moves it): frame, bars, a solid lower sheet, wire along the top, wheels, and
	# the floor rail it runs on.
	var g: StaticBody3D = s.gate
	for c in g.get_children(): c.queue_free()
	var z := -.25
	# 0.49: the walking box keeps people out; rounds go between the bars and strike the frame and the lower sheet.
	s.shape(g, Vector3(0, 1.3, z), Vector3(4.3, 2.6, .12)).set_meta("unseen", true)
	for y in [.12, 1.0, 2.45]: s.shape(g, Vector3(0, y, z), Vector3(4.3, .08, .07)).set_meta("surface", "metal")
	for x in [-2.12, 2.12]: s.shape(g, Vector3(x, 1.28, z), Vector3(.08, 2.4, .07)).set_meta("surface", "metal")
	s.shape(g, Vector3(0, .56, z), Vector3(4.2, .86, .04)).set_meta("surface", "metal")
	for y in [.12, 1.0, 2.45]: s.piece(g, Vector3(0, y, z), Vector3(4.3, .08, .07), "#2f5a3a")
	for x in [-2.12, 2.12]: s.piece(g, Vector3(x, 1.28, z), Vector3(.08, 2.4, .07), "#2f5a3a")
	for i in 20: s.piece(g, Vector3(-1.9 + i * .2, 1.74, z), Vector3(.025, 1.42, .025), "#2f5a3a")
	s.piece(g, Vector3(0, .56, z), Vector3(4.2, .86, .02), "rusty_metal_sheet|#3f6a48")
	for i in 11: s.piece(g, Vector3(-2.0 + i * .4, 2.62, z), Vector3(.02, .3, .02), "#3b352f")
	s.piece(g, Vector3(0, 2.7, z), Vector3(4.2, .012, .012), "#3b352f")
	s.piece(g, Vector3(0, 2.58, z), Vector3(4.2, .012, .012), "#3b352f")
	for x in [-1.6, 1.6]: s.rod(g, Vector3(x, .07, z), .07, .04, "#222320", Basis(Vector3.FORWARD, PI * .5))
	s.box(Vector3(2.5, .012, .75), Vector3(9.4, .025, .06), "rusty_metal_04")
	# Chain and padlock on the latch side (gone once the keys open it).
	s.gate_chain = Node3D.new()
	g.add_child(s.gate_chain)
	for i in 7:
		var link: MeshInstance3D = s.rod(s.gate_chain, Vector3(-2.18, 1.3 - i * .055, z - .02 + (i % 2) * .02), .016, .05, "#7e7b72", Basis(Vector3.RIGHT if i % 2 else Vector3.FORWARD, PI * .5))
		link.scale = Vector3(1, 1, .5)
	s.piece(s.gate_chain, Vector3(-2.18, .9, z - .05), Vector3(.07, .085, .035), "#c49a3a")

# ---------------------------------------------------------------- the soldiers' checkpoint

static func checkpoint(s) -> void:
	var rng: RandomNumberGenerator = s.rng
	# Sandbags in a horseshoe at the foot of the ramp, facing the settlement.
	var c := Vector3(9.0, G, -7.0)
	for spec in [[Vector3(0, 0, -.6), 0.0, 3.0, 3], [Vector3(-1.5, 0, .4), PI * .5, 2.0, 2], [Vector3(1.5, 0, .4), PI * .5, 2.0, 2]]:
		var b := Basis(Vector3.UP, spec[1])
		var span: float = spec[2]
		var n := int(span / .5)
		for layer in int(spec[3]):
			for j in n:
				if layer == 2 and j in [2, 3]: continue
				var tip := Basis(Vector3.UP, rng.randf_range(-.08, .08))
				s.box(c + spec[0] + b * Vector3(-span * .5 + .25 + j * .5 + (.12 if layer % 2 else 0.0), .12 + layer * .23, 0), Vector3(.48, .22, .36), "#7b7055" if (j + layer) % 2 else "#6f6650", false, b * tip)
		s.shape(s.solid, c + spec[0] + Vector3.UP * .36, Vector3(span, .72, .4), b)
	# Their sign, propped on the bags: hand-lettered on a carton.
	s.box(c + Vector3(.6, .86, -.82), Vector3(.75, .5, .02), "#b99a6a", false, Basis(Vector3.RIGHT, -.2))
	s.sign_at(c + Vector3(.6, .87, -.84), "CHECKPOINT\nHUMINTO • STOP", .1, PI, Color(.12, .1, .08), false).rotation.x = .2
	# Behind them: the folding table kicked over, the log book face down, the field radio with its handset on the
	# end of its cord, a helmet, an ammunition can, sardines and crackers they were eating.
	s.box(c + Vector3(-.4, .38, .7), Vector3(1.2, .04, .7), "#c9c6b8", false, Basis(Vector3.FORWARD, 1.35) * Basis(Vector3.UP, .3))
	for lx in [-.35, .35]: bar(s, c + Vector3(-.95, .05, .7 + lx), c + Vector3(-.2, .75, .7 + lx * .8), .03, "#55574f")
	s.box(c + Vector3(.5, .02, .9), Vector3(.24, .03, .32), "#2c3a52", false, Basis(Vector3.UP, .6))
	s.box(c + Vector3(.5, .036, .9), Vector3(.22, .004, .3), "#e7e2d2", false, Basis(Vector3.UP, .6))
	s.box(c + Vector3(1.0, .17, .3), Vector3(.42, .32, .26), "#3b4230", false, Basis(Vector3.UP, -.3))
	s.box(c + Vector3(1.0, .34, .3), Vector3(.36, .03, .2), "#252a1e", false, Basis(Vector3.UP, -.3))
	bar(s, c + Vector3(1.1, .3, .25), c + Vector3(1.25, .45, .4), .015, "#141414")
	s.wire(c + Vector3(1.05, .3, .38), c + Vector3(.55, .03, 1.2), .2, "#141414", .01)
	s.box(c + Vector3(.55, .05, 1.22), Vector3(.06, .05, .2), "#1c1c1c", false, Basis(Vector3.UP, 1.1))
	s.box(c + Vector3(.95, .41, .32), Vector3(.025, .025, .025), "glow#ff3b1f*2.4")
	s.can(c + Vector3(-.9, .1, 1.3), .15, .17, "#3e4a2c", Basis(Vector3.FORWARD, 1.1), 14)
	s.box(c + Vector3(-1.0, .14, -.1), Vector3(.3, .2, .16), "#4f5636")
	s.put("ligo_sardines", c + Vector3(.2, .02, .45), .4)
	s.drop("skyflakes", c + Vector3(-.2, .02, 1.05))
	for j in 150:
		s.can(c + Vector3(rng.randf_range(-1.2, 1.3), .015, rng.randf_range(-.3, 1.4)), .006, .045, "#b38b3a", Basis(Vector3.FORWARD, PI * .5) * Basis(Vector3.UP, rng.randf() * TAU), 5)
	for j in 3: s.box(c + Vector3(rng.randf_range(-1, 1), .02, rng.randf_range(0, 1.2)), Vector3(.035, .025, .16), "#1f201d", false, Basis(Vector3.UP, rng.randf() * TAU))
	# Razor wire across the yard, funnelling the settlement past the sandbags. Two runs; the east one trampled
	# flat for three metres where they came through.
	var rings := MultiMesh.new()
	rings.transform_format = MultiMesh.TRANSFORM_3D
	var torus := TorusMesh.new()
	torus.inner_radius = .4
	torus.outer_radius = .43
	torus.rings = 14
	torus.ring_segments = 4
	rings.mesh = torus
	var xfs: Array[Transform3D] = []
	for run in [[-7.4, 7.3], [10.7, 11.9]]:
		var x: float = run[0]
		while x < run[1]:
			var flat: bool = x > .6 and x < 3.4
			var b := Basis(Vector3.BACK, PI * .5) * Basis(Vector3.RIGHT, rng.randf_range(-.25, .25))
			var at := Vector3(x, G + (.08 if flat else .42), -9.6 + rng.randf_range(-.06, .06))
			if flat: b = Basis(Vector3.RIGHT, PI * .5 + rng.randf_range(-.3, .3)).scaled(Vector3(1.3, 1.3, .25))
			xfs.append(Transform3D(b, at))
			x += .16
		var lo: float = run[0]
		var hi: float = run[1]
		if run[0] > 0.0:
			s.shape(s.solid, Vector3((lo + hi) * .5, G + .45, -9.6), Vector3(hi - lo, .9, .8))
		else:
			s.shape(s.solid, Vector3((lo + .6) * .5, G + .45, -9.6), Vector3(.6 - lo, .9, .8))
			s.shape(s.solid, Vector3((3.4 + hi) * .5, G + .45, -9.6), Vector3(hi - 3.4, .9, .8))
		# Pickets the coils were staked to.
		var px: float = run[0] + .4
		while px < run[1]:
			if not (px > .6 and px < 3.4): bar(s, Vector3(px, G, -9.6), Vector3(px + .05, G + .95, -9.62), .04, "rusty_metal_04")
			px += 2.6
	rings.instance_count = xfs.size()
	for i in xfs.size(): rings.set_instance_transform(i, xfs[i])
	var wire := MultiMeshInstance3D.new()
	wire.multimesh = rings
	wire.material_override = s.material("#77756c")
	s.add_child(wire)
	# Torn uniform cloth snagged in the coil by the breach.
	s.box(Vector3(.7, G + .55, -9.55), Vector3(.25, .32, .01), "#4a5232", false, Basis(Vector3.FORWARD, .6))

# ---------------------------------------------------------------- the floodlight

static func floodlight(s) -> void:
	# The generator, still running, its cable across the dirt to the tripod light the horde knocked over. The lamp
	# lies on its side and throws its beam across the foot of the wall and up the ramp.
	var gen := Vector3(4.6, G, -8.3)
	s.box(gen + Vector3(0, .32, 0), Vector3(.75, .55, .55), "#2b2c29", true, Basis(Vector3.UP, .4))
	s.box(gen + Vector3(0, .62, 0), Vector3(.82, .06, .62), "#d9a521", false, Basis(Vector3.UP, .4))
	for corner in [Vector3(-.4, .3, -.3), Vector3(.4, .3, -.3), Vector3(-.4, .3, .3), Vector3(.4, .3, .3)]:
		s.box(gen + Basis(Vector3.UP, .4) * corner, Vector3(.04, .62, .04), "#d9a521")
	s.can(gen + Vector3(.9, .2, .3), .13, .4, "#b3261e", Basis(Vector3.UP, .3), 8)
	var head := Vector3(7.3, G + .3, -5.6)
	var aim := Vector3(3.6, G + 1.5, WALL_Z)
	var basis := Basis.looking_at((aim - head).normalized(), Vector3.UP)
	s.box(head, Vector3(.5, .4, .3), "#2e3a2a", false, basis)
	s.box(head + basis * Vector3(0, 0, -.16), Vector3(.44, .34, .02), "glow#f4f6ff*6.0", false, basis)
	for leg in [[Vector3(.6, 0, .7), Vector3(.1, .9, .1)], [Vector3(-.3, 0, .9), Vector3(1.2, .25, 1.9)], [Vector3(.9, 0, -.2), Vector3(1.6, .1, 1.1)]]:
		bar(s, head + leg[0] * Vector3(1, 0, 1) + Vector3(0, -.28, 0), head + leg[1] - Vector3(0, .28, 0), .035, "#262722")
	s.wire(gen + Vector3(-.3, .3, 0), head + Vector3(.25, -.2, .1), .02, "#121212", .022)
	var spot := SpotLight3D.new()
	spot.position = head + basis * Vector3(0, 0, -.3)
	spot.basis = basis
	spot.light_color = Color(.92, .95, 1.0)
	spot.light_energy = 14.0
	spot.spot_range = 24.0
	spot.spot_angle = 28.0
	spot.spot_attenuation = .9
	spot.shadow_enabled = true
	spot.distance_fade_enabled = true
	spot.distance_fade_begin = 60.0
	spot.distance_fade_length = 15.0
	spot.set_meta("outdoor", true)
	s.add_child(spot)
	s.light(head + Vector3(0, .4, 0), Color(.85, .9, 1.0), .5, 4.0)
	# The settlement's wooden power pole by the path, its sodium lamp over the trampled wire; its lines run up to
	# the purok and off over the settlement roofs.
	var pole := Vector3(-1.4, G, -12.6)
	s.can(pole + Vector3.UP * 3.6, .13, 7.2, "dark_wooden_planks|#6b5a48", Basis.IDENTITY, 10)
	s.box(pole + Vector3(0, 6.6, 0), Vector3(1.6, .1, .1), "dark_wooden_planks|#5b4b3b")
	bar(s, pole + Vector3(0, 5.5, 0), pole + Vector3(.2, 5.7, 1.3), .05, "#3a3b37")
	s.box(pole + Vector3(.2, 5.62, 1.45), Vector3(.26, .12, .46), "#2a2b28")
	s.box(pole + Vector3(.2, 5.55, 1.45), Vector3(.2, .02, .38), "glow#ffb35c*3.4")
	s.light(pole + Vector3(.2, 5.3, 1.5), Color(1.0, .66, .32), 3.0, 15.0, true)
	s.box(pole + Vector3(.15, 4.6, 0), Vector3(.3, .4, .22), "#5e615a")
	for k in 3:
		var dx := -.7 + k * .7
		s.wire(pole + Vector3(dx, 6.65, 0), Vector3(dx * 1.4, 4.2, -.4), .9, "#101010", .016)
		s.wire(pole + Vector3(dx, 6.65, 0), Vector3(-14.0, 5.0 + k * .2, -18.0), 1.2, "#101010", .016)
	var hum := AudioStreamPlayer3D.new()
	var stream := load("res://assets/audio/nichols/fridge_hum.ogg") as AudioStream
	if stream is AudioStreamOggVorbis: (stream as AudioStreamOggVorbis).loop = true
	hum.stream = stream
	hum.pitch_scale = .46
	hum.volume_db = -4.0
	hum.unit_size = 4.0
	hum.max_distance = 30.0
	hum.position = gen + Vector3.UP * .4
	hum.autoplay = true
	s.add_child(hum)

# ---------------------------------------------------------------- the blood

static func blood(s) -> void:
	var rng: RandomNumberGenerator = s.rng
	# Through the trampled wire: where the first of them were cut down, and what was dragged off.
	s.stain("pool_big", Vector3(2.0, G, -8.6), .5, 1.9, 1.5)
	s.stain("spatter_floor", Vector3(2.4, G, -9.9), 1.2, 1.6, 1.6, .85)
	s.drag_trail(Vector3(1.8, G, -10.6), Vector3(-.4, G, -13.6), false)
	# Behind the sandbags.
	s.stain("pool_big", Vector3(9.3, G, -7.4), 2.0, 1.8, 1.5)
	s.stain("spatter_floor", Vector3(8.6, G, -6.3), .3, 1.4, 1.4, .8)
	# The one who crawled up the ramp toward the gate: from the sandbags, up the slope, to where he stopped.
	s.drag_trail(Vector3(9.4, G, -6.0), Vector3(11.4, G, -2.6), false)
	var a := Vector3(10.8, ramp_y(10.8), -1.9)
	var b := Vector3(6.8, ramp_y(6.8), -1.85)
	var n := 5
	for i in n:
		var p := a.lerp(b, (i + .5) / n)
		s.stain(["drag_body_a", "drag_body_b", "drag_a"][i % 3], p, rng.randf_range(-.12, .12), 1.6, .6, .95, 1.4)
	s.stain("pool_big", Vector3(6.1, ramp_y(6.1), -1.85), .2, 1.6, 1.2, .95, 1.4)
	s.stain("drag_a", Vector3(8.0, ramp_y(8.0), -1.6), .05, 1.4, .3, .7, 1.4)
	# Below the bent railing.
	s.stain("pool_big", Vector3(6.0, G, -4.1), .9, 1.8, 1.5)
	s.wall_mark("spatter_floor", Vector3(6.2, G + 1.2, OUT_Z - .02), Vector3.FORWARD, 1.0, 1.0, .75)
	# At the gate: the tanod who couldn't open it.
	s.stain("pool_big", Vector3(-.6, 0, -.1), 2.4, 1.7, 1.4)
	s.wall_mark("smear_wall", Vector3(-2.38 + .26, 1.0, .75), Vector3.RIGHT, .9, 1.1)
	s.wall_mark("spatter_floor", Vector3(4.8, -1.0, WALL_Z - .01), Vector3.FORWARD, 1.2, 1.2, .8)
