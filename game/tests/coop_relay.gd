extends SceneTree
## 0.62: a squad through the Sleep relay (server/relay/sleep_relay.py). Two processes:
##   SLEEP_RELAY_HOST=127.0.0.1 SLEEP_COOP_PORT=26108 godot --headless --path game --script res://tests/coop_relay.gd -- --host --port-file=<file>
##   SLEEP_RELAY_HOST=127.0.0.1 godot --headless --path game --script res://tests/coop_relay.gd -- --peer --port-file=<file>
## Without SLEEP_RELAY_HOST both go through the real Sleep server.
var game
var session
var failed := []
var checks := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed.append(label)
	print("RELAY CHECK ", label, " ", ok)

func arg(key: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + key + "="): return a.substr(key.length() + 3)
	return ""

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	session = game.coop
	session.page()
	var file := arg("port-file")
	if "--peer" in OS.get_cmdline_user_args(): await peer(file)
	else: await host(file)
	print("RELAY RESULT ", "PASS" if failed.is_empty() else "FAIL %s" % str(failed), " (", checks, " checks)")
	await create_timer(.5, true).timeout
	quit(0 if failed.is_empty() else 1)

func host(file: String) -> void:
	if "--lobby" in OS.get_cmdline_user_args():
		var until := Time.get_ticks_msec() + 15000
		while not session.lobby.online and Time.get_ticks_msec() < until: await process_frame
		check(session.lobby.online and session.lobby._broker == 0, "lobby on the Sleep server's broker (broker %d)" % session.lobby._broker)
	session.host()
	check(session.peer != null, "ENet server open")
	session.relay.open("Relay test host")
	var limit := Time.get_ticks_msec() + 10000
	while not session.relay.is_open() and Time.get_ticks_msec() < limit: await process_frame
	check(session.relay.is_open(), "relay gave a room (%s)" % session.relay.failed)
	if not session.relay.is_open(): return
	var f := FileAccess.open(file, FileAccess.WRITE)
	f.store_string("%s %d" % [session.relay.public_ip, session.relay.port])
	f.close()
	limit = Time.get_ticks_msec() + 90000
	while session.team.size() < 2 and Time.get_ticks_msec() < limit: await process_frame
	check(session.team.size() == 2, "friend joined through the relay")
	if session.team.size() < 2: return
	await create_timer(1.0, true).timeout
	session.start_game()
	limit = Time.get_ticks_msec() + 30000
	while session.network_ready.size() < session.team.size() and Time.get_ticks_msec() < limit: await process_frame
	check(session.network_ready.size() == session.team.size(), "friend entered the mission")
	# a few seconds of real play traffic (poses both ways) through the relay
	var light_until := Time.get_ticks_msec() + 8000
	var lit := false
	while Time.get_ticks_msec() < light_until and not lit:
		for id: int in session.team:
			if id != 1 and session.team[id].light: lit = true
		await process_frame
	check(lit, "friend's flashlight state arrived through the relay")
	await create_timer(3.0, true).timeout
	session.relay.close()

func peer(file: String) -> void:
	var limit := Time.get_ticks_msec() + 60000
	while not FileAccess.file_exists(file) and Time.get_ticks_msec() < limit: await create_timer(.2, true).timeout
	var parts := FileAccess.get_file_as_string(file).split(" ")
	check(parts.size() == 2, "room address published")
	if parts.size() != 2: return
	session.join_listing({"relay": true, "ip": parts[0], "port": int(parts[1]), "host": "Relay test host", "same_version": true})
	limit = Time.get_ticks_msec() + 90000
	while not session.active and Time.get_ticks_msec() < limit: await process_frame
	check(session.active, "entered the host's mission")
	if session.active:
		game.story.flashlight.set_on(true)
		await create_timer(10.0, true).timeout
		check(session.peer != null and session.peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, "still connected after play")
