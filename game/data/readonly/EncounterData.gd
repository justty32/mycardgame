## Read only encounter: independent board sizes, deploy / spawn zones, blocked cells and waves.
## EventData.event_encounter_object_id points here; events without
## one get an encounter synthesized from their enemy list (synthesize_from_event), so legacy events
## need no changes and inherit the default board mode. Cell lists are [[x, y], ...] (JSON friendly).
extends SerializableData
class_name EncounterData

const BOARD_SIZE_DEFAULT: Vector2i = Vector2i(0, 0)

## -1 inherits combat rules; SINGLE must be explicitly selected for legacy shared-board content.
@export var encounter_board_mode: int = -1
## Per-board overrides keyed by party/enemy (or shared in SINGLE mode). Entry keys: size,
## blocked_cells, deploy_cells, spawn_zone_cells, initial_fields. Missing keys use legacy fields.
@export var encounter_boards: Dictionary = {}

## Board size of every board unless encounter_boards.<id>.size overrides it.
## BOARD_SIZE_DEFAULT (0, 0) = CombatRulesData.default_board_size. Sizes outside
## [CombatRulesData.board_min_size, board_max_size] fail validate_configuration.
@export var encounter_board_size: Vector2i = BOARD_SIZE_DEFAULT
## Party deploy cells in order (hero first). Empty = the two south rows, centered.
@export var encounter_deploy_cells: Array[Array] = []
## Preferred cells for wave units without a free cell. Empty = the two north rows.
@export var encounter_spawn_zone_cells: Array[Array] = []
## Obstacle cells: cannot be entered or stopped on; flying units pass over them.
@export var encounter_blocked_cells: Array[Array] = []
## Each entry: {field_id, cells:[[x,y],...]}; no owner for encounter terrain.
@export var encounter_initial_fields: Array[Dictionary] = []
@export var encounter_waves: Array[EncounterWaveData] = []
@export var encounter_cell_texture_path: String = ""
@export var encounter_background_texture_path: String = ""

## Raw envelope is deliberately Variant: malformed scalar/null inputs must survive loading.
## Local serialization handles it before SerializableData's typed Dictionary assignment.
var encounter_board_setup: Variant = {}

func get_serializable_property_names() -> Array[String]:
	var names: Array[String] = super.get_serializable_property_names()
	names.append("encounter_board_setup")
	return names

func get_serializable_properties(json_friendly: bool = true) -> Dictionary:
	var properties: Dictionary = super.get_serializable_properties(json_friendly)
	properties["encounter_board_setup"] = _copy_setup_value(encounter_board_setup)
	return properties

func set_serializable_properties(object_data: Dictionary, json_friendly: bool = true, patch_data: Dictionary = {}) -> void:
	var remaining: Dictionary = object_data.duplicate()
	if remaining.has("encounter_board_setup"):
		var incoming: Variant = remaining.encounter_board_setup
		if encounter_board_setup is Dictionary and incoming is Dictionary:
			encounter_board_setup = patch_dictionary(encounter_board_setup.duplicate(true), incoming.duplicate(true), patch_data.get("encounter_board_setup", "overwrite"))
		else:
			encounter_board_setup = _copy_setup_value(incoming)
		remaining.erase("encounter_board_setup")
	super.set_serializable_properties(remaining, json_friendly, patch_data)

static func _copy_setup_value(value: Variant) -> Variant:
	return value.duplicate(true) if value is Array or value is Dictionary else value

func has_legacy_board_overrides() -> bool:
	return encounter_board_mode != -1 or encounter_board_size != BOARD_SIZE_DEFAULT or not encounter_boards.is_empty() or not encounter_deploy_cells.is_empty() or not encounter_spawn_zone_cells.is_empty() or not encounter_blocked_cells.is_empty() or not encounter_initial_fields.is_empty()

func _get_native_properties() -> Dictionary:
	return {
		"encounter_board_size": Vector2i(),
	}

