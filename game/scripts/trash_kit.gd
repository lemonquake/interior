class_name InteriorTrash
extends RefCounted
## 0.60: litter that reads as litter: crushed cups, milk-tea cups with their dome lids and straws, styrofoam
## noodle cups with the foil torn back, open food clamshells, crushed cans, PET bottles, sando bags, sachets,
## crumpled paper, flattened cardboard, juice boxes, and the small bits (cigarette butts, straws, caps, spoons).
##
## Built for cost first:
## - 12 tiny meshes made here in code (no files, no textures, no UVs): 6..80 triangles each, vertex colours
##   only, shared by every map that uses them (static cache: the whole kit is ~45 KB of vertex data, once).
## - Every piece is a MultiMesh instance: 64 bytes each (transform + one tint/dirt vec4). 3000 pieces = 190 KB.
## - One shader material for all of it. No shadows, no colliders, no GI, hard visibility cut-off.
## - Instances are grouped per kind per CELL x CELL m square, so whole squares out of view or past the range
##   are culled at once: at most (kinds x visible squares) instanced draws.
##
## Usage: var t := InteriorTrash.new(parent, seed); t.ground = func(p: Vector3) -> float: ...
##        t.cluster(centre, radius, count) / t.line(a, b, per_metre, width) / t.floating(...); t.commit()

## Squares of CELL metres: small enough that a whole square goes out of range together without pieces popping
## near the player (the range is measured to the square's centre).
const CELL := 16.0
const RANGE := 36.0
const KINDS := ["cup", "milktea", "noodle", "clamshell", "can", "bottle", "bag", "sachet", "paper", "sheet", "juice", "bits"]
## How often each kind turns up in ordinary street litter (sachets, butts and cups everywhere; boxes rarer).
const STREET_MIX := {"cup": 11, "milktea": 6, "noodle": 5, "clamshell": 5, "can": 8, "bottle": 9, "bag": 10,
	"sachet": 16, "paper": 8, "sheet": 4, "juice": 5, "bits": 13}
## What floats: light, hollow, plastic.
const FLOAT_MIX := {"cup": 8, "milktea": 4, "noodle": 4, "clamshell": 6, "bottle": 12, "bag": 10, "sachet": 6, "juice": 3}

const TINTS := {
	"cup": [Color(.62, .12, .1), Color(.12, .25, .52), Color(.2, .4, .22), Color(.42, .26, .14), Color(.75, .72, .66)],
	"milktea": [Color(.6, .43, .28), Color(.5, .4, .58), Color(.78, .72, .6), Color(.32, .2, .13), Color(.55, .6, .35)],
	"noodle": [Color(.72, .14, .08), Color(.82, .45, .08), Color(.22, .45, .18), Color(.8, .66, .1)],
	"can": [Color(.6, .08, .07), Color(.12, .35, .16), Color(.55, .56, .58), Color(.12, .2, .5), Color(.08, .08, .09), Color(.75, .6, .12)],
	"bottle": [Color(.7, .12, .1), Color(.15, .3, .62), Color(.2, .5, .25), Color(.85, .85, .82), Color(.85, .45, .1)],
	"bag": [Color(.8, .8, .78), Color(.75, .45, .55), Color(.55, .1, .1), Color(.07, .07, .08), Color(.18, .3, .55), Color(.5, .62, .2), Color(.8, .45, .12)],
	"sachet": [Color(.85, .7, .1), Color(.15, .45, .2), Color(.65, .1, .12), Color(.12, .25, .6), Color(.4, .15, .45), Color(.06, .06, .07), Color(.85, .4, .08)],
	"juice": [Color(.85, .45, .08), Color(.25, .5, .15), Color(.45, .15, .45), Color(.7, .12, .12)],
	"sheet": [Color(.5, .38, .24), Color(.58, .45, .3), Color(.55, .55, .52)],
	"paper": [Color(.8, .78, .72), Color(.7, .7, .68)],
	"clamshell": [Color.WHITE],
	"bits": [Color.WHITE],
}

static var _meshes: Dictionary = {}
static var _material: ShaderMaterial

