extends Node
const Mission := preload("res://scripts/coop/mission.gd")
const Markers := preload("res://scripts/world_markers.gd")
## 0.58: a teammate's tag at full health, and in the red (Mission.CRITICAL_HP and under).
const TAG_COLOUR := Color(.92,.95,1.0,.92)
const TAG_CRITICAL := Color(1.0,.2,.15,1.0)
const Figure := preload("res://scripts/coop/figure.gd")
const Bots := preload("res://scripts/coop/bots.gd")
const Voices := preload("res://scripts/coop/voices.gd")
const LobbyNet := preload("res://scripts/coop/lobby_net.gd")
const LobbyUI := preload("res://scripts/coop/lobby_ui.gd")
const Relay := preload("res://scripts/coop/relay.gd")
## 0.40: the team's state goes out this often (s), and each player's own pose.
const STATE_RATE := .05
const POSE_RATE := .05
const NAMES := ["Alex","Aljay","Louie","Anthony","Clyde"]
const PORT := 25108
var main
var team := {}
var avatars := {}
var mission
var peer: ENetMultiplayerPeer
var status := ""
var last_state_tick := -1
var show_host_left := false
var preferred := 0
var custom_outfit := "default"
var custom_hair := "default"
var custom_hair_color := 0
var _preview_pivot: Node3D
var _preview_figure: Node3D
var _preview_label: Label
var address := ""
var active := false
var local_menu := false
var tick := 0.0
var world_tick := 0.0
var roster_label: Label
var start_button: Button
var feedback: Label
var dialogue: Label
var dialogue_panel: PanelContainer
## 0.54: who is talking, over the line (street-sign capitals, sodium).
var dialogue_name: Label
## 0.50: the school's story box (mission `flags.story`, the page the host is on), typed out page by page.
var story_panel: PanelContainer
var story_body: Label
var story_foot: Label
var _story_page := -1
var _story_at := 0.0
var hint: Label
var tutorial := true
var deadline := 0
var last_hp := 100
var hud_message := ""
var hud_until := 0
var last_results := false
## 0.49: the chapter leaderboard (mission `flags.board`): open here, and what it last showed (who is ready).
var board_open := false
var _board_sig := ""
var doors := {}
var network_ready := {}
## 0.40: the squad AI (host only) and everyone's voices.
var bots
var voices
var _avatar_text := {}
## 0.41: one number every peer builds Store Road from (dead lamps, lit windows, who stands where).
var run_seed := 5849
## 0.41: a line of advice now and then at the bottom of the screen (local): shown once each, the ones that fit
## what is happening now first.
const HINTS := {
	"light": "Your flashlight carries a long way. Anything that sees the beam comes for it. L switches it off.",
	"quiet": "Running is loud. Walk, or hold Ctrl, past the ones that haven't noticed you.",
	"shots": "Every shot is heard a few streets away. Whatever's sleeping in the houses wakes up to it.",
	"head": "Go for the head. Anywhere else takes a lot more rounds.",
	"heal": "Hold F to use a healthkit on yourself. Hold E on a hurt or downed teammate to patch them up.",
	"bodies": "The dead trip them up. Bodies piled in a doorway slow the rest down.",
	"squad": "Press ~ to talk to your squad. Tell them to hold and they stay put.",
	"tables": "The tables outside the mart can be moved. Hold E on one to drag it, let go to leave it.",
	"stack": "One table, they climb over. Two together, one behind the other, and they have to shove through.",
	"guns": "The soldiers' rifles are on the crates by the right wall, ammo beside them. Two shotguns as well.",
	"back": "Something is at the stockroom's back door. A table pushed up against it holds it longer.",
	"push": "Enough of them leaning on a table will slide it. Watch the gaps.",
	"stairs": "The students piled desks into the stairs. Look for their notes at the foot of each stairwell: they say which way is open.",
}
var hint_label: Label
var hint_queue: Array = []
var hint_shown := {}
var hint_wait := 7.0
var hint_time := 0.0
var _hint_stage := -1
var _dragging := -1
## 0.57: E went down on a school prop (school_props.gd): its release lets go, even before the host's state says it is
## held; the prop body the local player is not bumped by while dragging it; pushes waiting to go to the host.
var _prop_held := false
var _prop_dragging: RigidBody3D
var _pushes := {}
## 0.45: the online lobby (lobby_net.gd), its screens (lobby_ui.gd), the squad's chat (room and mission), where
## the internet reaches this host, and the router's port opened for it (UPnP, when the router allows).
var lobby
var ui
## 0.62: the Sleep server line that gives the squad a public room (relay.gd).
var relay
var party_log: Array = []
var public_endpoint := {}
var _upnp: UPNP
var _upnp_thread: Thread
var _upnp_port := false
var chatting := false
var chat_feed: VBoxContainer
var chat_input: LineEdit
## 0.46: the host's debug "infected cannot hurt the team" (kept here, so a new mission keeps it, and blasts obey it
## too), the game mode the host picked, and the held keys: F (a healthkit on yourself), G (put the weapon down).
var harmless := false
var mode := "normal"
const MODES := {
	"easy": {"label": "EASY", "about": "Rifle (100) and Glock (60), a frag grenade and a healthkit each.", "pistol": 60, "rifle": 100, "grenades": 1, "kits": 1},
	"normal": {"label": "NORMAL", "about": "Glock (65) and a healthkit each.", "pistol": 65, "rifle": 0, "grenades": 0, "kits": 1},
	"hard": {"label": "HARD", "about": "A Glock with 50 rounds. Nothing else.", "pistol": 50, "rifle": 0, "grenades": 0, "kits": 0},
}
const DROP_HOLD := .6
var _f_held := false
var _g_down := -1.0
var _g_dropped := false

func setup(parent) -> void:
	main = parent
	# 0.64 (owner): a phone's squad game starts on Easy.
	if main.mobile: mode = "easy"
	_load_look()
	lobby = LobbyNet.new()
	lobby.name = "LobbyNet"
	add_child(lobby)
	lobby.message.connect(_lobby_message)
	relay = Relay.new()
	relay.name = "Relay"
	add_child(relay)
	relay.setup(self)
	relay.ready_changed.connect(_relay_changed)
	(multiplayer as SceneMultiplayer).server_relay = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_new_peer)
	multiplayer.peer_disconnected.connect(_lost_peer)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_failed.bind("Couldn’t reach the host. Try again in a moment: their game may have just closed."))
	multiplayer.server_disconnected.connect(_failed.bind("The host left the game."))

func page() -> void:
	main._show_menu("multiplayer")

## 0.64 (owner): on a phone the squad game unloads the rice fields and the Nichols property (the town's ways to them
## are shut by InteriorMapSeals.seal_for_squad). What they drew, their sounds and their colliders all go, and since a
## phone keeps nothing of the start-up read (boot.gd), the memory they held is given back. Back to the solo game
## from here is a restart, which builds the whole world again.
const FAR_PLACES := ["Fields", "Balcony/Neighbourhood/Nichols property"]
func drop_far_places() -> int:
	var gone := 0
	for path: String in FAR_PLACES:
		var place: Node = main.get_node_or_null(path)
		if place == null: continue
		place.get_parent().remove_child(place)
		place.queue_free()
		gone += 1
	return gone

## 0.64: on a phone the keys named in a prompt or a hint are the touch buttons that do the same.
const PHONE_WORDS := [["Let go of E", "Let go of USE"], ["Hold E", "Keep holding USE"],
	["hold E", "keep holding USE"], ["E  •  ", "USE  •  "], ["Hold F", "Hold MEDKIT"],
	["L switches", "LIGHT switches"], ["hold Ctrl", "push the stick only a little"]]
func phone(text: String) -> String:
	if not main.mobile: return text
	for pair: Array in PHONE_WORDS:
		text = text.replace(str(pair[0]), str(pair[1]))
	return text

## The multiplayer screens (interior.gd shows them for the "multiplayer" page and hides them for any other).
func show_lobby_ui() -> void:
	if ui == null:
		ui = LobbyUI.new()
		main.ui.add_child(ui)
		ui.setup(self)
	lobby.start()
	if peer == null: lobby.set_state("menu")
	ui.show_view()

func hide_lobby_ui() -> void:
	if ui != null: ui.hide()

## A name to show for a member: the player's own (lobby) name, or the character for the squad AI.
func display_name(id: int) -> String:
	if not team.has(id): return "?"
	var p: Dictionary = team[id]
	var n := str(p.get("name", ""))
	if n.is_empty() or is_bot(id): n = NAMES[int(p.slot)] + (" (AI)" if is_bot(id) else "")
	return n

## How many players the host is still waiting on (not ready, or still connecting).
func waiting_count() -> int:
	var n := 0
	for id: int in team:
		if id != 1 and not is_bot(id) and not bool(team[id].get("ready", false)): n += 1
	if peer != null and multiplayer.is_server(): n += maxi(0, multiplayer.get_peers().size() + 1 - humans())
	return n

func toggle_ready() -> void:
	if peer == null or not team.has(local_id()) or multiplayer.is_server(): return
	set_ready.rpc_id(1, not bool(team[local_id()].get("ready", false)))

@rpc("any_peer","reliable")
func set_ready(on: bool) -> void:
	if not multiplayer.is_server() or active: return
	var id := multiplayer.get_remote_sender_id()
	if not team.has(id): return
	team[id]["ready"] = on
	roster.rpc(team)
	draw_roster()
	party_line.rpc("", "%s is %s." % [display_name(id), "ready" if on else "not ready"])

# ---------------------------------------------------------------- 0.45: squad chat

func send_party(text: String) -> void:
	var t := text.strip_edges().substr(0, 160)
	if t.is_empty() or peer == null: return
	if multiplayer.is_server(): party_line.rpc(display_name(1), t)
	else: party_say.rpc_id(1, t)

@rpc("any_peer","reliable")
func party_say(text: String) -> void:
	if not multiplayer.is_server(): return
	var id := multiplayer.get_remote_sender_id()
	if not team.has(id): return
	party_line.rpc(display_name(id), text.strip_edges().substr(0, 160))

## A line in the squad chat ("" who: something that happened, in grey).
@rpc("authority","call_local","reliable")
func party_line(who: String, text: String) -> void:
	party_log.append([who, text])
	if party_log.size() > 80: party_log.pop_front()
	if ui != null: ui.add_party_line(who, text)
	_post_chat(who, text)

## The squad's chat so far, for someone who just joined.
@rpc("authority","reliable")
func party_history(who: String, text: String) -> void:
	party_log.append([who, text])
	if ui != null: ui.add_party_line(who, text)

func _post_chat(who: String, text: String) -> void:
	if not is_instance_valid(chat_feed): return
	var label: Label = main._label(("%s:  %s" % [who, text]) if who != "" else text, 14)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(.95, .93, .88) if who != "" else Color(.7, .7, .72))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, .85))
	chat_feed.add_child(label)
	while chat_feed.get_child_count() > 7: chat_feed.get_child(0).free()
	var fade := label.create_tween()
	fade.tween_interval(10.0)
	fade.tween_property(label, "modulate:a", 0.0, 1.0)
	fade.tween_callback(label.queue_free)

## T (or Enter) during the mission: type to the squad; Enter sends, Esc puts it away.
func _open_chat() -> void:
	if not is_instance_valid(chat_input): return
	chatting = true
	chat_input.clear()
	chat_input.show()
	chat_input.grab_focus()

func _close_chat() -> void:
	chatting = false
	if is_instance_valid(chat_input):
		chat_input.release_focus()
		chat_input.hide()

func _chat_sent(t: String) -> void:
	send_party(t)
	_close_chat()

func _chat_key(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and (e as InputEventKey).keycode == KEY_ESCAPE:
		chat_input.accept_event()
		_close_chat()

func _build_chat_hud() -> void:
	chat_feed = VBoxContainer.new()
	chat_feed.name = "SquadChat"
	chat_feed.add_theme_constant_override("separation", 1)
	chat_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_feed.alignment = BoxContainer.ALIGNMENT_END
	main.hud.add_child(chat_feed)
	chat_feed.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	chat_feed.offset_left = 24
	chat_feed.offset_right = 420
	chat_feed.offset_top = -100 - 7 * 20
	chat_feed.offset_bottom = -100
	chat_input = LineEdit.new()
	chat_input.name = "SquadChatInput"
	chat_input.placeholder_text = "Message your squad…   Enter sends, Esc cancels"
	chat_input.max_length = 160
	chat_input.add_theme_font_size_override("font_size", 14)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, .6)
	back.border_color = Color(.74, .07, .09, .8)
	back.set_border_width_all(1)
	back.set_corner_radius_all(3)
	back.set_content_margin_all(7)
	chat_input.add_theme_stylebox_override("normal", back)
	chat_input.add_theme_stylebox_override("focus", back)
	main.hud.add_child(chat_input)
	chat_input.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	chat_input.offset_left = 24
	chat_input.offset_right = 420
	chat_input.offset_top = -92
	chat_input.offset_bottom = -60
	chat_input.hide()
	chat_input.text_submitted.connect(_chat_sent)
	chat_input.gui_input.connect(_chat_key)
	for entry: Array in party_log.slice(maxi(0, party_log.size() - 4)): _post_chat(entry[0], entry[1])

# ---------------------------------------------------------------- 0.45: hosting online, joining from the list

