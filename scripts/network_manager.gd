extends Node
## Autoload singleton (NetworkManager).
## Owns the ENetMultiplayerPeer connection for a simple 2-player LAN session
## and exposes a human-readable status string for the UI to display.

const PORT := 8999
const MAX_CLIENTS := 1  # Total session size is host + 1 client = 2 players.

enum Role { NONE, HOST, CLIENT }

signal status_changed(status_text: String)
signal lobbies_changed(lobbies: Dictionary)  # service name -> host IPv4

var role: Role = Role.NONE
var lobbies := {}
# iOS-only native plugin (native/bonjour): mDNSResponder advertise + NWBrowser browse.
# Null in the editor / non-iOS builds, where the manual IP field is the fallback.
var _bonjour: Object

var status: String = "Disconnected":
	set(value):
		status = value
		status_changed.emit(status)


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	if Engine.has_singleton("Bonjour"):
		_bonjour = Engine.get_singleton("Bonjour")
		_bonjour.start_browsing()
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


func host_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		status = "Host failed (err %d)" % err
		return
	multiplayer.multiplayer_peer = peer
	role = Role.HOST
	_stop_browsing()
	if _bonjour:
		_bonjour.start_advertising("", PORT)  # "" = device name.
	status = "Hosting on %s:%d" % [_get_local_ip(), PORT]


func join_game(address: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, PORT)
	if err != OK:
		status = "Join failed (err %d)" % err
		return
	multiplayer.multiplayer_peer = peer
	role = Role.CLIENT
	_stop_browsing()
	status = "Connecting to %s..." % address


func disconnect_game() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	role = Role.NONE
	if _bonjour:
		_bonjour.stop_advertising()
	status = "Disconnected"


func _stop_browsing() -> void:
	if _bonjour:
		_bonjour.stop_browsing()
		set_process(false)


func _on_peer_connected(id: int) -> void:
	if role == Role.HOST:
		status = "Connected as Host (peer %d joined)" % id


func _on_peer_disconnected(id: int) -> void:
	status = "Peer %d disconnected" % id


func _on_connected_to_server() -> void:
	status = "Connected as Client"


func _on_connection_failed() -> void:
	status = "Connection failed"
	multiplayer.multiplayer_peer = null
	role = Role.NONE


func _on_server_disconnected() -> void:
	status = "Host disconnected"
	multiplayer.multiplayer_peer = null
	role = Role.NONE


## Best-effort guess at this device's Wi-Fi LAN address, so the host can read
## it off-screen instead of digging through iOS Settings > Wi-Fi.
func _get_local_ip() -> String:
	for address in IP.get_local_addresses():
		if address.begins_with("192.168.") or address.begins_with("10.") or address.begins_with("172."):
			return address
	return "<unknown IP>"
