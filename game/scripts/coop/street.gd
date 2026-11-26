extends Node3D
const Shine := preload("res://scripts/pickup_shine.gd")
## 0.41: Store Road, from the barangay gate to Olivar Family Mart (0.42; it was Mabini Mart). A ramp over the old north floodwall drops into a covered
## market lane (shuttered shops, a sagging canopy, hanging bulbs), the lane opens onto Old Salmonan's road (two-storey
## houses behind low walls, a dead jeepney across one lane, poles and wires, sodium lamps that mostly work), an army
## checkpoint the soldiers left, and the store's forecourt with its tables. The store itself: aisles, a wall of
## drink fridges, the counter, a window bar, the soldiers' sandbags and supply crates, a stockroom with a steel
## back door onto a closed-off service alley.
##
## Loose: the forecourt tables (host physics, everyone else follows: `props_state` / `apply_props`). Moving: the road
## gate, the house doors, the stockroom's back door. Everything random (dead lamps, which windows are lit, litter)
## comes from `seed_value`, the same on every peer.
const ORIGIN := Vector3(-86, 1.05, 71.5)
const STORE := Vector3(0, 0, 65)
const CANAL := preload("res://scripts/canal_warren.gd")
const BANK := preload("res://scripts/canal_settlement.gd")
const HorrorLiquid := preload("res://scripts/horror_liquid.gd")
const GOODS := preload("res://scripts/coop/store_goods.gd")
const APPROACH := preload("res://scripts/coop/approach.gd")
const BACK_OFFICE := preload("res://scripts/coop/back_office.gd")
const BACKSTREETS := preload("res://scripts/coop/backstreets.gd")
## 0.44: the steel gate out of the service alley into the backstreets (centre of its opening).
const ALLEY_GATE := Vector3(-2.6, 0, 80)
const GATE := Vector3(0, 0, 1)
## The soldiers' supply crates (rifles at COUNTER+(2.4,1.08,1.1+i*.82), ammunition at COUNTER+(1.6,0,2.8)).
const COUNTER := Vector3(4.3, 0, 62.3)
const BACK_DOOR := Vector3(-6.0, 0, 73.5)
## Where the infected come from at the last stand: up the road, and the service alley behind the store.
const FRONT_SPAWN := [Vector3(-3.2, 0, 40.0), Vector3(3.2, 0, 46.0)]
const BACK_SPAWN := [Vector3(-8.0, 0, 75.4), Vector3(8.0, 0, 79.0)]
const TABLE_SPECS := [["long", Vector3(-4.6, 0, 52.4), .22], ["long", Vector3(4.9, 0, 51.6), -.16],
	["round", Vector3(-2.5, 0, 54.2), 0.0], ["round", Vector3(2.7, 0, 54.5), 0.0], ["square", Vector3(6.6, 0, 54.6), .35]]
var seed_value := 5849
var kits := {}
var mats := {}
var solid := StaticBody3D.new()
var gate: StaticBody3D
## 0.44: the chain and padlock on the night gate (gone once Dodong's keys open it).
var gate_chain: Node3D
## 0.44: the back office's door (swung in by flag "office"), the radio's channel light, the office tube, the
## alley gate and the backstreets.
var office_door: StaticBody3D
var radio_led: MeshInstance3D
var office_light: OmniLight3D
var alley_gate: StaticBody3D
var backstreets: Node3D
var _door_sound: AudioStreamPlayer3D
## 0.41: the forecourt tables: RigidBody3D, simulated by the host, followed everywhere else.
var tables: Array[RigidBody3D] = []
var doors: Array[StaticBody3D] = []
var back_door: StaticBody3D
var back_door_hp := 100.0
var rifles: Array[Node3D] = []
var shotguns: Array[Node3D] = []
var key: Node3D
var bad_light: OmniLight3D
var key_label: Label3D
var key_glow: OmniLight3D
var sparks: CPUParticles3D
var rng := RandomNumberGenerator.new()
## Lamps that flicker: [light, base energy, phase, material or null].
var flickers: Array = []
var authority := true
var _scrape: AudioStreamPlayer3D
var _bang: AudioStreamPlayer3D
## 0.49: the steel roll-down shutter across the whole mart front, which Jonna pulls down and padlocks once she has
## told them what she knows (mission `lockup`). `flags.shutter` 0 (up in its box) .. 1 (down), `flags.locked`.
var shutter: Node3D
var shutter_curtain: MeshInstance3D
var shutter_bar: MeshInstance3D
var shutter_lock: Node3D
var shutter_body: StaticBody3D
var _shutter_sound: AudioStreamPlayer3D
var _shutter_shown := -1.0
const SHUTTER_TOP := 3.06
const SHUTTER_Z := -8.97
var _prop_goal := {}
## 0.42: the store's stock (three meshes), and the phone on the floor that keeps lighting up.
var goods := GOODS.new()
var phone_screen: MeshInstance3D
var phone_glow: OmniLight3D

func material(id: String) -> StandardMaterial3D:
	if mats.has(id): return mats[id]
	var m := StandardMaterial3D.new()
	var tint := Color.WHITE
	var base := id
	if "|" in id:
		base = id.get_slice("|", 0)
		tint = Color(id.get_slice("|", 1))
	if base.begins_with("glow"):
		var parts := base.trim_prefix("glow").split("*")
		m.albedo_color = Color(parts[0])
		m.emission_enabled = true
		m.emission = Color(parts[0])
		m.emission_energy_multiplier = float(parts[1]) if parts.size() > 1 else 1.6
	elif base == "puddle":
		m.albedo_color = Color(.03, .035, .04, .55)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = .04
		m.metallic_specular = .9
	elif base.begins_with("glass"):
		m.albedo_color = Color(base.trim_prefix("glass")) if base.length() > 5 else Color(.5, .66, .66, .22)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = .08
		m.metallic_specular = .8
	elif base.begins_with("#"):
		m.albedo_color = Color(base)
	elif base.begins_with("label_"):
		m.albedo_texture = load("res://assets/coop/" + base + ".png")
	else:
		m.albedo_texture = load("res://assets/outdoor/textures/" + base + "/albedo.jpg")
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * .65
		m.albedo_color = tint
	m.roughness = m.roughness if base == "puddle" or base.begins_with("glass") else .84
	if base in ["asphalt_02", "concrete_pavement", "dirty_concrete", "damaged_concrete_floor"]: m.roughness = .58
	if base == "marble_tiles": m.roughness = .32
	mats[id] = m
	return m

func box(at: Vector3, size: Vector3, id: String, collide := false, basis := Basis.IDENTITY) -> void:
	if not kits.has(id): kits[id] = InteriorBoxKit.new()
	kits[id].box(size, Transform3D(basis, at))
	if collide: shape(solid, at, size, basis)

func can(at: Vector3, radius: float, h: float, id: String, basis := Basis.IDENTITY, sides := 12) -> void:
	if not kits.has(id): kits[id] = InteriorBoxKit.new()
	kits[id].cylinder(radius, h, sides, Transform3D(basis, at))

func shape(body: PhysicsBody3D, at: Vector3, size: Vector3, basis := Basis.IDENTITY) -> CollisionShape3D:
	var c := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	c.shape = b
	c.transform = Transform3D(basis, at)
	body.add_child(c)
	return c

## 0.49: a box only rounds strike (the shot layer): what is drawn of something whose walking box is bigger than it.
var shot_body: StaticBody3D
func shot_box(at: Vector3, size: Vector3, basis := Basis.IDENTITY, surface := "metal") -> void:
	if shot_body == null:
		shot_body = StaticBody3D.new()
		shot_body.name = "Shot boxes"
		shot_body.collision_layer = InteriorModelKit.SHOT_LAYER
		shot_body.collision_mask = 0
		add_child(shot_body)
	var c := shape(shot_body, at, size, basis)
	c.set_meta("surface", surface)

func piece(parent: Node3D, at: Vector3, size: Vector3, id: String) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var obj := MeshInstance3D.new()
	obj.mesh = mesh
	obj.material_override = material(id)
	obj.position = at
	parent.add_child(obj)
	return obj

func rod(parent: Node3D, at: Vector3, radius: float, h: float, id: String, basis := Basis.IDENTITY) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = h
	mesh.radial_segments = 14
	mesh.rings = 1
	var obj := MeshInstance3D.new()
	obj.mesh = mesh
	obj.material_override = material(id)
	obj.transform = Transform3D(basis, at)
	parent.add_child(obj)
	return obj

## Painted signs take the light like a wall (`lit` false); lit boxes and neon draw themselves.
func sign_at(at: Vector3, words: String, height: float, yaw := PI, color := Color.WHITE, lit := true) -> Label3D:
	var label := Label3D.new()
	label.text = words
	label.pixel_size = height / 64
	label.font_size = 64
	label.outline_size = 4 if lit else 0
	label.modulate = color
	label.shaded = not lit
	label.double_sided = false
	label.rotation.y = yaw
	label.position = at
	add_child(label)
	return label

func light(at: Vector3, color: Color, energy: float, reach: float, shadows := false) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.position = at
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = reach
	lamp.omni_attenuation = 1.35
	lamp.shadow_enabled = shadows
	lamp.distance_fade_enabled = true
	lamp.distance_fade_begin = 55.0
	lamp.distance_fade_length = 15.0
	lamp.set_meta("outdoor", true)
	add_child(lamp)
	return lamp

func movable(at: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 2
	b.position = at
	add_child(b)
	return b

func model(path: String, at: Vector3, yaw_deg := 0.0, scale := 1.0, tilt := Vector3.ZERO) -> Node3D:
	return InteriorModelKit.place(self, path, at, yaw_deg, scale, "bottom", tilt)

## 0.41: blood on the ground, the project's own liquid decals (`kind`: pool, pool_big, drag_body_a, drag_a,
## spatter_floor...), painting only the street's own meshes (layer bit 8), never the people walking over it.
func stain(kind: String, at: Vector3, yaw: float, length: float, width: float, alpha := .95, depth := .5) -> void:
	var t: Array = HorrorLiquid.texture_set(kind)
	var generated: bool = not t.is_empty()
	if not generated:
		var root := "res://assets/siege/"
		if not ResourceLoader.exists(root + kind + "_albedo.png"): return
		t = [load(root + kind + "_albedo.png"), load(root + kind + "_normal.png"), load(root + kind + "_orm.png")]
	var d := Decal.new()
	d.size = Vector3(length, depth, width)
	d.texture_albedo = t[0]
	d.texture_normal = t[1]
	d.texture_orm = t[2]
	d.modulate = Color(1, 1, 1, alpha)
	d.cull_mask = 8
	d.normal_fade = .35
	d.upper_fade = .2
	d.lower_fade = .2
	d.distance_fade_enabled = true
	d.distance_fade_begin = 34.0
	d.distance_fade_length = 8.0
	add_child(d)
	d.position = at + Vector3.UP * .08
	d.rotation.y = yaw
	HorrorLiquid.finish(d, generated)

## Blood dragged from `a` to `b`: a pool where it began and overlapping smears.
func drag_trail(a: Vector3, b: Vector3, pool := true) -> void:
	if pool: stain("pool_big", a, rng.randf() * TAU, 1.6, 1.3)
	var d := b - a
	var n := maxi(1, ceili(Vector2(d.x, d.z).length() / 1.3))
	for i in n:
		var at := a.lerp(b, (i + .5) / n) + Vector3(rng.randf_range(-.08, .08), 0, rng.randf_range(-.08, .08))
		stain(["drag_body_a", "drag_body_b", "drag_a"][i % 3], at, atan2(d.x, d.z) - PI * .5 + rng.randf_range(-.15, .15), 1.6, .62)

## A sagging wire from a to b.
func wire(a: Vector3, b: Vector3, sag := .45, id := "#101010", thick := .018) -> void:
	var steps := 6
	var last := a
	for i in range(1, steps + 1):
		var t := float(i) / steps
		var p := a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
		var mid := (last + p) * .5
		var d := p - last
		if d.length() > .01:
			var basis := Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < .98 else Vector3.RIGHT)
			box(mid, Vector3(thick, thick, d.length() + .01), id, false, basis)
		last = p

func _ready() -> void:
	position = ORIGIN
	rng.seed = seed_value
	authority = multiplayer.multiplayer_peer == null or multiplayer.is_server()
	solid.collision_layer = 2
	add_child(solid)
	box(Vector3(0, -.18, 40), Vector3(21, .36, 81), "asphalt_02", true)
	for side in [-1, 1]:
		box(Vector3(side * 10.45, 1.6, 40), Vector3(.22, 3.3, 81), "mossy_brick", true)
		box(Vector3(side * 6.35, 1.7, 1), Vector3(8.5, 3.4, .22), "concrete_block_wall", true)
	# 0.44: the alley's far wall, with the steel gate out to the backstreets (BACKSTREETS, built below).
	box(Vector3(-7.3, 2, 80), Vector3(6.4, 4, .2), "concrete_block_wall", true)
	box(Vector3(4.15, 2, 80), Vector3(12.5, 4, .2), "concrete_block_wall", true)
	box(Vector3(-2.6, 3.4, 80), Vector3(3.0, 1.2, .2), "concrete_block_wall", true)
	alley_gate = movable(ALLEY_GATE)
	shape(alley_gate, Vector3(0, 1.4, -.15), Vector3(3.0, 2.8, .1))
	piece(alley_gate, Vector3(0, 1.4, -.15), Vector3(3.0, 2.8, .04), "rusty_metal_sheet|#5c6b62")
	for i in 7: piece(alley_gate, Vector3(-1.35 + i * .45, 1.4, -.19), Vector3(.05, 2.8, .04), "rusty_metal_04")
	piece(alley_gate, Vector3(-1.3, 1.2, -.22), Vector3(.12, .2, .05), "#8c8c84")
	sign_at(ALLEY_GATE + Vector3(0, 2.25, -.22), "SERVICE GATE  •  KEEP CLOSED", .1, PI, Color(.9, .88, .8), false).reparent(alley_gate)
	backstreets = BACKSTREETS.new()
	add_child(backstreets)
	backstreets.build(self)
	gate = movable(GATE)
	# 0.44: the floodwall, the ramp up its face, the night gate, the soldiers' checkpoint (approach.gd).
	APPROACH.build(self)
	lane()
	road()
	for i in 4: house(i)
	checkpoint()
	forecourt()
	store()
	back_alley()
	front_shutter()
	# (0.65: materials alike but for their colour share one mesh: InteriorColourBatch.)
	InteriorColourBatch.commit_kits(self, kits, material, func(mesh: MeshInstance3D, _id: String) -> void: mesh.layers = 1 | 8)
	kits.clear()
	goods.build(self)
	barricades()
	key = Node3D.new()
	add_child(key)
	key.global_position = CANAL.pos(-6.04, CANAL.FLOOR + 1.13, 20.94)
	var gold := material("#f2b53d")
	gold.emission_enabled = true
	gold.emission = Color(.65, .32, .04)
	piece(key, Vector3.ZERO, Vector3(.17, .035, .035), "#f2b53d")
	piece(key, Vector3(.07, 0, .032), Vector3(.035, .035, .07), "#f2b53d")
	var ring := TorusMesh.new()
	ring.inner_radius = .032
	ring.outer_radius = .056
	var handle := MeshInstance3D.new()
	handle.mesh = ring
	handle.material_override = gold
	handle.position.x = -.1
	key.add_child(handle)
	Shine.apply(key)
	key_label = sign_at(to_local(key.global_position) + Vector3.UP * .23, "Gate Keys", .14, PI / 2, Color.WHEAT)
	key_glow = light(to_local(key.global_position) + Vector3.UP * .12, Color.ORANGE, 1.4, 2)
	_scrape = AudioStreamPlayer3D.new()
	_scrape.stream = preload("res://assets/audio/siege/scrape.ogg")
	_scrape.unit_size = 5.0
	_scrape.max_distance = 30.0
	add_child(_scrape)
	_bang = AudioStreamPlayer3D.new()
	_bang.unit_size = 9.0
	_bang.max_distance = 60.0
	_bang.position = BACK_DOOR + Vector3(0, 1.2, -.4)
	add_child(_bang)
	hum(STORE + Vector3(0, 3.5, 0), "res://assets/audio/nichols/bulb_hum.ogg", -20.0, 9.0)
	hum(STORE + Vector3(0, 1.0, 3.9), "res://assets/audio/nichols/fridge_hum.ogg", -15.0, 7.0)

