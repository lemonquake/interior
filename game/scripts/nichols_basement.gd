extends Node3D
## 0.22: what the Nichols house hides below its boards. Built by nichols_property.gd from layout.json["basement"]
## (geometry: tools/blender/nichols/nichols_basement.py, house_base.glb on its own visual layer).
##
## A drag trail of blood a few days old runs from the front porch across the foyer, round the grand stair, down the
## dark nook under its landing to a low cellar door left half open. The first time the player sees it inside:
## "Shit..", "I thought this place was empty decades ago?". A switch beside the door turns on a handful of weak bulbs:
## one over the stair shaft, one at its foot, two in the 1906 fieldstone cellar (a third is dead), three in the
## wartime tunnel reached through a hole someone broke in the cellar wall. Some of them flicker and buzz. The trail goes
## on down the stair, across the cellar, behind the shelf that hid the hole and along the tunnel to an iron door chained
## shut with a new padlock. Down there: a butcher's corner, a tarp over something the flies found, dog cages.

const INTERIOR_LAYER := 1 << 10
const BASEMENT_LAYER := 1 << 12
const OUTDOOR_LAYER := 2
const BLOOD := "res://assets/nichols/blood/"
const AUDIO := "res://assets/audio/nichols/"
const SIGHT_LINES := ["Shit..", "I thought this place was empty decades ago?"]
const LOCK_LINES := ["Chained shut.", "That padlock is new.", "Someone comes down here."]
## The house's outer walls (world XZ): the town's ground slab is cut away inside them.
const HOLE := Rect2(-25.0, -102.0, 26.0, 20.0)
const BULB_COLOR := Color(1.0, .7, .43)
const LockedScript := preload("res://scripts/nichols_locked.gd")
const HorrorLiquid := preload("res://scripts/horror_liquid.gd")

var prop: Node3D
var lb: Dictionary
var origin: Vector3
var bulbs: Array[Dictionary] = []
var lights_on := false
var flicker_enabled := true
var saw_blood := false
var sight_points: Array[Vector3] = []
var cellar_door: Node3D
var switch_node: Node3D
var stats := {"bulbs": 0, "lights": 0, "decals": 0, "props": 0, "ground_cut": 0, "meshes_cut": 0}
var _rooms: Array[Dictionary] = []
var _tex: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _lever: Node3D
var _click: AudioStreamPlayer3D
var _tone: AudioStreamPlayer
var _drips: AudioStreamPlayer3D
var _drip_wait := 3.0
var _bundle: Node3D
var _below := 0.0
var _probe_refresh := 0.0

func build(property: Node3D, town: Node3D) -> void:
	name = "Nichols basement"
	add_to_group("nichols_basement")
	prop = property
	lb = prop.layout.get("basement", {})
	origin = prop.HOUSE_POS
	_rng.seed = 2209
	if lb.is_empty():
		return
	_cut_ground(town)
	_door()
	_switch()
	_bulbs()
	_air()
	_props()
	_bundle_on_hook()
	_locked_door()
	_kitchen()
	_blood()
	_sounds()

func _v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])

func _at(a: Array) -> Vector3:
	return origin + _v(a)

## House space in Blender terms (x east, depth from the front facade, height above the boards) to world.
func bl(x: float, depth: float, up := 0.0) -> Vector3:
	return origin + Vector3(x, up, -depth)

# ------------------------------------------------------------------------------------------------ the ground

## The town's ground slab (and its grass) ran right under the house; the cellar needs it gone inside the walls.
func _cut_ground(town: Node3D) -> void:
	var colliders := town.get_node_or_null("NeighbourhoodColliders")
	if colliders != null:
		for child in colliders.get_children():
			var c := child as CollisionShape3D
			if c != null and not c.disabled and c.shape is BoxShape3D and str(c.name).begins_with("Ground"):
				_split_box(colliders, c)
	for child in town.get_children():
		if child.has_method("_carve_mesh"):
			for mesh in town.get_children():
				if mesh is MeshInstance3D:
					var before := (mesh as MeshInstance3D).mesh
					child.call("_carve_mesh", mesh, HOLE)
					if (mesh as MeshInstance3D).mesh != before:
						stats.meshes_cut += 1
			break

func _split_box(parent: Node, c: CollisionShape3D) -> void:
	var size: Vector3 = (c.shape as BoxShape3D).size
	var lo := Vector2(c.position.x - size.x * .5, c.position.z - size.z * .5)
	var hi := Vector2(c.position.x + size.x * .5, c.position.z + size.z * .5)
	var h0 := HOLE.position
	var h1 := HOLE.end
	if hi.x <= h0.x or lo.x >= h1.x or hi.y <= h0.y or lo.y >= h1.y:
		return
	c.disabled = true
	var pieces: Array[Rect2] = []
	if lo.y < h0.y: pieces.append(Rect2(lo.x, lo.y, hi.x - lo.x, h0.y - lo.y))
	if hi.y > h1.y: pieces.append(Rect2(lo.x, h1.y, hi.x - lo.x, hi.y - h1.y))
	var zlo := maxf(lo.y, h0.y)
	var zhi := minf(hi.y, h1.y)
	if lo.x < h0.x: pieces.append(Rect2(lo.x, zlo, h0.x - lo.x, zhi - zlo))
	if hi.x > h1.x: pieces.append(Rect2(h1.x, zlo, hi.x - h1.x, zhi - zlo))
	for r in pieces:
		var piece := CollisionShape3D.new()
		piece.name = str(c.name) + " around Nichols cellar"
		var box := BoxShape3D.new()
		box.size = Vector3(r.size.x, size.y, r.size.y)
		piece.shape = box
		piece.position = Vector3(r.get_center().x, c.position.y, r.get_center().y)
		for key in c.get_meta_list(): piece.set_meta(key, c.get_meta(key))
		parent.add_child(piece)
	stats.ground_cut += 1

