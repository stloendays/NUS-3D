extends Node
class_name NUS3DNetworkSession
## Optional ENet LAN/direct-IP session. Host relays sanitized poses.
## Personal coursework, XP, coins, login credentials and mailbox NEVER traverse RPC.
signal changed
signal notice(message: String)

enum State { OFFLINE, HOST, CONNECTING, CLIENT }
const PORT: int = 24568
const PROTOCOL: int = 1
const MAX_PLAYERS: int = 4
const SEND_HZ: float = 15.0
const TIMEOUT: float = 10.0
const MAX_SPEED: float = 65.0
const MAX_POSITION: float = 2000.0

var state: int = State.OFFLINE
var last_error: String = ""
var roster: Dictionary = {}
var _peer: ENetMultiplayerPeer
var _game: Node3D
var _remotes: NUS3DRemotePlayers
var _elapsed: float = 0.0
var _timeout: float = 0.0
var _last_pose: Dictionary = {}
var _last_received_ms: Dictionary = {}
var _last_sent_pose: Vector3 = Vector3.ZERO
var _host_weather: Dictionary = {}


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    multiplayer.peer_connected.connect(_peer_connected)
    multiplayer.peer_disconnected.connect(_peer_disconnected)
    multiplayer.connected_to_server.connect(_connected)
    multiplayer.connection_failed.connect(_connection_failed)
    multiplayer.server_disconnected.connect(_server_disconnected)


func bind_game(game: Node3D) -> void:
    _game = game
    if not is_instance_valid(_remotes):
        _remotes = NUS3DRemotePlayers.new()
        _remotes.name = "RemotePlayers"
        game.add_child(_remotes)


func is_online() -> bool:
    return state == State.HOST or state == State.CLIENT


func player_count() -> int:
    return roster.size()


func _version() -> String:
    return str(ProjectSettings.get_setting("application/config/version", "0.1.0"))


func host_room(name: String, port: int = PORT) -> String:
    leave_room()
    if port < 1024 or port > 65535:
        return "Invalid port"
    _peer = ENetMultiplayerPeer.new()
    var result: Error = _peer.create_server(port, MAX_PLAYERS)
    if result != OK:
        _peer = null
        return "Cannot host UDP port %d (error %d)" % [port, result]
    multiplayer.multiplayer_peer = _peer
    state = State.HOST
    roster = {1: _clean_name(name)}
    _last_pose.clear()
    _host_weather = _world_snapshot()
    changed.emit()
    notice.emit("Hosting LAN room on UDP %d" % port)
    return ""


func join_room(name: String, address: String, port: int = PORT) -> String:
    leave_room()
    var host: String = address.strip_edges()
    if host.is_empty() or host.length() > 253 or host.contains("/") or host.contains(" ") or port < 1024 or port > 65535:
        return "Enter a valid LAN IP or hostname and UDP port"
    _peer = ENetMultiplayerPeer.new()
    var result: Error = _peer.create_client(host, port)
    if result != OK:
        _peer = null
        return "Cannot connect (error %d)" % result
    multiplayer.multiplayer_peer = _peer
    state = State.CONNECTING
    roster.clear()
    _timeout = TIMEOUT
    _pending_name = _clean_name(name)
    changed.emit()
    return ""


var _pending_name: String = "Player"


func leave_room() -> void:
    if _peer != null:
        _peer.close()
    multiplayer.multiplayer_peer = null
    _peer = null
    state = State.OFFLINE
    roster.clear()
    _last_pose.clear()
    _last_received_ms.clear()
    _host_weather.clear()
    _elapsed = 0.0
    if is_instance_valid(_remotes):
        _remotes.clear_players()
    changed.emit()


func _clean_name(raw: String) -> String:
    var safe: String = raw.strip_edges().substr(0, 20)
    for symbol in ["\n", "\r", "\t", "[", "]"]:
        safe = safe.replace(symbol, "")
    return "Player" if safe.is_empty() else safe


func _peer_connected(_id: int) -> void:
    pass


func _peer_disconnected(peer_id: int) -> void:
    if state != State.HOST:
        return
    roster.erase(peer_id)
    _last_pose.erase(peer_id)
    _last_received_ms.erase(peer_id)
    if is_instance_valid(_remotes):
        _remotes.remove_player(peer_id)
    _remove_remote.rpc(peer_id)
    changed.emit()


func _connected() -> void:
    _hello.rpc_id(1, PROTOCOL, _version(), _pending_name)


func _connection_failed() -> void:
    last_error = "Connection failed"
    leave_room()
    notice.emit(last_error)


func _server_disconnected() -> void:
    leave_room()
    notice.emit("Host disconnected. Offline mode restored.")


@rpc("any_peer", "call_remote", "reliable")
func _hello(protocol: int, version: String, player_name: String) -> void:
    if state != State.HOST:
        return
    var sender: int = multiplayer.get_remote_sender_id()
    if protocol != PROTOCOL or version != _version() or roster.size() >= MAX_PLAYERS:
        _reject.rpc_id(sender, "Room full or incompatible game/protocol version")
        return
    var cleaned: String = _clean_name(player_name)
    roster[sender] = cleaned
    _welcome.rpc_id(sender, roster, _world_snapshot())
    _add_remote.rpc(sender, cleaned)
    _sync_remote_roster()
    changed.emit()


func _sync_remote_roster() -> void:
    for id in roster:
        if int(id) != 1:
            for other_id in roster:
                if int(other_id) != 1 and int(other_id) != int(id):
                    _add_remote.rpc_id(int(other_id), int(id), str(roster[id]))
    if is_instance_valid(_remotes):
        for id in roster:
            if int(id) != 1:
                _remotes.add_player(int(id), str(roster[id]))


