extends Control

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var solve_button: Button = $"../SolveButton"

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
	# ProgressBar clamps value to [0, max_value] itself.
	progress_bar.value -= drainPerSecond * delta
	puzzleTimeLeft -= delta
	if puzzleTimeLeft <= 0.0:
		progress_bar.value -= timeoutPenalty
		PuzzleSolver.new_puzzle()
		puzzleTimeLeft = puzzleTime

func _on_solve_pressed() -> void:
	if PuzzleSolver.solve_puzzle():
		progress_bar.value += solveReward
		puzzleTimeLeft = puzzleTime
