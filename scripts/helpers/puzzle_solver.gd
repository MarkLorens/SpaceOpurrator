extends Node
## One shared puzzle, owned by the host. Clients send their button input to the
## host and receive the current sequence back; only the host checks answers.
##
## A sequence is a list of steps, each Vector2i(component, tool): values are
## indices into GameState.level.button_defs(), and tool is NO_TOOL for a plain
## tap. A tool + component step goes in when a tool's gesture completes while a
## component is held — on either phone, so one player can hold while the other
## works the tool.

const NO_TOOL := -1
const NONE := -1

## Fires on host and client whenever a new sequence is set.
signal sequence_changed(seq: Array[Vector2i])
## Fires on host and client whenever the entered sequence changes (press, reset).
signal submitted_changed(seq: Array[Vector2i])
## Fires on host and client with each new puzzle's threat (null if the level has none).
signal threat_changed(threat: ThreatDef)
## Fires on host and client when the players enter the right sequence, just
## before the next puzzle arrives.
signal puzzle_solved
## Fires on host and client when the held component changes (NONE = nothing held).
signal held_component_changed(value: int)

var correctSeq: Array[Vector2i]
var submittedSeq: Array[Vector2i]
var current_threat: ThreatDef
## The component tools act on: the most recently pressed one still held.
var held_component := NONE
var _sequence_index := -1  # last handwritten sequence, so it isn't picked twice in a row
var _threat_index := -1
# Host only.
var _held: Array[int] = []  # held components, oldest first
var _used_in_combo: Array[int] = []  # held components already paired with a tool; their release isn't a tap

func _ready() -> void:
	GameState.level_started.connect(func():
		_held.clear()
		_used_in_combo.clear()
		_sequence_index = -1
		_threat_index = -1
		_set_held(NONE)
		if multiplayer.is_server(): new_puzzle())

## Host only.
func new_puzzle() -> void:
	_set_submitted.rpc([] as Array[Vector2i])
	var cfg := GameState.level
	var seq: Array[Vector2i]
	if cfg.sequences.is_empty():
		seq = generate_sequence(cfg, GameState.session_seed)
	else:
		_sequence_index = _pick_other(cfg.sequences.size(), _sequence_index)
		seq = sequence_steps(cfg, _sequence_index)
	_threat_index = _pick_other(cfg.threats.size(), _threat_index)
	_set_sequence.rpc(seq, _threat_index)

## Random index in [0, count), never `last` twice in a row. -1 when count is 0.
func _pick_other(count: int, last: int) -> int:
	if count <= 1:
		return count - 1
	var i := randi() % (count - 1)
	return i + 1 if last >= 0 and i >= last else i

## A handwritten sequence as step values.
func sequence_steps(cfg: LevelConfig, sequence_index: int) -> Array[Vector2i]:
	var defs := cfg.button_defs()
	var seq: Array[Vector2i] = []
	for step in cfg.sequences[sequence_index].steps:
		if not step or not step.component or step.component.is_tool():
			push_warning("Level sequence %d has a step without a component; skipping it" % sequence_index)
			continue
		if step.tool and not step.tool.is_tool():
			push_warning("Level sequence %d pairs a component with a non-tool; treating it as a tap" % sequence_index)
		var tool := defs.find(step.tool) if step.tool and step.tool.is_tool() else NO_TOOL
		seq.append(Vector2i(defs.find(step.component), tool))
	return seq

## Random steps from this level's live buttons. Any live component, sometimes
## paired with any live tool that has a gesture. Repeats are fine.
func generate_sequence(cfg: LevelConfig, seed_value: int) -> Array[Vector2i]:
	var defs := cfg.button_defs()
	var components: Array[int] = []
	var tools: Array[int] = []
	for value in cfg.live_buttons(seed_value):
		if not defs[value].is_tool():
			components.append(value)
		elif defs[value].gesture:
			tools.append(value)
	var seq: Array[Vector2i] = []
	if components.is_empty():
		push_error("PuzzleSolver: level has no live components to build a sequence from")
		return seq
	for i in cfg.sequence_length:
		var paired := not tools.is_empty() and randf() < cfg.combo_chance
		seq.append(Vector2i(components.pick_random(), tools.pick_random() if paired else NO_TOOL))
	return seq

## Called by component buttons on either player when a finger goes down on them.
func hold_component(value: int) -> void:
	if not multiplayer.is_server():
		_set_held(value)  # show it locally right away; the host confirms
	_hold.rpc_id(1, value)

## Called by component buttons on either player when the finger lifts (or
## drags off). was_tap: it was a quick tap, so it counts as a plain step.
func release_component(value: int, was_tap: bool) -> void:
	_release.rpc_id(1, value, was_tap)

## Called by tool buttons on either player when their gesture completes.
func complete_tool(value: int) -> void:
	_complete_tool.rpc_id(1, value)

## Called by the backspace button on either player; removes the last step.
func remove_last_press() -> void:
	_backspace.rpc_id(1)

## Host only.
func solve_puzzle() -> bool:
	var solved := correctSeq == submittedSeq
	print("expected: ", correctSeq, " submitted: ", submittedSeq)
	_set_submitted.rpc([] as Array[Vector2i])

	if solved:
		# Same reliable channel as _set_sequence, so peers hear this before the next threat.
		_announce_solved.rpc()
		new_puzzle()

	return solved

@rpc("any_peer", "call_local", "reliable")
func _hold(value: int) -> void:
	_held.erase(value)
	_held.append(value)
	_used_in_combo.erase(value)
	_sync_held()

@rpc("any_peer", "call_local", "reliable")
func _release(value: int, was_tap: bool) -> void:
	_held.erase(value)
	if was_tap and not _used_in_combo.has(value):
		_submit_step(Vector2i(value, NO_TOOL))
	_used_in_combo.erase(value)
	_sync_held()

@rpc("any_peer", "call_local", "reliable")
func _complete_tool(value: int) -> void:
	# The component may have been let go while this was in flight: then the
	# step just resets, like releasing early.
	if _held.is_empty():
		return
	var component: int = _held.back()
	if not _used_in_combo.has(component):
		_used_in_combo.append(component)
	_submit_step(Vector2i(component, value))

func _sync_held() -> void:
	_set_held.rpc(NONE if _held.is_empty() else _held.back())

## Host only.
func _submit_step(step: Vector2i) -> void:
	# Can't enter more steps than the target has; backspace to change one.
	if GameState.game_running and submittedSeq.size() < correctSeq.size():
		submittedSeq.append(step)
		_set_submitted.rpc(submittedSeq)

@rpc("any_peer", "call_local", "reliable")
func _backspace() -> void:
	if GameState.game_running and not submittedSeq.is_empty():
		submittedSeq.pop_back()
		_set_submitted.rpc(submittedSeq)

@rpc("authority", "call_local", "reliable")
func _set_sequence(seq: Array[Vector2i], threat_index: int) -> void:
	correctSeq = seq
	var threats := GameState.level.threats
	current_threat = threats[threat_index] if threat_index >= 0 and threat_index < threats.size() else null
	threat_changed.emit(current_threat)
	sequence_changed.emit(correctSeq)

@rpc("authority", "call_local", "reliable")
func _announce_solved() -> void:
	puzzle_solved.emit()

@rpc("authority", "call_local", "reliable")
func _set_submitted(seq: Array[Vector2i]) -> void:
	submittedSeq = seq.duplicate()
	submitted_changed.emit(submittedSeq)

@rpc("authority", "call_local", "reliable")
func _set_held(value: int) -> void:
	if value != held_component:
		held_component = value
		held_component_changed.emit(value)
