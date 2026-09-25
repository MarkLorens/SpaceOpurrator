extends Control
## Shown between the game room and level 1. The cat flies along the dashed
## route to the planet, then GameState loads the level. Both players run the
## same fixed-length animation, so they reach the level together.

## Seconds for the cat's trip; the level starts when it lands.
@export var duration := 4.0

@onready var stage: Node2D = $Stage
@onready var follower: PathFollow2D = $Stage/Route/Path2D/PathFollow2D
@onready var cat: Sprite2D = $Stage/Route/Path2D/PathFollow2D/Cat

func _ready() -> void:
	_center_stage()
	get_viewport().size_changed.connect(_center_stage)
	follower.progress_ratio = 0.0
	var trip := create_tween()
	trip.tween_property(follower, "progress_ratio", 1.0, duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	trip.tween_callback(GameState.enter_level)
	# Gentle hover so the UFO doesn't look glued to the line.
	var bob := create_tween().set_loops()
	bob.tween_property(cat, "position:y", -12.0, 0.35).set_trans(Tween.TRANS_SINE)
	bob.tween_property(cat, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_SINE)

## Route art is laid out around the screen centre; "expand" stretch can make
## the screen wider than the base size, so re-centre on resize.
func _center_stage() -> void:
	stage.position = get_viewport_rect().size / 2.0
