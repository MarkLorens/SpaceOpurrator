class_name TapArea
extends Area2D
## Area2D that fires `tapped` on release, but only if the finger barely moved
## since pressing it — so dragging the board across a button doesn't press it.

signal tapped

## Max screen-pixel travel between press and release that still counts as a tap.
@export var tap_max_distance := 20.0

var _press_pos := Vector2.INF  # INF = not currently pressed on this button.

func _ready() -> void:
	input_event.connect(_on_input_event)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_press_pos = event.position

# _input (not input_event) so the release is seen even if the finger ends off the button.
func _input(event: InputEvent) -> void:
	if _press_pos == Vector2.INF:
		return
		
	if event is InputEventMouseMotion and event.position.distance_to(_press_pos) > tap_max_distance:
		_press_pos = Vector2.INF  # Moved too far: it's a drag, cancel the tap.
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_press_pos = Vector2.INF
		tapped.emit()
