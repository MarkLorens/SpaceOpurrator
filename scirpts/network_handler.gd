extends Node

signal server_started

var peer: ENetMultiplayerPeer
const IP_ADDRESS: String = "localhost"
const PORT: int = 42069
const MAX_PLAYER: int = 2

func start_server() -> void:
	peer = ENetMultiplayerPeer.new()
	var err: int = peer.create_server(PORT, MAX_PLAYER)
	if err != OK:
		push_error("Failed to create server: %d" % err)
		return
	multiplayer.multiplayer_peer = peer
	# Let the spawner know the host is up so it can spawn the host's own circle.
	server_started.emit()


func start_client() -> void:
	peer = ENetMultiplayerPeer.new()
	var err: int = peer.create_client(IP_ADDRESS, PORT)
	if err != OK:
		push_error("Failed to create client: %d" % err)
		return
	multiplayer.multiplayer_peer = peer
