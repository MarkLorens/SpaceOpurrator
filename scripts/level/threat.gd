extends Node2D
## Shows the current puzzle's threat. PuzzleSolver picks it on the host and
## syncs it, so both players see the same one.
##
## The threat's sound plays whenever it's on this phone's screen: it starts
## from the top each time the threat comes into view and fades out when it
## leaves, and the background music dips while it plays. The notifier is part
## of this scene, so it follows the threat to whichever board slot the level
## puts it in.
##
## When the players solve the puzzle, the threat gets shot and blows up: a
## random laser sound fires, then the explosion plays over it with a random
## explosion sound, and the next threat appears once the blast has finished.
##
## With code cards on, a badge under the threat shows its code (X/Y/Z). It's
## part of the sprite, so it hides and changes along with it.

## Seconds to fade the sound out once the threat scrolls off screen.
@export var fade_out_time := 0.4
## Explosion frame at which the old threat disappears (the blast's biggest point).
@export var hide_on_frame := 2
## Seconds between the laser firing and the explosion.
@export var laser_lead_time := 0.4

const LASER_SOUNDS: Array[AudioStream] = [
	preload("res://assets/audio/1_laser shooting/1_laser-beam.wav"),
	preload("res://assets/audio/1_laser shooting/2_laser-gun.wav"),
	preload("res://assets/audio/1_laser shooting/3_laser-heavy.wav"),
]

const EXPLOSION_SOUNDS: Array[AudioStream] = [
	preload("res://assets/audio/3_explosion/1_explosion.wav"),
	preload("res://assets/audio/3_explosion/2_explosion.wav"),
	preload("res://assets/audio/3_explosion/3_explosion.wav"),
	preload("res://assets/audio/3_explosion/4_explosion.wav"),
	preload("res://assets/audio/3_explosion/5_explosion.wav"),
]

@onready var sprite: Sprite2D = $Sprite2D
@onready var on_screen: VisibleOnScreenNotifier2D = $OnScreen
@onready var enemy_sound: AudioStreamPlayer = $EnemySound
@onready var explosion: AnimatedSprite2D = $Explosion
@onready var code_badge: Node2D = $Sprite2D/CodeBadge
@onready var code_dot: Sprite2D = $Sprite2D/CodeBadge/Dot
@onready var code_letter: Label = $Sprite2D/CodeBadge/Letter

var _fade: Tween
var _exploding := false
var _pending: ThreatDef  # next threat, shown once the explosion finishes

func _ready() -> void:
	on_screen.screen_entered.connect(_start_sound)
	on_screen.screen_exited.connect(_stop_sound)
	# Tracks aren't imported as loops; keep one going while the threat is in view.
	enemy_sound.finished.connect(func() -> void:
		if on_screen.is_on_screen():
			enemy_sound.play())
	explosion.frame_changed.connect(func() -> void:
		if explosion.frame == hide_on_frame:
			sprite.visible = false)
	explosion.animation_finished.connect(_on_explosion_finished)
	PuzzleSolver.puzzle_solved.connect(_explode)
	PuzzleSolver.threat_changed.connect(_show_threat)
	_show_threat(PuzzleSolver.current_threat)

## Laser first, then the blast. The next threat waits until the blast clears.
func _explode() -> void:
	_exploding = true
	_pending = null
	AudioManager.play_sfx(LASER_SOUNDS.pick_random())
	create_tween().tween_callback(_blast).set_delay(laser_lead_time)  # tween dies with the scene

func _blast() -> void:
	explosion.visible = true
	explosion.play(&"boom")
	explosion.frame = 0
	AudioManager.play_sfx(EXPLOSION_SOUNDS.pick_random())

func _on_explosion_finished() -> void:
	explosion.visible = false
	sprite.visible = true
	_exploding = false
	if _pending:
		_show_threat(_pending)

func _show_threat(threat: ThreatDef) -> void:
	if _exploding:
		_pending = threat  # wait for the blast to clear
		return
	if threat:
		sprite.texture = threat.sprite
	_show_code(PuzzleSolver.current_code)
	on_screen.rect = sprite.get_rect()  # track the sprite's size as threats change
	if on_screen.is_on_screen():
		_start_sound()  # a new threat appeared while the player is looking

## Reuses the puzzle interface's code art so the badge matches the cards.
func _show_code(code: int) -> void:
	code_badge.visible = code >= 0 and code < PuzzleInterface.CODE_LETTERS.size()
	if not code_badge.visible:
		return
	code_dot.texture = PuzzleInterface.CODE_DOTS[code]
	code_letter.text = PuzzleInterface.CODE_LETTERS[code]
	code_letter.add_theme_color_override("font_color", PuzzleInterface.CODE_COLORS[code])

func _start_sound() -> void:
	var threat := PuzzleSolver.current_threat
	if threat == null or threat.sound == null:
		return
	if _fade:
		_fade.kill()
	enemy_sound.stream = threat.sound
	enemy_sound.volume_db = threat.sound_volume
	enemy_sound.play()
	AudioManager.set_music_ducked(true)

func _stop_sound() -> void:
	AudioManager.set_music_ducked(false)
	if not enemy_sound.playing:
		return
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(enemy_sound, "volume_db", -40.0, fade_out_time)
	_fade.tween_callback(enemy_sound.stop)

func _exit_tree() -> void:
	AudioManager.set_music_ducked(false)  # leaving the level while the threat was in view
