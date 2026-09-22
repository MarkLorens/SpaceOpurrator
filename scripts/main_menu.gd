extends Control
## Main menu: Host/Join UI. Kicks off NetworkManager and hands off to the
## world scene immediately, same as the connection flow always did.

@onready var ip_edit: LineEdit = $ConnectionPanel/IPEdit
@onready var lobby_list: ItemList = $ConnectionPanel/LobbyList
@onready var host_button: Button = $ConnectionPanel/HostButton
@onready var join_button: Button = $ConnectionPanel/JoinButton


func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	lobby_list.item_selected.connect(_on_lobby_selected)
	NetworkManager.lobbies_changed.connect(_on_lobbies_changed)


func _on_host_pressed() -> void:
	NetworkManager.host_game()
	get_tree().change_scene_to_file("res://scenes/world.tscn")


func _on_join_pressed() -> void:
	var address := ip_edit.text.strip_edges()
	_join(address if not address.is_empty() else "127.0.0.1")


func _on_lobbies_changed(lobbies: Dictionary) -> void:
	lobby_list.clear()
	for lobby_name in lobbies:
		lobby_list.set_item_metadata(lobby_list.add_item(lobby_name), lobbies[lobby_name])


func _on_lobby_selected(index: int) -> void:
	_join(lobby_list.get_item_metadata(index))


func _join(address: String) -> void:
	NetworkManager.join_game(address)
	get_tree().change_scene_to_file("res://scenes/world.tscn")
