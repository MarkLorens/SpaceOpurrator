class_name LevelConfig
extends Resource
## Everything that changes between levels. One .tres per level, listed in
## GameState.LEVELS; the level scene itself is shared.

@export_group("Puzzle")
## Steps in each target sequence.
@export var sequence_length := 3
## Components and tools this level uses; every one spawns on the control panel.
## Steps are a component on its own, or a component paired with a tool that has
## a gesture. A button's value in the puzzle is its index here.
@export var button_pool: Array[ButtonDef] = []
## Chance that a step pairs its component with one of the usable tools.
@export_range(0.0, 1.0) var combo_chance := 0.3
## Threats are just for show: each round displays a random one.
@export var threats: Array[ThreatDef] = []

@export_group("Progress bar")
@export var end_target := 100.0
@export var start_progress := 70.0
@export var drain_per_second := 1.0
@export var solve_reward := 10.0
## Seconds to solve the current puzzle before losing timeout_penalty.
@export var puzzle_time := 10.0
@export var timeout_penalty := 10.0