# ------------------------------------------------------------------------------------------------ door and switch

func _door() -> void:
	var d: Dictionary = lb.door
	var hinge := _at(d.hinge)
	var latch := _at(d.latch)
	# Half open, as it was left: E pushes or pulls it, hold E to drag it.
	cellar_door = prop._door(hinge, latch, _v(d.swing), float(d.height), float(d.width), prop.HOUSE_DIR + "house_leaf_cellar.glb",
		str(d.label), float(d.angle) / 100.0, false, float(d.width))

## An old round switch on the panelling beside the cellar door: a brass plate, a bakelite toggle, a conduit up to the
## landing above.
func _switch() -> void:
	var s: Dictionary = lb.switch
	var p := _at(s.pos)
	var n := _v(s.normal).normalized()
	switch_node = SwitchScript.new()
	switch_node.name = "Cellar light switch"
	switch_node.basement = self
	add_child(switch_node)
	# Local frame: -Z out of the wall (toward the player), Y up.
	switch_node.global_transform = Transform3D(Basis.looking_at(n, Vector3.UP), p)
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(.3, .22, .1)
	brass.metallic = .85
	brass.roughness = .45
	var bakelite := StandardMaterial3D.new()
	bakelite.albedo_color = Color(.07, .04, .025)
	bakelite.roughness = .3
	var iron: Material = prop.mats.get("iron", brass)
	_mesh(switch_node, _cyl(.052, .052, .008), brass, Vector3(0, 0, -.004), Basis(Vector3.RIGHT, PI * .5))
	_mesh(switch_node, _cyl(.03, .034, .02), bakelite, Vector3(0, 0, -.016), Basis(Vector3.RIGHT, PI * .5))
	_lever = Node3D.new()
	_lever.position = Vector3(0, 0, -.026)
	switch_node.add_child(_lever)
	var lever_mesh := BoxMesh.new()
	lever_mesh.size = Vector3(.012, .04, .012)
	_mesh(_lever, lever_mesh, bakelite, Vector3(0, .016, -.004))
	_lever.rotation.x = -.5
	# Conduit up to the soffit under the landing, a screw at either side of the plate.
	var up_to := origin.y + 1.93
	var conduit := _cyl(.009, .009, up_to - p.y - .05)
	_mesh(switch_node, conduit, iron, Vector3(0, .05 + (up_to - p.y - .05) * .5, -.012))
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	switch_node.add_child(body)
	var c := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(.16, .16, .06)
	c.shape = shape
	c.position = Vector3(0, 0, -.03)
	c.set_meta("surface", "wood")
	body.add_child(c)
	_click = AudioStreamPlayer3D.new()
	_click.stream = _audio("switch_click")
	_click.unit_size = 2.0
	_click.max_distance = 14.0
	_click.volume_db = -4.0
	switch_node.add_child(_click)

## The usable switch (players.gd finds it through its StaticBody3D child in "usables").
class SwitchScript extends Node3D:
	var basement: Node3D
	func _ready() -> void:
		add_to_group("usables")
		add_to_group("nichols_switch")
	func prompt_text() -> String:
		return "Turn off the light" if basement.lights_on else "Turn on the light"
	func toggle() -> void:
		basement.set_basement_lights(not basement.lights_on)

func set_basement_lights(on: bool, instant := false) -> void:
	if on == lights_on and not instant:
		return
	lights_on = on
	_probe_refresh = 1.9
	if is_instance_valid(_click):
		_click.pitch_scale = _rng.randf_range(.92, 1.06)
		_click.play()
	if is_instance_valid(_lever):
		var tw := create_tween()
		tw.tween_property(_lever, "rotation:x", .5 if on else -.5, .06)
	for i in bulbs.size():
		var b := bulbs[i]
		if on:
			# Old wiring: they come on one after another, stuttering before they settle.
			b.delay = 0.0 if instant else .08 + i * .11 + _rng.randf_range(0, .25)
			b.stutter = 0.0 if instant else _rng.randf_range(.15, .55)
			b.timer = _rng.randf_range(1.0, 5.0)
			if instant:
				b.level = 1.0
		else:
			b.delay = 0.0
			b.stutter = 0.0

func is_lit() -> bool:
	return lights_on

# ------------------------------------------------------------------------------------------------ bulbs

func _cyl(top: float, bottom: float, height: float, segments := 10) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	return m

func _mesh(parent: Node3D, mesh: Mesh, material: Material, at := Vector3.ZERO, basis := Basis.IDENTITY, layers := BASEMENT_LAYER) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.transform = Transform3D(basis, at)
	mi.layers = layers if parent != switch_node and not (switch_node != null and switch_node.is_ancestor_of(parent)) else INTERIOR_LAYER
	parent.add_child(mi)
	return mi

