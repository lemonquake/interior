class_name InteriorLighting
extends Node3D
## Room lighting rig (contract section 6): WorldEnvironment, warm recessed downlights,
## LED strips, a lamp accent, kitchen daylight, reflection probes and TV glow.
##
## Built once by InteriorRoomBuilder (and saved by editor/bake_room.gd). Everything the
## runtime needs is stored on the nodes themselves (metadata + persistent groups), so
## apply_quality() and set_tv_glow() work identically on a freshly built rig and on the
## baked scene reloaded from disk. Desktop and mobile variants are both present; tiers
## only toggle visibility / shadows / environment effects.

const TIER_NAMES := ["Low", "Medium", "High", "Ultra"]
const DESKTOP_DEFAULT_TIER := 2
const MOBILE_DEFAULT_TIER := 0
const MOBILE_MAX_TIER := 2
const MOBILE_MAX_LIGHTS := 2
const GROUP := "interior_lighting"
const LIGHT_GROUP := "interior_lighting_lights"
const TV_GLOW_ID := "tv_glow"

const WHITE_BALANCE_K := 3600.0
const DOWNLIGHT_K := 2850.0
const STRIP_K := 2700.0
const LAMP_K := 2500.0
const DAYLIGHT_K := 6500.0
const TV_K := 11000.0

const DOWNLIGHT_ENERGY := 2.2
const DOWNLIGHT_RANGE := 5.5
const DOWNLIGHT_ANGLE := 50.0
const STRIP_ENERGY := 1.4
const STRIP_RANGE := 1.6

const BACKGROUND := Color(0.035, 0.03, 0.026)
const AMBIENT_TOP := Color(0.62, 0.56, 0.50)
const AMBIENT_HORIZON := Color(0.72, 0.62, 0.52)
const AMBIENT_BOTTOM := Color(0.78, 0.66, 0.52)

## shadows = how many lights flagged "shadow" may cast one (in rig order).
const DESKTOP_TIERS := [
	{"msaa": Viewport.MSAA_DISABLED, "ssaa": Viewport.SCREEN_SPACE_AA_FXAA, "scale": 0.85,
		"shadows": 2, "atlas": 2048, "soft": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
		"ssao": false, "ssil": false, "gi": false, "ssr": false, "probes": false, "ambient": 0.9},
	{"msaa": Viewport.MSAA_2X, "ssaa": Viewport.SCREEN_SPACE_AA_DISABLED, "scale": 1.0,
		"shadows": 4, "atlas": 4096, "soft": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		"ssao": true, "ssil": false, "gi": false, "ssr": false, "probes": true, "ambient": 0.75,
		"ssao_quality": RenderingServer.ENV_SSAO_QUALITY_LOW},
	{"msaa": Viewport.MSAA_2X, "ssaa": Viewport.SCREEN_SPACE_AA_DISABLED, "scale": 1.0,
		"shadows": 7, "atlas": 4096, "soft": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		"ssao": true, "ssil": true, "gi": true, "ssr": false, "probes": true, "ambient": 0.45,
		"ssao_quality": RenderingServer.ENV_SSAO_QUALITY_MEDIUM, "ssil_quality": RenderingServer.ENV_SSIL_QUALITY_LOW},
	{"msaa": Viewport.MSAA_4X, "ssaa": Viewport.SCREEN_SPACE_AA_DISABLED, "scale": 1.0,
		"shadows": 99, "atlas": 8192, "soft": RenderingServer.SHADOW_QUALITY_SOFT_HIGH,
		"ssao": true, "ssil": true, "gi": true, "ssr": true, "probes": true, "ambient": 0.45,
		"ssao_quality": RenderingServer.ENV_SSAO_QUALITY_HIGH, "ssil_quality": RenderingServer.ENV_SSIL_QUALITY_HIGH},
]
const MOBILE_TIERS := [
	{"msaa": Viewport.MSAA_DISABLED, "scale": 0.7, "shadows": 1, "atlas": 1024,
		"soft": RenderingServer.SHADOW_QUALITY_HARD, "ambient": 1.0},
	{"msaa": Viewport.MSAA_DISABLED, "scale": 0.78, "shadows": 2, "atlas": 2048,
		"soft": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, "ambient": 1.0},
	{"msaa": Viewport.MSAA_2X, "scale": 0.85, "shadows": 2, "atlas": 2048,
		"soft": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, "ambient": 1.0},
]

