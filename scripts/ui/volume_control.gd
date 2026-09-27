extends Control
## This phone's master volume, in the pause menu's top-right corner. The
## speaker button slides the bar out or tucks it away; press or drag along the
## bar to set the volume (tapping the muted speaker at its left end mutes).
## Only this phone changes: AudioManager.set_master_volume never syncs.

## Where the slider's track runs inside the bar art, in art pixels.
const TRACK_LEFT := 27.0
const TRACK_RIGHT := 80.0

@onready var bar: TextureRect = $Bar
@onready var knob: TextureRect = $Bar/Knob
@onready var button: TextureButton = $Button

func _ready() -> void:
	bar.hide()
	button.pressed.connect(func() -> void: bar.visible = not bar.visible)
	bar.gui_input.connect(_on_bar_input)
	# Tucked away again whenever the pause menu closes.
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			bar.hide())
	_place_knob()

func _on_bar_input(event: InputEvent) -> void:
	var pressed: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var dragged: bool = event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT != 0
	if not (pressed or dragged):
		return
	var art_x: float = event.position.x / _art_scale()
	AudioManager.set_master_volume((art_x - TRACK_LEFT) / (TRACK_RIGHT - TRACK_LEFT))
	_place_knob()
	bar.accept_event()

func _place_knob() -> void:
	var k := _art_scale()
	knob.size = knob.texture.get_size() * k
	var x := TRACK_LEFT + AudioManager.master_volume * (TRACK_RIGHT - TRACK_LEFT)
	knob.position = Vector2(x * k - knob.size.x / 2.0, (bar.size.y - knob.size.y) / 2.0)

## Screen pixels per art pixel of the bar.
func _art_scale() -> float:
	return bar.size.x / bar.texture.get_width()
