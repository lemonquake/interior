class_name InteriorStudioBuilder
extends InteriorBalconyBuilder
## The music studio behind the glass sliding door at screen-right of the rear wall: a 4.4 x 4.4 m
## room lined floor to ceiling with black wedge acoustic foam. It holds a guitar wall, a drum kit,
## a two-tier keyboard station and a gaming / production desk with two monitors. Instruments and
## gear are downloaded models (res://assets/models/studio, credits in game/licenses/THIRD_PARTY_MODELS.md)
## placed by InteriorModelKit. editor/bake_studio.gd bakes the result into res://scenes/studio/studio.tscn.
##
## Frame: room floor y=0, ceiling 2.9. Interior x -5.65..-1.25, z 2.9..7.3. The doorway in the
## living-room rear wall spans x -3.25..-1.24 below the header at y 2.4.

const StudioScript = preload("res://scripts/studio.gd")
const SlidingDoorScript = preload("res://scripts/sliding_door.gd")
const SX0 := -5.65
const SX1 := -1.25
const SZ0 := 2.9
const SZ1 := 7.3
const SH := 2.9
const FOAM := .05
const DOOR_X0 := -3.25
const DOOR_X1 := -1.24
const DOOR_H := 2.4
const DESK := Vector3(-2.6, 0, 6.745)
const DESK_TOP := .692

static func build(root: Node3D) -> Dictionary:
	var builder := InteriorStudioBuilder.new()
	builder._root = root
	builder.visual_layer = 1
	builder._stats = {"triangles_added": 0, "static_batches": 0, "colliders": 0, "props": [], "features": [], "dynamic_props": 0, "models": 0}
	builder._build_all()
	var stats: Dictionary = builder._stats
	builder.free()
	root.set_meta("studio_stats", stats)
	print("INTERIOR_STUDIO_BUILT ", JSON.stringify(stats))
	return stats

func _build_all() -> void:
	_root.set_script(StudioScript)
	_root.name = "Studio"
	_prepare_studio_materials()
	_shell = _static_body("StudioStructure", Vector3.ZERO)
	_build_shell()
	_build_foam()
	_build_led_cove()
	_build_fixed_glass()
	_commit(_root, "Studio detail - ")
	_build_door()
	_build_furniture()
	_build_instruments()
	_build_desk()
	_build_studio_lights()

# ---------------------------------------------------------------- materials

func _prepare_studio_materials() -> void:
	_pbr("floor", "dark_wooden_planks", 2.0, Color(.78, .74, .72), 1.0)
	_lib("wall", "warm_plaster", Color(.06, .06, .065))
	_lib("ceiling", "white_matte", Color(.045, .045, .05))
	_lib("black metal", "black_metal", Color(.07, .07, .075))
	_lib("aluminium", "black_metal", Color(.10, .10, .11))
	_lib("walnut", "walnut", Color(1, 1, 1))
	_lib("rubber", "rubber_black", Color(.03, .03, .03))
	var rug := _pbr("rug", "fabric_pattern_07", 1.2, Color(.16, .14, .16), 1.0, .6)
	rug.roughness = 1.0
	for spec: Array in [["foam", Color(.028, .028, .03)], ["foam grey", Color(.07, .07, .075)]]:
		var foam := StandardMaterial3D.new()
		foam.resource_name = "Studio / " + spec[0]
		foam.albedo_color = spec[1]
		foam.roughness = 1.0
		var noise := NoiseTexture2D.new()
		noise.width = 256
		noise.height = 256
		noise.seamless = true
		noise.as_normal_map = true
		noise.bump_strength = 6.0
		var fast := FastNoiseLite.new()
		fast.frequency = .09
		noise.noise = fast
		foam.normal_enabled = true
		foam.normal_texture = noise
		foam.uv1_scale = Vector3.ONE * 6.0
		_materials[spec[0]] = foam
	for spec: Array in [["led purple", Color(.62, .22, 1.0), 6.0], ["led blue", Color(.18, .45, 1.0), 5.0], ["neon pink", Color(1.0, .25, .62), 7.0]]:
		var led := StandardMaterial3D.new()
		led.resource_name = "Studio / " + spec[0]
		led.albedo_color = Color.BLACK
		led.emission_enabled = true
		led.emission = spec[1]
		led.emission_energy_multiplier = spec[2]
		_materials[spec[0]] = led
	var glass := StandardMaterial3D.new()
	glass.resource_name = "Studio / glass"
	glass.albedo_color = Color(.55, .62, .64, .16)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = .04
	glass.metallic_specular = 1.0
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials["glass"] = glass
	var etch := StandardMaterial3D.new()
	etch.resource_name = "Studio / glass etch"
	etch.albedo_color = Color(.9, .92, .92, .55)
	etch.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	etch.roughness = .5
	_materials["glass etch"] = etch

