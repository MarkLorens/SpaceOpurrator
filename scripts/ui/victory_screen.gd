extends Control
## Shown on both players when the progress bar is filled. Its process_mode is
## ALWAYS (set in the scene) so the exit button works while the tree is paused.

@onready var exit_button: Button = $CenterContainer/VBoxContainer/ExitButton

func _ready() -> void:
	hide()
	exit_button.pressed.connect(func() -> void:
		get_tree().paused = false
		GameState.leave_game())

func show_victory() -> void:
	show()
	get_tree().paused = true