func hum(at: Vector3, path: String, volume: float, unit: float) -> void:
	var a := AudioStreamPlayer3D.new()
	var stream := load(path) as AudioStream
	if stream is AudioStreamOggVorbis: (stream as AudioStreamOggVorbis).loop = true
	a.stream = stream
	a.volume_db = volume
	a.unit_size = unit
	a.max_distance = unit * 4.0
	a.position = at
	a.autoplay = true
	add_child(a)

# ---------------------------------------------------------------- the market lane (z 1..17)

func lane() -> void:
	# Concrete lane, cracked into slabs, a gutter down each side, a manhole and puddles.
	for z in range(2, 17, 3):
		box(Vector3(0, .012, z + 1.5), Vector3(6.3, .03, 2.96), "dirty_concrete")
	for s in [-1, 1]:
		box(Vector3(s * 2.95, .03, 9), Vector3(.32, .02, 15.8), "#16191a")
		for z in [4.0, 9.5, 14.0]:
			box(Vector3(s * 2.95, .045, z), Vector3(.3, .012, .62), "rusty_metal_02")
	can(Vector3(.8, .03, 11.2), .36, .02, "rusty_metal_03", Basis.IDENTITY, 18)
	for spec in [[-.9, 5.6, 1.4, .9], [1.4, 12.8, 1.1, .7], [-1.6, 15.4, .8, 1.3]]:
		can(Vector3(spec[0], .035, spec[1]), .5, .004, "puddle", Basis(Vector3.UP, rng.randf_range(-.6, .6)).scaled(Vector3(spec[2], 1, spec[3])), 20)
	# Shophouse blocks either side: shutters below, windows and air-conditioners above.
	var left := [["BIGASAN NI ALING NENA", "#8a2b22"], ["KARINDERYA", "#2c5d3b"], ["TAILORING • ALTERATION", "#2a3f6b"]]
	var right := [["LECHON MANOK", "#a9411e"], ["E-LOAD DITO", "#1c6b72"], ["WATER REFILLING STATION", "#245d8a"]]
	for side in [-1, 1]:
		var walls: Array = ["painted_plaster_wall|#d9cfb4", "worn_cracked_plaster|#a8b9a3", "peeling_painted_wall|#c9b7a6"]
		box(Vector3(side * 6.8, 3.4, 9), Vector3(7.2, 6.8, 16), walls[0 if side < 0 else 2], true)
		for bay in 3:
			var z := 3.6 + bay * 5.0
			var face: float = side * 3.2
			var names: Array = left if side < 0 else right
			shopfront(Vector3(face, 0, z), side, names[bay][0], names[bay][1], bay == 1 and side > 0)
			# Upper floor: a window with a grille, a sill, an air-conditioner on a bracket.
			box(Vector3(face - side * .02, 4.6, z), Vector3(.06, 1.25, 1.6), "glass#0c1012" if rng.randf() > .18 else "glow#3d2c18*.35")
			for k in 6: box(Vector3(face - side * .08, 4.6, z - .7 + k * .28), Vector3(.03, 1.3, .03), "#2b2a27")
			for y in [4.0, 5.22]: box(Vector3(face - side * .08, y, z), Vector3(.035, .035, 1.62), "#2b2a27")
			box(Vector3(face - side * .1, 3.95, z), Vector3(.18, .07, 1.8), "rough_concrete")
			if rng.randf() < .7:
				model("street/exterior_aircon_unit", Vector3(face - side * .22, 5.75, z + 1.25), -90.0 * side, .5)
			box(Vector3(face - side * .05, 3.25, z + 2.4), Vector3(.1, 6.5, .1), "#3c3a35")
		# Roof edge and a parapet.
		box(Vector3(side * 3.45, 6.9, 9), Vector3(.5, .25, 16.1), "rough_concrete")
	# A canopy of old roofing over the lane, holed in places, on steel posts and beams.
	for z in [3.0, 7.0, 11.0, 15.0]:
		box(Vector3(0, 4.15, z), Vector3(6.4, .12, .12), "rusty_metal_03", false)
	var sheets := [[3.0, 5.0], [5.9, 8.4], [9.3, 10.6], [12.4, 15.6]]
	for s in sheets:
		var length: float = s[1] - s[0]
		box(Vector3(0, 4.27, (s[0] + s[1]) * .5), Vector3(6.6, .03, length), "rusty_corrugated_iron", false, Basis(Vector3.RIGHT, .03))
	box(Vector3(2.4, 3.2, 10.9), Vector3(1.3, .03, 2.0), "rusty_corrugated_iron", false, Basis(Vector3.RIGHT, -.9) * Basis(Vector3.FORWARD, .3))
	# Bulbs on the beams: warm, one of them going.
	for spec in [[-1.2, 3.0, true], [1.1, 7.0, false], [-.5, 11.0, true], [.9, 15.0, true]]:
		var at := Vector3(spec[0], 3.55, spec[1])
		box(at + Vector3.UP * .3, Vector3(.012, .6, .012), "#111111")
		can(at, .045, .09, "glow#ffcf8a*3.0" if spec[2] else "#3a3a33")
		if spec[2]:
			var lamp := light(at + Vector3.DOWN * .1, Color(1.0, .74, .42), 1.5, 7.5, spec[1] == 11.0)
			if spec[1] == 3.0: flickers.append([lamp, 1.5, 1.7, null])
	wire(Vector3(-3.2, 5.6, 1.5), Vector3(3.2, 5.0, 6.0), .5)
	wire(Vector3(-3.2, 5.9, 6.0), Vector3(3.2, 5.7, 12.5), .6)
	wire(Vector3(-3.2, 5.2, 12.0), Vector3(3.2, 6.0, 16.5), .7)
	wire(Vector3(-3.2, 4.9, 3.5), Vector3(-3.2, 5.6, 16.5), .4)
	# A street-food cart and a tricycle left in the lane: the way through is to one side.
	# (0.49: the boxes keep people out; rounds strike the models themselves.)
	InteriorModelKit.shot_proxy(shape(solid, Vector3(1.75, .95, 8.6), Vector3(1.3, 1.9, 2.25)), model("street/food_cart_a", Vector3(1.75, 0, 8.6), 90.0), "wood")
	InteriorModelKit.shot_proxy(shape(solid, Vector3(-1.85, .8, 13.6), Vector3(1.6, 1.6, 2.4), Basis(Vector3.UP, deg_to_rad(168.0))), model("street/tricycle_b", Vector3(-1.85, 0, 13.6), 168.0))
	for spec in [["nichols/nh_trashbag", -2.7, 2.3], ["nichols/nh_trashbag", -2.5, 2.9], ["nichols/nh_trashbag", 2.7, 16.4],
			["nichols/nh_wooden_crate_02", 2.6, 4.6], ["nichols/nh_cardboard_box_01", 2.4, 5.4], ["street/oil_drum", -2.75, 7.6],
			["nichols/nh_old_tyre", -2.7, 10.2], ["nichols/nh_cardboard_box_01", .3, 5.0], ["nichols/nh_trashbag", -2.2, 16.0]]:
		model(spec[0], Vector3(spec[1], .03, spec[2]), rng.randf_range(0, 360))
	sign_at(Vector3(-3.14, 2.15, 6.9), "BAWAL UMIHI DITO", .13, PI / 2, Color(.62, .1, .08), false)

## A ground-floor shop on a lane block: a roll-up shutter (one half up on a lit stall), the box it rolls into and a
## painted signboard.
func shopfront(at: Vector3, side: int, words: String, colour: String, open := false) -> void:
	var out := -side
	var yaw := PI * .5 * (-1 if side > 0 else 1)
	var shutter_h := 1.15 if open else 2.75
	box(at + Vector3(out * .03, 2.75 - shutter_h * .5 + .08, 0), Vector3(.05, shutter_h, 3.6), "painted_metal_shutter|#9a9c95" if rng.randf() < .5 else "rusty_metal_sheet")
	box(at + Vector3(out * .14, 2.95, 0), Vector3(.3, .32, 3.8), "rusty_metal_02")
	box(at + Vector3(out * .25, 3.42, 0), Vector3(.06, .62, 4.0), colour)
	sign_at(at + Vector3(out * .29, 3.42, 0), words, .25, yaw, Color(.95, .92, .82), false)
	box(at + Vector3(out * .15, .06, 0), Vector3(.5, .12, 3.8), "rough_concrete", true)
	if open:
		# Half up: a strip light still on inside, crates and an overturned stool beyond.
		box(at + Vector3(side * .9, .9, 0), Vector3(1.8, 1.8, 3.4), "#0b0b0a")
		box(at + Vector3(side * .4, .02, 0), Vector3(.8, .02, 3.3), "dirty_concrete")
		light(at + Vector3(side * .7, 1.3, 0), Color(.75, 1.0, .85), .8, 4.0)
		box(at + Vector3(side * 1.4, 2.4, 0), Vector3(.06, .04, 1.2), "glow#d8ffe8*2.5")

# ---------------------------------------------------------------- Old Salmonan's road (z 17..49)

func road() -> void:
	# Concrete road panels with joints and patches, footpaths a step up, gutters and grates.
	for i in 11:
		var z := 17.5 + i * 3.0
		box(Vector3(0, .015, z + 1.5), Vector3(7.0, .03, 2.94), "dirty_concrete" if i % 3 else "damaged_concrete_floor")
	for spec in [[-1.4, 22.6, 1.6, 1.1], [1.9, 34.2, 2.2, .8], [.4, 41.9, 1.2, 1.5], [-2.2, 27.7, .7, .9]]:
		can(Vector3(spec[0], .036, spec[1]), .5, .004, "puddle", Basis(Vector3.UP, rng.randf_range(-.5, .5)).scaled(Vector3(spec[2], 1, spec[3])), 20)
	can(Vector3(-.6, .035, 36.5), .36, .02, "rusty_metal_03", Basis.IDENTITY, 18)
	for s in [-1, 1]:
		box(Vector3(s * 4.1, .025, 33), Vector3(1.4, .05, 32), "concrete_pavement", true)
		box(Vector3(s * 3.43, .04, 33), Vector3(.1, .08, 32), "#8b8a80")
		box(Vector3(s * 3.62, .048, 33), Vector3(.26, .006, 32), "#141617")
		for z in range(19, 49, 6):
			box(Vector3(s * 3.62, .055, z), Vector3(.26, .01, .7), "rusty_metal_02")
	# Lane-to-road corner pillars, where the canopy ends.
	for s in [-1, 1]:
		box(Vector3(s * 3.4, 3.4, 17.2), Vector3(.5, 6.8, .5), "rough_concrete", true)
	# Poles every ten metres down the right side: crossarms, a transformer, wires to the next pole and to the houses.
	var poles := [Vector3(4.55, 0, 18.5), Vector3(4.55, 0, 28.5), Vector3(4.55, 0, 38.5), Vector3(4.55, 0, 48.5)]
	var dead := rng.randi() % 4
	var flicker := (dead + 1 + rng.randi() % 3) % 4
	for i in poles.size():
		var p: Vector3 = poles[i]
		can(p + Vector3.UP * 4.0, .13, 8.0, "rough_concrete", Basis.IDENTITY, 10)
		box(p + Vector3(0, 7.6, 0), Vector3(.12, .12, 1.8), "dark_wooden_planks")
		box(p + Vector3(0, 7.1, 0), Vector3(.1, .1, 1.3), "dark_wooden_planks")
		for k in [-.8, 0.0, .8]: can(p + Vector3(0, 7.72, k), .03, .1, "#c9c4b4")
		if i == 1:
			can(p + Vector3(.32, 6.5, 0), .24, .75, "#6d7069")
			box(p + Vector3(.18, 6.5, 0), Vector3(.2, .12, .12), "#3d3f3b")
		shape(solid, p + Vector3.UP * 2.0, Vector3(.28, 4.0, .28))
		# A sodium lamp on an arm over the road.
		box(p + Vector3(-.9, 6.2, 0), Vector3(1.8, .07, .07), "#3a3c39")
		box(p + Vector3(-1.75, 6.12, 0), Vector3(.5, .12, .24), "#2e302d")
		var on := i != dead
		box(p + Vector3(-1.75, 6.04, 0), Vector3(.4, .03, .18), "glow#ffb35a*4.0" if on else "#4a4434")
		if on:
			var lamp := light(p + Vector3(-1.75, 5.8, 0), Color(1.0, .64, .3), 4.2, 16.0, i % 2 == 0)
			if i == flicker: flickers.append([lamp, 4.2, 2.3, material("glow#ffb35a*4.0")])
		if i < poles.size() - 1:
			for k in [-.8, 0.0, .8]:
				wire(p + Vector3(0, 7.72, k), poles[i + 1] + Vector3(0, 7.72, k), .55)
		# Drops to the houses across the road and this side.
		wire(p + Vector3(0, 7.1, -.5), Vector3(-4.85, 5.3, p.z + 2.5), .8)
		wire(p + Vector3(0, 7.1, .5), Vector3(4.9, 5.5, p.z + 4.0), .4)
		model("street/power_box_01", p + Vector3(.2, 1.4, 0), -90.0)
	wire(Vector3(4.55, 7.72, 18.5), Vector3(3.2, 6.3, 15.5), .3)
	# A dead jeepney across the left lane, doors open, and a tricycle on its side up the road.
	InteriorModelKit.shot_proxy(shape(solid, Vector3(-1.45, 1.2, 30.6), Vector3(2.3, 2.4, 6.6), Basis(Vector3.UP, deg_to_rad(12.0))), model("street/jeepney", Vector3(-1.45, 0, 30.6), 12.0))
	InteriorModelKit.shot_proxy(shape(solid, Vector3(2.0, .55, 42.8), Vector3(1.7, 1.1, 2.3), Basis(Vector3.UP, deg_to_rad(-60.0))), model("street/tricycle_a", Vector3(2.1, .25, 42.8), -60.0, 1.0, Vector3(0, 0, 78)))
	# Laundry left on a line between two houses, slippers, a toppled bin, rubbish where the gutter blocked.
	wire(Vector3(-4.85, 2.7, 28.0), Vector3(-4.85, 2.6, 32.6), .25, "#5c5a52", .01)
	for k in 5:
		var z := 28.6 + k * .85
		box(Vector3(-4.85, 2.28 - .1 * sin(k * 1.3), z), Vector3(.04, .7, .55), ["#7a2e2e", "#c8c2b0", "#2f4f6f", "#5b6b3a", "#b48a3c"][k], false, Basis(Vector3.FORWARD, .05 * k))
	for spec in [["nichols/nh_trashbag", 3.3, 20.2], ["nichols/nh_trashbag", 3.6, 20.6], ["nichols/nh_cardboard_box_01", -.6, 25.0],
			["nichols/nh_trashbag", -3.9, 45.2], ["street/oil_drum", 3.95, 33.0], ["nichols/nh_old_tyre", 3.8, 46.2],
			["nichols/nh_cardboard_box_01", -3.6, 21.5], ["nichols/nh_wooden_crate_02", 3.5, 40.0], ["nichols/nh_trashbag", 3.9, 40.6]]:
		model(spec[0], Vector3(spec[1], .05, spec[2]), rng.randf_range(0, 360))
	for k in 6:
		box(Vector3(rng.randf_range(-3, 3), .045, rng.randf_range(18, 47)), Vector3(.1, .025, .24), ["#7a2e2e", "#d7d2c4", "#2a2a2a"][k % 3], false, Basis(Vector3.UP, rng.randf() * TAU))
	# Blood: a long drag from the jeepney's door to the gutter, and spatter where something was eaten.
	drag_trail(Vector3(-.3, 0, 29.2), Vector3(-2.8, 0, 26.9))
	stain("spatter_floor", Vector3(1.1, 0, 12.1), .7, 1.9, 1.9)
	stain("pool_big", Vector3(1.0, 0, 12.3), 2.0, 1.5, 1.2)
	# The left-side lots: a sari-sari store and a fenced vacant lot; right: a waiting shed, a side alley, a
	# vulcanizing shop.
	sari_sari(Vector3(-7.6, 0, 30.2))
	vacant_lot()
	waiting_shed(Vector3(7.5, 0, 19.6))
	vulcanizing(Vector3(7.6, 0, 45.2))
	# The narrow side alley between houses 1 and 3: dark, a single bulb at its end.
	box(Vector3(7.6, .02, 31.6), Vector3(5.6, .04, 2.9), "damaged_concrete_floor")
	light(Vector3(9.8, 2.6, 31.6), Color(.62, .8, .7), .35, 3.0)
	box(Vector3(10.2, 2.6, 31.6), Vector3(.06, .05, .4), "glow#cfe8db*1.3")
	for k in 4: model("nichols/nh_trashbag", Vector3(9.2 + (k % 2) * .4, .02, 30.9 + k * .35), k * 70.0)
	model("nichols/nh_wooden_crate_02", Vector3(8.4, .02, 32.6), 20.0)

