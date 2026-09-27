extends Node2D
## Shows a puzzle sequence as a row of steps: a component's icon, or for a
## tool + component step, the tool's icon and then the component's, wrapped in
## brackets: [ tool component ].
## Follows the entered sequence by default; set source to TARGET to show the
## sequence players must match, or MANUAL to only show what show_sequence() is
## given (e.g. a code card row).
##
## The row starts at this node's position (left edge, vertical middle) and fills
## to the right, so place the node at the left of wherever symbols should appear.

enum Source { SUBMITTED, TARGET, MANUAL }

const BRACKET_LEFT: Texture2D = preload("res://assets/icon/BracketLeft.png")
const BRACKET_RIGHT: Texture2D = preload("res://assets/icon/BracketRight.png")
## Bracket width relative to symbol_size (the art is half as wide as an icon).
const BRACKET_WIDTH := 0.5

@export var source: Source = Source.SUBMITTED
@export var symbol_size := Vector2(128, 128)
## Tool icons in a tool + component step, relative to symbol_size.
@export var tool_scale := 1.0

@onready var row: HBoxContainer = $Symbols

func _ready() -> void:
	if source == Source.TARGET:
		PuzzleSolver.sequence_changed.connect(show_sequence)
		show_sequence(PuzzleSolver.correctSeq)
	elif source == Source.SUBMITTED:
		PuzzleSolver.submitted_changed.connect(show_sequence)
		show_sequence(PuzzleSolver.submittedSeq)

func show_sequence(seq: Array[Vector2i]) -> void:
	# Keep the row centred on this node's y (symbol_size may change between calls).
	row.position.y = -symbol_size.y / 2.0
	row.size.y = symbol_size.y
	for child in row.get_children():
		row.remove_child(child)  # out now, so the row doesn't size around old icons this frame
		child.queue_free()
	
	var defs := GameState.level.button_defs()
	for step in seq:  # bounded by the target's length
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		var combo := step.y != PuzzleSolver.NO_TOOL
		var bracket_size := Vector2(symbol_size.x * BRACKET_WIDTH, symbol_size.y)
		if combo:
			box.add_child(_image(BRACKET_LEFT, bracket_size))
			box.add_child(_icon(defs, step.y, symbol_size * tool_scale))
		box.add_child(_icon(defs, step.x, symbol_size))
		if combo:
			box.add_child(_image(BRACKET_RIGHT, bracket_size))
		row.add_child(box)

## Width of one step in symbol_size.x units, for fitting a row into a space.
func step_width(step: Vector2i) -> float:
	if step.y == PuzzleSolver.NO_TOOL:
		return 1.0
	return 1.0 + tool_scale + 2.0 * BRACKET_WIDTH

func _icon(defs: Array[ButtonDef], value: int, size: Vector2) -> TextureRect:
	return _image(defs[value].icon if value >= 0 and value < defs.size() else null, size)

func _image(texture: Texture2D, size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = size
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return icon
