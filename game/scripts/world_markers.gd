extends CanvasLayer
## 0.58: markers on the screen for things a survivor must not miss, wherever they are (through walls, and pinned to
## the edge of the view when they are off it or behind you):
##
##   grenade  every live frag (scripts/grenade.gd feeds them, every frame): a drawn frag inside a ring that is its
##            fuse burning down, and how far away it is. Inside its blast it turns rust red and beats faster.
##   down     a downed teammate (scripts/coop/session.gd): a body lying inside a ring that beats like a slow pulse,
##            "DOWN" in the street face, their name and how far.
##
## Callers `mark()` each entry every frame they want it shown; an entry not marked again is gone the next frame.

const KEEP_FRAMES := 2
const EDGE := 64.0
## Off the view, a marker sits on this ellipse (fractions of the screen from its centre): clear of the corners'
## feeds (radio chat bottom left, ammunition bottom right) and the lens vignette.
const PIN := Vector2(.3, .37)
## Overall size against a 1080-line screen.
const SCALE := 1.45

var _entries := {}
var _canvas: Control

static func of(owner: Node) -> Node:
	if owner == null or not owner.is_inside_tree(): return null
	var found := owner.get_node_or_null("WorldMarkers")
	if found != null: return found
	var layer: CanvasLayer = (load("res://scripts/world_markers.gd") as GDScript).new()
	layer.name = "WorldMarkers"
	owner.add_child(layer)
	return layer

func _ready() -> void:
	layer = 4
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_canvas)
	_canvas.draw.connect(_draw_all)

## `kind`: "grenade" (data: fuse, total, metres, danger) or "down" (data: name, metres).
func mark(key: String, at: Vector3, kind: String, data: Dictionary) -> void:
	_entries[key] = {"at": at, "kind": kind, "data": data, "frame": Engine.get_process_frames()}

func shown(kind := "") -> int:
	var n := 0
	for k in _entries:
		if kind == "" or str(_entries[k].kind) == kind: n += 1
	return n

func _process(_delta: float) -> void:
	var now := Engine.get_process_frames()
	for k in _entries.keys():
		if now - int(_entries[k].frame) > KEEP_FRAMES: _entries.erase(k)
	visible = not _entries.is_empty()
	if visible: _canvas.queue_redraw()

# ---------------------------------------------------------------- drawing

func _draw_all() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	var view := _canvas.get_viewport_rect().size
	var unit := view.y / 1080.0 * SCALE
	var now := Time.get_ticks_msec() / 1000.0
	# Downed teammates under, grenades on top (a grenade is the more urgent).
	for pass_kind in ["down", "grenade"]:
		for k in _entries:
			var e: Dictionary = _entries[k]
			if str(e.kind) != pass_kind: continue
			var placed := _place(camera, e.at, view)
			var at: Vector2 = placed[0]
			var pinned: bool = placed[1]
			if pass_kind == "grenade": _grenade(at, pinned, placed[2], e.data, unit, now)
			else: _down(at, pinned, placed[2], e.data, unit, now)

## Where on the screen: [point, pinned to the edge, direction it points when pinned].
func _place(camera: Camera3D, at: Vector3, view: Vector2) -> Array:
	var centre := view * .5
	var behind := camera.is_position_behind(at)
	var p := camera.unproject_position(at)
	var inner := Rect2(Vector2(EDGE, EDGE), view - Vector2(EDGE, EDGE) * 2.0)
	if not behind and inner.has_point(p): return [p, false, Vector2.ZERO]
	var way := p - centre
	if behind: way = -way
	if way.length() < .01: way = Vector2.DOWN
	way = way.normalized()
	var a := view.x * PIN.x
	var b := view.y * PIN.y
	var t := a * b / sqrt(pow(b * way.x, 2.0) + pow(a * way.y, 2.0))
	return [centre + way * t, true, way]

func _beat(now: float, rate: float) -> float:
	# A heartbeat: two thumps, then a rest.
	var t := fmod(now * rate, 1.0)
	return maxf(exp(-pow((t - .08) / .05, 2.0)), .7 * exp(-pow((t - .3) / .05, 2.0)))

func _text(at: Vector2, words: String, font: Font, size: int, colour: Color, unit: float) -> void:
	var w := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var o := Vector2(at.x - w * .5, at.y)
	_canvas.draw_string_outline(font, o, words, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(2, int(4.0 * unit)), Color(0, 0, 0, colour.a * .75))
	_canvas.draw_string(font, o, words, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)

## A small tick outside the ring, toward where it is, when it is pinned to the edge.
func _tick(at: Vector2, way: Vector2, r: float, colour: Color) -> void:
	var side := Vector2(-way.y, way.x)
	var tip := at + way * (r + 12.0)
	_canvas.draw_colored_polygon(PackedVector2Array([tip, at + way * (r + 4.0) + side * 6.0, at + way * (r + 4.0) - side * 6.0]), colour)