## A segment of cord, chain or rod between two points (parent space).
func _rod(parent: Node3D, a: Vector3, b: Vector3, r: float, material: Material, layers := BASEMENT_LAYER) -> void:
	var d := b - a
	if d.length() < .001:
		return
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < .9 else Vector3.RIGHT).normalized()
	var mi := _mesh(parent, _cyl(r, r, d.length(), 6), material, (a + b) * .5, Basis(x, y, x.cross(y)), layers)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _bulbs() -> void:
	var cord := StandardMaterial3D.new()
	cord.albedo_color = Color(.03, .026, .022)
	cord.roughness = .8
	var bakelite := StandardMaterial3D.new()
	bakelite.albedo_color = Color(.06, .035, .02)
	bakelite.roughness = .35
	var enamel := StandardMaterial3D.new()
	enamel.albedo_color = Color(.08, .12, .09)
	enamel.roughness = .35
	enamel.metallic = .3
	var wire: Material = prop.mats.get("cage iron", cord)
	var i := 0
	for spec: Dictionary in lb.get("lights", []):
		var p := _at(spec.pos)
		var top := _at(spec.top)
		var kind := str(spec.kind)
		var room := str(spec.room)
		var layers := BASEMENT_LAYER | (INTERIOR_LAYER if room == "shaft" else 0)
		var fixture := Node3D.new()
		fixture.name = "Bulb %d (%s)" % [i, room]
		add_child(fixture)
		fixture.global_position = p
		_rod(fixture, top - p, Vector3(0, .07, 0), .004 if kind != "cage" else .006, cord, layers)
		var socket := _mesh(fixture, _cyl(.017, .022, .06), bakelite, Vector3(0, .045, 0), Basis.IDENTITY, layers)
		socket.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if kind == "pull":
			_rod(fixture, Vector3(.012, .02, 0), Vector3(.014, -.26, .004), .0018, wire, layers)
		if kind == "cage":
			var shade := _mesh(fixture, _cyl(.045, .16, .09, 18), enamel, Vector3(0, .05, 0), Basis.IDENTITY, layers)
			shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var ring := TorusMesh.new()
			ring.inner_radius = .07
			ring.outer_radius = .078
			ring.rings = 16
			ring.ring_segments = 4
			_mesh(fixture, ring, wire, Vector3(0, -.09, 0), Basis.IDENTITY, layers).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for k in 4:
				var a := TAU * k / 4.0 + .4
				_rod(fixture, Vector3(cos(a) * .15, .005, sin(a) * .15), Vector3(cos(a) * .074, -.09, sin(a) * .074), .003, wire, layers)
		# The bulb: clear glass round a filament glow.
		var glass := StandardMaterial3D.new()
		glass.albedo_color = Color(.35, .33, .3)
		glass.roughness = .12
		glass.emission_enabled = true
		glass.emission = BULB_COLOR
		glass.emission_energy_multiplier = 0.0
		var bulb := SphereMesh.new()
		bulb.radius = .03
		bulb.height = .075 if kind != "dead" else .04
		bulb.radial_segments = 12
		bulb.rings = 6
		var bulb_mi := _mesh(fixture, bulb, glass, Vector3(0, -.01, 0), Basis.IDENTITY, layers)
		bulb_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stats.bulbs += 1
		if kind == "dead":
			glass.albedo_color = Color(.08, .07, .06)
			i += 1
			continue
		var light := OmniLight3D.new()
		light.name = "Light"
		light.light_color = BULB_COLOR
		light.light_energy = 0.0
		# Weak bulbs: pools of light with dark between them.
		light.omni_range = 6.0 if room == "shaft" else 6.2
		light.omni_attenuation = 1.3
		light.light_cull_mask = layers
		light.shadow_enabled = bool(spec.shadow)
		light.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
		light.shadow_bias = .04
		light.shadow_normal_bias = 1.2
		light.light_specular = .35
		light.light_volumetric_fog_energy = .9
		light.visible = false
		fixture.add_child(light)
		light.position = Vector3(0, -.03, 0)
		var hum := AudioStreamPlayer3D.new()
		hum.stream = _audio("bulb_hum", true)
		hum.unit_size = .9
		hum.max_distance = 6.0
		hum.volume_db = -22.0
		fixture.add_child(hum)
		var buzz: AudioStreamPlayer3D = null
		if float(spec.flicker) > .3:
			buzz = AudioStreamPlayer3D.new()
			buzz.stream = _audio("arc_buzz")
			buzz.unit_size = 1.4
			buzz.max_distance = 10.0
			buzz.volume_db = -12.0
			fixture.add_child(buzz)
		bulbs.append({"light": light, "glass": glass, "energy": float(spec.energy), "flicker": float(spec.flicker), "room": room,
			"hum": hum, "buzz": buzz, "level": 0.0, "delay": 0.0, "stutter": 0.0, "step": 0.0, "stutter_level": 0.0,
			"timer": _rng.randf_range(1, 5), "phase": _rng.randf() * TAU})
		stats.lights += 1
		i += 1

func _flicker(b: Dictionary, delta: float) -> void:
	var want := 0.0
	if lights_on:
		if b.delay > 0.0:
			b.delay -= delta
		else:
			want = 1.0
			b.timer -= delta
			if b.stutter > 0.0:
				b.stutter -= delta
				b.step -= delta
				if b.step <= 0.0:
					b.step = _rng.randf_range(.025, .09)
					b.stutter_level = [0.0, 0.0, .1, .35, .8, 1.0][_rng.randi() % 6]
				want = b.stutter_level
			elif b.timer <= 0.0 and flicker_enabled:
				if _rng.randf() < b.flicker:
					b.stutter = _rng.randf_range(.06, .35) * (1.0 + 3.0 * b.flicker * b.flicker)
					if b.buzz != null and b.light.visible:
						(b.buzz as AudioStreamPlayer3D).pitch_scale = _rng.randf_range(.9, 1.1)
						(b.buzz as AudioStreamPlayer3D).play()
				b.timer = _rng.randf_range(1.2, 6.0) * (1.5 - b.flicker)
			# Weak supply: the failing ones never quite hold steady.
			want *= 1.0 - .08 * b.flicker * (.5 + .5 * sin(_t * 7.3 + b.phase)) * (.5 + .5 * sin(_t * 1.9 + b.phase * 2.0))
	b.level = lerpf(b.level, want, 1.0 - exp(-38.0 * delta))
	var light := b.light as OmniLight3D
	light.light_energy = b.energy * 2.1 * b.level
	light.visible = b.level > .01
	(b.glass as StandardMaterial3D).emission_energy_multiplier = b.level * 9.0
	var hum := b.hum as AudioStreamPlayer3D
	if b.level > .3 and not hum.playing:
		hum.play(_rng.randf() * 2.5)
	elif b.level <= .3 and hum.playing:
		hum.stop()

