extends TapArea
## The code cards' Next button: flips the puzzle interface to the next card on
## both phones. ControlPanelGrid spawns it on a dedicated panel beside the
## puzzle interface, so the other player can flip while the reader reads.
## Drawn with the flip item's panel art, like the item buttons.

const FLIP: ButtonDef = preload("res://tres/flip.tres")

## On-screen scale for the panel art. Set by ControlPanelGrid to its own stretch.
var art_scale := Vector2.ONE

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	sprite.texture = FLIP.unclick
	sprite.scale = art_scale / scale  # undo this node's scale so the art matches the panel
	pressed.connect(func() -> void:
		sprite.texture = FLIP.click
		AudioManager.play_sfx(FLIP.sfx))
	released.connect(func(_was_tap: bool) -> void: sprite.texture = FLIP.unclick)
	tapped.connect(PuzzleSolver.next_card)
	# Tap area covers the whole item.
	var rect := RectangleShape2D.new()
	rect.size = FLIP.unclick.get_size() * sprite.scale
	collision.shape = rect
