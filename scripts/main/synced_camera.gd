extends Camera2D
## Camera2D that stays in sync across both connected peers.
##
## Whichever peer drags updates its own position immediately (for a responsive
## feel) and relays the new X to the other peer over an unreliable-ordered RPC.
## The receiving peer lerps toward that value each frame to smooth out network
## tick jitter instead of snapping.
##
## Offset Mode: when enabled, this instance shifts its rendered position by
## screen_index * viewport_width, so a host (index 0) and a client (index 1)
## sitting side by side render as one continuous panorama instead of both
## showing the same patch of world.
##
## Haptics: every initial touch/click buzzes this device immediately and is
## relayed to the other peer so it buzzes too — a physical way to feel the
## network round-trip alongside the visual lerp.

@export var lerp_speed := 12.0
## True LEFT/RIGHT edges of the board in world X (e.g. 0 and 10488 for a
## 4-screen board). The camera clamps so the whole visible rect — including the
## client's offset screen — stays between these; it does NOT clamp the raw
## center to them (the view center can only reach edge minus half a screen).
@export var world_min_x := 0.0
@export var world_max_x := 10488.0
## How many extra viewport-widths sit to the RIGHT of this shared base (the
## client is 1 screen right in offset mode). Room is reserved so that far screen
## also stays on the board. Set to 0 if you don't use offset mode.
@export var side_screens := 1
@export var haptic_duration_ms := 20
## Which board section the HOST's camera starts on (0 = first section).
## The shared start point shifts by this many screen-widths, so the client
## (always one screen to the right) starts on host_start_index + 1.
@export var host_start_index := 0
## How long after MY last movement I keep snapping (vs smoothing) and drop my own
## network echoes. Authority is "newest mover wins"; this only hides my own echo.
@export var takeover_grace_ms := 150

var master_x: float = 0.0   # Authoritative shared world X, no offset applied.
var display_x: float = 0.0  # Smoothed value actually written to position.x.
var is_dragging := false     # Finger/mouse button down — only used for mouse drag detection.
var offset_mode := false
var screen_index := 0
var _last_local_move_ms := 0  # When I last actually moved the view (not just held).
# Whoever pressed their finger down most recently owns the camera; only their
# drags move it, so two simultaneous draggers don't fight. Defaults to the host.
var authority_id := 1


func _ready() -> void:
	# Start centered on the host's chosen section (index 0 = first section). The
	# client shares this same base and renders one screen further right.
	var start_x: float = world_min_x + get_viewport_rect().size.x * (host_start_index + 0.5)
	master_x = _clamp_master(start_x)
	display_x = master_x


## Clamp the shared center so the visible rect (this base plus the far offset
## screen) never leaves [world_min_x, world_max_x]. Same on both peers, so the
## dragging side and the receiving side always agree on the limits.
func _clamp_master(x: float) -> float:
	var half: float = get_viewport_rect().size.x * 0.5
	var lo: float = world_min_x + half
	var hi: float = world_max_x - half - side_screens * get_viewport_rect().size.x
	return clampf(x, lo, maxf(lo, hi))


func _input(event: InputEvent) -> void:
	# Using _input (not _unhandled_input) is deliberate: it fires before the GUI
	# system routes the event to Controls, so a decorative Control-based node
	# (e.g. ColorRect, which defaults to mouse_filter = STOP) can never swallow
	# a drag before it reaches the camera. This keeps panning working across
	# the entire world width, not just the gaps between UI elements.
	#
	# Mouse events only. On phones Godot also turns every touch into a mouse
	# event (input_devices/pointing/emulate_mouse_from_touch, on by default, and
	# the TapArea buttons rely on it), so handling ScreenTouch/ScreenDrag too
	# made every drag move the camera twice and every tap buzz and send its RPCs
	# twice.

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = event.pressed
			if event.pressed:
				_on_local_click()
				
	elif event is InputEventMouseMotion:
		if is_dragging and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_apply_drag(-event.relative.x)
			get_viewport().set_input_as_handled()