# ------------------------------------------------------------------------------------------------ air: probes, dust

## Each space gets a reflection probe whose ambient is near black, warming a little when its bulbs are on (their light
## bouncing off the stone), and a faint dust in the air for the bulbs' halos.
func _air() -> void:
	for room: Dictionary in lb.get("rooms", []):
		var a := _v(room.lo)
		var c := _v(room.hi)
		var lo := Vector3(minf(a.x, c.x), minf(a.y, c.y), minf(a.z, c.z))
		var hi := Vector3(maxf(a.x, c.x), maxf(a.y, c.y), maxf(a.z, c.z))
		var probe := ReflectionProbe.new()
		probe.name = ("Probe " + str(room.name)).validate_node_name()
		probe.size = (hi - lo) + Vector3(.1, .1, .1)
		probe.position = origin + (lo + hi) * .5
		probe.interior = true
		probe.box_projection = true
		probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
		probe.ambient_color = Color(.006, .006, .008)
		probe.ambient_color_energy = 1.0
		probe.intensity = .3
		probe.cull_mask = BASEMENT_LAYER | INTERIOR_LAYER
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		add_child(probe)
		if RenderingServer.get_current_rendering_method() != "gl_compatibility":
			var fog := FogVolume.new()
			fog.name = ("Dust " + str(room.name)).validate_node_name()
			fog.size = hi - lo
			fog.position = origin + (lo + hi) * .5
			var fm := FogMaterial.new()
			fm.density = .012 if str(room.name) != "shaft" else .008
			fm.albedo = Color(.82, .78, .7)
			fm.edge_fade = .2
			fog.material = fm
			add_child(fog)
		_rooms.append({"name": str(room.name), "probe": probe})

func _room_light(room: String) -> float:
	var total := 0.0
	var n := 0
	for b in bulbs:
		if b.room == room or (room == "passage" and b.room in ["cellar", "corridor"]):
			total += b.level * b.energy
			n += 1
	return total / maxf(n, 1)

# ------------------------------------------------------------------------------------------------ props

## Darker, matt finishes for models whose scans came out too pale for an unlit cellar.
const RETINT := {"old_tyre": Color(.035, .033, .032), "metal_office_desk": Color(.2, .21, .2)}

func _p(name_: String, x: float, depth: float, up: float, yaw := 0.0, scale := 1.0, tilt := Vector3.ZERO) -> Node3D:
	var node: Node3D = prop._model(name_, bl(x, depth, up), yaw, scale, true, tilt, BASEMENT_LAYER)
	if node != null:
		stats.props += 1
		if RETINT.has(name_):
			for child in node.find_children("*", "MeshInstance3D", true, false):
				var mi := child as MeshInstance3D
				for k in mi.mesh.get_surface_count():
					var m := mi.get_active_material(k) as BaseMaterial3D
					if m != null:
						m = m.duplicate() as BaseMaterial3D
						m.albedo_color = RETINT[name_]
						m.roughness = .85
						m.next_pass = null
						mi.set_surface_override_material(k, m)
	return node

func _props() -> void:
	var bf := float(lb.floors.cellar)
	var cf := float(lb.floors.corridor)
	# Cellar, south-west: barrels and an old iron stove with its flue into the joists.
	_p("wine_barrel_01", -11.45, 18.74, bf, 20.0)
	_p("barrel_01", -10.65, 18.75, bf, 0.0)
	_p("barrel_stove", -9.45, 18.62, bf, 180.0)
	_rod(self, bl(-9.45, 18.62, bf + .86), bl(-9.45, 18.62, -.3), .07, prop.mats.get("pipe"))
	# Along the north wall: shelving, a tool chest; boxes and a tyre.
	_p("wooden_display_shelves_01", -8.3, 11.4, bf, 90.0)
	_p("metal_tool_chest", -6.7, 11.35, bf, 0.0)
	_p("painted_wooden_shelves", -5.5, 11.3, bf, 0.0)
	_p("cardboard_box_01", -7.4, 11.4, bf, 8.0)
	_p("old_tyre", -4.7, 12.4, bf + .01, 25.0, 1.0, Vector3(90, 0, 0))
	_p("mousetrap", -9.9, 12.95, bf, 30.0)
	# East wall, north of the hole: racks, a step ladder, a gas tank.
	_p("worn_metal_rack", -.68, 12.3, bf, -90.0)
	_p("steel_frame_shelves_02", -.62, 13.65, bf, -90.0)
	_p("cardboard_box_01", -1.35, 12.0, bf, 70.0)
	_p("cardboard_box_01", -1.4, 12.05, bf + .35, 55.0)
	_p("wooden_ladder", -1.45, 14.85, bf, -80.0)
	_p("propane_tank", -2.2, 12.2, bf, 0.0)
	# Crates by the posts, garbage bags by the tarp, a bucket at the drain.
	_p("wooden_crate_01", -9.0, 13.3, bf, 12.0)
	_p("wooden_crate_01", -9.05, 13.32, bf + .36, 4.0)
	_p("trashbag", -9.8, 16.4, bf, 30.0)
	_p("trashbag", -9.35, 15.95, bf, 120.0)
	_p("wooden_bucket_01", -5.85, 17.15, bf, 0.0)
	_p("can_rusted", -3.1, 18.55, bf + .89, 0.0)
	_p("can_rusted", -10.2, 14.3, bf + .01, 40.0, 1.0, Vector3(90, 0, 0))
	# The work bench: a vice, saws, a machete, a wrench; a hatchet left in the chopping block.
	_p("bench_vice_01", -4.25, 18.7, bf + .88, 180.0)
	_p("handsaw_wood", -3.4, 18.7, bf + .89, 90.0, 1.0, Vector3(0, 0, 90))
	_p("rusted_hacksaw", -2.6, 18.62, bf + .89, 10.0, 1.0, Vector3(90, 0, 0))
	_p("machete", -3.3, 19.0, bf + .9, 90.0, 1.0, Vector3(90, 0, 0))   # 0.26: clear of the vice and the saw (it sprang off the bench)
	_p("pipe_wrench", -2.25, 18.75, bf + .89, 40.0, 1.0, Vector3(90, 0, 0))
	_p("bolt_cutters_01", -2.05, 18.25, bf, 90.0, 1.0, Vector3(12, 0, 0))
	_p("hatchet", -6.82, 17.86, bf + .74, 60.0, 1.0, Vector3(28, 0, 0))
	# What broke the wall: a sledgehammer against it, a crowbar on the floor.
	_p("sledgehammer_01", -.52, 15.75, bf, 90.0, 1.0, Vector3(0, 0, 16))
	_p("crowbar_01", -1.0, 16.2, bf + .02, 30.0, 1.0, Vector3(90, 0, 0))
	_p("street_rat", -8.95, 16.55, bf, 140.0, 1.4, Vector3(0, 0, 90))
	# The tunnel: a metal desk by the mouth (a first-aid box, a lantern), a stool, junk by the iron door.
	_p("metal_office_desk", 3.35, 17.62, cf, 180.0)
	_p("medical_box", 3.85, 17.6, cf + .8, -10.0)
	_p("lantern_01", 2.95, 17.5, cf + .8, 0.0)
	_p("metal_stool_01", 4.85, 17.45, cf, 0.0)
	_p("wooden_crate_01", 2.1, 15.85, cf, 0.0)
	_p("cardboard_box_01", 11.8, 17.75, cf, 20.0)
	_p("trashbag", 11.1, 17.8, cf, 60.0)
	_p("wooden_bucket_01", 8.05, 17.45, cf, 0.0)
	_p("street_rat", 7.6, 16.6, cf, 230.0, 1.4, Vector3(0, 0, 90))

