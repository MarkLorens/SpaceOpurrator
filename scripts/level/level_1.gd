extends Node2D
## Level 1: the shared board both peers pan across after connecting.
## Configures this peer's synced camera for its role and wires the pause button.
## The session itself (leaving, the other player dropping, returning to the
## menu) is owned by GameState — this level only cares about gameplay + pause.

@onready var camera: Camera2D = $Camera2D
@onready var pause_menu: Control = $UI/PauseMenu
@onready var pause_button: Button = $UI/LevelUi/MarginContainer/PauseButton

func _ready() -> void:
	camera.setup(GameState.role)
	pause_button.pressed.connect(pause_menu.pause)
