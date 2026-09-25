class_name ButtonDef
extends Resource
## One kind of control-panel button. Every button shares button.tscn; a def only
## supplies what differs. Its value in the puzzle is its index in the level's
## button_pool.

## Drawn on the button and in the sequence display.
@export var icon: Texture2D
## Control-panel art: the button at rest, and while pressed.
@export var unclick: Texture2D
@export var click: Texture2D
