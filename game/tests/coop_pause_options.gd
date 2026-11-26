extends SceneTree
## 0.67: Options from the squad game's pause. Esc brings up the pause (Resume, Options, Leave game); Options opens the
## settings window while the game runs on for the squad (the tree is never paused); its Back button and Esc both step
## back to the pause; Resume plays on.
##   godot --headless --path game --script res://tests/coop_pause_options.gd
## Prints INTERIOR_PAUSE_OPTIONS ok|FAIL.
var game
var session
var failed := []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failed.append(label)
	print("PAUSE CHECK ", label, " ", ok)

func frames(count: int) -> void:
	for i in count: await process_frame

func esc() -> void:
	var down := InputEventAction.new()
	down.action = "pause"
	down.pressed = true
	Input.parse_input_event(down)
	await frames(2)
	var up := InputEventAction.new()
	up.action = "pause"
	up.pressed = false
	Input.parse_input_event(up)
	await frames(3)

func buttons() -> Array:
	var out: Array = []
	for b: BaseButton in game.menu_content.find_children("*", "Button", true, false):
		out.append((b as Button).text)
	return out

func press(text: String) -> bool:
	for b: BaseButton in game.menu_content.find_children("*", "Button", true, false):
		if (b as Button).text == text:
			b.pressed.emit()
			return true
	return false

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 20: await process_frame
	session = game.coop
	session.host()
	session.add_bot()
	session.start_game()
	await frames(40)
	check(session.active and game.player.playing, "the squad game is running")
	await esc()
	check(game.current_menu == "coop_pause" and game.menu.visible, "Esc brings up the pause (%s)" % game.current_menu)
	check(buttons().has("Options"), "the pause has Options (%s)" % str(buttons()))
	check(not paused, "the game runs on behind the pause")
	check(press("Options"), "Options pressed")
	await frames(4)
	check(game.current_menu == "options" and game.menu.visible, "the Options window is up (%s)" % game.current_menu)
	check(not paused, "the game still runs on behind Options")
	check(session.local_menu and not game.player.playing, "the player is held while Options is up")
	check(buttons().has("Back"), "Options has Back")
	check(press("Back"), "Back pressed")
	await frames(4)
	check(game.current_menu == "coop_pause", "Back returns to the pause (%s)" % game.current_menu)
	check(not paused, "not paused after Back")
	press("Options")
	await frames(4)
	await esc()
	check(game.current_menu == "coop_pause" and game.menu.visible, "Esc in Options returns to the pause (%s)" % game.current_menu)
	await esc()
	await frames(6)
	check(not game.menu.visible and not session.local_menu, "Esc at the pause resumes")
	check(game.player.playing, "the player plays again")
	print("INTERIOR_PAUSE_OPTIONS ", "ok" if failed.is_empty() else "FAIL " + str(failed))
	quit(0 if failed.is_empty() else 1)
