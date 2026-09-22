extends Control

@onready var progressBar: Label = $Label
@onready var solve_button: Button = $"../SolveButton"

@export var endTarget: float = 100.0
@export var startProgress: float = 70.0

var trackProgress: float

func _ready() -> void:
	solve_button.pressed.connect(_on_solve_pressed)
	trackProgress = startProgress

func _process(delta: float) -> void:
	trackProgress -= 1 * delta
	progressBar.text = "%.2f" %trackProgress

func _on_solve_pressed() -> void:
	trackProgress += 10