## In the tunnel something wrapped in black plastic hangs from a hook, turning slowly; it has dripped for days.
func _bundle_on_hook() -> void:
	var cf := float(lb.floors.corridor)
	# Off the walking line, by the north wall between the desk and the cages.
	var top := bl(6.4, 16.3, -.47)
	_bundle = Node3D.new()
	_bundle.name = "Hanging bundle"
	add_child(_bundle)
	_bundle.global_position = top
	var chain: Material = prop.mats.get("chain")
	var tarp: Material = prop.mats.get("tarp")
	var cord: Material = prop.mats.get("cord")
	_rod(_bundle, Vector3.ZERO, Vector3(0, -.95, 0), .01, chain)
	var hook := TorusMesh.new()
	hook.inner_radius = .045
	hook.outer_radius = .058
	hook.rings = 12
	hook.ring_segments = 5
	_mesh(_bundle, hook, chain, Vector3(0, -1.0, 0), Basis(Vector3.FORWARD, PI * .5))
	# Twisted neck where it is tied to the hook, a heavy body, a lump sagging at the bottom.
	var plastic := (tarp as StandardMaterial3D).duplicate() as StandardMaterial3D
	plastic.roughness = .28
	plastic.metallic_specular = .7
	var neck := CylinderMesh.new()
	neck.top_radius = .025
	neck.bottom_radius = .13
	neck.height = .3
	_mesh(_bundle, neck, plastic, Vector3(0, -1.2, 0), Basis.from_euler(Vector3(0, 0, .08)))
	var body_mesh := SphereMesh.new()
	body_mesh.radius = .25
	body_mesh.height = .95
	body_mesh.radial_segments = 16
	body_mesh.rings = 10
	_mesh(_bundle, body_mesh, plastic, Vector3(.02, -1.62, 0), Basis.from_euler(Vector3(.06, .5, -.07)).scaled(Vector3(1.0, 1.0, .78)))
	var lump := SphereMesh.new()
	lump.radius = .2
	lump.height = .42
	_mesh(_bundle, lump, plastic, Vector3(.07, -1.98, .03), Basis.from_euler(Vector3(.2, .3, .25)).scaled(Vector3(1.1, 1.0, .8)))
	for y in [-1.3, -1.72]:
		var band := TorusMesh.new()
		band.inner_radius = .13 if y > -1.4 else .2
		band.outer_radius = band.inner_radius + .014
		band.rings = 14
		band.ring_segments = 3
		_mesh(_bundle, band, cord, Vector3(.02, y, 0), Basis.from_euler(Vector3(.06, 0, -.04)).scaled(Vector3(1, 1, .8)))
	# Its lowest point stays wet: a dark cap where it drips.
	var wet := StandardMaterial3D.new()
	wet.albedo_color = Color(.07, .012, .01)
	wet.roughness = .2
	var cap := SphereMesh.new()
	cap.radius = .13
	cap.height = .14
	_mesh(_bundle, cap, wet, Vector3(0, -2.07, 0))
	stats["bundle_floor_gap"] = (top.y - 2.15) - (origin.y + cf)
	# Blood has run down the plastic from the bottom of the bundle (a decal that sways with it).
	var t := _texture_set("drag_c")
	var streak := Decal.new()
	streak.texture_albedo = t[0]
	streak.texture_normal = t[1]
	streak.texture_orm = t[2]
	streak.modulate = HorrorLiquid.TINT
	streak.size = Vector3(.85, .7, .42)
	streak.cull_mask = BASEMENT_LAYER
	streak.normal_fade = 0.0
	streak.basis = Basis(Vector3.DOWN, Vector3.BACK, Vector3.DOWN.cross(Vector3.BACK))
	_bundle.add_child(streak)
	streak.position = Vector3(.02, -1.82, 0)
	stats.decals += 1
	var solid := StaticBody3D.new()
	solid.collision_layer = 2
	solid.collision_mask = 0
	_bundle.add_child(solid)
	var shape := CapsuleShape3D.new()
	shape.radius = .2
	shape.height = 1.2
	var c := CollisionShape3D.new()
	c.shape = shape
	c.position = Vector3(0, -1.6, 0)
	c.set_meta("surface", "carpet")
	solid.add_child(c)