## Host from the multiplayer screen: learn where the internet sees this PC (STUN, from the game's own port, so
## the router keeps that mapping for us), open the game, ask the router for the port (UPnP, in the background),
## and list the game in the lobby.
func host_public() -> void:
	if peer != null: return
	note("Opening your game…")
	await get_tree().process_frame
	await get_tree().process_frame
	var seen: Dictionary = LobbyNet.stun(PORT)
	host()
	if peer == null: return
	public_endpoint = seen
	party_log.clear()
	party_line("", "You opened the squad. Friends join from their game list.")
	relay.open(lobby.player_name if lobby != null else "Host")
	if seen.is_empty(): note("Your game is open on your network. The internet address couldn’t be found, so friends outside may not reach it.")
	else: note("Your game is listed. Friends see it in their list and join with one click.")
	_upnp_port = false
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_open)
	_publish_game()

func _upnp_open() -> Dictionary:
	var u := UPNP.new()
	if u.discover(1600, 2) != UPNP.UPNP_RESULT_SUCCESS: return {}
	var gateway := u.get_gateway()
	if gateway == null or not gateway.is_valid_gateway(): return {}
	if u.add_port_mapping(PORT, PORT, "Sleep co-op", "UDP", 0) != UPNP.UPNP_RESULT_SUCCESS: return {}
	_upnp = u
	return {"ip": u.query_external_address()}

## 0.62: the Sleep server gave us a room (or the line dropped): list the game where friends can reach it.
func _relay_changed(on: bool) -> void:
	if peer == null or not multiplayer.is_server(): return
	if on: note("Your game is online through the Sleep server. Friends join from their list: no VPN needed.")
	elif relay.failed != "": note("%s Friends on your network can still join." % relay.failed)
	_publish_game()

## The router answered (or not): when it opened the port and agrees on our address, list the plain port.
func _upnp_check() -> void:
	if _upnp_thread == null or _upnp_thread.is_alive(): return
	var got: Dictionary = _upnp_thread.wait_to_finish()
	_upnp_thread = null
	if not got.is_empty() and str(got.get("ip", "")) == str(public_endpoint.get("ip", "-")):
		_upnp_port = true
		_publish_game()

func _upnp_close() -> void:
	if _upnp_thread != null:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null
	if _upnp != null:
		_upnp.delete_port_mapping(PORT, "UDP")
		_upnp = null
	_upnp_port = false

## What the lobby shows of us: our state, and the game when we host one.
func _publish_game() -> void:
	if lobby == null: return
	if peer == null:
		lobby.set_state("menu")
		return
	if not multiplayer.is_server():
		lobby.set_state("in a game" if active else "in a lobby")
		return
	var g := {"mission": "Olivar Family Mart", "p": humans(), "b": team.size() - humans(), "st": "playing" if active else "lobby",
		"lan": LobbyNet.lan_addresses(), "lport": PORT}
	if relay != null and relay.is_open():
		g["ip"] = relay.public_ip
		g["port"] = relay.port
		g["relay"] = true
		g["hip"] = relay.seen_as if relay.seen_as != "" else str(public_endpoint.get("ip", ""))
	elif not public_endpoint.is_empty():
		g["ip"] = public_endpoint.ip
		g["port"] = PORT if _upnp_port else int(public_endpoint.port)
	lobby.set_state("in a game" if active else "hosting", g)

## A game from the list: the same router as the host means its home address; otherwise tell the host where the
## internet sees us (STUN), so it sends a few packets our way and our router lets its answer in, then connect.
func join_listing(g: Dictionary) -> void:
	if peer != null: return
	if not g.get("same_version", true):
		note("That game runs a different version. Both of you need the same build.")
		return
	note("Joining %s…" % str(g.get("host", "the game")))
	await get_tree().process_frame
	await get_tree().process_frame
	if bool(g.get("relay", false)):
		_join_relay(g)
		return
	var local_port := randi_range(30000, 60000)
	var me: Dictionary = LobbyNet.stun(local_port)
	var lan: Array = g.get("lan", [])
	var target := ""
	var port := int(g.get("port", PORT))
	if (me.is_empty() or str(me.get("ip", "")) == str(g.get("ip", ""))) and not lan.is_empty():
		target = _closest_lan(lan)
		port = int(g.get("lport", PORT))
		local_port = 0
	elif g.has("ip"):
		target = str(g.ip)
		if not me.is_empty():
			lobby.send_to(str(g.id), {"k": "punch", "ip": me.ip, "port": int(me.port)})
			await get_tree().create_timer(.4, true, false, true).timeout
	if target.is_empty():
		note("That host can’t be reached from here.")
		return
	if peer != null: return
	var transport := ENetMultiplayerPeer.new()
	if transport.create_client(target, port, 6, 0, 0, local_port) != OK:
		note("Couldn’t open a connection to that game.")
		return
	peer = transport
	multiplayer.multiplayer_peer = peer
	deadline = Time.get_ticks_msec() + 15000
	party_log.clear()
	note("Connecting to %s…" % str(g.get("host", "the host")))
	page()

## 0.62: a game hosted through the Sleep server. Same router as the host: its home address; otherwise the room.
func _join_relay(g: Dictionary) -> void:
	var target := str(g.get("ip", ""))
	var port := int(g.get("port", 0))
	var lan: Array = g.get("lan", [])
	if not lan.is_empty() and str(g.get("hip", "")) != "":
		var me: Dictionary = LobbyNet.stun(randi_range(30000, 60000))
		if str(me.get("ip", "-")) == str(g.hip):
			target = _closest_lan(lan)
			port = int(g.get("lport", PORT))
	if not target.is_valid_ip_address() or port <= 0:
		note("That game can't be reached.")
		return
	if peer != null: return
	var transport := ENetMultiplayerPeer.new()
	if transport.create_client(target, port, 6) != OK:
		note("Couldn’t open a connection to that game.")
		return
	peer = transport
	multiplayer.multiplayer_peer = peer
	deadline = Time.get_ticks_msec() + 15000
	party_log.clear()
	note("Connecting to %s…" % str(g.get("host", "the host")))
	page()

func _closest_lan(list: Array) -> String:
	var mine := LobbyNet.lan_addresses()
	for ip in list:
		for own in mine:
			if str(ip).get_slice(".", 0) == str(own).get_slice(".", 0) and str(ip).get_slice(".", 1) == str(own).get_slice(".", 1) and str(ip).get_slice(".", 2) == str(own).get_slice(".", 2): return str(ip)
	return str(list[0])

## Someone asks us (the host) to open the way to them: a few packets from the game's own socket.
func _lobby_message(data: Dictionary) -> void:
	if str(data.get("k", "")) != "punch" or peer == null or not multiplayer.is_server() or active: return
	var ip := str(data.get("ip", ""))
	var port := int(data.get("port", 0))
	if not ip.is_valid_ip_address() or port <= 0: return
	for k in 10:
		if peer == null or peer.host == null: return
		peer.host.socket_send(ip, port, PackedByteArray([0x53, 0x4c, 0x50]))
		await get_tree().create_timer(.15, true, false, true).timeout

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if lobby != null and is_instance_valid(lobby): lobby.stop()
		if relay != null and is_instance_valid(relay): relay.close()
		if _upnp_thread != null or _upnp != null: _upnp_close()


const LOOK_CFG := "user://coop_look.cfg"

func _load_look() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(LOOK_CFG) != OK:
		return
	preferred = clampi(int(cfg.get_value("look", "character", 0)), 0, NAMES.size() - 1)
	custom_outfit = Figure.valid_outfit(str(cfg.get_value("look", "outfit", "default")))
	custom_hair = Figure.valid_hair(str(cfg.get_value("look", "hair", "default")))
	custom_hair_color = clampi(int(cfg.get_value("look", "hair_color", 0)), 0, Figure.HAIR_COLORS.size() - 1)

func _save_look() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("look", "character", preferred)
	cfg.set_value("look", "outfit", custom_outfit)
	cfg.set_value("look", "hair", custom_hair)
	cfg.set_value("look", "hair_color", custom_hair_color)
	cfg.save(LOOK_CFG)

func current_look() -> Dictionary:
	return {"outfit": custom_outfit, "hair": custom_hair, "hair_color": custom_hair_color}

func _sync_my_look() -> void:
	_save_look()
	_refresh_preview()
	if peer != null and not active:
		if multiplayer.is_server():
			_apply_member_look(1, current_look())
			roster.rpc(team)
			draw_roster()
		else:
			update_look.rpc_id(1, current_look())

func _outfit_label(key: String) -> String:
	for entry: Array in Figure.OUTFITS:
		if entry[0] == key:
			return str(entry[1])
	return "Default Outfit"

func _hair_label(key: String) -> String:
	for entry: Array in Figure.HAIRSTYLES:
		if entry[0] == key:
			return str(entry[1])
	return "Default Hair"

func _add_option_row(parent: VBoxContainer, caption: String, items: Array, selected_idx: int, on_pick: Callable) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl: Label = main._label(caption, 17)
	lbl.custom_minimum_size = Vector2(96, 0)
	row.add_child(lbl)
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.add_theme_font_size_override("font_size", 17)
	# 0.54: not as wide as its longest choice (that pushed the squad chat off the screen's right edge).
	opt.fit_to_longest_item = false
	opt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	opt.custom_minimum_size.x = 140
	for text in items:
		opt.add_item(str(text))
	opt.select(clampi(selected_idx, 0, max(items.size() - 1, 0)))
	opt.item_selected.connect(on_pick)
	row.add_child(opt)
	parent.add_child(row)
	return opt

func _build_customizer(parent: VBoxContainer, allow_character: bool) -> void:
	parent.add_child(main._label("Customize Survivor", 20))
	if allow_character:
		_add_option_row(parent, "Survivor", NAMES, preferred, func(i: int):
			preferred = i
			_sync_my_look())
	var outfit_names := []
	var outfit_idx := 0
	for i in Figure.OUTFITS.size():
		outfit_names.append(Figure.OUTFITS[i][1])
		if Figure.OUTFITS[i][0] == custom_outfit:
			outfit_idx = i
	var opt_outfit := _add_option_row(parent, "Outfit", outfit_names, outfit_idx, func(i: int):
		custom_outfit = str(Figure.OUTFITS[i][0])
		_sync_my_look())
	var hair_names := []
	var hair_idx := 0
	for i in Figure.HAIRSTYLES.size():
		hair_names.append(Figure.HAIRSTYLES[i][1])
		if Figure.HAIRSTYLES[i][0] == custom_hair:
			hair_idx = i
	var opt_hair := _add_option_row(parent, "Hair", hair_names, hair_idx, func(i: int):
		custom_hair = str(Figure.HAIRSTYLES[i][0])
		_sync_my_look())
	var color_names := []
	for entry: Array in Figure.HAIR_COLORS:
		color_names.append(entry[0])
	var opt_color := _add_option_row(parent, "Hair Color", color_names, custom_hair_color, func(i: int):
		custom_hair_color = i
		_sync_my_look())
	var rand_btn := Button.new()
	rand_btn.text = "RANDOMIZE LOOK"
	rand_btn.add_theme_font_size_override("font_size", 16)
	rand_btn.pressed.connect(func():
		var oi := randi() % Figure.OUTFITS.size()
		var hi := randi() % Figure.HAIRSTYLES.size()
		var ci := randi() % Figure.HAIR_COLORS.size()
		custom_outfit = str(Figure.OUTFITS[oi][0])
		custom_hair = str(Figure.HAIRSTYLES[hi][0])
		custom_hair_color = ci
		opt_outfit.select(oi)
		opt_hair.select(hi)
		opt_color.select(ci)
		_sync_my_look())
	parent.add_child(rand_btn)

func _build_preview_panel(parent: HBoxContainer) -> void:
	_preview_pivot = null
	_preview_figure = null
	_preview_label = null
	if DisplayServer.get_name() == "headless":
		return
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(256, 360)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.custom_minimum_size = Vector2(248, 326)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.msaa_3d = Viewport.MSAA_2X
	vp.size = Vector2i(248, 326)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(vp)
	vbox.add_child(vpc)
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.085, 0.10)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.65)
	env.ambient_light_energy = 0.65
	world_env.environment = env
	vp.add_child(world_env)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.35
	key.rotation_degrees = Vector3(-32, 34, 0)
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_energy = 0.7
	rim.light_color = Color(0.75, 0.85, 1.0)
	rim.rotation_degrees = Vector3(-18, -145, 0)
	vp.add_child(rim)
	var cam := Camera3D.new()
	cam.fov = 36.0
	cam.position = Vector3(0.0, 1.00, 3.05)
	cam.look_at_from_position(cam.position, Vector3(0.0, 0.94, 0.0), Vector3.UP)
	vp.add_child(cam)
	_preview_pivot = Node3D.new()
	# Figure faces -Z by default, so rotate by PI + slight 3/4 angle to face the camera cleanly!
	_preview_pivot.rotation.y = PI + 0.28
	vp.add_child(_preview_pivot)
	_preview_label = main._label("", 15)
	_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_preview_label)
	parent.add_child(panel)
	_refresh_preview()

func _refresh_preview() -> void:
	if not is_instance_valid(_preview_pivot):
		return
	if is_instance_valid(_preview_figure):
		_preview_figure.queue_free()
		_preview_figure = null
	var slot_idx := preferred
	if peer != null and team.has(local_id()):
		slot_idx = int(team[local_id()].slot)
	var who: String = NAMES[clampi(slot_idx, 0, NAMES.size() - 1)]
	var fig := Figure.new()
	_preview_pivot.add_child(fig)
	fig.setup(Figure.asset_for(who, custom_outfit), Vector3.ZERO, "", false)
	fig.apply_hair(custom_hair, custom_hair_color, who)
	fig._drive_by_hand(false)
	fig.pose("idle")
	_preview_figure = fig
	if is_instance_valid(_preview_label):
		_preview_label.text = "%s • %s" % [who, _outfit_label(custom_outfit)]

