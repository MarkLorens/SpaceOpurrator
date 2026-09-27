class_name ThreatDef
extends Resource
## A threat shown while players solve a puzzle. Purely visual: each round shows
## a random one from LevelConfig.threats.

@export var display_name := ""
@export var sprite: Texture2D
## Plays while this threat is on a player's screen (started each time it comes into view).
@export var sound: AudioStream
@export var sound_volume: int
## Where the code badge's line points on this threat, from the sprite's centre
## in sprite pixels (e.g. the pilot's dome). The badge sits up and to the left.
@export var badge_anchor := Vector2(0, -180)
## Button numbers as designers write them: 1 = first button in the level's
## button_pool, 2 = second, and so on.
@export var sequence: Array[int] = []
