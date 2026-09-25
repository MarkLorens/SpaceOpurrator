class_name ButtonDef
extends Resource
## One kind of control-panel button. Every button shares button.tscn; a def only
## supplies what differs. Its value in the puzzle is its index in the level's
## button_defs().
##
## Components are tapped on their own, or held while someone works a tool.
## Tools only count as part of a tool + component step, via their gesture.

enum Kind { COMPONENT, TOOL }

@export var kind := Kind.COMPONENT
## Drawn on the button and in the sequence display.
@export var icon: Texture2D
## Control-panel art: the button at rest, and while pressed.
@export var unclick: Texture2D
@export var click: Texture2D
## Played on the phone that tapped it.
@export var sfx: AudioStream
## Tools only: what the player does on the tool while a component is held.
## A tool without one can't complete a step (and random puzzles skip it).
@export var gesture: ButtonGesture

func is_tool() -> bool:
	return kind == Kind.TOOL