func build_lobby() -> void:
	var box: VBoxContainer = main.menu_content
	box.add_child(main._label("Multiplayer",34))
	box.add_child(main._label("Mission 1   •   Olivar Family Mart",22))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	box.add_child(columns)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.custom_minimum_size = Vector2(360, 0)
	left.add_theme_constant_override("separation", 8)
	columns.add_child(left)
	_build_customizer(left, peer == null)
	if peer==null:
		var host_btn := Button.new()
		host_btn.text = "Host game"
		host_btn.add_theme_font_size_override("font_size", 21)
		host_btn.pressed.connect(host)
		left.add_child(host_btn)
		var edit := LineEdit.new()
		edit.placeholder_text = "Host IP address"
		edit.text = address
		edit.add_theme_font_size_override("font_size",20)
		edit.text_changed.connect(func(v): address=v.strip_edges())
		edit.text_submitted.connect(func(_v): join_game())
		left.add_child(edit)
		var join_btn := Button.new()
		join_btn.text = "Join game"
		join_btn.add_theme_font_size_override("font_size", 21)
		join_btn.pressed.connect(join_game)
		left.add_child(join_btn)
	else:
		roster_label = main._label("",19)
		left.add_child(roster_label)
		if multiplayer.is_server():
			var ips: Array = []
			for ip in IP.get_local_addresses():
				if ip.begins_with("192.168.") or ip.begins_with("10.") or (ip.begins_with("172.") and int(ip.get_slice(".",1)) in range(16,32)): ips.append(ip)
			left.add_child(main._label("Host address   "+", ".join(ips),17))
			var squad := HBoxContainer.new()
			squad.alignment = BoxContainer.ALIGNMENT_CENTER
			squad.add_theme_constant_override("separation",8)
			left.add_child(squad)
			for spec in [["Add AI",add_bot],["Fill AI",fill_bots],["Remove AI",remove_bot]]:
				var b := Button.new()
				b.text = spec[0]
				b.add_theme_font_size_override("font_size",17)
				b.pressed.connect(spec[1])
				squad.add_child(b)
			start_button = Button.new()
			start_button.text = "Start mission"
			start_button.add_theme_font_size_override("font_size", 21)
			start_button.pressed.connect(start_game)
			left.add_child(start_button)
		draw_roster()
	_build_preview_panel(columns)
	feedback = main._label(status,17)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(feedback)
	main._button("Leave lobby" if peer!=null else "Back",leave_lobby)

func draw_roster() -> void:
	if ui != null and ui.visible: ui.refresh_room()
	if peer != null and multiplayer.is_server(): _publish_game()
	if not is_instance_valid(roster_label): return
	var rows := PackedStringArray()
	for id: int in team:
		var p: Dictionary = team[id]
		var tag := "   •   Host" if id==1 else ("   •   AI" if is_bot(id) else "")
		var look_txt := ""
		var out_k := str(p.get("outfit", "default"))
		var hair_k := str(p.get("hair", "default"))
		if out_k != "default" or hair_k != "default":
			look_txt = "   [%s, %s]" % [_outfit_label(out_k), _hair_label(hair_k)]
		rows.append(NAMES[p.slot] + tag + look_txt)
	roster_label.text = "Team   %d / 5\n"%team.size()+"\n".join(rows)

func note(message: String) -> void:
	status = message
	if is_instance_valid(feedback): feedback.text = message
	if ui != null and ui.visible: ui.note(message)

## 0.55: the UDP port `host` opens (tests move it off PORT so they run beside a game that is hosting: set it, or the
## SLEEP_COOP_PORT environment variable).
var host_port := int(OS.get_environment("SLEEP_COOP_PORT")) if OS.get_environment("SLEEP_COOP_PORT").is_valid_int() else PORT

func host() -> void:
	var transport := ENetMultiplayerPeer.new()
	if transport.create_server(host_port,4,6)!=OK:
		note("Couldn’t host on UDP port %d. Another game may be using it." % host_port)
		return
	peer = transport
	multiplayer.multiplayer_peer = peer
	if main.mobile: mode = "easy"
	register_member(1,preferred,current_look(),lobby.player_name if lobby!=null else "")
	note("Your game is open. Friends on your network can also join by address.")
	page()

func join_game() -> void:
	if address.is_empty():
		note("Enter the host’s IP address first.")
		return
	var transport := ENetMultiplayerPeer.new()
	if transport.create_client(address,PORT,6)!=OK:
		note("Couldn’t open that address.")
		return
	peer = transport
	multiplayer.multiplayer_peer = peer
	deadline = Time.get_ticks_msec()+12000
	note("Connecting…")
	page()

func _connected() -> void:
	deadline = 0
	enroll.rpc_id(1,preferred,current_look(),lobby.player_name if lobby!=null else "")
	note("You’re in. Ready up when you’re set; the host starts the mission.")
	_publish_game()

func _new_peer(id: int) -> void:
	if peer!=null and multiplayer.is_server() and active: peer.disconnect_peer(id)

func _lost_peer(id: int) -> void:
	if peer==null or not multiplayer.is_server(): return
	network_ready.erase(id)
	if active and mission!=null and mission.stage>=Mission.OVER: return
	if team.has(id) and not active: party_line.rpc("", "%s left the squad." % display_name(id))
	team.erase(id)
	if not active: roster.rpc(team)
	draw_roster()

func _failed(message: String) -> void:
	if active:
		show_host_left = true
		if mission.stage<Mission.OVER:
			mission.stage = Mission.FAILED
			mission.text_line = message
		if not last_results: results()
	else:
		end_session()
		note(message)
		page()

func end_session() -> void:
	_close_chat()
	if peer != null and multiplayer.is_server(): _upnp_close()
	if relay != null: relay.close()
	public_endpoint = {}
	var old := peer
	peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if old!=null: old.close()
	team.clear()
	network_ready.clear()
	deadline = 0
	active = false
	_publish_game()

func leave_lobby() -> void:
	end_session()
	status = ""
	main._show_menu("home")

func _apply_member_look(id: int, look: Dictionary) -> void:
	if not team.has(id): return
	team[id]["outfit"] = Figure.valid_outfit(str(look.get("outfit", "default")))
	team[id]["hair"] = Figure.valid_hair(str(look.get("hair", "default")))
	team[id]["hair_color"] = clampi(int(look.get("hair_color", 0)), 0, Figure.HAIR_COLORS.size() - 1)

func register_member(id: int, wanted: int, look := {}, player_name := "") -> void:
	var used := []
	for p: Dictionary in team.values(): used.append(p.slot)
	var slot := clampi(wanted,0,4)
	if slot in used:
		for i in 5:
			if i not in used:
				slot = i
				break
	var start: Vector3 = main.player.position+Vector3([0,.55,-.55,.55,-.55][slot],0,[0,0,0,.55,.55][slot])
	team[id] = {"slot":slot,"pos":start,"yaw":0.0,"pitch":0.0,"light":false,"hp":Mission.MAX_HP,"kits":1,"rifle":false,
		"kills":0,"hurt":0,"shots":0,"hits":0,"revives":0,"shot_at":0,"clip":"idle","bot":id<0,"drag":-1,"pdrag":-1,
		"outfit":Figure.valid_outfit(str(look.get("outfit","default"))),
		"hair":Figure.valid_hair(str(look.get("hair","default"))),
		"hair_color":clampi(int(look.get("hair_color",0)),0,Figure.HAIR_COLORS.size()-1),
		"name":LobbyNet.clean_name(player_name),"ready":id==1 or id<0}

func is_bot(id: int) -> bool: return id<0

func humans() -> int:
	var n := 0
	for id: int in team:
		if not is_bot(id): n += 1
	return n

## 0.40: a squad AI member in the first free place, before or during the mission (host only).
func add_bot() -> bool:
	if peer==null or not multiplayer.is_server():
		note("Host a game first: the squad AI joins the host's team.")
		return false
	if team.size()>=5:
		note("The squad is full (five).")
		return false
	var id := -1
	while team.has(id): id -= 1
	register_member(id,team.size())
	if active:
		var lead: Dictionary = team[1]
		var forward := Vector3(-sin(float(lead.yaw)),0,-cos(float(lead.yaw)))
		var at: Vector3 = mission.ground(lead.pos-forward*1.8)
		team[id].pos = at if at.is_finite() else lead.pos
		bots.add(id,team[id].pos)
		team[id].kits = int(MODES[mode].kits)
		team[id].heal_t = -1.0
		team[id].held = false
		_bot_loadout(id)
		voices.warm([NAMES[team[id].slot]])
		speak_all(id,"lets_go")
	else:
		roster.rpc(team)
		draw_roster()
	return true

func fill_bots() -> void:
	while team.size()<5 and add_bot(): pass

func remove_bot() -> void:
	var ids: Array = team.keys().filter(func(i): return is_bot(i))
	if ids.is_empty(): return
	ids.sort()
	var id: int = ids[0]
	team.erase(id)
	if bots!=null: bots.remove(id)
	if not active:
		roster.rpc(team)
		draw_roster()

@rpc("any_peer","reliable")
func enroll(wanted: int, look := {}, player_name := "") -> void:
	if not multiplayer.is_server() or active: return
	var id := multiplayer.get_remote_sender_id()
	if team.has(id): return
	# A full squad makes room for a player by sending one of the squad AI home.
	if team.size()>=5:
		var ai: Array = team.keys().filter(func(i): return is_bot(i))
		if ai.is_empty():
			peer.disconnect_peer(id)
			return
		team.erase(ai[0])
	for entry: Array in party_log.slice(maxi(0, party_log.size() - 30)): party_history.rpc_id(id, entry[0], entry[1])
	register_member(id,wanted,look,player_name)
	mode_changed.rpc_id(id,mode)
	roster.rpc(team)
	draw_roster()
	party_line.rpc("", "%s joined the squad." % display_name(id))

@rpc("any_peer","reliable")
func update_look(look: Dictionary) -> void:
	if not multiplayer.is_server() or active: return
	var id := multiplayer.get_remote_sender_id()
	if not team.has(id): return
	_apply_member_look(id, look)
	roster.rpc(team)
	draw_roster()

@rpc("authority","reliable")
func roster(value: Dictionary) -> void:
	team = value
	draw_roster()
	_refresh_preview()

func start_game() -> void:
	if peer==null or not multiplayer.is_server() or active: return
	if multiplayer.get_peers().size()+1 != humans():
		note("Waiting for a teammate to finish connecting.")
		return
	peer.refuse_new_connections = true
	_publish_game.call_deferred()
	begin.rpc(team,randi()%1000000,mode)

@rpc("authority","call_local","reliable")
func begin(members: Dictionary, seed_value := 5849, game_mode := "normal") -> void:
	if active: return
	run_seed = seed_value
	mode = game_mode if MODES.has(game_mode) else "normal"
	team = members.duplicate(true)
	for id: int in team:
		team[id].kits = int(MODES[mode].kits)
		team[id].heal_t = -1.0
		team[id].held = false
		team[id].rifle = int(MODES[mode].rifle)>0
	active = true
	var stranger: Node = main.get_node_or_null("Stranger")
	if stranger!=null:
		main.remove_child(stranger)
		stranger.queue_free()
	# 0.64 (owner): the squad game never goes to the rice fields or the Nichols property. Their ways out of the town
	# are shut for everyone (phones and PCs play together), and a phone lets go of both places.
	InteriorMapSeals.seal_for_squad(main.get_node_or_null("Balcony/Neighbourhood") as Node3D)
	# 0.66 (owner: the game focuses on the mission now; Single Player is off): PCs let go of them too.
	drop_far_places()
	main.body.process_mode = Node.PROCESS_MODE_DISABLED
	main.zombies.process_mode = Node.PROCESS_MODE_DISABLED
	main.story.set_process(false)
	main.story.set_process_unhandled_input(false)
	main.story.inventory_label.hide()
	main.story.ui.hide()
	if main.player.console_requested.is_connected(main._show_console):
		main.player.console_requested.disconnect(main._show_console)
	main.status_label.hide()
	main.clue_label.hide()
	var debug: Node = main.get_node_or_null("DebugMenu")
	# 0.40: the host keeps Q W E R T Y (its co-op section: squad AI, infected, the mission); the others do not.
	if debug!=null and not multiplayer.is_server(): debug.process_mode = Node.PROCESS_MODE_DISABLED
	# The solo infected stand still, but the blood they share with the co-op ones keeps running.
	main.zombies.blood.process_mode = Node.PROCESS_MODE_PAUSABLE
	_loadout()
	main.story.flashlight.give()
	main.story.gun.fired.connect(_fired)
	main.player.hold_hook = use_nearby
	main.player.release_hook = _released
	main.player.prop_push_hook = _prop_push
	for d in get_tree().get_nodes_in_group("interior_doors")+get_tree().get_nodes_in_group("warren_doors"):
		if d is InteriorHingedDoor: doors[str(main.get_path_to(d))] = d
		elif d.has_method("snap_open"): d.snap_open()
	mission = Mission.new()
	add_child(mission)
	mission.setup(self)
	voices = Voices.new()
	add_child(voices)
	voices.setup(self)
	if multiplayer.is_server():
		bots = Bots.new()
		mission.add_child(bots)
		bots.setup(self)
		for id: int in team:
			if is_bot(id):
				bots.add(id,team[id].pos)
				_bot_loadout(id)
	var names := []
	for id: int in team: names.append(NAMES[team[id].slot])
	voices.warm(names)
	main.player.reset_motion(team[multiplayer.get_unique_id()].pos)
	main._play()
	if MODES[mode].rifle>0: main.story.gun.select("rifle")
	else: main.story.gun.draw()
	build_hud()
	voices.build_hud(main.hud)
	_build_chat_hud()
	hide_lobby_ui()
	_publish_game()
	if multiplayer.is_server(): network_ready[1] = true
	else: ready_for_state.rpc_id(1)

