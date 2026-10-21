## Read only combat rules shared by every combat (action timeline, energy, draw, board, party).
## The framework registers one object, DEFAULT_OBJECT_ID. New combats use two independent
## boards; SINGLE explicitly retains shared-board fixtures. Content packs patch rules to change pacing.
extends SerializableData
class_name CombatRulesData

## Object id of the rules object every combat reads. See Global.get_combat_rules().
const DEFAULT_OBJECT_ID: String = "combat_rules_default"
## energy_per_action / energy_cap value meaning "refill to max" / "cap is the unit's max energy".
const ENERGY_REFILL: int = -1
## Hard upper bound for board_max_size: above it BoardView cells drop below ~17 px.
const BOARD_SIZE_CEILING: Vector2i = Vector2i(16, 16)

enum DISTANCE_METRICS {MANHATTAN, CHEBYSHEV}
enum DOWNED_MEMBER_POLICIES {REVIVE_AFTER_COMBAT_1HP, LEAVE_PARTY, PERMADEATH}
enum TIE_BREAKS {HIGHER_SPEED_FIRST, PARTY_FIRST, SPAWN_ORDER}
enum MOVE_ADJACENCY {FOUR, EIGHT}
enum DISPLACE_TIE_AXES {VERTICAL, HORIZONTAL}
enum ZOC_MODES {NONE, EXTRA_MOVE_COST, OPPORTUNITY_ATTACK}
enum BOARD_MODES {SINGLE, DUAL}

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
## False leaves combat as an ordinary CTB battle without a mounted board component.
## Combat.board_module_enabled must also be true for the component to be composed.
@export var board_enabled: bool = true
## New combats use independent party/enemy boards. SINGLE is an explicit legacy fixture mode.
@export var board_mode: int = BOARD_MODES.DUAL
@export var cross_board_policy_version: int = 1
@export var cross_board_policy: String = "SELECT_TARGET_CELL"
@export var free_move_per_action: int = 0
@export var distance_metric: int = DISTANCE_METRICS.MANHATTAN
## Allowed board size per axis for every encounter board (inclusive). 3 keeps CROSS / SQUARE_3 and a
## centre cell on the board; 12 keeps the cell >= 23 px in BoardView's 460x280 slot. Packs may narrow
## or widen these within [1, BOARD_SIZE_CEILING]; out-of-range encounter sizes are rejected.
@export var board_min_size: Vector2i = Vector2i(3, 3)
@export var board_max_size: Vector2i = Vector2i(12, 12)
## Size of a board whose encounter declares none.
@export var default_board_size: Vector2i = Vector2i(5, 5)
#endregion

#region Party
@export var party_size_max: int = 1
@export var deploy_size_max: int = 1
@export var downed_member_policy: int = DOWNED_MEMBER_POLICIES.REVIVE_AFTER_COMBAT_1HP
@export var hero_down_ends_run: bool = true
#endregion

#region Movement (combat framework Phase 2; defaults = no movement, no change to old behavior)
## Neighbour rule of deterministic weighted path finding.
@export var move_adjacency: int = MOVE_ADJACENCY.FOUR
## true = a unit may move before and after playing cards; false = the first card play ends movement.
@export var move_split_allowed: bool = true
## Cells a party unit may move per action after its free move points, each adding
## extra_move_delay_per_cell to the action delay. 0 = no paid movement.
@export var paid_move_max_cells: int = 0
## Passing through units never permits stopping on an occupied cell.
@export var move_pass_through_allies: bool = false
@export var move_pass_through_enemies: bool = false
@export var move_undo_allowed: bool = false
@export var zone_of_control: int = ZOC_MODES.NONE
@export var zoc_extra_move_cost: int = 1
@export var zoc_triggers_on_forced_move: bool = false
## Axis used by forced displacement when |dx| == |dy|.
@export var displace_tie_axis: int = DISPLACE_TIE_AXES.VERTICAL
## Units whose footprint area exceeds this cannot be displaced.
@export var displace_max_footprint_area: int = 1
#endregion

func _get_native_properties() -> Dictionary:
	return {
		"board_min_size": Vector2i(),
		"board_max_size": Vector2i(),
		"default_board_size": Vector2i(),
	}

## Unknown policies are rejected, never interpreted as the currently supported policy.
func validate_configuration() -> String:
	if board_mode not in [BOARD_MODES.SINGLE, BOARD_MODES.DUAL]:
		return "unknown_board_mode"
	if cross_board_policy_version != 1:
		return "unsupported_cross_board_policy_version"
	if cross_board_policy != "SELECT_TARGET_CELL":
		return "unknown_cross_board_policy"
	if board_min_size.x < 1 or board_min_size.y < 1 or board_max_size.x > BOARD_SIZE_CEILING.x or board_max_size.y > BOARD_SIZE_CEILING.y:
		return "invalid_board_size_limits"
	if board_min_size.x > board_max_size.x or board_min_size.y > board_max_size.y or not is_board_size_allowed(default_board_size):
		return "invalid_board_size_limits"
	return ""

## True when size lies inside [board_min_size, board_max_size] on both axes.
func is_board_size_allowed(size: Vector2i) -> bool:
	return size.x >= board_min_size.x and size.y >= board_min_size.y and size.x <= board_max_size.x and size.y <= board_max_size.y

## Human readable allowed range, used in validation details.
func describe_board_size_limits() -> String:
	return "%dx%d..%dx%d" % [board_min_size.x, board_min_size.y, board_max_size.x, board_max_size.y]

## Energy to add at the start of an action, given the unit's current and max energy.
## With ENERGY_REFILL the caller resets energy to 0 first, so the gain is the full max.
## Interceptors still adjust the generated ActionAddEnergy amount.
func get_start_of_action_energy_gain(current_energy: int, energy_max: int) -> int:
	if energy_per_action == ENERGY_REFILL:
		return energy_max
	var cap: int = energy_max if energy_cap == ENERGY_REFILL else energy_cap
	return clampi(energy_per_action, 0, max(0, cap - current_energy))
