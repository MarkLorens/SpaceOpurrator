extends Control
## Overlay pause menu, synced across both players. Its process_mode is ALWAYS
## (set in the scene) so its buttons AND its incoming pause/resume RPC keep
## working while the rest of the tree is paused.
##
## Either player can pause or resume; the state is mirrored to the other peer,
## so both freeze and both see this menu. Exiting hands off to GameState, which
## owns the session and the return-to-menu transition.

@onready var resume_button: Button = $CenterContainer/VBoxContainer/ResumeButton
@onready var exit_button: Button = $CenterContainer/VBoxContainer/ExitButton

func _ready() -> void:
	hide()
	resume_button.pressed.connect(resume)
	exit_button.pressed.connect(exit)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			resume()
		else:
			pause()
		get_viewport().set_input_as_handled()

# --- Public: called by the local player (button / Esc) ---

func pause() -> void:
	_set_paused(true)
	_broadcast_paused(true)

func resume() -> void:
	_set_paused(false)
	_broadcast_paused(false)

func exit() -> void:
	# GameState drops the connection; the other player detects it and returns to
	# the menu too, so leaving is "together" without a fragile exit RPC.
	get_tree().paused = false
	GameState.leave_game()

# --- Shared pause state (local or remote) ---

func _set_paused(is_pause: bool) -> void:
	visible = is_pause
	get_tree().paused = is_pause

func _broadcast_paused(is_pause: bool) -> void:
	# Solo / editor run: no peer to tell.
	if multiplayer.multiplayer_peer == null:
		return
	_remote_set_paused.rpc(is_pause)

@rpc("any_peer", "call_remote", "reliable")
func _remote_set_paused(p: bool) -> void:
	# Mirror the other player's pause/resume without re-broadcasting (no echo).
	_set_paused(p)
