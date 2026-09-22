extends Node

var correctSeq : Array[int]
var submittedSeq: Array[int]

func _ready() -> void:
	correctSeq = SequenceGenerator.generate_new_task()
	print("new sequence: ", correctSeq)

func build_correct_seq(num: int) -> void:
	submittedSeq.append(num)

func solve_puzzle() -> bool:
	var solved := correctSeq == submittedSeq
	print("expected: ", correctSeq, " submitted: ", submittedSeq)
	submittedSeq.clear()
	if solved:
		correctSeq = SequenceGenerator.generate_new_task()
		print("new sequence: ", correctSeq)
	return solved
