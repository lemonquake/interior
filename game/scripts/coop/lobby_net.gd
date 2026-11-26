extends Node
## 0.45: the online lobby. No addresses to type: everyone running the game meets on a public message relay
## (MQTT 3.1.1 over plain TCP, a few public brokers tried in order), and through it
##   * says who they are and what they are doing (a retained presence message per player, cleared by the relay
##     itself when the game closes or drops: the "last will"),
##   * lists the game they host in that presence (host name, mission, how many, where to reach it),
##   * talks in the lobby chat (one public channel), and
##   * asks a host to open a way through its router for them (hole punching: see session.gd).
## Only names, chat lines and the host's public address go over the relay. It is public: anyone who knows the
## topic can read it, so the chat says so. The game itself (ENet) goes straight between the players.
##
## Topics, under ROOT:  u/<id> presence (retained) · chat · to/<id> messages for one player.

signal changed            ## players or games changed
signal chat(name: String, text: String, own: bool, system: bool)
signal status(text: String, online: bool)
signal message(data: Dictionary)   ## something sent to us alone (to/<id>)

const ROOT := "sleepgame-hk7q/v1/"
## 0.62: the Sleep server (server/deploy) first; the public brokers stay as a fallback.
const BROKERS := [["15.235.246.87", 1883], ["broker.hivemq.com", 1883], ["broker.emqx.io", 1883], ["test.mosquitto.org", 1883]]
const KEEPALIVE := 30
const CFG := "user://lobby.cfg"
const STUN_SERVERS := [["stun.l.google.com", 19302], ["stun1.l.google.com", 19302], ["stun.cloudflare.com", 3478]]

var id := ""
var player_name := ""
var state := "menu"
var game := {}
## Everyone online (not us): id -> {n, s, g, v, seen}
var players := {}
var online := false
var version := "0"

var _tcp: StreamPeerTCP
var _buffer := PackedByteArray()
var _broker := 0
var _phase := 0          # 0 idle, 1 resolving, 2 connecting, 3 waiting for CONNACK, 4 online
var _resolve_id := -1
var _since := 0.0
var _ping_at := 0.0
var _retry_at := 0.0
var _announce_at := 0.0
var _wanted := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	version = str(ProjectSettings.get_setting("application/config/version", "0"))
	var cfg := ConfigFile.new()
	cfg.load(CFG)
	player_name = clean_name(str(cfg.get_value("lobby", "name", "")))
	if player_name.is_empty():
		player_name = "Survivor %04d" % (randi() % 10000)
		_save()
	# One id per running game: two copies on one PC are two players.
	var bytes := Crypto.new().generate_random_bytes(6)
	id = bytes.hex_encode()

static func clean_name(value: String) -> String:
	var out := ""
	for c in value.strip_edges():
		if c.unicode_at(0) >= 32 and not c in "[]{}<>\\\"": out += c
	return out.substr(0, 18).strip_edges()

func set_player_name(value: String) -> bool:
	var v := clean_name(value)
	if v.length() < 2: return false
	player_name = v
	_save()
	announce()
	return true

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG)
	cfg.set_value("lobby", "name", player_name)
	cfg.save(CFG)

## Open the connection (the multiplayer screen does this the first time it shows).
func start() -> void:
	_wanted = true
	if _phase == 0: _connect_next(false)

func stop() -> void:
	_wanted = false
	if _phase == 4:
		_publish(ROOT + "u/" + id, PackedByteArray(), true)
		_send(PackedByteArray([0xE0, 0x00]))
	_close()

func set_state(value: String, hosted := {}) -> void:
	state = value
	game = hosted
	announce()

func announce() -> void:
	if _phase != 4: return
	var body := {"n": player_name, "s": state, "v": version, "t": int(Time.get_unix_time_from_system())}
	if not game.is_empty(): body["g"] = game
	_publish(ROOT + "u/" + id, JSON.stringify(body).to_utf8_buffer(), true)
	_announce_at = Time.get_ticks_msec() * .001 + 50.0

func say(text: String) -> void:
	var t := text.strip_edges().substr(0, 160)
	if t.is_empty() or _phase != 4: return
	_publish(ROOT + "chat", JSON.stringify({"c": id, "n": player_name, "m": t}).to_utf8_buffer(), false)

func send_to(who: String, data: Dictionary) -> void:
	if _phase != 4: return
	data["c"] = id
	_publish(ROOT + "to/" + who, JSON.stringify(data).to_utf8_buffer(), false)

func games() -> Array:
	var out: Array = []
	for who: String in players:
		var p: Dictionary = players[who]
		if p.has("g") and p.g is Dictionary:
			var g: Dictionary = (p.g as Dictionary).duplicate()
			g["id"] = who
			g["host"] = str(p.get("n", "?"))
			g["same_version"] = str(p.get("v", "")) == version
			out.append(g)
	out.sort_custom(func(a, b): return str(a.host) < str(b.host))
	return out

