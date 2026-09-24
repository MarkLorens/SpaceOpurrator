extends Control
## Host or join. Host asks for a room name first, then GameState opens the
## game room; Join goes to the lobby.

@export_file var HOST_BACKGROUND 
@export_file var CLIENT_BACKGROUND 

@onready var choice: VBoxContainer = $CenterContainer/VBoxContainer
@onready var host_button: TextureButton = $CenterContainer/VBoxContainer/HBoxContainer/HostButton
@onready var join_button: TextureButton = $CenterContainer/VBoxContainer/HBoxContainer/JoinButton
@onready var name_panel: VBoxContainer = $CenterContainer/NamePanel
@onready var name_edit: LineEdit = $CenterContainer/NamePanel/NameEdit
@onready var create_button: TextureButton = $CenterContainer/NamePanel/CreateButton
@onready var cancel_button: TextureButton = $CancelButton
@onready var background : TextureRect = $Background

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
	
	background.texture = load(HOST_BACKGROUND)
	
	_update_create()
	name_edit.grab_focus()

func _update_create() -> void:
	create_button.disabled = name_edit.text.strip_edges().is_empty()

func _create() -> void:
	if not create_button.disabled:
		GameState.host_game(name_edit.text.strip_edges())
