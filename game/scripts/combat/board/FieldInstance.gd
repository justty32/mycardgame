## One live field on one cell. No strong reference to its creator or board.
extends RefCounted
class_name FieldInstance

var field_data: FieldData = null
var cell: Vector2i = Vector2i.ZERO
var board_id: String = ""
var owner_uid: String = ""
## Kept after the creator dies; relative faction filters must not change allegiance.
var owner_faction: int = -1
var created_tick: int = 0
var expires_tick: int = -1
var next_tick: int = -1
var stacks: int = 1
## Refresh can occur twice at one combat tick; a timestamp is not a version.
var revision: int = 0

func _init(data: FieldData = null, at_cell: Vector2i = Vector2i.ZERO,
		owner: BaseCombatant = null, tick: int = 0, duration_override: int = -2) -> void:
	field_data = data
	cell = at_cell
	if is_instance_valid(owner):
		owner_uid = owner.unit_uid
		owner_faction = owner.faction
	refresh(tick, duration_override)

func refresh(tick: int, duration_override: int = -2) -> void:
	revision += 1
	created_tick = tick
	var duration: int = duration_override if duration_override != -2 else field_data.field_duration_ticks
	expires_tick = tick + max(0, duration) if duration >= 0 else -1
	next_tick = tick + field_data.field_tick_interval if field_data.field_tick_interval > 0 else -1

func get_owner() -> BaseCombatant:
	var owner: BaseCombatant = UnitRegistry.get_unit(owner_uid)
	return owner if is_instance_valid(owner) and owner.is_alive() else null

func affects(unit: BaseCombatant) -> bool:
	if not is_instance_valid(unit) or not unit.is_alive():
		return false
	match field_data.field_faction_filter:
		FieldData.FACTION_FILTERS.ANY:
			return true
		FieldData.FACTION_FILTERS.PARTY:
			return unit.faction == BaseCombatant.FACTIONS.PARTY
		FieldData.FACTION_FILTERS.ENEMY:
			return unit.faction == BaseCombatant.FACTIONS.ENEMY
		FieldData.FACTION_FILTERS.ALLY_OF_OWNER:
			return owner_faction >= 0 and unit.faction == owner_faction
		FieldData.FACTION_FILTERS.OPPONENT_OF_OWNER:
			return owner_faction >= 0 and unit.faction != owner_faction and unit.faction != BaseCombatant.FACTIONS.NEUTRAL
	return false
