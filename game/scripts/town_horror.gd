extends Node3D
## 0.23: what happened in the streets (built by scripts/town_siege.gd, sharing its builder and materials).
##
## Gore stays to splatter, smears, pools and drag trails (the owner's rule: no lettering, no hand prints); every odd
## thing has a reason you can see. The town was a barangay holding out behind its wall: the evacuees camped in the
## vacant lots across street A, a checkpoint at the passage logged who came and went, the dead were covered where they
## fell and candles were lit for some of them. Then it came inside. Bodies were dragged off the streets into the
## dark yards, under gates, into the north-west corner; the camp was left mid-meal; the checkpoint's flashlight is
## still on the ground where it fell, its batteries almost gone. Fiesta bunting still hangs over the streets.
##
## Ground decals are placed at build time (the streets are flat at y -2.9, kerbs +0.12). Wall decals (splatter,
## smears, the arrows that mark the survivors' route, the X sprayed on searched doors) and the trails that end under
## yard gates need the town's colliders and its gates, so they are placed one physics frame later (_place_late).

const GROUND := -2.9
const LAYER := 2
const SIEGE := "res://assets/siege/"
const NICHOLS_BLOOD := "res://assets/nichols/blood/"
const MODELS := "res://assets/models/"
const FLIES := "res://assets/audio/nichols/flies.ogg"
const HorrorLiquid := preload("res://scripts/horror_liquid.gd")

var s: InteriorTownSiege
var b: InteriorBalconyBuilder
var rng := RandomNumberGenerator.new()
var _textures: Dictionary = {}
var stats := {"decals": 0, "wall_splatter": 0, "trails": 0, "bodies": 0, "belongings": 0, "door_marks": 0, "arrows": 0,
	"flags": 0, "crows": 0}
var _torch: SpotLight3D
var _torch_time := 0.0
var _late_done := false

func build(siege: InteriorTownSiege) -> void:
	name = "Town horror"
	s = siege
	b = siege.b
	rng.seed = 23666
	_materials()
	_bodies()
	_camp()
	_checkpoint()
	_bunting()
	_tyre_fire()
	_reinforcements()
	_belongings()
	_creatures()
	_ground_marks()
	InteriorLoadClock.later(_late)

# ------------------------------------------------------------------------------------------------ materials

func _materials() -> void:
	var flats := {"sheet white": [Color(.62, .6, .55), .95], "sheet grey": [Color(.38, .37, .34), .95],
		"wax": [Color(.7, .66, .55), .6], "wick": [Color(.02, .02, .02), .9], "candle red": [Color(.32, .04, .03), .5],
		"flag red": [Color(.55, .06, .05), .55], "flag yellow": [Color(.65, .5, .06), .55], "flag blue": [Color(.06, .16, .5), .55],
		"flag white": [Color(.6, .6, .56), .55], "flag green": [Color(.05, .35, .12), .55], "flag pink": [Color(.6, .2, .35), .55],
		"string": [Color(.4, .38, .3), .9], "slipper blue": [Color(.08, .2, .45), .6], "slipper green": [Color(.1, .32, .14), .6],
		"slipper white": [Color(.55, .55, .5), .6], "slipper strap": [Color(.04, .04, .05), .5], "stone": [Color(.24, .23, .21), .95],
		"ash": [Color(.09, .085, .08), 1.0], "char": [Color(.025, .022, .02), .9], "plastic red": [Color(.4, .06, .05), .45],
		"plastic blue": [Color(.08, .2, .42), .45], "plastic green": [Color(.1, .3, .14), .45], "torch": [Color(.08, .08, .085), .4],
		"lens": [Color(1.0, .9, .7), .1], "paper": [Color(.55, .52, .44), .98], "cloth a": [Color(.42, .1, .08), .95],
		"cloth b": [Color(.16, .22, .34), .95], "cloth c": [Color(.5, .48, .42), .95], "cloth d": [Color(.25, .3, .2), .95],
		"umbrella": [Color(.05, .05, .06), .7]}
	for key: String in flats:
		b._flat(key, flats[key][0], flats[key][1])
	InteriorHorrorPropMaterials.dress_palette(b._materials)
	for key in ["sheet white", "sheet grey", "flag red", "flag yellow", "flag blue", "flag white", "flag green", "flag pink",
			"cloth a", "cloth b", "cloth c", "cloth d", "umbrella", "paper"]:
		(b._materials[key] as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	(b._materials["torch"] as StandardMaterial3D).metallic = .6
	var lens := b._materials["lens"] as StandardMaterial3D
	lens.emission_enabled = true
	lens.emission = Color(1.0, .85, .6)
	lens.emission_energy_multiplier = 2.5
	# Covers that bled through: vertex colour carries the stain.
	for key in ["sheet white", "sheet grey"]:
		(b._materials[key] as StandardMaterial3D).vertex_color_use_as_albedo = true
	# A banig (woven sleeping mat): coloured stripes in a basket weave, drawn once.
	var image := Image.create(128, 128, true, Image.FORMAT_RGB8)
	var stripes := [Color(.55, .45, .28), Color(.5, .12, .1), Color(.55, .45, .28), Color(.1, .25, .3), Color(.55, .45, .28), Color(.45, .38, .12)]
	for y in 128:
		for x in 128:
			var over := ((x / 4) + (y / 4)) % 2 == 0
			var band: Color = stripes[(y / 16) % stripes.size()] if over else stripes[(x / 16) % stripes.size()]
			var grain := .82 + .18 * sin(float(x if over else y) * 1.7)
			image.set_pixel(x, y, band * grain)
	image.generate_mipmaps()
	var banig := StandardMaterial3D.new()
	banig.resource_name = "Siege / banig"
	banig.albedo_texture = ImageTexture.create_from_image(image)
	banig.uv1_scale = Vector3.ONE / .7
	banig.roughness = .95
	banig.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	b._materials["banig"] = banig

func _model(file: String, at: Vector3, yaw: float, scale := 1.0, label := "", tilt := Vector3.ZERO, solid := false) -> Node3D:
	var node := InteriorModelKit.place(self, MODELS + file, at, yaw, scale, "bottom", tilt, label)
	InteriorModelKit.prepare_instance(node, LAYER, 70.0, true, false)
	if solid:
		var box := InteriorModelKit.bounds_in(node, self)
		s._solid(label + " body", box.get_center(), box.size * Vector3(.9, 1, .9), "wood")
	stats.belongings += 1
	return node

# ------------------------------------------------------------------------------------------------ decals

func _texture_set(kind: String) -> Array:
	if not _textures.has(kind):
		var generated := HorrorLiquid.texture_set(kind)
		if not generated.is_empty():
			_textures[kind] = generated
		else:
			var root := SIEGE if ResourceLoader.exists(SIEGE + kind + "_albedo.png") else NICHOLS_BLOOD
			_textures[kind] = [load(root + kind + "_albedo.png"), load(root + kind + "_normal.png"), load(root + kind + "_orm.png")]
	return _textures[kind]

## A decal whose texture u runs along `along` and which projects along `up` (the surface normal).
## size = (length along u, projection depth, width along v).
func decal(kind: String, at: Vector3, along: Vector3, up: Vector3, size: Vector3, alpha := 1.0, fade := 34.0) -> Decal:
	var t := _texture_set(kind)
	var d := Decal.new()
	var y := up.normalized()
	var x := (along - y * along.dot(y)).normalized()
	d.basis = Basis(x, y, x.cross(y))
	d.size = size
	d.texture_albedo = t[0]
	d.texture_normal = t[1]
	d.texture_orm = t[2]
	d.modulate = Color(1, 1, 1, alpha)
	d.cull_mask = LAYER
	d.normal_fade = .35
	d.upper_fade = .2
	d.lower_fade = .2
	d.distance_fade_enabled = true
	d.distance_fade_begin = fade
	d.distance_fade_length = 8.0
	add_child(d)
	d.position = at
	HorrorLiquid.finish(d, not HorrorLiquid.texture_set(kind).is_empty())
	stats.decals += 1
	return d

## On a wall with outward normal `n`: texture v runs down the wall, so drips fall.
func wall_decal(kind: String, at: Vector3, n: Vector3, width: float, height: float, alpha := 1.0) -> Decal:
	var x := n.cross(Vector3.DOWN).normalized()
	return decal(kind, at, x, n, Vector3(width, .5, height), alpha, 26.0)

func ground_decal(kind: String, at: Vector3, along: Vector3, length: float, width: float, alpha := 1.0) -> Decal:
	return decal(kind, Vector3(at.x, GROUND + .06, at.z), along, Vector3.UP, Vector3(length, .5, width), alpha)

## A drag trail along `points` (XZ at street level): a pool where it starts, overlapping smears, drops beside it.
func trail(points: Array, width := .62, start_pool := true, alpha := .95) -> void:
	if start_pool:
		ground_decal("pool_big", points[0], Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)), 1.7, 1.4, alpha)
	var kinds := ["drag_body_a", "drag_body_b", "drag_a", "drag_c"]
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var c: Vector3 = points[i + 1]
		var d := Vector2(a.x, a.z).distance_to(Vector2(c.x, c.z))
		var n := maxi(1, ceili(d / 1.45))
		for k in n:
			var f0 := float(k) / n
			var f1 := float(k + 1) / n
			var p := a.lerp(c, (f0 + f1) * .5)
			var along := (c - a).normalized()
			ground_decal(kinds[rng.randi() % kinds.size()], p, along + Vector3(0, 0, rng.randf_range(-.06, .06)), d / n + .35,
				width * rng.randf_range(.85, 1.15), alpha * rng.randf_range(.8, 1.0))
	stats.trails += 1

