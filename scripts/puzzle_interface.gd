class_name PuzzleInterface
extends Node2D
## Tells the players what to press.
##
## Shows one code card at a time: a row per threat with that threat's sequence
## for the card's code, and the code in the corner. The player here finds the
## card matching the threat's code badge while the other player flips cards with
## the Next button. A level without threats has no cards; it shows the current
## sequence (TargetSequence) instead.

const CODE_LETTERS := ["X", "Y", "Z"]
const CODE_DOTS: Array[Texture2D] = [
	preload("res://assets/ui/SeqX.png"),
	preload("res://assets/ui/SeqY.png"),
	preload("res://assets/ui/SeqZ.png"),
]
## Letter colours, matching the dots.
const CODE_COLORS: Array[Color] = [
	Color8(197, 58, 157),
	Color8(255, 142, 128),
	Color8(255, 210, 148),
]

## Card art pixels available for a row's sequence, and the biggest icon to use.
@export var row_width := 312.0
@export var max_symbol_size := 52.0
@export var symbol_separation := 4

@onready var target_sequence: Node2D = $TargetSequence
@onready var box: Control = $Box
@onready var rows: Array[Control] = [$Box/Row1, $Box/Row2, $Box/Row3]
@onready var code_dot: TextureRect = $Box/CodeDot
@onready var code_letter: Label = $Box/CodeLetter

func _ready() -> void:
	var codes := GameState.level.uses_codes()
	box.visible = codes
	target_sequence.visible = not codes
	if not codes:
		return
	for row in rows:
		var symbols: HBoxContainer = row.get_node("Sequence/Symbols")
		symbols.add_theme_constant_override("separation", symbol_separation)
	PuzzleSolver.ensure_codebook()  # already built in a session; solo runs build it here
	PuzzleSolver.card_changed.connect(_show_card)
	_show_card(PuzzleSolver.current_card())

func _show_card(code: int) -> void:
	if code < 0 or code >= PuzzleSolver.codebook.size():
		return
	var cfg := GameState.level
	var card: Array = PuzzleSolver.codebook[code]
	for i in rows.size():
		var row := rows[i]
		row.visible = i < card.size()
		if not row.visible:
			continue
		row.get_node("Icon").texture = cfg.threats[i].sprite
		var seq: Array[Vector2i] = []
		seq.assign(card[i])
		var display: Node2D = row.get_node("Sequence")
		display.symbol_size = Vector2.ONE * _fit(seq, display.tool_scale)
		display.show_sequence(seq)
	code_dot.texture = CODE_DOTS[code]
	code_letter.text = CODE_LETTERS[code]
	code_letter.add_theme_color_override("font_color", CODE_COLORS[code])

## Icon size that fits seq in the row slot: tool icons are tool_scale wide.
func _fit(seq: Array[Vector2i], tool_scale: float) -> float:
	if seq.is_empty():
		return max_symbol_size
	var units := 0.0
	for step in seq:
		units += 1.0 + (tool_scale if step.y != PuzzleSolver.NO_TOOL else 0.0)
	var room := row_width - symbol_separation * (seq.size() - 1)
	return minf(max_symbol_size, floorf(room / units))
