extends RefCounted
## 0.42: the stock of Olivar Family Mart. Real products (tools/store_goods.py draws their labels into one 4096 px
## atlas, goods.json says which cell is which), turned into meshes here: cans and tins, PET bottles with a shoulder,
## neck and cap, Pringles tubes, noodle cups, pillowed chip bags and boxes. Every item is a few dozen vertices added
## to one of three meshes (metal, plastic, paper), so a store holding a thousand of them is three draw calls.
##
## An item stands on its base at the transform's origin with its front (the label's middle) toward local +Z.

const ATLAS := preload("res://assets/coop/goods/atlas.png")
const MANIFEST := "res://assets/coop/goods/goods.json"
const SEGMENTS := 14
const PAD := .006

static var _data := {}
static var _mats := {}

var _arrays := {}

static func catalogue() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	return _data

static func names() -> Array:
	return catalogue().goods.keys()

static func has(item: String) -> bool:
	return catalogue().goods.has(item)

## Width, height and depth of an item standing up.
static func extent(item: String) -> Vector3:
	var g: Dictionary = catalogue().goods[item]
	var s: Array = g.size
	match String(g.shape):
		"box", "bag": return Vector3(s[0], s[1], s[2])
		"cup": return Vector3(s[0] * 2, s[2], s[0] * 2)
	return Vector3(s[0] * 2, s[1], s[0] * 2)

static func material(kind: String) -> StandardMaterial3D:
	if _mats.has(kind): return _mats[kind]
	var m := StandardMaterial3D.new()
	m.albedo_texture = ATLAS
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	match kind:
		"metal":
			m.metallic = .45
			m.roughness = .34
		"plastic":
			m.roughness = .26
			m.metallic_specular = .7
		_:
			m.roughness = .78
	_mats[kind] = m
	return m

## One item at `xf` (scale in the basis squashes it: a stepped-on can).
func add(item: String, xf: Transform3D) -> void:
	var g: Dictionary = catalogue().goods[item]
	var s: Array = g.size
	var cell := int(g.cell)
	var sw: Array = g.swatches
	var reps := int(g.get("repeats", 1))
	var kind: String = g.material
	match String(g.shape):
		"can":
			var r: float = s[0]
			var h: float = s[1]
			var top := String(sw[0]) if sw.size() > 0 else "silver"
			_lathe(kind, xf, cell, reps, [[r * .9, 0.0, top], [r, h * .025, [0.0, 1.0]], [r, h * .965, top], [r * .86, h, ""]], top, top)
		"tube":
			var r: float = s[0]
			var h: float = s[1]
			_lathe(kind, xf, cell, reps, [[r, 0.0, [0.0, 1.0]], [r, h * .97, String(sw[1])], [r * 1.03, h, ""]], String(sw[0]), String(sw[1]))
		"cup":
			_lathe(kind, xf, cell, reps, [[s[1], 0.0, [0.0, 1.0]], [s[0], s[2] * .97, "white"], [s[0] * 1.02, s[2], ""]], "white", "white")
		"bottle":
			var r: float = s[0]
			var h: float = s[1]
			var cap := String(sw[0])
			var drink := String(sw[1])
			_lathe("plastic", xf, cell, reps, [[r * .82, 0.0, drink], [r, h * .04, [0.0, 1.0]], [r, h * .66, drink],
				[r * .72, h * .76, drink], [r * .36, h * .84, drink], [r * .34, h * .9, cap], [r * .38, h * .9, cap], [r * .38, h, ""]], drink, cap)
		"box":
			_box(kind, xf, cell, Vector3(s[0], s[1], s[2]))
		"bag":
			_bag(kind, xf, cell, Vector3(s[0], s[1], s[2]))

## A flat sign or poster of an item's label, `size` wide, high and thick, its face toward local +Z.
func panel(item: String, xf: Transform3D, size: Vector3) -> void:
	var g: Dictionary = catalogue().goods[item]
	_box("paper", xf, int(g.cell), size)

## The meshes, added under `parent` (layer bits as the street's: 1 and 8, so the blood decals reach them).
func build(parent: Node3D, layers := 1 | 8) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for kind: String in _arrays:
		var a: Dictionary = _arrays[kind]
		if (a.v as PackedVector3Array).is_empty(): continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = a.v
		arrays[Mesh.ARRAY_NORMAL] = a.n
		arrays[Mesh.ARRAY_TEX_UV] = a.uv
		arrays[Mesh.ARRAY_INDEX] = a.i
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mi := MeshInstance3D.new()
		mi.name = "Goods_" + kind
		mi.mesh = mesh
		mi.material_override = material(kind)
		mi.layers = layers
		parent.add_child(mi)
		out.append(mi)
	_arrays.clear()
	return out

# ---------------------------------------------------------------- shapes

func _bucket(kind: String) -> Dictionary:
	if not _arrays.has(kind):
		_arrays[kind] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "i": PackedInt32Array()}
	return _arrays[kind]

func _cell_uv(cell: int, u: float, v: float) -> Vector2:
	var grid := int(catalogue().grid)
	var col := cell % grid
	var row := cell / grid
	return Vector2((col + PAD + u * (1.0 - 2.0 * PAD)) / grid, (row + PAD + v * (1.0 - 2.0 * PAD)) / grid)

func _swatch_uv(key: String) -> Vector2:
	var c: Dictionary = catalogue()
	var k := int(c.swatches.get(key, 0))
	return _cell_uv(int(c.swatch_cell), (k % 4 + .5) / 4.0, (k / 4 + .5) / 4.0)

