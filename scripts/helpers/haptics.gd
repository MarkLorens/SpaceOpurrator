class_name Haptics
## Phone haptics, shaped after iOS's standard feedback (UIFeedbackGenerator):
## impacts for presses, a selection tick for each step of a tool gesture, and
## the success / error notification patterns for the claw result.
## Input.vibrate_handheld plays these through Core Haptics on iOS; Android uses
## the same durations and strengths. Only ever buzzes this phone.

## A light tick, like scrolling a picker: one step of a tool gesture.
static func selection() -> void:
	_buzz(10, 0.35)

static func impact_light() -> void:
	_buzz(15, 0.5)

static func impact_medium() -> void:
	_buzz(20, 0.75)

static func impact_heavy() -> void:
	_buzz(30, 1.0)

## Two taps, soft then strong.
static func success() -> void:
	_pattern([[0, 20, 0.6], [110, 30, 1.0]])

## Three quick sharp taps.
static func error() -> void:
	_pattern([[0, 25, 0.9], [90, 25, 0.9], [180, 35, 1.0]])

## pulses: [delay_ms, duration_ms, amplitude] each.
static func _pattern(pulses: Array) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for pulse in pulses:
		if pulse[0] == 0:
			_buzz(pulse[1], pulse[2])
		else:
			# process_always: finish the pattern even if the game pauses mid-way
			tree.create_timer(pulse[0] / 1000.0, true).timeout.connect(_buzz.bind(pulse[1], pulse[2]))

static func _buzz(duration_ms: int, amplitude: float) -> void:
	Input.vibrate_handheld(duration_ms, amplitude)
