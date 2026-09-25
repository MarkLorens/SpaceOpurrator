class_name ThreatDef
extends Resource
## One predefined puzzle: the threat that appears and the sequence that stops it.
## Listed per level in LevelConfig.threats.

@export var display_name := ""
@export var sprite: Texture2D
## Button numbers as designers write them: 1 = first button in the level's
## button_pool, 2 = second, and so on.
@export var sequence: Array[int] = []