## A turned shape: `rings` are [radius, height, band] from the bottom up, where band is the label's [v0, v1] or a
## swatch name for the stretch up to the next ring. Discs close the bottom and the top.
func _lathe(kind: String, xf: Transform3D, cell: int, reps: int, rings: Array, bottom: String, top: String) -> void:
	var a := _bucket(kind)
	var nb := xf.basis.inverse().transposed()
	var centre := .5 / reps
	for j in rings.size() - 1:
		var r0: float = rings[j][0]
		var y0: float = rings[j][1]
		var r1: float = rings[j + 1][0]
		var y1: float = rings[j + 1][1]
		var band = rings[j][2]
		var slope := Vector2(y1 - y0, r0 - r1).normalized()
		var base := (a.v as PackedVector3Array).size()
		for k in SEGMENTS + 1:
			var u := float(k) / SEGMENTS
			var t := (u - centre) * TAU
			var dir := Vector3(sin(t), 0, cos(t))
			for side in 2:
				var r := r0 if side == 0 else r1
				var y := y0 if side == 0 else y1
				a.v.append(xf * (dir * r + Vector3.UP * y))
				a.n.append((nb * (dir * slope.x + Vector3.UP * slope.y)).normalized())
				if band is Array:
					a.uv.append(_cell_uv(cell, u, lerpf(band[1], band[0], float(side))))
				else:
					a.uv.append(_swatch_uv(band))
		for k in SEGMENTS:
			var p := base + k * 2
			a.i.append_array([p, p + 1, p + 2, p + 1, p + 3, p + 2])
	_disc(a, xf, nb, rings[0][0], rings[0][1], _swatch_uv(bottom), false)
	_disc(a, xf, nb, rings[-1][0], rings[-1][1], _swatch_uv(top), true)

func _disc(a: Dictionary, xf: Transform3D, nb: Basis, r: float, y: float, uv: Vector2, up: bool) -> void:
	var base := (a.v as PackedVector3Array).size()
	var n := (nb * (Vector3.UP if up else Vector3.DOWN)).normalized()
	a.v.append(xf * (Vector3.UP * y))
	a.n.append(n)
	a.uv.append(uv)
	for k in SEGMENTS:
		var t := float(k) / SEGMENTS * TAU
		a.v.append(xf * Vector3(sin(t) * r, y, cos(t) * r))
		a.n.append(n)
		a.uv.append(uv)
	for k in SEGMENTS:
		var b := base + 1 + k
		var c := base + 1 + (k + 1) % SEGMENTS
		if up: a.i.append_array([base, c, b])
		else: a.i.append_array([base, b, c])

## A carton: the label on the front and the back, the edge colour of the label on the other four faces.
func _box(kind: String, xf: Transform3D, cell: int, s: Vector3) -> void:
	var a := _bucket(kind)
	var nb := xf.basis.inverse().transposed()
	var h := s * .5
	# [normal, right, up] for each face, and whether it carries the whole label.
	var faces := [[Vector3.BACK, Vector3.RIGHT, Vector3.UP, true], [Vector3.FORWARD, Vector3.LEFT, Vector3.UP, true],
		[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP, false], [Vector3.LEFT, Vector3.BACK, Vector3.UP, false],
		[Vector3.UP, Vector3.RIGHT, Vector3.FORWARD, false], [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK, false]]
	for f in faces:
		var n: Vector3 = f[0]
		var right: Vector3 = f[1]
		var up: Vector3 = f[2]
		var full: bool = f[3]
		var base := (a.v as PackedVector3Array).size()
		for corner: Vector2 in [Vector2(-1, 1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var p := n * (n.abs() * h).length() + right * corner.x * (right.abs() * h).length() + up * corner.y * (up.abs() * h).length()
			a.v.append(xf * (p + Vector3.UP * h.y))
			a.n.append((nb * n).normalized())
			var u := (corner.x + 1.0) * .5
			var v := (1.0 - corner.y) * .5
			a.uv.append(_cell_uv(cell, u if full else lerpf(.01, .035, u), v))
		a.i.append_array([base, base + 1, base + 2, base, base + 2, base + 3])

## A chip bag: two pillowed sheets meeting at a crimped rim, the label on both.
func _bag(kind: String, xf: Transform3D, cell: int, s: Vector3) -> void:
	var a := _bucket(kind)
	var nb := xf.basis.inverse().transposed()
	var nu := 8
	var nv := 10
	for side: float in [1.0, -1.0]:
		var base := (a.v as PackedVector3Array).size()
		for j in nv + 1:
			for k in nu + 1:
				var u := float(k) / nu
				var v := float(j) / nv
				var p := _bag_point(u, v, s, side)
				var du := _bag_point(minf(u + .01, 1.0), v, s, side) - _bag_point(maxf(u - .01, 0.0), v, s, side)
				var dv := _bag_point(u, minf(v + .01, 1.0), s, side) - _bag_point(u, maxf(v - .01, 0.0), s, side)
				var n := dv.cross(du).normalized() * side
				if n.length() < .5: n = Vector3.BACK * side
				a.v.append(xf * p)
				a.n.append((nb * n).normalized())
				a.uv.append(_cell_uv(cell, u if side > 0 else 1.0 - u, v))
		for j in nv:
			for k in nu:
				var p := base + j * (nu + 1) + k
				var q := p + nu + 1
				if side > 0: a.i.append_array([p, p + 1, q, q, p + 1, q + 1])
				else: a.i.append_array([p, q, p + 1, q, q + 1, p + 1])

func _bag_point(u: float, v: float, s: Vector3, side: float) -> Vector3:
	var crimp := clampf((v - .07) / .86, 0.0, 1.0)
	var swell := pow(sin(PI * u), .55) * pow(sin(PI * crimp), .7)
	# The sides draw in a little where the bag puffs out.
	var x := (u - .5) * s.x * (1.0 - .08 * sin(PI * crimp))
	return Vector3(x, (1.0 - v) * s.y, side * swell * s.z * .5)
