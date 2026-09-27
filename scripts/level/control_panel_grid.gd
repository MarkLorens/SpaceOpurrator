extends Node2D
## Button spawn points: one Marker2D child per panel in the control panel art,
## placed at the panel's centre in texture pixels. The two next slot markers are
## kept free of random buttons: they hold the code cards' Next button. Tools get
## first pick of tool_slots. This node's scale matches the board's texture
## stretch (display size / texture size), so if that stretch changes, update the
## scale here, not the markers.
##
## Both players shuffle the markers with GameState.session_seed, so they get the
## same layout without sending positions.

## Shared by every button; the level's ButtonDefs supply what differs.
@export var button_scene: PackedScene = preload("res://scenes/buttons/button.tscn")
## Half the button's on-screen size (64px sprite * scale 5 / 2). Markers whose
## button would cross a phone edge (every base viewport width) are skipped.
@export var button_radius := 160.0
## Dedicated panels for the Next button, one beside each place the puzzle
## interface can be. Never used for random buttons, even when the level has no
## code cards.
@export var next_slot_left: Marker2D
@export var next_slot_right: Marker2D
@export var next_button_scene: PackedScene = preload("res://scenes/buttons/next_card_button.tscn")
## Panels within reach of every other panel with both phones side by side (the
## innermost ones), so any tool + component pair fits on screen together. Tools
## spawn here first; components get whatever's left, plus every other panel.
@export var tool_slots: Array[Marker2D] = []

func _ready() -> void:
	# GameState sets the seed before loading the level on both peers.
	if GameState.session_seed == 0:
		GameState.session_seed = randi() | 1  # solo / editor run
	_spawn_buttons(GameState.session_seed, GameState.level)

func _spawn_buttons(seed_value: int, cfg: LevelConfig) -> void:
	# Project base width, NOT get_viewport_rect(): with stretch aspect "expand" a
	# wider phone reports a wider viewport, which would filter different markers
	# and desync the layout between players.
	var screen_w: float = ProjectSettings.get_setting("display/window/size/viewport_width")
	
	# Child order comes from the scene file, so it's the same on both peers.
	var tool_spots: Array[Vector2] = []
	var spots: Array[Vector2] = []
	for marker in get_children():
		if marker == next_slot_left or marker == next_slot_right:
			continue
		var pos: Vector2 = marker.global_position
		if absf(pos.x - roundf(pos.x / screen_w) * screen_w) >= button_radius:
			(tool_spots if tool_slots.has(marker) else spots).append(pos)

	# Pool indices, tools first so they claim the tool spots.
	var pool := cfg.button_pool
	var order: Array[int] = []
	order.assign(range(pool.size()).filter(func(i: int) -> bool: return pool[i] and pool[i].is_tool()))
	var claimed := mini(order.size(), tool_spots.size())
	if order.size() > tool_spots.size():
		push_warning("ControlPanelGrid: %d tools but %d tool slots; the rest spawn anywhere" % [order.size(), tool_spots.size()])
	order.append_array(range(pool.size()).filter(func(i: int) -> bool: return pool[i] and not pool[i].is_tool()))

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_shuffle(tool_spots, rng)
	spots.append_array(tool_spots.slice(claimed))  # unclaimed tool spots are open to anyone
	_shuffle(spots, rng)
	var placed := tool_spots.slice(0, claimed)  # tools, in order's order
	placed.append_array(spots)

	# The puzzle already assumes every pool button is on the panel.
	if placed.size() < order.size():
		push_error("ControlPanelGrid: only %d usable panels for %d buttons; add markers" % [placed.size(), order.size()])
	
	for i in mini(order.size(), placed.size()):
		var button := button_scene.instantiate()
		button.btnValue = order[i]
		button.def = pool[order[i]]
		button.art_scale = scale  # item art is drawn at the panel texture's resolution
		button.position = placed[i]
		get_parent().add_child.call_deferred(button)

## Fisher-Yates with the shared rng (Array.shuffle() isn't seedable).
func _shuffle(values: Array, rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = values[i]
		values[i] = values[j]
		values[j] = tmp

## Puts the Next button on the dedicated panel nearest near_x (the puzzle
## interface), so the player beside it can flip cards for the one reading them.
func place_next_button(near_x: float) -> void:
	if not next_slot_left or not next_slot_right:
		push_error("ControlPanelGrid: next_slot_left/right not set; no Next button")
		return
	var left_gap := absf(next_slot_left.global_position.x - near_x)
	var right_gap := absf(next_slot_right.global_position.x - near_x)
	var best := next_slot_left if left_gap < right_gap else next_slot_right
	var button := next_button_scene.instantiate()
	button.art_scale = scale  # same panel art resolution as the item buttons
	button.position = best.global_position
	get_parent().add_child.call_deferred(button)