## Legacy single size after defaults, clamped into the rules range (validation reports violations).
func get_board_size(rules: CombatRulesData) -> Vector2i:
	var board_size: Vector2i = encounter_board_size
	if board_size.x <= 0 or board_size.y <= 0:
		board_size = rules.default_board_size
	return _clamp_size(board_size, rules)

func get_board_mode(rules: CombatRulesData) -> int:
	return rules.board_mode if encounter_board_mode == -1 else encounter_board_mode

## Board ids the mode creates: shared in SINGLE, party / enemy in DUAL.
func get_board_ids(rules: CombatRulesData) -> Array[String]:
	var ids: Array[String] = ["shared"]
	if get_board_mode(rules) == CombatRulesData.BOARD_MODES.DUAL:
		ids.assign(["party", "enemy"])
	return ids

func get_board_config(board_id: String) -> Dictionary:
	var result: Dictionary = {
		"size": encounter_board_size,
		"deploy_cells": encounter_deploy_cells,
		"spawn_zone_cells": encounter_spawn_zone_cells,
		"blocked_cells": encounter_blocked_cells,
		"initial_fields": encounter_initial_fields,
	}
	var overrides: Variant = encounter_boards.get(board_id, {})
	if overrides is Dictionary:
		result.merge(overrides, true)
	return result

## Per-board size: encounter_boards.<id>.size, else encounter_board_size, else the rules default.
## [0, 0] at either level means "inherit".
func get_size_for_board(board_id: String, rules: CombatRulesData) -> Vector2i:
	var configured: Vector2i = cell_from_json(get_board_config(board_id).size)
	if configured.x <= 0 or configured.y <= 0:
		return get_board_size(rules)
	return _clamp_size(configured, rules)

static func _clamp_size(size: Vector2i, rules: CombatRulesData) -> Vector2i:
	return Vector2i(clampi(size.x, max(1, rules.board_min_size.x), max(1, rules.board_max_size.x)), clampi(size.y, max(1, rules.board_min_size.y), max(1, rules.board_max_size.y)))

## Error code only ("" = valid). See validate_configuration_detail for the author-facing message.
func validate_configuration(rules: CombatRulesData) -> String:
	return validate_configuration_detail(rules).code

## {code, detail}: code is a stable identifier, detail names the encounter, board and offending value.
func validate_configuration_detail(rules: CombatRulesData) -> Dictionary:
	var mode: int = get_board_mode(rules)
	if mode not in [CombatRulesData.BOARD_MODES.SINGLE, CombatRulesData.BOARD_MODES.DUAL]:
		return _invalid("unknown_encounter_board_mode", "encounter_board_mode %s" % [mode])
	var allowed: Array[String] = get_board_ids(rules)
	for board_id: Variant in encounter_boards:
		if board_id not in allowed or not encounter_boards[board_id] is Dictionary:
			return _invalid("invalid_encounter_board", "encounter_boards key \"%s\" (this mode allows %s, each value an object)" % [board_id, allowed])
	var legacy: Dictionary = _check_size(encounter_board_size, rules, "encounter_board_size")
	if legacy.code != "":
		return legacy
	for board_id: String in allowed:
		var config: Dictionary = get_board_config(board_id)
		var checked: Dictionary = _check_size(config.size, rules, "board \"%s\" size" % board_id)
		if checked.code != "":
			return checked
		var board_size: Vector2i = get_size_for_board(board_id, rules)
		for key: String in ["blocked_cells", "deploy_cells", "spawn_zone_cells"]:
			if not config[key] is Array:
				return _invalid("invalid_encounter_board_cells", "board \"%s\" %s must be [[x, y], ...]" % [board_id, key])
			for cell: Variant in config[key]:
				var bad: Dictionary = _check_cell(cell, board_size, "board \"%s\" %s" % [board_id, key])
				if bad.code != "":
					return bad
		if not config.initial_fields is Array:
			return _invalid("invalid_encounter_board_fields", "board \"%s\" initial_fields must be an array" % board_id)
		for field: Variant in config.initial_fields:
			if not field is Dictionary or not field.get("cells", []) is Array:
				return _invalid("invalid_encounter_board_fields", "board \"%s\" initial_fields entries are {field_id, cells}" % board_id)
			for cell: Variant in field.get("cells", []):
				var bad: Dictionary = _check_cell(cell, board_size, "board \"%s\" initial_fields %s" % [board_id, field.get("field_id", "")])
				if bad.code != "":
					return bad
	var default_wave_board: String = allowed[allowed.size() - 1]
	for wave_index: int in encounter_waves.size():
		var wave: EncounterWaveData = encounter_waves[wave_index]
		if wave == null:
			continue
		for unit_index: int in wave.wave_units.size():
			var unit_entry: Dictionary = wave.wave_units[unit_index]
			var label: String = "wave %d unit %d" % [wave_index, unit_index]
			var board_id: String = str(unit_entry.get("board_id", ""))
			if board_id == "":
				board_id = default_wave_board
			if board_id not in allowed:
				return _invalid("invalid_encounter_wave_board", "%s board_id \"%s\" (this mode allows %s)" % [label, board_id, allowed])
			if unit_entry.has("cell"):
				var bad: Dictionary = _check_cell(unit_entry.cell, get_size_for_board(board_id, rules), "%s cell on board \"%s\"" % [label, board_id])
				if bad.code != "":
					return bad
	return {"code": "", "detail": ""}

