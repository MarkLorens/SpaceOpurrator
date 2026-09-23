extends Node2D
## Level 1: the shared board both peers pan across after connecting.
## Configures this peer's synced camera for its role and makes it current.
## Host renders screen section 0, client section 1 (only differs when
## Offset View Mode is on; otherwise both look at the same spot and stay
## in sync as either side drags).

@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	NetworkManager.level_ready()
	camera.setup(NetworkManager.role)
