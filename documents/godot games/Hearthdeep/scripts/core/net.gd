extends Node
## Networking hub. Every gameplay mutation flows: request() -> server validates ->
## broadcast() change to all peers -> Game.apply_change(). Single player runs the
## exact same path through an offline peer, so there is only one code path.

signal joined_world
signal connect_failed(reason: String)
signal peer_list_changed
signal chat_received(from_name: String, text: String, color: Color)

const DEFAULT_PORT := 24565
const MAX_PLAYERS := 6

var peers := {}          # peer id -> {"name", "look", "zone", "sleep", "down", "hp", "mhp"}
var server: ServerLogic = null
var _pstate_t := 0.0
var joining := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func my_id() -> int:
	return multiplayer.get_unique_id()

func is_server() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()

func is_online() -> bool:
	return multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)

# ------------------------------------------------------------------ session control

func start_offline() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	server = ServerLogic.new()
	peers.clear()

func host(port: int = DEFAULT_PORT) -> String:
	var p := ENetMultiplayerPeer.new()
	var err := p.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		return "Could not open port %d (error %d)." % [port, err]
	multiplayer.multiplayer_peer = p
	server = ServerLogic.new()
	peers.clear()
	return ""

func join(address: String, port: int = DEFAULT_PORT) -> String:
	var p := ENetMultiplayerPeer.new()
	var err := p.create_client(address, port)
	if err != OK:
		return "Could not start connection (error %d)." % err
	multiplayer.multiplayer_peer = p
	server = null
	peers.clear()
	joining = true
	return ""

func leave() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peers.clear()
	server = null

## Called by the host once its world is ready, to register itself as a player.
func register_self() -> void:
	peers[my_id()] = {"name": Game.profile["name"], "look": Game.profile["look"], "zone": "over", "sleep": false, "down": false, "hp": 100.0, "mhp": 100.0}
	peer_list_changed.emit()

# ------------------------------------------------------------------ connection events

func _on_peer_connected(_id: int) -> void:
	pass

func _on_peer_disconnected(id: int) -> void:
	if is_server() and peers.has(id):
		var nm: String = peers[id]["name"]
		peers.erase(id)
		_rpc_player_left.rpc(id)
		broadcast({"t": "toast", "text": "%s headed home." % nm, "color": Color("d8d0c0")})
		if server:
			server.on_player_left(id, nm)

func _on_connected() -> void:
	_rpc_hello.rpc_id(1, Game.profile)

func _on_connection_failed() -> void:
	joining = false
	connect_failed.emit("Couldn't reach that world.")
	leave()

func _on_server_disconnected() -> void:
	joining = false
	if Game.main:
		Game.main.on_disconnected()
	leave()

@rpc("any_peer", "reliable")
func _rpc_hello(prof: Dictionary) -> void:
	if not is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if peers.size() >= MAX_PLAYERS:
		_rpc_refused.rpc_id(id, "That world is full (6 players).")
		return
	var nm := String(prof.get("name", "Traveler")).strip_edges().substr(0, 18)
	if nm == "":
		nm = "Traveler"
	var base := nm
	var k := 2
	while _name_taken(nm):
		nm = "%s %d" % [base, k]
		k += 1
	var look: Dictionary = prof.get("look", {})
	peers[id] = {"name": nm, "look": look, "zone": "over", "sleep": false, "down": false, "hp": 100.0, "mhp": 100.0}
	var char_data: Dictionary = Game.world["players"].get(nm, {})
	if char_data.is_empty():
		char_data = Game.default_character(nm, look)
		Game.world["players"][nm] = char_data
	char_data["look"] = look
	_rpc_welcome.rpc_id(id, Game.world, Game.tod, char_data, peers)
	_rpc_player_joined.rpc(id, peers[id])
	broadcast({"t": "toast", "text": "%s arrived!" % nm, "color": Color("ffe08a")})
	if server:
		server.on_player_joined(id, nm)

func _name_taken(nm: String) -> bool:
	for p in peers:
		if peers[p]["name"] == nm:
			return true
	return false

@rpc("authority", "reliable")
func _rpc_refused(reason: String) -> void:
	connect_failed.emit(reason)
	leave()

@rpc("authority", "reliable")
func _rpc_welcome(world_state: Dictionary, tod: float, char_data: Dictionary, peer_list: Dictionary) -> void:
	joining = false
	Game.world = world_state
	Game.tod = tod
	peers = peer_list
	Game.profile["name"] = char_data["name"]
	if Game.main:
		Game.main.begin_world_as_client(char_data)
	joined_world.emit()
	peer_list_changed.emit()

@rpc("authority", "call_local", "reliable")
func _rpc_player_joined(id: int, info: Dictionary) -> void:
	peers[id] = info
	if id != my_id():
		Zones.spawn_remote_player(id, info)
	peer_list_changed.emit()

