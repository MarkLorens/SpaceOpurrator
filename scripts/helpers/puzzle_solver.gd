extends Node
## One shared puzzle, owned by the host. Clients send their button presses to
## the host and receive the current sequence back; only the host checks answers.

## Fires on host and client whenever a new sequence is set.
signal sequence_changed(seq: Array[int])
## Fires on host and client whenever the entered sequence changes (press, reset).
signal submitted_changed(seq: Array[int])

var correctSeq : Array[int]
var submittedSeq: Array[int]

func _ready() -> void:
	GameState.level_started.connect(func(): if multiplayer.is_server(): new_puzzle())

## Host only.
func new_puzzle() -> void:
	_set_submitted.rpc([] as Array[int])
	correctSeq = generate_sequence(GameState.level)
	sequence_changed.emit(correctSeq)
	_set_sequence.rpc(correctSeq)

## No repeats until every symbol has been used once.
func generate_sequence(cfg: LevelConfig) -> Array[int]:
	var seq: Array[int] = []
	while seq.size() < cfg.sequence_length:
		var pool: Array[int] = []
		pool.assign(range(1, cfg.symbol_count + 1))
		pool.shuffle()
		seq.append_array(pool)
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

@rpc("authority", "call_remote", "reliable")
func _set_sequence(seq: Array[int]) -> void:
	correctSeq = seq
	sequence_changed.emit(correctSeq)

@rpc("authority", "call_local", "reliable")
func _set_submitted(seq: Array[int]) -> void:
	submittedSeq = seq.duplicate()
	submitted_changed.emit(submittedSeq)
