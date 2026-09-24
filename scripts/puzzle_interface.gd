extends Node

@onready var instruction: Label = $instruction

func _ready() -> void:
	PuzzleSolver.sequence_changed.connect(
		func(seq: Array[int]) -> void:
			instruction.text = " ".join(seq.map(str)
		)
	)