# ------------------------------------------------------------------------------------------------ bodies

## A body under a sheet (or a tarp, or a banig): the cloth is a draped heightfield over a lying figure, the stain
## where it bled through in its vertex colour. Head toward +Z of `yaw`.
func covered_body(at: Vector3, yaw: float, cover := "sheet white", stain := .8, flies := true, candles := false) -> void:
	at.y = ground_y(at)  # on the kerb-high pavement or the street / yard
	var basis := Basis(Vector3.UP, yaw)
	# Every cover drapes; a tarp or a mat on its own material copy (vertex-coloured, so it can take the stain).
	var key := cover if cover.begins_with("sheet") else cover + " body"
	if not b._materials.has(key):
		var copy := (b._materials[cover] as BaseMaterial3D).duplicate() as BaseMaterial3D
		copy.vertex_color_use_as_albedo = true
		copy.cull_mode = BaseMaterial3D.CULL_DISABLED
		b._materials[key] = copy
	var tool := b._builder(key)
	var stiff := 0.0 if cover.begins_with("sheet") else 1.0
	var nx := 16
	var nz := 30
	var w := 1.1
	var l := 2.05
	var heights: Array = []
	for j in nz + 1:
		var row: Array = []
		for i in nx + 1:
			var x := -w * .5 + w * i / nx
			var z := -l * .5 + l * j / nz
			row.append(_body_height(x, z))
		heights.append(row)
	# Drape: the cloth bridges between high points (a few blur passes that never sink below the body).
	for pass_i in 5 + int(stiff) * 3:
		var next: Array = []
		for j in nz + 1:
			var row: Array = []
			for i in nx + 1:
				var sum := 0.0
				var count := 0
				for dj in [-1, 0, 1]:
					for di in [-1, 0, 1]:
						var jj: int = clampi(j + dj, 0, nz)
						var ii: int = clampi(i + di, 0, nx)
						sum += float(heights[jj][ii])
						count += 1
				row.append(maxf(float(heights[j][i]) * .9, sum / count))
			next.append(row)
		heights = next
	var seep := FastNoiseLite.new()
	seep.seed = rng.randi()
	seep.frequency = .9
	var spot := Vector2(rng.randf_range(-.12, .12), rng.randf_range(.15, .5))
	var verts: Array = []
	for j in nz + 1:
		var row: Array = []
		for i in nx + 1:
			var x := -w * .5 + w * i / nx
			var z := -l * .5 + l * j / nz
			var edge := minf(minf(i, nx - i), minf(j, nz - j))
			var h: float = heights[j][i] if edge > 0 else .004
			h += .012 * sin(x * 31.0 + z * 7.0) * smoothstep(0.0, .05, h)
			# Blood seeps through in patches where the wounds are (chest, head), soaking in from below.
			var chest := 1.0 - Vector2((x - spot.x) * 4.2, (z - spot.y) * 3.4).length()
			var head := 1.0 - Vector2(x * 6.0, (z - .82) * 5.0).length()
			var blot := smoothstep(.0, .5, maxf(chest, head * .8) + seep.get_noise_2d(x * 7.0, z * 7.0) * .45)
			var stained := clampf(stain * blot, 0, 1)
			row.append([at + basis * Vector3(x, h + .004, z), Vector2(x, z), stained])
		verts.append(row)
	if true:
		for j in nz:
			for i in nx:
				var quad := [verts[j][i], verts[j][i + 1], verts[j + 1][i + 1], verts[j + 1][i]]
				var n: Vector3 = ((quad[1][0] as Vector3) - (quad[0][0] as Vector3)).cross((quad[3][0] as Vector3) - (quad[0][0] as Vector3)).normalized()
				if n.y < 0: n = -n
				# x then z: the builder's winding would face down; wound the other way so the cloth faces up.
				for k in [0, 1, 2, 0, 2, 3]:
					var v: Array = quad[k]
					var base := Color(1, 1, 1)
					tool.set_color(base.lerp(Color(.3, .045, .035), float(v[2]) * .9))
					tool.set_normal(n)
					tool.set_uv(v[1])
					tool.add_vertex(v[0])
	# Blood from under it.
	ground_decal("pool_big" if stain > .6 else "pool", at + basis * Vector3(rng.randf_range(-.4, .4), 0, rng.randf_range(-.2, .5)),
		basis * Vector3.BACK, 1.5, 1.3, .9)
	s._solid("Covered body", at + Vector3.UP * .1, Vector3(.7, .2, 1.8), "carpet", basis)
	if candles:
		for k in rng.randi_range(3, 5):
			var p := at + basis * Vector3(rng.randf_range(-.75, .75) * (1 if k % 2 == 0 else -1), 0, .95 + rng.randf_range(0, .35))
			var h := rng.randf_range(.015, .06)
			b._rod(p, p + Vector3.UP * h, .018, "wax" if k % 3 else "candle red", 8)
			b._lathe(p + Vector3.UP * .002, [Vector2(0, 0), Vector2(.05, 0), Vector2(.045, .004), Vector2(0, .006)], "wax", 10)
			b._rod(p + Vector3.UP * h, p + Vector3.UP * (h + .008), .0015, "wick", 3)
	if flies and ResourceLoader.exists(FLIES):
		var buzz := AudioStreamPlayer3D.new()
		buzz.name = "Flies"
		buzz.stream = load(FLIES)
		buzz.unit_size = 1.2
		buzz.max_distance = 14.0
		buzz.volume_db = -8.0
		buzz.autoplay = true
		buzz.bus = "Night" if AudioServer.get_bus_index("Night") >= 0 else "Master"
		add_child(buzz)
		buzz.position = at + Vector3.UP * .4
	stats.bodies += 1

