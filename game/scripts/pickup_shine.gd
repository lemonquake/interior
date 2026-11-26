extends RefCounted
## 0.58: the white shine on pickups: every mesh of the item gets the shine overlay (scripts/pickup_shine.gdshader:
## a white rim, a breathing fill and a glint sweeping across it), and a twinkle (scripts/pickup_twinkle.gdshader)
## flares on it every couple of seconds. One shared material each for all of them.

const SHADER := preload("res://scripts/pickup_shine.gdshader")
const TWINKLE := preload("res://scripts/pickup_twinkle.gdshader")
static var _material: ShaderMaterial
static var _twinkle: ShaderMaterial
static var _quad: QuadMesh

static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
	return _material

## Every mesh under `node` (and `node` itself) shines; `twinkle_at` (local to `node`) is where the twinkle sits,
## or none with `twinkle := false`; `size` is the twinkle's width in metres (0.59: smaller for the story's small
## things on a dresser or in a drawer). The twinkle draws on the same render layers as the item's meshes.
static func apply(node: Node, twinkle := true, twinkle_at := Vector3(0, .16, 0), size := .42) -> void:
	if node == null: return
	var layers := 0
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_overlay = material()
		layers = (node as MeshInstance3D).layers
	for m in node.find_children("*", "MeshInstance3D", true, false):
		if m.name == "Twinkle": continue
		(m as MeshInstance3D).material_overlay = material()
		if layers == 0: layers = (m as MeshInstance3D).layers
	if twinkle and node is Node3D and (node as Node3D).get_node_or_null("Twinkle") == null:
		if _twinkle == null:
			_twinkle = ShaderMaterial.new()
			_twinkle.shader = TWINKLE
			_quad = QuadMesh.new()
			_quad.size = Vector2.ONE
		var star := MeshInstance3D.new()
		star.name = "Twinkle"
		star.mesh = _quad
		star.material_override = _twinkle
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		star.extra_cull_margin = .5
		if layers != 0: star.layers = layers
		node.add_child(star)
		star.position = twinkle_at
		# The quad's world size comes from its scale (the shader keeps it facing the camera).
		var outer := (node as Node3D).global_transform.basis.get_scale() if node.is_inside_tree() else Vector3.ONE
		star.scale = Vector3.ONE * (size / maxf(outer.x, .01))
