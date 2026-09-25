extends Control
## Pre-game room. Each player taps their own READY pill to toggle ready; once
## both are, the host's Start button unlocks. All state lives in GameState and
## is re-read on room_changed.
##
## Player 1 (host) is shown on the left, Player 2 (co-pilot) on the right.

@export_file var HOST_BACKGROUND
@export_file var CLIENT_BACKGROUND

const ACTIVE_TEXTURE := preload("res://assets/ui/button/Active Button.png")
const INACTIVE_TEXTURE := preload("res://assets/ui/button/Inactive Button.png")
const ACTIVE_TEXT_COLOR := Color("ffd294")
const INACTIVE_TEXT_COLOR := Color("7f86c6")

@onready var title_label: Label = $CenterContainer/VBoxContainer/VBoxContainer/TitleLabel
@onready var tip_label: Label = $CenterContainer/VBoxContainer/VBoxContainer/TipLabel
@onready var ip_label: Label = $CenterContainer/VBoxContainer/IPLabel
@onready var p1_name: Label = $CenterContainer/VBoxContainer/Players/Player1/NameLabel
@onready var p1_pill: TextureButton = $CenterContainer/VBoxContainer/Players/Player1/ReadyPill
@onready var p2_name: Label = $CenterContainer/VBoxContainer/Players/Player2/NameLabel
@onready var p2_pill: TextureButton = $CenterContainer/VBoxContainer/Players/Player2/ReadyPill
@onready var start_button: TextureButton = $StartMargin/StartButton
@onready var cancel_button: TextureButton = $CancelButton
@onready var background: TextureRect = $Background

var _is_host := false

func _ready() -> void:
	_is_host = GameState.role == Role.Type.HOST
	background.texture = load(HOST_BACKGROUND if _is_host else CLIENT_BACKGROUND)
	start_button.visible = _is_host
	# Fallback for when the co-pilot's lobby never discovers this room.
	ip_label.text = "Co-pilot can't find the room? Join by IP: %s" % NetworkManager.get_local_ip()

	var my_pill := p1_pill if _is_host else p2_pill
	my_pill.pressed.connect(_toggle_my_ready)
	start_button.pressed.connect(GameState.start_game)
	cancel_button.pressed.connect(GameState.leave_game)
	GameState.room_changed.connect(_refresh)
	_refresh()

func _toggle_my_ready() -> void:
	GameState.set_ready(not GameState.ready_by_peer.get(multiplayer.get_unique_id(), false))

func _refresh() -> void:
	var host_ready: Variant = null  # null = player not here yet
	var copilot_ready: Variant = null
	for id in GameState.ready_by_peer:
		if id == 1:
			host_ready = GameState.ready_by_peer[id]
		else:
			copilot_ready = GameState.ready_by_peer[id]

	var full := GameState.ready_by_peer.size() == 2
	title_label.text = GameState.room_name if full else "Waiting for your co-pilot"
	tip_label.visible = true if full else false
	ip_label.visible = _is_host and not full

	p1_name.text = "You" if _is_host else "Player 1"
	p2_name.text = "Player 2" if _is_host else "You"
	_set_pill(p1_pill, host_ready == true, _is_host and full)
	_set_pill(p2_pill, copilot_ready == true, not _is_host and full)

	start_button.disabled = not GameState.can_start()
	start_button.get_node("Label").add_theme_color_override(
		"font_color", INACTIVE_TEXT_COLOR if start_button.disabled else ACTIVE_TEXT_COLOR
	)

## Ready = pink with cream text; not ready (or not here) = navy with muted text.
## Only your own pill is tappable, and only once both players are in the room.
func _set_pill(pill: TextureButton, is_ready: bool, tappable: bool) -> void:
	# Texture
	pill.texture_normal = INACTIVE_TEXTURE if is_ready else ACTIVE_TEXTURE
	
	# Label
	var label = pill.get_node("Label")
	label.add_theme_color_override("font_color", INACTIVE_TEXT_COLOR if is_ready else ACTIVE_TEXT_COLOR)
	label.text = "YOU ARE READY" if is_ready else "READY"
	label.add_theme_font_size_override("font_size", 48 if is_ready else 72)
	
	# Untappable
	pill.mouse_filter = Control.MOUSE_FILTER_STOP if tappable else Control.MOUSE_FILTER_IGNORE
