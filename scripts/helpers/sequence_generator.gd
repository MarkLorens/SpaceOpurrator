extends Node

func generate_new_task() -> Array[int]:
	var task_sequence: Array[int] = [1, 2, 3]
	task_sequence.shuffle()
	return task_sequence