# ---------------------------------------------------------------- shell

func _build_shell() -> void:
	_feature("Studio room 4.4 x 4.4 m behind a glass sliding door")
	var cx := (SX0 + SX1) * .5
	var cz := (SZ0 + SZ1) * .5
	_box("Studio floor", Vector3(cx, -.1, (2.7 + SZ1 + .2) * .5), Vector3(SX1 - SX0 + .4, .2, SZ1 + .2 - 2.7), "floor", true)
	_box("Studio ceiling", Vector3(cx, SH + .1, cz), Vector3(SX1 - SX0 + .4, .2, SZ1 - SZ0 + .4), "ceiling", true)
	_box("Studio wall west", Vector3(SX0 - .1, SH * .5, cz + .1), Vector3(.2, SH, SZ1 - SZ0 + .2), "wall", true)
	_box("Studio wall east", Vector3(SX1 + .1, SH * .5, cz + .1), Vector3(.2, SH, SZ1 - SZ0 + .2), "wall", true)
	_box("Studio wall back", Vector3(cx, SH * .5, SZ1 + .1), Vector3(SX1 - SX0 + .4, SH, .2), "wall", true)
	# Door track, threshold and jamb trims (black anodised aluminium).
	_box("Door threshold", Vector3((DOOR_X0 + DOOR_X1) * .5, .006, 2.8), Vector3(DOOR_X1 - DOOR_X0, .012, .2), "aluminium")
	_box("Door head track", Vector3((DOOR_X0 + DOOR_X1) * .5, DOOR_H - .03, 2.8), Vector3(DOOR_X1 - DOOR_X0, .06, .2), "aluminium")
	for x in [DOOR_X0 + .015, DOOR_X1 - .015]:
		_box("Door jamb trim", Vector3(x, DOOR_H * .5, 2.8), Vector3(.03, DOOR_H, .2), "aluminium")
	# Skirting under the foam.
	for spec: Array in [[Vector3(SX0 + .03, .05, (SZ0 + SZ1) * .5), Vector3(.06, .1, SZ1 - SZ0)], [Vector3(SX1 - .03, .05, (SZ0 + SZ1) * .5), Vector3(.06, .1, SZ1 - SZ0)],
			[Vector3((SX0 + SX1) * .5, .05, SZ1 - .03), Vector3(SX1 - SX0, .1, .06)], [Vector3((SX0 + DOOR_X0) * .5, .05, SZ0 + .03), Vector3(DOOR_X0 - SX0, .1, .06)]]:
		_box("Skirting", spec[0], spec[1], "black metal")
	_box("Rug", Vector3(-3.55, .006, 4.75), Vector3(2.7, .012, 2.1), "rug")
	# Black lining over the living room's plaster where it faces into the studio (door wall,
	# header and the two jambs), so no pale seams show between the foam tiles.
	_box("Front wall lining", Vector3((SX0 + DOOR_X0) * .5, SH * .5, SZ0 + .006), Vector3(DOOR_X0 - SX0, SH, .012), "wall")
	_box("Header lining", Vector3((DOOR_X0 + DOOR_X1) * .5, (DOOR_H + SH) * .5, SZ0 + .006), Vector3(DOOR_X1 - DOOR_X0 + .02, SH - DOOR_H, .012), "wall")
	for x in [DOOR_X0 + .004, DOOR_X1 - .004]:
		_box("Jamb lining", Vector3(x, DOOR_H * .5, 2.86), Vector3(.008, DOOR_H, .08), "aluminium")

# ---------------------------------------------------------------- acoustic foam

