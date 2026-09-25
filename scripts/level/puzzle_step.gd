class_name PuzzleStep
extends Resource
## One step of a puzzle sequence: tap the component, or, when a tool is set,
## hold the component while someone completes the tool's gesture.

@export var component: ButtonDef
## Optional. Must be a ButtonDef whose kind is TOOL.
@export var tool: ButtonDef
