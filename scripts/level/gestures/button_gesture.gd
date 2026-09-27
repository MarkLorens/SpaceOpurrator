@abstract
class_name ButtonGesture
extends Resource
## What the player does on a tool while a component is held (tap N times, ...).
## Set one on a tool's ButtonDef; each spawned button gets its own copy, so
## gestures can keep per-button state.
##
## To add a gesture: extend this, listen to the TapArea's signals in attach(),
## only make progress while `armed`, and emit `activated` when it completes.

# Emitted by the subclasses, not here, hence the ignores.
## The gesture is complete: the tool + held component step goes in.
@warning_ignore("unused_signal")
signal activated
## 0..1, drives the tool's battery bar; 0 = idle.
@warning_ignore("unused_signal")
signal progress_changed(value: float)

## Movement gestures (uses_drags) only: how far (pixels) outside the tool a
## drag can start while armed. Never reaches onto another button.
@export var grab_margin := 150.0

## True while some component is held (on either phone). Disarming resets.
var armed := false:
	set(value):
		armed = value
		if not armed:
			reset()

## Called once, when the button enters the tree.
@abstract func attach(area: TapArea) -> void

## Drop any progress.
@abstract func reset() -> void

## Movement gestures return true: while armed, a drag that starts on the tool
## belongs to the gesture instead of panning the board.
func uses_drags() -> bool:
	return false