## Wedge foam tiles (0.5 m, four ridges, alternating direction) over a wall rectangle.
## `origin` is the wall's lower-left corner seen from inside the room; `right`/`up` span it and
## `normal` points into the room.
func _foam_wall(origin: Vector3, right: Vector3, normal: Vector3, width: float, height: float, up := Vector3.UP, skip := Rect2()) -> void:
	var cols := floori(width / .5)
	var rows := floori(height / .5)
	var margin_x := (width - cols * .5) * .5
	var margin_y := (height - rows * .5) * .5
	for r in rows:
		for c in cols:
			var u0 := margin_x + c * .5
			var v0 := margin_y + r * .5
			if skip.has_area() and Rect2(u0, v0, .5, .5).intersects(skip):
				continue
			var key := "foam grey" if (r * 7 + c * 3) % 11 == 0 else "foam"
			var corner := origin + right * u0 + up * v0
			_foam_tile(corner, right, up, normal, (r + c) % 2 == 0, key)

func _foam_tile(corner: Vector3, right: Vector3, up: Vector3, normal: Vector3, vertical: bool, key: String) -> void:
	var size := .49
	var a := right if vertical else up
	var b := up if vertical else right
	var base := corner + (right + up) * .005
	# Backing slab.
	_quad([base + normal * .012, base + right * size + normal * .012, base + (right + up) * size + normal * .012, base + up * size + normal * .012], normal, key, Vector2(size, size))
	var ridges := 4
	var w := size / ridges
	for i in ridges:
		var p0 := base + a * (i * w) + normal * .012
		var p1 := p0 + a * w
		var crest := p0 + a * (w * .5) + normal * (FOAM - .012)
		var length := b * size
		_tri_quad(p0, crest, crest + length, p0 + length, key, normal)
		_tri_quad(crest, p1, p1 + length, crest + length, key, normal)
		_tri(p0, p1, crest, key, -b)
		_tri(p1 + length, p0 + length, crest + length, key, b)

func _tri_quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, key: String, hint: Vector3) -> void:
	_tri(p0, p1, p2, key, hint)
	_tri(p0, p2, p3, key, hint)

## One triangle, wound so its face (and normal) points along `hint`.
func _tri(p0: Vector3, p1: Vector3, p2: Vector3, key: String, hint: Vector3) -> void:
	var normal := (p1 - p0).cross(p2 - p0).normalized()
	if normal.dot(hint) < 0.0:
		var swap := p1
		p1 = p2
		p2 = swap
		normal = -normal
	var tool := _builder(key)
	for p in [p0, p2, p1]:
		tool.set_normal(normal)
		tool.set_uv(Vector2(p.x + p.z, p.y))
		tool.add_vertex(p)
	_stats.triangles_added += 1

func _build_foam() -> void:
	_feature("Black wedge acoustic foam on every wall and the ceiling")
	var bottom := .12
	var top := SH - .1
	# West (guitar wall), east, back and front walls; the front skips the doorway.
	_foam_wall(Vector3(SX0, bottom, SZ1), Vector3.FORWARD, Vector3.RIGHT, SZ1 - SZ0, top - bottom)
	_foam_wall(Vector3(SX1, bottom, SZ0), Vector3.BACK, Vector3.LEFT, SZ1 - SZ0, top - bottom)
	_foam_wall(Vector3(SX1, bottom, SZ1), Vector3.LEFT, Vector3.FORWARD, SX1 - SX0, top - bottom)
	_foam_wall(Vector3(SX0, bottom, SZ0), Vector3.RIGHT, Vector3.BACK, DOOR_X0 - SX0 - .02, top - bottom)
	_foam_wall(Vector3(DOOR_X0, DOOR_H + .02, SZ0), Vector3.RIGHT, Vector3.BACK, DOOR_X1 - DOOR_X0, top - DOOR_H - .02)
	# Ceiling clouds: foam panels hung over the listening and drum positions.
	for spec: Array in [[Vector3(-3.35, SH - .02, 5.6), 1.5, 1.5], [Vector3(-5.1, SH - .02, 6.2), 1.0, 1.5]]:
		var c: Vector3 = spec[0]
		_foam_wall(c + Vector3(-spec[1] * .5, 0, -spec[2] * .5), Vector3.RIGHT, Vector3.DOWN, spec[1], spec[2], Vector3.BACK)

# ---------------------------------------------------------------- LEDs