func _invalid(code: String, detail: String) -> Dictionary:
	return {"code": code, "detail": "EncounterData \"%s\": %s" % [object_id, detail]}

## [0, 0] (inherit) is valid; otherwise both axes must be whole numbers inside the rules range.
func _check_size(value: Variant, rules: CombatRulesData, label: String) -> Dictionary:
	if not _valid_cell(value) or not _whole_cell(value):
		return _invalid("invalid_encounter_board_size", "%s %s is not [width, height] in whole cells" % [label, value])
	var size: Vector2i = cell_from_json(value)
	if size == Vector2i.ZERO:
		return {"code": "", "detail": ""}
	if size.x <= 0 or size.y <= 0:
		return _invalid("invalid_encounter_board_size", "%s %s needs both axes > 0 ([0, 0] inherits the default)" % [label, value])
	if not rules.is_board_size_allowed(size):
		return _invalid("encounter_board_size_out_of_range", "%s %dx%d is outside the allowed %s (CombatRulesData board_min_size / board_max_size)" % [label, size.x, size.y, rules.describe_board_size_limits()])
	return {"code": "", "detail": ""}

func _check_cell(value: Variant, board_size: Vector2i, label: String) -> Dictionary:
	if not _valid_cell(value) or not _whole_cell(value):
		return _invalid("invalid_encounter_board_cells", "%s %s is not [x, y] in whole cells" % [label, value])
	var cell: Vector2i = cell_from_json(value)
	if cell.x < 0 or cell.y < 0 or cell.x >= board_size.x or cell.y >= board_size.y:
		return _invalid("encounter_cell_out_of_bounds", "%s [%d, %d] is outside the %dx%d board (x 0..%d, y 0..%d)" % [label, cell.x, cell.y, board_size.x, board_size.y, board_size.x - 1, board_size.y - 1])
	return {"code": "", "detail": ""}

static func _whole_cell(value: Variant) -> bool:
	if value is Vector2:
		return value.x == floorf(value.x) and value.y == floorf(value.y)
	if value is Array:
		return float(value[0]) == floorf(float(value[0])) and float(value[1]) == floorf(float(value[1]))
	return true

static func _valid_cell(value: Variant) -> bool:
	if value is Vector2i or value is Vector2:
		return true
	return value is Array and value.size() == 2 and (value[0] is int or value[0] is float) and (value[1] is int or value[1] is float)

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