@rpc("any_peer","reliable")
func ready_for_state() -> void:
	if multiplayer.is_server() and active and team.has(multiplayer.get_remote_sender_id()):
		network_ready[multiplayer.get_remote_sender_id()] = true

## 0.46: what each survivor starts with, by the host's game mode (rounds counted with the loaded magazine).
func _loadout() -> void:
	var gun: InteriorGun = main.story.gun
	var spec: Dictionary = MODES[mode]
	gun.give()
	gun.debug_fill()
	gun.add_rounds(maxi(0,int(spec.pistol)-gun.loaded()))
	if int(spec.rifle)>0:
		gun.give_long("rifle",maxi(0,int(spec.rifle)-InteriorGun.RIFLE_MAG_SIZE))
	if main.grenades!=null:
		main.grenades.give(int(spec.grenades)-int(main.grenades.count))
	_kits_hud()

## 0.46: the squad AI start with what the players do.
func _bot_loadout(id: int) -> void:
	var b = bots.bots.get(id)
	if b==null: return
	var spec: Dictionary = MODES[mode]
	if int(spec.rifle)>0:
		bots.reward(id,"rifle")
		b.reserve = int(spec.rifle)-b.mag
	else:
		b.mag = 17
		b.reserve = maxi(0,int(spec.pistol)-17)

## 0.46: the host picks the game mode in the room; everyone sees it.
func set_mode(which: String) -> void:
	if not MODES.has(which) or peer==null or not multiplayer.is_server() or active: return
	mode = which
	mode_changed.rpc(which)

@rpc("authority","call_local","reliable")
func mode_changed(which: String) -> void:
	if MODES.has(which): mode = which
	if ui!=null and ui.has_method("refresh_room"): ui.refresh_room()

## 0.46 (host): a weapon off the ground into `id`'s hands, with the rounds it was dropped with.
func give_weapon(id: int, which: String, ammo: Array) -> void:
	if is_bot(id) or not team.has(id): return
	if InteriorArsenal.class_of(which)=="rifle": team[id].rifle = true
	if id==1: take_weapon(which,ammo)
	else: take_weapon.rpc_id(id,which,ammo)

@rpc("authority","reliable")
func take_weapon(which: String, ammo: Array) -> void:
	if ammo.size()<3: return
	var swapped: Dictionary = main.story.gun.take_weapon(which,int(ammo[0]),bool(ammo[1]),int(ammo[2]))
	# 0.48: one of each kind: the one it replaces goes on the ground.
	if not swapped.is_empty():
		var kept := [int(swapped.mag),bool(swapped.chambered),int(swapped.reserve)]
		if multiplayer.is_server(): _put_down(1,str(swapped.which),kept)
		else: put_down.rpc_id(1,str(swapped.which),kept)

@rpc("any_peer","reliable")
func put_down(which: String, ammo: Array) -> void:
	if not multiplayer.is_server() or not active: return
	var id := multiplayer.get_remote_sender_id()
	_put_down(id,which,ammo)

func _put_down(id: int, which: String, ammo: Array) -> void:
	if not team.has(id) or int(team[id].hp)<=0 or mission.stage>=Mission.OVER: return
	if InteriorArsenal.class_of(which)=="rifle": team[id].rifle = false
	mission.put_down(id,which,ammo)

## 0.46: G held: the weapon in the hands goes on the ground in front, with its magazine and spare rounds.
func _drop_weapon() -> void:
	var gun: InteriorGun = main.story.gun
	if not team.has(local_id()) or int(team[local_id()].hp)<=0: return
	var out: Dictionary = gun.drop_current()
	if out.is_empty(): return
	var ammo := [int(out.mag),bool(out.chambered),int(out.reserve)]
	if multiplayer.is_server(): _put_down(1,str(out.which),ammo)
	else: put_down.rpc_id(1,str(out.which),ammo)
	if main.story!=null and main.story.has_method("notify"): main.story.notify("Dropped the %s"%InteriorArsenal.display_name(str(out.which)))

## The healthkit count beside the ammunition (shown with the weapon, like the grenades).
func _kits_hud() -> void:
	if not team.has(local_id()): return
	var gun: InteriorGun = main.story.gun
	var kits := int(team[local_id()].get("kits",0))
	var text := "   %d kit%s" % [kits,"" if kits==1 else "s"] if kits>0 else ""
	if gun.extra_hud!=text:
		gun.extra_hud = text
		gun._update_hud()

