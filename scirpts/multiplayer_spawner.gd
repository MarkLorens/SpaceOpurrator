extends MultiplayerSpawner

@export var network_player: PackedScene

var _spawn_count: int = 0

func _ready() -> void:
	# Remote peers connecting -> spawn a circle for them.
	multiplayer.peer_connected.connect(spawn_player)
	# The host connecting to itself -> spawn the host's own circle.
	NetworkHandler.server_started.connect(_on_server_started)

func _on_server_started() -> void:
	spawn_player(multiplayer.get_unique_id())

func spawn_player(id: int) -> void:
	# Only the server owns spawning; clients receive the circles via replication.
	if not multiplayer.is_server(): return

	var player: Node = network_player.instantiate()
	player.name = str(id)
	# Line the circles up along the strip so they don't stack on spawn.
	player.position = Vector2(500.0 + _spawn_count * 200.0, 300.0)
	_spawn_count += 1

	get_node(spawn_path).add_child(player, true)
