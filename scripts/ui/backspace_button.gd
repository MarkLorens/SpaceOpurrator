extends TapArea

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pressed.connect(AudioManager.play_click)
	pressed.connect(Haptics.impact_light)
	tapped.connect(PuzzleSolver.remove_last_press)