var parent: Node3D
var rng := RandomNumberGenerator.new()
## Returns the floor height under a world position (x, z); y of the position is a hint. Unset: the given y.
var ground: Callable
## Render layers of the drawn squares (the canal draws on layer 2 with the outdoors).
var layers := 1
var visibility_end := RANGE
var count := 0
var _items: Dictionary = {}

func _init(parent_: Node3D, seed_: int) -> void:
	parent = parent_
	rng.seed = seed_

# ------------------------------------------------------------------------------------------------ scatter

## A heap of litter around `centre`: denser in the middle, a few strays further out.
func cluster(centre: Vector3, radius: float, n: int, mix: Dictionary = STREET_MIX) -> void:
	for i in n:
		var a := rng.randf() * TAU
		var d := radius * pow(rng.randf(), 1.6) * (1.0 if rng.randf() < .85 else 1.8)
		add(_pick(mix), centre + Vector3(cos(a) * d, 0, sin(a) * d))

## Litter drifted along a line (a gutter, the foot of a wall, a path's edge), `per_metre` pieces each metre.
func line(a: Vector3, b: Vector3, per_metre: float, width: float, mix: Dictionary = STREET_MIX) -> void:
	var length := a.distance_to(b)
	var side := Vector3(b.z - a.z, 0, a.x - b.x).normalized()
	var n := int(length * per_metre)
	for i in n:
		var t := rng.randf()
		# Drift collects in small knots along the line rather than evenly.
		if rng.randf() < .45: t = snappedf(t, 1.6 / maxf(length, 1.0)) + rng.randf_range(-.02, .02)
		var off := (rng.randf() + rng.randf() - 1.0) * width
		add(_pick(mix), a.lerp(b, clampf(t, 0, 1)) + side * off)

## Light rubbish floating at `y` (no ground lookup), bobbing nowhere: still water.
func floating(centre: Vector3, radius: float, n: int) -> void:
	for i in n:
		var a := rng.randf() * TAU
		var d := radius * sqrt(rng.randf())
		add(_pick(FLOAT_MIX), centre + Vector3(cos(a) * d, 0, sin(a) * d), true)

func add(kind: String, p: Vector3, afloat := false) -> void:
	var y := p.y
	var up := Vector3.UP
	if not afloat and ground.is_valid():
		y = ground.call(p)
		# Lie with the slope: two more samples 12 cm away give the ground's normal.
		var dx: float = ground.call(p + Vector3(.12, 0, 0)) - y
		var dz: float = ground.call(p + Vector3(0, 0, .12)) - y
		up = Vector3(-dx, .12, -dz).normalized()
		if up.y < .55: up = Vector3.UP  # a step or a wall edge, not a slope
	var pose := _pose(kind, afloat)
	var align := Basis.IDENTITY
	if up.dot(Vector3.UP) < .999:
		var axis := Vector3.UP.cross(up).normalized()
		align = Basis(axis, Vector3.UP.angle_to(up))
	var xf := Transform3D(align * Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, y - (.012 if afloat else .003), p.z)) * pose
	var tints: Array = TINTS[kind]
	var tint: Color = tints[rng.randi() % tints.size()]
	tint = tint.lerp(Color(tint.r * .7, tint.g * .7, tint.b * .7), rng.randf())
	# Alpha carries grime: most of it has been lying in the wet for weeks.
	tint.a = clampf(rng.randf_range(.0, .42) * rng.randf_range(.5, 1.0) + (.15 if afloat else 0.0), 0, .6)
	var key := "%s|%d|%d" % [kind, int(floor(p.x / CELL)), int(floor(p.z / CELL))]
	if not _items.has(key): _items[key] = []
	(_items[key] as Array).append([xf, tint])
	count += 1

func _pick(mix: Dictionary) -> String:
	var total := 0
	for k: String in mix: total += int(mix[k])
	var roll := rng.randi() % total
	for k: String in mix:
		roll -= int(mix[k])
		if roll < 0: return k
	return "sachet"

