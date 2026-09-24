extends Node
## Autoload GameState: owns the multiplayer SESSION.
##
## Holds the role (host/client), turns NetworkManager's raw transport events
## into game flow, and drives the scene transitions:
##   menu -> create/join -> host: name the room -> game room (wait for co-pilot)
##                       -> join: lobby -> tap a room -> game room
##   game room: both Ready, host presses Start  -> level 1
##   level won -> Next (either player)          -> next level
##   leave / drop                               -> main menu
## The UI calls host_game()/join_game()/set_ready()/start_game()/leave_game();
## everything else is reactions to NetworkManager signals.

const MAIN_MENU := "res://scenes/main_menu.tscn"
const CREATE_JOIN := "res://scenes/ui/create_join_room.tscn"
const LOBBY := "res://scenes/ui/lobby.tscn"
const GAME_ROOM := "res://scenes/ui/game_room.tscn"
## Every level shares this scene; what differs lives in LEVELS.
const LEVEL := "res://scenes/levels/level.tscn"
const LEVELS: Array[LevelConfig] = [
	preload("res://scenes/levels/level_1.tres"),
	preload("res://scenes/levels/level_2.tres"),
]

## How long the host waits for the client to disconnect before closing anyway.
const CLIENT_LEAVE_TIMEOUT := 2.0

## Fires on both peers each time a level loads.
signal level_started
## Fires on both peers whenever the room name, players or ready flags change.
signal room_changed

var role: Role.Type = Role.Type.NONE
## True once both players are connected. Gameplay waits on this.
var game_running := false
## Host-picked seed for any randomness both players must agree on (e.g. button
## layout). Re-rolled every level. 0 = not received yet.
var session_seed := 0
var level_index := 0
var level: LevelConfig:
	get: return LEVELS[level_index]
## Game room state, owned by the host and mirrored to the client.
var room_name := ""
var ready_by_peer := {}  # peer id -> bool; one entry per connected player
var in_room := false  # true from hosting/connecting until the first level loads
var _pending_host_close := false  # host is waiting for the client to leave first

func _ready() -> void:
	# Session RPCs (next level, leave) must land while the end/pause screen has the tree paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	NetworkManager.peer_joined.connect(_on_peer_joined)
	NetworkManager.peer_left.connect(_on_peer_left)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.connected_to_host.connect(_on_connected_to_host)
	NetworkManager.host_left.connect(_on_host_left)


# --- Session actions (called by the UI) ---

func host_game(new_room_name: String) -> void:
	if not NetworkManager.host(new_room_name):
		return

	_pending_host_close = false
	role = Role.Type.HOST
	room_name = new_room_name
	ready_by_peer = {1: false}
	in_room = true
	_change_scene(GAME_ROOM)


func join_game(address: String) -> void:
	if not NetworkManager.join(address):
		return

	_pending_host_close = false
	role = Role.Type.CLIENT


func leave_game() -> void:
	if role == Role.Type.HOST and _has_peers():
		_pending_host_close = true
		_request_client_leave.rpc()
		get_tree().create_timer(CLIENT_LEAVE_TIMEOUT).timeout.connect(_force_close_if_pending)
	else:
		_reset_to_menu()


## RPC the host sends to the client: "leave on your own". The client tears down
## its own connection, so the host later sees a clean, ordinary disconnect.
@rpc("authority", "call_remote", "reliable")
func _request_client_leave() -> void:
	_reset_to_menu()


# --- Game room ---

## Either player toggles their own ready flag; the host records it.
func set_ready(on: bool) -> void:
	_request_ready.rpc_id(1, on)


@rpc("any_peer", "call_local", "reliable")
func _request_ready(on: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not in_room or not ready_by_peer.has(id):
		return
	ready_by_peer[id] = on
	_sync_room.rpc(room_name, ready_by_peer)


## Host only: both players are here and ready.
func can_start() -> bool:
	return role == Role.Type.HOST and ready_by_peer.size() == 2 \
			and not ready_by_peer.values().has(false)


## Host only: starts level 1 for both players.
func start_game() -> void:
	if can_start():
		start_level(0)


@rpc("authority", "call_local", "reliable")
func _sync_room(new_room_name: String, ready_flags: Dictionary) -> void:
	room_name = new_room_name
	ready_by_peer = ready_flags
	room_changed.emit()


# --- Reactions to transport events ---

func _on_peer_joined(id: int) -> void:
	# The client moves itself to the game room on connect; the host just
	# records the new player, hides the (now full) room and shares room state.
	if role == Role.Type.HOST:
		ready_by_peer = {1: false, id: false}
		NetworkManager.set_advertising(false)
		_sync_room.rpc(room_name, ready_by_peer)


func _on_connected_to_host() -> void:
	in_room = true
	_change_scene(GAME_ROOM)


func _on_peer_left(_id: int) -> void:
	if role == Role.Type.HOST and in_room and not _pending_host_close:
		# Co-pilot left the game room: keep the room open for someone else.
		ready_by_peer = {1: false}
		NetworkManager.set_advertising(true)
		_sync_room.rpc(room_name, ready_by_peer)
	elif _pending_host_close:
		# We asked the client to leave; once none remain the server can close
		# safely (no peer attached).
		if not _has_peers():
			_reset_to_menu()
	else:
		_reset_to_menu()


func _on_host_left() -> void:
	_reset_to_menu()


func _on_connection_failed() -> void:
	role = Role.Type.NONE


# --- Levels ---

## Host only: loads level `index` on both peers with a fresh layout seed.
func start_level(index: int) -> void:
	_load_level.rpc(index, randi() | 1)  # seed never 0


func has_next_level() -> bool:
	return level_index + 1 < LEVELS.size()


## Either player, after a win. The host decides.
func request_next_level() -> void:
	_request_next_level.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _request_next_level() -> void:
	# game_running flips back on in _load_level, so a double press is ignored.
	if not game_running and has_next_level():
		start_level(level_index + 1)


@rpc("authority", "call_local", "reliable")
func _load_level(index: int, seed_value: int) -> void:
	level_index = index
	session_seed = seed_value
	in_room = false
	game_running = true
	get_tree().paused = false  # the end screen paused the previous level
	_change_scene(LEVEL)
	level_started.emit()


# --- Helpers ---


func _force_close_if_pending() -> void:
	# The client never disconnected (crashed/froze) — close anyway so the host
	# isn't stuck on the pause menu forever.
	if _pending_host_close:
		_reset_to_menu()


func _has_peers() -> bool:
	return multiplayer.multiplayer_peer != null and not multiplayer.get_peers().is_empty()


func _reset_to_menu() -> void:
	_pending_host_close = false
	game_running = false
	session_seed = 0
	level_index = 0
	room_name = ""
	ready_by_peer = {}
	in_room = false

	NetworkManager.leave()
	role = Role.Type.NONE
	get_tree().paused = false  # in case we were paused when the session ended
	_change_scene(MAIN_MENU)


func _change_scene(uid: String) -> void:
	get_tree().change_scene_to_file(uid)
