extends Node2D

# A simple long horizontal strip so movement along the map is easy to see.
const LENGTH: float = 4000.0
const HEIGHT: float = 500.0
const MARKER_STEP: float = 250.0

func _draw() -> void:
	var top: float = -HEIGHT * 0.5
	# Strip band.
	draw_rect(Rect2(0.0, top, LENGTH, HEIGHT), Color("282a37"))
	# Border.
	draw_rect(Rect2(0.0, top, LENGTH, HEIGHT), Color("666b80"), false, 3.0)
	# Vertical distance markers so you can perceive movement along the strip.
	var x: float = MARKER_STEP
	while x < LENGTH:
		draw_line(Vector2(x, top), Vector2(x, top + HEIGHT), Color("474b61"), 2.0)
		x += MARKER_STEP
