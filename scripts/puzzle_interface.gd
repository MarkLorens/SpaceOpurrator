extends Node
## Tells both players what's coming: the threat's name, with the button
## sequence that stops it drawn underneath by the TargetSequence display.

@onready var instruction: Label = $instruction

func _ready() -> void:
	PuzzleSolver.threat_changed.connect(_show_threat)
	_show_threat(PuzzleSolver.current_threat)

func _show_threat(threat: ThreatDef) -> void:
	instruction.text = "INCOMING: %s" % threat.display_name.to_upper() if threat else "FIX IT"
