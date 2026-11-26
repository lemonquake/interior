extends InteriorHingedDoor
## A hinged door of the canal warren (plank doors between rooms, pried tin sheets in the boundary fence).
## It swings and can be pulled by hand like every other door, but it is not one of the house's
## "interior_doors": those reveal the balcony and are looked up as the entry door. It joins "usables" instead,
## which the player targets the same way. A creak follows the swing.

var _creak: AudioStreamPlayer3D
var _last := 0.0

func _ready() -> void:
	super._ready()
	remove_from_group("interior_doors")
	add_to_group("usables")
	add_to_group("warren_doors")
	_creak = AudioStreamPlayer3D.new()
	_creak.name = "Hinge creak"
	_creak.max_distance = 16.0
	_creak.unit_size = 3.0
	_creak.volume_db = -14.0
	_creak.stream = _make_creak()
	add_child(_creak)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _body == null: return
	var angle := _body.rotation.y
	var speed := absf(angle - _last) / maxf(delta, .001)
	_last = angle
	if speed > .5 and not _creak.playing and is_visible_in_tree():
		_creak.pitch_scale = randf_range(.8, 1.15)
		_creak.play()

static var _shared: AudioStreamWAV

## A short, rusty hinge squeal: a gliding, rough tone (generated, no asset needed).
static func _make_creak() -> AudioStreamWAV:
	if _shared != null: return _shared
	var rate := 22050
	var length := int(rate * .55)
	var data := PackedByteArray()
	data.resize(length * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in length:
		var t := float(i) / rate
		var f := 520.0 + 260.0 * sin(t * 9.0) + 90.0 * sin(t * 37.0)
		phase += f / rate * TAU
		var stick := .55 + .45 * sin(t * 61.0)
		var env := smoothstep(0.0, .04, t) * (1.0 - smoothstep(.35, .55, t))
		var v := (sin(phase) * .6 + sin(phase * 2.01) * .25 + rng.randf_range(-.3, .3)) * stick * env * .5
		data.encode_s16(i * 2, int(clampf(v, -1, 1) * 22000))
	_shared = AudioStreamWAV.new()
	_shared.format = AudioStreamWAV.FORMAT_16_BITS
	_shared.mix_rate = rate
	_shared.data = data
	return _shared
