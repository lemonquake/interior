class_name InteriorBoxKit
extends RefCounted
## 0.34: boxes and cylinders by the hundred, into one mesh.
##
## `SurfaceTool.append_from(BoxMesh.new(), ...)` makes each box on the graphics card and reads it back: most of a
## millisecond a box, and the fences that shut the map are four hundred of them. Here the unit box (and a unit
## cylinder for each number of sides) is read once; every box after that is its twenty-four corners turned and
## moved in script. `pour` puts the lot into a SurfaceTool in one go (the same vertices and indices `append_from`
## would have added, box by box), `commit` makes a mesh of them by themselves.

static var _unit_box: Array = []
static var _unit_cylinders := {}

var vertices := PackedVector3Array()
var normals := PackedVector3Array()
var tangents := PackedFloat32Array()
var uvs := PackedVector2Array()
var indices := PackedInt32Array()
## 0.65: per-vertex colours, only once another kit has been taken in (`take`, InteriorColourBatch).
var colors := PackedColorArray()
## 0.65: where each shape starts (its first vertex, its first index), so a kit can be split by place.
var shape_v := PackedInt32Array()
var shape_i := PackedInt32Array()

func box(size: Vector3, xf: Transform3D) -> void:
	if _unit_box.is_empty():
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		_unit_box = mesh.get_mesh_arrays()
	_add(_unit_box, size, xf)

func cylinder(radius: float, height: float, sides: int, xf: Transform3D) -> void:
	if not _unit_cylinders.has(sides):
		var mesh := CylinderMesh.new()
		mesh.top_radius = 1.0
		mesh.bottom_radius = 1.0
		mesh.height = 1.0
		mesh.radial_segments = sides
		mesh.rings = 1
		_unit_cylinders[sides] = mesh.get_mesh_arrays()
	_add(_unit_cylinders[sides], Vector3(radius, height, radius), xf)

func _add(unit: Array, scale: Vector3, xf: Transform3D) -> void:
	var v: PackedVector3Array = unit[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = unit[Mesh.ARRAY_NORMAL]
	var t: PackedFloat32Array = unit[Mesh.ARRAY_TANGENT]
	var uv: PackedVector2Array = unit[Mesh.ARRAY_TEX_UV]
	var index: PackedInt32Array = unit[Mesh.ARRAY_INDEX]
	var base := vertices.size()
	shape_v.append(base)
	shape_i.append(indices.size())
	var basis := xf.basis
	for i in v.size():
		vertices.append(xf * (v[i] * scale))
		normals.append(basis * n[i])
		var along := basis * Vector3(t[i * 4], t[i * 4 + 1], t[i * 4 + 2])
		tangents.append(along.x)
		tangents.append(along.y)
		tangents.append(along.z)
		tangents.append(t[i * 4 + 3])
	uvs.append_array(uv)
	for i in index:
		indices.append(base + i)

## 0.65: another kit's shapes added to these, all in one colour (InteriorColourBatch). Shapes added without a colour
## are white.
func take(other: InteriorBoxKit, colour: Color) -> void:
	var base := vertices.size()
	if colors.size() < base:
		var pad := PackedColorArray()
		pad.resize(base - colors.size())
		pad.fill(Color.WHITE)
		colors.append_array(pad)
	vertices.append_array(other.vertices)
	normals.append_array(other.normals)
	tangents.append_array(other.tangents)
	uvs.append_array(other.uvs)
	var tint := PackedColorArray()
	tint.resize(other.vertices.size())
	tint.fill(colour)
	colors.append_array(tint)
	var start := indices.size()
	indices.append_array(other.indices)
	if base != 0:
		for i in range(start, indices.size()):
			indices[i] += base

## 0.65: shape `k` of another kit added to these in one colour (InteriorColourBatch, by place).
func take_shape(other: InteriorBoxKit, k: int, colour: Color) -> void:
	var v0 := other.shape_v[k]
	var v1 := other.shape_v[k + 1] if k + 1 < other.shape_v.size() else other.vertices.size()
	var i0 := other.shape_i[k]
	var i1 := other.shape_i[k + 1] if k + 1 < other.shape_i.size() else other.indices.size()
	var base := vertices.size()
	if colors.size() < base:
		var pad := PackedColorArray()
		pad.resize(base - colors.size())
		pad.fill(Color.WHITE)
		colors.append_array(pad)
	shape_v.append(base)
	shape_i.append(indices.size())
	vertices.append_array(other.vertices.slice(v0, v1))
	normals.append_array(other.normals.slice(v0, v1))
	tangents.append_array(other.tangents.slice(v0 * 4, v1 * 4))
	uvs.append_array(other.uvs.slice(v0, v1))
	var tint := PackedColorArray()
	tint.resize(v1 - v0)
	tint.fill(colour)
	colors.append_array(tint)
	var shift := base - v0
	for i in range(i0, i1):
		indices.append(other.indices[i] + shift)

func is_empty() -> bool:
	return vertices.is_empty()

func clear() -> void:
	vertices = PackedVector3Array()
	normals = PackedVector3Array()
	tangents = PackedFloat32Array()
	uvs = PackedVector2Array()
	indices = PackedInt32Array()
	colors = PackedColorArray()
	shape_v = PackedInt32Array()
	shape_i = PackedInt32Array()

## A mesh of what was added; null when nothing was.
func commit() -> ArrayMesh:
	if vertices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	if not colors.is_empty():
		if colors.size() < vertices.size():
			var pad := PackedColorArray()
			pad.resize(vertices.size() - colors.size())
			pad.fill(Color.WHITE)
			colors.append_array(pad)
		arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## Everything added so far into `tool`, and start again.
func pour(tool: SurfaceTool) -> void:
	var mesh := commit()
	if mesh != null:
		tool.append_from(mesh, 0, Transform3D.IDENTITY)
	clear()
