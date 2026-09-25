extends Node2D
## Shared scene for every level: the board both peers pan across. Per-level
## tuning lives in GameState.level (a LevelConfig), read by the nodes that need it.
## Configures this peer's synced camera for its role and wires the pause button.
## The session itself (leaving, the other player dropping, returning to the
## menu) is owned by GameState — this level only cares about gameplay + pause.

@onready var camera: Camera2D = $Camera2D
@onready var pause_menu: Control = $UI/PauseMenu
@onready var pause_button: TextureButton = $UI/LevelUi/MarginContainer/PauseButton
@onready var enemy: Node2D = $Enemy
@onready var puzzle_interface: Node2D = $PuzzleInterface

func _ready() -> void:
	camera.setup(GameState.role)
	pause_button.pressed.connect(pause_menu.pause)
	# Threat and instructions trade their two editor-placed slots on a coin flip
	# from the shared seed (re-rolled every level), so both peers agree. Bit 0 is
	# always 1, so use bit 1. Children's _ready (ControlPanelGrid) has already
	# filled in a seed for solo/editor runs.
	if GameState.session_seed & 2:
		var slot := enemy.position
		enemy.position = puzzle_interface.position
		puzzle_interface.position = slot