func _build_led_cove() -> void:
	_feature("Purple LED cove around the ceiling and a HARMONIK neon over the desk")
	var y := SH - .06
	var inset := FOAM + .02
	_box("LED cove", Vector3((SX0 + SX1) * .5, y, SZ1 - inset), Vector3(SX1 - SX0 - .2, .015, .015), "led purple")
	_box("LED cove", Vector3(SX0 + inset, y, (SZ0 + SZ1) * .5), Vector3(.015, .015, SZ1 - SZ0 - .2), "led purple")
	_box("LED cove", Vector3(SX1 - inset, y, (SZ0 + SZ1) * .5), Vector3(.015, .015, SZ1 - SZ0 - .2), "led purple")
	_box("LED cove", Vector3((SX0 + DOOR_X0) * .5, y, SZ0 + inset), Vector3(DOOR_X0 - SX0 - .1, .015, .015), "led purple")
	# Under-desk and drum riser accent strips.
	_box("Desk LED", Vector3(DESK.x, .02, SZ1 - inset), Vector3(1.7, .012, .012), "led blue")

## Wall bracket that holds a hanging guitar by its headstock.
func _hanger(at: Vector3) -> void:
	_box("Guitar hanger plate", at + Vector3(.006, 0, 0), Vector3(.012, .09, .05), "black metal")
	_rod(at + Vector3(.012, -.01, 0), at + Vector3(.085, .015, 0), .006, "black metal", 6)
	for dz in [-.022, .022]:
		_rod(at + Vector3(.075, .012, dz), at + Vector3(.1, .04, dz), .005, "rubber", 6)

# ---------------------------------------------------------------- door

func _build_fixed_glass() -> void:
	# Fixed panel (screen-right half) on the outer track, framed like the sliding leaf.
	var x0 := DOOR_X1 - 1.03
	_glass_panel(Vector3(x0, .015, 2.76), 1.03, DOOR_H - .07, false)
	_collider("Fixed glass panel", Vector3(x0 + .515, DOOR_H * .5, 2.76), Vector3(1.03, DOOR_H - .04, .04))

func _glass_panel(origin: Vector3, width: float, height: float, handle: bool) -> void:
	var f := .045
	_box("Door frame", origin + Vector3(width * .5, f * .5, 0), Vector3(width, f, .04), "aluminium")
	_box("Door frame", origin + Vector3(width * .5, height - f * .5, 0), Vector3(width, f, .04), "aluminium")
	_box("Door frame", origin + Vector3(f * .5, height * .5, 0), Vector3(f, height, .04), "aluminium")
	_box("Door frame", origin + Vector3(width - f * .5, height * .5, 0), Vector3(f, height, .04), "aluminium")
	_box("Door glass", origin + Vector3(width * .5, height * .5, 0), Vector3(width - f * 2, height - f * 2, .008), "glass")
	# A frosted band at eye height so the glass reads as a door.
	_box("Door etch band", origin + Vector3(width * .5, 1.05, 0), Vector3(width - f * 2, .09, .01), "glass etch")
	if handle:
		_rod(origin + Vector3(.09, .85, -.05), origin + Vector3(.09, 1.35, -.05), .012, "black metal", 8)
		_rod(origin + Vector3(.09, .85, .05), origin + Vector3(.09, 1.35, .05), .012, "black metal", 8)
		for y in [.88, 1.32]:
			_rod(origin + Vector3(.09, y, -.05), origin + Vector3(.09, y, .05), .007, "black metal", 6)

func _build_door() -> void:
	_feature("Glass sliding door (E to slide)")
	var door := SlidingDoorScript.new() as InteriorSlidingDoor
	door.name = "StudioDoor"
	door.label = "studio door"
	door.slide_distance = .98
	door.swing_seconds = .8
	door.position = Vector3(DOOR_X0 + .02, 0, 2.84)
	_root.add_child(door)
	var leaf := AnimatableBody3D.new()
	leaf.name = "DoorLeaf"
	leaf.collision_layer = 2
	leaf.collision_mask = 5
	leaf.sync_to_physics = true
	door.add_child(leaf)
	var collision := CollisionShape3D.new()
	collision.name = "LeafCollider"
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.03, DOOR_H - .04, .045)
	shape.margin = .002
	collision.shape = shape
	collision.position = Vector3(.515, DOOR_H * .5, 0)
	leaf.add_child(collision)
	var saved := _batches
	_batches = {}
	_glass_panel(Vector3(0, .015, 0), 1.03, DOOR_H - .07, true)
	_commit(leaf, "Door leaf - ")
	_batches = saved