## The tunnel's iron door: chained, a new padlock. It will not open (yet).
func _locked_door() -> void:
	var d: Dictionary = lb.secret_door
	var p := _at(d.pos)
	var n := _v(d.normal).normalized()
	var lock := LockedScript.new()
	lock.name = "Nichols iron door"
	lock.label = "the iron door"
	lock.lines = LOCK_LINES
	add_child(lock)
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	lock.add_child(body)
	var c := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(float(d.width), float(d.height), .04)
	c.shape = box
	c.set_meta("surface", "metal")
	body.add_child(c)
	lock.global_transform = Transform3D(Basis.looking_at(n, Vector3.UP), p + n * .03 + Vector3.UP * float(d.height) * .5)

# ------------------------------------------------------------------------------------------------ kitchen

## The refrigerator stands open with its bulb lit and its motor running: the house has power, and someone stocks it.
func _kitchen() -> void:
	var f: Dictionary = lb.get("fridge", {})
	if not f.is_empty():
		var bulb := OmniLight3D.new()
		bulb.name = "Refrigerator bulb"
		bulb.light_color = Color(1.0, .86, .66)
		bulb.light_energy = .55
		bulb.omni_range = 3.6
		bulb.omni_attenuation = 1.6
		bulb.light_cull_mask = INTERIOR_LAYER
		bulb.shadow_enabled = true
		bulb.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
		bulb.shadow_bias = .03
		bulb.light_volumetric_fog_energy = .4
		add_child(bulb)
		bulb.global_position = _at(f.light)
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color(.9, .85, .75)
		glow.emission_enabled = true
		glow.emission = Color(1.0, .86, .66)
		glow.emission_energy_multiplier = 5.0
		var lamp := SphereMesh.new()
		lamp.radius = .02
		lamp.height = .04
		var holder := Node3D.new()
		add_child(holder)
		holder.global_position = _at(f.light) + Vector3(0, .05, 0)
		_mesh(holder, lamp, glow, Vector3.ZERO, Basis.IDENTITY, INTERIOR_LAYER)
		var hum := AudioStreamPlayer3D.new()
		hum.name = "Refrigerator"
		hum.stream = _audio("fridge_hum", true)
		hum.unit_size = 1.3
		hum.max_distance = 11.0
		hum.volume_db = -13.0
		hum.autoplay = true
		add_child(hum)
		hum.global_position = _at(f.hum)
	# The power strip's lit rocker: a pinprick of orange on the floor beside the refrigerator.
	var j: Dictionary = lb.get("jumper", {})
	if not j.is_empty():
		var pin := OmniLight3D.new()
		pin.name = "Power strip light"
		pin.light_color = Color(1.0, .45, .1)
		pin.light_energy = .05
		pin.omni_range = 1.1
		pin.omni_attenuation = 2.8
		pin.light_cull_mask = INTERIOR_LAYER
		add_child(pin)
		pin.global_position = _at(j.strip) + Vector3(0, .03, 0)
	var k: Dictionary = lb.get("kitchen", {})
	if k.is_empty():
		return
	var table := _at(k.table)
	var range_top := _at(k.range)
	for spec: Array in [["wooden_cutting_board", Vector3(-.25, 0, .05), 15.0], ["fish_knife", Vector3(-.2, .045, .05), 70.0],
			["wooden_bowl_01", Vector3(.45, 0, -.15), 0.0], ["jug_01", Vector3(.6, 0, .2), 40.0]]:
		var node: Node3D = prop._model(spec[0], table + spec[1], spec[2], 1.0, true, Vector3.ZERO, INTERIOR_LAYER)
		if node != null:
			stats.props += 1
	for spec: Array in [["pot_enamel_01", Vector3(-.2, 0, .16), 10.0], ["brass_pan_01", Vector3(.2, 0, -.15), 100.0]]:
		if prop._model(spec[0], range_top + spec[1], spec[2], 1.0, true, Vector3.ZERO, INTERIOR_LAYER) != null:
			stats.props += 1

# ------------------------------------------------------------------------------------------------ blood

func _texture_set(kind: String) -> Array:
	if not _tex.has(kind):
		var generated := HorrorLiquid.texture_set(kind)
		_tex[kind] = generated if not generated.is_empty() else [load(BLOOD + kind + "_albedo.png"), load(BLOOD + kind + "_normal.png"), load(BLOOD + kind + "_orm.png")]
	return _tex[kind]

## A decal lying on a surface whose normal is `up`, its texture's u running along `along`; size is (length, depth,
## width).
func decal(kind: String, at: Vector3, along: Vector3, up: Vector3, size: Vector3, alpha := 1.0, mask := INTERIOR_LAYER | BASEMENT_LAYER) -> Decal:
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
	d.cull_mask = mask
	d.normal_fade = .3
	d.upper_fade = .25
	d.lower_fade = .25
	d.distance_fade_enabled = true
	d.distance_fade_begin = 30.0
	d.distance_fade_length = 6.0
	add_child(d)
	d.global_position = at
	HorrorLiquid.finish(d, not HorrorLiquid.texture_set(kind).is_empty())
	stats.decals += 1
	return d

const DRAGS := ["drag_a", "drag_b", "drag_c"]

