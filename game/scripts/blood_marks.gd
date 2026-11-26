class_name InteriorBloodMarks
extends Node3D
## 0.64: the blood on a phone. The phone renderer (Compatibility) cannot draw Decal nodes, so until now a phone got
## none of it: no splats, no spots under a bleeding wound, no pools, no wounds on the bodies (scripts/blood.gd
## returned early on every one). Here the same marks lie on the surfaces as flat quads cut from one sheet of all
## the blood pictures (tools/blood_atlas.py), with the decals' normal map and wet roughness, so they take the moon,
## a lamp or the flashlight the same way.
##
## Cost: marks on the ground and walls (nearly all of them) share one MultiMesh per 12 m patch of the world, so a
## street full of blood is a handful of draw calls, not hundreds. A mark on something that moves (a prop that was
## knocked over, a part of a body) is its own small mesh under it, so it moves (and is interpolated) with it.
## A wound on a body is a flattened blob that sinks into the part: what shows is the cap outside the skin, wherever
## the skin is, which a flat quad on the hit box could not promise.
##
## `blood.gd` asks `mark()` for a node and uses it the way it used a Decal: `size`, `modulate`, a transform with
## the picture's bottom along +Z and the surface normal along +Y, tweens on `size` and `position`, `queue_free`.

const ATLAS_ALBEDO := "res://assets/zombies/blood/mobile_atlas_albedo.png"
const ATLAS_NORMAL := "res://assets/zombies/blood/mobile_atlas_normal.png"
## Atlas cell of each picture (tools/blood_atlas.py order).
const CELLS := {"splat_a": 0, "splat_b": 1, "splat_c": 2, "splat_d": 3, "splat_e": 4, "drops_a": 5, "drops_b": 6,
	"pool_a": 7, "pool_b": 8, "blot_0": 9, "blot_1": 10, "blot_2": 11, "blot_3": 12}
const CHUNK := 12.0
## Instances a patch starts with; it doubles when full.
const START := 24
## Floats per instance in a MultiMesh buffer: transform (12), colour (4), custom (4).
const STRIDE := 20
## Above the surface (m). The shader also pulls every mark a hair toward the eye, so none of them fights the
## surface under it at any distance.
const LIFT := .003

const SHADER := "shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, shadows_disabled;
uniform sampler2D albedo_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D normal_atlas : hint_normal, filter_linear_mipmap, repeat_disable;
varying vec4 tint;
varying vec2 cell;
varying float fade_at;
void vertex() {
	tint = COLOR;
	float c = INSTANCE_CUSTOM.x;
	cell = vec2(mod(c, 4.0), floor(c / 4.0 + .01));
	fade_at = INSTANCE_CUSTOM.y;
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view.xyz *= .9985;
	POSITION = PROJECTION_MATRIX * view;
}
void fragment() {
	vec2 uv = (cell + clamp(UV, vec2(.004), vec2(.996))) * .25;
	vec4 a = texture(albedo_atlas, uv);
	float far = length(VERTEX);
	float fade = 1.0 - clamp((far - fade_at) / max(fade_at * .3, .5), 0.0, 1.0);
	ALBEDO = a.rgb * tint.rgb;
	ALPHA = a.a * tint.a * fade;
	NORMAL_MAP = texture(normal_atlas, uv).rgb;
	ROUGHNESS = .16;
	SPECULAR = .5;
}
"

var material: ShaderMaterial
var wound_material: StandardMaterial3D
var plane: PlaneMesh
var blob: SphereMesh
var _sheets := {}
var stats := {"sheets": 0, "marks": 0, "own": 0}

func setup() -> void:
	name = "BloodMarks"
	var shader := Shader.new()
	shader.code = SHADER
	material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("albedo_atlas", load(ATLAS_ALBEDO))
	material.set_shader_parameter("normal_atlas", load(ATLAS_NORMAL))
	plane = PlaneMesh.new()
	plane.size = Vector2.ONE
	plane.material = material
	# The wound blob: wet, dark, opaque (it is what is left of the skin there).
	wound_material = StandardMaterial3D.new()
	wound_material.albedo_color = Color(.2, .008, .01)
	wound_material.roughness = .16
	wound_material.metallic_specular = .55
	blob = SphereMesh.new()
	blob.radius = .5
	blob.height = 1.0
	blob.radial_segments = 10
	blob.rings = 5
	blob.material = wound_material

## A new mark showing atlas cell `key` (CELLS). It is not in the tree yet: the caller adds it where it belongs and
## sets its transform, as with a Decal.
func mark(key: String, size: Vector3, tint: Color, fade_begin: float) -> Mark:
	var m := Mark.new()
	m.marks = self
	m.cell = int(CELLS.get(key, 0))
	m.fade = fade_begin
	m.size = size
	m.modulate = tint
	return m

## A wound for a body part (blood.gd `wound_decal`).
func wound() -> Mark:
	var m := Mark.new()
	m.marks = self
	m.is_wound = true
	m.fade = 22.0
	m.size = Vector3(.17, .26, .17)
	return m