## Height of a lying figure (on its back, head at +z) at local (x, z), metres above the ground.
func _body_height(x: float, z: float) -> float:
	var h := 0.0
	var parts := [[Vector3(0, .1, .82), Vector3(.095, .1, .11)], [Vector3(0, .13, .4), Vector3(.21, .13, .27)],
		[Vector3(0, .11, .08), Vector3(.19, .1, .15)], [Vector3(.1, .08, -.3), Vector3(.075, .075, .28)],
		[Vector3(-.1, .08, -.3), Vector3(.075, .075, .28)], [Vector3(.12, .06, -.7), Vector3(.055, .06, .2)],
		[Vector3(-.12, .06, -.7), Vector3(.055, .06, .2)], [Vector3(.13, .1, -.9), Vector3(.075, .09, .09)],
		[Vector3(-.12, .09, -.9), Vector3(.075, .09, .09)], [Vector3(.27, .055, .32), Vector3(.05, .055, .3)],
		[Vector3(-.27, .055, .32), Vector3(.05, .055, .3)]]
	for part: Array in parts:
		var c: Vector3 = part[0]
		var r: Vector3 = part[1]
		var dx := (x - c.x) / r.x
		var dz := (z - c.z) / r.z
		var q := 1.0 - dx * dx - dz * dz
		if q > 0.0:
			h = maxf(h, (c.y + r.y * sqrt(q) - r.y * .35) * 1.45)
	return h

func _bodies() -> void:
	# Street B, east pavement: covered where it fell, candles for it.
	covered_body(Vector3(23.55, GROUND + .12, 11.4), 0.03, "sheet white", .9, true, true)
	# Street C, against the north kerb: under a sheet gone grey, candles.
	covered_body(Vector3(-9.1, GROUND + .12, 51.75), PI * .5 + .05, "sheet grey", .75, true, true)
	# Street D, east pavement, under a banig someone brought out of a house.
	covered_body(Vector3(-16.55, GROUND + .12, 43.6), .02, "banig", .6, true, false)
	# The north-west corner where the drags end: under a blue tarp.
	covered_body(Vector3(-21.7, GROUND, 52.7), PI * .5 - .3, "tarp blue", .9, true)

# ------------------------------------------------------------------------------------------------ the camp