func sari_sari(c: Vector3) -> void:
	box(c + Vector3(-.4, 2.0, 0), Vector3(5.2, 4.0, 4.6), "painted_plaster_wall|#9fc0a8", true)
	box(c + Vector3(2.24, 1.55, 0), Vector3(.06, .9, 2.4), "#141414")
	for k in 9: box(c + Vector3(2.27, 1.55, -1.1 + k * .275), Vector3(.03, .95, .03), "#4b4c45")
	box(c + Vector3(2.4, 1.02, 0), Vector3(.36, .06, 2.6), "dark_wooden_planks")
	box(c + Vector3(2.32, 2.25, 0), Vector3(.3, .06, 2.7), "rusty_corrugated_iron", false, Basis(Vector3.FORWARD, -.3))
	box(c + Vector3(2.21, 2.75, 0), Vector3(.05, .5, 2.9), "#c63a2a")
	sign_at(c + Vector3(2.25, 2.75, 0), "SARI-SARI STORE", .26, PI * .5, Color(1, .95, .8), false)
	sign_at(c + Vector3(2.26, 1.15, .95), "BAWAL ANG UTANG", .07, PI * .5, Color(.15, .12, .1), false)
	# Snack strips still hanging behind the grille.
	for k in 6:
		box(c + Vector3(2.15, 2.04, -.9 + k * .35), Vector3(.01, .04, .14), "#d8d8d0")
		for j in 3:
			put(["lucky_me_canton", "piattos", "nova"][k % 3], c + Vector3(2.15, 1.86 - j * .19, -.9 + k * .35), PI * .5, Basis.from_scale(Vector3.ONE * (1.0 if k % 3 == 0 else .7)))
	box(c + Vector3(-.4, 4.15, 0), Vector3(5.6, .14, 5.0), "rusty_corrugated_iron", false, Basis(Vector3.FORWARD, .06))

func vacant_lot() -> void:
	# z 40.5..49 on the left: a chain-link fence along the footpath, weeds, a dead banana stand, junk.
	for k in 22:
		box(Vector3(-4.85, 1.1, 40.6 + k * .38), Vector3(.025, 2.2, .025), "#55574f", false)
	for y in [.15, 1.1, 2.15]: box(Vector3(-4.85, y, 44.8), Vector3(.04, .04, 8.4), "#55574f", true)
	box(Vector3(-4.85, 1.1, 44.8), Vector3(.02, 2.2, 8.4), "glass#3a3d36aa", true)
	box(Vector3(-7.6, .02, 44.8), Vector3(5.5, .04, 8.4), "withered_grass")
	model("nature/banana_plant", Vector3(-9.7, 0, 41.2), 40.0, .8)
	model("nature/banana_small", Vector3(-5.6, 0, 48.4), 120.0)
	model("nichols/nh_old_bed_frame", Vector3(-5.8, .04, 43.0), 80.0)
	for k in 3: model("nichols/nh_old_tyre", Vector3(-9.6, .04 + k * .17, 48.0), k * 40.0, 1.0, Vector3(90, 0, 0))

func waiting_shed(c: Vector3) -> void:
	for x in [-1.3, 1.3]:
		for z in [-1.0, 1.0]: box(c + Vector3(x, 1.25, z), Vector3(.1, 2.5, .1), "#40623f")
	box(c + Vector3(0, 2.55, 0), Vector3(3.2, .08, 2.6), "corrugated_iron_02", false, Basis(Vector3.FORWARD, -.08))
	box(c + Vector3(0, .45, .7), Vector3(2.6, .06, .42), "#40623f", true)
	box(c + Vector3(0, .8, .95), Vector3(2.6, .5, .05), "#40623f")
	box(c + Vector3(0, 2.2, -1.32), Vector3(2.8, .36, .04), "#e4dcc3")
	sign_at(c + Vector3(0, 2.2, -1.35), "HON. KAP. R. MABINI • SALAMAT PO", .1, PI, Color(.15, .2, .45), false)
	stain("pool", c + Vector3(1.4, 0, -.5), 1.0, 1.0, .9)

func vulcanizing(c: Vector3) -> void:
	box(c + Vector3(.2, 3.0, 0), Vector3(5.6, 6.0, 7.2), "worn_cracked_plaster|#b7b1a2", true)
	var face := c.x - 2.62
	box(Vector3(face, 2.0, c.z - 1.4), Vector3(.05, 1.6, 3.4), "painted_metal_shutter|#7c8c96")
	box(Vector3(face - .05, 1.0, c.z - 1.4), Vector3(.05, .02, 3.4), "#191919")
	box(Vector3(face - .1, 3.35, c.z), Vector3(.06, .7, 6.6), "#d7c33a")
	sign_at(Vector3(face - .14, 3.35, c.z), "VULCANIZING • 24 HRS", .3, -PI * .5, Color(.12, .1, .08), false)
	for k in 5: model("nichols/nh_old_tyre", Vector3(face - .45, .05 + k * .17, c.z + 2.3), rng.randf_range(0, 360), 1.0, Vector3(90, 0, 0))
	model("nichols/nh_old_tyre", Vector3(face - .4, .02, c.z + 1.4), 0.0, 1.0, Vector3(0, 0, 90))
	model("nichols/nh_propane_tank", Vector3(face - .4, .02, c.z + .4), 0.0)
	box(Vector3(face - .02, 4.6, c.z + 1.5), Vector3(.06, 1.1, 1.4), "glass#0c1012")

# ---------------------------------------------------------------- the four houses (doors, sleepers)

func house(i: int) -> void:
	var side := -1 if i % 2 == 0 else 1
	var c := Vector3(side * 7.6, 0, [24.0, 25.6, 36.6, 37.7][i])
	var palette: Array = ["painted_plaster_wall|#e2c9a6", "painted_plaster_wall|#b9d0c8", "peeling_painted_wall|#d8b6b4", "worn_cracked_plaster|#cfd2b0"]
	var wall: String = palette[i]
	var front := c.x - side * 2.8
	box(c + Vector3(0, 1.55, 3.5), Vector3(5.6, 3.1, .18), wall, true)
	box(c + Vector3(0, 1.55, -3.5), Vector3(5.6, 3.1, .18), wall, true)
	box(c + Vector3(side * 2.75, 1.55, 0), Vector3(.15, 3.1, 7), wall, true)
	for z in [-2.12, 2.12]: box(Vector3(front, 1.55, c.z + z), Vector3(.16, 3.1, 2.76), wall, true)
	box(Vector3(front, 2.73, c.z), Vector3(.16, .74, 1.5), wall, true)
	# An upper storey of planks on a slab, a window on the road, a rusted roof.
	box(c + Vector3(0, 3.17, 0), Vector3(5.8, .14, 7.2), "rough_concrete", true)
	box(c + Vector3(0, 4.55, 0), Vector3(5.5, 2.6, 6.9), "weathered_plank_siding" if i % 2 == 0 else "blue_painted_planks", true)
	box(c + Vector3(0, 6.05, 0), Vector3(6.4, .12, 7.8), "rusty_corrugated_iron", true, Basis(Vector3.BACK, side * .1))
	var lit := rng.randf() < .3
	box(Vector3(front - side * .03, 4.5, c.z - 1.3), Vector3(.05, 1.0, 1.3), "glow#3d2c18*.35" if lit else "glass#0d1112")
	for k in 5: box(Vector3(front - side * .07, 4.5, c.z - 1.85 + k * .275), Vector3(.03, 1.04, .03), "#2c2b28")
	box(Vector3(front - side * .03, 4.5, c.z + 1.6), Vector3(.05, 1.0, 1.0), "glass#0d1112")
	# A window on the ground floor too, with a grille and a curtain half drawn.
	box(Vector3(front - side * .02, 1.55, c.z + 2.2), Vector3(.05, .9, .9), "glass#0d1112")
	for k in 4: box(Vector3(front - side * .07, 1.55, c.z + 1.84 + k * .24), Vector3(.03, .95, .03), "#2c2b28")
	box(Vector3(front + side * .05, 1.6, c.z + 2.0), Vector3(.02, .8, .45), "fabric_pattern_07")
	# Front wall to the footpath with a gap for the door, a gate leaf swung in.
	var fence := c.x - side * 3.35
	for z in [-2.5, 2.2]:
		box(Vector3(fence, .6, c.z + z), Vector3(.18, 1.2, 2.0 if z == -2.5 else 2.6), "concrete_block_wall", true)
	box(Vector3(fence - side * .1, 1.25, c.z + .5), Vector3(.05, .1, 1.0), "rusty_metal")
	box(Vector3(front - side * .3, .02, c.z), Vector3(.6, .04, 7.0), "concrete_pavement")
	sign_at(Vector3(fence - side * .1, .85, c.z - 2.5), str(17 + i), .2, -side * PI / 2, Color(.1, .1, .1), false)
	if i == 1: model("street/security_light", Vector3(front - side * .12, 2.6, c.z - .95), 90.0 * side)
	# Inside: a bed, a cabinet, the furniture they left, a floor.
	box(c + Vector3(0, .02, 0), Vector3(5.4, .04, 6.8), "old_wood_floor" if i % 2 else "worn_planks")
	var furniture: String = ["nh_rockingchair_01", "nh_barrel_stove", "nh_sofa_01", "nh_metal_tool_chest"][i]
	model("nichols/" + furniture, c + Vector3(side * 1.2, .05, -1.5), side * 72)
	model("nichols/nh_cardboard_box_01", c + Vector3(-side * 1.4, .05, 2.7), i * 23)
	var door := movable(Vector3(front, 0, c.z - .74))
	shape(door, Vector3(0, 1.16, .74), Vector3(.08, 2.32, 1.48))
	piece(door, Vector3(0, 1.16, .74), Vector3(.08, 2.32, 1.48), "wood_peeling_paint_weathered")
	piece(door, Vector3(-side * .09, 1.05, 1.29), Vector3(.13, .07, .12), "#a78951")
	doors.append(door)
	box(c + Vector3(side * 1.6, .26, 1.5), Vector3(1.1, .48, 2.1), "dark_wooden_planks", true)
	box(c + Vector3(side * 1.6, .55, 1.5), Vector3(1.08, .18, 2.05), "fabric_pattern_07")
	box(c + Vector3(-.4, .65, -2.6), Vector3(2.2, 1.3, .8), "wood_cabinet_worn_long", true)
	box(c + Vector3(0, 3.02, 0), Vector3(5.4, .04, 6.8), "ceiling_interior")
	# One dim bulb inside, so a door left open throws a little light on the road.
	if rng.randf() < .5:
		light(c + Vector3(0, 2.7, .5), Color(1.0, .8, .55), .5, 5.0)
		can(c + Vector3(0, 2.9, .5), .04, .08, "glow#ffd9a0*2.0")

# ---------------------------------------------------------------- the soldiers' checkpoint (z 46..50)