# ---------------------------------------------------------------- connection

func _connect_next(advance: bool) -> void:
	_close()
	if advance: _broker = (_broker + 1) % BROKERS.size()
	var host: String = BROKERS[_broker][0]
	_resolve_id = IP.resolve_hostname_queue_item(host, IP.TYPE_IPV4)
	_phase = 1
	_since = _now()
	status.emit("Connecting to the lobby…", false)

func _close() -> void:
	if _tcp != null: _tcp.disconnect_from_host()
	_tcp = null
	_buffer.clear()
	if _resolve_id >= 0: IP.erase_resolve_item(_resolve_id)
	_resolve_id = -1
	var was := online
	_phase = 0
	online = false
	if was:
		players.clear()
		changed.emit()

func _now() -> float: return Time.get_ticks_msec() * .001

func _process(_delta: float) -> void:
	var now := _now()
	match _phase:
		0:
			if _wanted and now >= _retry_at: _connect_next(true)
		1:
			var st := IP.get_resolve_item_status(_resolve_id)
			if st == IP.RESOLVER_STATUS_DONE:
				var address := IP.get_resolve_item_address(_resolve_id)
				IP.erase_resolve_item(_resolve_id)
				_resolve_id = -1
				_tcp = StreamPeerTCP.new()
				if _tcp.connect_to_host(address, int(BROKERS[_broker][1])) != OK: _fail()
				else:
					_phase = 2
					_since = now
			elif st == IP.RESOLVER_STATUS_ERROR or now - _since > 6.0: _fail()
		2:
			_tcp.poll()
			var s := _tcp.get_status()
			if s == StreamPeerTCP.STATUS_CONNECTED:
				_tcp.set_no_delay(true)
				_send(_connect_packet())
				_phase = 3
				_since = now
			elif s == StreamPeerTCP.STATUS_ERROR or s == StreamPeerTCP.STATUS_NONE or now - _since > 6.0: _fail()
		3, 4:
			_tcp.poll()
			if _tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
				_fail()
				return
			var n := _tcp.get_available_bytes()
			if n > 0:
				var got := _tcp.get_partial_data(n)
				if got[0] == OK: _buffer.append_array(got[1])
				_parse()
			if _phase == 3 and now - _since > 6.0: _fail()
			if _phase == 4:
				if now >= _ping_at:
					_send(PackedByteArray([0xC0, 0x00]))
					_ping_at = now + KEEPALIVE * .5
				if now >= _announce_at: announce()

func _fail() -> void:
	_close()
	status.emit("Lobby offline. Retrying…", false)
	_retry_at = _now() + 4.0

# ---------------------------------------------------------------- MQTT packets

static func _remaining(n: int) -> PackedByteArray:
	var out := PackedByteArray()
	while true:
		var b := n % 128
		n = n / 128
		if n > 0: b |= 0x80
		out.append(b)
		if n == 0: break
	return out

