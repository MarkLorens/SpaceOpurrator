@abstract
class_name ButtonGesture
extends Resource
## What the player does on a tool while a component is held (tap N times, ...).
## Set one on a tool's ButtonDef; each spawned button gets its own copy, so
## gestures can keep per-button state.
##
## To add a gesture: extend this, listen to the TapArea's signals in attach(),
## only make progress while `armed`, and emit `activated` when it completes.

## The gesture is complete: the tool + held component step goes in.
signal activated
## 0..1, drives the tool's progress ring; 0 = idle.
signal progress_changed(value: float)

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
