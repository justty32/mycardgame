## Read only board encounter of a combat (combat framework Phase 2): board size, deploy / spawn
## zones, blocked cells and waves. EventData.event_encounter_object_id points here; events without
## one get an encounter synthesized from their enemy list (synthesize_from_event), so legacy events
## need no changes. Cell lists are [[x, y], ...] (JSON friendly).
extends SerializableData
class_name EncounterData

const BOARD_SIZE_DEFAULT: Vector2i = Vector2i(0, 0)

## Board size; BOARD_SIZE_DEFAULT = CombatRulesData.default_board_size. Smaller than
## CombatRulesData.board_min_size logs an error and is clamped to the minimum.
@export var encounter_board_size: Vector2i = BOARD_SIZE_DEFAULT
## Party deploy cells in order (hero first). Empty = the two south rows, centered.
@export var encounter_deploy_cells: Array[Array] = []
## Preferred cells for wave units without a free cell. Empty = the two north rows.
@export var encounter_spawn_zone_cells: Array[Array] = []
## Obstacle cells: cannot be entered or stopped on; flying units pass over them.
@export var encounter_blocked_cells: Array[Array] = []
@export var encounter_waves: Array[EncounterWaveData] = []
@export var encounter_cell_texture_path: String = ""
@export var encounter_background_texture_path: String = ""

func _get_native_properties() -> Dictionary:
	return {
		"encounter_board_size": Vector2i(),
	}

## Board size after defaults and the minimum clamp.
func get_board_size(rules: CombatRulesData) -> Vector2i:
	var board_size: Vector2i = encounter_board_size
	if board_size.x <= 0 or board_size.y <= 0:
		board_size = rules.default_board_size
	if board_size.x < rules.board_min_size.x or board_size.y < rules.board_min_size.y:
		DebugLogger.log_error("EncounterData: board size {0} of \"{1}\" is below the minimum {2}; clamped".format([board_size, object_id, rules.board_min_size]))
		board_size = Vector2i(max(board_size.x, rules.board_min_size.x), max(board_size.y, rules.board_min_size.y))
	return board_size

## Encounter of a legacy event: one wave, units on the north row (centered, left to right),
## default board size, default deploy and spawn zones.
static func synthesize_from_event(event_data: EventData, rules: CombatRulesData) -> EncounterData:
	var encounter := EncounterData.new("encounter_synthesized_" + (event_data.object_id if event_data != null else ""))
	var wave := EncounterWaveData.new()
	var board_size: Vector2i = rules.default_board_size
	var weights_list: Array[Dictionary] = []
	if event_data != null:
		weights_list = event_data.event_weighted_enemy_object_ids
	var count: int = len(weights_list)
	var start_x: int = max(0, int((board_size.x - count) / 2))
	for index: int in count:
		var unit_entry: Dictionary = {"weights": weights_list[index]}
		var x: int = start_x + index
		if x < board_size.x:
			unit_entry["cell"] = [x, 0]
		wave.wave_units.append(unit_entry)
	encounter.encounter_waves.append(wave)
	return encounter

static func cells_from_json(cell_list: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for value: Variant in cell_list:
		var cell: Vector2i = cell_from_json(value)
		if cell != BaseCombatant.BOARD_ANCHOR_NONE:
			cells.append(cell)
	return cells

## [x, y] / Vector2i / Vector2 -> Vector2i; anything else -> BaseCombatant.BOARD_ANCHOR_NONE.
static func cell_from_json(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(value)
	if value is Array and len(value) >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return BaseCombatant.BOARD_ANCHOR_NONE