func checkpoint() -> void:
	# Sandbag walls across the road with a gap in the middle, cones, a barrier, and their truck.
	for row in [[-3.3, -.9], [1.5, 3.3]]:
		var x0: float = row[0]
		var x1: float = row[1]
		var n := int((x1 - x0) / .52)
		for layer in 3:
			for k in n:
				var x := x0 + .26 + k * .52 + (.13 if layer % 2 else 0.0)
				if x > x1 - .2: continue
				box(Vector3(x, .14 + layer * .24, 48.6), Vector3(.5, .23, .36), "#7b7055" if (k + layer) % 3 else "#6f6650", false, Basis(Vector3.UP, rng.randf_range(-.08, .08)))
		box(Vector3((x0 + x1) * .5, .37, 48.6), Vector3(x1 - x0, .74, .4), "#000000", true)
	kits.erase("#000000")
	for x in [-.5, 1.1]:
		can(Vector3(x, .3, 47.3), .12, .6, "#d4572a", Basis.IDENTITY, 8)
		can(Vector3(x, .5, 47.3), .123, .07, "#e8e2d6", Basis.IDENTITY, 8)
	# A sawhorse barrier pushed aside.
	var bar := Basis(Vector3.UP, .5)
	box(Vector3(-2.2, .95, 46.8), Vector3(2.0, .22, .05), "#d8d4c7", false, bar)
	for k in 4: box(Vector3(-2.2, .95, 46.8) + bar * Vector3(-.75 + k * .5, 0, -.03), Vector3(.22, .22, .01), "#b52d22", false, bar)
	for x in [-.9, .9]: box(Vector3(-2.2, .45, 46.8) + bar * Vector3(x, 0, 0), Vector3(.06, .9, .5), "#55534c", false, bar)
	sign_at(Vector3(-2.2, 1.35, 46.75), "CHECKPOINT", .2, PI + .5, Color(.9, .88, .8), false)
	# Brass all over the ground behind the bags, a helmet, an ammo can, a radio still hissing.
	for k in 60:
		var at := Vector3(rng.randf_range(-3.4, 3.4), .052, rng.randf_range(48.9, 50.6))
		can(at, .006, .045, "#b38b3a", Basis(Vector3.FORWARD, PI * .5) * Basis(Vector3.UP, rng.randf() * TAU), 5)
	can(Vector3(-1.9, .1, 49.5), .14, .14, "#3c4530", Basis.IDENTITY, 12)
	box(Vector3(2.2, .9, 48.75), Vector3(.3, .2, .22), "#353a2a")
	box(Vector3(2.3, 1.1, 48.75), Vector3(.012, .32, .012), "#111111")
	var radio := AudioStreamPlayer3D.new()
	radio.stream = preload("res://assets/audio/nichols/arc_buzz.ogg")
	if radio.stream is AudioStreamOggVorbis: (radio.stream as AudioStreamOggVorbis).loop = true
	radio.volume_db = -22.0
	radio.pitch_scale = .55
	radio.unit_size = 2.0
	radio.max_distance = 12.0
	radio.position = Vector3(2.2, .95, 48.75)
	radio.autoplay = true
	add_child(radio)
	# Their truck, nosed into the vacant lot's fence: cab, flatbed under canvas, six wheels.
	var t := Transform3D(Basis(Vector3.UP, deg_to_rad(-8.0)), Vector3(-7.5, 0, 45.0))
	var olive := "#454c33"
	box(t * Vector3(0, 1.45, -2.85), Vector3(2.2, 1.5, 1.7), olive, false, t.basis)
	box(t * Vector3(0, 1.7, -3.72), Vector3(1.9, .7, .05), "glass#1a2020cc", false, t.basis)
	box(t * Vector3(0, .95, -3.72), Vector3(2.2, .55, .12), "#2a2d22", false, t.basis)
	box(t * Vector3(0, .95, 1.0), Vector3(2.3, .25, 5.6), "#2f3325", false, t.basis)
	box(t * Vector3(0, 1.85, 1.15), Vector3(2.35, 1.6, 4.9), "#5a5a3e", false, t.basis)
	box(t * Vector3(0, 1.85, 3.62), Vector3(2.35, 1.6, .06), "#1f2118", false, t.basis)
	for z in [-2.8, .6, 2.4]:
		for x in [-1.05, 1.05]:
			can(t * Vector3(x, .48, z), .48, .32, "#1a1a1a", t.basis * Basis(Vector3.FORWARD, PI * .5), 14)
	InteriorModelKit.shot_proxy(shape(solid, t * Vector3(0, 1.3, -.2), Vector3(2.35, 2.6, 7.3), t.basis), null)
	# What rounds strike of it: cab, bed, canvas, the wheels (0.49).
	shot_box(t * Vector3(0, 1.45, -2.85), Vector3(2.2, 1.5, 1.7), t.basis)
	shot_box(t * Vector3(0, .95, -3.72), Vector3(2.2, .55, .12), t.basis)
	shot_box(t * Vector3(0, .95, 1.0), Vector3(2.3, .25, 5.6), t.basis)
	shot_box(t * Vector3(0, 1.85, 1.15), Vector3(2.35, 1.6, 4.9), t.basis, "fabric")
	for z in [-2.8, .6, 2.4]:
		for x in [-1.05, 1.05]:
			shot_box(t * Vector3(x, .48, z), Vector3(.32, .96, .96), t.basis, "rubber")
	stain("pool_big", Vector3(.5, 0, 49.8), .4, 1.8, 1.5)
	drag_trail(Vector3(.4, 0, 50.4), Vector3(-.5, 0, 55.0), false)

# ---------------------------------------------------------------- the forecourt (z 50..56.5)

func forecourt() -> void:
	box(Vector3(0, .025, 53.3), Vector3(17.0, .05, 6.4), "concrete_pavement", true)
	for x in [-6.0, -3.0, 3.0, 6.0]:
		box(Vector3(x, .056, 52.6), Vector3(.08, .01, 4.4), "#c9c6b8")
	# Bollards along the glass, the entrance between them left open.
	for x in [-7.8, -6.3, -4.8, -3.3, 3.3, 4.8, 6.3, 7.8]:
		can(Vector3(x, .4, 55.9), .085, .8, "#d1aa2e", Basis.IDENTITY, 10)
		shape(solid, Vector3(x, .4, 55.9), Vector3(.17, .8, .17))
	# The pylon: OLIVAR FAMILY MART, open all hours, one panel failing.
	var p := Vector3(8.0, 0, 50.6)
	box(p + Vector3.UP * 2.5, Vector3(.3, 5.0, .3), "#3c4a48", true)
	box(p + Vector3(0, 5.3, 0), Vector3(1.9, 1.15, .4), "#4a1010")
	box(p + Vector3(0, 5.3, -.21), Vector3(1.7, .95, .02), "glow#9a2020*1.4")
	sign_at(p + Vector3(0, 5.5, -.24), "OLIVAR", .32)
	sign_at(p + Vector3(0, 5.1, -.24), "FAMILY MART", .2, PI, Color(1, .9, .55))
	box(p + Vector3(0, 4.45, -.21), Vector3(1.7, .38, .02), "glow#c9a646*1.6")
	var open_sign := sign_at(p + Vector3(0, 4.45, -.24), "BUKAS 24 ORAS", .19, PI, Color(.15, .1, .02), false)
	open_sign.modulate = Color(.12, .08, .02)
	var pylon_lamp := light(p + Vector3(0, 5.0, -1.0), Color(1.0, .45, .4), 1.1, 6.0)
	flickers.append([pylon_lamp, 1.1, 3.1, material("glow#9a2020*1.4")])
	# The ice chest, a gas-cylinder cage, stacked monobloc chairs, a bin.
	box(Vector3(-6.9, .45, 55.55), Vector3(1.5, .9, .7), "#e6e8e4", true)
	box(Vector3(-6.9, .91, 55.55), Vector3(1.52, .03, .72), "#2f6c9a")
	sign_at(Vector3(-6.9, .55, 55.19), "ICE  •  YELO", .16, PI, Color(.15, .35, .7), false)
	box(Vector3(7.3, .7, 55.4), Vector3(1.2, 1.4, .6), "#202020", true)
	for k in 7: box(Vector3(6.75 + k * .18, .7, 55.1), Vector3(.025, 1.4, .025), "#7b7d77")
	for k in 3: model("nichols/nh_propane_tank", Vector3(6.95 + k * .34, .05, 55.45), k * 40.0)
	for k in 4: model("street/plastic_monobloc_chair_01", Vector3(-8.0, .05 + k * .13, 54.4), 90.0)
	model("street/plastic_monobloc_chair_01", Vector3(-1.0, .05, 51.2), 200.0, 1.0, Vector3(0, 0, 88))
	model("street/plastic_monobloc_chair_01", Vector3(3.6, .05, 53.2), 33.0)
	model("street/plastic_monobloc_chair_01", Vector3(-5.6, .05, 53.6), 150.0)
	can(Vector3(4.15, .45, 55.6), .25, .9, "#33553c", Basis.IDENTITY, 12)
	# Side fences between the store and the boundary walls: the service alley behind is shut off.
	for s in [-1, 1]:
		var x: float = s * 9.47
		for k in 11: box(Vector3(x - 1.0 + k * .195, 1.2, 56.6), Vector3(.03, 2.4, .03), "#5d5f58")
		for y in [.1, 1.2, 2.35]: box(Vector3(x, y, 56.6), Vector3(1.95, .045, .045), "#5d5f58")
		box(Vector3(x, 1.2, 56.6), Vector3(1.95, 2.4, .04), "glass#3a3d36aa", true)
		for k in 9: box(Vector3(x - .9 + k * .23, 2.55, 56.6), Vector3(.1, .1, .1), "#3c3c38", false, Basis(Vector3.FORWARD, .78))

# ---------------------------------------------------------------- Olivar Family Mart

## 0.42: what the shelves held, by aisle (scripts/coop/store_goods.gd, tools/store_goods.py).
const PANTRY := ["century_tuna", "argentina_corned_beef", "555_sardines", "ligo_sardines", "libbys_vienna", "del_monte_fruit",
	"campbells_tomato", "spam", "cup_noodles", "cup_noodles_seafood", "lucky_me_canton"]
const SNACKS := ["lays_classic", "doritos_nacho", "cheetos", "piattos", "nova", "oishi_prawn", "ruffles", "pringles_original",
	"pringles_sour_cream", "pringles_cheese", "oreo", "skyflakes", "mms_peanut"]
const HOUSEHOLD := ["tide_powder", "colgate", "safeguard", "corn_flakes", "milo_tin", "nescafe_3in1", "oreo", "skyflakes"]
const CANS := ["coke_can", "coke_zero_can", "pepsi_can", "sprite_can", "mtn_dew_can", "sevenup_can", "royal_can", "redbull_can",
	"monster_can", "sanmig_can", "redhorse_can", "heineken_can"]
const BOTTLES := ["coke_bottle", "sprite_bottle", "pepsi_bottle", "gatorade_bottle", "pocari_bottle", "c2_bottle", "wilkins_bottle",
	"minute_maid_bottle", "cobra_bottle"]
## 0.42: the dead inside: [where, which of mission.INFECTED, yaw, the clip they fell from, how far into it, push].
## Faces -Z at yaw 0. Each lies where the fight left it, with a reason: the cashier and a customer at the till, the
## soldier who held the sandbags, people cut down running for the back, one of the infected the soldiers dropped.
const STORE_DEAD := [
	[Vector3(4.95, 0, 59.6), 5, PI * .5, "devour", .55, Vector3(260, 0, 0)],
	[Vector3(3.0, 0, 60.5), 3, -PI * .5, "death_fwd", .3, Vector3(420, 60, 0)],
	[Vector3(.3, 0, 59.7), 2, 0.0, "death_back", .95, Vector3(0, 0, 120)],
	[Vector3(.5, 0, 66.0), 6, PI, "death_fwd", .95, Vector3.ZERO],
	[Vector3(2.3, 0, 67.6), 4, 0.0, "death_back", .9, Vector3(0, 0, 80)],
	[Vector3(-6.85, 0, 65.2), 0, PI * .5, "death_fwd", .3, Vector3(-420, 40, 0)],
	[Vector3(-4.9, 0, 57.9), 1, PI, "death_crumple", .9, Vector3.ZERO],
	[Vector3(5.7, 0, 68.35), 4, PI, "death_fwd", .9, Vector3(0, 0, 60)],
	[Vector3(-1.4, 0, 57.4), 0, PI, "death_back", .95, Vector3(0, 0, -100)],
	[Vector3(3.0, 0, 57.95), 6, -PI * .3, "death_crumple", .9, Vector3.ZERO]]
const HOLE := preload("res://assets/coop/goods/hole.png")
const CRACK := preload("res://assets/coop/goods/crack.png")

## One product standing at `at`, its label turned `yaw` from +Z.
func put(item: String, at: Vector3, yaw: float, tilt := Basis.IDENTITY) -> void:
	goods.add(item, Transform3D(Basis(Vector3.UP, yaw) * tilt, at))

## A product knocked to the floor: on its side, flat on its back or face, now and then upright; cans stepped flat.
func drop(item: String, at: Vector3) -> void:
	var e := GOODS.extent(item)
	var shape: String = GOODS.catalogue().goods[item].shape
	var yaw := rng.randf() * TAU
	var r := rng.randf()
	var turn := Basis(Vector3.UP, yaw)
	if shape in ["can", "tube", "bottle", "cup"]:
		if shape == "can" and r < .22:
			goods.add(item, Transform3D(turn * Basis(Vector3.FORWARD, rng.randf_range(-.25, .25)) * Basis.from_scale(Vector3(1.3, rng.randf_range(.25, .45), 1.15)), at))
		elif r < .88:
			goods.add(item, Transform3D(turn * Basis(Vector3.FORWARD, PI * .5) * Basis(Vector3.UP, rng.randf() * TAU), at + Vector3.UP * e.x * .5))
		else:
			put(item, at, yaw)
	elif r < .8:
		goods.add(item, Transform3D(turn * Basis(Vector3.RIGHT, -PI * .5 if r < .5 else PI * .5), at + Vector3.UP * e.z * .5))
	else:
		goods.add(item, Transform3D(turn * Basis(Vector3.FORWARD, PI * .5), at + Vector3.UP * e.x * .5))

## Somewhere on the shop floor that is not inside a fixture.
func floor_clear(at: Vector3) -> bool:
	var p := at - STORE
	for r: Rect2 in [Rect2(-5.92, -4.85, 1.24, 6.8), Rect2(-2.32, -4.85, 1.24, 6.8), Rect2(.95, -1.6, 1.9, 3.8),
			Rect2(3.4, -7.4, 1.0, 3.7), Rect2(5.4, -7.2, .5, 2.6), Rect2(-8.3, -2.6, 1.1, 5.6), Rect2(-8.45, -5.9, .6, 3.4),
			Rect2(5.9, -2.8, 1.4, 4.7), Rect2(-1.6, -6.7, 3.2, .7), Rect2(-1.6, -6.4, .45, 1.6), Rect2(1.15, -6.4, .45, 1.6),
			Rect2(-1.9, 3.45, 5.4, 1.1)]:
		if r.grow(.04).has_point(Vector2(p.x, p.z)): return false
	return absf(p.x) < 8.2 and p.z > -8.2 and p.z < 4.3

