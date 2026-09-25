extends Node2D
## Shows a puzzle sequence as a row of symbols. Follows the entered sequence by
## default; set source to TARGET to show the sequence players must match.
##
## The row starts at this node's position (left edge, vertical middle) and fills
## to the right, so place the node at the left of wherever symbols should appear.

enum Source { SUBMITTED, TARGET }

@export var source: Source = Source.SUBMITTED
@export var symbol_size := Vector2(128, 128)

@onready var row: HBoxContainer = $Symbols

func _ready() -> void:
	row.position.y = -symbol_size.y / 2.0  # keep the row centred on this node's y
	if source == Source.TARGET:
		PuzzleSolver.sequence_changed.connect(show_sequence)
		show_sequence(PuzzleSolver.correctSeq)
	else:
		PuzzleSolver.submitted_changed.connect(show_sequence)
		show_sequence(PuzzleSolver.submittedSeq)

func show_sequence(seq: Array[int]) -> void:
	for child in row.get_children():
		row.remove_child(child)  # out now, so the row doesn't size around old icons this frame
		child.queue_free()
	
	var pool := GameState.level.button_pool
	for value in seq:  # bounded by the level's sequence_length
		var icon := TextureRect.new()
		icon.texture = pool[value].icon if value >= 0 and value < pool.size() else null
		icon.custom_minimum_size = symbol_size
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		
		row.add_child(icon)
