extends SceneTree
## 0.45: the multiplayer screens and the online lobby.
##   `-- --role=host`  opens the screen, waits for the lobby, hosts a game (listed online), waits for a player to
##                     join from the list, ready up and chat, starts the mission, and checks the client is in it.
##   `-- --role=join`  opens the screen, waits for the host's game in the list, joins it with one click (no
##                     address), says hello in both chats, readies up, and waits for the mission to begin.
##   `-- --role=solo`  (default) only the screens: browse online, rename, host, add squad AI.
## `-- --shots=<dir>` saves photos of the screens to work/v45/<dir>/ (needs a window, not --headless).
## Prints LOBBY CHECK lines and INTERIOR_LOBBY {json}.
var main
var session
var failed := []
var checks := 0
var role := "solo"
var shots := ""
var tag := ""

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed.append(label)
	print("LOBBY CHECK [", role, "] ", label, " ", ok)

func wait_for(condition: Callable, seconds: float) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if condition.call(): return true
		await process_frame
	return condition.call()

func photo(label: String) -> void:
	if shots.is_empty() or DisplayServer.get_name() == "headless": return
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://../work/v45/" + shots)
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_texture().get_image().save_jpg(dir + "/" + label + ".jpg", .92)
	print("photo ", label)

func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="): role = a.trim_prefix("--role=")
		if a.begins_with("--shots="): shots = a.trim_prefix("--shots=")
		if a.begins_with("--tag="): tag = a.trim_prefix("--tag=")
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	session = main.coop
	var net = session.lobby
	net.set_player_name(("Host " if role == "host" else ("Joiner " if role == "join" else "Tester ")) + tag)
	session.page()
	await process_frame
	check(session.ui != null and session.ui.visible, "the multiplayer screen opens")
	check(not main.menu.visible, "the old centred window is hidden")
	var online: bool = await wait_for(func(): return net.online, 20.0)
	check(online, "online lobby reached (%s)" % str(net.BROKERS[net._broker][0]))
	await photo("browse")
	if role == "solo":
		await solo()
	elif role == "host":
		await host_role()
	else:
		await join_role()
	print("INTERIOR_LOBBY ", JSON.stringify({"role": role, "passed": failed.is_empty(), "checks": checks, "failures": failed}))
	net.stop()
	for i in 10: await process_frame
	quit(0 if failed.is_empty() else 1)

func solo() -> void:
	var net = session.lobby
	check(not net.set_player_name("x"), "a one-letter name is refused")
	check(net.set_player_name("Lemon [Tester]") and net.player_name == "Lemon Tester", "names are cleaned (%s)" % net.player_name)
	net.say("lobby test line")
	await session.host_public()
	await process_frame
	check(session.peer != null and session.ui.view == "room", "hosting switches to the squad room")
	check(session.display_name(1) == "Lemon Tester", "the host's squad card shows the player name")
	session.add_bot()
	session.add_bot()
	session.send_party("squad test line")
	await process_frame
	check(session.team.size() == 3 and session.waiting_count() == 0, "squad AI fill places and count as ready")
	await photo("room")
	session.ui.view = ""
	session.leave_lobby()
	await process_frame
	check(session.peer == null and not session.ui.visible, "leaving closes the room and the screen")

func host_role() -> void:
	await session.host_public()
	check(session.peer != null, "hosted")
	var listed: bool = await wait_for(func(): return session.lobby.game.has("lan"), 5.0)
	check(listed, "the game is published to the lobby")
	var joined: bool = await wait_for(func(): return session.humans() == 2, 90.0)
	check(joined, "a player joined from the list")
	var ready: bool = await wait_for(func(): return session.waiting_count() == 0, 30.0)
	check(ready, "the player readied up")
	var heard: bool = await wait_for(func():
		for e: Array in session.party_log:
			if str(e[1]) == "hello squad": return true
		return false, 15.0)
	check(heard, "squad chat from the joiner arrived")
	session.send_party("welcome")
	await photo("host_room")
	for i in 30: await process_frame
	session.start_game()
	var going: bool = await wait_for(func(): return session.active, 10.0)
	check(going, "the mission starts for the host")
	var both: bool = await wait_for(func(): return session.network_ready.size() == 2, 40.0)
	check(both, "the joiner entered the mission")
	for i in 120: await process_frame

func join_role() -> void:
	var net = session.lobby
	var found: bool = await wait_for(func():
		for g: Dictionary in net.games():
			if str(g.host) == "Host " + tag: return true
		return false, 90.0)
	check(found, "the host's game shows in the list")
	await photo("browse_listed")
	var game := {}
	for g: Dictionary in net.games():
		if str(g.host) == "Host " + tag: game = g
	if game.is_empty(): return
	net.say("hello lobby from " + tag)
	await session.join_listing(game)
	var connected: bool = await wait_for(func(): return session.team.has(session.local_id()), 30.0)
	check(connected, "joined with one click, no address typed")
	check(session.display_name(1) == "Host " + tag, "the host shows under its player name")
	session.send_party("hello squad")
	session.toggle_ready()
	var ready: bool = await wait_for(func(): return bool(session.team.get(session.local_id(), {}).get("ready", false)), 10.0)
	check(ready, "ready is shown back by the host")
	await photo("join_room")
	var welcomed: bool = await wait_for(func():
		for e: Array in session.party_log:
			if str(e[1]) == "welcome": return true
		return false, 20.0)
	check(welcomed, "squad chat from the host arrived")
	var going: bool = await wait_for(func(): return session.active, 60.0)
	check(going, "the mission began for the joiner")
	for i in 240: await process_frame
