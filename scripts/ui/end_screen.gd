extends Control
## Shown on both players when a level ends (bar full = win, bar empty = loss).
## A win with levels left offers Next Level; either player can press it.
## Its process_mode is ALWAYS (set in the scene) so the exit button works while
## the tree is paused.

@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var next_button: TextureButton = $CenterContainer/VBoxContainer/VBoxContainer/NextButton
@onready var exit_button: TextureButton = $CenterContainer/VBoxContainer/VBoxContainer/ExitButton

func _ready() -> void:
	hide()
	next_button.pressed.connect(GameState.request_next_level)
	exit_button.pressed.connect(func() -> void:
		get_tree().paused = false
		GameState.leave_game())

func show_result(won: bool) -> void:
	var has_next := won and GameState.has_next_level()
	next_button.visible = has_next
	title_label.text = "Level Cleared!" if has_next else "Victory!" if won else "Defeated"
	title_label.add_theme_color_override("font_color",
		Color(1, 0.85, 0.2) if won else Color(0.9, 0.15, 0.15))
	show()
	get_tree().paused = true