## The middle vacant lot across street A (x -6.2..4, z 21.8..31.6): the evacuees' camp, left mid-meal.
func _camp() -> void:
	# A tarp shelter on a bamboo ridge, one end collapsed.
	var ridge_a := Vector3(-4.6, GROUND + 1.7, 24.4)
	var ridge_b := Vector3(-1.5, GROUND + .55, 25.0)
	b._rod(ridge_a + Vector3.DOWN * 1.7, ridge_a, .035, "bamboo", 6)
	b._rod(ridge_a, ridge_b, .03, "bamboo", 6)
	for side: float in [-1.0, 1.0]:
		var foot_a := ridge_a + Vector3(0, -1.7, side * 1.25)
		var foot_b := ridge_b + Vector3(.2, -.55, side * 1.1)
		b._plate([ridge_a, ridge_b, foot_b, foot_a], "tarp blue")
	s._solid("Camp shelter", Vector3(-3.0, GROUND + .55, 24.7), Vector3(3.2, 1.1, 2.2), "carpet")
	# A standing A-frame under the tree line, its tarp still tied.
	var ra := Vector3(.6, GROUND + 1.55, 28.2)
	var rb := Vector3(3.0, GROUND + 1.5, 28.5)
	for p: Vector3 in [ra, rb]:
		for side: float in [-1.0, 1.0]:
			b._rod(p + Vector3(0, -1.55, side * 1.0), p, .03, "bamboo", 6)
	b._rod(ra, rb, .03, "bamboo", 6)
	for side: float in [-1.0, 1.0]:
		b._plate([ra, rb, rb + Vector3(0, -1.5, side * 1.05), ra + Vector3(0, -1.55, side * 1.0)], "tarp blue")
	s._solid("Camp tent", Vector3(1.8, GROUND + .75, 28.35), Vector3(2.6, 1.5, 2.1), "carpet")
	# Mats, things on them.
	for spec: Array in [[Vector3(-1.2, 0, 27.4), .3], [Vector3(-3.6, 0, 27.9), -.2], [Vector3(2.1, 0, 26.0), 1.4]]:
		b._box("Banig", Vector3(spec[0].x, GROUND + .006, spec[0].z), Vector3(1.0, .012, 1.9), "banig", false, Basis(Vector3.UP, spec[1]))
	for k in 6:
		var p := Vector3(rng.randf_range(-4.5, 2.8), GROUND, rng.randf_range(25.8, 30.5))
		b._sphere(p + Vector3.UP * .06, Vector3(rng.randf_range(.3, .5), .12, rng.randf_range(.25, .4)), ["cloth a", "cloth b", "cloth c", "cloth d"][k % 4], 7)
	# The cooking fire: a ring of stones, ash, the pot still on it, the rice scorched black inside.
	var fire := Vector3(-.4, GROUND, 25.1)
	for k in 9:
		var a := TAU * k / 9.0
		b._sphere(fire + Vector3(cos(a) * .32, .06, sin(a) * .32), Vector3(.16, .12, .14) * rng.randf_range(.8, 1.2), "stone", 6)
	b._sphere(fire + Vector3.UP * .02, Vector3(.5, .05, .5), "ash", 8)
	_model("nichols/nh_pot_enamel_01.glb", fire + Vector3.UP * .12, 20.0, 1.3, "Camp pot")
	decal("scorch", fire + Vector3.UP * .05, Vector3.RIGHT, Vector3.UP, Vector3(1.6, .5, 1.6), .9)
	# Plates and a basin knocked over; a monobloc on its side.
	for k in 4:
		var p := fire + Vector3(rng.randf_range(-1.2, 1.4), .01, rng.randf_range(.5, 1.6))
		b._lathe(p, [Vector2(0, 0), Vector2(.11, 0), Vector2(.12, .02), Vector2(.0, .012)], "plastic red" if k % 2 else "plastic green", 12,
			Basis(Vector3.RIGHT, rng.randf_range(0, .3)))
	b._lathe(Vector3(-2.2, GROUND + .2, 29.6), [Vector2(0, -.2), Vector2(.22, -.2), Vector2(.3, .18), Vector2(.28, .2)], "plastic blue", 16, Basis(Vector3.FORWARD, 1.45))
	_model("street/plastic_monobloc_chair_01.glb", Vector3(-.9, GROUND, 23.2), 40.0, 1.0, "Camp chair", Vector3(0, 0, 85))
	_model("street/plastic_monobloc_chair_01.glb", Vector3(1.1, GROUND, 24.0), -70.0, 1.0, "Camp chair")
	# A body by the shelter, under a sheet; and the drag from the shelter to the dark back corner, where whatever
	# was taken lies under a second sheet.
	covered_body(Vector3(-2.7, GROUND, 26.9), PI * .5 + .2, "sheet white", .85, true, false)
	trail([Vector3(-3.9, 0, 25.6), Vector3(-1.6, 0, 27.6), Vector3(.9, 0, 29.6), Vector3(3.3, 0, 31.0)], .7)
	covered_body(Vector3(3.35, GROUND, 30.95), PI * .5, "sheet grey", 1.0, false)
	# A clothes line across the lot from the tent to the fence post: shirts and a towel still on it.
	_line(Vector3(-5.9, GROUND + 1.85, 30.9), Vector3(.2, GROUND + 1.7, 28.4), 6)

## A sagging clothes line with things pegged on it.
func _line(a: Vector3, c: Vector3, items: int) -> void:
	var points: Array = []
	for i in 9:
		var f := i / 8.0
		points.append(a.lerp(c, f) + Vector3.DOWN * sin(f * PI) * .22)
	b._tube(points, .004, "string", 3)
	b._rod(a + Vector3.DOWN * 1.85, a + Vector3.UP * .05, .03, "bamboo", 6)
	var along := (c - a).normalized()
	for k in items:
		var f := (k + .7) / (items + .4)
		var top: Vector3 = a.lerp(c, f) + Vector3.DOWN * (sin(f * PI) * .22 + .01)
		var w := rng.randf_range(.38, .6)
		var h := rng.randf_range(.45, .7)
		var key: String = ["cloth a", "cloth b", "cloth c", "cloth d"][rng.randi() % 4]
		var down := Vector3.DOWN.rotated(along, rng.randf_range(-.12, .12))
		# A shirt: body and two sleeves; a towel: one sheet.
		b._plate([top - along * w * .5, top + along * w * .5, top + along * w * .45 + down * h, top - along * w * .45 + down * h], key)
		if k % 2 == 0:
			for side: float in [-1.0, 1.0]:
				var sh := top + along * side * w * .5
				b._plate([sh, sh + along * side * .16, sh + along * side * .2 + down * .2, sh + down * .2], key)

# ------------------------------------------------------------------------------------------------ checkpoint

## The barangay checkpoint at the passage: a tarp canopy, a folding table on its side, the logbook's pages in the
## street, chairs, a pool and the drag to where the dead were laid by the wall; the tanod's flashlight still lit.
func _checkpoint() -> void:
	var c := Vector3(-20.6, GROUND, 20.2)
	for p: Vector3 in [c + Vector3(-1.4, 0, -.9), c + Vector3(1.4, 0, -.9), c + Vector3(-1.4, 0, .8), c + Vector3(1.4, 0, .8)]:
		b._rod(p, p + Vector3.UP * (2.3 if p.z < c.z else 2.5), .03, "bamboo", 6)
		s._solid("Checkpoint pole", p + Vector3.UP * 1.2, Vector3(.07, 2.4, .07), "wood")
	b._plate([c + Vector3(-1.5, 2.32, -1.0), c + Vector3(1.5, 2.3, -1.0), c + Vector3(1.5, 2.52, .9), c + Vector3(-1.5, 2.5, .9)], "tarp blue")
	# One corner of the tarp torn loose, hanging.
	b._plate([c + Vector3(1.5, 2.3, -1.0), c + Vector3(1.0, 2.31, -1.0), c + Vector3(1.6, 1.3, -1.2), c + Vector3(1.9, 1.5, -1.15)], "tarp blue")
	var desk := _model("nichols/nh_metal_office_desk.glb", c + Vector3(.2, 0, .3), 180.0, .62, "Checkpoint table", Vector3(0, 0, 88))
	s._solid("Checkpoint table", c + Vector3(.2, .3, .3), Vector3(1.25, .6, .6), "metal")
	_model("street/plastic_monobloc_chair_01.glb", c + Vector3(-.9, 0, -.3), 160.0, 1.0, "Checkpoint chair")
	_model("street/plastic_monobloc_chair_01.glb", c + Vector3(1.6, 0, -1.6), 10.0, 1.0, "Checkpoint chair", Vector3(80, 0, 0))
	# Logbook pages blown across the street.
	for k in 14:
		var p := c + Vector3(rng.randf_range(-3.0, 3.5), .015, rng.randf_range(-4.5, .5))
		b._box("Logbook page", p + Vector3.UP * (.0 if p.z > 20.9 else .0), Vector3(.21, .002, .29), "paper", false,
			Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-.06, .06)))
	# The pool where it happened, the drag to the wall, and the two laid there under mats.
	trail([Vector3(-20.4, 0, 17.0), Vector3(-21.4, 0, 15.2), Vector3(-22.3, 0, 13.6), Vector3(-22.6, 0, 12.6)], .66)
	covered_body(Vector3(-22.85, GROUND, 11.85), PI + .04, "banig", .7, true, false)
	covered_body(Vector3(-22.9, GROUND, 9.75), PI - .03, "sheet white", .8, false, false)
	decal("spatter_floor", Vector3(-19.6, GROUND + .06, 17.6), Vector3(1, 0, .4), Vector3.UP, Vector3(1.6, .5, 1.6), .9)
	# The flashlight: on its side by the pool, still pointing at the drag; the batteries are almost gone.
	var at := Vector3(-19.75, GROUND + .03, 17.25)
	var aim := (Vector3(-22.3, GROUND + .1, 13.4) - at).normalized()
	var basis := Basis.looking_at(aim)
	b._rod(at - aim * .11, at + aim * .1, .019, "torch", 10)
	b._rod(at + aim * .1, at + aim * .13, .027, "torch", 12)
	b._lathe(at + aim * .131, [Vector2(0, 0), Vector2(.024, 0), Vector2(0, .002)], "lens", 12, Basis.looking_at(aim) * Basis(Vector3.RIGHT, -PI * .5))
	_torch = SpotLight3D.new()
	_torch.name = "Dropped flashlight"
	_torch.light_color = Color(1.0, .86, .62)
	_torch.light_energy = 1.4
	_torch.spot_range = 9.0
	_torch.spot_angle = 18.0
	_torch.spot_attenuation = .9
	_torch.light_cull_mask = LAYER
	_torch.shadow_enabled = true
	_torch.light_volumetric_fog_energy = .4
	add_child(_torch)
	_torch.transform = Transform3D(basis, at + aim * .14 + Vector3.UP * .02)

