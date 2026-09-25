class_name LevelConfig
extends Resource
## Everything that changes between levels. One .tres per level, listed in
## GameState.LEVELS; the level scene itself is shared.

@export_group("Puzzle")
## Symbols in each target sequence.
@export var sequence_length := 3
## Buttons this level can use. Each spawns at most once.
@export var button_pool: Array[ButtonDef] = []
## How many pool buttons spawn on the control panel (capped at the pool size).
@export var button_count := 3
## How many of the spawned buttons appear in sequences; the rest are decoys.
@export var symbol_count := 3
## Predefined puzzles. When set, each round shows one of these threats and asks
## for its sequence; when empty, sequences are random (sequence_length long).
@export var threats: Array[ThreatDef] = []

@export_group("Progress bar")
@export var end_target := 100.0
@export var start_progress := 70.0
@export var drain_per_second := 1.0
@export var solve_reward := 10.0
## Seconds to solve the current puzzle before losing timeout_penalty.
@export var puzzle_time := 10.0
@export var timeout_penalty := 10.0


## Pool indices of the buttons on the panel this level, in spawn order. Same
## seed -> same answer, so both peers (and the puzzle, before the scene loads)
## agree without syncing anything.
func pick_buttons(seed_value: int) -> Array[int]:
	var picked: Array[int] = []
	picked.assign(range(button_pool.size()))
	
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	
	for i in range(picked.size() - 1, 0, -1):  # Fisher-Yates with the shared rng
		var j := rng.randi_range(0, i)
		var tmp := picked[i]
		picked[i] = picked[j]
		picked[j] = tmp
	
	return picked.slice(0, button_count)


## The spawned buttons the puzzle may ask for.
func live_buttons(seed_value: int) -> Array[int]:
	return pick_buttons(seed_value).slice(0, symbol_count)
