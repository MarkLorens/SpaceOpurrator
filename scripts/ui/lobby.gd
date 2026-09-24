extends Control
## Rooms found on the LAN, three to a row. Tapping one joins it; GameState moves
## us to the game room once connected. Without Bonjour (editor / desktop) a
## manual IP row is shown instead.

@onready var grid: GridContainer = $VBoxContainer/ScrollContainer/RoomGrid
@onready var empty_label: Label = $VBoxContainer/EmptyLabel
@onready var ip_row: HBoxContainer = $VBoxContainer/IPRow
@onready var ip_edit: LineEdit = $VBoxContainer/IPRow/IPEdit
@onready var ip_join_button: Button = $VBoxContainer/IPRow/JoinButton
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var cancel_button: Button = $CancelButton

func _ready() -> void:
	ip_row.visible = not Engine.has_singleton("Bonjour")
	ip_join_button.pressed.connect(func() -> void:
		var address := ip_edit.text.strip_edges()
		GameState.join_game(address if not address.is_empty() else "127.0.0.1"))
	cancel_button.pressed.connect(GameState.leave_game)
	NetworkManager.lobbies_changed.connect(_on_lobbies_changed)
	NetworkManager.status_changed.connect(_on_status_changed)
	_on_lobbies_changed(NetworkManager.lobbies)
	_on_status_changed(NetworkManager.status)

func _on_lobbies_changed(lobbies: Dictionary) -> void:
	for child in grid.get_children():
		child.queue_free()
	for room_name in lobbies:
		var card := Button.new()
		card.text = room_name
		card.custom_minimum_size = Vector2(560, 240)
		card.add_theme_font_size_override("font_size", 56)
		card.clip_text = true
		var address: String = lobbies[room_name]
		card.pressed.connect(func() -> void: GameState.join_game(address))
		grid.add_child(card)
	empty_label.visible = lobbies.is_empty()

func _on_status_changed(text: String) -> void:
	status_label.text = text