@rpc("authority", "call_remote", "reliable")
func _reject(reason: String) -> void:
    last_error = reason
    leave_room()
    notice.emit(reason)


@rpc("authority", "call_remote", "reliable")
func _welcome(players: Dictionary, world: Dictionary) -> void:
    if state != State.CONNECTING:
        return
    roster = players
    state = State.CLIENT
    _host_weather = world
    _apply_world(world)
    for id in roster:
        if int(id) != multiplayer.get_unique_id() and is_instance_valid(_remotes):
            _remotes.add_player(int(id), str(roster[id]))
    changed.emit()
    notice.emit("Joined room: %d players" % roster.size())


@rpc("authority", "call_remote", "reliable")
func _add_remote(peer_id: int, player_name: String) -> void:
    if state != State.CLIENT:
        return
    roster[peer_id] = _clean_name(player_name)
    if peer_id != multiplayer.get_unique_id() and is_instance_valid(_remotes):
        _remotes.add_player(peer_id, roster[peer_id])
    changed.emit()


@rpc("authority", "call_remote", "reliable")
func _remove_remote(peer_id: int) -> void:
    if state != State.CLIENT:
        return
    roster.erase(peer_id)
    if is_instance_valid(_remotes):
        _remotes.remove_player(peer_id)
    changed.emit()


func _valid_pose(p: Vector3, yaw: float) -> bool:
    return is_finite(p.x) and is_finite(p.y) and is_finite(p.z) and is_finite(yaw) \
        and absf(p.x) <= MAX_POSITION and absf(p.y) <= MAX_POSITION and absf(p.z) <= MAX_POSITION \
        and absf(yaw) <= TAU * 100.0


func _accept_pose(peer_id: int, p: Vector3, yaw: float) -> bool:
    if not _valid_pose(p, yaw):
        return false
    var now: int = Time.get_ticks_msec()
    if _last_pose.has(peer_id):
        var last: Vector3 = _last_pose[peer_id]
        var previous_ms: int = int(_last_received_ms.get(peer_id, now))
        var elapsed_s: float = maxf(0.05, float(now - previous_ms) * 0.001)
        if p.distance_to(last) > MAX_SPEED * elapsed_s + 4.0:
            return false
    _last_pose[peer_id] = p
    _last_received_ms[peer_id] = now
    return true


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _submit_pose(p: Vector3, yaw: float) -> void:
    if state != State.HOST:
        return
    var sender: int = multiplayer.get_remote_sender_id()
    if not roster.has(sender) or not _accept_pose(sender, p, yaw):
        return
    if is_instance_valid(_remotes):
        _remotes.update_pose(sender, p, yaw)
    for other in roster:
        if int(other) != 1 and int(other) != sender:
            _receive_pose.rpc_id(int(other), sender, p, yaw)


@rpc("authority", "call_remote", "unreliable_ordered")
func _receive_pose(peer_id: int, p: Vector3, yaw: float) -> void:
    if state != State.CLIENT or peer_id == multiplayer.get_unique_id() or not roster.has(peer_id):
        return
    if _valid_pose(p, yaw) and is_instance_valid(_remotes):
        _remotes.update_pose(peer_id, p, yaw)


func _world_snapshot() -> Dictionary:
    if not is_instance_valid(_game):
        return {"weather": 0, "lighting": 0}
    var weather: UTownWeather = _game.get_node_or_null("Weather") as UTownWeather
    var world: UTownWorld = _game.get_node_or_null("World") as UTownWorld
    return {"weather": weather.mode if weather != null else 0,
        "lighting": world.lighting_mode if world != null else 0}


func _apply_world(snapshot: Dictionary) -> void:
    if not is_instance_valid(_game):
        return
    var world: UTownWorld = _game.get_node_or_null("World") as UTownWorld
    var weather: UTownWeather = _game.get_node_or_null("Weather") as UTownWeather
    if world != null:
        world.set_lighting_mode(clampi(int(snapshot.get("lighting", 0)), 0, 3))
    if weather != null:
        weather.set_mode(clampi(int(snapshot.get("weather", 0)), 0, 4))


@rpc("authority", "call_remote", "unreliable_ordered")
func _receive_world(snapshot: Dictionary) -> void:
    if state == State.CLIENT:
        _host_weather = snapshot
        _apply_world(snapshot)


func _process(delta: float) -> void:
    if state == State.CONNECTING:
        _timeout -= delta
        if _timeout <= 0.0:
            last_error = "Connection timed out"
            leave_room()
            notice.emit(last_error)
        return
    if not is_online() or not is_instance_valid(_game) or get_tree().paused:
        return
    _elapsed += delta
    if _elapsed < 1.0 / SEND_HZ:
        return
    _elapsed = 0.0
    var player: UTownPlayer = _game.get_node_or_null("Player") as UTownPlayer
    if player == null:
        return
    if state == State.HOST:
        if _accept_pose(1, player.global_position, player.rotation.y):
            for id in roster:
                if int(id) != 1:
                    _receive_pose.rpc_id(int(id), 1, player.global_position, player.rotation.y)
        var snapshot: Dictionary = _world_snapshot()
        if snapshot != _host_weather:
            _host_weather = snapshot
            _receive_world.rpc(snapshot)
    elif state == State.CLIENT:
        _submit_pose.rpc_id(1, player.global_position, player.rotation.y)
        # Host-only environment; client hotkeys can be handled locally and
        # corrected here without persisting any host state to account saves.
        if _world_snapshot() != _host_weather:
            _apply_world(_host_weather)
