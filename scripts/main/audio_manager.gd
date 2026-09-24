extends Node
## Autoload AudioManager (scenes/audio_manager.tscn): background music.
## Picks the track from whichever scene is showing, so screens don't have to
## call it: main menu = menu music, matchmaking screens = the same music a bit
## quieter, level = level music. The HUD switches to low-time music in danger.

@export_file("*.wav", "*.ogg", "*.mp3") var MAIN_MENU_MUSIC: String
@export_file("*.wav", "*.ogg", "*.mp3") var LEVEL_MUSIC: String
@export_file("*.wav", "*.ogg", "*.mp3") var LOW_TIME_MUSIC: String

## Menu music volume while picking/joining a room or waiting in the game room.
@export var matchmaking_volume_db := -8.0
@export var fade_time := 1.0

const SILENT_DB := -40.0

## Two players so one track can fade out while the next fades in.
var _player_a := AudioStreamPlayer.new()
var _player_b := AudioStreamPlayer.new()
var _current: AudioStreamPlayer = _player_a
var _tweens := {}  # player -> its running volume tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep playing while the game is paused
	for p: AudioStreamPlayer in [_player_a, _player_b]:
		p.volume_db = SILENT_DB
		add_child(p)
	get_tree().scene_changed.connect(_on_scene_changed)
	_on_scene_changed()

func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	match scene.scene_file_path:
		GameState.MAIN_MENU:
			play_music(MAIN_MENU_MUSIC)
		GameState.CREATE_JOIN, GameState.LOBBY, GameState.GAME_ROOM:
			play_music(MAIN_MENU_MUSIC, matchmaking_volume_db)
		GameState.LEVEL:
			play_music(LEVEL_MUSIC)

## Called by the HUD when the bar enters/leaves the danger zone.
func set_low_time(on: bool) -> void:
	play_music(LOW_TIME_MUSIC if on else LEVEL_MUSIC)

## Fades to `path` at `volume_db`. If that track is already playing, only its
## volume changes, so it isn't restarted.
func play_music(path: String, volume_db := 0.0) -> void:
	if path.is_empty():
		return
	var stream: AudioStream = load(path)
	if _current.playing and _current.stream == stream:
		_fade(_current, volume_db)
		return
	var old := _current
	_current = _player_b if old == _player_a else _player_a
	_current.stream = stream
	_current.volume_db = SILENT_DB
	_current.play()
	_fade(_current, volume_db)
	_fade(old, SILENT_DB, true)

func _fade(p: AudioStreamPlayer, to_db: float, stop_after := false) -> void:
	if _tweens.has(p):
		_tweens[p].kill()
	var t := create_tween()
	t.tween_property(p, "volume_db", to_db, fade_time)
	if stop_after:
		t.tween_callback(p.stop)
	_tweens[p] = t