# ------------------------------------------------------------------------------------------------ bunting

## Banderitas: plastic fiesta bunting strung across the streets for a feast nobody held. Some strings have snapped.
func _bunting() -> void:
	for spec: Array in [[Vector3(17.7, 4.5, 9.6), Vector3(25.2, 4.3, 9.9)], [Vector3(17.7, 4.4, 23.6), Vector3(25.1, 4.6, 23.2)],
			[Vector3(17.7, 4.3, 37.4), Vector3(25.2, 4.4, 37.7)], [Vector3(11.0, 4.4, 14.5), Vector3(11.4, 4.2, 21.4)],
			[Vector3(.8, 4.5, 14.5), Vector3(1.0, 4.4, 21.4)], [Vector3(-9.2, 4.3, 14.5), Vector3(-9.4, 4.5, 21.4)],
			[Vector3(-17.0, 4.4, 14.5), Vector3(-16.8, 4.2, 21.4)], [Vector3(8.0, 4.5, 45.4), Vector3(8.2, 4.4, 52.4)],
			[Vector3(-6.0, 4.4, 45.4), Vector3(-6.2, 4.6, 52.4)]]:
		var a: Vector3 = spec[0] + Vector3.UP * GROUND
		var c: Vector3 = spec[1] + Vector3.UP * GROUND
		var snapped := rng.randf() < .25
		if snapped:
			# One end gave way: the string hangs down from the other, flags dragging on the ground.
			var low := a.lerp(c, .55) + Vector3(rng.randf_range(-.4, .4), 0, 0)
			low.y = GROUND + .02
			_flags(c, low, .3, false)
		else:
			_flags(a, c, .55, true)

func _flags(a: Vector3, c: Vector3, sag: float, across: bool) -> void:
	var points: Array = []
	for i in 13:
		var f := i / 12.0
		points.append(a.lerp(c, f) + Vector3.DOWN * sin(f * PI) * sag * (1.0 if across else .0) + (Vector3.DOWN * f * f * .0))
	b._tube(points, .003, "string", 3)
	var length := a.distance_to(c)
	var n := int(length / .3)
	var keys := ["flag red", "flag yellow", "flag blue", "flag white", "flag green", "flag pink"]
	var along := (c - a).normalized()
	for i in n:
		if rng.randf() < .12: continue
		var f := (i + .5) / n
		var p: Vector3 = a.lerp(c, f) + Vector3.DOWN * sin(f * PI) * sag * (1.0 if across else 0.0)
		var hang := Vector3.DOWN.rotated(along, rng.randf_range(-.35, .35))
		var h := .26 if rng.randf() > .15 else rng.randf_range(.08, .18)
		var tool := b._builder(keys[i % keys.size()])
		var q0 := p - along * .1
		var q1 := p + along * .1
		var q2 := p + hang * h
		var normal := along.cross(hang).normalized()
		for v: Vector3 in [q0, q2, q1]:
			tool.set_normal(normal)
			tool.set_uv(Vector2(v.x, v.y))
			tool.add_vertex(v)
		stats.flags += 1

# ------------------------------------------------------------------------------------------------ street dressing

## Tyres burnt in street B (to keep something away, or to see): rubber melted to the asphalt, a scorch and soot.
func _tyre_fire() -> void:
	var at := Vector3(22.7, GROUND, 33.6)
	for k in 5:
		var p := at + Vector3(rng.randf_range(-.6, .6), k * .1, rng.randf_range(-.5, .5))
		var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-.3, .3))
		b._lathe(p + Vector3.UP * .08, [Vector2(.18, -.06), Vector2(.28, -.07), Vector2(.3, 0), Vector2(.27, .06), Vector2(.18, .05)], "char", 14, basis)
	# The steel belts left when the rubber burns away.
	for k in 3:
		b._ring(at + Vector3(rng.randf_range(-.8, .8), .02, rng.randf_range(-.8, .8)), .3, "rust", Basis(Vector3.RIGHT, PI * .5 + rng.randf_range(-.2, .2)), .006, 18)
	b._sphere(at + Vector3.UP * .02, Vector3(1.4, .06, 1.2), "ash", 10)
	decal("scorch", at + Vector3.UP * .05, Vector3.RIGHT, Vector3.UP, Vector3(3.6, .6, 3.2), 1.0)
	s._solid("Burnt tyres", at + Vector3.UP * .2, Vector3(1.3, .4, 1.1), "carpet")