## How each kind comes to rest: upright, on its side, stepped flat. (Meshes are authored upright on y = 0.)
func _pose(kind: String, afloat: bool) -> Transform3D:
	var r := rng.randf()
	var side := Basis(Vector3.BACK, PI * .5)
	var s := rng.randf_range(.9, 1.12)
	match kind:
		"cup":
			if r < .2 and not afloat: return Transform3D(Basis.from_scale(Vector3(s, rng.randf_range(.5, 1.0) * s, s)), Vector3.ZERO)
			var flat := rng.randf_range(.35, .7) if r > .85 else 1.0
			return Transform3D(side * Basis.from_scale(Vector3(s, s, s * flat)), Vector3(0, .034 * flat * s, 0))
		"milktea":
			if r < .25 and not afloat: return Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3.ZERO)
			return Transform3D(side * Basis.from_scale(Vector3.ONE * s), Vector3(0, .042 * s, 0))
		"noodle":
			if r < .35 and not afloat: return Transform3D(Basis.from_scale(Vector3(s, rng.randf_range(.7, 1.0) * s, s)), Vector3.ZERO)
			if r < .5: return Transform3D(Basis(Vector3.RIGHT, PI) * Basis.from_scale(Vector3.ONE * s), Vector3(0, .085 * s, 0))
			return Transform3D(side * Basis.from_scale(Vector3.ONE * s), Vector3(0, .048 * s, 0))
		"can":
			if r < .25 and not afloat: return Transform3D(Basis.from_scale(Vector3(s, rng.randf_range(.3, .6), s)), Vector3.ZERO)
			return Transform3D(side * Basis.from_scale(Vector3(s, s, s * rng.randf_range(.55, 1.0))), Vector3(0, .03, 0))
		"bottle":
			if r < .1 and not afloat: return Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3.ZERO)
			var crush := rng.randf_range(.45, 1.0)
			return Transform3D(side * Basis.from_scale(Vector3(s, s, s * crush)), Vector3(0, .031 * crush, 0))
		"juice":
			if r < .2 and not afloat: return Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3.ZERO)
			return Transform3D(Basis(Vector3.RIGHT, PI * .5) * Basis.from_scale(Vector3(s, s, s * rng.randf_range(.5, 1.0))), Vector3(0, .02, 0))
		"bag":
			return Transform3D(Basis.from_scale(Vector3(rng.randf_range(.65, 1.1), rng.randf_range(.45, 1.0), rng.randf_range(.65, 1.1))), Vector3.ZERO)
		"sheet":
			return Transform3D(Basis.from_scale(Vector3(rng.randf_range(.7, 1.25), 1, rng.randf_range(.7, 1.2))), Vector3.ZERO)
		"sachet", "paper":
			return Transform3D(Basis.from_scale(Vector3.ONE * rng.randf_range(.8, 1.3)), Vector3.ZERO)
	return Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3.ZERO)

# ------------------------------------------------------------------------------------------------ commit

## Turns everything added into MultiMesh squares under `parent`. Returns how many squares were made.
func commit(name_prefix := "Trash") -> int:
	var made := 0
	var mat := material()
	for key: String in _items:
		var items: Array = _items[key]
		var kind := key.get_slice("|", 0)
		# The node sits at the square's centre (visibility ranges are measured to it); pieces are relative.
		var centre := Vector3.ZERO
		for it: Array in items: centre += (it[0] as Transform3D).origin
		centre /= float(items.size())
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh(kind)
		mm.instance_count = items.size()
		for i in items.size():
			var xf: Transform3D = items[i][0]
			mm.set_instance_transform(i, Transform3D(xf.basis, xf.origin - centre))
			mm.set_instance_custom_data(i, items[i][1])
		var mi := MultiMeshInstance3D.new()
		mi.position = centre
		mi.name = name_prefix + " " + key.replace("|", " ")
		mi.multimesh = mm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mi.visibility_range_end = visibility_end
		mi.layers = layers
		parent.add_child(mi)
		made += 1
	_items.clear()
	return made

static func material() -> ShaderMaterial:
	if _material == null:
		var shader := Shader.new()
		# Vertex colour = the piece's own colours; its alpha = how much of that spot takes the instance's tint.
		# The instance's alpha = grime. Opaque, double-sided (open cups, sheets), no texture lookups at all.
		shader.code = """shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
varying flat vec4 tint;
void vertex() {
	tint = INSTANCE_CUSTOM;
}
void fragment() {
	vec3 c = mix(COLOR.rgb, tint.rgb, COLOR.a);
	ALBEDO = c * (1.0 - tint.a * .6) + vec3(.035, .03, .02) * tint.a;
	ROUGHNESS = .42 + tint.a * .4;
	SPECULAR = .45;
}
"""
		_material = ShaderMaterial.new()
		_material.shader = shader
	return _material

