## Read-only cell effect template (SCHEMA fields/). Durations use combat ticks.
extends SerializableData
class_name FieldData

enum FACTION_FILTERS {ANY, PARTY, ENEMY, ALLY_OF_OWNER, OPPONENT_OF_OWNER}
enum STACK_POLICIES {REPLACE, STACK, IGNORE}

@export var field_name: String = ""
@export var field_color_id: String = ""
@export var field_icon_texture_path: String = ""
@export var field_duration_ticks: int = -1
@export var field_tick_interval: int = 0
@export var field_faction_filter: int = FACTION_FILTERS.ANY
@export var field_stack_policy: int = STACK_POLICIES.REPLACE
@export var field_blocks_movement: bool = false
@export var field_blocks_teleport_into: bool = false
@export var field_move_cost_override: int = -1
@export var field_triggers_on_pass_through: bool = false
@export var field_triggers_on_spawn: bool = false
@export var field_on_enter_actions: Array[Dictionary] = []
@export var field_on_leave_actions: Array[Dictionary] = []
@export var field_on_stay_actions: Array[Dictionary] = []
@export var field_tick_actions: Array[Dictionary] = []
@export var field_tags: Array[String] = []