# ---------------------------------------------------------------- models

## A downloaded model as its own named static body (box collider unless `collide` is false).
func _model(label: String, path: String, at: Vector3, yaw := 0.0, scale := 1.0, anchor := "bottom", tilt := Vector3.ZERO, collide := true, inset := Vector3.ZERO) -> Node3D:
	var body := _static_body(label, Vector3.ZERO)
	var node := InteriorModelKit.place(body, "studio/" + path if not path.contains("/") else path, at, yaw, scale, anchor, tilt, path.get_file())
	if collide:
		InteriorModelKit.add_box_collider(body, node, inset)
		_stats.colliders += 1
	(_stats.props as Array).append(label)
	_stats.models += 1
	return node

func _build_furniture() -> void:
	_feature("Producer couch, plants, wall shelves and a pendant lamp")
	_model("Couch", "decor/sofa_02", Vector3(-4.62, 0, SZ0 + FOAM + .42), 0.0)
	_model("Tall plant", "decor/potted_plant_01", Vector3(-1.62, 0, SZ0 + .4), 30.0)
	# Walnut wall shelves above the keyboard station, holding records, books and a boombox.
	_begin_prop("Wall shelves", Vector3.ZERO)
	for y in [1.55, 1.95]:
		_box("Shelf board", Vector3(SX1 - FOAM - .13, y, 4.55), Vector3(.24, .03, 1.2), "walnut", false)
		for z in [4.1, 5.0]:
			_box("Shelf bracket", Vector3(SX1 - FOAM - .1, y - .05, z), Vector3(.18, .07, .02), "black metal", false)
	_collider("Shelves", Vector3(SX1 - FOAM - .13, 1.75, 4.55), Vector3(.24, .45, 1.2))
	_end_prop()
	_model("Encyclopedia books", "decor/book_encyclopedia_set_01", Vector3(SX1 - FOAM - .13, 1.565, 4.85), 90.0, 1.0, "bottom", Vector3.ZERO, false)
	_model("Boombox", "decor/boombox", Vector3(SX1 - FOAM - .14, 1.965, 4.55), -90.0, .55, "bottom", Vector3.ZERO, false)
	_model("Alarm clock", "decor/alarm_clock_01", Vector3(SX1 - FOAM - .12, 1.565, 4.3), -90.0, 1.0, "bottom", Vector3.ZERO, false)
	_model("Brass vase", "decor/brass_vase_01", Vector3(SX1 - FOAM - .12, 1.965, 5.05), 0.0, .45, "bottom", Vector3.ZERO, false)
	_model("Shelf plant", "decor/potted_plant_04", Vector3(SX1 - FOAM - .13, 1.565, 4.05), 0.0, 1.0, "bottom", Vector3.ZERO, false)
	_model("Cassette player", "decor/cassette_player", Vector3(SX1 - FOAM - .12, 1.965, 4.15), -90.0, 1.0, "bottom", Vector3.ZERO, false)
	_model("Pendant lamp", "decor/modern_ceiling_lamp_01", Vector3(-3.55, SH, 4.75), 0.0, .72, "top", Vector3.ZERO, false)