func _blood() -> void:
	var pts: Array[Vector3] = []
	for p: Array in lb.get("trail", []):
		# It begins just inside the front door: nothing on the porch gives it away.
		if float(p[2]) > .55:
			continue
		pts.append(_at(p))
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var seg := b - a
		var length := seg.length()
		if length < .05:
			continue
		var stair := absf(seg.y) > .2
		var side := seg.cross(Vector3.UP).normalized()
		var up := Vector3.UP if not stair else side.cross(seg).normalized()
		if up.y < 0.0:
			up = -up
		var mask := INTERIOR_LAYER | BASEMENT_LAYER
		var n := maxi(1, int(ceil(length / 1.05)))
		for k in n:
			var c := a + seg * ((k + .5) / n) + side * _rng.randf_range(-.06, .06)
			var dir := seg.rotated(up, _rng.randf_range(-.08, .08))
			decal(DRAGS[_rng.randi() % 3], c, dir, up, Vector3(length / n * 1.4, .55 if stair else .3, _rng.randf_range(.5, .68)),
				_rng.randf_range(.88, 1.0), mask)
			# An older trail beside it, browner and fainter: this was not the first one.
			if not stair and _rng.randf() < .55:
				decal(DRAGS[_rng.randi() % 3], c + side * _rng.randf_range(.22, .34) * (1 if _rng.randf() < .5 else -1), dir, up,
					Vector3(length / n * 1.3, .3, _rng.randf_range(.35, .5)), _rng.randf_range(.35, .55), mask)
			if _rng.randf() < .45:
				decal("drops", c + side * _rng.randf_range(-.6, .6) + seg.normalized() * _rng.randf_range(-.4, .4), side, up,
					Vector3(.45, .3, .45), _rng.randf_range(.7, 1.0), mask)
		if i < 8:
			for k in 6:
				sight_points.append(a + seg * (k / 6.0) + Vector3.UP * .03)
	var bf0 := float(lb.floors.cellar)
	var branch: Array[Vector3] = [bl(-3.4, 11.6, bf0), bl(-4.4, 13.6, bf0), bl(-5.3, 15.6, bf0), bl(-6.15, 17.25, bf0)]
	for i in branch.size() - 1:
		var seg := branch[i + 1] - branch[i]
		var n := maxi(1, int(ceil(seg.length() / 1.05)))
		for k in n:
			decal(DRAGS[_rng.randi() % 3], branch[i] + seg * ((k + .5) / n), seg, Vector3.UP, Vector3(seg.length() / n * 1.35, .3, .5),
				_rng.randf_range(.45, .65))
	var s: Dictionary = lb.spots
	# Where they were set down: the stair foot, by the drain, under the tarp, at the iron door, under the bundle.
	decal("pool", _at(s.shaft_foot) + Vector3(0, .02, 0), Vector3.RIGHT, Vector3.UP, Vector3(1.2, .3, 1.0))
	decal("pool", _at(s.drain) + Vector3(-.3, .02, .1), Vector3.FORWARD, Vector3.UP, Vector3(1.8, .3, 1.5))
	decal("pool", _at(s.tarp) + Vector3(.7, .02, -.4), Vector3.RIGHT, Vector3.UP, Vector3(1.0, .3, .8), .85)
	decal("pool", _at(s.steel_door) + Vector3(.75, .02, 0), Vector3.RIGHT, Vector3.UP, Vector3(1.0, .3, .9))
	decal("pool", bl(6.45, 16.35, float(lb.floors.corridor) + .02), Vector3.RIGHT, Vector3.UP, Vector3(.8, .3, .7))
	# Splatter here and there: the wall behind the chopping block, the bench, the block, a cage floor, the sink.
	var bf := float(lb.floors.cellar)
	var cf := float(lb.floors.corridor)
	var south := Vector3(0, 0, 1)   # Blender -y (toward the front) in Godot, out of the cellar's south wall
	decal("drops", bl(-6.9, 19.17, bf + .75), Vector3.RIGHT, south, Vector3(1.1, .25, 1.0))
	decal("drops", bl(-6.4, 19.17, bf + .35), Vector3.RIGHT, south, Vector3(.6, .25, .6), .8)
	decal("drops", bl(-3.6, 18.8, bf + .89), Vector3.RIGHT, Vector3.UP, Vector3(.7, .2, .5))
	decal("pool", bl(-6.9, 17.9, bf + .77), Vector3.RIGHT, Vector3.UP, Vector3(.55, .12, .55), .9)
	decal("drops", bl(8.96, 15.75, cf + .03), Vector3.RIGHT, Vector3.UP, Vector3(.6, .12, .45))
	decal("drops", bl(8.35, 17.95, cf + .82), Vector3.RIGHT, Vector3.UP, Vector3(.5, .2, .4), .8)
	decal("drops", bl(4.9, 18.18, cf + .5), Vector3.RIGHT, Vector3(0, 0, 1), Vector3(.8, .25, .8), .7)
	decal("drops", bl(-2.3, 10.9, bf + .5), Vector3.RIGHT, Vector3(0, 0, 1), Vector3(.6, .2, .7), .7)
	decal("drops", bl(2.59, 8.85, .45), Vector3.FORWARD, Vector3.LEFT, Vector3(.6, .2, .5), .6, INTERIOR_LAYER)
	# The kitchen: the table top, the plates in the drainer, the sink, drops from the refrigerator to the table.
	var k: Dictionary = lb.get("kitchen", {})
	if not k.is_empty():
		var table := _at(k.table)
		decal("pool", table + Vector3(.1, .01, 0), Vector3.RIGHT, Vector3.UP, Vector3(1.0, .12, .7), .9, INTERIOR_LAYER)
		decal("drops", table + Vector3(-.5, .01, .2), Vector3.RIGHT, Vector3.UP, Vector3(.6, .12, .5), .9, INTERIOR_LAYER)
		var sink := _at(k.sink)
		decal("pool", sink + Vector3(0, -.2, 0), Vector3.RIGHT, Vector3.UP, Vector3(.6, .3, .45), .85, INTERIOR_LAYER)
		for dx in [-.65, .65]:
			decal("drops", sink + Vector3(dx, .05, 0), Vector3.RIGHT, Vector3.UP, Vector3(.45, .2, .4), .9, INTERIOR_LAYER)
		var f: Dictionary = lb.get("fridge", {})
		if not f.is_empty():
			var inside := _at(f.inside)
			decal("pool", inside + Vector3(0, -.55, 0), Vector3.RIGHT, Vector3.UP, Vector3(.4, .25, .4), .8, INTERIOR_LAYER)
			var floor_y := origin.y + .01
			var from := Vector3(inside.x - .9, floor_y, inside.z)
			var to := Vector3(table.x + .9, floor_y, table.z)
			for i in 5:
				var p := from.lerp(to, i / 4.0) + Vector3(_rng.randf_range(-.2, .2), 0, _rng.randf_range(-.25, .25))
				decal("drops", p, Vector3.RIGHT.rotated(Vector3.UP, _rng.randf() * TAU), Vector3.UP, Vector3(.5, .25, .5), .85, INTERIOR_LAYER)
	# The shelf that hid the hole was dragged through the dust to where it stands now.
	decal("scrape", bl(-.75, 17.55, bf + .01), Vector3(0, 0, -1), Vector3.UP, Vector3(1.9, .2, 1.0), .75)

