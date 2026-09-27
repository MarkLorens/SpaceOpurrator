extends Control

## Characters bob this many pixels up and down, taking this long each way.
@export var bob_height := 20.0
@export var bob_time := 1.5
## Play: the menu slides off to the left while the intro label slides in from
## the right, the label holds, then the create/join screen opens.
@export var slide_time := 1.2
@export var intro_hold_time := 2.0

@onready var play_button: TextureButton = $Column/PlayButton
## Opens Game Center's list of every leaderboard (native "Leaderboards" plugin, iOS only).
@onready var leaderboard_button: TextureButton = $LeaderboardButton
@onready var characters: TextureRect = $Characters
@onready var intro_label: Label = $Label
## Everything that slides off when Play is pressed.
@onready var menu_items: Array[Control] = [$Characters, $Column, $VolumeControl, $LeaderboardButton]

func _ready() -> void:
	var bob := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(characters, "position:y", -bob_height, bob_time).as_relative()
	bob.tween_property(characters, "position:y", bob_height, bob_time).as_relative()
	intro_label.position.x += get_viewport_rect().size.x  # waits off-screen right
	play_button.pressed.connect(_play_intro)
	leaderboard_button.visible = Engine.has_singleton("Leaderboards")
	if leaderboard_button.visible:
		leaderboard_button.pressed.connect(Engine.get_singleton("Leaderboards").show_all)
		# The volume bar slides out over this spot; step aside while it's open.
		$VolumeControl/Bar.visibility_changed.connect(func() -> void:
			leaderboard_button.visible = not $VolumeControl/Bar.visible)
	if Engine.has_singleton("GameCenterKit"):
		var game_center := Engine.get_singleton("GameCenterKit")
		game_center.authenticated.connect(_on_authenticated)
		game_center.authenticate()

func _play_intro() -> void:
	play_button.disabled = true  # no double start
	leaderboard_button.disabled = true
	var shift := -get_viewport_rect().size.x
	# Quart in-out: starts slow and builds speed, then settles the label gently.
	var slide := create_tween().set_parallel().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	for item in menu_items + [intro_label]:
		slide.tween_property(item, "position:x", shift, slide_time).as_relative()
	slide.chain().tween_interval(intro_hold_time)
	slide.chain().tween_callback(get_tree().change_scene_to_file.bind(GameState.CREATE_JOIN))

func _on_authenticated(ok: bool, error: String) -> void:
	print("Game Center authenticated: ", ok, " ", error)
