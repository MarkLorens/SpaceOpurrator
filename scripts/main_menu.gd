extends Control

@onready var connection_panel: VBoxContainer = $ConnectionPanel
@onready var ip_edit: LineEdit = $ConnectionPanel/IPEdit
@onready var lobby_list: ItemList = $ConnectionPanel/LobbyList
@onready var host_button: Button = $ConnectionPanel/HostButton
@onready var join_button: Button = $ConnectionPanel/JoinButton
@onready var status_label: Label = $StatusLabel

func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	lobby_list.item_selected.connect(_on_lobby_selected)
	if Engine.has_singleton("GameCenterKit"):
		var game_center := Engine.get_singleton("GameCenterKit")
		Engine.get_singleton("GameCenterKit")
		game_center.authenticated.connect(_on_authenticated)
		game_center.authenticate()

	NetworkManager.lobbies_changed.connect(_on_lobbies_changed)
	NetworkManager.status_changed.connect(_on_status_changed)
	
	#offset_checkbox.button_pressed = NetworkManager.offset_mode
	_on_status_changed(NetworkManager.status)

func _on_authenticated(ok: bool, error: String) -> void:
	print("Game Center authenticated: ", ok, " ", error)

func _on_host_pressed() -> void:
	GameState.host_game()


func _on_join_pressed() -> void:
	var address := ip_edit.text.strip_edges()
	GameState.join_game(address if not address.is_empty() else "127.0.0.1")


func _on_lobbies_changed(lobbies: Dictionary) -> void:
	lobby_list.clear()
	for lobby_name in lobbies:
		lobby_list.set_item_metadata(lobby_list.add_item(lobby_name), lobbies[lobby_name])


func _on_lobby_selected(index: int) -> void:
	GameState.join_game(lobby_list.get_item_metadata(index))


func _on_status_changed(status: String) -> void:
	status_label.text = status
	