func _grenade(at: Vector2, pinned: bool, way: Vector2, d: Dictionary, unit: float, now: float) -> void:
	var left := clampf(float(d.get("fuse", 0.0)) / maxf(float(d.get("total", 3.6)), .01), 0.0, 1.0)
	var danger: bool = d.get("danger", false)
	var calm := SleepType.SODIUM
	var hot := Color(.93, .2, .14)
	var colour := hot if danger else calm.lerp(hot, clampf(1.0 - left * 1.6, 0.0, 1.0))
	# Faster as the fuse runs down.
	var rate := lerpf(5.0, 1.4, left)
	var pulse := .5 + .5 * sin(now * TAU * rate)
	var r := (17.0 + (3.0 if danger else 0.0) + 1.5 * pulse) * unit
	var line := maxf(1.5, 2.6 * unit)
	_canvas.draw_circle(at, r + 3.0 * unit, Color(0, 0, 0, .38))
	_canvas.draw_arc(at, r, 0.0, TAU, 40, Color(colour, .22), line, true)
	# The fuse: what is left of it, burning down clockwise from the top.
	if left > .001: _canvas.draw_arc(at, r, -PI * .5, -PI * .5 + TAU * left, 40, Color(colour, .95), line * 1.25, true)
	# The frag: a ribbed egg, the spoon down its side, the ring at the top.
	var s := unit * (1.0 + .06 * pulse)
	var body := Color(colour, .95)
	_canvas.draw_set_transform(at + Vector2(0, 1.5) * s, 0.0, Vector2(.8, 1.0) * s)
	_canvas.draw_circle(Vector2.ZERO, 7.0, body)
	_canvas.draw_set_transform(Vector2.ZERO)
	_canvas.draw_line(at + Vector2(-5.4, 1.5) * s, at + Vector2(5.4, 1.5) * s, Color(0, 0, 0, .55), maxf(1.0, 1.1 * s))
	_canvas.draw_line(at + Vector2(0, -5.0) * s, at + Vector2(0, 8.0) * s, Color(0, 0, 0, .45), maxf(1.0, 1.0 * s))
	_canvas.draw_rect(Rect2(at + Vector2(-2.6, -8.6) * s, Vector2(5.2, 3.2) * s), body)
	_canvas.draw_polyline(PackedVector2Array([at + Vector2(2.4, -7.6) * s, at + Vector2(6.6, -6.4) * s, at + Vector2(7.2, 4.5) * s]), body, maxf(1.2, 1.6 * s), true)
	_canvas.draw_arc(at + Vector2(-4.6, -8.4) * s, 2.6 * s, 0.0, TAU, 14, body, maxf(1.0, 1.2 * s), true)
	if pinned: _tick(at, way, r, Color(colour, .9))
	_text(at + Vector2(0, r + 17.0 * unit), "%d m" % int(d.get("metres", 0)), SleepType.mono(1), int(14.0 * unit), Color(colour.lerp(SleepType.BONE, .35), .95), unit)

func _down(at: Vector2, pinned: bool, way: Vector2, d: Dictionary, unit: float, now: float) -> void:
	var red := Color(.9, .17, .12)
	var beat := _beat(now, .9)
	var r := (15.0 + 2.5 * beat) * unit
	var line := maxf(1.5, 2.2 * unit)
	_canvas.draw_circle(at, r + 3.0 * unit, Color(0, 0, 0, .4))
	_canvas.draw_circle(at, r, Color(red, .12 + .22 * beat))
	_canvas.draw_arc(at, r, 0.0, TAU, 36, Color(red, .7 + .3 * beat), line, true)
	# Someone lying on their side: head, body, a knee drawn up.
	var s := unit
	var bone := Color(SleepType.BONE, .95)
	_canvas.draw_circle(at + Vector2(-7.5, -1.5) * s, 2.6 * s, bone)
	_canvas.draw_polyline(PackedVector2Array([at + Vector2(-4.5, -.5) * s, at + Vector2(3.0, .5) * s, at + Vector2(6.0, -3.0) * s, at + Vector2(9.0, 1.5) * s]), bone, maxf(1.4, 2.2 * s), true)
	_canvas.draw_line(at + Vector2(-2.0, 0.0) * s, at + Vector2(0.5, 4.5) * s, bone, maxf(1.2, 1.8 * s), true)
	_canvas.draw_line(at + Vector2(-11.0, 4.6) * s, at + Vector2(11.0, 4.6) * s, Color(bone, .5), maxf(1.0, 1.2 * s), true)
	if pinned: _tick(at, way, r, Color(red, .95))
	_text(at + Vector2(0, -r - 8.0 * unit), "DOWN", SleepType.street(2), int(17.0 * unit), Color(red.lerp(Color.WHITE, .12 * beat), .98), unit)
	_text(at + Vector2(0, r + 18.0 * unit), "%s  ·  %d m" % [str(d.get("name", "")), int(d.get("metres", 0))], SleepType.text(560), int(12.5 * unit), Color(SleepType.BONE, .92), unit)