## Room frame: floor y=0, ceiling 2.90, TV wall z=-2.8, kitchen x<-3.3 (window wall x=-5.65).
## "mobile": true marks the (max two) lights kept on Android / Compatibility.
const DEFAULT_RIG := [
	{"id": "down_table", "type": "spot", "position": [-0.6, 2.885, 0.25], "shadow": true,
		"mobile": true, "mobile_angle_deg": 80.0, "mobile_energy": 3.0, "mobile_range": 8.0},
	{"id": "down_tv_center", "type": "spot", "position": [-0.55, 2.885, -1.75], "shadow": true},
	{"id": "down_tv_left", "type": "spot", "position": [-2.15, 2.885, -1.85], "shadow": true},
	{"id": "down_tv_right", "type": "spot", "position": [1.2, 2.885, -1.85], "shadow": true},
	{"id": "down_sofa", "type": "spot", "position": [-2.3, 2.885, 0.45], "shadow": true},
	{"id": "down_right", "type": "spot", "position": [1.75, 2.885, -0.2], "shadow": true},
	{"id": "down_kitchen", "type": "spot", "position": [-4.55, 2.885, -0.2], "shadow": true, "kelvin": 3000.0,
		"angle_deg": 60.0},
	{"id": "down_rear", "type": "spot", "position": [-0.45, 2.885, 1.95], "shadow": false},
	{"id": "down_rear_right", "type": "spot", "position": [2.0, 2.885, 1.85], "shadow": false},
	# Kitchen window: cool-neutral daylight raking in from the far wall.
	{"id": "window_daylight", "type": "spot", "position": [-5.45, 2.35, -0.1], "rotation_deg": [-35, -90, 0],
		"energy": 2.0, "range": 6.0, "angle_deg": 70.0, "shadow": false, "kelvin": DAYLIGHT_K,
		"mobile": true, "mobile_energy": 1.4, "fixture": false},
	# Warm accent lamp glow in the rear-right corner.
	{"id": "accent_lamp", "type": "omni", "position": [2.75, 1.45, 2.3], "energy": 0.8, "range": 3.0, "kelvin": LAMP_K},
	# LED strips: under the TV console front and under each floating shelf.
	{"id": "strip_console", "type": "strip", "position": [-0.55, 0.11, -2.12], "length": 2.4, "energy": 1.2},
	{"id": "strip_shelf_left_high", "type": "strip", "position": [-2.15, 2.21, -2.62], "length": 0.56},
	{"id": "strip_shelf_left_low", "type": "strip", "position": [-2.1, 1.58, -2.62], "length": 0.56},
	{"id": "strip_shelf_right_high", "type": "strip", "position": [1.21, 2.12, -2.62], "length": 0.56},
	{"id": "strip_shelf_right_low", "type": "strip", "position": [1.24, 1.57, -2.62], "length": 0.56},
	{"id": TV_GLOW_ID, "type": "tv", "position": [-0.55, 1.77, -2.55], "length": 1.43},
]

@export var tv_glow_on := false
var mobile := false
var tier := -1
var world_environment: WorldEnvironment
var environment: Environment
var _compat := false
var _collected := false
var _lights: Array[Light3D] = []
var _probes: Array[ReflectionProbe] = []
var _wash: Array[Node3D] = []
var _tv: Array[Node3D] = []
static var _mat_cache: Dictionary = {}

