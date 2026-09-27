class_name TapArea
extends Area2D
## Area2D that follows one finger at a time. `tapped` fires on release, but only
## if the finger barely moved since pressing — so dragging the board across a
## button doesn't press it.
##
## Uses touch events, not mouse, so several buttons can be held at once (hold a
## component with one finger, tap a tool with another). On desktop, mouse
## clicks arrive as touches via input_devices/pointing/emulate_touch_from_mouse.

## A finger went down on this button (at press_position).
signal pressed
## The pressing finger moved (screen position). Movement gestures read this.
signal finger_moved(screen_pos: Vector2)
## That finger lifted, or moved too far and turned into a drag (was_tap false).
signal released(was_tap: bool)
## Released as a tap: barely moved, and quick enough (see tap_max_time).
signal tapped

## Max screen-pixel travel between press and release that still counts as a tap.
@export var tap_max_distance := 20.0
## Presses held longer than this (seconds) don't count as taps. 0 = no limit.
@export var tap_max_time := 0.0
## While true, a pressing finger belongs to this button until it lifts: moving
## doesn't cancel the press, and the board doesn't pan. Turning it on mid-press
## keeps that finger too (as long as it hasn't already become a drag).
@export var keep_drags := false:
	set(value):
		keep_drags = value
		if keep_drags and _finger != -1 and not _kept_fingers.has(_finger):
			_kept_fingers.append(_finger)
## While keep_drags is on, presses up to this many pixels outside the button
## also start here — unless they land on another button. Where two widened
## buttons overlap, the nearer one gets the press.
@export var grab_margin := 0.0

## Touch indices currently kept by some TapArea (see keep_drags). The camera
## skips panning for these.
static var _kept_fingers: Array[int] = []
## Every TapArea in the tree, to settle overlapping grab margins.
static var _all: Array[TapArea] = []

## Where the current press started, in screen pixels.
var press_position := Vector2.ZERO
var _finger := -1  # touch index pressing this button; -1 = not pressed
var _press_ms := 0
var _moved_far := false  # travelled past tap_max_distance (only possible when kept)

static func is_finger_kept(index: int) -> bool:
	return _kept_fingers.has(index)

# _input (not input_event) so the release is seen even if the finger ends off
# the button, and so each finger is tracked by its own touch index.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _finger == -1 and _claims(event.position):
			_finger = event.index
			press_position = event.position
			_press_ms = Time.get_ticks_msec()
			_moved_far = false
			if keep_drags:
				_kept_fingers.append(_finger)
			pressed.emit()
		elif not event.pressed and event.index == _finger:
			var quick := tap_max_time <= 0.0 or Time.get_ticks_msec() - _press_ms <= tap_max_time * 1000.0
			_end(quick and not _moved_far)
	elif event is InputEventScreenDrag and event.index == _finger:
		finger_moved.emit(event.position)
		if event.position.distance_to(press_position) > tap_max_distance:
			if _kept_fingers.has(_finger):
				_moved_far = true
			else:
				_end(false)  # Moved too far: it's a drag, cancel the tap.

func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_all.append(self)
	elif what == NOTIFICATION_EXIT_TREE:
		_all.erase(self)
		if _finger != -1:
			_kept_fingers.erase(_finger)  # level is closing; just don't leak the finger
	elif what == NOTIFICATION_PAUSED and _finger != -1:
		_end(false)  # the release can't reach _input while paused, so let go now

func _end(was_tap: bool) -> void:
	_kept_fingers.erase(_finger)
	_finger = -1
	released.emit(was_tap)
	if was_tap:
		tapped.emit()

## Whether a press at screen_pos starts on this button.
func _claims(screen_pos: Vector2) -> bool:
	var world := get_canvas_transform().affine_inverse() * screen_pos
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hits := get_world_2d().direct_space_state.intersect_point(query)
	for hit in hits:
		if hit.collider == self:
			return true
	if not _grabs(world):
		return false
	for hit in hits:
		if hit.collider is TapArea:
			return false  # right on another button: that one's press
	var nearest: TapArea = self
	for area in _all:
		if area._grabs(world) and area.global_position.distance_squared_to(world) < nearest.global_position.distance_squared_to(world):
			nearest = area
	return nearest == self

## In this button's widened area (world position)?
func _grabs(world: Vector2) -> bool:
	if not keep_drags or grab_margin <= 0.0:
		return false
	for owner_id in get_shape_owners():
		var xf := global_transform * shape_owner_get_transform(owner_id)
		for i in shape_owner_get_shape_count(owner_id):
			var rect := xf * shape_owner_get_shape(owner_id, i).get_rect()
			if rect.grow(grab_margin).has_point(world):
				return true
	return false
