extends Node
## One shared puzzle, owned by the host. Clients send their button presses to
## the host and receive the current sequence back; only the host checks answers.

## Fires on host and client whenever a new sequence is set.
signal sequence_changed(seq: Array[int])

var correctSeq : Array[int]
var submittedSeq: Array[int]

func _ready() -> void:
	GameState.game_started.connect(func(): if multiplayer.is_server(): new_puzzle())

## Host only.
func new_puzzle() -> void:
	submittedSeq.clear()
	correctSeq = SequenceGenerator.generate_new_task()
	sequence_changed.emit(correctSeq)
	_set_sequence.rpc(correctSeq)

## Called by the buttons on either player; the press always lands on the host.
func build_correct_seq(num: int) -> void:
	_submit_press.rpc_id(1, num)

## Host only.
func solve_puzzle() -> bool:
	var solved := correctSeq == submittedSeq
	print("expected: ", correctSeq, " submitted: ", submittedSeq)
	submittedSeq.clear()
	if solved:
		new_puzzle()
	return solved

@rpc("any_peer", "call_local", "reliable")
func _submit_press(num: int) -> void:
	if GameState.game_running:
		submittedSeq.append(num)

@rpc("authority", "call_remote", "reliable")
func _set_sequence(seq: Array[int]) -> void:
	correctSeq = seq
	sequence_changed.emit(correctSeq)