## Inside the wall where it was hit hardest: furniture, drums and sandbags piled against the sheets.
func _reinforcements() -> void:
	# Street A's east end (the wall across the road at x 25.8).
	var x := InteriorTownSiege.EAST_X - .55
	_model("decor/sofa_02.glb", Vector3(x - .2, GROUND, 17.0), 90.0, 1.0, "Barricade sofa", Vector3(0, 0, -12), true)
	_model("street/oil_drum.glb", Vector3(x, GROUND, 15.6), 0.0, 1.0, "Barricade drum", Vector3.ZERO, true)
	_model("street/oil_drum.glb", Vector3(x - .1, GROUND, 19.2), 30.0, 1.0, "Barricade drum", Vector3.ZERO, true)
	_model("street/oil_drum.glb", Vector3(x - .9, GROUND, 18.8), 0.0, 1.0, "Barricade drum", Vector3(90, 20, 0), true)
	_model("decor/steel_frame_shelves_01.glb", Vector3(x - .15, GROUND, 20.4), 90.0, 1.0, "Barricade shelf", Vector3(0, 0, 18), true)
	for k in 4:
		s._sandbag(Vector3(x - .3, GROUND, 15.3 + k * 1.4), Vector3.BACK)
	s.knock_spots.append([Vector3(InteriorTownSiege.EAST_X + .4, GROUND + 1.2, 17.6), Vector3.RIGHT, null])
	s.knock_spots.append([Vector3(InteriorTownSiege.EAST_X + .4, GROUND + 1.0, 19.6), Vector3.RIGHT, null])
	# Street C's east end: crates and a table on end, a propane tank.
	_model("nichols/nh_wooden_crate_01.glb", Vector3(x, GROUND, 47.2), 90.0, 1.2, "Barricade crate", Vector3.ZERO, true)
	_model("nichols/nh_wooden_crate_01.glb", Vector3(x - .05, GROUND + .42, 47.3), 84.0, 1.2, "Barricade crate", Vector3.ZERO, true)
	_model("nichols/nh_wooden_crate_02.glb", Vector3(x - .1, GROUND, 49.5), 95.0, 1.2, "Barricade crate", Vector3.ZERO, true)
	_model("street/oil_drum.glb", Vector3(x, GROUND, 50.9), 0.0, 1.0, "Barricade drum", Vector3.ZERO, true)
	_model("nichols/nh_propane_tank.glb", Vector3(x - .8, GROUND, 48.6), 0.0, 1.0, "Barricade tank")
	s.knock_spots.append([Vector3(InteriorTownSiege.EAST_X + .4, GROUND + 1.1, 48.8), Vector3.RIGHT, null])
	# Street D at the north wall, and the north wall behind the camp.
	s.knock_spots.append([Vector3(-19.0, GROUND + 1.2, InteriorTownSiege.NORTH_Z + .4), Vector3.BACK, null])
	s.knock_spots.append([Vector3(-6.0, GROUND + 1.0, InteriorTownSiege.NORTH_Z + .4), Vector3.BACK, null])

## Things people dropped running: rubber slippers (singles and pairs), bags of rubbish, boxes, a suitcase, umbrellas.
func _belongings() -> void:
	var slippers := [Vector3(18.6, 0, 12.2), Vector3(22.7, 0, 20.2), Vector3(20.1, 0, 28.6), Vector3(19.0, 0, 41.5),
		Vector3(9.3, 0, 16.6), Vector3(-3.4, 0, 19.7), Vector3(-14.2, 0, 16.0), Vector3(-19.6, 0, 26.4), Vector3(-18.1, 0, 38.2),
		Vector3(3.2, 0, 47.4), Vector3(-12.6, 0, 50.1), Vector3(23.6, 0, 45.2), Vector3(-21.3, 0, 18.9), Vector3(16.6, 0, 6.4)]
	for k in slippers.size():
		var p: Vector3 = slippers[k]
		_slipper(p, rng.randf() * TAU, ["slipper blue", "slipper green", "slipper white"][k % 3])
		if k % 3 == 0:
			_slipper(p + Vector3(rng.randf_range(-.6, .6), 0, rng.randf_range(-.6, .6)), rng.randf() * TAU, ["slipper blue", "slipper green", "slipper white"][k % 3])
	for spec: Array in [[Vector3(17.9, 0, 14.0), 3], [Vector3(24.7, 0, 32.4), 4], [Vector3(-16.3, 0, 21.6), 3], [Vector3(-13.7, 0, 45.3), 2],
			[Vector3(13.3, 0, 52.2), 3], [Vector3(-22.6, 0, 46.1), 2]]:
		for k: int in spec[1]:
			var p: Vector3 = spec[0] + Vector3(rng.randf_range(-.5, .5), 0, rng.randf_range(-.5, .5))
			_model("nichols/nh_trashbag.glb", Vector3(p.x, ground_y(p), p.z), rng.randf() * 360.0, rng.randf_range(.85, 1.15), "Rubbish bag")
	_model("nichols/nh_vintage_suitcase.glb", Vector3(22.4, GROUND, 30.2), 70.0, .42, "Suitcase", Vector3(0, 0, 0))
	_model("nichols/nh_vintage_suitcase.glb", Vector3(-8.2, GROUND, 17.0), -20.0, .42, "Suitcase", Vector3(90, 0, 0))
	_model("nichols/nh_cardboard_box_01.glb", Vector3(19.2, GROUND, 22.0), 15.0, 1.0, "Box")
	_model("nichols/nh_cardboard_box_01.glb", Vector3(-11.5, GROUND, 47.8), -40.0, 1.0, "Box", Vector3(0, 0, 90))
	_model("nichols/nh_cardboard_box_01.glb", Vector3(6.6, GROUND, 19.8), 60.0, 1.0, "Box")
	for spec: Array in [[Vector3(21.9, 0, 15.6), 1.2], [Vector3(-12.0, 0, 18.9), -.4]]:
		_umbrella(spec[0], spec[1])

func _on_pavement(p: Vector3) -> bool:
	return ground_y(p) > GROUND + .06

var _floors: Array = []  # [AABB, top y] of the town's kerbs and low slabs

## The walking surface under `p` (street level, or the top of a kerb / pavement slab), from the town's colliders.
func ground_y(p: Vector3) -> float:
	if _floors.is_empty():
		var colliders := s.town.get_node_or_null("NeighbourhoodColliders")
		if colliders != null:
			for child in colliders.get_children():
				if not child is CollisionShape3D or (child as CollisionShape3D).disabled: continue
				var c := child as CollisionShape3D
				var box := AABB()
				if c.shape is BoxShape3D:
					var size: Vector3 = (c.shape as BoxShape3D).size
					box = AABB(c.position - size * .5, size)
				elif c.shape is ConvexPolygonShape3D:
					var pts: PackedVector3Array = (c.shape as ConvexPolygonShape3D).points
					box = AABB(c.transform * pts[0], Vector3.ZERO)
					for q in pts: box = box.expand(c.transform * q)
				else:
					continue
				var top := box.end.y
				if top > GROUND + .02 and top < GROUND + .3 and box.size.x > .3 and box.size.z > .3:
					_floors.append([box, top])
		_floors.append([AABB(), GROUND])
	var y := GROUND
	for item: Array in _floors:
		var box: AABB = item[0]
		if p.x > box.position.x + .05 and p.x < box.end.x - .05 and p.z > box.position.z + .05 and p.z < box.end.z - .05:
			y = maxf(y, float(item[1]))
	return y