## The draw call that holds the marks of the patch around `at`.
func _sheet(key: Vector3i) -> Sheet:
	var sheet: Sheet = _sheets.get(key)
	if sheet != null:
		return sheet
	sheet = Sheet.new()
	sheet.mm = MultiMesh.new()
	sheet.mm.transform_format = MultiMesh.TRANSFORM_3D
	sheet.mm.use_colors = true
	sheet.mm.use_custom_data = true
	sheet.mm.mesh = plane
	sheet.mm.instance_count = START
	sheet.node = MultiMeshInstance3D.new()
	sheet.node.name = "Patch %d %d %d" % [key.x, key.y, key.z]
	sheet.node.multimesh = sheet.mm
	sheet.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sheet.node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	sheet.node.layers = 3
	# The patch and a margin: a big splat can reach past its own patch.
	var corner := Vector3(key) * CHUNK
	sheet.node.custom_aabb = AABB(corner - Vector3.ONE * 2.0, Vector3.ONE * (CHUNK + 4.0))
	add_child(sheet.node)
	for i in range(START - 1, -1, -1):
		sheet.free.append(i)
	_sheets[key] = sheet
	stats.sheets = _sheets.size()
	return sheet

static func patch(at: Vector3) -> Vector3i:
	return Vector3i(floori(at.x / CHUNK), floori(at.y / CHUNK), floori(at.z / CHUNK))

func _take(sheet: Sheet) -> int:
	if sheet.free.is_empty():
		var count := sheet.mm.instance_count
		var keep := sheet.mm.buffer
		sheet.mm.instance_count = count * 2
		var grown := PackedFloat32Array()
		grown.resize(count * 2 * STRIDE)
		for i in keep.size():
			grown[i] = keep[i]
		sheet.mm.buffer = grown
		for i in range(count * 2 - 1, count - 1, -1):
			sheet.free.append(i)
	stats.marks += 1
	return sheet.free.pop_back()

func _give_back(sheet: Sheet, slot: int) -> void:
	if sheet == null or slot < 0:
		return
	sheet.mm.set_instance_transform(slot, Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO))
	sheet.mm.set_instance_color(slot, Color(0, 0, 0, 0))
	sheet.free.append(slot)
	stats.marks -= 1

class Sheet:
	var node: MultiMeshInstance3D
	var mm: MultiMesh
	var free: Array[int] = []

## One mark: where it lies, how big, what tint. On the world it is a slot in its patch's MultiMesh; on anything
## that moves it is a mesh of its own under that thing.
class Mark extends Node3D:
	var marks: InteriorBloodMarks
	var cell := 0
	var fade := 40.0
	var is_wound := false
	var cull_mask := 3:
		set(value):
			cull_mask = value
			if _own != null:
				_own.layers = value
	var size := Vector3.ONE:
		set(value):
			size = value
			_sync()
	var modulate := Color.WHITE:
		set(value):
			modulate = value
			_sync()
	var _sheet: InteriorBloodMarks.Sheet
	var _slot := -1
	var _key := Vector3i.MAX
	var _own: GeometryInstance3D
	var _own_mm: MultiMesh

	func _init() -> void:
		name = "Blood"
		add_to_group("blood_decals")

	func _notification(what: int) -> void:
		if what == NOTIFICATION_ENTER_TREE:
			# On the world: follow its own transform into the patch. On a body or a prop: a child mesh does it.
			set_notify_transform(_on_world())
			_sync()
		elif what == NOTIFICATION_TRANSFORM_CHANGED:
			_sync()
		elif what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_PREDELETE:
			if marks != null and is_instance_valid(marks) and _sheet != null:
				marks._give_back(_sheet, _slot)
			_sheet = null
			_slot = -1
			_key = Vector3i.MAX

	func _on_world() -> bool:
		return not is_wound and get_parent() == marks

	func _sync() -> void:
		if not is_inside_tree() or marks == null:
			return
		if is_wound:
			if _own == null:
				var mesh := MeshInstance3D.new()
				mesh.mesh = marks.blob
				_own = mesh
				_setup_own()
			# Flattened into the skin; the run tweened onto `size.z` draws it down the part.
			_own.transform = Transform3D(Basis.from_scale(Vector3(size.x * .42, .045, size.z * .5)), Vector3(0, 0, size.z * .12))
			return
		var scaled := Basis.from_scale(Vector3(maxf(size.x, .001), 1.0, maxf(size.z, .001)))
		var custom := Color(float(cell), fade, 0.0, 0.0)
		if not _on_world():
			if _own == null:
				_own_mm = MultiMesh.new()
				_own_mm.transform_format = MultiMesh.TRANSFORM_3D
				_own_mm.use_colors = true
				_own_mm.use_custom_data = true
				_own_mm.mesh = marks.plane
				_own_mm.instance_count = 1
				var holder := MultiMeshInstance3D.new()
				holder.multimesh = _own_mm
				_own = holder
				_setup_own()
			_own_mm.set_instance_transform(0, Transform3D(scaled, Vector3.UP * InteriorBloodMarks.LIFT))
			_own_mm.set_instance_color(0, modulate)
			_own_mm.set_instance_custom_data(0, custom)
			return
		var at := global_transform
		var key := InteriorBloodMarks.patch(at.origin)
		if key != _key:
			if _sheet != null:
				marks._give_back(_sheet, _slot)
			_key = key
			_sheet = marks._sheet(key)
			_slot = marks._take(_sheet)
		var placed := Transform3D(at.basis.orthonormalized() * scaled, at.origin + at.basis.y.normalized() * InteriorBloodMarks.LIFT)
		_sheet.mm.set_instance_transform(_slot, placed)
		_sheet.mm.set_instance_color(_slot, modulate)
		_sheet.mm.set_instance_custom_data(_slot, custom)

	func _setup_own() -> void:
		_own.name = "Mark"
		_own.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_own.layers = cull_mask
		_own.visibility_range_end = fade + 6.0
		_own.visibility_range_end_margin = 2.0
		_own.extra_cull_margin = .2
		add_child(_own)
		marks.stats.own += 1