func _build_instruments() -> void:
	_feature("Guitar wall: Ibanez, Gibson SG, Les Paul and two acoustics on hangers")
	var wall_x := SX0 + FOAM
	# [model, z, tilt, yaw, scale]: each turned so the headstock points up and the face looks +X.
	var guitars := [
		["guitar_acoustic_a", 3.78, Vector3(90, 0, 0), 90.0],
		["guitar_ibanez", 4.2, Vector3(0, 0, -90), 0.0],
		["guitar_sg", 4.6, Vector3.ZERO, 90.0],
		["guitar_lespaul", 5.0, Vector3(90, 0, 0), 0.0],
		["guitar_acoustic_b", 5.42, Vector3.ZERO, 90.0],
	]
	for item: Array in guitars:
		var node := _model("Guitar " + str(item[0]).trim_prefix("guitar_"), item[0], Vector3(wall_x + .015, 1.42, item[1]), item[3], 1.0, "left", item[2], false)
		var box := InteriorModelKit.bounds_in(node, _root)
		_begin_prop("Hanger " + str(item[0]).trim_prefix("guitar_"), Vector3.ZERO)
		_hanger(Vector3(wall_x, box.end.y - .14, item[1]))
		_end_prop()
	_feature("Marshall and Orange combo amps under the guitars, Fender P-bass on its stand")
	_model("Marshall amp", "amp_marshall", Vector3(wall_x + .14, 0, 4.15), 90.0)
	_model("Orange amp", "amp_orange", Vector3(wall_x + .14, 0, 4.95), 90.0)
	_model("Bass on stand", "bass_precision", Vector3(-3.95, 0, 5.35), 200.0)
	_feature("Drum kit in the back corner, facing the room")
	_model("Drum kit", "drum_kit", Vector3(-4.73, 0, 6.4), 180.0, 1.0, "bottom", Vector3.ZERO, true, Vector3(.15, 0, .15))
	_feature("Two-tier keyboard station: 61-key synth below, analogue synth above")
	var station := Vector3(SX1 - FOAM - .38, 0, 4.55)
	_begin_prop("Keyboard X-stand", Vector3.ZERO)
	for side in [-1.0, 1.0]:
		var z: float = station.z + side * .32
		_rod(Vector3(station.x - .22, .02, z), Vector3(station.x + .22, .8, z), .016, "black metal", 8)
		_rod(Vector3(station.x + .22, .02, z), Vector3(station.x - .22, .8, z), .016, "black metal", 8)
		_rod(Vector3(station.x, .8, z), Vector3(station.x + .08, 1.12, z), .013, "black metal", 8)
		for x in [-.22, .22]:
			_box("Stand foot", Vector3(station.x + x, .012, z), Vector3(.05, .024, .06), "rubber")
	for y in [.8, 1.12]:
		_rod(Vector3(station.x + (.0 if y < 1 else .08), y, station.z - .45), Vector3(station.x + (.0 if y < 1 else .08), y, station.z + .45), .012, "black metal", 8)
	_collider("Keyboard stand", Vector3(station.x, .55, station.z), Vector3(.5, 1.1, 1.0))
	_end_prop()
	_model("Synth 61-key", "synth_b", Vector3(station.x, .815, station.z), -90.0, 1.0, "bottom", Vector3.ZERO, false)
	_model("Analogue synth", "synth_wood", Vector3(station.x + .06, 1.135, station.z), 180.0, 1.0, "bottom", Vector3(0, 0, 0), false)
	_model("Mic boom stand", "mic_boom_stand", Vector3(-2.5, 0, 4.3), -60.0, 1.0, "bottom", Vector3.ZERO, true, Vector3(.4, 0, .25))

func _build_desk() -> void:
	_feature("Gaming / production desk: two curved monitors, RGB tower, keyboard, mouse, MIDI controller, KRK monitors")
	var desk := _model("Gaming desk", "gaming_desk", DESK, 180.0)
	desk.set_meta("studio_desk", true)
	for side in [-1.0, 1.0]:
		var at := Vector3(DESK.x + side * .42, DESK_TOP, DESK.z + .2)
		var monitor := _model("Monitor " + ("left" if side > 0 else "right"), "gaming_monitor", at, 180.0 + side * 15.0, .78, "bottom", Vector3.ZERO, false)
		monitor.set_meta("studio_screen", "daw" if side > 0 else "game")
	_model("Gaming PC", "gaming_pc", Vector3(DESK.x - .62, 0, DESK.z + .12), 180.0)
	_model("Keyboard", "gaming_keyboard", Vector3(DESK.x - .2, DESK_TOP, DESK.z - .3), 180.0, 1.0, "bottom", Vector3.ZERO, false)
	_model("Mouse", "gaming_mouse", Vector3(DESK.x - .58, DESK_TOP, DESK.z - .3), 180.0, 1.0, "bottom", Vector3.ZERO, false)
	_model("MIDI controller", "midi_controller", Vector3(DESK.x + .5, DESK_TOP, DESK.z - .3), 180.0, .82, "bottom", Vector3.ZERO, false)
	_model("Audio interface", "audio_interface", Vector3(DESK.x + .82, DESK_TOP, DESK.z - .05), 90.0, 1.0, "bottom", Vector3.ZERO, false)
	_model("Gaming chair", "gaming_chair", Vector3(DESK.x - .05, 0, DESK.z - .95), 0.0, 1.0, "bottom", Vector3.ZERO, true, Vector3(.08, 0, .08))
	# KRK monitors on speaker stands either side of the desk, toed in toward the chair.
	for side in [-1.0, 1.0]:
		var x: float = DESK.x + side * 1.05
		_begin_prop("Speaker stand " + ("left" if side > 0 else "right"), Vector3.ZERO)
		_box("Stand base", Vector3(x, .012, DESK.z + .15), Vector3(.28, .024, .28), "black metal")
		_rod(Vector3(x, .02, DESK.z + .15), Vector3(x, .95, DESK.z + .15), .025, "black metal", 10)
		_box("Stand top", Vector3(x, .96, DESK.z + .15), Vector3(.2, .02, .24), "black metal")
		_collider("Speaker stand", Vector3(x, .6, DESK.z + .15), Vector3(.28, 1.2, .28))
		_end_prop()
		_model("KRK monitor " + ("left" if side > 0 else "right"), "studio_monitor_krk", Vector3(x, .97, DESK.z + .15), 180.0 + side * 20.0, 1.0, "bottom", Vector3.ZERO, false)
	# Headphones on a small stand by the right edge of the desk.
	_begin_prop("Headphone stand", Vector3.ZERO)
	var hp := Vector3(DESK.x - .82, DESK_TOP, DESK.z - .38)
	_rod(hp, hp + Vector3(0, .012, 0), .06, "black metal", 14)
	_rod(hp, hp + Vector3(0, .26, 0), .009, "black metal", 8)
	_end_prop()
	_model("Headphones", "headphones_sony", hp + Vector3(0, .0, 0), 90.0, .95, "bottom", Vector3.ZERO, false)

