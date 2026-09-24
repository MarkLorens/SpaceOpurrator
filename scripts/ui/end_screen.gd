extends Control
## Shown on both players when the game ends (bar full = win, bar empty = loss).
## Its process_mode is ALWAYS (set in the scene) so the exit button works while
## the tree is paused.

@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var exit_button: Button = $CenterContainer/VBoxContainer/ExitButton

func _ready() -> void:
	hide()
	exit_button.pressed.connect(func() -> void:
		get_tree().paused = false
		GameState.leave_game())

func show_result(won: bool) -> void:
	title_label.text = "Victory!" if won else "Defeated"
	title_label.add_theme_color_override("font_color",
		Color(1, 0.85, 0.2) if won else Color(0.9, 0.15, 0.15))
	show()
	get_tree().paused = true
