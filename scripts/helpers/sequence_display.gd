extends Node2D
## Shows a puzzle sequence as a row of steps: a component's icon, or for a
## tool + component step, the tool's icon (smaller) and then the component's.
## Follows the entered sequence by default; set source to TARGET to show the
## sequence players must match.
##
## The row starts at this node's position (left edge, vertical middle) and fills
## to the right, so place the node at the left of wherever symbols should appear.

enum Source { SUBMITTED, TARGET }

@export var source: Source = Source.SUBMITTED
@export var symbol_size := Vector2(128, 128)
## Tool icons in a tool + component step, relative to symbol_size.
@export var tool_scale := 0.7

@onready var row: HBoxContainer = $Symbols

func _ready() -> void:
	row.position.y = -symbol_size.y / 2.0  # keep the row centred on this node's y
	if source == Source.TARGET:
		PuzzleSolver.sequence_changed.connect(show_sequence)
		show_sequence(PuzzleSolver.correctSeq)
	else:
		PuzzleSolver.submitted_changed.connect(show_sequence)
		show_sequence(PuzzleSolver.submittedSeq)

func show_sequence(seq: Array[Vector2i]) -> void:
	for child in row.get_children():
		row.remove_child(child)  # out now, so the row doesn't size around old icons this frame
		child.queue_free()
	
	var defs := GameState.level.button_defs()
	for step in seq:  # bounded by the target's length
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		if step.y != PuzzleSolver.NO_TOOL:
			box.add_child(_icon(defs, step.y, symbol_size * tool_scale))
		box.add_child(_icon(defs, step.x, symbol_size))
		row.add_child(box)

func _icon(defs: Array[ButtonDef], value: int, size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = defs[value].icon if value >= 0 and value < defs.size() else null
	icon.custom_minimum_size = size
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return icon
