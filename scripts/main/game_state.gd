extends Node
## Autoload GameState: owns the multiplayer SESSION.
##
## Holds the role (host/client), turns NetworkManager's raw transport events
## into game flow, and drives the scene transitions:
##   host  -> loading screen -> (player joins) -> level 1
##   join  -> (host's _load_level RPC)         -> level 1
##   level won -> Next (either player)         -> next level
##   leave / drop                              -> main menu
## The UI calls host_game()/join_game()/leave_game(); everything else is
## reactions to NetworkManager signals.

const MAIN_MENU := "res://scenes/main_menu.tscn"  # scenes/main.tscn
const LOADING := "res://scenes/loading_screen.tscn"     # scenes/loading_screen.tscn
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

var role: Role.Type = Role.Type.NONE
## True once both players are connected. Gameplay waits on this.
var game_running := false
## Host-picked seed for any randomness both players must agree on (e.g. button
## layout). Re-rolled every level. 0 = not received yet.
var session_seed := 0
var level_index := 0
var level: LevelConfig:
	get: return LEVELS[level_index]
var _pending_host_close := false  # host is waiting for the client to leave first

func _ready() -> void:
	# Session RPCs (next level, leave) must land while the end/pause screen has the tree paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	NetworkManager.peer_joined.connect(_on_peer_joined)
	NetworkManager.peer_left.connect(_on_peer_left)
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
	# The client just waits: it moves when _load_level arrives.
	if role == Role.Type.HOST:
		start_level(0)


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

	NetworkManager.leave()
	role = Role.Type.NONE
	get_tree().paused = false  # in case we were paused when the session ended
	_change_scene(MAIN_MENU)


func _change_scene(uid: String) -> void:
	get_tree().change_scene_to_file(uid)