# ------------------------------------------------------------------------------------------------ the meshes

static func mesh(kind: String) -> ArrayMesh:
	if not _meshes.has(kind):
		var m := _Mesh.new(hash(kind))
		match kind:
			"cup": m.cup()
			"milktea": m.milktea()
			"noodle": m.noodle()
			"clamshell": m.clamshell()
			"can": m.can()
			"bottle": m.bottle()
			"bag": m.bag()
			"sachet": m.sachet()
			"paper": m.paper()
			"sheet": m.sheet()
			"juice": m.juice()
			"bits": m.bits()
		_meshes[kind] = m.commit()
	return _meshes[kind]

## Triangle counts of the kit (for the report and the tests).
static func triangle_counts() -> Dictionary:
	var out := {}
	for k: String in KINDS:
		var arrays := mesh(k).surface_get_arrays(0)
		out[k] = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return out

class _Mesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var r := RandomNumberGenerator.new()

	func _init(seed_: int) -> void:
		r.seed = seed_

	func tri(a: Vector3, b: Vector3, d: Vector3, col: Color) -> void:
		# Godot's front faces wind clockwise: the normal must face the side the triangle is front-facing on, or the
		# double-sided shading (which flips back-face normals) turns every lit surface away from the light.
		var nn := (d - a).cross(b - a).normalized()
		v.append_array([a, b, d])
		n.append_array([nn, nn, nn])
		c.append_array([col, col, col])

	func quad(a: Vector3, b: Vector3, d: Vector3, e: Vector3, col: Color) -> void:
		tri(a, b, d, col)
		tri(a, d, e, col)

	func ring(y: float, rad: float, sides: int, jitter := 0.0) -> PackedVector3Array:
		var out := PackedVector3Array()
		for i in sides:
			var a := TAU * i / sides
			var rr := rad * (1.0 + r.randf_range(-jitter, jitter))
			out.append(Vector3(cos(a) * rr, y, sin(a) * rr))
		return out

	func band(lo: PackedVector3Array, hi: PackedVector3Array, col: Color) -> void:
		for i in lo.size():
			var j := (i + 1) % lo.size()
			quad(lo[i], lo[j], hi[j], hi[i], col)

	## The inside of an open container: the rings pulled in a few millimetres, darker (dregs, shadow).
	func inside(rings: Array, col: Color, inset := .0035) -> void:
		var pulled := []
		for rg: PackedVector3Array in rings:
			var q := PackedVector3Array()
			for p in rg:
				q.append(Vector3(p.x, p.y, p.z) - Vector3(p.x, 0, p.z).normalized() * inset)
			pulled.append(q)
		for i in range(pulled.size() - 1):
			band(pulled[i + 1], pulled[i], col)
		var floor_ring: PackedVector3Array = pulled[0]
		var lifted := PackedVector3Array()
		for p in floor_ring: lifted.append(p + Vector3(0, .004, 0))
		cap(lifted, Vector3(0, .004, 0), col)

	func cap(rg: PackedVector3Array, centre: Vector3, col: Color) -> void:
		for i in rg.size():
			tri(centre, rg[(i + 1) % rg.size()], rg[i], col)

	func box(centre: Vector3, size: Vector3, col: Color, basis := Basis.IDENTITY, open_top := false) -> void:
		var h := size * .5
		var p := []
		for k in 8:
			p.append(centre + basis * Vector3(h.x * (1 if k & 1 else -1), h.y * (1 if k & 2 else -1), h.z * (1 if k & 4 else -1)))
		quad(p[0], p[1], p[5], p[4], col)  # bottom
		if not open_top: quad(p[2], p[6], p[7], p[3], col)
		quad(p[0], p[4], p[6], p[2], col)
		quad(p[1], p[3], p[7], p[5], col)
		quad(p[0], p[2], p[3], p[1], col)
		quad(p[4], p[5], p[7], p[6], col)

	## Pushes one side of everything in: a stepped-on, kicked, rained-on shape.
	func dent(amount: float, toward := Vector3.ZERO) -> void:
		var dir := Vector3(r.randf_range(-1, 1), 0, r.randf_range(-1, 1)).normalized()
		for i in v.size():
			var p := v[i]
			var k := maxf(0.0, Vector3(p.x, 0, p.z).normalized().dot(dir))
			v[i] = p - Vector3(p.x, 0, p.z) * k * amount + toward * k
		# Flat normals again after moving the corners.
		for i in range(0, v.size(), 3):
			var nn := (v[i + 2] - v[i]).cross(v[i + 1] - v[i]).normalized()
			n[i] = nn; n[i + 1] = nn; n[i + 2] = nn

	func commit() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_COLOR] = c
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return m

	# --- the pieces (metres, upright, standing on y = 0)

	## Paper coffee/softdrink cup: white, a coloured band (tinted), a rolled rim, dented.
	func cup() -> void:
		var white := Color(.78, .76, .72, 0)
		var printed := Color(.78, .76, .72, 1)
		var r0 := ring(0, .028, 8)
		var r1 := ring(.035, .031, 8)
		var r2 := ring(.08, .037, 8)
		var r3 := ring(.105, .04, 8)
		var lip := ring(.108, .043, 8)
		band(r0, r1, white)
		band(r1, r2, printed)
		band(r2, r3, white)
		band(r3, lip, white)
		cap(r0, Vector3.ZERO, white)
		inside([r0, r1, r2, r3], Color(.36, .3, .24, 0))
		dent(.35)

	## Milk tea cup: clear plastic showing the tea (tinted), a dome lid, a fat black straw through it.
	func milktea() -> void:
		var tea := Color(.7, .7, .7, 1)
		var clear := Color(.72, .74, .74, 0)
		var r0 := ring(0, .034, 8)
		var r1 := ring(.09, .042, 8)
		var r2 := ring(.15, .048, 8)
		band(r0, r1, tea)
		band(r1, r2, clear)
		cap(r0, Vector3.ZERO, tea)
		var dome := ring(.172, .03, 8)
		band(r2, dome, clear)
		cap(dome, Vector3(0, .18, 0), clear)
		# The straw: a thin square tube, out of the dome at a lean.
		var s0 := Vector3(.006, .175, 0)
		var s1 := Vector3(.03, .29, .012)
		var black := Color(.05, .05, .06, 0)
		var w := Vector3(.0055, 0, 0)
		var d := Vector3(0, 0, .0055)
		quad(s0 - w, s0 + w, s1 + w, s1 - w, black)
		quad(s0 - d, s0 + d, s1 + d, s1 - d, black)
		dent(.12)

	## Styrofoam instant-noodle cup: wide and short, printed band (tinted), foil lid torn half back.
	func noodle() -> void:
		var foam := Color(.82, .8, .74, 0)
		var printed := Color(.8, .8, .8, 1)
		var r0 := ring(0, .042, 9)
		var r1 := ring(.03, .046, 9)
		var r2 := ring(.07, .052, 9)
		var r3 := ring(.085, .056, 9)
		band(r0, r1, foam)
		band(r1, r2, printed)
		band(r2, r3, foam)
		cap(r0, Vector3.ZERO, foam)
		inside([r0, r1, r2, r3], Color(.42, .32, .18, 0))
		var foil := Color(.62, .6, .55, 0)
		quad(Vector3(-.05, .086, -.03), Vector3(-.05, .086, .03), Vector3(-.085, .13, .035), Vector3(-.09, .125, -.028), foil)
		tri(Vector3(-.05, .086, .03), Vector3(-.01, .086, .05), Vector3(-.03, .12, .06), foil)
		dent(.18)

	## Styrofoam food box (the take-out clamshell): the tray with sauce in it, the lid flopped open.
	func clamshell() -> void:
		var foam := Color(.8, .79, .74, 0)
		box(Vector3(0, .025, 0), Vector3(.18, .05, .15), foam, Basis.IDENTITY, true)
		quad(Vector3(-.08, .012, -.06), Vector3(.05, .012, -.065), Vector3(.06, .012, .04), Vector3(-.07, .012, .05), Color(.32, .17, .08, 0))
		quad(Vector3(-.02, .013, -.03), Vector3(.03, .013, -.02), Vector3(.035, .013, .02), Vector3(-.01, .013, .015), Color(.55, .5, .38, 0))
		var hinge := Basis(Vector3.BACK, -1.95)
		box(Vector3(-.09, .05, 0) + hinge * Vector3(.09, .02, 0), Vector3(.18, .04, .15), foam, hinge, true)

	## Softdrink can, crushed in the middle.
	func can() -> void:
		var body := Color(.8, .8, .8, 1)
		var metal := Color(.6, .6, .62, 0)
		var r0 := ring(0, .026, 8)
		var r1 := ring(.012, .033, 8)
		var r2 := ring(.055, .026, 8, .3)
		var r3 := ring(.105, .033, 8)
		var r4 := ring(.122, .027, 8)
		band(r0, r1, metal)
		band(r1, r2, body)
		band(r2, r3, body)
		band(r3, r4, metal)
		cap(r0, Vector3.ZERO, metal)
		cap(r4, Vector3(0, .12, 0), metal)
		dent(.25)

	## 500 ml PET bottle: clear body, a printed label (tinted), shoulder, neck, cap (tinted).
	func bottle() -> void:
		var clear := Color(.62, .72, .74, 0)
		var label := Color(.8, .8, .8, 1)
		var r0 := ring(0, .026, 8)
		var r1 := ring(.008, .032, 8)
		var r2 := ring(.06, .032, 8)
		var r3 := ring(.13, .032, 8)
		var r4 := ring(.175, .028, 8)
		var r5 := ring(.2, .013, 8)
		var r6 := ring(.215, .013, 8)
		var r7 := ring(.23, .015, 8)
		band(r0, r1, clear)
		band(r1, r2, clear)
		band(r2, r3, label)
		band(r3, r4, clear)
		band(r4, r5, clear)
		band(r5, r6, clear)
		band(r6, r7, label)
		cap(r0, Vector3(0, .005, 0), clear)
		cap(r7, Vector3(0, .23, 0), label)
		dent(.3)

	## Sando bag: a knotted, half-full plastic bag slumped on its side, the two handles looped up out of the knot.
	func bag() -> void:
		var plastic := Color(.85, .85, .85, 1)
		var low := ring(.01, .075, 8, .2)
		var mid := ring(.06, .115, 8, .22)
		var high := ring(.11, .07, 8, .25)
		for rg in [mid, high]:
			for i in rg.size(): rg[i] += Vector3(r.randf_range(-.012, .012), r.randf_range(-.015, .015), r.randf_range(-.012, .012))
		band(low, mid, plastic)
		band(mid, high, plastic)
		cap(low, Vector3(0, 0, 0), plastic)
		var neck := ring(.135, .018, 8)
		band(high, neck, plastic)
		cap(neck, Vector3(.004, .15, 0), plastic)
		# The handles: two flat loops of plastic, knotted at the neck.
		for side in [-1.0, 1.0]:
			var base := Vector3(side * .01, .145, 0)
			var tip := Vector3(side * .06, .2, side * .015)
			var w := Vector3(0, 0, .012)
			quad(base - w, base + w, tip + w * 1.6, tip - w * 1.6, plastic)
			quad(tip - w * 1.6, tip + w * 1.6, tip + Vector3(side * .02, -.035, 0) + w, tip + Vector3(side * .02, -.035, 0) - w, plastic)

	## Sachets (shampoo, coffee, ketchup): two in one piece, crinkled, one torn open.
	func sachet() -> void:
		var printed := Color(.8, .8, .8, 1)
		var foil := Color(.62, .62, .6, .35)
		for k in 2:
			var o := Vector3(k * .07 - .03, 0, k * .05 - .02)
			var a := r.randf() * TAU
			var bs := Basis(Vector3.UP, a)
			var w := .045 if k == 0 else .03
			var h := .03 if k == 0 else .05
			var p := [o + bs * Vector3(-w, .002, -h), o + bs * Vector3(0, .006, -h), o + bs * Vector3(w, .002, -h),
				o + bs * Vector3(-w, .004, h), o + bs * Vector3(0, .008, h), o + bs * Vector3(w, .003, h)]
			quad(p[0], p[3], p[4], p[1], printed if k == 0 else foil)
			quad(p[1], p[4], p[5], p[2], printed)

	## Crumpled paper or a tissue: a lumpy ball of facets.
	func paper() -> void:
		var paper := Color(.82, .8, .74, .3)
		var pts := [Vector3(0, .05, 0), Vector3(0, 0, 0)]
		var mid := ring(.025, .03, 6, .4)
		for i in mid.size(): mid[i].y += r.randf_range(-.012, .012)
		for i in mid.size():
			var j := (i + 1) % mid.size()
			tri(mid[i], mid[j], pts[0] + Vector3(r.randf_range(-.01, .01), r.randf_range(-.01, .005), r.randf_range(-.01, .01)), paper)
			tri(mid[j], mid[i], pts[1], paper)

	## Flattened cardboard or newspaper: folded once along a crease, one corner curling up.
	func sheet() -> void:
		var col := Color(.8, .8, .8, 1)
		var crease := Color(.62, .62, .62, 1)
		var p := [Vector3(-.15, .003, -.11), Vector3(0, .016, -.12), Vector3(.15, .004, -.1),
			Vector3(-.16, .005, .11), Vector3(0, .02, .12), Vector3(.13, .045, .13)]
		quad(p[0], p[3], p[4], p[1], col)
		quad(p[1], p[4], p[5], p[2], crease)

	## Juice box (tetra pack): a dented brick with its straw.
	func juice() -> void:
		var printed := Color(.8, .8, .8, 1)
		box(Vector3(0, .05, 0), Vector3(.06, .1, .04), printed, Basis(Vector3.FORWARD, .08))
		var white := Color(.75, .74, .7, 0)
		quad(Vector3(-.026, .102, -.015), Vector3(.026, .098, -.015), Vector3(.026, .098, .015), Vector3(-.026, .102, .015), white)
		var s := Color(.75, .75, .72, 0)
		tri(Vector3(.015, .1, 0), Vector3(.019, .1, .004), Vector3(.045, .14, .002), s)
		dent(.25)

	## The small stuff: cigarette butts, a bent straw, a bottle cap, a plastic spoon.
	func bits() -> void:
		var filter := Color(.75, .45, .2, 0)
		var paper := Color(.78, .76, .7, 0)
		for k in 3:
			var o := Vector3(r.randf_range(-.08, .08), .004, r.randf_range(-.08, .08))
			var d := Basis(Vector3.UP, r.randf() * TAU) * Vector3(.012, 0, 0)
			var e := Basis(Vector3.UP, PI * .5) * d.normalized() * .004
			quad(o - e, o + e, o + e + d, o - e + d, filter)
			quad(o - e + d, o + e + d, o + e + d * 2.2, o - e + d * 2.2, paper)
		var straw := Color(.65, .2, .3, 0)
		quad(Vector3(-.1, .003, .05), Vector3(-.1, .003, .056), Vector3(.02, .004, .07), Vector3(.02, .004, .064), straw)
		quad(Vector3(.02, .004, .064), Vector3(.02, .004, .07), Vector3(.06, .005, .1), Vector3(.06, .005, .094), straw)
		var capc := Color(.15, .3, .65, 0)
		var cr := ring(.008, .014, 6)
		cap(cr, Vector3(0, .009, 0), capc)
		for i in cr.size(): cr[i] += Vector3(.05, 0, -.06)
		cap(cr, Vector3(.05, .009, -.06), capc)
		var spoon := Color(.8, .8, .78, 0)
		quad(Vector3(-.06, .004, -.08), Vector3(-.055, .004, -.084), Vector3(.02, .006, -.03), Vector3(.015, .006, -.026), spoon)
		var bowl := ring(.008, .018, 6)
		for i in bowl.size(): bowl[i] += Vector3(.03, 0, -.018)
		cap(bowl, Vector3(.03, .005, -.018), spoon)
