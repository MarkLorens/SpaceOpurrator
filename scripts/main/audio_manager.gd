extends Node
## Autoload AudioManager (scenes/audio_manager.tscn): background music and
## one-shot sound effects (play_sfx). Every Godot button (BaseButton) in the
## game clicks when pressed; give one the metadata "no_click_sfx" to opt out.
## Picks the track from whichever scene is showing, so screens don't have to
## call it: main menu = menu music, matchmaking screens = the same music a bit
## quieter, level = level music. The HUD switches to low-time music in danger.

@export_file("*.wav", "*.ogg", "*.mp3") var MAIN_MENU_MUSIC: String
@export_file("*.wav", "*.ogg", "*.mp3") var LEVEL_MUSIC: String
@export_file("*.wav", "*.ogg", "*.mp3") var LOW_TIME_MUSIC: String

## Menu music volume while picking/joining a room or waiting in the game room.
@export var matchmaking_volume_db := -8.0
@export var fade_time := 1.0
## How much quieter the music gets while something else needs the spotlight
## (e.g. an enemy's sound on screen), and how fast it dips/returns.
@export var duck_db := -12.0
@export var duck_time := 0.4
## Played by every UI button (and panel buttons without their own sound).
@export var button_click_sfx: AudioStream = preload("res://assets/audio/4_buttons/general/general_button_click.wav")

const SILENT_DB := -40.0
## One-shot sounds that can overlap (e.g. quick button taps).
const SFX_VOICES := 8

## Two players so one track can fade out while the next fades in.
var _player_a := AudioStreamPlayer.new()
var _player_b := AudioStreamPlayer.new()
var _current: AudioStreamPlayer = _player_a
var _tweens := {}  # player -> its running volume tween
var _sfx: Array[AudioStreamPlayer] = []
var _music_db := 0.0  # the current track's normal volume, before ducking
var _ducked := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep playing while the game is paused
	for p: AudioStreamPlayer in [_player_a, _player_b]:
		p.volume_db = SILENT_DB
		add_child(p)
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx.append(p)
	get_tree().node_added.connect(_on_node_added)
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

## Hooks up the click for every button as it enters the tree, including ones
## made in code (e.g. lobby room cards). Finger-down, like the panel buttons.
func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.has_meta("no_click_sfx"):
		node.button_down.connect(play_click)

func play_click() -> void:
	play_sfx(button_click_sfx)

## Plays a one-shot sound on a free voice; if all are busy, the oldest-started
## voice (the first) is reused.
func play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	for p in _sfx:
		if not p.playing:
			p.stream = stream
			p.play()
			return
	_sfx[0].stream = stream
	_sfx[0].play()

## Lowers the music (true) or brings it back (false). Survives track changes,
## so switching to low-time music while ducked stays ducked.
func set_music_ducked(on: bool) -> void:
	if on == _ducked:
		return
	_ducked = on
	_fade(_current, _music_target(), duck_time)

func _music_target() -> float:
	return _music_db + (duck_db if _ducked else 0.0)

## Fades the current track to silence over `time` seconds, then stops it.
## The next play_music() fades its own track in as usual.
func fade_out_music(time: float) -> void:
	_fade(_current, SILENT_DB, time, true)

## Called by the HUD when the bar enters/leaves the danger zone.
func set_low_time(on: bool) -> void:
	play_music(LOW_TIME_MUSIC if on else LEVEL_MUSIC)

## Fades to `path` at `volume_db`. If that track is already playing, only its
## volume changes, so it isn't restarted.
func play_music(path: String, volume_db := 0.0) -> void:
	if path.is_empty():
		return
	var stream: AudioStream = load(path)
	_music_db = volume_db
	if _current.playing and _current.stream == stream:
		_fade(_current, _music_target())
		return
	var old := _current
	_current = _player_b if old == _player_a else _player_a
	_current.stream = stream
	_current.volume_db = SILENT_DB
	_current.play()
	_fade(_current, _music_target())
	_fade(old, SILENT_DB, fade_time, true)

func _fade(p: AudioStreamPlayer, to_db: float, time := fade_time, stop_after := false) -> void:
	if _tweens.has(p):
		_tweens[p].kill()
	var t := create_tween()
	t.tween_property(p, "volume_db", to_db, time)
	if stop_after:
		t.tween_callback(p.stop)
	_tweens[p] = t
