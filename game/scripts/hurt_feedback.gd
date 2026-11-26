class_name InteriorHurtFeedback
extends CanvasLayer
## 0.60: being hit, felt: the view shakes a little (player.gd `shake`, ~0.4 s, under a degree) and the screen
## flashes a faint red, stronger at the edges, gone in under half a second. Solo (zombies.gd `hurt_player`) and
## co-op (session.gd, when the local survivor's HP drops) both call `InteriorHurtFeedback.hit(player, severity)`.
## One full-screen rect with a tiny shader; hidden (no draw at all) whenever it is not fading.

const SHADER := """shader_type canvas_item;
uniform float amount = 0.0;
void fragment() {
	float edge = smoothstep(.18, .75, length(UV - vec2(.5)) * 1.25);
	COLOR = vec4(.55, .02, .02, amount * (.07 + .26 * edge));
}
"""
const FADE := .42

static var _layer: InteriorHurtFeedback

var _rect: ColorRect
var _mat: ShaderMaterial
var _left := 0.0
var _peak := 0.0

## severity 0..1 (a light scratch .4, a full blow 1).
static func hit(player: Node, severity := 1.0) -> void:
	severity = clampf(severity, .25, 1.0)
	if player != null and player.has_method("shake"):
		player.shake(severity)
	if player == null or not player.is_inside_tree():
		return
	if _layer == null or not is_instance_valid(_layer):
		_layer = InteriorHurtFeedback.new()
		player.get_tree().root.add_child(_layer)
	_layer._flash(severity)

func _ready() -> void:
	name = "Hurt feedback"
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)

func _flash(severity: float) -> void:
	_peak = maxf(_peak * (_left / FADE), severity)
	_left = FADE
	_rect.visible = true
	_mat.set_shader_parameter("amount", _peak)

func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left = maxf(_left - delta, 0.0)
	var t := _left / FADE
	_mat.set_shader_parameter("amount", _peak * t * t)
	if _left <= 0.0:
		_rect.visible = false
		_peak = 0.0
