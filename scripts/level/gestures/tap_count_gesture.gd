class_name TapCountGesture
extends ButtonGesture
## Tap the tool `taps` times while a component is held.

@export var taps := 4

var _count := 0

func attach(area: TapArea) -> void:
	area.tapped.connect(_on_tapped)

func _on_tapped() -> void:
	if not armed:
		return
	if _count >= taps:
		_count = 0  # last one completed; the ring stayed full until now
	_count += 1
	progress_changed.emit(float(_count) / taps)
	if _count >= taps:
		activated.emit()

func reset() -> void:
	_count = 0
	progress_changed.emit(0.0)
