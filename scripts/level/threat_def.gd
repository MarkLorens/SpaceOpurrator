class_name ThreatDef
extends Resource
## A threat shown while players solve a puzzle. Purely visual: each round shows
## a random one from LevelConfig.threats.

@export var display_name := ""
@export var sprite: Texture2D