static func create(room: Node3D, layout: Dictionary, is_mobile: bool) -> InteriorLighting:
	var lighting := InteriorLighting.new()
	lighting.name = "InteriorLighting"
	var specs: Array = layout.get("lights", [])
	lighting._build(specs if not specs.is_empty() else DEFAULT_RIG.duplicate(true))
	lighting.mobile = is_mobile
	if room != null:
		room.add_child(lighting)
	lighting.apply_quality(MOBILE_DEFAULT_TIER if is_mobile else DESKTOP_DEFAULT_TIER)
	return lighting

## Finds the rig under `root` (works for built and reloaded scenes).
static func find_in(root: Node) -> InteriorLighting:
	if root == null or not root.is_inside_tree():
		return null
	for node in root.get_tree().get_nodes_in_group(GROUP):
		if node is InteriorLighting and (node == root or root.is_ancestor_of(node)):
			return node
	return null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUP, true)
	_collect()
	if OS.has_feature("android") or "--mobile-test" in OS.get_cmdline_user_args():
		mobile = true
	if tier < 0:
		apply_quality(MOBILE_DEFAULT_TIER if mobile else DESKTOP_DEFAULT_TIER)
	else:
		apply_quality(tier)
	set_tv_glow(tv_glow_on)

## 0 Low, 1 Medium, 2 High, 3 Ultra (desktop only; Android clamps to High).
func apply_quality(index: int) -> void:
	_collect()
	tier = clampi(index, 0, MOBILE_MAX_TIER if mobile else TIER_NAMES.size() - 1)
	var t := _tier()
	var desktop := not (_compat or mobile)
	if environment != null:
		environment.ambient_light_energy = float(t.ambient)
		environment.glow_enabled = true
		environment.ssao_enabled = desktop and bool(t.get("ssao", false))
		environment.ssil_enabled = desktop and bool(t.get("ssil", false))
		environment.ssr_enabled = desktop and bool(t.get("ssr", false))
		environment.sdfgi_enabled = desktop and bool(t.get("gi", false))
		environment.tonemap_mode = Environment.TONE_MAPPER_AGX if desktop else Environment.TONE_MAPPER_FILMIC
		environment.tonemap_exposure = 1.0 if desktop else 1.05
	var budget := int(t.shadows)
	var mobile_count := 0
	for light in _lights:
		var kind := str(light.get_meta("light_type", "spot"))
		var on := true
		if not desktop:
			# Compatibility: no area lights, at most two positional lights.
			on = bool(light.get_meta("mobile_ok", false)) and kind != "strip" and mobile_count < MOBILE_MAX_LIGHTS
			if on:
				mobile_count += 1
		light.visible = on and kind != "tv"
		var cast: bool = on and bool(light.get_meta("shadow", false)) and budget > 0 and not (light.get_class() == "AreaLight3D")
		if cast:
			budget -= 1
		light.shadow_enabled = cast
		var key := "mobile_energy" if not desktop else "base_energy"
		light.light_energy = float(light.get_meta(key, light.get_meta("base_energy", light.light_energy)))
		if light.get_meta("light_type", "") == "spot" and light is SpotLight3D:
			(light as SpotLight3D).spot_angle = float(light.get_meta("mobile_angle" if not desktop else "base_angle", (light as SpotLight3D).spot_angle))
			(light as SpotLight3D).spot_range = float(light.get_meta("mobile_range" if not desktop else "base_range", (light as SpotLight3D).spot_range))
	for card in _wash:
		card.visible = not desktop
	for probe in _probes:
		probe.visible = desktop and bool(t.get("probes", false))
	set_tv_glow(tv_glow_on)
	if is_inside_tree():
		_apply_viewport(t, desktop)

func set_tv_glow(on: bool) -> void:
	tv_glow_on = on
	_collect()
	for node in _tv:
		if node is Light3D:
			node.visible = on and not (_compat or mobile)
		else:
			node.visible = on