func scatter(items: Array, centre: Vector3, spread: Vector2, n: int) -> void:
	for k in n:
		for attempt in 6:
			var at := centre + Vector3(rng.randf_range(-spread.x, spread.x), .005, rng.randf_range(-spread.y, spread.y))
			if floor_clear(at):
				drop(items[rng.randi() % items.size()], at)
				break

## A mark on a wall or a fixture (`normal` out of the surface): blood smears, bullet holes.
func wall_mark(kind: String, at: Vector3, normal: Vector3, length: float, width: float, alpha := .92) -> void:
	var d := Decal.new()
	var generated := false
	if kind == "hole":
		d.texture_albedo = HOLE
		d.modulate = Color(1, 1, 1, alpha)
	else:
		var t: Array = HorrorLiquid.texture_set(kind)
		generated = not t.is_empty()
		if not generated:
			var root := "res://assets/siege/"
			if not ResourceLoader.exists(root + kind + "_albedo.png"):
				d.free()
				return
			t = [load(root + kind + "_albedo.png"), load(root + kind + "_normal.png"), load(root + kind + "_orm.png")]
		d.texture_albedo = t[0]
		d.texture_normal = t[1]
		d.texture_orm = t[2]
		d.modulate = Color(1, 1, 1, alpha)
	d.size = Vector3(length, .3, width)
	d.cull_mask = 8
	d.normal_fade = .4
	d.distance_fade_enabled = true
	d.distance_fade_begin = 30.0
	d.distance_fade_length = 8.0
	add_child(d)
	var up := normal.normalized()
	var side := up.cross(Vector3.UP if absf(up.y) < .95 else Vector3.RIGHT).normalized()
	d.transform = Transform3D(Basis(up, rng.randf_range(-.4, .4)) * Basis(side, up, side.cross(up)), at)
	if kind != "hole": HorrorLiquid.finish(d, generated)

## A star of cracks in a pane (decals do not take on glass): a card just off it.
func crack(at: Vector3, yaw: float, size: float) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.albedo_texture = CRACK
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = .1
	var card := MeshInstance3D.new()
	card.mesh = quad
	card.material_override = m
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	card.position = at
	card.rotation = Vector3(0, yaw, rng.randf() * TAU)
	add_child(card)

## A red shopping basket: an open tray of thin walls, two handles, base at the transform's origin.
func basket(xf: Transform3D) -> void:
	var b := xf.basis
	box(xf * Vector3(0, .01, 0), Vector3(.42, .02, .29), "#b92b23", false, b)
	for s in [-1, 1]:
		box(xf * Vector3(s * .21, .11, 0), Vector3(.015, .2, .3), "#b92b23", false, b)
		box(xf * Vector3(0, .11, s * .145), Vector3(.43, .2, .015), "#b92b23", false, b)
		box(xf * Vector3(s * .09, .22, 0), Vector3(.02, .02, .3), "#262626", false, b)

