extends Control
## Overlay pause menu, synced across both players. Its process_mode is ALWAYS
## (set in the scene) so its buttons AND its incoming pause/resume RPC keep
## working while the rest of the tree is paused.
##
## Either player can pause; both freeze. Only the player who paused sees
## Resume — the other sees a "the other player paused" screen until they
## resume. Exiting hands off to GameState, which owns the session and the
## return-to-menu transition.

@onready var own_menu: Control = $CenterContainer
@onready var remote_menu: Control = $RemotePaused
@onready var resume_button: Button = $CenterContainer/VBoxContainer/ResumeButton
@onready var exit_button: Button = $CenterContainer/VBoxContainer/ExitButton
@onready var remote_exit_button: Button = $RemotePaused/VBoxContainer/ExitButton

## Peer id of whoever paused; 0 = not paused.
var paused_by := 0

func _ready() -> void:
	hide()
	resume_button.pressed.connect(resume)
	exit_button.pressed.connect(exit)
	remote_exit_button.pressed.connect(exit)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if paused_by == 0:
			pause()
		else:
			resume()  # ignored unless I'm the one who paused
		get_viewport().set_input_as_handled()

# --- Public: called by the local player (button / Esc) ---

func pause() -> void:
	if paused_by != 0:
		return
	
	_set_paused_by(_my_id())
	_broadcast_paused(true)

func resume() -> void:
	if paused_by != _my_id():
		return
	_set_paused_by(0)
	_broadcast_paused(false)

func exit() -> void:
	# GameState drops the connection; the other player detects it and returns to
	# the menu too, so leaving is "together" without a fragile exit RPC.
	get_tree().paused = false
	GameState.leave_game()

# --- Shared pause state (local or remote) ---

func _set_paused_by(id: int) -> void:
	paused_by = id
	visible = id != 0
	own_menu.visible = id == _my_id()
	remote_menu.visible = id != 0 and id != _my_id()
	get_tree().paused = id != 0

func _my_id() -> int:
	# Solo / editor run: no peer, treat me as the host.
	return multiplayer.get_unique_id() if multiplayer.multiplayer_peer else 1

func _broadcast_paused(is_pause: bool) -> void:
	# Solo / editor run: no peer to tell.
	if multiplayer.multiplayer_peer == null:
		return
	_remote_set_paused.rpc(is_pause)

@rpc("any_peer", "call_remote", "reliable")
func _remote_set_paused(p: bool) -> void:
	# Mirror the other player's pause/resume without re-broadcasting (no echo).
	var sender := multiplayer.get_remote_sender_id()
	if p:
		# Both paused at once: the lower id (the host) keeps control on both sides.
		if paused_by == 0 or sender < paused_by:
			_set_paused_by(sender)
	elif paused_by == sender:
		_set_paused_by(0)
