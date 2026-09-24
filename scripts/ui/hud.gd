extends Control
## Progress bar + puzzle timer. The host runs the numbers and streams the bar
## value to the client; the client's bar only displays it.

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var solve_button: BaseButton = $"../../SolveButton" # world-space, centre of the board
@onready var end_screen: Control = $"../EndScreen"

## Red vignette shows when the bar drops to this fraction of the end target.
@export var dangerRatio: float = 0.2

## Max screen-pixel travel between press and release that still counts as a tap.
@export var tap_max_distance: float = 20.0

## Bar tuning for this level. Only the host's copy drives the numbers.
var cfg: LevelConfig = GameState.level
var puzzleTimeLeft: float
var vignette: ColorRect
var _solve_press_pos: Vector2

func _ready() -> void:
	# Fire on release so a drag that starts on the button can be told apart from a tap.
	solve_button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	solve_button.button_down.connect(func() -> void:
		_solve_press_pos = get_viewport().get_mouse_position())
	
	solve_button.pressed.connect(_on_solve_pressed)
	
	# ponytail: quick test vignette built in code; move into hud.tscn if it stays.
	vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Code must be set before the shader is handed to the material, or it renders plain white.
	var shader := Shader.new()
	shader.code = """
	shader_type canvas_item;
	void fragment() {
		float d = distance(UV, vec2(0.5)) * 1.4;
		float pulse = 0.75 + 0.25 * sin(TIME * 4.0);
		COLOR = vec4(0.8, 0.0, 0.0, smoothstep(0.45, 1.0, d) * pulse);
	}
	"""
	
	var mat := ShaderMaterial.new()
	mat.shader = shader
	vignette.material = mat
	vignette.visible = false
	add_child(vignette)
	move_child(vignette, 0) # behind the progress bar
	
	# value_changed fires on host and client, so both see it.
	progress_bar.value_changed.connect(func(v: float) -> void:
		vignette.visible = v <= progress_bar.max_value * dangerRatio)
	
	progress_bar.max_value = cfg.end_target
	progress_bar.value = cfg.start_progress
	puzzleTimeLeft = cfg.puzzle_time

func _process(delta: float) -> void:
	if not GameState.game_running or not multiplayer.is_server():
		return
	# ProgressBar clamps value to [0, max_value] itself.
	progress_bar.value -= cfg.drain_per_second * delta
	puzzleTimeLeft -= delta
	if puzzleTimeLeft <= 0.0:
		progress_bar.value -= cfg.timeout_penalty
		PuzzleSolver.new_puzzle()
		puzzleTimeLeft = cfg.puzzle_time
	if progress_bar.value <= 0.0:
		_end_game.rpc(false, progress_bar.value)
		return
	# ponytail: sends every frame; throttle to a fixed tick if bandwidth ever matters.
	_sync_progress.rpc(progress_bar.value, cfg.end_target)

func _on_solve_pressed() -> void:
	if get_viewport().get_mouse_position().distance_to(_solve_press_pos) > tap_max_distance:
		return  # It was a drag, not a tap.
	_request_solve.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func _request_solve() -> void:
	if not GameState.game_running:
		return
	if PuzzleSolver.solve_puzzle():
		progress_bar.value += cfg.solve_reward
		puzzleTimeLeft = cfg.puzzle_time
		if progress_bar.value >= cfg.end_target:
			_end_game.rpc(true, progress_bar.value)

@rpc("authority", "call_remote", "unreliable_ordered")
func _sync_progress(value: float, max_value: float) -> void:
	progress_bar.max_value = max_value
	progress_bar.value = value

## Host decides; both players stop and see the end screen.
@rpc("authority", "call_local", "reliable")
func _end_game(won: bool, final_value: float) -> void:
	progress_bar.value = final_value
	GameState.game_running = false
	end_screen.show_result(won)
