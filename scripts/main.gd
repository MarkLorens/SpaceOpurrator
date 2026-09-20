extends Control
## Main scene controller: wires the Host/Join UI, connection status display,
## and the Offset Mode toggle to NetworkManager and the shared world's camera.

@onready var connection_panel: VBoxContainer = $UI/ConnectionPanel
@onready var ip_edit: LineEdit = $UI/ConnectionPanel/IPEdit
@onready var lobby_list: ItemList = $UI/ConnectionPanel/LobbyList
@onready var host_button: Button = $UI/ConnectionPanel/HostButton
@onready var join_button: Button = $UI/ConnectionPanel/JoinButton
@onready var status_label: Label = $UI/StatusLabel
@onready var offset_checkbox: CheckBox = $UI/OffsetModeCheckBox
@onready var camera: Camera2D = $World/Camera2D


func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	lobby_list.item_selected.connect(_on_lobby_selected)
	NetworkManager.lobbies_changed.connect(_on_lobbies_changed)
	offset_checkbox.toggled.connect(_on_offset_toggled)
	NetworkManager.status_changed.connect(_on_status_changed)
	_on_status_changed(NetworkManager.status)


func _on_host_pressed() -> void:
	NetworkManager.host_game()
	camera.set_screen_index(0)
	connection_panel.visible = false


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
	camera.set_screen_index(1)
	connection_panel.visible = false


func _on_status_changed(status: String) -> void:
	status_label.text = status


func _on_offset_toggled(enabled: bool) -> void:
	camera.set_offset_mode(enabled)
