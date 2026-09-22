extends Area2D

@export var btnValue: int = 0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	input_event.connect(_on_input_event)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _on_input_event(_viewport: Node, event: InputEvent, _shade_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		PuzzleSolver.build_correct_seq(btnValue)
