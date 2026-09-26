extends Node2D
## Button spawn points: one Marker2D child per panel in the control panel art,
## placed at the panel's centre in texture pixels. The two next slot markers are
## kept free of random buttons: they hold the code cards' Next button. This node's scale matches the
## board's texture stretch (display size / texture size), so if that stretch
## changes, update the scale here, not the markers.
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

func _ready() -> void:
	# GameState sets the seed before loading the level on both peers.
	if GameState.session_seed == 0:
		GameState.session_seed = randi() | 1  # solo / editor run
	_spawn_buttons(GameState.session_seed, GameState.level)

func _spawn_buttons(seed_value: int, cfg: LevelConfig) -> void:
	var picked := cfg.pick_buttons(seed_value)
	var defs := cfg.button_defs()
	# Project base width, NOT get_viewport_rect(): with stretch aspect "expand" a
	# wider phone reports a wider viewport, which would filter different markers
	# and desync the layout between players.
	var screen_w: float = ProjectSettings.get_setting("display/window/size/viewport_width")
	
	# Child order comes from the scene file, so it's the same on both peers.
	var spots: Array[Vector2] = []
	for marker in get_children():
		if marker == next_slot_left or marker == next_slot_right:
			continue
		var pos: Vector2 = marker.global_position
		if absf(pos.x - roundf(pos.x / screen_w) * screen_w) >= button_radius:
			spots.append(pos)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(spots.size() - 1, 0, -1):  # Fisher-Yates with the shared rng
		var j := rng.randi_range(0, i)
		var tmp := spots[i]
		spots[i] = spots[j]
		spots[j] = tmp

	# The puzzle already assumes every picked button is on the panel.
	if spots.size() < picked.size():
		push_error("ControlPanelGrid: only %d usable panels for %d buttons; add markers" % [spots.size(), picked.size()])
	
	for i in mini(picked.size(), spots.size()):
		var button := button_scene.instantiate()
		button.btnValue = picked[i]
		button.def = defs[picked[i]]
		button.art_scale = scale  # item art is drawn at the panel texture's resolution
		button.position = spots[i]
		get_parent().add_child.call_deferred(button)


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