## Light, shadow and feature counts for tests and reports.
func stats() -> Dictionary:
	_collect()
	var vis_count := 0
	var shadowed := 0
	for light in _lights:
		if light.visible:
			vis_count += 1
			if light.shadow_enabled:
				shadowed += 1
	return {"tier": tier, "tier_name": TIER_NAMES[maxi(tier, 0)], "mobile": mobile, "compat": _compat,
		"lights": _lights.size(), "visible_lights": vis_count, "shadowed_lights": shadowed,
		"ssao": environment.ssao_enabled, "ssil": environment.ssil_enabled, "sdfgi": environment.sdfgi_enabled,
		"ssr": environment.ssr_enabled, "glow": environment.glow_enabled, "tonemap": environment.tonemap_mode,
		"probes": _probes.filter(func(p: ReflectionProbe) -> bool: return p.visible).size(), "tv_glow": tv_glow_on}

static func kelvin(k: float) -> Color:
	var t := clampf(k, 1000.0, 40000.0) / 100.0
	var r := 255.0
	var g := 0.0
	var b := 255.0
	if t <= 66.0:
		g = 99.4708025861 * log(t) - 161.1195681661
		b = 0.0 if t <= 19.0 else 138.5177312231 * log(t - 10.0) - 305.0447927307
	else:
		r = 329.698727446 * pow(t - 60.0, -0.1332047592)
		g = 288.1221695283 * pow(t - 60.0, -0.0755148492)
	return Color(clampf(r, 0, 255) / 255.0, clampf(g, 0, 255) / 255.0, clampf(b, 0, 255) / 255.0)

## Light colour at `k` Kelvin as seen by a camera white-balanced to WHITE_BALANCE_K.
static func balanced(k: float) -> Color:
	var c := kelvin(k)
	var w := kelvin(WHITE_BALANCE_K)
	var out := Vector3(c.r / w.r, c.g / w.g, c.b / w.b)
	var peak := maxf(out.x, maxf(out.y, out.z))
	return Color(out.x / peak, out.y / peak, out.z / peak)

func _tier() -> Dictionary:
	return (MOBILE_TIERS if mobile else DESKTOP_TIERS)[tier]

# --- Runtime discovery (works after the scene is saved and reloaded) -----------

func _collect() -> void:
	_compat = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	if _collected and world_environment != null:
		return
	_collected = true
	_lights.clear()
	_probes.clear()
	_wash.clear()
	_tv.clear()
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is WorldEnvironment:
			world_environment = node
			environment = (node as WorldEnvironment).environment
		elif node is Light3D:
			if node.get_meta("light_type", "") == "tv":
				_tv.append(node)
			else:
				_lights.append(node)
		elif node is ReflectionProbe:
			_probes.append(node)
		elif node.has_meta("wash_card"):
			_wash.append(node)
		elif node.has_meta("tv_panel"):
			_tv.append(node)
	# Rig order defines the shadow priority.
	_lights.sort_custom(func(a: Light3D, b: Light3D) -> bool: return int(a.get_meta("order", 0)) < int(b.get_meta("order", 0)))

# --- Construction ------------------------------------------------------------

func _build(specs: Array) -> void:
	world_environment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	environment = _make_environment()
	world_environment.environment = environment
	add_child(world_environment)
	var order := 0
	for spec: Dictionary in specs:
		var kind := str(spec.get("type", "omni"))
		var id := str(spec.get("id", "%s_%d" % [kind, order]))
		order += 1
		match kind:
			"strip":
				_build_strip(id, spec, order)
			"tv":
				_build_tv_glow(spec)
			_:
				_build_point(id, kind, spec, order)
	_build_probes()