static func _str(value: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray([value.size() >> 8, value.size() & 0xFF])
	out.append_array(value)
	return out

func _connect_packet() -> PackedByteArray:
	var body := _str("MQTT".to_utf8_buffer())
	# Protocol level 4; flags: clean session, a retained last will (QoS 0); keep-alive.
	body.append_array(PackedByteArray([4, 0x02 | 0x04 | 0x20, KEEPALIVE >> 8, KEEPALIVE & 0xFF]))
	body.append_array(_str(("sleep-" + id).to_utf8_buffer()))
	body.append_array(_str((ROOT + "u/" + id).to_utf8_buffer()))
	body.append_array(_str(PackedByteArray()))
	var out := PackedByteArray([0x10])
	out.append_array(_remaining(body.size()))
	out.append_array(body)
	return out

func _publish(topic: String, payload: PackedByteArray, retain: bool) -> void:
	var body := _str(topic.to_utf8_buffer())
	body.append_array(payload)
	var out := PackedByteArray([0x30 | (1 if retain else 0)])
	out.append_array(_remaining(body.size()))
	out.append_array(body)
	_send(out)

func _subscribe(topics: Array) -> void:
	var body := PackedByteArray([0, 1])
	for t: String in topics:
		body.append_array(_str(t.to_utf8_buffer()))
		body.append(0)
	var out := PackedByteArray([0x82])
	out.append_array(_remaining(body.size()))
	out.append_array(body)
	_send(out)

func _send(data: PackedByteArray) -> void:
	if _tcp != null and _tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED: _tcp.put_data(data)

func _parse() -> void:
	while _buffer.size() >= 2:
		var multiplier := 1
		var length := 0
		var i := 1
		var complete := false
		while i < _buffer.size() and i < 5:
			var b := _buffer[i]
			length += (b & 0x7F) * multiplier
			multiplier *= 128
			i += 1
			if b & 0x80 == 0:
				complete = true
				break
		if not complete or _buffer.size() < i + length: return
		var kind := _buffer[0] >> 4
		var flags := _buffer[0] & 0x0F
		var body := _buffer.slice(i, i + length)
		_buffer = _buffer.slice(i + length)
		match kind:
			2: _connack(body)
			3: _incoming(body, flags)

func _connack(body: PackedByteArray) -> void:
	if body.size() < 2 or body[1] != 0:
		_fail()
		return
	_phase = 4
	online = true
	_ping_at = _now() + KEEPALIVE * .5
	_subscribe([ROOT + "u/+", ROOT + "chat", ROOT + "to/" + id])
	announce()
	status.emit("Online", true)
	changed.emit()

func _incoming(body: PackedByteArray, flags: int) -> void:
	if body.size() < 2: return
	var tl := (body[0] << 8) | body[1]
	var topic := body.slice(2, 2 + tl).get_string_from_utf8()
	var at := 2 + tl
	if (flags >> 1) & 3 > 0: at += 2
	var payload := body.slice(at)
	if not topic.begins_with(ROOT): return
	var key := topic.substr(ROOT.length())
	if key.begins_with("u/"):
		var who := key.substr(2)
		if who == id: return
		if payload.is_empty():
			if players.erase(who): changed.emit()
			return
		var data = JSON.parse_string(payload.get_string_from_utf8())
		if not data is Dictionary: return
		# Leftovers from a crash the relay never cleared: older than ten minutes is gone.
		if absf(Time.get_unix_time_from_system() - float(data.get("t", 0))) > 600.0: return
		data["n"] = clean_name(str(data.get("n", "?")))
		players[who] = data
		changed.emit()
	elif key == "chat":
		var data = JSON.parse_string(payload.get_string_from_utf8())
		if not data is Dictionary: return
		chat.emit(clean_name(str(data.get("n", "?"))), str(data.get("m", "")).substr(0, 160), str(data.get("c", "")) == id, false)
	elif key == "to/" + id:
		var data = JSON.parse_string(payload.get_string_from_utf8())
		if data is Dictionary: message.emit(data)

# ---------------------------------------------------------------- reaching each other

## This machine's address as the internet sees it, from `port` (a STUN binding request). Blocks up to ~1.2 s.
## Returns {ip, port} or {} (no answer).
static func stun(port: int) -> Dictionary:
	var udp := PacketPeerUDP.new()
	if udp.bind(port) != OK: return {}
	var out := {}
	for server: Array in STUN_SERVERS:
		var address := IP.resolve_hostname(server[0], IP.TYPE_IPV4)
		if address.is_empty(): continue
		udp.set_dest_address(address, int(server[1]))
		var tid := Crypto.new().generate_random_bytes(12)
		var request := PackedByteArray([0, 1, 0, 0, 0x21, 0x12, 0xA4, 0x42])
		request.append_array(tid)
		udp.put_packet(request)
		var until := Time.get_ticks_msec() + 700
		while Time.get_ticks_msec() < until and out.is_empty():
			OS.delay_msec(10)
			while udp.get_available_packet_count() > 0:
				out = _stun_answer(udp.get_packet(), tid)
				if not out.is_empty(): break
		if not out.is_empty(): break
	udp.close()
	return out

static func _stun_answer(d: PackedByteArray, tid: PackedByteArray) -> Dictionary:
	if d.size() < 20 or d.slice(8, 20) != tid: return {}
	var i := 20
	while i + 4 <= d.size():
		var t := (d[i] << 8) | d[i + 1]
		var l := (d[i + 2] << 8) | d[i + 3]
		if (t == 0x20 or t == 0x01) and i + 12 <= d.size() and d[i + 5] == 1:
			var x := t == 0x20
			var port := ((d[i + 6] << 8) | d[i + 7]) ^ (0x2112 if x else 0)
			var cookie := [0x21, 0x12, 0xA4, 0x42]
			var parts := []
			for k in 4: parts.append(str(d[i + 8 + k] ^ (cookie[k] if x else 0)))
			return {"ip": ".".join(parts), "port": port}
		i += 4 + l + ((4 - l % 4) % 4)
	return {}

## The PC's own addresses on its home network (for players behind the same router).
static func lan_addresses() -> Array:
	var out: Array = []
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or (ip.begins_with("172.") and int(ip.get_slice(".", 1)) in range(16, 32)):
			out.append(ip)
	return out