func store() -> void:
	var S := STORE
	box(S + Vector3(0, .02, 0), Vector3(17, .06, 17), "marble_tiles", true)
	for s in [-1, 1]:
		box(S + Vector3(s * 8.5, 2, 0), Vector3(.2, 4, 17), "white_plaster_02|#d9d7cb", true)
		box(S + Vector3(s * 8.38, 3.05, -.5), Vector3(.04, .5, 15.8), "#7d1d1d")
		box(S + Vector3(s * 8.37, 2.78, -.5), Vector3(.04, .05, 15.8), "#e3b23c")
		box(S + Vector3(s * 8.38, .08, -.5), Vector3(.04, .16, 15.8), "#2b3533")
		for k in 4:
			var at := S + Vector3(s * 8.36, 3.05, -6.2 + k * 3.2)
			box(at, Vector3(.03, .44, 1.9), ["#d6492f", "#2f74b5", "#e7a92b", "#3c9a5f"][(k + (1 if s > 0 else 0)) % 4])
			sign_at(at + Vector3(-s * .03, 0, 0), ["CANNED GOODS", "BEVERAGES", "SNACKS", "HOUSEHOLD"][(k + (2 if s > 0 else 0)) % 4], .16, -s * PI * .5, Color.WHITE, false)
	# The back wall, with a door-sized gap for the stockroom's steel door.
	box(S + Vector3(-7.6, 2, 8.5), Vector3(1.8, 4, .2), "concrete_block_wall", true)
	box(S + Vector3(1.6, 2, 8.5), Vector3(13.8, 4, .2), "concrete_block_wall", true)
	box(S + Vector3(-6.0, 3.15, 8.5), Vector3(1.4, 1.7, .2), "concrete_block_wall", true)
	box(S + Vector3(0, 4.12, 0), Vector3(17.4, .24, 17.4), "ceiling_interior", true)
	# Shopfront: a red plinth, glass panels with frames, posters and a half-pulled shutter; the sliding doors stuck.
	for s in [-1, 1]:
		box(S + Vector3(s * 5.35, .36, -8.5), Vector3(6.3, .72, .18), "#6e2020", true)
		box(S + Vector3(s * 5.35, 2.0, -8.5), Vector3(6.3, 2.56, .08), "glass", true)
		box(S + Vector3(s * 5.35, 3.35, -8.5), Vector3(6.3, .14, .16), "#a3aca1")
		for j in 4: box(S + Vector3(s * (2.35 + j * 1.45), 1.96, -8.6), Vector3(.08, 3.35, .065), "#a3aca1")
	box(S + Vector3(5.35, 2.65, -8.66), Vector3(6.3, 1.3, .04), "painted_metal_shutter|#a7aaa3")
	box(S + Vector3(5.35, 3.35, -8.72), Vector3(6.4, .26, .3), "rusty_metal_02")
	for i in 3:
		goods.panel(["lays_classic", "nescafe_3in1", "corn_flakes"][i], Transform3D(Basis(Vector3.UP, PI), S + Vector3(-3.6 - i * 1.53, 1.33, -8.56)), Vector3(.56, .78, .012))
	box(S + Vector3(4.1, 1.45, -8.56), Vector3(.62, .45, .018), "#e8e1c6")
	sign_at(S + Vector3(4.1, 1.5, -8.58), "WALANG\nBENTA NG\nSIGARILYO\nSA MENOR", .045, PI, Color(.4, .08, .05), false)
	# Doors: the left leaf slid open behind the glass, the right one burst (its frame and what is left of the pane).
	box(S + Vector3(-2.6, 1.55, -8.42), Vector3(1.1, 2.9, .04), "glass")
	box(S + Vector3(-2.6, 3.0, -8.42), Vector3(1.15, .06, .06), "#8f9890")
	for x in [2.05, 3.15]: box(S + Vector3(x, 1.55, -8.42), Vector3(.06, 2.9, .06), "#8f9890")
	box(S + Vector3(2.6, 3.0, -8.42), Vector3(1.15, .06, .06), "#8f9890")
	box(S + Vector3(2.6, .08, -8.42), Vector3(1.15, .06, .06), "#8f9890")
	box(S + Vector3(2.4, 2.55, -8.42), Vector3(.7, .8, .02), "glass", false, Basis(Vector3.FORWARD, .2))
	box(S + Vector3(0, 3.2, -8.5), Vector3(4.6, .2, .3), "#353b38")
	for k in 110:
		var at := S + Vector3(rng.randf_range(-1.6, 2.4), .055, rng.randf_range(-9.8, -5.6))
		box(at, Vector3(rng.randf_range(.03, .14), .005, rng.randf_range(.03, .12)), "glass#c8e0dccc", false, Basis(Vector3.UP, rng.randf() * TAU))
	# Rounds the soldiers put out through their own windows: cracked panes, holes in the frames and the plinth.
	for spec in [[-5.8, 1.6, .9], [-4.4, 2.3, .6], [-1.4, 1.2, .5], [4.9, 1.1, .8], [6.7, 1.9, .55], [-7.2, 1.0, .45], [3.6, 2.4, .5]]:
		crack(S + Vector3(spec[0], spec[1], -8.45), 0.0, spec[2])
	for k in 14:
		wall_mark("hole", S + Vector3(rng.randf_range(-8.2, 8.2), rng.randf_range(.15, .65), -8.4), Vector3.BACK, .07, .07)
	# Fascia: a lit band, the name and the promise under it, a canopy with tubes beneath.
	box(S + Vector3(0, 3.8, -8.75), Vector3(17.2, .95, .6), "#7a1717", true)
	box(S + Vector3(0, 3.33, -9.06), Vector3(17.3, .08, .04), "glow#e8b84a*1.3")
	box(S + Vector3(0, 4.27, -9.06), Vector3(17.3, .05, .04), "glow#e8b84a*1.3")
	sign_at(S + Vector3(0, 4.0, -9.08), "OLIVAR FAMILY MART", .4)
	box(S + Vector3(0, 3.36, -9.6), Vector3(17.3, .1, 1.3), "painted_metal_shutter|#cfd3cc")
	# The valance along the canopy's edge carries the promise.
	box(S + Vector3(0, 3.2, -10.26), Vector3(17.3, .32, .04), "#7a1717")
	box(S + Vector3(0, 3.05, -10.29), Vector3(17.3, .02, .02), "glow#e8b84a*1.1")
	sign_at(S + Vector3(0, 3.2, -10.3), "Pang-pamilya ang presyo, Garantisado!", .16, PI, Color(1, .88, .5))
	for x in [-6.0, 0.0, 6.0]:
		var lamp := light(S + Vector3(x, 3.1, -9.6), Color(.72, .9, .85), 1.5, 7.2)
		box(S + Vector3(x, 3.28, -9.6), Vector3(1.2, .04, .12), "glow#eef4e6*2.4" if x != -6.0 else "#4b4c48")
		if x == -6.0: lamp.light_energy = 0.0
		if x == 6.0: flickers.append([lamp, 1.5, 5.3, null])
	# Back rooms behind a partition at z 69.5: stockroom on the left, staff room on the right (its door left open).
	var pz := S.z + 4.5
	box(Vector3(-6.2, 2, pz), Vector3(4.6, 4, .14), "white_plaster_02|#d8d6cb", true)
	box(Vector3(-2.975, 3.25, pz), Vector3(1.85, 1.5, .14), "white_plaster_02|#d8d6cb", true)
	box(Vector3(.9, 2, pz), Vector3(5.9, 4, .14), "white_plaster_02|#d8d6cb", true)
	box(Vector3(6.7, 2, pz), Vector3(3.6, 4, .14), "white_plaster_02|#d8d6cb", true)
	box(Vector3(4.375, 3.25, pz), Vector3(1.05, 1.5, .14), "white_plaster_02|#d8d6cb", true)
	sign_at(Vector3(4.4, 2.75, pz - .08), "STAFF ONLY", .1, PI, Color(.75, .15, .1), false)
	box(Vector3(-2.975, 2.48, pz - .09), Vector3(1.85, .04, .03), "#8a8f88")
	box(Vector3(-2.975, 2.75, pz - .1), Vector3(.5, .17, .05), "glow#1fbf5a*1.8")
	sign_at(Vector3(-2.975, 2.75, pz - .13), "EXIT", .1, PI, Color(.9, 1, .9))
	light(Vector3(-2.975, 2.6, pz - .4), Color(.3, 1.0, .5), .35, 2.6)
	box(Vector3(1.0, 2, pz + 2.0), Vector3(.14, 4, 3.9), "white_plaster_02|#d8d6cb", true)
	wall_mark("smear_wall", Vector3(3.5, 1.0, pz - .07), Vector3.FORWARD, .7, 1.1)
	stockroom()
	# The wall of drink fridges on the partition: lit doors, a header, the real stock; one hanging open and
	# emptied onto the floor, one with a round through its glass.
	var fridge_rows := [[["coke_can", "coke_zero_can"], ["sprite_can", "coke_can"], ["coke_bottle"], ["sprite_bottle"]],
		[["pepsi_can", "sevenup_can"], ["mtn_dew_can", "royal_can"], ["pepsi_bottle"], ["wilkins_bottle", "pocari_bottle"]],
		[["gatorade_bottle", "c2_bottle"], ["minute_maid_bottle", "cobra_bottle"], ["redbull_can"], ["monster_can"]],
		[["sanmig_can"], ["redhorse_can"], ["heineken_can", "sanmig_can"], ["redhorse_can", "heineken_can"]]]
	for i in 4:
		var c := Vector3(-1.2 + i * 1.32, 0, pz - .55)
		shape(solid, c + Vector3(0, 1.26, 0), Vector3(1.28, 2.5, .95))
		box(c + Vector3(0, 1.26, .44), Vector3(1.28, 2.5, .07), "#9aa5a3")
		for sx in [-.62, .62]: box(c + Vector3(sx, 1.26, 0), Vector3(.04, 2.5, .95), "#1f2b2b")
		box(c + Vector3(0, 2.49, 0), Vector3(1.28, .04, .95), "#1f2b2b")
		box(c + Vector3(0, .3, 0), Vector3(1.28, .6, .95), "#1f2b2b")
		if i != 2: box(c + Vector3(0, 1.35, -.48), Vector3(1.12, 1.94, .02), "glass#9fdad655")
		box(c + Vector3(0, 2.38, -.44), Vector3(1.1, .05, .04), "glow#eafff8*2.2" if i != 1 else "#4b4c48")
		for j in 4: box(c + Vector3(0, .62 + .45 * j, -.3), Vector3(1.1, .025, .5), "#c9cdc4")
		box(c + Vector3(.48, 1.3, -.52), Vector3(.04, .6, .06), "#c9cdc4")
		for j in 4:
			var row: Array = fridge_rows[i][3 - j]
			var y := .62 + .45 * j + .013
			var x := -.5
			var k := 0
			while x < .5:
				var item: String = row[(k / 4) % row.size()]
				var e := GOODS.extent(item)
				if x + e.x > .52: break
				var keep := .15 if i == 2 else .86
				for depth in [-.42, -.27]:
					if rng.randf() > keep: continue
					var at := c + Vector3(x + e.x * .5, y, depth)
					if rng.randf() < .06: drop(item, at)
					else: put(item, at, PI + rng.randf_range(-.12, .12))
				x += e.x + .008
				k += 1
	crack(Vector3(-1.4, 1.5, pz - 1.04), 0.0, .6)
	crack(Vector3(-.8, .9, pz - 1.04), 0.0, .35)
	crack(Vector3(3.0, 1.75, pz - 1.04), 0.0, .45)
	# Third fridge: door hanging open, its stock out over the floor and run into a sticky pool.
	box(Vector3(1.5, 1.35, pz - 1.35), Vector3(.02, 1.94, 1.1), "glass#9fdad655", false)
	scatter(["gatorade_bottle", "c2_bottle", "minute_maid_bottle", "cobra_bottle", "redbull_can", "monster_can", "coke_can"], Vector3(1.9, 0, pz - 2.0), Vector2(1.3, .9), 34)
	for spec in [[Vector3(1.6, 0, pz - 1.8), .7, "glass#2a4fa0aa"], [Vector3(2.5, 0, pz - 2.3), .5, "glass#c0901ccc"], [Vector3(-.6, 0, pz - 1.6), .45, "glass#2a120ad8"]]:
		can(spec[0] + Vector3.UP * .052, spec[1], .004, spec[2], Basis.IDENTITY, 16)
		can(spec[0] + Vector3(spec[1] * .7, .052, .2), spec[1] * .45, .004, spec[2], Basis.IDENTITY, 12)
	box(Vector3(.9, 2.95, pz - .2), Vector3(5.4, .5, .3), "wood_cabinet_worn_long")
	sign_at(Vector3(.9, 2.95, pz - .36), "ICE COLD DRINKS", .3, PI, Color(1, .97, .9))
	light(Vector3(.9, 2.3, pz - 1.2), Color(.62, .95, 1.0), 1.0, 5.0)
	# Aisles: three gondolas with end caps, the stock in blocks as it was faced; one tipped across the aisle by the
	# soldiers for cover, the household one shoved askew; their goods everywhere.
	shelves(S + Vector3(-5.3, 0, -3.2), PANTRY, .2)
	shelves(S + Vector3(-5.3, 0, .3), PANTRY, .3)
	shelves(S + Vector3(-1.7, 0, -3.2), SNACKS, .25)
	shelves(S + Vector3(-1.7, 0, .3), SNACKS, .35)
	shelves(S + Vector3(1.9, 0, .3), HOUSEHOLD, .5, .22)
	for x in [-5.3, -1.7, 1.9]:
		var b := Basis(Vector3.UP, .22 if x == 1.9 else 0.0)
		var cap := S + Vector3(x, 0, .3 if x == 1.9 else -3.2) + b * Vector3(0, 0, -1.8)
		box(cap + Vector3.UP * .75, Vector3(1.12, 1.5, .3), "#d7d2bf", true, b)
		for level in 3: box(cap + b * Vector3(0, .35 + level * .45, -.17), Vector3(1.0, .03, .1), "#dcad55", false, b)
		box(cap + b * Vector3(0, 1.75, 0), Vector3(1.0, .4, .05), ["#c43b2b", "#2c6fb0", "#e0a72c"][int(x + 6) % 3], false, b)
		var display: Array = {-5.3: ["pringles_original", "pringles_sour_cream", "pringles_cheese"], -1.7: ["lays_classic", "doritos_nacho", "piattos"]}.get(x, ["cup_noodles", "cup_noodles_seafood", "lucky_me_canton"])
		for level in 3:
			var item: String = display[level]
			var e := GOODS.extent(item)
			var n := int(.94 / (e.x + .01))
			for k in n:
				if rng.randf() < .3: continue
				var at := cap + b * Vector3(-.47 + (k + .5) * (e.x + .01), .365 + level * .45, -.18)
				put(item, at, PI + rng.randf_range(-.1, .1) + b.get_euler().y)
		scatter(display, cap + Vector3(0, 0, -.8), Vector2(.8, .5), 7)
		if x != -1.7: sign_at(cap + b * Vector3(0, 1.75, -.03), "SALE" if x < 0 else "NEW!", .2, PI + b.get_euler().y, Color.WHITE if x < 0 else Color(.12, .1, .05), false)
	# The tipped gondola: on its side across the aisle by the window bar, its stock spilled round it.
	var tip := Basis(Vector3.UP, .12) * Basis(Vector3.FORWARD, PI * .5)
	box(S + Vector3(-3.5, .56, 1.0), Vector3(1.12, .12, 2.6), "#cdc8b0", true, tip)
	box(S + Vector3(-3.5, .56, 1.0), Vector3(.1, 1.1, 2.6), "#4c5951", false, tip)
	scatter(SNACKS + PANTRY, S + Vector3(-3.4, 0, 1.0), Vector2(1.5, 2.2), 70)
	# Aisle floors: what was pulled down in the fight, crushed underfoot, and the cans the soldiers emptied.
	scatter(PANTRY, S + Vector3(-6.3, 0, -1.4), Vector2(.5, 3.2), 22)
	scatter(PANTRY + SNACKS, S + Vector3(-3.5, 0, -3.0), Vector2(.55, 1.7), 26)
	scatter(SNACKS, S + Vector3(-.4, 0, -1.4), Vector2(.6, 3.2), 26)
	scatter(HOUSEHOLD, S + Vector3(.7, 0, .3), Vector2(.5, 1.8), 14)
	scatter(HOUSEHOLD, S + Vector3(3.2, 0, .6), Vector2(.7, 1.8), 18)
	scatter(CANS + BOTTLES, S + Vector3(0, 0, -4.2), Vector2(2.6, 1.6), 30)
	scatter(CANS + SNACKS, S + Vector3(-5.6, 0, -6.4), Vector2(2.3, .7), 16)
	# A stacked display of Coke cases by the door: one knocked off and burst.
	for k in 3:
		put("coke_case", S + Vector3(-6.4 + (k % 2) * .42, .045 + (k / 2) * .25, -5.6), PI + rng.randf_range(-.06, .06))
	goods.add("coke_case", Transform3D(Basis(Vector3.UP, .9) * Basis(Vector3.FORWARD, PI * .5), S + Vector3(-5.5, .2, -5.0)))
	scatter(["coke_can", "coke_zero_can"], S + Vector3(-5.3, 0, -4.7), Vector2(.8, .6), 16)
	# Cola and spilt drinks dried tacky on the tiles; receipts and flyers.
	for spec in [[Vector3(-.3, 0, -3.6), .55, "glass#2a120ad0"], [Vector3(-5.1, 0, -4.7), .6, "glass#2a120ad8"], [Vector3(-2.9, 0, 2.6), .4, "glass#a4c23ccc"], [Vector3(3.0, 0, 1.4), .38, "glass#d7e6e888"]]:
		can(S + spec[0] + Vector3.UP * .052, spec[1], .004, spec[2], Basis.IDENTITY, 16)
		can(S + spec[0] + Vector3(spec[1] * .8, .052, -.25), spec[1] * .5, .004, spec[2], Basis.IDENTITY, 12)
	for k in 55:
		var at := S + Vector3(rng.randf_range(-7.5, 7.5), .056, rng.randf_range(-7.8, 3.8))
		if floor_clear(at): box(at, Vector3(rng.randf_range(.07, .1), .002, rng.randf_range(.12, .21)), ["#e9e5d8", "#e1dccb", "#f0d24a", "#d9573c"][k % 4], false, Basis(Vector3.UP, rng.randf() * TAU))
	# The left wall: freezer chests and wall shelving (coffee, Milo, cereal, biscuits); front left: a window bar
	# with stools under yellow pendants, two of them dark.
	for i in 3:
		var f := S + Vector3(-7.75, 0, -1.6 + i * 1.8)
		box(f + Vector3.UP * .42, Vector3(.95, .84, 1.7), "#e9ece8", true)
		box(f + Vector3(.02, .86, 0), Vector3(.9, .03, 1.6), "glass#bfe6ec88")
		box(f + Vector3(0, .8, 0), Vector3(.8, .02, 1.5), "glow#d6f3ff*.6" if i != 1 else "#2b3a3d")
	for i in 2:
		var w := S + Vector3(-8.15, 0, -5.0 + i * 1.6)
		shape(solid, w + Vector3(0, 1.0, 0), Vector3(.5, 2.0, 1.6))
		box(w + Vector3(-.2, 1.0, 0), Vector3(.1, 2.0, 1.6), "#4c5951")
		for sz in [-.79, .79]: box(w + Vector3(0, 1.0, sz), Vector3(.5, 2.0, .03), "#4c5951")
		for level in 4:
			box(w + Vector3(.05, .3 + level * .45, 0), Vector3(.45, .03, 1.58), "#cdc8b0")
			var item: String = [["milo_tin", "nescafe_3in1", "corn_flakes", "skyflakes"], ["oreo", "skyflakes", "nescafe_3in1", "milo_tin"]][i][level]
			var e := GOODS.extent(item)
			var n := int(1.5 / (e.x + .01))
			for j in n:
				if rng.randf() < .35: continue
				var at := w + Vector3(.12, .315 + level * .45, -.75 + (j + .5) * (e.x + .01))
				if rng.randf() < .12: drop(item, at + Vector3(.04, 0, 0))
				else: put(item, at, PI * .5 + rng.randf_range(-.1, .1))
	scatter(["milo_tin", "nescafe_3in1", "corn_flakes", "skyflakes", "oreo"], S + Vector3(-7.4, 0, -4.2), Vector2(.4, 1.0), 12)
	box(S + Vector3(-5.6, 1.05, -7.85), Vector3(5.0, .06, .5), "wood_cabinet_worn_long", true)
	for k in 4:
		var at := S + Vector3(-7.3 + k * 1.15, 0, -7.25)
		model("nichols/nh_metal_stool_01", at, k * 30.0, 1.0, Vector3(0, 0, 90) if k in [0, 2] else Vector3.ZERO)
		var pend := S + Vector3(-7.3 + k * 1.15, 3.1, -7.8)
		box(pend + Vector3.UP * .5, Vector3(.01, 1.0, .01), "#111111")
		can(pend, .2, .18, "#d8c22a", Basis.IDENTITY, 16)
		can(pend + Vector3.DOWN * .1, .17, .02, "glow#fff2b8*2.5" if k in [1, 3] else "#4b4c48", Basis.IDENTITY, 16)
	var bar_lamp := light(S + Vector3(-5.6, 2.6, -7.6), Color(1.0, .78, .4), .8, 4.5)
	flickers.append([bar_lamp, .8, 2.3, null])
	# Checkout at the front right: the counter, the till knocked off it and emptied, a candy rack on the customer's
	# side, the cigarette rack behind and the hot-food warmer, long cold.
	var ck := S + Vector3(3.9, 0, -5.6)
	box(ck + Vector3(0, .5, 0), Vector3(.9, 1.0, 3.6), "#d9d4c2", true)
	box(ck + Vector3(0, 1.02, 0), Vector3(1.0, .05, 3.7), "#2f3533")
	box(ck + Vector3(-.46, .5, 0), Vector3(.02, .7, 3.4), "#7a1717")
	var till := Transform3D(Basis(Vector3.UP, .7) * Basis(Vector3.FORWARD, 1.2), ck + Vector3(.95, .2, -1.1))
	box(till * Vector3(0, 0, 0), Vector3(.4, .3, .35), "#262a28", false, till.basis)
	box(till * Vector3(.05, -.12, .25), Vector3(.36, .08, .3), "#3a3d3a", false, till.basis)
	box(ck + Vector3(.2, 1.12, -.5), Vector3(.05, .35, .3), "#151918", false, Basis(Vector3.FORWARD, -1.2))
	for k in 46:
		var at := ck + Vector3(rng.randf_range(.5, 1.5), .055, rng.randf_range(-2.0, .2))
		if k % 3 == 0: box(at, Vector3(.16, .002, .068), ["#5b86b4", "#d7c05a", "#8e6fa8", "#c25b5b"][k % 4], false, Basis(Vector3.UP, rng.randf() * TAU))
		else: can(at, .012, .004, "#b6a46a", Basis.IDENTITY, 8)
	box(ck + Vector3(.05, 1.12, .7), Vector3(.5, .15, .5), "#bdb6a0")
	box(ck + Vector3(1.75, 1.5, -.5), Vector3(.35, 1.8, 2.4), "#2a2c29", true)
	for level in 5:
		box(ck + Vector3(1.55, .78 + level * .3, -.5), Vector3(.06, .02, 2.3), "#3c3f3b")
		var z := -1.6
		while z < .62:
			if rng.randf() < .8:
				if rng.randf() < .07: drop("marlboro", ck + Vector3(rng.randf_range(.6, 1.4), .005, rng.randf_range(-1.8, .4)))
				else: put("marlboro", ck + Vector3(1.53, .79 + level * .3, z + .03), -PI * .5 + rng.randf_range(-.1, .1))
			z += .062
	box(ck + Vector3(1.6, 1.25, 1.45), Vector3(.6, .55, .55), "glass#ffd59a44")
	box(ck + Vector3(1.6, 1.0, 1.45), Vector3(.6, .05, .55), "#4b3a2a")
	sign_at(ck + Vector3(-.48, .75, 0), "CASHIER", .14, -PI * .5, Color(.9, .85, .7), false)
	for t in 2:
		var shelf := ck + Vector3(-.58, .42 + t * .26, -.9)
		box(shelf, Vector3(.18, .02, 1.3), "#3c3f3b")
		var items: Array = [["snickers", "kitkat", "hersheys"], ["mms_peanut", "kitkat", "snickers"]][t]
		for k in 8:
			if rng.randf() < .35: continue
			var item: String = items[k / 3]
			var at := shelf + Vector3(-.02, .012, -.55 + k * .157)
			put(item, at, -PI * .5, Basis(Vector3.RIGHT, -.25))
	scatter(["snickers", "kitkat", "hersheys", "mms_peanut", "marlboro"], ck + Vector3(-1.0, 0, -.8), Vector2(.4, 1.0), 14)
	wall_mark("smear_wall", ck + Vector3(-.47, .6, .3), Vector3.LEFT, 1.0, .8)
	wall_mark("spatter_floor", ck + Vector3(1.6, 1.4, -.9), Vector3.LEFT, .9, .9)
	# Red baskets: a stack by the door, others dropped with what was in them.
	for k in 4: basket(Transform3D(Basis.IDENTITY, S + Vector3(2.5, .045 + k * .07, -7.6)))
	for spec in [[Vector3(-.9, .17, -1.2), .4], [Vector3(-4.0, .17, -4.3), 2.0], [Vector3(.9, .17, -2.6), 1.1]]:
		basket(Transform3D(Basis(Vector3.UP, spec[1]) * Basis(Vector3.FORWARD, 1.5), S + spec[0]))
	var stand := S + Vector3(-3.0, 0, -6.0)
	box(stand + Vector3(0, .1, 0), Vector3(.32, .64, .2), "#e1b81e", false, Basis(Vector3.RIGHT, PI * .5))
	can(S + Vector3(.3, .12, -3.0), .15, .15, "#3c4530")
	# The soldiers' position: a horseshoe of sandbags facing the door, brass, a blood trail to the stockroom.
	# 0.46: the side walls used to run into the back wall's end bags at the same heights, so the coplanar faces of
	# the overlapping bags flickered (z-fighting at the corners). They now stop short of it, a touch higher.
	for spec in [[Vector3(0, 0, -6.4), 0.0, 2.5, 0.0], [Vector3(-1.32, 0, -5.42), PI * .5, 1.5, .018], [Vector3(1.32, 0, -5.42), PI * .5, 1.5, .018]]:
		var b := Basis(Vector3.UP, spec[1])
		var span: float = spec[2]
		var lift: float = spec[3]
		var n := int(span / .5)
		for layer in 2:
			for k in n:
				box(S + spec[0] + b * Vector3(-span * .5 + .25 + k * .5 + (.12 if layer else 0.0), .14 + lift + layer * .24, 0), Vector3(.48, .23 - lift * .5, .36), "#7b7055" if (k + layer) % 2 else "#6f6650", false, b)
		box(S + spec[0] + Vector3.UP * .26, Vector3(span, .52, .4), "#000000", true, b)
	kits.erase("#000000")
	for k in 160:
		can(S + Vector3(rng.randf_range(-2.2, 2.2), .06, rng.randf_range(-6.4, -3.6)), .006, .045, "#b38b3a", Basis(Vector3.FORWARD, PI * .5) * Basis(Vector3.UP, rng.randf() * TAU), 5)
	drag_trail(S + Vector3(-.4, 0, -5.0), S + Vector3(-.4, 0, 2.6))
	drag_trail(S + Vector3(-.4, 0, 2.6), S + Vector3(-2.9, 0, 4.4), false)
	drag_trail(S + Vector3(-2.9, 0, 4.4), Vector3(-5.0, 0, 71.6), false)
	# Where each of the dead lies, the blood that ran out of them; spray where rounds went through.
	for spec in STORE_DEAD:
		stain("pool_big", spec[0] + Vector3(rng.randf_range(-.3, .3), 0, rng.randf_range(-.3, .3)), rng.randf() * TAU, 1.8, 1.5)
		if rng.randf() < .6: stain("spatter_floor", spec[0] + Vector3(rng.randf_range(-.9, .9), 0, rng.randf_range(-.9, .9)), rng.randf() * TAU, 1.2, 1.2, .8)
	stain("spatter_floor", S + Vector3(-1.4, 0, -7.9), .4, 1.8, 1.6)
	wall_mark("spatter_floor", Vector3(-7.75 + .48, .6, 65.2), Vector3.RIGHT, 1.0, 1.0)
	wall_mark("smear_wall", Vector3(-8.38, 1.2, 63.3), Vector3.RIGHT, 1.4, .9)
	for k in 26:
		var on_left := k % 2 == 0
		wall_mark("hole", Vector3(-8.37 if on_left else 8.37, rng.randf_range(.5, 2.6), rng.randf_range(57.0, 62.5)), Vector3.RIGHT if on_left else Vector3.LEFT, .07, .07)
	for k in 10:
		wall_mark("hole", S + Vector3(rng.randf_range(-6, -1), rng.randf_range(.3, 1.4), -5.21), Vector3.FORWARD, .07, .07)
	# The soldiers' supplies along the right wall: crates on a pallet, rifles laid on top, ammunition beside.
	box(COUNTER + Vector3(2.45, .07, 2.75), Vector3(1.3, .14, 4.6), "worn_planks", true)
	for k in 5:
		box(COUNTER + Vector3(2.45, .45, .75 + k * .82), Vector3(1.1, .62, .75), "#4a5232", true)
		box(COUNTER + Vector3(2.45, .77, .75 + k * .82), Vector3(1.12, .04, .77), "#353a24")
		sign_at(COUNTER + Vector3(1.88, .5, .75 + k * .82), "AFP", .1, -PI * .5, Color(.85, .82, .6), false)
	for i in 5:
		var gun := InteriorGun.RIFLE.instantiate() as Node3D
		gun.position = COUNTER + Vector3(2.4, 1.08 - .25, 1.1 + i * .82 - .35)
		gun.rotation = Vector3(0, PI / 2, PI / 2)
		add_child(gun)
		rifles.append(gun)
	for i in 8:
		box(COUNTER + Vector3(1.6, .1, 1 + i * .54), Vector3(.3, .19, .4), "#626540")
		box(COUNTER + Vector3(1.6, .21, 1 + i * .54), Vector3(.06, .03, .2), "#2d2f1e")
	for i in 2:
		var shotgun := (load("res://assets/models/story/shotgun.glb") as PackedScene).instantiate() as Node3D
		shotgun.position = COUNTER + Vector3(1.75 - i * .3, .95, -.5)
		shotgun.rotation = Vector3(0, .3 + i * .2, PI * .5)
		add_child(shotgun)
		shotguns.append(shotgun)
	box(COUNTER + Vector3(1.6, .45, -.5), Vector3(.9, .9, .6), "#4a5232", true)
	# Ceiling: tube troffers, most dead now; a few flicker, and one has come down on its wires, sparking.
	var states := {Vector2(-5.3, -5.5): "dead", Vector2(-5.3, -1.6): "flicker", Vector2(-5.3, 2.2): "on",
		Vector2(-1.7, -5.5): "flicker", Vector2(-1.7, -1.6): "shadow", Vector2(-1.7, 2.2): "dead",
		Vector2(1.9, -5.5): "hanging", Vector2(1.9, -1.6): "dead", Vector2(1.9, 2.2): "flicker",
		Vector2(5.4, -5.5): "on", Vector2(5.4, -1.6): "flicker", Vector2(5.4, 2.2): "dead"}
	for key: Vector2 in states:
		var state: String = states[key]
		var at := S + Vector3(key.x, 3.96, key.y)
		if state == "hanging":
			var top := at + Vector3(0, 0, .65)
			var down := Vector3(0, -sin(deg_to_rad(65.0)), -cos(deg_to_rad(65.0)))
			var tilt := Basis(Vector3.RIGHT, deg_to_rad(-65.0))
			box(top + down * .65, Vector3(.5, .07, 1.3), "#d8d9d2", false, tilt)
			box(top + down * .65 + tilt * Vector3.DOWN * .04, Vector3(.4, .02, 1.2), "#9aa29c", false, tilt)
			box(at + Vector3(0, 0, -.1), Vector3(.5, .02, 1.1), "#151515")
			wire(at + Vector3(.15, .02, -.6), top + down * 1.28 + Vector3(.15, 0, 0), .25)
			wire(at + Vector3(-.15, .02, -.6), top + down * 1.25 + Vector3(-.15, 0, 0), .35)
			bad_light = light(top + down * 1.25 + Vector3.DOWN * .1, Color(.88, 1.0, .93), 1.4, 6.0, true)
			continue
		box(at, Vector3(.5, .07, 1.3), "#d8d9d2")
		box(at + Vector3.DOWN * .04, Vector3(.4, .02, 1.2), "#4b4c48" if state == "dead" else "glow#e3f7e6*2.2")
		if state == "dead": continue
		var lamp := light(at + Vector3.DOWN * .35, Color(.8, 1.0, .88), .85, 5.2, state == "shadow")
		if state == "flicker": flickers.append([lamp, .85, rng.randf_range(4.0, 9.0), null])
	for spec in [[-5.3, "PANTRY • CANNED GOODS"], [-1.7, "SNACKS • CHIPS"], [1.9, "HOUSEHOLD • PERSONAL CARE"]]:
		var board := S + Vector3(spec[0], 2.85, -1.4)
		var hang := Basis(Vector3.FORWARD, .25) if spec[0] == 1.9 else Basis.IDENTITY
		box(board, Vector3(1.8, .32, .05), "#7a1717", false, hang)
		var words := sign_at(board + Vector3(0, 0, -.03), spec[1], .11)
		words.rotation.z = -.25 if spec[0] == 1.9 else 0.0
		for offset in [-.6, .6]: box(board + Vector3(offset, .58, 0), Vector3(.012, .85, .012), "#555650")
	can(S + Vector3(7.9, 3.6, -7.9), .3, .02, "glass#c9d6d6aa", Basis(Vector3.RIGHT, PI * .5) * Basis(Vector3.FORWARD, .7), 18)
	box(S + Vector3(-8.1, 3.7, -7.9), Vector3(.14, .12, .26), "#e6e6e0", false, Basis(Vector3.UP, .6))
	box(S + Vector3(-8.05, 3.6, -7.85), Vector3(.03, .03, .03), "glow#ff2a1a*3.0")
	sparks = CPUParticles3D.new()
	sparks.position = bad_light.position
	sparks.amount = 12
	sparks.lifetime = .42
	sparks.direction = Vector3.DOWN
	sparks.spread = 55
	sparks.initial_velocity_min = 1.0
	sparks.initial_velocity_max = 3.0
	sparks.gravity = Vector3.DOWN * 6
	var spark := BoxMesh.new()
	spark.size = Vector3(.018, .07, .018)
	var m := material("#ffc46b")
	m.emission_enabled = true
	m.emission = Color(1, .45, .07)
	spark.material = m
	sparks.mesh = spark
	add_child(sparks)
	hum(bad_light.position, "res://assets/audio/nichols/arc_buzz.ogg", -16.0, 3.0)
	# A phone face up beside the man at the counter, lighting now and then: someone still calling him.
	var phone_at := Vector3(2.55, .058, 60.9)
	box(phone_at, Vector3(.075, .01, .155), "#111214", false, Basis(Vector3.UP, .5))
	phone_screen = MeshInstance3D.new()
	var screen := BoxMesh.new()
	screen.size = Vector3(.066, .004, .14)
	phone_screen.mesh = screen
	phone_screen.material_override = material("glow#bfe2ff*2.2")
	phone_screen.position = phone_at + Vector3.UP * .007
	phone_screen.rotation.y = .5
	add_child(phone_screen)
	phone_glow = light(phone_at + Vector3.UP * .12, Color(.7, .85, 1.0), .5, 1.6)
	# Flies over the dead, a drip from the open fridge.
	hum(Vector3(4.3, 1.0, 59.8), "res://assets/audio/nichols/flies.ogg", -14.0, 3.0)
	hum(Vector3(-6.6, 1.0, 65.2), "res://assets/audio/nichols/flies.ogg", -16.0, 3.0)
	hum(Vector3(1.6, .4, 68.0), "res://assets/audio/nichols/drip.ogg", -18.0, 2.5)
	for spec in [["nichols/nh_trashbag", -7.7, -6.6], ["nichols/nh_cardboard_box_01", 7.4, -1.0],
			["nichols/nh_cardboard_box_01", -3.4, 3.4], ["nichols/nh_wine_bottles_01", -6.5, 1.9]]:
		model(spec[0], S + Vector3(spec[1], .06, spec[2]), rng.randf_range(-30, 30))

