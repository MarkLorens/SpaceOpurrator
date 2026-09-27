class_name LevelConfig
extends Resource
## Everything that changes between levels. One .tres per level, listed in
## GameState.LEVELS; the level scene itself is shared.

@export_group("Puzzle")
## Steps in each sequence.
@export var sequence_length := 3
## Components and tools this level uses; every one spawns on the control panel.
## Steps are a component on its own, or a component paired with a tool that has
## a gesture. A button's value in the puzzle is its index here.
@export var button_pool: Array[ButtonDef] = []
## Chance that a step pairs its component with one of the usable tools.
@export_range(0.0, 1.0) var combo_chance := 0.3
## Never used to build sequences. Each round shows one; with code cards, each
## also labels a row (the first MAX_CODE_ROWS threats).
@export var threats: Array[ThreatDef] = []
## How many codes this level uses: 1 = X only, 2 = X and Y, 3 = X, Y and Z.
## Each round's threat carries one of them, and the players find its sequence
## on that code's card: one row per threat, random from button_pool and fixed
## for the level. With more than one code, the Next button flips between cards.
@export_range(1, 3) var code_count := 1

@export_group("Tutorial")
## Show a tutorial card when the level starts. Play waits until both players
## have closed it.
@export var has_tutorial := false
## Pages of the tutorial card (picture, caption, steps title, steps body).
@export var tutorial: Tutorial

@export_group("Progress bar")
@export var end_target := 100.0
@export var start_progress := 70.0
@export var drain_per_second := 1.0
@export var solve_reward := 10.0
## Seconds to solve the current puzzle before losing timeout_penalty.
@export var puzzle_time := 10.0
@export var timeout_penalty := 10.0


## The tutorial card opens at the start of this level.
func shows_tutorial() -> bool:
	return has_tutorial and tutorial != null and not tutorial.pages.is_empty()


## Rows on a code card (the card art has three slots).
const MAX_CODE_ROWS := 3


## There's at least one threat to put on the code cards. Without one the
## puzzle falls back to showing the sequence directly.
func uses_codes() -> bool:
	return not threats.is_empty()


## More than one card, so the players need the Next button to flip between them.
func has_next_button() -> bool:
	return uses_codes() and code_count > 1


## Threats that appear on code cards (and so can be picked in code mode).
func code_threats() -> int:
	return mini(threats.size(), MAX_CODE_ROWS)
