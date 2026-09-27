class_name RollGesture
extends ButtonGesture
## Draw `turns` loops, starting on the tool, in either direction. Counts how far
## the finger's heading has turned in total, so loops can be any size and
## anywhere, and wiggling back and forth cancels itself out.
## Lifting the finger keeps progress; releasing the component resets it.

@export var turns := 2.0
## Finger travel (screen pixels) between heading samples; smooths out jitter.
@export var sample_distance := 16.0

var _turned := 0.0  # signed total heading change, radians
var _quarters := 0  # quarter turns made so far, for a tick on each new one
var _done := false  # completed; the battery stays full until the next roll
var _last_point := Vector2.ZERO
var _last_heading := 0.0
var _has_heading := false  # a heading needs two samples; reset on every press

func attach(area: TapArea) -> void:
	area.pressed.connect(func() -> void:
		_last_point = area.press_position
		_has_heading = false)
	area.finger_moved.connect(_on_finger_moved)

func uses_drags() -> bool:
	return true

func _on_finger_moved(pos: Vector2) -> void:
	var segment := pos - _last_point
	if segment.length() < sample_distance:
		return
	_last_point = pos
	var heading := segment.angle()
	if _has_heading and armed:
		if _done:
			_done = false
			_turned = 0.0
			_quarters = 0
		_turned += wrapf(heading - _last_heading, -PI, PI)
		var progress := absf(_turned) / (turns * TAU)
		progress_changed.emit(minf(progress, 1.0))
		var quarters := int(absf(_turned) / (PI / 2.0))
		if progress >= 1.0:
			_done = true
			activated.emit()
		elif quarters > _quarters:
			stepped.emit()
		_quarters = quarters
	_last_heading = heading
	_has_heading = true

func reset() -> void:
	_turned = 0.0
	_quarters = 0
	_done = false
	progress_changed.emit(0.0)
