class_name InteriorStrangerCutscene
extends Node
## 0.23: the first sight of the hooded man, played like a film (scripts/stranger.gd acts it out, this node shoots it).
##
##  0.0  Cut: behind him at the gate, low, past his shoulder up at the house, breathing; a slow push in.
##  2.6  The camera swings round to his side as he senses he is watched and turns his head toward the player.
##  3.7  He lets go of the bars (they clank) and backs off a few steps, still looking.
##  5.1  He turns away and walks (does not run) up the lane; the camera stays and pans after him.
##  8.6  Cut back to the player.
## The player is held still (InteriorPlayer.cutscene) and the HUD hidden; black bars slide in. The scene pauses with the
## game. A low swell plays under it (tools/assets/make_siege_sounds.py, sting.ogg).

const LENGTH := 8.6
const BACK_END := 2.6
const SWING_END := 4.8
const STING := "res://assets/audio/siege/sting.ogg"

var stranger: Node3D
var main: Node
var player: Node3D
var camera: Camera3D
var t := 0.0
var _bars: CanvasLayer
var _top: ColorRect
var _bottom: ColorRect
var _hud_was := true
var _look := Vector3.ZERO
var _finished := false

func _init() -> void:
	name = "Stranger cutscene"
	process_mode = Node.PROCESS_MODE_PAUSABLE

func play(man: Node3D) -> void:
	stranger = man
	main = get_tree().current_scene
	player = main.get("player") if main != null else null
	camera = Camera3D.new()
	camera.name = "Cutscene camera"
	camera.fov = 48.0
	camera.near = .05
	camera.far = 900.0
	var source := player.get("camera") as Camera3D if player != null else null
	if source != null:
		camera.cull_mask = source.cull_mask
		camera.attributes = source.attributes
		camera.environment = source.environment
	add_child(camera)
	_look = _target_house()
	_shoot(0.0)
	camera.make_current()
	if player != null:
		player.set("cutscene", true)
	if main != null and "hud" in main and main.hud != null:
		_hud_was = main.hud.visible
		main.hud.visible = false
	_letterbox()
	if ResourceLoader.exists(STING):
		var sting := AudioStreamPlayer.new()
		sting.stream = load(STING)
		sting.volume_db = -6.0
		add_child(sting)
		sting.play()

func _letterbox() -> void:
	_bars = CanvasLayer.new()
	_bars.layer = 45
	add_child(_bars)
	for top in [true, false]:
		var rect := ColorRect.new()
		rect.color = Color.BLACK
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.anchor_left = 0.0
		rect.anchor_right = 1.0
		rect.anchor_top = 0.0 if top else 1.0
		rect.anchor_bottom = 0.0 if top else 1.0
		_bars.add_child(rect)
		if top: _top = rect
		else: _bottom = rect
	_set_bars(0.0)

func _set_bars(f: float) -> void:
	var h := f * .115 * float(main.get_viewport().get_visible_rect().size.y if main != null else 1080.0)
	_top.offset_top = 0.0
	_top.offset_bottom = h
	_bottom.offset_top = -h
	_bottom.offset_bottom = 0.0

func _process(delta: float) -> void:
	if _finished: return
	t += delta
	_set_bars(clampf(t / .35, 0, 1) if t < LENGTH - .3 else clampf((LENGTH - t) / .3, 0, 1))
	_shoot(delta)
	if t >= LENGTH:
		finish()

## Where he stares: up at the balcony and the navy door.
func _target_house() -> Vector3:
	return Vector3(4.6, 1.15, 3.7)

func _head() -> Vector3:
	return stranger.global_position + Vector3.UP * 1.55 if is_instance_valid(stranger) else Vector3(13.0, -1.35, 4.1)

func _shoot(delta: float) -> void:
	var gate := Vector3(13.0, -2.9, 4.1)
	var shake := Vector3(sin(t * 1.3) * .012, sin(t * 1.9 + 1.0) * .01, sin(t * .9 + 2.0) * .012)
	var eye: Vector3
	var target: Vector3
	if t < BACK_END:
		# Behind him, a little to his left and below his shoulder: the bars, the courtyard, the house over them.
		var f := smoothstep(0.0, BACK_END, t)
		eye = gate + Vector3(1.98 - .36 * f, 1.42, .14 - .14 * f)
		target = _target_house()
	elif t < SWING_END:
		# Round to his side (south of him), ending in profile at his head.
		var f := smoothstep(BACK_END, SWING_END, t)
		var angle := lerpf(0.0, -PI * .5, f)
		var radius := lerpf(1.62, 2.25, f)
		var centre := gate + Vector3(0, 1.4, 0)
		eye = centre + Vector3(cos(angle) * radius, lerpf(.02, -.04, f), sin(angle) * radius)
		target = _target_house().lerp(_head(), smoothstep(0.0, .7, f))
	else:
		# Hold there and let him walk out of the profile, panning after him.
		var f := smoothstep(SWING_END, LENGTH, t)
		eye = gate + Vector3(0, 1.36, -2.25) + Vector3(.25 * f, 0, -.1 * f)
		target = _head()
	_look = target if t < .05 else _look.lerp(target, minf(1.0, delta * 5.0))
	camera.global_position = eye + shake
	if not camera.global_position.is_equal_approx(_look):
		camera.look_at(_look, Vector3.UP)

func finish() -> void:
	if _finished: return
	_finished = true
	if player != null and is_instance_valid(player):
		player.set("cutscene", false)
		var source := player.get("camera") as Camera3D
		if source != null: source.make_current()
	if main != null and "hud" in main and main.hud != null:
		main.hud.visible = _hud_was
	if is_instance_valid(stranger) and stranger.has_method("end_cutscene"):
		stranger.end_cutscene()
	queue_free()
