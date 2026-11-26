class_name SleepType
extends RefCounted
## 0.54: the game's type and the colours the screens share. Four faces, each with one job:
##
##   serif  Instrument Serif: the story's voice. The title, chapter names, a boss's name, the big moments.
##   street Vina Sans: the street. Short labels in capitals, buttons, badges, a shout. Cut from hand-painted shop and
##          road signs; its lower case is drawn as caps of another shape, so it is only ever set in capitals here.
##   text   Familjen Grotesk: people talking and reading. Dialogue, the objective, menus, the default for everything.
##   mono   Xanh Mono: the record. Numbers, stats, loading lines, anything counted.
##
## All four are SIL Open Font License (game/licenses/FONTS.md). The default font for every Control and Label3D is
## res://assets/fonts/sleep_text.tres (project setting gui/theme/custom_font).

const SERIF := "res://assets/fonts/InstrumentSerif-Regular.ttf"
const SERIF_ITALIC := "res://assets/fonts/InstrumentSerif-Italic.ttf"
const SIGN := "res://assets/fonts/VinaSans-Regular.ttf"
const TEXT := "res://assets/fonts/FamiljenGrotesk-Variable.ttf"
const TEXT_ITALIC := "res://assets/fonts/FamiljenGrotesk-Italic-Variable.ttf"
const MONO := "res://assets/fonts/XanhMono-Regular.ttf"

## Bone: paper and old paint, the ink for nearly everything.
const BONE := Color(.92, .9, .84)
const BONE_DIM := Color(.92, .9, .84, .58)
## Sodium: Davao's orange street lamps; names, what is chosen, what is warm.
const SODIUM := Color(.97, .67, .33)
## Rust: yero sheets and dried blood; rules, danger, the boss.
const RUST := Color(.66, .17, .1)
const RUST_DEEP := Color(.36, .07, .05)
## Moon: the cold side of the night.
const MOON := Color(.64, .72, .84)
## Ink: the dark the panels are cut from.
const INK := Color(.03, .028, .03, .94)

const WGHT := 2003265652 # OpenType tag 'wght'

static var _cache := {}

static func _base(path: String) -> FontFile:
	if not _cache.has(path):
		var f: FontFile = load(path) as FontFile
		_cache[path] = f
	return _cache[path]

static func serif(italic := false) -> Font:
	return _base(SERIF_ITALIC if italic else SERIF)

## Street-sign capitals. `spacing`: extra pixels between letters (tracked out for small labels).
static func street(spacing := 0) -> Font:
	var key := "street/%d" % spacing
	if not _cache.has(key):
		var v := FontVariation.new()
		v.base_font = _base(SIGN)
		v.spacing_glyph = spacing
		_cache[key] = v
	return _cache[key]

static func text(weight := 500, italic := false) -> Font:
	var key := "text/%d/%s" % [weight, italic]
	if not _cache.has(key):
		var v := FontVariation.new()
		v.base_font = _base(TEXT_ITALIC if italic else TEXT)
		v.variation_opentype = {WGHT: weight}
		_cache[key] = v
	return _cache[key]

static func mono(spacing := 0) -> Font:
	var key := "mono/%d" % spacing
	if not _cache.has(key):
		var v := FontVariation.new()
		v.base_font = _base(MONO)
		v.spacing_glyph = spacing
		_cache[key] = v
	return _cache[key]

## Set a control's face, size and colour in one go (Label, Button, LineEdit...).
static func style(c: Control, font: Font, size: int, colour := Color(0, 0, 0, 0)) -> Control:
	c.add_theme_font_override("font", font)
	c.add_theme_font_size_override("font_size", size)
	if colour.a > 0.0:
		c.add_theme_color_override("font_color", colour)
	if c is Label and font is FontVariation and (font as FontVariation).base_font == _base(SIGN):
		(c as Label).uppercase = true
	return c

## A label in one go.
static func label(words: String, font: Font, size: int, colour := BONE) -> Label:
	var l := Label.new()
	l.text = words
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style(l, font, size, colour)
	return l

## Street-sign capitals, tracked out a little: a small label or kicker.
static func kicker(words: String, size := 13, colour := SODIUM, spacing := 2) -> Label:
	var l := label(words, street(spacing), size, colour)
	l.uppercase = true
	return l

## The panels' look: cut from the dark, a hairline of bone at the edge, a rust rule along the top.
static func panel(pad_x := 30, pad_y := 24, top_rule := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = INK
	s.border_color = Color(BONE, .1)
	s.set_border_width_all(1)
	s.border_width_top = top_rule
	s.border_color = Color(RUST, .9) if top_rule > 1 else Color(BONE, .1)
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	s.shadow_color = Color(0, 0, 0, .55)
	s.shadow_size = 24
	return s
