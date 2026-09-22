extends Control

@export_file var LEVEL_1_PATH

@onready var connection_panel: VBoxContainer = $UI/ConnectionPanel
@onready var ip_edit: LineEdit = $UI/ConnectionPanel/IPEdit
@onready var lobby_list: ItemList = $UI/ConnectionPanel/LobbyList
@onready var host_button: Button = $UI/ConnectionPanel/HostButton
@onready var join_button: Button = $UI/ConnectionPanel/JoinButton
@onready var status_label: Label = $UI/StatusLabel

func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	lobby_list.item_selected.connect(_on_lobby_selected)

	NetworkManager.lobbies_changed.connect(_on_lobbies_changed)
	NetworkManager.status_changed.connect(_on_status_changed)
	NetworkManager.level_should_start.connect(_on_level_should_start)
	
	#offset_checkbox.button_pressed = NetworkManager.offset_mode
	_on_status_changed(NetworkManager.status)


func _on_host_pressed() -> void:
	NetworkManager.host_game()


func _on_join_pressed() -> void:
	var address := ip_edit.text.strip_edges()
	NetworkManager.join_game(address if not address.is_empty() else "127.0.0.1")


func _on_lobbies_changed(lobbies: Dictionary) -> void:
	lobby_list.clear()
	for lobby_name in lobbies:
		lobby_list.set_item_metadata(lobby_list.add_item(lobby_name), lobbies[lobby_name])


func _on_lobby_selected(index: int) -> void:
	NetworkManager.join_game(lobby_list.get_item_metadata(index))


func _on_status_changed(status: String) -> void:
	status_label.text = status
	

func _on_level_should_start() -> void:
	get_tree().change_scene_to_file(LEVEL_1_PATH)
