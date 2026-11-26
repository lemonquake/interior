extends RefCounted
## Shared generated albedo and surface-conforming decals for desktop and Compatibility/Android.
## The original PNG alpha is retained; the game lighting supplies the night/flashlight response.

const ROOT := "res://assets/horror_textures/liquid/"
const TINT := Color(.58, .48, .40, 1.0)
static var _images: Dictionary = {}
static var _orm: Texture2D

static func texture_set(kind: String) -> Array:
	var file := ""
	if kind.begins_with("splat") or kind == "spatter_floor":
		file = "splatter"
	elif kind.begins_with("drag_") or kind in ["smear_wall", "scrape"]:
		file = "drag_smear"
	elif kind.begins_with("pool"):
		file = "pool"
	if file.is_empty():
		return []
	if not _images.has(file):
		_images[file] = load(ROOT + file + ".png")
	if _orm == null:
		# Uniform nonmetallic, damp roughness: no unrelated normal pattern under the new alpha.
		var scalar := Image.create(1, 1, false, Image.FORMAT_RGB8)
		scalar.fill(Color(1.0, .52, 0.0))
		_orm = ImageTexture.create_from_image(scalar)
	return [_images[file], null, _orm]

static func finish(decal: Decal, generated: bool) -> void:
	if generated:
		decal.modulate *= TINT
		decal.add_to_group("red_liquid_decals")
		decal.set_meta("generated_albedo", true)
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		# Native Decal is unavailable in Compatibility. Keep its data for inspection,
		# and bake only the actual static receiving surfaces into a transparent mesh.
		decal.visible = false
		InteriorLoadClock.later(_build_fallback.bind(decal))

static func _build_fallback(decal: Decal) -> void:
	if not is_instance_valid(decal) or not decal.is_inside_tree():
		return
	var tree := decal.get_tree()
	for frame in 3:
		await tree.physics_frame
		if not is_instance_valid(decal) or not decal.is_inside_tree():
			return
	var space := decal.get_world_3d().direct_space_state
	var nx := clampi(ceili(decal.size.x / .25), 2, 12)
	var nz := clampi(ceili(decal.size.z / .25), 2, 12)
	var samples: Array = []
	var normals: Array = []
	var valid: Array[bool] = []
	var up := decal.global_basis.y.normalized()
	for z in nz + 1:
		for x in nx + 1:
			var uv := Vector2(float(x) / nx, float(z) / nz)
			var local := Vector3((uv.x - .5) * decal.size.x, 0, (uv.y - .5) * decal.size.z)
			var center := decal.to_global(local)
			var half_depth := decal.size.y * .5 + .025
			var query := PhysicsRayQueryParameters3D.create(center + up * half_depth, center - up * half_depth, 2)
			var hit := space.intersect_ray(query)
			var accepted := not hit.is_empty()
			if accepted:
				accepted = (hit.normal as Vector3).dot(up) > .35 and not hit.collider is RigidBody3D and not hit.collider is AnimatableBody3D
			valid.append(accepted)
			var receiver: Vector3 = hit.position + hit.normal * .004 if accepted else center
			# Town asphalt, paint and silt are visual sheets over the walking slab
			# (neighborhood_builder.gd / neighborhood_ground.gd). Clear their top,
			# while keeping the pavement and walls on the exact sampled receiver.
			if accepted and decal.get_parent().has_method("ground_y") and up.y > .9:
				if receiver.y < -2.87 and receiver.y > -3.0 and InteriorSurfaces.at(receiver) == "asphalt":
					receiver.y = maxf(receiver.y, -2.9 + .038)
			samples.append(decal.to_local(receiver) if accepted else local)
			normals.append(decal.global_basis.inverse() * (hit.normal as Vector3) if accepted else Vector3.UP)
	# 0.65: the stain's triangles go into the batch of its texture and its 16 m square (one draw for every stain of
	# a kind there; each was its own mesh and material, ~190 draws along Store Road on a phone).
	var to_parent := decal.transform
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	for z in nz:
		for x in nx:
			var a := z * (nx + 1) + x
			var b := a + 1
			var c := a + nx + 2
			var d := a + nx + 1
			# A missing receiver leaves a hole rather than a floating quad across a gate/doorway.
			if not (valid[a] and valid[b] and valid[c] and valid[d]):
				continue
			# Keep a stair riser, wall edge or kerb from becoming a slanted floating stain.
			var low := minf(minf(samples[a].y, samples[b].y), minf(samples[c].y, samples[d].y))
			var high := maxf(maxf(samples[a].y, samples[b].y), maxf(samples[c].y, samples[d].y))
			if high - low > .09:
				continue
			for i in [a, b, c, a, c, d]:
				norms.append((to_parent.basis * (normals[i] as Vector3)).normalized())
				uvs.append(Vector2(float(i % (nx + 1)) / nx, float(floori(float(i) / (nx + 1))) / nz))
				verts.append(to_parent * (samples[i] as Vector3))
	if verts.is_empty():
		return
	var batch := _batch_for(decal)
	batch.add(verts, norms, uvs, decal.modulate, decal.distance_fade_begin + decal.distance_fade_length)
	decal.set_meta("compatibility_batch", batch.get_path())

