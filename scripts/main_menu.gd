extends Control

@onready var play_button: TextureButton = $CenterContainer/VBoxContainer/PlayButton

func _ready() -> void:
	play_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(GameState.CREATE_JOIN))
	if Engine.has_singleton("GameCenterKit"):
		var game_center := Engine.get_singleton("GameCenterKit")
		game_center.authenticated.connect(_on_authenticated)
		game_center.authenticate()

func _on_authenticated(ok: bool, error: String) -> void:
	print("Game Center authenticated: ", ok, " ", error)
