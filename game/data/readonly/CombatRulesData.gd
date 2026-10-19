## Read only combat rules shared by every combat (action timeline, energy, draw, board, party).
## The framework registers one object, DEFAULT_OBJECT_ID, whose values reproduce the original
## single-character, turn-based behavior. Content packs patch that object to change pacing.
## NOTE: Phase 0 only consumes draw_per_action, energy_per_action and energy_cap
## (see ActionGenerator start-of-action helpers); the remaining fields are read by later phases.
extends SerializableData
class_name CombatRulesData

## Object id of the rules object every combat reads. See Global.get_combat_rules().
const DEFAULT_OBJECT_ID: String = "combat_rules_default"
## energy_per_action / energy_cap value meaning "refill to max" / "cap is the unit's max energy".
const ENERGY_REFILL: int = -1

enum DISTANCE_METRICS {MANHATTAN, CHEBYSHEV}
enum DOWNED_MEMBER_POLICIES {REVIVE_AFTER_COMBAT_1HP, LEAVE_PARTY, PERMADEATH}
enum TIE_BREAKS {HIGHER_SPEED_FIRST, PARTY_FIRST, SPAWN_ORDER}

#region Timeline
## wait = action_delay * timeline_delay_scale / speed
@export var timeline_delay_scale: int = 100
@export var default_action_delay: int = 100
## Delay of an action that only waits.
@export var wait_action_delay: int = 50
@export var extra_move_delay_per_cell: int = 0
@export var tie_break: int = TIE_BREAKS.HIGHER_SPEED_FIRST
#endregion

#region Energy, draw and hand
## ENERGY_REFILL (-1) = refill to max at the start of each action (original behavior);
## >= 0 = add this much energy at the start of each action.
@export var energy_per_action: int = ENERGY_REFILL
## ENERGY_REFILL (-1) = cap is the unit's max energy; >= 0 = explicit cap for per-action gains.
@export var energy_cap: int = ENERGY_REFILL
## Cards drawn at the start of each action.
@export var draw_per_action: int = 5
@export var hand_limit: int = 10
@export var discard_hand_on_action_end: bool = true
@export var reset_block_on_action_start: bool = true
#endregion

#region Board and movement
@export var free_move_per_action: int = 0
@export var distance_metric: int = DISTANCE_METRICS.MANHATTAN
@export var board_min_size: Vector2i = Vector2i(5, 5)
@export var default_board_size: Vector2i = Vector2i(5, 5)
#endregion

#region Party
@export var party_size_max: int = 1
@export var deploy_size_max: int = 1
@export var downed_member_policy: int = DOWNED_MEMBER_POLICIES.REVIVE_AFTER_COMBAT_1HP
@export var hero_down_ends_run: bool = true
#endregion

func _get_native_properties() -> Dictionary:
	return {
		"board_min_size": Vector2i(),
		"default_board_size": Vector2i(),
	}

## Energy to add at the start of an action, given the unit's current and max energy.
## With ENERGY_REFILL the caller resets energy to 0 first, so the gain is the full max.
## Interceptors still adjust the generated ActionAddEnergy amount.
func get_start_of_action_energy_gain(current_energy: int, energy_max: int) -> int:
	if energy_per_action == ENERGY_REFILL:
		return energy_max
	var cap: int = energy_max if energy_cap == ENERGY_REFILL else energy_cap
	return clampi(energy_per_action, 0, max(0, cap - current_energy))
