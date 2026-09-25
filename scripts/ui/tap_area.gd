class_name TapArea
extends Area2D
## Area2D that follows one finger at a time. `tapped` fires on release, but only
## if the finger barely moved since pressing — so dragging the board across a
## button doesn't press it.
##
## Uses touch events, not mouse, so several buttons can be held at once (hold a
## component with one finger, tap a tool with another). On desktop, mouse
## clicks arrive as touches via input_devices/pointing/emulate_touch_from_mouse.

## A finger went down on this button.
signal pressed
## That finger lifted, or moved too far and turned into a drag (was_tap false).
signal released(was_tap: bool)
## Released as a tap: barely moved, and quick enough (see tap_max_time).
signal tapped

## Max screen-pixel travel between press and release that still counts as a tap.
@export var tap_max_distance := 20.0
## Presses held longer than this (seconds) don't count as taps. 0 = no limit.
@export var tap_max_time := 0.0

var _finger := -1  # touch index pressing this button; -1 = not pressed
var _press_pos := Vector2.ZERO
var _press_ms := 0

# _input (not input_event) so the release is seen even if the finger ends off
# the button, and so each finger is tracked by its own touch index.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _finger == -1 and _is_over(event.position):
			_finger = event.index
			_press_pos = event.position
			_press_ms = Time.get_ticks_msec()
			pressed.emit()
		elif not event.pressed and event.index == _finger:
			var quick := tap_max_time <= 0.0 or Time.get_ticks_msec() - _press_ms <= tap_max_time * 1000.0
			_end(quick)
	elif event is InputEventScreenDrag and event.index == _finger:
		if event.position.distance_to(_press_pos) > tap_max_distance:
			_end(false)  # Moved too far: it's a drag, cancel the tap.

# The release can't reach _input while the game is paused, so let go now.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and _finger != -1:
		_end(false)

func _end(was_tap: bool) -> void:
	_finger = -1
	released.emit(was_tap)
	if was_tap:
		tapped.emit()

func _is_over(screen_pos: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = get_canvas_transform().affine_inverse() * screen_pos
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit in get_world_2d().direct_space_state.intersect_point(query):
		if hit.collider == self:
			return true
	return false
