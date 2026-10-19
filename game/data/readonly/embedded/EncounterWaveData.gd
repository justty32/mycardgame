## Embedded read only data in EncounterData: one wave of units entering the board.
## Phase 2 spawns wave 0 only; the timing and action fields are consumed by the wave flow (Phase 3).
extends SerializableData
class_name EncounterWaveData

## What to do when a wave unit's cell is occupied. Phase 2 implements NEAREST_EMPTY.
enum SPAWN_POLICIES {NEAREST_EMPTY, WAIT_UNTIL_FREE, FAIL_SKIP}

## One entry per unit: {"weights": {"enemy_id": weight}, "cell": [x, y], "spawn_delay_ticks": int}.
## A missing or off-board "cell" places the unit on the nearest empty spawn-zone cell.
@export var wave_units: Array[Dictionary] = []
@export var wave_enter_delay_ticks: int = 0
@export var wave_stagger_ticks: int = 0
@export var wave_on_start_actions: Array[Dictionary] = []
@export var wave_on_cleared_actions: Array[Dictionary] = []
@export var wave_spawn_policy: int = SPAWN_POLICIES.NEAREST_EMPTY
@export var wave_spawn_retry_ticks: int = 50
@export var wave_spawn_max_retries: int = 4