func _make_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BACKGROUND
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = AMBIENT_TOP
	sky_material.sky_horizon_color = AMBIENT_HORIZON
	sky_material.ground_horizon_color = AMBIENT_HORIZON
	sky_material.ground_bottom_color = AMBIENT_BOTTOM
	sky_material.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06
	env.adjustment_contrast = 1.04
	env.glow_enabled = true
	env.glow_normalized = false
	env.glow_intensity = 0.5
	env.glow_strength = 1.0
	env.glow_bloom = 0.015
	env.glow_hdr_threshold = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	for level in 7:
		env.set_glow_level(level, [0.0, 0.25, 0.8, 0.6, 0.3, 0.0, 0.0][level])
	env.ssao_radius = 0.8
	env.ssao_intensity = 2.0
	env.ssao_power = 1.5
	env.ssao_detail = 0.6
	env.ssao_light_affect = 0.1
	env.ssil_radius = 3.0
	env.ssil_intensity = 0.7
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.12
	env.ssr_fade_out = 2.5
	env.sdfgi_use_occlusion = true
	env.sdfgi_read_sky_light = false
	env.sdfgi_bounce_feedback = 0.4
	env.sdfgi_cascades = 3
	env.sdfgi_min_cell_size = 0.1
	env.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT
	env.sdfgi_energy = 0.9
	env.sdfgi_normal_bias = 1.1
	env.sdfgi_probe_bias = 1.1
	return env

func _vec(value: Variant, fallback := Vector3.ZERO) -> Vector3:
	if value is Array and (value as Array).size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return fallback

func _spec_color(spec: Dictionary, default_k: float) -> Color:
	if spec.has("color") and spec.color is Array and (spec.color as Array).size() >= 3:
		return Color(float(spec.color[0]), float(spec.color[1]), float(spec.color[2]))
	return balanced(float(spec.get("kelvin", default_k)))

func _tag(light: Light3D, kind: String, spec: Dictionary, order: int) -> void:
	light.add_to_group(LIGHT_GROUP, true)
	light.set_meta("light_type", kind)
	light.set_meta("order", order)
	light.set_meta("shadow", bool(spec.get("shadow", false)))
	light.set_meta("mobile_ok", bool(spec.get("mobile", false)))
	light.set_meta("base_energy", light.light_energy)
	light.set_meta("mobile_energy", float(spec.get("mobile_energy", light.light_energy)))

func _build_point(id: String, kind: String, spec: Dictionary, order: int) -> void:
	var root := Node3D.new()
	root.name = "Light_" + id
	root.position = _vec(spec.get("position"))
	var default_down := kind == "spot" and not spec.has("rotation_deg")
	root.rotation_degrees = Vector3(-90, 0, 0) if default_down else _vec(spec.get("rotation_deg"))
	add_child(root)
	var light: Light3D
	if kind == "spot":
		var spot := SpotLight3D.new()
		spot.spot_range = float(spec.get("range", DOWNLIGHT_RANGE))
		spot.spot_angle = float(spec.get("angle_deg", DOWNLIGHT_ANGLE))
		spot.spot_angle_attenuation = 0.7
		spot.spot_attenuation = 1.3
		light = spot
	elif kind == "omni":
		var omni := OmniLight3D.new()
		omni.omni_range = float(spec.get("range", 3.0))
		omni.omni_attenuation = 1.3
		light = omni
	else:
		light = DirectionalLight3D.new()
	light.name = "Light"
	light.light_color = _spec_color(spec, DOWNLIGHT_K)
	light.light_energy = float(spec.get("energy", DOWNLIGHT_ENERGY if kind == "spot" else 1.0))
	light.light_size = 0.06
	light.shadow_bias = 0.03
	light.shadow_normal_bias = 0.8
	light.shadow_blur = 1.2
	light.light_specular = 0.6
	light.position = Vector3(0, 0, -0.04) if default_down else Vector3.ZERO
	root.add_child(light)
	_tag(light, kind, spec, order)
	if light is SpotLight3D:
		light.set_meta("base_angle", (light as SpotLight3D).spot_angle)
		light.set_meta("base_range", (light as SpotLight3D).spot_range)
		light.set_meta("mobile_angle", float(spec.get("mobile_angle_deg", (light as SpotLight3D).spot_angle)))
		light.set_meta("mobile_range", float(spec.get("mobile_range", (light as SpotLight3D).spot_range)))
	if default_down and bool(spec.get("fixture", true)):
		_add_downlight_fixture(root, light.light_color)

