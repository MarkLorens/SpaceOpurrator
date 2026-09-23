extends Control
## Progress bar + puzzle timer. The host runs the numbers and streams the bar
## value to the client; the client's bar only displays it.

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var solve_button: Button = $"../SolveButton"

# Only the host's values matter in a networked game.
@export var endTarget: float = 100.0
@export var startProgress: float = 70.0
@export var drainPerSecond: float = 1.0
@export var solveReward: float = 10.0
## Seconds the player has to solve the current puzzle before losing timeoutPenalty.
@export var puzzleTime: float = 10.0
@export var timeoutPenalty: float = 10.0

var puzzleTimeLeft: float

func _ready() -> void:
	solve_button.pressed.connect(_on_solve_pressed)
	progress_bar.max_value = endTarget
	progress_bar.value = startProgress
	puzzleTimeLeft = puzzleTime

func _process(delta: float) -> void:
	if not GameState.game_running or not multiplayer.is_server():
		return
	# ProgressBar clamps value to [0, max_value] itself.
	progress_bar.value -= drainPerSecond * delta
	puzzleTimeLeft -= delta
	if puzzleTimeLeft <= 0.0:
		progress_bar.value -= timeoutPenalty
		PuzzleSolver.new_puzzle()
		puzzleTimeLeft = puzzleTime
	# ponytail: sends every frame; throttle to a fixed tick if bandwidth ever matters.
	_sync_progress.rpc(progress_bar.value, endTarget)

func _on_solve_pressed() -> void:
	_request_solve.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func _request_solve() -> void:
	if not GameState.game_running:
		return
	if PuzzleSolver.solve_puzzle():
		progress_bar.value += solveReward
		puzzleTimeLeft = puzzleTime

@rpc("authority", "call_remote", "unreliable_ordered")
func _sync_progress(value: float, max_value: float) -> void:
	progress_bar.max_value = max_value
	progress_bar.value = value
