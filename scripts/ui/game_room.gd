extends Control
## Pre-game room. Both players toggle Ready; once both are, the host's Start
## button unlocks. All state lives in GameState and is re-read on room_changed.

@onready var room_label: Label = $CenterContainer/VBoxContainer/RoomLabel
@onready var ip_label: Label = $CenterContainer/VBoxContainer/IPLabel
@onready var host_status: Label = $CenterContainer/VBoxContainer/Players/HostStatus
@onready var copilot_status: Label = $CenterContainer/VBoxContainer/Players/CopilotStatus
@onready var ready_button: Button = $CenterContainer/VBoxContainer/Buttons/ReadyButton
@onready var start_button: Button = $CenterContainer/VBoxContainer/Buttons/StartButton
@onready var cancel_button: Button = $CancelButton

func _ready() -> void:
	start_button.visible = GameState.role == Role.Type.HOST
	# Fallback for when the co-pilot's lobby never discovers this room.
	ip_label.text = "Co-pilot can't find the room? Join by IP: %s" % NetworkManager.get_local_ip()
	ready_button.toggled.connect(GameState.set_ready)
	start_button.pressed.connect(GameState.start_game)
	cancel_button.pressed.connect(GameState.leave_game)
	GameState.room_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	room_label.text = GameState.room_name
	var host_ready: Variant = null
	var copilot_ready: Variant = null
	
	for id in GameState.ready_by_peer:
		if id == 1:
			host_ready = GameState.ready_by_peer[id]
		else:
			copilot_ready = GameState.ready_by_peer[id]
	
	host_status.text = "Host: " + _status_text(host_ready)
	copilot_status.text = "Co-pilot: " + _status_text(copilot_ready)

	var full := GameState.ready_by_peer.size() == 2
	ip_label.visible = GameState.role == Role.Type.HOST and not full
	ready_button.disabled = not full
	
	# Mirror the host's view (e.g. flags reset when a co-pilot leaves) without re-sending.
	var my_ready: bool = GameState.ready_by_peer.get(multiplayer.get_unique_id(), false)
	ready_button.set_pressed_no_signal(my_ready)
	ready_button.text = "Ready!" if my_ready else "Ready"
	start_button.disabled = not GameState.can_start()

func _status_text(is_ready: Variant) -> String:
	if is_ready == null:
		return "Waiting for player..."
	
	return "Ready" if is_ready else "Not ready"