func _apply_drag(delta_x: float) -> void:
	# Only the current authority (last player to press down) moves the view.
	if not _has_authority():
		return
	_last_local_move_ms = Time.get_ticks_msec()  # I'm the most recent mover now.
	master_x = _clamp_master(master_x + delta_x)
	display_x = master_x  # No lerp on the dragging side: keep local input snappy.
	_broadcast_camera_x(master_x)


func _has_authority() -> bool:
	# Offline (editor / no peer) there's only me, so I always control.
	if multiplayer.multiplayer_peer == null:
		return true
	return authority_id == multiplayer.get_unique_id()


## True only while I actively moved the view very recently — NOT just holding a
## finger still. Drives snap-vs-smoothing and dropping my own echoes.
func _moving_locally() -> bool:
	return Time.get_ticks_msec() - _last_local_move_ms < takeover_grace_ms


func _process(delta: float) -> void:
	if not _moving_locally():
		display_x = lerp(display_x, master_x, clampf(delta * lerp_speed, 0.0, 1.0))
	
	var offset_value : float
	if offset_mode:
		offset_value = (screen_index * get_viewport_rect().size.x)
	else: 
		offset_value = 0.0
	
	position.x = display_x + offset_value


func setup(role: Role.Type) -> void:
	var player_number : int = 0 if role == Role.Type.HOST else 1
	
	self.set_offset_mode(player_number)
	self.set_screen_index(player_number)
	self.make_current()

func set_offset_mode(offset_enabled: int) -> void:
	offset_mode = offset_enabled


func set_screen_index(number: int) -> void:
	screen_index = number


func _on_local_click() -> void:
	_claim_authority()  # pressing down takes control of the camera
	Input.vibrate_handheld(haptic_duration_ms)
	_broadcast_click()


## Pressing a finger down makes me the camera's authority. Applied locally right
## away for responsiveness, then confirmed by the server (which resolves the
## ordering if both players press at nearly the same moment).
func _claim_authority() -> void:
	authority_id = multiplayer.get_unique_id()
	if multiplayer.multiplayer_peer == null:
		return
	if multiplayer.is_server():
		set_authority.rpc(authority_id)
	else:
		request_authority.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func request_authority() -> void:
	if not multiplayer.is_server():
		return
	authority_id = multiplayer.get_remote_sender_id()
	set_authority.rpc(authority_id)


@rpc("authority", "call_remote", "reliable")
func set_authority(id: int) -> void:
	authority_id = id


# --- Networking ---
# ENet's high-level API only connects clients directly to the server (star
# topology), so a client can never RPC another client. A client always sends
# to the server (peer id 1), and the server is the only side that can
# broadcast onward to every other connected peer.

func _broadcast_camera_x(x: float) -> void:
	if multiplayer.multiplayer_peer == null: 
		return
	
	if multiplayer.is_server():
		receive_camera_x.rpc(x, multiplayer.get_unique_id())
	else:
		client_dragged.rpc_id(1, x)


func _broadcast_click() -> void:
	if multiplayer.multiplayer_peer == null:
		return
	
	if multiplayer.is_server():
		receive_click.rpc()
	else:
		client_clicked.rpc_id(1)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func client_dragged(x: float) -> void:
	if not multiplayer.is_server():
		return

	# Only the current authority moves the view; ignore a stale drag from a
	# client that just lost control. Relay it on, tagged so the sender can
	# ignore its own echo.
	if multiplayer.get_remote_sender_id() != authority_id:
		return
	master_x = x
	receive_camera_x.rpc(x, multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "unreliable_ordered")
func receive_camera_x(x: float, origin: int) -> void:
	# Drop my own echo (it would yank my camera backward mid-drag); apply the
	# other player's movement immediately so the latest mover always wins.
	if origin == multiplayer.get_unique_id():
		return
	master_x = x


@rpc("any_peer", "call_remote", "reliable")
func client_clicked() -> void:
	if not multiplayer.is_server(): 
		return
	receive_click.rpc()


@rpc("any_peer", "call_remote", "reliable")
func receive_click() -> void:
	Input.vibrate_handheld(haptic_duration_ms)
