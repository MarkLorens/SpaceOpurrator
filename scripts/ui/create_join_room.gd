extends Control
## Host or join. Host asks for a room name first, then GameState opens the
## game room; Join goes to the lobby.

@onready var choice: VBoxContainer = $CenterContainer/VBoxContainer
@onready var host_button: Button = $CenterContainer/VBoxContainer/HBoxContainer/HostButton
@onready var join_button: Button = $CenterContainer/VBoxContainer/HBoxContainer/JoinButton
@onready var name_panel: VBoxContainer = $CenterContainer/NamePanel
@onready var name_edit: LineEdit = $CenterContainer/NamePanel/NameEdit
@onready var create_button: Button = $CenterContainer/NamePanel/CreateButton
@onready var cancel_button: Button = $CancelButton

func _ready() -> void:
	name_panel.hide()
	host_button.pressed.connect(_show_name_prompt)
	join_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(GameState.LOBBY))
	name_edit.text_changed.connect(func(_t: String) -> void: _update_create())
	name_edit.text_submitted.connect(func(_t: String) -> void: _create())
	create_button.pressed.connect(_create)
	cancel_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(GameState.MAIN_MENU))

func _show_name_prompt() -> void:
	choice.hide()
	name_panel.show()
	_update_create()
	name_edit.grab_focus()

func _update_create() -> void:
	create_button.disabled = name_edit.text.strip_edges().is_empty()

func _create() -> void:
	if not create_button.disabled:
		GameState.host_game(name_edit.text.strip_edges())
