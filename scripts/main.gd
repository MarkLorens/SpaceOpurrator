extends Control
## Main scene controller: wires the Host/Join UI, connection status display,
## and the Offset Mode toggle to NetworkManager and the shared world's camera.

@onready var connection_panel: VBoxContainer = $UI/ConnectionPanel
@onready var ip_edit: LineEdit = $UI/ConnectionPanel/IPEdit
@onready var host_button: Button = $UI/ConnectionPanel/HostButton
@onready var join_button: Button = $UI/ConnectionPanel/JoinButton
@onready var status_label: Label = $UI/StatusLabel
@onready var offset_checkbox: CheckBox = $UI/OffsetModeCheckBox
@onready var camera: Camera2D = $World/Camera2D


func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	offset_checkbox.toggled.connect(_on_offset_toggled)
	NetworkManager.status_changed.connect(_on_status_changed)
	_on_status_changed(NetworkManager.status)


func _on_host_pressed() -> void:
	NetworkManager.host_game()
	camera.set_screen_index(0)
	connection_panel.visible = false


func _on_join_pressed() -> void:
	var address := ip_edit.text.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"
	NetworkManager.join_game(address)
	camera.set_screen_index(1)
	connection_panel.visible = false


func _on_status_changed(status: String) -> void:
	status_label.text = status


func _on_offset_toggled(enabled: bool) -> void:
	camera.set_offset_mode(enabled)
