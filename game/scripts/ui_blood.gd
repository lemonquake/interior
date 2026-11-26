class_name InteriorBloodTitle
extends Control
## 0.31: the game's title with blood running down from its letters (the main menu and the loading screen), and the
## colours the menus share. The runs are drawn, not a picture: one under each letter, of different lengths, one of
## them still creeping, and now and then a drop lets go.

const BLOOD := Color(.36, .016, .022)
const BLOOD_WET := Color(.62, .06, .05, .55)
const BONE := Color(.86, .84, .8)
const DESCENDERS := "gjpqy"
const LENGTHS: Array[float] = [30.0, 56.0, 12.0, 44.0, 20.0, 38.0, 9.0]
const WIDTHS: Array[float] = [3.4, 4.2, 3.0, 4.6, 3.4, 3.8, 3.0]

var text := "Sleep"
var font_size := 100
var ink := Color(.91, .92, .86)
var _time := 0.0

static func make(title: String, size: int, colour: Color) -> InteriorBloodTitle:
	var out := InteriorBloodTitle.new()
	out.text = title
	out.font_size = size
	out.ink = colour
	return out

## 0.54: the title is set in the story's serif (SleepType), not the default text face.
func _font() -> Font:
	return SleepType.serif()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The menus are up while the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var font := _font()
	var extent := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	custom_minimum_size = Vector2(extent.x, font.get_height(font_size) + 34.0)

func _process(delta: float) -> void:
	if is_visible_in_tree():
		_time += delta
		queue_redraw()

func _draw() -> void:
	var font := _font()
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	var scale_by := font_size / 100.0
	var x := 0.0
	for index in text.length():
		var letter := text[index]
		var width := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if letter != " ":
			var low := DESCENDERS.contains(letter)
			var at := Vector2(x + width * (.2 if low else .5), ascent - 5.0 * scale_by + (descent * .78 if low else 0.0))
			var length := LENGTHS[index % LENGTHS.size()] * scale_by
			var thick := WIDTHS[index % WIDTHS.size()] * scale_by
			if index % LENGTHS.size() == 1:
				# This one is still coming down, a little, and gives up a drop every so often.
				length += (sin(_time * .35) * .5 + .5) * 9.0 * scale_by
				var fall := fmod(_time, 7.5)
				if fall < 1.1:
					var drop := at + Vector2(0, length + fall * fall * 150.0 * scale_by)
					draw_circle(drop, thick * .62, Color(BLOOD, 1.0 - fall / 1.1))
			_run(at, length, thick)
		x += width
	draw_string(font, Vector2(0, ascent), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)

## One run: narrow where it leaves the letter, a bead at its end, a line of light down its wet side.
func _run(from: Vector2, length: float, thick: float) -> void:
	var to := from + Vector2(0, length)
	draw_line(from, to, BLOOD, thick * .62, true)
	draw_line(from + Vector2(0, length * .55), to, BLOOD, thick * .8, true)
	draw_circle(to, thick * .72, BLOOD)
	draw_line(from + Vector2(-thick * .16, 2.0), to + Vector2(-thick * .16, -thick * .4), BLOOD_WET, maxf(1.0, thick * .22), true)
	draw_circle(to + Vector2(-thick * .22, -thick * .18), thick * .2, BLOOD_WET)
