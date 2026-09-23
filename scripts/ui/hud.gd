extends Control
## Progress bar + puzzle timer. The host runs the numbers and streams the bar
## value to the client; the client's bar only displays it.

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var solve_button: Button = $"../SolveButton"

# Only the host's values matter in a networked game.
@export var endTarget: float = 100.0
@export var startProgress: float = 70.0
@export var drainPerSecond: float = 1.0
@export var solveReward: float = 10.0
## Seconds the player has to solve the current puzzle before losing timeoutPenalty.
@export var puzzleTime: float = 10.0
@export var timeoutPenalty: float = 10.0

## Red vignette shows when the bar drops to this fraction of endTarget.
@export var dangerRatio: float = 0.2

var puzzleTimeLeft: float
var vignette: ColorRect

func _ready() -> void:
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
	progress_bar.max_value = endTarget
	progress_bar.value = startProgress
	puzzleTimeLeft = puzzleTime

func _process(delta: float) -> void:
	if not GameState.game_running or not multiplayer.is_server():
		return
	# ProgressBar clamps value to [0, max_value] itself.
	progress_bar.value -= drainPerSecond * delta
	puzzleTimeLeft -= delta
	if puzzleTimeLeft <= 0.0:
		progress_bar.value -= timeoutPenalty
		PuzzleSolver.new_puzzle()
		puzzleTimeLeft = puzzleTime
	# ponytail: sends every frame; throttle to a fixed tick if bandwidth ever matters.
	_sync_progress.rpc(progress_bar.value, endTarget)

func _on_solve_pressed() -> void:
	_request_solve.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func _request_solve() -> void:
	if not GameState.game_running:
		return
	if PuzzleSolver.solve_puzzle():
		progress_bar.value += solveReward
		puzzleTimeLeft = puzzleTime

@rpc("authority", "call_remote", "unreliable_ordered")
func _sync_progress(value: float, max_value: float) -> void:
	progress_bar.max_value = max_value
	progress_bar.value = value