# ------------------------------------------------------------------------------------------------ sound

func _audio(clip: String, loop := false) -> AudioStream:
	var path := AUDIO + clip + ".ogg"
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStream
	if loop and stream is AudioStreamOggVorbis:
		stream = stream.duplicate()
		(stream as AudioStreamOggVorbis).loop = true
	return stream

func _sounds() -> void:
	var s: Dictionary = lb.spots
	for at: Vector3 in [_at(s.tarp) + Vector3(0, .4, 0), bl(6.4, 16.3, -2.2)]:
		var flies := AudioStreamPlayer3D.new()
		flies.name = "Flies"
		flies.stream = _audio("flies", true)
		flies.unit_size = 1.1
		flies.max_distance = 9.0
		flies.volume_db = -9.0
		flies.autoplay = true
		add_child(flies)
		flies.global_position = at
	_drips = AudioStreamPlayer3D.new()
	_drips.name = "Drips"
	_drips.stream = _audio("drip")
	_drips.unit_size = 1.6
	_drips.max_distance = 12.0
	_drips.volume_db = -8.0
	add_child(_drips)
	_tone = AudioStreamPlayer.new()
	_tone.name = "Cellar tone"
	_tone.stream = _audio("cellar_tone", true)
	_tone.volume_db = -80.0
	add_child(_tone)

# ------------------------------------------------------------------------------------------------ runtime

func _process(delta: float) -> void:
	_t += delta
	for b in bulbs:
		_flicker(b, delta)
	for room in _rooms:
		var level := _room_light(room.name)
		(room.probe as ReflectionProbe).ambient_color = Color(.005, .005, .007).lerp(Color(.022, .023, .03), clampf(level * 1.6, 0, 1))
	# The probes re-capture shortly after the switch so the damp floors reflect the bulbs (or stop reflecting them).
	if _probe_refresh > 0.0:
		_probe_refresh -= delta
		var mode := ReflectionProbe.UPDATE_ALWAYS if _probe_refresh < .4 and _probe_refresh > 0.0 else ReflectionProbe.UPDATE_ONCE
		for room in _rooms:
			if (room.probe as ReflectionProbe).update_mode != mode:
				(room.probe as ReflectionProbe).update_mode = mode
	if is_instance_valid(_bundle):
		_bundle.rotation.y = sin(_t * .23) * .5
		_bundle.rotation.x = sin(_t * .41) * .012
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var below := 1.0 if prop.is_below(cam.global_position) else 0.0
		_below = lerpf(_below, below, 1.0 - exp(-2.0 * delta))
		if _tone != null and _tone.stream != null:
			if _below > .02 and not _tone.playing:
				_tone.play()
			elif _below <= .02 and _tone.playing:
				_tone.stop()
			_tone.volume_db = linear_to_db(maxf(_below, .0001)) - 15.0
		_drip_wait -= delta
		if _drip_wait <= 0.0 and _below > .5 and _drips != null and _drips.stream != null:
			_drip_wait = _rng.randf_range(1.8, 6.5)
			_drips.global_position = [bl(6.4, 16.3, -2.6), bl(8.35, 17.95, float(lb.floors.corridor) + .9), bl(-6.2, 17.6, -.5),
				bl(-11.0, 12.0, -.4)][_rng.randi() % 4]
			_drips.pitch_scale = _rng.randf_range(.8, 1.2)
			_drips.play()
		if not saw_blood and Engine.get_process_frames() % 4 == 0:
			_check_sight(cam)

## The first time the player looks at the trail from inside the house.
func _check_sight(cam: Camera3D) -> void:
	var eye := cam.global_position
	if not prop.is_inside(eye) or prop.is_below(eye):
		return
	var story := get_tree().get_first_node_in_group("story")
	if story == null or story.ui.dialogue_active():
		return
	var forward := -cam.global_basis.z
	var space := get_world_3d().direct_space_state
	for p in sight_points:
		if eye.distance_to(p) > 9.0 or not cam.is_position_in_frustum(p):
			continue
		if (p - eye).normalized().dot(forward) < .8:
			continue
		var q := PhysicsRayQueryParameters3D.create(eye, p + Vector3.UP * .06, 2)
		if space.intersect_ray(q):
			continue
		saw_blood = true
		story.ui.say("You", SIGHT_LINES, 3.2)
		return
