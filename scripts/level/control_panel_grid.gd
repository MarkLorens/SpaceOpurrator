extends TileMapLayer
## Spawn mask for puzzle buttons. Paint cells over the control panel art; each
## painted cell can hold one button. The layer itself is hidden at runtime.
##
## Both players shuffle the cells with GameState.session_seed, so they get the
## same layout without sending positions.

@export var button_scene: PackedScene = preload("res://scenes/buttons/button.tscn")
## Half the button's on-screen size (64px sprite * scale 5 / 2). Cells whose
## button would cross a phone edge (every base viewport width) are skipped.
@export var button_radius := 160.0

func _ready() -> void:
	visible = false
	# GameState sets the seed before loading the level on both peers.
	if GameState.session_seed == 0:
		GameState.session_seed = randi() | 1  # solo / editor run
	_spawn_buttons(GameState.session_seed, GameState.level.button_count)

func _spawn_buttons(seed_value: int, button_count: int) -> void:
	# Project base width, NOT get_viewport_rect(): with stretch aspect "expand" a
	# wider phone reports a wider viewport, which would filter different cells
	# and desync the layout between players.
	var screen_w: float = ProjectSettings.get_setting("display/window/size/viewport_width")
	var cells := get_used_cells().filter(func(cell: Vector2i) -> bool:
		var x := to_global(map_to_local(cell)).x
		var to_edge := absf(x - roundf(x / screen_w) * screen_w)
		return to_edge >= button_radius)
	cells.sort()  # same order on both peers before shuffling

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(cells.size() - 1, 0, -1):  # Fisher-Yates with the shared rng
		var j := rng.randi_range(0, i)
		var tmp = cells[i]
		cells[i] = cells[j]
		cells[j] = tmp

	if cells.size() < button_count:
		push_warning("ControlPanelGrid: only %d usable cells for %d buttons" % [cells.size(), button_count])
	for i in mini(button_count, cells.size()):
		var button := button_scene.instantiate()
		button.btnValue = i + 1
		button.position = to_global(map_to_local(cells[i]))
		get_parent().add_child.call_deferred(button)