func _slipper(at: Vector3, yaw: float, key: String) -> void:
	var y := ground_y(at)
	var basis := Basis(Vector3.UP, yaw)
	var p := Vector3(at.x, y + .008, at.z)
	b._box("Tsinelas", p, Vector3(.095, .016, .25), key, false, basis)
	b._box("Tsinelas heel", p + basis * Vector3(0, 0, -.1), Vector3(.085, .0161, .06), key, false, basis * Basis(Vector3.UP, .1))
	var toe := p + basis * Vector3(0, .01, .07)
	for side: float in [-1.0, 1.0]:
		b._rod(toe, p + basis * Vector3(side * .045, .03, -.02), .005, "slipper strap", 4)
	stats.belongings += 1

func _umbrella(at: Vector3, yaw: float) -> void:
	# Open, blown over onto its side, a rib bent.
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, 1.2)
	var centre := Vector3(at.x, GROUND + .45, at.z)
	b._lathe(centre, [Vector2(0, .28), Vector2(.25, .22), Vector2(.45, .08), Vector2(.5, 0)], "umbrella", 8, basis)
	b._rod(centre + basis * Vector3(0, .28, 0), centre + basis * Vector3(0, -.45, 0), .008, "torch", 5)

func _creatures() -> void:
	# Crows on the ground by the bodies, the camp and the north-west corner.
	for spec: Array in [[Vector3(22.9, 0, 12.6), 100.0], [Vector3(-1.9, 0, 28.1), 10.0], [Vector3(-21.9, 0, 10.8), -80.0],
			[Vector3(-20.6, 0, 53.4), 140.0], [Vector3(-22.6, 0, 51.6), 200.0]]:
		var at: Vector3 = spec[0]
		at.y = ground_y(at)
		_model("nichols/nh_crow.glb" if stats.crows % 2 == 0 else "nichols/nh_crow_b.glb", at, spec[1], 1.0, "Crow")
		stats.crows += 1
	for spec: Array in [[Vector3(-8.4, GROUND + .12, 51.2), 30.0], [Vector3(2.8, GROUND, 30.4), 200.0], [Vector3(-22.1, GROUND, 11.2), 80.0]]:
		_model("nichols/nh_street_rat.glb", spec[0], spec[1], 1.7, "Rat")

# ------------------------------------------------------------------------------------------------ ground marks

func _ground_marks() -> void:
	# Survivors' arrows sprayed on the road where the route turns.
	ground_decal("spray_arrow", Vector3(20.6, 0, 8.6), Vector3.BACK, 2.0, 1.1, .85)
	ground_decal("spray_arrow", Vector3(19.4, 0, 18.25), Vector3.LEFT, 2.2, 1.2, .85)
	ground_decal("spray_arrow", Vector3(-15.3, 0, 16.3), Vector3.LEFT, 2.0, 1.1, .8)
	stats.arrows += 3
	# The hooded man's muddy prints to the hole and out the other side (he comes and goes this way).
	var steps: Array[Vector3] = []
	for k in 9:
		steps.append(Vector3(20.2, 0, 47.5).lerp(Vector3(InteriorTownSiege.HOLE_X, 0, InteriorTownSiege.NORTH_Z - .3), k / 8.0))
	for k in 6:
		steps.append(Vector3(InteriorTownSiege.HOLE_X, 0, InteriorTownSiege.NORTH_Z + .5).lerp(Vector3(21.0, 0, 59.0), k / 5.0))
	for k in steps.size():
		var side := .1 if k % 2 == 0 else -.1
		var dir := Vector3.BACK if k == steps.size() - 1 else (steps[mini(k + 1, steps.size() - 1)] - steps[k]).normalized()
		var right := dir.cross(Vector3.UP)
		# shoe_mud's toe is at -v; the decal's v axis is along x.cross(up): turn it so the toe leads.
		ground_decal("shoe_mud", steps[k] + right * side, right, .12, .3, .8)
	# Drips along street B from the lane mouth to the corner, and a smear where something fell there.
	for k in 7:
		ground_decal("drops", Vector3(19.6 + rng.randf_range(-.6, .6), 0, 6.5 + k * 1.6), Vector3(rng.randf_range(-1, 1), 0, 1), .7, .7, .8)
	ground_decal("pool", Vector3(22.8, 0, 25.4), Vector3.RIGHT, 1.3, 1.1, .9)
	# The north-west corner: two drags converging on the tarp.
	trail([Vector3(-18.4, 0, 47.6), Vector3(-19.6, 0, 50.4), Vector3(-21.2, 0, 52.4), Vector3(-22.5, 0, 53.4)], .6)
	trail([Vector3(-12.6, 0, 49.4), Vector3(-16.8, 0, 50.9), Vector3(-20.2, 0, 52.2)], .55, true, .75)
	# Street C: the pool by the covered body runs into the gutter.
	ground_decal("spatter_floor", Vector3(-7.4, 0, 50.6), Vector3(1, 0, -.3), 1.6, 1.6, .9)

# ------------------------------------------------------------------------------------------------ late: needs colliders

func _late() -> void:
	if not is_inside_tree(): return
	# The neighbourhood installs its gates and doors deferred too; let that and one physics step happen first.
	for i in 3:
		await get_tree().physics_frame
	if not is_inside_tree(): return
	_place_late()

func _place_late() -> void:
	if _late_done: return
	_late_done = true
	var space := get_world_3d().direct_space_state
	_wall_splatter(space)
	_route_arrows(space)
	_door_marks(space)
	_gate_trails()
	set_meta("counts", stats)

func _wall_hit(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 2)
	var hit := space.intersect_ray(query)
	if hit.is_empty() or absf((hit.normal as Vector3).y) > .3: return {}
	var body: Object = hit.collider
	if body is RigidBody3D or body is AnimatableBody3D: return {}
	return hit

