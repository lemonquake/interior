class_name InteriorGlitchClock
extends Label3D
## The digital clock's red display. Once a second it shows a time that makes no sense (27:84,
## 9#:61, 00:-3...) and sometimes symbols instead of digits. Added to the clock body at runtime,
## so it travels with the clock when it is carried.

const DIGITS := "0123456789"
const SYMBOLS := "#%&?*@$<>=+-/[]~"

var _wait := 0.0
var _colon := true
var _rng := RandomNumberGenerator.new()

static func attach(clock: Node3D) -> InteriorGlitchClock:
	var label := InteriorGlitchClock.new()
	label.name = "GlitchDisplay"
	clock.add_child(label)
	# Display window of the clock mesh: x -0.105..0.108, y 0.061..0.152, front face z 0.044.
	label.position = Vector3(.0015, .106, .0465)
	# Hide the modelled static digits underneath.
	var mesh := clock.find_child("*", true, false) as MeshInstance3D
	for child in clock.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null and (child as MeshInstance3D).mesh.get_surface_count() > 1:
			mesh = child
	if mesh != null and mesh.mesh.get_surface_count() > 1:
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color(.035, .01, .01)
		dark.roughness = .3
		mesh.set_surface_override_material(1, dark)
	return label

func _ready() -> void:
	_rng.randomize()
	font_size = 64
	outline_size = 0
	pixel_size = .00092
	modulate = Color(1.0, .16, .1)
	shaded = false
	double_sided = false
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = .6
	font.spacing_glyph = 4
	self.font = font
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_tick()

func _process(delta: float) -> void:
	_wait -= delta
	if _wait <= 0.0:
		_tick()

func _tick() -> void:
	_wait += 1.0
	if _wait < 0.0:
		_wait = 1.0
	_colon = not _colon
	text = _nonsense()
	# Now and then the display dims or stutters.
	modulate.a = .55 if _rng.randf() < .12 else 1.0

func _char(symbol_chance: float) -> String:
	if _rng.randf() < symbol_chance:
		return SYMBOLS[_rng.randi_range(0, SYMBOLS.length() - 1)]
	return DIGITS[_rng.randi_range(0, 9)]

func _nonsense() -> String:
	var roll := _rng.randf()
	var sep := ":" if _colon else " "
	if roll < .06:
		return "--" + sep + "--"
	if roll < .1:
		return "88" + sep + "88"
	if roll < .14:
		return "00" + sep + "00"
	var symbols := .35 if roll > .7 else .08
	# Hours and minutes beyond any real clock: 24..99 and 60..99 show up often.
	var h := _char(symbols) + _char(symbols)
	var m := _char(symbols) + _char(symbols)
	if _rng.randf() < .4:
		h = str(_rng.randi_range(24, 99))
	if _rng.randf() < .4:
		m = str(_rng.randi_range(60, 99))
	if _rng.randf() < .08:
		m = "-" + str(_rng.randi_range(1, 9))
	return h + sep + m
