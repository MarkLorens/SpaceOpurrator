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
var _room_name := ""  # Bonjour service name the host advertises (shown in lobbies).

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

func host(room_name: String) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		status = "Host failed (err %d)" % err
		return false

	multiplayer.multiplayer_peer = peer
	_stop_browsing()
	_room_name = room_name
	set_advertising(true)

	status = "Hosting on %s:%d — waiting for a player…" % [get_local_ip(), PORT]
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
	# leave() is often reached from INSIDE a multiplayer callback: GameState
	# resets to the menu from peer_disconnected (host vanished) or from the
	# host's "please leave" RPC. Those fire while SceneMultiplayer is mid-poll,
	# and swapping out the peer there crashes (segfault on the client when the
	# host drops). So the actual teardown waits until the poll has finished.
	_teardown_peer.call_deferred(multiplayer.multiplayer_peer)

	set_advertising(false)

	status = "Disconnected"

	# Back to idle -> discover lobbies again for the menu.
	start_browsing()


## Deferred half of leave(). Takes the peer that was active when leave() ran,
## so a host()/join() that happens before this runs is left untouched.
func _teardown_peer(peer: MultiplayerPeer) -> void:
	# Detach the peer BEFORE closing it. Closing a server while the client is
	# still the active multiplayer_peer makes Godot fire peer_disconnected
	# synchronously, mid-close — re-entering teardown while ENet is still tearing
	# itself down, which corrupts state and crashes on host exit. Holding our own
	# reference keeps the peer alive so we can close it cleanly once detached.
	if multiplayer.multiplayer_peer == peer:
		multiplayer.multiplayer_peer = null
	if peer:
		peer.close()


## Host: show/hide this room in other players' lobbies (hidden while full).
func set_advertising(on: bool) -> void:
	if not _bonjour:
		return
	if on:
		_bonjour.start_advertising(_room_name, PORT)
	else:
		_bonjour.stop_advertising()


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


## Start a brand-new search. Bonjour queries back off to minutes apart over
## time, so a search left running since app launch hears about a new room only
## if it catches the host's few announcements, which phones on Wi-Fi often miss.
## A fresh search queries right away. Call when the lobby opens.
func restart_browsing() -> void:
	_stop_browsing()
	start_browsing()


func _stop_browsing() -> void:
	if not _bonjour or not _browsing:
		return
	_bonjour.stop_browsing()
	# Drop what the old search queued but we never read, so a room that just
	# vanished can't reappear in the next search's list.
	while _bonjour.get_pending_event_count() > 0:
		_bonjour.pop_pending_event()
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
	_teardown_peer.call_deferred(multiplayer.multiplayer_peer)  # mid-poll, see leave()
	connection_failed.emit()
	# Couldn't join -> back to idle, so resume discovery for the menu.
	start_browsing()


func _on_server_disconnected() -> void:
	status = "Host disconnected"
	_teardown_peer.call_deferred(multiplayer.multiplayer_peer)  # mid-poll, see leave()
	host_left.emit()


## Best-effort guess at this device's Wi-Fi LAN address, shown on the host's
## room screen so the co-pilot can join by IP when Bonjour discovery fails.
## Prefers en0 (Wi-Fi on iOS/macOS): with mobile data on, the cellular
## interface also has a private-looking 10.x address that the co-pilot can't
## reach.
func get_local_ip() -> String:
	for iface in IP.get_local_interfaces():
		if iface.name == "en0":
			for address in iface.addresses:
				if address.is_valid_ip_address() and address.count(".") == 3 and not address.begins_with("169.254."):
					return address
	for address in IP.get_local_addresses():
		if address.begins_with("192.168.") or address.begins_with("10.") or address.begins_with("172."):
			return address
	return "<unknown IP>"
