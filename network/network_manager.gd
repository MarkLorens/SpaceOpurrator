extends Node
## Autoload NetworkManager: TRANSPORT ONLY.
## Creates/destroys the ENetMultiplayerPeer, runs Bonjour LAN discovery, tracks
## a human-readable status string, and forwards raw connection events. It knows
## nothing about roles, levels or game flow — that lives in GameState, which
## reacts to the signals below.

const PORT := 8999
const MAX_CLIENTS := 1

signal status_changed(status_text: String)
signal lobbies_changed(lobbies: Dictionary)  # service name -> host IPv4

# Raw connection lifecycle, consumed by GameState:
signal peer_joined(id: int)     # server side: a client connected
signal peer_left(id: int)       # server side: a client disconnected
signal connected_to_host        # client side: connected to the server
signal connection_failed        # client side: could not connect
signal host_left                # client side: the server dropped

var lobbies := {}

# iOS-only native plugin (native/bonjour): mDNSResponder advertise + NWBrowser browse.
# Null in the editor / non-iOS builds, where the manual IP field is the fallback.
var _bonjour: Object
var _browsing := false

var status: String = "Disconnected":
	set(value):
		status = value
		status_changed.emit(status)

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	#multiplayer.server_disconnected.connect(_on_server_disconnected)

	if Engine.has_singleton("Bonjour"):
		_bonjour = Engine.get_singleton("Bonjour")
		start_browsing()
	else:
		set_process(false)


func _process(_delta: float) -> void:
	while _bonjour.get_pending_event_count() > 0:
		var event: Dictionary = _bonjour.pop_pending_event()
		if event.type == "found":
			lobbies[event.name] = event.host
		else:
			lobbies.erase(event.name)
		lobbies_changed.emit(lobbies)


# --- Transport actions (return true on success) ---

func host() -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		status = "Host failed (err %d)" % err
		return false

	multiplayer.multiplayer_peer = peer
	_stop_browsing()
	if _bonjour:
		_bonjour.start_advertising("", PORT)  # "" = device name.

	status = "Hosting on %s:%d — waiting for a player…" % [_get_local_ip(), PORT]
	return true


func join(address: String) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, PORT)
	if err != OK:
		status = "Join failed (err %d)" % err
		return false

	multiplayer.multiplayer_peer = peer
	_stop_browsing()
	status = "Connecting to %s..." % address
	return true


func leave() -> void:
	# Detach the peer BEFORE closing it. Closing a server while the client is
	# still the active multiplayer_peer makes Godot fire peer_disconnected
	# synchronously, mid-close — re-entering teardown while ENet is still tearing
	# itself down, which corrupts state and crashes on host exit. Holding our own
	# reference keeps the peer alive so we can close it cleanly once detached.
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	multiplayer.multiplayer_peer = null
	if peer:
		peer.close()

	if _bonjour:
		_bonjour.stop_advertising()

	status = "Disconnected"

	# Back to idle -> discover lobbies again for the menu.
	start_browsing()


## Resume LAN discovery. Safe to call repeatedly; clears any stale lobby list so
## the menu starts fresh.
func start_browsing() -> void:
	if not _bonjour or _browsing:
		return
	lobbies.clear()
	lobbies_changed.emit(lobbies)
	set_process(true)
	_bonjour.start_browsing()
	_browsing = true


func _stop_browsing() -> void:
	if not _bonjour or not _browsing:
		return
	_bonjour.stop_browsing()
	set_process(false)
	_browsing = false


# --- Raw multiplayer signals -> forwarded, role-agnostic events ---

func _on_peer_connected(id: int) -> void:
	status = "Player %d joined" % id
	peer_joined.emit(id)


func _on_peer_disconnected(id: int) -> void:
	status = "Player %d left" % id
	peer_left.emit(id)


func _on_connected_to_server() -> void:
	status = "Connected"
	connected_to_host.emit()


func _on_connection_failed() -> void:
	status = "Connection failed"
	multiplayer.multiplayer_peer = null
	connection_failed.emit()
	# Couldn't join -> back to idle, so resume discovery for the menu.
	start_browsing()


func _on_server_disconnected() -> void:
	status = "Host disconnected"
	multiplayer.multiplayer_peer = null
	host_left.emit()


## Best-effort guess at this device's Wi-Fi LAN address, so the host can read
## it off-screen instead of digging through iOS Settings > Wi-Fi.
func _get_local_ip() -> String:
	for address in IP.get_local_addresses():
		if address.begins_with("192.168.") or address.begins_with("10.") or address.begins_with("172."):
			return address
	return "<unknown IP>"
