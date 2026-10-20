## Embedded read only data in EncounterData: one wave of units entering the board.
## Wave flow (combat framework Phase 3, CombatDirector's WaveController / UnitSpawner): wave 0 enters
## at combat start; wave i + 1 starts wave_enter_delay_ticks after wave i is cleared (no living
## non-minion enemy and all its units entered). Unit k enters at the wave start
## + wave_stagger_ticks * k + its spawn_delay_ticks and acts at that tick (wave 0 units are placed at
## combat start and first act at that tick). wave_on_start_actions run on wave_started,
## wave_on_cleared_actions on wave_cleared (parent = hero).
extends SerializableData
class_name EncounterWaveData

## What to do when a wave unit's cell is occupied: NEAREST_EMPTY = nearest free anchor (full board:
## retry like WAIT_UNTIL_FREE); WAIT_UNTIL_FREE = retry every wave_spawn_retry_ticks up to
## wave_spawn_max_retries, then NEAREST_EMPTY; FAIL_SKIP = skip the unit. Skipped units do not block
## the wave clear.
enum SPAWN_POLICIES {NEAREST_EMPTY, WAIT_UNTIL_FREE, FAIL_SKIP}

## One entry per unit: {"weights": {"enemy_id": weight}, "cell": [x, y], "spawn_delay_ticks": int}.
## Optional board_id selects a destination board; absent means enemy/shared, never overflow to another board.
## A missing or off-board "cell" places the unit on the nearest empty spawn-zone cell.
@export var wave_units: Array[Dictionary] = []
@export var wave_enter_delay_ticks: int = 0
@export var wave_stagger_ticks: int = 0
@export var wave_on_start_actions: Array[Dictionary] = []
@export var wave_on_cleared_actions: Array[Dictionary] = []
@export var wave_spawn_policy: int = SPAWN_POLICIES.NEAREST_EMPTY
@export var wave_spawn_retry_ticks: int = 50
@export var wave_spawn_max_retries: int = 4
