class_name InteriorStudio
extends Node3D
## Runtime glue for the baked studio (scenes/studio/studio.tscn): prepares the downloaded model
## instances (alpha-scissor plants), lights the two monitors with generated DAW / game screens,
## and scales the studio lights with the room's quality tier (Compatibility keeps two lights).

var _tier := -2
var _poll := 0.0

func _ready() -> void:
	add_to_group("studio")
	for node in find_children("*", "Node3D", true, false):
		if node.has_meta("keep_instance"):
			InteriorModelKit.prepare_instance(node, 1)
		if node.has_meta("studio_screen"):
			_light_screen(node, str(node.get_meta("studio_screen")))

func _process(delta: float) -> void:
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = .5
	var lighting := InteriorLighting.find_in(get_parent())
	var tier := lighting.tier if lighting != null else 2
	var mobile := lighting.mobile if lighting != null else false
	var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	if tier == _tier:
		return
	_tier = tier
	var light_budget := 2 if (mobile or compat) else 99
	for light: Light3D in find_children("*", "Light3D", false, false):
		var keep := light_budget > 0 and (not (mobile or compat) or light.name in ["Room fill", "LED glow purple"])
		light.visible = keep
		if keep and (mobile or compat):
			light_budget -= 1
		light.shadow_enabled = keep and bool(light.get_meta("studio_shadow", false)) and tier >= 1 and not (mobile or compat)

## Gives the monitor's screen surface an emissive, generated picture.
func _light_screen(model: Node, kind: String) -> void:
	var texture := ImageTexture.create_from_image(_screen_image(kind))
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.BLACK
	material.emission_enabled = true
	material.emission_texture = texture
	material.emission_energy_multiplier = 1.6
	material.roughness = .15
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := (child as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var source := mesh.surface_get_material(i)
			if source != null and source.resource_name.to_lower().contains("screen"):
				(child as MeshInstance3D).set_surface_override_material(i, material)

static func _screen_image(kind: String) -> Image:
	var w := 512
	var h := 224
	var image := Image.create(w, h, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3 if kind == "daw" else 11
	if kind == "daw":
		# A DAW arrangement: dark UI, track headers, coloured clips with waveforms, a playhead.
		image.fill(Color(.07, .075, .09))
		image.fill_rect(Rect2i(0, 0, w, 14), Color(.13, .14, .17))
		image.fill_rect(Rect2i(0, 14, 70, h - 14), Color(.1, .105, .125))
		var colours := [Color(.95, .36, .45), Color(.98, .7, .25), Color(.35, .85, .55), Color(.3, .65, 1.0), Color(.7, .45, 1.0), Color(.95, .5, .9)]
		for track in 8:
			var y := 18 + track * 25
			image.fill_rect(Rect2i(4, y, 60, 20), Color(.16, .17, .2))
			image.fill_rect(Rect2i(6, y + 3, 8, 14), colours[track % colours.size()])
			var x := 74 + rng.randi_range(0, 30)
			while x < w - 20:
				var length := rng.randi_range(40, 120)
				var c: Color = colours[track % colours.size()]
				image.fill_rect(Rect2i(x, y, mini(length, w - x - 4), 20), c.darkened(.55))
				for i in mini(length, w - x - 4):
					var amp := int(absf(sin(i * .31 + track) * cos(i * .07)) * 8.0 * rng.randf_range(.6, 1.0))
					image.fill_rect(Rect2i(x + i, y + 10 - amp, 1, amp * 2 + 1), c)
				x += length + rng.randi_range(6, 40)
		image.fill_rect(Rect2i(300, 14, 2, h - 14), Color(1, 1, 1))
	else:
		# A game on the second screen: dusk sky, hills, a HUD bar.
		for y in h:
			var t := y / float(h)
			image.fill_rect(Rect2i(0, y, w, 1), Color(.25, .2, .45).lerp(Color(.98, .55, .35), t * 1.2))
		for x in w:
			var ridge := int(h * (.55 + .12 * sin(x * .021) + .05 * sin(x * .07)))
			image.fill_rect(Rect2i(x, ridge, 1, h - ridge), Color(.12, .1, .2))
			var near := int(h * (.75 + .08 * sin(x * .033 + 1.7)))
			image.fill_rect(Rect2i(x, near, 1, h - near), Color(.06, .05, .1))
		image.fill_rect(Rect2i(10, h - 20, 120, 8), Color(.15, .9, .4))
		image.fill_rect(Rect2i(10, h - 10, 90, 5), Color(.3, .6, 1.0))
		image.fill_rect(Rect2i(w / 2 - 1, h / 2 - 8, 2, 16), Color(1, 1, 1))
		image.fill_rect(Rect2i(w / 2 - 8, h / 2 - 1, 16, 2), Color(1, 1, 1))
	image.generate_mipmaps()
	return image
