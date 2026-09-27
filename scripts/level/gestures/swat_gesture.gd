class_name SwatGesture
extends ButtonGesture
## Swipe left and right `swats` times, starting on the tool. Each swat must
## travel swat_distance horizontally and go the opposite way from the last one;
## one continuous scrub and separate flicks both count.
## Lifting the finger keeps progress; releasing the component resets it.

@export var swats := 4
## Horizontal travel (screen pixels) that counts as one swat.
@export var swat_distance := 150.0

var _count := 0
var _last_dir := 0  # direction of the last swat: -1 left, 1 right, 0 none yet
var _anchor_x := 0.0  # where the current stroke started (its turning point)

func attach(area: TapArea) -> void:
	area.pressed.connect(func() -> void: _anchor_x = area.press_position.x)
	area.finger_moved.connect(_on_finger_moved)

func uses_drags() -> bool:
	return true

func _on_finger_moved(pos: Vector2) -> void:
	# Still going the way of the last swat: slide the turning point along, so
	# the next swat is measured from where the finger actually turns back.
	if _last_dir != 0 and (pos.x - _anchor_x) * _last_dir > 0.0:
		_anchor_x = pos.x
		return
	var dx := pos.x - _anchor_x
	if absf(dx) < swat_distance or not armed:
		return
	if _count >= swats:
		_count = 0  # last one completed; the ring stayed full until now
	_count += 1
	_last_dir = 1 if dx > 0.0 else -1
	_anchor_x = pos.x
	progress_changed.emit(float(_count) / swats)
	if _count >= swats:
		activated.emit()

func reset() -> void:
	_count = 0
	_last_dir = 0
	progress_changed.emit(0.0)