## The stockroom (left of the partition) and the staff room's dark doorway: racks, boxes, the back door.
func stockroom() -> void:
	var z0 := STORE.z + 4.57
	box(Vector3(-3.75, .03, z0 + 2.0), Vector3(9.4, .04, 3.8), "concrete_floor_02")
	for k in 3:
		InteriorModelKit.shot_proxy(null, model("nichols/nh_steel_frame_shelves_02", Vector3(-8.0, .05, z0 + .7 + k * .9), 90.0))
	var racks: Array = []
	racks.append(model("nichols/nh_worn_metal_rack", Vector3(-1.6, .05, z0 + 3.3), 180.0))
	racks.append(model("nichols/nh_worn_metal_rack", Vector3(-2.6, .05, z0 + 3.3), 180.0))
	# (0.49: rounds go between the shelves and strike the frames, not the walking boxes.)
	InteriorModelKit.shot_proxy(shape(solid, Vector3(-8.0, 1.0, z0 + 1.6), Vector3(.6, 2.0, 2.8)), null)
	InteriorModelKit.shot_proxy(shape(solid, Vector3(-2.1, 1.0, z0 + 3.3), Vector3(2.0, 1.9, .6)), null)
	for r in racks: InteriorModelKit.shot_proxy(null, r)
	for k in 9:
		var at := Vector3(rng.randf_range(-7.0, -3.6), .05, rng.randf_range(z0 + .5, z0 + 3.4))
		if absf(at.x - BACK_DOOR.x) < 1.0 and at.z > z0 + 2.4: continue
		model("nichols/nh_cardboard_box_01", at, rng.randf_range(0, 360), 1.0 + rng.randf() * .4)
	box(Vector3(-4.2, 1.5, z0 + .12), Vector3(1.0, .7, .03), "#e6dfc8")
	sign_at(Vector3(-4.2, 1.55, z0 + .1), "INVENTORY\nNOV  •  DEC", .06, 0.0, Color(.1, .1, .1), false)
	var bulb := Vector3(-5.0, 3.6, z0 + 2.0)
	box(bulb + Vector3.UP * .2, Vector3(.01, .4, .01), "#111111")
	can(bulb, .04, .08, "glow#ffd39a*2.5")
	light(bulb + Vector3.DOWN * .1, Color(1.0, .8, .55), .9, 5.5, true)
	# The steel back door: on a frame, bolted, dented by what has been at it.
	box(BACK_DOOR + Vector3(0, 2.2, -.12), Vector3(1.3, .08, .1), "rusty_metal_04")
	for s in [-1, 1]: box(BACK_DOOR + Vector3(s * .66, 1.1, -.12), Vector3(.06, 2.2, .1), "rusty_metal_04")
	back_door = movable(BACK_DOOR + Vector3(-.6, 0, -.05))
	shape(back_door, Vector3(.6, 1.1, 0), Vector3(1.2, 2.2, .08))
	piece(back_door, Vector3(.6, 1.1, 0), Vector3(1.2, 2.2, .06), "rusty_metal_sheet|#6a5c50")
	piece(back_door, Vector3(.6, 1.15, -.05), Vector3(.9, .06, .05), "rusty_metal_04")
	piece(back_door, Vector3(1.05, 1.05, -.06), Vector3(.12, .05, .04), "#8c8c84")
	# 0.44: the back office (back_office.gd), where Jonna is.
	box(Vector3(4.75, .03, z0 + 2.0), Vector3(7.4, .04, 3.8), "concrete_floor_02")
	BACK_OFFICE.build(self)

func back_alley() -> void:
	box(Vector3(0, .02, 76.8), Vector3(20.8, .04, 6.4), "damaged_concrete_floor")
	model("street/security_light", BACK_DOOR + Vector3(1.0, 2.7, .1), 180.0)
	light(BACK_DOOR + Vector3(1.0, 2.4, .7), Color(.85, .9, .78), .7, 6.0)
	box(Vector3(3.2, .7, 78.9), Vector3(2.0, 1.4, 1.1), "#2f4a33", true)
	box(Vector3(3.2, 1.43, 78.9), Vector3(2.05, .06, 1.15), "#1f2f22")
	for spec in [["nichols/nh_trashbag", 1.9, 79.2], ["nichols/nh_trashbag", 4.5, 78.4], ["nichols/nh_wooden_crate_02", -8.6, 78.5],
			["nichols/nh_trashbag", 7.5, 77.8], ["street/oil_drum", -9.6, 76.0]]:
		model(spec[0], Vector3(spec[1], .04, spec[2]), rng.randf_range(0, 360))

