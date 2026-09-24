extends TapArea

## Set by ControlPanelGrid before the button enters the tree.
var btnValue := 0  # index in the level's button_pool
var def: ButtonDef

func _ready() -> void:
	super()
	if def:
		$Sprite2D.texture = def.icon
	tapped.connect(func() -> void: PuzzleSolver.build_correct_seq(btnValue))
