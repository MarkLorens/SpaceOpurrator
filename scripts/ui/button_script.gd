extends TapArea

## Set by ControlPanelGrid before the button enters the tree.
var btnValue := 0  # index in the level's button_pool
var def: ButtonDef
## On-screen scale for item art (unclick/click), which is drawn at the panel
## texture's resolution. Set by ControlPanelGrid to its own stretch.
var art_scale := Vector2.ONE

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	super()
	if def and def.unclick:
		_use_item_art()
	elif def:
		sprite.texture = def.icon  # old defs without panel art
	tapped.connect(func() -> void: PuzzleSolver.build_correct_seq(btnValue))

## Panel shows unclick at rest and click while held. The icon is only for the
## sequence display.
func _use_item_art() -> void:
	sprite.texture = def.unclick
	sprite.scale = art_scale / scale  # undo this node's scale so the art matches the panel
	held_changed.connect(func(held: bool) -> void:
		sprite.texture = def.click if held and def.click else def.unclick)
	# Tap area covers the whole item instead of the small prototype circle.
	var rect := RectangleShape2D.new()
	rect.size = def.unclick.get_size() * sprite.scale
	collision.scale = Vector2.ONE
	collision.shape = rect
