## Detached, normalized board definitions. Runtime geometry never interprets legacy modes.
extends RefCounted
class_name BoardSetup

var _definitions: Dictionary = {}
var deployment: BoardDeployment = null
var _validated: bool = false
var error: String = ""
var error_detail: String = ""

func is_valid() -> bool:
	return _validated and error == ""

func get_config(id: String) -> Dictionary:
	return _definitions.get(id, {}).duplicate(true)

func get_board_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_definitions.keys())
	return ids

static func from_legacy(encounter: EncounterData, rules: CombatRulesData) -> BoardSetup:
	var setup := BoardSetup.new()
	setup.error = rules.validate_configuration()
	if setup.error != "":
		setup.error_detail = "CombatRulesData \"%s\": %s (board sizes %s, default %s, ceiling %s)" % [rules.object_id, setup.error, rules.describe_board_size_limits(), rules.default_board_size, CombatRulesData.BOARD_SIZE_CEILING]
		return setup
	var checked: Dictionary = encounter.validate_configuration_detail(rules)
	setup.error = checked.code
	setup.error_detail = checked.detail
	if setup.error != "":
		return setup
	for id: String in encounter.get_board_ids(rules):
		var config: Dictionary = encounter.get_board_config(id).duplicate(true)
		config.size = encounter.get_size_for_board(id, rules)
		setup._definitions[id] = config
	var single: bool = encounter.get_board_mode(rules) == CombatRulesData.BOARD_MODES.SINGLE
	var normalized: BoardSetup = from_definitions(setup._definitions, rules)
	if normalized.is_valid():
		normalized.deployment = BoardDeployment.new(normalized._definitions, "shared" if single else "party", "shared" if single else "enemy")
	return normalized

## Internal geometry input, not a serialized encounter format. No deployment policy is required.
static func from_definitions(definitions: Dictionary, rules: CombatRulesData) -> BoardSetup:
	var setup := BoardSetup.new()
	setup.error = rules.validate_spatial_configuration()
	if setup.error != "":
		setup.error_detail = setup.error
		return setup
	for id: Variant in definitions:
		if not id is String or id == "" or not definitions[id] is Dictionary:
			return _invalid("invalid_board_definition", "board IDs must be nonempty strings and definitions objects")
		var config: Dictionary = definitions[id].duplicate(true)
		var raw_size: Variant = config.get("size", null)
		if not EncounterData._valid_cell(raw_size) or not EncounterData._whole_cell(raw_size):
			return _invalid("invalid_board_definition_size", "board %s size must be two whole numbers" % id)
		var size: Vector2i = EncounterData.cell_from_json(raw_size)
		if not rules.is_board_size_allowed(size):
			return _invalid("invalid_board_definition_size", "board %s size %s is outside %s" % [id, size, rules.describe_board_size_limits()])
		config.size = size
		for key: String in ["blocked_cells", "deploy_cells", "spawn_zone_cells"]:
			var cells: Variant = config.get(key, [])
			if not cells is Array:
				return _invalid("invalid_board_definition_cells", "board %s %s must be an array" % [id, key])
			for value: Variant in cells:
				if not _valid_cell(value, size):
					return _invalid("invalid_board_definition_cells", "board %s %s has invalid cell %s" % [id, key, value])
			config[key] = cells
		var fields: Variant = config.get("initial_fields", [])
		if not fields is Array:
			return _invalid("invalid_board_definition_fields", "board %s initial_fields must be an array" % id)
		for field: Variant in fields:
			if not field is Dictionary or not field.get("cells", []) is Array:
				return _invalid("invalid_board_definition_fields", "board %s invalid initial field" % id)
			for value: Variant in field.get("cells", []):
				if not _valid_cell(value, size):
					return _invalid("invalid_board_definition_fields", "board %s invalid field cell %s" % [id, value])
		config.initial_fields = fields
		setup._definitions[id] = config
	setup._validated = true
	return setup

static func _valid_cell(value: Variant, size: Vector2i) -> bool:
	if not EncounterData._valid_cell(value) or not EncounterData._whole_cell(value):
		return false
	var cell: Vector2i = EncounterData.cell_from_json(value)
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y

static func _invalid(code: String, detail: String) -> BoardSetup:
	var setup := BoardSetup.new()
	setup.error = code
	setup.error_detail = detail
	return setup
