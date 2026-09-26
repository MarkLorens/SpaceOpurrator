class_name LevelConfig
extends Resource
## Everything that changes between levels. One .tres per level, listed in
## GameState.LEVELS; the level scene itself is shared.

@export_group("Puzzle")
## Handwritten puzzles for the code card rows (each row gets a different one
## while they last). Every button they use always spawns. When empty, rows are
## random sequences (see below).
@export var sequences: Array[PuzzleSequence] = []
## Extra buttons for the panel: decoys next to the sequences' buttons, or the
## buttons random sequences are built from.
@export var button_pool: Array[ButtonDef] = []
## Buttons on the control panel (never fewer than the sequences need).
@export var button_count := 3
## Threats are just for show: each round displays a random one.
@export var threats: Array[ThreatDef] = []
## How many codes this level uses: 1 = X only, 2 = X and Y, 3 = X, Y and Z.
## Each round's threat carries one of them, and the players find its sequence
## on that code's card: one row per threat (the first MAX_CODE_ROWS), fixed for
## the level. With more than one code, the Next button flips between cards.
@export_range(1, 3) var code_count := 1

@export_subgroup("Random sequences")
## Steps in each random sequence.
@export var sequence_length := 3
## How many of the spawned buttons random sequences may use; the rest are decoys.
@export var symbol_count := 3
## Chance that a random step pairs its component with one of the usable tools.
@export_range(0.0, 1.0) var combo_chance := 0.3

@export_group("Progress bar")
@export var end_target := 100.0
@export var start_progress := 70.0
@export var drain_per_second := 1.0
@export var solve_reward := 10.0
## Seconds to solve the current puzzle before losing timeout_penalty.
@export var puzzle_time := 10.0
@export var timeout_penalty := 10.0


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


## Every button this level can spawn: the sequences' buttons first, then the
## rest of button_pool. A button's value in the puzzle is its index here, and
## both peers build the same list from the same resource.
func button_defs() -> Array[ButtonDef]:
	var defs := _sequence_buttons()
	for def in button_pool:
		if def and not defs.has(def):
			defs.append(def)
	return defs


## Indices into button_defs() of the buttons on the panel this level, in spawn
## order: every sequence button, then shuffled pool extras up to button_count.
## Same seed -> same answer, so both peers (and the puzzle, before the scene
## loads) agree without syncing anything.
func pick_buttons(seed_value: int) -> Array[int]:
	var required := _sequence_buttons().size()
	var extras: Array[int] = []
	extras.assign(range(required, button_defs().size()))
	
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	
	for i in range(extras.size() - 1, 0, -1):  # Fisher-Yates with the shared rng
		var j := rng.randi_range(0, i)
		var tmp := extras[i]
		extras[i] = extras[j]
		extras[j] = tmp
	
	var picked: Array[int] = []
	picked.assign(range(required))
	picked.append_array(extras.slice(0, maxi(button_count - required, 0)))
	return picked


## Random levels only: the spawned buttons random sequences may use.
func live_buttons(seed_value: int) -> Array[int]:
	return pick_buttons(seed_value).slice(0, symbol_count)


func _sequence_buttons() -> Array[ButtonDef]:
	var defs: Array[ButtonDef] = []
	for sequence in sequences:
		if not sequence:
			continue
		for step in sequence.steps:
			for def in [step.component, step.tool] if step else []:
				if def and not defs.has(def):
					defs.append(def)
	return defs