## The shared stain material per texture (white; the colour and alpha of each stain ride on its vertices).
static var _batch_mats: Dictionary = {}
static var _batches: Dictionary = {}
const BATCH_CELL := 16.0

static func _batch_material(texture: Texture2D) -> StandardMaterial3D:
	var key := texture.get_instance_id() if texture != null else 0
	if _batch_mats.has(key): return _batch_mats[key]
	var mat := StandardMaterial3D.new()
	mat.resource_name = "Red liquid / Compatibility surface"
	mat.albedo_texture = texture
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = .72
	mat.metallic = 0.0
	mat.metallic_specular = .12
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_repeat = false
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_batch_mats[key] = mat
	return mat

static func _batch_for(decal: Decal) -> LiquidBatch:
	var parent := decal.get_parent()
	var p := decal.position
	var key := "%d|%d|%d|%d|%d" % [parent.get_instance_id(), decal.texture_albedo.get_instance_id() if decal.texture_albedo != null else 0, decal.cull_mask, floori(p.x / BATCH_CELL), floori(p.z / BATCH_CELL)]
	# (`-- --no-colour-batch`: one per stain, as before 0.65, for comparing.)
	if "--no-colour-batch" in OS.get_cmdline_user_args(): key += "|%d" % decal.get_instance_id()
	var batch: LiquidBatch = _batches.get(key) if _batches.has(key) and is_instance_valid(_batches[key]) else null
	if batch == null:
		batch = LiquidBatch.new()
		batch.name = "Surface decals (Android)"
		batch.material_override = _batch_material(decal.texture_albedo)
		batch.layers = decal.cull_mask
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.add_to_group("compatibility_surface_decals")
		batch.position = Vector3((floori(p.x / BATCH_CELL) + .5) * BATCH_CELL, p.y, (floori(p.z / BATCH_CELL) + .5) * BATCH_CELL)
		parent.add_child(batch)
		_batches[key] = batch
	return batch

## One draw for many stains (parent space, non-indexed triangles), rebuilt once at the end of a frame that added any.
class LiquidBatch extends MeshInstance3D:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var reach := 0.0
	var _dirty := false

	func add(v: PackedVector3Array, n: PackedVector3Array, uv: PackedVector2Array, colour: Color, range_end: float) -> void:
		# (Given in the parent's space; kept round this node, which sits in the middle of its square.)
		for i in v.size(): v[i] -= position
		verts.append_array(v)
		norms.append_array(n)
		uvs.append_array(uv)
		var c := PackedColorArray()
		c.resize(v.size())
		c.fill(colour)
		cols.append_array(c)
		# (Its range from its middle: each stain's own, and the reach across the square.)
		reach = maxf(reach, range_end + BATCH_CELL * .75)
		visibility_range_end = reach
		if not _dirty:
			_dirty = true
			_rebuild.call_deferred()

	func _rebuild() -> void:
		_dirty = false
		if verts.is_empty(): return
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = norms
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_COLOR] = cols
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh = m
