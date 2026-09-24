extends Control
## Rooms found on the LAN, three to a row. Tapping one joins it; GameState moves
## us to the game room once connected. The manual IP row is always shown: Bonjour
## discovery is unreliable on some phones/networks, and the host's room screen
## shows its IP for exactly this.

@onready var grid: GridContainer = $VBoxContainer/ScrollContainer/RoomGrid
@onready var empty_label: Label = $VBoxContainer/EmptyLabel
@onready var ip_edit: LineEdit = $VBoxContainer/IPRow/IPEdit
@onready var ip_join_button: Button = $VBoxContainer/IPRow/JoinButton
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var cancel_button: Button = $CancelButton

func _ready() -> void:
	ip_join_button.pressed.connect(_join_typed_ip)
	ip_edit.text_submitted.connect(func(_t: String) -> void: _join_typed_ip())
	cancel_button.pressed.connect(GameState.leave_game)
	NetworkManager.lobbies_changed.connect(_on_lobbies_changed)
	NetworkManager.status_changed.connect(_on_status_changed)
	NetworkManager.restart_browsing()
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

func _input(event: InputEvent) -> void:
	# iOS only hides the keyboard when the field loses focus, and tapping empty
	# space doesn't take focus, so drop it on any tap outside the field.
	if event is InputEventMouseButton and event.pressed and ip_edit.has_focus() \
			and not ip_edit.get_global_rect().has_point(event.position):
		ip_edit.release_focus()


func _join_typed_ip() -> void:
	ip_edit.release_focus()  # hide the keyboard so the status line is visible
	# Commas too: some keyboards/regions only offer "," as the decimal key.
	var address := ip_edit.text.strip_edges().replace(",", ".").replace(" ", "")
	if not address.is_valid_ip_address():
		status_label.text = "Enter the IP shown on the host's screen, e.g. 192.168.1.5"
		return
	GameState.join_game(address)


func _on_status_changed(text: String) -> void:
	status_label.text = text
