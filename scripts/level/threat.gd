extends Node2D
## Shows the current puzzle's threat. PuzzleSolver picks it on the host and
## syncs it, so both players see the same one.

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	PuzzleSolver.threat_changed.connect(_show_threat)
	_show_threat(PuzzleSolver.current_threat)

func _show_threat(threat: ThreatDef) -> void:
	if threat:
		sprite.texture = threat.sprite
