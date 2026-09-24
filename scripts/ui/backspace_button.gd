extends TapArea

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	tapped.connect(PuzzleSolver.remove_last_press)