## Splatter and smears on the houses and the wall: sampled along every street, at chest to head height mostly.
func _wall_splatter(space: PhysicsDirectSpaceState3D) -> void:
	var lines := [[Vector3(21.0, 0, -15.0), Vector3(21.0, 0, 52.0), 2.4], [Vector3(-22.0, 0, 18.0), Vector3(24.0, 0, 18.0), 2.6],
		[Vector3(-22.0, 0, 48.8), Vector3(24.0, 0, 48.8), 2.6], [Vector3(-19.0, 0, 12.0), Vector3(-19.0, 0, 53.0), 2.4]]
	var kinds := ["splat_a", "splat_b", "splat_c", "splat_a", "splat_b", "smear_wall"]
	for line: Array in lines:
		var a: Vector3 = line[0]
		var c: Vector3 = line[1]
		var step: float = line[2]
		var along := (c - a).normalized()
		var side := Vector3(-along.z, 0, along.x)
		var t := 0.0
		while t < a.distance_to(c):
			if rng.randf() < .42:
				var sign := 1.0 if rng.randf() < .5 else -1.0
				var h := GROUND + rng.randf_range(.5, 2.1)
				var origin := a + along * t + Vector3.UP * h
				var hit := _wall_hit(space, origin, origin + side * sign * 7.0)
				if not hit.is_empty() and InteriorTownSiege.inside(hit.position) and not _near_home(hit.position):
					var kind: String = kinds[rng.randi() % kinds.size()]
					var size := rng.randf_range(.55, 1.35)
					if kind == "smear_wall":
						var foot: Vector3 = hit.position
						foot.y = GROUND + .75
						wall_decal(kind, foot, hit.normal, .55, 1.6, .9)
					else:
						wall_decal(kind, hit.position, hit.normal, size, size, rng.randf_range(.8, 1.0))
					stats.wall_splatter += 1
			t += step
	# The inside of the wall by the hole, the corner and the camp: smears low down where it was hit from outside.
	for spec: Array in [[Vector3(20.2, GROUND + .9, 52.0), Vector3.BACK], [Vector3(-21.8, GROUND + 1.0, 52.4), Vector3.BACK],
			[Vector3(24.0, GROUND + 1.1, 17.8), Vector3.RIGHT], [Vector3(-21.5, GROUND + 1.0, 13.0), Vector3.LEFT]]:
		var origin: Vector3 = spec[0]
		var hit := _wall_hit(space, origin, origin + (spec[1] as Vector3) * 4.0)
		if not hit.is_empty():
			wall_decal("splat_b", hit.position, hit.normal, 1.1, 1.1, .95)
			stats.wall_splatter += 1

func _near_home(p: Vector3) -> bool:
	# The owner's house and its courtyard stay clean.
	return p.x > -8.0 and p.x < 14.0 and p.z > -5.0 and p.z < 9.2

## Orange arrows on walls where the route to the passage turns (pointing along `dir`).
func _route_arrows(space: PhysicsDirectSpaceState3D) -> void:
	for spec: Array in [[Vector3(20.6, GROUND + 1.5, 6.4), Vector3.RIGHT, Vector3.BACK], [Vector3(19.2, GROUND + 1.6, 16.4), Vector3.FORWARD, Vector3.LEFT],
			[Vector3(6.0, GROUND + 1.5, 16.6), Vector3.FORWARD, Vector3.LEFT], [Vector3(-8.0, GROUND + 1.6, 16.6), Vector3.FORWARD, Vector3.LEFT],
			[Vector3(-15.0, GROUND + 1.4, 19.8), Vector3.BACK, Vector3.LEFT], [Vector3(-21.0, GROUND + 1.6, 16.4), Vector3.FORWARD, Vector3.LEFT],
			[Vector3(10.0, GROUND + 1.4, 19.6), Vector3.BACK, Vector3.LEFT]]:
		var origin: Vector3 = spec[0]
		var hit := _wall_hit(space, origin, origin + (spec[1] as Vector3) * 8.0)
		if hit.is_empty(): continue
		var n: Vector3 = hit.normal
		var x := n.cross(Vector3.DOWN).normalized()
		var kind := "spray_arrow" if x.dot(spec[2]) > 0.0 else "spray_arrow_l"
		wall_decal(kind, hit.position, n, 1.1, 1.1, .9)
		stats.arrows += 1

## An X sprayed on some of the house doors: searched, nobody (alive) inside.
func _door_marks(space: PhysicsDirectSpaceState3D) -> void:
	var interactions := s.town.get_node_or_null("Neighborhood interactions")
	if interactions == null or not "doors" in interactions: return
	var doors: Array = interactions.doors
	for k in doors.size():
		if k % 2 == 1: continue
		var door := doors[k] as Node3D
		if not is_instance_valid(door): continue
		var p := door.global_position
		if not InteriorTownSiege.inside(p) or _near_home(p): continue
		for dir: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
			var origin := Vector3(p.x, GROUND + 1.55, p.z) + dir * 1.4
			var hit := _wall_hit(space, origin, origin - dir * 2.0)
			if not hit.is_empty() and (hit.normal as Vector3).dot(dir) > .7:
				wall_decal("spray_x", hit.position, hit.normal, .85, .85, .9)
				stats.door_marks += 1
				break

## Drags that end under yard gates: the yard behind is dark and whatever was dragged is in there.
func _gate_trails() -> void:
	var interactions := s.town.get_node_or_null("Neighborhood interactions")
	if interactions == null or not "gates" in interactions: return
	var gates: Array = interactions.gates
	for start: Vector3 in [Vector3(21.6, 0, 24.6), Vector3(5.0, 0, 48.4), Vector3(-19.3, 0, 31.0), Vector3(12.8, 0, 16.6), Vector3(21.2, 0, 41.0)]:
		var best: Node3D = null
		var best_d := 9.5
		for gate in gates:
			if not is_instance_valid(gate): continue
			var g := (gate as Node3D).global_position
			var d := Vector2(g.x, g.z).distance_to(Vector2(start.x, start.z))
			if d < best_d and not _near_home(g) and InteriorTownSiege.inside(g):
				best_d = d
				best = gate
		if best == null: continue
		var g := best.global_position
		# Into the yard: away from the street the trail starts in.
		var into := Vector3(g.x - start.x, 0, g.z - start.z)
		into = Vector3(signf(into.x), 0, 0) if absf(into.x) > absf(into.z) else Vector3(0, 0, signf(into.z))
		var kerb := Vector3(g.x, 0, g.z) - into * 1.6
		trail([start, kerb, Vector3(g.x, 0, g.z), Vector3(g.x, 0, g.z) + into * 2.2], .62)

func _process(delta: float) -> void:
	if _torch == null: return
	_torch_time += delta
	# Almost flat batteries: a low orange-ish glow that browns out and comes back.
	var dip := .55 + .45 * clampf(sin(_torch_time * .7) * 1.8, -1, 1)
	if randf() < delta * .4: dip = .15
	_torch.light_energy = lerpf(_torch.light_energy, 1.5 * dip, minf(1.0, delta * 8.0))
