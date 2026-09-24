class_name LevelConfig
extends Resource
## Everything that changes between levels. One .tres per level, listed in
## GameState.LEVELS; the level scene itself is shared.

@export_group("Puzzle")
## Symbols in each target sequence.
@export var sequence_length := 3
## Sequence values are drawn from 1..symbol_count. Needs a texture for each in
## SequencedDone's `symbols`.
@export var symbol_count := 3
## Buttons spawned on the control panel (values 1..button_count); any above
## symbol_count are decoys.
@export var button_count := 6

@export_group("Progress bar")
@export var end_target := 100.0
@export var start_progress := 70.0
@export var drain_per_second := 1.0
@export var solve_reward := 10.0
## Seconds to solve the current puzzle before losing timeout_penalty.
@export var puzzle_time := 10.0
@export var timeout_penalty := 10.0