## A gondola: a spine, four shelves a side with price strips, and its stock faced in blocks as it was put out.
## `mess` is how much of it the fight took: emptied blocks, things knocked over on the shelf or down onto the floor.
## `yaw` turns it (the household one was shoved askew).
func shelves(c: Vector3, theme: Array, mess: float, yaw := 0.0) -> void:
	var b := Basis(Vector3.UP, yaw)
	box(c + Vector3.UP * .85, Vector3(.12, 1.7, 3.3), "#4c5951", true, b)
	var fits: Array = theme.filter(func(item: String) -> bool: return GOODS.extent(item).y < .36)
	for level in 4:
		var y := .22 + level * .43
		box(c + Vector3.UP * y, Vector3(1.12, .055, 3.3), "#cdc8b0", level == 0, b)
		for side in [-1, 1]:
			box(c + b * Vector3(side * .55, y + .033, 0), Vector3(.05, .065, 3.29), "#dcad55", false, b)
			var z := -1.6
			while z < 1.55:
				var item: String = fits[rng.randi() % fits.size()]
				var e := GOODS.extent(item)
				var facings := rng.randi_range(2, 5)
				var gone := rng.randf() < mess * .35
				for k in facings:
					if z + e.x > 1.6: break
					var mid := z + e.x * .5
					if not gone:
						for row in 2:
							var depth := .5 - e.z * .5 - row * (e.z + .015)
							if depth < .12 or (row == 1 and rng.randf() < .5): continue
							var at := c + b * Vector3(side * depth, y + .028, mid)
							var r := rng.randf()
							if r < mess * .12: drop(item, at)
							elif r < mess * .3 and row == 0:
								var fell := c + b * Vector3(side * rng.randf_range(.7, 1.4), 0, mid + rng.randf_range(-.3, .3))
								if floor_clear(fell): drop(item, fell)
							else: put(item, at, yaw + side * PI * .5 + rng.randf_range(-.07, .07))
					z += e.x + .012
				if gone: z += .02

# ---------------------------------------------------------------- the forecourt tables

func barricades() -> void:
	var friction := PhysicsMaterial.new()
	friction.friction = .85
	friction.bounce = .02
	for spec in TABLE_SPECS:
		var t := RigidBody3D.new()
		t.collision_layer = 4
		t.collision_mask = 1 | 2 | 4 | 16
		t.physics_material_override = friction
		t.position = spec[1]
		t.rotation.y = spec[2]
		t.linear_damp = .6
		t.angular_damp = 2.0
		t.can_sleep = true
		t.continuous_cd = true
		t.set_meta("barricade", true)
		var kind: String = spec[0]
		t.set_meta("half", {"long": Vector3(1.0, .4, .4), "round": Vector3(.5, .4, .5)}.get(kind, Vector3(.45, .4, .45)))
		match kind:
			"long":
				t.mass = 24.0
				piece(t, Vector3.UP * .74, Vector3(2.0, .04, .8), "#e3e1d8")
				piece(t, Vector3(0, .69, .38), Vector3(2.0, .06, .03), "#8f938c")
				for x in [-.85, .85]:
					for z in [-.32, .32]: piece(t, Vector3(x, .36, z), Vector3(.035, .72, .035), "#8f938c")
				shape(t, Vector3.UP * .73, Vector3(2.0, .06, .8))
				shape(t, Vector3.UP * .36, Vector3(1.8, .7, .68))
			"round":
				t.mass = 19.0
				rod(t, Vector3.UP * .76, .5, .03, "#a9aca8")
				rod(t, Vector3.UP * .39, .04, .72, "#6f726e")
				rod(t, Vector3.UP * .02, .3, .03, "#6f726e")
				var top := CollisionShape3D.new()
				var cyl := CylinderShape3D.new()
				cyl.radius = .5
				cyl.height = .05
				top.shape = cyl
				top.position = Vector3.UP * .76
				t.add_child(top)
				shape(t, Vector3.UP * .38, Vector3(.42, .74, .42))
				t.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
				t.center_of_mass = Vector3.UP * .25
			_:
				t.mass = 14.0
				piece(t, Vector3.UP * .72, Vector3(.9, .04, .9), "#c43a2e")
				for x in [-.38, .38]:
					for z in [-.38, .38]: piece(t, Vector3(x, .36, z), Vector3(.05, .72, .05), "#b5352a")
				shape(t, Vector3.UP * .72, Vector3(.9, .05, .9))
				shape(t, Vector3.UP * .36, Vector3(.82, .7, .82))
		if not authority:
			t.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
			t.freeze = true
		add_child(t)
		tables.append(t)

## Host: where every table is, for the others.
func props_state() -> Array:
	var out := []
	for t in tables: out.append([t.global_position, t.global_basis.get_rotation_quaternion()])
	return out

## Everyone else: the host's tables, eased toward between updates.
func apply_props(state: Array) -> void:
	for i in mini(state.size(), tables.size()):
		_prop_goal[i] = state[i]

func _physics_process(delta: float) -> void:
	if authority:
		# Scrape when a table is dragged or shoved along the ground.
		var loud := 0.0
		for t in tables:
			if t.sleeping: continue
			var v := Vector2(t.linear_velocity.x, t.linear_velocity.z).length()
			if v > loud:
				loud = v
				_scrape.position = to_local(t.global_position)
		if loud > .35 and not _scrape.playing:
			_scrape.pitch_scale = randf_range(.85, 1.1)
			_scrape.play()
		return
	for i: int in _prop_goal:
		var goal: Array = _prop_goal[i]
		var t := tables[i]
		var to: Vector3 = goal[0]
		if t.global_position.distance_to(to) > .01:
			if t.global_position.distance_to(to) > .5 and not _scrape.playing:
				_scrape.position = to_local(t.global_position)
				_scrape.play()
			t.global_position = t.global_position.lerp(to, 1.0 - exp(-14.0 * delta))
			t.global_basis = Basis(t.global_basis.get_rotation_quaternion().slerp(goal[1], 1.0 - exp(-14.0 * delta)))

## A door or gate starting to move: a lock and a scrape.
## 0.49: the roll-down shutter over the shopfront, rolled up into its box under the fascia until Jonna pulls it down.
func front_shutter() -> void:
	var S := STORE
	shutter = Node3D.new()
	shutter.name = "Front shutter"
	shutter.position = S + Vector3(0, 0, SHUTTER_Z)
	add_child(shutter)
	# The box it rolls into and the guide rails down either end.
	piece(shutter, Vector3(0, SHUTTER_TOP + .1, -.07), Vector3(17.36, .26, .28), "rusty_metal_02")
	for x in [-8.66, 8.66]: piece(shutter, Vector3(x, SHUTTER_TOP * .5, 0), Vector3(.1, SHUTTER_TOP, .12), "#5b605c")
	shutter_curtain = piece(shutter, Vector3(0, SHUTTER_TOP - .01, 0), Vector3(17.2, 1.0, .035), "painted_metal_shutter|#9a9c95")
	shutter_bar = piece(shutter, Vector3(0, SHUTTER_TOP, -.03), Vector3(17.24, .07, .07), "#3c403d")
	# The hasp at the foot of the middle and the padlock through it (shown once it is locked).
	shutter_lock = Node3D.new()
	shutter_lock.position = Vector3(.4, .12, -.06)
	shutter.add_child(shutter_lock)
	piece(shutter_lock, Vector3(0, .02, 0), Vector3(.1, .06, .03), "#8a8f88")
	piece(shutter_lock, Vector3(0, -.05, -.015), Vector3(.07, .08, .03), "#b49a52")
	shutter_lock.visible = false
	shutter_body = StaticBody3D.new()
	shutter_body.name = "Front shutter body"
	shutter_body.collision_layer = 0
	shutter_body.collision_mask = 0
	shutter_body.set_meta("surface", "metal")
	shutter.add_child(shutter_body)
	shape(shutter_body, Vector3(0, SHUTTER_TOP * .5, 0), Vector3(17.2, SHUTTER_TOP, .1))
	_shutter_sound = AudioStreamPlayer3D.new()
	_shutter_sound.unit_size = 6.0
	_shutter_sound.max_distance = 40.0
	_shutter_sound.position = Vector3(0, 2.0, .6)
	shutter.add_child(_shutter_sound)
	_shutter_at(0.0)

func _shutter_at(t: float) -> void:
	var h := maxf(SHUTTER_TOP * t, .02)
	shutter_curtain.scale.y = h
	shutter_curtain.position.y = SHUTTER_TOP - h * .5
	shutter_curtain.visible = t > .005
	shutter_bar.position.y = SHUTTER_TOP - h
	# Down far enough that nobody gets under it: it walls the front off (people and rounds alike).
	shutter_body.collision_layer = 2 if t > .55 else 0

func _shutter_sync(flags: Dictionary) -> void:
	var t := clampf(float(flags.get("shutter", 0.0)), 0.0, 1.0)
	if t != _shutter_shown:
		if _shutter_shown >= 0.0 and t > _shutter_shown and not _shutter_sound.playing and t < .98:
			_shutter_sound.stream = preload("res://assets/audio/siege/scrape.ogg")
			_shutter_sound.pitch_scale = .72
			_shutter_sound.volume_db = 2.0
			_shutter_sound.play()
		if t >= 1.0 and _shutter_shown < 1.0 and _shutter_shown >= 0.0:
			_shutter_sound.stream = preload("res://assets/audio/sfx/impactMetal_heavy_001.ogg")
			_shutter_sound.pitch_scale = .8
			_shutter_sound.volume_db = 4.0
			_shutter_sound.play()
		_shutter_shown = t
		_shutter_at(t)
	var locked: bool = flags.get("locked", false)
	if locked and not shutter_lock.visible:
		shutter_lock.visible = true
		_door_creak(shutter_lock.global_position)

func _door_creak(at: Vector3) -> void:
	if _door_sound == null:
		_door_sound = AudioStreamPlayer3D.new()
		_door_sound.unit_size = 5.0
		_door_sound.max_distance = 30.0
		add_child(_door_sound)
	_door_sound.global_position = at + Vector3.UP * 1.2
	_door_sound.stream = preload("res://assets/audio/sfx/lock_turn.ogg")
	_door_sound.play()

## 0.66: a one-off scrape of steel on its rail at `at` (the Old Salmonan gate rolling shut behind the squad).
func _scrape_at(at: Vector3) -> void:
	var a := AudioStreamPlayer3D.new()
	a.stream = preload("res://assets/audio/siege/scrape.ogg")
	a.unit_size = 8.0
	a.max_distance = 45.0
	a.pitch_scale = .8
	add_child(a)
	a.global_position = at + Vector3.UP
	a.finished.connect(a.queue_free)
	a.play()

## The back door taking a blow; `broken` throws it in.
func back_door_hit(broken: bool) -> void:
	_bang.stream = load("res://assets/audio/siege/bang_%s.ogg" % ["a", "b", "c", "d"][randi() % 4])
	_bang.pitch_scale = randf_range(.85, 1.05)
	_bang.volume_db = 4.0 if broken else 0.0
	_bang.play()

func sync(flags: Dictionary) -> void:
	# 0.40: a body is only moved when it has somewhere to go (moving a static body every frame costs the physics).
	var gate_x := 4.5 if flags.get("gate", false) else 0.0
	if gate.position.x != gate_x:
		# 0.66: shut behind the squad (chapter one put away): it rolls shut along its rail, heard from up the road.
		if gate_x == 0.0 and flags.get("road_shut", false) and gate.position.x == 4.5:
			_door_creak(gate.global_position)
			_scrape_at(gate.global_position)
		gate.position.x = gate_x
	if gate_chain != null: gate_chain.visible = not flags.get("unlocked", false)
	# 0.44: the office door swings in when Jonna opens it; the back door is let open (not broken) for the way
	# out; the alley gate slides aside on her key; the radio's light blinks.
	var want := BACK_OFFICE.OPEN_YAW if flags.get("office", false) else 0.0
	if office_door.rotation.y != want:
		if office_door.rotation.y == 0.0: _door_creak(office_door.global_position)
		office_door.rotation.y = move_toward(office_door.rotation.y, want, .03)
	if flags.get("backdoor_open", false) and back_door.rotation.y == 0.0 and not flags.get("backdoor", false):
		back_door.rotation.y = -1.6
		back_door.collision_layer = 0
		_door_creak(back_door.global_position)
	var alley_x := -2.9 if flags.get("alley", false) else 0.0
	if alley_gate.position.x != ALLEY_GATE.x + alley_x:
		if alley_gate.position.x == ALLEY_GATE.x: _door_creak(alley_gate.global_position)
		alley_gate.position.x = move_toward(alley_gate.position.x, ALLEY_GATE.x + alley_x, .04)
	radio_led.visible = fmod(Time.get_ticks_msec() * .001, 2.2) < .14
	_shutter_sync(flags)
	# 0.49: the backstreets are put away until the run reaches them (mission `wake_ahead`).
	if backstreets.visible: backstreets.tick(Time.get_ticks_msec() * .001)
	for i in doors.size():
		var swing := (-PI * .49 if i % 2 == 0 else PI * .49) if flags.get("door%d" % i, false) else 0.0
		if doors[i].rotation.y != swing: doors[i].rotation.y = swing
	var broken: bool = flags.get("backdoor", false)
	if broken and back_door.rotation.y == 0.0:
		back_door.rotation = Vector3(-.12, -1.7, 0)
		back_door.position += Vector3(0, .02, -.2)
		back_door.collision_layer = 0
		back_door_hit(true)
	var dents: int = flags.get("backhits", 0)
	if dents != int(back_door.get_meta("dents", 0)):
		back_door.set_meta("dents", dents)
		if not broken:
			back_door_hit(false)
			back_door.rotation.x = -.01 * (dents % 3)
	for i in rifles.size(): rifles[i].visible = not flags.get("rifle%d" % i, false)
	for i in shotguns.size(): shotguns[i].visible = not flags.get("shotgun%d" % i, false)
	key.visible = not flags.get("keys", false)
	key_label.visible = key.visible
	key_glow.visible = key.visible
	var now := Time.get_ticks_msec()
	var flicker := sin(now * .031) > .84 and sin(now * .0031) > .65
	bad_light.light_energy = .05 if flicker else 1.4
	sparks.emitting = flicker
	# The phone: a call every so often, lit for a few seconds, a beat dark between the rings.
	var ring := fmod(now * .001, 19.0)
	var lit := ring < 6.5 and fmod(ring, 1.6) < 1.25
	phone_screen.visible = lit
	phone_glow.visible = lit
	for f: Array in flickers:
		var phase: float = f[2]
		var off := sin(now * .001 * phase * 7.0) > .7 and sin(now * .001 * phase) > .2
		(f[0] as OmniLight3D).light_energy = float(f[1]) * (.08 if off else randf_range(.85, 1.0))
