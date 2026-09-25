extends TapArea
## A control-panel button. Components tell PuzzleSolver when they're held and
## released (a quick tap is a plain step); tools run their def's gesture, which
## only makes progress while some component is held.

## Longer presses on a component are holds (waiting for a tool), not taps.
const COMPONENT_TAP_MAX_TIME := 0.4

## Set by ControlPanelGrid before the button enters the tree.
var btnValue := 0  # index in the level's button_defs()
var def: ButtonDef
## On-screen scale for item art (unclick/click), which is drawn at the panel
## texture's resolution. Set by ControlPanelGrid to its own stretch.
var art_scale := Vector2.ONE
## Tools only: this button's own copy of def.gesture, so per-button state isn't shared.
var gesture: ButtonGesture

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	if def and def.unclick:
		_use_item_art()
	elif def:
		sprite.texture = def.icon  # old defs without panel art
		
	# Sound on finger-down, so holds and tools make a sound too. The step itself
	# is recorded by hold/release (components) or the gesture (tools).
	pressed.connect(func() -> void:
		if def:
			AudioManager.play_sfx(def.sfx))

	if def and def.is_tool():
		_setup_tool()
	else:
		_setup_component()

func _setup_component() -> void:
	tap_max_time = COMPONENT_TAP_MAX_TIME
	pressed.connect(func() -> void: PuzzleSolver.hold_component(btnValue))
	released.connect(func(was_tap: bool) -> void: PuzzleSolver.release_component(btnValue, was_tap))

func _setup_tool() -> void:
	if not def.gesture:
		return  # no gesture yet: this tool can't complete a step
	gesture = def.gesture.duplicate()
	gesture.attach(self)
	gesture.activated.connect(func() -> void: PuzzleSolver.complete_tool(btnValue))
	_add_progress_ring()
	PuzzleSolver.held_component_changed.connect(_on_held_component_changed)
	_on_held_component_changed(PuzzleSolver.held_component)

func _on_held_component_changed(value: int) -> void:
	gesture.armed = value != PuzzleSolver.NONE

## Panel shows unclick at rest and click while held. The icon is only for the
## sequence display.
func _use_item_art() -> void:
	sprite.texture = def.unclick
	sprite.scale = art_scale / scale  # undo this node's scale so the art matches the panel
	if def.click:
		pressed.connect(func() -> void: sprite.texture = def.click)
		released.connect(func(_was_tap: bool) -> void: sprite.texture = def.unclick)
	# Tap area covers the whole item instead of the small prototype circle.
	var rect := RectangleShape2D.new()
	rect.size = def.unclick.get_size() * sprite.scale
	collision.scale = Vector2.ONE
	collision.shape = rect

## Shows how far along the tool's gesture is. Hidden while idle.
func _add_progress_ring() -> void:
	var ring := ProgressRing.new()
	ring.scale = Vector2.ONE / scale  # draw in world pixels, like the art
	ring.z_index = 1
	var art_size := sprite.texture.get_size() * sprite.scale * scale if sprite.texture else Vector2.ZERO
	if art_size != Vector2.ZERO:
		ring.radius = minf(art_size.x, art_size.y) * 0.45
	add_child(ring)
	gesture.progress_changed.connect(func(value: float) -> void: ring.progress = value)
