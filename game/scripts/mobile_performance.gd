extends Node
## Mobile render budgets. Geometry and physics remain intact at every tier.
##
## 0.64: the budgets also reach what is built after start-up. The squad game builds its districts (Store Road, the
## mart, the backstreets, the school, Outer Street) as the run goes; none of it had a distance limit on a phone, so
## the store run alone was 4,200 draw calls a frame there. New geometry and lights are picked up as they enter the
## tree and get the same budget a moment later (once their builders have given them a mesh and a place).
var _main: Node
var _meshes: Array[GeometryInstance3D] = []
var _lights: Array[Light3D] = []
var _materials: Dictionary = {}
var _ranges: Dictionary = {}
var _disabled_shadows: Array[Light3D] = []
var _tier := 0
var stats: Dictionary = {}
## 0.64: the level's render scale ceiling (its pixel budget); performance.gd moves the scale below it by frame time.
var ceiling := 1.0
var _ready_to_budget := false
var _arrived: Array[Node] = []
var _arrived_t := 0.0

func setup(main: Node) -> void:
	_main = main
	name = "Mobile performance"
	get_window().size_changed.connect(_resize)
	_resize()
	# Runtime doors, chairs and surface decals are installed after _ready().
	while InteriorLoadClock.staged: await get_tree().process_frame
	for i in 5: await get_tree().physics_frame
	if not is_instance_valid(_main): return
	for node in _main.find_children("*", "GeometryInstance3D", true, false):
		_register(node as GeometryInstance3D)
	for node in _main.find_children("*", "Light3D", true, false):
		_lights.append(node)
	_ready_to_budget = true
	get_tree().node_added.connect(_on_added)
	apply_quality(_main.quality)

func _register(geometry: GeometryInstance3D) -> void:
	_meshes.append(geometry)
	_ranges[geometry.get_instance_id()] = geometry.visibility_range_end
	if geometry is MeshInstance3D and geometry.mesh != null:
		for s in geometry.mesh.get_surface_count():
			var mat := geometry.get_active_material(s) as BaseMaterial3D
			if mat != null and not _materials.has(mat):
				_materials[mat] = {"normal":mat.normal_enabled,"detail":mat.detail_enabled,
					"clearcoat":mat.clearcoat_enabled,"height":mat.heightmap_enabled}

func _on_added(node: Node) -> void:
	# Not the bodies (the infected, the squad: never hidden by distance, a sniper sees them far off) and not the
	# short-lived bursts.
	if node is GPUParticles3D or node is CPUParticles3D or node.get_parent() is Skeleton3D:
		return
	if node is GeometryInstance3D or node is Light3D:
		_arrived.append(node)

func _process(delta: float) -> void:
	if _arrived.is_empty() or not _ready_to_budget:
		return
	_arrived_t += delta
	if _arrived_t < .5:
		return
	_arrived_t = .45
	# A district going up adds thousands at once: a few hundred a frame, so its budget never costs one long frame.
	var batch := _arrived.slice(0, 300)
	_arrived = _arrived.slice(300)
	if _arrived.is_empty():
		_arrived_t = 0.0
	for node in batch:
		if not is_instance_valid(node) or not node.is_inside_tree() or not _main.is_ancestor_of(node):
			continue
		if node is Light3D:
			var light := node as Light3D
			_lights.append(light)
			if _tier == 0 and light.shadow_enabled:
				_disabled_shadows.append(light)
				light.shadow_enabled = false
			continue
		var geometry := node as GeometryInstance3D
		if _ranges.has(geometry.get_instance_id()):
			continue
		var known := _materials.size()
		_register(geometry)
		_budget(geometry)
		if _materials.size() != known:
			_material_budget()
	stats["late"] = int(stats.get("late", 0)) + batch.size()
	# What was freed since (bursts, gibs, a district let go of) leaves the lists now and then.
	if _meshes.size() > int(stats.get("pruned_at", 0)) + 2000:
		var kept: Array[GeometryInstance3D] = []
		for geometry in _meshes:
			if is_instance_valid(geometry):
				kept.append(geometry)
		_meshes = kept
		stats["pruned_at"] = _meshes.size()

func apply_quality(tier: int) -> void:
	_tier = tier
	_resize()
	var viewport := get_viewport()
	viewport.mesh_lod_threshold = [4.0, 2.0, 1.0][clampi(tier,0,2)]
	var ranged := 0
	for geometry in _meshes:
		if not is_instance_valid(geometry): continue
		if _budget(geometry):
			ranged += 1
	_material_budget()
	if tier > 0:
		for light in _disabled_shadows:
			if is_instance_valid(light): light.shadow_enabled = true
		_disabled_shadows.clear()
	else:
		for light in _lights:
			if is_instance_valid(light) and light.shadow_enabled:
				if not light in _disabled_shadows: _disabled_shadows.append(light)
				light.shadow_enabled = false
	stats = {"geometry":_meshes.size(),"range_culled":ranged,"materials":_materials.size(),
		"lod_threshold":viewport.mesh_lod_threshold,"tier":tier}
	set_meta("budgets",stats)

## One instance's distance limit for the level: true when it has one.
func _budget(geometry: GeometryInstance3D) -> bool:
	var original: float = _ranges.get(geometry.get_instance_id(), geometry.visibility_range_end)
	var end := original
	if geometry is MeshInstance3D and geometry.mesh != null and not geometry.has_meta("no_range"):
		var size: Vector3 = geometry.get_aabb().size * geometry.global_basis.get_scale().abs()
		var extent := size.length()
		# Keep the sky, terrain and broad architectural batches. Cull small detail
		# by its actual size; never use range culling for a world-sized batch.
		var budget := 24.0 if extent < .5 else (45.0 if extent < 2.0 else (80.0 if extent < 6.0 else 140.0))
		if extent < 24.0:
			budget *= [1.0,1.35,1.8][clampi(_tier,0,2)]
			end = minf(original,budget) if original > 0.0 else budget
	geometry.visibility_range_end = end
	# Compatibility has no per-instance transparency fade. Its margin supplies hysteresis.
	geometry.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	if end > 0:
		geometry.visibility_range_end_margin = minf(end*.08,8.0)
		return true
	return false

func _material_budget() -> void:
	for mat: BaseMaterial3D in _materials:
		var original: Dictionary = _materials[mat]
		mat.normal_enabled = original.normal and _tier > 0
		mat.detail_enabled = original.detail and _tier > 0
		mat.clearcoat_enabled = original.clearcoat and _tier > 0
		mat.heightmap_enabled = original.height and _tier > 0

func _resize() -> void:
	var pixels := get_window().size
	if pixels.x <= 0 or pixels.y <= 0: return
	var index := clampi(_tier,0,2)
	var base: float = [.7,.78,.85][index]
	var long_limit: float = [1280.0,1600.0,1920.0][index]
	var short_limit: float = [720.0,900.0,1080.0][index]
	# Keep UI at native resolution while bounding 3D cost on high-density phones.
	ceiling = minf(base,minf(long_limit/maxi(pixels.x,pixels.y),short_limit/mini(pixels.x,pixels.y)))
	get_viewport().scaling_3d_scale = ceiling
