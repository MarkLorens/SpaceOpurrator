extends Control

## Debug overlay for board.tscn.
## Draws one box outline per phone-screen worth of board (each == the game
## viewport, 2622x1206 by default) and a big number in each, so when testing
## on an actual iPhone you can tell which section (1..N) is currently on screen.
## Toggle the whole thing off by hiding this node, or with the `visible` export.

## One phone screen == the project viewport size (Project Settings > Display).
@export var phone_size: Vector2 = Vector2(2622, 1206)
@export var screen_count: int = 4

@export_group("Outline")
@export var line_color: Color = Color(1.0, 0.25, 0.25, 0.9)
@export var line_width: float = 10.0

@export_group("Number")
@export var show_numbers: bool = true
@export var number_color: Color = Color(1.0, 1.0, 1.0, 0.35)
@export var number_size: int = 420

func _ready() -> void:
	# Cover the whole board so our local draw coords line up with it.
	size = Vector2(phone_size.x * screen_count, phone_size.y)
	# Never eat input meant for the game underneath.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	for i in screen_count:
		var rect := Rect2(i * phone_size.x, 0.0, phone_size.x, phone_size.y)
		# Box outline for this phone screen.
		draw_rect(rect, line_color, false, line_width)

		if show_numbers:
			var num := str(i + 1)
			var text_w := font.get_string_size(
				num, HORIZONTAL_ALIGNMENT_LEFT, -1, number_size).x
			var pos := Vector2(
				rect.position.x + (rect.size.x - text_w) * 0.5,
				rect.position.y + (rect.size.y + font.get_ascent(number_size)) * 0.5
					- font.get_descent(number_size) * 0.5)
			draw_string(font, pos, num, HORIZONTAL_ALIGNMENT_LEFT, -1,
				number_size, number_color)