func _add_downlight_fixture(root: Node3D, color: Color) -> void:
	# Recessed can: satin white trim ring with a glowing diffuser just inside it.
	var trim := MeshInstance3D.new()
	trim.name = "Trim"
	var ring := CylinderMesh.new()
	ring.top_radius = 0.065
	ring.bottom_radius = 0.06
	ring.height = 0.008
	ring.radial_segments = 32
	trim.mesh = ring
	trim.material_override = _satin_white()
	trim.rotation_degrees = Vector3(90, 0, 0)
	trim.position = Vector3(0, 0, -0.002)
	var lens := MeshInstance3D.new()
	lens.name = "Diffuser"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.046
	disc.bottom_radius = 0.046
	disc.height = 0.004
	disc.radial_segments = 32
	lens.mesh = disc
	lens.material_override = _emissive(color, 5.0)
	lens.rotation_degrees = Vector3(90, 0, 0)
	lens.position = Vector3(0, 0, -0.007)
	for mesh: MeshInstance3D in [trim, lens]:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mesh)

func _build_strip(id: String, spec: Dictionary, order: int) -> void:
	# Strip frame: runs along local X, emits toward -Y; the room is toward +Z.
	var length := float(spec.get("length", 1.0))
	var color := _spec_color(spec, STRIP_K)
	var root := Node3D.new()
	root.name = "Strip_" + id
	root.position = _vec(spec.get("position"))
	root.rotation_degrees = _vec(spec.get("rotation_deg"))
	add_child(root)
	var bar := MeshInstance3D.new()
	bar.name = "LedBar"
	var box := BoxMesh.new()
	box.size = Vector3(length, 0.008, 0.012)
	bar.mesh = box
	bar.material_override = _emissive(color, 4.0)
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bar)
	var energy := float(spec.get("energy", STRIP_ENERGY))
	# Compatibility stand-in: an additive gradient wash on the surface below.
	_add_wash_card(root, length, color, energy)
	if ClassDB.class_exists("AreaLight3D"):
		var area := ClassDB.instantiate("AreaLight3D") as Light3D
		area.name = "Light"
		area.set("area_size", Vector2(length, 0.02))
		area.set("area_range", float(spec.get("range", STRIP_RANGE)))
		area.light_color = color
		area.light_energy = energy
		area.light_specular = 0.3
		area.shadow_enabled = false
		area.rotation_degrees = Vector3(-90, 0, 0)
		area.position = Vector3(0, -0.006, 0)
		root.add_child(area)
		_tag(area, "strip", spec, order)
	else:
		for i in 2:
			var omni := OmniLight3D.new()
			omni.name = "Light%d" % i
			omni.omni_range = float(spec.get("range", STRIP_RANGE))
			omni.omni_attenuation = 1.6
			omni.light_color = color
			omni.light_energy = energy * 0.5
			omni.position = Vector3((float(i) - 0.5) * length * 0.6, -0.05, 0.02)
			root.add_child(omni)
			_tag(omni, "strip", spec, order)

func _add_wash_card(root: Node3D, length: float, color: Color, energy: float) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.35, Color(1, 1, 1, 0.45))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 8
	texture.height = 64
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = texture
	mat.albedo_color = Color(color.r, color.g, color.b) * 0.5 * energy
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var card := MeshInstance3D.new()
	card.name = "WashCard"
	var quad := QuadMesh.new()
	quad.size = Vector2(length * 1.15, 0.5)
	card.mesh = quad
	card.material_override = mat
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	card.position = Vector3(0, -0.25, -0.02)
	card.set_meta("wash_card", true)
	card.visible = false
	root.add_child(card)