# ---------------------------------------------------------------- lights

func _build_studio_lights() -> void:
	for spec: Array in [["Desk spot", Vector3(-2.6, SH - .05, 6.0), 1.6, 55.0, true], ["Drum spot", Vector3(-4.75, SH - .05, 6.0), 1.3, 55.0, true]]:
		var spot := SpotLight3D.new()
		spot.name = spec[0]
		spot.light_color = InteriorLighting.kelvin(3000)
		spot.light_energy = spec[2]
		spot.spot_angle = spec[3]
		spot.spot_range = 4.5
		spot.spot_attenuation = .8
		spot.position = spec[1]
		spot.rotation_degrees = Vector3(-90, 0, 0)
		spot.set_meta("studio_shadow", spec[4])
		_root.add_child(spot)
	for spec: Array in [["Room fill", Vector3(-3.55, 2.05, 4.75), Color(1.0, .78, .58), .8, 5.0], ["LED glow purple", Vector3(-3.4, 2.65, 6.9), Color(.62, .25, 1.0), 1.2, 3.2],
			["LED glow blue", Vector3(-5.3, 2.65, 4.2), Color(.25, .45, 1.0), .7, 3.0], ["Monitor glow", Vector3(-2.6, 1.05, 6.5), Color(.55, .7, 1.0), .35, 1.8]]:
		var omni := OmniLight3D.new()
		omni.name = spec[0]
		omni.position = spec[1]
		omni.light_color = spec[2]
		omni.light_energy = spec[3]
		omni.omni_range = spec[4]
		omni.omni_attenuation = 1.2
		omni.light_specular = .4
		_root.add_child(omni)
	var neon := Label3D.new()
	neon.name = "Neon HARMONIK"
	neon.text = "HARMONIK"
	neon.font_size = 96
	neon.outline_size = 0
	neon.pixel_size = .003
	neon.modulate = Color(3.2, .9, 2.2)
	neon.shaded = false
	neon.double_sided = false
	neon.position = Vector3(DESK.x, 2.25, SZ1 - FOAM - .02)
	neon.rotation_degrees = Vector3(0, 180, 0)
	_root.add_child(neon)
	var sub := Label3D.new()
	sub.name = "Neon 3RD"
	sub.text = "3RD"
	sub.font_size = 64
	sub.outline_size = 0
	sub.pixel_size = .0035
	sub.modulate = Color(.7, 1.6, 3.4)
	sub.shaded = false
	sub.position = Vector3(DESK.x, 2.52, SZ1 - FOAM - .02)
	sub.rotation_degrees = Vector3(0, 180, 0)
	_root.add_child(sub)
