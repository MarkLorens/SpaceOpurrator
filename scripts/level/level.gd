extends Node2D
## Shared scene for every level: the board both peers pan across. Per-level
## tuning lives in GameState.level (a LevelConfig), read by the nodes that need it.
## Configures this peer's synced camera for its role, wires the pause button and
## opens the level's tutorial card.
## The session itself (leaving, the other player dropping, returning to the
## menu) is owned by GameState — this level only cares about gameplay + pause.

@onready var camera: Camera2D = $Camera2D
@onready var pause_menu: Control = $UI/PauseMenu
@onready var pause_button: TextureButton = $UI/LevelUi/MarginContainer/PauseButton
@onready var tutorial_card: Control = $UI/TutorialCard
@onready var enemy: Node2D = $Enemy
@onready var puzzle_interface: Node2D = $PuzzleInterface
@onready var control_panel_grid: Node2D = $ControlPanelGrid

func _ready() -> void:
	camera.setup(GameState.role)
	pause_button.pressed.connect(pause_menu.pause)
	# Threat and instructions trade their two editor-placed slots on a coin flip
	# from the shared seed (re-rolled every level). Children's _ready
	# (ControlPanelGrid) has already filled in a seed for solo/editor runs.
	if GameState.slots_swapped():
		var slot := enemy.position
		enemy.position = puzzle_interface.position
		puzzle_interface.position = slot
	if GameState.level.has_next_button():
		control_panel_grid.place_next_button(puzzle_interface.global_position.x)
	# Also resets the lock a previous level may have left on.
	_lock_board(GameState.level.shows_tutorial())
	if GameState.level.shows_tutorial():
		tutorial_card.closed.connect(GameState.finish_tutorial)
		GameState.play_started.connect(_lock_board.bind(false), CONNECT_ONE_SHOT)
		tutorial_card.open(GameState.level.tutorial)

## While the tutorial card is up (until both players closed it): no panning,
## no board buttons, no pause.
func _lock_board(locked: bool) -> void:
	camera.set_process_input(not locked)
	TapArea.locked = locked
	pause_button.visible = not locked
