extends SceneTree
## Exercise doorway adaptation, quality changes, pause and UI layering in the real scene.
var failures: Array[String] = []
var checks := 0
var main: Node

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error(description)

func frames(count: int) -> void:
	for i in count:
		await process_frame

## Everything in the environment that would show as a change at a doorway, rounded so float noise is ignored.
func _grade(env: Environment) -> String:
	return "%d %.3f %.3f,%.3f,%.3f %.3f %.3f %.3f %.3f %.3f" % [env.ambient_light_source, env.ambient_light_energy,
		env.ambient_light_color.r, env.ambient_light_color.g, env.ambient_light_color.b, env.adjustment_saturation,
		env.adjustment_contrast, env.tonemap_exposure, env.glow_intensity, env.glow_bloom]

func _run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._play()
	await frames(8)
	var player: InteriorPlayer = main.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var neighbourhood: InteriorNeighborhood = get_first_node_in_group("neighbourhood")
	var lighting := InteriorLighting.find_in(main)
	var env := lighting.environment
	# 0.39: one night grade inside and out; nothing in it may change when the camera crosses the navy door.
	var indoor := _grade(env)
	check(env.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR, "The room has no daylight sky ambient")
	check(env.ambient_light_energy < .4, "Room ambient is the dim night ambient (%.2f)" % env.ambient_light_energy)
	var grade := main.ui.get_node("AtmosphereGrade") as ColorRect
	check(grade != null and grade.get_index() == 0, "Atmosphere renders behind all HUD text and touch controls")
	check(grade.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Atmosphere never captures input")
	check(main.atmosphere.process_mode == Node.PROCESS_MODE_PAUSABLE, "Atmosphere pauses with gameplay")
	check(main.atmosphere_particles.process_mode == Node.PROCESS_MODE_PAUSABLE, "Particle controller pauses with gameplay")
	player.camera.global_position = Vector3(20, -1.32, 35)
	await frames(1)
	check(neighbourhood._outside_blend > 0 and neighbourhood._outside_blend < .2, "Doorway lighting starts with a gradual transition")
	await frames(220)
	check(neighbourhood._outside_blend > .99, "The outdoor mist fades fully in")
	check(_grade(env) == indoor, "The grade outdoors is the room's grade (%s vs %s)" % [_grade(env), indoor])
	main._apply_quality(0)
	await frames(4)
	check(not env.volumetric_fog_enabled, "Low disables volumetric mist while standing still")
	check(absf(env.tonemap_exposure - 1.02) < .01, "Changing quality outdoors preserves outdoor exposure")
	main._apply_quality(2)
	await frames(4)
	if DisplayServer.get_name() != "headless" and RenderingServer.get_current_rendering_method() != "gl_compatibility":
		check(env.volumetric_fog_enabled, "High restores volumetric mist while standing still")
	var elapsed: float = main.atmosphere._elapsed
	var balcony: InteriorBalcony = main.get_node("Balcony")
	var flicker := balcony._flicker_time
	paused = true
	await frames(30)
	check(is_equal_approx(elapsed, main.atmosphere._elapsed), "Film grain and atmosphere clock freeze in pause")
	check(is_equal_approx(flicker, balcony._flicker_time), "Street lamp dips freeze in pause")
	paused = false
	# Cross back, reverse direction before fully adapting, then return indoors.
	player.camera.global_position = Vector3(.6, 1.58, 1.3)
	await frames(18)
	player.camera.global_position = Vector3(20, -1.32, 35)
	await frames(18)
	player.camera.global_position = Vector3(.6, 1.58, 1.3)
	await frames(240)
	check(_grade(env) == indoor, "Repeated doorway crossings leave the grade as it was")
	check(not env.volumetric_fog_enabled or DisplayServer.get_name() == "headless", "The mist switches off once faded indoors")
	print("INTERIOR_ATMOSPHERE_INTEGRATION ", JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
