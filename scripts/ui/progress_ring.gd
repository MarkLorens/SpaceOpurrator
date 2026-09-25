class_name ProgressRing
extends Node2D
## Ring drawn around a button while a timed gesture (e.g. hold) is in progress.
## Hidden at 0; fills clockwise from the top; switches to done_color when full.

@export var radius := 150.0
@export var width := 18.0
@export var track_color := Color(0, 0, 0, 0.35)
@export var fill_color := Color("ff8e80")
@export var done_color := Color("ffd294")

var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()

func _draw() -> void:
	if progress <= 0.0:
		return
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, track_color, width, true)
	var end := -PI / 2 + TAU * progress
	draw_arc(Vector2.ZERO, radius, -PI / 2, end, 64,
		done_color if progress >= 1.0 else fill_color, width, true)