func _build_tv_glow(spec: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "TvGlow"
	root.position = _vec(spec.get("position"))
	add_child(root)
	var width := float(spec.get("length", 1.4))
	var panel := MeshInstance3D.new()
	panel.name = "ScreenPanel"
	var quad := QuadMesh.new()
	quad.size = Vector2(width, width * 9.0 / 16.0)
	panel.mesh = quad
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.78, 0.86, 1.0))
	gradient.set_color(1, Color(0.22, 0.32, 0.52))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.45)
	texture.fill_to = Vector2(1.1, 1.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.BLACK
	mat.emission_enabled = true
	mat.emission_texture = texture
	mat.emission = Color.WHITE
	mat.emission_energy_multiplier = 1.3
	mat.roughness = 0.15
	panel.material_override = mat
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	panel.position = Vector3(0, 0, 0.004)
	panel.set_meta("tv_panel", true)
	panel.visible = false
	root.add_child(panel)
	var spot := SpotLight3D.new()
	spot.name = "Light"
	spot.light_color = _spec_color(spec, TV_K)
	spot.light_energy = 1.4
	spot.spot_range = 4.5
	spot.spot_angle = 72.0
	spot.spot_angle_attenuation = 0.5
	spot.light_size = width * 0.5
	spot.rotation_degrees = Vector3(0, 0, 0)
	spot.basis = Basis(Vector3.UP, PI)  # face +Z, into the room
	spot.position = Vector3(0, 0, 0.06)
	spot.set_meta("light_type", "tv")
	spot.visible = false
	root.add_child(spot)

func _build_probes() -> void:
	for box: AABB in [AABB(Vector3(-3.3, 0.0, -2.75), Vector3(6.65, 2.9, 5.5)), AABB(Vector3(-5.65, 0.0, -2.75), Vector3(2.35, 2.9, 5.5))]:
		var probe := ReflectionProbe.new()
		probe.name = "ReflectionProbe"
		probe.position = box.get_center() + Vector3(0, 0.15, 0)
		probe.size = box.size
		probe.origin_offset = Vector3(0, -0.15, 0)
		probe.box_projection = true
		probe.interior = true
		probe.enable_shadows = true
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		probe.blend_distance = 0.4
		probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
		add_child(probe)

func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var key := "emit_%s_%.2f" % [color.to_html(false), energy]
	if not _mat_cache.has(key):
		var mat := StandardMaterial3D.new()
		mat.resource_name = "Lighting emissive"
		mat.albedo_color = color.lerp(Color.WHITE, 0.4)
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = energy
		mat.roughness = 0.4
		_mat_cache[key] = mat
	return _mat_cache[key]

func _satin_white() -> Material:
	return InteriorMaterials.material("ceiling_white")

func _apply_viewport(t: Dictionary, desktop: bool) -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	viewport.msaa_3d = t.msaa
	viewport.scaling_3d_scale = float(t.scale)
	viewport.positional_shadow_atlas_size = int(t.atlas)
	RenderingServer.positional_soft_shadow_filter_set_quality(t.soft)
	RenderingServer.directional_soft_shadow_filter_set_quality(t.soft)
	if not desktop:
		viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		viewport.use_taa = false
		return
	viewport.screen_space_aa = t.get("ssaa", Viewport.SCREEN_SPACE_AA_DISABLED)
	viewport.use_taa = false
	viewport.anisotropic_filtering_level = Viewport.ANISOTROPY_16X if tier >= 1 else Viewport.ANISOTROPY_8X
	RenderingServer.environment_set_ssao_quality(t.get("ssao_quality", RenderingServer.ENV_SSAO_QUALITY_LOW), true, 0.5, 2, 50.0, 300.0)
	RenderingServer.environment_set_ssil_quality(t.get("ssil_quality", RenderingServer.ENV_SSIL_QUALITY_LOW), true, 0.5, 4, 50.0, 300.0)
	RenderingServer.environment_set_sdfgi_ray_count(RenderingServer.ENV_SDFGI_RAY_COUNT_32 if tier >= 3 else RenderingServer.ENV_SDFGI_RAY_COUNT_16)
	RenderingServer.gi_set_use_half_resolution(tier < 3)