@rpc("authority", "call_local", "reliable")
func _rpc_player_left(id: int) -> void:
	peers.erase(id)
	Zones.remove_remote_player(id)
	peer_list_changed.emit()

# ------------------------------------------------------------------ requests & changes

## Ask the server to perform an action on our behalf.
func request(action: String, args: Dictionary = {}) -> void:
	if is_server():
		if server:
			server.handle(my_id(), action, args)
	else:
		_rpc_request.rpc_id(1, action, args)

@rpc("any_peer", "reliable")
func _rpc_request(action: String, args: Dictionary) -> void:
	if not is_server() or server == null:
		return
	var id := multiplayer.get_remote_sender_id()
	if not peers.has(id):
		return
	server.handle(id, action, args)

## Server -> everyone (including itself).
func broadcast(ch: Dictionary) -> void:
	if not is_server():
		return
	_rpc_change.rpc(ch)

@rpc("authority", "call_local", "reliable")
func _rpc_change(ch: Dictionary) -> void:
	Game.apply_change(ch)

## Server -> one peer: items approved for their pack.
func grant(peer: int, items: Array, quiet: bool = false) -> void:
	if items.is_empty():
		return
	if peer == my_id():
		Game.local_grant(items, quiet)
	else:
		_rpc_grant.rpc_id(peer, items, quiet)

@rpc("authority", "reliable")
func _rpc_grant(items: Array, quiet: bool) -> void:
	Game.local_grant(items, quiet)

## Server -> one peer: arbitrary message for local systems (dialogue replies, UI refreshes).
func tell(peer: int, kind: String, data: Dictionary) -> void:
	if peer == my_id():
		_handle_tell(kind, data)
	else:
		_rpc_tell.rpc_id(peer, kind, data)

@rpc("authority", "reliable")
func _rpc_tell(kind: String, data: Dictionary) -> void:
	_handle_tell(kind, data)

func _handle_tell(kind: String, data: Dictionary) -> void:
	if Game.main:
		Game.main.on_tell(kind, data)

func broadcast_time() -> void:
	_rpc_time.rpc(Game.day(), Game.tod)

@rpc("authority", "unreliable_ordered")
func _rpc_time(d: int, t: float) -> void:
	if d == Game.day():
		Game.tod = t

func name_of(peer: int) -> String:
	return peers.get(peer, {}).get("name", "Someone")

func peer_by_name(nm: String) -> int:
	for p in peers:
		if peers[p]["name"] == nm:
			return p
	return -1

func everyone_sleeping() -> bool:
	if peers.is_empty():
		return false
	for p in peers:
		if not peers[p].get("sleep", false):
			return false
	return true

# ------------------------------------------------------------------ character data

func push_my_data() -> void:
	if Game.me.is_empty() or not Game.running:
		return
	var snap := Game.character_snapshot()
	if is_server():
		Game.world["players"][snap["name"]] = snap
	else:
		_rpc_push_data.rpc_id(1, snap)

@rpc("any_peer", "reliable")
func _rpc_push_data(data: Dictionary) -> void:
	if not is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if peers.has(id) and data.get("name", "") == peers[id]["name"]:
		Game.world["players"][data["name"]] = data

# ------------------------------------------------------------------ player state sync

func _process(delta: float) -> void:
	if not Game.running or Game.local_player == null:
		return
	_pstate_t += delta
	if _pstate_t >= 0.05:
		_pstate_t = 0.0
		var p = Game.local_player
		var st: Array = p.net_state()
		var me_id := my_id()
		if peers.has(me_id):
			peers[me_id]["zone"] = p.zone_id
			peers[me_id]["sleep"] = p.sleeping
			peers[me_id]["down"] = p.downed
			peers[me_id]["hp"] = p.hp
			peers[me_id]["mhp"] = p.max_hp()
		if is_online():
			_rpc_pstate.rpc(st)

@rpc("any_peer", "unreliable_ordered")
func _rpc_pstate(st: Array) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not peers.has(id):
		return
	peers[id]["zone"] = st[0]
	peers[id]["sleep"] = st[5]
	peers[id]["down"] = st[6]
	peers[id]["hp"] = st[7]
	peers[id]["mhp"] = st[8]
	Zones.update_remote_player(id, st)

# ------------------------------------------------------------------ chat

func send_chat(text: String) -> void:
	text = text.strip_edges().substr(0, 200)
	if text == "":
		return
	_rpc_chat.rpc(Game.profile["name"], text)

@rpc("any_peer", "call_local", "reliable")
func _rpc_chat(from_name: String, text: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	var col := Color("ffffff")
	if peers.has(id):
		col = peers[id].get("look", {}).get("shirt", Color.WHITE).lightened(0.4)
	chat_received.emit(from_name, text, col)