func build_hud() -> void:
	hint = main._label("",16)
	hint.position = Vector2(24,19)
	hint.size = Vector2(960,135)
	hint.add_theme_constant_override("outline_size",5)
	hint.add_theme_font_override("font",SleepType.text(500))
	hint.add_theme_font_size_override("font_size",15)
	hint.add_theme_color_override("font_color",Color(SleepType.BONE,.9))
	main.hud.add_child(hint)
	# 0.54: the lines are subtitles: no box, a soft band of dark behind them that fades out to both sides; the
	# speaker's name over the line in street-sign capitals.
	dialogue_panel = PanelContainer.new()
	main.hud.add_child(dialogue_panel)
	dialogue_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	dialogue_panel.offset_left = -460
	dialogue_panel.offset_right = 460
	dialogue_panel.offset_top = -205
	dialogue_panel.offset_bottom = -99
	dialogue_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var band := StyleBoxTexture.new()
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0,.22,.78,1.0])
	fade.colors = PackedColorArray([Color(0,0,0,0),Color(0,0,0,.58),Color(0,0,0,.58),Color(0,0,0,0)])
	var strip := GradientTexture2D.new()
	strip.gradient = fade
	strip.width = 256
	strip.height = 4
	band.texture = strip
	band.content_margin_left = 150
	band.content_margin_right = 150
	band.content_margin_top = 12
	band.content_margin_bottom = 14
	dialogue_panel.add_theme_stylebox_override("panel",band)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation",3)
	lines.alignment = BoxContainer.ALIGNMENT_END
	dialogue_panel.add_child(lines)
	dialogue_name = SleepType.kicker("",14,SleepType.SODIUM,3)
	dialogue_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(dialogue_name)
	dialogue = main._label("",20)
	dialogue.add_theme_font_override("font",SleepType.text(500))
	dialogue.add_theme_font_size_override("font_size",21)
	dialogue.add_theme_color_override("font_color",SleepType.BONE)
	dialogue.add_theme_color_override("font_outline_color",Color(0,0,0,.6))
	dialogue.add_theme_constant_override("outline_size",3)
	dialogue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lines.add_child(dialogue)
	dialogue_panel.hide()
	story_panel = PanelContainer.new()
	main.hud.add_child(story_panel)
	story_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	story_panel.offset_left = -400
	story_panel.offset_right = 400
	story_panel.offset_top = 86
	# 0.54: the story's page: the panel cut from the dark, the heading in street capitals, the words in the
	# story's serif (italic, like something read aloud), the page count in the record's mono.
	var frame := SleepType.panel(34,22,2)
	story_panel.add_theme_stylebox_override("panel",frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	story_panel.add_child(column)
	var heading: Label = SleepType.kicker(Mission.STORY_TITLE,15,SleepType.SODIUM,4)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	var rule := ColorRect.new()
	rule.color = Color(SleepType.RUST,.7)
	rule.custom_minimum_size = Vector2(0,1)
	column.add_child(rule)
	story_body = main._label("",19)
	story_body.add_theme_font_override("font",SleepType.serif(true))
	story_body.add_theme_font_size_override("font_size",24)
	story_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_body.custom_minimum_size = Vector2(740,0)
	story_body.add_theme_color_override("font_color",SleepType.BONE)
	column.add_child(story_body)
	story_foot = main._label("",13)
	story_foot.add_theme_font_override("font",SleepType.mono(1))
	story_foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	story_foot.add_theme_color_override("font_color",Color(SleepType.BONE,.5))
	column.add_child(story_foot)
	story_panel.hide()
	hint_label = main._label("",15)
	main.hud.add_child(hint_label)
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.offset_left = -430
	hint_label.offset_right = 430
	hint_label.offset_top = -40
	hint_label.offset_bottom = -14
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_color_override("font_color",Color(.86,.85,.8))
	hint_label.add_theme_color_override("font_outline_color",Color(0,0,0,.85))
	hint_label.add_theme_constant_override("outline_size",4)
	hint_label.modulate.a = 0.0
	hint_queue = ["light","quiet","shots","head","heal","bodies"]
	for id: int in team:
		if is_bot(id):
			hint_queue.insert(3,"squad")
			break

func local_id() -> int: return multiplayer.get_unique_id()

func _physics_process(delta: float) -> void:
	if not active or show_host_left or last_results: return
	var id := local_id()
	if not team.has(id): return
	tick += delta
	if tick>=POSE_RATE:
		var player: InteriorPlayer = main.player
		var moving := Vector2(player.velocity.x,player.velocity.z).length()
		# 0.43: down, the player crawls (scripts/player.gd `downed`): the others see the crawl, or lying still.
		var clip := ("crawl" if moving>.12 else "down_idle") if team[id].hp==0 else ("walk_hurt" if moving>.2 and team[id].hp<=Mission.CRITICAL_HP else ("run" if moving>3 else ("walk" if moving>.2 else "idle")))
		# 0.51: crouched (the school's duct): the others see them low, not standing through its roof.
		if team[id].hp>0 and player.crouching:
			var duct: bool = mission.school!=null and mission.school.in_duct(player.global_position)
			clip = ("crawl" if moving>.12 else "down_idle") if duct else "crouch_walk"
		if multiplayer.is_server(): record_pose(id,player.position,player.rotation.y,player.camera.rotation.x,main.story.flashlight.on,clip)
		else: send_pose.rpc_id(1,player.position,player.rotation.y,player.camera.rotation.x,main.story.flashlight.on,clip)
		tick = 0
		if not _pushes.is_empty():
			var data := PackedFloat32Array()
			for i: int in _pushes:
				var push: Array = _pushes[i]
				data.append_array([float(i),push[0].x,push[0].y,push[0].z,push[1].x,push[1].y,push[1].z,float(push[2])])
			_pushes.clear()
			if not multiplayer.is_server(): push_props.rpc_id(1,data)
	var t0 := Time.get_ticks_usec()
	if multiplayer.is_server() and network_ready.size()>=humans():
		if bots!=null: bots.tick(delta)
		var t1 := Time.get_ticks_usec()
		mission.tick(delta)
		if mission.school!=null:
			for member: int in team: team[member].pdrag = mission.school.props.dragging(member)
		var t2 := Time.get_ticks_usec()
		world_tick += delta
		if world_tick>=STATE_RATE:
			world_tick = 0
			if network_ready.size()>1: send_state()
		if timing: _time_add([t1-t0,t2-t1,Time.get_ticks_usec()-t2])
	var t3 := Time.get_ticks_usec()
	update_avatars()
	if timing: _time_add([0,0,0,Time.get_ticks_usec()-t3])

## `-- --coop-timing`: where the host's tick goes (µs per tick: AI, infected, state out, figures), every 2 s.
var timing := "--coop-timing" in OS.get_cmdline_user_args()
var _timing := [0,0,0,0,0]
func _time_add(parts: Array) -> void:
	for i in parts.size(): _timing[i] += parts[i]
	if parts.size()==3: _timing[4] += 1
	if _timing[4]>=120:
		print("INTERIOR_COOP_TIMING ai %d  infected %d  state %d  figures %d  (µs per tick, %d infected)"%[_timing[0]/_timing[4],_timing[1]/_timing[4],_timing[2]/_timing[4],_timing[3]/_timing[4],mission.enemies.size()])
		_timing = [0,0,0,0,0]

func record_pose(id: int, pos: Vector3, yaw: float, pitch: float, lit: bool, clip: String) -> void:
	if not team.has(id) or not pos.is_finite() or not is_finite(yaw) or not is_finite(pitch): return
	var p: Dictionary = team[id]
	if mission.stage>=Mission.OVER: return
	if pos.distance_to(p.pos)>(1.5 if p.hp<=0 else 10.0): return
	p.pos = pos
	p.yaw = yaw
	p.pitch = clampf(pitch,-1.55,1.55)
	p.light = lit
	p.clip = clip if clip in ["idle","walk","walk_hurt","run","knockdown","crawl","down_idle","crouch_walk"] else "idle"
	if p.hp<=0 and not p.clip in ["crawl","down_idle"]: p.clip = "down_idle"

@rpc("any_peer","call_remote","unreliable_ordered",1)
func send_pose(pos: Vector3,yaw: float,pitch: float,lit: bool,clip: String) -> void:
	if multiplayer.is_server() and active: record_pose(multiplayer.get_remote_sender_id(),pos,yaw,pitch,lit,clip)

func send_state(final_state := false) -> void:
	var zombies := {}
	for k in mission.enemies:
		var z = mission.enemies[k]
		zombies[k] = [z.get_meta("kind"),z.position,z.rotation.y,z.anim_name]
	var state := [mission.stage,mission.guide_hp,mission.guide.position,mission.guide.rotation.y,mission.guide.anim_name,mission.guide.scale.y,mission.flags,mission.drops,mission.threat,mission.text_line,mission.wave_left,mission.wave_total,mission.street.props_state(),
		[mission.jonna.position,mission.jonna.rotation.y,mission.jonna.anim_name,mission.jonna.visible],
		mission.escape.state() if mission.escape!=null else [],
		mission.school.props.state() if mission.school!=null else PackedFloat32Array()]
	var packet := var_to_bytes([team,state,zombies,Engine.get_physics_frames()]).compress(FileAccess.COMPRESSION_GZIP)
	for id in network_ready:
		if id==1 or not multiplayer.get_peers().has(id): continue
		if peer.get_peer(id).get_state()!=ENetPacketPeer.STATE_CONNECTED: continue
		if final_state or packet.size()>6000: full_snapshot.rpc_id(id,packet)
		else: snapshot.rpc_id(id,packet)

@rpc("authority","call_remote","unreliable_ordered",2)
func snapshot(packet: PackedByteArray) -> void:
	apply_snapshot(packet)

@rpc("authority","reliable")
func full_snapshot(packet: PackedByteArray) -> void:
	apply_snapshot(packet)

const NEW_PER_SNAPSHOT := 4
func apply_snapshot(packet: PackedByteArray) -> void:
	if not active: return
	var data: Array = bytes_to_var(packet.decompress_dynamic(262144,FileAccess.COMPRESSION_GZIP))
	if data[3]<=last_state_tick: return
	last_state_tick = data[3]
	var members: Dictionary = data[0]
	var state: Array = data[1]
	var zombies: Dictionary = data[2]
	team = members
	mission.stage = state[0]
	mission.guide_hp = state[1]
	mission.guide.replicated = true
	mission.guide.follow(state[2],state[3])
	mission.guide.pose(state[4])
	mission.guide.scale.y = state[5]
	mission.flags = state[6]
	mission.drops = state[7]
	mission.threat = state[8]
	mission.text_line = state[9]
	mission.wave_left = state[10]
	mission.wave_total = state[11]
	if state.size()>12: mission.street.apply_props(state[12])
	if state.size()>13:
		var j: Array = state[13]
		mission.jonna.replicated = true
		mission.jonna.follow(j[0],j[1])
		mission.jonna.pose(j[2])
		mission.jonna.visible = j[3]
	# 0.52: Ma'am Teves and her students (the school builds on this peer when the backstreets wake).
	if state.size()>14 and mission.escape!=null: mission.escape.apply(state[14])
	# 0.57: the school's chairs and doors where the host has them (school_props.gd).
	if state.size()>15 and mission.school!=null: mission.school.props.apply(state[15])
	for k in mission.enemies.keys():
		if not zombies.has(k):
			mission.enemies[k].queue_free()
			mission.enemies.erase(k)
	# 0.66: at most NEW_PER_SNAPSHOT new figures a snapshot (a whole floor's sleepers arriving at once was one long
	# frame here too); the rest come with the next ones, 50 ms apart.
	var made := 0
	for k in zombies:
		var v: Array = zombies[k]
		var z = mission.enemies.get(k)
		if z==null:
			if made>=NEW_PER_SNAPSHOT: continue
			made += 1
			z = mission.make_enemy(k,v[0],v[1])
			z.reset_physics_interpolation()
		z.replicated = true
		z.follow(v[1],v[2])
		z.pose(v[3])

func update_avatars() -> void:
	for id in avatars.keys():
		if not team.has(id):
			avatars[id].queue_free()
			avatars.erase(id)
	for id: int in team:
		if id==local_id(): continue
		var p: Dictionary = team[id]
		if not avatars.has(id):
			var a := Figure.new()
			add_child(a)
			var who: String = NAMES[p.slot]
			a.setup(Figure.asset_for(who, str(p.get("outfit", "default"))), p.pos, who)
			a.apply_hair(str(p.get("hair", "default")), int(p.get("hair_color", 0)), who)
			a.replicated = true
			avatars[id] = a
		var a = avatars[id]
		if is_bot(id) and multiplayer.is_server():
			# The host moves it: drawn where it is, blended between physics ticks by the engine.
			a.replicated = false
			a.global_position = p.pos
			a.rotation.y = lerp_angle(a.rotation.y,float(p.yaw),.35)
		elif a.goal!=p.pos or a.goal_yaw!=float(p.yaw):
			a.follow(p.pos,p.yaw)
		a.flashlight(p.light,p.pitch)
		a.carry(p.rifle)
		# 0.53: always shown, however far, and how far (a fixed size on the screen, seen through walls).
		var metres := int(round(main.player.global_position.distance_to(a.global_position))) if main.get("player")!=null else 0
		var text: String = display_name(id)+"   "+("Down" if p.hp==0 else "%d HP"%p.hp)+"   %d m"%metres
		if a.caption!=null and not a.has_meta("far_tag"):
			a.set_meta("far_tag",true)
			a.caption.visibility_range_end = 0.0
			a.caption.fixed_size = true
			a.caption.pixel_size = .0011
			a.caption.font_size = 30
			a.caption.outline_size = 7
			a.caption.no_depth_test = true
			a.caption.render_priority = 2
			a.caption.position.y = 2.15
			a.caption.modulate = TAG_COLOUR
		# 0.58: down, the tag gives way to the downed marker (scripts/world_markers.gd), seen at any distance and
		# pinned to the screen's edge when they are out of view; in the red, the tag turns red and beats.
		var down: bool = int(p.hp)<=0
		if down:
			text = ""
			var marks: Node = Markers.of(main)
			if marks!=null: marks.mark("down:%d"%id,a.global_position+Vector3.UP*.75,"down",{"name":display_name(id),"metres":metres})
		if _avatar_text.get(id,"")!=text:
			_avatar_text[id] = text
			a.caption.text = text
		if int(p.hp)>0 and int(p.hp)<=Mission.CRITICAL_HP:
			var t := fmod(Time.get_ticks_msec()/1000.0*1.15,1.0)
			var beat := maxf(exp(-pow((t-.08)/.06,2.0)),.7*exp(-pow((t-.32)/.06,2.0)))
			a.caption.modulate = TAG_CRITICAL.lerp(Color(1.0,.62,.55,1.0),beat*.55)
			a.caption.outline_modulate = Color(.18,0,0,.9)
		elif a.caption.modulate!=TAG_COLOUR:
			a.caption.modulate = TAG_COLOUR
			a.caption.outline_modulate = Color(0,0,0,1)
		if a.get_meta("shots",p.shots)!=p.shots: a.fire_flash(p.rifle)
		a.set_meta("shots",p.shots)
		# 0.43: going down plays the fall first, then they lie there or crawl.
		if p.hp<=0:
			if not a.has_meta("down_at"): a.set_meta("down_at",Time.get_ticks_msec())
			a.pose("knockdown" if Time.get_ticks_msec()-int(a.get_meta("down_at"))<1300 else (p.clip if p.clip in ["crawl","down_idle"] else "down_idle"))
		else:
			if a.has_meta("down_at"): a.remove_meta("down_at")
			a.pose(p.clip)

## 0.40: the local gun's rounds land on the infected's own hit boxes (figure.gd `shot`, `report_hit`); the shot
## itself is only counted here (everyone hears it, the results count it).
func _fired() -> void:
	if multiplayer.is_server(): mission.fired(1)
	else: fire.rpc_id(1)

@rpc("any_peer","reliable")
func fire() -> void:
	if multiplayer.is_server() and active: mission.fired(multiplayer.get_remote_sender_id())

## A round from this peer's gun struck infected `key` on `bone`.
func report_hit(key: int, bone: String, point: Vector3, dir: Vector3, dealt: float, knock: float, tear := -1.0) -> void:
	if not active or mission==null: return
	if multiplayer.is_server(): mission.damage(1,key,bone,point,dir,dealt,knock,tear)
	else: hit_report.rpc_id(1,key,bone,point,dir,dealt,knock,tear)

## 0.41: a round into one of the dead: the host counts what each part has taken (`tear`) and says what comes off.
func report_corpse_hit(key: int, bone: String, point: Vector3, dir: Vector3, knock: float, tear: float) -> void:
	if not active or mission==null: return
	if multiplayer.is_server(): mission.tear(mission.figure_of(key),bone,dir,knock,tear)
	else: corpse_hit_report.rpc_id(1,key,bone,point,dir,knock,tear)

@rpc("any_peer","call_remote","reliable",3)
func corpse_hit_report(key: int, bone: String, point: Vector3, dir: Vector3, knock: float, tear: float) -> void:
	if not multiplayer.is_server() or not active: return
	var f = mission.figure_of(key)
	if f==null or not dir.is_finite() or not point.is_finite() or point.distance_to(f.where())>4.0: return
	if not InteriorZombie.BODIES.has(bone): return
	mission.tear(f,bone,dir.normalized(),clampf(knock,0.0,400.0),clampf(tear,0.0,300.0))

## 0.41: the host's word that a part comes off one of them (or a piece is torn out of it), everywhere.
@rpc("authority","call_local","reliable")
func cut_all(key: int, bone: String, way: Vector3, knock: float, burst: bool, chunk_only: bool) -> void:
	if not active or mission==null: return
	var f = mission.figure_of(key)
	if f!=null: f.cut(bone,way,knock,burst,chunk_only)

@rpc("any_peer","call_remote","reliable",3)
func hit_report(key: int, bone: String, point: Vector3, dir: Vector3, dealt: float, knock: float, tear := -1.0) -> void:
	if not multiplayer.is_server() or not active: return
	var id := multiplayer.get_remote_sender_id()
	var z = mission.enemies.get(key)
	if z==null or not team.has(id) or team[id].hp<=0: return
	if not point.is_finite() or not dir.is_finite() or point.distance_to(z.global_position)>4.5: return
	if not InteriorZombie.BODIES.has(bone): return
	mission.damage(id,key,bone,point,dir,clampf(dealt,0.0,700.0),clampf(knock,0.0,400.0),clampf(tear,-1.0,300.0))

## Everyone but the one who fired sees the hit: the blood and the jerk.
@rpc("authority","call_local","unreliable_ordered",3)
func struck(key: int, bone: String, point: Vector3, dir: Vector3, dealt: float, knock: float, shooter: int) -> void:
	if not active or shooter==local_id(): return
	var z = mission.enemies.get(key)
	if z==null or z.dead: return
	var body: Node3D = z.bodies.get(bone)
	z.bleed(body,point,dir,dealt,bone=="head")
	z.flinch(dir,knock,bone)

func blood():
	return main.zombies.blood if main.get("zombies")!=null and main.zombies!=null else null

func use_nearby() -> bool:
	if not active or mission.stage>=Mission.OVER: return true
	var action: String = mission.candidate(local_id())
	if action=="":
		main.player.update_target()
		var d = main.player.door_target
		if d!=null and d is InteriorHingedDoor and doors.has(str(main.get_path_to(d))): action = "hinge/"+str(main.get_path_to(d))
	# 0.57: a school chair or classroom door under the view (school_props.gd): hold E drags it, a tap shuts a door.
	if action=="" and mission.school!=null:
		var aimed: Array = mission.school.props.aimed(main.player)
		if not aimed.is_empty():
			var grip: Vector3 = aimed[1]
			action = "prop/%d/%.3f,%.3f,%.3f"%[int(aimed[0]),grip.x,grip.y,grip.z]
			_prop_held = true
	if action=="":
		# Loose solo clues and inspection screens do not own co-op interactions.
		return true
	if multiplayer.is_server(): handle(1,action)
	else: use.rpc_id(1,action)
	return true

@rpc("any_peer","reliable")
func use(action: String) -> void:
	if multiplayer.is_server() and active: handle(multiplayer.get_remote_sender_id(),action)

func handle(id: int,action: String) -> void:
	# 0.49: READY on the chapter board (down or not).
	if action=="next_ready":
		if team.has(id) and mission.flags.get("board",false): team[id].next_ready = true
		return
	if not team.has(id) or team[id].hp<=0 or mission.stage>=Mission.OVER: return
	if action=="heal": mission.start_heal(id,id)
	elif action=="heal_stop": mission.stop_heal(id)
	elif action=="letgo":
		mission.release(id)
		if mission.school!=null:
			mission.school.props.release(id)
			team[id].pdrag = -1
	elif action.begins_with("prop/"):
		var parts := action.split("/")
		var xyz := parts[2].split(",") if parts.size()>2 else PackedStringArray()
		if mission.school!=null and xyz.size()==3 and not mission.draggers.has(id):
			var i := int(parts[1])
			if mission.school.props.grab(id,i,Vector3(float(xyz[0]),float(xyz[1]),float(xyz[2])),team[id].pos): team[id].pdrag = i
	elif action=="shove": mission.shove(id)
	elif action.begins_with("hinge/"):
		var path := action.trim_prefix("hinge/")
		var d = doors.get(path)
		if d!=null and d.global_position.distance_to(team[id].pos)<4.5: switch_door.rpc(path,not d.is_open())
	else: mission.interact(id,action)

@rpc("authority","call_local","reliable")
func switch_door(path: String,opened: bool) -> void:
	var d = doors.get(path)
	if d!=null and d.is_open()!=opened: d.toggle()

## 0.40: dead, everywhere at once: the body falls as a ragdoll, pushed the way the rounds went.
@rpc("authority","call_local","reliable")
func fallen(id: int, at: Vector3, kind: int, yaw: float, push := Vector3.ZERO, bone := "chest") -> void:
	if not active: return
	var corpse = mission.enemies.get(id)
	if corpse==null:
		corpse = mission.make_enemy(id,kind,at)
		corpse.rotation.y = yaw
	mission.enemies.erase(id)
	corpse.replicated = false
	# Where the host had it, unless this peer drew it close enough already (no jump as it falls).
	if corpse.global_position.distance_to(at)>1.2: corpse.global_position = at
	corpse.sound(preload("res://assets/audio/zombies/death_1.ogg"),-4.0)
	corpse.go_limp(push,bone)
	mission.corpses.append(corpse)
	# As many bodies as the solo game keeps (InteriorZombies.MAX_CORPSES), every one a live ragdoll.
	if mission.corpses.size()>InteriorZombies.MAX_CORPSES: mission.corpses.pop_front().queue_free()

# ---------------------------------------------------------------- 0.40: what the squad says

## Host: `id` says `key` to everyone (one of its takes).
func speak_all(id: int, key: String) -> void:
	if not multiplayer.is_server() or not team.has(id) or voices==null: return
	speak.rpc(id,key,randi()%maxi(1,voices.takes(key)))

@rpc("authority","call_local","reliable",4)
func speak(id: int, key: String, take: int) -> void:
	if active and voices!=null: voices.play(id,key,take)

## The local player picked a line from the voice menu.
func player_line(key: String) -> void:
	if multiplayer.is_server():
		speak_all(1,key)
		if bots!=null: bots.heard(1,key)
	else: line.rpc_id(1,key)

@rpc("any_peer","call_remote","reliable",4)
func line(key: String) -> void:
	if not multiplayer.is_server() or not active: return
	var id := multiplayer.get_remote_sender_id()
	if not team.has(id) or voices.takes(key)==0: return
	speak_all(id,key)
	if bots!=null: bots.heard(id,key)

func _bot(id: int):
	return bots.bots.get(id) if bots!=null and is_bot(id) else null

func killed(id: int, _victim: int) -> void:
	var b = _bot(id)
	if b!=null and randf()<.35: bots.say(b,"kill",false,6.0)

func hurt(id: int, _amount: int) -> void:
	var b = _bot(id)
	if b!=null and team[id].hp>0 and team[id].hp<=Mission.MAX_HP*.55: bots.say(b,"hit",false,9.0)

func revived(by: int, other: int) -> void:
	var b = _bot(other)
	if b!=null: bots.say(b,"thanks",true)

func healed(id: int) -> void:
	var b = _bot(id)
	if b!=null: bots.say(b,"healing",false,5.0)

func picked(_id: int, _what: String) -> void:
	pass

## The squad AI comes into the store with the players (the last stand starts once the players are in).
func gather_bots(centre: Vector3) -> void:
	if bots==null: return
	for id: int in bots.bots:
		var v: Vector3 = team[id].pos-centre
		if absf(v.x)>8.0 or absf(v.z)>7.8:
			var at: Vector3 = mission.ground(centre+Vector3(randf_range(-3,3),0,randf_range(-2,3)))
			if at.is_finite():
				bots.bots[id].body.global_position = at
				team[id].pos = at

func reward(id: int,what: String) -> void:
	if is_bot(id):
		if bots!=null: bots.reward(id,what)
		return
	if id==1: supplies(what)
	else: supplies.rpc_id(id,what)

# ---------------------------------------------------------------- 0.43: grenades (scripts/grenade.gd)

## The thrower tells everyone else: a grenade is in the air (they see it fly).
@rpc("any_peer","call_remote","reliable",5)
func grenade_out(id: String, from: Vector3, velocity: Vector3, fuse: float) -> void:
	if active and main.grenades!=null: main.grenades.remote_throw(id,from,velocity,fuse)

## The thrower's grenade went off: everyone else sees and hears it, and their own player takes the blast.
@rpc("any_peer","call_remote","reliable",5)
func grenade_boom(id: String, at: Vector3) -> void:
	if active and main.grenades!=null: main.grenades.remote_boom(id,at)

## A player caught in a blast (their own game measured it): the host takes it off their health.
func blast_hurt(amount: int, own := true) -> void:
	# 0.46: one frag must not finish the whole squad: a teammate's blast takes at most 45, your own at most 85.
	amount = mini(amount,85 if own else 45)
	if multiplayer.is_server(): _blast(1,amount)
	else: blast_report.rpc_id(1,amount)

@rpc("any_peer","call_remote","reliable",5)
func blast_report(amount: int) -> void:
	if multiplayer.is_server(): _blast(multiplayer.get_remote_sender_id(),amount)

# ---------------------------------------------------------------- 0.53: Heavy-arm (scripts/coop/heavyarm.gd)

## A grenade's blast on Heavy-arm, measured by the game that threw it: the host takes it off him.
func report_boss_blast(amount: float, _at: Vector3) -> void:
	if not active or mission==null: return
	if multiplayer.is_server(): _boss_blast(1,amount)
	else: boss_blast_report.rpc_id(1,amount)

@rpc("any_peer","call_remote","reliable",3)
func boss_blast_report(amount: float) -> void:
	if multiplayer.is_server() and active: _boss_blast(multiplayer.get_remote_sender_id(),clampf(amount,0.0,500.0))

func _boss_blast(id: int, amount: float) -> void:
	var bf = mission.boss_fight()
	if bf!=null and team.has(id): bf.blast(id,amount)

## A round into one of the fuel drums at the rear gate.
@rpc("any_peer","call_remote","reliable",3)
func barrel_report(i: int, damage: float) -> void:
	if not multiplayer.is_server() or not active or mission.escape==null or mission.escape.fight==null: return
	var id := multiplayer.get_remote_sender_id()
	if team.has(id) and int(team[id].hp)>0: mission.escape.fight.barrel_hit(id,i,clampf(damage,0.0,200.0))

## Struck by Heavy-arm: thrown (each game moves its own player), the lens shaken.
@rpc("authority","call_local","reliable")
func knocked(id: int, push: Vector3) -> void:
	if not active or id!=local_id() or main.get("player")==null: return
	main.player.throw_back(push)
	main.player.jolt(.09)

func _blast(id: int, amount: int) -> void:
	if not active or not team.has(id) or int(team[id].hp)<=0: return
	if harmless or (mission!=null and mission.harmless):
		if mission!=null: mission.blocked_hits += 1
		return
	amount = clampi(amount,0,85)
	var taken := clampi(amount,0,int(team[id].hp))
	team[id].hp -= taken
	team[id].hurt += taken
	hurt(id,taken)

@rpc("authority","reliable")
func supplies(what: String) -> void:
	var gun: InteriorGun = main.story.gun
	match what:
		"grenade":
			if main.grenades!=null:
				main.grenades.give(1)
				notice("Frag grenade (%d)  •  5 to throw" % int(main.grenades.count))
		"rifle":
			gun.give_rifle()
			gun.select("rifle")
		"ammo", "ammo:small", "ammo:medium", "ammo:large":
			# 0.48: a box for what is in the hands: small, medium or large.
			var size := Mission.drop_size(what)
			var boxes: Array = InteriorArsenal.AMMO_BOX.get(gun.weapon,[24,24,24])
			var count := int(boxes[["small","medium","large"].find(size)])
			gun.add_rounds(count,gun.weapon)
			notice("+%d rounds" % count)
			if main.grenades!=null and main.grenades.count<2: main.grenades.give(1)
		"shotgun":
			gun.give_shotgun()
			gun.select("shotgun")
		"dark":
			# 0.55: a debug jump into the fifth floor's dark (mission `_settle`): the flashlight put out.
			if main.story.flashlight.on: main.story.flashlight.set_on(false)
		"refill":
			gun.add_rounds(maxi(0,180-gun.total()))
			if gun.rifle_owned:
				var reserve: int = gun.reserve if gun.weapon=="rifle" else gun._stock.rifle.reserve
				gun.add_rounds(maxi(0,300-reserve),"rifle")
			if gun.shotgun_owned:
				var shells: int = gun.reserve if gun.weapon=="shotgun" else gun._stock.shotgun.reserve
				gun.add_rounds(maxi(0,64-shells),"shotgun")
			gun.debug_fill()

func personal(id: int,message: String) -> void:
	if is_bot(id): return
	if id==1: notice(message)
	else: notice.rpc_id(id,message)

@rpc("authority","reliable")
func notice(message: String) -> void:
	hud_message = message
	hud_until = Time.get_ticks_msec()+3500
	var menu: Node = main.get_node_or_null("DebugMenu")
	if menu!=null and bool(menu.get("open")): menu.show_reply(message)

func _process(delta: float) -> void:
	_upnp_check()
	if is_instance_valid(_preview_pivot):
		_preview_pivot.rotation.y += delta * 0.55
	if deadline>0 and Time.get_ticks_msec()>deadline: _failed("The connection timed out. Check the host address.")
	if not active or show_host_left or not team.has(local_id()): return
	mission.render(delta)
	_board_tick()
	var p: Dictionary = team[local_id()]
	main.player.limp = 1.0 if p.hp>0 and p.hp<=Mission.CRITICAL_HP else 0.0
	main.player.can_run = p.hp>Mission.CRITICAL_HP
	main.player.pace_scale = (.64 if p.hp<=Mission.CRITICAL_HP else 1.0)*(.62 if int(p.get("drag",-1))>=0 else 1.0)*(.8 if int(p.get("pdrag",-1))>=0 else 1.0)
	# 0.46: being patched up by a teammate: stand still; patching yourself: a slow shuffle at most.
	var heal_t := float(p.get("heal_t",-1.0))
	if bool(p.get("held",false)): main.player.pace_scale = 0.0
	elif heal_t>=0.0: main.player.pace_scale *= .35
	if heal_t>=0.0: main.player.can_run = false
	_kits_hud()
	if _g_down>=0.0 and not _g_dropped and Time.get_ticks_msec()/1000.0-_g_down>=DROP_HOLD:
		_g_dropped = true
		_drop_weapon()
	if p.hp<last_hp:
		main.player.jolt(.048)
		# 0.60: a small shake and a faint red flash (scripts/hurt_feedback.gd); a bigger bite shakes more.
		if p.hp>0: InteriorHurtFeedback.hit(main.player,clampf(float(last_hp-p.hp)/30.0,.35,1.0))
	last_hp = p.hp
	if mission.stage>=Mission.OVER:
		if not last_results: results()
		return
	# 0.43: down is not frozen any more: the player crawls (slowly, low, no gun) toward help.
	main.player.playing = not local_menu and not chatting and not _debug_open()
	main.player.downed = p.hp<=0
	if p.hp<=0 and main.story.gun.drawn: main.story.gun.holster()
	if main.story.flashlight.on: tutorial = false
	# 0.40: almost nothing on the screen: the objective, and a word when you are down. (No name, health, kits or
	# key list: the owner wants the HUD all but empty.)
	var text: String = mission.objective()
	if p.hp==0: text += "\nDown • a teammate with a healthkit can help you up (they hold E on you)"
	hint.text = phone(text)
	var message: String = mission.text_line
	if Time.get_ticks_msec()<hud_until: message = hud_message
	_set_dialogue(message)
	_story_box()
	var action: String = mission.candidate(local_id())
	if action!="": main.prompt.text = phone(mission.prompt_for(action))
	elif mission.school!=null and int(p.get("pdrag",-1))<0:
		var said: String = mission.school.props.prompt(main.player)
		if said!="": main.prompt.text = phone(said)
	if heal_t>=0.0:
		var bar := int(clampf(heal_t,0.0,1.0)*10.0)
		var word := "Being patched up  •  hold still" if bool(p.get("held",false)) else "Using a healthkit"
		main.prompt.text = "%s   %s%s" % [word,"■".repeat(bar),"□".repeat(10-bar)]
	_drag_feel(int(p.get("drag",-1)))
	_prop_feel(int(p.get("pdrag",-1)))
	_hints(delta)

## 0.54: a line on the screen: "Name\nwords" shows the name over the words; anything else, the words alone.
func _set_dialogue(message: String) -> void:
	dialogue_panel.visible = message!=""
	var who := ""
	var words := message
	var cut := message.find("\n")
	if cut>0 and cut<=30 and message.length()>cut+1:
		who = message.substr(0,cut)
		words = message.substr(cut+1)
	dialogue_name.visible = who!=""
	dialogue_name.text = who
	dialogue.text = words
	# 0.60: the line is spoken (ElevenLabs clips, scripts/voice_lines.gd), once, on every peer.
	InteriorVoiceLines.speak(self,who,words)

## 0.50: the school's story, on every peer: the page the host is on, typed out, faded in.
func _story_box() -> void:
	var page := int(mission.flags.get("story",-1))
	if page<0 or page>=Mission.STORY.size():
		if story_panel.visible: story_panel.hide()
		_story_page = -1
		return
	var now := Time.get_ticks_msec()*.001
	if page!=_story_page:
		_story_page = page
		_story_at = now
		story_body.text = Mission.STORY[page]
	var text: String = Mission.STORY[page]
	story_body.visible_characters = mini(int((now-_story_at)*46.0),text.length())
	story_foot.text = "%d / %d     E  •  go on" % [page+1,Mission.STORY.size()]
	story_panel.modulate.a = clampf((now-_story_at)*2.5,0.0,1.0) if page==0 else 1.0
	story_panel.show()

## 0.41: E let go: whoever was dragging a table leaves it where it is.
func _released() -> void:
	if not active or mission==null or not team.has(local_id()): return
	# (Always, not only once the host's state says so: a client's E can come up before that arrives.)
	if not _f_held: _send("heal_stop")
	# 0.57: a prop taken hold of (or a tap on a door): let go of it, whatever the host has said so far.
	if _prop_held:
		_prop_held = false
		_send("letgo")
		return
	if int(team[local_id()].get("drag",-1))<0: return
	_send("letgo")

## 0.48: the shove as this player feels it: the hands and the weapon go out, the lens jolts; the host decides
## what it moved.
var _shove_at := -10.0
func _shove_local() -> void:
	var now := Time.get_ticks_msec()*.001
	if now-_shove_at<.75: return
	_shove_at = now
	var gun: InteriorGun = main.story.gun
	if gun!=null and gun.drawn: gun.thrust()
	main.player.punch(Vector3(-1.6,randf_range(-.6,.6),randf_range(-.8,.8)))
	_send("shove")

func _send(action: String) -> void:
	if multiplayer.is_server(): handle(1,action)
	else: use.rpc_id(1,action)

## Dragging a table: the body does not bump the table it is pulling, and it goes slower.
func _drag_feel(index: int) -> void:
	if index==_dragging: return
	var player: InteriorPlayer = main.player
	if _dragging>=0 and _dragging<mission.street.tables.size():
		player.remove_collision_exception_with(mission.street.tables[_dragging])
	_dragging = index
	if index>=0 and index<mission.street.tables.size():
		player.add_collision_exception_with(mission.street.tables[index])

## 0.57: the same for a school prop being dragged (school_props.gd).
func _prop_feel(index: int) -> void:
	var body: RigidBody3D = mission.school.props.body_of(index) if mission.school!=null and index>=0 else null
	if body==_prop_dragging: return
	var player: InteriorPlayer = main.player
	if is_instance_valid(_prop_dragging): player.remove_collision_exception_with(_prop_dragging)
	_prop_dragging = body
	if body!=null: player.add_collision_exception_with(body)

## 0.57: the local player walked into a school prop (player.gd `prop_push_hook`): the host pushes it now; a client's
## pushes go to the host with its pose.
func _prop_push(body: RigidBody3D, point: Vector3, toward: Vector3, speed: float) -> void:
	if not active or mission==null or mission.school==null: return
	var i := int(body.get_meta("coop_prop",-1))
	if i<0: return
	if multiplayer.is_server(): mission.school.props.intent(1,i,point,toward,speed)
	else: _pushes[i] = [point,toward,speed]

@rpc("any_peer","call_remote","unreliable_ordered",1)
func push_props(data: PackedFloat32Array) -> void:
	if not multiplayer.is_server() or not active or mission==null or mission.school==null: return
	var id := multiplayer.get_remote_sender_id()
	if not team.has(id) or int(team[id].hp)<=0: return
	for o in range(0,data.size()-7,8):
		var point := Vector3(data[o+1],data[o+2],data[o+3])
		if not point.is_finite() or point.distance_to(team[id].pos+Vector3.UP*.9)>2.0: continue
		mission.school.props.intent(id,int(data[o]),point,Vector3(data[o+4],data[o+5],data[o+6]),data[o+7])

## 0.55: the hints that belong to stretches of the run: [first stage, last stage] they still apply in.
const HINT_STAGES := {"tables": Vector2i(4, 5), "guns": Vector2i(4, 5), "stack": Vector2i(5, 5), "push": Vector2i(5, 5),
	"stairs": Vector2i(10, 10), "back": Vector2i(5, 5)}
var _hint_key := ""

## The hint line: one at a time, faded in and out, with a while between them. What fits the moment goes first.
func _hints(delta: float) -> void:
	if hint_label==null: return
	var stage: int = mission.stage
	if stage!=_hint_stage:
		_hint_stage = stage
		# (0.55: the stages' own hints go once the run is past them (a debug jump goes past several at once): out of
		# the queue, and faded out if one is up.)
		for key: String in HINT_STAGES:
			var span: Vector2i = HINT_STAGES[key]
			if stage>=span.x and stage<=span.y: continue
			hint_queue.erase(key)
			if key==_hint_key and hint_time>.6: hint_time = .6
		if stage==4: _hint_now(["tables","guns"])
		elif stage==5: _hint_now(["stack","push"])
		elif stage==10: _hint_now(["stairs"])
	if stage==5 and int(mission.flags.get("backhits",0))>0 and not hint_shown.has("back"): _hint_now(["back"])
	if hint_time>0.0:
		hint_time -= delta
		hint_label.modulate.a = clampf(minf(7.5-hint_time,hint_time)/.6,0.0,1.0)
		return
	hint_label.modulate.a = 0.0
	hint_wait -= delta
	if hint_wait>0.0 or hint_queue.is_empty() or local_menu: return
	var key: String = hint_queue.pop_front()
	if hint_shown.has(key): return
	hint_shown[key] = true
	# (0.64: a phone has no squad-talk menu: that hint is not for it.)
	if main.mobile and key == "squad": return
	_hint_key = key
	hint_label.text = phone(HINTS[key])
	hint_time = 7.5
	hint_wait = randf_range(24.0,38.0)

func _hint_now(keys: Array) -> void:
	for i in range(keys.size()-1,-1,-1):
		if hint_shown.has(keys[i]): continue
		hint_queue.erase(keys[i])
		hint_queue.push_front(keys[i])
	hint_wait = minf(hint_wait,1.5)

func _unhandled_input(event: InputEvent) -> void:
	if not active or mission.stage>=Mission.OVER: return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if board_open: return
		# 0.67: Esc in Options steps back to the pause, as its Back button does.
		if local_menu and main.current_menu=="options": show_pause()
		elif local_menu: resume()
		else: show_pause()
	elif not local_menu and not chatting and event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode in [KEY_ENTER, KEY_KP_ENTER] and humans() > 1:
		get_viewport().set_input_as_handled()
		_open_chat()


## 0.46: F and G belong to the co-op game here, before the player (F inspects) and the gun (G holsters) see them.
func _input(event: InputEvent) -> void:
	if not active or mission==null or mission.stage>=Mission.OVER or local_menu or chatting or _debug_open(): return
	if not event is InputEventKey or (event as InputEventKey).echo: return
	var key := event as InputEventKey
	# 0.48: T shoves (the chat is Enter now).
	if key.physical_keycode==KEY_T:
		get_viewport().set_input_as_handled()
		if key.pressed and not main.player.downed: _shove_local()
		return
	if key.physical_keycode==KEY_F:
		get_viewport().set_input_as_handled()
		if key.pressed and not _f_held:
			_f_held = true
			_send("heal")
		elif not key.pressed and _f_held:
			_f_held = false
			_send("heal_stop")
	elif key.physical_keycode==KEY_G:
		get_viewport().set_input_as_handled()
		if key.pressed and _g_down<0.0:
			_g_down = Time.get_ticks_msec()/1000.0
			_g_dropped = false
		elif not key.pressed:
			# A tap still does what G always did: the Glock up, or away.
			if not _g_dropped and _g_down>=0.0 and main.story.gun.has_weapon("pistol"): main.story.gun._key_weapon("pistol")
			_g_down = -1.0
			_g_dropped = false

## 0.49: the Q W E R T Y debug menu from any squad member: the host carries the action out for them.
@rpc("any_peer","reliable")
func debug_request(what: String, ahead: Vector3) -> void:
	if not multiplayer.is_server() or not active: return
	var menu: Node = main.get_node_or_null("DebugMenu")
	if menu!=null and ahead.is_finite(): menu.coop_as(multiplayer.get_remote_sender_id(),what,ahead)

@rpc("authority","reliable")
func debug_teleport(to: Vector3, yaw := INF) -> void:
	var menu: Node = main.get_node_or_null("DebugMenu")
	if menu!=null and to.is_finite(): menu._teleport(to)
	if yaw!=INF:
		main.player.rotation.y = yaw
		if main.player.get("_look_pitch")!=null: main.player._look_pitch = 0.0

## 0.49 (host): debug: one squad member to `to`, facing `yaw`.
func debug_move_one(id: int, to: Vector3, yaw: float) -> void:
	if not team.has(id): return
	if is_bot(id):
		if bots!=null and bots.bots.has(id):
			bots.bots[id].body.global_position = to
			bots.bots[id].dest = to
	elif id==local_id(): debug_teleport(to,yaw)
	else: debug_teleport.rpc_id(id,to,yaw)
	team[id].pos = to
	team[id].yaw = yaw

## 0.49 (host): debug: every player to `to` (side by side), facing `yaw`, and the squad AI with them. 0.55: on spots
## with room for each (mission.squad_spots: side by side were there is room, then in rows behind; a fire escape's
## landing or a corridor used to put the third and fourth into a wall or over the edge). `first` (whoever asked) gets
## the place itself, then the other players, then the squad AI.
func debug_move_squad(to: Vector3, yaw: float, bots_too := true, first := 0) -> void:
	var ids: Array = []
	for id: int in team.keys():
		if is_bot(id) and not bots_too: continue
		ids.append(id)
	ids.sort_custom(func(a: int, b: int) -> bool: return _squad_rank(a,first)<_squad_rank(b,first))
	var spots: Array = mission.squad_spots(to,yaw,ids.size())
	for i in ids.size(): debug_move_one(ids[i],spots[i],yaw)

func _squad_rank(id: int, first: int) -> int:
	if id==first: return 0
	if is_bot(id): return 3
	return 1 if id==1 else 2

func _debug_open() -> bool:
	var menu: Node = main.get_node_or_null("DebugMenu")
	return menu!=null and bool(menu.get("open"))

func show_pause() -> void:
	local_menu = true
	main._show_menu("coop_pause")
	get_tree().paused = false

func resume() -> void:
	local_menu = false
	main._play()

func results() -> void:
	if not show_host_left and multiplayer.is_server() and team.size()>1: send_state(true)
	last_results = true
	local_menu = true
	main._show_menu("coop_results")
	get_tree().paused = false

## 0.49: the chapter leaderboard comes up on every peer with the host's `flags.board` and goes when the host
## moves the run on (everyone ready). While it is up the next stretch is woken (mission `wake_ahead`).
func _board_tick() -> void:
	var want: bool = bool(mission.flags.get("board",false)) and mission.stage<Mission.OVER
	# 0.55: on past the mart's board without it ever coming up here (a debug jump): its loading caught up.
	if _catching:
		if not want:
			_catch_up_tick()
			return
		_catching = false
	elif not want and not board_open and _past_a_board(): _catch_up()
	if want and not board_open:
		board_open = true
		_board_sig = ""
		_close_chat()
		_start_chapter_load()
	elif board_open and not want:
		board_open = false
		_board_sig = ""
		if local_menu: resume()
		# 0.53: on into the next chapter: the loading screen says it is ready and fades into it.
		if mission.stage<Mission.OVER and _load_done: _show_chapter_screen()
		return
	_chapter_screen_tick()
	if not board_open: return
	_chapter_load_tick()
	var sig := "load:%d:%s;" % [_load_i,str(_load_done)]
	for id: int in team: sig += "%d:%s;" % [id,str(team[id].get("next_ready",false))]
	if sig!=_board_sig or not local_menu:
		_board_sig = sig
		local_menu = true
		main._show_menu("coop_board")
		get_tree().paused = false

# ---------------------------------------------------------------- 0.53: loading at the chapter board

## While the board is up, each game puts what is behind away and loads what is ahead, a step a frame (at most ~12 ms
## of work each), and the board shows how far it has got; READY waits until it is done. The steps are real: the
## street behind is let go of (`mission.free_unloaded`: meshes and materials dropped), the backstreets and the
## college woken, the college's people loaded from disk, and drawn once out of sight so their shaders are compiled
## before anyone meets them.
var _load_steps: Array = []
var _load_i := 0
var _load_done := false
var _load_caption := ""
var _load_title := ""
var _load_assets: Array = []
var _warm: Array = []
var _chapter_screen: CanvasLayer
var _screen_fill: ColorRect
var _screen_caption: Label
var _screen_title: Label
var _screen_time := -1.0
## 0.55: the chapters this game has loaded for (the steps run to the end): "backstreets" at the mart's board, "city"
## at PILCST's. A debug jump past the mart's board never shows the board: the same steps are caught up behind the
## chapter screen (`_catch_up`), so the street behind is let go of and the college's people are loaded, as in play.
var chapters_loaded := {}
var _load_key := ""
var _catching := false

func _start_chapter_load() -> void:
	_load_i = 0
	_load_done = false
	_load_assets.clear()
	_warm.clear()
	_load_steps.clear()
	var to_city := bool(mission.stage>=16 or bool(mission.flags.get("pilcst_out",false)))
	# 0.68: across the long bridge: Outer Street put away and let go of, the hospital built and its people loaded.
	var to_hospital := bool(mission.stage>=Mission.HOSPITAL or bool(mission.flags.get("bridge_out",false)))
	_load_key = "hospital" if to_hospital else ("city" if to_city else "backstreets")
	if to_hospital:
		_load_title = "Davao Central Laboratory"
		_load_steps.append(["Putting Outer Street away",_step_leave_outer])
		_load_steps.append(["Letting go of Outer Street",_step_free])
		_load_steps.append(["Building the hospital",_step_hospital])
		for path: String in mission.hospital_assets():
			_load_steps.append(["Loading the hospital's people",_load_one.bind(path)])
		_load_steps.append(["Building the hospital",_step_premap_hospital])
		_load_steps.append(["Warming up",_warm_up])
		_load_steps.append(["Warming up",_cool_down])
	elif to_city:
		_load_title = "Outer Street"
		_load_steps.append(["Putting the college away",_step_clean])
		_load_steps.append(["Letting go of the college and the night's dead",_step_free])
		_load_steps.append(["Building Outer Street",_step_outer_street])
		# (0.67: the lane, the avenue and the plaza read into the nav's map; the rest in the background.)
		_load_steps.append(["Building Outer Street",_step_premap_outer])
		_load_steps.append(["Warming up",_warm_up])
		_load_steps.append(["Warming up",_cool_down])
	else:
		_load_title = "The backstreets"
		_load_steps.append(["Putting Olivar Family Mart away",_step_shut])
		_load_steps.append(["Letting go of the street behind",_step_free])
		_load_steps.append(["Waking the backstreets and the college",_step_wake])
		for path: String in mission.chapter_assets():
			_load_steps.append(["Loading the college's people",_load_one.bind(path)])
		_load_steps.append(["Waking the backstreets and the college",_step_premap])
		_load_steps.append(["Warming up",_warm_up])
		_load_steps.append(["Warming up",_cool_down])
	print("INTERIOR_COOP_CHAPTER loading %s (%d steps)" % [_load_title,_load_steps.size()])

func _step_clean() -> void:
	if mission.escape!=null: mission.escape.clean()

func _step_free() -> void: mission.free_unloaded()
## 0.66: the college's ground into the nav's map (host), 10 ms a frame behind the board.
var _premap_t := 0
func _step_premap() -> bool:
	if _premap_t==0: _premap_t = Time.get_ticks_msec()
	mission.premap_school()
	var done: bool = mission.premap_step(10000)
	if done: print("INTERIOR_COOP_NAV premapped %d half cells (%d ms of frames)" % [mission.nav_premapped,Time.get_ticks_msec()-_premap_t])
	return done
func _step_outer_street() -> void: mission.build_outer_street()
func _step_leave_outer() -> void: mission.leave_outer_street()
func _step_hospital() -> void: mission.build_hospital()
func _step_premap_hospital() -> bool: return mission.premap_hospital()
func _step_premap_outer() -> bool: return not multiplayer.is_server() or mission.premap_outer_board()
func _step_none() -> void: pass
func _step_shut() -> void: mission.shut_front()
func _step_wake() -> void: mission.wake_ahead()

func _load_one(path: String) -> void:
	if ResourceLoader.exists(path): _load_assets.append(load(path))

func _chapter_load_tick() -> void:
	if _load_done or _load_steps.is_empty(): return
	var t0 := Time.get_ticks_usec()
	while _load_i<_load_steps.size():
		var step: Array = _load_steps[_load_i]
		_load_caption = str(step[0])
		# (0.66: a step that answers false is not done yet: it runs again, next frame.)
		var done = (step[1] as Callable).call()
		if done is bool and not done: break
		_load_i += 1
		# (Warming up has to be drawn: a frame between; anything else as much as fits in ~12 ms.)
		if _load_caption=="Warming up" or Time.get_ticks_usec()-t0>12000: break
	if _load_i>=_load_steps.size():
		_load_done = true
		_load_caption = "Ready"
		chapters_loaded[_load_key] = true
		print("INTERIOR_COOP_CHAPTER loaded %s" % _load_title)

## 0.55: the run is past the mart's board (stage 8 on) and this game never loaded for it: a debug jump.
func _past_a_board() -> bool:
	if mission.stage>=Mission.HOSPITAL and mission.stage<Mission.OVER: return not chapters_loaded.has("hospital")
	if mission.stage>=16 and mission.stage<Mission.OVER: return not chapters_loaded.has("city")
	return mission.stage>=8 and mission.stage<16 and not chapters_loaded.has("backstreets") and not bool(mission.flags.get("pilcst_out",false))

## The board's loading, behind the chapter screen held up (black, the chapter's name, the step, the bar).
func _catch_up() -> void:
	_catching = true
	_start_chapter_load()
	print("INTERIOR_COOP_CHAPTER catching up %s" % _load_title)
	_screen_held()

func _catch_up_tick() -> void:
	_chapter_load_tick()
	_screen_held()
	if not _load_done: return
	_catching = false
	_show_chapter_screen(true)

func _screen_held() -> void:
	_build_chapter_screen()
	_screen_title.text = _load_title
	_screen_caption.text = _load_caption if _load_caption!="" else "Loading"
	_screen_fill.size.x = 440.0*chapter_progress()
	_screen_time = -1.0
	_chapter_screen.get_child(0).modulate.a = 1.0
	_chapter_screen.visible = true

func chapter_progress() -> float:
	return 1.0 if _load_done else float(_load_i)/maxf(float(_load_steps.size()),1.0)

## Each of the college's people drawn once in front of the lens, behind the board (their pipelines compiled now).
func _warm_up() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera==null: return
	var i := 0
	for res in _load_assets:
		if not res is PackedScene: continue
		var node := (res as PackedScene).instantiate()
		if not node is Node3D:
			node.free()
			continue
		main.add_child(node)
		(node as Node3D).global_position = camera.global_position-camera.global_basis.z*(3.0+float(i%4))+camera.global_basis.x*(float(i%5)-2.0)*.6
		_warm.append(node)
		i += 1

func _cool_down() -> void:
	for n in _warm:
		if is_instance_valid(n): n.queue_free()
	_warm.clear()

## The loading screen into the next chapter: black, its name, the bar full, "Ready", fading into play. (`held`: it was
## already up while the chapter loaded: the bar goes on from where it is.)
func _show_chapter_screen(held := false) -> void:
	_build_chapter_screen()
	if not held: _screen_fill.size.x = 0.0
	_screen_title.text = _load_title
	_screen_caption.text = "Ready"
	_screen_time = 0.0
	_chapter_screen.visible = true
	print("INTERIOR_COOP_CHAPTER screen %s" % _load_title)

func _build_chapter_screen() -> void:
	if _chapter_screen==null:
		_chapter_screen = CanvasLayer.new()
		_chapter_screen.layer = 40
		add_child(_chapter_screen)
		var back := ColorRect.new()
		back.color = Color(0,0,0,1)
		back.set_anchors_preset(Control.PRESET_FULL_RECT)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_chapter_screen.add_child(back)
		# 0.54: a small line of street capitals, the chapter's name large in the story's serif, a sodium bar.
		var kick := SleepType.kicker("Next",13,Color(SleepType.SODIUM,.8),6)
		kick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kick.set_anchors_preset(Control.PRESET_CENTER)
		kick.offset_left = -300
		kick.offset_right = 300
		kick.offset_top = -112
		kick.offset_bottom = -94
		back.add_child(kick)
		_screen_title = Label.new()
		_screen_title.add_theme_font_override("font",SleepType.serif())
		_screen_title.add_theme_font_size_override("font_size",66)
		_screen_title.add_theme_color_override("font_color",Color(.91,.92,.86))
		_screen_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_screen_title.set_anchors_preset(Control.PRESET_CENTER)
		_screen_title.offset_left = -500
		_screen_title.offset_right = 500
		_screen_title.offset_top = -96
		_screen_title.offset_bottom = -10
		back.add_child(_screen_title)
		var track := ColorRect.new()
		track.color = Color(.96,.9,.79,.18)
		track.set_anchors_preset(Control.PRESET_CENTER)
		track.offset_left = -220
		track.offset_right = 220
		track.offset_top = 4
		track.offset_bottom = 7
		back.add_child(track)
		_screen_fill = ColorRect.new()
		_screen_fill.color = Color(SleepType.SODIUM,.9)
		_screen_fill.size = Vector2(0,3)
		track.add_child(_screen_fill)
		_screen_caption = Label.new()
		_screen_caption.add_theme_font_override("font",SleepType.street(5))
		_screen_caption.uppercase = true
		_screen_caption.add_theme_font_size_override("font_size",15)
		_screen_caption.add_theme_color_override("font_color",Color(.96,.9,.79,.62))
		_screen_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_screen_caption.set_anchors_preset(Control.PRESET_CENTER)
		_screen_caption.offset_left = -300
		_screen_caption.offset_right = 300
		_screen_caption.offset_top = 16
		_screen_caption.offset_bottom = 40
		back.add_child(_screen_caption)

func _chapter_screen_tick() -> void:
	if _chapter_screen==null or _screen_time<0.0: return
	_screen_time += get_process_delta_time()
	var fill := clampf(.86+_screen_time/.6*.14,0.0,1.0)
	_screen_fill.size.x = maxf(_screen_fill.size.x,440.0*fill)
	var a := 1.0 if _screen_time<1.1 else clampf(1.0-(_screen_time-1.1)/.5,0.0,1.0)
	_chapter_screen.get_child(0).modulate.a = a
	if a<=0.0:
		_screen_time = -1.0
		_chapter_screen.visible = false

func _board_ready() -> void:
	if team.has(local_id()): team[local_id()].next_ready = true
	_board_sig = ""
	_send("next_ready")

## The board's rows: everyone, most kills first.
func _board_grid() -> void:
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation",16)
	main.menu_content.add_child(grid)
	for s in ["Survivor","Kills","Damage taken","Ammo used","Hits","Revives",""]: grid.add_child(_head_cell(s))
	var ids := team.keys()
	ids.sort_custom(func(a,b): return team[a].kills>team[b].kills)
	for id in ids:
		var p: Dictionary = team[id]
		var ready: bool = bool(p.get("next_ready",false)) or is_bot(id)
		grid.add_child(_name_cell(display_name(id)))
		for v in [p.kills,p.hurt,p.shots,p.hits,p.revives]: grid.add_child(_stat_cell(str(v)))
		var r := SleepType.kicker("Ready" if ready else "...",15,Color(.36,.78,.46) if ready else Color(SleepType.BONE,.5),2)
		grid.add_child(r)

## 0.54: the boards' cells: column heads in small street capitals, names in the text face, numbers in the mono.
func _head_cell(words: String) -> Label:
	return SleepType.kicker(words,13,Color(SleepType.BONE,.55),2)

func _name_cell(words: String) -> Label:
	return SleepType.label(words,SleepType.text(600),19,SleepType.BONE)

func _stat_cell(words: String) -> Label:
	return SleepType.label(words,SleepType.mono(),19,Color(SleepType.BONE,.86))

## 0.54: the next chapter loading on the board: what is being done, in the mono, over a thin sodium bar.
func _load_line(parent: Control, line: String, fraction: float) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",6)
	parent.add_child(column)
	column.add_child(SleepType.label(line,SleepType.mono(),14,Color(SleepType.BONE,.7)))
	var track := ColorRect.new()
	track.color = Color(SleepType.BONE,.12)
	track.custom_minimum_size = Vector2(0,3)
	column.add_child(track)
	var fill := ColorRect.new()
	fill.color = SleepType.SODIUM
	fill.anchor_right = clampf(fraction,0.0,1.0)
	fill.anchor_bottom = 1.0
	track.add_child(fill)

func build_overlay(kind: String) -> void:
	if kind=="coop_board":
		if bool(mission.flags.get("bridge_out",false)):
			main.menu_content.add_child(main._label("Outer Street",34))
			main.menu_content.add_child(main._label("Across the long bridge. Next: Davao Central Laboratory.",20))
		elif bool(mission.flags.get("pilcst_out",false)):
			# 0.52: out of the college's rear gate with the survivors of 501.
			main.menu_content.add_child(main._label("Prof. Ivan Lawrence College",34))
			var brought: int = mission.escape.saved() if mission.escape!=null else 0
			main.menu_content.add_child(main._label("Out through the rear gate with Ma'am Teves and her students (%d of 5). Next: Outer Street." % brought,20))
		else:
			main.menu_content.add_child(main._label("Olivar Family Mart",34))
			main.menu_content.add_child(main._label("The front is shut and locked. Next: the backstreets to the Prof. Ivan Lawrence College.",20))
		_board_grid()
		var waiting: Array = []
		for id: int in team:
			if not is_bot(id) and not bool(team[id].get("next_ready",false)): waiting.append(display_name(id))
		main.menu_content.add_child(main._label("Waiting for: "+", ".join(waiting) if not waiting.is_empty() else "Everyone is ready.",18))
		# 0.53: what this game is loading for the next chapter (READY waits for it).
		var line := ("Loading: %s  ·  %s" % [_load_title,_load_caption]) if not _load_done else ("%s: ready" % _load_title)
		_load_line(main.menu_content,line,chapter_progress())
		var mine: bool = bool(team.get(local_id(),{}).get("next_ready",false))
		var b: Button = main._button(("Ready" if not mine else "Ready - waiting for the squad") if _load_done else "Loading...",_board_ready)
		b.disabled = mine or not _load_done
		return
	if kind=="coop_pause":
		main.menu_content.add_child(main._label("Pause",32))
		main._button("Resume",resume)
		# 0.67: the graphics, sound and display settings from the pause (the game goes on meanwhile).
		main._button("Options",func(): main._show_menu("options"))
	else:
		main.menu_content.add_child(main._label("Match Results",34))
		main.menu_content.add_child(main._label(Mission.END_TITLE if mission.stage==Mission.WON else mission.text_line,22))
		var grid := GridContainer.new()
		grid.columns = 6
		grid.add_theme_constant_override("h_separation",16)
		main.menu_content.add_child(grid)
		for s in ["Survivor","Kills","Damage taken","Ammo used","Hits","Revives"]: grid.add_child(_head_cell(s))
		var ids := team.keys()
		ids.sort_custom(func(a,b): return team[a].kills>team[b].kills)
		for id in ids:
			var p: Dictionary = team[id]
			grid.add_child(_name_cell(display_name(id)))
			for v in [p.kills,p.hurt,p.shots,p.hits,p.revives]: grid.add_child(_stat_cell(str(v)))
	main._button("Leave game",func(): end_session(); main._restart())

