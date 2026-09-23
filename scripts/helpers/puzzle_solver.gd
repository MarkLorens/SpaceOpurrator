extends Node

var correctSeq : Array[int]
var submittedSeq: Array[int]

func _ready() -> void:
	new_puzzle()

func new_puzzle() -> void:
	submittedSeq.clear()
	correctSeq = SequenceGenerator.generate_new_task()
	print("new sequence: ", correctSeq)

func build_correct_seq(num: int) -> void:
	submittedSeq.append(num)

func solve_puzzle() -> bool:
	var solved := correctSeq == submittedSeq
	print("expected: ", correctSeq, " submitted: ", submittedSeq)
	submittedSeq.clear()
	if solved:
		new_puzzle()
	return solved
