extends Node
## One shared puzzle, owned by the host. Clients send their button presses to
## the host and receive the current sequence back; only the host checks answers.

## Fires on host and client whenever a new sequence is set.
signal sequence_changed(seq: Array[int])
## Fires on host and client whenever the entered sequence changes (press, reset).
signal submitted_changed(seq: Array[int])
## Fires on host and client with each new puzzle's threat (null on random levels).
signal threat_changed(threat: ThreatDef)
## Fires on host and client when the players enter the right sequence, just
## before the next puzzle arrives.
signal puzzle_solved

var correctSeq : Array[int]
var submittedSeq: Array[int]
var current_threat: ThreatDef
var _threat_index := -1  # index into GameState.level.threats; -1 = random puzzle

func _ready() -> void:
	GameState.level_started.connect(func(): if multiplayer.is_server(): new_puzzle())

## Host only.
func new_puzzle() -> void:
	_set_submitted.rpc([] as Array[int])
	var cfg := GameState.level
	var threat_index := -1
	var seq: Array[int]
	if cfg.threats.is_empty():
		seq = generate_sequence(cfg, GameState.session_seed)
	else:
		threat_index = _pick_threat(cfg)
		seq = threat_sequence(cfg, threat_index)
	_set_sequence.rpc(seq, threat_index)

## Random threat, never the same one twice in a row.
func _pick_threat(cfg: LevelConfig) -> int:
	var count := cfg.threats.size()
	if count == 1:
		return 0
	var i := randi() % (count - 1)
	return i + 1 if _threat_index >= 0 and i >= _threat_index else i

## A threat's sequence as button values (pool indices). Designers write 1-based
## button numbers, so 1 = button_pool[0].
func threat_sequence(cfg: LevelConfig, threat_index: int) -> Array[int]:
	var threat := cfg.threats[threat_index]
	var live := cfg.live_buttons(GameState.session_seed)
	var seq: Array[int] = []
	for number in threat.sequence:
		if not live.has(number - 1):
			push_warning("Threat '%s' asks for button %d, which isn't on this level's panel" % [threat.display_name, number])
		seq.append(number - 1)
	return seq

## Values are pool indices of this level's live buttons. No repeats until every
## live button has been used once.
func generate_sequence(cfg: LevelConfig, seed_value: int) -> Array[int]:
	var live := cfg.live_buttons(seed_value)
	var seq: Array[int] = []
	while seq.size() < cfg.sequence_length and not live.is_empty():
		live.shuffle()
		seq.append_array(live)
	return seq.slice(0, cfg.sequence_length)

## Called by the buttons on either player; the press always lands on the host.
func build_correct_seq(num: int) -> void:
	_submit_press.rpc_id(1, num)

## Called by the backspace button on either player; removes the last press.
func remove_last_press() -> void:
	_backspace.rpc_id(1)

## Host only.
func solve_puzzle() -> bool:
	var solved := correctSeq == submittedSeq
	print("expected: ", correctSeq, " submitted: ", submittedSeq)
	_set_submitted.rpc([] as Array[int])
	
	if solved:
		# Same reliable channel as _set_sequence, so peers hear this before the next threat.
		_announce_solved.rpc()
		new_puzzle()
	
	return solved

@rpc("any_peer", "call_local", "reliable")
func _submit_press(num: int) -> void:
	# Can't enter more symbols than the target has; backspace to change one.
	if GameState.game_running and submittedSeq.size() < correctSeq.size():
		submittedSeq.append(num)
		_set_submitted.rpc(submittedSeq)

@rpc("any_peer", "call_local", "reliable")
func _backspace() -> void:
	if GameState.game_running and not submittedSeq.is_empty():
		submittedSeq.pop_back()
		_set_submitted.rpc(submittedSeq)

@rpc("authority", "call_local", "reliable")
func _set_sequence(seq: Array[int], threat_index: int) -> void:
	correctSeq = seq
	_threat_index = threat_index
	var threats := GameState.level.threats
	current_threat = threats[threat_index] if threat_index >= 0 and threat_index < threats.size() else null
	threat_changed.emit(current_threat)
	sequence_changed.emit(correctSeq)

@rpc("authority", "call_local", "reliable")
func _announce_solved() -> void:
	puzzle_solved.emit()

@rpc("authority", "call_local", "reliable")
func _set_submitted(seq: Array[int]) -> void:
	submittedSeq = seq.duplicate()
	submitted_changed.emit(submittedSeq)
