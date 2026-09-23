extends Control
## Host waiting room. GameState brings us here after Host is pressed and moves
## us on to the level once a player joins — so this screen only shows the
## connection status and offers a Cancel that ends the session.

@onready var status_label: Label = $CenterContainer/VBoxContainer/StatusLabel
@onready var cancel_button: Button = $CenterContainer/VBoxContainer/CancelButton

func _ready() -> void:
	NetworkManager.status_changed.connect(_on_status_changed)
	cancel_button.pressed.connect(_on_cancel)
	_on_status_changed(NetworkManager.status)

func _on_status_changed(text: String) -> void:
	status_label.text = text

func _on_cancel() -> void:
	GameState.leave_game()
