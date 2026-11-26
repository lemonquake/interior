extends Node
## 0.62: hosting through the Sleep server (server/relay/sleep_relay.py), so friends never need a VPN, port
## forwarding or a router that allows hole punching.
##
## The host's game keeps being the ENet server and runs the mission exactly as before. This node holds a small TCP
## line to the relay, which gives the squad a public room port. A friend connects ENet to <server>:<room port>; the
## relay tells us "open Q" and we send a few "SLR1<token>" packets to <server>:Q from the game's own UDP socket.
## That outgoing traffic is what lets the relay's packets back in through our router, and from then on every ENet
## packet between that friend and us passes through the relay unchanged.

signal ready_changed(on: bool)     ## the room port is known (true) or the relay line was lost (false)

## The game's server. SLEEP_RELAY_HOST overrides it (tests run a relay on this PC).
const DEFAULT_HOST := "15.235.246.87"
const CONTROL_PORT := 25109
const MAGIC := "SLR1"
const PING_EVERY := 15.0
const ANSWER_WAIT := 8.0

var relay_host := OS.get_environment("SLEEP_RELAY_HOST") if OS.get_environment("SLEEP_RELAY_HOST") != "" else DEFAULT_HOST
var port := 0              ## the squad's public room port (0 until the relay answered)
var public_ip := ""        ## the relay's address as friends should dial it
var seen_as := ""          ## our own public address, as the relay saw it
var token := ""
var failed := ""           ## why the relay could not be used (empty while fine)

var _session
var _tcp: StreamPeerTCP
var _buffer := ""
var _phase := 0            # 0 idle, 1 connecting, 2 waiting for the room, 3 room open
var _since := 0.0
var _ping_at := 0.0
var _opening := {}         # friend port Q -> sends left
var _open_at := 0.0
var _name := ""

func _now() -> float: return Time.get_ticks_msec() * .001

func setup(session) -> void:
	_session = session
	process_mode = Node.PROCESS_MODE_ALWAYS

func is_open() -> bool: return _phase == 3 and port > 0

## Ask the relay for a room. Call after the ENet server exists.
func open(player_name: String) -> void:
	close()
	_name = player_name
	failed = ""
	_tcp = StreamPeerTCP.new()
	var address := relay_host if relay_host.is_valid_ip_address() else IP.resolve_hostname(relay_host, IP.TYPE_IPV4)
	if address.is_empty() or _tcp.connect_to_host(address, CONTROL_PORT) != OK:
		_give_up("The Sleep server can't be reached.")
		return
	public_ip = address
	_phase = 1
	_since = _now()

func close() -> void:
	if _tcp != null and _tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED: _line({"t": "bye"})
	if _tcp != null: _tcp.disconnect_from_host()
	_tcp = null
	_buffer = ""
	_opening.clear()
	var was := is_open()
	_phase = 0
	port = 0
	token = ""
	if was: ready_changed.emit(false)

func _give_up(why: String) -> void:
	close()
	failed = why
	ready_changed.emit(false)

func _line(msg: Dictionary) -> void:
	if _tcp == null: return
	_tcp.put_data((JSON.stringify(msg) + "\n").to_utf8_buffer())

func _process(_delta: float) -> void:
	if _phase == 0 or _tcp == null: return
	var now := _now()
	_tcp.poll()
	var st := _tcp.get_status()
	if _phase == 1:
		if st == StreamPeerTCP.STATUS_CONNECTED:
			_tcp.set_no_delay(true)
			_line({"t": "hello", "name": _name, "v": str(ProjectSettings.get_setting("application/config/version", "0"))})
			_phase = 2
			_since = now
		elif st == StreamPeerTCP.STATUS_ERROR or now - _since > ANSWER_WAIT:
			_give_up("The Sleep server can't be reached.")
		return
	if st != StreamPeerTCP.STATUS_CONNECTED:
		_give_up("Lost the line to the Sleep server.")
		return
	var n := _tcp.get_available_bytes()
	if n > 0:
		var got := _tcp.get_partial_data(n)
		if got[0] == OK: _buffer += (got[1] as PackedByteArray).get_string_from_utf8()
		while _buffer.contains("\n"):
			var cut := _buffer.find("\n")
			var text := _buffer.substr(0, cut)
			_buffer = _buffer.substr(cut + 1)
			var msg = JSON.parse_string(text)
			if msg is Dictionary: _message(msg)
			if _phase == 0: return
	if _phase == 2 and now - _since > ANSWER_WAIT:
		_give_up("The Sleep server didn't answer.")
		return
	if _phase == 3 and now >= _ping_at:
		_line({"t": "ping"})
		_ping_at = now + PING_EVERY
	# Knock from the game socket until the relay says it heard us (a few times a second, for up to 4 s).
	if not _opening.is_empty() and now >= _open_at:
		_open_at = now + .2
		for q: int in _opening.keys():
			_knock(q)
			_opening[q] = int(_opening[q]) - 1
			if int(_opening[q]) <= 0: _opening.erase(q)

func _knock(q: int) -> void:
	if _session == null or _session.peer == null or _session.peer.host == null: return
	_session.peer.host.socket_send(public_ip, q, (MAGIC + token).to_utf8_buffer())

func _message(msg: Dictionary) -> void:
	match str(msg.get("t", "")):
		"room":
			port = int(msg.get("port", 0))
			token = str(msg.get("token", ""))
			seen_as = str(msg.get("you", ""))
			if str(msg.get("ip", "")).is_valid_ip_address(): public_ip = str(msg.ip)
			if port <= 0 or token.is_empty():
				_give_up("The Sleep server sent no room.")
				return
			_phase = 3
			_ping_at = _now() + PING_EVERY
			ready_changed.emit(true)
		"open":
			var q := int(msg.get("port", 0))
			if q > 0:
				_opening[q] = 20
				_knock(q)
		"bound":
			_opening.erase(int(msg.get("port", 0)))
		"close":
			_opening.erase(int(msg.get("port", 0)))
		"full":
			_give_up("The Sleep server is full right now (%s)." % str(msg.get("why", "")))
