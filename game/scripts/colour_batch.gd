class_name InteriorColourBatch
extends RefCounted
## 0.65: fewer draws for the districts built from box kits (Store Road, the backstreets, PILCST, Outer Street).
##
## Each district merged its boxes into one mesh per material id, and most ids differ only in their colour ("#a8885a",
## "#5a3a28", "painted_plaster_wall|#d8d0bc" ...): Store Road alone drew ~200 meshes that were the same material in
## all but colour, each its own draw. On a phone a draw is most of the frame's processor time. Here the kits whose
## materials match in everything but `albedo_color` (texture, triplanar scale, roughness, transparency, emission ...,
## and how the caller dresses the mesh: layers, shadow, distance range) go into one mesh, the colour carried by the
## vertices: the material multiplies the same colour in, from the vertex instead of the uniform (sRGB in, linear
## out, as the uniform is). A material alone in its group keeps its own mesh and material exactly as before.

## Signature (everything that is not the colour) per material instance; "" = never shares.
static var _signatures := {}
## The shared material per signature (white, colour from the vertices).
static var _merged := {}
## Merged meshes are cut into squares this big (m).
const CELL := 24.0
const SKIP := ["albedo_color", "resource_name", "resource_path", "resource_local_to_scene", "resource_scene_unique_id", "script"]

static func signature(m: Material) -> String:
	if m == null: return ""
	var key := m.get_instance_id()
	if _signatures.has(key): return _signatures[key]
	var sig := ""
	var sm := m as StandardMaterial3D
	# (Never a glowing one: lamps flicker and switch by changing their own material while the game runs, school.gd
	# and outer_kit.gd `lamps`; a merged copy would stay as it was built.)
	if sm != null and not sm.vertex_color_use_as_albedo and sm.next_pass == null and not sm.emission_enabled:
		var parts := PackedStringArray([m.get_class()])
		for p: Dictionary in sm.get_property_list():
			if not (int(p.usage) & PROPERTY_USAGE_STORAGE): continue
			var n: String = p.name
			if n in SKIP: continue
			var v: Variant = sm.get(n)
			if v is Resource:
				parts.append("%s=%s" % [n, (v as Resource).resource_path if (v as Resource).resource_path != "" else str((v as Resource).get_instance_id())])
			else:
				parts.append("%s=%s" % [n, str(v)])
		sig = ",".join(parts)
	_signatures[key] = sig
	return sig

static func merged_material(sig: String, like: StandardMaterial3D) -> StandardMaterial3D:
	if _merged.has(sig): return _merged[sig]
	var m := like.duplicate() as StandardMaterial3D
	m.albedo_color = Color.WHITE
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.resource_name = "colour batch"
	_merged[sig] = m
	return m

## The kits (id -> InteriorBoxKit) made into meshes under `parent`. `material_of(id)` is the id's material,
## `dress(mesh, id)` sets what the caller sets on each mesh (layers, shadow, range): ids dressed differently never
## share a mesh. Returns how many meshes were made.
static func commit_kits(parent: Node3D, kits: Dictionary, material_of: Callable, dress: Callable) -> int:
	var groups := {}
	var order: Array[String] = []
	var probe := MeshInstance3D.new()
	var plain := MeshInstance3D.new()
	for id: String in kits:
		var kit: InteriorBoxKit = kits[id]
		if kit == null or kit.is_empty(): continue
		var m: Material = material_of.call(id)
		probe.layers = plain.layers
		probe.cast_shadow = plain.cast_shadow
		probe.visibility_range_begin = 0.0
		probe.visibility_range_end = 0.0
		probe.visibility_range_end_margin = 0.0
		probe.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		probe.gi_mode = plain.gi_mode
		dress.call(probe, id)
		var look := "%d|%d|%.3f|%.3f|%.3f|%d|%d" % [probe.layers, probe.cast_shadow, probe.visibility_range_begin, probe.visibility_range_end, probe.visibility_range_end_margin, probe.visibility_range_fade_mode, probe.gi_mode]
		var sig := signature(m)
		var key := ("solo:" + id) if sig == "" or "--no-colour-batch" in OS.get_cmdline_user_args() else (sig + "#" + look)
		if not groups.has(key):
			groups[key] = {"sig": sig, "ids": []}
			order.append(key)
		groups[key].ids.append(id)
	probe.free()
	plain.free()
	var made := 0
	for key in order:
		var ids: Array = groups[key].ids
		var mesh := MeshInstance3D.new()
		var first: String = ids[0]
		if ids.size() == 1:
			mesh.mesh = (kits[first] as InteriorBoxKit).commit()
			mesh.material_override = material_of.call(first)
			dress.call(mesh, first)
			parent.add_child(mesh)
			made += 1
			continue
		mesh.free()
		# Merged by place too (CELL squares): each mesh stays near the lamps that light it (a phone lights each mesh
		# with two lamps at most) and what is off screen is still left out.
		var cells := {}
		for id: String in ids:
			var kit: InteriorBoxKit = kits[id]
			var colour := (material_of.call(id) as StandardMaterial3D).albedo_color
			for k in kit.shape_v.size():
				var p := kit.vertices[kit.shape_v[k]]
				var c := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
				if not cells.has(c): cells[c] = InteriorBoxKit.new()
				(cells[c] as InteriorBoxKit).take_shape(kit, k, colour)
		var material := merged_material(str(groups[key].sig), material_of.call(first))
		for c: Vector2i in cells:
			var part := MeshInstance3D.new()
			part.mesh = (cells[c] as InteriorBoxKit).commit()
			part.material_override = material
			part.name = "Colour batch %d" % made
			dress.call(part, first)
			parent.add_child(part)
			made += 1
	return made
