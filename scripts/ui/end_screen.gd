extends Control
## Shown on both players when a level ends (bar full = win, bar empty = loss).
## Win with levels left: Next Level. Loss: Play Again (back to level 1). Either
## player can press Continue; the host decides. Winning the last level swaps to
## FinalPanel: whole-run stats and Back to Menu.
## Its process_mode is ALWAYS (set in the scene) so the buttons work while the
## tree is paused.

const BG_LEVEL_COMPLETE := preload("res://assets/ui/backgrounds/level_complete.png")
const BG_GAME_WIN := preload("res://assets/ui/backgrounds/game_win.png")
const BG_FAILED := preload("res://assets/ui/backgrounds/main_bg.png")
const PLANET_SYLLABLES := ["MEW", "PUR", "ZOR", "KIT", "NYA", "FLUF", "TOR", "BUL", "WHIS", "KER"]

@onready var background: TextureRect = $Background
@onready var level_panel: Control = $CenterContainer
@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $CenterContainer/VBoxContainer/SubtitleLabel
@onready var score_label: RichTextLabel = $CenterContainer/VBoxContainer/ScoreLabel
@onready var continue_button: TextureButton = $CenterContainer/VBoxContainer/Buttons/ContinueButton
@onready var continue_label: Label = $CenterContainer/VBoxContainer/Buttons/ContinueButton/Label
@onready var exit_button: TextureButton = $CenterContainer/VBoxContainer/Buttons/ExitButton
@onready var final_panel: Control = $FinalPanel
@onready var stats_label: RichTextLabel = $FinalPanel/Stats/StatsLabel
@onready var menu_button: TextureButton = $FinalPanel/Stats/MenuButton
@onready var planet_label: Label = $FinalPanel/PlanetLabel

func _ready() -> void:
	hide()
	continue_button.pressed.connect(GameState.request_continue)
	exit_button.pressed.connect(_leave)
	menu_button.pressed.connect(_leave)

func _leave() -> void:
	get_tree().paused = false
	GameState.leave_game()

## solved: this level. run_solved / run_time: the whole run, for the final screen.
func show_result(won: bool, solved: int, run_solved: int, run_time: float) -> void:
	var final_win := won and not GameState.has_next_level()
	_submit_scores(final_win, run_solved, run_time)
	level_panel.visible = not final_win
	final_panel.visible = final_win
	if final_win:
		background.texture = BG_GAME_WIN
		var secs := int(run_time)
		stats_label.text = "Targets destroyed :  [b]%d[/b]\nTime elapsed :  [b]%02d:%02d[/b]" \
				% [run_solved, floori(run_time / 60.0), secs % 60]
		planet_label.text = "PLANET %s WAS CONQUERED" % _planet_name()
	elif won:
		background.texture = BG_LEVEL_COMPLETE
		title_label.text = "LEVEL COMPLETED"
		continue_label.text = "NEXT LEVEL"
		score_label.text = "[b]%d[/b] targets were destroyed" % solved
	else:
		background.texture = BG_FAILED
		title_label.text = "MISSION FAILED"
		continue_label.text = "PLAY AGAIN"
		score_label.text = "Only [b]%d[/b] targets were destroyed" % solved
	subtitle_label.visible = not won
	show()
	get_tree().paused = true

## Both players submit the shared run totals to their own Game Center account.
## most_targets after every level (Game Center keeps the best); fastest_time only
## for a finished run, in hundredths of a second (the leaderboard's format).
## ponytail: run_solved counts retries, so losing and replaying pads most_targets;
## reset it per retry if that becomes a problem.
func _submit_scores(final_win: bool, run_solved: int, run_time: float) -> void:
	if not Engine.has_singleton("GameCenterKit"):
		return
	var game_center := Engine.get_singleton("GameCenterKit")
	if not game_center.is_authenticated():
		return
	game_center.submit_score("most_targets", run_solved)
	if final_win:
		game_center.submit_score("fastest_time", roundi(run_time * 100.0))

## Built from the level's shared seed, so both players see the same name.
func _planet_name() -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.session_seed
	var planet := "%s%d-" % [char(rng.randi_range(65, 90)), rng.randi_range(10, 99)]
	for i in rng.randi_range(2, 3):
		planet += PLANET_SYLLABLES[rng.randi() % PLANET_SYLLABLES.size()]
	return planet
