extends Node
## Autoload GameState: owns the multiplayer SESSION.
##
## Holds the role (host/client), turns NetworkManager's raw transport events
## into game flow, and drives the scene transitions:
##   host  -> loading screen -> (player joins) -> level
##   join  -> (connected)    -> level
##   leave / drop            -> main menu
## The UI calls host_game()/join_game()/leave_game(); everything else is
## reactions to NetworkManager signals.

const MAIN_MENU := "res://scenes/main_menu.tscn"  # scenes/main.tscn
const LOADING := "res://scenes/loading_screen.tscn"     # scenes/loading_screen.tscn
const LEVEL_1 := "res://scenes/levels/level_1.tscn"    # scenes/levels/level_1.tscn

## How long the host waits for the client to disconnect before closing anyway.
const CLIENT_LEAVE_TIMEOUT := 2.0

signal game_started
## Fires on the client when the host's session_seed arrives.
signal session_seed_received

var role: Role.Type = Role.Type.NONE
## True once both players are connected. Gameplay waits on this.
var game_running := false
## Host-picked seed for any randomness both players must agree on (e.g. button
## layout). 0 = not received yet.
var session_seed := 0
var _pending_host_close := false  # host is waiting for the client to leave first

func _ready() -> void:
	NetworkManager.peer_joined.connect(_on_peer_joined)
	NetworkManager.peer_left.connect(_on_peer_left)
	NetworkManager.connected_to_host.connect(_on_connected_to_host)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.host_left.connect(_on_host_left)


# --- Session actions (called by the UI) ---

func host_game() -> void:
	if not NetworkManager.host():
		return

	_pending_host_close = false
	role = Role.Type.HOST
	_change_scene(LOADING)


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


# --- Reactions to transport events ---

func _on_peer_joined(_id: int) -> void:
	if role == Role.Type.HOST:
		_start_game()


func _on_connected_to_host() -> void:
	_start_game()


func _on_peer_left(_id: int) -> void:
	if _pending_host_close :
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


# --- Helpers ---

func _start_game() -> void:
	game_running = true
	if role == Role.Type.HOST:
		session_seed = randi() | 1  # never 0
		_set_session_seed.rpc(session_seed)
	_change_scene(LEVEL_1)
	game_started.emit()


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

	NetworkManager.leave()
	role = Role.Type.NONE
	get_tree().paused = false  # in case we were paused when the session ended
	_change_scene(MAIN_MENU)


func _change_scene(uid: String) -> void:
	get_tree().change_scene_to_file(uid)


@rpc("authority", "call_remote", "reliable")
func _set_session_seed(value: int) -> void:
	session_seed = value
	session_seed_received.emit()
