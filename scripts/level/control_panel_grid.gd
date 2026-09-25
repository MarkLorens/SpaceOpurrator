extends Node2D
## Button spawn points: one Marker2D child per panel in the control panel art,
## placed at the panel's centre in texture pixels. This node's scale matches the
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

func _ready() -> void:
	# GameState sets the seed before loading the level on both peers.
	if GameState.session_seed == 0:
		GameState.session_seed = randi() | 1  # solo / editor run
	_spawn_buttons(GameState.session_seed, GameState.level)

func _spawn_buttons(seed_value: int, cfg: LevelConfig) -> void:
	var picked := cfg.pick_buttons(seed_value)
	# Project base width, NOT get_viewport_rect(): with stretch aspect "expand" a
	# wider phone reports a wider viewport, which would filter different markers
	# and desync the layout between players.
	var screen_w: float = ProjectSettings.get_setting("display/window/size/viewport_width")
	
	# Child order comes from the scene file, so it's the same on both peers.
	var spots: Array[Vector2] = []
	for marker in get_children():
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
		button.def = cfg.button_pool[picked[i]]
		button.art_scale = scale  # item art is drawn at the panel texture's resolution
		button.position = spots[i]
		get_parent().add_child.call_deferred(button)
